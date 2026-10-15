(** End users (consumers): creation, email and mobile verification, KYC.

    Flow: {!create} sends an email and an SMS code (sandbox code ["123456"], nothing is
    really sent), {!verify_email} and {!verify_mobile}, then {!start_kyc} returns a SumSub
    token for the web or mobile SDK. In the sandbox {!Simulator.kyc} stands in for the
    SumSub decision. *)

open! Core
open! Async

module Kyc_status : sig
  type t =
    | Not_started
    | Initiated (** SumSub token fetched *)
    | Pending_review
    | On_hold (** manual review by compliance *)
    | Approved
    | Rejected (** more information needed; start KYC again *)
    | Rejected_final
    | Other of string
  [@@deriving sexp, equal, compare, yojson]

  val to_string : t -> string
end

module Limit_pair : sig
  type t =
    { all : Wire.Num_string.t option
    ; va : Wire.Num_string.t option
    }
  [@@deriving sexp, equal, yojson]
end

module Tier : sig
  type t =
    { eligible : bool option
    ; status : Kyc_status.t option
    ; inbound_limit_consumed : Limit_pair.t option
    ; inbound_limit_allowed : Limit_pair.t option
    ; outbound_limit_consumed : Wire.Num_string.t option (** EUR cents *)
    ; outbound_limit_allowed : Wire.Num_string.t option
    ; verification_expiry_date : string option
    }
  [@@deriving sexp, equal, yojson]
end

module Rejection_comments : sig
  type t =
    { user_comment : string option
    ; auto_comment : string option
    }
  [@@deriving sexp, equal, yojson]
end

(** The [KYC] object of a user, the body of [GET /user/kyc/{id}], and the KYC webhook. *)
module Kyc : sig
  type t =
    { user_id : string option
    ; email_verified : bool option
    ; mobile_verified : bool option
    ; status : Kyc_status.t option
    ; current_tier : int option
    ; details : string list option (** rejection labels, e.g. [EXPIRATION_DATE] *)
    ; rejection_comments : Rejection_comments.t option
    ; rejection_final : bool option
    ; tier0 : Tier.t option
    ; tier1 : Tier.t option
    ; tier2 : Tier.t option
    ; tier3 : Tier.t option
    ; ts : Wire.Num_string.t option (** webhook only *)
    }
  [@@deriving sexp, equal, yojson]
end

module Expiry : sig
  type t = { date_expires : string option } [@@deriving sexp, equal, yojson]
end

module Mfa : sig
  type t =
    { enabled : bool option
    ; enrolled_methods : string list option
    ; passkey_count : int option
    }
  [@@deriving sexp, equal, yojson]
end

type t =
  { user_id : string
  ; first_name : string option
  ; last_name : string option
  ; user_handle : string option
  ; email : string option
  ; mobile : Common.Mobile.t option
  (** the sandbox replaces the number it was given with a random one *)
  ; date_of_birth : Common.Date_of_birth.t option
  ; address : Common.Address.t option
  ; kyc : Kyc.t option
  ; created_at : Wire.Num_string.t option (** epoch ms *)
  ; missing_fields : string list option (** needed before KYC can start *)
  ; email_verification : Expiry.t option
  ; mobile_verification : Expiry.t option
  ; multi_factor_auth : Mfa.t option
  }
[@@deriving sexp, equal, yojson]

module Kyc_start : sig
  type t =
    { provider : string option (** ["SUMSUB"] *)
    ; token : Wire.Hidden_string.t (** short-lived SumSub SDK access token *)
    ; user_id : string option
    ; verification_link : Wire.Hidden_string.t option (** hosted SumSub page *)
    }
  [@@deriving sexp_of, equal, yojson]
end

val create
  :  Transport.t
  -> first_name:string
  -> last_name:string
  -> email:string
  -> mobile:Common.Mobile.t
  -> ?date_of_birth:Common.Date_of_birth.t
  -> ?address:Common.Address.t
  -> unit
  -> t Or_error.t Deferred.t

(** [PATCH /user/update]; only the given fields change. Changing a verified email or
    mobile sends new codes. *)
val update
  :  Transport.t
  -> user_id:string
  -> ?first_name:string
  -> ?last_name:string
  -> ?email:string
  -> ?mobile:Common.Mobile.t
  -> ?date_of_birth:Common.Date_of_birth.t
  -> ?address:Common.Address.t
  -> unit
  -> t Or_error.t Deferred.t

val get : Transport.t -> user_id:string -> t Or_error.t Deferred.t
val get_by_email : Transport.t -> email:string -> t Or_error.t Deferred.t

(** [code] is ["123456"] in the sandbox. *)
val verify_email
  :  Transport.t
  -> user_id:string
  -> code:string
  -> unit Or_error.t Deferred.t

val verify_mobile
  :  Transport.t
  -> user_id:string
  -> code:string
  -> unit Or_error.t Deferred.t

val resend_email : Transport.t -> user_id:string -> unit Or_error.t Deferred.t
val resend_sms : Transport.t -> user_id:string -> unit Or_error.t Deferred.t

(** Needs a verified email and mobile and no [missing_fields]. [tier] is 1 or 2. *)
val start_kyc
  :  Transport.t
  -> user_id:string
  -> ?tier:int
  -> unit
  -> Kyc_start.t Or_error.t Deferred.t

val kyc_status : Transport.t -> user_id:string -> Kyc.t Or_error.t Deferred.t

(** Acceptance of the Payment Account terms. Together with the application-level Payment
    Accounts setting it lets EUR accounts receive and send third-party SEPA payments. *)
module Payment_account_consent : sig
  type t =
    { accepted : bool
    ; date_accepted : string option
    ; ip : string option
    ; terms_uri : string option
    ; terms_version : string option
    }
  [@@deriving sexp, equal, yojson]

  type consent = t [@@deriving sexp, equal, yojson]

  module Record : sig
    type t =
      { user_id : string
      ; payment_account_consent : consent option (** [None] when never recorded *)
      }
    [@@deriving sexp, equal, yojson]
  end
end

(** Record (or, with [~accepted:false], withdraw) the user's consent. Each call replaces
    the stored record whole. Pass the end user's [ip]: without it the caller's server
    address is recorded. [date_accepted] (ISO 8601, e.g. ["2026-09-11T12:00:00.000Z"])
    defaults to the server time. Allowed before KYC. *)
val set_payment_account_consent
  :  Transport.t
  -> user_id:string
  -> accepted:bool
  -> ?terms_version:string
  -> ?terms_uri:string
  -> ?date_accepted:string
  -> ?ip:string
  -> unit
  -> Payment_account_consent.Record.t Or_error.t Deferred.t

val payment_account_consent
  :  Transport.t
  -> user_id:string
  -> Payment_account_consent.Record.t Or_error.t Deferred.t
