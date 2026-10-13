(** Redaction for anything that may reach a log: API credentials, card numbers, IBANs and
    the one-time tokens Striga returns (SumSub tokens, card PAN auth tokens, TOTP secrets,
    recovery codes, PINs).

    Card numbers keep their last 4 digits, IBANs their country code and last 4
    characters. *)

open! Core

(** ["GB10SEOU19870010266392"] -> ["GB****************6392"]. Strings that do not look like
    an IBAN are returned unchanged. *)
val iban : string -> string

(** All but the last 4 digits become [*]. *)
val pan : string -> string

(** Luhn check over a string of digits. *)
val luhn_valid : string -> bool

(** Free text: replaces each secret, IBAN-shaped words, and Luhn-valid 13-19 digit runs
    (card numbers). Long amounts in wei can pass the Luhn check by chance and be masked
    too; this is meant for logs, where over-redaction is harmless. *)
val text : ?secrets:Secret.t list -> string -> string

(** Field names whose values are always replaced by ["<redacted>"] in {!json}. *)
val sensitive_fields : string list

(** JSON: values of {!sensitive_fields} are replaced, [iban] fields keep the last 4,
    [accountNumber] fields keep the last 4, and every string goes through {!text}. *)
val json : ?secrets:Secret.t list -> Yojson.Safe.t -> Yojson.Safe.t
