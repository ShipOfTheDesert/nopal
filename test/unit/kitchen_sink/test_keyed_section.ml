open Nopal_test.Test_renderer

(* Native structural coverage for the kitchen-sink keyed-lists section
   (feature 0120). The section is the living reference for the four keyed
   reconciliation contracts; this proves the view renders each scenario the
   renderer fixes target:
     - FR-3 reorder: every row carries an editable input (the focusable node
       whose focus the reorder must preserve in the browser e2e);
     - FR-1 into-keyed: a container that flips its whole child list between
       non-keyed and all-keyed;
     - FR-2 variant change: the same key rendered as a Box or a Text;
     - FR-4 keyed Empty: the same key rendered as Empty or a visible Box.
   Navigation is stubbed and storage in-memory so the test stays browser-free,
   mirroring {!Test_mobile_section}. *)
module Test_platform : Nopal_platform.Platform.S = struct
  let current_path () = "/"
  let push_state (_ : string) = ()
  let replace_state (_ : string) = ()
  let back () = ()
  let on_popstate (_ : string -> unit) () = ()

  module Store = Nopal_storage.In_memory ()

  let storage = (module Store : Nopal_storage.S)
end

module K = Kitchen_sink_app.Make (Test_platform)
open K

let model0 () = fst (init ())
let apply msg = fst (update (model0 ()) msg)
let keyed_tree model = tree (render (view_keyed model))
let present sel model = Option.is_some (find sel (keyed_tree model))
let testid id = By_attr ("data-testid", id)

(* FR-3: each keyed row renders an editable input plus its reorder affordance.
   The input is the node the browser e2e focuses; its [on_change] feeds the
   label back through [EditKeyedItem], so editing one row never disturbs the
   list order. *)
let test_reorder_rows_render_editable_inputs () =
  let m = model0 () in
  let t = keyed_tree m in
  List.iter
    (fun id ->
      Alcotest.(check bool)
        (Printf.sprintf "row %d input present" id)
        true
        (Option.is_some (find (testid ("keyed-input-" ^ string_of_int id)) t));
      Alcotest.(check bool)
        (Printf.sprintf "row %d up affordance present" id)
        true
        (Option.is_some (find (testid ("keyed-up-" ^ string_of_int id)) t)))
    [ 1; 2; 3 ];
  match
    find (testid "keyed-input-2")
      (keyed_tree (apply (EditKeyedItem (2, "edited"))))
  with
  | Some node ->
      Alcotest.(check (option string))
        "input value reflects EditKeyedItem" (Some "edited") (attr "value" node)
  | None -> Alcotest.fail "edited row-2 input missing"

(* FR-1: the into-keyed container shows non-keyed boxes by default and all-keyed
   boxes once toggled; the old non-keyed children must not survive the switch. *)
let test_into_keyed_transition_renders_both_modes () =
  let plain = model0 () in
  Alcotest.(check bool)
    "plain mode shows a non-keyed child" true
    (present (testid "ik-plain-a") plain);
  Alcotest.(check bool)
    "plain mode has no keyed child" false
    (present (testid "ik-keyed-a") plain);
  let keyed = apply ToggleKeyedIntoKeyed in
  Alcotest.(check bool)
    "keyed mode shows a keyed child" true
    (present (testid "ik-keyed-a") keyed);
  Alcotest.(check bool)
    "keyed mode drops the non-keyed child" false
    (present (testid "ik-plain-a") keyed)

(* FR-2: the same key "vc" is a Box by default and a Text once toggled. *)
let vc_node model = find (By_attr ("key", "vc")) (keyed_tree model)

let test_variant_change_box_to_text () =
  (match vc_node (model0 ()) with
  | Some n ->
      Alcotest.(check bool)
        "box variant present" true
        (Option.is_some (find (testid "vc-box") n));
      Alcotest.(check bool)
        "box variant carries its label" true
        (Test_util.string_contains (text_content n) ~sub:"variant as box")
  | None -> Alcotest.fail "vc keyed node missing in box mode");
  match vc_node (apply ToggleKeyedVariant) with
  | Some n ->
      Alcotest.(check bool)
        "box gone in text mode" false
        (Option.is_some (find (testid "vc-box") n));
      Alcotest.(check bool)
        "text variant carries its label" true
        (Test_util.string_contains (text_content n) ~sub:"variant as text")
  | None -> Alcotest.fail "vc keyed node missing in text mode"

(* FR-4: the same key "ks" renders as Empty (no box, no text) by default and a
   visible Box once toggled — the keyed Empty the renderer must reuse, not leak. *)
let ks_node model = find (By_attr ("key", "ks")) (keyed_tree model)

let test_keyed_empty_renders_empty_then_visible () =
  (match ks_node (model0 ()) with
  | Some n ->
      Alcotest.(check bool)
        "no box while empty" false
        (Option.is_some (find (testid "ks-box") n));
      Alcotest.(check string) "empty child renders no text" "" (text_content n)
  | None -> Alcotest.fail "ks keyed node missing while empty");
  match ks_node (apply ToggleKeyedEmpty) with
  | Some n ->
      Alcotest.(check bool)
        "box visible once shown" true
        (Option.is_some (find (testid "ks-box") n))
  | None -> Alcotest.fail "ks keyed node missing once shown"

let () =
  Alcotest.run "kitchen_sink_keyed_section"
    [
      ( "scenarios",
        [
          Alcotest.test_case "reorder rows render editable inputs" `Quick
            test_reorder_rows_render_editable_inputs;
          Alcotest.test_case "into-keyed transition renders both modes" `Quick
            test_into_keyed_transition_renders_both_modes;
          Alcotest.test_case "variant change flips box to text" `Quick
            test_variant_change_box_to_text;
          Alcotest.test_case "keyed empty renders empty then visible" `Quick
            test_keyed_empty_renders_empty_then_visible;
        ] );
    ]
