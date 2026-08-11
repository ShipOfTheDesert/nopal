(** Pure pixel data: a validated RGBA buffer, its conversion to luminance, a
    sharpness metric over that luminance, the capture parameters a platform
    backend reads, and the seam a platform backend registers itself into.

    Nothing here touches compressed bytes, a canvas, or any platform API. The
    only dependency is [nopal_mvu], which supplies the task and command types
    {!Processing} states its effect in; a canvas is named in a {!Processing}
    failure but never reached for. A backend hands in raw pixels through
    {!Buffer}, reads its encode settings out of {!Config}, and reports what it
    produced back through {!Processing}; everything between those points is
    ordinary OCaml and is exercised without a browser.

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

module Processing = Processing
(** The seam an application calls to have a stored image processed, and the
    failures a platform backend reports back through it. *)
