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
