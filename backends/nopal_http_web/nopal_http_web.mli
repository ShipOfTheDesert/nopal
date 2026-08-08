(** Web HTTP backend for Nopal applications.

    Implements HTTP requests using the browser Fetch API via Brr. Application
    code uses [nopal_http] types; this package is wired in at the mounting layer
    (e.g., [main.ml]). *)

val send : Nopal_http.request -> Nopal_http.outcome Nopal_mvu.Task.t
(** [send request] creates a task that performs the HTTP request described by
    [request] using the browser Fetch API. Supports all HTTP methods, headers,
    and request bodies.

    A successful fetch produces [Ok { status; body; headers }]. A network
    failure (DNS error, connection refused, fetch rejection) produces
    [Error (Network_error msg)], and a request that exceeds its timeout produces
    [Error Timeout] — never a raised exception.

    A [Multipart] body resolves each [File] part's [blob_id] against the web
    blob store ({!Nopal_blob_web.Blob_store}) and appends the stored blob
    itself, so the bytes are never read into OCaml. A handle with no store entry
    produces [Error (Invalid_blob handle)] — again never a raised exception —
    and fails the whole request: no fetch is issued, so none of the other parts
    is sent either. [filename] and [mime] are independent per-part overrides;
    with [filename = None] the blob's own name is used when it has one, and with
    [mime = None] the blob's own type is left in place. This is the only failure
    mode that is a programming error rather than a transport one, which is why
    it is a distinct arm. *)

val get :
  ?headers:(string * string) list ->
  ?timeout:float ->
  string ->
  Nopal_http.outcome Nopal_mvu.Task.t
(** [get ?headers ?timeout url] creates a task that performs an HTTP GET request
    to [url] with optional [headers] and [timeout]. *)

val post :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:Nopal_http.body ->
  string ->
  Nopal_http.outcome Nopal_mvu.Task.t
(** [post ?headers ?timeout ~body url] creates a task that performs an HTTP POST
    request to [url] with the given [body]. *)

val put :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:Nopal_http.body ->
  string ->
  Nopal_http.outcome Nopal_mvu.Task.t
(** [put ?headers ?timeout ~body url] creates a task that performs an HTTP PUT
    request to [url] with the given [body]. *)

val delete_ :
  ?body:Nopal_http.body ->
  ?headers:(string * string) list ->
  ?timeout:float ->
  string ->
  Nopal_http.outcome Nopal_mvu.Task.t
(** [delete_ ?body ?headers ?timeout url] creates a task that performs an HTTP
    DELETE request to [url]. *)

val patch :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:Nopal_http.body ->
  string ->
  Nopal_http.outcome Nopal_mvu.Task.t
(** [patch ?headers ?timeout ~body url] creates a task that performs an HTTP
    PATCH request to [url] with the given [body]. *)

val send_cancellable :
  Nopal_http.request ->
  Nopal_mvu.Task.cancellation_token * Nopal_http.outcome Nopal_mvu.Task.t
(** [send_cancellable request] is like {!val-send} but returns a cancellation
    token. When the token is cancelled, the underlying Fetch request is aborted
    via [AbortController]. The task resolves with
    [Error (Network_error "cancelled")]. It shares {!val-send}'s body handling,
    including [Error (Invalid_blob handle)] for an unresolvable [File] part. *)
