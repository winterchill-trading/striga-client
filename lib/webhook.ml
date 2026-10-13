open! Core

module Event = struct
  type t =
    | Kyc of User.Kyc.t
    | Transaction of Transaction.t
    | Card_transaction of Card.Card_transaction.t
    | Card_status of Wire.Raw_json.t
    | Ping of Wire.Raw_json.t
    | Other of
        { path : string
        ; body : Wire.Raw_json.t
        }
  [@@deriving sexp_of]
end

let has field (json : Yojson.Safe.t) =
  match json with
  | `Assoc fields -> List.Assoc.mem fields field ~equal:String.equal
  | _ -> false
;;

let parse ~path ~body =
  let open Or_error.Let_syntax in
  let%bind json =
    Or_error.try_with (fun () -> Yojson.Safe.from_string body)
    |> Or_error.tag ~tag:"webhook body is not JSON"
  in
  let ends suffix = String.is_suffix (String.chop_suffix_if_exists path ~suffix:"/") ~suffix in
  if ends "/kyc"
  then Wire.decode "User.Kyc.t" User.Kyc.t_of_yojson json >>| fun k -> Event.Kyc k
  else if ends "/tx"
  then
    if has "cardId" json || has "merchantName" json
    then
      Wire.decode "Card.Card_transaction.t" Card.Card_transaction.t_of_yojson json
      >>| fun c -> Event.Card_transaction c
    else if has "txType" json
    then
      Wire.decode "Transaction.t" Transaction.t_of_yojson json
      >>| fun t -> Event.Transaction t
    else return (Event.Other { path; body = json })
  else if ends "/card/watch"
  then return (Event.Card_status json)
  else if ends "/ping"
  then return (Event.Ping json)
  else return (Event.Other { path; body = json })
;;

let verify_and_parse ~api_key ~path ~headers ~body =
  match
    List.find_map headers ~f:(fun (k, v) ->
      if String.Caseless.equal k "signature" then Some v else None)
  with
  | None -> Or_error.error_string "webhook has no signature header"
  | Some signature ->
    if Signature.verify_webhook ~api_key ~body ~signature
    then parse ~path ~body
    else Or_error.error_string "webhook signature does not match"
;;
