open Nopal_test.Test_renderer
module BT = Nopal_ui.Bottom_tabs
module Nav_stack = Nopal_navigation.Nav_stack
module E = Nopal_element.Element
module Style = Nopal_style.Style
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

let test_with_attrs_applied_to_root () =
  let config =
    make_config ~tabs ~active:"a" ~safe_area_bottom:0
    |> BT.with_attrs [ ("data-testid", "custom-root") ]
  in
  let r = render (BT.view config) in
  Alcotest.(check bool)
    "root container carries custom attr" true
    (Option.is_some (find (By_attr ("data-testid", "custom-root")) (tree r)))

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
        ] );
      ( "safe area",
        [
          Alcotest.test_case "applies padding for non-zero inset" `Quick
            test_safe_area_bottom_applies_padding;
          Alcotest.test_case "no padding for zero inset" `Quick
            test_zero_safe_area_no_padding;
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
    ]
