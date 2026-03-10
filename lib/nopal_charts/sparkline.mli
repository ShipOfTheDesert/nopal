(** Minimal inline sparkline chart. REQ-F6, REQ-F13.

    Renders a small line chart with no axes, labels, or interaction. Suitable
    for embedding in table cells and list items. *)

val view :
  data:float list ->
  width:float ->
  height:float ->
  ?color:Nopal_draw.Color.t ->
  ?stroke_width:float ->
  unit ->
  'msg Nopal_element.Element.t
(** [view ~data ~width ~height ()] renders a sparkline. Defaults:
    [color = Color.categorical.(0)], [stroke_width = 1.5]. Empty data produces a
    blank chart (Draw with empty scene). *)
