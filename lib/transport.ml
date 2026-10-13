open! Core
open! Async

module Meth = struct
  type t =
    [ `GET
    | `POST
    | `PATCH
    | `DELETE
    ]
  [@@deriving sexp_of, equal]

  let to_string = function
    | `GET -> "GET"
    | `POST -> "POST"
    | `PATCH -> "PATCH"
    | `DELETE -> "DELETE"
  ;;
end

module Response = struct
  type t =
    { status : int
    ; headers : (string * string) list
    ; body : string
    }
  [@@deriving sexp_of]

  let header t name =
    List.find_map t.headers ~f:(fun (k, v) ->
      if String.Caseless.equal k name then Some v else None)
  ;;
end

type send =
  meth:Meth.t
  -> Uri.t
  -> headers:(string * string) list
  -> body:string option
  -> Response.t Or_error.t Deferred.t

module Event = struct
  type t =
    { request_id : string
    ; meth : Meth.t
    ; path : string
    ; attempt : int
    ; outcome : [ `Status of int | `Failed of string ]
    ; elapsed : Time_ns.Span.t
    }
  [@@deriving sexp_of]
end

type t =
  { config : Config.t
  ; send : send
  ; sleep : Time_ns.Span.t -> unit Deferred.t
  ; now : unit -> Time_ns.t
  ; max_retries : int
  ; throttle : unit Throttle.t
  ; on_event : Event.t -> unit
  }

let config t = t.config

(* Seeded from the clock: ox Base forbids [Random.State.make_self_init] inside inline
   tests ("nondeterministic seed is forbidden"). *)
let random_state =
  lazy (Random.State.make [| Time_ns.to_int_ns_since_epoch (Time_ns.now ()) |])
;;

let uuid_v4 () =
  let st = Lazy.force random_state in
  let b = Bytes.init 16 ~f:(fun _ -> Char.of_int_exn (Random.State.int st 256)) in
  Bytes.set b 6 (Char.of_int_exn (Char.to_int (Bytes.get b 6) land 0x0f lor 0x40));
  Bytes.set b 8 (Char.of_int_exn (Char.to_int (Bytes.get b 8) land 0x3f lor 0x80));
  let hex = Cryptokit.transform_string (Cryptokit.Hexa.encode ()) (Bytes.to_string b) in
  String.concat
    ~sep:"-"
    [ String.sub hex ~pos:0 ~len:8
    ; String.sub hex ~pos:8 ~len:4
    ; String.sub hex ~pos:12 ~len:4
    ; String.sub hex ~pos:16 ~len:4
    ; String.sub hex ~pos:20 ~len:12
    ]
;;

let cohttp_send ~timeout ~meth uri ~headers ~body =
  let ssl_config =
    match Uri.scheme uri, Uri.host uri with
    | Some "https", Some host -> Some (Tls.config ~host)
    | _ -> None
  in
  let attempt () =
    let%bind resp, body =
      Cohttp_async.Client.call
        ?ssl_config
        ~headers:(Cohttp.Header.of_list headers)
        ?body:(Option.map body ~f:Cohttp_async.Body.of_string)
        (meth :> Cohttp.Code.meth)
        uri
    in
    let%map body = Cohttp_async.Body.to_string body in
    { Response.status = Cohttp.Code.code_of_status (Cohttp.Response.status resp)
    ; headers = Cohttp.Header.to_list (Cohttp.Response.headers resp)
    ; body
    }
  in
  match%map
    Clock_ns.with_timeout timeout (Monitor.try_with_or_error ~extract_exn:true attempt)
  with
  | `Timeout -> Or_error.error_s [%message "request timed out" (timeout : Time_ns.Span.t)]
  | `Result r -> r
;;

let create
  ?send
  ?(sleep = Clock_ns.after)
  ?(now = Time_ns.now)
  ?(max_retries = 4)
  ?(max_in_flight = 8)
  ?(timeout = Time_ns.Span.of_sec 30.)
  ?(on_event = ignore)
  config
  =
  let send = Option.value send ~default:(cohttp_send ~timeout) in
  { config
  ; send
  ; sleep
  ; now
  ; max_retries
  ; throttle = Throttle.create ~continue_on_error:true ~max_concurrent_jobs:max_in_flight
  ; on_event
  }
;;

let url t path =
  if not (String.is_prefix path ~prefix:"/")
  then Or_error.error_s [%message "API path must start with /" (path : string)]
  else if String.is_substring path ~substring:"://" || String.is_prefix path ~prefix:"//"
  then Or_error.error_s [%message "API path must not name a host" (path : string)]
  else (
    let base = t.config.base_url in
    let base_path = String.chop_suffix_if_exists (Uri.path base) ~suffix:"/" in
    Ok (Uri.with_path (Uri.with_query base []) (base_path ^ path)))
;;

let backoff ~attempt ~retry_after =
  match Option.bind retry_after ~f:(fun s -> Int.of_string_opt (String.strip s)) with
  | Some secs when secs >= 0 -> Time_ns.Span.of_int_sec (Int.min secs 60)
  | _ ->
    let ms = 250 * (1 lsl Int.min (attempt - 1) 5) in
    Time_ns.Span.of_int_ms (Int.min ms 8000)
;;

let retryable_status s = s = 429 || s = 500 || s = 502 || s = 503 || s = 504
let redact t s = Redact.text ~secrets:(Config.secrets t.config) s

let headers_for t ~meth ~path ~body ~request_id =
  let time_ms = Int.to_string (Time_ns.to_int_ns_since_epoch (t.now ()) / 1_000_000) in
  let authorization =
    Signature.authorization
      ~secret:t.config.api_secret
      ~time_ms
      ~meth:(Meth.to_string meth)
      ~path
      ~body
  in
  [ "api-key", Secret.reveal t.config.api_key
  ; "authorization", authorization
  ; "content-type", "application/json"
  ; "accept", "application/json"
  ; "x-request-id", request_id
  ]
;;

let call ?idempotent t (meth : Meth.t) path ?body () =
  let idempotent =
    match idempotent with
    | Some b -> b
    | None ->
      (match meth with
       | `GET -> true
       | `POST | `PATCH | `DELETE -> false)
  in
  match url t path with
  | Error _ as e -> return e
  | Ok uri ->
    let request_id = uuid_v4 () in
    let body =
      match meth, body with
      | `GET, _ -> None
      | _, Some b -> Some (Yojson.Safe.to_string b)
      | _, None -> Some "{}"
    in
    let rec attempt n =
      (* Signed per attempt: the timestamp is part of the signature. *)
      let headers = headers_for t ~meth ~path ~body ~request_id in
      let started = t.now () in
      let%bind result =
        Throttle.enqueue t.throttle (fun () -> t.send ~meth uri ~headers ~body)
      in
      let elapsed = Time_ns.diff (t.now ()) started in
      let outcome =
        match result with
        | Ok r -> `Status r.status
        | Error e -> `Failed (redact t (Error.to_string_hum e))
      in
      t.on_event { request_id; meth; path; attempt = n; outcome; elapsed };
      let retry ~retry_after =
        let%bind () = t.sleep (backoff ~attempt:n ~retry_after) in
        attempt (n + 1)
      in
      match result with
      | Ok r when retryable_status r.status && idempotent && n <= t.max_retries ->
        retry ~retry_after:(Response.header r "retry-after")
      | Ok r -> return (Ok (r, request_id))
      | Error _ when idempotent && n <= t.max_retries -> retry ~retry_after:None
      | Error e ->
        return
          (Error
             (Error.create_s
                [%message
                  "striga request failed"
                    ~meth:(Meth.to_string meth)
                    (path : string)
                    (request_id : string)
                    ~error:(redact t (Error.to_string_hum e))]))
    in
    attempt 1
;;

let check t meth path (r : Response.t) request_id =
  if r.status >= 200 && r.status < 300
  then Ok r
  else
    Error
      (Api_error.to_error
         (Api_error.of_response
            ~meth:(Meth.to_string meth)
            ~path
            ~request_id
            ~redact:(redact t)
            ~status:r.status
            ~body:r.body))
;;

let json ?idempotent t meth path ?body () =
  let%map result = call ?idempotent t meth path ?body () in
  let open Or_error.Let_syntax in
  let%bind r, request_id = result in
  let%bind r = check t meth path r request_id in
  Or_error.try_with (fun () -> Yojson.Safe.from_string r.body)
  |> Or_error.tag_s ~tag:[%message "response is not JSON" (path : string)]
;;

let unit ?idempotent t meth path ?body () =
  let%map result = call ?idempotent t meth path ?body () in
  let open Or_error.Let_syntax in
  let%bind r, request_id = result in
  let%map (_ : Response.t) = check t meth path r request_id in
  ()
;;
