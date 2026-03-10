(** Shared chart composition — wraps a draw element with optional tooltip in a
    fixed-size container. Eliminates tooltip wiring duplication across chart
    modules. *)

val compose :
  draw_el:'msg Nopal_element.Element.t ->
  width:float ->
  height:float ->
  tooltip:'msg Nopal_element.Element.t option ->
  'msg Nopal_element.Element.t
(** [compose ~draw_el ~width ~height ~tooltip] wraps [draw_el] in a fixed-size
    Box. When [tooltip] is [Some el], the tooltip element is layered on top of
    the draw element. When [None], only the draw element is included. *)
