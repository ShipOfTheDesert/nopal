(** What went wrong while turning a stored image into an upload-ready one. Each
    constructor names the stage that failed and carries a description of the
    specific failure. *)
type error =
  | Blob_not_found of string
      (** no stored image is held under the handle that was asked for *)
  | Decode_failed of string
      (** the stored bytes did not decode as an image this platform can read. A
          platform with no image decoder at all fails here too, because the
          decode is where it is asked for one: an application testing for an
          unsupported environment must treat this arm as covering that case as
          well as a bad file. *)
  | Canvas_unavailable of string
      (** the drawing surface this platform needs could not be obtained. This
          means the surface was refused or no backend was registered at all -
          not that the platform lacks an image decoder, which is
          [Decode_failed]. *)
  | Pixel_read_failed of string
      (** the drawn pixels could not be read back off the drawing surface *)
  | Encode_failed of string
      (** the processed pixels did not re-encode into stored bytes *)

val message : error -> string
(** Human-readable description of an [error], for display. *)

type result_info = {
  blob_id : string;
      (** handle the processed image was stored under. It is a new handle handed
          out by the blob store, not the handle that was processed, and the
          handle that was processed keeps its own entry. *)
  width : int;  (** width in pixels the processed image was stored at *)
  height : int;  (** height in pixels the processed image was stored at *)
  byte_size : int;
      (** length in bytes of the stored encoded image. This is the compressed
          length, which is a different quantity from the raw RGBA length
          [Buffer.byte_size] reports for the same picture. *)
  sharpness : float;
      (** focus score measured over the processed pixels, on the scale
          [Sharpness.score] defines *)
}
(** What a completed processing pass produced. Every field describes the image
    that was actually stored, never the parameters that were asked for. *)

type backend = {
  process :
    blob_id:string ->
    config:Config.t ->
    (result_info, error) result Nopal_mvu.Task.t;
}
(** A platform-specific image processing implementation. [process] takes the
    handle of a stored image and the capture parameters to store it under, and
    answers with what it produced or with the stage that failed. *)

val default_backend : backend
(** The backend in force before any platform registers one. It resolves
    [Canvas_unavailable] rather than raising or leaving the task unresolved, so
    a program that forgot to register a backend reports a failure instead of
    waiting forever. Public so a test can restore it after {!register_backend}.
*)

val register_backend : backend -> unit
(** [register_backend b] makes [b] the backend {!val-process} dispatches to.
    Call it once at mount, before any command is built. *)

val process :
  blob_id:string ->
  config:Config.t ->
  ((result_info, error) result -> 'msg) ->
  'msg Nopal_mvu.Cmd.t
(** [process ~blob_id ~config on_result] is a command that asks the registered
    backend to turn the stored image [blob_id] into an upload-ready one under
    [config], and dispatches [on_result] with what it produced. The backend is
    read when the command is built, so build the command inside [update] rather
    than at module initialisation, which runs before a backend is registered. *)
