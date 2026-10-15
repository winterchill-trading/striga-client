(** Cards: virtual and physical Visa cards linked to one account of the user, in any
    currency (the linked account is debited at authorization time).

    Card numbers never reach this library: responses carry [maskedCardNumber]. Showing the
    full PAN, CVV or PIN goes through Striga's browser UI component: the browser calls
    [StrigaUXPlugin.create(uiSecret, {applicationId})] (see {!Pan_ui.browser_options}) and
    [requestConsent({userId})], which sends an OTP; the server then calls
    {!confirm_consent} and hands the returned [cardAuthToken] (valid 24 hours) to the
    browser's [render]. *)

open! Core
open! Async

module Card_type : sig
  type t =
    | Virtual
    | Physical
    | Physical_anonymous
    | Other of string
  [@@deriving sexp, equal, compare, yojson]

  val to_string : t -> string
end

module Status : sig
  type t =
    | Created
    | Dispatched
    | Active
    | Activated
    | Blocked
    | Closed
    | Expired
    | Other of string
  [@@deriving sexp, equal, compare, yojson]

  val to_string : t -> string
end

(** Delivery address of a physical card. [country_code] is what create takes (alpha-2);
    responses carry [country] (alpha-3). *)
module Card_address : sig
  type t =
    { address_line1 : string option
    ; address_line2 : string option
    ; city : string option
    ; postal_code : string option
    ; country : string option
    ; country_code : string option
    ; dispatch_method : string option
    ; tracking_number : string option
    }
  [@@deriving sexp, equal, yojson]
end

module Security : sig
  type t =
    { contactless_enabled : bool option
    ; withdrawal_enabled : bool option
    ; internet_purchase_enabled : bool option
    ; overall_limits_enabled : bool option
    }
  [@@deriving sexp, equal, yojson]
end

(** Every numeric field of [limits], by name: the settable limits ([dailyPurchase],
    [monthlyWithdrawal], [transactionContactlessPurchase], ...) in EUR, and the
    [...Available]/[...Used] counters. *)
module Limits : sig
  type t = (string * int) list [@@deriving sexp, equal, yojson]

  val find : t -> string -> int option
end

type t =
  { id : string
  ; name : string option
  ; type_ : Card_type.t option
  ; user_id : string option
  ; masked_card_number : string option (** first 6 and last 4 digits *)
  ; expiry_data : string option (** Striga's spelling; [expiry_date] on newer responses *)
  ; expiry_date : string option
  ; status : Status.t option
  ; address : Card_address.t option
  ; delivery_address : Card_address.t option
  ; is_enrolled_for_3d_secure : bool option
  ; is_card_3d_secure_activated : bool option
  ; security : Security.t option
  ; limits : Limits.t option
  ; activated_at : string option
  ; linked_account_id : string option (** [UNLINKED] when none *)
  ; parent_wallet_id : string option
  ; linked_account_currency : string option
  ; last_linked_account_id : string option
  ; created_at : string option
  ; fee : Wire.Raw_json.t option (** creation fee breakdown, on create only *)
  }
[@@deriving sexp, equal, yojson]

module Page : sig
  type card = t [@@deriving sexp, equal, yojson]

  type t =
    { cards : card list
    ; count : int option
    ; total : int option
    }
  [@@deriving sexp, equal, yojson]
end

(** One entry of a card statement (also the shape of card transaction webhooks). *)
module Card_transaction : sig
  type t =
    { card_id : string option (** webhooks only *)
    ; related_card_transaction_id : string option
    ; type_ : Transaction.Tx_type.t option
    ; original_amount : Wire.Num_string.t option
    (** in whole units of [original_currency], e.g. 12.34 *)
    ; original_currency : string option
    ; transaction_amount : Wire.Num_string.t option
    ; transaction_currency : string option
    ; merchant_id : string option
    ; merchant_name : string option
    ; merchant_city : string option
    ; merchant_country_code : string option
    ; merchant_category_code : string option
    ; account_transaction_id : string option
    ; order : Wire.Raw_json.t option
    ; linked_account_id : string option
    ; linked_account_currency : string option
    ; parent_wallet_id : string option
    ; created_at : string option
    ; decline_details : string option (** e.g. [Not Sufficient Funds] *)
    ; merchant_transaction_amount : Wire.Num_string.t option
    ; merchant_transaction_currency : string option
    ; account_transaction_amount : Wire.Num_string.t option
    ; account_transaction_currency : string option
    }
  [@@deriving sexp, equal, yojson]

  module Page : sig
    type card_transaction = t [@@deriving sexp, equal, yojson]

    type t =
      { transactions : card_transaction list
      ; count : int option
      ; total : int option
      }
    [@@deriving sexp, equal, yojson]
  end
end

module Consent : sig
  type t = { card_auth_token : Wire.Hidden_string.t } [@@deriving sexp_of, equal, yojson]
end

module Pan_ui : sig
  (** [{"uiSecret", "applicationId"}] for the browser's [StrigaUXPlugin.create]. The UI
      secret is meant for the browser (it only drives the iframe after an OTP consent), so
      this is the one place the library hands it out. *)
  val browser_options : Config.t -> Yojson.Safe.t Or_error.t
end

(** [account_id_to_link] defaults to the user's default account. A physical card needs
    [address]. The 3-D Secure password is 8-36 characters. *)
val create
  :  Transport.t
  -> user_id:string
  -> name_on_card:string
  -> three_d_secure_password:string
  -> type_:Card_type.t
  -> ?account_id_to_link:string
  -> ?address:Card_address.t
  -> unit
  -> t Or_error.t Deferred.t

val get : Transport.t -> card_id:string -> t Or_error.t Deferred.t

(** [limit] is capped at 100 by Striga. *)
val get_all
  :  Transport.t
  -> user_id:string
  -> ?limit:int
  -> ?offset:int
  -> unit
  -> Page.t Or_error.t Deferred.t

(** Freeze. *)
val block : Transport.t -> card_id:string -> unit Or_error.t Deferred.t

val unblock : Transport.t -> card_id:string -> unit Or_error.t Deferred.t

(** Close a virtual card for good. *)
val burn : Transport.t -> card_id:string -> t Or_error.t Deferred.t

val report_missing : Transport.t -> card_id:string -> t Or_error.t Deferred.t

(** A new card with the old one's name, 3DS password, delivery method and address, linked
    to the same account. Physical or virtual. *)
val replace : Transport.t -> card_id:string -> t Or_error.t Deferred.t

(** Activate a delivered physical card with the last 4 digits printed on it. In the
    sandbox, {!Simulator.card_status} does this instead. *)
val activate
  :  Transport.t
  -> card_id:string
  -> activation_code:string
  -> t Or_error.t Deferred.t

(** Set some of the limits, e.g. [["dailyPurchase", 500]] (EUR). *)
val update_limits
  :  Transport.t
  -> card_id:string
  -> limits:Limits.t
  -> t Or_error.t Deferred.t

val update_security
  :  Transport.t
  -> card_id:string
  -> contactless:bool
  -> withdrawal:bool
  -> internet_purchase:bool
  -> t Or_error.t Deferred.t

val update_3ds
  :  Transport.t
  -> card_id:string
  -> three_d_secure_password:string
  -> unit Or_error.t Deferred.t

(** Active physical cards only; 4 digits, no repeats or runs. *)
val set_pin : Transport.t -> card_id:string -> pin:string -> unit Or_error.t Deferred.t

(** Returns [{"linkedAccountId", "parentWalletId"}]. *)
val link_account
  :  Transport.t
  -> card_id:string
  -> account_id:string
  -> Wire.Raw_json.t Or_error.t Deferred.t

val statement
  :  Transport.t
  -> card_id:string
  -> start:Time_ns.t
  -> stop:Time_ns.t
  -> ?page:int
  -> ?limit:int
  -> unit
  -> Card_transaction.Page.t Or_error.t Deferred.t

(** Second half of the PAN display consent: [challenge_id] comes from the browser's
    [requestConsent]; [code] is the OTP (sandbox ["123456"]). *)
val confirm_consent
  :  Transport.t
  -> user_id:string
  -> challenge_id:string
  -> code:string
  -> Consent.t Or_error.t Deferred.t

val resend_consent_code
  :  Transport.t
  -> user_id:string
  -> challenge_id:string
  -> Common.Challenge.t Or_error.t Deferred.t

(** Invalidate every card auth token of the user. *)
val revoke_consents : Transport.t -> user_id:string -> unit Or_error.t Deferred.t
