(** Drawdown chart — inverted area from 0% baseline downward. REQ-F3.

    Renders drawdown percentage data as an area chart extending downward from a
    0% baseline. Y domain is [{min_drawdown, 0.0}]. When [domain_window] is
    provided, data is clipped via [Viewport.clip] with [buffer=1]. Uses
    vertical-band hit testing and standard tooltip support. *)

val scene :
  data:'a list ->
  x:('a -> float) ->
  y:('a -> float) ->
  width:float ->
  height:float ->
  ?padding:Padding.t ->
  ?fill_color:Nopal_draw.Color.t ->
  ?x_axis:Axis.config ->
  ?y_axis:Axis.config ->
  ?domain_window:Domain_window.t ->
  unit ->
  Nopal_scene.Scene.t list
(** [scene ~data ~x ~y ~width ~height ()] returns the scene nodes for a drawdown
    chart without wrapping in an element or adding interaction handlers. Use for
    SVG export or embedding in composite scenes. *)

val view :
  data:'a list ->
  x:('a -> float) ->
  y:('a -> float) ->
  width:float ->
  height:float ->
  ?padding:Padding.t ->
  ?fill_color:Nopal_draw.Color.t ->
  ?x_axis:Axis.config ->
  ?y_axis:Axis.config ->
  ?format_tooltip:(int -> float -> 'msg Nopal_element.Element.t) ->
  ?on_hover:(Hover.t -> 'msg) ->
  ?on_leave:'msg ->
  ?hover:Hover.t ->
  ?domain_window:Domain_window.t ->
  unit ->
  'msg Nopal_element.Element.t
(** [view ~data ~x ~y ~width ~height ()] renders an interactive drawdown chart.
    [y] should return drawdown values (<= 0.0). [fill_color] defaults to a
    semi-transparent red. [format_tooltip] receives the data index and the
    drawdown value. *)
