(** Interactive bar chart.

    Renders vertical bars from data with axes, hit testing, hover highlighting,
    and tooltip support. Empty data produces a blank chart. Zero-value bars have
    minimum visible height. Negative values render below baseline. When
    [domain_window] is provided with [x], data is clipped via [Viewport.clip]
    with [buffer=0].

    The X axis line and the X axis label are drawn here rather than by
    [Axis.render_x], and are painted with [x_axis.appearance] — its
    [line_color], [line_width] and [axis_label_color], [axis_label_size] — so a
    themed axis reaches them as it reaches the Y axis. There are no X tick marks
    and no X tick labels to paint: the per-bar category labels underneath the
    axis are series chrome, not axis chrome, and are not configurable. *)

val scene :
  data:'a list ->
  label:('a -> string) ->
  value:('a -> float) ->
  color:('a -> Nopal_draw.Color.t) ->
  ?x:('a -> float) ->
  width:float ->
  height:float ->
  ?padding:Padding.t ->
  ?x_axis:Axis.config ->
  ?y_axis:Axis.config ->
  ?domain_window:Domain_window.t ->
  unit ->
  Nopal_scene.Scene.t list
(** [scene ~data ~label ~value ~color ~width ~height ()] returns the scene nodes
    for a bar chart without wrapping in an element or adding interaction
    handlers. Use for SVG export or embedding in composite scenes. *)

val view :
  data:'a list ->
  label:('a -> string) ->
  value:('a -> float) ->
  color:('a -> Nopal_draw.Color.t) ->
  ?x:('a -> float) ->
  width:float ->
  height:float ->
  ?padding:Padding.t ->
  ?x_axis:Axis.config ->
  ?y_axis:Axis.config ->
  ?format_tooltip:('a -> 'msg Nopal_element.Element.t) ->
  ?on_hover:(Hover.t -> 'msg) ->
  ?on_leave:'msg ->
  ?hover:Hover.t ->
  ?domain_window:Domain_window.t ->
  unit ->
  'msg Nopal_element.Element.t
(** [view ~data ~label ~value ~color ~width ~height ()] renders an interactive
    bar chart. When [~x] and [~domain_window] are both provided, data is clipped
    to the visible window. *)
