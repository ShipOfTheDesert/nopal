open Nopal_charts

(* Helper: extract x from a float *)
let x_of f = f

let test_nearest_empty () =
  let result = Snap.nearest_index ~x:x_of ~data:[] ~target:5.0 in
  Alcotest.(check (option int)) "empty list returns None" None result

let test_nearest_single () =
  let result = Snap.nearest_index ~x:x_of ~data:[ 3.0 ] ~target:5.0 in
  Alcotest.(check (option int)) "single element returns index 0" (Some 0) result

let test_nearest_exact () =
  let data = [ 1.0; 2.0; 3.0; 4.0; 5.0 ] in
  let result = Snap.nearest_index ~x:x_of ~data ~target:3.0 in
  Alcotest.(check (option int)) "exact match returns its index" (Some 2) result

let test_nearest_between () =
  let data = [ 1.0; 3.0; 5.0; 7.0; 9.0 ] in
  (* 4.0 is between 3.0 (idx 1) and 5.0 (idx 2); closer to 3.0 *)
  let result = Snap.nearest_index ~x:x_of ~data ~target:4.0 in
  Alcotest.(check (option int)) "snaps to nearest" (Some 1) result

let test_nearest_left_edge () =
  let data = [ 1.0; 3.0; 5.0; 7.0; 9.0 ] in
  let result = Snap.nearest_index ~x:x_of ~data ~target:(-10.0) in
  Alcotest.(check (option int)) "far left snaps to first" (Some 0) result

let test_nearest_right_edge () =
  let data = [ 1.0; 3.0; 5.0; 7.0; 9.0 ] in
  let result = Snap.nearest_index ~x:x_of ~data ~target:100.0 in
  Alcotest.(check (option int)) "far right snaps to last" (Some 4) result

let sorted_data = [| 1.0; 3.0; 5.0; 7.0; 9.0 |]

let test_nearest_sorted_matches () =
  let data_list = [ 1.0; 3.0; 5.0; 7.0; 9.0 ] in
  let targets = [ -1.0; 1.0; 2.0; 4.0; 5.0; 6.0; 9.0; 20.0 ] in
  List.iter
    (fun target ->
      let linear = Snap.nearest_index ~x:x_of ~data:data_list ~target in
      let sorted =
        Snap.nearest_index_sorted ~x:x_of ~data:sorted_data ~target
      in
      Alcotest.(check (option int))
        (Printf.sprintf "target=%.1f" target)
        linear sorted)
    targets

let () =
  Alcotest.run "Snap"
    [
      ( "nearest_index",
        [
          Alcotest.test_case "empty" `Quick test_nearest_empty;
          Alcotest.test_case "single" `Quick test_nearest_single;
          Alcotest.test_case "exact" `Quick test_nearest_exact;
          Alcotest.test_case "between" `Quick test_nearest_between;
          Alcotest.test_case "left edge" `Quick test_nearest_left_edge;
          Alcotest.test_case "right edge" `Quick test_nearest_right_edge;
        ] );
      ( "nearest_index_sorted",
        [
          Alcotest.test_case "matches linear" `Quick test_nearest_sorted_matches;
        ] );
    ]
