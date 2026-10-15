open! Core
open! Async
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Banking_details = struct
  type t =
    { currency : string option [@default None] [@yojson_drop_if Option.is_none]
    ; status : string option [@default None] [@yojson_drop_if Option.is_none]
    ; internal_account_id : string option
         [@key "internalAccountId"] [@default None] [@yojson_drop_if Option.is_none]
    ; bank_country : string option
         [@key "bankCountry"] [@default None] [@yojson_drop_if Option.is_none]
    ; bank_address : string option
         [@key "bankAddress"] [@default None] [@yojson_drop_if Option.is_none]
    ; iban : string option [@default None] [@yojson_drop_if Option.is_none]
    ; bic : string option [@default None] [@yojson_drop_if Option.is_none]
    ; account_number : string option
         [@key "accountNumber"] [@default None] [@yojson_drop_if Option.is_none]
    ; bank_name : string option
         [@key "bankName"] [@default None] [@yojson_drop_if Option.is_none]
    ; bank_account_holder_name : string option
         [@key "bankAccountHolderName"] [@default None] [@yojson_drop_if Option.is_none]
    ; provider : string option [@default None] [@yojson_drop_if Option.is_none]
    ; payment_type : string option
         [@key "paymentType"] [@default None] [@yojson_drop_if Option.is_none]
    ; domestic : bool option [@default None] [@yojson_drop_if Option.is_none]
    ; pay_in_reference : string option
         [@key "payInReference"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Deposit_address = struct
  type t =
    { network : string option [@default None] [@yojson_drop_if Option.is_none]
    ; address : string option [@default None] [@yojson_drop_if Option.is_none]
    ; status : string option [@default None] [@yojson_drop_if Option.is_none]
    ; created_at : string option
         [@key "createdAt"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Account = struct
  type t =
    { account_id : string [@key "accountId"]
    ; parent_wallet_id : string option
         [@key "parentWalletId"] [@default None] [@yojson_drop_if Option.is_none]
    ; currency : string option [@default None] [@yojson_drop_if Option.is_none]
    ; owner_id : string option
         [@key "ownerId"] [@default None] [@yojson_drop_if Option.is_none]
    ; owner_type : string option
         [@key "ownerType"] [@default None] [@yojson_drop_if Option.is_none]
    ; created_at : string option
         [@key "createdAt"] [@default None] [@yojson_drop_if Option.is_none]
    ; available_balance : Common.Balance.t option
         [@key "availableBalance"] [@default None] [@yojson_drop_if Option.is_none]
    ; linked_card_id : string option
         [@key "linkedCardId"] [@default None] [@yojson_drop_if Option.is_none]
    ; linked_bank_account_id : string option
         [@key "linkedBankAccountId"] [@default None] [@yojson_drop_if Option.is_none]
    ; status : string option [@default None] [@yojson_drop_if Option.is_none]
    ; permissions : string list option [@default None] [@yojson_drop_if Option.is_none]
    ; enriched : bool option [@default None] [@yojson_drop_if Option.is_none]
    ; parent_application_id : string option
         [@key "parentApplicationId"] [@default None] [@yojson_drop_if Option.is_none]
    ; synced_owner_id : string option
         [@key "syncedOwnerId"] [@default None] [@yojson_drop_if Option.is_none]
    ; account_path : string option
         [@key "accountPath"] [@default None] [@yojson_drop_if Option.is_none]
    ; blockchain_deposit_address : string option
         [@key "blockchainDepositAddress"]
         [@default None]
         [@yojson_drop_if Option.is_none]
    ; blockchain_network : Common.Blockchain_network.t option
         [@key "blockchainNetwork"] [@default None] [@yojson_drop_if Option.is_none]
    ; blockchain_networks : Common.Blockchain_network.t list option
         [@key "blockchainNetworks"] [@default None] [@yojson_drop_if Option.is_none]
    ; multi_chain_support : bool option
         [@key "multiChainSupport"] [@default None] [@yojson_drop_if Option.is_none]
    ; deposit_addresses : Deposit_address.t list option
         [@key "depositAddresses"] [@default None] [@yojson_drop_if Option.is_none]
    ; banking_details : Banking_details.t option
         [@key "bankingDetails"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Accounts = struct
  type t = (string * Account.t) list [@@deriving sexp, equal]

  let t_of_yojson (json : Yojson.Safe.t) =
    match json with
    | `Assoc fields ->
      List.map fields ~f:(fun (currency, a) -> currency, Account.t_of_yojson a)
    | _ ->
      raise
        (Ppx_yojson_conv_lib.Yojson_conv.Of_yojson_error
           (Failure "accounts: expected an object keyed by currency", json))
  ;;

  let yojson_of_t t : Yojson.Safe.t =
    `Assoc (List.map t ~f:(fun (currency, a) -> currency, Account.yojson_of_t a))
  ;;
end

type t =
  { wallet_id : string [@key "walletId"]
  ; accounts : Accounts.t
  ; synced_owner_id : string option
       [@key "syncedOwnerId"] [@default None] [@yojson_drop_if Option.is_none]
  ; owner_type : string option
       [@key "ownerType"] [@default None] [@yojson_drop_if Option.is_none]
  ; created_at : string option
       [@key "createdAt"] [@default None] [@yojson_drop_if Option.is_none]
  ; comment : string option [@default None] [@yojson_drop_if Option.is_none]
  ; wallet_balance : Wire.Num_string.t option
       [@key "walletBalance"] [@default None] [@yojson_drop_if Option.is_none]
  }
[@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]

let account t ~currency = List.Assoc.find t.accounts currency ~equal:String.equal

module Page = struct
  type wallet = t [@@deriving sexp, equal, yojson]

  type t =
    { wallets : wallet list [@default []]
    ; count : int option [@default None] [@yojson_drop_if Option.is_none]
    ; total : int option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

(* Only [] has been seen in the sandbox, so the element shape is unknown: keep each entry
   as raw JSON instead of guessing a record. *)
module Routing_code_entry = struct
  type t = Yojson.Safe.t

  let t_of_yojson = Fn.id
  let yojson_of_t = Fn.id
  let equal = Yojson.Safe.equal
  let sexp_of_t t = Sexp.Atom (Yojson.Safe.to_string t)

  let t_of_sexp = function
    | Sexp.Atom s -> Yojson.Safe.from_string s
    | sexp -> of_sexp_error "Routing_code_entry: expected a JSON string atom" sexp
  ;;
end

module Enrichment = struct
  type t =
    { (* The EUR enrichment in the sandbox has no [accountId], only [internalAccountId]. *)
      account_id : string option
         [@key "accountId"] [@default None] [@yojson_drop_if Option.is_none]
    ; owner_id : string option
         [@key "ownerId"] [@default None] [@yojson_drop_if Option.is_none]
    ; currency : string option [@default None] [@yojson_drop_if Option.is_none]
    ; blockchain_deposit_address : string option
         [@key "blockchainDepositAddress"]
         [@default None]
         [@yojson_drop_if Option.is_none]
    ; blockchain_network : Common.Blockchain_network.t option
         [@key "blockchainNetwork"] [@default None] [@yojson_drop_if Option.is_none]
    ; blockchain_networks : Common.Blockchain_network.t list option
         [@key "blockchainNetworks"] [@default None] [@yojson_drop_if Option.is_none]
    ; multi_chain_support : bool option
         [@key "multiChainSupport"] [@default None] [@yojson_drop_if Option.is_none]
    ; deposit_addresses : Deposit_address.t list option
         [@key "depositAddresses"] [@default None] [@yojson_drop_if Option.is_none]
    ; status : string option [@default None] [@yojson_drop_if Option.is_none]
    ; internal_account_id : string option
         [@key "internalAccountId"] [@default None] [@yojson_drop_if Option.is_none]
    ; bank_country : string option
         [@key "bankCountry"] [@default None] [@yojson_drop_if Option.is_none]
    ; bank_address : string option
         [@key "bankAddress"] [@default None] [@yojson_drop_if Option.is_none]
    ; iban : string option [@default None] [@yojson_drop_if Option.is_none]
    ; bic : string option [@default None] [@yojson_drop_if Option.is_none]
    ; account_number : string option
         [@key "accountNumber"] [@default None] [@yojson_drop_if Option.is_none]
    ; bank_name : string option
         [@key "bankName"] [@default None] [@yojson_drop_if Option.is_none]
    ; bank_account_holder_name : string option
         [@key "bankAccountHolderName"] [@default None] [@yojson_drop_if Option.is_none]
    ; provider : string option [@default None] [@yojson_drop_if Option.is_none]
    ; payment_type : string option
         [@key "paymentType"] [@default None] [@yojson_drop_if Option.is_none]
    ; domestic : bool option [@default None] [@yojson_drop_if Option.is_none]
    ; pay_in_reference : string option
         [@key "payInReference"] [@default None] [@yojson_drop_if Option.is_none]
    ; routing_code_entries : Routing_code_entry.t list option
         [@key "routingCodeEntries"] [@default None] [@yojson_drop_if Option.is_none]
    ; bban : string option [@default None] [@yojson_drop_if Option.is_none]
    ; bank_postal_code : string option
         [@key "bankPostalCode"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

let user_body user_id fields = Wire.obj (("userId", Some (`String user_id)) :: fields)

let create tr ~user_id =
  Call.json
    tr
    `POST
    "/wallets/create"
    ~body:(user_body user_id [])
    ~name:"Wallet.t"
    t_of_yojson
;;

let get tr ~user_id ~wallet_id =
  Call.read
    tr
    "/wallets/get"
    ~body:(user_body user_id [ "walletId", Some (`String wallet_id) ])
    ~name:"Wallet.t"
    t_of_yojson
;;

let get_all tr ~user_id ~start ~stop ?(page = 1) () =
  Call.read
    tr
    "/wallets/get/all"
    ~body:
      (user_body
         user_id
         [ "startDate", Some (Call.ms start)
         ; "endDate", Some (Call.ms stop)
         ; "page", Some (`Int page)
         ])
    ~name:"Wallet.Page.t"
    Page.t_of_yojson
;;

let get_account tr ~user_id ~account_id =
  Call.read
    tr
    "/wallets/get/account"
    ~body:(user_body user_id [ "accountId", Some (`String account_id) ])
    ~name:"Wallet.Account.t"
    Account.t_of_yojson
;;

let enrich_account tr ~user_id ~account_id =
  (* A second call returns the same deposit details (checked in the sandbox), so a retry
     after a lost response is safe. *)
  Call.json
    ~idempotent:true
    tr
    `POST
    "/wallets/account/enrich"
    ~body:(user_body user_id [ "accountId", Some (`String account_id) ])
    ~name:"Wallet.Enrichment.t"
    Enrichment.t_of_yojson
;;

let statement tr ~user_id ~account_id ~start ~stop ?(page = 1) ?limit () =
  Call.read
    tr
    "/wallets/get/account/statement"
    ~body:
      (user_body
         user_id
         [ "accountId", Some (`String account_id)
         ; "startDate", Some (Call.ms start)
         ; "endDate", Some (Call.ms stop)
         ; "page", Some (`Int page)
         ; "limit", Option.map limit ~f:(fun l -> `Int l)
         ])
    ~name:"Transaction.Page.t"
    Transaction.Page.t_of_yojson
;;

let transactions_by_id tr ~user_id ~account_id ~tx_id =
  Call.read
    tr
    "/wallets/account/get-transactions-by-id"
    ~body:
      (user_body
         user_id
         [ "accountId", Some (`String account_id); "txId", Some (`String tx_id) ])
    ~name:"Transaction.Page.t"
    Transaction.Page.t_of_yojson
;;
