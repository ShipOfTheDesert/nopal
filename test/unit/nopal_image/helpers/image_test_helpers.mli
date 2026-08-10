(** Shared helpers for the [nopal_image] unit tests. *)

val close : epsilon:float -> float -> float -> bool
(** [close ~epsilon expected actual] is [true] when the two values differ by no
    more than [epsilon]. A NaN on either side is rejected before the
    subtraction, so a NaN fails on the NaN rather than on a comparison accident.
*)

val approx : epsilon:float -> float Alcotest.testable
(** A float testable comparing with {!close} at the given tolerance. *)

val exact : float Alcotest.testable
(** A float testable comparing with [Float.equal]. Note that this does not
    separate [-0.0] from [0.0]; use {!same_bits} where the sign of a zero is
    part of the claim. *)

val same_bits : float -> float -> bool
(** [same_bits a b] compares the IEEE bit patterns. This is the only comparison
    that separates [-0.0] from [0.0], so it is the only one that can pin a claim
    that a float was stored or echoed exactly as supplied. *)

val rgba_pixel : (int * int * int * int) Alcotest.testable
(** A red, green, blue and alpha quadruple, as {!Nopal_image.Buffer.pixel}
    returns. *)

val buffer_or_fail :
  context:string ->
  (Nopal_image.Buffer.t, Nopal_image.error) result ->
  Nopal_image.Buffer.t
(** [buffer_or_fail ~context result] is the buffer, or fails the running test
    naming [context] and the error's displayable message. *)

val rgba_of_pixels : (int * int * int * int) list -> bytes
(** [rgba_of_pixels pixels] packs the quadruples into RGBA bytes, in the order
    given. *)

val rgba_of_gray_levels : int array -> bytes
(** [rgba_of_gray_levels levels] packs each level into an opaque gray pixel, so
    a pixel's luminance is its own level and a fixture's expected score can be
    read straight off the levels. Row-major, matching the order
    {!Nopal_image.Luma.of_buffer} produces. *)

val gray_buffer :
  width:int ->
  height:int ->
  int array ->
  (Nopal_image.Buffer.t, Nopal_image.error) result
(** [gray_buffer ~width ~height levels] builds a buffer from
    {!rgba_of_gray_levels}. *)

val gray_buffer_or_fail :
  context:string -> width:int -> height:int -> int array -> Nopal_image.Buffer.t
(** {!gray_buffer}, failing the running test rather than returning a result. *)
