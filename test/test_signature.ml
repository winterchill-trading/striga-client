open! Core
open Striga_client

(* Vectors computed with the docs' Node.js sample ("Putting it all together" on the
   authentication page) with the time fixed at 1700000000000 and a fake secret. *)
let secret = Secret.of_string "not-a-real-secret"

let%expect_test "matches the docs' JS sample" =
  print_endline
    (Signature.authorization
       ~secret
       ~time_ms:"1700000000000"
       ~meth:"POST"
       ~path:"/ping"
       ~body:(Some {|{"dummy":1,"data":2}|}));
  print_endline
    (Signature.authorization
       ~secret
       ~time_ms:"1700000000000"
       ~meth:"GET"
       ~path:"/user/00000000-0000-0000-0000-000000000000"
       ~body:None);
  [%expect
    {|
    HMAC 1700000000000:984567f2c60aaf672180a1c858d26089651c9f43d2d18a9a8c39ac78bb6f0874
    HMAC 1700000000000:bdf674462432b9e06254bba4fa1177c8dd757d52e288befe4657aacb77a8cd01
    |}]
;;

let%expect_test "GET bodies sign as {}" =
  print_endline (Signature.body_digest None);
  print_endline
    (Signature.signing_input ~time_ms:"1" ~meth:"GET" ~path:"/ping" ~body:None);
  [%expect
    {|
    99914b932bd37a50b983c5e7c90ae93b
    1GET/ping99914b932bd37a50b983c5e7c90ae93b
    |}]
;;

let%expect_test "webhook signatures" =
  let api_key = Secret.of_string "not-a-real-api-key" in
  let body = {|{"userId":"u1","status":"APPROVED","ts":1700000000000}|} in
  (* From crypto.createHmac('sha256', apiKey).update(JSON.stringify(payload)). *)
  let expected = "03267cf575eafcad3f27c9897d63cef0f51df7c68389dae2c1e6e52ea1abbc11" in
  print_endline (Signature.webhook_signature ~api_key body);
  let check ~body ~signature =
    print_s [%sexp (Signature.verify_webhook ~api_key ~body ~signature : bool)]
  in
  check ~body ~signature:expected;
  check ~body ~signature:(String.uppercase expected);
  (* Pretty-printed by a proxy: still verifies through the compact form. *)
  check ~body:{|{ "userId": "u1", "status": "APPROVED", "ts": 1700000000000 }|} ~signature:expected;
  check ~body:{|{"userId":"u2","status":"APPROVED","ts":1700000000000}|} ~signature:expected;
  check ~body ~signature:"00";
  check ~body:"not json" ~signature:expected;
  [%expect
    {|
    03267cf575eafcad3f27c9897d63cef0f51df7c68389dae2c1e6e52ea1abbc11
    true
    true
    true
    false
    false
    false
    |}]
;;
