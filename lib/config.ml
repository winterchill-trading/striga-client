open! Core

module Url = struct
  type t = Uri.t

  let sexp_of_t u = Sexp.Atom (Uri.to_string u)
end

type t =
  { base_url : Url.t
  ; api_key : Secret.t
  ; api_secret : Secret.t
  ; application_id : string option
  ; ui_secret : Secret.t option
  ; live : bool
  }
[@@deriving sexp_of]

let sandbox_base_url = Uri.of_string "https://www.sandbox.striga.com/api/v1"

let is_sandbox_host host =
  match String.lowercase host with
  | "www.sandbox.striga.com" | "sandbox.striga.com" -> true
  | _ -> false
;;

let create
  ?(base_url = sandbox_base_url)
  ?application_id
  ?ui_secret
  ?(live = false)
  ~api_key
  ~api_secret
  ()
  =
  let api_key = String.strip api_key
  and api_secret = String.strip api_secret in
  let host = Uri.host base_url in
  if String.is_empty api_key
  then Or_error.error_string "STRIGA_API_KEY is empty"
  else if String.is_empty api_secret
  then Or_error.error_string "STRIGA_API_SECRET is empty"
  else (
    match Uri.scheme base_url, host with
    | Some "https", Some host when live || is_sandbox_host host ->
      Ok
        { base_url
        ; api_key = Secret.of_string api_key
        ; api_secret = Secret.of_string api_secret
        ; application_id
        ; ui_secret = Option.map ui_secret ~f:Secret.of_string
        ; live
        }
    | Some "https", Some host ->
      (* Sandbox and production share request formats; only the host tells them apart, so
         anything but the sandbox host needs an explicit opt-in. *)
      Or_error.error_s
        [%message
          "base URL is not the Striga sandbox; pass ~live:true to use it" (host : string)]
    | _ -> Or_error.error_string "STRIGA_BASE_URL must be an https URL")
;;

let non_empty getenv name =
  match getenv name with
  | Some v when not (String.is_empty (String.strip v)) -> Some (String.strip v)
  | _ -> None
;;

let env_available ?(getenv = Sys.getenv) () =
  Option.is_some (non_empty getenv "STRIGA_API_KEY")
  && Option.is_some (non_empty getenv "STRIGA_API_SECRET")
;;

let of_env ?(getenv = Sys.getenv) ?live () =
  let open Or_error.Let_syntax in
  let required name =
    match non_empty getenv name with
    | Some v -> Ok v
    | None ->
      Or_error.error_s [%message "environment variable is not set" (name : string)]
  in
  let%bind api_key = required "STRIGA_API_KEY" in
  let%bind api_secret = required "STRIGA_API_SECRET" in
  let base_url = Option.map (non_empty getenv "STRIGA_BASE_URL") ~f:Uri.of_string in
  create
    ?base_url
    ?application_id:(non_empty getenv "STRIGA_APPLICATION_ID")
    ?ui_secret:(non_empty getenv "STRIGA_UI_SECRET")
    ?live
    ~api_key
    ~api_secret
    ()
;;

let secrets t = [ t.api_key; t.api_secret ] @ Option.to_list t.ui_secret
