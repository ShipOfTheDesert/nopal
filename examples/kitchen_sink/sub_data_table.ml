open Nopal_element
open Nopal_ui
open Nopal_style

type person = { name : string; age : int; city : string }
type model = { data : person list; sort : Data_table.sort option }
type msg = Sort of string

let sample_data =
  [
    { name = "Alice"; age = 30; city = "Portland" };
    { name = "Bob"; age = 25; city = "Austin" };
    { name = "Carol"; age = 35; city = "Denver" };
    { name = "Dave"; age = 28; city = "Austin" };
    { name = "Eve"; age = 32; city = "Portland" };
  ]

let init () = ({ data = sample_data; sort = None }, Nopal_mvu.Cmd.none)

let compare_by_key key a b =
  match key with
  | "name" -> String.compare a.name b.name
  | "age" -> Int.compare a.age b.age
  (* "city" has no sort_key so it never reaches here; catch-all handles any
     future keys gracefully by treating them as equal. *)
  | _ -> 0

let sort_data key direction data =
  let cmp = compare_by_key key in
  let sorted = List.sort cmp data in
  match direction with
  | Data_table.Ascending -> sorted
  | Data_table.Descending -> List.rev sorted

let update model msg =
  match msg with
  | Sort key ->
      let direction =
        match model.sort with
        | Some { column; direction = Data_table.Ascending }
          when String.equal column key ->
            Data_table.Descending
        | _ -> Data_table.Ascending
      in
      let sort = Some Data_table.{ column = key; direction } in
      let data = sort_data key direction sample_data in
      ({ data; sort }, Nopal_mvu.Cmd.none)

let subscriptions _model = Nopal_mvu.Sub.none
let border_color = Style.Rgba { r = 220; g = 220; b = 220; a = 1.0 }

let table_style =
  Style.default
  |> Style.with_paint (fun p ->
      {
        p with
        border =
          Some
            { width = 1.0; style = Solid; color = border_color; radius = 6.0 };
      })

let col_width = Style.Fixed 150.0

let header_style =
  Style.default
  |> Style.with_layout (fun l ->
      l |> Style.padding 10.0 14.0 10.0 14.0 |> fun l ->
      { l with width = Some col_width })
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.Rgba { r = 245; g = 245; b = 245; a = 1.0 });
        border =
          Some
            { width = 1.0; style = Solid; color = border_color; radius = 0.0 };
      })
  |> Style.with_text (fun _ ->
      Text.default |> Text.font_weight Font.Semi_bold |> Text.font_size 0.85)

let cell_style =
  Style.default
  |> Style.with_layout (fun l ->
      l |> Style.padding 8.0 14.0 8.0 14.0 |> fun l ->
      { l with width = Some col_width })
  |> Style.with_paint (fun p ->
      {
        p with
        border =
          Some
            { width = 1.0; style = Solid; color = border_color; radius = 0.0 };
      })
  |> Style.with_text (fun _ -> Text.default |> Text.font_size 0.85)

let view _vp model =
  ignore (model : model);
  let columns =
    [
      Data_table.column ~header:"Name"
        ~cell:(fun p -> Element.text p.name)
        ~sort_key:"name" ();
      Data_table.column ~header:"Age"
        ~cell:(fun p -> Element.text (string_of_int p.age))
        ~sort_key:"age" ();
      Data_table.column ~header:"City" ~cell:(fun p -> Element.text p.city) ();
    ]
  in
  let config =
    Data_table.make ~columns ~rows:model.data
      ~key:(fun p -> p.name)
      ~on_sort:(fun key -> Sort key)
      ?sort:model.sort ~style:table_style ~header_style ~cell_style
      ~attrs:[ ("data-testid", "data-table") ]
      ()
  in
  Data_table.view config
