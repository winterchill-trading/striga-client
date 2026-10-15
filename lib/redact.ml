open! Core

let keep_last n s =
  let len = String.length s in
  if len <= n then s else String.make (len - n) '*' ^ String.suffix s n
;;

let is_iban_shaped s =
  let len = String.length s in
  len >= 15
  && len <= 34
  && Char.is_uppercase s.[0]
  && Char.is_uppercase s.[1]
  && Char.is_digit s.[2]
  && Char.is_digit s.[3]
  && String.for_all s ~f:(fun c -> Char.is_digit c || Char.is_uppercase c)
;;

let iban s =
  if is_iban_shaped s then String.prefix s 2 ^ keep_last 4 (String.drop_prefix s 2) else s
;;

let pan s = keep_last 4 s

let luhn_valid digits =
  let n = String.length digits in
  n > 0
  && String.for_all digits ~f:Char.is_digit
  &&
  let sum = ref 0 in
  for i = 0 to n - 1 do
    let d = Char.get_digit_exn digits.[n - 1 - i] in
    let d = if i % 2 = 1 then if d * 2 > 9 then (d * 2) - 9 else d * 2 else d in
    sum := !sum + d
  done;
  !sum % 10 = 0
;;

(* Split into maximal alphanumeric words and the separators between them, mask each word
   that is an IBAN or a card number, and glue everything back. *)
let mask_words text =
  let buf = Buffer.create (String.length text) in
  let n = String.length text in
  let rec go i =
    if i < n
    then
      if Char.is_alphanum text.[i]
      then (
        let j = ref i in
        while !j < n && Char.is_alphanum text.[!j] do
          incr j
        done;
        let word = String.sub text ~pos:i ~len:(!j - i) in
        let len = String.length word in
        let word =
          if is_iban_shaped word
          then iban word
          else if len >= 13 && len <= 19 && luhn_valid word
          then pan word
          else word
        in
        Buffer.add_string buf word;
        go !j)
      else (
        Buffer.add_char buf text.[i];
        go (i + 1))
  in
  go 0;
  Buffer.contents buf
;;

let text ?(secrets = []) s =
  List.fold secrets ~init:s ~f:(fun acc secret -> Secret.redact secret acc) |> mask_words
;;

let sensitive_fields =
  [ "token" (* SumSub access token from /user/kyc/start *)
  ; "verificationLink"
  ; "cardAuthToken"
  ; "secret"
  ; "secretBase32Encoded"
  ; "totpUri"
  ; "recoveryCodes"
  ; "pin"
  ; "threeDSecurePassword"
  ; "verificationCode"
  ; "verificationId"
  ; "code"
  ; "shareToken"
  ; "sumsubAccessToken" (* 2FA reset identity check *)
  ]
;;

let rec json ?secrets (v : Yojson.Safe.t) : Yojson.Safe.t =
  match v with
  | `Assoc fields ->
    `Assoc
      (List.map fields ~f:(fun (k, v) ->
         if List.mem sensitive_fields k ~equal:String.equal
         then k, `String "<redacted>"
         else (
           match k, v with
           | ("iban" | "bankingSenderIban"), `String s -> k, `String (iban s)
           | "accountNumber", `String s -> k, `String (keep_last 4 s)
           | _ -> k, json ?secrets v)))
  | `List l -> `List (List.map l ~f:(json ?secrets))
  | `String s -> `String (text ?secrets s)
  | other -> other
;;
