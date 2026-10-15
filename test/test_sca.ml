open! Core
open Striga_client

let%expect_test "2FA reset bodies (sandbox, ids replaced)" =
  let i =
    Fixture.roundtrip
      "reset-2fa-initiate.json"
      Sca.Reset_2fa.Initiated.t_of_yojson
      Sca.Reset_2fa.Initiated.yojson_of_t
      Sca.Reset_2fa.Initiated.equal
  in
  print_s [%sexp (i : Sca.Reset_2fa.Initiated.t)];
  List.iter [ "reset-2fa-liveness.json"; "reset-2fa-status.json" ] ~f:(fun f ->
    let s =
      Fixture.roundtrip
        f
        Sca.Reset_2fa.Status.t_of_yojson
        Sca.Reset_2fa.Status.yojson_of_t
        Sca.Reset_2fa.Status.equal
    in
    print_s [%sexp (s : Sca.Reset_2fa.Status.t)]);
  let c =
    Fixture.roundtrip
      "reset-2fa-complete-sms.json"
      Sca.Reset_2fa.Completed.t_of_yojson
      Sca.Reset_2fa.Completed.yojson_of_t
      Sca.Reset_2fa.Completed.equal
  in
  print_s [%sexp (c : Sca.Reset_2fa.Completed.t)];
  [%expect
    {|
    ((reset_id 00000000-0000-4000-8000-0000000000a1)
     (sumsub_access_token (<hidden>)) (verification_link (<hidden>))
     (expires_at (2026-10-15T05:40:51.407Z)))
    ((reset_id (00000000-0000-4000-8000-0000000000a1)) (factor ())
     (status (LIVENESS_PASSED)) (enrollment_status ()) (expires_at ())
     (completed_at ()))
    ((reset_id (00000000-0000-4000-8000-0000000000a1)) (factor (Sms))
     (status (COMPLETED)) (enrollment_status ())
     (expires_at (2026-10-15T05:40:51.407Z))
     (completed_at (2026-10-15T05:10:59.062Z)))
    ((factor (Sms)) (ok (true)) (secret ()) (secret_base32_encoded ())
     (totp_uri ()) (options ()) (allowed_origins ()) (relying_party_id ()))
    |}]
;;
