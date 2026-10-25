(** Interactive scatter chart.

    Renders data points as circles with optional variable radius (bubble chart).
    Empty data produces a blank chart. Default radius is 4.0. Hovered point is
    enlarged. Hit map uses Circle_region per point; last-drawn takes priority
    for overlapping points. *)

val scene :
  data:'a list ->
  x:('a -> float) ->
  y:('a -> float) ->
  ?radius:('a -> float) ->
  color:('a -> Nopal_draw.Color.t) ->
  width:float ->
  height:float ->
  ?padding:Padding.t ->
  ?x_axis:Axis.config ->
  ?y_axis:Axis.config ->
  ?domain_window:Domain_window.t ->
  unit ->
  Nopal_scene.Scene.t list
(** [scene ~data ~x ~y ~color ~width ~height ()] returns the scene nodes for a
    scatter chart without wrapping in an element or adding interaction handlers.
    Use for SVG export or embedding in composite scenes. *)

val view :
  name:Nopal_element.Graphic_name.t ->
  data:'a list ->
  x:('a -> float) ->
  y:('a -> float) ->
  ?radius:('a -> float) ->
  color:('a -> Nopal_draw.Color.t) ->
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
(** [view ~name ~data ~x ~y ~color ~width ~height ()] renders an interactive
    scatter chart. Variable [radius] makes it a bubble chart. Default radius is
    4.0. Default color uses the first categorical palette entry.

    [name] is the accessible-name decision for the chart's canvas. It is passed
    to [Nopal_element.Element.draw] unchanged, including when there is no data
    to draw. The view takes no attribute list; if one is added, [name] outranks
    it, as on [Nopal_element.Element.draw]. *)
