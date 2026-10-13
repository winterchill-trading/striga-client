(** RFC 6238 time-based one-time passwords (HMAC-SHA1, 30 s steps, 6 digits), the codes an
    authenticator app shows. Used by the live sandbox walk and dev tools to act as the
    user's authenticator; a real application never holds the user's TOTP secret. *)

open! Core

(** RFC 4648 base32 (case-insensitive, padding optional). *)
val base32_decode : string -> string Or_error.t

(** The code for [key] (raw bytes) at [time]. [digits] defaults to 6. *)
val code : ?digits:int -> key:string -> Time_ns.t -> string

(** The code for an [otpauth://] secret as Striga returns it in [secretBase32Encoded]. *)
val code_of_base32 : ?digits:int -> string -> Time_ns.t -> string Or_error.t
