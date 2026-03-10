val view :
  data:'a list ->
  value:('a -> float) ->
  label:('a -> string) ->
  color:('a -> Nopal_draw.Color.t) ->
  width:float ->
  height:float ->
  ?inner_radius:float ->
  ?label_threshold:float ->
  ?format_tooltip:('a -> 'msg Nopal_element.Element.t) ->
  ?on_hover:(Hover.t -> 'msg) ->
  ?on_leave:'msg ->
  ?hover:Hover.t ->
  unit ->
  'msg Nopal_element.Element.t
(** Renders a pie chart (inner_radius=0.0, default) or donut chart
    (inner_radius>0.0). Segment labels hidden below label_threshold (default: 15
    degrees). Hovered segment offsets outward. REQ-F4. *)
