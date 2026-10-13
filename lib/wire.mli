(** JSON helpers shared by the resource modules. *)

open! Core

(** A decimal number carried as text. Striga sends amounts as strings in the smallest unit
    ("10000" cents, "200000000000000000" wei, which overflows a 63-bit int past 4.6 ETH)
    but some endpoints send numbers ([credit: 495], card [originalAmount: 12.34],
    [createdAt: 1791929027997]). Decoding accepts both; encoding always writes a string. *)
module Num_string : sig
  type t = string [@@deriving sexp, equal, compare, yojson]
end

(** A string that prints as [<hidden>] in sexps: one-time tokens, TOTP secrets. *)
module Hidden_string : sig
  type t = string [@@deriving sexp_of, equal, yojson]
end

(** Arbitrary JSON kept as is, for sub-objects whose shape varies between endpoints (e.g.
    a swap [order] carries strings in statements and objects in confirmations). Sexps show
    the compact JSON text. *)
module Raw_json : sig
  type t = Yojson.Safe.t [@@deriving sexp, equal, yojson]
end

(** A blockchain network reference: statements send the network name as a string,
    initiation responses send [{"name": ...}]. Decodes to the name, encodes as a string. *)
module Network_name : sig
  type t = string [@@deriving sexp, equal, yojson]
end

(** String enums with a catch-all, so a new value from Striga never fails a decode. *)
module Enum : sig
  module type Arg = sig
    type t

    val table : (t * string) list
    val other : string -> t
    val to_other : t -> string option
  end

  module Make (X : Arg) : sig
    val to_string : X.t -> string
    val of_string : string -> X.t
    val t_of_yojson : Yojson.Safe.t -> X.t
    val yojson_of_t : X.t -> Yojson.Safe.t
  end
end

(** Drop [null] and absent optional fields from an object (for request bodies). *)
val obj : (string * Yojson.Safe.t option) list -> Yojson.Safe.t

(** Decode with a ppx converter, turning exceptions into a tagged error that names the
    type. The raw JSON is not included (it may hold personal data). *)
val decode : string -> (Yojson.Safe.t -> 'a) -> Yojson.Safe.t -> 'a Or_error.t
