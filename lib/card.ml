open! Core
open! Async
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Card_type = struct
  module T = struct
    type t =
      | Virtual
      | Physical
      | Physical_anonymous
      | Other of string
    [@@deriving sexp, equal, compare]

    let table =
      [ Virtual, "VIRTUAL"
      ; Physical, "PHYSICAL"
      ; Physical_anonymous, "PHYSICAL_ANONYMOUS"
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

module Status = struct
  module T = struct
    type t =
      | Created
      | Dispatched
      | Active
      | Activated
      | Blocked
      | Closed
      | Expired
      | Other of string
    [@@deriving sexp, equal, compare]

    let table =
      [ Created, "CREATED"
      ; Dispatched, "DISPATCHED"
      ; Active, "ACTIVE"
      ; Activated, "ACTIVATED"
      ; Blocked, "BLOCKED"
      ; Closed, "CLOSED"
      ; Expired, "EXPIRED"
      ]
    ;;

    (* One docs example says "Created"; match case-insensitively before giving up. *)
    let other s =
      match List.find table ~f:(fun (_, n) -> String.Caseless.equal n s) with
      | Some (v, _) -> v
      | None -> Other s
    ;;

    let to_other = function
      | Other s -> Some s
      | _ -> None
    ;;
  end

  include T
  include Wire.Enum.Make (T)
end

module Card_address = struct
  type t =
    { address_line1 : string option
         [@key "addressLine1"] [@default None] [@yojson_drop_if Option.is_none]
    ; address_line2 : string option
         [@key "addressLine2"] [@default None] [@yojson_drop_if Option.is_none]
    ; city : string option [@default None] [@yojson_drop_if Option.is_none]
    ; postal_code : string option
         [@key "postalCode"] [@default None] [@yojson_drop_if Option.is_none]
    ; country : string option [@default None] [@yojson_drop_if Option.is_none]
    ; country_code : string option
         [@key "countryCode"] [@default None] [@yojson_drop_if Option.is_none]
    ; dispatch_method : string option
         [@key "dispatchMethod"] [@default None] [@yojson_drop_if Option.is_none]
    ; tracking_number : string option
         [@key "trackingNumber"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Security = struct
  type t =
    { contactless_enabled : bool option
         [@key "contactlessEnabled"] [@default None] [@yojson_drop_if Option.is_none]
    ; withdrawal_enabled : bool option
         [@key "withdrawalEnabled"] [@default None] [@yojson_drop_if Option.is_none]
    ; internet_purchase_enabled : bool option
         [@key "internetPurchaseEnabled"] [@default None] [@yojson_drop_if Option.is_none]
    ; overall_limits_enabled : bool option
         [@key "overallLimitsEnabled"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Limits = struct
  type t = (string * int) list [@@deriving sexp, equal]

  let t_of_yojson (json : Yojson.Safe.t) =
    match json with
    | `Assoc fields ->
      List.filter_map fields ~f:(fun (k, v) ->
        match v with
        | `Int i -> Some (k, i)
        | `Float f -> Some (k, Float.iround_nearest_exn f)
        | _ -> None)
    | _ ->
      raise
        (Ppx_yojson_conv_lib.Yojson_conv.Of_yojson_error
           (Failure "limits: expected an object", json))
  ;;

  let yojson_of_t t : Yojson.Safe.t = `Assoc (List.map t ~f:(fun (k, v) -> k, `Int v))
  let find t name = List.Assoc.find t name ~equal:String.equal
end

type t =
  { id : string
  ; name : string option [@default None] [@yojson_drop_if Option.is_none]
  ; type_ : Card_type.t option
       [@key "type"] [@default None] [@yojson_drop_if Option.is_none]
  ; user_id : string option
       [@key "userId"] [@default None] [@yojson_drop_if Option.is_none]
  ; masked_card_number : string option
       [@key "maskedCardNumber"] [@default None] [@yojson_drop_if Option.is_none]
  ; expiry_data : string option
       [@key "expiryData"] [@default None] [@yojson_drop_if Option.is_none]
  ; expiry_date : string option
       [@key "expiryDate"] [@default None] [@yojson_drop_if Option.is_none]
  ; status : Status.t option [@default None] [@yojson_drop_if Option.is_none]
  ; address : Card_address.t option [@default None] [@yojson_drop_if Option.is_none]
  ; delivery_address : Card_address.t option
       [@key "deliveryAddress"] [@default None] [@yojson_drop_if Option.is_none]
  ; is_enrolled_for_3d_secure : bool option
       [@key "isEnrolledFor3dSecure"] [@default None] [@yojson_drop_if Option.is_none]
  ; is_card_3d_secure_activated : bool option
       [@key "isCard3dSecureActivated"] [@default None] [@yojson_drop_if Option.is_none]
  ; security : Security.t option [@default None] [@yojson_drop_if Option.is_none]
  ; limits : Limits.t option [@default None] [@yojson_drop_if Option.is_none]
  ; activated_at : string option
       [@key "activatedAt"] [@default None] [@yojson_drop_if Option.is_none]
  ; linked_account_id : string option
       [@key "linkedAccountId"] [@default None] [@yojson_drop_if Option.is_none]
  ; parent_wallet_id : string option
       [@key "parentWalletId"] [@default None] [@yojson_drop_if Option.is_none]
  ; linked_account_currency : string option
       [@key "linkedAccountCurrency"] [@default None] [@yojson_drop_if Option.is_none]
  ; last_linked_account_id : string option
       [@key "lastLinkedAccountId"] [@default None] [@yojson_drop_if Option.is_none]
  ; created_at : string option
       [@key "createdAt"] [@default None] [@yojson_drop_if Option.is_none]
  ; fee : Wire.Raw_json.t option [@default None] [@yojson_drop_if Option.is_none]
  }
[@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]

module Page = struct
  type card = t [@@deriving sexp, equal, yojson]

  type t =
    { cards : card list [@default []]
    ; count : int option [@default None] [@yojson_drop_if Option.is_none]
    ; total : int option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Card_transaction = struct
  type t =
    { card_id : string option
         [@key "cardId"] [@default None] [@yojson_drop_if Option.is_none]
    ; related_card_transaction_id : string option
         [@key "relatedCardTransactionId"]
         [@default None]
         [@yojson_drop_if Option.is_none]
    ; type_ : Transaction.Tx_type.t option
         [@key "type"] [@default None] [@yojson_drop_if Option.is_none]
    ; original_amount : Wire.Num_string.t option
         [@key "originalAmount"] [@default None] [@yojson_drop_if Option.is_none]
    ; original_currency : string option
         [@key "originalCurrency"] [@default None] [@yojson_drop_if Option.is_none]
    ; transaction_amount : Wire.Num_string.t option
         [@key "transactionAmount"] [@default None] [@yojson_drop_if Option.is_none]
    ; transaction_currency : string option
         [@key "transactionCurrency"] [@default None] [@yojson_drop_if Option.is_none]
    ; merchant_id : string option
         [@key "merchantId"] [@default None] [@yojson_drop_if Option.is_none]
    ; merchant_name : string option
         [@key "merchantName"] [@default None] [@yojson_drop_if Option.is_none]
    ; merchant_city : string option
         [@key "merchantCity"] [@default None] [@yojson_drop_if Option.is_none]
    ; merchant_country_code : string option
         [@key "merchantCountryCode"] [@default None] [@yojson_drop_if Option.is_none]
    ; merchant_category_code : string option
         [@key "merchantCategoryCode"] [@default None] [@yojson_drop_if Option.is_none]
    ; account_transaction_id : string option
         [@key "accountTransactionId"] [@default None] [@yojson_drop_if Option.is_none]
    ; order : Wire.Raw_json.t option [@default None] [@yojson_drop_if Option.is_none]
    ; linked_account_id : string option
         [@key "linkedAccountId"] [@default None] [@yojson_drop_if Option.is_none]
    ; linked_account_currency : string option
         [@key "linkedAccountCurrency"] [@default None] [@yojson_drop_if Option.is_none]
    ; parent_wallet_id : string option
         [@key "parentWalletId"] [@default None] [@yojson_drop_if Option.is_none]
    ; created_at : string option
         [@key "createdAt"] [@default None] [@yojson_drop_if Option.is_none]
    ; decline_details : string option
         [@key "declineDetails"] [@default None] [@yojson_drop_if Option.is_none]
    ; merchant_transaction_amount : Wire.Num_string.t option
         [@key "merchantTransactionAmount"]
         [@default None]
         [@yojson_drop_if Option.is_none]
    ; merchant_transaction_currency : string option
         [@key "merchantTransactionCurrency"]
         [@default None]
         [@yojson_drop_if Option.is_none]
    ; account_transaction_amount : Wire.Num_string.t option
         [@key "accountTransactionAmount"]
         [@default None]
         [@yojson_drop_if Option.is_none]
    ; account_transaction_currency : string option
         [@key "accountTransactionCurrency"]
         [@default None]
         [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]

  module Page = struct
    type card_transaction = t [@@deriving sexp, equal, yojson]

    type t =
      { transactions : card_transaction list [@default []]
      ; count : int option [@default None] [@yojson_drop_if Option.is_none]
      ; total : int option [@default None] [@yojson_drop_if Option.is_none]
      }
    [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
  end
end

module Consent = struct
  type t = { card_auth_token : Wire.Hidden_string.t [@key "cardAuthToken"] }
  [@@deriving sexp_of, equal, yojson] [@@yojson.allow_extra_fields]
end

module Pan_ui = struct
  let browser_options (config : Config.t) =
    match config.application_id, config.ui_secret with
    | Some application_id, Some ui_secret ->
      Ok
        (`Assoc
          [ "uiSecret", `String (Secret.reveal ui_secret)
          ; "applicationId", `String application_id
          ])
    | _ ->
      Or_error.error_string
        "the card PAN UI needs STRIGA_APPLICATION_ID and STRIGA_UI_SECRET"
  ;;
end

let s v = Option.map v ~f:(fun s -> `String s)
let card = t_of_yojson
let card_body card_id fields = Wire.obj (("cardId", Some (`String card_id)) :: fields)

let create
  tr
  ~user_id
  ~name_on_card
  ~three_d_secure_password
  ~type_
  ?account_id_to_link
  ?address
  ()
  =
  Call.json
    tr
    `POST
    "/card/create"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "nameOnCard", s (Some name_on_card)
         ; "threeDSecurePassword", s (Some three_d_secure_password)
         ; "type", Some (Card_type.yojson_of_t type_)
         ; "accountIdToLink", s account_id_to_link
         ; "address", Option.map address ~f:Card_address.yojson_of_t
         ])
    ~name:"Card.t"
    card
;;

let get tr ~card_id = Call.json tr `GET ("/card/" ^ card_id) ~name:"Card.t" card

let get_all tr ~user_id ?(limit = 100) ?(offset = 0) () =
  Call.read
    tr
    "/card/get-all"
    ~body:
      (`Assoc [ "userId", `String user_id; "limit", `Int limit; "offset", `Int offset ])
    ~name:"Card.Page.t"
    Page.t_of_yojson
;;

let unit_action path tr ~card_id = Call.unit tr `POST path ~body:(card_body card_id []) ()
let block = unit_action "/card/block"
let unblock = unit_action "/card/unblock"

let burn tr ~card_id =
  Call.json tr `POST "/card/burn" ~body:(card_body card_id []) ~name:"Card.t" card
;;

let report_missing tr ~card_id =
  Call.json
    tr
    `POST
    "/card/report-missing"
    ~body:(card_body card_id [])
    ~name:"Card.t"
    card
;;

let update_limits tr ~card_id ~limits =
  Call.json
    tr
    `PATCH
    "/card/limits"
    ~body:(card_body card_id [ "limits", Some (Limits.yojson_of_t limits) ])
    ~name:"Card.t"
    card
;;

let update_security tr ~card_id ~contactless ~withdrawal ~internet_purchase =
  Call.json
    tr
    `PATCH
    "/card/security"
    ~body:
      (card_body
         card_id
         [ ( "security"
           , Some
               (`Assoc
                 [ "contactlessEnabled", `Bool contactless
                 ; "withdrawalEnabled", `Bool withdrawal
                 ; "internetPurchaseEnabled", `Bool internet_purchase
                 ]) )
         ])
    ~name:"Card.t"
    card
;;

let update_3ds tr ~card_id ~three_d_secure_password =
  Call.unit
    tr
    `PATCH
    "/card/3ds"
    ~body:
      (card_body
         card_id
         [ "threeDSecurePassword", Some (`String three_d_secure_password) ])
    ()
;;

let set_pin tr ~card_id ~pin =
  Call.unit
    tr
    `PATCH
    "/card/set-pin"
    ~body:(card_body card_id [ "pin", Some (`String pin) ])
    ()
;;

let link_account tr ~card_id ~account_id =
  Call.json
    tr
    `PATCH
    "/card/link-account"
    ~body:(card_body card_id [ "accountId", Some (`String account_id) ])
    ~name:"Card link"
    Wire.Raw_json.t_of_yojson
;;

let statement tr ~card_id ~start ~stop ?(page = 1) ?limit () =
  Call.read
    tr
    "/card/statement"
    ~body:
      (card_body
         card_id
         [ "startDate", Some (Call.ms start)
         ; "endDate", Some (Call.ms stop)
         ; "page", Some (`Int page)
         ; "limit", Option.map limit ~f:(fun l -> `Int l)
         ])
    ~name:"Card.Card_transaction.Page.t"
    Card_transaction.Page.t_of_yojson
;;

let confirm_consent tr ~user_id ~challenge_id ~code =
  Call.json
    tr
    `POST
    "/card/confirm-consent"
    ~body:
      (`Assoc
        [ "userId", `String user_id
        ; "challengeId", `String challenge_id
        ; "verificationCode", `String code
        ])
    ~name:"Card.Consent.t"
    Consent.t_of_yojson
;;

let resend_consent_code tr ~user_id ~challenge_id =
  Call.json
    tr
    `POST
    "/card/resend-consent-code"
    ~body:(`Assoc [ "userId", `String user_id; "challengeId", `String challenge_id ])
    ~name:"Common.Challenge.t"
    Common.Challenge.t_of_yojson
;;

let revoke_consents tr ~user_id =
  Call.unit
    tr
    `POST
    "/card/revoke-consents"
    ~body:(`Assoc [ "userId", `String user_id ])
    ()
;;
