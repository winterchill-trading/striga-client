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
