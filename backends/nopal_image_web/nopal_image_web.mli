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

val preview_url :
  blob_id:string -> (string, Nopal_image.Preview.error) result Nopal_mvu.Task.t
(** [preview_url ~blob_id] mints a browser URL that displays the image stored
    under [blob_id], without reading its bytes back or copying them.

    The two ways there can be no URL are kept apart, because they have different
    owners. A handle the store resolves to nothing is [Blob_not_found], and it
    is the application holding a stale handle. A handle it does resolve, for
    which this browser still produced no URL - it has no notion of an object URL
    at all, or it refused the call - is [Url_unavailable], and it is the
    platform.

    The minted URL pins the image's bytes until {!revoke_preview_url} releases
    it. Nothing else releases it: not unmounting, not releasing the store entry
    it was minted from. A caller that replaces one displayed image with another
    releases the URL it is replacing, or every image it has ever shown stays
    resident for the rest of the page session. Every call mints a URL of its
    own, so two mints are two releases rather than one.

    This is the browser implementation of the seam application code calls, and
    it is wired in at the mounting layer, once, before any command is built:

    {[
      Nopal_image.Preview.register_backend
        {
          Nopal_image.Preview.url = Nopal_image_web.preview_url;
          revoke = Nopal_image_web.revoke_preview_url;
        }
    ]} *)

val revoke_preview_url : url:string -> unit
(** [revoke_preview_url ~url] releases [url], after which it displays nothing
    and no longer pins the image's bytes.

    Idempotent, and a no-op on a string this browser never minted or in an
    environment with no notion of an object URL at all, so a caller releasing
    whatever it happens to hold needs no bookkeeping to avoid a double release.

    Releasing a URL releases the URL only: the store entry it was minted from
    stays registered and can mint again. *)
