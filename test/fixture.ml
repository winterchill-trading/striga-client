open! Core

let load name = Yojson.Safe.from_file ("fixtures/" ^ name)

(* Decode a recorded body, encode it back and decode again: the two values must be equal,
   which is what "stable JSON types" means here. *)
let roundtrip
  (type a)
  name
  (of_yojson : Yojson.Safe.t -> a)
  (to_yojson : a -> Yojson.Safe.t)
  (equal : a -> a -> bool)
  =
  let v = of_yojson (load name) in
  let again = of_yojson (Yojson.Safe.from_string (Yojson.Safe.to_string (to_yojson v))) in
  if not (equal v again) then raise_s [%message "round trip changed the value" name];
  v
;;
