open! Core
open Striga_client

let api_key = Secret.of_string "not-a-real-api-key"

(* Deliveries are compact JSON, as Striga's JSON.stringify sends them. *)
let delivery name = Yojson.Safe.to_string (Fixture.load name)

let show path body =
  let headers = [ "Signature", Signature.webhook_signature ~api_key body ] in
  match Webhook.verify_and_parse ~api_key ~path ~headers ~body with
  | Error e -> print_s [%sexp (e : Error.t)]
  | Ok (Kyc k) ->
    print_s
      [%message
        "kyc"
          ~status:(k.status : User.Kyc_status.t option)
          ~details:(k.details : string list option)]
  | Ok (Transaction t) ->
    print_s
      [%message
        "tx"
          ~type_:(t.tx_type : Transaction.Tx_type.t option)
          ~debit:(t.debit : string option)
          ~credit:(t.credit : string option)]
  | Ok (Card_transaction c) ->
    print_s
      [%message
        "card"
          ~type_:(c.type_ : Transaction.Tx_type.t option)
          ~card:(c.card_id : string option)
          ~amount:(c.merchant_transaction_amount : string option)]
  | Ok e -> print_s [%sexp (e : Webhook.Event.t)]
;;

let%expect_test "documented webhook payloads route by path and shape" =
  show "/webhooks/striga/kyc" (delivery "docs-webhook-kyc.json");
  show "/webhooks/striga/tx" (delivery "docs-webhook-intra.json");
  show "/webhooks/striga/tx" (delivery "docs-webhook-card-auth.json");
  (* The ledger side of a card payment has a txType and no cardId. *)
  show "/webhooks/striga/tx" (delivery "docs-webhook-card-debit.json");
  show "/webhooks/striga/card/watch" {|{"cardId":"c1","status":"EXPIRED"}|};
  show "/webhooks/striga/ping" {|{"hello":"world","uid":"u","ts":1}|};
  show "/webhooks/striga/tx" {|{"type":"COUNTERPARTY_DECLARATION_REQUIRED","userId":"u"}|};
  [%expect
    {|
    (kyc (status (Rejected)) (details ((BAD_PROOF_OF_ADDRESS))))
    (tx (type_ (Intra_ledger_send)) (debit (100000)) (credit ()))
    (card (type_ (Card_authorization))
     (card (00000000-0000-4000-8000-000000000060)) (amount (1000)))
    (tx (type_ (Card_authorization)) (debit (4193529)) (credit ()))
    (Card_status "{\"cardId\":\"c1\",\"status\":\"EXPIRED\"}")
    (Ping "{\"hello\":\"world\",\"uid\":\"u\",\"ts\":1}")
    (Other (path /webhooks/striga/tx)
     (body "{\"type\":\"COUNTERPARTY_DECLARATION_REQUIRED\",\"userId\":\"u\"}"))
    |}]
;;

let%expect_test "bad or missing signatures are refused" =
  let body = delivery "docs-webhook-kyc.json" in
  let try_ headers =
    print_s
      [%sexp
        (Webhook.verify_and_parse ~api_key ~path:"/kyc" ~headers ~body
         |> Or_error.map ~f:(fun _ -> ())
         : unit Or_error.t)]
  in
  try_ [];
  try_ [ "signature", String.make 64 '0' ];
  try_
    [ "signature", Signature.webhook_signature ~api_key:(Secret.of_string "other") body ];
  [%expect
    {|
    (Error "webhook has no signature header")
    (Error "webhook signature does not match")
    (Error "webhook signature does not match")
    |}]
;;

let%expect_test "notices (docs examples, ids replaced)" =
  List.iter
    [ "/tx", "docs-webhook-account-enriched.json"
    ; "/tx", "docs-webhook-under-review.json"
    ; "/tx", "docs-webhook-standing-order-failed.json"
    ; "/tx", "docs-webhook-debt-added.json"
    ; "/kyc", "docs-webhook-action-needed.json"
    ; "/tx", "docs-webhook-intra.json"
    ; "/kyc", "docs-webhook-kyc.json"
    ]
    ~f:(fun (path, f) ->
      let body = Yojson.Safe.to_string (Fixture.load f) in
      match Webhook.notice ~path ~body with
      | Ok None -> printf "%s: not a notice\n" f
      | Ok (Some n) -> print_s [%sexp (n : Webhook.Notice.t)]
      | Error e -> print_s [%sexp (e : Error.t)]);
  List.iter
    [ "/kyb", {|{"businessId":"b1","status":"APPROVED"}|}
    ; "/tx", {|{"type":"BLOCKED_DUE_TO_TRAVEL_RULE","userId":"u"}|}
    ]
    ~f:(fun (path, body) ->
      print_s [%sexp (Webhook.notice ~path ~body : Webhook.Notice.t option Or_error.t)]);
  [%expect
    {|
    (Account_enriched
     ((account_id (ffff0000000000000000000000000071)) (owner_id ())
      (currency (EUR)) (blockchain_deposit_address ()) (blockchain_network ())
      (blockchain_networks ()) (multi_chain_support ()) (deposit_addresses ())
      (status (ACTIVE)) (internal_account_id (EUR00000000008233))
      (bank_country (GB))
      (bank_address ("The Bower, 207-211 Old Street, London, England, EC1V 9NR"))
      (iban (GB50000000000000006783)) (bic (SEOUGB21))
      (account_number (000006783)) (bank_name ("Simulator Bank"))
      (bank_account_holder_name ("ADA SANDBOX")) (provider (SIMULATOR))
      (payment_type ()) (domestic (false)) (pay_in_reference ())
      (routing_code_entries (())) (bban ()) (bank_postal_code ())))
    (Transaction_under_review
     ((uid (a7c31e52-90bb-4f6d-8c21-3d4e5f6a7b8c))
      (transaction_id (0cf9a1d4-5b6e-4c7d-8e9f-0a1b2c3d4e5f))
      (account_id (9b8a7c6d5e4f30211203f4e5d6c7b8a9))
      (synced_owner_id (00000000-0000-4000-8000-000000000001))
      (business_id (00000000-0000-4000-8000-000000000001))
      (tx_type (Sepa_payin_completed)) (amount (250000)) (currency (EUR))
      (held_at (2026-10-06T09:12:45.820Z)) (ts (1791278011443))))
    (Standing_order_failed
     ((uid (99225580-59fb-47c2-a87c-6e2aa48d6150))
      (source_synced_owner_id (00000000-0000-4000-8000-000000000001))
      (standing_order_id (00000000-0000-4000-8000-0000000000b1))
      (standing_order_direction (CRYPTO_TO_FIAT))
      (standing_order_span_id (00000000-0000-4000-8000-0000000000b2))
      (failure_type (SEPA_WITHDRAWAL_FAILED)) (ts (1756992421918))))
    (Account_debt_added
     ((uid (00000000-0000-4000-8000-0000000000c1))
      (synced_owner_id (00000000-0000-4000-8000-000000000001))
      (debt_amount (2.5)) (desc ("Settlement of 2.5 EUR at Example Merchant/"))
      (ts (1768691280411))))
    (User_action_needed
     ((user_id (00000000-0000-4000-8000-000000000001)) (status (APPROVED))
      (reason (TIN_INFORMATION_MISSING_DAC8))
      (tin_verification_expiry_date (2026-12-31T00:00:00.000Z))))
    docs-webhook-intra.json: not a notice
    docs-webhook-kyc.json: not a notice
    (Ok ((Kyb "{\"businessId\":\"b1\",\"status\":\"APPROVED\"}")))
    (Ok
     ((Travel_rule (type_ BLOCKED_DUE_TO_TRAVEL_RULE)
       (body "{\"type\":\"BLOCKED_DUE_TO_TRAVEL_RULE\",\"userId\":\"u\"}"))))
    |}]
;;
