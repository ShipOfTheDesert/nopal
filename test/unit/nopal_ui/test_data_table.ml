open Nopal_test.Test_renderer
module DT = Nopal_ui.Data_table
module E = Nopal_element.Element

type msg = Sort of string

let msg_testable =
  Alcotest.testable
    (fun fmt (Sort key) -> Format.fprintf fmt "Sort %S" key)
    ( = )

(* --- test data --- *)

type person = { name : string; age : int }

let alice = { name = "Alice"; age = 30 }
let bob = { name = "Bob"; age = 25 }

let name_col =
  DT.column ~header:"Name" ~cell:(fun p -> E.text p.name) ~sort_key:"name" ()

let age_col =
  DT.column ~header:"Age"
    ~cell:(fun p -> E.text (string_of_int p.age))
    ~sort_key:"age" ()

let static_col = DT.column ~header:"Static" ~cell:(fun _p -> E.text "fixed") ()
let on_sort key = Sort key
let key_fn p = p.name

let make_config ?sort ?(rows = [ alice; bob ]) cols =
  DT.make ~columns:cols ~rows ~key:key_fn ~on_sort ?sort ~attrs:[] ()

(* --- helpers --- *)

let children_of = function
  | Element { children; _ } -> children
  | _ -> Alcotest.fail "expected Element with children"

let attrs_of = function
  | Element { attrs; _ } -> attrs
  | _ -> Alcotest.fail "expected Element with attrs"

(* --- ARIA role tests --- *)

let test_table_has_role_table () =
  let config = make_config [ name_col; age_col ] in
  let r = render (DT.view config) in
  let root = tree r in
  Alcotest.(check (option string))
    "role=table" (Some "table")
    (List.assoc_opt "role" (attrs_of root))

let test_header_row_has_role_row () =
  let config = make_config [ name_col; age_col ] in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | header_row :: _ ->
      Alcotest.(check (option string))
        "role=row" (Some "row")
        (List.assoc_opt "role" (attrs_of header_row))
  | [] -> Alcotest.fail "expected at least one child (header row)"

let test_header_cells_have_role_columnheader () =
  let config = make_config [ name_col; age_col ] in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | header_row :: _ ->
      let cells = children_of header_row in
      List.iter
        (fun cell ->
          Alcotest.(check (option string))
            "role=columnheader" (Some "columnheader")
            (List.assoc_opt "role" (attrs_of cell)))
        cells
  | [] -> Alcotest.fail "expected header row"

let test_data_rows_have_role_row () =
  let config = make_config [ name_col; age_col ] in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | _ :: data_rows ->
      List.iter
        (fun keyed_row ->
          (* Each data row is wrapped in Keyed *)
          match children_of keyed_row with
          | [ actual_row ] ->
              Alcotest.(check (option string))
                "role=row" (Some "row")
                (List.assoc_opt "role" (attrs_of actual_row))
          | _ -> Alcotest.fail "expected keyed to wrap one row")
        data_rows
  | [] -> Alcotest.fail "expected children"

let test_data_cells_have_role_cell () =
  let config = make_config [ name_col; age_col ] in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | _ :: data_rows ->
      List.iter
        (fun keyed_row ->
          match children_of keyed_row with
          | [ actual_row ] ->
              let cells = children_of actual_row in
              List.iter
                (fun cell ->
                  Alcotest.(check (option string))
                    "role=cell" (Some "cell")
                    (List.assoc_opt "role" (attrs_of cell)))
                cells
          | _ -> Alcotest.fail "expected keyed to wrap one row")
        data_rows
  | [] -> Alcotest.fail "expected children"

(* --- sort interaction tests --- *)

let test_sortable_header_click_dispatches_message () =
  let config = make_config [ name_col; age_col ] in
  let r = render (DT.view config) in
  let result = click (By_tag "button") r in
  Alcotest.(check (result unit Test_util.error_testable))
    "click ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "sort dispatched" [ Sort "name" ] (messages r)

let test_non_sortable_header_click_no_message () =
  let config = make_config [ static_col ] in
  let r = render (DT.view config) in
  (* Non-sortable header is a box, not a button — click should fail with no handler *)
  let result = click (By_attr ("role", "columnheader")) r in
  (match result with
  | Error (No_handler _) -> ()
  | Error (Not_found _) -> ()
  | Ok () -> ());
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

(* --- aria-sort tests --- *)

let test_ascending_sort_sets_aria_sort () =
  let sort = { DT.column = "name"; direction = Ascending } in
  let config = make_config ~sort [ name_col; age_col ] in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | header_row :: _ -> (
      let cells = children_of header_row in
      match cells with
      | first :: _ ->
          Alcotest.(check (option string))
            "aria-sort=ascending" (Some "ascending")
            (List.assoc_opt "aria-sort" (attrs_of first))
      | [] -> Alcotest.fail "expected header cells")
  | [] -> Alcotest.fail "expected header row"

let test_descending_sort_sets_aria_sort () =
  let sort = { DT.column = "name"; direction = Descending } in
  let config = make_config ~sort [ name_col; age_col ] in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | header_row :: _ -> (
      let cells = children_of header_row in
      match cells with
      | first :: _ ->
          Alcotest.(check (option string))
            "aria-sort=descending" (Some "descending")
            (List.assoc_opt "aria-sort" (attrs_of first))
      | [] -> Alcotest.fail "expected header cells")
  | [] -> Alcotest.fail "expected header row"

let test_non_sorted_columns_no_aria_sort () =
  let sort = { DT.column = "name"; direction = Ascending } in
  let config = make_config ~sort [ name_col; age_col ] in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | header_row :: _ -> (
      let cells = children_of header_row in
      match cells with
      | _ :: second :: _ ->
          Alcotest.(check (option string))
            "no aria-sort on age" None
            (List.assoc_opt "aria-sort" (attrs_of second))
      | _ -> Alcotest.fail "expected at least two header cells")
  | [] -> Alcotest.fail "expected header row"

let test_no_sort_config_no_aria_sort () =
  let config = make_config [ name_col; age_col ] in
  let r = render (DT.view config) in
  let headers = find_all (By_attr ("role", "columnheader")) (tree r) in
  List.iter
    (fun h ->
      Alcotest.(check (option string))
        "no aria-sort" None
        (List.assoc_opt "aria-sort" (attrs_of h)))
    headers

(* --- keyed rows --- *)

let test_rows_are_keyed () =
  let config = make_config [ name_col ] in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | _ :: data_rows ->
      let keys =
        List.map
          (fun row ->
            Alcotest.(check (option string))
              "tag is keyed" (Some "keyed")
              (match row with
              | Element { tag; _ } -> Some tag
              | _ -> None);
            List.assoc_opt "key" (attrs_of row))
          data_rows
      in
      Alcotest.(check (list (option string)))
        "keys match"
        [ Some "Alice"; Some "Bob" ]
        keys
  | [] -> Alcotest.fail "expected children"

(* --- empty rows --- *)

let test_empty_rows_renders_header_only () =
  let config = make_config ~rows:[] [ name_col; age_col ] in
  let r = render (DT.view config) in
  let root = tree r in
  let children = children_of root in
  Alcotest.(check int) "only header row" 1 (List.length children);
  match children with
  | [ header_row ] ->
      Alcotest.(check (option string))
        "role=row" (Some "row")
        (List.assoc_opt "role" (attrs_of header_row))
  | _ -> Alcotest.fail "expected exactly one child"

(* --- cell renderer --- *)

let test_cell_renderer_called_per_row () =
  let config = make_config [ name_col; age_col ] in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | _ :: data_rows ->
      let row_texts =
        List.map
          (fun keyed_row ->
            match children_of keyed_row with
            | [ actual_row ] ->
                let cells = children_of actual_row in
                List.map text_content cells
            | _ -> Alcotest.fail "expected keyed to wrap one row")
          data_rows
      in
      Alcotest.(check (list (list string)))
        "cell contents"
        [ [ "Alice"; "30" ]; [ "Bob"; "25" ] ]
        row_texts
  | [] -> Alcotest.fail "expected children"

(* --- config passthrough tests --- *)

let test_style_passed_to_container () =
  let s =
    {
      Nopal_style.Style.default with
      paint =
        {
          Nopal_style.Style.default_paint with
          background = Some (Nopal_style.Style.hex "#f00");
        };
    }
  in
  let config =
    DT.make ~columns:[ name_col ] ~rows:[ alice ] ~key:key_fn ~on_sort ~style:s
      ~attrs:[] ()
  in
  let r = render (DT.view config) in
  let root = tree r in
  Alcotest.(check (option string))
    "background passed through" (Some "#f00")
    (match style root with
    | Some { paint = { background = Some (Hex h); _ }; _ } -> Some h
    | _ -> None)

let test_interaction_passed_to_container () =
  let hover_style =
    {
      Nopal_style.Style.default with
      paint =
        {
          Nopal_style.Style.default_paint with
          background = Some (Nopal_style.Style.hex "#0f0");
        };
    }
  in
  let ix = { Nopal_style.Interaction.default with hover = Some hover_style } in
  let config =
    DT.make ~columns:[ name_col ] ~rows:[ alice ] ~key:key_fn ~on_sort
      ~interaction:ix ~attrs:[] ()
  in
  let r = render (DT.view config) in
  let root = tree r in
  Alcotest.(check bool) "has hover interaction" true (has_hover root)

let test_custom_attrs_on_container () =
  let config =
    DT.make ~columns:[ name_col ] ~rows:[ alice ] ~key:key_fn ~on_sort
      ~attrs:[ ("data-testid", "my-table"); ("aria-label", "People") ]
      ()
  in
  let r = render (DT.view config) in
  let root = tree r in
  let a = attrs_of root in
  Alcotest.(check (option string))
    "data-testid present" (Some "my-table")
    (List.assoc_opt "data-testid" a);
  Alcotest.(check (option string))
    "aria-label present" (Some "People")
    (List.assoc_opt "aria-label" a)

(* --- inner style passthrough tests --- *)

let red_bg =
  {
    Nopal_style.Style.default with
    paint =
      {
        Nopal_style.Style.default_paint with
        background = Some (Nopal_style.Style.hex "#f00");
      };
  }

let blue_bg =
  {
    Nopal_style.Style.default with
    paint =
      {
        Nopal_style.Style.default_paint with
        background = Some (Nopal_style.Style.hex "#00f");
      };
  }

let green_bg =
  {
    Nopal_style.Style.default with
    paint =
      {
        Nopal_style.Style.default_paint with
        background = Some (Nopal_style.Style.hex "#0f0");
      };
  }

let has_bg hex node =
  match style node with
  | Some { paint = { background = Some (Hex h); _ }; _ } -> String.equal h hex
  | _ -> false

let test_header_style_applied_to_header_cells () =
  let config =
    DT.make ~columns:[ name_col; age_col ] ~rows:[ alice ] ~key:key_fn ~on_sort
      ~header_style:red_bg ~attrs:[] ()
  in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | header_row :: _ ->
      List.iter
        (fun cell ->
          Alcotest.(check bool)
            "header cell has red bg" true (has_bg "#f00" cell))
        (children_of header_row)
  | [] -> Alcotest.fail "expected header row"

let test_cell_style_applied_to_data_cells () =
  let config =
    DT.make ~columns:[ name_col ] ~rows:[ alice ] ~key:key_fn ~on_sort
      ~cell_style:blue_bg ~attrs:[] ()
  in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | _ :: data_rows ->
      List.iter
        (fun keyed_row ->
          match children_of keyed_row with
          | [ actual_row ] ->
              List.iter
                (fun cell ->
                  Alcotest.(check bool)
                    "data cell has blue bg" true (has_bg "#00f" cell))
                (children_of actual_row)
          | _ -> Alcotest.fail "expected keyed to wrap one row")
        data_rows
  | [] -> Alcotest.fail "expected children"

let test_row_style_applied_to_data_rows () =
  let config =
    DT.make ~columns:[ name_col ] ~rows:[ alice ] ~key:key_fn ~on_sort
      ~row_style:green_bg ~attrs:[] ()
  in
  let r = render (DT.view config) in
  let root = tree r in
  match children_of root with
  | _ :: data_rows ->
      List.iter
        (fun keyed_row ->
          match children_of keyed_row with
          | [ actual_row ] ->
              Alcotest.(check bool)
                "data row has green bg" true (has_bg "#0f0" actual_row)
          | _ -> Alcotest.fail "expected keyed to wrap one row")
        data_rows
  | [] -> Alcotest.fail "expected children"

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_ui_data_table"
    [
      ( "aria roles",
        [
          Alcotest.test_case "table has role=table" `Quick
            test_table_has_role_table;
          Alcotest.test_case "header row has role=row" `Quick
            test_header_row_has_role_row;
          Alcotest.test_case "header cells have role=columnheader" `Quick
            test_header_cells_have_role_columnheader;
          Alcotest.test_case "data rows have role=row" `Quick
            test_data_rows_have_role_row;
          Alcotest.test_case "data cells have role=cell" `Quick
            test_data_cells_have_role_cell;
        ] );
      ( "sort interaction",
        [
          Alcotest.test_case "sortable header click dispatches" `Quick
            test_sortable_header_click_dispatches_message;
          Alcotest.test_case "non-sortable header no message" `Quick
            test_non_sortable_header_click_no_message;
        ] );
      ( "aria-sort",
        [
          Alcotest.test_case "ascending sets aria-sort" `Quick
            test_ascending_sort_sets_aria_sort;
          Alcotest.test_case "descending sets aria-sort" `Quick
            test_descending_sort_sets_aria_sort;
          Alcotest.test_case "non-sorted columns no aria-sort" `Quick
            test_non_sorted_columns_no_aria_sort;
          Alcotest.test_case "no sort config no aria-sort" `Quick
            test_no_sort_config_no_aria_sort;
        ] );
      ( "keyed rows",
        [ Alcotest.test_case "rows are keyed" `Quick test_rows_are_keyed ] );
      ( "empty rows",
        [
          Alcotest.test_case "empty rows renders header only" `Quick
            test_empty_rows_renders_header_only;
        ] );
      ( "cell rendering",
        [
          Alcotest.test_case "cell renderer called per row" `Quick
            test_cell_renderer_called_per_row;
        ] );
      ( "config passthrough",
        [
          Alcotest.test_case "style passed to container" `Quick
            test_style_passed_to_container;
          Alcotest.test_case "interaction passed to container" `Quick
            test_interaction_passed_to_container;
          Alcotest.test_case "custom attrs on container" `Quick
            test_custom_attrs_on_container;
        ] );
      ( "inner styles",
        [
          Alcotest.test_case "header_style applied to header cells" `Quick
            test_header_style_applied_to_header_cells;
          Alcotest.test_case "cell_style applied to data cells" `Quick
            test_cell_style_applied_to_data_cells;
          Alcotest.test_case "row_style applied to data rows" `Quick
            test_row_style_applied_to_data_rows;
        ] );
    ]
