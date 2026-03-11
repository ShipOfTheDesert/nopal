(** Heat map chart — renders a 2D grid of colored cells. REQ-F1, REQ-F2.

    Each cell is colored by applying a [Color_scale] to its value. Empty data
    produces a blank chart. Hit map uses [Rect_region] per cell with
    [index = row * col_count + col]. Hovered cells are lightened toward white.

    Uses the accessor pattern for API consistency with other chart types. *)

val view :
  data:'a list ->
  row:('a -> int) ->
  col:('a -> int) ->
  value:('a -> float) ->
  row_count:int ->
  col_count:int ->
  ?row_labels:string list ->
  ?col_labels:string list ->
  scale:Color_scale.t ->
  width:float ->
  height:float ->
  ?padding:Padding.t ->
  ?format_tooltip:('a -> string) ->
  ?on_hover:(Hover.t -> 'msg) ->
  ?on_leave:'msg ->
  ?hover:Hover.t ->
  unit ->
  'msg Nopal_element.Element.t
(** [view ~data ~row ~col ~value ~row_count ~col_count ~scale ~width ~height ()]
    renders an interactive heat map. [data] is a flat list of data points;
    [row], [col], and [value] are accessor functions that extract grid
    coordinates and cell values from each datum. Cell colors are determined by
    [scale] applied over the data range. *)
