open! Core
open Striga_client

let%expect_test "numbers and strings both decode as text" =
  List.iter [ {|"10000"|}; "495"; "200000000000000000000"; "12.34"; "5e-08" ] ~f:(fun s ->
    let v = Wire.Num_string.t_of_yojson (Yojson.Safe.from_string s) in
    print_endline (Yojson.Safe.to_string (Wire.Num_string.yojson_of_t v)));
  [%expect
    {|
    "10000"
    "495"
    "200000000000000000000"
    "12.34"
    "5e-08"
    |}]
;;

let%expect_test "enums keep unknown values" =
  let m = Common.Verification_method.t_of_yojson (`String "biometric") in
  print_s [%sexp (m : Common.Verification_method.t)];
  print_endline (Yojson.Safe.to_string (Common.Verification_method.yojson_of_t m));
  print_endline (Common.Verification_method.to_string Totp);
  [%expect {|
    (Other biometric)
    "biometric"
    totp
    |}]
;;

let%expect_test "obj drops absent fields" =
  print_endline
    (Yojson.Safe.to_string (Wire.obj [ "a", Some (`Int 1); "b", None; "c", Some `Null ]));
  [%expect {| {"a":1,"c":null} |}]
;;
