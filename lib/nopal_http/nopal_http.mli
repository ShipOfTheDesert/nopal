(** Pure HTTP types for Nopal applications.

    This package defines the platform-agnostic type vocabulary for HTTP requests
    and responses. Application code pattern-matches on these types in [update];
    platform backends (e.g., [nopal_http_web]) provide the actual network
    implementation via {!register_backend}. *)

type response = { status : int; body : string }
(** An HTTP response. [status] is the HTTP status code (e.g. 200, 404). [body]
    is the response body as a string. *)

type error =
  | Network_error of string
      (** HTTP failure modes. [Network_error msg] indicates the request could
          not be completed (DNS failure, connection refused, etc.). *)

type outcome = (response, error) result
(** The result of an HTTP request — either a successful [response] or an
    [error]. *)

type backend = {
  get : 'msg. string -> (outcome -> 'msg) -> 'msg Nopal_mvu.Cmd.t;
}
(** A platform-specific HTTP backend. *)

val default_backend : backend
(** The default backend, which always dispatches [Network_error]. Useful for
    testing or restoring state after {!register_backend}. *)

val register_backend : backend -> unit
(** [register_backend b] sets the HTTP backend used by {!val-get}. Call this at
    application startup before mounting the app. *)

val get : string -> (outcome -> 'msg) -> 'msg Nopal_mvu.Cmd.t
(** [get url on_result] creates a command that will perform an HTTP GET request
    to [url]. When the request completes, [on_result] is called with the
    [outcome] and the resulting message is dispatched.

    Uses the backend registered via {!register_backend}, or the default stub
    which always dispatches [Network_error]. *)
