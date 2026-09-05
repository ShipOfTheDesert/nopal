(* The focus-revealed-note kitchen-sink section, read structurally.

   Two layers meet in this file and only one of them is here. The section's own
   arithmetic — which message each focus edge produces, what the update function
   does with it, and what the view renders afterwards — is entirely structural
   and is pinned below. Whether the platform reports an edge at all, and whether
   a move between two elements inside the container counts as one, is the
   backend's business: the structural renderer fires the selected node's own
   handler and models no propagation, so a container's edges cannot be scoped to
   a subtree here and nothing in this file may be read as evidence that they
   are. That half is pinned in the browser spec beside it.

   Both messages are taken from the container's own handlers rather than named
   here. A container that stopped carrying one fails at the simulator instead of
   leaving these cases driving the section by a message its view can no longer
   produce.

   State is asserted through the telemetry serializer rather than through the
   model's fields, because the serializer is what the browser spec reads: an
   assertion here and an assertion there then fail together rather than one
   silently drifting past the other. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_focus_reveal

let vp = Nopal_element.Viewport.desktop
let container = By_attr ("data-testid", "focus-reveal-box")
let note = By_attr ("data-testid", "focus-reveal-note")

(* The whole section driven through the MVU loop rather than by constructing a
   model, so a state the section can no longer reach cannot keep an assertion
   alive here. *)
let after msgs =
  fst (run_app ~init:Sub.init ~update:Sub.update ~view:Sub.view msgs)

let rendered_for model = render (Sub.view vp model)
let note_shown model = Option.is_some (find note (tree (rendered_for model)))

let fail_on_error label result =
  match result with
  | Ok () -> ()
  | Error (Not_found _) -> Alcotest.fail (label ^ ": no such element")
  | Error (No_handler { tag; event }) ->
      Alcotest.fail
        (Printf.sprintf "%s: the %s element handles no %s" label tag event)

let single_message label rendered =
  match messages rendered with
  | [ msg ] -> msg
  | [] -> Alcotest.fail (label ^ " dispatched no message")
  | _ :: _ :: _ -> Alcotest.fail (label ^ " dispatched more than one message")

let edge simulate label model =
  let rendered = rendered_for model in
  fail_on_error label (simulate container rendered);
  single_message label rendered

let focus_edge model = edge box_focus "the container's focus edge" model
let blur_edge model = edge box_blur "the container's blur edge" model
let ack_button = By_attr ("data-action", "focus-reveal-ack")
let reset_button = By_attr ("data-action", "focus-reveal-reset")

(* The section's two buttons are driven by clicking the rendered control rather
   than by naming the message behind it, for the same reason the focus edges
   are: a control the view stopped rendering fails at the simulator instead of
   leaving a case here driving the section by hand. *)
let press label selector model =
  let rendered = rendered_for model in
  fail_on_error label (click selector rendered);
  single_message label rendered

let acknowledge model = press "the note's own control" ack_button model
let reset model = press "the reset control" reset_button model

let ack_label model =
  match find ack_button (tree (rendered_for model)) with
  | None -> Alcotest.fail "the note carries no control to acknowledge"
  | Some node -> text_content node

(* The container asks the platform for a tab stop. Nothing else in this file
   could fail if it stopped asking: every case here fires the container's own
   handler, and a handler fires whether or not a keyboard could ever reach the
   node it hangs on. FR-3 is the precondition the whole section rests on, and
   this is the one assertion outside the browser spec that holds it. The
   declaration is read back through the derived attribute the structural
   renderer surfaces for it, the same route a scroll container's reveal takes.
*)
let test_container_is_focusable () =
  match find container (tree (rendered_for (after []))) with
  | None -> Alcotest.fail "the section renders no container to focus"
  | Some node ->
      Alcotest.(check (option string))
        "the container declares itself a tab stop" (Some "true")
        (attr "focusable" node)

(* The other half of what a keyboard user gets, and the half the model knows
   nothing about. The note is the section's event mechanism; the ring is its
   styling mechanism, a rule the browser applies while the container matches
   [:focus-visible]. Nothing else in this file could fail if the container
   stopped carrying it, and a tab stop with no visible focus indicator is worse
   than one the keyboard cannot reach at all: the section would be teaching half
   of its own subject. The shape is asserted, not merely the presence, because
   the claim the section makes on screen is that the ring costs no layout — a
   focused override that widened the border would light up just as brightly and
   nudge everything after it. *)
let focus_ring node =
  let open Nopal_style in
  match interaction node with
  | None -> None
  | Some i -> (
      match i.Interaction.focused with
      | None -> None
      | Some style -> style.Style.paint.shadow)

let test_container_carries_a_focus_ring () =
  match find container (tree (rendered_for (after []))) with
  | None -> Alcotest.fail "the section renders no container to focus"
  | Some node -> (
      match focus_ring node with
      | None ->
          Alcotest.fail
            "the container carries no focused shadow, so the one section about \
             keyboard focus shows a keyboard user nothing when focus arrives"
      | Some shadow ->
          let open Nopal_style in
          Alcotest.(check (list (float 0.001)))
            "the ring sits at no offset and carries no blur, so it reads as a \
             ring rather than a drop shadow"
            [ 0.0; 0.0; 0.0 ]
            [ shadow.Style.x; shadow.y; shadow.blur ];
          Alcotest.(check bool)
            "and its width comes from the spread, which paints outside the box \
             without displacing anything after it"
            true
            (shadow.Style.spread > 0.0))

(* Focus arriving reveals the note and counts an edge. The initial arm is not
   decoration: without it a view that rendered the note unconditionally would
   satisfy every other assertion in this file. *)
let test_focus_reveals_panel () =
  let base = after [] in
  Alcotest.(check bool)
    "the note is on screen before focus has arrived anywhere" false
    (note_shown base);
  Alcotest.(check string)
    "and the section starts with nothing revealed and no edge reported"
    "focus_note=false; focus_edges=0; focus_ack=false;"
    (Sub.serialize_model base);
  let arrived = after [ focus_edge base ] in
  Alcotest.(check bool)
    "the arrival puts the note on screen" true (note_shown arrived);
  Alcotest.(check string)
    "and the model records the reveal and exactly one edge"
    "focus_note=true; focus_edges=1; focus_ack=false;"
    (Sub.serialize_model arrived)

(* Focus leaving takes the note away and counts a second edge. The count is what
   separates a departure from a return to the initial state: an update arm that
   hid the note by resetting the section would leave the note gone and the count
   at zero, and would pass a test that read the reveal flag alone. *)
let test_blur_hides_panel () =
  let base = after [] in
  let arrival = focus_edge base in
  let arrived = after [ arrival ] in
  Alcotest.(check bool)
    "the note is on screen for the departure to take away" true
    (note_shown arrived);
  let departed = after [ arrival; blur_edge arrived ] in
  Alcotest.(check bool)
    "the departure takes the note off screen" false (note_shown departed);
  Alcotest.(check string)
    "and the model records the second edge rather than starting over"
    "focus_note=false; focus_edges=2; focus_ack=false;"
    (Sub.serialize_model departed)

(* The control inside the note. It is the reason the container has a focusable
   descendant at all, and the only message that changes what the control reads,
   so without this case the label's two branches are both dead. The labels are
   compared whole rather than by substring: "Acknowledge" is a prefix of
   "Acknowledged", so a containment check would pass on either. *)
let test_the_note_is_acknowledged () =
  let base = after [] in
  let arrival = focus_edge base in
  let revealed = after [ arrival ] in
  Alcotest.(check string)
    "the control invites the reader to use it before it has been used"
    "Acknowledge" (ack_label revealed);
  let acknowledged = after [ arrival; acknowledge revealed ] in
  Alcotest.(check string)
    "using it records the acknowledgement and leaves the reveal and the count"
    "focus_note=true; focus_edges=1; focus_ack=true;"
    (Sub.serialize_model acknowledged);
  Alcotest.(check string)
    "and the control now reads back as used" "Acknowledged"
    (ack_label acknowledged)

(* The reset clears the count and the acknowledgement and deliberately leaves
   the reveal alone, which is what makes the reveal's single writer the two
   focus edges. It is run from a revealed, acknowledged, counted state, because
   from the initial state a reset that also cleared the reveal would be
   indistinguishable from one that did not. The browser spec starts every run
   from this control, so a reset that touched the reveal would move that spec's
   starting point without failing anything. *)
let test_reset_leaves_the_reveal_alone () =
  let base = after [] in
  let arrival = focus_edge base in
  let revealed = after [ arrival ] in
  let acknowledged = after [ arrival; acknowledge revealed ] in
  Alcotest.(check string)
    "the reset runs from a state with all three fields set away from their \
     initial values"
    "focus_note=true; focus_edges=1; focus_ack=true;"
    (Sub.serialize_model acknowledged);
  let cleared = after [ arrival; acknowledge revealed; reset acknowledged ] in
  Alcotest.(check bool)
    "the note the focus edge revealed is still on screen after the reset" true
    (note_shown cleared);
  Alcotest.(check string)
    "and the reset clears the count and the acknowledgement, not the reveal"
    "focus_note=true; focus_edges=0; focus_ack=false;"
    (Sub.serialize_model cleared)

let () =
  Alcotest.run "kitchen_sink_focus_reveal_section"
    [
      ( "focus edges",
        [
          Alcotest.test_case "focus reveals the panel" `Quick
            test_focus_reveals_panel;
          Alcotest.test_case "blur hides the panel" `Quick test_blur_hides_panel;
        ] );
      ( "focusability",
        [
          Alcotest.test_case "the container is a tab stop" `Quick
            test_container_is_focusable;
          Alcotest.test_case "the container shows a focus ring" `Quick
            test_container_carries_a_focus_ring;
        ] );
      ( "the section's controls",
        [
          Alcotest.test_case "the note is acknowledged" `Quick
            test_the_note_is_acknowledged;
          Alcotest.test_case "the reset leaves the reveal alone" `Quick
            test_reset_leaves_the_reveal_alone;
        ] );
    ]
