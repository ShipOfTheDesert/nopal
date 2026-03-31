type sort_direction = Ascending | Descending
type sort = { column : string; direction : sort_direction }

type ('row, 'msg) column = {
  header : string;
  cell : 'row -> 'msg Nopal_element.Element.t;
  sort_key : string option;
}

type ('row, 'msg) config = {
  columns : ('row, 'msg) column list;
  rows : 'row list;
  key : 'row -> string;
  sort : sort option;
  on_sort : string -> 'msg;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
}

let column ~header ~cell ?sort_key () = { header; cell; sort_key }

let make ~columns ~rows ~key ~on_sort ?sort ?style ?interaction ?attrs () =
  let attrs =
    match attrs with
    | Some a -> a
    | None -> []
  in
  { columns; rows; key; sort; on_sort; style; interaction; attrs }

let view config =
  let module E = Nopal_element.Element in
  let aria_sort_for sort_key =
    match config.sort with
    | Some { column = col; direction } when String.equal col sort_key ->
        let dir_str =
          match direction with
          | Ascending -> "ascending"
          | Descending -> "descending"
        in
        [ ("aria-sort", dir_str) ]
    | Some _
    | None ->
        []
  in
  let render_header col =
    let base_attrs = [ ("role", "columnheader") ] in
    match col.sort_key with
    | Some key ->
        let attrs = base_attrs @ aria_sort_for key in
        E.box ~attrs
          [ E.button ~on_click:(config.on_sort key) (E.text col.header) ]
    | None -> E.box ~attrs:base_attrs [ E.text col.header ]
  in
  let header_row =
    E.row ~attrs:[ ("role", "row") ] (List.map render_header config.columns)
  in
  let render_cell row col =
    E.box ~attrs:[ ("role", "cell") ] [ col.cell row ]
  in
  let render_row row =
    let cells = List.map (render_cell row) config.columns in
    E.keyed (config.key row) (E.row ~attrs:[ ("role", "row") ] cells)
  in
  let data_rows = List.map render_row config.rows in
  let table_attrs = ("role", "table") :: config.attrs in
  E.column ~attrs:table_attrs ?style:config.style
    ?interaction:config.interaction (header_row :: data_rows)
