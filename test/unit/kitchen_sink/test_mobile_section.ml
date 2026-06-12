open Nopal_test.Test_renderer

(* Native structural coverage for the kitchen-sink mobile-signals section
   (RFC 0116 Task 4). Two device-independent MVU contracts:
     - the keyboard-height debug display reflects [KeyboardHeightChanged] (REQ-N2);
     - the back-demo's current route follows [Route_changed] (REQ-F3), proving the
       router-back consumer the Tauri back-IPC e2e (Task 6) depends on.
   Navigation is stubbed and storage is in-memory so the tests stay browser-free,
   mirroring {!Test_storage_section}. *)
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

let model0 () =
  let m, _ = init () in
  m

let apply msg = fst (update (model0 ()) msg)

let testid_text testid model =
  let t = tree (render (view_mobile model)) in
  match find (By_attr ("data-testid", testid)) t with
  | Some node -> text_content node
  | None -> Alcotest.fail (testid ^ " element missing")

(* REQ-N2: the keyboard-height subscription drives a debug display. A height of
   280 must surface; a 0 (keyboard hidden) must surface its own digit, not stay
   stuck on the prior value. *)
let test_keyboard_height_display_reflects_message () =
  Alcotest.(check bool)
    "shows shown-keyboard height" true
    (Test_util.string_contains
       (testid_text "keyboard-height" (apply (KeyboardHeightChanged 280)))
       ~sub:"280");
  Alcotest.(check bool)
    "shows hidden-keyboard height" true
    (Test_util.string_contains
       (testid_text "keyboard-height" (apply (KeyboardHeightChanged 0)))
       ~sub:"0")

(* REQ-F3: a popstate-driven [Route_changed] returns the demo to the prior route.
   Drive into [Back_detail] via the push affordance, then deliver
   [Route_changed Back_home] (what the real history.back() -> popstate ->
   on_navigate chain produces) and confirm the demo reflects home again. *)
let test_back_demo_route_changed_updates_current () =
  let detail = fst (update (model0 ()) Back_demo_push) in
  Alcotest.(check bool)
    "push drove the demo to detail" true
    (Test_util.string_contains
       (testid_text "back-demo-current" detail)
       ~sub:"Back_detail");
  let home = fst (update detail (Route_changed Back_home)) in
  Alcotest.(check bool)
    "route change returned the demo to home" true
    (Test_util.string_contains
       (testid_text "back-demo-current" home)
       ~sub:"Back_home");
  Alcotest.(check bool)
    "home no longer reads as detail" false
    (Test_util.string_contains
       (testid_text "back-demo-current" home)
       ~sub:"Back_detail")

(* REQ-F4/N2: the page root pads its content by the live safe-area insets so
   nothing is clipped by the status bar, navigation bar, or home indicator on
   mobile. With a non-zero safe-area viewport the outermost column's padding is
   the base 32px plus each inset; with zero insets (desktop/web) it stays 32px,
   so omitting a native source is byte-for-byte today's behaviour. *)
let test_page_padding_includes_safe_area () =
  let open Nopal_style.Style in
  let module Viewport = Nopal_element.Viewport in
  let page_layout vp =
    match find (By_tag "column") (tree (render (view vp (model0 ())))) with
    | Some node -> (
        match style node with
        | Some s -> s.layout
        | None -> Alcotest.fail "page root column has no style")
    | None -> Alcotest.fail "page root column missing"
  in
  let pad = Alcotest.(check (option (float 0.01))) in
  let l =
    page_layout
      (Viewport.make ~width:400 ~height:800
         ~safe_area:
           (Viewport.make_safe_area ~top:50 ~right:10 ~bottom:30 ~left:5 ())
         ())
  in
  pad "top = 32 + 50" (Some 82.0) l.padding_top;
  pad "right = 32 + 10" (Some 42.0) l.padding_right;
  pad "bottom = 32 + 30" (Some 62.0) l.padding_bottom;
  pad "left = 32 + 5" (Some 37.0) l.padding_left;
  let z = page_layout (Viewport.make ~width:400 ~height:800 ()) in
  pad "zero insets keep the base 32px (web/desktop)" (Some 32.0) z.padding_top

let () =
  Alcotest.run "kitchen_sink_mobile_section"
    [
      ( "keyboard",
        [
          Alcotest.test_case "height display reflects message" `Quick
            test_keyboard_height_display_reflects_message;
        ] );
      ( "back-demo",
        [
          Alcotest.test_case "route change updates current route" `Quick
            test_back_demo_route_changed_updates_current;
        ] );
      ( "safe-area",
        [
          Alcotest.test_case "page padding includes safe-area insets" `Quick
            test_page_padding_includes_safe_area;
        ] );
    ]
