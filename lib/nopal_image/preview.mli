(** Displayable URLs for stored images, and the seam a platform backend
    registers itself into.

    A preview URL is a platform reference that names bytes already held in the
    session blob store, so an application can show a picture it has stored
    without reading those bytes back or copying them. Nothing here mints or
    releases one: this module names the two operations and dispatches them to
    whatever backend the platform registered, exactly as [Processing] does for
    image processing.

    A minted URL keeps its bytes alive until it is released through
    {!val-revoke}, and releasing is always something the application asks for -
    no runtime, unmount or collector does it. An application that replaces one
    picture with another releases the URL it replaces first, or every picture it
    has ever shown is retained for the life of the session.

    Four seams are now built in this shape: a backend record, a registration
    function, and command builders that read the registration. This paragraph
    used to name the fourth consumer as the point at which lifting a shared
    registry would pay for itself. The fourth arrived, the lift was evaluated
    against it, and it was declined.

    What repeats across the four is not a near-identical block. The four backend
    records share nothing but the name: [{ process }], [{ url; revoke }],
    [{ release }] and [{ send }] have no field, no arity and no result type in
    common, so what four sites hold identically is a [ref] and a one-line setter
    read at four unrelated types - two lines whose only differing content is the
    type they stand at. The shape has diverged exactly where a lift would have
    to bind it, and that is the ground.

    Two lesser ones sit under it. The eight lines across the four have no shared
    home: three of them sit in this package and one does not, so a shared
    registry needs a package of its own or a widening of what [Nopal_mvu] is
    for. And each registration function is documented with prose about its own
    seam, which a shared one cannot carry - a property of the shape that only
    became visible on the attempt to write the fourth.

    The count is spent, and no further one re-opens this. What would: a seam
    whose registration needs behaviour rather than storage, or a third package
    acquiring one of these seams. That the seams span two packages is not itself
    a reason - they already did when there were three, so the count was set
    without weighing it. *)

(** What went wrong while asking for a displayable URL. Each constructor names
    the reason and carries a description of the specific failure. *)
type error =
  | Blob_not_found of string
      (** no stored image is held under the handle that was asked for *)
  | Url_unavailable of string
      (** the image is stored, but this platform minted no URL for it. A
          platform with no notion of a displayable URL at all fails here too,
          because minting is where it is asked for one. *)
  | Backend_unregistered of string
      (** no platform backend was registered, so nothing could be asked. This is
          a wiring failure in the application, not a property of the image. *)

val message : error -> string
(** Human-readable description of an [error], for display. *)

type backend = {
  url : blob_id:string -> (string, error) result Nopal_mvu.Task.t;
      (** mint a displayable URL for the image stored under [blob_id], or report
          why none could be minted *)
  revoke : url:string -> unit;
      (** release a URL this backend minted, so its bytes stop being pinned.
          Releasing cannot fail: a URL that was already released, or that this
          backend never minted, is a no-op rather than an error. *)
}
(** A platform-specific preview implementation. *)

val default_backend : backend
(** The backend in force before any platform registers one. Its {!field-url}
    resolves [Backend_unregistered] rather than raising or leaving the task
    unresolved, so a program that forgot to register a backend reports a failure
    instead of waiting forever, and its {!field-revoke} does nothing, because no
    URL can have been minted through it. Public so a test can restore it after
    {!register_backend}. *)

val register_backend : backend -> unit
(** [register_backend b] makes [b] the backend {!preview_url} and {!val-revoke}
    dispatch to. Call it once at mount, before any command is built. *)

val preview_url :
  blob_id:string -> ((string, error) result -> 'msg) -> 'msg Nopal_mvu.Cmd.t
(** [preview_url ~blob_id on_result] is a command that asks the registered
    backend for a displayable URL naming the stored image [blob_id], and
    dispatches [on_result] once with the URL or with the reason there is none.
    The backend is read when the command is built, so build the command inside
    [update] rather than at module initialisation, which runs before a backend
    is registered.

    The URL it delivers pins its image until {!val-revoke} releases it. *)

val revoke : url:string -> 'msg Nopal_mvu.Cmd.t
(** [revoke ~url] is a command that asks the registered backend to release
    [url]. It dispatches no message: releasing cannot fail, so there is no
    outcome to report and no reply to wait for. Like {!preview_url} it reads the
    backend when the command is built.

    Releasing a URL the backend never minted, or releasing the same URL twice,
    is a no-op. *)
