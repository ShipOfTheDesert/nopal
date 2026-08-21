(* The relative-scroll kitchen-sink section, read structurally.

   A relative movement is a command, and a command leaves no trace in the
   element tree, so there is nothing here to project the way the reveal section
   projects its declaration onto the container's attributes. The compensation is
   the extractor over the command tree, driven through the MVU loop: every
   assertion below reads the request back through [Cmd.extract_scroll_bys]
   rather than pattern-matching a constructor, because [Cmd.t] and
   [Scroll_delta.t] are both abstract.

   That leaves one thing the extractor cannot say. The id a request names and
   the id the container renders with are the same OCaml constant, so an
   assertion that they match would be a tautology on its own. The container test
   at the bottom is what breaks it: it reads the id off the rendered node, so
   the constant is pinned to the DOM once and every other case may then use it
   as the expected target. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_scroll_pane
module Scroll_delta = Nopal_element.Scroll_delta
module Reveal = Nopal_element.Reveal

let vp = Nopal_element.Viewport.desktop

(* [Scroll_delta.t] withholds every projection, so a mismatch would otherwise
   print two identical placeholders and say nothing about which delta arrived.
   This reads the multiple back out through the only public observation there
   is — the offset a delta produces on a container one unit tall, parked far
   enough from both ends that no clamp applies — and is diagnostics only: the
   comparison stays [Scroll_delta.equal]. *)
let pp_delta fmt d =
  match
    Scroll_delta.offset_for ~scroll_offset:1e6 ~viewport_height:1.0
      ~content_height:1e12 d
  with
  | Some offset -> Format.fprintf fmt "%g viewports" (offset -. 1e6)
  | None -> Format.pp_print_string fmt "no movement, or not finite"

let delta = Alcotest.testable pp_delta Scroll_delta.equal
let requests = Alcotest.list (Alcotest.pair Alcotest.string delta)
let half_forward = Scroll_delta.viewports 0.5
let half_back = Scroll_delta.viewports (-0.5)
let one_forward = Scroll_delta.viewports 1.0

(* The whole section driven through the MVU loop rather than by constructing a
   model, so a message the section can no longer produce cannot keep an
   assertion alive here. *)
let drive msgs =
  let model, _rendered, cmds =
    run_app_with_cmds ~init:Sub.init ~update:Sub.update ~view:Sub.view msgs
  in
  (model, List.concat_map Nopal_mvu.Cmd.extract_scroll_bys cmds)

let model_after msgs = fst (drive msgs)
let requests_after msgs = snd (drive msgs)

let scroll_node model =
  match find (By_tag "scroll") (tree (render (Sub.view vp model))) with
  | Some node -> node
  | None -> Alcotest.fail "the section rendered no scroll container"

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
   leaving the two chords silently unreachable in a browser. *)
let enable_keys_msg () =
  let rendered = render (Sub.view vp (model_after [])) in
  fail_on_error "keyboard toggle"
    (toggle (By_attr ("data-field", "scroll-pane-keys")) rendered);
  single_message "the keyboard toggle" rendered

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

let dispatches key model =
  List.filter_map (fun handler -> handler key) (keydown_handlers model)

(* The message and the prevent flag both come from the subscription's own
   handler, so this pins the wiring from a chord to a message rather than
   restating the message the section happens to define. *)
let press key model =
  match dispatches key model with
  | [ dispatched ] -> dispatched
  | [] -> Alcotest.fail (key ^ " dispatches nothing")
  | _ :: _ :: _ -> Alcotest.fail (key ^ " dispatches more than one message")

let waypoint_at index =
  match List.nth_opt Sub.waypoint_keys index with
  | Some key -> key
  | None ->
      Alcotest.fail (Printf.sprintf "the section has no waypoint %d" index)

let first_row () =
  match Sub.row_keys with
  | key :: _ -> key
  | [] -> Alcotest.fail "the section renders no paragraphs"

(* ------------------------------------------------------------------ *)
(* The two chords                                                       *)
(* ------------------------------------------------------------------ *)

(* The forward chord, taken from the subscription and followed all the way to
   the request it produces. The second half is the non-idempotence: two
   identical presses are two requests, not one, which is the property that made
   this a command instead of a declaration compared for change. *)
let test_ctrl_d_emits_a_half_viewport_request () =
  let enable = enable_keys_msg () in
  let enabled = model_after [ enable ] in
  let msg, prevents = press "Ctrl+d" enabled in
  Alcotest.(check bool)
    "the forward chord prevents the browser default" true prevents;
  Alcotest.check requests
    "the press asks the pane to move forward half its own height"
    [ (Sub.container_id, half_forward) ]
    (requests_after [ enable; msg ]);
  Alcotest.check requests
    "two identical presses ask twice, and are not collapsed into one"
    [ (Sub.container_id, half_forward); (Sub.container_id, half_forward) ]
    (requests_after [ enable; msg; msg ])

(* The backward chord, and the two of them together in issue order. Asserting
   the pair as one fully-enumerated ordered list is what pins the order: a
   drain fed the requests the other way round would move the pane back before
   it moved it forward, and a section that emitted the same delta for both
   chords would satisfy neither entry. *)
let test_ctrl_u_emits_the_inverse () =
  let enable = enable_keys_msg () in
  let enabled = model_after [ enable ] in
  let up, prevents = press "Ctrl+u" enabled in
  Alcotest.(check bool)
    "the backward chord prevents the browser default" true prevents;
  Alcotest.check requests "the press asks the pane to move back by the same"
    [ (Sub.container_id, half_back) ]
    (requests_after [ enable; up ]);
  let down, _ = press "Ctrl+d" enabled in
  Alcotest.check requests "forward then back reaches the drain in that order"
    [ (Sub.container_id, half_forward); (Sub.container_id, half_back) ]
    (requests_after [ enable; down; up ])

(* The chords are a document-level subscription that prevents the browser
   default, and the forward one is the browser's own bookmark shortcut, so the
   section leaves both unsubscribed until the reader asks for them. Each
   absence below sits next to the affirmative arm on the same fixture: without
   them, a section that had stopped subscribing at all, or one whose chord no
   longer produced a request, would keep every "nothing happens" green. *)
let test_keys_gated_until_enabled () =
  let idle = model_after [] in
  Alcotest.(check int)
    "no keydown subscription while the gate is off" 0
    (List.length (keydown_handlers idle));
  Alcotest.check requests "and nothing has asked the pane to move" []
    (requests_after []);
  let enable = enable_keys_msg () in
  let enabled = model_after [ enable ] in
  Alcotest.(check int)
    "both chords subscribe once the gate is on" 2
    (List.length (keydown_handlers enabled));
  let msg, _ = press "Ctrl+d" enabled in
  Alcotest.check requests "and the forward chord then asks the pane to move"
    [ (Sub.container_id, half_forward) ]
    (requests_after [ enable; msg ]);
  (* The chord is the whole key, not the letter in it. A subscription on the
     bare letter would take "d" away from every text field on the page, and it
     would still satisfy every assertion above. *)
  Alcotest.(check int)
    "the bare letter is a different key and dispatches nothing" 0
    (List.length (dispatches "d" enabled))

(* ------------------------------------------------------------------ *)
(* One container, two ways of moving it                                 *)
(* ------------------------------------------------------------------ *)

(* The pane carries the id a request names it by and the paragraph it is asked
   to reveal, at the same time and on the same node — which is what lets the two
   writers be ordered at all. The waypoint control then changes the reveal and
   issues a relative movement in a single update, so the pairing is a fact about
   one update rather than about two the section happens to offer. *)
let test_container_carries_both_declarations () =
  let base = model_after [] in
  let node = scroll_node base in
  Alcotest.(check (option string))
    "the pane renders the id a request names it by" (Some Sub.container_id)
    (attr "id" node);
  Alcotest.(check (option string))
    "and it can be found by a browser test" (Some "scroll-pane-container")
    (attr "data-testid" node);
  Alcotest.(check (option string))
    "the first render asks for the paragraph the pane already shows"
    (Some (first_row ()))
    (attr "reveal" node);
  Alcotest.(check (option string))
    "aligned so the paragraph's top becomes the pane's top"
    (Some (Reveal.align_token Reveal.Start))
    (attr "reveal-align" node);
  let rendered = render (Sub.view vp base) in
  fail_on_error "waypoint control"
    (click (By_attr ("data-action", "scroll-pane-waypoint")) rendered);
  let msg = single_message "the waypoint control" rendered in
  let advanced, cmd = Sub.update base msg in
  Alcotest.(check (option string))
    "the control moves the reveal to the first waypoint"
    (Some (waypoint_at 0))
    (attr "reveal" (scroll_node advanced));
  Alcotest.check requests
    "and the same update asks the same container to back off half a viewport"
    [ (Sub.container_id, half_back) ]
    (Nopal_mvu.Cmd.extract_scroll_bys cmd)

(* Taken from the control rather than written down, for the same reason the
   keyboard gate is: a control that stopped being wired would fail here instead
   of leaving the cycle reachable only from a message this file constructs. *)
let waypoint_msg model =
  let rendered = render (Sub.view vp model) in
  fail_on_error "waypoint control"
    (click (By_attr ("data-action", "scroll-pane-waypoint")) rendered);
  single_message "the waypoint control" rendered

(* The cycle is over the waypoints alone. The marker starts outside it, so the
   very first press already runs the wrap arm — which is exactly why executing
   that arm proves nothing about where it wraps *to*. Pressing until the marker
   comes back around is what separates a cycle over the waypoints from one over
   the paragraphs: a wrap reaching for the first paragraph would return the pane
   to the top and would satisfy every other case in this file. *)
let test_the_cycle_returns_to_the_first_waypoint () =
  let base = model_after [] in
  let cycle = List.length Sub.waypoint_keys in
  Alcotest.(check bool)
    "the section offers more than one waypoint, or the cycle has nothing to say"
    true (cycle > 1);
  Alcotest.(check bool)
    "the first waypoint is not the first paragraph, or a wrap to either would \
     look the same"
    false
    (String.equal (waypoint_at 0) (first_row ()));
  let advance = waypoint_msg base in
  let marker_after presses =
    attr "reveal"
      (scroll_node (model_after (List.init presses (fun _ -> advance))))
  in
  Alcotest.(check (option string))
    "the first press leaves the paragraph the pane opened on"
    (Some (waypoint_at 0))
    (marker_after 1);
  Alcotest.(check (option string))
    "one press per waypoint reaches the last of them"
    (Some (waypoint_at (cycle - 1)))
    (marker_after cycle);
  Alcotest.(check (option string))
    "and the next comes back to the first waypoint, not to the first paragraph"
    (Some (waypoint_at 0))
    (marker_after (cycle + 1))

(* ------------------------------------------------------------------ *)
(* The third stage of the order                                         *)
(* ------------------------------------------------------------------ *)

(* The focus control, which is the only place in the section where the third
   stage of the drain order is exercised. Structurally there are three things to
   say and one there is not. Both requests leave the same update; the reveal
   does not move, so exactly two of the three writers contend and the browser
   test beside this one can read the landing position as focus's rather than as
   the reveal's; and the id the command names is read off the rendered node, so
   the constant is pinned to the tree rather than compared with itself. What no
   structural test can say is where the pane comes to rest — that is the
   browser's own scroll-into-view, and it is asserted in the Playwright spec. *)
let test_focus_batches_with_the_relative_movement () =
  let base = model_after [] in
  let target =
    match
      find
        (By_attr ("data-testid", "scroll-pane-focus-target"))
        (tree (render (Sub.view vp base)))
    with
    | Some node -> node
    | None -> Alcotest.fail "the section renders no focus target"
  in
  Alcotest.(check (option string))
    "the focus target renders the id the command names it by"
    (Some Sub.focus_target_id) (attr "id" target);
  let rendered = render (Sub.view vp base) in
  fail_on_error "focus control"
    (click (By_attr ("data-action", "scroll-pane-focus")) rendered);
  let msg = single_message "the focus control" rendered in
  let moved, cmd = Sub.update base msg in
  Alcotest.check requests
    "the update asks the pane to move forward a whole visible height"
    [ (Sub.container_id, one_forward) ]
    (Nopal_mvu.Cmd.extract_scroll_bys cmd);
  Alcotest.(check (list string))
    "and the same update focuses the row far down the pane"
    [ Sub.focus_target_id ]
    (Nopal_mvu.Cmd.extract_focuses cmd);
  Alcotest.(check (option string))
    "while the reveal stays where it was, so only two writers contend"
    (Some (first_row ()))
    (attr "reveal" (scroll_node moved))

let () =
  Alcotest.run "kitchen_sink_scroll_pane_section"
    [
      ( "chords",
        [
          Alcotest.test_case "Ctrl+D emits a half-viewport request" `Quick
            test_ctrl_d_emits_a_half_viewport_request;
          Alcotest.test_case "Ctrl+U emits the inverse" `Quick
            test_ctrl_u_emits_the_inverse;
          Alcotest.test_case "the chords are gated until enabled" `Quick
            test_keys_gated_until_enabled;
        ] );
      ( "container",
        [
          Alcotest.test_case "the container carries both declarations" `Quick
            test_container_carries_both_declarations;
          Alcotest.test_case "the cycle returns to the first waypoint" `Quick
            test_the_cycle_returns_to_the_first_waypoint;
          Alcotest.test_case "focus batches with the relative movement" `Quick
            test_focus_batches_with_the_relative_movement;
        ] );
    ]
