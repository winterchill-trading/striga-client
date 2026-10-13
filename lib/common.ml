open! Core
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Mobile = struct
  type t =
    { country_code : string [@key "countryCode"]
    ; number : string
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Address = struct
  type t =
    { address_line1 : string [@key "addressLine1"]
    ; address_line2 : string option
         [@key "addressLine2"] [@default None] [@yojson_drop_if Option.is_none]
    ; city : string
    ; postal_code : string [@key "postalCode"]
    ; state : string option [@default None] [@yojson_drop_if Option.is_none]
    ; country : string
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Date_of_birth = struct
  type t =
    { year : Wire.Num_string.t
    ; month : Wire.Num_string.t
    ; day : Wire.Num_string.t
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]

  let create ~year ~month ~day =
    { year = Int.to_string year; month = Int.to_string month; day = Int.to_string day }
  ;;

  let to_request_json t : Yojson.Safe.t =
    let n s = `Int (Int.of_string s) in
    `Assoc [ "year", n t.year; "month", n t.month; "day", n t.day ]
  ;;
end

module Verification_method = struct
  module T = struct
    type t =
      | Sms
      | Totp
      | Passkey
      | Other of string
    [@@deriving sexp, equal, compare]

    let table = [ Sms, "sms"; Totp, "totp"; Passkey, "passkey" ]
    let other s = Other s

    let to_other = function
      | Other s -> Some s
      | _ -> None
    ;;
  end

  include T
  include Wire.Enum.Make (T)
end

module Challenge = struct
  type t =
    { challenge_id : string [@key "challengeId"]
    ; date_expires : string option
         [@key "dateExpires"] [@default None] [@yojson_drop_if Option.is_none]
    ; attempts : int option [@default None] [@yojson_drop_if Option.is_none]
    ; verification_method : Verification_method.t option
         [@key "verificationMethod"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Blockchain_network = struct
  type t =
    { name : string
    ; network : string option [@default None] [@yojson_drop_if Option.is_none]
    ; type_ : string option [@key "type"] [@default None] [@yojson_drop_if Option.is_none]
    ; contract_address : string option
         [@key "contractAddress"] [@default None] [@yojson_drop_if Option.is_none]
    ; blockchain_deposit_address : string option
         [@key "blockchainDepositAddress"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Balance = struct
  type t =
    { amount : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    ; balance : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    ; currency : string option [@default None] [@yojson_drop_if Option.is_none]
    ; h_amount : string option
         [@key "hAmount"] [@default None] [@yojson_drop_if Option.is_none]
    ; fiat_equivalent_balance : Wire.Num_string.t option
         [@key "fiatEquivalentBalance"] [@default None] [@yojson_drop_if Option.is_none]
    ; fiat_currency : string option
         [@key "fiatCurrency"] [@default None] [@yojson_drop_if Option.is_none]
    ; h_fiat_equivalent_balance : string option
         [@key "hFiatEquivalentBalance"] [@default None] [@yojson_drop_if Option.is_none]
    ; rate : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Fee_estimate = struct
  type t =
    { total_fee : Wire.Num_string.t option
         [@key "totalFee"] [@default None] [@yojson_drop_if Option.is_none]
    ; network_fee : Wire.Num_string.t option
         [@key "networkFee"] [@default None] [@yojson_drop_if Option.is_none]
    ; our_fee : Wire.Num_string.t option
         [@key "ourFee"] [@default None] [@yojson_drop_if Option.is_none]
    ; their_fee : Wire.Num_string.t option
         [@key "theirFee"] [@default None] [@yojson_drop_if Option.is_none]
    ; fee_currency : string option
         [@key "feeCurrency"] [@default None] [@yojson_drop_if Option.is_none]
    ; gas_limit : Wire.Num_string.t option
         [@key "gasLimit"] [@default None] [@yojson_drop_if Option.is_none]
    ; gas_price : Wire.Num_string.t option
         [@key "gasPrice"] [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end
