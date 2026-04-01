open Nopal_element
open Nopal_ui
open Nopal_style

let focusable_ids = [ "modal-input-1"; "modal-input-2"; "modal-close-button" ]
let first_focusable = "modal-input-1"

type model = { open_ : bool; focused : string }
type msg = Open | Close | FocusChanged of string | TabCycled of string

let init () = ({ open_ = false; focused = first_focusable }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | Open ->
      ( { open_ = true; focused = first_focusable },
        Nopal_mvu.Cmd.focus first_focusable )
  | Close -> ({ model with open_ = false }, Nopal_mvu.Cmd.none)
  | FocusChanged id -> ({ model with focused = id }, Nopal_mvu.Cmd.none)
  | TabCycled id -> ({ model with focused = id }, Nopal_mvu.Cmd.focus id)

(* Styles *)

let open_button_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 8.0 16.0 8.0 16.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#4a90d9");
        border =
          Some
            {
              width = 1.0;
              style = Solid;
              color = Style.hex "#3a7bc8";
              radius = 6.0;
            };
      })
  |> Style.with_text (fun _ -> Text.default |> Text.font_weight Font.Bold)

let open_button_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#3a7bc8") })
  in
  { Interaction.default with hover = Some hover }

let close_button_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 6.0 12.0 6.0 12.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#e74c3c");
        border =
          Some
            {
              width = 1.0;
              style = Solid;
              color = Style.hex "#c0392b";
              radius = 6.0;
            };
      })

let close_button_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#c0392b") })
  in
  { Interaction.default with hover = Some hover }

let backdrop_style =
  Style.default
  |> Style.with_paint (fun p ->
      { p with background = Some (Style.rgba 0 0 0 0.5) })

let dialog_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        gap = Some 12.0;
        width = Some (Fixed 360.0);
        cross_align = Some Stretch;
      }
      |> Style.padding 24.0 24.0 24.0 24.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#ffffff");
        border =
          Some
            {
              width = 1.0;
              style = Solid;
              color = Style.hex "#dee2e6";
              radius = 10.0;
            };
        shadow =
          Some { x = 0.0; y = 4.0; blur = 20.0; color = Style.rgba 0 0 0 0.15 };
      })

let input_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 8.0 12.0 8.0 12.0)
  |> Style.with_paint (fun p ->
      {
        p with
        border =
          Some
            {
              width = 1.0;
              style = Solid;
              color = Style.hex "#ced4da";
              radius = 4.0;
            };
      })

let title_style =
  Style.default
  |> Style.with_text (fun _ ->
      Text.default |> Text.font_size 1.2 |> Text.font_weight Font.Bold)

let button_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        direction = Some Row_dir;
        gap = Some 8.0;
        main_align = Some End_;
      })

(* View *)

let view _vp model =
  ignore (model : model);
  let modal_body =
    Element.column
      ~style:
        (Style.default
        |> Style.with_layout (fun l -> { l with gap = Some 12.0 }))
      [
        Element.box ~style:title_style
          ~attrs:[ ("id", "modal-title") ]
          [ Element.text "Modal Dialog" ];
        Element.input ~style:input_style
          ~attrs:
            [
              ("id", "modal-input-1");
              ("data-testid", "modal-input-1");
              ("aria-label", "First input");
            ]
          ~placeholder:"First input"
          ~on_change:(fun _ -> FocusChanged "modal-input-1")
          "";
        Element.input ~style:input_style
          ~attrs:
            [
              ("id", "modal-input-2");
              ("data-testid", "modal-input-2");
              ("aria-label", "Second input");
            ]
          ~placeholder:"Second input"
          ~on_change:(fun _ -> FocusChanged "modal-input-2")
          "";
        Element.row ~style:button_row_style
          [
            Element.button ~style:close_button_style
              ~interaction:close_button_interaction ~on_click:Close
              ~attrs:
                [
                  ("id", "modal-close-button");
                  ("data-testid", "modal-close-button");
                ]
              (Element.text "Close");
          ];
      ]
  in
  let config =
    Modal.make ~open_:model.open_ ~title_id:"modal-title" ~on_close:Close
      ~body:modal_body
    |> Modal.with_on_backdrop_click Close
    |> Modal.with_style dialog_style
    |> Modal.with_backdrop_style backdrop_style
  in
  Element.column
    ~style:
      (Style.default |> Style.with_layout (fun l -> { l with gap = Some 12.0 }))
    [
      Element.button ~style:open_button_style
        ~interaction:open_button_interaction ~on_click:Open
        ~attrs:[ ("data-testid", "modal-open-button") ]
        (Element.text "Open Modal");
      Modal.view config;
    ]

(* Subscriptions *)

let subscriptions model =
  if not model.open_ then Nopal_mvu.Sub.none
  else
    let escape_sub =
      Modal.subscriptions
        (Modal.make ~open_:true ~title_id:"modal-title" ~on_close:Close
           ~body:Element.empty)
    in
    let tab_sub =
      Nopal_mvu.Sub.on_keydown_prevent "modal-tab-trap" (fun key ->
          match key with
          | "Tab"
          | "Shift+Tab" -> (
              match
                Modal.next_focus ~focusable_ids ~current:model.focused ~key
              with
              | Some next_id -> Some (TabCycled next_id, true)
              | None -> Some (TabCycled first_focusable, true))
          | _ -> None)
    in
    Nopal_mvu.Sub.batch [ escape_sub; tab_sub ]
