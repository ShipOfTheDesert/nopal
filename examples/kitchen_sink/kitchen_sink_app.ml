open Nopal_element
open Nopal_style
open Nopal_draw

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
  sub_counter : Sub_counter.model;
  draw_pointer : (float * float) option;
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
  | SubCounterMsg of Sub_counter.msg
  | DrawPointerMove of float * float
  | DrawPointerLeave

let init () =
  let sub_counter, sub_cmd = Sub_counter.init () in
  ( {
      button_clicks = 0;
      input_text = "";
      submit_input_text = "";
      submitted_value = "";
      keyed_items = [ (1, "Item 1"); (2, "Item 2"); (3, "Item 3") ];
      next_keyed_id = 4;
      sub_counter;
      draw_pointer = None;
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
  | SubCounterMsg sub_msg ->
      let sub_counter, sub_cmd = Sub_counter.update model.sub_counter sub_msg in
      ( { model with sub_counter },
        Nopal_mvu.Cmd.map (fun m -> SubCounterMsg m) sub_cmd )
  | DrawPointerMove (x, y) ->
      ({ model with draw_pointer = Some (x, y) }, Nopal_mvu.Cmd.none)
  | DrawPointerLeave -> ({ model with draw_pointer = None }, Nopal_mvu.Cmd.none)

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

(* Section 9: Map / Composition (REQ-F9) *)
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
         view_composition model;
         view_draw model;
       ])

let subscriptions _model = Nopal_mvu.Sub.none
