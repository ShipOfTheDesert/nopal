(** Hit regions for interactive chart elements.

    Each chart builds a hit map alongside its scene in a single pass. [hit_test]
    traverses regions in reverse order so the topmost (last-drawn) region takes
    priority. *)

type hit = { index : int; series : int }

type region =
  | Rect_region of { x : float; y : float; w : float; h : float; hit : hit }
  | Circle_region of { cx : float; cy : float; r : float; hit : hit }
  | Wedge_region of {
      cx : float;
      cy : float;
      inner_r : float;
      outer_r : float;
      start_angle : float;
      end_angle : float;
      hit : hit;
    }
  | Band_region of { x : float; w : float; hit : hit }

type t

val empty : t
(** The empty hit map with no regions. *)

val add : region -> t -> t
(** [add region t] adds [region] to the hit map. Regions added later take
    priority in hit testing (topmost wins). *)

val hit_test : t -> x:float -> y:float -> hit option
(** [hit_test t ~x ~y] returns the topmost region containing the point [(x, y)],
    or [None] if no region matches. Traverses regions in reverse insertion
    order. *)

val equal_hit : hit -> hit -> bool
(** Structural equality on {!hit} values. *)
