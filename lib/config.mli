(** Client configuration, read from environment variables.

    - [STRIGA_API_KEY] and [STRIGA_API_SECRET] (required): the API credentials from the
      dashboard. The key goes in the [api-key] header and also signs webhooks; the secret
      signs requests.
    - [STRIGA_BASE_URL] (optional, default {!sandbox_base_url}).
    - [STRIGA_APPLICATION_ID] and [STRIGA_UI_SECRET] (optional): only used by the browser
      card PAN UI component ([StrigaUXPlugin.create(UI_SECRET, {applicationId})]); the
      REST API never needs them. [APPLICATION_ID] is also the [parentApplicationId] that
      accounts and whitelisted IBANs report.

    The library defaults to the sandbox: a base URL whose host is not a Striga sandbox
    host is refused unless [~live:true] is passed. *)

open! Core

type t =
  { base_url : Uri.t (** up to and including [/api/v1]; not part of the signed path *)
  ; api_key : Secret.t
  ; api_secret : Secret.t
  ; application_id : string option
  ; ui_secret : Secret.t option
  ; live : bool
  }

val sexp_of_t : t -> Sexp.t
val sandbox_base_url : Uri.t

(** [true] for [www.sandbox.striga.com] and [sandbox.striga.com]. *)
val is_sandbox_host : string -> bool

val create
  :  ?base_url:Uri.t
  -> ?application_id:string
  -> ?ui_secret:string
  -> ?live:bool
  -> api_key:string
  -> api_secret:string
  -> unit
  -> t Or_error.t

(** [of_env ()] reads the variables above; [getenv] defaults to [Sys.getenv]. *)
val of_env : ?getenv:(string -> string option) -> ?live:bool -> unit -> t Or_error.t

(** [true] when both [STRIGA_API_KEY] and [STRIGA_API_SECRET] are set. Live tests use it
    to skip. *)
val env_available : ?getenv:(string -> string option) -> unit -> bool

(** Every secret in [t] (key, secret, UI secret), for redaction. *)
val secrets : t -> Secret.t list
