open Nopal_test.Test_renderer
module BT = Nopal_ui.Bottom_tabs
module Nav_stack = Nopal_navigation.Nav_stack
module E = Nopal_element.Element
module Style = Nopal_style.Style
module Interaction = Nopal_style.Interaction
module Viewport = Nopal_element.Viewport

type msg = Select of string | Back

let msg_testable =
  Alcotest.testable
    (fun fmt m ->
      match m with
      | Select s -> Format.fprintf fmt "Select %s" s
      | Back -> Format.fprintf fmt "Back")
    ( = )

(* Active tab "a" is two screens deep (can_pop = true); tab "b" is at its
   root (can_pop = false). *)
let a_stack = Nav_stack.create "A-root" |> Nav_stack.push "A-detail"
let b_stack = Nav_stack.create "B-root"

let tabs =
  [
    BT.tab ~id:"a" ~label:"Alpha" ~stack:a_stack ();
    BT.tab ~id:"b" ~label:"Beta" ~stack:b_stack ();
  ]

let make_config ~tabs ~active ~safe_area_bottom =
  BT.make ~tabs ~active
    ~render_screen:(fun s -> E.text s)
    ~on_select:(fun id -> Select id)
    ~on_back:Back ~safe_area_bottom

(* --- Panel content --- *)

let test_panel_renders_active_tab_current_screen () =
  let config = make_config ~tabs ~active:"a" ~safe_area_bottom:0 in
  let r = render (BT.view config) in
  match find (By_attr ("role", "tabpanel")) (tree r) with
  | None -> Alcotest.fail "no tabpanel node"
  | Some node ->
      let content = text_content node in
      Alcotest.(check bool)
        "panel shows active tab's current screen" true
        (Test_util.string_contains content ~sub:"A-detail");
      Alcotest.(check bool)
        "panel hides inactive tab's screen" false
        (Test_util.string_contains content ~sub:"B-root")

(* --- ARIA roles --- *)

let test_panel_has_tabpanel_role () =
  let config = make_config ~tabs ~active:"a" ~safe_area_bottom:0 in
  let r = render (BT.view config) in
  Alcotest.(check bool)
    "tabpanel role present" true
    (Option.is_some (find (By_attr ("role", "tabpanel")) (tree r)))

let test_bar_has_tablist_role () =
  let config = make_config ~tabs ~active:"a" ~safe_area_bottom:0 in
  let r = render (BT.view config) in
  Alcotest.(check bool)
    "tablist role present (bar composed in)" true
    (Option.is_some (find (By_attr ("role", "tablist")) (tree r)))

(* --- Tab selection --- *)

let test_select_inactive_tab_emits_on_select () =
  let home = BT.tab ~id:"home" ~label:"Home" ~stack:(Nav_stack.create "h") () in
  let profile =
    BT.tab ~id:"profile" ~label:"Profile" ~stack:(Nav_stack.create "p") ()
  in
  let config =
    make_config ~tabs:[ home; profile ] ~active:"home" ~safe_area_bottom:0
  in
  let r = render (BT.view config) in
  let result = click (By_attr ("data-field", "profile")) r in
  Alcotest.(check (result unit Test_util.error_testable))
    "click ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "selected profile" [ Select "profile" ] (messages r)

(* --- Back affordance --- *)

let test_back_shown_and_emits_when_can_pop () =
  let config = make_config ~tabs ~active:"a" ~safe_area_bottom:0 in
  let r = render (BT.view config) in
  Alcotest.(check bool)
    "back affordance present when can_pop" true
    (Option.is_some (find (By_attr ("data-action", "nav-back")) (tree r)));
  let result = click (By_attr ("data-action", "nav-back")) r in
  Alcotest.(check (result unit Test_util.error_testable))
    "click ok" (Ok ()) result;
  Alcotest.(check (list msg_testable)) "back emitted" [ Back ] (messages r)

let test_back_hidden_at_root () =
  let config = make_config ~tabs ~active:"b" ~safe_area_bottom:0 in
  let r = render (BT.view config) in
  Alcotest.(check bool)
    "no back affordance at root" true
    (Option.is_none (find (By_attr ("data-action", "nav-back")) (tree r)))

(* --- Back suppression --- *)

(* Both halves are asserted in one case on purpose: [None] on the nav-back
   query is also what a component rendering nothing at all would answer, and it
   is what the root-stack arm already answers. The affirmative arm is the
   screen still being drawn, and the stack being one that *can* pop
   (empty-assertion-needs-affirmative-arm). *)
let test_back_suppressed_even_when_can_pop () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_back_suppressed true
  in
  let r = render (BT.view config) in
  Alcotest.(check bool)
    "back affordance suppressed" true
    (Option.is_none (find (By_attr ("data-action", "nav-back")) (tree r)));
  match find (By_attr ("role", "tabpanel")) (tree r) with
  | None -> Alcotest.fail "no tabpanel node"
  | Some node ->
      Alcotest.(check bool)
        "the screen is still drawn" true
        (Test_util.string_contains (text_content node) ~sub:"A-detail")

(* The flag's *value* has to reach the consumer, not merely its presence: an
   implementation branching on [Some _] passes the suppressed case and the
   default case and fails only here (config-knob-must-reach-its-consumer). *)
let test_back_not_suppressed_when_flag_is_false () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_back_suppressed false
  in
  let r = render (BT.view config) in
  Alcotest.(check bool)
    "back affordance still present" true
    (Option.is_some (find (By_attr ("data-action", "nav-back")) (tree r)))

(* --- Safe-area gutter --- *)

let gutter_padding_bottom r =
  match find (By_attr ("data-testid", "bottom-tabs-gutter")) (tree r) with
  | None -> Alcotest.fail "no gutter node"
  | Some node -> (
      match style node with
      | None -> Alcotest.fail "gutter has no style"
      | Some s -> s.layout.padding_bottom)

let test_safe_area_bottom_applies_padding () =
  (* Build the inset through Viewport (the real integration path); do not rely
     on the all-zero presets. *)
  let inset =
    Viewport.safe_area_bottom
      (Viewport.make_safe_area ~top:0 ~right:0 ~bottom:34 ~left:0 ())
  in
  let config = make_config ~tabs ~active:"a" ~safe_area_bottom:inset in
  let r = render (BT.view config) in
  Alcotest.(check (option (float 0.001)))
    "gutter padding_bottom = 34" (Some 34.0) (gutter_padding_bottom r)

let test_zero_safe_area_no_padding () =
  let config = make_config ~tabs ~active:"a" ~safe_area_bottom:0 in
  let r = render (BT.view config) in
  Alcotest.(check (option (float 0.001)))
    "gutter padding_bottom = 0" (Some 0.0) (gutter_padding_bottom r)

(* Labelled, and the two values kept distinct: both edges are floats landing on
   one record, so a transposed pair would otherwise render and pass. The
   distinct values are what make 48 readable as 14 + 34 rather than as either
   number doubled. *)
let gutter_top_pad = 10.0
let gutter_bottom_pad = 14.0

let padding_style ~top ~bottom =
  Style.default
  |> Style.with_layout (fun l ->
      { l with padding_top = Some top; padding_bottom = bottom })

(* --- The gutter's own style --- *)

let gutter_padding_top r =
  match find (By_attr ("data-testid", "bottom-tabs-gutter")) (tree r) with
  | None -> Alcotest.fail "no gutter node"
  | Some node -> (
      match style node with
      | None -> Alcotest.fail "gutter has no style"
      | Some s -> s.layout.padding_top)

let test_with_gutter_style_applied () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_gutter_style
         (padding_style ~top:gutter_top_pad ~bottom:(Some gutter_bottom_pad))
  in
  let r = render (BT.view config) in
  Alcotest.(check (option (float 0.001)))
    "gutter padding_top from the override" (Some 10.0) (gutter_padding_top r)

(* The contract the safe area rests on: the inset is *added* to whatever the
   caller asked for, so a cosmetic override cannot drop the bar under a gesture
   bar. 14 + 34, not 14 and not 34. *)
let test_gutter_style_padding_bottom_sums_with_inset () =
  let inset =
    Viewport.safe_area_bottom
      (Viewport.make_safe_area ~top:0 ~right:0 ~bottom:34 ~left:0 ())
  in
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:inset
    |> BT.with_gutter_style
         (padding_style ~top:gutter_top_pad ~bottom:(Some gutter_bottom_pad))
  in
  let r = render (BT.view config) in
  Alcotest.(check (option (float 0.001)))
    "gutter padding_bottom = 14 + 34" (Some 48.0) (gutter_padding_bottom r)

(* A gutter style that says nothing about the bottom edge leaves the inset
   exactly as it was, rather than resetting it to zero. *)
let test_gutter_style_without_bottom_keeps_the_inset () =
  let inset =
    Viewport.safe_area_bottom
      (Viewport.make_safe_area ~top:0 ~right:0 ~bottom:34 ~left:0 ())
  in
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:inset
    |> BT.with_gutter_style (padding_style ~top:gutter_top_pad ~bottom:None)
  in
  let r = render (BT.view config) in
  Alcotest.(check (option (float 0.001)))
    "gutter padding_bottom = 34" (Some 34.0) (gutter_padding_bottom r)

(* --- Cosmetic overrides (with_* accessors) --- *)

let style_with_padding_top v =
  Style.default |> Style.with_layout (fun l -> { l with padding_top = Some v })

let node_padding_top node =
  Option.bind (style node) (fun s -> s.layout.padding_top)

(* The active tab's button and the tabpanel Box both carry [data-field=<active
   id>], so resolve a tab button by id among the [role="tab"] nodes only. *)
let find_tab r ~id =
  List.find_opt
    (fun n -> attr "data-field" n = Some id)
    (find_all (By_attr ("role", "tab")) (tree r))

let test_with_back_label_overrides_label () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_back_label "Go up"
  in
  let r = render (BT.view config) in
  match find (By_attr ("data-action", "nav-back")) (tree r) with
  | None -> Alcotest.fail "no back affordance"
  | Some node ->
      Alcotest.(check bool)
        "back button shows overridden label" true
        (Test_util.string_contains (text_content node) ~sub:"Go up")

let test_with_panel_style_applied () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_panel_style (style_with_padding_top 7.0)
  in
  let r = render (BT.view config) in
  match find (By_attr ("role", "tabpanel")) (tree r) with
  | None -> Alcotest.fail "no tabpanel node"
  | Some node ->
      Alcotest.(check (option (float 0.001)))
        "panel carries overridden style" (Some 7.0) (node_padding_top node)

let test_with_tab_style_applied () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_tab_style (style_with_padding_top 5.0)
  in
  let r = render (BT.view config) in
  match find_tab r ~id:"b" with
  | None -> Alcotest.fail "no inactive tab node"
  | Some node ->
      Alcotest.(check (option (float 0.001)))
        "inactive tab carries overridden base style" (Some 5.0)
        (node_padding_top node)

let test_with_active_tab_style_applied () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_active_tab_style (style_with_padding_top 9.0)
  in
  let r = render (BT.view config) in
  match find_tab r ~id:"a" with
  | None -> Alcotest.fail "no active tab node"
  | Some node ->
      Alcotest.(check (option (float 0.001)))
        "active tab carries overridden active style" (Some 9.0)
        (node_padding_top node)

(* The bar is a [Navigation_bar] composed in, and the three setters below are
   the ones that reach *it* rather than the root or the panel. They are resolved
   through the tablist node, which is the bar's own container element. *)
let bar_node r =
  match find (By_attr ("role", "tablist")) (tree r) with
  | None -> Alcotest.fail "no tablist node"
  | Some node -> node

let test_with_bar_style_applied_to_bar () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_bar_style (style_with_padding_top 11.0)
  in
  let r = render (BT.view config) in
  Alcotest.(check (option (float 0.001)))
    "tablist container carries the bar style" (Some 11.0)
    (node_padding_top (bar_node r))

let test_with_bar_attrs_applied_to_bar () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_bar_attrs [ ("data-testid", "custom-bar") ]
  in
  let r = render (BT.view config) in
  match find (By_attr ("data-testid", "custom-bar")) (tree r) with
  | None -> Alcotest.fail "no node carrying the bar attr"
  | Some node ->
      Alcotest.(check (option string))
        "the attr lands on the tablist, not the root" (Some "tablist")
        (attr "role" node)

(* [with_attrs] targets the root and [with_bar_attrs] the bar; setting both must
   not collapse them onto one element. *)
let test_bar_attrs_and_root_attrs_are_distinct () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_attrs [ ("data-testid", "the-root") ]
    |> BT.with_bar_attrs [ ("data-testid", "the-bar") ]
  in
  let r = render (BT.view config) in
  let role_of testid =
    Option.bind (find (By_attr ("data-testid", testid)) (tree r)) (attr "role")
  in
  Alcotest.(check (option string))
    "root has no tablist role" None (role_of "the-root");
  Alcotest.(check (option string))
    "bar is the tablist" (Some "tablist") (role_of "the-bar")

(* [Navigation_bar] applies one interaction to every tab button, the active one
   included; the assertion covers both so the forwarding is pinned to the
   behaviour the .mli now describes rather than to the label it used to. *)
let test_with_bar_interaction_reaches_every_tab () =
  let hover =
    {
      Interaction.default with
      hover =
        Some
          (Style.default
          |> Style.with_paint (fun p ->
              { p with background = Some (Style.rgba 1 2 3 1.0) }));
    }
  in
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_bar_interaction hover
  in
  let r = render (BT.view config) in
  let tab_has_hover id =
    match find_tab r ~id with
    | None -> Alcotest.fail ("no tab node " ^ id)
    | Some node -> has_hover node
  in
  Alcotest.(check bool)
    "inactive tab carries the hover style" true (tab_has_hover "b");
  Alcotest.(check bool) "active tab carries it too" true (tab_has_hover "a")

(* Without the setter no tab has one, so the assertion above is a change and not
   a property of the default render. *)
let test_no_bar_interaction_by_default () =
  let config = make_config ~tabs ~active:"a" ~safe_area_bottom:0 in
  let r = render (BT.view config) in
  match find_tab r ~id:"b" with
  | None -> Alcotest.fail "no inactive tab node"
  | Some node ->
      Alcotest.(check bool) "no hover style by default" false (has_hover node)

let test_with_attrs_applied_to_root () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_attrs [ ("data-testid", "custom-root") ]
  in
  let r = render (BT.view config) in
  Alcotest.(check bool)
    "root container carries custom attr" true
    (Option.is_some (find (By_attr ("data-testid", "custom-root")) (tree r)))

(* --- Filling the container: the bar is at the bottom, not merely below --- *)

(* The root is reached through the custom attr rather than by walking the tree,
   so these assert about the element the caller actually mounts and not about a
   position in a structure. *)
let root_node r =
  match find (By_attr ("data-testid", "fill-root")) (tree r) with
  | None -> Alcotest.fail "no root node"
  | Some node -> node

let rooted ?panel_style () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_attrs [ ("data-testid", "fill-root") ]
  in
  let config =
    match panel_style with
    | Some s -> BT.with_panel_style s config
    | None -> config
  in
  render (BT.view config)

let node_height node = Option.bind (style node) (fun s -> s.layout.height)

let panel_flex_grow r =
  match find (By_attr ("role", "tabpanel")) (tree r) with
  | None -> Alcotest.fail "no tabpanel node"
  | Some node -> Option.bind (style node) (fun s -> s.layout.flex_grow)

let size_testable =
  Alcotest.testable
    (fun fmt (s : Style.size) ->
      match s with
      | Style.Fill -> Format.fprintf fmt "Fill"
      | Style.Hug -> Format.fprintf fmt "Hug"
      | Style.Fixed f -> Format.fprintf fmt "Fixed %g" f
      | Style.Fraction f -> Format.fprintf fmt "Fraction %g" f)
    ( = )

let test_root_fills_container_height () =
  let r = rooted () in
  Alcotest.(check (option size_testable))
    "root height is Fill" (Some Style.Fill)
    (node_height (root_node r))

let test_panel_grows_by_default () =
  let r = rooted () in
  Alcotest.(check (option (float 0.001)))
    "panel grows into the leftover space" (Some 1.0) (panel_flex_grow r)

(* The regression this pair exists for: a caller overriding the panel's paint
   used to replace the whole style, which silently took the growth with it and
   dropped the bar back under the content. *)
let test_panel_grows_through_cosmetic_override () =
  let r = rooted ~panel_style:(style_with_padding_top 7.0) () in
  Alcotest.(check (option (float 0.001)))
    "cosmetic override keeps the growth" (Some 1.0) (panel_flex_grow r);
  match find (By_attr ("role", "tabpanel")) (tree r) with
  | None -> Alcotest.fail "no tabpanel node"
  | Some node ->
      Alcotest.(check (option (float 0.001)))
        "and keeps the override itself" (Some 7.0) (node_padding_top node)

let test_explicit_flex_grow_is_honoured () =
  let no_grow =
    Style.default
    |> Style.with_layout (fun l -> { l with flex_grow = Some 0.0 })
  in
  let r = rooted ~panel_style:no_grow () in
  Alcotest.(check (option (float 0.001)))
    "an explicit 0 opts out rather than being filled in" (Some 0.0)
    (panel_flex_grow r)

let () =
  Alcotest.run "nopal_ui_bottom_tabs"
    [
      ( "panel",
        [
          Alcotest.test_case "renders active tab's current screen" `Quick
            test_panel_renders_active_tab_current_screen;
        ] );
      ( "aria",
        [
          Alcotest.test_case "panel has tabpanel role" `Quick
            test_panel_has_tabpanel_role;
          Alcotest.test_case "bar has tablist role" `Quick
            test_bar_has_tablist_role;
        ] );
      ( "selection",
        [
          Alcotest.test_case "select inactive tab emits on_select" `Quick
            test_select_inactive_tab_emits_on_select;
        ] );
      ( "back affordance",
        [
          Alcotest.test_case "shown and emits when can_pop" `Quick
            test_back_shown_and_emits_when_can_pop;
          Alcotest.test_case "hidden at root" `Quick test_back_hidden_at_root;
          Alcotest.test_case "suppressed even when can_pop" `Quick
            test_back_suppressed_even_when_can_pop;
          Alcotest.test_case "not suppressed when the flag is false" `Quick
            test_back_not_suppressed_when_flag_is_false;
        ] );
      ( "safe area",
        [
          Alcotest.test_case "applies padding for non-zero inset" `Quick
            test_safe_area_bottom_applies_padding;
          Alcotest.test_case "no padding for zero inset" `Quick
            test_zero_safe_area_no_padding;
          Alcotest.test_case "with_gutter_style applied to the gutter" `Quick
            test_with_gutter_style_applied;
          Alcotest.test_case "gutter padding_bottom sums with the inset" `Quick
            test_gutter_style_padding_bottom_sums_with_inset;
          Alcotest.test_case "a gutter style without a bottom keeps the inset"
            `Quick test_gutter_style_without_bottom_keeps_the_inset;
        ] );
      ( "cosmetic overrides",
        [
          Alcotest.test_case "with_back_label overrides label" `Quick
            test_with_back_label_overrides_label;
          Alcotest.test_case "with_panel_style applied to tabpanel" `Quick
            test_with_panel_style_applied;
          Alcotest.test_case "with_tab_style applied to tabs" `Quick
            test_with_tab_style_applied;
          Alcotest.test_case "with_active_tab_style applied to active tab"
            `Quick test_with_active_tab_style_applied;
          Alcotest.test_case "with_attrs applied to root" `Quick
            test_with_attrs_applied_to_root;
        ] );
      ( "bar-level overrides",
        [
          Alcotest.test_case "with_bar_style applied to the tablist" `Quick
            test_with_bar_style_applied_to_bar;
          Alcotest.test_case "with_bar_attrs applied to the tablist" `Quick
            test_with_bar_attrs_applied_to_bar;
          Alcotest.test_case "bar attrs and root attrs stay distinct" `Quick
            test_bar_attrs_and_root_attrs_are_distinct;
          Alcotest.test_case "with_bar_interaction reaches every tab" `Quick
            test_with_bar_interaction_reaches_every_tab;
          Alcotest.test_case "no bar interaction by default" `Quick
            test_no_bar_interaction_by_default;
        ] );
      ( "filling the container",
        [
          Alcotest.test_case "root height is Fill" `Quick
            test_root_fills_container_height;
          Alcotest.test_case "panel grows by default" `Quick
            test_panel_grows_by_default;
          Alcotest.test_case "growth survives a cosmetic panel override" `Quick
            test_panel_grows_through_cosmetic_override;
          Alcotest.test_case "explicit flex_grow is honoured" `Quick
            test_explicit_flex_grow_is_honoured;
        ] );
    ]
