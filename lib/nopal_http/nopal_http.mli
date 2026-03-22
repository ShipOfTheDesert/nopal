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

type body =
  | String of { content : string; content_type : string option }
  | Json of string
  | Form_encoded of (string * string) list
  | Multipart of (string * string) list
  | Empty
      (** HTTP request body variants. [String] carries raw content with an
          optional content type. [Json] carries a JSON string. [Form_encoded]
          and [Multipart] carry key-value pairs. [Empty] indicates no body. *)

type error =
  | Network_error of string
  | Timeout
      (** HTTP failure modes. [Network_error msg] indicates the request could
          not be completed (DNS failure, connection refused, etc.). [Timeout]
          indicates the request exceeded its timeout. *)

type outcome = (response, error) result
(** The result of an HTTP request — either a successful [response] or an
    [error]. *)

type meth = GET | POST | PUT | DELETE | PATCH  (** HTTP request methods. *)

type request = {
  meth : meth;
  url : string;
  headers : (string * string) list;
  body : body;
  timeout : float option;
}
(** An HTTP request. [meth] is the HTTP method, [url] is the target URL,
    [headers] is a list of header name-value pairs, [body] is the request body,
    and [timeout] is an optional timeout in seconds. *)

type backend = { send : request -> outcome Nopal_mvu.Task.t }
(** A platform-specific HTTP backend. The [send] field handles all HTTP methods
    by inspecting the [request.meth] field. Returns a {!Nopal_mvu.Task.t} that
    resolves with the HTTP outcome. *)

type cancellable_backend = {
  send_cancellable :
    request -> Nopal_mvu.Task.cancellation_token * outcome Nopal_mvu.Task.t;
}
(** A platform-specific cancellable HTTP backend. [send_cancellable] returns
    both a cancellation token and a task. When the token is cancelled, the
    underlying I/O is aborted (e.g., via [AbortController] on web). *)

val default_backend : backend
(** The default backend, which always dispatches [Network_error]. Useful for
    testing or restoring state after {!register_backend}. *)

val default_cancellable_backend : cancellable_backend
(** The default cancellable backend. Wraps {!default_backend}'s [send] with
    {!Nopal_mvu.Task.cancellable}. *)

val register_backend : backend -> unit
(** [register_backend b] sets the HTTP backend used by {!val-send}, {!val-get},
    {!val-post}, {!val-put}, {!val-delete_}, and {!val-patch}. Call this at
    application startup before mounting the app. *)

val register_cancellable_backend : cancellable_backend -> unit
(** [register_cancellable_backend b] sets the cancellable HTTP backend used by
    {!val-send_cancellable}, {!val-get_cancellable}, {!val-post_cancellable},
    {!val-put_cancellable}, {!val-delete_cancellable}, and
    {!val-patch_cancellable}. Call this at application startup before mounting
    the app. *)

val send : request -> (outcome -> 'msg) -> 'msg Nopal_mvu.Cmd.t
(** [send request on_result] creates a command that will perform the HTTP
    request described by [request]. When the request completes, [on_result] is
    called with the [outcome] and the resulting message is dispatched. *)

val get :
  ?headers:(string * string) list ->
  ?timeout:float ->
  string ->
  (outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [get ?headers ?timeout url on_result] creates a command that will perform an
    HTTP GET request to [url] with optional [headers] and [timeout]. *)

val post :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:body ->
  string ->
  (outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [post ?headers ?timeout ~body url on_result] creates a command that will
    perform an HTTP POST request to [url] with the given [body]. *)

val put :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:body ->
  string ->
  (outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [put ?headers ?timeout ~body url on_result] creates a command that will
    perform an HTTP PUT request to [url] with the given [body]. *)

val delete_ :
  ?body:body ->
  ?headers:(string * string) list ->
  ?timeout:float ->
  string ->
  (outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [delete_ ?body ?headers ?timeout url on_result] creates a command that will
    perform an HTTP DELETE request to [url]. *)

val patch :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:body ->
  string ->
  (outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [patch ?headers ?timeout ~body url on_result] creates a command that will
    perform an HTTP PATCH request to [url] with the given [body]. *)

val send_cancellable :
  request ->
  (outcome -> 'msg) ->
  Nopal_mvu.Task.cancellation_token * 'msg Nopal_mvu.Cmd.t
(** [send_cancellable request on_result] is like {!val-send} but also returns a
    cancellation token. If a platform-specific cancellable backend is
    registered, I/O is aborted on cancellation; otherwise, the default backend's
    [send] is wrapped with {!Nopal_mvu.Task.cancellable}. *)

val get_cancellable :
  ?headers:(string * string) list ->
  ?timeout:float ->
  string ->
  (outcome -> 'msg) ->
  Nopal_mvu.Task.cancellation_token * 'msg Nopal_mvu.Cmd.t
(** [get_cancellable ?headers ?timeout url on_result] is like {!val-get} but
    also returns a cancellation token. *)

val post_cancellable :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:body ->
  string ->
  (outcome -> 'msg) ->
  Nopal_mvu.Task.cancellation_token * 'msg Nopal_mvu.Cmd.t
(** [post_cancellable ?headers ?timeout ~body url on_result] is like {!val-post}
    but also returns a cancellation token. *)

val put_cancellable :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:body ->
  string ->
  (outcome -> 'msg) ->
  Nopal_mvu.Task.cancellation_token * 'msg Nopal_mvu.Cmd.t
(** [put_cancellable ?headers ?timeout ~body url on_result] is like {!val-put}
    but also returns a cancellation token. *)

val delete_cancellable :
  ?body:body ->
  ?headers:(string * string) list ->
  ?timeout:float ->
  string ->
  (outcome -> 'msg) ->
  Nopal_mvu.Task.cancellation_token * 'msg Nopal_mvu.Cmd.t
(** [delete_cancellable ?body ?headers ?timeout url on_result] is like
    {!val-delete_} but also returns a cancellation token. *)

val patch_cancellable :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:body ->
  string ->
  (outcome -> 'msg) ->
  Nopal_mvu.Task.cancellation_token * 'msg Nopal_mvu.Cmd.t
(** [patch_cancellable ?headers ?timeout ~body url on_result] is like
    {!val-patch} but also returns a cancellation token. *)
