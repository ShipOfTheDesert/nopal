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
  column_style : (('row, 'msg) column -> Nopal_style.Style.t option) option;
  sort_control_style : Nopal_style.Style.t option;
  header_interaction : Nopal_style.Interaction.t option;
  header_row_style : Nopal_style.Style.t option;
}
(** Configuration for rendering a data table. All behavioural fields ([columns],
    [rows], [key], [on_sort]) are required parameters on [make].

    The last four fields are the per-column and header override surface. The
    supported route to them is {!with_column_style}, {!with_sort_control_style},
    {!with_header_interaction} and {!with_header_row_style} rather than writing
    them by hand; they are fields because a setter needs somewhere to put its
    value, and a caller who builds this record as a complete literal must supply
    them. *)

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
    [style], [interaction], and [attrs] default to [None]/empty, and so do the
    four override fields — a table built by [make] alone renders exactly as it
    did before they existed. *)

(** {1 Optional overrides} *)

val with_column_style :
  (('row, 'msg) column -> Nopal_style.Style.t option) ->
  ('row, 'msg) config ->
  ('row, 'msg) config
(** [with_column_style f config] styles one column at a time. For every column
    the table renders, [f] is asked for that column's style: [Some s] gives
    {e both} that column's header cell and every one of its data cells the style
    [s], and [None] leaves the column alone — it keeps [header_style] and
    [cell_style] like any other.

    A column's style {e replaces} [header_style] on its header box and
    [cell_style] on its cells; nothing is merged. It covers the header cell as
    well as the cells because a per-column width or alignment that reached only
    the cells would not line the column up with its own header, which is the
    decision this setter exists to make reachable.

    The function is keyed on the column value rather than on a string, because
    [sort_key] is optional and a non-sortable column has no name to key on. It
    is called once per column per render and must be total. Match on the
    column's [header] or [sort_key] to recognise it; comparing the whole record
    with [(=)] raises [Invalid_argument], because [cell] holds a function and
    structural equality cannot look at one.

    It does not reach the sortable header's button — that is
    {!with_sort_control_style} — nor the cell content, which [column ~cell]
    already gives the caller. *)

val with_sort_control_style :
  Nopal_style.Style.t -> ('row, 'msg) config -> ('row, 'msg) config
(** [with_sort_control_style style config] styles the button a column with a
    [sort_key] turns its header into. [header_style] and {!with_column_style}
    land on the box {e around} that button, never on the button itself, so
    without this setter the sort control's own appearance is unreachable.

    It replaces whatever the button would otherwise carry, which is nothing. A
    column with no [sort_key] renders no button and is unaffected. *)

val with_header_interaction :
  Nopal_style.Interaction.t -> ('row, 'msg) config -> ('row, 'msg) config
(** [with_header_interaction interaction config] gives every sortable header's
    button its hover, pressed and focused treatment. Like
    {!with_sort_control_style} it lands on the button, not on the header box
    around it — the button is the only thing in a header a user interacts with,
    and [config.interaction] lands on the table container.

    It replaces the button's interaction, which is otherwise unset. *)

val with_header_row_style :
  Nopal_style.Style.t -> ('row, 'msg) config -> ('row, 'msg) config
(** [with_header_row_style style config] styles the header row itself — the
    [role="row"] element holding the header cells. [row_style] reaches only the
    data rows, so without this setter the header row's own appearance is
    unreachable.

    It replaces the header row's style, which is otherwise unset. *)

(** {1 View} *)

val view : ('row, 'msg) config -> 'msg Nopal_element.Element.t
(** Renders the table. Each sortable header carries
    [data-action="datatable-sort"] plus [data-field=<column sort key>]. These
    anchors are the E2E selector contract (RFC 0112) and are asserted by
    [test_anchors.ml].

    Render the data table. The outer container carries [role="table"]. Header
    cells carry [role="columnheader"]; the active sort column carries
    [aria-sort]. Data cells carry [role="cell"]. Each data row is wrapped in
    [Element.keyed] using the config's [key] function. *)
