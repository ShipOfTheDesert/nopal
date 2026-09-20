open Nopal_test.Test_renderer
module Modal = Nopal_ui.Modal
module E = Nopal_element.Element
module Sub = Nopal_mvu.Sub

type msg = Close

let pp_msg fmt Close = Format.fprintf fmt "Close"
let equal_msg Close Close = true
let msg_testable = Alcotest.testable pp_msg equal_msg

(* --- open/closed rendering --- *)

let test_closed_modal_renders_empty () =
  let config =
    Modal.make ~open_:false ~title_id:"t" ~on_close:Close ~body:(E.text "hi")
  in
  let r = render (Modal.view config) in
  match tree r with
  | Empty -> ()
  | Text _
  | Element _ ->
      Alcotest.fail "expected Empty when modal is closed"

let test_open_modal_renders_dialog () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:(E.text "Hello")
  in
  let r = render (Modal.view config) in
  let root = tree r in
  match find (By_attr ("data-testid", "modal-dialog")) root with
  | Some dialog ->
      let content = text_content dialog in
      Alcotest.(check bool)
        "contains Hello" true
        (Test_util.string_contains content ~sub:"Hello")
  | None -> Alcotest.fail "expected modal-dialog node"

(* --- ARIA attributes --- *)

let test_dialog_has_role_dialog () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
  in
  let r = render (Modal.view config) in
  match find (By_attr ("data-testid", "modal-dialog")) (tree r) with
  | Some dialog ->
      Alcotest.(check (option string))
        "role" (Some "dialog") (attr "role" dialog)
  | None -> Alcotest.fail "expected modal-dialog node"

let test_dialog_has_aria_modal_true () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
  in
  let r = render (Modal.view config) in
  match find (By_attr ("data-testid", "modal-dialog")) (tree r) with
  | Some dialog ->
      Alcotest.(check (option string))
        "aria-modal" (Some "true") (attr "aria-modal" dialog)
  | None -> Alcotest.fail "expected modal-dialog node"

let test_dialog_has_aria_labelledby () =
  let config =
    Modal.make ~open_:true ~title_id:"my-title" ~on_close:Close ~body:E.empty
  in
  let r = render (Modal.view config) in
  match find (By_attr ("data-testid", "modal-dialog")) (tree r) with
  | Some dialog ->
      Alcotest.(check (option string))
        "aria-labelledby" (Some "my-title")
        (attr "aria-labelledby" dialog)
  | None -> Alcotest.fail "expected modal-dialog node"

(* --- backdrop rendering --- *)

let test_backdrop_rendered_when_on_backdrop_click_set () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
    |> Modal.with_on_backdrop_click Close
  in
  let r = render (Modal.view config) in
  match find (By_attr ("data-testid", "modal-backdrop")) (tree r) with
  | Some _ -> ()
  | None -> Alcotest.fail "expected modal-backdrop node"

let test_no_backdrop_when_on_backdrop_click_not_set () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
  in
  let r = render (Modal.view config) in
  match find (By_attr ("data-testid", "modal-backdrop")) (tree r) with
  | Some _ -> Alcotest.fail "expected no modal-backdrop node"
  | None -> ()

(* --- subscriptions --- *)

let test_subscriptions_none_when_closed () =
  let config =
    Modal.make ~open_:false ~title_id:"t" ~on_close:Close ~body:E.empty
  in
  let subs = Modal.subscriptions config in
  Alcotest.(check (list string)) "no keys" [] (Sub.keys subs)

(* The keydown handler of the modal's single Escape subscription. The modal
   wires [Sub.on_key], which normalizes to one [Keydown] atom. *)
let escape_handler subs =
  match Sub.atoms subs with
  | [ Keydown { handler; _ } ] -> Some handler
  | [ (Every _ | Keyup _ | Resize _ | Visibility _ | Viewport _ | Custom _) ]
  | []
  | _ :: _ :: _ ->
      Option.none

let test_subscriptions_intercepts_escape_when_open () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
  in
  let subs = Modal.subscriptions config in
  match escape_handler subs with
  | Some callback -> (
      match callback "Escape" with
      | Some (msg, prevent) ->
          Alcotest.(check msg_testable) "on_close msg" Close msg;
          Alcotest.(check bool) "preventDefault" true prevent
      | None -> Alcotest.fail "expected Some for Escape key")
  | None -> Alcotest.fail "expected a keydown subscription"

let test_subscriptions_ignores_non_escape_keys () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
  in
  let subs = Modal.subscriptions config in
  match escape_handler subs with
  | Some callback ->
      Alcotest.(check bool) "None for 'a'" true (Option.is_none (callback "a"))
  | None -> Alcotest.fail "expected a keydown subscription"

(* --- builder overrides --- *)

let custom_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_paint (fun p ->
      { p with background = Some (Nopal_style.Style.rgba 200 0 0 1.0) })

let custom_backdrop_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_paint (fun p ->
      { p with background = Some (Nopal_style.Style.rgba 0 0 0 0.5) })

let custom_interaction =
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

let test_with_style_overrides_dialog () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
    |> Modal.with_style custom_style
  in
  let r = render (Modal.view config) in
  match find (By_attr ("data-testid", "modal-dialog")) (tree r) with
  | Some dialog -> (
      match style dialog with
      | Some s -> (
          match s.paint.background with
          | Some bg ->
              Alcotest.(check bool)
                "dialog has custom background" true
                (Nopal_style.Style.equal_color bg
                   (Nopal_style.Style.rgba 200 0 0 1.0))
          | None -> Alcotest.fail "dialog has no background")
      | None -> Alcotest.fail "dialog has no style")
  | None -> Alcotest.fail "expected modal-dialog node"

let test_with_backdrop_style_overrides_backdrop () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
    |> Modal.with_on_backdrop_click Close
    |> Modal.with_backdrop_style custom_backdrop_style
  in
  let r = render (Modal.view config) in
  match find (By_attr ("data-testid", "modal-backdrop")) (tree r) with
  | Some backdrop -> (
      match style backdrop with
      | Some s -> (
          match s.paint.background with
          | Some bg ->
              Alcotest.(check bool)
                "backdrop has custom background" true
                (Nopal_style.Style.equal_color bg
                   (Nopal_style.Style.rgba 0 0 0 0.5))
          | None -> Alcotest.fail "backdrop has no background")
      | None -> Alcotest.fail "backdrop has no style")
  | None -> Alcotest.fail "expected modal-backdrop node"

let test_with_interaction_applies_to_dialog () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
    |> Modal.with_interaction custom_interaction
  in
  let r = render (Modal.view config) in
  match find (By_attr ("data-testid", "modal-dialog")) (tree r) with
  | Some _ -> ()
  | None -> Alcotest.fail "expected modal-dialog node"

(* --- root style and the forced-positioning contract --- *)

let custom_root_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_paint (fun p ->
      { p with background = Some (Nopal_style.Style.rgba 0 0 200 1.0) })
  |> Nopal_style.Style.with_layout (fun l -> { l with main_align = Some End_ })

let layout_of node =
  match style node with
  | Some s -> s.Nopal_style.Style.layout
  | None -> Alcotest.fail "expected a styled element"

let test_root_style_reaches_the_modal_root () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
    |> Modal.with_root_style custom_root_style
  in
  let r = render (Modal.view config) in
  match find (By_attr ("data-testid", "modal-root")) (tree r) with
  | Some root ->
      let l = layout_of root in
      Alcotest.(check bool)
        "the override's main_align replaced the default's" true
        (match l.main_align with
        | Some End_ -> true
        | Some Start
        | Some Center
        | Some Stretch
        | Some Space_between
        | None ->
            false);
      Alcotest.(check bool)
        "nothing of the default style is merged back in" true
        (Option.is_none l.z_index && Option.is_none l.position)
  | None -> Alcotest.fail "expected modal-root node"

let test_default_root_style_positions_the_root_without_an_override () =
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
  in
  let r = render (Modal.view config) in
  match find (By_attr ("data-testid", "modal-root")) (tree r) with
  | Some root ->
      let l = layout_of root in
      Alcotest.(check bool)
        "root is fixed" true
        (match l.position with
        | Some Pos_fixed -> true
        | Some Pos_static
        | Some Pos_relative
        | Some Pos_absolute
        | None ->
            false);
      Alcotest.(check (option int)) "root z-index" (Some 1000) l.z_index;
      Alcotest.(check bool)
        "the published default is what the root carries" true
        (Nopal_style.Style.equal
           (match style root with
           | Some s -> s
           | None -> Nopal_style.Style.default)
           Modal.default_root_style)
  | None -> Alcotest.fail "expected modal-root node"

let test_backdrop_positioning_is_forced_over_the_override () =
  let mispositioned =
    Nopal_style.Style.default
    |> Nopal_style.Style.with_paint (fun p ->
        { p with background = Some (Nopal_style.Style.rgba 0 0 0 0.5) })
    |> Nopal_style.Style.with_layout (fun l ->
        { l with position = Some Pos_static; top = Some 50.0 })
  in
  let config =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
    |> Modal.with_on_backdrop_click Close
    |> Modal.with_backdrop_style mispositioned
  in
  let r = render (Modal.view config) in
  match find (By_attr ("data-testid", "modal-backdrop")) (tree r) with
  | Some backdrop ->
      let l = layout_of backdrop in
      Alcotest.(check bool)
        "position is forced back to absolute" true
        (match l.position with
        | Some Pos_absolute -> true
        | Some Pos_static
        | Some Pos_relative
        | Some Pos_fixed
        | None ->
            false);
      Alcotest.(check (option (float 0.001)))
        "top is forced to 0" (Some 0.0) l.top;
      Alcotest.(check bool)
        "every other field still replaces — the paint survives" true
        (match (style backdrop : Nopal_style.Style.t option) with
        | Some s -> (
            match s.paint.background with
            | Some bg ->
                Nopal_style.Style.equal_color bg
                  (Nopal_style.Style.rgba 0 0 0 0.5)
            | None -> false)
        | None -> false)
  | None -> Alcotest.fail "expected modal-backdrop node"

let test_dialog_position_is_filled_in_only_when_absent () =
  let positioned =
    Nopal_style.Style.default
    |> Nopal_style.Style.with_layout (fun l ->
        { l with position = Some Pos_absolute })
  in
  let dialog_position config =
    let r = render (Modal.view config) in
    match find (By_attr ("data-testid", "modal-dialog")) (tree r) with
    | Some dialog -> (layout_of dialog).position
    | None -> Alcotest.fail "expected modal-dialog node"
  in
  let base =
    Modal.make ~open_:true ~title_id:"t" ~on_close:Close ~body:E.empty
    |> Modal.with_on_backdrop_click Close
  in
  Alcotest.(check bool)
    "filled in when the caller leaves it unset" true
    (match dialog_position (base |> Modal.with_style custom_style) with
    | Some Pos_relative -> true
    | Some Pos_static
    | Some Pos_absolute
    | Some Pos_fixed
    | None ->
        false);
  Alcotest.(check bool)
    "the caller's own position is kept" true
    (match dialog_position (base |> Modal.with_style positioned) with
    | Some Pos_absolute -> true
    | Some Pos_static
    | Some Pos_relative
    | Some Pos_fixed
    | None ->
        false)

let test_dialog_aria_is_unchanged_under_every_style_override () =
  let config =
    Modal.make ~open_:true ~title_id:"my-title" ~on_close:Close ~body:E.empty
    |> Modal.with_on_backdrop_click Close
    |> Modal.with_style custom_style
    |> Modal.with_backdrop_style custom_backdrop_style
    |> Modal.with_interaction custom_interaction
    |> Modal.with_root_style custom_root_style
  in
  let r = render (Modal.view config) in
  let root = tree r in
  (match find (By_attr ("data-testid", "modal-dialog")) root with
  | Some dialog ->
      Alcotest.(check (option string))
        "role" (Some "dialog") (attr "role" dialog);
      Alcotest.(check (option string))
        "aria-modal" (Some "true") (attr "aria-modal" dialog);
      Alcotest.(check (option string))
        "aria-labelledby" (Some "my-title")
        (attr "aria-labelledby" dialog)
  | None -> Alcotest.fail "expected modal-dialog node");
  (match find (By_attr ("data-testid", "modal-backdrop")) root with
  | Some backdrop ->
      Alcotest.(check (option string))
        "dismiss anchor survives" (Some "modal-dismiss")
        (attr "data-action" backdrop)
  | None -> Alcotest.fail "expected modal-backdrop node");
  match find (By_attr ("data-testid", "modal-root")) root with
  | Some _ -> ()
  | None -> Alcotest.fail "expected the modal-root anchor to stay put"

(* --- next_focus --- *)

let test_next_focus_tab_advances () =
  let result =
    Modal.next_focus ~focusable_ids:[ "a"; "b"; "c" ] ~current:"a" ~key:"Tab"
  in
  Alcotest.(check (option string)) "next" (Some "b") result

let test_next_focus_tab_wraps_at_end () =
  let result =
    Modal.next_focus ~focusable_ids:[ "a"; "b"; "c" ] ~current:"c" ~key:"Tab"
  in
  Alcotest.(check (option string)) "wraps to first" (Some "a") result

let test_next_focus_shift_tab_goes_back () =
  let result =
    Modal.next_focus ~focusable_ids:[ "a"; "b"; "c" ] ~current:"b"
      ~key:"Shift+Tab"
  in
  Alcotest.(check (option string)) "previous" (Some "a") result

let test_next_focus_shift_tab_wraps_at_start () =
  let result =
    Modal.next_focus ~focusable_ids:[ "a"; "b"; "c" ] ~current:"a"
      ~key:"Shift+Tab"
  in
  Alcotest.(check (option string)) "wraps to last" (Some "c") result

let test_next_focus_unknown_current_returns_none () =
  let result =
    Modal.next_focus ~focusable_ids:[ "a"; "b"; "c" ] ~current:"z" ~key:"Tab"
  in
  Alcotest.(check (option string)) "unknown current" None result

let test_next_focus_empty_list_returns_none () =
  let result = Modal.next_focus ~focusable_ids:[] ~current:"a" ~key:"Tab" in
  Alcotest.(check (option string)) "empty list" None result

let test_next_focus_non_tab_key_returns_none () =
  let result =
    Modal.next_focus ~focusable_ids:[ "a"; "b"; "c" ] ~current:"a" ~key:"Enter"
  in
  Alcotest.(check (option string)) "non-tab key" None result

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_ui_modal"
    [
      ( "rendering",
        [
          Alcotest.test_case "closed modal renders empty" `Quick
            test_closed_modal_renders_empty;
          Alcotest.test_case "open modal renders dialog" `Quick
            test_open_modal_renders_dialog;
        ] );
      ( "ARIA",
        [
          Alcotest.test_case "dialog has role=dialog" `Quick
            test_dialog_has_role_dialog;
          Alcotest.test_case "dialog has aria-modal=true" `Quick
            test_dialog_has_aria_modal_true;
          Alcotest.test_case "dialog has aria-labelledby" `Quick
            test_dialog_has_aria_labelledby;
        ] );
      ( "backdrop",
        [
          Alcotest.test_case "backdrop rendered when set" `Quick
            test_backdrop_rendered_when_on_backdrop_click_set;
          Alcotest.test_case "no backdrop when not set" `Quick
            test_no_backdrop_when_on_backdrop_click_not_set;
        ] );
      ( "subscriptions",
        [
          Alcotest.test_case "none when closed" `Quick
            test_subscriptions_none_when_closed;
          Alcotest.test_case "intercepts Escape when open" `Quick
            test_subscriptions_intercepts_escape_when_open;
          Alcotest.test_case "ignores non-Escape keys" `Quick
            test_subscriptions_ignores_non_escape_keys;
        ] );
      ( "builder overrides",
        [
          Alcotest.test_case "with_style overrides dialog" `Quick
            test_with_style_overrides_dialog;
          Alcotest.test_case "with_backdrop_style overrides backdrop" `Quick
            test_with_backdrop_style_overrides_backdrop;
          Alcotest.test_case "with_interaction applies to dialog" `Quick
            test_with_interaction_applies_to_dialog;
        ] );
      ( "root style and forced positioning",
        [
          Alcotest.test_case "root style reaches the modal root" `Quick
            test_root_style_reaches_the_modal_root;
          Alcotest.test_case "default root style positions the root" `Quick
            test_default_root_style_positions_the_root_without_an_override;
          Alcotest.test_case "backdrop positioning is forced" `Quick
            test_backdrop_positioning_is_forced_over_the_override;
          Alcotest.test_case "dialog position is filled in only when absent"
            `Quick test_dialog_position_is_filled_in_only_when_absent;
          Alcotest.test_case "dialog ARIA unchanged under every override" `Quick
            test_dialog_aria_is_unchanged_under_every_style_override;
        ] );
      ( "next_focus",
        [
          Alcotest.test_case "Tab advances" `Quick test_next_focus_tab_advances;
          Alcotest.test_case "Tab wraps at end" `Quick
            test_next_focus_tab_wraps_at_end;
          Alcotest.test_case "Shift+Tab goes back" `Quick
            test_next_focus_shift_tab_goes_back;
          Alcotest.test_case "Shift+Tab wraps at start" `Quick
            test_next_focus_shift_tab_wraps_at_start;
          Alcotest.test_case "unknown current returns None" `Quick
            test_next_focus_unknown_current_returns_none;
          Alcotest.test_case "empty list returns None" `Quick
            test_next_focus_empty_list_returns_none;
          Alcotest.test_case "non-Tab key returns None" `Quick
            test_next_focus_non_tab_key_returns_none;
        ] );
    ]
