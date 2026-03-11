open Nopal_element
open Nopal_style
open Nopal_draw
open Nopal_charts

(* Color palette *)
let bg_page = Style.hex "#f8f9fa"
let bg_section = Style.hex "#ffffff"
let bg_accent = Style.hex "#4a90d9"
let bg_muted = Style.hex "#e9ecef"
let border_light = Style.hex "#dee2e6"

(* Shared styles *)
let section_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = 12.0 } |> Style.padding_all 20.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some bg_section;
        border =
          Some
            { width = 1.0; style = Solid; color = border_light; radius = 10.0 };
        shadow =
          Some { x = 0.0; y = 1.0; blur = 6.0; color = Style.rgba 0 0 0 0.04 };
      })

let section_body_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = 8.0 })

let page_title_text =
  Text.default
  |> Text.font_size 1.8
  |> Text.font_weight Font.Bold
  |> Text.font_family System_ui

let page_subtitle_text = Text.default |> Text.font_size 0.95

let page_header_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = 4.0; cross_align = Center }
      |> Style.padding 8.0 0.0 8.0 0.0)

let page_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = 20.0 } |> Style.padding 32.0 32.0 32.0 32.0)
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
  draw_pointer : (float * float) option;
  chart_hover : Hover.t option;
  pie_hover : Hover.t option;
  scatter_hover : Hover.t option;
  heat_map_hover : Hover.t option;
  trading_hover : Hover.t option;
  domain_window : Domain_window.t;
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
  | DrawPointerMove of float * float
  | DrawPointerLeave
  | ChartHovered of Hover.t
  | ChartLeft
  | PieHovered of Hover.t
  | PieLeft
  | ScatterHovered of Hover.t
  | ScatterLeft
  | HeatMapHovered of Hover.t
  | HeatMapLeft
  | TradingHovered of Hover.t
  | TradingLeft
  | Pan of float
  | Zoom of float * float

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
      draw_pointer = None;
      chart_hover = None;
      pie_hover = None;
      scatter_hover = None;
      heat_map_hover = None;
      trading_hover = None;
      domain_window = Domain_window.create ~x_min:0.0 ~x_max:50.0;
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
  | DrawPointerMove (x, y) ->
      ({ model with draw_pointer = Some (x, y) }, Nopal_mvu.Cmd.none)
  | DrawPointerLeave -> ({ model with draw_pointer = None }, Nopal_mvu.Cmd.none)
  | ChartHovered h -> ({ model with chart_hover = Some h }, Nopal_mvu.Cmd.none)
  | ChartLeft -> ({ model with chart_hover = None }, Nopal_mvu.Cmd.none)
  | PieHovered h -> ({ model with pie_hover = Some h }, Nopal_mvu.Cmd.none)
  | PieLeft -> ({ model with pie_hover = None }, Nopal_mvu.Cmd.none)
  | ScatterHovered h ->
      ({ model with scatter_hover = Some h }, Nopal_mvu.Cmd.none)
  | ScatterLeft -> ({ model with scatter_hover = None }, Nopal_mvu.Cmd.none)
  | HeatMapHovered h ->
      ({ model with heat_map_hover = Some h }, Nopal_mvu.Cmd.none)
  | HeatMapLeft -> ({ model with heat_map_hover = None }, Nopal_mvu.Cmd.none)
  | TradingHovered h ->
      ({ model with trading_hover = Some h }, Nopal_mvu.Cmd.none)
  | TradingLeft -> ({ model with trading_hover = None }, Nopal_mvu.Cmd.none)
  | Pan delta ->
      let dw = Domain_window.pan model.domain_window ~delta in
      ({ model with domain_window = dw }, Nopal_mvu.Cmd.none)
  | Zoom (center, factor) ->
      let dw = Domain_window.zoom model.domain_window ~center ~factor in
      ({ model with domain_window = dw }, Nopal_mvu.Cmd.none)

(* Section wrapper (REQ-F10) *)
let view_section title children =
  Element.column ~style:section_style
    [ Element.text title; Element.column ~style:section_body_style children ]

(* Section 1: Typography *)
let view_typography _model =
  let open Nopal_style in
  (* Heading scale h1–h4 *)
  let heading size label =
    Element.styled_text
      ~text_style:
        (Text.default |> Text.font_size size |> Text.font_weight Font.Bold)
      label
  in
  (* Fixed-width container for ellipsis demo *)
  let fixed_width_style =
    Style.default |> Style.with_layout (fun l -> { l with width = Fixed 150.0 })
  in
  (* Alignment container: block-level div with text-align set via Style.t text *)
  let align_box align ~attrs children =
    let style =
      Style.default
      |> Style.with_layout (fun l -> { l with width = Fill })
      |> Style.with_text (fun t -> t |> Text.text_align align)
    in
    Element.box ~style ~attrs children
  in
  (* Weight label helper *)
  let weight_item (w : Font.weight) (label : string) (testid : string) =
    Element.box
      ~attrs:[ ("data-testid", testid) ]
      [
        Element.styled_text
          ~text_style:(Text.default |> Text.font_weight w)
          label;
      ]
  in
  Element.column ~style:section_style
    ~attrs:[ ("data-section", "typography") ]
    [
      Element.text "Typography";
      Element.column ~style:section_body_style
        [
          Element.text "Heading scale:";
          Element.box
            ~attrs:[ ("data-testid", "heading-h1") ]
            [ heading 2.0 "Heading 1 (2rem)" ];
          Element.box
            ~attrs:[ ("data-testid", "heading-h2") ]
            [ heading 1.5 "Heading 2 (1.5rem)" ];
          Element.box
            ~attrs:[ ("data-testid", "heading-h3") ]
            [ heading 1.25 "Heading 3 (1.25rem)" ];
          Element.box
            ~attrs:[ ("data-testid", "heading-h4") ]
            [ heading 1.0 "Heading 4 (1rem)" ];
          Element.text "Body copy with line height:";
          Element.box
            ~attrs:[ ("data-testid", "body-copy") ]
            [
              Element.styled_text
                ~text_style:
                  (Text.default
                  |> Text.font_size 1.0
                  |> Text.line_height (Lh_multiplier 1.6))
                "This is body text with a 1.6x line-height multiplier for \
                 comfortable reading.";
            ];
          Element.text "Monospace block:";
          Element.box
            ~attrs:[ ("data-testid", "monospace-block") ]
            [
              Element.styled_text
                ~text_style:(Text.default |> Text.font_family Monospace)
                "let x = 42 in x + 1";
            ];
          Element.text "Full 9-weight scale:";
          Element.column ~style:section_body_style
            [
              weight_item Thin "Thin (100)" "weight-100";
              weight_item Extra_light "Extra Light (200)" "weight-200";
              weight_item Light "Light (300)" "weight-300";
              weight_item Normal "Normal (400)" "weight-400";
              weight_item Medium "Medium (500)" "weight-500";
              weight_item Semi_bold "Semi Bold (600)" "weight-600";
              weight_item Bold "Bold (700)" "weight-700";
              weight_item Extra_bold "Extra Bold (800)" "weight-800";
              weight_item Black "Black (900)" "weight-900";
            ];
          Element.text "Ellipsis truncation:";
          Element.box ~style:fixed_width_style
            ~attrs:[ ("data-testid", "ellipsis-text") ]
            [
              Element.styled_text
                ~text_style:(Text.default |> Text.text_overflow Ellipsis)
                "This text is long enough to be truncated with an ellipsis in \
                 a narrow container.";
            ];
          Element.text "Wrap vs no-wrap:";
          Element.box ~style:fixed_width_style
            [
              Element.styled_text
                ~text_style:(Text.default |> Text.text_overflow Wrap)
                "This text wraps normally in a fixed container.";
            ];
          Element.box ~style:fixed_width_style
            [
              Element.styled_text
                ~text_style:(Text.default |> Text.text_overflow No_wrap)
                "This text does not wrap and overflows.";
            ];
          Element.text "Text alignment:";
          align_box Align_left
            ~attrs:[ ("data-testid", "align-left") ]
            [ Element.text "Left aligned" ];
          align_box Align_center
            ~attrs:[ ("data-testid", "align-center") ]
            [ Element.text "Center aligned" ];
          align_box Align_right
            ~attrs:[ ("data-testid", "align-right") ]
            [ Element.text "Right aligned" ];
          align_box Align_justify
            ~attrs:[ ("data-testid", "align-justify") ]
            [
              Element.text
                "Justified text that needs to be long enough to show the \
                 justification effect across the full width of the container.";
            ];
          Element.text "Italic text:";
          Element.box
            ~attrs:[ ("data-testid", "italic-text") ]
            [
              Element.styled_text
                ~text_style:(Text.default |> Text.italic true)
                "This text is italic.";
            ];
          Element.text "Text transforms:";
          Element.box
            ~attrs:[ ("data-testid", "transform-uppercase") ]
            [
              Element.styled_text
                ~text_style:(Text.default |> Text.text_transform Uppercase)
                "uppercase text";
            ];
          Element.box
            ~attrs:[ ("data-testid", "transform-lowercase") ]
            [
              Element.styled_text
                ~text_style:(Text.default |> Text.text_transform Lowercase)
                "LOWERCASE TEXT";
            ];
          Element.box
            ~attrs:[ ("data-testid", "transform-capitalize") ]
            [
              Element.styled_text
                ~text_style:(Text.default |> Text.text_transform Capitalize)
                "capitalize each word";
            ];
        ];
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

(* Section 10: 2D Drawing (REQ-F13) *)
let view_draw model =
  let pi = Float.pi in
  (* Helpers for gradient results *)
  let unwrap_gradient = function
    | Ok g -> g
    | Error _ -> Paint.no_paint
  in
  (* Colors *)
  let red = Color.red in
  let blue = Color.blue in
  let green = Color.green in
  let black = Color.black in
  let white = Color.white in
  (* Basic shapes scene *)
  let shapes_scene =
    [
      (* Sharp rect *)
      Scene.rect ~fill:(Paint.solid blue) ~x:10.0 ~y:10.0 ~w:60.0 ~h:40.0 ();
      (* Rounded rect *)
      Scene.rect ~fill:(Paint.solid green) ~rx:8.0 ~ry:8.0 ~x:80.0 ~y:10.0
        ~w:60.0 ~h:40.0 ();
      (* Circle *)
      Scene.circle ~fill:(Paint.solid red) ~cx:180.0 ~cy:30.0 ~r:20.0 ();
      (* Ellipse *)
      Scene.ellipse
        ~fill:(Paint.solid (Color.rgba ~r:0.6 ~g:0.2 ~b:0.8 ~a:1.0))
        ~cx:240.0 ~cy:30.0 ~rx:30.0 ~ry:15.0 ();
      (* Line *)
      Scene.line
        ~stroke:(Paint.stroke ~width:2.0 (Paint.solid black))
        ~x1:290.0 ~y1:10.0 ~x2:340.0 ~y2:50.0 ();
      (* Polygon (triangle) *)
      Scene.polygon
        ~fill:(Paint.solid (Color.rgba ~r:1.0 ~g:0.6 ~b:0.0 ~a:1.0))
        [ (360.0, 50.0); (385.0, 10.0); (410.0, 50.0) ];
      (* Polyline *)
      Scene.polyline
        ~stroke:(Paint.stroke ~width:2.0 (Paint.solid black))
        [
          (420.0, 50.0);
          (435.0, 10.0);
          (450.0, 30.0);
          (465.0, 10.0);
          (480.0, 50.0);
        ];
    ]
  in
  (* Path variants scene *)
  let path_scene =
    [
      (* Smooth curve *)
      Scene.path
        ~stroke:(Paint.stroke ~width:2.0 (Paint.solid blue))
        ~fill:Paint.no_paint
        (Path.smooth_curve
           [
             (10.0, 40.0);
             (40.0, 10.0);
             (70.0, 40.0);
             (100.0, 10.0);
             (130.0, 40.0);
           ]);
      (* Straight line segments *)
      Scene.path
        ~stroke:(Paint.stroke ~width:2.0 (Paint.solid green))
        ~fill:Paint.no_paint
        (Path.straight_line
           [ (150.0, 40.0); (170.0, 10.0); (190.0, 40.0); (210.0, 10.0) ]);
      (* Arc segment *)
      Scene.path
        ~stroke:(Paint.stroke ~width:2.0 (Paint.solid red))
        ~fill:Paint.no_paint
        (Path.arc_segment ~cx:270.0 ~cy:30.0 ~r:20.0 ~start_angle:0.0
           ~end_angle:(pi *. 1.5));
    ]
  in
  (* Fill types scene *)
  let linear_grad =
    unwrap_gradient
      (Paint.linear_gradient ~x0:0.0 ~y0:0.0 ~x1:60.0 ~y1:0.0
         ~stops:
           [
             { Paint.offset = 0.0; color = red }; { offset = 1.0; color = blue };
           ])
  in
  let radial_grad =
    unwrap_gradient
      (Paint.radial_gradient ~cx:30.0 ~cy:25.0 ~r:25.0
         ~stops:
           [
             { Paint.offset = 0.0; color = white };
             { offset = 1.0; color = green };
           ])
  in
  let fill_scene =
    [
      (* Solid fill *)
      Scene.rect ~fill:(Paint.solid red) ~x:10.0 ~y:5.0 ~w:60.0 ~h:40.0 ();
      (* Linear gradient *)
      Scene.rect ~fill:linear_grad ~x:80.0 ~y:5.0 ~w:60.0 ~h:40.0 ();
      (* Radial gradient *)
      Scene.rect ~fill:radial_grad ~x:150.0 ~y:5.0 ~w:60.0 ~h:40.0 ();
    ]
  in
  (* Stroke styles scene *)
  let stroke_scene =
    [
      (* Solid stroke *)
      Scene.line
        ~stroke:(Paint.stroke ~width:3.0 (Paint.solid black))
        ~x1:10.0 ~y1:15.0 ~x2:100.0 ~y2:15.0 ();
      (* Dashed stroke *)
      Scene.line
        ~stroke:(Paint.stroke ~width:3.0 ~dash:[ 8.0; 4.0 ] (Paint.solid blue))
        ~x1:10.0 ~y1:35.0 ~x2:100.0 ~y2:35.0 ();
      (* Round cap *)
      Scene.line
        ~stroke:(Paint.stroke ~width:6.0 ~line_cap:Round_cap (Paint.solid red))
        ~x1:120.0 ~y1:15.0 ~x2:210.0 ~y2:15.0 ();
      (* Bevel join polyline *)
      Scene.polyline
        ~stroke:(Paint.stroke ~width:4.0 ~line_join:Bevel (Paint.solid green))
        [ (120.0, 45.0); (155.0, 25.0); (190.0, 45.0) ];
    ]
  in
  (* Text scene *)
  let text_scene =
    [
      Scene.text ~x:10.0 ~y:15.0 ~font_size:14.0 ~fill:(Paint.solid black)
        "Start anchor";
      Scene.text ~x:200.0 ~y:15.0 ~font_size:14.0 ~anchor:Middle
        ~fill:(Paint.solid blue) "Middle anchor";
      Scene.text ~x:390.0 ~y:15.0 ~font_size:14.0 ~anchor:End_anchor
        ~fill:(Paint.solid red) "End anchor";
      Scene.text ~x:10.0 ~y:40.0 ~font_size:12.0
        ~font_weight:Nopal_style.Font.Bold ~fill:(Paint.solid black) "Bold text";
      Scene.text ~x:120.0 ~y:40.0 ~font_size:18.0 ~fill:(Paint.solid black)
        "Size 18";
    ]
  in
  (* Transform scene *)
  let transform_scene =
    [
      (* Translated rect *)
      Scene.group
        ~transforms:[ Transform.translate ~dx:10.0 ~dy:5.0 ]
        [ Scene.rect ~fill:(Paint.solid blue) ~x:0.0 ~y:0.0 ~w:30.0 ~h:20.0 () ];
      (* Scaled rect *)
      Scene.group
        ~transforms:
          [
            Transform.translate ~dx:60.0 ~dy:5.0;
            Transform.scale ~sx:1.5 ~sy:1.0;
          ]
        [
          Scene.rect ~fill:(Paint.solid green) ~x:0.0 ~y:0.0 ~w:30.0 ~h:20.0 ();
        ];
      (* Rotated rect *)
      Scene.group
        ~transforms:
          [
            Transform.translate ~dx:140.0 ~dy:25.0; Transform.rotate (pi /. 6.0);
          ]
        [
          Scene.rect ~fill:(Paint.solid red) ~x:(-15.0) ~y:(-10.0) ~w:30.0
            ~h:20.0 ();
        ];
      (* Rotate-around *)
      Scene.group
        ~transforms:
          [ Transform.rotate_around ~angle:(pi /. 4.0) ~cx:220.0 ~cy:25.0 ]
        [
          Scene.rect
            ~fill:(Paint.solid (Color.rgba ~r:0.6 ~g:0.2 ~b:0.8 ~a:1.0))
            ~x:205.0 ~y:15.0 ~w:30.0 ~h:20.0 ();
        ];
      (* Skewed rect *)
      Scene.group
        ~transforms:
          [
            Transform.translate ~dx:270.0 ~dy:5.0;
            Transform.skew ~sx:0.3 ~sy:0.0;
          ]
        [
          Scene.rect
            ~fill:(Paint.solid (Color.rgba ~r:1.0 ~g:0.6 ~b:0.0 ~a:1.0))
            ~x:0.0 ~y:0.0 ~w:30.0 ~h:20.0 ();
        ];
    ]
  in
  (* Group scene — shared opacity and blend *)
  let group_scene =
    [
      (* Background for blend demo *)
      Scene.rect ~fill:(Paint.solid blue) ~x:10.0 ~y:5.0 ~w:80.0 ~h:40.0 ();
      (* Semi-transparent overlapping group *)
      Scene.group ~opacity:0.5
        [ Scene.rect ~fill:(Paint.solid red) ~x:50.0 ~y:5.0 ~w:80.0 ~h:40.0 () ];
      (* Multiply blend group *)
      Scene.group ~blend:Multiply
        [
          Scene.rect ~fill:(Paint.solid green) ~x:150.0 ~y:5.0 ~w:60.0 ~h:40.0
            ();
        ];
    ]
  in
  (* Clipping scene *)
  let clip_scene =
    [
      Scene.clip
        ~shape:(Scene.circle ~cx:50.0 ~cy:25.0 ~r:20.0 ())
        [
          Scene.rect ~fill:(Paint.solid red) ~x:10.0 ~y:5.0 ~w:80.0 ~h:40.0 ();
          Scene.rect ~fill:(Paint.solid blue) ~x:30.0 ~y:15.0 ~w:40.0 ~h:30.0 ();
        ];
    ]
  in
  (* Interactive canvas with pointer tracking *)
  let interactive_scene =
    [
      Scene.rect
        ~fill:(Paint.solid (Color.rgba ~r:0.95 ~g:0.95 ~b:0.95 ~a:1.0))
        ~x:0.0 ~y:0.0 ~w:400.0 ~h:60.0 ();
      Scene.text ~x:200.0 ~y:20.0 ~font_size:12.0 ~anchor:Middle
        ~fill:(Paint.solid black) "Move pointer over this canvas";
    ]
    @
    match model.draw_pointer with
    | None -> []
    | Some (px, py) ->
        [
          Scene.circle
            ~fill:(Paint.solid (Color.rgba ~r:1.0 ~g:0.0 ~b:0.0 ~a:0.5))
            ~cx:px ~cy:py ~r:8.0 ();
        ]
  in
  let pointer_text =
    match model.draw_pointer with
    | None -> "Pointer: \xe2\x80\x94"
    | Some (x, y) -> Printf.sprintf "Pointer: (%.0f, %.0f)" x y
  in
  let canvas_w = 500.0 in
  let canvas_h = 60.0 in
  let small_h = 50.0 in
  Element.column ~style:section_style
    ~attrs:[ ("data-section", "draw") ]
    [
      Element.text "2D Drawing";
      Element.column ~style:section_body_style
        [
          Element.text "Basic shapes:";
          Element.draw ~width:canvas_w ~height:canvas_h shapes_scene;
          Element.text "Path variants:";
          Element.draw ~width:canvas_w ~height:small_h path_scene;
          Element.text "Fill types (solid, linear gradient, radial gradient):";
          Element.draw ~width:canvas_w ~height:small_h fill_scene;
          Element.text "Stroke styles:";
          Element.draw ~width:canvas_w ~height:small_h stroke_scene;
          Element.text "Text:";
          Element.draw ~width:canvas_w ~height:small_h text_scene;
          Element.text "Transforms:";
          Element.draw ~width:canvas_w ~height:small_h transform_scene;
          Element.text "Groups (opacity, blend):";
          Element.draw ~width:canvas_w ~height:small_h group_scene;
          Element.text "Clipping:";
          Element.draw ~width:canvas_w ~height:small_h clip_scene;
          Element.text "Pointer interactivity:";
          Element.draw ~aria_label:"Interactive drawing"
            ~cursor:Nopal_style.Cursor.Crosshair
            ~on_pointer_move:(fun (ev : Element.pointer_event) ->
              DrawPointerMove (ev.x, ev.y))
            ~on_pointer_leave:DrawPointerLeave ~width:400.0 ~height:canvas_h
            interactive_scene;
          Element.box
            ~attrs:[ ("data-section", "draw-coords") ]
            [ Element.text pointer_text ];
        ];
    ]

(* Section 12: Charts (nopal_charts kitchen sink) *)
let view_charts model =
  let cat = Color.categorical in
  (* Sample bar data *)
  let bar_data =
    [
      ("Jan", 30.0);
      ("Feb", 45.0);
      ("Mar", 25.0);
      ("Apr", 60.0);
      ("May", 35.0);
      ("Jun", 50.0);
    ]
  in
  (* Sample time-series data for line/area charts *)
  let ts_data =
    [
      (0.0, 10.0, 20.0);
      (1.0, 25.0, 15.0);
      (2.0, 18.0, 30.0);
      (3.0, 40.0, 25.0);
      (4.0, 30.0, 35.0);
      (5.0, 55.0, 40.0);
    ]
  in
  (* Sample pie data *)
  let pie_data =
    [
      ("Desktop", 45.0, cat.(0));
      ("Mobile", 35.0, cat.(1));
      ("Tablet", 15.0, cat.(2));
      ("Other", 5.0, cat.(3));
    ]
  in
  (* Sample scatter data *)
  let scatter_data =
    [
      (10.0, 20.0, 6.0);
      (25.0, 40.0, 10.0);
      (35.0, 15.0, 4.0);
      (50.0, 50.0, 8.0);
      (60.0, 30.0, 12.0);
      (70.0, 45.0, 5.0);
      (80.0, 25.0, 7.0);
    ]
  in
  (* Sparkline data *)
  let spark_data =
    [ 5.0; 10.0; 8.0; 15.0; 12.0; 20.0; 18.0; 25.0; 22.0; 30.0 ]
  in
  let chart_w = 400.0 in
  let chart_h = 250.0 in
  let row_style =
    Style.default |> Style.with_layout (fun l -> { l with gap = 16.0 })
  in
  let sparkline_row_style =
    Style.default
    |> Style.with_layout (fun l -> { l with gap = 8.0; cross_align = Center })
  in
  Element.column ~style:section_style
    ~attrs:[ ("data-section", "charts") ]
    [
      Element.text "Charts";
      Element.column ~style:section_body_style
        [
          (* Bar chart with hover + tooltip *)
          Element.text "Bar chart (shared hover):";
          Element.box
            ~attrs:[ ("data-testid", "bar-chart") ]
            [
              Bar.view ~data:bar_data
                ~label:(fun (l, _) -> l)
                ~value:(fun (_, v) -> v)
                ~color:(fun _ -> cat.(0))
                ~width:chart_w ~height:chart_h
                ~format_tooltip:(fun (l, v) ->
                  Tooltip.text (Printf.sprintf "%s: %.0f" l v))
                ~on_hover:(fun h -> ChartHovered h)
                ~on_leave:ChartLeft ?hover:model.chart_hover ();
            ];
          (* Line chart — multi-series, cross-chart hover + tooltip *)
          Element.text "Line chart (multi-series, cross-chart hover):";
          Element.box
            ~attrs:[ ("data-testid", "line-chart") ]
            [
              Line.view
                ~series:
                  [
                    Line.series ~smooth:true ~show_points:true ~label:"Revenue"
                      ~color:cat.(1)
                      ~y:(fun (_, a, _) -> a)
                      ts_data;
                    Line.series ~label:"Costs" ~color:cat.(2)
                      ~y:(fun (_, _, b) -> b)
                      ts_data;
                  ]
                ~x:(fun (x, _, _) -> x)
                ~width:chart_w ~height:chart_h
                ~format_tooltip:(fun entries ->
                  Tooltip.text
                    (String.concat ", "
                       (List.map
                          (fun (l, v) -> Printf.sprintf "%s: %.0f" l v)
                          entries)))
                ~on_hover:(fun h -> ChartHovered h)
                ~on_leave:ChartLeft ?hover:model.chart_hover ();
            ];
          (* Area chart — stacked *)
          Element.text "Area chart (stacked):";
          Area.view
            ~series:
              [
                Area.series ~label:"Product A" ~color:cat.(3)
                  ~y:(fun (_, a, _) -> a)
                  ts_data;
                Area.series ~label:"Product B" ~color:cat.(4)
                  ~y:(fun (_, _, b) -> b)
                  ts_data;
              ]
            ~x:(fun (x, _, _) -> x)
            ~width:chart_w ~height:chart_h ~mode:Area.Stacked ();
          (* Pie and donut side by side *)
          Element.text "Pie chart and donut chart:";
          Element.row ~style:row_style
            [
              Element.box
                ~attrs:[ ("data-testid", "pie-chart") ]
                [
                  Pie.view ~data:pie_data
                    ~value:(fun (_, v, _) -> v)
                    ~label:(fun (l, _, _) -> l)
                    ~color:(fun (_, _, c) -> c)
                    ~width:200.0 ~height:200.0
                    ~format_tooltip:(fun (l, v, _) ->
                      Tooltip.text (Printf.sprintf "%s: %.0f%%" l v))
                    ~on_hover:(fun h -> PieHovered h)
                    ~on_leave:PieLeft ?hover:model.pie_hover ();
                ];
              Pie.view ~data:pie_data
                ~value:(fun (_, v, _) -> v)
                ~label:(fun (l, _, _) -> l)
                ~color:(fun (_, _, c) -> c)
                ~width:200.0 ~height:200.0 ~inner_radius:50.0 ();
            ];
          (* Scatter chart with variable radius + tooltip *)
          Element.text "Scatter chart (variable radius):";
          Element.box
            ~attrs:[ ("data-testid", "scatter-chart") ]
            [
              Scatter.view ~data:scatter_data
                ~x:(fun (x, _, _) -> x)
                ~y:(fun (_, y, _) -> y)
                ~radius:(fun (_, _, r) -> r)
                ~color:(fun _ -> cat.(7))
                ~width:chart_w ~height:chart_h
                ~format_tooltip:(fun (x, y, _) ->
                  Tooltip.text (Printf.sprintf "(%.0f, %.0f)" x y))
                ~on_hover:(fun h -> ScatterHovered h)
                ~on_leave:ScatterLeft ?hover:model.scatter_hover ();
            ];
          (* Sparkline in a row *)
          Element.text "Sparkline (inline):";
          Element.row ~style:sparkline_row_style
            ~attrs:[ ("data-testid", "sparkline-row") ]
            [
              Element.text "Trend:";
              Sparkline.view ~data:spark_data ~width:120.0 ~height:24.0
                ~color:cat.(0) ();
              Element.text "Growth:";
              Sparkline.view ~data:(List.rev spark_data) ~width:120.0
                ~height:24.0 ~color:cat.(2) ();
            ];
          (* Legend *)
          Element.text "Legend:";
          Element.box
            ~attrs:[ ("data-testid", "chart-legend") ]
            [
              Legend.view
                ~entries:
                  [
                    Legend.entry ~label:"Revenue" ~color:cat.(1);
                    Legend.entry ~label:"Costs" ~color:cat.(2);
                    Legend.entry ~label:"Product A" ~color:cat.(3);
                    Legend.entry ~label:"Product B" ~color:cat.(4);
                  ]
                ();
            ];
        ];
    ]

(* Section 13: Chart Extensions (heat map, trading, multi-pane, pan/zoom) *)
let view_chart_extensions model =
  let chart_w = 400.0 in
  let chart_h = 250.0 in
  let cat = Color.categorical in
  (* Heat map data: P&L by hour (rows) × day (cols), sequential scale *)
  let pnl_row_labels = [ "9am"; "10am"; "11am"; "12pm" ] in
  let pnl_col_labels = [ "Mon"; "Tue"; "Wed"; "Thu"; "Fri" ] in
  let pnl_data =
    [
      (0, 0, 1.2);
      (0, 1, 3.5);
      (0, 2, 0.8);
      (0, 3, 2.1);
      (0, 4, 4.0);
      (1, 0, 2.0);
      (1, 1, 1.5);
      (1, 2, 3.2);
      (1, 3, 0.5);
      (1, 4, 2.8);
      (2, 0, 0.3);
      (2, 1, 2.9);
      (2, 2, 4.1);
      (2, 3, 1.7);
      (2, 4, 3.3);
      (3, 0, 3.8);
      (3, 1, 0.6);
      (3, 2, 1.9);
      (3, 3, 4.5);
      (3, 4, 2.2);
    ]
  in
  let pnl_scale =
    Color_scale.sequential
      ~low:(Nopal_draw.Color.rgba ~r:1.0 ~g:1.0 ~b:0.88 ~a:1.0)
      ~high:(Nopal_draw.Color.rgba ~r:0.0 ~g:0.39 ~b:0.0 ~a:1.0)
  in
  (* Heat map data: correlation matrix, diverging scale *)
  let corr_labels = [ "SPY"; "QQQ"; "TLT"; "GLD" ] in
  let corr_data =
    [
      (0, 0, 1.0);
      (0, 1, 0.8);
      (0, 2, -0.3);
      (0, 3, 0.1);
      (1, 0, 0.8);
      (1, 1, 1.0);
      (1, 2, -0.5);
      (1, 3, 0.2);
      (2, 0, -0.3);
      (2, 1, -0.5);
      (2, 2, 1.0);
      (2, 3, 0.6);
      (3, 0, 0.1);
      (3, 1, 0.2);
      (3, 2, 0.6);
      (3, 3, 1.0);
    ]
  in
  let corr_scale =
    Color_scale.diverging
      ~low:(Nopal_draw.Color.rgba ~r:0.7 ~g:0.09 ~b:0.17 ~a:1.0)
      ~mid:(Nopal_draw.Color.rgba ~r:1.0 ~g:1.0 ~b:1.0 ~a:1.0)
      ~high:(Nopal_draw.Color.rgba ~r:0.13 ~g:0.4 ~b:0.67 ~a:1.0)
      ()
  in
  (* Candlestick OHLC sample data *)
  let ohlc_data =
    [
      (0.0, 100.0, 105.0, 98.0, 103.0, 50000.0);
      (1.0, 103.0, 108.0, 101.0, 106.0, 62000.0);
      (2.0, 106.0, 107.0, 99.0, 100.0, 45000.0);
      (3.0, 100.0, 104.0, 97.0, 102.0, 55000.0);
      (4.0, 102.0, 110.0, 101.0, 109.0, 71000.0);
      (5.0, 109.0, 112.0, 106.0, 107.0, 48000.0);
      (6.0, 107.0, 108.0, 100.0, 101.0, 53000.0);
      (7.0, 101.0, 106.0, 99.0, 105.0, 60000.0);
      (8.0, 105.0, 111.0, 104.0, 110.0, 68000.0);
      (9.0, 110.0, 113.0, 108.0, 112.0, 75000.0);
    ]
  in
  (* Drawdown data (cumulative max drawdown %) *)
  let drawdown_data =
    [
      (0.0, 0.0);
      (1.0, -2.0);
      (2.0, -5.0);
      (3.0, -3.0);
      (4.0, -1.0);
      (5.0, 0.0);
      (6.0, -4.0);
      (7.0, -8.0);
      (8.0, -6.0);
      (9.0, -2.0);
    ]
  in
  (* Volume data for bar chart pane *)
  let volume_data = List.map (fun (x, _, _, _, _, vol) -> (x, vol)) ohlc_data in
  (* 1k data points for pan/zoom line chart *)
  let panzoom_data =
    List.init 1000 (fun i ->
        let x = Float.of_int i in
        let y =
          50.0
          +. (30.0 *. sin (x *. 0.05))
          +. (10.0 *. sin (x *. 0.13))
          +. (5.0 *. cos (x *. 0.31))
        in
        (x, y))
  in
  let row_style =
    Style.default |> Style.with_layout (fun l -> { l with gap = 16.0 })
  in
  Element.column ~style:section_style
    ~attrs:[ ("data-section", "chart-extensions") ]
    [
      Element.text "Chart Extensions";
      Element.column ~style:section_body_style
        [
          (* Heat map — sequential scale (P&L by hour × day) *)
          Element.text "Heat map (sequential scale — P&L by hour × day):";
          Element.box
            ~attrs:[ ("data-testid", "heat-map-sequential") ]
            [
              Heat_map.view ~data:pnl_data
                ~row:(fun (r, _, _) -> r)
                ~col:(fun (_, c, _) -> c)
                ~value:(fun (_, _, v) -> v)
                ~row_count:4 ~col_count:5 ~row_labels:pnl_row_labels
                ~col_labels:pnl_col_labels ~scale:pnl_scale ~width:chart_w
                ~height:chart_h
                ~format_tooltip:(fun (r, c, v) ->
                  Tooltip.text
                    (Printf.sprintf "%s %s: $%.1fk"
                       (List.nth pnl_row_labels r)
                       (List.nth pnl_col_labels c)
                       v))
                ~on_hover:(fun h -> HeatMapHovered h)
                ~on_leave:HeatMapLeft ?hover:model.heat_map_hover ();
            ];
          (* Heat map — diverging scale (correlation matrix) *)
          Element.text "Heat map (diverging scale — correlation matrix):";
          Element.box
            ~attrs:[ ("data-testid", "heat-map-diverging") ]
            [
              Heat_map.view ~data:corr_data
                ~row:(fun (r, _, _) -> r)
                ~col:(fun (_, c, _) -> c)
                ~value:(fun (_, _, v) -> v)
                ~row_count:4 ~col_count:4 ~row_labels:corr_labels
                ~col_labels:corr_labels ~scale:corr_scale ~width:chart_w
                ~height:chart_h
                ~format_tooltip:(fun (r, c, v) ->
                  Tooltip.text
                    (Printf.sprintf "%s vs %s: %.2f" (List.nth corr_labels r)
                       (List.nth corr_labels c) v))
                ~on_hover:(fun h -> HeatMapHovered h)
                ~on_leave:HeatMapLeft ?hover:model.heat_map_hover ();
            ];
          (* Candlestick chart *)
          Element.text "Candlestick chart (OHLC):";
          Element.box
            ~attrs:[ ("data-testid", "candlestick-chart") ]
            [
              Trading.Candlestick.view ~data:ohlc_data
                ~x:(fun (x, _, _, _, _, _) -> x)
                ~open_:(fun (_, o, _, _, _, _) -> o)
                ~high:(fun (_, _, h, _, _, _) -> h)
                ~low:(fun (_, _, _, l, _, _) -> l)
                ~close:(fun (_, _, _, _, c, _) -> c)
                ~width:chart_w ~height:chart_h
                ~format_tooltip:(fun _i o h l c ->
                  Tooltip.text
                    (Printf.sprintf "O:%.0f H:%.0f L:%.0f C:%.0f" o h l c))
                ~on_hover:(fun h -> TradingHovered h)
                ~on_leave:TradingLeft ?hover:model.trading_hover ();
            ];
          (* Drawdown chart *)
          Element.text "Drawdown chart:";
          Element.box
            ~attrs:[ ("data-testid", "drawdown-chart") ]
            [
              Trading.Drawdown.view ~data:drawdown_data
                ~x:(fun (x, _) -> x)
                ~y:(fun (_, y) -> y)
                ~width:chart_w ~height:chart_h
                ~format_tooltip:(fun _i dd ->
                  Tooltip.text (Printf.sprintf "Drawdown: %.1f%%" dd))
                ~on_hover:(fun h -> TradingHovered h)
                ~on_leave:TradingLeft ?hover:model.trading_hover ();
            ];
          (* Multi-pane layout: candlestick (60%) + volume bar (20%) + drawdown (20%) *)
          Element.text
            "Multi-pane layout (candlestick + volume + drawdown, synchronized):";
          Element.box
            ~attrs:[ ("data-testid", "multi-pane-chart") ]
            [
              Chart_pane.view
                ~panes:
                  [
                    Chart_pane.pane ~height_ratio:0.6 (fun dw ->
                        Trading.Candlestick.view ~data:ohlc_data
                          ~x:(fun (x, _, _, _, _, _) -> x)
                          ~open_:(fun (_, o, _, _, _, _) -> o)
                          ~high:(fun (_, _, h, _, _, _) -> h)
                          ~low:(fun (_, _, _, l, _, _) -> l)
                          ~close:(fun (_, _, _, _, c, _) -> c)
                          ~width:chart_w ~height:1.0 ~domain_window:dw
                          ~on_hover:(fun h -> TradingHovered h)
                          ~on_leave:TradingLeft ?hover:model.trading_hover ());
                    Chart_pane.pane ~height_ratio:0.2 (fun dw ->
                        Bar.view ~data:volume_data
                          ~x:(fun (x, _) -> x)
                          ~label:(fun (x, _) -> Printf.sprintf "%.0f" x)
                          ~value:(fun (_, v) -> v)
                          ~color:(fun _ -> cat.(5))
                          ~width:chart_w ~height:1.0 ~domain_window:dw ());
                    Chart_pane.pane ~height_ratio:0.2 (fun dw ->
                        Trading.Drawdown.view ~data:drawdown_data
                          ~x:(fun (x, _) -> x)
                          ~y:(fun (_, y) -> y)
                          ~width:chart_w ~height:1.0 ~domain_window:dw ());
                  ]
                ~domain_window:model.domain_window ~width:chart_w
                ~height:(chart_h *. 2.0)
                ~on_pan:(fun delta -> Pan delta)
                ~on_zoom:(fun center factor -> Zoom (center, factor))
                ();
            ];
          (* Standalone line chart with pan/zoom and 1k data points *)
          Element.text "Line chart with pan/zoom (1,000 data points):";
          Element.row ~style:row_style
            [
              Element.box
                ~attrs:[ ("data-testid", "panzoom-line-chart") ]
                [
                  Line.view
                    ~series:
                      [
                        Line.series ~smooth:true ~label:"Signal" ~color:cat.(1)
                          ~y:(fun (_, y) -> y)
                          panzoom_data;
                      ]
                    ~x:(fun (x, _) -> x)
                    ~width:(chart_w *. 1.5) ~height:chart_h
                    ~domain_window:model.domain_window
                    ~on_hover:(fun h -> ChartHovered h)
                    ~on_leave:ChartLeft ?hover:model.chart_hover ();
                ];
            ];
        ];
    ]

(* Main view — all sections in a scrollable column (REQ-F10, REQ-F12) *)
let view model =
  Element.scroll
    (Element.column ~style:page_style
       [
         Element.column ~style:page_header_style
           [
             Element.styled_text ~text_style:page_title_text "Kitchen Sink";
             Element.styled_text ~text_style:page_subtitle_text
               "A living reference of every Nopal feature.";
           ];
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
         view_draw model;
         view_charts model;
         view_chart_extensions model;
       ])

let subscriptions _model = Nopal_mvu.Sub.none
