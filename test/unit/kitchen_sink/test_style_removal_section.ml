open Nopal_test.Test_renderer

(* Native structural coverage for the kitchen-sink style-removal section
   (feature 0119, FR-1). The section is the living reference for stale-inline-
   style removal: a box is painted with a background by default, and toggling
   drops the background style prop *entirely* (not merely changing it) — the
   exact case the web renderer must clear from the DOM. This test pins the demo
   wiring (the DOM-level removal itself is covered by
   [test_reconcile_removes_dropped_inline_style] in test_nopal_web). Navigation
   is stubbed and storage in-memory so the test stays browser-free, mirroring
   {!Test_keyed_section}. *)
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
let section_tree model = tree (render (view_style_removal model))
let testid id = By_attr ("data-testid", id)
let box_of model = find (testid "style-removal-box") (section_tree model)

(* The background paint on the demo box, or [None] when the box carries no
   background style prop. *)
let background_of model =
  match box_of model with
  | Some n -> (
      match style n with
      | Some s -> s.Nopal_style.Style.paint.background
      | None -> None)
  | None -> None

let test_toggle_button_present () =
  Alcotest.(check bool)
    "toggle button present" true
    (Option.is_some
       (find (testid "style-removal-toggle") (section_tree (model0 ()))))

let test_background_present_by_default () =
  Alcotest.(check bool)
    "box is painted with a background initially" true
    (Option.is_some (background_of (model0 ())))

let test_background_removed_after_toggle () =
  let toggled = apply ToggleStyleBackground in
  Alcotest.(check bool)
    "box is still rendered after the toggle" true
    (Option.is_some (box_of toggled));
  Alcotest.(check bool)
    "background style prop is absent after the toggle" true
    (Option.is_none (background_of toggled))

let () =
  Alcotest.run "kitchen_sink_style_removal_section"
    [
      ( "scenarios",
        [
          Alcotest.test_case "toggle button present" `Quick
            test_toggle_button_present;
          Alcotest.test_case "background present by default" `Quick
            test_background_present_by_default;
          Alcotest.test_case "background removed after toggle" `Quick
            test_background_removed_after_toggle;
        ] );
    ]
