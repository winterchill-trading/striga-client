open! Core
open! Async
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Rate = struct
  type t =
    { price : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    ; buy : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    ; sell : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    ; timestamp : Wire.Num_string.t option [@default None] [@yojson_drop_if Option.is_none]
    ; h_timestamp : string option
         [@key "hTimestamp"] [@default None] [@yojson_drop_if Option.is_none]
    ; currency : string option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end

module Rates = struct
  type t = (string * Rate.t) list [@@deriving sexp, equal]

  let t_of_yojson (json : Yojson.Safe.t) =
    match json with
    | `Assoc fields -> List.map fields ~f:(fun (ticker, r) -> ticker, Rate.t_of_yojson r)
    | _ ->
      raise
        (Ppx_yojson_conv_lib.Yojson_conv.Of_yojson_error
           (Failure "rates: expected an object keyed by ticker", json))
  ;;

  let yojson_of_t t : Yojson.Safe.t =
    `Assoc (List.map t ~f:(fun (ticker, r) -> ticker, Rate.yojson_of_t r))
  ;;

  let find t ~ticker = List.Assoc.find t ticker ~equal:String.equal
end

let rates tr = Call.read tr "/trade/rates" ~body:(`Assoc []) ~name:"Exchange.Rates.t" Rates.t_of_yojson

let swap
  tr
  ~user_id
  ~source_account_id
  ~destination_account_id
  ~amount
  ~ip
  ?memo
  ?proposed_rate
  ?verification_method
  ()
  =
  let s v = Option.map v ~f:(fun s -> `String s) in
  Call.json
    tr
    `POST
    "/wallets/swap"
    ~body:
      (Wire.obj
         [ "userId", s (Some user_id)
         ; "sourceAccountId", s (Some source_account_id)
         ; "destinationAccountId", s (Some destination_account_id)
         ; "amount", s (Some amount)
         ; "ip", s (Some ip)
         ; "memo", s memo
         ; "proposedRate", s proposed_rate
         ; ( "verificationMethod"
           , Option.map verification_method ~f:Common.Verification_method.yojson_of_t )
         ])
    ~name:"Payment.Initiated.t"
    Payment.Initiated.t_of_yojson
;;
