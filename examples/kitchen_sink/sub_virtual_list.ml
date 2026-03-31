open Nopal_element
open Nopal_style

let item_count = 10_000

let row_height =
  (* These literals are compile-time constants known to be valid;
     Option.get is safe here. *)
  Option.get (Virtual_list.Positive_float.of_float 40.0)

let container_height = Option.get (Virtual_list.Positive_float.of_float 400.0)
let nat_item_count = Option.get (Virtual_list.Natural.of_int item_count)
let overscan = Option.get (Virtual_list.Natural.of_int 5)

type model = { scroll_offset : float; visible_first : int; visible_last : int }
type msg = Scrolled of float

let compute_range offset =
  let scroll_state = Virtual_list.scroll_state ~offset in
  Virtual_list.visible_range ~scroll_state ~row_height ~container_height
    ~item_count:nat_item_count ~overscan

let init () =
  let range = compute_range 0.0 in
  ( {
      scroll_offset = 0.0;
      visible_first = range.first;
      visible_last = range.last;
    },
    Nopal_mvu.Cmd.none )

let update _model msg =
  match msg with
  | Scrolled offset ->
      let range = compute_range offset in
      ( {
          scroll_offset = offset;
          visible_first = range.first;
          visible_last = range.last;
        },
        Nopal_mvu.Cmd.none )

let subscriptions _model = Nopal_mvu.Sub.none

let info_style =
  Style.default
  |> Style.with_layout (fun l -> { l with gap = Some 4.0 })
  |> Style.with_text (fun _ -> Text.default |> Text.font_size 0.85)

let row_style =
  Style.default
  |> Style.with_layout (fun l ->
      l |> Style.padding 8.0 12.0 8.0 12.0 |> fun l ->
      { l with cross_align = Some Center })
  |> Style.with_paint (fun p ->
      {
        p with
        border =
          Some
            {
              width = 0.0;
              style = Solid;
              color = Style.Rgba { r = 0; g = 0; b = 0; a = 0.0 };
              radius = 0.0;
            };
      })

let alt_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      l |> Style.padding 8.0 12.0 8.0 12.0 |> fun l ->
      { l with cross_align = Some Center })
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.Rgba { r = 245; g = 245; b = 245; a = 1.0 });
      })

let view _vp model =
  ignore (model : model);
  let info =
    Element.column ~style:info_style
      [
        Element.text
          (Printf.sprintf "Scroll offset: %.0f px" model.scroll_offset);
        Element.text
          (Printf.sprintf "Visible range: %d – %d (%d items)"
             model.visible_first model.visible_last
             (model.visible_last - model.visible_first + 1));
        Element.text (Printf.sprintf "Total items: %d" item_count);
      ]
  in
  let scroll_state = Virtual_list.scroll_state ~offset:model.scroll_offset in
  let list =
    Element.virtual_list
      ~on_scroll:(fun offset -> Scrolled offset)
      ~item_count:nat_item_count ~row_height ~container_height ~scroll_state
      ~overscan
      (fun i ->
        let style = if i mod 2 = 0 then row_style else alt_row_style in
        Element.box ~style
          ~attrs:[ ("data-testid", Printf.sprintf "vl-row-%d" i) ]
          [
            Element.text (Printf.sprintf "Item %d — virtual list row content" i);
          ])
  in
  Element.column ~attrs:[ ("data-testid", "virtual-list-demo") ] [ info; list ]
