open! Core
open! Async

let json ?idempotent t meth path ?body ~name of_yojson =
  match%map Transport.json ?idempotent t meth path ?body () with
  | Error _ as e -> e
  | Ok json -> Wire.decode name of_yojson json
;;

let unit = Transport.unit
let read t path ~body ~name of_yojson = json ~idempotent:true t `POST path ~body ~name of_yojson
let ms time : Yojson.Safe.t = `Int (Time_ns.to_int_ns_since_epoch time / 1_000_000)
