(** Web HTTP backend for Nopal applications.

    Implements HTTP requests using the browser Fetch API via Brr. Application
    code uses [nopal_http] types; this package is wired in at the mounting layer
    (e.g., [main.ml]). *)

val get : string -> (Nopal_http.outcome -> 'msg) -> 'msg Nopal_mvu.Cmd.t
(** [get url on_result] creates a command that performs an HTTP GET request to
    [url] using the browser Fetch API. When the request completes, [on_result]
    is called with the outcome and the resulting message is dispatched to
    [update].

    A successful fetch produces [Ok { status; body }]. A network failure (DNS
    error, connection refused, fetch rejection) produces
    [Error (Network_error msg)] — never a raised exception. *)
