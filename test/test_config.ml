open! Core
open Striga_client

let env pairs name = List.Assoc.find pairs name ~equal:String.equal

let show r =
  match r with
  | Ok (c : Config.t) -> print_s [%sexp (c : Config.t)]
  | Error e -> print_s [%sexp (e : Error.t)]
;;

let creds = [ "STRIGA_API_KEY", "k"; "STRIGA_API_SECRET", "s" ]

let%expect_test "defaults to the sandbox and hides secrets" =
  show (Config.of_env ~getenv:(env (("STRIGA_UI_SECRET", "u") :: creds)) ());
  [%expect
    {|
    ((base_url https://www.sandbox.striga.com/api/v1) (api_key <redacted>)
     (api_secret <redacted>) (application_id ()) (ui_secret (<redacted>))
     (live false))
    |}]
;;

let%expect_test "refuses a non-sandbox host unless live" =
  let getenv = env (("STRIGA_BASE_URL", "https://api.striga.com/api/v1") :: creds) in
  show (Config.of_env ~getenv ());
  show (Config.of_env ~getenv ~live:true ());
  show (Config.of_env ~getenv:(env (("STRIGA_BASE_URL", "http://x/api/v1") :: creds)) ());
  [%expect
    {|
    ("base URL is not the Striga sandbox; pass ~live:true to use it"
     (host api.striga.com))
    ((base_url https://api.striga.com/api/v1) (api_key <redacted>)
     (api_secret <redacted>) (application_id ()) (ui_secret ()) (live true))
    "STRIGA_BASE_URL must be an https URL"
    |}]
;;

let%expect_test "missing credentials" =
  show (Config.of_env ~getenv:(env [ "STRIGA_API_KEY", "k" ]) ());
  print_s [%sexp (Config.env_available ~getenv:(env [ "STRIGA_API_KEY", " " ]) () : bool)];
  print_s [%sexp (Config.env_available ~getenv:(env creds) () : bool)];
  [%expect
    {|
    ("environment variable is not set" (name STRIGA_API_SECRET))
    false
    true
    |}]
;;

let%expect_test "the application id is not printed either" =
  show (Config.of_env ~getenv:(env (("STRIGA_APPLICATION_ID", "app-123") :: creds)) ());
  [%expect
    {|
    ((base_url https://www.sandbox.striga.com/api/v1) (api_key <redacted>)
     (api_secret <redacted>) (application_id (<set>)) (ui_secret ())
     (live false))
    |}]
;;
