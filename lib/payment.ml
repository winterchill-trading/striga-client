open! Core
open! Async
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Initiated = struct
  type t =
    { challenge_id : string [@key "challengeId"]
    ; date_expires : string option
         [@key "dateExpires"] [@default None] [@yojson_drop_if Option.is_none]
    ; transaction : Transaction.t option [@default None] [@yojson_drop_if Option.is_none]
    ; fee_estimate : Common.Fee_estimate.t option
         [@key "feeEstimate"] [@default None] [@yojson_drop_if Option.is_none]
    ; verification_method : Common.Verification_method.t option
         [@key "verificationMethod"] [@default None] [@yojson_drop_if Option.is_none]
    ; available_verification_methods : Common.Verification_method.t list option
         [@key "availableVerificationMethods"]
         [@default None]
         [@yojson_drop_if Option.is_none]
    ; fallback_via_resend : bool option
         [@key "fallbackViaResend"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Lightning_invoice = struct
  type t =
    { id : string option [@default None] [@yojson_drop_if Option.is_none]
    ; description : string option [@default None] [@yojson_drop_if Option.is_none]
    ; amount : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    ; invoice : string
    ; expiry : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    ; proposed_rate : string option
         [@key "proposedRate"] [@default None] [@yojson_drop_if Option.is_none]
    ; fill_or_kill_at_proposed_rate : bool option
         [@key "fillOrKillAtProposedRate"]
         [@default None]
         [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Whitelisted_address = struct
  type t =
    { id : string
    ; status : string option [@default None] [@yojson_drop_if Option.is_none]
    ; address : string option [@default None] [@yojson_drop_if Option.is_none]
    ; currency : string option [@default None] [@yojson_drop_if Option.is_none]
    ; label : string option [@default None] [@yojson_drop_if Option.is_none]
    ; network : Common.Blockchain_network.t option
         [@default None] [@yojson_drop_if Option.is_none]
    ; internal : bool option [@default None] [@yojson_drop_if Option.is_none]
    ; internal_account_id : string option
         [@key "internalAccountId"] [@default None] [@yojson_drop_if Option.is_none]
    ; created_at : string option
         [@key "createdAt"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Whitelisted_iban = struct
  type t =
    { id : string
    ; iban : string option [@default None] [@yojson_drop_if Option.is_none]
    ; bic : string option [@default None] [@yojson_drop_if Option.is_none]
    ; label : string option [@default None] [@yojson_drop_if Option.is_none]
    ; payment_type : string option
         [@key "paymentType"] [@default None] [@yojson_drop_if Option.is_none]
    ; status : string option [@default None] [@yojson_drop_if Option.is_none]
    ; owner_type : string option
         [@key "ownerType"] [@default None] [@yojson_drop_if Option.is_none]
    ; synced_owner_id : string option
         [@key "syncedOwnerId"] [@default None] [@yojson_drop_if Option.is_none]
    ; parent_application_id : string option
         [@key "parentApplicationId"] [@default None] [@yojson_drop_if Option.is_none]
    ; created_at : string option
         [@key "createdAt"] [@default None] [@yojson_drop_if Option.is_none]
    ; validation : Wire.Raw_json.t option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Address_page = struct
  type t =
    { addresses : Whitelisted_address.t list [@default []]
    ; count : int option [@default None] [@yojson_drop_if Option.is_none]
    ; total : int option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Iban_page = struct
  type t =
    { ibans : Whitelisted_iban.t list [@default []]
    ; count : int option [@default None] [@yojson_drop_if Option.is_none]
    ; total : int option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Sepa_validation = struct
  type t =
    { payment_type : string option
         [@key "paymentType"] [@default None] [@yojson_drop_if Option.is_none]
    ; valid : bool option [@default None] [@yojson_drop_if Option.is_none]
    ; messages : Wire.Raw_json.t option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

let s v = Option.map v ~f:(fun s -> `String s)
let vm v = Option.map v ~f:Common.Verification_method.yojson_of_t
let initiated = Initiated.t_of_yojson

let ledger
  path
  tr
  ~user_id
  ~source_account_id
  ~destination_account_id
  ~amount
  ?memo
  ?verification_method
  ()
  =
  Call.json
    tr
    `POST
    path
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "sourceAccountId", s (Some source_account_id)
         ; "destinationAccountId", s (Some destination_account_id)
         ; "amount", s (Some amount)
         ; "memo", s memo
         ; "verificationMethod", vm verification_method
         ])
    ~name:"Payment.Initiated.t"
    initiated
;;

let intraledger = ledger "/wallets/send/intra/initiate"
let interledger = ledger "/wallets/send/inter/initiate"

let sepa
  tr
  ~user_id
  ~source_account_id
  ~amount
  ~iban
  ~bic
  ?memo
  ?payment_type
  ?whitelisted_iban_id
  ?name
  ?verification_method
  ()
  =
  Call.json
    tr
    `POST
    "/wallets/send/initiate/bank"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "sourceAccountId", s (Some source_account_id)
         ; "amount", s (Some amount)
         ; "destination", Some (`Assoc [ "iban", `String iban; "bic", `String bic ])
         ; "memo", s memo
         ; "paymentType", s payment_type
         ; "whitelistedIbanId", s whitelisted_iban_id
         ; "name", s name
         ; "verificationMethod", vm verification_method
         ])
    ~name:"Payment.Initiated.t"
    initiated
;;

let onchain_body ~user_id ~source_account_id ~whitelisted_address_id ~amount rest =
  Wire.obj
    ([ "userId", s (Some user_id)
     ; "sourceAccountId", s (Some source_account_id)
     ; "whitelistedAddressId", s (Some whitelisted_address_id)
     ; "amount", s (Some amount)
     ]
     @ rest)
;;

let onchain_fee_estimate tr ~user_id ~source_account_id ~whitelisted_address_id ~amount =
  Call.read
    tr
    "/wallets/send/initiate/onchain/fee-estimate"
    ~body:(onchain_body ~user_id ~source_account_id ~whitelisted_address_id ~amount [])
    ~name:"Common.Fee_estimate.t"
    Common.Fee_estimate.t_of_yojson
;;

let onchain_withdrawal
  tr
  ~user_id
  ~source_account_id
  ~whitelisted_address_id
  ~amount
  ?verification_method
  ()
  =
  Call.json
    tr
    `POST
    "/wallets/send/initiate/onchain"
    ~body:
      (onchain_body
         ~user_id
         ~source_account_id
         ~whitelisted_address_id
         ~amount
         [ "verificationMethod", vm verification_method ])
    ~name:"Payment.Initiated.t"
    initiated
;;

let lightning_withdrawal tr ~user_id ~source_account_id ~invoice ?verification_method () =
  Call.json
    tr
    `POST
    "/wallets/send/initiate/lightning"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "sourceAccountId", s (Some source_account_id)
         ; "invoice", s (Some invoice)
         ; "verificationMethod", vm verification_method
         ])
    ~name:"Payment.Initiated.t"
    initiated
;;

let lightning_deposit tr ~user_id ~account_id ~amount_sats ?memo ?ttl_minutes () =
  Call.json
    tr
    `POST
    "/wallets/account/lightning/topup"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "accountId", s (Some account_id)
         ; "amount", s (Some amount_sats)
         ; "memo", s memo
         ; "ttl", Option.map ttl_minutes ~f:(fun m -> `Int m)
         ])
    ~name:"Payment.Lightning_invoice.t"
    Lightning_invoice.t_of_yojson
;;

let confirm tr ~user_id ~challenge_id ~code ~ip ?verification_method () =
  Call.json
    tr
    `POST
    "/wallets/transaction/confirm"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "challengeId", s (Some challenge_id)
         ; "verificationCode", s (Some code)
         ; "ip", s (Some ip)
         ; "verificationMethod", vm verification_method
         ])
    ~name:"Transaction.t"
    Transaction.t_of_yojson
;;

let confirm_with_passkey tr ~user_id ~challenge_id ~ip ~origin ~assertion =
  Call.json
    tr
    `POST
    "/wallets/transaction/confirm"
    ~body:
      (`Assoc
        [ "userId", `String user_id
        ; "challengeId", `String challenge_id
        ; "ip", `String ip
        ; "verificationMethod", `String "passkey"
        ; "origin", `String origin
        ; "passkeyAssertion", assertion
        ])
    ~name:"Transaction.t"
    Transaction.t_of_yojson
;;

let resend_otp tr ~user_id ~challenge_id =
  Call.json
    tr
    `POST
    "/wallets/transaction/resend-otp"
    ~body:(`Assoc [ "userId", `String user_id; "challengeId", `String challenge_id ])
    ~name:"Common.Challenge.t"
    Common.Challenge.t_of_yojson
;;

let whitelist_address tr ~user_id ~address ~currency ~network ?label () =
  Call.json
    tr
    `POST
    "/wallets/whitelist-address"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "address", s (Some address)
         ; "currency", s (Some currency)
         ; "network", s (Some network)
         ; "label", s label
         ])
    ~name:"Payment.Whitelisted_address.t"
    Whitelisted_address.t_of_yojson
;;

let whitelisted_addresses tr ~user_id ?currency ?label ?page () =
  Call.read
    tr
    "/wallets/get/whitelisted-addresses"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "currency", s currency
         ; "label", s label
         ; "page", s (Option.map page ~f:Int.to_string)
         ])
    ~name:"Payment.Address_page.t"
    Address_page.t_of_yojson
;;

let whitelist_iban tr ~user_id ~iban ~bic ?label ?payment_type ?name () =
  Call.json
    tr
    `POST
    "/wallets/whitelist-iban"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "iban", s (Some iban)
         ; "bic", s (Some bic)
         ; "label", s label
         ; "paymentType", s payment_type
         ; "name", s name
         ])
    ~name:"Payment.Whitelisted_iban.t"
    Whitelisted_iban.t_of_yojson
;;

let whitelisted_ibans tr ~user_id ?page ?limit () =
  Call.read
    tr
    "/wallets/get/whitelisted-ibans"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "page", Option.map page ~f:(fun p -> `Int p)
         ; "limit", Option.map limit ~f:(fun l -> `Int l)
         ])
    ~name:"Payment.Iban_page.t"
    Iban_page.t_of_yojson
;;

let deactivate_iban tr ~user_id ~iban =
  Call.json
    tr
    `POST
    "/wallets/deactivate-iban"
    ~body:(`Assoc [ "userId", `String user_id; "iban", `String iban ])
    ~name:"Payment.Whitelisted_iban.t"
    Whitelisted_iban.t_of_yojson
;;

let validate_sepa_beneficiary tr ~user_id ~source_account_id ~iban ~bic =
  Call.read
    tr
    "/wallets/validate-sepa-beneficiary"
    ~body:
      (`Assoc
        [ "userId", `String user_id
        ; "sourceAccountId", `String source_account_id
        ; "iban", `String iban
        ; "bic", `String bic
        ])
    ~name:"Payment.Sepa_validation.t list"
    (list_of_yojson Sepa_validation.t_of_yojson)
;;

let validate_ip_region tr ~user_id ~ip =
  Call.unit
    ~idempotent:true
    tr
    `POST
    "/wallets/validate-ip-region"
    ~body:(`Assoc [ "userId", `String user_id; "ip", `String ip ])
    ()
;;
