(** The sandbox simulator ([/simulate/...]): stand-ins for events that start outside the
    application (a KYC decision, an incoming SEPA payment, a card used at a till). They
    change state and send webhooks like the real events. Every function refuses to run
    against a host that is not the Striga sandbox.

    [PATCH /simulate/payment-accounts] (turn Payment Accounts on or off) changes an
    application-level setting and is deliberately not wrapped. *)

open! Core
open! Async

module Decision : sig
  type t =
    | Approved
    | Rejected
    | Rejected_final
  [@@deriving sexp, equal]
end

module Card_authorization : sig
  type t =
    { transaction : Wire.Raw_json.t option
    ; response : string option (** [APPROVED] or [DECLINED]; the reason is in webhooks *)
    }
  [@@deriving sexp, equal, yojson]
end

(** Needs a verified email and mobile and a started KYC. Answers at once; the default
    wallet appears a few seconds later. *)
val kyc
  :  Transport.t
  -> user_id:string
  -> decision:Decision.t
  -> ?tier:int
  -> ?reject_labels:string list
  -> unit
  -> unit Or_error.t Deferred.t

val kyb
  :  Transport.t
  -> business_id:string
  -> decision:Decision.t
  -> unit Or_error.t Deferred.t

(** Credit an enriched EUR account as if a SEPA payment arrived. [amount_cents] is a
    string of digits ("10000" = 100.00 EUR). Error [31123] for a non-EUR account, [31002]
    for one that is not enriched. *)
val deposit
  :  Transport.t
  -> account_id:string
  -> amount_cents:string
  -> ?sender_name:string
  -> ?sender_iban:string
  -> ?sender_bic:string
  -> ?reference:string
  -> ?instant:bool
  -> unit
  -> unit Or_error.t Deferred.t

(** Settle or fail an outgoing SEPA payment. *)
val sepa_outcome
  :  Transport.t
  -> transaction_id:string
  -> account_id:string
  -> completed:bool
  -> unit Or_error.t Deferred.t

(** Move a physical card to [DISPATCHED] or [ACTIVE]. *)
val card_status
  :  Transport.t
  -> card_id:string
  -> active:bool
  -> unit Or_error.t Deferred.t

(** A card payment of [amount_eur_cents] (0 to 1,500,000); [mcc] ["ATM"] or ["6011"] is a
    cash withdrawal. Decided against the linked account's balance, limits and status. *)
val card_authorization
  :  Transport.t
  -> card_id:string
  -> amount_eur_cents:int
  -> ?mcc:string
  -> unit
  -> Card_authorization.t Or_error.t Deferred.t

(** [{"paymentAccountsEnabled", "effective3pSepaPayoutsEnabled"}]. Read-only. *)
val payment_accounts_state : Transport.t -> Wire.Raw_json.t Or_error.t Deferred.t

(** Send [payload] to the application's webhook URL as a signed [TEST] webhook. *)
val webhook_ping : Transport.t -> payload:Yojson.Safe.t -> unit Or_error.t Deferred.t

(** Pass the liveness check of a pending 2FA reset ({!Sca.reset_2fa_initiate}); the answer
    carries the reset's new status, [LIVENESS_PASSED]. *)
val reset_2fa_liveness
  :  Transport.t
  -> reset_id:string
  -> Sca.Reset_2fa.Status.t Or_error.t Deferred.t

(** A KYC share token, as another provider would issue it, for {!User.start_kyc}'s
    [?share_token] (reusable KYC). It is a credential, hidden in sexps. *)
val kyc_share_token : Transport.t -> Wire.Hidden_string.t Or_error.t Deferred.t
