(** HTTP transport: [api-key] header, HMAC [Authorization], retries with backoff, a cap on
    in-flight requests, client request ids and redaction.

    Every status comes back as [Ok] from {!call}; the JSON helpers turn non-2xx into an
    [Error] carrying an {!Api_error.t}. *)

open! Core
open! Async

module Meth : sig
  type t =
    [ `GET
    | `POST
    | `PATCH
    | `DELETE
    ]
  [@@deriving sexp_of, equal]

  val to_string : t -> string
end

module Response : sig
  type t =
    { status : int
    ; headers : (string * string) list
    ; body : string
    }
  [@@deriving sexp_of]

  val header : t -> string -> string option
end

(** One HTTP exchange; the default is cohttp-async with {!Tls.config}. *)
type send =
  meth:Meth.t
  -> Uri.t
  -> headers:(string * string) list
  -> body:string option
  -> Response.t Or_error.t Deferred.t

(** What happened on one attempt, for logging. Holds no headers or bodies. *)
module Event : sig
  type t =
    { request_id : string
    ; meth : Meth.t
    ; path : string
    ; attempt : int
    ; outcome : [ `Status of int | `Failed of string ]
    ; elapsed : Time_ns.Span.t
    }
  [@@deriving sexp_of]
end

type t

val create
  :  ?send:send
  -> ?sleep:(Time_ns.Span.t -> unit Deferred.t)
  -> ?now:(unit -> Time_ns.t)
  -> ?max_retries:int (** default 4 *)
  -> ?max_in_flight:int (** default 8 *)
  -> ?timeout:Time_ns.Span.t (** per attempt, default 30 s *)
  -> ?on_event:(Event.t -> unit)
  -> Config.t
  -> t

val config : t -> Config.t

(** The full URL for an API path such as [/user/create]. Refuses paths that do not start
    with [/] or that carry a scheme or host, so credentials never leave for another host. *)
val url : t -> string -> Uri.t Or_error.t

(** Backoff before retry [attempt] (1-based): 250 ms doubling up to 8 s, or the response's
    [Retry-After] seconds when present (the sandbox sends [retry-after: 1]). *)
val backoff : attempt:int -> retry_after:string option -> Time_ns.Span.t

(** Redact this client's secrets, IBANs and card numbers from text. *)
val redact : t -> string -> string

(** One logical request; returns the response and the client request id. GET sends no body
    and signs ["{}"]; POST and PATCH always send a JSON body (default ["{}"]). Retries
    429/5xx and transport failures only when [~idempotent:true]; the default is [true] for
    GET and [false] otherwise, because Striga uses POST for most reads but also for every
    money movement. *)
val call
  :  ?idempotent:bool
  -> t
  -> Meth.t
  -> string
  -> ?body:Yojson.Safe.t
  -> unit
  -> (Response.t * string) Or_error.t Deferred.t

(** [call], then decode a 2xx JSON body; non-2xx becomes {!Api_error.to_error}. *)
val json
  :  ?idempotent:bool
  -> t
  -> Meth.t
  -> string
  -> ?body:Yojson.Safe.t
  -> unit
  -> Yojson.Safe.t Or_error.t Deferred.t

(** Like {!json} for endpoints answering [OK], [Accepted] or an empty body. *)
val unit
  :  ?idempotent:bool
  -> t
  -> Meth.t
  -> string
  -> ?body:Yojson.Safe.t
  -> unit
  -> unit Or_error.t Deferred.t

(** The default [send], exposed for tests and tools. *)
val cohttp_send : timeout:Time_ns.Span.t -> send

(** A random UUID v4, used as the client request id. *)
val uuid_v4 : unit -> string
