open Nopal_charts

(* Helper: extract x from a float *)
let x_of f = f

(* Sample data: points at x = 0, 1, 2, ..., 9 *)
let data = [ 0.0; 1.0; 2.0; 3.0; 4.0; 5.0; 6.0; 7.0; 8.0; 9.0 ]
let sorted_data = Array.of_list data

let test_clip_all_visible () =
  let window = Domain_window.create ~x_min:0.0 ~x_max:9.0 in
  let result = Viewport.clip ~x:x_of ~data ~window ~buffer:0 in
  Alcotest.(check (list (float 0.0))) "all points returned" data result

let test_clip_none_visible () =
  let window = Domain_window.create ~x_min:20.0 ~x_max:30.0 in
  let result = Viewport.clip ~x:x_of ~data ~window ~buffer:0 in
  Alcotest.(check (list (float 0.0))) "no points returned" [] result

let test_clip_partial () =
  let window = Domain_window.create ~x_min:3.0 ~x_max:6.0 in
  let result = Viewport.clip ~x:x_of ~data ~window ~buffer:0 in
  Alcotest.(check (list (float 0.0)))
    "only points within window" [ 3.0; 4.0; 5.0; 6.0 ] result

let test_clip_buffer_one () =
  let window = Domain_window.create ~x_min:3.0 ~x_max:6.0 in
  let result = Viewport.clip ~x:x_of ~data ~window ~buffer:1 in
  (* buffer=1 includes one point beyond each edge: 2.0 and 7.0 *)
  Alcotest.(check (list (float 0.0)))
    "buffer includes adjacent points"
    [ 2.0; 3.0; 4.0; 5.0; 6.0; 7.0 ]
    result

let test_clip_buffer_zero () =
  let window = Domain_window.create ~x_min:3.0 ~x_max:6.0 in
  let result = Viewport.clip ~x:x_of ~data ~window ~buffer:0 in
  Alcotest.(check (list (float 0.0)))
    "buffer=0 no extra points" [ 3.0; 4.0; 5.0; 6.0 ] result

let test_clip_preserves_order () =
  let window = Domain_window.create ~x_min:2.0 ~x_max:7.0 in
  let result = Viewport.clip ~x:x_of ~data ~window ~buffer:1 in
  (* Should be in original list order *)
  let expected = [ 1.0; 2.0; 3.0; 4.0; 5.0; 6.0; 7.0; 8.0 ] in
  Alcotest.(check (list (float 0.0))) "order preserved" expected result

let test_clip_sorted_matches_clip () =
  let window = Domain_window.create ~x_min:3.0 ~x_max:6.0 in
  let clip_result = Viewport.clip ~x:x_of ~data ~window ~buffer:1 in
  let sorted_result =
    Viewport.clip_sorted ~x:x_of ~data:sorted_data ~window ~buffer:1
    |> Array.to_list
  in
  Alcotest.(check (list (float 0.0)))
    "clip_sorted matches clip" clip_result sorted_result

let test_clip_sorted_empty () =
  let window = Domain_window.create ~x_min:0.0 ~x_max:10.0 in
  let result = Viewport.clip_sorted ~x:x_of ~data:[||] ~window ~buffer:0 in
  Alcotest.(check int) "empty array" 0 (Array.length result)

let test_clip_edge_inclusive () =
  let window = Domain_window.create ~x_min:3.0 ~x_max:7.0 in
  let result = Viewport.clip ~x:x_of ~data ~window ~buffer:0 in
  (* Points exactly at 3.0 and 7.0 should be included *)
  Alcotest.(check (list (float 0.0)))
    "edge points included"
    [ 3.0; 4.0; 5.0; 6.0; 7.0 ]
    result

let () =
  Alcotest.run "Viewport"
    [
      ( "clip",
        [
          Alcotest.test_case "all visible" `Quick test_clip_all_visible;
          Alcotest.test_case "none visible" `Quick test_clip_none_visible;
          Alcotest.test_case "partial" `Quick test_clip_partial;
          Alcotest.test_case "buffer one" `Quick test_clip_buffer_one;
          Alcotest.test_case "buffer zero" `Quick test_clip_buffer_zero;
          Alcotest.test_case "preserves order" `Quick test_clip_preserves_order;
          Alcotest.test_case "edge inclusive" `Quick test_clip_edge_inclusive;
        ] );
      ( "clip_sorted",
        [
          Alcotest.test_case "matches clip" `Quick test_clip_sorted_matches_clip;
          Alcotest.test_case "empty" `Quick test_clip_sorted_empty;
        ] );
    ]
