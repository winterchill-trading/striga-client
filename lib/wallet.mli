(** Wallets and accounts. A wallet holds one account per currency enabled for the
    application; an account is the unit of value storage and is enriched to get deposit
    credentials (an IBAN for EUR, an address for crypto). KYC approval provisions a
    default wallet. *)

open! Core
open! Async

(** IBAN details of an enriched EUR account. *)
module Banking_details : sig
  type t =
    { currency : string option
    ; status : string option
    ; internal_account_id : string option
    ; bank_country : string option
    ; bank_address : string option
    ; iban : string option
    ; bic : string option
    ; account_number : string option
    ; bank_name : string option
    ; bank_account_holder_name : string option
    ; provider : string option
    ; payment_type : string option
    ; domestic : bool option
    ; pay_in_reference : string option
    }
  [@@deriving sexp, equal, yojson]
end

module Deposit_address : sig
  type t =
    { network : string option
    ; address : string option
    ; status : string option
    ; created_at : string option
    }
  [@@deriving sexp, equal, yojson]
end

module Account : sig
  type t =
    { account_id : string
    ; parent_wallet_id : string option
    ; currency : string option
    ; owner_id : string option
    ; owner_type : string option
    ; created_at : string option
    ; available_balance : Common.Balance.t option
    (** in the smallest unit; see [currency] inside *)
    ; linked_card_id : string option (** [UNLINKED] when none *)
    ; linked_bank_account_id : string option
    ; status : string option
    ; permissions : string list option
    ; enriched : bool option
    ; parent_application_id : string option
    (** the application id ([STRIGA_APPLICATION_ID]) *)
    ; synced_owner_id : string option
    ; account_path : string option
    ; blockchain_deposit_address : string option
    ; blockchain_network : Common.Blockchain_network.t option
    ; blockchain_networks : Common.Blockchain_network.t list option
    ; multi_chain_support : bool option
    ; deposit_addresses : Deposit_address.t list option
    ; banking_details : Banking_details.t option
    }
  [@@deriving sexp, equal, yojson]
end

(** The [accounts] object, keyed by currency (["EUR"], ["BTC"], ...), in response order. *)
module Accounts : sig
  type t = (string * Account.t) list [@@deriving sexp, equal, yojson]
end

type t =
  { wallet_id : string
  ; accounts : Accounts.t
  ; synced_owner_id : string option
  ; owner_type : string option
  ; created_at : string option
  ; comment : string option
  ; wallet_balance : Wire.Num_string.t option
  }
[@@deriving sexp, equal, yojson]

val account : t -> currency:string -> Account.t option

module Page : sig
  type wallet = t [@@deriving sexp, equal, yojson]

  type t =
    { wallets : wallet list
    ; count : int option
    ; total : int option
    }
  [@@deriving sexp, equal, yojson]
end

(** What [/wallets/account/enrich] returns: deposit addresses for crypto accounts, or
    banking details (IBAN, BIC) for EUR accounts. *)
module Enrichment : sig
  type t =
    { account_id : string
    ; owner_id : string option
    ; currency : string option
    ; blockchain_deposit_address : string option
    ; blockchain_network : Common.Blockchain_network.t option
    ; blockchain_networks : Common.Blockchain_network.t list option
    ; multi_chain_support : bool option
    ; deposit_addresses : Deposit_address.t list option
    ; status : string option
    ; internal_account_id : string option
    ; bank_country : string option
    ; bank_address : string option
    ; iban : string option
    ; bic : string option
    ; account_number : string option
    ; bank_name : string option
    ; bank_account_holder_name : string option
    ; provider : string option
    ; payment_type : string option
    ; domestic : bool option
    ; pay_in_reference : string option
    }
  [@@deriving sexp, equal, yojson]
end

(** Another wallet for an approved user, with an account per enabled currency. *)
val create : Transport.t -> user_id:string -> t Or_error.t Deferred.t

val get : Transport.t -> user_id:string -> wallet_id:string -> t Or_error.t Deferred.t

(** Wallets created between [start] and [stop]. The sandbox rejects [startDate = 0]
    ("Invalid startDate"). *)
val get_all
  :  Transport.t
  -> user_id:string
  -> start:Time_ns.t
  -> stop:Time_ns.t
  -> ?page:int
  -> unit
  -> Page.t Or_error.t Deferred.t

val get_account
  :  Transport.t
  -> user_id:string
  -> account_id:string
  -> Account.t Or_error.t Deferred.t

val enrich_account
  :  Transport.t
  -> user_id:string
  -> account_id:string
  -> Enrichment.t Or_error.t Deferred.t

val statement
  :  Transport.t
  -> user_id:string
  -> account_id:string
  -> start:Time_ns.t
  -> stop:Time_ns.t
  -> ?page:int
  -> ?limit:int
  -> unit
  -> Transaction.Page.t Or_error.t Deferred.t

(** Every ledger entry belonging to one transaction id. *)
val transactions_by_id
  :  Transport.t
  -> user_id:string
  -> account_id:string
  -> tx_id:string
  -> Transaction.Page.t Or_error.t Deferred.t
