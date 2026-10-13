(** Exchange rates and currency swaps between two accounts of the same user.

    Under PSD2 SCA (all applications from 1 July 2026) a swap is initiated here and only
    executes after {!Payment.confirm} with the matching factor; swaps from EUR or USDC
    need [sms] or [passkey]. Minimum order size is about 10 EUR equivalent. *)

open! Core
open! Async

module Rate : sig
  type t =
    { price : Wire.Num_string.t option
    ; buy : Wire.Num_string.t option
    ; sell : Wire.Num_string.t option
    ; timestamp : Wire.Num_string.t option (** epoch ms *)
    ; h_timestamp : string option
    ; currency : string option (** quote currency name, e.g. ["Euros"] *)
    }
  [@@deriving sexp, equal, yojson]
end

(** Keyed by ticker (["BTCEUR"], ["USDCEUR"], ["BTCUSDC"], ...), in response order. *)
module Rates : sig
  type t = (string * Rate.t) list [@@deriving sexp, equal, yojson]

  val find : t -> ticker:string -> Rate.t option
end

val rates : Transport.t -> Rates.t Or_error.t Deferred.t

(** [amount] is in the smallest unit of the source currency. [ip] is the end user's IP
    (required, checked against restricted jurisdictions). [proposed_rate] must be within
    3% of the market rate and needs enabling by Striga. *)
val swap
  :  Transport.t
  -> user_id:string
  -> source_account_id:string
  -> destination_account_id:string
  -> amount:string
  -> ip:string
  -> ?memo:string
  -> ?proposed_rate:string
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Payment.Initiated.t Or_error.t Deferred.t
