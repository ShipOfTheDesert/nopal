open Nopal_charts

let test_default_config () =
  let cfg = Axis.default_config in
  Alcotest.(check (option string)) "no label" None cfg.label;
  Alcotest.(check (option (float 0.001))) "no explicit min" None cfg.min;
  Alcotest.(check (option (float 0.001))) "no explicit max" None cfg.max;
  Alcotest.(check int) "tick_count = 5" 5 cfg.tick_count;
  Alcotest.(check string) "default format" "0." (cfg.format_tick 0.)

let test_compute_ticks_count () =
  let cfg = { Axis.default_config with tick_count = 4 } in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let n = List.length ticks in
  Alcotest.(check bool) "reasonable tick count" true (n >= 2 && n <= 10)

let test_compute_ticks_range () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let values = List.map (fun (t : Axis.tick) -> t.value) ticks in
  let min_v = List.fold_left Float.min Float.infinity values in
  let max_v = List.fold_left Float.max Float.neg_infinity values in
  Alcotest.(check bool) "min tick >= 0" true (min_v >= 0.0);
  Alcotest.(check bool) "max tick <= 100" true (max_v <= 100.0)

let test_compute_ticks_explicit_min_max () =
  let cfg = { Axis.default_config with min = Some 10.0; max = Some 50.0 } in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let values = List.map (fun (t : Axis.tick) -> t.value) ticks in
  let min_v = List.fold_left Float.min Float.infinity values in
  let max_v = List.fold_left Float.max Float.neg_infinity values in
  Alcotest.(check bool) "min tick >= 10" true (min_v >= 10.0);
  Alcotest.(check bool) "max tick <= 50" true (max_v <= 50.0)

let test_compute_ticks_format () =
  let fmt v = Printf.sprintf "%.1f%%" v in
  let cfg = { Axis.default_config with format_tick = fmt } in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  List.iter
    (fun (t : Axis.tick) ->
      Alcotest.(check bool)
        "label ends with %" true
        (String.length t.label > 0 && t.label.[String.length t.label - 1] = '%'))
    ticks

let test_compute_domain_auto () =
  let cfg = Axis.default_config in
  let lo, hi = Axis.compute_domain cfg ~data_min:3.0 ~data_max:97.0 in
  Alcotest.(check bool) "lo <= data_min" true (lo <= 3.0);
  Alcotest.(check bool) "hi >= data_max" true (hi >= 97.0)

let test_compute_domain_explicit () =
  let cfg = { Axis.default_config with min = Some 10.0; max = Some 90.0 } in
  let lo, hi = Axis.compute_domain cfg ~data_min:0.0 ~data_max:100.0 in
  Alcotest.(check (float 0.001)) "lo = 10" 10.0 lo;
  Alcotest.(check (float 0.001)) "hi = 90" 90.0 hi

let test_compute_domain_partial () =
  let cfg_min = { Axis.default_config with min = Some 5.0 } in
  let lo, hi = Axis.compute_domain cfg_min ~data_min:10.0 ~data_max:50.0 in
  Alcotest.(check (float 0.001)) "lo = 5" 5.0 lo;
  Alcotest.(check bool) "hi >= 50" true (hi >= 50.0);
  let cfg_max = { Axis.default_config with max = Some 80.0 } in
  let lo2, hi2 = Axis.compute_domain cfg_max ~data_min:10.0 ~data_max:50.0 in
  Alcotest.(check bool) "lo2 <= 10" true (lo2 <= 10.0);
  Alcotest.(check (float 0.001)) "hi2 = 80" 80.0 hi2

let test_render_x_produces_scenes () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(0.0, 400.0)
  in
  let scenes =
    Axis.render_x cfg ~ticks ~scale ~chart_x:50.0 ~chart_y:300.0
      ~chart_width:400.0
  in
  Alcotest.(check bool) "non-empty scenes" true (List.length scenes > 0)

let test_render_y_produces_scenes () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(300.0, 0.0)
  in
  let scenes =
    Axis.render_y cfg ~ticks ~scale ~chart_x:50.0 ~chart_y:0.0
      ~chart_height:300.0
  in
  Alcotest.(check bool) "non-empty scenes" true (List.length scenes > 0)

let rec has_text_with_content content scene =
  match (scene : Nopal_draw.Scene.t) with
  | Text { content = c; _ } -> String.equal c content
  | Group { children; _ } ->
      List.exists (has_text_with_content content) children
  | _ -> false

let test_render_x_tick_labels () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(0.0, 400.0)
  in
  let scenes =
    Axis.render_x cfg ~ticks ~scale ~chart_x:50.0 ~chart_y:300.0
      ~chart_width:400.0
  in
  List.iter
    (fun (t : Axis.tick) ->
      Alcotest.(check bool)
        ("x axis has label " ^ t.label)
        true
        (List.exists (has_text_with_content t.label) scenes))
    ticks

let test_render_y_tick_labels () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(300.0, 0.0)
  in
  let scenes =
    Axis.render_y cfg ~ticks ~scale ~chart_x:50.0 ~chart_y:0.0
      ~chart_height:300.0
  in
  List.iter
    (fun (t : Axis.tick) ->
      Alcotest.(check bool)
        ("y axis has label " ^ t.label)
        true
        (List.exists (has_text_with_content t.label) scenes))
    ticks

let test_large_axis_range () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.001 ~data_max:1000000.0 in
  let n = List.length ticks in
  (* Should produce a reasonable number of ticks without crashing *)
  Alcotest.(check bool) "reasonable tick count" true (n >= 2 && n <= 20);
  let values = List.map (fun (t : Axis.tick) -> t.value) ticks in
  let min_v = List.fold_left Float.min Float.infinity values in
  let max_v = List.fold_left Float.max Float.neg_infinity values in
  Alcotest.(check bool) "min tick covers lower bound" true (min_v <= 0.001);
  Alcotest.(check bool) "max tick covers upper bound" true (max_v >= 1000000.0)

let () =
  Alcotest.run "Axis"
    [
      ( "config",
        [ Alcotest.test_case "default_config" `Quick test_default_config ] );
      ( "compute_ticks",
        [
          Alcotest.test_case "count" `Quick test_compute_ticks_count;
          Alcotest.test_case "range" `Quick test_compute_ticks_range;
          Alcotest.test_case "explicit_min_max" `Quick
            test_compute_ticks_explicit_min_max;
          Alcotest.test_case "format" `Quick test_compute_ticks_format;
          Alcotest.test_case "large_axis_range" `Quick test_large_axis_range;
        ] );
      ( "compute_domain",
        [
          Alcotest.test_case "auto" `Quick test_compute_domain_auto;
          Alcotest.test_case "explicit" `Quick test_compute_domain_explicit;
          Alcotest.test_case "partial" `Quick test_compute_domain_partial;
        ] );
      ( "render",
        [
          Alcotest.test_case "x_produces_scenes" `Quick
            test_render_x_produces_scenes;
          Alcotest.test_case "y_produces_scenes" `Quick
            test_render_y_produces_scenes;
          Alcotest.test_case "x_tick_labels" `Quick test_render_x_tick_labels;
          Alcotest.test_case "y_tick_labels" `Quick test_render_y_tick_labels;
        ] );
    ]
