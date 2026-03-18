(** Web HTTP backend for Nopal applications.

    Implements HTTP requests using the browser Fetch API via Brr. Application
    code uses [nopal_http] types; this package is wired in at the mounting layer
    (e.g., [main.ml]). *)

val send :
  Nopal_http.request -> (Nopal_http.outcome -> 'msg) -> 'msg Nopal_mvu.Cmd.t
(** [send request on_result] creates a command that performs the HTTP request
    described by [request] using the browser Fetch API. Supports all HTTP
    methods, headers, and request bodies.

    A successful fetch produces [Ok { status; body }]. A network failure (DNS
    error, connection refused, fetch rejection) produces
    [Error (Network_error msg)] — never a raised exception. *)

val get :
  ?headers:(string * string) list ->
  string ->
  (Nopal_http.outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [get ?headers url on_result] creates a command that performs an HTTP GET
    request to [url] with optional [headers] using the browser Fetch API. *)

val post :
  string ->
  ?headers:(string * string) list ->
  body:string ->
  (Nopal_http.outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [post url ?headers ~body on_result] creates a command that performs an HTTP
    POST request to [url] with the given [body] and optional [headers]. *)
