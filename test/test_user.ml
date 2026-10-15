open! Core
open Striga_client

let%expect_test "created user" =
  let u =
    Fixture.roundtrip "user-create.json" User.t_of_yojson User.yojson_of_t User.equal
  in
  print_s [%sexp (u : User.t)];
  [%expect
    {|
    ((user_id 00000000-0000-4000-8000-000000000001) (first_name ())
     (last_name ()) (user_handle ())
     (email (hello+striga-1791929027@winterchill.xyz))
     (mobile (((country_code +372) (number 59892958)))) (date_of_birth ())
     (address ())
     (kyc
      (((user_id ()) (email_verified (false)) (mobile_verified (false))
        (status (Not_started)) (current_tier ()) (details ())
        (rejection_comments ()) (rejection_final ()) (tier0 ()) (tier1 ())
        (tier2 ()) (tier3 ()) (ts ()))))
     (created_at ()) (missing_fields ())
     (email_verification (((date_expires (2026-10-13T22:08:47.923Z)))))
     (mobile_verification (((date_expires (2026-10-13T22:08:47.923Z)))))
     (multi_factor_auth ()))
    |}]
;;

let%expect_test "user after verification" =
  let u =
    Fixture.roundtrip "user-get.json" User.t_of_yojson User.yojson_of_t User.equal
  in
  print_s [%sexp (u.kyc : User.Kyc.t option)];
  print_s [%sexp (u.date_of_birth : Common.Date_of_birth.t option)];
  [%expect
    {|
    (((user_id ()) (email_verified (true)) (mobile_verified (true))
      (status (Not_started)) (current_tier (0)) (details ())
      (rejection_comments (((user_comment ()) (auto_comment ()))))
      (rejection_final ())
      (tier0
       (((eligible (true)) (status (Not_started)) (inbound_limit_consumed ())
         (inbound_limit_allowed ()) (outbound_limit_consumed (0))
         (outbound_limit_allowed (1500000)) (verification_expiry_date ()))))
      (tier1
       (((eligible (true)) (status (Not_started))
         (inbound_limit_consumed (((all (0)) (va (0)))))
         (inbound_limit_allowed (((all (2500000)) (va (1500000)))))
         (outbound_limit_consumed (0)) (outbound_limit_allowed (1000000))
         (verification_expiry_date ()))))
      (tier2
       (((eligible (false)) (status (Not_started)) (inbound_limit_consumed ())
         (inbound_limit_allowed ()) (outbound_limit_consumed (0))
         (outbound_limit_allowed (10000000)) (verification_expiry_date ()))))
      (tier3
       (((eligible (false)) (status (Not_started)) (inbound_limit_consumed ())
         (inbound_limit_allowed ()) (outbound_limit_consumed (0))
         (outbound_limit_allowed (10000000)) (verification_expiry_date ()))))
      (ts ())))
    (((year 1990) (month 1) (day 15)))
    |}]
;;

let%expect_test "KYC status after the simulated approval" =
  let k =
    Fixture.roundtrip
      "kyc-status.json"
      User.Kyc.t_of_yojson
      User.Kyc.yojson_of_t
      User.Kyc.equal
  in
  print_s
    [%message
      ""
        ~status:(k.status : User.Kyc_status.t option)
        ~tier:(k.current_tier : int option)
        ~tier1:(Option.bind k.tier1 ~f:(fun t -> t.status) : User.Kyc_status.t option)];
  [%expect {| ((status (Approved)) (tier (1)) (tier1 (Approved))) |}]
;;

let%expect_test "KYC start hides the SDK token in sexps" =
  let s =
    Fixture.roundtrip
      "kyc-start.json"
      User.Kyc_start.t_of_yojson
      User.Kyc_start.yojson_of_t
      User.Kyc_start.equal
  in
  print_s [%sexp (s : User.Kyc_start.t)];
  [%expect
    {|
    ((provider (SUMSUB)) (token <hidden>)
     (user_id (00000000-0000-4000-8000-000000000001))
     (verification_link (<hidden>)))
    |}]
;;

let%expect_test "a real token never prints" =
  let s =
    User.Kyc_start.t_of_yojson
      (Yojson.Safe.from_string
         {|{"token":"_act-sbx-jwt-abc","verificationLink":"https://x"}|})
  in
  print_s [%sexp (s : User.Kyc_start.t)];
  [%expect
    {| ((provider ()) (token <hidden>) (user_id ()) (verification_link (<hidden>))) |}]
;;

let%expect_test "unknown KYC status values survive" =
  let k = User.Kyc.t_of_yojson (Yojson.Safe.from_string {|{"status":"FROZEN","x":1}|}) in
  print_s [%sexp (k.status : User.Kyc_status.t option)];
  [%expect {| ((Other FROZEN)) |}]
;;

let%expect_test "Payment Account consent, recorded and never recorded (sandbox)" =
  List.iter [ "consent-set.json"; "consent-none.json" ] ~f:(fun f ->
    let r =
      Fixture.roundtrip
        f
        User.Payment_account_consent.Record.t_of_yojson
        User.Payment_account_consent.Record.yojson_of_t
        User.Payment_account_consent.Record.equal
    in
    print_s [%sexp (r.payment_account_consent : User.Payment_account_consent.t option)]);
  [%expect
    {|
    (((accepted true) (date_accepted (2026-10-15T05:06:31.097Z))
      (ip (185.46.212.10)) (terms_uri (https://example.com/terms))
      (terms_version (2026-08-v1))))
    ()
    |}]
;;
