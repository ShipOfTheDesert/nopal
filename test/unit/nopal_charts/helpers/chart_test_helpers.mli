(** Shared helpers for chart unit tests. *)

val extract_draw :
  'msg Nopal_element.Element.t ->
  (Nopal_scene.Scene.t list
  * (Nopal_element.Element.pointer_event -> 'msg) option
  * 'msg option
  * float
  * float)
  option
(** Extract the Draw element's fields from a chart view result. Handles both
    bare [Draw] and [Box \{ children = [... Draw ...]; _ \}] wrappers that chart
    views may produce. *)

val count_nodes :
  (Nopal_scene.Scene.t -> bool) -> Nopal_scene.Scene.t list -> int
(** Recursively count scene nodes matching a predicate, traversing [Clip] and
    [Group] children. *)

val is_polyline : Nopal_scene.Scene.t -> bool
(** [true] when the node is a [Polyline]. *)

val is_path : Nopal_scene.Scene.t -> bool
(** [true] when the node is a [Path]. *)

val is_circle : Nopal_scene.Scene.t -> bool
(** [true] when the node is a [Circle]. *)

val is_rect : Nopal_scene.Scene.t -> bool
(** [true] when the node is a [Rect]. *)
