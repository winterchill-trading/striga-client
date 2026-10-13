open! Core

type t =
  { meth : string
  ; path : string
  ; status : int
  ; request_id : string
  ; error_code : string option
  ; message : string option
  ; details : string option
  ; body : string option
  }
[@@deriving sexp_of]

let string_member name (json : Yojson.Safe.t) =
  match json with
  | `Assoc fields ->
    (match List.Assoc.find fields name ~equal:String.equal with
     | Some (`String s) -> Some s
     | Some (`Int i) -> Some (Int.to_string i)
     | _ -> None)
  | _ -> None
;;

let member name (json : Yojson.Safe.t) =
  match json with
  | `Assoc fields -> List.Assoc.find fields name ~equal:String.equal
  | _ -> None
;;

let of_response ~meth ~path ~request_id ~redact ~status ~body =
  let base =
    { meth
    ; path
    ; status
    ; request_id
    ; error_code = None
    ; message = None
    ; details = None
    ; body = None
    }
  in
  match Yojson.Safe.from_string body with
  | exception _ ->
    let body = redact (String.strip body) in
    let body = if String.length body > 1024 then String.prefix body 1024 ^ "..." else body in
    { base with body = (if String.is_empty body then None else Some body) }
  | json ->
    let details = member "errorDetails" json in
    let message =
      match string_member "message" json with
      | Some m -> Some m
      | None -> Option.bind details ~f:(string_member "message")
    in
    let details =
      match details with
      | None | Some `Null -> None
      | Some d -> Some (redact (Yojson.Safe.to_string d))
    in
    { base with
      error_code = string_member "errorCode" json
    ; message = Option.map message ~f:redact
    ; details
    }
;;

(* The error carries the record as a tagged sexp so status and code survive
   [Or_error.tag]; see [status_of_error]. *)
let tag = "striga api error"
let to_error t = Error.create_s [%sexp (tag : string), (t : t)]

let rec find_field sexp name =
  match (sexp : Sexp.t) with
  | List [ Atom n; v ] when String.equal n name -> Some v
  | List l -> List.find_map l ~f:(fun s -> find_field s name)
  | Atom _ -> None
;;

let rec find_tagged (sexp : Sexp.t) =
  match sexp with
  | List [ Atom s; v ] when String.equal s tag -> Some v
  | List l -> List.find_map l ~f:find_tagged
  | Atom _ -> None
;;

let status_of_error e =
  match Option.bind (find_tagged (Error.sexp_of_t e)) ~f:(fun v -> find_field v "status") with
  | Some (Atom s) -> Int.of_string_opt s
  | _ -> None
;;

let code_of_error e =
  match
    Option.bind (find_tagged (Error.sexp_of_t e)) ~f:(fun v -> find_field v "error_code")
  with
  | Some (List [ Atom c ]) -> Some c
  | _ -> None
;;
