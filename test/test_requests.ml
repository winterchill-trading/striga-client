open! Core
open! Async
open Striga_client

(* Every endpoint against an in-memory server that answers with a recorded fixture (or
   "OK"), printing the request line and body it was sent. Pins paths, verbs and field
   names. *)

let transport answers =
  let answers = Queue.of_list answers in
  let send ~meth uri ~headers:_ ~body =
    let path = String.chop_prefix_exn (Uri.path uri) ~prefix:"/api/v1" in
    printf
      "%s %s %s\n"
      (Transport.Meth.to_string meth)
      path
      (Option.value body ~default:"-");
    let status, body =
      match Queue.dequeue answers with
      | Some (`Fixture f) -> 200, Yojson.Safe.to_string (Fixture.load f)
      | Some (`Text t) -> 200, t
      | None -> 200, "OK"
    in
    return (Ok { Transport.Response.status; headers = []; body })
  in
  Transport.create
    ~send
    ~now:(fun () -> Time_ns.of_int_ns_since_epoch 1_700_000_000_000_000_000)
    (ok_exn (Config.create ~api_key:"k" ~api_secret:"s" ()))
;;

let ok r = ignore (ok_exn r : _)
let t0 = Time_ns.of_int_ns_since_epoch 1_699_000_000_000_000_000
let t1 = Time_ns.of_int_ns_since_epoch 1_700_000_000_000_000_000
let mobile = { Common.Mobile.country_code = "+372"; number = "56781234" }

let%expect_test "users" =
  let tr =
    transport
      [ `Fixture "user-create.json"
      ; `Fixture "user-get.json"
      ; `Text "Accepted"
      ; `Text "Accepted"
      ; `Fixture "kyc-start.json"
      ; `Fixture "kyc-status.json"
      ; `Fixture "user-get.json"
      ]
  in
  let%bind r =
    User.create
      tr
      ~first_name:"Ada"
      ~last_name:"Sandbox"
      ~email:"hello+striga-test@winterchill.xyz"
      ~mobile
      ~date_of_birth:(Common.Date_of_birth.create ~year:1990 ~month:1 ~day:15)
      ()
  in
  ok r;
  let%bind r = User.get tr ~user_id:"u1" in
  ok r;
  let%bind r = User.verify_email tr ~user_id:"u1" ~code:"123456" in
  ok r;
  let%bind r = User.verify_mobile tr ~user_id:"u1" ~code:"123456" in
  ok r;
  let%bind r = User.start_kyc tr ~user_id:"u1" ~tier:1 () in
  ok r;
  let%bind r = User.kyc_status tr ~user_id:"u1" in
  ok r;
  let%bind r = User.update tr ~user_id:"u1" ~first_name:"Eve" () in
  ok r;
  [%expect
    {|
    POST /user/create {"firstName":"Ada","lastName":"Sandbox","email":"hello+striga-test@winterchill.xyz","mobile":{"countryCode":"+372","number":"56781234"},"dateOfBirth":{"year":1990,"month":1,"day":15}}
    GET /user/u1 -
    POST /user/verify-email {"userId":"u1","verificationId":"123456"}
    POST /user/verify-mobile {"userId":"u1","verificationCode":"123456"}
    POST /user/kyc/start {"userId":"u1","tier":1}
    GET /user/kyc/u1 -
    PATCH /user/update {"userId":"u1","firstName":"Eve"}
    |}];
  return ()
;;

let%expect_test "wallets" =
  let tr =
    transport
      [ `Fixture "wallet-create.json"
      ; `Fixture "wallets-all.json"
      ; `Fixture "account-get.json"
      ; `Fixture "enrich-btc.json"
      ; `Fixture "docs-statement.json"
      ; `Fixture "docs-transactions-ln.json"
      ]
  in
  let%bind r = Wallet.create tr ~user_id:"u1" in
  ok r;
  let%bind r = Wallet.get_all tr ~user_id:"u1" ~start:t0 ~stop:t1 () in
  ok r;
  let%bind r = Wallet.get_account tr ~user_id:"u1" ~account_id:"a1" in
  ok r;
  let%bind r = Wallet.enrich_account tr ~user_id:"u1" ~account_id:"a1" in
  ok r;
  let%bind r =
    Wallet.statement tr ~user_id:"u1" ~account_id:"a1" ~start:t0 ~stop:t1 ~limit:50 ()
  in
  ok r;
  let%bind r = Wallet.transactions_by_id tr ~user_id:"u1" ~account_id:"a1" ~tx_id:"tx" in
  ok r;
  [%expect
    {|
    POST /wallets/create {"userId":"u1"}
    POST /wallets/get/all {"userId":"u1","startDate":1699000000000,"endDate":1700000000000,"page":1}
    POST /wallets/get/account {"userId":"u1","accountId":"a1"}
    POST /wallets/account/enrich {"userId":"u1","accountId":"a1"}
    POST /wallets/get/account/statement {"userId":"u1","accountId":"a1","startDate":1699000000000,"endDate":1700000000000,"page":1,"limit":50}
    POST /wallets/account/get-transactions-by-id {"userId":"u1","accountId":"a1","txId":"tx"}
    |}];
  return ()
;;

let%expect_test "money movement and exchange" =
  let tr =
    transport
      [ `Fixture "rates.json"
      ; `Fixture "docs-swap-initiated.json"
      ; `Fixture "docs-intra-initiated.json"
      ; `Fixture "docs-sepa-initiated.json"
      ; `Fixture "docs-confirm-inter.json"
      ; `Fixture "docs-resend-otp.json"
      ; `Fixture "ln-topup.json"
      ; `Fixture "docs-ln-withdrawal-initiated.json"
      ; `Fixture "docs-fee-estimate.json"
      ; `Fixture "docs-onchain-initiated.json"
      ; `Fixture "docs-whitelist-iban.json"
      ; `Fixture "docs-validate-sepa.json"
      ]
  in
  let%bind r = Exchange.rates tr in
  ok r;
  let%bind r =
    Exchange.swap
      tr
      ~user_id:"u1"
      ~source_account_id:"eur"
      ~destination_account_id:"usdc"
      ~amount:"2000"
      ~ip:"192.0.2.1"
      ~verification_method:Sms
      ()
  in
  ok r;
  let%bind r =
    Payment.intraledger
      tr
      ~user_id:"u1"
      ~source_account_id:"a1"
      ~destination_account_id:"a2"
      ~amount:"100"
      ~memo:"lunch"
      ()
  in
  ok r;
  let%bind r =
    Payment.sepa
      tr
      ~user_id:"u1"
      ~source_account_id:"eur"
      ~amount:"1000"
      ~iban:"EE000000000000000000"
      ~bic:"EEUHEE2X"
      ()
  in
  ok r;
  let%bind r =
    Payment.confirm tr ~user_id:"u1" ~challenge_id:"c1" ~code:"123456" ~ip:"192.0.2.1" ()
  in
  ok r;
  let%bind r = Payment.resend_otp tr ~user_id:"u1" ~challenge_id:"c1" in
  ok r;
  let%bind r =
    Payment.lightning_deposit
      tr
      ~user_id:"u1"
      ~account_id:"btc"
      ~amount_sats:"10000"
      ~ttl_minutes:60
      ()
  in
  ok r;
  let%bind r =
    Payment.lightning_withdrawal
      tr
      ~user_id:"u1"
      ~source_account_id:"btc"
      ~invoice:"lnbcrt1..."
      ()
  in
  ok r;
  let%bind r =
    Payment.onchain_fee_estimate
      tr
      ~user_id:"u1"
      ~source_account_id:"eth"
      ~whitelisted_address_id:"w1"
      ~amount:"1000"
  in
  ok r;
  let%bind r =
    Payment.onchain_withdrawal
      tr
      ~user_id:"u1"
      ~source_account_id:"eth"
      ~whitelisted_address_id:"w1"
      ~amount:"1000"
      ~verification_method:Totp
      ()
  in
  ok r;
  let%bind r =
    Payment.whitelist_iban
      tr
      ~user_id:"u1"
      ~iban:"EE000000000000000000"
      ~bic:"EEUHEE2X"
      ~label:"own"
      ()
  in
  ok r;
  let%bind r =
    Payment.validate_sepa_beneficiary
      tr
      ~user_id:"u1"
      ~source_account_id:"eur"
      ~iban:"EE000000000000000000"
      ~bic:"EEUHEE2X"
  in
  ok r;
  [%expect
    {|
    POST /trade/rates {}
    POST /wallets/swap {"userId":"u1","sourceAccountId":"eur","destinationAccountId":"usdc","amount":"2000","ip":"192.0.2.1","verificationMethod":"sms"}
    POST /wallets/send/intra/initiate {"userId":"u1","sourceAccountId":"a1","destinationAccountId":"a2","amount":"100","memo":"lunch"}
    POST /wallets/send/initiate/bank {"userId":"u1","sourceAccountId":"eur","amount":"1000","destination":{"iban":"EE000000000000000000","bic":"EEUHEE2X"}}
    POST /wallets/transaction/confirm {"userId":"u1","challengeId":"c1","verificationCode":"123456","ip":"192.0.2.1"}
    POST /wallets/transaction/resend-otp {"userId":"u1","challengeId":"c1"}
    POST /wallets/account/lightning/topup {"userId":"u1","accountId":"btc","amount":"10000","ttl":60}
    POST /wallets/send/initiate/lightning {"userId":"u1","sourceAccountId":"btc","invoice":"lnbcrt1..."}
    POST /wallets/send/initiate/onchain/fee-estimate {"userId":"u1","sourceAccountId":"eth","whitelistedAddressId":"w1","amount":"1000"}
    POST /wallets/send/initiate/onchain {"userId":"u1","sourceAccountId":"eth","whitelistedAddressId":"w1","amount":"1000","verificationMethod":"totp"}
    POST /wallets/whitelist-iban {"userId":"u1","iban":"EE000000000000000000","bic":"EEUHEE2X","label":"own"}
    POST /wallets/validate-sepa-beneficiary {"userId":"u1","sourceAccountId":"eur","iban":"EE000000000000000000","bic":"EEUHEE2X"}
    |}];
  return ()
;;

let%expect_test "cards, standing orders, SCA and simulator" =
  let tr =
    transport
      [ `Fixture "card-create.json"
      ; `Text "OK"
      ; `Text "OK"
      ; `Fixture "card-get.json"
      ; `Fixture "card-get.json"
      ; `Fixture "card-statement.json"
      ; `Text {|{"challengeId":"c2","dateExpires":"2026-10-13T22:10:00Z"}|}
      ; `Text {|{"status":"OK"}|}
      ; `Text "OK"
      ; `Fixture "sim-card-auth.json"
      ]
  in
  let%bind r =
    Card.create
      tr
      ~user_id:"u1"
      ~name_on_card:"Ada Sandbox"
      ~three_d_secure_password:"Sandbox#Pass2026"
      ~type_:Virtual
      ~account_id_to_link:"btc"
      ()
  in
  ok r;
  let%bind r = Card.block tr ~card_id:"c1" in
  ok r;
  let%bind r = Card.unblock tr ~card_id:"c1" in
  ok r;
  let%bind r = Card.update_limits tr ~card_id:"c1" ~limits:[ "dailyPurchase", 500 ] in
  ok r;
  let%bind r =
    Card.update_security
      tr
      ~card_id:"c1"
      ~contactless:false
      ~withdrawal:true
      ~internet_purchase:true
  in
  ok r;
  let%bind r = Card.statement tr ~card_id:"c1" ~start:t0 ~stop:t1 () in
  ok r;
  let%bind r =
    Standing_order.create
      tr
      ~user_id:"u1"
      ~account_id:"btc"
      ~action:Swap_only
      ~destination_currency:"EUR"
      ()
  in
  ok r;
  let%bind r =
    Sca.login_complete
      tr
      ~user_id:"u1"
      ~verification_method:Totp
      ~ip:"192.0.2.1"
      ~code:"000000"
      ()
  in
  ok r;
  let%bind r = Simulator.kyc tr ~user_id:"u1" ~decision:Approved ~tier:1 () in
  ok r;
  let%bind r =
    Simulator.card_authorization tr ~card_id:"c1" ~amount_eur_cents:1234 ~mcc:"5812" ()
  in
  ok r;
  [%expect
    {|
    POST /card/create {"userId":"u1","nameOnCard":"Ada Sandbox","threeDSecurePassword":"Sandbox#Pass2026","type":"VIRTUAL","accountIdToLink":"btc"}
    POST /card/block {"cardId":"c1"}
    POST /card/unblock {"cardId":"c1"}
    PATCH /card/limits {"cardId":"c1","limits":{"dailyPurchase":500}}
    PATCH /card/security {"cardId":"c1","security":{"contactlessEnabled":false,"withdrawalEnabled":true,"internetPurchaseEnabled":true}}
    POST /card/statement {"cardId":"c1","startDate":1699000000000,"endDate":1700000000000,"page":1}
    POST /standing-orders/create {"userId":"u1","accountId":"btc","action":"SWAP_ONLY","destinationCurrency":"EUR"}
    POST /user/login/complete {"userId":"u1","verificationMethod":"totp","ip":"192.0.2.1","code":"000000"}
    PATCH /simulate/user/kyc {"userId":"u1","status":"APPROVED","tier":1}
    POST /simulate/card/authorization {"cardId":"c1","amountEURCents":1234,"mcc":"5812"}
    |}];
  return ()
;;

let%expect_test "the simulator refuses a live host" =
  let tr =
    Transport.create
      ~send:(fun ~meth:_ _ ~headers:_ ~body:_ -> assert false)
      (ok_exn
         (Config.create
            ~base_url:(Uri.of_string "https://api.example.com/api/v1")
            ~live:true
            ~api_key:"k"
            ~api_secret:"s"
            ()))
  in
  let%bind r = Simulator.deposit tr ~account_id:"a" ~amount_cents:"100" () in
  print_s [%sexp (r : unit Or_error.t)];
  [%expect
    {|
    (Error
     ("simulator endpoints exist only on the sandbox" (host (api.example.com))))
    |}];
  return ()
;;
