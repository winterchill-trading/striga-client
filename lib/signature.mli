(** Striga's HMAC request signatures and webhook signatures.

    Requests carry [Authorization: HMAC <ms>:<hex>] where [<hex>] is HMAC-SHA256, keyed
    with the API secret, over [ms ^ METHOD ^ path ^ hex(MD5(body))]. [path] is the request
    path below [/api/v1] (v1 dropped the prefix from the signed text), and a request
    without a body signs the MD5 of ["{}"].

    Webhooks carry a [signature] header: hex HMAC-SHA256, keyed with the API {b key} (not
    the secret), over the JSON body. *)

open! Core

(** Hex MD5 of the body as sent; [None] signs as ["{}"]. *)
val body_digest : string option -> string

(** The string that gets HMAC'd. *)
val signing_input
  :  time_ms:string
  -> meth:string
  -> path:string
  -> body:string option
  -> string

(** The full [Authorization] header value. *)
val authorization
  :  secret:Secret.t
  -> time_ms:string
  -> meth:string
  -> path:string
  -> body:string option
  -> string

(** Hex HMAC-SHA256 of [body] keyed with [api_key]. *)
val webhook_signature : api_key:Secret.t -> string -> string

(** Check a webhook's [signature] header against the raw body. Striga computes it over
    [JSON.stringify(payload)], which is the body as delivered; if the raw bytes do not
    match (a proxy re-encoded the JSON), the compact re-serialisation is tried too.
    Comparison is constant time. *)
val verify_webhook : api_key:Secret.t -> body:string -> signature:string -> bool
