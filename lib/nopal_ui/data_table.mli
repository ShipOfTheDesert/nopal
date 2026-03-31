(** {1 Types} *)

(** Sort direction for a column. *)
type sort_direction = Ascending | Descending

type sort = { column : string; direction : sort_direction }
(** Current sort state — which column is sorted and in which direction. *)

type ('row, 'msg) column = {
  header : string;
  cell : 'row -> 'msg Nopal_element.Element.t;
  sort_key : string option;
}
(** A column definition. [header] is the text displayed in the column header.
    [cell] renders the cell content for a given row. [sort_key] identifies the
    column for sorting — when [None], the column header is not clickable. *)

type ('row, 'msg) config = {
  columns : ('row, 'msg) column list;
  rows : 'row list;
  key : 'row -> string;
  sort : sort option;
  on_sort : string -> 'msg;
  style : Nopal_style.Style.t option;
  header_style : Nopal_style.Style.t option;
  row_style : Nopal_style.Style.t option;
  cell_style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
}
(** Configuration for rendering a data table. All behavioural fields ([columns],
    [rows], [key], [on_sort]) are required parameters on [make]. *)

(** {1 Construction} *)

val column :
  header:string ->
  cell:('row -> 'msg Nopal_element.Element.t) ->
  ?sort_key:string ->
  unit ->
  ('row, 'msg) column
(** Create a column definition. When [sort_key] is provided, the header becomes
    a clickable button that dispatches the sort message. *)

val make :
  columns:('row, 'msg) column list ->
  rows:'row list ->
  key:('row -> string) ->
  on_sort:(string -> 'msg) ->
  ?sort:sort ->
  ?style:Nopal_style.Style.t ->
  ?header_style:Nopal_style.Style.t ->
  ?row_style:Nopal_style.Style.t ->
  ?cell_style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  ?attrs:(string * string) list ->
  unit ->
  ('row, 'msg) config
(** Create a data table config. [sort] defaults to [None] (no active sort).
    [style], [interaction], and [attrs] default to [None]/empty. *)

(** {1 View} *)

val view : ('row, 'msg) config -> 'msg Nopal_element.Element.t
(** Render the data table. The outer container carries [role="table"]. Header
    cells carry [role="columnheader"]; the active sort column carries
    [aria-sort]. Data cells carry [role="cell"]. Each data row is wrapped in
    [Element.keyed] using the config's [key] function. *)
