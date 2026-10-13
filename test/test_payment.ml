open! Core
open Striga_client

let initiated f =
  Fixture.roundtrip
    f
    Payment.Initiated.t_of_yojson
    Payment.Initiated.yojson_of_t
    Payment.Initiated.equal
;;

let%expect_test "initiations (docs examples)" =
  List.iter
    [ "docs-swap-initiated.json"
    ; "docs-sepa-initiated.json"
    ; "docs-onchain-initiated.json"
    ; "docs-intra-initiated.json"
    ; "docs-ln-withdrawal-initiated.json"
    ]
    ~f:(fun f ->
      let i = initiated f in
      let tx = i.transaction in
      print_s
        [%message
          f
            ~type_:(Option.bind tx ~f:(fun t -> t.tx_type) : Transaction.Tx_type.t option)
            ~status:(Option.bind tx ~f:(fun t -> t.status) : string option)
            ~amount:(Option.bind tx ~f:(fun t -> t.amount) : string option)
            ~fee:
              (Option.bind
                 (Option.first_some
                    i.fee_estimate
                    (Option.bind tx ~f:(fun t -> t.fee_estimate)))
                 ~f:(fun f -> f.total_fee)
               : string option)
            ~methods:
              (i.available_verification_methods
               : Common.Verification_method.t list option)]);
  [%expect
    {|
    (docs-swap-initiated.json (type_ (Swap_currency_initiated))
     (status (PENDING_2FA_CONFIRMATION)) (amount (2000)) (fee (0))
     (methods ((Sms))))
    (docs-sepa-initiated.json (type_ (Sepa_payout_initiated))
     (status (PENDING_2FA_CONFIRMATION)) (amount (959606)) (fee (20094))
     (methods ()))
    (docs-onchain-initiated.json (type_ (On_chain_withdrawal_initiated))
     (status (PENDING_2FA_CONFIRMATION)) (amount (1000)) (fee (398))
     (methods ()))
    (docs-intra-initiated.json (type_ (Intra_ledger_send))
     (status (PENDING_2FA_CONFIRMATION)) (amount (20000)) (fee ()) (methods ()))
    (docs-ln-withdrawal-initiated.json (type_ ()) (status ()) (amount ())
     (fee ()) (methods ()))
    |}]
;;

let%expect_test "rates (sandbox)" =
  let r =
    Fixture.roundtrip
      "rates.json"
      Exchange.Rates.t_of_yojson
      Exchange.Rates.yojson_of_t
      Exchange.Rates.equal
  in
  print_s [%sexp (List.map r ~f:fst : string list)];
  (* MATICEUR has no [currency] and a stale timestamp: kept, not rejected. *)
  print_s [%sexp (Exchange.Rates.find r ~ticker:"MATICEUR" : Exchange.Rate.t option)];
  [%expect
    {|
    (ETHEUR MATICEUR USDCEUR BTCEUR BTCUSDC BNBEUR POLEUR SOLEUR)
    (((price (0.21)) (buy (0.22)) (sell (0.19)) (timestamp (1747670876835))
      (h_timestamp (2025-05-19T16:07:56.835Z)) (currency ())))
    |}]
;;

let%expect_test "Lightning deposit invoice (sandbox)" =
  let i =
    Fixture.roundtrip
      "ln-topup.json"
      Payment.Lightning_invoice.t_of_yojson
      Payment.Lightning_invoice.yojson_of_t
      Payment.Lightning_invoice.equal
  in
  print_s [%sexp (i : Payment.Lightning_invoice.t)];
  [%expect
    {|
    ((id (eeee000000000000000000000000000000000000000000000000000000000014))
     (description ("sandbox topup")) (amount (10000))
     (invoice lnbcrt100u1p<redacted>) (expiry (1792015520)) (proposed_rate ())
     (fill_or_kill_at_proposed_rate (false)))
    |}]
;;

let%expect_test "whitelists, validation, resend and fee estimate (docs examples)" =
  let a =
    Fixture.roundtrip
      "docs-whitelisted-addresses.json"
      Payment.Address_page.t_of_yojson
      Payment.Address_page.yojson_of_t
      Payment.Address_page.equal
  in
  List.iter a.addresses ~f:(fun a ->
    print_s
      [%message
        ""
          ~currency:(a.currency : string option)
          ~status:(a.status : string option)
          ~internal:(a.internal : bool option)]);
  let i =
    Fixture.roundtrip
      "docs-whitelisted-ibans.json"
      Payment.Iban_page.t_of_yojson
      Payment.Iban_page.yojson_of_t
      Payment.Iban_page.equal
  in
  print_s [%sexp (List.length i.ibans : int), (i.total : int option)];
  let w =
    Fixture.roundtrip
      "docs-whitelist-iban.json"
      Payment.Whitelisted_iban.t_of_yojson
      Payment.Whitelisted_iban.yojson_of_t
      Payment.Whitelisted_iban.equal
  in
  print_s [%sexp (w.payment_type : string option)];
  let v =
    Fixture.load "docs-validate-sepa.json"
    |> Ppx_yojson_conv_lib.Yojson_conv.list_of_yojson Payment.Sepa_validation.t_of_yojson
  in
  print_s [%sexp (v : Payment.Sepa_validation.t list)];
  let c =
    Fixture.roundtrip
      "docs-resend-otp.json"
      Common.Challenge.t_of_yojson
      Common.Challenge.yojson_of_t
      Common.Challenge.equal
  in
  print_s [%sexp (c.attempts : int option)];
  let f =
    Fixture.roundtrip
      "docs-fee-estimate.json"
      Common.Fee_estimate.t_of_yojson
      Common.Fee_estimate.yojson_of_t
      Common.Fee_estimate.equal
  in
  print_s [%sexp (f : Common.Fee_estimate.t)];
  [%expect
    {|
    ((currency (BTC)) (status (ACTIVATED)) (internal (true)))
    ((currency (USDC_POLYGON)) (status (ACTIVATED)) (internal (false)))
    ((currency (BTC)) (status (ACTIVATED)) (internal (false)))
    (4 (4))
    (SEPA_INSTANT)
    (((payment_type (SEPA_INSTANT)) (valid (true)) (messages ({})))
     ((payment_type (SEPA)) (valid (true)) (messages ({}))))
    (1)
    ((total_fee (398)) (network_fee (1662779116152000)) (our_fee (279))
     (their_fee (119)) (fee_currency (USDT)) (gas_limit (84000))
     (gas_price (15.014)))
    |}]
;;

let%expect_test "EUR walk in the sandbox: swap to USDC and SEPA payout, each with OTP" =
  List.iter [ "swap-init.json"; "sepa-init.json" ] ~f:(fun f ->
    let i = initiated f in
    print_s
      [%message
        f
          ~type_:
            (Option.bind i.transaction ~f:(fun t -> t.tx_type)
             : Transaction.Tx_type.t option)
          ~method_:(i.verification_method : Common.Verification_method.t option)
          ~methods:
            (i.available_verification_methods : Common.Verification_method.t list option)]);
  List.iter [ "swap-confirm.json"; "sepa-confirm.json" ] ~f:(fun f ->
    let tx =
      Fixture.roundtrip
        f
        Transaction.t_of_yojson
        Transaction.yojson_of_t
        Transaction.equal
    in
    print_s
      [%message
        f
          ~type_:(tx.tx_type : Transaction.Tx_type.t option)
          ~status:(tx.status : string option)
          ~before:(Option.bind tx.balance_before ~f:(fun b -> b.amount) : string option)
          ~after:(Option.bind tx.balance_after ~f:(fun b -> b.amount) : string option)
          ~order:(tx.order : Wire.Raw_json.t option)]);
  [%expect
    {|
    (swap-init.json (type_ (Swap_currency_initiated)) (method_ (Sms))
     (methods ((Sms))))
    (sepa-init.json (type_ (Sepa_payout_initiated)) (method_ (Sms))
     (methods ((Sms))))
    (swap-confirm.json (type_ (Currency_exchange)) (status (COMMITTED))
     (before (10000)) (after (8000))
     (order
      ("{\"id\":\"00000000-0000-4000-8000-000000000069\",\"price\":\"0.91\",\"type\":\"buy\",\"ticker\":\"USDCEUR\",\"debit\":{\"currency\":\"EUR\",\"amountFloat\":\"20\",\"amount\":\"2000\"},\"credit\":{\"currency\":\"USDC\",\"amountFloat\":\"21.97\",\"amount\":\"2197\"}}")))
    (sepa-confirm.json (type_ (Sepa_payout_initiated)) (status ())
     (before (8000)) (after (7000)) (order ()))
    |}]
;;
