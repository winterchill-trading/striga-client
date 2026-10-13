open! Core

val load : string -> Yojson.Safe.t

val roundtrip
  :  string
  -> (Yojson.Safe.t -> 'a)
  -> ('a -> Yojson.Safe.t)
  -> ('a -> 'a -> bool)
  -> 'a
