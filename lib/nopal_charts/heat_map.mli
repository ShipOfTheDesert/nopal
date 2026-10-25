(** Heat map chart — renders a 2D grid of colored cells.

    Each cell is colored by applying a [Color_scale] to its value. Empty data
    produces a blank chart. Hit map uses [Rect_region] per cell with
    [index = row * col_count + col]. Hovered cells are lightened toward white.

    Uses the accessor pattern for API consistency with other chart types. *)

val scene :
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
  unit ->
  Nopal_scene.Scene.t list
(** [scene ~data ~row ~col ~value ~row_count ~col_count ~scale ~width ~height
     ()] returns the scene nodes for a heat map without wrapping in an element
    or adding interaction handlers. Use for SVG export or embedding in composite
    scenes. *)

val view :
  name:Nopal_element.Graphic_name.t ->
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
  ?format_tooltip:('a -> 'msg Nopal_element.Element.t) ->
  ?on_hover:(Hover.t -> 'msg) ->
  ?on_leave:'msg ->
  ?hover:Hover.t ->
  unit ->
  'msg Nopal_element.Element.t
(** [view ~name ~data ~row ~col ~value ~row_count ~col_count ~scale ~width
     ~height ()] renders an interactive heat map. [data] is a flat list of data
    points; [row], [col], and [value] are accessor functions that extract grid
    coordinates and cell values from each datum. Cell colors are determined by
    [scale] applied over the data range.

    [name] is the accessible-name decision for the chart's canvas. It is passed
    to [Nopal_element.Element.draw] unchanged, including when there is no data
    to draw. The view takes no attribute list; if one is added, [name] outranks
    it, as on [Nopal_element.Element.draw]. *)
