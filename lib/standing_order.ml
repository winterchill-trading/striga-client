open! Core
open! Async
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Action = struct
  type t =
    | Swap_only
    | Swap_and_withdraw
  [@@deriving sexp, equal, compare]

  let to_string = function
    | Swap_only -> "SWAP_ONLY"
    | Swap_and_withdraw -> "SWAP_AND_WITHDRAW"
  ;;
end

type t =
  { id : string
  ; user_id : string option
       [@key "userId"] [@default None] [@yojson_drop_if Option.is_none]
  ; status : string option [@default None] [@yojson_drop_if Option.is_none]
  ; currency : string option [@default None] [@yojson_drop_if Option.is_none]
  ; source_currency : string option
       [@key "sourceCurrency"] [@default None] [@yojson_drop_if Option.is_none]
  ; network : string option [@default None] [@yojson_drop_if Option.is_none]
  ; address : string option [@default None] [@yojson_drop_if Option.is_none]
  ; proposed_rate : string option
       [@key "proposedRate"] [@default None] [@yojson_drop_if Option.is_none]
  ; parent_wallet_id : string option
       [@key "parentWalletId"] [@default None] [@yojson_drop_if Option.is_none]
  ; root_account_id : string option
       [@key "rootAccountId"] [@default None] [@yojson_drop_if Option.is_none]
  ; whitelisted_address_id : string option
       [@key "whitelistedAddressId"] [@default None] [@yojson_drop_if Option.is_none]
  ; whitelisted_iban_id : string option
       [@key "whitelistedIbanId"] [@default None] [@yojson_drop_if Option.is_none]
  ; iban : string option [@default None] [@yojson_drop_if Option.is_none]
  ; bic : string option [@default None] [@yojson_drop_if Option.is_none]
  ; standing_order_direction : string option
       [@key "standingOrderDirection"] [@default None] [@yojson_drop_if Option.is_none]
  ; action : string option [@default None] [@yojson_drop_if Option.is_none]
  ; created_at : string option
       [@key "createdAt"] [@default None] [@yojson_drop_if Option.is_none]
  ; last_updated_at : string option
       [@key "lastUpdatedAt"] [@default None] [@yojson_drop_if Option.is_none]
  ; swaps : Wire.Raw_json.t option [@default None] [@yojson_drop_if Option.is_none]
  ; payouts : Wire.Raw_json.t option [@default None] [@yojson_drop_if Option.is_none]
  ; fixed_fee : Wire.Num_string.t option
       [@key "fixedFee"] [@default None] [@yojson_drop_if Option.is_none]
  ; percent_fee_bps : Wire.Num_string.t option
       [@key "percentFeeBps"] [@default None] [@yojson_drop_if Option.is_none]
  }
[@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]

module Page = struct
  type standing_order = t [@@deriving sexp, equal, yojson]

  type t =
    { orders : standing_order list [@default []]
    ; count : int option [@default None] [@yojson_drop_if Option.is_none]
    ; total : int option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Unified = struct
  type t =
    { challenge_id : string [@key "challengeId"]
    ; date_expires : string option
         [@key "dateExpires"] [@default None] [@yojson_drop_if Option.is_none]
    ; verification_method : Common.Verification_method.t option
         [@key "verificationMethod"] [@default None] [@yojson_drop_if Option.is_none]
    ; affected_account_ids : string list option
         [@key "affectedAccountIds"] [@default None] [@yojson_drop_if Option.is_none]
    ; skipped_account_ids : string list option
         [@key "skippedAccountIds"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Confirmed = struct
  type t =
    { id : string option [@default None] [@yojson_drop_if Option.is_none]
    ; user_id : string option
         [@key "userId"] [@default None] [@yojson_drop_if Option.is_none]
    ; status : string option [@default None] [@yojson_drop_if Option.is_none]
    ; whitelisted_address_id : string option
         [@key "whitelistedAddressId"] [@default None] [@yojson_drop_if Option.is_none]
    ; whitelisted_iban_id : string option
         [@key "whitelistedIbanId"] [@default None] [@yojson_drop_if Option.is_none]
    ; wallet_id : string option
         [@key "walletId"] [@default None] [@yojson_drop_if Option.is_none]
    ; direction : string option [@default None] [@yojson_drop_if Option.is_none]
    ; standing_orders : Wire.Raw_json.t option
         [@key "standingOrders"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

let s v = Option.map v ~f:(fun s -> `String s)
let vm v = Option.map v ~f:Common.Verification_method.yojson_of_t
let path p = "/standing-orders" ^ p
let challenge = Common.Challenge.t_of_yojson

let create
  tr
  ~user_id
  ~account_id
  ?whitelisted_address_id
  ?whitelisted_iban_id
  ?action
  ?destination_currency
  ?verification_method
  ()
  =
  Call.json
    tr
    `POST
    (path "/create")
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "accountId", s (Some account_id)
         ; "whitelistedAddressId", s whitelisted_address_id
         ; "whitelistedIbanId", s whitelisted_iban_id
         ; "action", s (Option.map action ~f:Action.to_string)
         ; "destinationCurrency", s destination_currency
         ; "verificationMethod", vm verification_method
         ])
    ~name:"Common.Challenge.t"
    challenge
;;

let wallet_create tr ~user_id ~wallet_id ?verification_method () =
  Call.json
    tr
    `POST
    (path "/wallet-create")
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "walletId", s (Some wallet_id)
         ; "direction", s (Some "CRYPTO_TO_FIAT")
         ; "verificationMethod", vm verification_method
         ])
    ~name:"Standing_order.Unified.t"
    Unified.t_of_yojson
;;

let confirm tr ~user_id ~challenge_id ~code ~ip ?verification_method () =
  Call.json
    tr
    `POST
    (path "/confirm")
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "challengeId", s (Some challenge_id)
         ; "verificationCode", s (Some code)
         ; "ip", s (Some ip)
         ; "verificationMethod", vm verification_method
         ])
    ~name:"Standing_order.Confirmed.t"
    Confirmed.t_of_yojson
;;

let cancel tr ~user_id ~standing_order_id ?verification_method () =
  Call.json
    tr
    `POST
    (path "/cancel")
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "standingOrderId", s (Some standing_order_id)
         ; "verificationMethod", vm verification_method
         ])
    ~name:"Common.Challenge.t"
    challenge
;;

let resend_otp tr ~user_id ~challenge_id =
  Call.json
    tr
    `POST
    (path "/resend-otp")
    ~body:(`Assoc [ "userId", `String user_id; "challengeId", `String challenge_id ])
    ~name:"Common.Challenge.t"
    challenge
;;

let get_all tr ~user_id ~start ~stop ?(page = 1) ?limit () =
  Call.read
    tr
    (path "/get-all")
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "startDate", Some (Call.ms start)
         ; "endDate", Some (Call.ms stop)
         ; "page", Some (`Int page)
         ; "limit", Option.map limit ~f:(fun l -> `Int l)
         ])
    ~name:"Standing_order.Page.t"
    Page.t_of_yojson
;;

let by_id p tr ~user_id ~standing_order_id =
  Call.json
    ~idempotent:true
    tr
    `POST
    (path p)
    ~body:
      (`Assoc [ "userId", `String user_id; "standingOrderId", `String standing_order_id ])
    ~name:"Standing_order.t"
    t_of_yojson
;;

let get_by_id = by_id "/get-by-id"

(* Not idempotent in effect (it executes the order), but a repeat on an active order is a
   no-op on Striga's side; keep it unretried anyway. *)
let resume tr ~user_id ~standing_order_id =
  Call.json
    tr
    `POST
    (path "/resume")
    ~body:
      (`Assoc [ "userId", `String user_id; "standingOrderId", `String standing_order_id ])
    ~name:"Standing_order.t"
    t_of_yojson
;;
