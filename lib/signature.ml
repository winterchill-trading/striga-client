open! Core

let hex s = Cryptokit.transform_string (Cryptokit.Hexa.encode ()) s
let empty_body = "{}"

let body_digest body =
  hex
    (Cryptokit.hash_string
       (Cryptokit.Hash.md5 ())
       (Option.value body ~default:empty_body))
;;

let signing_input ~time_ms ~meth ~path ~body =
  String.concat [ time_ms; meth; path; body_digest body ]
;;

let hmac_sha256 ~key data =
  hex (Cryptokit.hash_string (Cryptokit.MAC.hmac_sha256 key) data)
;;

let authorization ~secret ~time_ms ~meth ~path ~body =
  let mac =
    hmac_sha256 ~key:(Secret.reveal secret) (signing_input ~time_ms ~meth ~path ~body)
  in
  "HMAC " ^ time_ms ^ ":" ^ mac
;;

let webhook_signature ~api_key body = hmac_sha256 ~key:(Secret.reveal api_key) body

let constant_time_equal a b =
  String.length a = String.length b
  && String.foldi a ~init:0 ~f:(fun i acc c ->
       acc lor (Char.to_int c lxor Char.to_int b.[i]))
     = 0
;;

let verify_webhook ~api_key ~body ~signature =
  let signature = String.lowercase (String.strip signature) in
  let matches text = constant_time_equal (webhook_signature ~api_key text) signature in
  matches body
  ||
  match Yojson.Safe.from_string body with
  | json -> matches (Yojson.Safe.to_string json)
  | exception _ -> false
;;
