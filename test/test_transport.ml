open! Core
open! Async
module T = Striga_client.Transport

let config () =
  ok_exn
    (Striga_client.Config.create ~api_key:"key-NOT-REAL" ~api_secret:"secret-NOT-REAL" ())
;;

(* A scripted server: answers in order, records what it was asked. *)
let fake responses =
  let queue = Queue.of_list responses in
  let seen = Queue.create () in
  let send ~meth uri ~headers ~body =
    Queue.enqueue seen (meth, uri, headers, body);
    return
      (match Queue.dequeue queue with
       | Some (`Status (status, headers, body)) -> Ok { T.Response.status; headers; body }
       | Some `Fail -> Or_error.error_string "connection reset by key-NOT-REAL"
       | None -> Or_error.error_string "no scripted response")
  in
  send, seen
;;

let transport responses =
  let send, seen = fake responses in
  let sleeps = Queue.create () in
  let events = Queue.create () in
  let t =
    T.create
      ~send
      ~sleep:(fun span ->
        Queue.enqueue sleeps span;
        return ())
      ~now:(fun () -> Time_ns.of_int_ns_since_epoch 1_700_000_000_000_000_000)
      ~on_event:(Queue.enqueue events)
      (config ())
  in
  t, seen, sleeps, events
;;

let status ?(headers = []) s body = `Status (s, headers, body)

let%expect_test "signed headers, signed path and bodies" =
  let t, seen, _, _ = transport [ status 200 "pong"; status 200 {|{"a":1}|} ] in
  let%bind r = T.call t `POST "/ping" () in
  ignore (r : _ Or_error.t);
  let%bind r = T.json t `GET "/user/00000000-0000-0000-0000-000000000000" () in
  ignore (r : _ Or_error.t);
  Queue.iter seen ~f:(fun (meth, uri, headers, body) ->
    let headers =
      List.map headers ~f:(fun (k, v) ->
        k, if String.equal k "x-request-id" then "<id>" else v)
    in
    print_s
      [%message
        ""
          ~meth:(T.Meth.to_string meth)
          ~uri:(Uri.to_string uri)
          (headers : (string * string) list)
          (body : string option)]);
  [%expect
    {|
    ((meth POST) (uri https://www.sandbox.striga.com/api/v1/ping)
     (headers
      ((api-key key-NOT-REAL)
       (authorization
        "HMAC 1700000000000:ad927d6d541937b8d331c4a26ee06a8c6ead250e186bea14d0ce8716ddaf1867")
       (content-type application/json) (accept application/json)
       (x-request-id <id>)))
     (body ({})))
    ((meth GET)
     (uri
      https://www.sandbox.striga.com/api/v1/user/00000000-0000-0000-0000-000000000000)
     (headers
      ((api-key key-NOT-REAL)
       (authorization
        "HMAC 1700000000000:5d488f04397d61a4b498adaf79fd3fcf4b019e1b4963fb70aec7d150c7831130")
       (content-type application/json) (accept application/json)
       (x-request-id <id>)))
     (body ()))
    |}];
  return ()
;;

let%expect_test "idempotent requests retry 429, 5xx and failures; Retry-After wins" =
  let t, seen, sleeps, events =
    transport
      [ status 429 ~headers:[ "retry-after", "1" ] ""
      ; `Fail
      ; status 503 "busy"
      ; status 200 {|{"a":1}|}
      ]
  in
  let%bind r = T.json ~idempotent:true t `POST "/wallets/get" () in
  print_s [%sexp (Or_error.map r ~f:Yojson.Safe.to_string : string Or_error.t)];
  print_s
    [%message (Queue.length seen : int) (Queue.to_list sleeps : Time_ns.Span.t list)];
  Queue.iter events ~f:(fun (e : T.Event.t) ->
    print_s
      [%message
        ""
          ~attempt:(e.attempt : int)
          ~outcome:(e.outcome : [ `Status of int | `Failed of string ])]);
  [%expect
    {|
    (Ok "{\"a\":1}")
    (("Queue.length seen" 4) ("Queue.to_list sleeps" (1s 500ms 1s)))
    ((attempt 1) (outcome (Status 429)))
    ((attempt 2) (outcome (Failed "connection reset by <redacted>")))
    ((attempt 3) (outcome (Status 503)))
    ((attempt 4) (outcome (Status 200)))
    |}];
  return ()
;;

let%expect_test "money movement is not retried" =
  let t, seen, _, _ = transport [ status 503 ""; status 200 "{}" ] in
  let%bind r = T.json t `POST "/wallets/send/intra/initiate" ~body:(`Assoc []) () in
  print_s [%message (Result.is_ok r : bool) (Queue.length seen : int)];
  let t, seen, _, _ = transport [ `Fail; status 200 "{}" ] in
  let%bind r = T.json t `POST "/wallets/send/intra/initiate" ~body:(`Assoc []) () in
  print_s [%message (Result.is_ok r : bool) (Queue.length seen : int)];
  (* The message names the request id, which is random; show the rest. *)
  (match r with
   | Ok _ -> ()
   | Error e ->
     let s = Error.to_string_hum e in
     print_s
       [%message
         ""
           ~names_request:(String.is_substring s ~substring:"request_id" : bool)
           ~redacted:(not (String.is_substring s ~substring:"key-NOT-REAL") : bool)]);
  [%expect
    {|
    (("Result.is_ok r" false) ("Queue.length seen" 1))
    (("Result.is_ok r" false) ("Queue.length seen" 1))
    ((names_request true) (redacted true))
    |}];
  return ()
;;

let%expect_test "errors carry status, code and redacted details" =
  let t, _, _, _ =
    transport
      [ status
          409
          {|{"status":409,"errorCode":"30007","errorDetails":{"message":"User is not verified for key-NOT-REAL"}}|}
      ]
  in
  let%bind r = T.unit t `POST "/card/create" ~body:(`Assoc []) () in
  (match r with
   | Ok () -> print_endline "ok"
   | Error e ->
     print_s
       [%message
         ""
           ~status:(Striga_client.Api_error.status_of_error e : int option)
           ~code:(Striga_client.Api_error.code_of_error e : string option)];
     print_endline
       (String.substr_replace_all
          (Error.to_string_hum e)
          ~pattern:(String.concat [ "\n" ])
          ~with_:" "
        |> fun s ->
        if String.is_substring s ~substring:"key-NOT-REAL" then "LEAKED" else "redacted"));
  [%expect {|
    ((status (409)) (code (30007)))
    redacted
    |}];
  return ()
;;

let%expect_test "OK and Accepted bodies are fine for unit endpoints" =
  let t, _, _, _ = transport [ status 202 "Accepted"; status 200 "OK" ] in
  let%bind a = T.unit t `POST "/user/verify-email" () in
  let%bind b = T.unit t `PATCH "/simulate/user/kyc" () in
  print_s [%message (a : unit Or_error.t) (b : unit Or_error.t)];
  [%expect {| ((a (Ok ())) (b (Ok ()))) |}];
  return ()
;;

let%expect_test "paths cannot leave the API host" =
  let t, _, _, _ = transport [] in
  List.iter [ "user/create"; "//evil.example/x"; "/x?y=https://evil" ] ~f:(fun p ->
    print_s [%sexp (T.url t p |> Or_error.map ~f:Uri.to_string : string Or_error.t)]);
  print_s [%sexp (T.backoff ~attempt:9 ~retry_after:None : Time_ns.Span.t)];
  [%expect
    {|
    (Error ("API path must start with /" (path user/create)))
    (Error ("API path must not name a host" (path //evil.example/x)))
    (Error ("API path must not name a host" (path /x?y=https://evil)))
    8s
    |}];
  return ()
;;
