(** Browser canvas image pipeline for Nopal applications.

    Decodes a stored image, downscales it natively, re-encodes it back into the
    browser blob store and scores its sharpness. Application code uses
    [nopal_image] types; this package is wired in at the mounting layer. *)

module Dimensions = Nopal_image_web_internal.Dimensions
(** Target sizing for the two downscale passes. Pure, and re-exported so it can
    be named without an internal module path.

    The raw browser bindings the pipeline is built from are deliberately not
    re-exported here. They live in the [nopal_image_web.internal] library, which
    a caller has to ask for by name: reaching [Canvas_ffi.read_pixels] directly
    would carry a full-resolution image across the js_of_ocaml boundary, which
    is the single crossing {!val-process} exists to make exactly once. *)

val process :
  blob_id:string ->
  config:Nopal_image.Config.t ->
  (Nopal_image.Processing.result_info, Nopal_image.Processing.error) result
  Nopal_mvu.Task.t
(** [process ~blob_id ~config] decodes the stored image held under [blob_id],
    draws it down to the long edge [config] asks for, encodes it in the format
    [config] names, registers the encoded bytes under a fresh blob-store handle,
    and scores the sharpness of a second, smaller draw of the same image.

    The handle that was processed keeps its own entry, and the encoded bytes are
    never copied into the OCaml heap: what comes back is the new handle, the
    size the image was stored at, the length of the stored bytes and the score.
    The pixels cross into OCaml once, on the sharpness canvas only.

    This is the browser implementation of the seam application code calls, and
    it is wired in at the mounting layer, once, before any command is built:

    {[
      Nopal_image.Processing.register_backend
        { Nopal_image.Processing.process = Nopal_image_web.process }
    ]} *)
