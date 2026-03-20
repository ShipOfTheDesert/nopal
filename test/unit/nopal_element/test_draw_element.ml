open Nopal_element

type msg = Moved of float * float | Clicked of float * float | Left

let scene = [ Nopal_scene.Scene.rect ~x:0. ~y:0. ~w:100. ~h:50. () ]

let test_draw_builder_defaults () =
  let el = Element.draw ~width:200. ~height:100. scene in
  Alcotest.(check bool)
    "draw produces Draw with scene" true
    (match el with
    | Element.Draw { width; height; scene = s; _ } ->
        Float.equal width 200. && Float.equal height 100. && List.length s = 1
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _ ->
        false);
  Alcotest.(check bool)
    "draw defaults: no callbacks, no cursor, no aria_label" true
    (match el with
    | Element.Draw
        {
          on_pointer_move = None;
          on_click = None;
          on_pointer_leave = None;
          cursor = None;
          aria_label = None;
          _;
        } ->
        true
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_draw_with_callbacks () =
  let on_move (pe : Element.pointer_event) = Moved (pe.x, pe.y) in
  let on_click (pe : Element.pointer_event) = Clicked (pe.x, pe.y) in
  let el =
    Element.draw ~width:100. ~height:50. ~on_pointer_move:on_move ~on_click
      ~on_pointer_leave:Left ~cursor:Nopal_style.Cursor.Crosshair
      ~aria_label:"chart" scene
  in
  Alcotest.(check bool)
    "draw with all callbacks set" true
    (match el with
    | Element.Draw
        {
          on_pointer_move = Some f;
          on_click = Some g;
          on_pointer_leave = Some Left;
          cursor = Some Nopal_style.Cursor.Crosshair;
          aria_label = Some "chart";
          _;
        } -> (
        let m =
          f { Element.x = 10.; y = 20.; client_x = 10.; client_y = 20. }
        in
        let c = g { Element.x = 5.; y = 15.; client_x = 5.; client_y = 15. } in
        match (m, c) with
        | Moved (10., 20.), Clicked (5., 15.) -> true
        | Moved _, _
        | Clicked _, _
        | Left, _ ->
            false)
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

type wrapper = Wrapped of msg

let test_draw_map () =
  let on_move (pe : Element.pointer_event) = Moved (pe.x, pe.y) in
  let el =
    Element.draw ~width:100. ~height:50. ~on_pointer_move:on_move
      ~on_pointer_leave:Left scene
  in
  let mapped = Element.map (fun m -> Wrapped m) el in
  Alcotest.(check bool)
    "map transforms draw callbacks" true
    (match mapped with
    | Element.Draw
        { on_pointer_move = Some f; on_pointer_leave = Some (Wrapped Left); _ }
      -> (
        match f { Element.x = 1.; y = 2.; client_x = 1.; client_y = 2. } with
        | Wrapped (Moved (1., 2.)) -> true
        | Wrapped (Moved _ | Clicked _ | Left) -> false)
    | Element.Empty
    | Element.Text _
    | Element.Box _
    | Element.Row _
    | Element.Column _
    | Element.Button _
    | Element.Input _
    | Element.Image _
    | Element.Scroll _
    | Element.Keyed _
    | Element.Draw _ ->
        false)

let test_draw_equal () =
  let el1 =
    Element.draw ~width:100. ~height:50. ~aria_label:"chart"
      ~cursor:Nopal_style.Cursor.Pointer scene
  in
  let el2 =
    Element.draw ~width:100. ~height:50. ~aria_label:"chart"
      ~cursor:Nopal_style.Cursor.Pointer scene
  in
  let el3 = Element.draw ~width:200. ~height:50. scene in
  Alcotest.(check bool)
    "equal draw with same data fields" true (Element.equal el1 el2);
  Alcotest.(check bool)
    "not equal draw with different width" false (Element.equal el1 el3)

let () =
  Alcotest.run "nopal_element_draw"
    [
      ( "draw",
        [
          Alcotest.test_case "draw_builder_defaults" `Quick
            test_draw_builder_defaults;
          Alcotest.test_case "draw_with_callbacks" `Quick
            test_draw_with_callbacks;
          Alcotest.test_case "draw_map" `Quick test_draw_map;
          Alcotest.test_case "draw_equal" `Quick test_draw_equal;
        ] );
    ]
