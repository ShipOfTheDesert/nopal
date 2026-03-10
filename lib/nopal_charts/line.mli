(** Interactive line chart. REQ-F2, REQ-F9, REQ-F10, REQ-F11, REQ-F13.

    Renders one or more data series as polylines (straight) or Bezier paths
    (smooth). Supports optional area fill, point markers, vertical-band hit
    testing, and multi-series tooltips. Empty series produces a blank chart. *)

type 'a series = {
  data : 'a list;
  y : 'a -> float;
  color : Nopal_draw.Color.t;
  label : string;
  smooth : bool;
  area_fill : bool;
  show_points : bool;
}

val series :
  ?smooth:bool ->
  ?area_fill:bool ->
  ?show_points:bool ->
  label:string ->
  color:Nopal_draw.Color.t ->
  y:('a -> float) ->
  'a list ->
  'a series
(** Convenience constructor. Defaults: [smooth=false], [area_fill=false],
    [show_points=false]. *)

val view :
  series:'a series list ->
  x:('a -> float) ->
  width:float ->
  height:float ->
  ?padding:Padding.t ->
  ?x_axis:Axis.config ->
  ?y_axis:Axis.config ->
  ?format_tooltip:((string * float) list -> 'msg Nopal_element.Element.t) ->
  ?on_hover:(Hover.t -> 'msg) ->
  ?on_leave:'msg ->
  ?hover:Hover.t ->
  unit ->
  'msg Nopal_element.Element.t
(** [view ~series ~x ~width ~height ()] renders a multi-series line chart. Hover
    shows all series values at the hovered X position. [format_tooltip] receives
    [(series_label, value)] pairs. *)
