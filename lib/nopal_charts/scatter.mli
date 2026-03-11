(** Interactive scatter chart. REQ-F5, REQ-F9, REQ-F10, REQ-F13, REQ-F15.

    Renders data points as circles with optional variable radius (bubble chart).
    Empty data produces a blank chart. Default radius is 4.0. Hovered point is
    enlarged. Hit map uses Circle_region per point; last-drawn takes priority
    for overlapping points. *)

val view :
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
  ?format_tooltip:('a -> string) ->
  ?on_hover:(Hover.t -> 'msg) ->
  ?on_leave:'msg ->
  ?hover:Hover.t ->
  ?domain_window:Domain_window.t ->
  unit ->
  'msg Nopal_element.Element.t
(** [view ~data ~x ~y ~color ~width ~height ()] renders an interactive scatter
    chart. Variable [radius] makes it a bubble chart. Default radius is 4.0.
    Default color uses the first categorical palette entry. *)
