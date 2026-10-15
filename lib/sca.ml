open! Core
open! Async
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Totp_enrollment = struct
  type t =
    { secret : Wire.Hidden_string.t
    ; secret_base32_encoded : Wire.Hidden_string.t option
         [@key "secretBase32Encoded"] [@default None] [@yojson_drop_if Option.is_none]
    ; totp_uri : Wire.Hidden_string.t option
         [@key "totpUri"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp_of, equal, yojson] [@@yojson.allow_extra_fields]
end

module Recovery_codes = struct
  type t =
    { recovery_codes : Wire.Hidden_string.t list [@key "recoveryCodes"] [@default []] }
  [@@deriving sexp_of, equal, yojson] [@@yojson.allow_extra_fields]
end

module Login_challenge = struct
  type t =
    { ok : bool option [@default None] [@yojson_drop_if Option.is_none]
    ; challenge_id : string option
         [@key "challengeId"] [@default None] [@yojson_drop_if Option.is_none]
    ; date_expires : string option
         [@key "dateExpires"] [@default None] [@yojson_drop_if Option.is_none]
    ; options : Wire.Raw_json.t option [@default None] [@yojson_drop_if Option.is_none]
    ; allowed_origins : string list option
         [@key "allowedOrigins"] [@default None] [@yojson_drop_if Option.is_none]
    ; relying_party_id : string option
         [@key "relyingPartyId"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Event = struct
  type t =
    | Reset_password_completed
    | Failed_login_attempt
  [@@deriving sexp, equal]

  let to_string = function
    | Reset_password_completed -> "RESET_PASSWORD_COMPLETED"
    | Failed_login_attempt -> "FAILED_LOGIN_ATTEMPT"
  ;;
end

module Beneficiary = struct
  type t =
    [ `Iban of string
    | `Address of string
    ]
  [@@deriving sexp, equal]

  let field : t -> string * Yojson.Safe.t option = function
    | `Iban id -> "whitelistedIbanId", Some (`String id)
    | `Address id -> "whitelistedAddressId", Some (`String id)
  ;;

  let kind : t -> string = function
    | `Iban _ -> "iban"
    | `Address _ -> "address"
  ;;
end

let s v = Option.map v ~f:(fun s -> `String s)
let vm v = Option.map v ~f:Common.Verification_method.yojson_of_t
let vm_json = Common.Verification_method.yojson_of_t
let raw = Wire.Raw_json.t_of_yojson

let start_totp tr ~user_id =
  Call.json
    tr
    `POST
    "/user/start/setup-two-factor"
    ~body:(`Assoc [ "userId", `String user_id ])
    ~name:"Sca.Totp_enrollment.t"
    Totp_enrollment.t_of_yojson
;;

let complete_totp tr ~user_id ~secret ~code =
  Call.json
    tr
    `POST
    "/user/resume/setup-two-factor"
    ~body:
      (`Assoc
        [ "userId", `String user_id; "secret", `String secret; "code", `String code ])
    ~name:"Sca.Recovery_codes.t"
    Recovery_codes.t_of_yojson
;;

let login_start tr ~user_id ~verification_method =
  Call.json
    tr
    `POST
    "/user/login/start"
    ~body:
      (`Assoc
        [ "userId", `String user_id
        ; "verificationMethod", Common.Verification_method.yojson_of_t verification_method
        ])
    ~name:"Sca.Login_challenge.t"
    Login_challenge.t_of_yojson
;;

let login_complete tr ~user_id ~verification_method ~ip ?challenge_id ?code () =
  Call.json
    tr
    `POST
    "/user/login/complete"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "verificationMethod", vm (Some verification_method)
         ; "ip", s (Some ip)
         ; "challengeId", s challenge_id
         ; "code", s code
         ])
    ~name:"login status"
    raw
;;

let record_event tr ~user_id ~event =
  Call.json
    tr
    `POST
    "/user/record-event"
    ~body:(`Assoc [ "userId", `String user_id; "event", `String (Event.to_string event) ])
    ~name:"recorded event"
    raw
;;

let beneficiary_call path tr ~user_id b ?verification_method fields =
  Call.json
    tr
    `POST
    path
    ~body:
      (Wire.obj
         ([ "userId", s (Some user_id)
          ; Beneficiary.field b
          ; "verificationMethod", vm verification_method
          ]
          @ fields))
    ~name:"beneficiary"
    raw
;;

let trust tr ~user_id b ?verification_method () =
  beneficiary_call
    (sprintf "/wallets/beneficiary/%s/trust" (Beneficiary.kind b))
    tr
    ~user_id
    b
    ?verification_method
    []
;;

let untrust tr ~user_id b ?verification_method () =
  beneficiary_call
    (sprintf "/wallets/beneficiary/%s/untrust" (Beneficiary.kind b))
    tr
    ~user_id
    b
    ?verification_method
    []
;;

let confirm_trust tr ~user_id b ?verification_method ?challenge_id ?code () =
  beneficiary_call
    "/wallets/beneficiary/confirm-trust"
    tr
    ~user_id
    b
    ?verification_method
    [ "challengeId", s challenge_id; "code", s code ]
;;

let confirm_untrust tr ~user_id b ?verification_method ?challenge_id ?code () =
  beneficiary_call
    "/wallets/beneficiary/confirm-untrust"
    tr
    ~user_id
    b
    ?verification_method
    [ "challengeId", s challenge_id; "code", s code ]
;;

let list_passkeys tr ~user_id =
  Call.read
    tr
    "/user/passkey/list"
    ~body:(`Assoc [ "userId", `String user_id ])
    ~name:"passkeys"
    raw
;;

module Reset_2fa = struct
  module Initiated = struct
    type t =
      { reset_id : string [@key "resetId"]
      ; sumsub_access_token : Wire.Hidden_string.t option
           [@key "sumsubAccessToken"] [@default None] [@yojson_drop_if Option.is_none]
      ; verification_link : Wire.Hidden_string.t option
           [@key "verificationLink"] [@default None] [@yojson_drop_if Option.is_none]
      ; expires_at : string option
           [@key "expiresAt"] [@default None] [@yojson_drop_if Option.is_none]
      }
    [@@deriving sexp_of, equal, yojson] [@@yojson.allow_extra_fields]
  end

  module Status = struct
    type t =
      { reset_id : string option
           [@key "resetId"] [@default None] [@yojson_drop_if Option.is_none]
      ; factor : Common.Verification_method.t option
           [@default None] [@yojson_drop_if Option.is_none]
      ; status : string option [@default None] [@yojson_drop_if Option.is_none]
      ; enrollment_status : string option
           [@key "enrollmentStatus"] [@default None] [@yojson_drop_if Option.is_none]
      ; expires_at : string option
           [@key "expiresAt"] [@default None] [@yojson_drop_if Option.is_none]
      ; completed_at : string option
           [@key "completedAt"] [@default None] [@yojson_drop_if Option.is_none]
      }
    [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
  end

  module Completed = struct
    type t =
      { factor : Common.Verification_method.t option
           [@default None] [@yojson_drop_if Option.is_none]
      ; ok : bool option [@default None] [@yojson_drop_if Option.is_none]
      ; secret : Wire.Hidden_string.t option
           [@default None] [@yojson_drop_if Option.is_none]
      ; secret_base32_encoded : Wire.Hidden_string.t option
           [@key "secretBase32Encoded"] [@default None] [@yojson_drop_if Option.is_none]
      ; totp_uri : Wire.Hidden_string.t option
           [@key "totpUri"] [@default None] [@yojson_drop_if Option.is_none]
      ; options : Wire.Raw_json.t option [@default None] [@yojson_drop_if Option.is_none]
      ; allowed_origins : string list option
           [@key "allowedOrigins"] [@default None] [@yojson_drop_if Option.is_none]
      ; relying_party_id : string option
           [@key "relyingPartyId"] [@default None] [@yojson_drop_if Option.is_none]
      }
    [@@deriving sexp_of, equal, yojson] [@@yojson.allow_extra_fields]
  end
end

let reset_2fa_initiate tr ~user_id ~factor =
  Call.json
    tr
    `POST
    "/user/2fa/reset/initiate"
    ~body:(`Assoc [ "userId", `String user_id; "factor", vm_json factor ])
    ~name:"Sca.Reset_2fa.Initiated.t"
    Reset_2fa.Initiated.t_of_yojson
;;

let reset_2fa_status tr ~user_id ~reset_id =
  Call.read
    tr
    "/user/2fa/reset/status"
    ~body:(`Assoc [ "userId", `String user_id; "resetId", `String reset_id ])
    ~name:"Sca.Reset_2fa.Status.t"
    Reset_2fa.Status.t_of_yojson
;;

let reset_2fa_complete tr ~user_id ~reset_id ?mobile () =
  Call.json
    tr
    `POST
    "/user/2fa/reset/complete"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "resetId", s (Some reset_id)
         ; "mobile", Option.map mobile ~f:Common.Mobile.yojson_of_t
         ])
    ~name:"Sca.Reset_2fa.Completed.t"
    Reset_2fa.Completed.t_of_yojson
;;
