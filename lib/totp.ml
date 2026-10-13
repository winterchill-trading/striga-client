open! Core

let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

let base32_decode s =
  let s = String.uppercase (String.filter s ~f:(fun c -> not (Char.equal c '='))) in
  let buf = Buffer.create (String.length s * 5 / 8) in
  let rec go i acc bits =
    if i = String.length s
    then Ok (Buffer.contents buf)
    else (
      match String.index alphabet s.[i] with
      | None -> Or_error.error_s [%message "not base32" ~char:(s.[i] : char)]
      | Some v ->
        let acc = (acc lsl 5) lor v
        and bits = bits + 5 in
        if bits >= 8
        then (
          Buffer.add_char buf (Char.of_int_exn ((acc lsr (bits - 8)) land 0xff));
          go (i + 1) (acc land ((1 lsl (bits - 8)) - 1)) (bits - 8))
        else go (i + 1) acc bits)
  in
  go 0 0 0
;;

let code ?(digits = 6) ~key time =
  let counter = Time_ns.to_int_ns_since_epoch time / 1_000_000_000 / 30 in
  let msg = Bytes.create 8 in
  for i = 0 to 7 do
    Bytes.set msg (7 - i) (Char.of_int_exn ((counter asr (8 * i)) land 0xff))
  done;
  let mac =
    Cryptokit.hash_string (Cryptokit.MAC.hmac_sha1 key) (Bytes.to_string msg)
  in
  let byte i = Char.to_int mac.[i] in
  let offset = byte 19 land 0x0f in
  let bin =
    ((byte offset land 0x7f) lsl 24)
    lor (byte (offset + 1) lsl 16)
    lor (byte (offset + 2) lsl 8)
    lor byte (offset + 3)
  in
  let modulus = Int.pow 10 digits in
  sprintf "%0*d" digits (bin % modulus)
;;

let code_of_base32 ?digits secret time =
  Or_error.map (base32_decode secret) ~f:(fun key -> code ?digits ~key time)
;;
