(** Hand-written [Jv] bindings for the browser image calls [brr] does not bind.

    [brr] binds neither [createImageBitmap] nor the canvas methods this pipeline
    needs, so these are raw bindings over the global object and over a detached
    canvas element, following the convention [nopal_storage_web]'s IndexedDB
    bindings set.

    Nothing here classifies a failure. A call the browser rejects asynchronously
    reports a message through its continuation; a call the browser refuses
    synchronously lets the [Jv.Error] escape, so a caller can attribute it to
    the stage that raised rather than by reading the text of the message.
    Turning either into a typed error is the caller's job.

    Every canvas allocated here is detached: it is never inserted into a
    document, so nothing drawn on it is displayed. *)

type bitmap
(** A decoded image, held on the JavaScript side. Full-resolution pixels stay
    behind this handle and never enter the OCaml heap. *)

type canvas
(** A detached canvas element together with its pixel backing store. *)

type context
(** A canvas 2D drawing context. *)

val decode : Brr.Blob.t -> ((bitmap, string) result -> unit) -> unit
(** [decode blob k] decodes the encoded image held in [blob] and calls [k]
    exactly once: [Ok bitmap] once the image is available, or [Error message]
    when the browser rejects the bytes. The message is for a human reader and is
    never a token to branch on. The caller owns the bitmap and must {!release}
    it. *)

val bitmap_width : bitmap -> int
(** Width in pixels of the decoded image, as the decoder read it out of the
    encoded bytes rather than as any caller requested it. *)

val bitmap_height : bitmap -> int
(** Height in pixels of the decoded image, read the same way as {!bitmap_width}.
*)

val release : bitmap -> unit
(** [release bitmap] frees the decoded pixels. A decoded full-resolution image
    is the largest thing this pipeline holds, so every path that decodes one
    releases it, the failing paths included. Releasing an already released
    bitmap does nothing. *)

val create_canvas : width:int -> height:int -> canvas
(** [create_canvas ~width ~height] allocates a detached canvas whose backing
    store is exactly [width] by [height] pixels. Both are written explicitly,
    because a canvas that is only created carries the platform's own default
    size instead. *)

val canvas_width : canvas -> int
(** Width in pixels of the backing store of [canvas], read back off the canvas
    rather than recalled from the request that allocated it. A pipeline
    reporting the size an image was stored at reports this, so that a browser
    which served something other than what was asked for is described honestly
    rather than by the request. *)

val canvas_height : canvas -> int
(** Height in pixels of the backing store of [canvas], read the same way as
    {!canvas_width}. *)

val context_2d : canvas -> context option
(** [context_2d canvas] is the 2D drawing context of [canvas], or [None] when
    the environment supplies none. The absence is a value rather than an
    exception because that is how the platform reports it. *)

val draw : context -> bitmap -> width:int -> height:int -> unit
(** [draw context bitmap ~width ~height] paints [bitmap] onto the canvas of
    [context] at the origin, scaled to [width] by [height]. The resampling is
    the platform's, which is the point: the pixels are scaled on the JavaScript
    side and never travel through OCaml to be resized. *)

val encode :
  canvas ->
  mime:string ->
  quality:float ->
  ((Brr.Blob.t, string) result -> unit) ->
  unit
(** [encode canvas ~mime ~quality k] encodes the backing store of [canvas] and
    calls [k] exactly once: [Ok blob] holding the encoded bytes, or
    [Error message] when the encoder produces nothing. [mime] names the target
    format and [quality] is a number between 0 and 1 that a lossy format reads
    and a lossless one ignores. Derive [mime] from a typed format value, never
    from a string a caller supplied. *)

val read_pixels : context -> Brr.Tarray.uint8_clamped
(** [read_pixels context] is the whole backing store of the canvas of [context]
    as packed RGBA bytes, four per pixel, row by row from the top left. This is
    the one point at which pixels come within reach of OCaml, so a pipeline
    calls it once and on the smallest canvas it needs. A read the browser
    refuses raises its error rather than reporting an absence, so the caller can
    attribute the failure to this stage. *)
