open Jsfb
open Nopal_test.Test_renderer

let test_create_1000 () =
  let model, r = run_app ~init ~update ~view [ Create_1000 ] in
  Alcotest.(check int) "model has 1000 rows" 1000 (List.length model.rows);
  let t = tree r in
  let rows = find_all (By_tag "row") t in
  Alcotest.(check int) "view has 1000 rows" 1000 (List.length rows)

let test_replace_1000 () =
  let model, _r = run_app ~init ~update ~view [ Create_1000; Replace_1000 ] in
  Alcotest.(check int) "model has 1000 rows" 1000 (List.length model.rows);
  (* After replace, all IDs should be >= 1001 since first batch used 1-1000 *)
  let min_id =
    List.fold_left (fun acc (r : row) -> min acc r.id) max_int model.rows
  in
  Alcotest.(check bool) "all IDs differ from original" true (min_id > 1000)

let test_partial_update () =
  let model, _r =
    run_app ~init ~update ~view [ Create_1000; Update_every_10th ]
  in
  Alcotest.(check int) "still 1000 rows" 1000 (List.length model.rows);
  (* Every 10th row (0-indexed: 0, 10, 20, ...) should have " !!!" appended
     per canonical jsfb spec: for (i = 0; i < len; i += 10) *)
  let first_row = List.nth model.rows 0 in
  let has_suffix =
    let len = String.length first_row.label in
    len >= 4 && String.sub first_row.label (len - 4) 4 = " !!!"
  in
  Alcotest.(check bool) "first row label updated" true has_suffix;
  (* Verify a non-10th row was NOT updated *)
  let second_row = List.nth model.rows 1 in
  let second_has_suffix =
    let len = String.length second_row.label in
    len >= 4 && String.sub second_row.label (len - 4) 4 = " !!!"
  in
  Alcotest.(check bool) "second row label not updated" false second_has_suffix

let test_select_row () =
  let model, _r = run_app ~init ~update ~view [ Create_1000; Select 1 ] in
  Alcotest.(check int) "1000 rows" 1000 (List.length model.rows);
  Alcotest.(check (option int)) "selected row" (Some 1) model.selected

let test_swap_rows () =
  let model, _r = run_app ~init ~update ~view [ Create_1000; Swap_rows ] in
  Alcotest.(check int) "1000 rows" 1000 (List.length model.rows);
  (* After swap, row at position 1 should have the ID that was at 998 *)
  let row_1 = List.nth model.rows 1 in
  let row_998 = List.nth model.rows 998 in
  Alcotest.(check bool) "rows swapped" true (row_1.id > row_998.id)

let test_remove_row () =
  let model, _r = run_app ~init ~update ~view [ Create_1000; Remove 1 ] in
  Alcotest.(check int) "999 rows remain" 999 (List.length model.rows);
  let ids = List.map (fun (r : row) -> r.id) model.rows in
  Alcotest.(check bool) "removed ID absent" true (not (List.mem 1 ids))

let test_create_10000 () =
  let model, r = run_app ~init ~update ~view [ Create_10000 ] in
  Alcotest.(check int) "model has 10000 rows" 10000 (List.length model.rows);
  let t = tree r in
  let rows = find_all (By_tag "row") t in
  Alcotest.(check int) "view has 10000 rows" 10000 (List.length rows)

let test_append_1000 () =
  let model, _r = run_app ~init ~update ~view [ Create_1000; Append_1000 ] in
  Alcotest.(check int) "2000 total rows" 2000 (List.length model.rows);
  (* First row should be preserved from original batch *)
  let first_row = List.hd model.rows in
  Alcotest.(check int) "first row ID preserved" 1 first_row.id

let test_clear () =
  let model, r = run_app ~init ~update ~view [ Create_1000; Clear ] in
  Alcotest.(check int) "no rows" 0 (List.length model.rows);
  (* next_id must have advanced past the created rows *)
  Alcotest.(check bool) "next_id advanced" true (model.next_id > 1);
  let t = tree r in
  let rows = find_all (By_tag "row") t in
  Alcotest.(check int) "view has no rows" 0 (List.length rows)

let () =
  Alcotest.run "jsfb"
    [
      ( "operations",
        [
          Alcotest.test_case "create 1000" `Quick test_create_1000;
          Alcotest.test_case "replace 1000" `Quick test_replace_1000;
          Alcotest.test_case "partial update" `Quick test_partial_update;
          Alcotest.test_case "select row" `Quick test_select_row;
          Alcotest.test_case "swap rows" `Quick test_swap_rows;
          Alcotest.test_case "remove row" `Quick test_remove_row;
          Alcotest.test_case "create 10000" `Quick test_create_10000;
          Alcotest.test_case "append 1000" `Quick test_append_1000;
          Alcotest.test_case "clear" `Quick test_clear;
        ] );
    ]
