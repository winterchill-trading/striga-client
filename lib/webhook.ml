open! Core
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Event = struct
  type t =
    | Kyc of User.Kyc.t
    | Transaction of Transaction.t
    | Card_transaction of Card.Card_transaction.t
    | Card_status of Wire.Raw_json.t
    | Ping of Wire.Raw_json.t
    | Other of
        { path : string
        ; body : Wire.Raw_json.t
        }
  [@@deriving sexp_of]
end

let has field (json : Yojson.Safe.t) =
  match json with
  | `Assoc fields -> List.Assoc.mem fields field ~equal:String.equal
  | _ -> false
;;

let parse ~path ~body =
  let open Or_error.Let_syntax in
  let%bind json =
    Or_error.try_with (fun () -> Yojson.Safe.from_string body)
    |> Or_error.tag ~tag:"webhook body is not JSON"
  in
  let ends suffix =
    String.is_suffix (String.chop_suffix_if_exists path ~suffix:"/") ~suffix
  in
  if ends "/kyc"
  then Wire.decode "User.Kyc.t" User.Kyc.t_of_yojson json >>| fun k -> Event.Kyc k
  else if ends "/tx"
  then
    if has "cardId" json || has "merchantName" json
    then
      Wire.decode "Card.Card_transaction.t" Card.Card_transaction.t_of_yojson json
      >>| fun c -> Event.Card_transaction c
    else if has "txType" json
    then
      Wire.decode "Transaction.t" Transaction.t_of_yojson json
      >>| fun t -> Event.Transaction t
    else return (Event.Other { path; body = json })
  else if ends "/card/watch"
  then return (Event.Card_status json)
  else if ends "/ping"
  then return (Event.Ping json)
  else return (Event.Other { path; body = json })
;;

let verify_and_parse ~api_key ~path ~headers ~body =
  match
    List.find_map headers ~f:(fun (k, v) ->
      if String.Caseless.equal k "signature" then Some v else None)
  with
  | None -> Or_error.error_string "webhook has no signature header"
  | Some signature ->
    if Signature.verify_webhook ~api_key ~body ~signature
    then parse ~path ~body
    else Or_error.error_string "webhook signature does not match"
;;

module Notice = struct
  module Under_review = struct
    type t =
      { uid : string option [@default None] [@yojson_drop_if Option.is_none]
      ; transaction_id : string option
           [@key "transactionId"] [@default None] [@yojson_drop_if Option.is_none]
      ; account_id : string option
           [@key "accountId"] [@default None] [@yojson_drop_if Option.is_none]
      ; synced_owner_id : string option
           [@key "syncedOwnerId"] [@default None] [@yojson_drop_if Option.is_none]
      ; business_id : string option
           [@key "businessId"] [@default None] [@yojson_drop_if Option.is_none]
      ; tx_type : Transaction.Tx_type.t option
           [@key "txType"] [@default None] [@yojson_drop_if Option.is_none]
      ; amount : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
      ; currency : string option [@default None] [@yojson_drop_if Option.is_none]
      ; held_at : string option
           [@key "heldAt"] [@default None] [@yojson_drop_if Option.is_none]
      ; ts : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
      }
    [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
  end

  module Standing_order_failed = struct
    type t =
      { uid : string option [@default None] [@yojson_drop_if Option.is_none]
      ; source_synced_owner_id : string option
           [@key "sourceSyncedOwnerId"] [@default None] [@yojson_drop_if Option.is_none]
      ; standing_order_id : string option
           [@key "standingOrderId"] [@default None] [@yojson_drop_if Option.is_none]
      ; standing_order_direction : string option
           [@key "standingOrderDirection"]
           [@default None]
           [@yojson_drop_if Option.is_none]
      ; standing_order_span_id : string option
           [@key "standingOrderSpanId"] [@default None] [@yojson_drop_if Option.is_none]
      ; failure_type : string option
           [@key "failureType"] [@default None] [@yojson_drop_if Option.is_none]
      ; ts : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
      }
    [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
  end

  module Debt_added = struct
    type t =
      { uid : string option [@default None] [@yojson_drop_if Option.is_none]
      ; synced_owner_id : string option
           [@key "syncedOwnerId"] [@default None] [@yojson_drop_if Option.is_none]
      ; debt_amount : string option
           [@key "debtAmount"] [@default None] [@yojson_drop_if Option.is_none]
      ; desc : string option [@default None] [@yojson_drop_if Option.is_none]
      ; ts : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
      }
    [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
  end

  module Action_needed = struct
    type t =
      { user_id : string option
           [@key "userId"] [@default None] [@yojson_drop_if Option.is_none]
      ; status : string option [@default None] [@yojson_drop_if Option.is_none]
      ; reason : string option [@default None] [@yojson_drop_if Option.is_none]
      ; tin_verification_expiry_date : string option
           [@key "tinVerificationExpiryDate"]
           [@default None]
           [@yojson_drop_if Option.is_none]
      }
    [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
  end

  type t =
    | Account_enriched of Wallet.Enrichment.t
    | Transaction_under_review of Under_review.t
    | Standing_order_failed of Standing_order_failed.t
    | Account_debt_added of Debt_added.t
    | User_action_needed of Action_needed.t
    | Kyb of Wire.Raw_json.t
    | Travel_rule of
        { type_ : string
        ; body : Wire.Raw_json.t
        }
  [@@deriving sexp_of]
end

let travel_rule_types =
  [ "COUNTERPARTY_DECLARATION_REQUIRED"
  ; "WALLET_VERIFICATION_REQUIRED"
  ; "WALLET_VERIFICATION_IN_REVIEW"
  ; "WALLET_VERIFICATION_COMPLETED"
  ; "WALLET_VERIFICATION_FAILED"
  ; "VASP_COUNTERPARTY_USER_INFO_REQUIRED"
  ; "USER_ACTION_COMPLETED_FOR_TRAVEL_RULE"
  ; "BLOCKED_DUE_TO_TRAVEL_RULE"
  ; "TRAVEL_RULE_ERROR_OCCURRED"
  ]
;;

let notice ~path ~body =
  let open Or_error.Let_syntax in
  let%bind json =
    Or_error.try_with (fun () -> Yojson.Safe.from_string body)
    |> Or_error.tag ~tag:"webhook body is not JSON"
  in
  let ends suffix =
    String.is_suffix (String.chop_suffix_if_exists path ~suffix:"/") ~suffix
  in
  let type_ =
    match json with
    | `Assoc fields ->
      (match List.Assoc.find fields "type" ~equal:String.equal with
       | Some (`String s) -> Some s
       | _ -> None)
    | _ -> None
  in
  let decode name f k = Wire.decode name f json >>| fun v -> Some (k v) in
  if ends "/kyb"
  then return (Some (Notice.Kyb json))
  else if ends "/kyc"
  then (
    match type_ with
    | Some "USER_ACCOUNT_ACTION_NEEDED" ->
      decode "Webhook.Notice.Action_needed.t" Notice.Action_needed.t_of_yojson (fun v ->
        Notice.User_action_needed v)
    | _ -> return None)
  else if ends "/tx"
  then (
    match type_ with
    | Some "ACCOUNT_ENRICHED" ->
      decode "Wallet.Enrichment.t" Wallet.Enrichment.t_of_yojson (fun v ->
        Notice.Account_enriched v)
    | Some "TRANSACTION_UNDER_REVIEW" ->
      decode "Webhook.Notice.Under_review.t" Notice.Under_review.t_of_yojson (fun v ->
        Notice.Transaction_under_review v)
    | Some "STANDING_ORDER_FAILED" ->
      decode
        "Webhook.Notice.Standing_order_failed.t"
        Notice.Standing_order_failed.t_of_yojson
        (fun v -> Notice.Standing_order_failed v)
    | Some "USER_ACCOUNT_DEBT_ADDED" ->
      decode "Webhook.Notice.Debt_added.t" Notice.Debt_added.t_of_yojson (fun v ->
        Notice.Account_debt_added v)
    | Some t when List.mem travel_rule_types t ~equal:String.equal ->
      return (Some (Notice.Travel_rule { type_ = t; body = json }))
    | _ -> return None)
  else return None
;;
