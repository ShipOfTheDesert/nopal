(** Releasing a stored image, and the seam a platform backend registers itself
    into.

    A stored image is bytes the platform holds under a handle, and it stays held
    until something releases it - no runtime, unmount or collector does it. An
    application that keeps storing pictures and never releases the ones it has
    stopped using retains every one of them for the life of the session. This
    module names that one operation and dispatches it to whatever backend the
    platform registered, as {!Processing} and {!Preview} do for their own.

    Releasing a stored image is not the same as releasing a displayable URL
    minted from it. {!Preview.val-revoke} releases the URL and leaves the entry
    registered, still able to mint again; this releases the entry itself, after
    which nothing can be minted from it and the handle naming it resolves to
    nothing. Neither operation performs the other, so an application showing a
    picture it is finished with asks for both. *)

type backend = {
  release : blob_id:string -> unit;
      (** release the image stored under [blob_id]. Releasing cannot fail: a
          handle this backend never issued, or one it has already released, is a
          no-op rather than an error. *)
}
(** A platform-specific release implementation. *)

val default_backend : backend
(** The backend in force before any platform registers one. It releases nothing,
    because nothing can have been stored through a platform that never
    registered itself, so there is no entry for it to free. That is inertness
    rather than a reported failure by design: releasing reports no outcome at
    all, so a default that raised would abandon whatever the caller was in the
    middle of doing while giving it nothing to respond to. Public so a test can
    restore it after {!register_backend}. *)

val register_backend : backend -> unit
(** [register_backend b] makes [b] the backend {!val-release} dispatches to.
    Call it once at mount, before any command is built.

    This is the fourth seam built on a [ref] and a one-line setter, and the
    fourth occurrence is where a shared registry was to be lifted. It was
    evaluated there and declined; {!Preview} records the grounds and what would
    re-open the question - a seam whose registration needs behaviour rather than
    storage, or a third package acquiring one of these seams. Whoever writes a
    fifth seam owns that question and reads it there before copying this file.
*)

val release : blob_id:string -> 'msg Nopal_mvu.Cmd.t
(** [release ~blob_id] is a command that asks the registered backend to release
    the image stored under [blob_id]. It dispatches no message: releasing cannot
    fail, so there is no outcome to report and no reply to wait for, and the
    message type stays free precisely because no message is ever made.

    Releasing a handle that was never issued, or releasing the same handle
    twice, is a no-op. A caller may therefore release whatever it happens to
    hold without keeping a record of what it has already released.

    The backend is read when the command is built, so build the command inside
    [update] rather than at module initialisation, which runs before a backend
    is registered. *)
