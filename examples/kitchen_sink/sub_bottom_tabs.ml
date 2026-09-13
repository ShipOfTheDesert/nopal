open Nopal_element
open Nopal_ui
open Nopal_style
module Interaction = Nopal_style.Interaction
module Nav_stack = Nopal_navigation.Nav_stack

type tab = Home | Profile
type screen = Home_root | Home_detail | Profile_root | Profile_detail

type model = {
  active : tab;
  home : screen Nav_stack.t;
  profile : screen Nav_stack.t;
}

type msg = Select of string | Push of screen | Back

let tab_id = function
  | Home -> "home"
  | Profile -> "profile"

let tab_of_id = function
  | "home" -> Some Home
  | "profile" -> Some Profile
  | _ -> None

let init () =
  ( {
      active = Home;
      home = Nav_stack.create Home_root;
      profile = Nav_stack.create Profile_root;
    },
    Nopal_mvu.Cmd.none )

let update model msg =
  let model' =
    match msg with
    | Select id -> (
        match tab_of_id id with
        | Some active -> { model with active }
        | None -> model)
    | Push screen -> (
        match model.active with
        | Home -> { model with home = Nav_stack.push screen model.home }
        | Profile ->
            { model with profile = Nav_stack.push screen model.profile })
    | Back -> (
        match model.active with
        | Home -> { model with home = Nav_stack.pop model.home }
        | Profile -> { model with profile = Nav_stack.pop model.profile })
  in
  (model', Nopal_mvu.Cmd.none)

(* A fixed, non-zero inset so the kitchen sink always renders a visible
   safe-area gutter (the desktop viewport carries no real bottom inset). The
   value is passed explicitly to [Bottom_tabs.make ~safe_area_bottom]. *)
let demo_safe_area_bottom = 34

let screen_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0 } |> Style.padding_all 12.0)

let push_button_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 6.0 14.0 6.0 14.0)
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
  |> Style.with_text (fun t -> t |> Text.font_weight Font.Semi_bold)

let push_button ~screen label =
  Element.button ~style:push_button_style
    ~attrs:[ ("data-action", "bottom-tabs-push") ]
    ~on_click:(Push screen) (Element.text label)

(* Bar-level geometry, set through [Bottom_tabs.with_bar_style] rather than
   around the component: padding, gap, radius and a shadow all belong to the
   [role="tablist"] row, which until these setters existed was unreachable
   through [Bottom_tabs] even though [Navigation_bar] exposed it. *)
let bar_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0 } |> Style.padding_all 8.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#f2f4f7");
        border = Some { Style.default_border with radius = 12.0; style = Solid };
        shadow =
          Some
            {
              Style.default_shadow with
              y = -2.0;
              blur = 8.0;
              color = Style.rgba 0 0 0 0.12;
            };
      })

(* One interaction for the whole bar — [Navigation_bar] has no per-tab
   interaction, and it applies this to every tab including the active one. *)
let bar_interaction =
  {
    Interaction.default with
    hover =
      Some
        (Style.default
        |> Style.with_paint (fun p ->
            { p with background = Some (Style.hex "#dbe4f0") }));
  }

let render_screen screen =
  match screen with
  | Home_root ->
      Element.column ~style:screen_style
        [
          Element.text "Home";
          push_button ~screen:Home_detail "Open home detail";
        ]
  | Home_detail ->
      Element.column ~style:screen_style [ Element.text "Home detail" ]
  | Profile_root ->
      Element.column ~style:screen_style
        [
          Element.text "Profile";
          push_button ~screen:Profile_detail "Open profile detail";
        ]
  | Profile_detail ->
      Element.column ~style:screen_style [ Element.text "Profile detail" ]

let view _vp model =
  let config =
    Bottom_tabs.make
      ~tabs:
        [
          Bottom_tabs.tab ~id:"home" ~label:"Home" ~stack:model.home ();
          Bottom_tabs.tab ~id:"profile" ~label:"Profile" ~stack:model.profile ();
        ]
      ~active:(tab_id model.active) ~render_screen
      ~on_select:(fun id -> Select id)
      ~on_back:Back ~safe_area_bottom:demo_safe_area_bottom
    |> Bottom_tabs.with_bar_style bar_style
    |> Bottom_tabs.with_bar_interaction bar_interaction
    |> Bottom_tabs.with_bar_attrs [ ("data-testid", "bottom-tabs-bar") ]
  in
  Bottom_tabs.view config

let subscriptions _model = Nopal_mvu.Sub.none

let serialize_model model =
  Printf.sprintf "active=%s; home_depth=%d; profile_depth=%d;"
    (tab_id model.active)
    (Nav_stack.depth model.home)
    (Nav_stack.depth model.profile)
