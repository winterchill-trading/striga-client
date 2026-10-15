open! Core
open Striga_client

let%expect_test "default wallet after KYC approval (sandbox app with crypto only)" =
  let p =
    Fixture.roundtrip
      "wallets-all.json"
      Wallet.Page.t_of_yojson
      Wallet.Page.yojson_of_t
      Wallet.Page.equal
  in
  List.iter p.wallets ~f:(fun w ->
    print_s
      [%message
        ""
          ~wallet:(w.wallet_id : string)
          ~comment:(w.comment : string option)
          ~currencies:(List.map w.accounts ~f:fst : string list)]);
  let btc = Option.value_exn (Wallet.account (List.hd_exn p.wallets) ~currency:"BTC") in
  print_s [%sexp (btc.available_balance : Common.Balance.t option)];
  [%expect
    {|
    ((wallet 00000000-0000-4000-8000-000000000002) (comment (DEFAULT))
     (currencies (BTC BNB ETH POL SOL)))
    (((amount (0)) (balance ()) (currency (satoshis)) (h_amount (0.00000000))
      (fiat_equivalent_balance (0)) (fiat_currency (EUR))
      (h_fiat_equivalent_balance (0)) (rate (74462.5))))
    |}]
;;

let%expect_test "created wallet" =
  let w =
    Fixture.roundtrip
      "wallet-create.json"
      Wallet.t_of_yojson
      Wallet.yojson_of_t
      Wallet.equal
  in
  print_s [%sexp (List.length w.accounts : int)];
  [%expect {| 5 |}]
;;

let%expect_test "enriched crypto accounts" =
  List.iter [ "enrich-btc.json"; "enrich-eth.json" ] ~f:(fun f ->
    let e =
      Fixture.roundtrip
        f
        Wallet.Enrichment.t_of_yojson
        Wallet.Enrichment.yojson_of_t
        Wallet.Enrichment.equal
    in
    print_s
      [%message
        ""
          ~currency:(e.currency : string option)
          ~address:(e.blockchain_deposit_address : string option)
          ~network:(Option.map e.blockchain_network ~f:(fun n -> n.name) : string option)]);
  let a =
    Fixture.roundtrip
      "account-get.json"
      Wallet.Account.t_of_yojson
      Wallet.Account.yojson_of_t
      Wallet.Account.equal
  in
  print_s
    [%message
      "" ~enriched:(a.enriched : bool option) ~card:(a.linked_card_id : string option)];
  [%expect
    {|
    ((currency (BTC)) (address (tb1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq))
     (network ("Bitcoin Testnet 3")))
    ((currency (ETH)) (address (0x0000000000000000000000000000000000000030))
     (network ("Ethereum Test (Sepolia)")))
    ((enriched (true)) (card (UNLINKED)))
    |}]
;;

let%expect_test "EUR account with banking details (docs example)" =
  let a =
    Fixture.roundtrip
      "docs-account-eur.json"
      Wallet.Account.t_of_yojson
      Wallet.Account.yojson_of_t
      Wallet.Account.equal
  in
  print_s [%sexp (a.banking_details : Wallet.Banking_details.t option)];
  [%expect
    {|
    (((currency (EUR)) (status (ACTIVE))
      (internal_account_id (EUR00000000007233)) (bank_country (GB))
      (bank_address ("The Bower, 207-211 Old Street, London, England, EC1V 9NR"))
      (iban (GB10000000000000006392)) (bic (SEOUGB21))
      (account_number (000006392)) (bank_name ("Simulator Bank"))
      (bank_account_holder_name ("ADA SANDBOX")) (provider (SIMULATOR))
      (payment_type ()) (domestic (false)) (pay_in_reference ())
      (routing_code_entries (())) (bban ()) (bank_postal_code ())))
    |}]
;;

let%expect_test "statements (docs examples)" =
  List.iter [ "docs-statement.json"; "docs-transactions-ln.json" ] ~f:(fun f ->
    let p =
      Fixture.roundtrip
        f
        Transaction.Page.t_of_yojson
        Transaction.Page.yojson_of_t
        Transaction.Page.equal
    in
    List.iter p.transactions ~f:(fun (tx : Transaction.t) ->
      print_s
        [%message
          ""
            ~type_:(tx.tx_type : Transaction.Tx_type.t option)
            ~credit:(tx.credit : string option)
            ~network:(tx.blockchain_network : string option)
            ~after:(Option.bind tx.balance_after ~f:(fun b -> b.amount) : string option)]));
  [%expect
    {|
    ((type_ (On_chain_deposit_confirmed)) (credit (200000000000000000))
     (network ("Polygon Testnet Amoy")) (after (200000000000000000)))
    ((type_ (On_chain_deposit_pending)) (credit ())
     (network ("Polygon Testnet Amoy")) (after (0)))
    ((type_ (Ln_incoming_confirmed)) (credit (495)) (network ()) (after (495)))
    |}]
;;

let%expect_test "OTP confirmation of an interledger send (docs example)" =
  let tx =
    Fixture.roundtrip
      "docs-confirm-inter.json"
      Transaction.t_of_yojson
      Transaction.yojson_of_t
      Transaction.equal
  in
  print_s
    [%message
      ""
        ~status:(tx.status : string option)
        ~type_:(tx.tx_type : Transaction.Tx_type.t option)
        ~order:(tx.order : Wire.Raw_json.t option)];
  [%expect
    {|
    ((status (COMMITTED)) (type_ (Inter_ledger_send))
     (order
      ("{\"price\":\"1\",\"debit\":{\"currency\":\"EUR\",\"amountFloat\":\"5\",\"amount\":500},\"credit\":{\"currency\":\"EUR\",\"amountFloat\":\"5\",\"amount\":500}}")))
    |}]
;;

let%expect_test "EUR enrichment and statement in the sandbox" =
  let e =
    Fixture.roundtrip
      "enrich-eur.json"
      Wallet.Enrichment.t_of_yojson
      Wallet.Enrichment.yojson_of_t
      Wallet.Enrichment.equal
  in
  print_s
    [%message
      ""
        ~iban:(e.iban : string option)
        ~bic:(e.bic : string option)
        ~provider:(e.provider : string option)
        ~status:(e.status : string option)];
  let p =
    Fixture.roundtrip
      "statement-eur.json"
      Transaction.Page.t_of_yojson
      Transaction.Page.yojson_of_t
      Transaction.Page.equal
  in
  List.iter p.transactions ~f:(fun (tx : Transaction.t) ->
    print_s
      [%message
        ""
          ~type_:(tx.tx_type : Transaction.Tx_type.t option)
          ~credit:(tx.credit : string option)
          ~debit:(tx.debit : string option)
          ~after:(Option.bind tx.balance_after ~f:(fun b -> b.amount) : string option)]);
  [%expect
    {|
    ((iban (GB50000000000000002758)) (bic (SEOUGB21)) (provider (SIMULATOR))
     (status (ACTIVE)))
    ((type_ (Card_authorization)) (credit ()) (debit (1234)) (after (5766)))
    ((type_ (Sepa_payout_completed)) (credit ()) (debit ()) (after (7000)))
    ((type_ (Sepa_payout_initiated)) (credit ()) (debit (1000)) (after (7000)))
    ((type_ (Exchange_debit)) (credit ()) (debit (2000)) (after (8000)))
    ((type_ (Sepa_payin_completed)) (credit (10000)) (debit ()) (after (10000)))
    |}]
;;

let%expect_test "EUR enrichment as the sandbox returns it (no accountId)" =
  let e =
    Fixture.roundtrip
      "enrich-eur-sandbox.json"
      Wallet.Enrichment.t_of_yojson
      Wallet.Enrichment.yojson_of_t
      Wallet.Enrichment.equal
  in
  print_s [%sexp (e : Wallet.Enrichment.t)];
  [%expect
    {|
    ((account_id ()) (owner_id ()) (currency (EUR))
     (blockchain_deposit_address ()) (blockchain_network ())
     (blockchain_networks ()) (multi_chain_support ()) (deposit_addresses ())
     (status (ACTIVE)) (internal_account_id (EUR03076388531233))
     (bank_country (GB))
     (bank_address ("The Bower, 207-211 Old Street, London, England, EC1V 9NR"))
     (iban (GB81SEOU19870010482976)) (bic (SEOUGB21))
     (account_number (010482976)) (bank_name ("Simulator Bank"))
     (bank_account_holder_name ("SANDBOX ADA")) (provider (SIMULATOR))
     (payment_type ()) (domestic (false)) (pay_in_reference ())
     (routing_code_entries (())) (bban ()) (bank_postal_code ("SE1 9PA")))
    |}]
;;
