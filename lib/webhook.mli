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
