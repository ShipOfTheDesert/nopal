(** Interactive area chart. REQ-F3, REQ-F9, REQ-F10, REQ-F13.

    Renders one or more data series as filled areas. Supports stacked mode (each
    series baseline is the previous series' top) and overlapping mode (each
    series baseline is Y=0). Uses vertical-band hit testing and multi-series
    tooltips. Empty series produces a blank chart. *)

type mode = Stacked | Overlapping

type 'a series = {
  data : 'a list;
  y : 'a -> float;
  color : Nopal_draw.Color.t;
  label : string;
}

val series :
  label:string ->
  color:Nopal_draw.Color.t ->
  y:('a -> float) ->
  'a list ->
  'a series
(** Convenience constructor. *)

val scene :
  series:'a series list ->
  x:('a -> float) ->
  width:float ->
  height:float ->
  ?mode:mode ->
  ?padding:Padding.t ->
  ?x_axis:Axis.config ->
  ?y_axis:Axis.config ->
  ?domain_window:Domain_window.t ->
  unit ->
  Nopal_scene.Scene.t list
(** [scene ~series ~x ~width ~height ()] returns the scene nodes for a
    multi-series area chart without wrapping in an element or adding interaction
    handlers. Use for SVG export or embedding in composite scenes. *)

val view :
  series:'a series list ->
  x:('a -> float) ->
  width:float ->
  height:float ->
  ?mode:mode ->
  ?padding:Padding.t ->
  ?x_axis:Axis.config ->
  ?y_axis:Axis.config ->
  ?format_tooltip:((string * float) list -> 'msg Nopal_element.Element.t) ->
  ?on_hover:(Hover.t -> 'msg) ->
  ?on_leave:'msg ->
  ?hover:Hover.t ->
  ?domain_window:Domain_window.t ->
  unit ->
  'msg Nopal_element.Element.t
(** [view ~series ~x ~width ~height ()] renders a multi-series area chart.
    [mode] defaults to [Overlapping]. Stacked mode accumulates Y values.
    [format_tooltip] receives [(series_label, value)] pairs. REQ-F3. *)
