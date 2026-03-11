open Nopal_charts

let dw_testable =
  Alcotest.testable
    (fun fmt (w : Domain_window.t) ->
      Format.fprintf fmt "{ x_min=%.3f; x_max=%.3f }" w.x_min w.x_max)
    Domain_window.equal

let approx_dw_equal (a : Domain_window.t) (b : Domain_window.t) =
  Float.abs (a.x_min -. b.x_min) < 1e-9 && Float.abs (a.x_max -. b.x_max) < 1e-9

let dw_approx_testable =
  Alcotest.testable
    (fun fmt (w : Domain_window.t) ->
      Format.fprintf fmt "{ x_min=%.6f; x_max=%.6f }" w.x_min w.x_max)
    approx_dw_equal

let test_create () =
  let w = Domain_window.create ~x_min:10.0 ~x_max:20.0 in
  Alcotest.(check (float 0.0)) "x_min" 10.0 w.x_min;
  Alcotest.(check (float 0.0)) "x_max" 20.0 w.x_max

let test_equal_same () =
  let a = Domain_window.create ~x_min:5.0 ~x_max:15.0 in
  let b = Domain_window.create ~x_min:5.0 ~x_max:15.0 in
  Alcotest.check dw_testable "same windows are equal" a b

let test_equal_different () =
  let a = Domain_window.create ~x_min:5.0 ~x_max:15.0 in
  let b = Domain_window.create ~x_min:5.0 ~x_max:20.0 in
  Alcotest.(check bool)
    "different windows not equal" false (Domain_window.equal a b)

let test_width () =
  let w = Domain_window.create ~x_min:10.0 ~x_max:30.0 in
  Alcotest.(check (float 0.0))
    "width is x_max - x_min" 20.0 (Domain_window.width w)

let test_pan_positive () =
  let w = Domain_window.create ~x_min:10.0 ~x_max:20.0 in
  let panned = Domain_window.pan w ~delta:5.0 in
  let expected = Domain_window.create ~x_min:15.0 ~x_max:25.0 in
  Alcotest.check dw_testable "pan positive shifts right" expected panned

let test_pan_negative () =
  let w = Domain_window.create ~x_min:10.0 ~x_max:20.0 in
  let panned = Domain_window.pan w ~delta:(-3.0) in
  let expected = Domain_window.create ~x_min:7.0 ~x_max:17.0 in
  Alcotest.check dw_testable "pan negative shifts left" expected panned

let test_zoom_in () =
  let w = Domain_window.create ~x_min:0.0 ~x_max:100.0 in
  let zoomed = Domain_window.zoom w ~center:50.0 ~factor:0.5 in
  Alcotest.(check (float 0.0))
    "zoom in width halved" 50.0
    (Domain_window.width zoomed)

let test_zoom_out () =
  let w = Domain_window.create ~x_min:0.0 ~x_max:100.0 in
  let zoomed = Domain_window.zoom w ~center:50.0 ~factor:2.0 in
  Alcotest.(check (float 0.0))
    "zoom out width doubled" 200.0
    (Domain_window.width zoomed)

let test_zoom_center_preserved () =
  let w = Domain_window.create ~x_min:0.0 ~x_max:100.0 in
  let zoomed = Domain_window.zoom w ~center:25.0 ~factor:0.5 in
  (* center=25.0 is at 25% of the window.
     New width = 50.0. Center stays at 25.0.
     x_min = 25.0 - 0.25 * 50.0 = 12.5
     x_max = 25.0 + 0.75 * 50.0 = 62.5 *)
  let expected = Domain_window.create ~x_min:12.5 ~x_max:62.5 in
  Alcotest.check dw_approx_testable "center preserved after zoom" expected
    zoomed

let test_clamp_within_bounds () =
  let w = Domain_window.create ~x_min:10.0 ~x_max:20.0 in
  let clamped = Domain_window.clamp ~data_min:0.0 ~data_max:100.0 w in
  Alcotest.check dw_testable "within bounds unchanged" w clamped

let test_clamp_past_left () =
  let w = Domain_window.create ~x_min:(-5.0) ~x_max:5.0 in
  let clamped = Domain_window.clamp ~data_min:0.0 ~data_max:100.0 w in
  let expected = Domain_window.create ~x_min:0.0 ~x_max:10.0 in
  Alcotest.check dw_testable "shifted to data_min" expected clamped

let test_clamp_past_right () =
  let w = Domain_window.create ~x_min:95.0 ~x_max:105.0 in
  let clamped = Domain_window.clamp ~data_min:0.0 ~data_max:100.0 w in
  let expected = Domain_window.create ~x_min:90.0 ~x_max:100.0 in
  Alcotest.check dw_testable "shifted to data_max" expected clamped

let test_clamp_wider_than_data () =
  let w = Domain_window.create ~x_min:(-50.0) ~x_max:150.0 in
  let clamped = Domain_window.clamp ~data_min:0.0 ~data_max:100.0 w in
  let expected = Domain_window.create ~x_min:0.0 ~x_max:100.0 in
  Alcotest.check dw_testable "snapped to data range" expected clamped

let () =
  Alcotest.run "Domain_window"
    [
      ("create", [ Alcotest.test_case "create" `Quick test_create ]);
      ( "equal",
        [
          Alcotest.test_case "same" `Quick test_equal_same;
          Alcotest.test_case "different" `Quick test_equal_different;
        ] );
      ("width", [ Alcotest.test_case "width" `Quick test_width ]);
      ( "pan",
        [
          Alcotest.test_case "positive" `Quick test_pan_positive;
          Alcotest.test_case "negative" `Quick test_pan_negative;
        ] );
      ( "zoom",
        [
          Alcotest.test_case "in" `Quick test_zoom_in;
          Alcotest.test_case "out" `Quick test_zoom_out;
          Alcotest.test_case "center preserved" `Quick
            test_zoom_center_preserved;
        ] );
      ( "clamp",
        [
          Alcotest.test_case "within bounds" `Quick test_clamp_within_bounds;
          Alcotest.test_case "past left" `Quick test_clamp_past_left;
          Alcotest.test_case "past right" `Quick test_clamp_past_right;
          Alcotest.test_case "wider than data" `Quick test_clamp_wider_than_data;
        ] );
    ]
