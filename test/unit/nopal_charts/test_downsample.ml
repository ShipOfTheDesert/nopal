open Nopal_charts

let x_of (x, _y) = x
let y_of (_x, y) = y

let pair_testable =
  Alcotest.testable
    (fun fmt (x, y) -> Format.fprintf fmt "(%.1f, %.1f)" x y)
    (fun (a1, b1) (a2, b2) -> Float.equal a1 a2 && Float.equal b1 b2)

let test_lttb_preserves_endpoints () =
  let data =
    [|
      (0.0, 1.0);
      (1.0, 3.0);
      (2.0, 2.0);
      (3.0, 5.0);
      (4.0, 4.0);
      (5.0, 6.0);
      (6.0, 1.0);
      (7.0, 3.0);
      (8.0, 2.0);
      (9.0, 4.0);
    |]
  in
  let result = Downsample.lttb ~x:x_of ~y:y_of ~data ~target:5 in
  Alcotest.(check pair_testable) "first preserved" data.(0) result.(0);
  Alcotest.(check pair_testable)
    "last preserved"
    data.(Array.length data - 1)
    result.(Array.length result - 1)

let test_lttb_no_reduction_needed () =
  let data = [| (0.0, 1.0); (1.0, 2.0); (2.0, 3.0) |] in
  let result = Downsample.lttb ~x:x_of ~y:y_of ~data ~target:5 in
  Alcotest.(check int)
    "length unchanged" (Array.length data) (Array.length result);
  Array.iteri
    (fun i d ->
      Alcotest.(check pair_testable)
        (Printf.sprintf "element %d" i)
        d result.(i))
    data

let test_lttb_reduces_to_target () =
  let data =
    Array.init 100 (fun i ->
        let x = Float.of_int i in
        (x, sin x))
  in
  let target = 20 in
  let result = Downsample.lttb ~x:x_of ~y:y_of ~data ~target in
  Alcotest.(check int)
    "output length equals target" target (Array.length result)

let test_lttb_preserves_peaks () =
  (* Flat data with a single prominent peak *)
  let data =
    Array.init 50 (fun i ->
        let x = Float.of_int i in
        let y = if i = 25 then 100.0 else 1.0 in
        (x, y))
  in
  let result = Downsample.lttb ~x:x_of ~y:y_of ~data ~target:10 in
  let has_peak =
    Array.exists (fun (_x, y) -> Float.abs (y -. 100.0) < 1e-6) result
  in
  Alcotest.(check bool) "peak retained" true has_peak

let test_lttb_preserves_valleys () =
  (* Flat data with a single prominent valley *)
  let data =
    Array.init 50 (fun i ->
        let x = Float.of_int i in
        let y = if i = 25 then -100.0 else 1.0 in
        (x, y))
  in
  let result = Downsample.lttb ~x:x_of ~y:y_of ~data ~target:10 in
  let has_valley =
    Array.exists (fun (_x, y) -> Float.abs (y -. (-100.0)) < 1e-6) result
  in
  Alcotest.(check bool) "valley retained" true has_valley

let test_should_downsample_below_threshold () =
  (* 100 points at 200px => 100 < 3 * 200 = 600 => false *)
  let result =
    Downsample.should_downsample ~data_length:100 ~pixel_width:200.0
  in
  Alcotest.(check bool) "below threshold" false result

let test_should_downsample_above_threshold () =
  (* 1000 points at 200px => 1000 > 3 * 200 = 600 => true *)
  let result =
    Downsample.should_downsample ~data_length:1000 ~pixel_width:200.0
  in
  Alcotest.(check bool) "above threshold" true result

let test_target_for_width () =
  let result = Downsample.target_for_width ~pixel_width:300.0 in
  Alcotest.(check int) "2x pixel width" 600 result

let () =
  Alcotest.run "Downsample"
    [
      ( "lttb",
        [
          Alcotest.test_case "preserves endpoints" `Quick
            test_lttb_preserves_endpoints;
          Alcotest.test_case "no reduction needed" `Quick
            test_lttb_no_reduction_needed;
          Alcotest.test_case "reduces to target" `Quick
            test_lttb_reduces_to_target;
          Alcotest.test_case "preserves peaks" `Quick test_lttb_preserves_peaks;
          Alcotest.test_case "preserves valleys" `Quick
            test_lttb_preserves_valleys;
        ] );
      ( "helpers",
        [
          Alcotest.test_case "should_downsample below" `Quick
            test_should_downsample_below_threshold;
          Alcotest.test_case "should_downsample above" `Quick
            test_should_downsample_above_threshold;
          Alcotest.test_case "target_for_width" `Quick test_target_for_width;
        ] );
    ]
