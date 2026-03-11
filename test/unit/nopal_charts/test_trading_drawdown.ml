open Nopal_charts
open Nopal_element
open Nopal_draw

type msg = Hovered of Hover.t | Left [@@warning "-37"]

(* --- sample data --- *)

(* Each point: (x, drawdown_pct) where drawdown_pct <= 0.0 *)
type point = { x : float; dd : float }

let sample_data =
  [
    { x = 1.0; dd = 0.0 };
    { x = 2.0; dd = -0.05 };
    { x = 3.0; dd = -0.15 };
    { x = 4.0; dd = -0.10 };
    { x = 5.0; dd = -0.02 };
  ]

let x_of p = p.x
let dd_of p = p.dd
let custom_fill = Color.rgb ~r:0.8 ~g:0.2 ~b:0.2

(* --- helpers --- *)

let drawdown_view ?fill_color ?on_hover ?on_leave ?hover ?format_tooltip
    ?domain_window data =
  Trading.Drawdown.view ~data ~x:x_of ~y:dd_of ~width:400.0 ~height:300.0
    ?fill_color ?on_hover ?on_leave ?hover ?format_tooltip ?domain_window ()

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

let count_paths (scene : Scene.t list) =
  List.fold_left
    (fun acc (node : Scene.t) ->
      match node with
      | Path _ -> acc + 1
      | _ -> acc)
    0 scene

let get_path_fills (scene : Scene.t list) =
  List.filter_map
    (fun (node : Scene.t) ->
      match node with
      | Path { fill; _ } -> Some fill
      | _ -> None)
    scene

(* --- tests --- *)

let test_empty_data () =
  let el =
    Trading.Drawdown.view ~data:[] ~x:x_of ~y:dd_of ~width:400.0 ~height:300.0
      ()
  in
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check int) "empty scene" 0 (List.length scene)
  | _ -> Alcotest.fail "expected Draw element for empty data"

let test_produces_draw_element () =
  let el = drawdown_view sample_data in
  match extract_draw el with
  | Some (_, _, _, w, h) ->
      Alcotest.(check (float 0.01)) "width" 400.0 w;
      Alcotest.(check (float 0.01)) "height" 300.0 h
  | None -> Alcotest.fail "expected Draw element"

let test_inverted_area () =
  (* Should produce at least one Path (the filled area from 0% baseline downward) *)
  let el = drawdown_view sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let n = count_paths scene in
      Alcotest.(check bool) "has area path" true (n >= 1)
  | None -> Alcotest.fail "expected Draw element"

let test_y_axis_range () =
  (* Y domain should be [min_drawdown, 0.0] = [-0.15, 0.0]
     Y axis text labels are rendered with anchor=End_anchor, so filter by
     that to separate from X axis labels. Check that Y tick values are <= 0. *)
  let el = drawdown_view sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* Y axis tick labels use End_anchor; X axis uses Middle *)
      let y_tick_values =
        List.filter_map
          (fun (node : Scene.t) ->
            match node with
            | Text { content; anchor = End_anchor; _ } -> (
                match float_of_string_opt content with
                | Some v -> Some v
                | None -> None)
            | _ -> None)
          scene
      in
      (* All Y axis numeric labels should be <= 0.0 *)
      let all_non_positive =
        List.for_all (fun v -> v <= 0.0 +. 1e-9) y_tick_values
      in
      Alcotest.(check bool) "all y tick values <= 0" true all_non_positive;
      (* There should be at least one Y tick label *)
      Alcotest.(check bool)
        "has y tick labels" true
        (List.length y_tick_values > 0)
  | None -> Alcotest.fail "expected Draw element"

let test_fill_color_applied () =
  let el = drawdown_view ~fill_color:custom_fill sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let fills = get_path_fills scene in
      (* The area fill should use the custom color (with alpha) *)
      let has_custom =
        List.exists
          (fun (p : Paint.t) ->
            match p with
            | Solid c ->
                Float.equal c.r custom_fill.r
                && Float.equal c.g custom_fill.g
                && Float.equal c.b custom_fill.b
            | _ -> false)
          fills
      in
      Alcotest.(check bool) "custom fill color applied" true has_custom
  | None -> Alcotest.fail "expected Draw element"

let test_domain_window_clips () =
  (* With a domain window [2.0, 4.0], only points with x in that range
     (plus buffer=1) should affect the chart *)
  let window = Domain_window.create ~x_min:2.0 ~x_max:4.0 in
  let el = drawdown_view ~domain_window:window sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      (* Should still produce a valid chart *)
      let n = count_paths scene in
      Alcotest.(check bool) "has area path after clipping" true (n >= 1)
  | None -> Alcotest.fail "expected Draw element"

let () =
  Alcotest.run "Trading_drawdown"
    [
      ( "trading_drawdown",
        [
          Alcotest.test_case "empty_data" `Quick test_empty_data;
          Alcotest.test_case "produces_draw_element" `Quick
            test_produces_draw_element;
          Alcotest.test_case "inverted_area" `Quick test_inverted_area;
          Alcotest.test_case "y_axis_range" `Quick test_y_axis_range;
          Alcotest.test_case "fill_color_applied" `Quick test_fill_color_applied;
          Alcotest.test_case "domain_window_clips" `Quick
            test_domain_window_clips;
        ] );
    ]
