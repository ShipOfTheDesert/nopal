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

val object_url : string -> string option
(** [object_url handle] is a browser URL that displays [handle]'s blob, or
    [None] when [handle] resolves to nothing or the environment mints no URL for
    it. A minted URL is same-origin and meaningless outside the page session
    that issued it, exactly like the handle it was minted from.

    Both ways an environment can decline are that same [None]: one with no
    notion of object URLs at all, and one that has the capability and refuses
    the call — a quota, a hardened global, a blocked call. Neither raises, here
    as everywhere in this module. Which of the three causes produced the [None]
    is not recoverable from it; a caller that must tell a stale handle apart
    from a declining platform asks {!lookup} first.

    A URL pins its blob for as long as it is live: the bytes stay resident even
    after the entry behind them is released with {!remove} or {!clear}, and
    unmounting a Nopal application releases neither. Only {!revoke_url} does.
    That makes revocation a caller obligation — a view that replaces one image
    with another revokes the URL it is replacing, or every photograph the user
    takes stays in memory for the rest of the session.

    Every call mints a separate URL, including repeated calls with the same
    handle. Two URLs for one blob are two resources to revoke, not one. *)

val revoke_url : string -> unit
(** [revoke_url url] releases [url], after which it displays nothing and its
    blob is no longer pinned by it. Idempotent, and a no-op on a string this
    store never minted, so a caller releasing whatever it happens to hold needs
    no bookkeeping to avoid a double release.

    An environment that cannot release, or that refuses to, is a no-op as well
    rather than an exception: this reports no outcome at all, so a raise would
    give the caller nothing to respond to while abandoning whatever else it was
    in the middle of doing.

    Revoking releases the URL only. The entry it was minted from stays
    registered and can mint again; use {!remove} to release that. *)

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
