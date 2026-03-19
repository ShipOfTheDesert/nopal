(** Web HTTP backend for Nopal applications.

    Implements HTTP requests using the browser Fetch API via Brr. Application
    code uses [nopal_http] types; this package is wired in at the mounting layer
    (e.g., [main.ml]). *)

val send :
  Nopal_http.request -> (Nopal_http.outcome -> 'msg) -> 'msg Nopal_mvu.Cmd.t
(** [send request on_result] creates a command that performs the HTTP request
    described by [request] using the browser Fetch API. Supports all HTTP
    methods, headers, and request bodies.

    A successful fetch produces [Ok { status; body; headers }]. A network
    failure (DNS error, connection refused, fetch rejection) produces
    [Error (Network_error msg)] — never a raised exception. *)

val get :
  ?headers:(string * string) list ->
  ?timeout:float ->
  string ->
  (Nopal_http.outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [get ?headers ?timeout url on_result] creates a command that performs an
    HTTP GET request to [url] with optional [headers] and [timeout]. *)

val post :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:Nopal_http.body ->
  string ->
  (Nopal_http.outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [post ?headers ?timeout ~body url on_result] creates a command that performs
    an HTTP POST request to [url] with the given [body]. *)

val put :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:Nopal_http.body ->
  string ->
  (Nopal_http.outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [put ?headers ?timeout ~body url on_result] creates a command that performs
    an HTTP PUT request to [url] with the given [body]. *)

val delete_ :
  ?body:Nopal_http.body ->
  ?headers:(string * string) list ->
  ?timeout:float ->
  string ->
  (Nopal_http.outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [delete_ ?body ?headers ?timeout url on_result] creates a command that
    performs an HTTP DELETE request to [url]. *)

val patch :
  ?headers:(string * string) list ->
  ?timeout:float ->
  body:Nopal_http.body ->
  string ->
  (Nopal_http.outcome -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [patch ?headers ?timeout ~body url on_result] creates a command that
    performs an HTTP PATCH request to [url] with the given [body]. *)
