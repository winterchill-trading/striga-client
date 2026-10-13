(** Endpoint plumbing for the resource modules: call, check, decode. *)

open! Core
open! Async

val json
  :  ?idempotent:bool
  -> Transport.t
  -> Transport.Meth.t
  -> string
  -> ?body:Yojson.Safe.t
  -> name:string
  -> (Yojson.Safe.t -> 'a)
  -> 'a Or_error.t Deferred.t

val unit
  :  ?idempotent:bool
  -> Transport.t
  -> Transport.Meth.t
  -> string
  -> ?body:Yojson.Safe.t
  -> unit
  -> unit Or_error.t Deferred.t

(** Read-only POST (Striga uses POST for most reads); retried on 429/5xx. *)
val read
  :  Transport.t
  -> string
  -> body:Yojson.Safe.t
  -> name:string
  -> (Yojson.Safe.t -> 'a)
  -> 'a Or_error.t Deferred.t

(** Epoch milliseconds, as Striga's date-range filters want them. *)
val ms : Time_ns.t -> Yojson.Safe.t
