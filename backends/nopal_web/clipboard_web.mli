(** The browser's clipboard write, behind {!Nopal_mvu.Cmd.write_clipboard}. *)

val write : string -> ((unit, Nopal_mvu.Clipboard.error) result -> unit) -> unit
(** [write text resolve] calls [navigator.clipboard.writeText text] before it
    returns, and calls [resolve] exactly once with the outcome, either before
    returning or when the browser's promise settles. It must be called on the
    stack of the gesture that asked for the write: a browser grants the write
    only within that gesture's user activation, so a caller that defers the call
    — to a frame, a timer, a promise — may see it refused.

    Outcomes:
    - [Ok ()] when the promise fulfils.
    - [Error Unavailable] when [navigator.clipboard] or its [writeText] is
      absent (an insecure context, or a browser without the asynchronous
      Clipboard API).
    - [Error Not_permitted] when the promise rejects with a [NotAllowedError].
    - [Error (Failed reason)] for any other rejection and for an exception
      thrown while issuing the write. [reason] is the platform's message, or a
      fixed description when the platform gave none; it never contains [text].

    Every outcome after the first is discarded, including one produced by an
    exception that follows a delivered outcome. *)
