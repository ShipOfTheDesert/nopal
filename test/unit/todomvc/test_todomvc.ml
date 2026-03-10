open Todomvc
open Test_helpers

(* -- Test helpers --------------------------------------------------------- *)

(** Initialize a model with noop storage and default router. *)
let init_model () =
  let router = make_router () in
  let model, _cmd = init noop_storage router () in
  model

(** Apply a sequence of messages to a model, returning the final model. *)
let apply_msgs storage model msgs =
  List.fold_left
    (fun (m, _) msg -> update storage m msg)
    (model, Nopal_mvu.Cmd.none)
    msgs
  |> fst

(* -- Alcotest testables -------------------------------------------------- *)

let filter_to_string = function
  | All -> "All"
  | Active -> "Active"
  | Completed -> "Completed"

let filter_equal a b =
  match (a, b) with
  | All, All -> true
  | Active, Active -> true
  | Completed, Completed -> true
  | All, _
  | Active, _
  | Completed, _ ->
      false

let filter_testable =
  Alcotest.testable (Fmt.of_to_string filter_to_string) filter_equal

let route_to_string = function
  | All_route -> "All_route"
  | Active_route -> "Active_route"
  | Completed_route -> "Completed_route"

let route_equal a b =
  match (a, b) with
  | All_route, All_route -> true
  | Active_route, Active_route -> true
  | Completed_route, Completed_route -> true
  | All_route, _
  | Active_route, _
  | Completed_route, _ ->
      false

let route_testable =
  Alcotest.testable (Fmt.of_to_string route_to_string) route_equal

(* -- Tests ---------------------------------------------------------------- *)

let test_init_empty () =
  let model = init_model () in
  Alcotest.(check (list pass)) "empty todos" [] model.todos;
  Alcotest.check filter_testable "filter is All" All model.filter;
  Alcotest.(check string) "input is empty" "" model.input;
  Alcotest.(check bool) "editing is None" true (Option.is_none model.editing);
  Alcotest.(check int) "next_id is 1" 1 model.next_id

let test_init_loads_from_storage () =
  let existing =
    [
      { id = 5; title = "Existing"; completed = false };
      { id = 3; title = "Old"; completed = true };
    ]
  in
  let storage = preloaded_storage existing in
  let router = make_router () in
  let model, _cmd = init storage router () in
  Alcotest.(check int) "has 2 todos" 2 (List.length model.todos);
  Alcotest.(check int) "next_id is max+1" 6 model.next_id

let test_add_todo () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model [ Input_changed "Buy milk"; Add_todo ]
  in
  Alcotest.(check int) "has 1 todo" 1 (List.length model.todos);
  let todo = List.hd model.todos in
  Alcotest.(check string) "title" "Buy milk" todo.title;
  Alcotest.(check bool) "not completed" false todo.completed;
  Alcotest.(check string) "input cleared" "" model.input;
  Alcotest.(check int) "next_id incremented" 2 model.next_id

let test_add_todo_trims_whitespace () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model [ Input_changed "  Buy milk  "; Add_todo ]
  in
  Alcotest.(check int) "has 1 todo" 1 (List.length model.todos);
  let todo = List.hd model.todos in
  Alcotest.(check string) "title trimmed" "Buy milk" todo.title

let test_add_todo_empty_ignored () =
  let model = init_model () in
  let model = apply_msgs noop_storage model [ Input_changed ""; Add_todo ] in
  Alcotest.(check int) "no todos" 0 (List.length model.todos);
  let model2 =
    apply_msgs noop_storage model [ Input_changed "   "; Add_todo ]
  in
  Alcotest.(check int) "still no todos" 0 (List.length model2.todos)

let test_toggle () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model [ Input_changed "Task"; Add_todo; Toggle 1 ]
  in
  let todo = List.hd model.todos in
  Alcotest.(check bool) "completed" true todo.completed

let test_toggle_all_to_completed () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model
      [ Input_changed "A"; Add_todo; Input_changed "B"; Add_todo; Toggle_all ]
  in
  Alcotest.(check bool)
    "all completed" true
    (List.for_all (fun t -> t.completed) model.todos)

let test_toggle_all_to_active () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model
      [
        Input_changed "A";
        Add_todo;
        Input_changed "B";
        Add_todo;
        Toggle_all;
        Toggle_all;
      ]
  in
  Alcotest.(check bool)
    "all active" true
    (List.for_all (fun t -> not t.completed) model.todos)

let test_delete () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model [ Input_changed "Task"; Add_todo; Delete 1 ]
  in
  Alcotest.(check int) "no todos" 0 (List.length model.todos)

let test_start_editing () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model
      [ Input_changed "Task"; Add_todo; Start_editing 1 ]
  in
  Alcotest.(check bool) "editing is Some" true (Option.is_some model.editing);
  let editing = Option.get model.editing in
  Alcotest.(check int) "editing id" 1 editing.id;
  Alcotest.(check string) "editing text" "Task" editing.text

let test_edit_changed () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model
      [
        Input_changed "Task"; Add_todo; Start_editing 1; Edit_changed "New text";
      ]
  in
  let editing = Option.get model.editing in
  Alcotest.(check string) "editing text updated" "New text" editing.text

let test_submit_edit () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model
      [
        Input_changed "Task";
        Add_todo;
        Start_editing 1;
        Edit_changed "Updated";
        Submit_edit;
      ]
  in
  Alcotest.(check bool) "editing is None" true (Option.is_none model.editing);
  let todo = List.hd model.todos in
  Alcotest.(check string) "title updated" "Updated" todo.title

let test_submit_edit_empty_deletes () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model
      [
        Input_changed "Task";
        Add_todo;
        Start_editing 1;
        Edit_changed "   ";
        Submit_edit;
      ]
  in
  Alcotest.(check bool) "editing is None" true (Option.is_none model.editing);
  Alcotest.(check int) "todo deleted" 0 (List.length model.todos)

let test_cancel_edit () =
  let model = init_model () in
  (* Cancel_edit sets cancelled flag and restores original text;
     the subsequent Submit_edit from blur clears editing. *)
  let model =
    apply_msgs noop_storage model
      [
        Input_changed "Task";
        Add_todo;
        Start_editing 1;
        Edit_changed "Changed";
        Cancel_edit;
        Submit_edit;
      ]
  in
  Alcotest.(check bool) "editing is None" true (Option.is_none model.editing);
  let todo = List.hd model.todos in
  Alcotest.(check string) "title unchanged" "Task" todo.title

let test_clear_completed () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model
      [
        Input_changed "Done";
        Add_todo;
        Toggle 1;
        Input_changed "Active";
        Add_todo;
        Clear_completed;
      ]
  in
  Alcotest.(check int) "1 todo left" 1 (List.length model.todos);
  let todo = List.hd model.todos in
  Alcotest.(check string) "active remains" "Active" todo.title

let test_filter_active () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model
      [
        Input_changed "Done";
        Add_todo;
        Toggle 1;
        Input_changed "Active";
        Add_todo;
        Route_changed Active_route;
      ]
  in
  Alcotest.check filter_testable "filter is Active" Active model.filter;
  let visible = List.filter (fun t -> not t.completed) model.todos in
  Alcotest.(check int) "1 visible" 1 (List.length visible)

let test_filter_completed () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model
      [
        Input_changed "Done";
        Add_todo;
        Toggle 1;
        Input_changed "Active";
        Add_todo;
        Route_changed Completed_route;
      ]
  in
  Alcotest.check filter_testable "filter is Completed" Completed model.filter;
  let visible = List.filter (fun t -> t.completed) model.todos in
  Alcotest.(check int) "1 visible" 1 (List.length visible)

let test_active_count () =
  let model = init_model () in
  let model =
    apply_msgs noop_storage model
      [
        Input_changed "A";
        Add_todo;
        Input_changed "B";
        Add_todo;
        Input_changed "C";
        Add_todo;
        Toggle 1;
      ]
  in
  let active_count =
    List.length (List.filter (fun t -> not t.completed) model.todos)
  in
  Alcotest.(check int) "2 active" 2 active_count

let test_navigate_to () =
  let model = init_model () in
  let model', cmd = update noop_storage model (Navigate_to Active_route) in
  Alcotest.check filter_testable "filter is Active" Active model'.filter;
  (* Navigate_to returns a Cmd that pushes the route — not Cmd.none *)
  Alcotest.(check bool)
    "returns navigation command" true
    (cmd <> Nopal_mvu.Cmd.none)

let test_route_changed () =
  let model = init_model () in
  let model = apply_msgs noop_storage model [ Route_changed Active_route ] in
  Alcotest.check filter_testable "filter is Active" Active model.filter

let test_parse_routes () =
  Alcotest.check
    (Alcotest.option route_testable)
    "/ -> All_route" (Some All_route) (parse "/");
  Alcotest.check
    (Alcotest.option route_testable)
    "empty -> All_route" (Some All_route) (parse "");
  Alcotest.check
    (Alcotest.option route_testable)
    "/active -> Active_route" (Some Active_route) (parse "/active");
  Alcotest.check
    (Alcotest.option route_testable)
    "/completed -> Completed_route" (Some Completed_route) (parse "/completed");
  Alcotest.check
    (Alcotest.option route_testable)
    "/unknown -> None" None (parse "/unknown")

let test_to_path () =
  Alcotest.(check string) "All_route -> /" "/" (to_path All_route);
  Alcotest.(check string)
    "Active_route -> /active" "/active" (to_path Active_route);
  Alcotest.(check string)
    "Completed_route -> /completed" "/completed" (to_path Completed_route);
  (* Roundtrip *)
  List.iter
    (fun route ->
      let path = to_path route in
      Alcotest.check
        (Alcotest.option route_testable)
        ("roundtrip " ^ route_to_string route)
        (Some route) (parse path))
    [ All_route; Active_route; Completed_route ]

let test_save_on_mutation () =
  let storage, saves = tracking_storage () in
  let router = make_router () in
  let model, _cmd = init storage router () in
  (* Add a todo — should save *)
  let model, _cmd = update storage { model with input = "Task" } Add_todo in
  Alcotest.(check int) "save after Add_todo" 1 (List.length !saves);
  (* Toggle — should save *)
  let model, _cmd = update storage model (Toggle 1) in
  Alcotest.(check int) "save after Toggle" 2 (List.length !saves);
  (* Toggle_all — should save *)
  let model, _cmd = update storage model Toggle_all in
  Alcotest.(check int) "save after Toggle_all" 3 (List.length !saves);
  (* Start editing + Submit_edit — should save *)
  let model, _cmd = update storage model (Start_editing 1) in
  Alcotest.(check int) "no save on Start_editing" 3 (List.length !saves);
  let model, _cmd = update storage model (Edit_changed "Updated") in
  Alcotest.(check int) "no save on Edit_changed" 3 (List.length !saves);
  let model, _cmd = update storage model Submit_edit in
  Alcotest.(check int) "save after Submit_edit" 4 (List.length !saves);
  (* Clear_completed — should save *)
  let _model, _cmd = update storage model Clear_completed in
  Alcotest.(check int) "save after Clear_completed" 5 (List.length !saves)

let () =
  Alcotest.run "todomvc"
    [
      ( "init",
        [
          Alcotest.test_case "empty" `Quick test_init_empty;
          Alcotest.test_case "loads from storage" `Quick
            test_init_loads_from_storage;
        ] );
      ( "add_todo",
        [
          Alcotest.test_case "adds todo" `Quick test_add_todo;
          Alcotest.test_case "trims whitespace" `Quick
            test_add_todo_trims_whitespace;
          Alcotest.test_case "empty ignored" `Quick test_add_todo_empty_ignored;
        ] );
      ( "toggle",
        [
          Alcotest.test_case "toggle" `Quick test_toggle;
          Alcotest.test_case "toggle all to completed" `Quick
            test_toggle_all_to_completed;
          Alcotest.test_case "toggle all to active" `Quick
            test_toggle_all_to_active;
        ] );
      ("delete", [ Alcotest.test_case "delete" `Quick test_delete ]);
      ( "editing",
        [
          Alcotest.test_case "start editing" `Quick test_start_editing;
          Alcotest.test_case "edit changed" `Quick test_edit_changed;
          Alcotest.test_case "submit edit" `Quick test_submit_edit;
          Alcotest.test_case "submit edit empty deletes" `Quick
            test_submit_edit_empty_deletes;
          Alcotest.test_case "cancel edit" `Quick test_cancel_edit;
        ] );
      ( "clear_completed",
        [ Alcotest.test_case "clear completed" `Quick test_clear_completed ] );
      ( "filter",
        [
          Alcotest.test_case "filter active" `Quick test_filter_active;
          Alcotest.test_case "filter completed" `Quick test_filter_completed;
          Alcotest.test_case "active count" `Quick test_active_count;
        ] );
      ( "routing",
        [
          Alcotest.test_case "navigate to" `Quick test_navigate_to;
          Alcotest.test_case "route changed" `Quick test_route_changed;
          Alcotest.test_case "parse routes" `Quick test_parse_routes;
          Alcotest.test_case "to_path" `Quick test_to_path;
        ] );
      ( "persistence",
        [ Alcotest.test_case "save on mutation" `Quick test_save_on_mutation ]
      );
    ]
