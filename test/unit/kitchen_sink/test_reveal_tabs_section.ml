open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_reveal_tabs
module Reveal = Nopal_element.Reveal
module Style = Nopal_style.Style

let vp = Nopal_element.Viewport.desktop

(* The whole section, driven through the MVU loop rather than by constructing a
   model, so a state the section can no longer reach cannot keep a rendering
   alive here. *)
let after msgs =
  fst (run_app ~init:Sub.init ~update:Sub.update ~view:Sub.view msgs)

let by_testid testid model =
  Test_util.find_or_fail
    ("the section rendered no " ^ testid)
    (By_attr ("data-testid", testid))
    (tree (render (Sub.view vp model)))

let strip model = by_testid "reveal-tabs-strip" model
let grid model = by_testid "reveal-tabs-grid" model
let children = Test_util.children_of "a node"

let only_child label node =
  match children node with
  | [ child ] -> child
  | [] -> Alcotest.fail (label ^ " has no child")
  | _ :: _ :: _ -> Alcotest.fail (label ^ " has more than one child")

let declared_key container =
  match attr "reveal" container with
  | Some key -> key
  | None -> Alcotest.fail "the scroll container declared no child to reveal"

let declared_align container =
  match attr "reveal-align" container with
  | Some token -> token
  | None -> Alcotest.fail "the scroll container declared no alignment"

(* A keyed child renders as its own ["keyed"] node carrying the key, with the
   element it wraps as its only child. Anything else is a child the renderer
   would reconcile by position, which is what this suite exists to rule out. *)
let keyed_entry label node =
  match (node, attr "key" node) with
  | Element { tag = "keyed"; children = [ child ]; _ }, Some key -> (key, child)
  | Element _, (Some _ | None)
  | Empty, (Some _ | None)
  | Text _, (Some _ | None) ->
      Alcotest.fail (label ^ " is not keyed")

let declared_size label axis node =
  match style node with
  | None -> Alcotest.fail (label ^ " carries no style")
  | Some style -> (
      let size =
        match axis with
        | `Width -> style.Style.layout.width
        | `Height -> style.Style.layout.height
      in
      match size with
      | Some (Style.Fixed pixels) -> pixels
      | Some (Style.Fill | Style.Hug | Style.Fraction _)
      | None ->
          Alcotest.fail (label ^ " declares no fixed size on that axis"))

(* The tabs as rendered, in order: every child of the row inside the strip. *)
let rendered_tabs model =
  List.map (keyed_entry "a tab")
    (children (only_child "the strip" (strip model)))

let rendered_tab_keys model = List.map fst (rendered_tabs model)
let sum = List.fold_left ( +. ) 0.0

let fail_on_error label result =
  match result with
  | Ok () -> ()
  | Error (Not_found _) -> Alcotest.fail (label ^ ": no such control")
  | Error (No_handler { tag; event }) ->
      Alcotest.fail
        (Printf.sprintf "%s: the %s control handles no %s" label tag event)

let single_message label rendered =
  match messages rendered with
  | [ msg ] -> msg
  | [] -> Alcotest.fail (label ^ " dispatched no message")
  | _ :: _ :: _ -> Alcotest.fail (label ^ " dispatched more than one message")

(* Driven through the rendered tab chooser, so a chooser wired to the wrong
   message fails here rather than in a browser. *)
let choose key model =
  let rendered = render (Sub.view vp model) in
  fail_on_error "tab chooser"
    (input (By_attr ("data-field", "reveal-tabs-choice")) key rendered);
  fst (Sub.update model (single_message "the tab chooser" rendered))

let press_align action model =
  let rendered = render (Sub.view vp model) in
  fail_on_error action (click (By_attr ("data-action", action)) rendered);
  fst (Sub.update model (single_message action rendered))

(* The request a fresh section makes, with no interaction at all, names the
   last tab as rendered — read off the tree, not the module's own key list — so
   the container has to move to show it the moment it first renders. *)
let test_initial_model_requests_last_tab () =
  let model = after [] in
  match List.rev (rendered_tab_keys model) with
  | last :: _ :: _ ->
      Alcotest.(check string)
        "the first render asks for the last tab" last
        (declared_key (strip model));
      Alcotest.(check string)
        "under the nearest alignment"
        (Reveal.align_token Reveal.Nearest)
        (declared_align (strip model))
  | [ _ ]
  | [] ->
      Alcotest.fail "the strip renders fewer than two tabs"

(* The request is re-derived from the model on every view call, so choosing a
   tab is enough to move the container. The first assertion is what a request
   frozen on the initial tab would fail; the second is the way back. Every
   alignment control lands its own token on both containers, since one
   alignment governs the section. *)
let test_choosing_a_tab_changes_the_request () =
  let base = after [] in
  match rendered_tab_keys base with
  | first :: (_ :: _ as rest) ->
      let chose_first = choose first base in
      Alcotest.(check string)
        "choosing the first tab asks for it" first
        (declared_key (strip chose_first));
      let last =
        match List.rev rest with
        | key :: _ -> key
        | [] -> Alcotest.fail "the strip has no last tab"
      in
      Alcotest.(check string)
        "choosing the last tab again asks for it" last
        (declared_key (strip (choose last chose_first)));
      let tokens_after action =
        let model = press_align action base in
        (declared_align (strip model), declared_align (grid model))
      in
      let expected =
        List.map
          (fun align ->
            let token = Reveal.align_token align in
            (token, token))
          [ Reveal.Nearest; Reveal.Start; Reveal.Center; Reveal.End_ ]
      in
      Alcotest.(check (list (pair string string)))
        "every alignment control lands its own alignment on both containers"
        expected
        (List.map tokens_after
           [
             "reveal-tabs-align-nearest";
             "reveal-tabs-align-start";
             "reveal-tabs-align-center";
             "reveal-tabs-align-end";
           ])
  | [ _ ]
  | [] ->
      Alcotest.fail "the strip renders fewer than two tabs"

(* Every tab is keyed, on the first render and after a choice. A strip with one
   unkeyed sibling would be reconciled by position, replacing every keyed tab on
   every render; and the reveal resolves its target by key, so an unkeyed tab
   could never be revealed at all. *)
let test_tabs_are_keyed_throughout () =
  let initial = after [] in
  let check_keys label model =
    let keys = rendered_tab_keys model in
    Alcotest.(check (list string))
      (label ^ ": the tabs carry the section's keys, in order")
      Sub.tab_keys keys;
    Alcotest.(check int)
      (label ^ ": no two tabs share a key")
      (List.length keys)
      (List.length (List.sort_uniq String.compare keys))
  in
  check_keys "first render" initial;
  match Sub.tab_keys with
  | first :: _ :: _ -> check_keys "after a choice" (choose first initial)
  | [ _ ]
  | [] ->
      Alcotest.fail "the section declares fewer than two tabs"

(* The geometry the horizontal reveal needs, from the declared sizes: every tab
   fits inside the strip, so it can end fully visible, and the tabs before the
   last already fill the strip, so the last tab starts past its right edge and
   showing it is a sideways scroll rather than a formality. *)
let test_tab_row_fixed_widths_exceed_container () =
  let model = after [] in
  let container = declared_size "the strip" `Width (strip model) in
  let widths =
    List.map
      (fun (_key, tab) -> declared_size "a tab" `Width tab)
      (rendered_tabs model)
  in
  List.iter
    (fun width ->
      Alcotest.(check bool)
        (Printf.sprintf "a %.0fpx tab fits inside the %.0fpx strip" width
           container)
        true (width <= container))
    widths;
  match List.rev widths with
  | _last :: before ->
      Alcotest.(check bool)
        (Printf.sprintf
           "the tabs before the last (%.0fpx) fill the %.0fpx strip"
           (sum before) container)
        true
        (sum before >= container)
  | [] -> Alcotest.fail "the strip renders no tabs"

(* Where the requested cell sits, from the declared sizes of the rows and cells
   before it. A row is as tall as its tallest cell. *)
let locate_cell key rows =
  let rec in_row ~x cells =
    match cells with
    | [] -> None
    | (cell_key, cell) :: rest ->
        let width = declared_size "a cell" `Width cell in
        if String.equal cell_key key then
          Some (x, width, declared_size "a cell" `Height cell)
        else in_row ~x:(x +. width) rest
  in
  let rec down ~y rows =
    match rows with
    | [] -> None
    | (_row_key, row) :: rest -> (
        let cells = List.map (keyed_entry "a cell") (children row) in
        match in_row ~x:0.0 cells with
        | Some (x, width, height) -> Some (x, y, width, height)
        | None ->
            let height =
              List.fold_left
                (fun tallest (_key, cell) ->
                  Float.max tallest (declared_size "a cell" `Height cell))
                0.0 cells
            in
            down ~y:(y +. height) rest)
  in
  down ~y:0.0 rows

(* The two-way container overflows on both axes, and the cell it asks for lies
   wholly past its right edge and wholly below its bottom edge, so the reveal on
   arrival has to move it along both axes. The cell itself fits, so it can end
   fully visible. Rows and cells are keyed throughout, for the same reason the
   tabs are. *)
let test_grid_overflows_both_ways_and_requests_a_far_cell () =
  let model = after [] in
  let container = grid model in
  let width = declared_size "the grid" `Width container in
  let height = declared_size "the grid" `Height container in
  let rows =
    List.map (keyed_entry "a row") (children (only_child "the grid" container))
  in
  let key = declared_key container in
  match locate_cell key rows with
  | None -> Alcotest.fail ("no cell carries the requested key " ^ key)
  | Some (x, y, cell_width, cell_height) ->
      Alcotest.(check bool)
        (Printf.sprintf "the cell starts at x=%.0f, past the %.0fpx width" x
           width)
        true (x >= width);
      Alcotest.(check bool)
        (Printf.sprintf "the cell starts at y=%.0f, below the %.0fpx height" y
           height)
        true (y >= height);
      Alcotest.(check bool)
        "the cell fits inside the container" true
        (cell_width <= width && cell_height <= height)

(* The two extra strips exist to give a real browser reversed-axis cases, so
   what is checked here is only that they are present and wired: same request
   as the first strip, the same keyed tabs, and the right-to-left one carries
   its direction. The vertical one carries none and no writing mode — nopal_test
   computes no style, and the browser test sets the mode itself. *)
let test_reversed_strips_are_wired () =
  let model = after [] in
  let rtl = by_testid "reveal-tabs-rtl-strip" model in
  let vertical = by_testid "reveal-tabs-vertical-strip" model in
  Alcotest.(check (option string))
    "the rtl strip is right to left" (Some "rtl") (attr "dir" rtl);
  Alcotest.(check (option string))
    "the vertical strip sets no direction" None (attr "dir" vertical);
  List.iter
    (fun (label, container) ->
      Alcotest.(check string)
        (label ^ " asks for the same tab as the first strip")
        (declared_key (strip model))
        (declared_key container);
      Alcotest.(check (list string))
        (label ^ " holds the section's keyed tabs, in order")
        Sub.tab_keys
        (List.map
           (fun child -> fst (keyed_entry "a tab" child))
           (children (only_child label container))))
    [ ("the rtl strip", rtl); ("the vertical strip", vertical) ];
  List.iter
    (fun i ->
      List.iter
        (fun prefix ->
          let testid = Printf.sprintf "%s-tab-%d" prefix i in
          Alcotest.(check (option string))
            (testid ^ " is rendered") (Some testid)
            (attr "data-testid" (by_testid testid model)))
        [ "reveal-tabs-rtl"; "reveal-tabs-vertical" ])
    [ 0; 9 ]

(* The cover list gives a real browser the covering-rule case: it asks for the
   same tab as the strip, holds the section's keyed rows in order, and its
   column is a fractional number of pixels wide, wider than the list. *)
let test_cover_list_is_wired () =
  let model = after [] in
  let list = by_testid "reveal-tabs-cover-list" model in
  Alcotest.(check string)
    "the cover list asks for the same tab as the strip"
    (declared_key (strip model))
    (declared_key list);
  let column = only_child "the cover list" list in
  Alcotest.(check (list string))
    "the cover list holds the section's keyed rows, in order" Sub.tab_keys
    (List.map (fun child -> fst (keyed_entry "a row" child)) (children column));
  let width = declared_size "the cover list" `Width list in
  let content = declared_size "the cover column" `Width column in
  Alcotest.(check bool)
    "the column is wider than the list" true (content > width);
  Alcotest.(check bool)
    "the column is not a whole number of pixels wide" true
    (not (Float.equal content (Float.round content)))

let () =
  Alcotest.run "kitchen_sink_reveal_tabs_section"
    [
      ( "request",
        [
          Alcotest.test_case "the initial model requests the last tab" `Quick
            test_initial_model_requests_last_tab;
          Alcotest.test_case "choosing a tab changes the request" `Quick
            test_choosing_a_tab_changes_the_request;
        ] );
      ( "structure",
        [
          Alcotest.test_case "the tabs are keyed throughout" `Quick
            test_tabs_are_keyed_throughout;
          Alcotest.test_case "the tab row's fixed widths exceed the container"
            `Quick test_tab_row_fixed_widths_exceed_container;
          Alcotest.test_case
            "the grid overflows both ways and requests a far cell" `Quick
            test_grid_overflows_both_ways_and_requests_a_far_cell;
          Alcotest.test_case "the reversed strips are wired" `Quick
            test_reversed_strips_are_wired;
          Alcotest.test_case "the cover list is wired" `Quick
            test_cover_list_is_wired;
        ] );
    ]
