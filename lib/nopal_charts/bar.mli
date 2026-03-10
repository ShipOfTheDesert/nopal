(** Interactive bar chart. REQ-F1, REQ-F9, REQ-F10, REQ-F11, REQ-F12, REQ-F13,
    REQ-F14.

    Renders vertical bars from data with axes, hit testing, hover highlighting,
    and tooltip support. Empty data produces a blank chart. Zero-value bars have
    minimum visible height. Negative values render below baseline. *)

val view :
  data:'a list ->
  label:('a -> string) ->
  value:('a -> float) ->
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
  unit ->
  'msg Nopal_element.Element.t
(** [view ~data ~label ~value ~color ~width ~height ()] renders an interactive
    bar chart. *)
