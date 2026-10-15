(** Strong customer authentication (PSD2): TOTP enrollment, the unified login that opens a
    180-day SCA session, security events, and trusted beneficiaries (whitelisted IBANs and
    USDC addresses that later debits can use with lighter factors).

    The application manages passwords and sessions itself and reports failed logins and
    password resets through {!record_event}. Passkey ceremonies need a browser and are not
    wrapped here. *)

open! Core
open! Async

module Totp_enrollment : sig
  type t =
    { secret : Wire.Hidden_string.t (** pass back to {!complete_totp} *)
    ; secret_base32_encoded : Wire.Hidden_string.t option
    (** what authenticator apps take; {!Totp.code_of_base32} computes codes from it *)
    ; totp_uri : Wire.Hidden_string.t option (** [otpauth://...] for a QR code *)
    }
  [@@deriving sexp_of, equal, yojson]
end

module Recovery_codes : sig
  type t = { recovery_codes : Wire.Hidden_string.t list }
  [@@deriving sexp_of, equal, yojson]
end

(** Depends on the factor: [sms] gives a challenge id, [totp] gives [ok], [passkey] gives
    WebAuthn [options]. *)
module Login_challenge : sig
  type t =
    { ok : bool option
    ; challenge_id : string option
    ; date_expires : string option
    ; options : Wire.Raw_json.t option
    ; allowed_origins : string list option
    ; relying_party_id : string option
    }
  [@@deriving sexp, equal, yojson]
end

module Event : sig
  type t =
    | Reset_password_completed (** revokes every SCA session of the user *)
    | Failed_login_attempt (** 5 -> 15 min lock ... 9 -> suspension *)
  [@@deriving sexp, equal]
end

module Beneficiary : sig
  type t =
    [ `Iban of string (** whitelisted IBAN id *)
    | `Address of string (** whitelisted USDC address id *)
    ]
  [@@deriving sexp, equal]
end

(** Needs [totp] in the application's allowed SCA methods. *)
val start_totp : Transport.t -> user_id:string -> Totp_enrollment.t Or_error.t Deferred.t

(** [code] is the authenticator's current code. Returns one-time recovery codes. *)
val complete_totp
  :  Transport.t
  -> user_id:string
  -> secret:string
  -> code:string
  -> Recovery_codes.t Or_error.t Deferred.t

val login_start
  :  Transport.t
  -> user_id:string
  -> verification_method:Common.Verification_method.t
  -> Login_challenge.t Or_error.t Deferred.t

(** [challenge_id] for [sms]; [code] for [sms] and [totp]. Returns the session status. *)
val login_complete
  :  Transport.t
  -> user_id:string
  -> verification_method:Common.Verification_method.t
  -> ip:string
  -> ?challenge_id:string
  -> ?code:string
  -> unit
  -> Wire.Raw_json.t Or_error.t Deferred.t

val record_event
  :  Transport.t
  -> user_id:string
  -> event:Event.t
  -> Wire.Raw_json.t Or_error.t Deferred.t

(** Start marking a beneficiary as trusted (or untrusted). Returns the challenge (for
    [sms]) as raw JSON. *)
val trust
  :  Transport.t
  -> user_id:string
  -> Beneficiary.t
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Wire.Raw_json.t Or_error.t Deferred.t

val untrust
  :  Transport.t
  -> user_id:string
  -> Beneficiary.t
  -> ?verification_method:Common.Verification_method.t
  -> unit
  -> Wire.Raw_json.t Or_error.t Deferred.t

val confirm_trust
  :  Transport.t
  -> user_id:string
  -> Beneficiary.t
  -> ?verification_method:Common.Verification_method.t
  -> ?challenge_id:string
  -> ?code:string
  -> unit
  -> Wire.Raw_json.t Or_error.t Deferred.t

val confirm_untrust
  :  Transport.t
  -> user_id:string
  -> Beneficiary.t
  -> ?verification_method:Common.Verification_method.t
  -> ?challenge_id:string
  -> ?code:string
  -> unit
  -> Wire.Raw_json.t Or_error.t Deferred.t

val list_passkeys : Transport.t -> user_id:string -> Wire.Raw_json.t Or_error.t Deferred.t

(** Second-factor recovery: the user proves who they are with a liveness check (the
    sandbox passes it with {!Simulator.reset_2fa_liveness}), then gets a fresh factor.
    Completing revokes the user's SCA sessions. *)
module Reset_2fa : sig
  module Initiated : sig
    type t =
      { reset_id : string
      ; sumsub_access_token : Wire.Hidden_string.t option
      (** for the embedded verification SDK *)
      ; verification_link : Wire.Hidden_string.t option (** hosted verification page *)
      ; expires_at : string option (** the reset must complete within 30 minutes *)
      }
    [@@deriving sexp_of, equal, yojson]
  end

  module Status : sig
    type t =
      { reset_id : string option
      ; factor : Common.Verification_method.t option
      ; status : string option
      (** [INITIATED], [PENDING_REVIEW], [LIVENESS_PASSED], [COMPLETED], [REJECTED],
          [EXPIRED] *)
      ; enrollment_status : string option
      (** [PENDING] or [COMPLETED] for totp/passkey resets; absent for sms *)
      ; expires_at : string option
      ; completed_at : string option
      }
    [@@deriving sexp, equal, yojson]
  end

  (** By factor: [sms] answers [ok]; [totp] a fresh secret to finish with
      {!complete_totp}; [passkey] WebAuthn creation options to finish with
      {!register_passkey_complete}. *)
  module Completed : sig
    type t =
      { factor : Common.Verification_method.t option
      ; ok : bool option
      ; secret : Wire.Hidden_string.t option
      ; secret_base32_encoded : Wire.Hidden_string.t option
      ; totp_uri : Wire.Hidden_string.t option
      ; options : Wire.Raw_json.t option
      ; allowed_origins : string list option
      ; relying_party_id : string option
      }
    [@@deriving sexp_of, equal, yojson]
  end
end

(** Start a reset of an enrolled [factor]. At most 5 per user per 24 hours. Calling again
    while pending re-issues verification credentials for the same reset. *)
val reset_2fa_initiate
  :  Transport.t
  -> user_id:string
  -> factor:Common.Verification_method.t
  -> Reset_2fa.Initiated.t Or_error.t Deferred.t

val reset_2fa_status
  :  Transport.t
  -> user_id:string
  -> reset_id:string
  -> Reset_2fa.Status.t Or_error.t Deferred.t

(** Call once the status is [LIVENESS_PASSED]. [mobile] is required for an [sms] reset
    (the new number). *)
val reset_2fa_complete
  :  Transport.t
  -> user_id:string
  -> reset_id:string
  -> ?mobile:Common.Mobile.t
  -> unit
  -> Reset_2fa.Completed.t Or_error.t Deferred.t
