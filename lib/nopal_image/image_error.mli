(** What went wrong while validating a value this library constructs. Each
    constructor carries a description of the specific value that was rejected.
*)
type t =
  | Invalid_dimensions of string
      (** a width, height and byte length that cannot describe an image *)
  | Invalid_config of string
      (** a capture parameter outside the range it is permitted to take *)

val message : t -> string
(** Human-readable description of an error, for display. *)
