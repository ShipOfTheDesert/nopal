(** Pure HTTP types for Nopal applications.

    This package defines the platform-agnostic type vocabulary for HTTP requests
    and responses. Application code pattern-matches on these types in [update];
    platform backends (e.g., [nopal_http_web]) provide the actual network
    implementation via {!register_backend}. *)

type response = {
  status : int;
  body : string;
  headers : (string * string) list;
}
(** An HTTP response. [status] is the HTTP status code (e.g. 200, 404). [body]
    is the response body as a string. [headers] is a list of response header
    name-value pairs with lowercased names. *)

type error =
  | Network_error of string
      (** HTTP failure modes. [Network_error msg] indicates the request could
          not be completed (DNS failure, connection refused, etc.). *)

type outcome = (response, error) result
(** The result of an HTTP request — either a successful [response] or an
    [error]. *)

type meth = GET | POST | PUT | DELETE | PATCH  (** HTTP request methods. *)

type request = {
  meth : meth;
  url : string;
  headers : (string * string) list;
  body : string;
}
(** An HTTP request. [meth] is the HTTP method, [url] is the target URL,
    [headers] is a list of header name-value pairs, and [body] is the request
    body (empty string for GET requests). *)

type backend = {
  send : 'msg. request -> (outcome -> 'msg) -> 'msg Nopal_mvu.Cmd.t;
}
(** A platform-specific HTTP backend. The [send] field handles all HTTP methods
    by inspecting the [request.meth] field. *)

val default_backend : backend
(** The default backend, which always dispatches [Network_error]. Useful for
    testing or restoring state after {!register_backend}. *)

val register_backend : backend -> unit
(** [register_backend b] sets the HTTP backend used by {!val-send}, {!val-get},
    {!val-post}, {!val-put}, {!val-delete_}, and {!val-patch}. Call this at
    application startup before mounting the app. *)

val send : request -> (outcome -> 'msg) -> 'msg Nopal_mvu.Cmd.t
(** [send request on_result] creates a command that will perform the HTTP
    request described by [request]. When the request completes, [on_result] is
    called with the [outcome] and the resulting message is dispatched. *)

val get :
  ?headers:(string * string) list ->
  string ->
  (outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [get ?headers url on_result] creates a command that will perform an HTTP GET
    request to [url] with optional [headers]. When the request completes,
    [on_result] is called with the [outcome] and the resulting message is
    dispatched. *)

val post :
  string ->
  ?headers:(string * string) list ->
  body:string ->
  (outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [post url ?headers ~body on_result] creates a command that will perform an
    HTTP POST request to [url] with the given [body] and optional [headers]. *)

val put :
  string ->
  ?headers:(string * string) list ->
  body:string ->
  (outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [put url ?headers ~body on_result] creates a command that will perform an
    HTTP PUT request to [url] with the given [body] and optional [headers]. *)

val delete_ :
  ?body:string ->
  ?headers:(string * string) list ->
  string ->
  (outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [delete_ ?body ?headers url on_result] creates a command that will perform
    an HTTP DELETE request to [url] with an optional [body] and [headers]. *)

val patch :
  string ->
  ?headers:(string * string) list ->
  body:string ->
  (outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [patch url ?headers ~body on_result] creates a command that will perform an
    HTTP PATCH request to [url] with the given [body] and optional [headers]. *)
