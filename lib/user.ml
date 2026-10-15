open! Core
open! Async
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Kyc_status = struct
  module T = struct
    type t =
      | Not_started
      | Initiated
      | Pending_review
      | On_hold
      | Approved
      | Rejected
      | Rejected_final
      | Other of string
    [@@deriving sexp, equal, compare]

    let table =
      [ Not_started, "NOT_STARTED"
      ; Initiated, "INITIATED"
      ; Pending_review, "PENDING_REVIEW"
      ; On_hold, "ON_HOLD"
      ; Approved, "APPROVED"
      ; Rejected, "REJECTED"
      ; Rejected_final, "REJECTED_FINAL"
      ]
    ;;

    let other s = Other s

    let to_other = function
      | Other s -> Some s
      | _ -> None
    ;;
  end

  include T
  include Wire.Enum.Make (T)
end

module Limit_pair = struct
  type t =
    { all : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    ; va : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Tier = struct
  type t =
    { eligible : bool option [@default None] [@yojson_drop_if Option.is_none]
    ; status : Kyc_status.t option [@default None] [@yojson_drop_if Option.is_none]
    ; inbound_limit_consumed : Limit_pair.t option
         [@key "inboundLimitConsumed"] [@default None] [@yojson_drop_if Option.is_none]
    ; inbound_limit_allowed : Limit_pair.t option
         [@key "inboundLimitAllowed"] [@default None] [@yojson_drop_if Option.is_none]
    ; outbound_limit_consumed : Wire.Num_string.t option
         [@key "outboundLimitConsumed"] [@default None] [@yojson_drop_if Option.is_none]
    ; outbound_limit_allowed : Wire.Num_string.t option
         [@key "outboundLimitAllowed"] [@default None] [@yojson_drop_if Option.is_none]
    ; verification_expiry_date : string option
         [@key "verificationExpiryDate"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Rejection_comments = struct
  type t =
    { user_comment : string option
         [@key "userComment"] [@default None] [@yojson_drop_if Option.is_none]
    ; auto_comment : string option
         [@key "autoComment"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Kyc = struct
  type t =
    { user_id : string option
         [@key "userId"] [@default None] [@yojson_drop_if Option.is_none]
    ; email_verified : bool option
         [@key "emailVerified"] [@default None] [@yojson_drop_if Option.is_none]
    ; mobile_verified : bool option
         [@key "mobileVerified"] [@default None] [@yojson_drop_if Option.is_none]
    ; status : Kyc_status.t option [@default None] [@yojson_drop_if Option.is_none]
    ; current_tier : int option
         [@key "currentTier"] [@default None] [@yojson_drop_if Option.is_none]
    ; details : string list option [@default None] [@yojson_drop_if Option.is_none]
    ; rejection_comments : Rejection_comments.t option
         [@key "rejectionComments"] [@default None] [@yojson_drop_if Option.is_none]
    ; rejection_final : bool option
         [@key "rejectionFinal"] [@default None] [@yojson_drop_if Option.is_none]
    ; tier0 : Tier.t option [@default None] [@yojson_drop_if Option.is_none]
    ; tier1 : Tier.t option [@default None] [@yojson_drop_if Option.is_none]
    ; tier2 : Tier.t option [@default None] [@yojson_drop_if Option.is_none]
    ; tier3 : Tier.t option [@default None] [@yojson_drop_if Option.is_none]
    ; ts : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Expiry = struct
  type t =
    { date_expires : string option
         [@key "dateExpires"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Mfa = struct
  type t =
    { enabled : bool option [@default None] [@yojson_drop_if Option.is_none]
    ; enrolled_methods : string list option
         [@key "enrolledMethods"] [@default None] [@yojson_drop_if Option.is_none]
    ; passkey_count : int option
         [@key "passkeyCount"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

type t =
  { user_id : string [@key "userId"]
  ; first_name : string option
       [@key "firstName"] [@default None] [@yojson_drop_if Option.is_none]
  ; last_name : string option
       [@key "lastName"] [@default None] [@yojson_drop_if Option.is_none]
  ; user_handle : string option
       [@key "userHandle"] [@default None] [@yojson_drop_if Option.is_none]
  ; email : string option [@default None] [@yojson_drop_if Option.is_none]
  ; mobile : Common.Mobile.t option [@default None] [@yojson_drop_if Option.is_none]
  ; date_of_birth : Common.Date_of_birth.t option
       [@key "dateOfBirth"] [@default None] [@yojson_drop_if Option.is_none]
  ; address : Common.Address.t option [@default None] [@yojson_drop_if Option.is_none]
  ; kyc : Kyc.t option [@key "KYC"] [@default None] [@yojson_drop_if Option.is_none]
  ; created_at : Wire.Num_string.t option
       [@key "createdAt"] [@default None] [@yojson_drop_if Option.is_none]
  ; missing_fields : string list option
       [@key "missingFields"] [@default None] [@yojson_drop_if Option.is_none]
  ; email_verification : Expiry.t option
       [@key "emailVerification"] [@default None] [@yojson_drop_if Option.is_none]
  ; mobile_verification : Expiry.t option
       [@key "mobileVerification"] [@default None] [@yojson_drop_if Option.is_none]
  ; multi_factor_auth : Mfa.t option
       [@key "multiFactorAuth"] [@default None] [@yojson_drop_if Option.is_none]
  }
[@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]

module Kyc_start = struct
  type t =
    { provider : string option [@default None] [@yojson_drop_if Option.is_none]
    ; token : Wire.Hidden_string.t
    ; user_id : string option
         [@key "userId"] [@default None] [@yojson_drop_if Option.is_none]
    ; verification_link : Wire.Hidden_string.t option
         [@key "verificationLink"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp_of, equal, yojson] [@@yojson.allow_extra_fields]
end

let profile_fields ?first_name ?last_name ?email ?mobile ?date_of_birth ?address () =
  [ "firstName", Option.map first_name ~f:(fun s -> `String s)
  ; "lastName", Option.map last_name ~f:(fun s -> `String s)
  ; "email", Option.map email ~f:(fun s -> `String s)
  ; "mobile", Option.map mobile ~f:Common.Mobile.yojson_of_t
  ; "dateOfBirth", Option.map date_of_birth ~f:Common.Date_of_birth.to_request_json
  ; "address", Option.map address ~f:Common.Address.yojson_of_t
  ]
;;

let create tr ~first_name ~last_name ~email ~mobile ?date_of_birth ?address () =
  let body =
    Wire.obj
      (profile_fields ~first_name ~last_name ~email ~mobile ?date_of_birth ?address ())
  in
  Call.json tr `POST "/user/create" ~body ~name:"User.t" t_of_yojson
;;

let update tr ~user_id ?first_name ?last_name ?email ?mobile ?date_of_birth ?address () =
  let body =
    Wire.obj
      (("userId", Some (`String user_id))
       :: profile_fields ?first_name ?last_name ?email ?mobile ?date_of_birth ?address ()
      )
  in
  Call.json tr `PATCH "/user/update" ~body ~name:"User.t" t_of_yojson
;;

let get tr ~user_id = Call.json tr `GET ("/user/" ^ user_id) ~name:"User.t" t_of_yojson

let get_by_email tr ~email =
  Call.read
    tr
    "/user/get-by-email"
    ~body:(`Assoc [ "email", `String email ])
    ~name:"User.t"
    t_of_yojson
;;

let verify_email tr ~user_id ~code =
  Call.unit
    tr
    `POST
    "/user/verify-email"
    ~body:(`Assoc [ "userId", `String user_id; "verificationId", `String code ])
    ()
;;

let verify_mobile tr ~user_id ~code =
  Call.unit
    tr
    `POST
    "/user/verify-mobile"
    ~body:(`Assoc [ "userId", `String user_id; "verificationCode", `String code ])
    ()
;;

let resend_email tr ~user_id =
  Call.unit tr `POST "/user/resend-email" ~body:(`Assoc [ "userId", `String user_id ]) ()
;;

let resend_sms tr ~user_id =
  Call.unit tr `POST "/user/resend-sms" ~body:(`Assoc [ "userId", `String user_id ]) ()
;;

let start_kyc tr ~user_id ?tier ?share_token () =
  Call.json
    tr
    `POST
    "/user/kyc/start"
    ~body:
      (Wire.obj
         [ "userId", Some (`String user_id)
         ; "tier", Option.map tier ~f:(fun i -> `Int i)
         ; "shareToken", Option.map share_token ~f:(fun s -> `String s)
         ])
    ~name:"User.Kyc_start.t"
    Kyc_start.t_of_yojson
;;

let kyc_status tr ~user_id =
  Call.json tr `GET ("/user/kyc/" ^ user_id) ~name:"User.Kyc.t" Kyc.t_of_yojson
;;

module Payment_account_consent = struct
  type t =
    { accepted : bool
    ; date_accepted : string option
         [@key "dateAccepted"] [@default None] [@yojson_drop_if Option.is_none]
    ; ip : string option [@default None] [@yojson_drop_if Option.is_none]
    ; terms_uri : string option
         [@key "termsUri"] [@default None] [@yojson_drop_if Option.is_none]
    ; terms_version : string option
         [@key "termsVersion"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]

  type consent = t [@@deriving sexp, equal, yojson]

  module Record = struct
    type t =
      { user_id : string [@key "userId"]
      ; payment_account_consent : consent option
           [@key "paymentAccountConsent"] [@default None]
      }
    [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
  end
end

let set_payment_account_consent
  tr
  ~user_id
  ~accepted
  ?terms_version
  ?terms_uri
  ?date_accepted
  ?ip
  ()
  =
  (* Each call replaces the stored record, so a retry after a lost response writes the
     same record again. *)
  Call.json
    ~idempotent:true
    tr
    `POST
    "/user/payment-account/consent"
    ~body:
      (Wire.obj
         [ "userId", Some (`String user_id)
         ; "accepted", Some (`Bool accepted)
         ; "termsVersion", Option.map terms_version ~f:(fun s -> `String s)
         ; "termsUri", Option.map terms_uri ~f:(fun s -> `String s)
         ; "dateAccepted", Option.map date_accepted ~f:(fun s -> `String s)
         ; "ip", Option.map ip ~f:(fun s -> `String s)
         ])
    ~name:"User.Payment_account_consent.Record.t"
    Payment_account_consent.Record.t_of_yojson
;;

let payment_account_consent tr ~user_id =
  Call.read
    tr
    "/user/payment-account/consent/get"
    ~body:(`Assoc [ "userId", `String user_id ])
    ~name:"User.Payment_account_consent.Record.t"
    Payment_account_consent.Record.t_of_yojson
;;
