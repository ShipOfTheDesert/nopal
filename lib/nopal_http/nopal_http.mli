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

(** One part of a [Multipart] body. A [File] part names its bytes by handle so
    binary never enters the OCaml heap. *)
type part =
  | Field of string * string
      (** [Field (name, value)] is a plain string form field. *)
  | File of {
      name : string;  (** The form field name the part is sent under. *)
      blob_id : string;
          (** Opaque handle issued by the web blob store. Never parse, derive,
              or fabricate one — a handle is only meaningful to a web backend,
              which is the only place it can be resolved. On any other backend a
              [File] part cannot be sent. *)
      filename : string option;
          (** Filename the server sees. [None] defers to the blob's own name. *)
      mime : string option;
          (** MIME type the part is sent under. [None] defers to the type the
              blob itself reports. A value here is a caller {e declaration}
              attached to the outgoing part, never a check that the bytes match
              it — a server must not trust it. *)
    }  (** A file part, named by store handle rather than carrying its bytes. *)

(** HTTP request body variants. *)
type body =
  | String of { content : string; content_type : string option }
      (** Raw content with an optional content type. *)
  | Json of string  (** A JSON string. *)
  | Form_encoded of (string * string) list
      (** Key-value pairs, URL-encoded into the body. *)
  | Multipart of part list
      (** No [Content-Type] header is sent for a multipart body — the platform's
          Fetch implementation generates the boundary, and a hand-written header
          would not match the encoded body. *)
  | Empty  (** No body. *)

(** HTTP failure modes. *)
type error =
  | Network_error of string
      (** The request could not be completed (DNS failure, connection refused,
          etc.). Carries the platform's message. *)
  | Timeout  (** The request exceeded its timeout. *)
  | Invalid_blob of string
      (** A [File] part named a handle with no store entry at send time. Carries
          the unresolvable handle, and nothing was sent. *)

val message : error -> string
(** Human-readable description of an [error], for display. *)

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
