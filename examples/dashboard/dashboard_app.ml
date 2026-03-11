open Nopal_element
open Nopal_style
open Nopal_charts

let cat = Nopal_draw.Color.categorical

(* Shared styles *)
let page_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = 20.0 } |> Style.padding 32.0 32.0 32.0 32.0)
  |> Style.with_paint (fun p ->
      { p with background = Some (Style.hex "#faf9f7") })

let page_title_text =
  Text.default
  |> Text.font_size 1.8
  |> Text.font_weight Font.Bold
  |> Text.font_family System_ui

let page_subtitle_text = Text.default |> Text.font_size 0.95

let card_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = 12.0 } |> Style.padding_all 20.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#ffffff");
        border =
          Some
            {
              width = 1.0;
              style = Solid;
              color = Style.hex "#e5e3df";
              radius = 10.0;
            };
        shadow =
          Some { x = 0.0; y = 1.0; blur = 6.0; color = Style.rgba 0 0 0 0.04 };
      })

let row_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = 16.0 })

let detail_style =
  Style.default
  |> Style.with_layout (fun l -> { l with gap = 4.0 } |> Style.padding_all 14.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#f5f4f1");
        border =
          Some
            {
              width = 1.0;
              style = Solid;
              color = Style.hex "#e5e3df";
              radius = 8.0;
            };
      })

let card_heading_text =
  Text.default
  |> Text.font_size 0.9
  |> Text.font_weight Font.Semi_bold
  |> Text.letter_spacing (Ls_em 0.02)

(* Sample data — monthly revenue and costs *)
type month_data = {
  month : string;
  revenue : float;
  costs : float;
  customers : float;
}

let data =
  [
    { month = "Jan"; revenue = 30.0; costs = 20.0; customers = 120.0 };
    { month = "Feb"; revenue = 45.0; costs = 25.0; customers = 150.0 };
    { month = "Mar"; revenue = 25.0; costs = 22.0; customers = 110.0 };
    { month = "Apr"; revenue = 60.0; costs = 30.0; customers = 200.0 };
    { month = "May"; revenue = 35.0; costs = 28.0; customers = 160.0 };
    { month = "Jun"; revenue = 50.0; costs = 32.0; customers = 180.0 };
  ]

(* Pie data — revenue breakdown *)
let pie_data =
  [
    ("Product A", 45.0, cat.(0));
    ("Product B", 30.0, cat.(1));
    ("Product C", 15.0, cat.(2));
    ("Services", 10.0, cat.(3));
  ]

(* Model *)
type model = { hover : Hover.t option }

(* Messages *)
type msg = ChartHovered of Hover.t | ChartLeft

let init () = ({ hover = None }, Nopal_mvu.Cmd.none)

let update _model msg =
  match msg with
  | ChartHovered h -> ({ hover = Some h }, Nopal_mvu.Cmd.none)
  | ChartLeft -> ({ hover = None }, Nopal_mvu.Cmd.none)

let view _vp model =
  let chart_w = 380.0 in
  let chart_h = 220.0 in
  (* Detail panel: show hovered data point *)
  let detail_text =
    match model.hover with
    | Some h when h.Hover.index < List.length data ->
        let d = List.nth data h.Hover.index in
        Printf.sprintf
          "Selected: %s — Revenue: %.0f, Costs: %.0f, Customers: %.0f" d.month
          d.revenue d.costs d.customers
    | _ -> "Hover over a chart to see details"
  in
  Element.scroll
    (Element.column ~style:page_style
       ~attrs:[ ("data-section", "dashboard") ]
       [
         Element.styled_text ~text_style:page_title_text "Dashboard";
         Element.styled_text ~text_style:page_subtitle_text
           "Interactive data visualization with linked charts.";
         (* Detail panel *)
         Element.box ~style:detail_style
           ~attrs:[ ("data-testid", "detail-panel") ]
           [ Element.text detail_text ];
         (* Row: bar chart + line chart *)
         Element.row ~style:row_style
           [
             (* Bar chart: revenue *)
             Element.column ~style:card_style
               ~attrs:[ ("data-testid", "dashboard-bar") ]
               [
                 Element.styled_text ~text_style:card_heading_text
                   "Monthly Revenue";
                 Bar.view ~data
                   ~label:(fun d -> d.month)
                   ~value:(fun d -> d.revenue)
                   ~color:(fun _ -> cat.(0))
                   ~width:chart_w ~height:chart_h
                   ~format_tooltip:(fun d ->
                     Tooltip.text (Printf.sprintf "%s: %.0f" d.month d.revenue))
                   ~on_hover:(fun h -> ChartHovered h)
                   ~on_leave:ChartLeft ?hover:model.hover ();
               ];
             (* Line chart: revenue + costs *)
             Element.column ~style:card_style
               ~attrs:[ ("data-testid", "dashboard-line") ]
               [
                 Element.styled_text ~text_style:card_heading_text
                   "Revenue vs Costs";
                 Line.view
                   ~series:
                     [
                       Line.series ~smooth:true ~show_points:true
                         ~label:"Revenue" ~color:cat.(0)
                         ~y:(fun d -> d.revenue)
                         data;
                       Line.series ~show_points:true ~label:"Costs"
                         ~color:cat.(1)
                         ~y:(fun d -> d.costs)
                         data;
                     ]
                   ~x:(fun d ->
                     Float.of_int
                       (match
                          List.find_index
                            (fun d2 -> String.equal d2.month d.month)
                            data
                        with
                       | Some i -> i
                       | None -> 0))
                   ~width:chart_w ~height:chart_h
                   ~format_tooltip:(fun entries ->
                     Tooltip.text
                       (String.concat ", "
                          (List.map
                             (fun (l, v) -> Printf.sprintf "%s: %.0f" l v)
                             entries)))
                   ~on_hover:(fun h -> ChartHovered h)
                   ~on_leave:ChartLeft ?hover:model.hover ();
               ];
           ];
         (* Row: pie chart + legend *)
         Element.row ~style:row_style
           [
             Element.column ~style:card_style
               [
                 Element.styled_text ~text_style:card_heading_text
                   "Revenue Breakdown";
                 Pie.view ~data:pie_data
                   ~value:(fun (_, v, _) -> v)
                   ~label:(fun (l, _, _) -> l)
                   ~color:(fun (_, _, c) -> c)
                   ~width:200.0 ~height:200.0
                   ~format_tooltip:(fun (l, v, _) ->
                     Tooltip.text (Printf.sprintf "%s: %.0f%%" l v))
                   ();
               ];
             Element.column ~style:card_style
               ~attrs:[ ("data-testid", "dashboard-legend") ]
               [
                 Element.styled_text ~text_style:card_heading_text "Legend";
                 (* Legend entries dim when another index is hovered *)
                 (let all_entries =
                    [
                      (0, Legend.entry ~label:"Revenue" ~color:cat.(0));
                      (1, Legend.entry ~label:"Costs" ~color:cat.(1));
                      (2, Legend.entry ~label:"Product A" ~color:cat.(0));
                      (3, Legend.entry ~label:"Product B" ~color:cat.(1));
                      (4, Legend.entry ~label:"Product C" ~color:cat.(2));
                      (5, Legend.entry ~label:"Services" ~color:cat.(3));
                    ]
                  in
                  let entries =
                    List.map
                      (fun (i, e) ->
                        match model.hover with
                        | Some h when h.Hover.index <> i ->
                            (* Dim non-hovered entries by lerping color toward white *)
                            let dimmed =
                              Nopal_draw.Color.lerp e.Legend.color
                                Nopal_draw.Color.white 0.6
                            in
                            Legend.entry ~label:e.label ~color:dimmed
                        | _ -> e)
                      all_entries
                  in
                  Legend.view ~entries ~direction:Legend.Vertical ());
               ];
           ];
       ])

let subscriptions _model = Nopal_mvu.Sub.none
