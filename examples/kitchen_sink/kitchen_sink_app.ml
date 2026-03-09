open Nopal_element
open Nopal_style

(* Color palette (REQ-F12) *)
let bg_page = Style.hex "#f8f9fa"
let bg_section = Style.hex "#ffffff"
let bg_accent = Style.hex "#4a90d9"
let bg_muted = Style.hex "#e9ecef"
let border_light = Style.hex "#dee2e6"

(* Shared styles *)
let section_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = 12.0 } |> Style.padding_all 16.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some bg_section;
        border =
          Some
            { width = 1.0; style = Solid; color = border_light; radius = 8.0 };
      })

let section_body_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = 8.0 })

let page_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = 16.0; width = Fill } |> Style.padding_all 24.0)
  |> Style.with_paint (fun p -> { p with background = Some bg_page })

(* Model *)
type model = {
  button_clicks : int;
  input_text : string;
  submit_input_text : string;
  submitted_value : string;
  keyed_items : (int * string) list;
  next_keyed_id : int;
  interaction_toggled : bool;
  sub_counter : Sub_counter.model;
}

(* Messages *)
type msg =
  | ButtonClicked
  | InputChanged of string
  | SubmitInputChanged of string
  | InputSubmitted
  | AddKeyedItem
  | RemoveKeyedItem of int
  | MoveKeyedItemUp of int
  | ToggleInteraction
  | SubCounterMsg of Sub_counter.msg

let init () =
  let sub_counter, sub_cmd = Sub_counter.init () in
  ( {
      button_clicks = 0;
      input_text = "";
      submit_input_text = "";
      submitted_value = "";
      keyed_items = [ (1, "Item 1"); (2, "Item 2"); (3, "Item 3") ];
      next_keyed_id = 4;
      interaction_toggled = false;
      sub_counter;
    },
    Nopal_mvu.Cmd.map (fun m -> SubCounterMsg m) sub_cmd )

let update model = function
  | ButtonClicked ->
      ( { model with button_clicks = model.button_clicks + 1 },
        Nopal_mvu.Cmd.none )
  | InputChanged text -> ({ model with input_text = text }, Nopal_mvu.Cmd.none)
  | SubmitInputChanged text ->
      ({ model with submit_input_text = text }, Nopal_mvu.Cmd.none)
  | InputSubmitted ->
      ( {
          model with
          submitted_value = model.submit_input_text;
          submit_input_text = "";
        },
        Nopal_mvu.Cmd.none )
  | AddKeyedItem ->
      let id = model.next_keyed_id in
      let item = (id, "Item " ^ string_of_int id) in
      ( {
          model with
          keyed_items = List.rev (item :: List.rev model.keyed_items);
          next_keyed_id = id + 1;
        },
        Nopal_mvu.Cmd.none )
  | RemoveKeyedItem id ->
      ( {
          model with
          keyed_items = List.filter (fun (i, _) -> i <> id) model.keyed_items;
        },
        Nopal_mvu.Cmd.none )
  | MoveKeyedItemUp id ->
      let rec move_up = function
        | a :: ((b_id, _) as b) :: rest when b_id = id -> b :: a :: rest
        | x :: rest -> x :: move_up rest
        | [] -> []
      in
      ( { model with keyed_items = move_up model.keyed_items },
        Nopal_mvu.Cmd.none )
  | ToggleInteraction ->
      ( { model with interaction_toggled = not model.interaction_toggled },
        Nopal_mvu.Cmd.none )
  | SubCounterMsg sub_msg ->
      let sub_counter, sub_cmd = Sub_counter.update model.sub_counter sub_msg in
      ( { model with sub_counter },
        Nopal_mvu.Cmd.map (fun m -> SubCounterMsg m) sub_cmd )

(* Section wrapper (REQ-F10) *)
let view_section title children =
  Element.column ~style:section_style
    [ Element.text title; Element.column ~style:section_body_style children ]

(* Section 1: Typography (REQ-F1) — container styling since typography properties are planned *)
let view_typography _model =
  let heading_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding_all 12.0)
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some bg_accent;
          border = Some { Style.default_border with radius = 4.0 };
        })
  in
  let muted_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding_all 10.0)
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some bg_muted;
          border =
            Some
              { width = 1.0; style = Solid; color = border_light; radius = 4.0 };
        })
  in
  let shadow_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding_all 10.0)
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some bg_section;
          shadow =
            Some { x = 0.0; y = 2.0; blur = 6.0; color = Style.rgba 0 0 0 0.15 };
        })
  in
  view_section "Typography"
    [
      Element.box ~style:heading_style
        [ Element.text "Heading-style container (accent background)" ];
      Element.box ~style:muted_style
        [ Element.text "Muted container (border + muted background)" ];
      Element.box ~style:shadow_style
        [ Element.text "Shadow container (elevated appearance)" ];
      Element.text
        "(Typography properties like font-size and text-color are planned)";
    ]

(* Section 2: Layout (REQ-F2) *)
let view_layout _model =
  let bordered_box_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding_all 8.0)
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some bg_muted;
          border =
            Some
              { width = 1.0; style = Solid; color = border_light; radius = 4.0 };
        })
  in
  let row_start_style =
    Style.default
    |> Style.with_layout (fun l -> { l with main_align = Start; gap = 8.0 })
  in
  let row_center_style =
    Style.default
    |> Style.with_layout (fun l -> { l with main_align = Center; gap = 8.0 })
  in
  let row_end_style =
    Style.default
    |> Style.with_layout (fun l -> { l with main_align = End_; gap = 8.0 })
  in
  let row_between_style =
    Style.default
    |> Style.with_layout (fun l ->
        { l with main_align = Space_between; gap = 8.0; width = Fill })
  in
  let col_gap_style =
    Style.default |> Style.with_layout (fun l -> { l with gap = 16.0 })
  in
  view_section "Layout"
    [
      Element.text "Box:";
      Element.box ~style:bordered_box_style
        [ Element.text "A single Box container" ];
      Element.text "Row (start):";
      Element.row ~style:row_start_style
        [
          Element.box ~style:bordered_box_style [ Element.text "A" ];
          Element.box ~style:bordered_box_style [ Element.text "B" ];
          Element.box ~style:bordered_box_style [ Element.text "C" ];
        ];
      Element.text "Row (center):";
      Element.row ~style:row_center_style
        [
          Element.box ~style:bordered_box_style [ Element.text "A" ];
          Element.box ~style:bordered_box_style [ Element.text "B" ];
        ];
      Element.text "Row (end):";
      Element.row ~style:row_end_style
        [
          Element.box ~style:bordered_box_style [ Element.text "X" ];
          Element.box ~style:bordered_box_style [ Element.text "Y" ];
        ];
      Element.text "Row (space-between):";
      Element.row ~style:row_between_style
        [
          Element.box ~style:bordered_box_style [ Element.text "Left" ];
          Element.box ~style:bordered_box_style [ Element.text "Right" ];
        ];
      Element.text "Column (gap = 16):";
      Element.column ~style:col_gap_style
        [
          Element.box ~style:bordered_box_style [ Element.text "Row 1" ];
          Element.box ~style:bordered_box_style [ Element.text "Row 2" ];
        ];
    ]

(* Section 3: Buttons (REQ-F3) *)
let view_buttons model =
  let default_button_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding 6.0 16.0 6.0 16.0)
  in
  let styled_button_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding 6.0 16.0 6.0 16.0)
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some bg_accent;
          border =
            Some
              {
                width = 1.0;
                style = Solid;
                color = Style.hex "#3a7bc8";
                radius = 6.0;
              };
          shadow =
            Some { x = 0.0; y = 1.0; blur = 3.0; color = Style.rgba 0 0 0 0.2 };
        })
  in
  let disabled_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding 6.0 16.0 6.0 16.0)
    |> Style.with_paint (fun p ->
        { p with background = Some bg_muted; opacity = 0.5 })
  in
  let row_style =
    Style.default
    |> Style.with_layout (fun l -> { l with gap = 8.0; cross_align = Center })
  in
  view_section "Buttons"
    [
      Element.row ~style:row_style
        [
          Element.button ~style:default_button_style ~on_click:ButtonClicked
            (Element.text "Click me");
          Element.text ("Clicks: " ^ string_of_int model.button_clicks);
        ];
      Element.button ~style:styled_button_style ~on_click:ButtonClicked
        (Element.text "Styled button");
      Element.button ~style:disabled_style
        (Element.text "Disabled-appearance button");
    ]

(* Section 4: Inputs (REQ-F4) *)
let view_inputs model =
  let input_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding 6.0 8.0 6.0 8.0)
    |> Style.with_paint (fun p ->
        {
          p with
          border =
            Some
              { width = 1.0; style = Solid; color = border_light; radius = 4.0 };
        })
  in
  let row_style =
    Style.default
    |> Style.with_layout (fun l -> { l with gap = 8.0; cross_align = Center })
  in
  view_section "Inputs"
    [
      Element.text "Text input (echoes value):";
      Element.input ~style:input_style
        ~on_change:(fun s -> InputChanged s)
        model.input_text;
      Element.text ("Echoed: " ^ model.input_text);
      Element.text "Input with placeholder:";
      Element.input ~style:input_style ~placeholder:"Type something here..." "";
      Element.text "Input with on_submit:";
      Element.row ~style:row_style
        [
          Element.input ~style:input_style ~placeholder:"Press Enter to submit"
            ~on_change:(fun s -> SubmitInputChanged s)
            ~on_submit:InputSubmitted model.submit_input_text;
        ];
      (match model.submitted_value with
      | "" -> Element.empty
      | value -> Element.text ("Submitted: " ^ value));
    ]

(* Section 5: Images (REQ-F5) *)
let view_images _model =
  view_section "Images"
    [ Element.image ~src:"assets/placeholder.png" ~alt:"Placeholder image" () ]

(* Section 6: Scroll (REQ-F6) *)
let view_scroll _model =
  let scroll_style =
    Style.default
    |> Style.with_layout (fun l -> { l with height = Fixed 120.0 })
    |> Style.with_paint (fun p ->
        {
          p with
          border =
            Some
              { width = 1.0; style = Solid; color = border_light; radius = 4.0 };
        })
  in
  let content_style =
    Style.default
    |> Style.with_layout (fun l ->
        { l with gap = 8.0 } |> Style.padding_all 8.0)
  in
  let items =
    List.init 20 (fun i ->
        Element.text ("Scroll item " ^ string_of_int (i + 1)))
  in
  view_section "Scroll"
    [
      Element.text "Fixed-height scroll container with overflowing content:";
      Element.scroll ~style:scroll_style
        (Element.column ~style:content_style items);
    ]

(* Section 7: Keyed Lists (REQ-F7) *)
let view_keyed model =
  let item_style =
    Style.default
    |> Style.with_layout (fun l ->
        { l with gap = 8.0; cross_align = Center }
        |> Style.padding 4.0 8.0 4.0 8.0)
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some bg_muted;
          border =
            Some
              { width = 1.0; style = Solid; color = border_light; radius = 4.0 };
        })
  in
  let btn_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding 2.0 8.0 2.0 8.0)
  in
  let items =
    List.map
      (fun (id, label) ->
        Element.keyed (string_of_int id)
          (Element.row ~style:item_style
             [
               Element.text label;
               Element.button ~style:btn_style ~on_click:(MoveKeyedItemUp id)
                 (Element.text "Up");
               Element.button ~style:btn_style ~on_click:(RemoveKeyedItem id)
                 (Element.text "Remove");
             ]))
      model.keyed_items
  in
  view_section "Keyed Lists"
    [
      Element.button ~style:btn_style ~on_click:AddKeyedItem
        (Element.text "Add item");
      Element.column ~style:section_body_style items;
    ]

(* Section 8: Nested Layout (REQ-F8) *)
let view_nested _model =
  let outer_style =
    Style.default
    |> Style.with_layout (fun l ->
        { l with gap = 8.0 } |> Style.padding_all 8.0)
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some bg_muted;
          border =
            Some
              { width = 1.0; style = Solid; color = border_light; radius = 4.0 };
        })
  in
  let inner_style =
    Style.default
    |> Style.with_layout (fun l ->
        { l with gap = 8.0 } |> Style.padding_all 8.0)
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some bg_section;
          border =
            Some
              { width = 1.0; style = Dashed; color = bg_accent; radius = 4.0 };
        })
  in
  let cell_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding_all 6.0)
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some bg_muted;
          border =
            Some
              { width = 1.0; style = Solid; color = border_light; radius = 2.0 };
        })
  in
  view_section "Nested Layout"
    [
      Element.column ~style:outer_style
        [
          Element.text "Outer column";
          Element.row ~style:inner_style
            [
              Element.box ~style:cell_style [ Element.text "Row > Cell 1" ];
              Element.box ~style:cell_style [ Element.text "Row > Cell 2" ];
            ];
          Element.column ~style:inner_style
            [
              Element.text "Inner column";
              Element.row ~style:inner_style
                [
                  Element.box ~style:cell_style [ Element.text "Nested A" ];
                  Element.box ~style:cell_style [ Element.text "Nested B" ];
                  Element.box ~style:cell_style [ Element.text "Nested C" ];
                ];
            ];
        ];
    ]

(* Section 9: Interaction States (PRD REQ-F7) *)
let view_interaction_states model =
  let btn_base_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding 6.0 16.0 6.0 16.0)
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some bg_accent;
          border =
            Some
              {
                width = 1.0;
                style = Solid;
                color = Style.hex "#3a7bc8";
                radius = 6.0;
              };
        })
  in
  let hover_btn_interaction =
    {
      Interaction.default with
      hover =
        Some
          (Style.default
          |> Style.with_paint (fun p ->
              { p with background = Some (Style.hex "#5ba0e9") }));
    }
  in
  let pressed_btn_interaction =
    {
      Interaction.default with
      hover =
        Some
          (Style.default
          |> Style.with_paint (fun p ->
              { p with background = Some (Style.hex "#5ba0e9") }));
      pressed =
        Some
          (Style.default
          |> Style.with_paint (fun p ->
              { p with background = Some (Style.hex "#2a6ab8") }));
    }
  in
  let focus_input_style =
    Style.default
    |> Style.with_layout (fun l -> l |> Style.padding 6.0 8.0 6.0 8.0)
    |> Style.with_paint (fun p ->
        {
          p with
          border =
            Some
              { width = 1.0; style = Solid; color = border_light; radius = 4.0 };
        })
  in
  let focus_interaction =
    {
      Interaction.default with
      focused =
        Some
          (Style.default
          |> Style.with_paint (fun p ->
              {
                p with
                border =
                  Some
                    {
                      width = 2.0;
                      style = Solid;
                      color = bg_accent;
                      radius = 4.0;
                    };
              }));
    }
  in
  let card_style =
    Style.default
    |> Style.with_layout (fun l ->
        { l with gap = 4.0 } |> Style.padding_all 12.0)
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some bg_muted;
          border =
            Some
              { width = 1.0; style = Solid; color = border_light; radius = 8.0 };
        })
  in
  let card_hover_interaction =
    {
      Interaction.default with
      hover =
        Some
          (Style.default
          |> Style.with_paint (fun p ->
              {
                p with
                background = Some (Style.hex "#d0e4f7");
                shadow =
                  Some
                    {
                      x = 0.0;
                      y = 2.0;
                      blur = 8.0;
                      color = Style.rgba 0 0 0 0.12;
                    };
              }));
    }
  in
  let row_style =
    Style.default
    |> Style.with_layout (fun l -> { l with gap = 8.0; cross_align = Center })
  in
  view_section "Interaction States"
    [
      Element.text "Button with hover highlight:";
      Element.button ~style:btn_base_style ~interaction:hover_btn_interaction
        ~attrs:[ ("data-testid", "hover-button") ]
        ~on_click:ButtonClicked (Element.text "Hover me");
      Element.text "Button with hover + pressed state:";
      Element.button ~style:btn_base_style ~interaction:pressed_btn_interaction
        ~attrs:[ ("data-testid", "pressed-button") ]
        ~on_click:ButtonClicked (Element.text "Press me");
      Element.text "Input with focus ring:";
      Element.row ~style:row_style
        [
          Element.input ~style:focus_input_style ~interaction:focus_interaction
            ~attrs:[ ("data-testid", "focus-input") ]
            ~placeholder:"Click to focus" "";
        ];
      Element.text "Clickable box card with hover highlight:";
      Element.box ~style:card_style ~interaction:card_hover_interaction
        ~attrs:[ ("data-testid", "hover-card") ]
        [
          Element.text "Hoverable Card";
          Element.text "This card highlights on hover";
        ];
      Element.text "Dynamic interaction toggle:";
      Element.row ~style:row_style
        [
          Element.button
            ~style:
              (Style.default
              |> Style.with_layout (fun l ->
                  l |> Style.padding 6.0 16.0 6.0 16.0))
            ~attrs:[ ("data-testid", "toggle-interaction-btn") ]
            ~on_click:ToggleInteraction
            (Element.text
               (if model.interaction_toggled then "Disable hover"
                else "Enable hover"));
          Element.box ~style:card_style
            ~interaction:
              (if model.interaction_toggled then card_hover_interaction
               else Interaction.default)
            ~attrs:[ ("data-testid", "toggle-card") ]
            [ Element.text "Toggleable card" ];
        ];
    ]

(* Section 10: Map / Composition (REQ-F9) *)
let view_composition model =
  view_section "Map / Composition"
    [
      Element.text "Sub-counter composed via Element.map:";
      Element.map
        (fun m -> SubCounterMsg m)
        (Sub_counter.view model.sub_counter);
    ]

(* Main view — all sections in a scrollable column (REQ-F10, REQ-F12) *)
let view model =
  Element.scroll
    (Element.column ~style:page_style
       [
         view_typography model;
         view_layout model;
         view_buttons model;
         view_inputs model;
         view_images model;
         view_scroll model;
         view_keyed model;
         view_nested model;
         view_interaction_states model;
         view_composition model;
       ])

let subscriptions _model = Nopal_mvu.Sub.none
