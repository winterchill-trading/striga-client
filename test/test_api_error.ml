open! Core
open Striga_client

let parse ~status body =
  Api_error.of_response
    ~meth:"POST"
    ~path:"/x"
    ~request_id:"req-1"
    ~redact:(Redact.text ~secrets:[ Secret.of_string "sekret" ])
    ~status
    ~body
;;

let show t = print_s [%sexp (t : Api_error.t)]

(* Bodies as the sandbox sent them (2026-10-13). *)
let%expect_test "error body shapes" =
  show
    (parse
       ~status:400
       {|{"message":"Invalid fields --> Invalid startDate","errorCode":"00002","errorDetails":[{"msg":"Invalid startDate","param":"startDate","location":"body"}]}|});
  show
    (parse
       ~status:409
       {|{"status":409,"errorCode":"30007","errorDetails":{"message":"User is not verified"}}|});
  show
    (parse
       ~status:400
       {|{"message":"Only EUR deposits can be simulated","errorCode":"31123","errorDetails":"Only EUR deposits can be simulated"}|});
  show (parse ~status:404 "<pre>Cannot GET /ping sekret</pre>");
  [%expect
    {|
    ((meth POST) (path /x) (status 400) (request_id req-1) (error_code (00002))
     (message ("Invalid fields --> Invalid startDate"))
     (details
      ("[{\"msg\":\"Invalid startDate\",\"param\":\"startDate\",\"location\":\"body\"}]"))
     (body ()))
    ((meth POST) (path /x) (status 409) (request_id req-1) (error_code (30007))
     (message ("User is not verified"))
     (details ("{\"message\":\"User is not verified\"}")) (body ()))
    ((meth POST) (path /x) (status 400) (request_id req-1) (error_code (31123))
     (message ("Only EUR deposits can be simulated"))
     (details ("\"Only EUR deposits can be simulated\"")) (body ()))
    ((meth POST) (path /x) (status 404) (request_id req-1) (error_code ())
     (message ()) (details ()) (body ("<pre>Cannot GET /ping <redacted></pre>")))
    |}]
;;

let%expect_test "status and code survive tagging" =
  let e =
    Api_error.to_error (parse ~status:409 {|{"errorCode":"30007","message":"m"}|})
    |> Error.tag ~tag:"creating card"
  in
  print_s
    [%message
      ""
        ~status:(Api_error.status_of_error e : int option)
        ~code:(Api_error.code_of_error e : string option)];
  print_s
    [%message "" ~status:(Api_error.status_of_error (Error.of_string "x") : int option)];
  [%expect {|
    ((status (409)) (code (30007)))
    (status ())
    |}]
;;

let%expect_test "SCA session required (sandbox body)" =
  let e =
    Api_error.of_response
      ~meth:"POST"
      ~path:"/wallets/get/account"
      ~request_id:"r1"
      ~redact:Fn.id
      ~status:403
      ~body:
        {|{"message":"SCA_REQUIRED","errorCode":"30070","errorDetails":{"reason":"NO_SESSION"}}|}
    |> Api_error.to_error
  in
  print_s [%sexp (Api_error.is_sca_session_required e : bool)];
  print_s [%sexp (Api_error.is_sca_session_required (Error.tag e ~tag:"x") : bool)];
  [%expect {|
    true
    true
    |}]
;;
