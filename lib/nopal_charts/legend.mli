(** Legend component for chart series labels and colour swatches. REQ-F7. *)

type direction = Horizontal | Vertical
type entry = { label : string; color : Nopal_draw.Color.t }

val entry : label:string -> color:Nopal_draw.Color.t -> entry
(** Convenience constructor. *)

val view :
  entries:entry list ->
  ?direction:direction ->
  ?style:Nopal_style.Style.t ->
  unit ->
  'msg Nopal_element.Element.t
(** Renders a legend as a Row (Horizontal) or Column (Vertical) of colour swatch
    \+ label pairs. Defaults to Horizontal. *)
