open Nopal_test.Test_renderer
module B = Nopal_ui.Button
module E = Nopal_element.Element
module S = Nopal_style.Style

type msg = Click

let msg_testable =
  Alcotest.testable (fun fmt Click -> Format.fprintf fmt "Click") ( = )

let check_attr msg key expected node =
  Alcotest.(check (option string)) msg expected (attr key node)

let find_button node =
  match find (By_tag "button") node with
  | Some n -> n
  | None -> Alcotest.fail "expected a button element"

(* --- Variant default attrs --- *)

let test_primary_default_attrs () =
  let config = B.default Primary in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-variant" "data-variant" (Some "primary") btn;
  Alcotest.(check (option string))
    "no aria-disabled" None (attr "aria-disabled" btn);
  Alcotest.(check (option string)) "no aria-busy" None (attr "aria-busy" btn)

let test_secondary_default_attrs () =
  let config = B.default Secondary in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-variant" "data-variant" (Some "secondary") btn

let test_destructive_default_attrs () =
  let config = B.default Destructive in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-variant" "data-variant" (Some "destructive") btn

let test_ghost_default_attrs () =
  let config = B.default Ghost in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-variant" "data-variant" (Some "ghost") btn

let test_icon_default_attrs () =
  let config = B.default Icon in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-variant" "data-variant" (Some "icon") btn

(* --- Disabled --- *)

let test_disabled_suppresses_click () =
  let config =
    { (B.default Primary) with disabled = true; on_click = Some Click }
  in
  let r = render (B.view config (E.text "ok")) in
  let _result = click (By_tag "button") r in
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

let test_disabled_sets_aria () =
  let config = { (B.default Primary) with disabled = true } in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "aria-disabled" "aria-disabled" (Some "true") btn

(* --- Loading --- *)

let test_loading_suppresses_click () =
  let config =
    { (B.default Primary) with loading = true; on_click = Some Click }
  in
  let r = render (B.view config (E.text "ok")) in
  let _result = click (By_tag "button") r in
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

let test_loading_sets_aria () =
  let config = { (B.default Primary) with loading = true } in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "aria-busy" "aria-busy" (Some "true") btn

(* --- Both disabled and loading --- *)

let test_disabled_and_loading_both_aria () =
  let config = { (B.default Primary) with disabled = true; loading = true } in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "aria-disabled" "aria-disabled" (Some "true") btn;
  check_attr "aria-busy" "aria-busy" (Some "true") btn

(* --- Click dispatches --- *)

let test_click_dispatches_message () =
  let config = { (B.default Primary) with on_click = Some Click } in
  let r = render (B.view config (E.text "ok")) in
  let result = click (By_tag "button") r in
  Alcotest.(check (result unit Test_util.error_testable))
    "click ok" (Ok ()) result;
  Alcotest.(check (list msg_testable)) "one message" [ Click ] (messages r)

(* --- Child text --- *)

let test_child_text_preserved () =
  let config = B.default Primary in
  let r = render (B.view config (E.text "Save")) in
  let btn = find_button (tree r) in
  Alcotest.(check string) "child text" "Save" (text_content btn)

(* --- User attrs merged --- *)

let test_user_attrs_merged_with_aria () =
  let config =
    {
      (B.default Primary) with
      disabled = true;
      attrs = [ ("data-testid", "my-btn") ];
    }
  in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-testid" "data-testid" (Some "my-btn") btn;
  check_attr "aria-disabled" "aria-disabled" (Some "true") btn

(* --- Custom interaction override --- *)

let test_custom_interaction_overrides_variant_default () =
  let custom_interaction =
    {
      Nopal_style.Interaction.default with
      hover =
        Some
          (S.default
          |> S.with_paint (fun p ->
              { p with background = Some (S.hex "#ff0000") }));
    }
  in
  let config =
    { (B.default Primary) with interaction = Some custom_interaction }
  in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  Alcotest.(check (option bool))
    "custom interaction preserved" (Some true)
    (Option.map
       (Nopal_style.Interaction.equal custom_interaction)
       (interaction btn))

(* --- Disabled and loading treatment --- *)

let style_with_background hex =
  S.default |> S.with_paint (fun p -> { p with background = Some (S.hex hex) })

let disabled_look = style_with_background "#101010"
let loading_look = style_with_background "#202020"

(* Every field of the record is written out. [B.default] carries behavioural
   values that are not options ([disabled], [loading], [on_click]), so a
   [{ (B.default Primary) with _ }] fixture would inherit state this case never
   asked for. The two style overrides are then applied through their setters
   rather than written into the literal, so the setters are on the path these
   cases walk: a setter body that wrote the other field reddens here. *)
let rendered_button ~disabled ~loading ~disabled_style ~loading_style =
  let config : msg B.config =
    {
      B.variant = B.Primary;
      disabled;
      loading;
      on_click = None;
      style = None;
      interaction = None;
      attrs = [];
      disabled_style = None;
      loading_style = None;
    }
  in
  let config =
    match disabled_style with
    | None -> config
    | Some s -> B.with_disabled_style s config
  in
  let config =
    match loading_style with
    | None -> config
    | Some s -> B.with_loading_style s config
  in
  find_button (tree (render (B.view config (E.text "ok"))))

let style_of ~disabled ~loading ~disabled_style ~loading_style =
  style (rendered_button ~disabled ~loading ~disabled_style ~loading_style)

let test_disabled_style_reaches_the_disabled_button () =
  let without =
    style_of ~disabled:true ~loading:false ~disabled_style:None
      ~loading_style:None
  in
  let with_override =
    style_of ~disabled:true ~loading:false ~disabled_style:(Some disabled_look)
      ~loading_style:None
  in
  let while_enabled =
    style_of ~disabled:false ~loading:false ~disabled_style:(Some disabled_look)
      ~loading_style:None
  in
  Alcotest.(check (option bool))
    "the override reaches the disabled button" (Some true)
    (Option.map (S.equal disabled_look) with_override);
  Alcotest.(check (option bool))
    "and displaces what the button carried without it" (Some false)
    (Option.map (S.equal disabled_look) without);
  Alcotest.(check (option bool))
    "and does not reach the button while it is enabled" (Some false)
    (Option.map (S.equal disabled_look) while_enabled)

let test_loading_style_reaches_the_loading_button () =
  let without =
    style_of ~disabled:false ~loading:true ~disabled_style:None
      ~loading_style:None
  in
  let with_override =
    style_of ~disabled:false ~loading:true ~disabled_style:None
      ~loading_style:(Some loading_look)
  in
  let while_idle =
    style_of ~disabled:false ~loading:false ~disabled_style:None
      ~loading_style:(Some loading_look)
  in
  Alcotest.(check (option bool))
    "the override reaches the loading button" (Some true)
    (Option.map (S.equal loading_look) with_override);
  Alcotest.(check (option bool))
    "and displaces what the button carried without it" (Some false)
    (Option.map (S.equal loading_look) without);
  Alcotest.(check (option bool))
    "and does not reach the button while it is idle" (Some false)
    (Option.map (S.equal loading_look) while_idle)

(* The order the two states resolve in is a published rule (button.mli), so it
   is pinned rather than left to drift. *)
let test_disabled_style_wins_when_both_disabled_and_loading () =
  let both =
    style_of ~disabled:true ~loading:true ~disabled_style:(Some disabled_look)
      ~loading_style:(Some loading_look)
  in
  let loading_only =
    style_of ~disabled:true ~loading:true ~disabled_style:None
      ~loading_style:(Some loading_look)
  in
  Alcotest.(check (option bool))
    "the disabled style wins" (Some true)
    (Option.map (S.equal disabled_look) both);
  Alcotest.(check (option bool))
    "the loading style does not" (Some false)
    (Option.map (S.equal loading_look) both);
  Alcotest.(check (option bool))
    "and the loading style still applies with no disabled style set" (Some true)
    (Option.map (S.equal loading_look) loading_only)

let test_aria_disabled_is_unchanged_under_a_style_override () =
  let btn =
    rendered_button ~disabled:true ~loading:true
      ~disabled_style:(Some disabled_look) ~loading_style:(Some loading_look)
  in
  check_attr "aria-disabled" "aria-disabled" (Some "true") btn;
  check_attr "aria-busy" "aria-busy" (Some "true") btn;
  check_attr "data-variant" "data-variant" (Some "primary") btn

(* --- Default config --- *)

let test_default_config_not_disabled_or_loading () =
  let config = B.default Primary in
  Alcotest.(check bool) "not disabled" false config.disabled;
  Alcotest.(check bool) "not loading" false config.loading

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_ui_button"
    [
      ( "variant attrs",
        [
          Alcotest.test_case "primary" `Quick test_primary_default_attrs;
          Alcotest.test_case "secondary" `Quick test_secondary_default_attrs;
          Alcotest.test_case "destructive" `Quick test_destructive_default_attrs;
          Alcotest.test_case "ghost" `Quick test_ghost_default_attrs;
          Alcotest.test_case "icon" `Quick test_icon_default_attrs;
        ] );
      ( "disabled",
        [
          Alcotest.test_case "suppresses click" `Quick
            test_disabled_suppresses_click;
          Alcotest.test_case "sets aria" `Quick test_disabled_sets_aria;
        ] );
      ( "loading",
        [
          Alcotest.test_case "suppresses click" `Quick
            test_loading_suppresses_click;
          Alcotest.test_case "sets aria" `Quick test_loading_sets_aria;
        ] );
      ( "combined",
        [
          Alcotest.test_case "disabled+loading aria" `Quick
            test_disabled_and_loading_both_aria;
        ] );
      ( "events",
        [
          Alcotest.test_case "click dispatches" `Quick
            test_click_dispatches_message;
        ] );
      ( "rendering",
        [
          Alcotest.test_case "child text" `Quick test_child_text_preserved;
          Alcotest.test_case "user attrs merged" `Quick
            test_user_attrs_merged_with_aria;
          Alcotest.test_case "custom interaction override" `Quick
            test_custom_interaction_overrides_variant_default;
        ] );
      ( "state treatment",
        [
          Alcotest.test_case "disabled style reaches the disabled button" `Quick
            test_disabled_style_reaches_the_disabled_button;
          Alcotest.test_case "loading style reaches the loading button" `Quick
            test_loading_style_reaches_the_loading_button;
          Alcotest.test_case "disabled style wins over loading" `Quick
            test_disabled_style_wins_when_both_disabled_and_loading;
          Alcotest.test_case "aria unchanged under a style override" `Quick
            test_aria_disabled_is_unchanged_under_a_style_override;
        ] );
      ( "defaults",
        [
          Alcotest.test_case "not disabled or loading" `Quick
            test_default_config_not_disabled_or_loading;
        ] );
    ]
