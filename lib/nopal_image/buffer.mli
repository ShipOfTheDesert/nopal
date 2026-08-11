type t
(** A validated, immutable RGBA pixel buffer. *)

val create : width:int -> height:int -> rgba:bytes -> (t, Image_error.t) result
(** [create ~width ~height ~rgba] validates that both dimensions are positive
    and that [rgba] holds exactly four bytes per pixel, then takes a copy of
    [rgba]. The caller may reuse or mutate its own byte source afterwards
    without affecting the returned buffer. *)

val width : t -> int
(** Width in pixels. Always positive. *)

val height : t -> int
(** Height in pixels. Always positive. *)

val byte_size : t -> int
(** Size of the packed RGBA data in bytes. This is the raw pixel length, four
    bytes per pixel, which is a different quantity from the compressed length a
    platform backend reports for the same picture in
    [Processing.result_info.byte_size]; the two differ by roughly an order of
    magnitude. *)

val pixel : t -> x:int -> y:int -> (int * int * int * int) option
(** [pixel t ~x ~y] is the red, green, blue and alpha channels at [(x, y)], each
    in the range 0 to 255, or [None] when the coordinate lies outside the
    buffer. Coordinates are zero-based with the origin at the top left. *)
