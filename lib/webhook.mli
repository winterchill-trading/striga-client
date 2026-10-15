(** Incoming webhooks. Striga posts to the configured URL plus a path per channel: [/kyc],
    [/kyb], [/tx] (ledger transactions, card authorizations and travel-rule notices, told
    apart by their fields), [/card/watch] (card status) and [/ping] (dashboard test button
    and {!Simulator.webhook_ping}). Each request has a [signature] header (see
    {!Signature.verify_webhook}); deliveries are retried up to 5 times until the endpoint
    answers 2xx. *)

open! Core

module Event : sig
  type t =
    | Kyc of User.Kyc.t
    | Transaction of Transaction.t
    | Card_transaction of Card.Card_transaction.t
    | Card_status of Wire.Raw_json.t (** [{"cardId", "status": EXPIRED | CLOSED | ...}] *)
    | Ping of Wire.Raw_json.t
    | Other of
        { path : string
        ; body : Wire.Raw_json.t
        }
  [@@deriving sexp_of]
end

(** Decode a delivery by the path it arrived on (with or without the application's own
    prefix, e.g. [/webhooks/striga/tx]). *)
val parse : path:string -> body:string -> Event.t Or_error.t

(** Check the [signature] header (looked up case-insensitively), then {!parse}. *)
val verify_and_parse
  :  api_key:Secret.t
  -> path:string
  -> headers:(string * string) list
  -> body:string
  -> Event.t Or_error.t

(** Deliveries that are not ledger rows, KYC statuses or card events, typed by their
    [type] field. They arrive on the same paths, so {!parse} gives most of them as [Other]
    (and a [TRANSACTION_UNDER_REVIEW] as a [Transaction], since it carries a [txType]);
    {!notice} decodes the same delivery into one of these. Kept apart from {!Event.t} so
    code matching on [Event.t] keeps compiling. *)
module Notice : sig
  (** A transaction held for compliance review (funds are not released yet). *)
  module Under_review : sig
    type t =
      { uid : string option
      ; transaction_id : string option
      ; account_id : string option
      ; synced_owner_id : string option
      ; business_id : string option
      ; tx_type : Transaction.Tx_type.t option
      ; amount : Wire.Num_string.t option
      ; currency : string option
      ; held_at : string option
      ; ts : Wire.Num_string.t option
      }
    [@@deriving sexp, equal, yojson]
  end

  module Standing_order_failed : sig
    type t =
      { uid : string option
      ; source_synced_owner_id : string option
      ; standing_order_id : string option
      ; standing_order_direction : string option (** e.g. [CRYPTO_TO_FIAT] *)
      ; standing_order_span_id : string option
      ; failure_type : string option
      (** [SEPA_WITHDRAWAL_FAILED], [ON_CHAIN_WITHDRAWAL_FAILED], [USER_LIMIT_EXCEEDED],
          [PROPOSED_RATE_VALIDATION_FAILED], [BLOCKED_BY_TRAVEL_RULE],
          [BLOCKED_BY_TRANSACTION_RESTRICTION] *)
      ; ts : Wire.Num_string.t option
      }
    [@@deriving sexp, equal, yojson]
  end

  (** A card settlement the balance could not cover; [debt_amount] is in units (["2.5"]
      EUR), not cents. *)
  module Debt_added : sig
    type t =
      { uid : string option
      ; synced_owner_id : string option
      ; debt_amount : string option
      ; desc : string option
      ; ts : Wire.Num_string.t option
      }
    [@@deriving sexp, equal, yojson]
  end

  (** On [/kyc]: the user must supply something (e.g. [TIN_INFORMATION_MISSING_DAC8]). *)
  module Action_needed : sig
    type t =
      { user_id : string option
      ; status : string option
      ; reason : string option
      ; tin_verification_expiry_date : string option
      }
    [@@deriving sexp, equal, yojson]
  end

  type t =
    | Account_enriched of Wallet.Enrichment.t (** IBAN details after enrichment *)
    | Transaction_under_review of Under_review.t
    | Standing_order_failed of Standing_order_failed.t
    | Account_debt_added of Debt_added.t
    | User_action_needed of Action_needed.t
    | Kyb of Wire.Raw_json.t (** [/kyb]: business status changes *)
    | Travel_rule of
        { type_ : string
        ; body : Wire.Raw_json.t
        }
  [@@deriving sexp_of]
end

(** [Some] for a delivery that is one of {!Notice.t}, [None] otherwise. Does not check the
    signature: call it after {!verify_and_parse} succeeded on the same delivery. *)
val notice : path:string -> body:string -> Notice.t option Or_error.t
