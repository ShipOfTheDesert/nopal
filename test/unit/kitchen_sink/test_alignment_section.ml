(* The kitchen sink's alignment section, read structurally: one row per value of
   each axis's alignment, each reporting the value it was built with, and cross
   rows whose children differ in height so the four cross values look different.

   Whether a browser applies those values is a computed style, and the browser
   spec reads it from the data-testids pinned here. *)

open Nopal_test.Test_renderer
module Style = Nopal_style.Style

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

let vp = Nopal_element.Viewport.desktop

(* Each list sits beside an exhaustive or-pattern, so a constructor added to the
   type stops this compiling, which points at the list to extend. *)
let every_main_align =
  let listed : Style.align -> Style.align list = function
    | Start
    | Center
    | End_
    | Space_between ->
        [ Start; Center; End_; Space_between ]
  in
  listed Start

let every_cross_align =
  let listed : Style.cross_align -> Style.cross_align list = function
    | Start
    | Center
    | End_
    | Stretch ->
        [ Start; Center; End_; Stretch ]
  in
  listed Start

let main_name : Style.align -> string = function
  | Start -> "start"
  | Center -> "center"
  | End_ -> "end"
  | Space_between -> "space-between"

let cross_name : Style.cross_align -> string = function
  | Start -> "start"
  | Center -> "center"
  | End_ -> "end"
  | Stretch -> "stretch"

let main_testid a = "align-main-" ^ main_name a
let cross_testid a = "align-cross-" ^ cross_name a

let section () =
  let page = tree (render (K.view vp (fst (K.init ())))) in
  match find (By_attr ("data-testid", "alignment-section")) page with
  | Some node -> node
  | None -> Alcotest.fail "the page renders no alignment section"

let row_in testid parent =
  match find (By_attr ("data-testid", testid)) parent with
  | Some node -> node
  | None -> Alcotest.failf "the section renders no %S" testid

let layout_of label node =
  match style node with
  | Some s -> s.Style.layout
  | None -> Alcotest.failf "%s is not an element" label

let children_of testid node =
  match node with
  | Element { children; _ } -> children
  | Empty
  | Text _ ->
      Alcotest.failf "%S is not an element" testid

let test_each_main_row_reports_its_alignment () =
  let root = section () in
  List.iter
    (fun a ->
      let testid = main_testid a in
      let layout = layout_of testid (row_in testid root) in
      Alcotest.(check (option string))
        (testid ^ " reports its main_align")
        (Some (main_name a))
        (Option.map main_name layout.main_align))
    every_main_align

let test_each_cross_row_reports_its_alignment () =
  let root = section () in
  List.iter
    (fun a ->
      let testid = cross_testid a in
      let layout = layout_of testid (row_in testid root) in
      Alcotest.(check (option string))
        (testid ^ " reports its cross_align")
        (Some (cross_name a))
        (Option.map cross_name layout.cross_align))
    every_cross_align

let fixed_height label (layout : Style.layout) =
  match layout.height with
  | Some (Fixed h) -> h
  | Some Fill
  | Some Hug
  | Some (Fraction _)
  | None ->
      Alcotest.failf "%s has no fixed height" label

(* A stretched child is one whose height the row decides, so the stretch row's
   children must declare none. Every other row's children declare a fixed
   height each, all different and all shorter than the row, so where they sit
   across it tells start, center and end apart. *)
let test_cross_rows_have_unequal_children () =
  let root = section () in
  List.iter
    (fun a ->
      let testid = cross_testid a in
      let row = row_in testid root in
      let row_height = fixed_height testid (layout_of testid row) in
      let children = children_of testid row in
      Alcotest.(check int)
        (testid ^ " holds three boxes")
        3 (List.length children);
      let child_layouts = List.map (layout_of (testid ^ "'s child")) children in
      match a with
      | Stretch ->
          List.iter
            (fun (l : Style.layout) ->
              Alcotest.(check bool)
                (testid ^ "'s child declares no height")
                true (Option.is_none l.height))
            child_layouts
      | Start
      | Center
      | End_ ->
          let heights =
            List.map (fixed_height (testid ^ "'s child")) child_layouts
          in
          Alcotest.(check int)
            (testid ^ "'s children have three different heights")
            3
            (List.length (List.sort_uniq Float.compare heights));
          List.iter
            (fun h ->
              Alcotest.(check bool)
                (Printf.sprintf "%s's %gpx child is shorter than the %gpx row"
                   testid h row_height)
                true (h < row_height))
            heights)
    every_cross_align

let () =
  Alcotest.run "kitchen_sink_alignment_section"
    [
      ( "alignment_section",
        [
          Alcotest.test_case "each_main_row_reports_its_alignment" `Quick
            test_each_main_row_reports_its_alignment;
          Alcotest.test_case "each_cross_row_reports_its_alignment" `Quick
            test_each_cross_row_reports_its_alignment;
          Alcotest.test_case "cross_rows_have_unequal_children" `Quick
            test_cross_rows_have_unequal_children;
        ] );
    ]
