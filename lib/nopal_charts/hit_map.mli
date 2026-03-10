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

type t

val empty : t
val add : region -> t -> t
val hit_test : t -> x:float -> y:float -> hit option
val equal_hit : hit -> hit -> bool
