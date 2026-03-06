(** Typed style properties for Nopal elements.

    Stub for the PoC -- will be expanded with layout and paint properties in a
    future PRD. *)

type t
(** Abstract style type. *)

val empty : t
(** The empty style -- no layout or paint properties. *)

val equal : t -> t -> bool
(** Structural equality for styles. *)
