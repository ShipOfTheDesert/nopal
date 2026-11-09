(* The switch kitchen-sink section, read structurally through the whole kitchen
   sink so the section's registration is under test too.

   What this file can see is the three switches' role, state, description and
   texts, the message a press asks for, and the navigation [update] answers the
   hint link with, run against a platform that records what is pushed. What it
   cannot see is the knob moving, the ring, a keyboard press or a browser
   following the link — that is the browser spec's job. The expected ids, texts
   and addresses are written out here from the requested section, never read
   back from it. *)

open Nopal_test.Test_renderer
module Link = Nopal_element.Link
module Sub = Kitchen_sink_app.Sub_switch

(* mutable: the recording platform stub appends each path the router pushes;
   a test reads it back after following the link. *)
let pushed = ref []

module Recording_platform : Nopal_platform.Platform.S = struct
  let current_path () = "/kitchen_sink/"
  let push_state path = pushed := !pushed @ [ path ]
  let replace_state (_ : string) = ()
  let back () = ()
  let on_popstate (_ : string -> unit) () = ()

  module Store = Nopal_storage.In_memory ()

  let storage = (module Store : Nopal_storage.S)
end

module K = Kitchen_sink_app.Make (Recording_platform)

let vp = Nopal_element.Viewport.desktop
let label_text = "Send an alert when it goes silent"
let reason_text = "Needs a silence threshold."
let host_hint_text = "Delivering to alerts.example.com"
let dropped_link_path = "/kitchen_sink/?switch=dropped-alerts"
let starts_on = "switch-starts-on"
let starts_off = "switch-starts-off"
let disabled = "switch-disabled"

let plain_primary =
  {
    Link.button = Link.Primary;
    ctrl = false;
    meta = false;
    shift = false;
    alt = false;
  }

let model0 () = fst (K.init ())

let node_in what selector node =
  match find selector node with
  | Some found -> found
  | None -> Alcotest.fail (what ^ ": no such element")

let section_of rendered =
  node_in "the switch section"
    (By_attr ("data-testid", "switch-section"))
    (tree rendered)

let by_id id = By_attr ("id", id)

(* Each switch's id, [aria-checked] and [aria-disabled], in page order. *)
let switch_states section =
  List.map
    (fun node ->
      (attr "id" node, attr "aria-checked" node, attr "aria-disabled" node))
    (find_all (By_attr ("role", "switch")) section)

let state_testable =
  Alcotest.(list (triple (option string) (option string) (option string)))

let three_states_render_with_their_aria_checked () =
  let section = section_of (render (K.view vp (model0 ()))) in
  Alcotest.check state_testable "on, off, and disabled off, in that order"
    [
      (Some starts_on, Some "true", None);
      (Some starts_off, Some "false", None);
      (Some disabled, Some "false", Some "true");
    ]
    (switch_states section);
  List.iter
    (fun id ->
      Alcotest.(check string)
        (id ^ ": the switch is a button")
        "button"
        (Test_util.tag_of id (node_in id (by_id id) section)))
    [ starts_on; starts_off; disabled ];
  Alcotest.(check (list (pair (option string) string)))
    "each switch is named by the same visible label"
    [
      (Some starts_on, label_text);
      (Some starts_off, label_text);
      (Some disabled, label_text);
    ]
    (List.map
       (fun label -> (attr "for" label, text_content label))
       (find_all (By_tag "label") section))

(* The absence of a dispatch is read against the same section, where the
   enabled switch's press does dispatch, so the empty list is the disabled
   state's doing and not a press that reached nothing. *)
let disabled_state_carries_the_reason () =
  let rendered = render (K.view vp (model0 ())) in
  let section = section_of rendered in
  Alcotest.(check string)
    "the reason is visible text beside the disabled switch" reason_text
    (text_content
       (node_in "the reason box" (by_id (disabled ^ "-reason")) section));
  Alcotest.(check (option string))
    "the disabled switch is described by the reason, then the hint"
    (Some (disabled ^ "-reason " ^ disabled ^ "-hint"))
    (attr "aria-describedby" (node_in disabled (by_id disabled) section));
  Alcotest.(check int)
    "no enabled switch shows a reason" 0
    (List.length
       (List.filter_map
          (fun id -> find (by_id (id ^ "-reason")) section)
          [ starts_on; starts_off ]));
  (match click (by_id disabled) rendered with
  | Error (No_handler _) -> ()
  | Ok () -> Alcotest.fail "a press on the disabled switch was answered"
  | Error (Not_found _) -> Alcotest.fail "the disabled switch is missing");
  (match click (By_attr ("for", disabled)) rendered with
  | Error (No_handler _) -> ()
  | Ok () -> Alcotest.fail "a press on the disabled switch's label was answered"
  | Error (Not_found _) ->
      Alcotest.fail "the disabled switch's label is missing");
  Alcotest.(check int)
    "neither press dispatches anything" 0
    (List.length (messages rendered));
  (match click (by_id starts_off) rendered with
  | Ok () -> ()
  | Error (No_handler _) -> Alcotest.fail "the enabled switch has no handler"
  | Error (Not_found _) -> Alcotest.fail "the enabled switch is missing");
  Alcotest.(check int)
    "the enabled switch's press in the same section dispatches" 1
    (List.length (messages rendered))

let hint_link_is_present () =
  pushed := [];
  let model = model0 () in
  let rendered = render (K.view vp model) in
  let section = section_of rendered in
  Alcotest.(check string)
    "the switch that starts on carries the delivery hint" host_hint_text
    (text_content
       (node_in "the delivery hint" (by_id (starts_on ^ "-hint")) section));
  Alcotest.(check (option string))
    "the switch that starts on is described by its hint alone"
    (Some (starts_on ^ "-hint"))
    (attr "aria-describedby" (node_in starts_on (by_id starts_on) section));
  let hint =
    node_in "the dropped-alerts hint" (by_id (disabled ^ "-hint")) section
  in
  Alcotest.(check bool)
    "the disabled switch's hint says alerts are being dropped" true
    (Test_util.string_contains (text_content hint)
       ~sub:"alerts are being dropped");
  let link = node_in "the hint's link" (By_tag "a") hint in
  Alcotest.(check (option string))
    "the hint's link points at a kitchen-sink route" (Some dropped_link_path)
    (attr "href" link);
  let link_selector = By_attr ("data-testid", "switch-dropped-alerts-link") in
  Alcotest.(check (option string))
    "the hint's link is the one the browser spec reaches"
    (Some dropped_link_path)
    (attr "href" (node_in "the hint's link by test id" link_selector hint));
  (match click_link ~host:Link.Browser plain_primary link_selector rendered with
  | Ok (Link.Navigate _) -> ()
  | Ok Link.Leave_to_platform ->
      Alcotest.fail "a plain click on the hint's link was left to the browser"
  | Ok (Link.Open_externally _) ->
      Alcotest.fail "a plain click on the hint's link opened externally"
  | Error (Not_found _) -> Alcotest.fail "the hint's link is missing"
  | Error (No_handler { tag; event }) ->
      Alcotest.failf "the hint's link is a %s with no %s" tag event);
  let followed =
    match messages rendered with
    | [ K.Switch_msg msg ] -> msg
    | msgs ->
        Alcotest.failf
          "the click dispatched %d messages, expected one switch msg"
          (List.length msgs)
  in
  Alcotest.(check string)
    "the click dispatches the follow message" "Switch:Dropped_alerts_followed;"
    (Sub.serialize_msg followed);
  Alcotest.(check (list string)) "the click itself pushes nothing" [] !pushed;
  let _, cmd = K.update model (K.Switch_msg followed) in
  Nopal_mvu.Cmd.execute (fun (_ : K.msg) -> ()) cmd;
  Alcotest.(check (list string))
    "update pushes the link's address" [ dropped_link_path ] !pushed

(* A press goes through the whole kitchen sink: the view's message, then the
   kitchen sink's update, then the view again. *)
let press id model =
  let rendered = render (K.view vp model) in
  (match click (by_id id) rendered with
  | Ok () -> ()
  | Error (No_handler _) -> Alcotest.fail (id ^ ": the switch has no handler")
  | Error (Not_found _) -> Alcotest.fail (id ^ ": the switch is missing"));
  match messages rendered with
  | [ K.Switch_msg msg ] -> (msg, fst (K.update model (K.Switch_msg msg)))
  | msgs ->
      Alcotest.failf
        "%s: the press dispatched %d messages, expected one switch msg" id
        (List.length msgs)

let serialized = Sub.serialize_msg

let toggle_message_reaches_update_and_flips_state () =
  let states model = switch_states (section_of (render (K.view vp model))) in
  let msg, after_off = press starts_on (model0 ()) in
  Alcotest.(check string)
    "pressing the on switch asks for off" "Switch:Starts_on_toggled:false;"
    (serialized msg);
  Alcotest.check state_testable "the on switch is now off, the others unchanged"
    [
      (Some starts_on, Some "false", None);
      (Some starts_off, Some "false", None);
      (Some disabled, Some "false", Some "true");
    ]
    (states after_off);
  let msg, after_on = press starts_on after_off in
  Alcotest.(check string)
    "pressing it again asks for on" "Switch:Starts_on_toggled:true;"
    (serialized msg);
  let msg, both_on = press starts_off after_on in
  Alcotest.(check string)
    "pressing the off switch asks for on" "Switch:Starts_off_toggled:true;"
    (serialized msg);
  Alcotest.check state_testable "both enabled switches are on"
    [
      (Some starts_on, Some "true", None);
      (Some starts_off, Some "true", None);
      (Some disabled, Some "false", Some "true");
    ]
    (states both_on)

let () =
  Alcotest.run "Switch section"
    [
      ( "switch",
        [
          Alcotest.test_case "three_states_render_with_their_aria_checked"
            `Quick three_states_render_with_their_aria_checked;
          Alcotest.test_case "disabled_state_carries_the_reason" `Quick
            disabled_state_carries_the_reason;
          Alcotest.test_case "hint_link_is_present" `Quick hint_link_is_present;
          Alcotest.test_case "toggle_message_reaches_update_and_flips_state"
            `Quick toggle_message_reaches_update_and_flips_state;
        ] );
    ]
