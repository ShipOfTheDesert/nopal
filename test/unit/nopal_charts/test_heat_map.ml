open Nopal_charts
open Nopal_element
open Nopal_draw

type msg = Hovered of Hover.t | Left

(* --- sample data as flat list of (row, col, value) tuples --- *)

type cell = { r : int; c : int; v : float }

let sample_data =
  [
    { r = 0; c = 0; v = 1.0 };
    { r = 0; c = 1; v = 2.0 };
    { r = 0; c = 2; v = 3.0 };
    { r = 1; c = 0; v = 4.0 };
    { r = 1; c = 1; v = 5.0 };
    { r = 1; c = 2; v = 6.0 };
  ]

let row_labels = [ "row0"; "row1" ]
let col_labels = [ "col0"; "col1"; "col2" ]

let seq_scale =
  Color_scale.sequential
    ~low:(Color.rgb ~r:1.0 ~g:1.0 ~b:1.0)
    ~high:(Color.rgb ~r:1.0 ~g:0.0 ~b:0.0)

let div_scale =
  Color_scale.diverging
    ~low:(Color.rgb ~r:0.0 ~g:0.0 ~b:1.0)
    ~mid:(Color.rgb ~r:1.0 ~g:1.0 ~b:1.0)
    ~high:(Color.rgb ~r:1.0 ~g:0.0 ~b:0.0)
    ~midpoint:3.5 ()

(* --- helpers --- *)

let heat_map_view ?(scale = seq_scale) ?on_hover ?on_leave ?hover
    ?format_tooltip data =
  Heat_map.view ~data
    ~row:(fun d -> d.r)
    ~col:(fun d -> d.c)
    ~value:(fun d -> d.v)
    ~row_count:2 ~col_count:3 ~row_labels ~col_labels ~scale ~width:400.0
    ~height:300.0 ?on_hover ?on_leave ?hover ?format_tooltip ()

let extract_draw (el : msg Element.t) =
  match el with
  | Box { children; _ } ->
      List.find_map
        (fun (child : msg Element.t) ->
          match child with
          | Draw d ->
              Some
                ( d.scene,
                  d.on_pointer_move,
                  d.on_pointer_leave,
                  d.width,
                  d.height )
          | _ -> None)
        children
  | Draw d ->
      Some (d.scene, d.on_pointer_move, d.on_pointer_leave, d.width, d.height)
  | _ -> None

let count_rects (scene : Scene.t list) =
  List.fold_left
    (fun acc (node : Scene.t) ->
      match node with
      | Rect _ -> acc + 1
      | _ -> acc)
    0 scene

let get_rect_fills (scene : Scene.t list) =
  List.filter_map
    (fun (node : Scene.t) ->
      match node with
      | Rect { fill; _ } -> Some fill
      | _ -> None)
    scene

let find_texts (scene : Scene.t list) =
  List.filter_map
    (fun (node : Scene.t) ->
      match node with
      | Text { content; _ } -> Some content
      | _ -> None)
    scene

(* --- tests --- *)

let test_empty_data () =
  let el =
    Heat_map.view ~data:[]
      ~row:(fun _ -> 0)
      ~col:(fun _ -> 0)
      ~value:(fun _ -> 0.0)
      ~row_count:0 ~col_count:0 ~scale:seq_scale ~width:400.0 ~height:300.0 ()
  in
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check int) "empty scene" 0 (List.length scene)
  | _ -> Alcotest.fail "expected Draw element for empty data"

let test_produces_draw_element () =
  let el = heat_map_view sample_data in
  match extract_draw el with
  | Some (_, _, _, w, h) ->
      Alcotest.(check (float 0.01)) "width" 400.0 w;
      Alcotest.(check (float 0.01)) "height" 300.0 h
  | None -> Alcotest.fail "expected Draw element"

let test_cell_count () =
  (* 2 rows × 3 cols = 6 cell rects *)
  let el = heat_map_view sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let n = count_rects scene in
      Alcotest.(check int) "6 cell rects" 6 n
  | None -> Alcotest.fail "expected Draw element"

let test_cell_color_sequential () =
  (* With sequential scale white→red, min=1.0, max=6.0:
     value 1.0 should be white (low), value 6.0 should be red (high) *)
  let el = heat_map_view ~scale:seq_scale sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let fills = get_rect_fills scene in
      (* First cell value=1.0 (min) → white *)
      let first_fill = List.hd fills in
      let expected_low = Color_scale.apply seq_scale ~min:1.0 ~max:6.0 1.0 in
      let actual_color =
        match first_fill with
        | Paint.Solid c -> c
        | _ -> Alcotest.failf "expected solid fill"
      in
      Alcotest.(check bool)
        "first cell is low color" true
        (Color.equal actual_color expected_low);
      (* Last cell value=6.0 (max) → red *)
      let last_fill = List.nth fills 5 in
      let expected_high = Color_scale.apply seq_scale ~min:1.0 ~max:6.0 6.0 in
      let actual_last =
        match last_fill with
        | Paint.Solid c -> c
        | _ -> Alcotest.failf "expected solid fill"
      in
      Alcotest.(check bool)
        "last cell is high color" true
        (Color.equal actual_last expected_high)
  | None -> Alcotest.fail "expected Draw element"

let test_cell_color_diverging () =
  (* With diverging scale blue-white-red, midpoint=3.5:
     value 1.0 → blueish, value 6.0 → reddish *)
  let el = heat_map_view ~scale:div_scale sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let fills = get_rect_fills scene in
      let first_fill = List.hd fills in
      let expected_low = Color_scale.apply div_scale ~min:1.0 ~max:6.0 1.0 in
      let actual_color =
        match first_fill with
        | Paint.Solid c -> c
        | _ -> Alcotest.failf "expected solid fill"
      in
      Alcotest.(check bool)
        "first cell uses diverging color" true
        (Color.equal actual_color expected_low)
  | None -> Alcotest.fail "expected Draw element"

let test_row_labels_rendered () =
  let el = heat_map_view sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let texts = find_texts scene in
      let has_row0 = List.exists (String.equal "row0") texts in
      let has_row1 = List.exists (String.equal "row1") texts in
      Alcotest.(check bool) "row0 label" true has_row0;
      Alcotest.(check bool) "row1 label" true has_row1
  | None -> Alcotest.fail "expected Draw element"

let test_col_labels_rendered () =
  let el = heat_map_view sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let texts = find_texts scene in
      let has_col0 = List.exists (String.equal "col0") texts in
      let has_col1 = List.exists (String.equal "col1") texts in
      let has_col2 = List.exists (String.equal "col2") texts in
      Alcotest.(check bool) "col0 label" true has_col0;
      Alcotest.(check bool) "col1 label" true has_col1;
      Alcotest.(check bool) "col2 label" true has_col2
  | None -> Alcotest.fail "expected Draw element"

let test_hover_highlight () =
  (* Hovering cell (1, 2) = index 5, value 6.0 (max → red), lightened should differ *)
  let hover =
    Hover.{ index = 5; series = 0; cursor_x = 300.0; cursor_y = 200.0 }
  in
  let el_no = heat_map_view sample_data in
  let el_yes = heat_map_view ~hover sample_data in
  match (extract_draw el_no, extract_draw el_yes) with
  | Some (scene_no, _, _, _, _), Some (scene_yes, _, _, _, _) ->
      let fills_no = get_rect_fills scene_no in
      let fills_yes = get_rect_fills scene_yes in
      (* Index 5 is the last cell rect *)
      let c_no =
        match List.nth fills_no 5 with
        | Paint.Solid c -> c
        | _ -> Color.black
      in
      let c_yes =
        match List.nth fills_yes 5 with
        | Paint.Solid c -> c
        | _ -> Color.black
      in
      (* The hovered cell's color should differ from non-hovered *)
      Alcotest.(check bool) "hover changes color" false (Color.equal c_no c_yes)
  | _ -> Alcotest.fail "expected Draw elements"

let test_hit_map_rect_count () =
  (* With on_hover/on_leave, hit testing should work for all 6 cells *)
  let el =
    heat_map_view ~on_hover:(fun h -> Hovered h) ~on_leave:Left sample_data
  in
  match extract_draw el with
  | Some (_, Some on_move, _, _, _) ->
      (* The handler should be callable *)
      let _msg =
        on_move { x = 200.0; y = 150.0; client_x = 200.0; client_y = 150.0 }
      in
      ()
  | Some (_, None, _, _, _) -> Alcotest.fail "expected on_pointer_move handler"
  | None -> Alcotest.fail "expected Draw element"

let test_tooltip_shows_cell_value () =
  let hover =
    Hover.{ index = 0; series = 0; cursor_x = 100.0; cursor_y = 100.0 }
  in
  let el =
    heat_map_view ~hover
      ~format_tooltip:(fun d -> Printf.sprintf "R%d C%d: %.1f" d.r d.c d.v)
      sample_data
  in
  (* With tooltip, result is a Draw with merged scene nodes *)
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check bool) "has scene nodes" true (List.length scene >= 2)
  | _ -> Alcotest.fail "expected Draw with tooltip scene"

let () =
  Alcotest.run "Heat_map"
    [
      ( "heat_map",
        [
          Alcotest.test_case "empty_data" `Quick test_empty_data;
          Alcotest.test_case "produces_draw_element" `Quick
            test_produces_draw_element;
          Alcotest.test_case "cell_count" `Quick test_cell_count;
          Alcotest.test_case "cell_color_sequential" `Quick
            test_cell_color_sequential;
          Alcotest.test_case "cell_color_diverging" `Quick
            test_cell_color_diverging;
          Alcotest.test_case "row_labels_rendered" `Quick
            test_row_labels_rendered;
          Alcotest.test_case "col_labels_rendered" `Quick
            test_col_labels_rendered;
          Alcotest.test_case "hover_highlight" `Quick test_hover_highlight;
          Alcotest.test_case "hit_map_rect_count" `Quick test_hit_map_rect_count;
          Alcotest.test_case "tooltip_shows_cell_value" `Quick
            test_tooltip_shows_cell_value;
        ] );
    ]
