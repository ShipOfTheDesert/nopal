open Nopal_test.Test_renderer
module NB = Nopal_ui.Navigation_bar
module E = Nopal_element.Element

type msg = Selected of string

let msg_testable =
  Alcotest.testable
    (fun fmt (Selected v) -> Format.fprintf fmt "Selected %s" v)
    ( = )

let items =
  [ NB.item ~id:"a" "Alpha"; NB.item ~id:"b" "Beta"; NB.item ~id:"c" "Gamma" ]

let two_items = [ NB.item ~id:"x" "Ex"; NB.item ~id:"y" "Why" ]
let base_config = NB.make ~items ~active:"b" ~on_select:(fun v -> Selected v)

(* --- Structure --- *)

let test_container_has_tablist_role () =
  let r = render (NB.view base_config) in
  let root = tree r in
  Alcotest.(check (option string))
    "role is tablist" (Some "tablist") (attr "role" root)

let test_each_item_has_tab_role () =
  let config =
    NB.make ~items:two_items ~active:"x" ~on_select:(fun v -> Selected v)
  in
  let r = render (NB.view config) in
  let tabs = find_all (By_attr ("role", "tab")) (tree r) in
  Alcotest.(check int) "one tab per item" 2 (List.length tabs)

(* --- Active/Inactive ARIA --- *)

let test_active_tab_has_aria_selected_true () =
  let r = render (NB.view base_config) in
  let tab_b = find (By_attr ("data-testid", "nav-tab-b")) (tree r) in
  match tab_b with
  | None -> Alcotest.fail "nav-tab-b not found"
  | Some node ->
      Alcotest.(check (option string))
        "aria-selected is true" (Some "true")
        (attr "aria-selected" node)

let test_inactive_tabs_have_aria_selected_false () =
  let r = render (NB.view base_config) in
  let root = tree r in
  let tab_a = find (By_attr ("data-testid", "nav-tab-a")) root in
  let tab_c = find (By_attr ("data-testid", "nav-tab-c")) root in
  (match tab_a with
  | None -> Alcotest.fail "nav-tab-a not found"
  | Some node ->
      Alcotest.(check (option string))
        "tab-a aria-selected is false" (Some "false")
        (attr "aria-selected" node));
  match tab_c with
  | None -> Alcotest.fail "nav-tab-c not found"
  | Some node ->
      Alcotest.(check (option string))
        "tab-c aria-selected is false" (Some "false")
        (attr "aria-selected" node)

(* --- Icon support --- *)

let test_item_with_icon_renders_icon_and_label () =
  let items_with_icon =
    [ NB.item ~icon:(E.text "\xe2\x98\x85") ~id:"star" "Starred" ]
  in
  let config =
    NB.make ~items:items_with_icon ~active:"star" ~on_select:(fun v ->
        Selected v)
  in
  let r = render (NB.view config) in
  let tab = find (By_attr ("data-testid", "nav-tab-star")) (tree r) in
  match tab with
  | None -> Alcotest.fail "nav-tab-star not found"
  | Some node ->
      let content = text_content node in
      Alcotest.(check bool)
        "contains star icon" true
        (Test_util.string_contains content ~sub:"\xe2\x98\x85");
      Alcotest.(check bool)
        "contains label" true
        (Test_util.string_contains content ~sub:"Starred")

let test_item_without_icon_renders_label_only () =
  let items_no_icon = [ NB.item ~id:"plain" "Plain" ] in
  let config =
    NB.make ~items:items_no_icon ~active:"plain" ~on_select:(fun v ->
        Selected v)
  in
  let r = render (NB.view config) in
  let tab = find (By_attr ("data-testid", "nav-tab-plain")) (tree r) in
  match tab with
  | None -> Alcotest.fail "nav-tab-plain not found"
  | Some node ->
      let content = text_content node in
      Alcotest.(check string) "text is label only" "Plain" content

(* --- Click behaviour --- *)

let test_click_inactive_tab_emits_on_select () =
  let config = NB.make ~items ~active:"a" ~on_select:(fun v -> Selected v) in
  let r = render (NB.view config) in
  let result = click (By_attr ("data-testid", "nav-tab-b")) r in
  Alcotest.(check (result unit Test_util.error_testable))
    "click ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "selected b" [ Selected "b" ] (messages r)

let test_click_active_tab_emits_no_message () =
  let config = NB.make ~items ~active:"a" ~on_select:(fun v -> Selected v) in
  let r = render (NB.view config) in
  let result = click (By_attr ("data-testid", "nav-tab-a")) r in
  (match result with
  | Ok () -> Alcotest.fail "expected click to fail on active tab (no handler)"
  | Error _ -> ());
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

(* --- Mismatched active ID --- *)

let test_mismatched_active_selects_no_tab () =
  let config =
    NB.make ~items ~active:"does-not-exist" ~on_select:(fun v -> Selected v)
  in
  let r = render (NB.view config) in
  let tabs = find_all (By_attr ("role", "tab")) (tree r) in
  List.iter
    (fun node ->
      Alcotest.(check (option string))
        "aria-selected is false" (Some "false")
        (attr "aria-selected" node))
    tabs

(* --- Builder overrides --- *)

let custom_red_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_paint (fun p ->
      { p with background = Some (Nopal_style.Style.rgba 200 0 0 1.0) })

let custom_green_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_paint (fun p ->
      { p with background = Some (Nopal_style.Style.rgba 0 200 0 1.0) })

let custom_blue_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_paint (fun p ->
      { p with background = Some (Nopal_style.Style.rgba 0 0 200 1.0) })

let test_with_style_overrides_container () =
  let config =
    NB.make ~items ~active:"a" ~on_select:(fun v -> Selected v)
    |> NB.with_style custom_red_style
  in
  let r = render (NB.view config) in
  let root = tree r in
  match style root with
  | None -> Alcotest.fail "root has no style"
  | Some s -> (
      match s.paint.background with
      | None -> Alcotest.fail "root has no background"
      | Some bg ->
          Alcotest.(check bool)
            "container has custom red background" true
            (Nopal_style.Style.equal_color bg
               (Nopal_style.Style.rgba 200 0 0 1.0)))

let test_with_tab_style_overrides_tabs () =
  let config =
    NB.make ~items ~active:"a" ~on_select:(fun v -> Selected v)
    |> NB.with_tab_style custom_green_style
  in
  let r = render (NB.view config) in
  let root = tree r in
  let tab_b = find (By_attr ("data-testid", "nav-tab-b")) root in
  let tab_c = find (By_attr ("data-testid", "nav-tab-c")) root in
  (match tab_b with
  | None -> Alcotest.fail "nav-tab-b not found"
  | Some node -> (
      match style node with
      | None -> Alcotest.fail "tab-b has no style"
      | Some s -> (
          match s.paint.background with
          | None -> Alcotest.fail "tab-b has no background"
          | Some bg ->
              Alcotest.(check bool)
                "tab-b has custom green background" true
                (Nopal_style.Style.equal_color bg
                   (Nopal_style.Style.rgba 0 200 0 1.0)))));
  match tab_c with
  | None -> Alcotest.fail "nav-tab-c not found"
  | Some node -> (
      match style node with
      | None -> Alcotest.fail "tab-c has no style"
      | Some s -> (
          match s.paint.background with
          | None -> Alcotest.fail "tab-c has no background"
          | Some bg ->
              Alcotest.(check bool)
                "tab-c has custom green background" true
                (Nopal_style.Style.equal_color bg
                   (Nopal_style.Style.rgba 0 200 0 1.0))))

let test_with_active_tab_style_overrides_active_only () =
  let config =
    NB.make ~items ~active:"b" ~on_select:(fun v -> Selected v)
    |> NB.with_tab_style custom_green_style
    |> NB.with_active_tab_style custom_blue_style
  in
  let r = render (NB.view config) in
  let root = tree r in
  let tab_a = find (By_attr ("data-testid", "nav-tab-a")) root in
  let tab_b = find (By_attr ("data-testid", "nav-tab-b")) root in
  (* Active tab should have the blue active_tab_style *)
  (match tab_b with
  | None -> Alcotest.fail "nav-tab-b not found"
  | Some node -> (
      match style node with
      | None -> Alcotest.fail "tab-b has no style"
      | Some s -> (
          match s.paint.background with
          | None -> Alcotest.fail "tab-b has no background"
          | Some bg ->
              Alcotest.(check bool)
                "active tab has custom blue background" true
                (Nopal_style.Style.equal_color bg
                   (Nopal_style.Style.rgba 0 0 200 1.0)))));
  (* Inactive tab should have the green tab_style *)
  match tab_a with
  | None -> Alcotest.fail "nav-tab-a not found"
  | Some node -> (
      match style node with
      | None -> Alcotest.fail "tab-a has no style"
      | Some s -> (
          match s.paint.background with
          | None -> Alcotest.fail "tab-a has no background"
          | Some bg ->
              Alcotest.(check bool)
                "inactive tab has custom green background" true
                (Nopal_style.Style.equal_color bg
                   (Nopal_style.Style.rgba 0 200 0 1.0))))

let test_with_attrs_adds_custom_attrs () =
  let config =
    NB.make ~items ~active:"a" ~on_select:(fun v -> Selected v)
    |> NB.with_attrs [ ("data-nav", "main"); ("aria-label", "Main nav") ]
  in
  let r = render (NB.view config) in
  let root = tree r in
  Alcotest.(check (option string))
    "has data-nav" (Some "main") (attr "data-nav" root);
  Alcotest.(check (option string))
    "has aria-label" (Some "Main nav") (attr "aria-label" root)

let test_with_interaction_does_not_crash () =
  let interaction =
    {
      Nopal_style.Interaction.default with
      hover =
        Some
          (Nopal_style.Style.default
          |> Nopal_style.Style.with_paint (fun p ->
              {
                p with
                background = Some (Nopal_style.Style.rgba 100 100 100 1.0);
              }));
    }
  in
  let config =
    NB.make ~items ~active:"a" ~on_select:(fun v -> Selected v)
    |> NB.with_interaction interaction
  in
  let r = render (NB.view config) in
  let tabs = find_all (By_attr ("role", "tab")) (tree r) in
  Alcotest.(check int) "still renders all tabs" 3 (List.length tabs)

(* --- Empty items --- *)

let test_empty_items_renders_empty_tablist () =
  let config =
    NB.make ~items:[] ~active:"none" ~on_select:(fun v -> Selected v)
  in
  let r = render (NB.view config) in
  let root = tree r in
  Alcotest.(check (option string))
    "role is tablist" (Some "tablist") (attr "role" root);
  let tabs = find_all (By_attr ("role", "tab")) root in
  Alcotest.(check int) "no tabs" 0 (List.length tabs)

(* --- Styling --- *)

let test_active_tab_has_distinct_style () =
  let config = NB.make ~items ~active:"b" ~on_select:(fun v -> Selected v) in
  let r = render (NB.view config) in
  let root = tree r in
  let tab_a = find (By_attr ("data-testid", "nav-tab-a")) root in
  let tab_b = find (By_attr ("data-testid", "nav-tab-b")) root in
  match (tab_a, tab_b) with
  | Some a_node, Some b_node -> (
      let a_style = style a_node in
      let b_style = style b_node in
      match (a_style, b_style) with
      | Some s_a, Some s_b ->
          let bg_a = s_a.paint.background in
          let bg_b = s_b.paint.background in
          let bg_equal =
            match (bg_a, bg_b) with
            | Some ca, Some cb -> Nopal_style.Style.equal_color ca cb
            | None, None -> true
            | _ -> false
          in
          Alcotest.(check bool)
            "active and inactive have different background" false bg_equal
      | _ -> Alcotest.fail "could not extract styles from tabs")
  | _ -> Alcotest.fail "could not find both tabs"

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_ui_navigation_bar"
    [
      ( "structure",
        [
          Alcotest.test_case "container has tablist role" `Quick
            test_container_has_tablist_role;
          Alcotest.test_case "each item has tab role" `Quick
            test_each_item_has_tab_role;
        ] );
      ( "aria",
        [
          Alcotest.test_case "active tab has aria-selected true" `Quick
            test_active_tab_has_aria_selected_true;
          Alcotest.test_case "inactive tabs have aria-selected false" `Quick
            test_inactive_tabs_have_aria_selected_false;
        ] );
      ( "icons",
        [
          Alcotest.test_case "item with icon renders icon and label" `Quick
            test_item_with_icon_renders_icon_and_label;
          Alcotest.test_case "item without icon renders label only" `Quick
            test_item_without_icon_renders_label_only;
        ] );
      ( "events",
        [
          Alcotest.test_case "click inactive tab emits on_select" `Quick
            test_click_inactive_tab_emits_on_select;
          Alcotest.test_case "click active tab emits no message" `Quick
            test_click_active_tab_emits_no_message;
        ] );
      ( "empty items",
        [
          Alcotest.test_case "empty items renders empty tablist" `Quick
            test_empty_items_renders_empty_tablist;
        ] );
      ( "styling",
        [
          Alcotest.test_case "active tab has distinct style" `Quick
            test_active_tab_has_distinct_style;
        ] );
      ( "mismatched active",
        [
          Alcotest.test_case "no tab selected when active ID mismatches" `Quick
            test_mismatched_active_selects_no_tab;
        ] );
      ( "builder overrides",
        [
          Alcotest.test_case "with_style overrides container" `Quick
            test_with_style_overrides_container;
          Alcotest.test_case "with_tab_style overrides tabs" `Quick
            test_with_tab_style_overrides_tabs;
          Alcotest.test_case "with_active_tab_style overrides active only"
            `Quick test_with_active_tab_style_overrides_active_only;
          Alcotest.test_case "with_attrs adds custom attrs" `Quick
            test_with_attrs_adds_custom_attrs;
          Alcotest.test_case "with_interaction does not crash" `Quick
            test_with_interaction_does_not_crash;
        ] );
    ]
