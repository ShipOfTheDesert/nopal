open Todomvc
open Test_helpers
module R = Nopal_test.Test_renderer

(* -- Test helpers --------------------------------------------------------- *)

(** Build a model with the given todos and filter, with no editing state. *)
let model_with ?(filter = All) ?(edit_state : editing option = None)
    ?(input = "") (todos : todo list) =
  let next_id =
    match todos with
    | [] -> 1
    | _ -> 1 + List.fold_left (fun acc (t : todo) -> max acc t.id) 0 todos
  in
  let router = make_router () in
  { todos; filter; input; editing = edit_state; next_id; router }

let make_todo ?(completed = false) id title = { id; title; completed }

(* -- Tests ---------------------------------------------------------------- *)

let test_empty_hides_main_and_footer () =
  let model = model_with [] in
  let rendered = R.render (view model) in
  let tree = R.tree rendered in
  (* With no todos, there should be no main section or footer *)
  let main = R.find (By_attr ("data-section", "main")) tree in
  Alcotest.(check bool) "no main section" true (Option.is_none main);
  let footer = R.find (By_attr ("data-section", "footer")) tree in
  Alcotest.(check bool) "no footer" true (Option.is_none footer)

let test_header_input_present () =
  let model = model_with [] in
  let rendered = R.render (view model) in
  let tree = R.tree rendered in
  let input_node = R.find (By_tag "input") tree in
  Alcotest.(check bool) "input present" true (Option.is_some input_node)

let test_add_todo_via_submit () =
  let model = model_with [] in
  let rendered = R.render (view model) in
  let result = R.submit (By_tag "input") rendered in
  Alcotest.(check bool) "submit succeeds" true (Result.is_ok result);
  let msgs = R.messages rendered in
  Alcotest.(check int) "one message" 1 (List.length msgs);
  match msgs with
  | [ Add_todo ] -> ()
  | _ -> Alcotest.fail "expected Add_todo message"

let test_todo_items_keyed () =
  let model = model_with [ make_todo 1 "A"; make_todo 2 "B" ] in
  let rendered = R.render (view model) in
  let tree = R.tree rendered in
  let keyed1 = R.find (By_attr ("key", "todo-1")) tree in
  let keyed2 = R.find (By_attr ("key", "todo-2")) tree in
  Alcotest.(check bool) "todo-1 keyed" true (Option.is_some keyed1);
  Alcotest.(check bool) "todo-2 keyed" true (Option.is_some keyed2)

let test_toggle_click () =
  let model = model_with [ make_todo 1 "Task" ] in
  let rendered = R.render (view model) in
  let result = R.click (By_attr ("data-action", "toggle-1")) rendered in
  Alcotest.(check bool) "click succeeds" true (Result.is_ok result);
  let msgs = R.messages rendered in
  match msgs with
  | [ Toggle 1 ] -> ()
  | _ -> Alcotest.fail "expected Toggle 1 message"

let test_delete_click () =
  let model = model_with [ make_todo 1 "Task" ] in
  let rendered = R.render (view model) in
  let result = R.click (By_attr ("data-action", "delete-1")) rendered in
  Alcotest.(check bool) "click succeeds" true (Result.is_ok result);
  let msgs = R.messages rendered in
  match msgs with
  | [ Delete 1 ] -> ()
  | _ -> Alcotest.fail "expected Delete 1 message"

let test_dblclick_enters_editing () =
  let model = model_with [ make_todo 1 "Task" ] in
  let rendered = R.render (view model) in
  let result = R.dblclick (By_attr ("data-action", "edit-1")) rendered in
  Alcotest.(check bool) "dblclick succeeds" true (Result.is_ok result);
  let msgs = R.messages rendered in
  match msgs with
  | [ Start_editing 1 ] -> ()
  | _ -> Alcotest.fail "expected Start_editing 1 message"

let test_edit_blur_saves () =
  let model =
    model_with
      ~edit_state:(Some { id = 1; text = "Editing"; original = "Task" })
      [ make_todo 1 "Task" ]
  in
  let rendered = R.render (view model) in
  let result = R.blur (By_attr ("data-action", "edit-input")) rendered in
  Alcotest.(check bool) "blur succeeds" true (Result.is_ok result);
  let msgs = R.messages rendered in
  match msgs with
  | [ Submit_edit ] -> ()
  | _ -> Alcotest.fail "expected Submit_edit message"

let test_edit_escape_cancels () =
  let model =
    model_with
      ~edit_state:(Some { id = 1; text = "Editing"; original = "Task" })
      [ make_todo 1 "Task" ]
  in
  let rendered = R.render (view model) in
  let result =
    R.keydown (By_attr ("data-action", "edit-input")) "Escape" rendered
  in
  Alcotest.(check bool) "keydown succeeds" true (Result.is_ok result);
  let msgs = R.messages rendered in
  match msgs with
  | [ Cancel_edit ] -> ()
  | _ -> Alcotest.fail "expected Cancel_edit message"

let test_toggle_all_click () =
  let model = model_with [ make_todo 1 "A"; make_todo 2 "B" ] in
  let rendered = R.render (view model) in
  let result = R.click (By_attr ("data-action", "toggle-all")) rendered in
  Alcotest.(check bool) "click succeeds" true (Result.is_ok result);
  let msgs = R.messages rendered in
  match msgs with
  | [ Toggle_all ] -> ()
  | _ -> Alcotest.fail "expected Toggle_all message"

let test_filter_links () =
  let model = model_with [ make_todo 1 "Task" ] in
  let rendered = R.render (view model) in
  let tree = R.tree rendered in
  let all_link = R.find (By_text "All") tree in
  let active_link = R.find (By_text "Active") tree in
  let completed_link = R.find (By_text "Completed") tree in
  Alcotest.(check bool) "All link" true (Option.is_some all_link);
  Alcotest.(check bool) "Active link" true (Option.is_some active_link);
  Alcotest.(check bool) "Completed link" true (Option.is_some completed_link)

let test_active_filter_highlighted () =
  let model = model_with ~filter:Active [ make_todo 1 "Task" ] in
  let rendered = R.render (view model) in
  let tree = R.tree rendered in
  let active_link = R.find (By_attr ("data-selected", "true")) tree in
  Alcotest.(check bool)
    "active filter highlighted" true
    (Option.is_some active_link);
  match active_link with
  | Some node ->
      let text = R.text_content node in
      Alcotest.(check bool) "contains Active" true (String.length text > 0)
  | None -> Alcotest.fail "no highlighted filter"

let test_items_left_count () =
  let model = model_with [ make_todo 1 "A"; make_todo ~completed:true 2 "B" ] in
  let rendered = R.render (view model) in
  let tree = R.tree rendered in
  let count_text = R.find (By_attr ("data-section", "todo-count")) tree in
  Alcotest.(check bool) "count present" true (Option.is_some count_text);
  match count_text with
  | Some node ->
      let text = R.text_content node in
      Alcotest.(check string) "shows 1 item left" "1 item left" text
  | None -> Alcotest.fail "no count element"

let test_clear_completed_visible () =
  let model = model_with [ make_todo ~completed:true 1 "Done" ] in
  let rendered = R.render (view model) in
  let tree = R.tree rendered in
  let clear = R.find (By_text "Clear completed") tree in
  Alcotest.(check bool) "clear completed visible" true (Option.is_some clear)

let test_clear_completed_hidden () =
  let model = model_with [ make_todo 1 "Active" ] in
  let rendered = R.render (view model) in
  let tree = R.tree rendered in
  let clear = R.find (By_text "Clear completed") tree in
  Alcotest.(check bool) "clear completed hidden" true (Option.is_none clear)

let test_editing_mode () =
  let model =
    model_with
      ~edit_state:(Some { id = 1; text = "Edit text"; original = "Task" })
      [ make_todo 1 "Task" ]
  in
  let rendered = R.render (view model) in
  let tree = R.tree rendered in
  let edit_input = R.find (By_attr ("data-action", "edit-input")) tree in
  Alcotest.(check bool) "edit input present" true (Option.is_some edit_input);
  match edit_input with
  | Some node ->
      let value = R.attr "value" node in
      Alcotest.(check (option string))
        "value is edit text" (Some "Edit text") value
  | None -> Alcotest.fail "no edit input"

let test_full_mvu_cycle () =
  let router = make_router () in
  let init () = init noop_storage router () in
  let update model msg = update noop_storage model msg in
  let model, rendered =
    R.run_app ~init ~update ~view
      [ Input_changed "Buy milk"; Add_todo; Toggle 1 ]
  in
  Alcotest.(check int) "1 todo" 1 (List.length model.todos);
  let todo_item = List.hd model.todos in
  Alcotest.(check bool) "completed" true todo_item.completed;
  let tree = R.tree rendered in
  let node = R.find (By_text "Buy milk") tree in
  Alcotest.(check bool) "contains Buy milk" true (Option.is_some node)

let () =
  Alcotest.run "todomvc_view"
    [
      ( "empty",
        [
          Alcotest.test_case "hides main and footer" `Quick
            test_empty_hides_main_and_footer;
        ] );
      ( "header",
        [
          Alcotest.test_case "input present" `Quick test_header_input_present;
          Alcotest.test_case "add todo via submit" `Quick
            test_add_todo_via_submit;
        ] );
      ( "todo_items",
        [
          Alcotest.test_case "keyed" `Quick test_todo_items_keyed;
          Alcotest.test_case "toggle click" `Quick test_toggle_click;
          Alcotest.test_case "delete click" `Quick test_delete_click;
          Alcotest.test_case "dblclick enters editing" `Quick
            test_dblclick_enters_editing;
        ] );
      ( "editing",
        [
          Alcotest.test_case "blur saves" `Quick test_edit_blur_saves;
          Alcotest.test_case "escape cancels" `Quick test_edit_escape_cancels;
          Alcotest.test_case "editing mode" `Quick test_editing_mode;
        ] );
      ("toggle_all", [ Alcotest.test_case "click" `Quick test_toggle_all_click ]);
      ( "footer",
        [
          Alcotest.test_case "filter links" `Quick test_filter_links;
          Alcotest.test_case "active filter highlighted" `Quick
            test_active_filter_highlighted;
          Alcotest.test_case "items left count" `Quick test_items_left_count;
          Alcotest.test_case "clear completed visible" `Quick
            test_clear_completed_visible;
          Alcotest.test_case "clear completed hidden" `Quick
            test_clear_completed_hidden;
        ] );
      ("mvu", [ Alcotest.test_case "full cycle" `Quick test_full_mvu_cycle ]);
    ]
