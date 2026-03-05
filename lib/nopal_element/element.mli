(** A pure description of a UI element.

    This is a stub type for the PoC. The full element DSL will be defined in the
    future. *)

type 'msg t =
  | Text of string  (** A text node with the given content. *)
  | Empty  (** An empty element that renders nothing. *)
