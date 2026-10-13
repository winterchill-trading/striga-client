(** Money movement: transfers between Striga accounts (intraledger between users of the
    same kind, interledger between a user and the corporate), SEPA payouts, on-chain and
    Lightning withdrawals, Lightning deposits, and the OTP confirmation every outgoing
    transfer needs.

    Every initiation returns a challenge; the user's code (SMS, sandbox ["123456"], or
    TOTP) goes to {!confirm}. Initiations are never retried automatically: a lost response
    may still have created a pending transaction. *)

open! Core
open! Async

(** What an initiation returns. *)
module Initiated : sig
  type t =
    { challenge_id : string
    ; date_expires : string option
    ; transaction : Transaction.t option
    (** status [PENDING_2FA_CONFIRMATION]; absent for Lightning withdrawals *)
    ; fee_estimate : Common.Fee_estimate.t option
    ; verification_method : Common.Verification_method.t option
    ; available_verification_methods : Common.Verification_method.t list option
    ; fallback_via_resend : bool option
    }
  [@@deriving sexp, equal, yojson]
end

module Lightning_invoice : sig
  type t =
    { id : string option
    ; description : string option
    ; amount : Wire.Num_string.t option (** satoshis *)
    ; invoice : string (** BOLT11 *)
    ; expiry : Wire.Num_string.t option (** epoch seconds *)
    ; proposed_rate : string option
    ; fill_or_kill_at_proposed_rate : bool option
    }
  [@@deriving sexp, equal, yojson]
end

module Whitelisted_address : sig
  type t =
    { id : string
    ; status : string option (** [PENDING_ACTIVATION], [ACTIVATED] *)
    ; address : string option
    ; currency : string option
    ; label : string option
    ; network : Common.Blockchain_network.t option
    ; internal : bool option (** the address belongs to another Striga account *)
    ; internal_account_id : string option
    ; created_at : string option
    }
  [@@deriving sexp, equal, yojson]
end

module Whitelisted_iban : sig
  type t =
    { id : string
    ; iban : string option
    ; bic : string option
    ; label : string option
    ; payment_type : string option
    ; status : string option
    ; owner_type : string option
    ; synced_owner_id : string option
    ; parent_application_id : string option
    ; created_at : string option
    ; validation : Wire.Raw_json.t option
    }
  [@@deriving sexp, equal, yojson]
end

module Address_page : sig
  type t =
    { addresses : Whitelisted_address.t list
    ; count : int option
    ; total : int option
    }
  [@@deriving sexp, equal, yojson]
end

module Iban_page : sig
  type t =
    { ibans : Whitelisted_iban.t list
    ; count : int option
    ; total : int option
    }
  [@@deriving sexp, equal, yojson]
end

(** One payment scheme's verdict from {!validate_sepa_beneficiary}. *)
module Sepa_validation : sig
  type t =
    { payment_type : string option (** [SEPA] or [SEPA_INSTANT] *)
    ; valid : bool option
    ; messages : Wire.Raw_json.t option
    }
  [@@deriving sexp, equal, yojson]
end

(** Between two consumers (or two corporates), same currency. *)
val intraledger
  :  Transport.t
  -> user_id:string
  -> source_account_id:string
  -> destination_account_id:string
  -> amount:string
  -> ?memo:string
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Initiated.t Or_error.t Deferred.t

(** Between a consumer and the corporate. Prohibited for unlicensed partners. *)
val interledger
  :  Transport.t
  -> user_id:string
  -> source_account_id:string
  -> destination_account_id:string
  -> amount:string
  -> ?memo:string
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Initiated.t Or_error.t Deferred.t

(** SEPA payout from an enriched EUR account. The destination must be in the account
    holder's name unless [name] declares a third-party beneficiary (needs Payment
    Accounts). *)
val sepa
  :  Transport.t
  -> user_id:string
  -> source_account_id:string
  -> amount:string
  -> iban:string
  -> bic:string
  -> ?memo:string
  -> ?payment_type:string
  -> ?whitelisted_iban_id:string
  -> ?name:string
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Initiated.t Or_error.t Deferred.t

val onchain_fee_estimate
  :  Transport.t
  -> user_id:string
  -> source_account_id:string
  -> whitelisted_address_id:string
  -> amount:string
  -> Common.Fee_estimate.t Or_error.t Deferred.t

val onchain_withdrawal
  :  Transport.t
  -> user_id:string
  -> source_account_id:string
  -> whitelisted_address_id:string
  -> amount:string
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Initiated.t Or_error.t Deferred.t

(** Pay a BOLT11 invoice from a BTC account. *)
val lightning_withdrawal
  :  Transport.t
  -> user_id:string
  -> source_account_id:string
  -> invoice:string
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Initiated.t Or_error.t Deferred.t

(** An invoice that credits a BTC account when paid. [ttl_minutes] is 10 to 1440. The
    sandbox issues regtest invoices ([lnbcrt...]). *)
val lightning_deposit
  :  Transport.t
  -> user_id:string
  -> account_id:string
  -> amount_sats:string
  -> ?memo:string
  -> ?ttl_minutes:int
  -> unit
  -> Lightning_invoice.t Or_error.t Deferred.t

(** Complete an initiated transfer or swap. 5 attempts per challenge. *)
val confirm
  :  Transport.t
  -> user_id:string
  -> challenge_id:string
  -> code:string
  -> ip:string
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Transaction.t Or_error.t Deferred.t

(** Up to 5 resends per challenge. *)
val resend_otp
  :  Transport.t
  -> user_id:string
  -> challenge_id:string
  -> Common.Challenge.t Or_error.t Deferred.t

(** [network] as in the docs' network table (e.g. ["Bitcoin"], ["Ethereum"]). *)
val whitelist_address
  :  Transport.t
  -> user_id:string
  -> address:string
  -> currency:string
  -> network:string
  -> ?label:string
  -> unit
  -> Whitelisted_address.t Or_error.t Deferred.t

val whitelisted_addresses
  :  Transport.t
  -> user_id:string
  -> ?currency:string
  -> ?label:string
  -> ?page:int
  -> unit
  -> Address_page.t Or_error.t Deferred.t

val whitelist_iban
  :  Transport.t
  -> user_id:string
  -> iban:string
  -> bic:string
  -> ?label:string
  -> ?payment_type:string
  -> ?name:string
  -> unit
  -> Whitelisted_iban.t Or_error.t Deferred.t

val whitelisted_ibans
  :  Transport.t
  -> user_id:string
  -> ?page:int
  -> ?limit:int
  -> unit
  -> Iban_page.t Or_error.t Deferred.t

(** The docs list [userId] and [iban] as headers; this sends them in the body like every
    other endpoint (unverified). *)
val deactivate_iban
  :  Transport.t
  -> user_id:string
  -> iban:string
  -> Whitelisted_iban.t Or_error.t Deferred.t

val validate_sepa_beneficiary
  :  Transport.t
  -> user_id:string
  -> source_account_id:string
  -> iban:string
  -> bic:string
  -> Sepa_validation.t list Or_error.t Deferred.t

(** [Ok ()] when the IP is outside restricted jurisdictions (error [30046] otherwise). *)
val validate_ip_region
  :  Transport.t
  -> user_id:string
  -> ip:string
  -> unit Or_error.t Deferred.t
