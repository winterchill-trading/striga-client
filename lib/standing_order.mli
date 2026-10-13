(** Standing orders: rules that convert every deposit into an account and optionally pay
    it out. A EUR source pays out to a whitelisted crypto address (fiat to crypto); a
    crypto source pays out to a whitelisted IBAN (crypto to fiat). [SWAP_ONLY] converts
    within the wallet with no payout.

    Creating and cancelling need an OTP (SCA at setup, none per execution). Under SCA the
    destination must first be a trusted beneficiary (errors [64009], [64011]). *)

open! Core
open! Async

module Action : sig
  type t =
    | Swap_only
    | Swap_and_withdraw
  [@@deriving sexp, equal, compare]

  val to_string : t -> string
end

type t =
  { id : string
  ; user_id : string option
  ; status : string option (** [ACTIVE], [PAUSED], [CANCELLED] *)
  ; currency : string option
  ; source_currency : string option
  ; network : string option
  ; address : string option
  ; proposed_rate : string option
  ; parent_wallet_id : string option
  ; root_account_id : string option
  ; whitelisted_address_id : string option
  ; whitelisted_iban_id : string option
  ; iban : string option
  ; bic : string option
  ; standing_order_direction : string option (** [FIAT_TO_CRYPTO] or [CRYPTO_TO_FIAT] *)
  ; action : string option (** [SWAP_ONLY] or [SWAP_AND_WITHDRAW] *)
  ; created_at : string option
  ; last_updated_at : string option
  ; swaps : Wire.Raw_json.t option
  ; payouts : Wire.Raw_json.t option
  ; fixed_fee : Wire.Num_string.t option
  ; percent_fee_bps : Wire.Num_string.t option
  }
[@@deriving sexp, equal, yojson]

module Page : sig
  type standing_order = t [@@deriving sexp, equal, yojson]

  type t =
    { orders : standing_order list
    ; count : int option
    ; total : int option
    }
  [@@deriving sexp, equal, yojson]
end

(** The challenge for a wallet-wide [CRYPTO_TO_FIAT] setup. *)
module Unified : sig
  type t =
    { challenge_id : string
    ; date_expires : string option
    ; verification_method : Common.Verification_method.t option
    ; affected_account_ids : string list option
    ; skipped_account_ids : string list option
    }
  [@@deriving sexp, equal, yojson]
end

(** What {!confirm} returns: the confirmed (or cancelled) order, or for a unified setup
    the wallet and its [standing_orders]. *)
module Confirmed : sig
  type t =
    { id : string option
    ; user_id : string option
    ; status : string option
    ; whitelisted_address_id : string option
    ; whitelisted_iban_id : string option
    ; wallet_id : string option
    ; direction : string option
    ; standing_orders : Wire.Raw_json.t option
    }
  [@@deriving sexp, equal, yojson]
end

(** Returns the OTP challenge; the order exists after {!confirm}. *)
val create
  :  Transport.t
  -> user_id:string
  -> account_id:string
  -> ?whitelisted_address_id:string
  -> ?whitelisted_iban_id:string
  -> ?action:Action.t
  -> ?destination_currency:string
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Common.Challenge.t Or_error.t Deferred.t

(** One [SWAP_ONLY] order per crypto account of the wallet, into its EUR account. *)
val wallet_create
  :  Transport.t
  -> user_id:string
  -> wallet_id:string
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Unified.t Or_error.t Deferred.t

(** Confirms whatever the challenge was for: a create, a unified create or a cancel. *)
val confirm
  :  Transport.t
  -> user_id:string
  -> challenge_id:string
  -> code:string
  -> ip:string
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Confirmed.t Or_error.t Deferred.t

val cancel
  :  Transport.t
  -> user_id:string
  -> standing_order_id:string
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Common.Challenge.t Or_error.t Deferred.t

val resend_otp
  :  Transport.t
  -> user_id:string
  -> challenge_id:string
  -> Common.Challenge.t Or_error.t Deferred.t

val get_all
  :  Transport.t
  -> user_id:string
  -> start:Time_ns.t
  -> stop:Time_ns.t
  -> ?page:int
  -> ?limit:int
  -> unit
  -> Page.t Or_error.t Deferred.t

val get_by_id
  :  Transport.t
  -> user_id:string
  -> standing_order_id:string
  -> t Or_error.t Deferred.t

(** Resume a paused order and execute it on the current balance. *)
val resume
  :  Transport.t
  -> user_id:string
  -> standing_order_id:string
  -> t Or_error.t Deferred.t
