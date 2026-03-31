module Sub = Kitchen_sink_app__Sub_data_table
module DT = Nopal_ui.Data_table

let sort_testable =
  Alcotest.testable
    (fun fmt (s : DT.sort) ->
      let dir =
        match s.direction with
        | DT.Ascending -> "Ascending"
        | DT.Descending -> "Descending"
      in
      Format.fprintf fmt "{ column = %S; direction = %s }" s.column dir)
    ( = )

let sort_option_testable = Alcotest.option sort_testable

(* --- sort toggle tests --- *)

let test_sort_new_column_starts_ascending () =
  let model, _ = Sub.init () in
  let model', _ = Sub.update model (Sort "name") in
  Alcotest.(check sort_option_testable)
    "sort by name ascending"
    (Some { DT.column = "name"; direction = Ascending })
    model'.sort

let test_sort_same_column_toggles_to_descending () =
  let model, _ = Sub.init () in
  let model', _ = Sub.update model (Sort "name") in
  let model'', _ = Sub.update model' (Sort "name") in
  Alcotest.(check sort_option_testable)
    "sort by name descending"
    (Some { DT.column = "name"; direction = Descending })
    model''.sort

let test_sort_descending_toggles_back_to_ascending () =
  let model, _ = Sub.init () in
  let m1, _ = Sub.update model (Sort "name") in
  let m2, _ = Sub.update m1 (Sort "name") in
  let m3, _ = Sub.update m2 (Sort "name") in
  Alcotest.(check sort_option_testable)
    "sort by name ascending again"
    (Some { DT.column = "name"; direction = Ascending })
    m3.sort

let test_sort_different_column_resets_to_ascending () =
  let model, _ = Sub.init () in
  let m1, _ = Sub.update model (Sort "name") in
  let m2, _ = Sub.update m1 (Sort "name") in
  (* m2 is descending on "name" *)
  let m3, _ = Sub.update m2 (Sort "age") in
  Alcotest.(check sort_option_testable)
    "sort by age ascending"
    (Some { DT.column = "age"; direction = Ascending })
    m3.sort

let test_sort_reorders_data () =
  let model, _ = Sub.init () in
  let model', _ = Sub.update model (Sort "age") in
  let names = List.map (fun (p : Sub.person) -> p.name) model'.data in
  Alcotest.(check (list string))
    "sorted by age ascending"
    [ "Bob"; "Dave"; "Alice"; "Eve"; "Carol" ]
    names

let test_sort_descending_reorders_data () =
  let model, _ = Sub.init () in
  let m1, _ = Sub.update model (Sort "age") in
  let m2, _ = Sub.update m1 (Sort "age") in
  let names = List.map (fun (p : Sub.person) -> p.name) m2.data in
  Alcotest.(check (list string))
    "sorted by age descending"
    [ "Carol"; "Eve"; "Alice"; "Dave"; "Bob" ]
    names

let () =
  Alcotest.run "kitchen_sink_data_table_section"
    [
      ( "sort toggle",
        [
          Alcotest.test_case "new column starts ascending" `Quick
            test_sort_new_column_starts_ascending;
          Alcotest.test_case "same column toggles to descending" `Quick
            test_sort_same_column_toggles_to_descending;
          Alcotest.test_case "descending toggles back to ascending" `Quick
            test_sort_descending_toggles_back_to_ascending;
          Alcotest.test_case "different column resets to ascending" `Quick
            test_sort_different_column_resets_to_ascending;
          Alcotest.test_case "sort reorders data ascending" `Quick
            test_sort_reorders_data;
          Alcotest.test_case "sort reorders data descending" `Quick
            test_sort_descending_reorders_data;
        ] );
    ]
