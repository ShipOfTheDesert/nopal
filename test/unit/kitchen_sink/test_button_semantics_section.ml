(* The button-semantics kitchen-sink section, driven cell by cell through the
   matrix in test/e2e/fixtures/button-submit-matrix.tsv.

   The matrix is the statement of what a button inside a form dispatches, and
   the browser suite reads the same file, so a line this renderer answers
   differently from the browser fails here rather than in a consumer's app.
   Each line is one case: the section is put in the line's cell by pressing its
   own selectors, the line's action is performed, and the whole ordered list of
   what the section dispatched is compared with the line, through the section's
   telemetry serializer, so the names pinned here are the names the browser
   suite waits on. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app.Sub_button_semantics

type action = Click_button_1 | Click_button_2 | Enter_field_1 | Enter_field_2

let actions = [ Click_button_1; Click_button_2; Enter_field_1; Enter_field_2 ]

let action_to_string = function
  | Click_button_1 -> "click-button-1"
  | Click_button_2 -> "click-button-2"
  | Enter_field_1 -> "enter-field-1"
  | Enter_field_2 -> "enter-field-2"

type cell = {
  field_set : Sub.field_set;
  button_state : Sub.button_state;
  action : action;
  expected : string list;
}

let header = "field_set\tbutton_state\taction\texpected"

(* The file is a dependency of this test's runtest action, copied into the
   build tree; the path is taken from the executable so it holds under
   [dune exec] as well, once [dune build] has copied the file. *)
let matrix_path =
  Filename.concat
    (Filename.dirname Sys.executable_name)
    "../../../test/e2e/fixtures/button-submit-matrix.tsv"

let named to_string values name =
  List.find_opt (fun v -> String.equal (to_string v) name) values

let expected_of_column = function
  | "-" -> []
  | tokens -> String.split_on_char ',' tokens

let cell_of_line line =
  match String.split_on_char '\t' line with
  | [ field_set; button_state; action; expected ] -> (
      match
        ( named Sub.field_set_to_string Sub.field_sets field_set,
          named Sub.button_state_to_string Sub.button_states button_state,
          named action_to_string actions action )
      with
      | Some field_set, Some button_state, Some action ->
          Ok
            {
              field_set;
              button_state;
              action;
              expected = expected_of_column expected;
            }
      | None, _, _
      | _, None, _
      | _, _, None ->
          Error "a name the section's vocabulary does not have")
  | _ -> Error "not four tab-separated columns"

(* Each line of the matrix that states a cell, paired with its parse. Comment
   lines, the header and blank lines state none. *)
let matrix_lines () =
  match In_channel.with_open_text matrix_path In_channel.input_all with
  | text ->
      Ok
        (String.split_on_char '\n' text
        |> List.filter (fun line ->
            not
              (String.equal line ""
              || String.equal line header
              || String.starts_with ~prefix:"#" line))
        |> List.map (fun line -> (line, cell_of_line line)))
  | exception Sys_error e -> Error e

let testid suffix = By_attr ("data-testid", "button-semantics-" ^ suffix)

let fail_on_not_found label result =
  match result with
  | Ok ()
  | Error (No_handler _) ->
      ()
  | Error (Not_found _) -> Alcotest.fail (label ^ ": no such element")

(* The cell is reached by pressing the section's own selectors and feeding what
   they dispatch back through the loop, so a selector that stopped dispatching
   its selection fails here rather than leaving every case on the initial
   cell. *)
let rendered_in field_set button_state =
  let run msgs =
    snd (run_app ~init:Sub.init ~update:Sub.update ~view:Sub.view msgs)
  in
  let initial = run [] in
  let press suffix =
    match click (testid suffix) initial with
    | Ok () -> ()
    | Error (Not_found _ | No_handler _) ->
        Alcotest.fail ("the selector " ^ suffix ^ " dispatches nothing")
  in
  press ("fields-" ^ Sub.field_set_to_string field_set);
  press ("buttons-" ^ Sub.button_state_to_string button_state);
  Alcotest.(check (list string))
    "the selectors dispatch the selection and nothing else"
    [
      "ButtonSemantics:fields=" ^ Sub.field_set_to_string field_set ^ ";";
      "ButtonSemantics:buttons=" ^ Sub.button_state_to_string button_state ^ ";";
    ]
    (List.map Sub.serialize_msg (messages initial));
  run (messages initial)

let perform action rendered =
  let label = action_to_string action in
  match action with
  | Click_button_1 ->
      fail_on_not_found label (click (testid "button-1") rendered)
  | Click_button_2 ->
      fail_on_not_found label (click (testid "button-2") rendered)
  | Enter_field_1 ->
      fail_on_not_found label (keydown (testid "field-1") "Enter" rendered)
  | Enter_field_2 ->
      fail_on_not_found label (keydown (testid "field-2") "Enter" rendered)

let dispatches_what_the_line_states cell () =
  let rendered = rendered_in cell.field_set cell.button_state in
  perform cell.action rendered;
  Alcotest.(check (list string))
    "the whole ordered dispatch list"
    (List.map (fun token -> "ButtonSemantics:" ^ token ^ ";") cell.expected)
    (List.map Sub.serialize_msg (messages rendered))

let cell_case (line, parsed) =
  let name = String.concat " " (String.split_on_char '\t' line) in
  match parsed with
  | Ok cell ->
      Alcotest.test_case name `Quick (dispatches_what_the_line_states cell)
  | Error reason ->
      Alcotest.test_case name `Quick (fun () -> Alcotest.fail reason)

let two_fields = function
  | Sub.Text
  | Sub.Password ->
      false
  | Sub.Text_text
  | Sub.Text_password ->
      true

(* The actions that apply to a cell: a click only where there is a button to
   click, a second click only where there is a second button, and an Enter in
   each field the form has. *)
let applies field_set button_state action =
  match action with
  | Click_button_1 -> (
      match button_state with
      | Sub.No_button -> false
      | Sub.Submit_enabled
      | Sub.Submit_disabled
      | Sub.Push_enabled
      | Sub.Disabled_submit_before_enabled_submit ->
          true)
  | Click_button_2 -> (
      match button_state with
      | Sub.Disabled_submit_before_enabled_submit -> true
      | Sub.Submit_enabled
      | Sub.Submit_disabled
      | Sub.Push_enabled
      | Sub.No_button ->
          false)
  | Enter_field_1 -> true
  | Enter_field_2 -> two_fields field_set

let key field_set button_state action =
  String.concat " "
    [
      Sub.field_set_to_string field_set;
      Sub.button_state_to_string button_state;
      action_to_string action;
    ]

let matrix_file_covers_every_field_set_button_state_and_action () =
  let lines =
    match matrix_lines () with
    | Ok lines -> lines
    | Error e -> Alcotest.fail ("cannot read the matrix: " ^ e)
  in
  let stated =
    List.map
      (fun (line, parsed) ->
        match parsed with
        | Ok cell -> key cell.field_set cell.button_state cell.action
        | Error reason -> Alcotest.fail (line ^ ": " ^ reason))
      lines
  in
  let owed =
    List.concat_map
      (fun field_set ->
        List.concat_map
          (fun button_state ->
            List.filter_map
              (fun action ->
                match applies field_set button_state action with
                | true -> Some (key field_set button_state action)
                | false -> None)
              actions)
          Sub.button_states)
      Sub.field_sets
  in
  Alcotest.(check (list string))
    "every cell exactly once, and no cell that does not apply"
    (List.sort String.compare owed)
    (List.sort String.compare stated)

let dispatched_text msgs =
  let rendered =
    snd (run_app ~init:Sub.init ~update:Sub.update ~view:Sub.view msgs)
  in
  match find (testid "dispatched") (tree rendered) with
  | Some node -> text_content node
  | None -> Alcotest.fail "the section renders no dispatch list"

(* What a person sees on the page after pressing a button: the form's dispatches
   in the order they came, until a selection starts a new cell. *)
let the_dispatch_list_shows_what_the_form_dispatched () =
  let initial =
    snd (run_app ~init:Sub.init ~update:Sub.update ~view:Sub.view [])
  in
  fail_on_not_found "click-button-1" (click (testid "button-1") initial);
  let pressed = messages initial in
  Alcotest.(check string)
    "the dispatches, oldest first" "Dispatched since the last selection: C1, S"
    (dispatched_text pressed);
  clear_messages initial;
  fail_on_not_found "fields-text-text"
    (click (testid "fields-text-text") initial);
  Alcotest.(check string)
    "a selection empties the list"
    "Dispatched since the last selection: nothing"
    (dispatched_text (pressed @ messages initial))

(* The save form's button disables itself: its first click submits, and the
   pending save that submission starts renders it disabled, so the second click
   on the same button dispatches nothing. The first click is the affirmative
   arm of the second, on the same button. *)
let the_save_button_disables_itself () =
  let run msgs =
    snd (run_app ~init:Sub.init ~update:Sub.update ~view:Sub.view msgs)
  in
  let idle = run [] in
  (match click (testid "save-button") idle with
  | Ok () -> ()
  | Error (Not_found _ | No_handler _) ->
      Alcotest.fail "the idle save button dispatches nothing");
  let first_click = messages idle in
  Alcotest.(check (list string))
    "the first click dispatches the button's on_click, then the form's \
     on_submit"
    [ "ButtonSemantics:save=C;"; "ButtonSemantics:save=S;" ]
    (List.map Sub.serialize_msg first_click);
  let pending = run first_click in
  let aria_disabled =
    match find (testid "save-button") (tree pending) with
    | Some node -> attr "aria-disabled" node
    | None -> Alcotest.fail "the pending save form renders no save button"
  in
  Alcotest.(check (option string))
    "the pending save button is announced as disabled" (Some "true")
    aria_disabled;
  (match click (testid "save-button") pending with
  | Error (No_handler _) -> ()
  | Ok () -> Alcotest.fail "the pending save button still dispatches"
  | Error (Not_found _) -> Alcotest.fail "the pending save button is gone");
  Alcotest.(check (list string))
    "the second click dispatches nothing" []
    (List.map Sub.serialize_msg (messages pending))

let () =
  let cells =
    match matrix_lines () with
    | Ok lines -> List.map cell_case lines
    | Error e ->
        [
          Alcotest.test_case "the matrix file" `Quick (fun () ->
              Alcotest.fail ("cannot read the matrix: " ^ e));
        ]
  in
  Alcotest.run "button_semantics_section"
    [
      ("every_matrix_cell_dispatches_what_the_table_states", cells);
      ( "matrix_file_covers_every_field_set_button_state_and_action",
        [
          Alcotest.test_case "the matrix has every cell once" `Quick
            matrix_file_covers_every_field_set_button_state_and_action;
        ] );
      ( "the section's own display",
        [
          Alcotest.test_case "the dispatch list" `Quick
            the_dispatch_list_shows_what_the_form_dispatched;
        ] );
      ( "the save form",
        [
          Alcotest.test_case "the save button disables itself" `Quick
            the_save_button_disables_itself;
        ] );
    ]
