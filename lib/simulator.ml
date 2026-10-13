open! Core
open! Async
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Decision = struct
  type t =
    | Approved
    | Rejected
    | Rejected_final
  [@@deriving sexp, equal]

  let to_json t : Yojson.Safe.t =
    `String
      (match t with
       | Approved -> "APPROVED"
       | Rejected -> "REJECTED"
       | Rejected_final -> "REJECTED_FINAL")
  ;;
end

module Card_authorization = struct
  type t =
    { transaction : Wire.Raw_json.t option
         [@default None] [@yojson_drop_if Option.is_none]
    ; response : string option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

let sandbox_only tr f =
  let config = Transport.config tr in
  match Uri.host config.Config.base_url with
  | Some host when Config.is_sandbox_host host -> f ()
  | host ->
    return
      (Or_error.error_s
         [%message "simulator endpoints exist only on the sandbox" (host : string option)])
;;

let s v = Option.map v ~f:(fun s -> `String s)

let kyc tr ~user_id ~decision ?tier ?reject_labels () =
  sandbox_only tr (fun () ->
    Call.unit
      tr
      `PATCH
      "/simulate/user/kyc"
      ~body:
        (Wire.obj
           [ "userId", s (Some user_id)
           ; "status", Some (Decision.to_json decision)
           ; "tier", Option.map tier ~f:(fun t -> `Int t)
           ; ( "rejectLabels"
             , Option.map reject_labels ~f:(fun l ->
                 `List (List.map l ~f:(fun x -> `String x))) )
           ])
      ())
;;

let kyb tr ~business_id ~decision =
  sandbox_only tr (fun () ->
    Call.unit
      tr
      `PATCH
      "/simulate/business/kyb"
      ~body:
        (`Assoc
          [ "businessId", `String business_id; "status", Decision.to_json decision ])
      ())
;;

let deposit
  tr
  ~account_id
  ~amount_cents
  ?sender_name
  ?sender_iban
  ?sender_bic
  ?reference
  ?instant
  ()
  =
  sandbox_only tr (fun () ->
    Call.unit
      tr
      `PATCH
      "/simulate/accounts/deposit"
      ~body:
        (Wire.obj
           [ "accountId", s (Some account_id)
           ; "amount", s (Some amount_cents)
           ; "senderName", s sender_name
           ; "senderIban", s sender_iban
           ; "senderBic", s sender_bic
           ; "reference", s reference
           ; ( "paymentType"
             , s (Option.map instant ~f:(fun i -> if i then "SEPA_INSTANT" else "SEPA")) )
           ])
      ())
;;

let sepa_outcome tr ~transaction_id ~account_id ~completed =
  sandbox_only tr (fun () ->
    Call.unit
      tr
      `PATCH
      "/simulate/sepa"
      ~body:
        (`Assoc
          [ "transactionId", `String transaction_id
          ; "accountId", `String account_id
          ; "status", `String (if completed then "COMPLETED" else "FAILED")
          ])
      ())
;;

let card_status tr ~card_id ~active =
  sandbox_only tr (fun () ->
    Call.unit
      tr
      `PATCH
      "/simulate/card/status"
      ~body:
        (`Assoc
          [ "cardId", `String card_id
          ; "status", `String (if active then "ACTIVE" else "DISPATCHED")
          ])
      ())
;;

let card_authorization tr ~card_id ~amount_eur_cents ?mcc () =
  sandbox_only tr (fun () ->
    Call.json
      tr
      `POST
      "/simulate/card/authorization"
      ~body:
        (Wire.obj
           [ "cardId", s (Some card_id)
           ; "amountEURCents", Some (`Int amount_eur_cents)
           ; "mcc", s mcc
           ])
      ~name:"Simulator.Card_authorization.t"
      Card_authorization.t_of_yojson)
;;

let payment_accounts_state tr =
  sandbox_only tr (fun () ->
    Call.read
      tr
      "/simulate/payment-accounts/state"
      ~body:(`Assoc [])
      ~name:"payment accounts state"
      Wire.Raw_json.t_of_yojson)
;;

let webhook_ping tr ~payload =
  sandbox_only tr (fun () ->
    Call.unit tr `POST "/simulate/webhook/ping" ~body:(`Assoc [ "payload", payload ]) ())
;;
