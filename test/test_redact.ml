open! Core
open Striga_client

let%expect_test "IBANs and card numbers" =
  print_endline (Redact.iban "GB10SEOU19870010266392");
  print_endline (Redact.iban "not an iban");
  print_endline (Redact.pan "4111111111111111");
  [%expect {|
    GB****************6392
    not an iban
    ************1111
    |}]
;;

let%expect_test "free text" =
  let secrets = [ Secret.of_string "sekret-key" ] in
  print_endline
    (Redact.text
       ~secrets
       "api-key sekret-key, pay to EE351010052031000004 from card 4111111111111111, \
        amount 200000000000000000 wei, masked 474367******2932");
  [%expect
    {| api-key <redacted>, pay to EE**************0004 from card ************1111, amount 200000000000000000 wei, masked 474367******2932 |}]
;;

let%expect_test "JSON fields" =
  let j =
    Yojson.Safe.from_string
      {|{"provider":"SUMSUB","token":"_act-sbx-jwt-abc","bankingDetails":{"iban":"GB10SEOU19870010266392","accountNumber":"010266392","bic":"SEOUGB21"},"recoveryCodes":["a","b"],"memo":"card 4111111111111111"}|}
  in
  print_endline (Yojson.Safe.pretty_to_string (Redact.json j));
  [%expect
    {|
    {
      "provider": "SUMSUB",
      "token": "<redacted>",
      "bankingDetails": {
        "iban": "GB****************6392",
        "accountNumber": "*****6392",
        "bic": "SEOUGB21"
      },
      "recoveryCodes": "<redacted>",
      "memo": "card ************1111"
    }
    |}]
;;

let%test_unit "masking keeps the length and the last 4" =
  Quickcheck.test
    (String.gen_with_length 16 Char.gen_digit)
    ~sexp_of:String.sexp_of_t
    ~f:(fun digits ->
      let masked = Redact.pan digits in
      [%test_result: int] (String.length masked) ~expect:(String.length digits);
      [%test_result: string] (String.suffix masked 4) ~expect:(String.suffix digits 4))
;;
