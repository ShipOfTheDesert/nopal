(** Session-local registry mapping opaque handles to browser blobs.

    Binary data stays on the JavaScript side. A handle is the only thing that
    crosses into a natively-compiled Nopal package — [Brr.Blob.t] never appears
    in one — so a [_web] backend that needs the bytes resolves the handle here
    rather than receiving them from pure code.

    A handle is a session-local key, not a URL: it addresses nothing outside the
    page that issued it, and it is meaningless in another document, another
    origin, or after a reload. *)

val store : Brr.Blob.t -> string
(** [store blob] registers [blob] and returns a fresh handle.

    Every call returns a distinct handle, including repeated calls with a blob
    that is already registered — the store never deduplicates, so each handle
    owns its own entry. A handle is never reused within the page session, not
    even after {!remove} or {!clear}, so a stale handle can only ever resolve to
    [None] and never to some later blob.

    A handle also carries a random per-session component, so a fabricated one —
    a literal written by hand rather than issued here — cannot collide with a
    live entry and silently resolve to another caller's blob. Its shape is not
    part of this interface: do not parse it, and do not construct one. *)

val lookup : string -> Brr.Blob.t option
(** [lookup handle] is the blob registered under [handle], or [None] when
    [handle] was never issued by {!store} or has since been released. An unknown
    or fabricated handle is an absence, never an error and never an exception.
*)

val remove : string -> unit
(** [remove handle] releases [handle]'s entry. Idempotent: removing a handle
    that is unknown or already released does nothing. *)

val clear : unit -> unit
(** [clear ()] releases every entry. The store remains usable afterwards and
    keeps issuing fresh, never-recycled handles.

    Releasing is always an explicit caller action: entries otherwise live for
    the whole page session, and unmounting a Nopal application does not clear
    them. A blob can outlive the mount that registered it — an upload still in
    flight at teardown — and a blob registered with no mount in the picture
    would have no mount to be released by. *)
