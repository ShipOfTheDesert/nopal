open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_reveal_list
module Reveal = Nopal_element.Reveal

let vp = Nopal_element.Viewport.desktop

(* The whole section, driven through the MVU loop rather than by constructing a
   model: a selection the section can no longer reach cannot keep a rendering
   alive here. *)
let after msgs =
  fst (run_app ~init:Sub.init ~update:Sub.update ~view:Sub.view msgs)

let scroll_node model =
  match find (By_tag "scroll") (tree (render (Sub.view vp model))) with
  | Some node -> node
  | None -> Alcotest.fail "the section rendered no scroll container"

let declared_key model =
  match attr "reveal" (scroll_node model) with
  | Some key -> key
  | None -> Alcotest.fail "the scroll container declared no child to reveal"

let declared_align model =
  match attr "reveal-align" (scroll_node model) with
  | Some token -> token
  | None -> Alcotest.fail "the scroll container declared no alignment"

let key_at index =
  match List.nth_opt Sub.row_keys index with
  | Some key -> key
  | None -> Alcotest.fail (Printf.sprintf "the list has no row %d" index)

(* Where the hostile row sits, found rather than written down, so moving it
   costs nothing here and a list that stops carrying it fails loudly. *)
let hostile_index () =
  let rec go index keys =
    match keys with
    | [] -> Alcotest.fail "no row carries the hostile key"
    | key :: rest ->
        if String.equal key Sub.hostile_key then index else go (index + 1) rest
  in
  go 0 Sub.row_keys

let fail_on_error label result =
  match result with
  | Ok () -> ()
  | Error (Not_found _) -> Alcotest.fail (label ^ ": no such control")
  | Error (No_handler { tag; event }) ->
      Alcotest.fail
        (Printf.sprintf "%s: the %s control handles no %s" label tag event)

let single_message label rendered =
  match messages rendered with
  | [ msg ] -> msg
  | [] -> Alcotest.fail (label ^ " dispatched no message")
  | _ :: _ :: _ -> Alcotest.fail (label ^ " dispatched more than one message")

(* Taken from the checkbox rather than written down, so the gate stays reachable
   from the UI: a toggle that stopped being wired would fail here instead of
   leaving the keyboard silently unreachable in the browser. *)
let toggle_keys model =
  let rendered = render (Sub.view vp model) in
  fail_on_error "keyboard toggle"
    (toggle (By_attr ("data-field", "reveal-keys")) rendered);
  fst (Sub.update model (single_message "the keyboard toggle" rendered))

let keydown_handlers model =
  List.filter_map
    (fun atom ->
      match atom with
      | Nopal_mvu.Sub.Keydown { key = _; handler } -> Some handler
      | Every _
      | Keyup _
      | Resize _
      | Visibility _
      | Viewport _
      | Custom _ ->
          None)
    (Nopal_mvu.Sub.atoms (Sub.subscriptions model))

(* The message and the prevent flag both come from the subscription's own
   handler, so this pins the wiring from a key to a message rather than
   restating the message the section happens to define. *)
let press key model =
  match
    List.filter_map (fun handler -> handler key) (keydown_handlers model)
  with
  | [ dispatched ] -> dispatched
  | [] -> Alcotest.fail (key ^ " dispatches nothing")
  | _ :: _ :: _ -> Alcotest.fail (key ^ " dispatches more than one message")

(* The keyboard gate is off until the reader asks for it, because the arrows are
   a document-level subscription that prevents the browser default: left always
   on it would cancel arrow navigation everywhere else on the page. The enabled
   half is the affirmative arm — without it "no subscription" would stay green on
   a section that had stopped subscribing at all. *)
let test_arrow_down_advances_selection () =
  let idle = after [] in
  Alcotest.(check int)
    "no keydown subscription while the toggle is off" 0
    (List.length (keydown_handlers idle));
  let enabled = toggle_keys idle in
  Alcotest.(check int)
    "both arrows subscribe once the toggle is on" 2
    (List.length (keydown_handlers enabled));
  Alcotest.(check string)
    "the selection starts on the first row" (key_at 0) enabled.Sub.selected;
  let down_msg, down_prevents = press "ArrowDown" enabled in
  Alcotest.(check bool)
    "ArrowDown prevents the browser default" true down_prevents;
  let moved = fst (Sub.update enabled down_msg) in
  Alcotest.(check string)
    "ArrowDown advances one row" (key_at 1) moved.Sub.selected;
  let up_msg, up_prevents = press "ArrowUp" moved in
  Alcotest.(check bool) "ArrowUp prevents the browser default" true up_prevents;
  let back = fst (Sub.update moved up_msg) in
  Alcotest.(check string)
    "ArrowUp goes back one row" (key_at 0) back.Sub.selected;
  let held = fst (Sub.update back (fst (press "ArrowUp" back))) in
  Alcotest.(check string)
    "the top of the list is a wall, not a wrap" (key_at 0) held.Sub.selected

(* The reveal declaration is derived from the selection on every view call, so a
   selection that moves is enough to move the container. The first assertion is
   what a declaration frozen on row 0 would still satisfy; the second is what it
   would not. *)
let test_selection_declares_reveal () =
  Alcotest.(check string)
    "the first render declares the first row" (key_at 0)
    (declared_key (after []));
  Alcotest.(check string)
    "the declaration follows the selection" (key_at 3)
    (declared_key (after [ Sub.Select_next; Sub.Select_next; Sub.Select_next ]));
  (* A key carrying a double quote and a backslash reaches the declaration
     byte-identical. Escaping belongs to whichever backend builds a query out of
     it; a value escaped here would be escaped twice there and resolve to
     nothing. *)
  let index = hostile_index () in
  let hostile = after (List.init index (fun _ -> Sub.Select_next)) in
  Alcotest.(check string)
    "a key with a quote and a backslash reaches the declaration unchanged"
    Sub.hostile_key (declared_key hostile)

(* Each alignment control declares its own alignment. Driven through the
   rendered buttons, so a control wired to the wrong constructor fails here
   rather than in a browser. *)
let test_align_selector_changes_token () =
  let base = after [] in
  Alcotest.(check string)
    "the first render asks for the nearest alignment"
    (Reveal.align_token Reveal.Nearest)
    (declared_align base);
  let token_after action =
    let rendered = render (Sub.view vp base) in
    fail_on_error action (click (By_attr ("data-action", action)) rendered);
    declared_align (fst (Sub.update base (single_message action rendered)))
  in
  Alcotest.(check (list string))
    "every alignment control lands its own alignment"
    (List.map Reveal.align_token
       [ Reveal.Nearest; Reveal.Start; Reveal.Center; Reveal.End_ ])
    (List.map token_after
       [
         "reveal-align-nearest";
         "reveal-align-start";
         "reveal-align-center";
         "reveal-align-end";
       ])

let () =
  Alcotest.run "kitchen_sink_reveal_list_section"
    [
      ( "selection",
        [
          Alcotest.test_case "arrow down advances the selection" `Quick
            test_arrow_down_advances_selection;
          Alcotest.test_case "the selection declares the reveal" `Quick
            test_selection_declares_reveal;
        ] );
      ( "alignment",
        [
          Alcotest.test_case "the align selector changes the token" `Quick
            test_align_selector_changes_token;
        ] );
    ]
