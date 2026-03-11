(** Tooltip rendering as canvas scene nodes.

    Tooltips are drawn directly on the chart canvas, avoiding DOM flex-layout
    issues. Position is automatically flipped to stay within chart bounds. *)

val text : string -> string
(** Identity — provided for API compatibility. [text s] returns [s]. *)

val scene :
  x:float ->
  y:float ->
  chart_width:float ->
  chart_height:float ->
  string ->
  Nopal_draw.Scene.t list
(** [scene ~x ~y ~chart_width ~chart_height content] renders a tooltip near
    [(x, y)] as canvas scene nodes. The tooltip is flipped to stay within the
    chart bounds. *)
