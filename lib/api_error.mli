(** A non-2xx response from Striga.

    Error bodies come in a few shapes: [{"message", "errorCode", "errorDetails"}] with
    details as a string or a list of field errors, or
    [{"status", "errorCode", "errorDetails": {"message", "errorDetails"}}]. Unknown routes
    answer with an HTML page. *)

open! Core

type t =
  { meth : string
  ; path : string
  ; status : int
  ; request_id : string (** client-generated, sent as [x-request-id] *)
  ; error_code : string option (** e.g. ["00002"] invalid fields, ["30043"] suspended *)
  ; message : string option
  ; details : string option (** compact JSON of [errorDetails], redacted *)
  ; body : string option (** redacted and cut to 1 KiB, only when the body is not JSON *)
  }
[@@deriving sexp_of]

val of_response
  :  meth:string
  -> path:string
  -> request_id:string
  -> redact:(string -> string)
  -> status:int
  -> body:string
  -> t

val to_error : t -> Error.t

(** Recover the HTTP status and Striga error code from an error built by {!to_error}, also
    through [Or_error.tag]. *)
val status_of_error : Error.t -> int option

val code_of_error : Error.t -> string option

(** [30070] ([SCA_REQUIRED], reason [NO_SESSION] in the sandbox): the user has no SCA
    session; open one with {!Sca.login_start} and {!Sca.login_complete} and retry. *)
val is_sca_session_required : Error.t -> bool
