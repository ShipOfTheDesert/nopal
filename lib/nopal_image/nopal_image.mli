(** Pure pixel data: a validated RGBA buffer, its conversion to luminance, a
    sharpness metric over that luminance, and the capture parameters a platform
    backend reads.

    Nothing here touches compressed bytes, a canvas, or any platform API. A
    backend hands in raw pixels through {!Buffer} and reads its encode settings
    out of {!Config}; everything between those two points is ordinary OCaml and
    is exercised without a browser.

    Note that [open Nopal_image] shadows [Stdlib.Buffer]. Qualify the stdlib
    module as [Stdlib.Buffer] where a byte buffer rather than a pixel buffer is
    meant. *)

(** What went wrong while validating a value this library constructs. *)
type error = Image_error.t =
  | Invalid_dimensions of string
      (** a width, height and byte length that cannot describe an image *)
  | Invalid_config of string
      (** a capture parameter outside the range it is permitted to take *)

val message : error -> string
(** Human-readable description of an [error], for display. *)

module Image_error = Image_error
(** The error type the constructors in this library return. Re-exported so the
    signatures naming it can be read without an internal module path; {!error}
    above is the same type. *)

module Buffer = Buffer
(** The validated pixel buffer every other module here reads. *)

module Luma = Luma
(** Perceptual luminance, per pixel and over a whole buffer. *)

module Sharpness = Sharpness
(** The focus metric, built on luminance gradients. *)

module Config = Config
(** Validated capture parameters for a platform backend. *)
