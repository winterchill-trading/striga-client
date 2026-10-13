open! Core
open Striga_client

(* RFC 6238 appendix B, SHA-1 rows (key "12345678901234567890"), 8 digits. The last RFC
   row (T = 20000000000 s, year 2603) is past what [Time_ns] can hold, so it is left out. *)
let%expect_test "RFC 6238 vectors" =
  let key = "12345678901234567890" in
  List.iter [ 59; 1111111109; 1111111111; 1234567890; 2000000000 ] ~f:(fun s ->
    print_endline (Totp.code ~digits:8 ~key (Time_ns.of_int_ns_since_epoch (s * 1_000_000_000))));
  [%expect
    {|
    94287082
    07081804
    14050471
    89005924
    69279037
    |}]
;;

let%expect_test "base32 secrets" =
  (* "12345678901234567890" in base32, as an authenticator app would get it. *)
  let b32 = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ" in
  print_s [%sexp (Totp.base32_decode b32 : string Or_error.t)];
  print_s
    [%sexp
      (Totp.code_of_base32 (String.lowercase b32) (Time_ns.of_int_ns_since_epoch 59_000_000_000)
       : string Or_error.t)];
  print_s [%sexp (Totp.base32_decode "AB1" : string Or_error.t)];
  [%expect
    {|
    (Ok 12345678901234567890)
    (Ok 287082)
    (Error ("not base32" (char 1)))
    |}]
;;
