(** Virtual list primitives — scroll state and pure windowing computation.

    All types and functions compile on native OCaml (no js_of_ocaml dependency).
    The windowing function is backend-independent and testable without a
    browser. *)

type fixed
(** Phantom type tag for fixed-height virtualization. A future [variable] tag
    will enable variable-height rows without breaking existing [fixed] code. *)

module Positive_float : sig
  type t
  (** A float known to be strictly positive (> 0.0). *)

  val of_float : float -> t option
  (** [of_float f] returns [Some t] when [f > 0.0], [None] otherwise. *)

  val to_float : t -> float
end

module Natural : sig
  type t
  (** A non-negative integer (>= 0). *)

  val of_int : int -> t option
  (** [of_int n] returns [Some t] when [n >= 0], [None] otherwise. *)

  val to_int : t -> int
end

type 'height scroll_state
(** Scroll position tagged with the height strategy phantom type. Currently
    carries only a float offset. Opaque to enable future extension with
    variable-height metadata. *)

val scroll_state : offset:float -> fixed scroll_state
(** Create a fixed-height scroll state. Negative offsets are clamped to 0. *)

val offset : _ scroll_state -> float
(** Extract the current scroll offset in pixels. *)

type range = { first : int; last : int }
(** Inclusive index range of visible items. *)

val visible_range :
  scroll_state:fixed scroll_state ->
  row_height:Positive_float.t ->
  container_height:Positive_float.t ->
  item_count:Natural.t ->
  overscan:Natural.t ->
  range
(** Pure windowing computation. Returns the range of item indices that should be
    rendered (visible window + overscan buffer). When [item_count] is 0, returns
    [{first = 0; last = -1}] (empty range). *)
