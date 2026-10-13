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
