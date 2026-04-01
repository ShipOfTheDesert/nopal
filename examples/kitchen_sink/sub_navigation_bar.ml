open Nopal_element
open Nopal_ui
open Nopal_style

type tab = Home | Settings | About
type model = { active_tab : tab }
type msg = SelectTab of string

let tab_to_id = function
  | Home -> "home"
  | Settings -> "settings"
  | About -> "about"

let id_to_tab = function
  | "home" -> Some Home
  | "settings" -> Some Settings
  | "about" -> Some About
  | _ -> None

let init () = ({ active_tab = Home }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | SelectTab id ->
      let active_tab = Option.value ~default:model.active_tab (id_to_tab id) in
      ({ active_tab }, Nopal_mvu.Cmd.none)

let tab_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 10.0 20.0 10.0 20.0)
  |> Style.with_paint (fun p ->
      { p with background = Some (Style.hex "#f0f0f0") })

let active_tab_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 10.0 20.0 10.0 20.0)
  |> Style.with_paint (fun p ->
      { p with background = Some (Style.hex "#4a90d9") })
  |> Style.with_text (fun _ -> Text.default |> Text.font_weight Font.Bold)

let bar_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some 4.0 })

let content_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 16.0 16.0 16.0 16.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#f8f9fa");
        border =
          Some
            {
              width = 1.0;
              style = Solid;
              color = Style.hex "#dee2e6";
              radius = 6.0;
            };
      })

let tab_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#e0e0e0") })
  in
  { Interaction.default with hover = Some hover }

let view_content tab =
  let text, testid =
    match tab with
    | Home ->
        ( "Welcome to the Home tab. This is the default content.",
          "nav-content-home" )
    | Settings ->
        ( "Settings panel. Configure your preferences here.",
          "nav-content-settings" )
    | About -> ("About this app. Built with Nopal.", "nav-content-about")
  in
  Element.box ~style:content_style
    ~attrs:[ ("data-testid", testid); ("role", "tabpanel") ]
    [ Element.text text ]

let subscriptions _model = Nopal_mvu.Sub.none

let view _vp model =
  ignore (model : model);
  let active_id = tab_to_id model.active_tab in
  let items =
    [
      Navigation_bar.item ~id:"home" "Home";
      Navigation_bar.item ~id:"settings" "Settings";
      Navigation_bar.item ~id:"about" "About";
    ]
  in
  let config =
    Navigation_bar.make ~items ~active:active_id ~on_select:(fun id ->
        SelectTab id)
    |> Navigation_bar.with_style bar_style
    |> Navigation_bar.with_tab_style tab_style
    |> Navigation_bar.with_active_tab_style active_tab_style
    |> Navigation_bar.with_interaction tab_interaction
    |> Navigation_bar.with_attrs [ ("data-testid", "navigation-bar") ]
  in
  Element.column
    ~style:
      (Style.default |> Style.with_layout (fun l -> { l with gap = Some 12.0 }))
    [ Navigation_bar.view config; view_content model.active_tab ]
