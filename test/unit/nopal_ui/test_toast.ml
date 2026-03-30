open Nopal_test.Test_renderer
module Toast = Nopal_ui.Toast
module E = Nopal_element.Element
module Cmd = Nopal_mvu.Cmd

type msg = Dismiss of string

let msg_testable =
  Alcotest.testable
    (fun fmt (Dismiss id) -> Format.fprintf fmt "Dismiss %S" id)
    ( = )

let dismiss id = Dismiss id
let make_toast ~id ~variant ~message : Toast.toast = { id; variant; message }

(* --- add --- *)

let test_add_appends_toast () =
  let toasts, _cmd =
    Toast.add ~variant:Info ~message:"hello" ~id:"t1" ~dismiss []
  in
  match toasts with
  | [ t ] ->
      Alcotest.(check string) "id" "t1" t.id;
      Alcotest.(check string) "message" "hello" t.message
  | _ -> Alcotest.fail "expected exactly one toast"

let test_add_preserves_existing () =
  let existing = [ make_toast ~id:"t0" ~variant:Success ~message:"first" ] in
  let toasts, _cmd =
    Toast.add ~variant:Warning ~message:"second" ~id:"t1" ~dismiss existing
  in
  match toasts with
  | [ a; b ] ->
      Alcotest.(check string) "original id" "t0" a.id;
      Alcotest.(check string) "new id" "t1" b.id
  | _ -> Alcotest.fail "expected exactly two toasts"

let test_add_with_duration_returns_cmd_after () =
  let _toasts, cmd =
    Toast.add ~variant:Info ~message:"timed" ~id:"t1" ~duration_ms:3000 ~dismiss
      []
  in
  match Cmd.extract_after cmd with
  | Some (delay, Dismiss id) ->
      Alcotest.(check int) "delay" 3000 delay;
      Alcotest.(check string) "dismiss id" "t1" id
  | None -> Alcotest.fail "expected Some from extract_after"

let test_add_without_duration_returns_cmd_none () =
  let _toasts, cmd =
    Toast.add ~variant:Info ~message:"no timer" ~id:"t1" ~dismiss []
  in
  Alcotest.(check bool)
    "cmd is none" true
    (Option.is_none (Cmd.extract_after cmd))

(* --- dismiss --- *)

let test_dismiss_removes_matching_toast () =
  let toasts =
    [
      make_toast ~id:"t1" ~variant:Info ~message:"one";
      make_toast ~id:"t2" ~variant:Error ~message:"two";
    ]
  in
  let result = Toast.dismiss "t1" toasts in
  match result with
  | [ t ] -> Alcotest.(check string) "remaining" "t2" t.id
  | _ -> Alcotest.fail "expected exactly one toast after dismiss"

let test_dismiss_nonexistent_id_unchanged () =
  let toasts = [ make_toast ~id:"t1" ~variant:Info ~message:"one" ] in
  let result = Toast.dismiss "missing" toasts in
  Alcotest.(check int) "same length" 1 (List.length result)

(* --- view --- *)

let test_view_empty_list_renders_container () =
  let config = Toast.make ~dismiss in
  let r = render (Toast.view config []) in
  let root = tree r in
  match root with
  | Element { tag = "column"; attrs; children; _ } ->
      Alcotest.(check (option string))
        "no aria-live on container" None
        (List.assoc_opt "aria-live" attrs);
      Alcotest.(check int) "no children" 0 (List.length children)
  | _ -> Alcotest.fail "expected column element at root"

let test_view_multiple_toasts_renders_all () =
  let config = Toast.make ~dismiss in
  let toasts =
    [
      make_toast ~id:"t1" ~variant:Info ~message:"a";
      make_toast ~id:"t2" ~variant:Success ~message:"b";
      make_toast ~id:"t3" ~variant:Warning ~message:"c";
    ]
  in
  let r = render (Toast.view config toasts) in
  let root = tree r in
  match root with
  | Element { tag = "column"; children; _ } ->
      Alcotest.(check int) "three children" 3 (List.length children)
  | _ -> Alcotest.fail "expected column element at root"

let test_view_click_dispatches_dismiss () =
  let config = Toast.make ~dismiss in
  let toasts = [ make_toast ~id:"t1" ~variant:Info ~message:"click me" ] in
  let r = render (Toast.view config toasts) in
  let result = click (By_tag "button") r in
  Alcotest.(check (result unit Test_util.error_testable))
    "click ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "dismiss dispatched" [ Dismiss "t1" ] (messages r)

let test_view_variants_have_distinct_attrs () =
  let config = Toast.make ~dismiss in
  let variants =
    [
      (Toast.Info, "info");
      (Toast.Success, "success");
      (Toast.Warning, "warning");
      (Toast.Error, "error");
    ]
  in
  let seen =
    List.map
      (fun (variant, expected_str) ->
        let toasts = [ make_toast ~id:"t1" ~variant ~message:"test" ] in
        let r = render (Toast.view config toasts) in
        match find (By_tag "button") (tree r) with
        | Some btn ->
            let actual = attr "data-variant" btn in
            Alcotest.(check (option string))
              ("data-variant for " ^ expected_str)
              (Some expected_str) actual;
            expected_str
        | None -> Alcotest.fail "expected button element")
      variants
  in
  (* Verify all four are distinct *)
  let unique = List.sort_uniq String.compare seen in
  Alcotest.(check int) "four distinct variants" 4 (List.length unique)

(* --- config overrides --- *)

let test_custom_style_applied () =
  let custom_style =
    Nopal_style.Style.default
    |> Nopal_style.Style.with_layout (fun l -> { l with gap = Some 20.0 })
  in
  let config = { (Toast.make ~dismiss) with style = Some custom_style } in
  let toasts = [ make_toast ~id:"t1" ~variant:Info ~message:"styled" ] in
  let r = render (Toast.view config toasts) in
  let root = tree r in
  match root with
  | Element { tag = "column"; style = s; children; _ } ->
      Alcotest.(check int) "one child" 1 (List.length children);
      Alcotest.(check (option (float 0.01)))
        "custom gap applied" (Some 20.0) s.layout.gap
  | _ -> Alcotest.fail "expected column element at root"

let test_custom_interaction_applied () =
  let custom_hover =
    Nopal_style.Style.default
    |> Nopal_style.Style.with_paint (fun p ->
        { p with background = Some (Nopal_style.Style.hex "#ff0000") })
  in
  let custom_interaction =
    { Nopal_style.Interaction.default with hover = Some custom_hover }
  in
  let config =
    { (Toast.make ~dismiss) with interaction = Some custom_interaction }
  in
  let toasts = [ make_toast ~id:"t1" ~variant:Info ~message:"interactive" ] in
  let r = render (Toast.view config toasts) in
  match find (By_tag "button") (tree r) with
  | Some btn ->
      let ix = interaction btn in
      Alcotest.(check bool)
        "has hover" true
        (match ix with
        | Some i -> Option.is_some i.Nopal_style.Interaction.hover
        | None -> false);
      Alcotest.(check bool)
        "no pressed" true
        (match ix with
        | Some i -> Option.is_none i.Nopal_style.Interaction.pressed
        | None -> false)
  | None -> Alcotest.fail "expected button element"

let test_custom_attrs_propagated () =
  let config =
    { (Toast.make ~dismiss) with attrs = [ ("data-custom", "hello") ] }
  in
  let r = render (Toast.view config []) in
  let root = tree r in
  match root with
  | Element { attrs; _ } ->
      Alcotest.(check (option string))
        "custom attr" (Some "hello")
        (List.assoc_opt "data-custom" attrs);
      Alcotest.(check (option string))
        "no aria-live on container" None
        (List.assoc_opt "aria-live" attrs)
  | _ -> Alcotest.fail "expected column element at root"

(* --- aria-live --- *)

let test_aria_live_for_all_variants () =
  let cases =
    [
      (Toast.Info, "polite", "info");
      (Toast.Success, "polite", "success");
      (Toast.Warning, "assertive", "warning");
      (Toast.Error, "assertive", "error");
    ]
  in
  List.iter
    (fun (variant, expected, label) ->
      Alcotest.(check string) label expected (Toast.aria_live_for variant))
    cases

let test_view_toast_aria_label () =
  let config = Toast.make ~dismiss in
  let toasts = [ make_toast ~id:"t1" ~variant:Info ~message:"hello world" ] in
  let r = render (Toast.view config toasts) in
  match find (By_tag "button") (tree r) with
  | Some btn ->
      Alcotest.(check (option string))
        "aria-label" (Some "Dismiss: hello world") (attr "aria-label" btn)
  | None -> Alcotest.fail "expected button element"

(* --- styling --- *)

module S = Nopal_style.Style
module I = Nopal_style.Interaction

let all_variants = [ Toast.Info; Toast.Success; Toast.Warning; Toast.Error ]
let background_of style = style.S.paint.S.background

let color_option_equal a b =
  match (a, b) with
  | Some c1, Some c2 -> S.equal_color c1 c2
  | None, None -> true
  | Some _, None
  | None, Some _ ->
      false

let test_default_style_for_variants () =
  List.iter
    (fun variant ->
      Alcotest.(check bool)
        "non-None background" true
        (Option.is_some (background_of (Toast.default_style_for variant))))
    all_variants;
  let backgrounds =
    List.map (fun v -> background_of (Toast.default_style_for v)) all_variants
  in
  Alcotest.(check int)
    "four distinct backgrounds" 4
    (Test_util.count_unique color_option_equal backgrounds)

let test_default_interaction_for_variants () =
  List.iter
    (fun variant ->
      let ix = Toast.default_interaction_for variant in
      Alcotest.(check bool) "has hover" true (Option.is_some ix.I.hover);
      Alcotest.(check bool) "has pressed" true (Option.is_some ix.I.pressed))
    all_variants;
  let hover_bgs =
    List.map
      (fun v ->
        let ix = Toast.default_interaction_for v in
        match ix.I.hover with
        | Some s -> background_of s
        | None -> None)
      all_variants
  in
  Alcotest.(check int)
    "four distinct hover backgrounds" 4
    (Test_util.count_unique color_option_equal hover_bgs)

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_ui_toast"
    [
      ( "add",
        [
          Alcotest.test_case "appends toast" `Quick test_add_appends_toast;
          Alcotest.test_case "preserves existing" `Quick
            test_add_preserves_existing;
          Alcotest.test_case "with duration returns cmd after" `Quick
            test_add_with_duration_returns_cmd_after;
          Alcotest.test_case "without duration returns cmd none" `Quick
            test_add_without_duration_returns_cmd_none;
        ] );
      ( "dismiss",
        [
          Alcotest.test_case "removes matching" `Quick
            test_dismiss_removes_matching_toast;
          Alcotest.test_case "nonexistent unchanged" `Quick
            test_dismiss_nonexistent_id_unchanged;
        ] );
      ( "view",
        [
          Alcotest.test_case "empty list renders container" `Quick
            test_view_empty_list_renders_container;
          Alcotest.test_case "multiple toasts all rendered" `Quick
            test_view_multiple_toasts_renders_all;
          Alcotest.test_case "click dispatches dismiss" `Quick
            test_view_click_dispatches_dismiss;
          Alcotest.test_case "variants distinct attrs" `Quick
            test_view_variants_have_distinct_attrs;
        ] );
      ( "config overrides",
        [
          Alcotest.test_case "custom style applied" `Quick
            test_custom_style_applied;
          Alcotest.test_case "custom interaction applied" `Quick
            test_custom_interaction_applied;
          Alcotest.test_case "custom attrs propagated" `Quick
            test_custom_attrs_propagated;
        ] );
      ( "aria-live",
        [
          Alcotest.test_case "all variants" `Quick
            test_aria_live_for_all_variants;
          Alcotest.test_case "toast carries aria-label" `Quick
            test_view_toast_aria_label;
        ] );
      ( "styling",
        [
          Alcotest.test_case "default_style_for variants" `Quick
            test_default_style_for_variants;
          Alcotest.test_case "default_interaction_for variants" `Quick
            test_default_interaction_for_variants;
        ] );
    ]
