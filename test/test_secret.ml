open! Core
open Striga_client

let%expect_test "a secret never prints" =
  let s = Secret.of_string "not-a-real-secret" in
  print_s [%sexp (s : Secret.t)];
  print_endline (Secret.redact s "header HMAC with not-a-real-secret inside");
  [%expect
    {|
    <redacted>
    header HMAC with <redacted> inside
    |}]
;;
