(** Small records shared by several resources. Every record decodes leniently (unknown
    fields are ignored, absent or [null] optional fields become [None]) and encodes back
    to the same field names. *)

open! Core

module Mobile : sig
  type t =
    { country_code : string (** with the [+], e.g. ["+372"] *)
    ; number : string
    }
  [@@deriving sexp, equal, yojson]
end

module Address : sig
  type t =
    { address_line1 : string
    ; address_line2 : string option
    ; city : string
    ; postal_code : string
    ; state : string option
    ; country : string (** ISO 3166 alpha-2 *)
    }
  [@@deriving sexp, equal, yojson]
end

module Date_of_birth : sig
  (** Sent as numbers, returned as strings ([{"year":"1990"}]). *)
  type t =
    { year : Wire.Num_string.t
    ; month : Wire.Num_string.t
    ; day : Wire.Num_string.t
    }
  [@@deriving sexp, equal, yojson]

  val create : year:int -> month:int -> day:int -> t

  (** Numbers, the way the create and update endpoints want them. *)
  val to_request_json : t -> Yojson.Safe.t
end

(** The second factor for a challenge. *)
module Verification_method : sig
  type t =
    | Sms
    | Totp
    | Passkey
    | Other of string
  [@@deriving sexp, equal, compare, yojson]

  val to_string : t -> string
  val of_string : string -> t
end

(** An OTP challenge: an SMS code was sent (or a TOTP/passkey proof is due). *)
module Challenge : sig
  type t =
    { challenge_id : string
    ; date_expires : string option
    ; attempts : int option
    ; verification_method : Verification_method.t option
    }
  [@@deriving sexp, equal, yojson]
end

module Blockchain_network : sig
  type t =
    { name : string
    ; network : string option
    ; type_ : string option
    ; contract_address : string option
    ; blockchain_deposit_address : string option
    }
  [@@deriving sexp, equal, yojson]
end

(** [{"amount": "0", "currency": "cents", ...}]: an amount in the smallest unit, named by
    [currency] (cents, satoshis, wei, lamports). *)
module Balance : sig
  type t =
    { amount : Wire.Num_string.t option
    ; balance : Wire.Num_string.t option
    ; currency : string option
    ; h_amount : string option (** human-readable, in whole units *)
    ; fiat_equivalent_balance : Wire.Num_string.t option
    ; fiat_currency : string option
    ; h_fiat_equivalent_balance : string option
    ; rate : Wire.Num_string.t option
    }
  [@@deriving sexp, equal, yojson]
end

module Fee_estimate : sig
  type t =
    { total_fee : Wire.Num_string.t option
    ; network_fee : Wire.Num_string.t option
    ; our_fee : Wire.Num_string.t option
    ; their_fee : Wire.Num_string.t option
    ; fee_currency : string option
    ; gas_limit : Wire.Num_string.t option
    ; gas_price : Wire.Num_string.t option
    }
  [@@deriving sexp, equal, yojson]
end
