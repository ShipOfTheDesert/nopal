val text : string -> 'msg Nopal_element.Element.t
(** Simple text tooltip content. Renders as a styled Text element with default
    tooltip appearance (dark background, white text, padding). *)

val container :
  x:float ->
  y:float ->
  chart_width:float ->
  chart_height:float ->
  'msg Nopal_element.Element.t ->
  'msg Nopal_element.Element.t
(** Wraps tooltip content in an absolutely-positioned container near (x, y).
    Flips position to stay within chart bounds. *)
