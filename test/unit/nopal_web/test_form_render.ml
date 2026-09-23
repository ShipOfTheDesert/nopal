(* Renderer coverage for the [Form] element: the node and children it creates,
   the attributes it derives, the submit listener it wires, the axis it hands
   its children, and what a reconcile patches.

   Runs under dom_shim.js, which reproduces the platform's form-submission
   default: an Enter in a text field and a submit-button click submit the
   nearest form, and a submission no listener cancels is recorded in
   [document._navigations]. Every case that asserts "did not navigate" reads
   that record before and after, and one case builds a bare DOM form outside the
   renderer to show the record does move when nothing cancels — so an unchanged
   count is the renderer's doing, not a shim that never navigates.

   Every assertion on what was dispatched checks the whole ordered list, so a
   double dispatch and a dropped one both fail. *)

open Nopal_element.Element

type msg =
  | Form_submitted
  | Other_form_submitted
  | Field_submitted
  | Clicked
  | Twin_clicked

let msg_to_string = function
  | Form_submitted -> "Form_submitted"
  | Other_form_submitted -> "Other_form_submitted"
  | Field_submitted -> "Field_submitted"
  | Clicked -> "Clicked"
  | Twin_clicked -> "Twin_clicked"

let equal_msg a b =
  match (a, b) with
  | Form_submitted, Form_submitted
  | Other_form_submitted, Other_form_submitted
  | Field_submitted, Field_submitted
  | Clicked, Clicked
  | Twin_clicked, Twin_clicked ->
      true
  | ( ( Form_submitted | Other_form_submitted | Field_submitted | Clicked
      | Twin_clicked ),
      _ ) ->
      false

let msg_testable =
  Alcotest.testable
    (fun ppf m -> Format.pp_print_string ppf (msg_to_string m))
    equal_msg

let check_dispatched label expected msgs =
  Alcotest.(check (list msg_testable)) label expected (List.rev !msgs)

let fresh_dispatch () =
  let msgs = ref [] in
  let dispatch msg = msgs := msg :: !msgs in
  (dispatch, msgs)

let fresh_parent () = Brr.El.v (Jstr.v "div") []

(* ---- fixtures: every field spelled out, nothing inherited ---- *)

(* [default_layout] is all-[None] and carries no behaviour; the paint fields
   carry concrete values, so they are written out rather than inherited. *)
let style_with layout =
  Nopal_style.Style.
    {
      layout;
      paint =
        {
          background = None;
          border = None;
          opacity = 1.0;
          shadow = None;
          overflow = Visible;
        };
      text = default_text;
    }

let no_layout = style_with Nopal_style.Style.default_layout

let across =
  style_with
    {
      Nopal_style.Style.default_layout with
      direction = Some Nopal_style.Style.Row_dir;
    }

let padded =
  style_with { Nopal_style.Style.default_layout with padding_left = Some 8.0 }

let no_interaction =
  Nopal_style.Interaction.{ hover = None; pressed = None; focused = None }

let hover_interaction =
  Nopal_style.Interaction.
    { hover = Some padded; pressed = None; focused = None }

let form ~style ~interaction ~attrs ~on_submit ~autocomplete ~novalidate
    children =
  Form
    { style; interaction; attrs; children; on_submit; autocomplete; novalidate }

(* A form that authors nothing of its own: no submission, no autocomplete, no
   novalidate. *)
let unauthored_form children =
  form ~style:no_layout ~interaction:no_interaction ~attrs:[] ~on_submit:None
    ~autocomplete:None ~novalidate:false children

let submitting_form ~on_submit children =
  form ~style:no_layout ~interaction:no_interaction ~attrs:[]
    ~on_submit:(Some on_submit) ~autocomplete:None ~novalidate:false children

let text_input ~on_submit ~on_keydown =
  Input
    {
      style = no_layout;
      interaction = no_interaction;
      attrs = [];
      value = "";
      placeholder = "";
      on_change = None;
      on_submit;
      on_focus = None;
      on_blur = None;
      on_keydown;
      required = false;
      autocomplete = None;
      input_type = None;
    }

let bare_input () = text_input ~on_submit:None ~on_keydown:None

let input_with_value ~input_type value =
  Input
    {
      style = no_layout;
      interaction = no_interaction;
      attrs = [];
      value;
      placeholder = "";
      on_change = None;
      on_submit = None;
      on_focus = None;
      on_blur = None;
      on_keydown = None;
      required = false;
      autocomplete = None;
      input_type;
    }

let button ~button_type ~disabled ~attrs ~on_click =
  Button
    {
      style = no_layout;
      interaction = no_interaction;
      attrs;
      button_type;
      disabled;
      on_click;
      on_dblclick = None;
      child = Text { content = "Go"; text_style = None };
    }

(* ---- DOM helpers ---- *)

let tag_of jv =
  Jv.Jstr.get jv "nodeName" |> Jstr.to_string |> String.uppercase_ascii

let children_of node = Jv.to_jv_list (Jv.get node "childNodes")

let nth_child node i =
  match List.nth_opt (children_of node) i with
  | Some child -> child
  | None -> Alcotest.failf "the form has no child at index %d" i

let value_of node = Jv.Jstr.get node "value" |> Jstr.to_string

let attr node name =
  let v = Jv.call node "getAttribute" [| Jv.of_string name |] in
  if Jv.is_null v then None else Some (Jv.to_string v)

let navigations () =
  Jv.Int.get (Jv.get (Jv.get Jv.global "document") "_navigations") "length"

let press_enter node =
  let ev =
    Jv.new'
      (Jv.get Jv.global "KeyboardEvent")
      [|
        Jv.of_string "keydown";
        Jv.obj [| ("key", Jv.of_string "Enter"); ("cancelable", Jv.true') |];
      |]
  in
  ignore (Jv.call node "dispatchEvent" [| ev |])

let click node =
  let ev =
    Jv.new' (Jv.get Jv.global "Event")
      [|
        Jv.of_string "click";
        Jv.obj [| ("bubbles", Jv.true'); ("cancelable", Jv.true') |];
      |]
  in
  ignore (Jv.call node "dispatchEvent" [| ev |])

let render element =
  let dispatch, msgs = fresh_dispatch () in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent:(fresh_parent ()) element
  in
  (handle, Nopal_web.Renderer.dom_node handle, msgs, dispatch)

let inline node property =
  Jv.Jstr.get (Jv.get node "style") property |> Jstr.to_string

let class_list node =
  Jv.to_string (Jv.call (Jv.get node "classList") "toString" [||])

(* ---- create ---- *)

let test_renders_a_form_node_with_its_children () =
  let _handle, node, _msgs, _dispatch =
    render
      (form ~style:padded ~interaction:no_interaction
         ~attrs:[ ("aria-label", "Sign in") ]
         ~on_submit:None ~autocomplete:None ~novalidate:false
         [
           bare_input ();
           button ~button_type:Push ~disabled:false ~attrs:[] ~on_click:None;
         ])
  in
  Alcotest.(check string) "the node is a form" "FORM" (tag_of node);
  Alcotest.(check (list string))
    "its children are created inside it, in order" [ "INPUT"; "BUTTON" ]
    (List.map tag_of (children_of node));
  Alcotest.(check string)
    "it is a flex container" "flex" (inline node "display");
  Alcotest.(check string)
    "laid out down the page when the style names no direction" "column"
    (inline node "flex-direction");
  Alcotest.(check string)
    "its style reached the node" "8px"
    (inline node "padding-left");
  Alcotest.(check (option string))
    "its declared attributes reached the node" (Some "Sign in")
    (attr node "aria-label");
  Alcotest.(check string) "no interaction, no class" "" (class_list node);
  let _handle, across_node, _msgs, _dispatch =
    render
      (form ~style:across ~interaction:no_interaction ~attrs:[] ~on_submit:None
         ~autocomplete:None ~novalidate:false [])
  in
  Alcotest.(check string)
    "a style asking for a row lays out across" "row"
    (inline across_node "flex-direction");
  let _handle, interactive_node, _msgs, _dispatch =
    render
      (form ~style:padded ~interaction:hover_interaction ~attrs:[]
         ~on_submit:None ~autocomplete:None ~novalidate:false [])
  in
  Alcotest.(check bool)
    "an interaction is styled through an injected class" true
    (not (String.equal "" (class_list interactive_node)))

let test_an_unauthored_form_neither_dispatches_nor_navigates () =
  let _handle, node, msgs, _dispatch =
    render
      (unauthored_form
         [
           bare_input ();
           button ~button_type:Submit ~disabled:false ~attrs:[] ~on_click:None;
         ])
  in
  Alcotest.(check (option string))
    "no autocomplete is emitted" None (attr node "autocomplete");
  Alcotest.(check (option string))
    "no novalidate is emitted" None (attr node "novalidate");
  let before = navigations () in
  press_enter (nth_child node 0);
  click (nth_child node 1);
  check_dispatched "Enter and a submit-button click dispatch nothing" [] msgs;
  Alcotest.(check int) "and neither navigates away" before (navigations ());
  (* Affirmative arm on the same shape: the same field and button in a form the
     renderer did not build, so nothing cancels its submission. Both navigate,
     which is what makes the unchanged count above the renderer's doing. *)
  let raw_input = Brr.El.v (Jstr.v "input") [] in
  let raw_button = Brr.El.v (Jstr.v "button") [] in
  let _raw_form = Brr.El.v (Jstr.v "form") [ raw_input; raw_button ] in
  let before_raw = navigations () in
  press_enter (Brr.El.to_jv raw_input);
  click (Brr.El.to_jv raw_button);
  Alcotest.(check int)
    "an uncancelled form navigates on each" (before_raw + 2) (navigations ());
  (* And the two derivations do reach the node when authored. *)
  let _handle, authored, _msgs, _dispatch =
    render
      (form ~style:no_layout ~interaction:no_interaction ~attrs:[]
         ~on_submit:None ~autocomplete:(Some Off) ~novalidate:true [])
  in
  Alcotest.(check (option string))
    "an authored autocomplete is emitted" (Some "off")
    (attr authored "autocomplete");
  Alcotest.(check (option string))
    "an authored novalidate is emitted" (Some "")
    (attr authored "novalidate")

(* ---- the submit listener ---- *)

let test_enter_in_a_bare_field_submits_once_and_does_not_navigate () =
  (* One text field and no button: the platform submits the form directly. *)
  let _handle, node, msgs, _dispatch =
    render (submitting_form ~on_submit:Form_submitted [ bare_input () ])
  in
  let before = navigations () in
  press_enter (nth_child node 0);
  check_dispatched "the form's message, once" [ Form_submitted ] msgs;
  Alcotest.(check int) "and no navigation" before (navigations ())

let test_submit_button_click_submits_once_and_does_not_navigate () =
  let _handle, node, msgs, _dispatch =
    render
      (submitting_form ~on_submit:Form_submitted
         [
           bare_input ();
           button ~button_type:Submit ~disabled:false ~attrs:[] ~on_click:None;
         ])
  in
  let before = navigations () in
  click (nth_child node 1);
  check_dispatched "a submit-button click dispatches the form's message once"
    [ Form_submitted ] msgs;
  Alcotest.(check int) "and does not navigate" before (navigations ())

let test_untyped_button_in_form_answers_its_own_click_only () =
  let _handle, node, msgs, _dispatch =
    render
      (submitting_form ~on_submit:Form_submitted
         [
           bare_input ();
           button ~button_type:Push ~disabled:false ~attrs:[]
             ~on_click:(Some Clicked);
           button ~button_type:Push ~disabled:false
             ~attrs:[ ("type", "submit") ]
             ~on_click:(Some Twin_clicked);
           button ~button_type:Submit ~disabled:false ~attrs:[] ~on_click:None;
         ])
  in
  let before = navigations () in
  click (nth_child node 1);
  check_dispatched "a button that names no type answers its own click only"
    [ Clicked ] msgs;
  click (nth_child node 2);
  check_dispatched "a caller's submit type pair does not make it submit"
    [ Clicked; Twin_clicked ] msgs;
  (* Affirmative arm on the same form: a button typed to submit does reach the
     form's listener, so the silence above is the type answering. *)
  click (nth_child node 3);
  check_dispatched "a submit-typed button in the same form submits it"
    [ Clicked; Twin_clicked; Form_submitted ]
    msgs;
  Alcotest.(check int) "none of it navigated" before (navigations ())

let test_submit_typed_button_click_dispatches_click_then_form () =
  let _handle, node, msgs, _dispatch =
    render
      (submitting_form ~on_submit:Form_submitted
         [
           bare_input ();
           button ~button_type:Submit ~disabled:false ~attrs:[]
             ~on_click:(Some Clicked);
         ])
  in
  let before = navigations () in
  click (nth_child node 1);
  check_dispatched "the button's own message, then the form's"
    [ Clicked; Form_submitted ]
    msgs;
  Alcotest.(check int) "and does not navigate" before (navigations ())

(* The disabled button and its enabled twin share one form, so the twin's
   submission shows the form is listening and the disabled button's silence is
   its own. *)
let test_disabled_submit_button_click_dispatches_nothing_and_does_not_submit ()
    =
  let _handle, node, msgs, _dispatch =
    render
      (submitting_form ~on_submit:Form_submitted
         [
           bare_input ();
           button ~button_type:Submit ~disabled:true ~attrs:[]
             ~on_click:(Some Clicked);
           button ~button_type:Submit ~disabled:false ~attrs:[]
             ~on_click:(Some Twin_clicked);
         ])
  in
  let before = navigations () in
  click (nth_child node 1);
  check_dispatched "a disabled submit button dispatches nothing" [] msgs;
  click (nth_child node 2);
  check_dispatched "its enabled twin dispatches its click, then the form's"
    [ Twin_clicked; Form_submitted ]
    msgs;
  Alcotest.(check int) "and nothing navigated" before (navigations ())

let one_field_form ~disabled =
  submitting_form ~on_submit:Form_submitted
    [
      bare_input ();
      button ~button_type:Submit ~disabled ~attrs:[] ~on_click:(Some Clicked);
    ]

let test_enter_in_field_with_disabled_default_button_submits_nothing () =
  let _handle, node, msgs, _dispatch = render (one_field_form ~disabled:true) in
  let before = navigations () in
  press_enter (nth_child node 0);
  check_dispatched "Enter clicks the disabled default button, which is inert" []
    msgs;
  Alcotest.(check int) "and nothing navigated" before (navigations ());
  let _handle, enabled_node, enabled_msgs, _dispatch =
    render (one_field_form ~disabled:false)
  in
  press_enter (nth_child enabled_node 0);
  check_dispatched "with the button enabled, Enter clicks it and submits"
    [ Clicked; Form_submitted ]
    enabled_msgs

(* The default button is the first submit button in tree order, so a disabled
   one placed first blocks Enter even though an enabled one follows it. The
   affirmative arm swaps the two and nothing else. *)
let test_disabled_before_enabled_submit_button_blocks_enter () =
  let two_buttons ~first_disabled =
    submitting_form ~on_submit:Form_submitted
      [
        bare_input ();
        button ~button_type:Submit ~disabled:first_disabled ~attrs:[]
          ~on_click:(Some Clicked);
        button ~button_type:Submit ~disabled:(not first_disabled) ~attrs:[]
          ~on_click:(Some Twin_clicked);
      ]
  in
  let _handle, node, msgs, _dispatch =
    render (two_buttons ~first_disabled:true)
  in
  press_enter (nth_child node 0);
  check_dispatched "a disabled default button blocks Enter" [] msgs;
  let _handle, swapped, swapped_msgs, _dispatch =
    render (two_buttons ~first_disabled:false)
  in
  press_enter (nth_child swapped 0);
  check_dispatched "an enabled default button answers Enter"
    [ Clicked; Form_submitted ]
    swapped_msgs

let test_input_on_submit_inside_a_form_dispatches_once () =
  (* The submit button is what lets Enter in a form of two text fields submit it
     at all, so the bare field below has a route to the form. *)
  let _handle, node, msgs, _dispatch =
    render
      (submitting_form ~on_submit:Form_submitted
         [
           text_input ~on_submit:(Some Field_submitted) ~on_keydown:None;
           bare_input ();
           button ~button_type:Submit ~disabled:false ~attrs:[] ~on_click:None;
         ])
  in
  let before = navigations () in
  press_enter (nth_child node 0);
  check_dispatched "the field's own message and not the form's"
    [ Field_submitted ] msgs;
  (* Affirmative arm on the same fixture: the form does submit for a field that
     answers nothing itself. *)
  press_enter (nth_child node 1);
  check_dispatched "a bare field in the same form submits the form"
    [ Field_submitted; Form_submitted ]
    msgs;
  Alcotest.(check int) "and nothing navigated" before (navigations ())

(* ---- the axis a form hands its children ---- *)

let fixed_width_child () =
  Box
    {
      style =
        style_with
          {
            Nopal_style.Style.default_layout with
            width = Some (Nopal_style.Style.Fixed 120.);
          };
      interaction = no_interaction;
      attrs = [];
      children = [];
      focusable = false;
      on_focus = None;
      on_blur = None;
      on_pointer_move = None;
      on_pointer_leave = None;
      on_pointer_down = None;
      on_pointer_up = None;
      on_wheel = None;
    }

let fixed_height_child () =
  Box
    {
      style =
        style_with
          {
            Nopal_style.Style.default_layout with
            height = Some (Nopal_style.Style.Fixed 96.);
          };
      interaction = no_interaction;
      attrs = [];
      children = [];
      focusable = false;
      on_focus = None;
      on_blur = None;
      on_pointer_move = None;
      on_pointer_leave = None;
      on_pointer_down = None;
      on_pointer_up = None;
      on_wheel = None;
    }

let test_a_fixed_child_of_a_form_does_not_shrink () =
  let _handle, down_node, _msgs, _dispatch =
    render (unauthored_form [ fixed_height_child (); fixed_width_child () ])
  in
  Alcotest.(check string)
    "a fixed height down a form is guarded" "0"
    (inline (nth_child down_node 0) "flex-shrink");
  (* Affirmative arm: the width reached the child and, being across a column,
     is not guarded — so the guard above is the axis answering, not a constant. *)
  Alcotest.(check string)
    "the declared width reached the child" "120px"
    (inline (nth_child down_node 1) "width");
  Alcotest.(check string)
    "a fixed width across a form is not guarded" ""
    (inline (nth_child down_node 1) "flex-shrink");
  let _handle, across_node, _msgs, _dispatch =
    render
      (form ~style:across ~interaction:no_interaction ~attrs:[] ~on_submit:None
         ~autocomplete:None ~novalidate:false
         [ fixed_width_child () ])
  in
  Alcotest.(check string)
    "a fixed width along a form laid out across is guarded" "0"
    (inline (nth_child across_node 0) "flex-shrink")

(* ---- reconcile ---- *)

(* Rebuilt per frame, never shared, as a view does: the reconcile compares
   structurally, and a shared value would hide a guard comparing by identity. *)
let frame ~on_submit ~autocomplete ~novalidate =
  form ~style:no_layout ~interaction:no_interaction
    ~attrs:[ ("autocomplete", "on") ]
    ~on_submit ~autocomplete ~novalidate
    [ bare_input () ]

let test_reconcile_updates_autocomplete_novalidate_and_on_submit () =
  let handle, node, msgs, dispatch =
    render
      (frame ~on_submit:(Some Form_submitted) ~autocomplete:None
         ~novalidate:false)
  in
  Alcotest.(check (option string))
    "an absent typed autocomplete leaves the declared pair standing" (Some "on")
    (attr node "autocomplete");
  Alcotest.(check (option string))
    "no novalidate at first" None (attr node "novalidate");
  let before = navigations () in
  Nopal_web.Renderer.update ~dispatch handle
    (frame ~on_submit:(Some Other_form_submitted) ~autocomplete:(Some Off)
       ~novalidate:true);
  Alcotest.(check bool)
    "the form node is reconciled in place" true
    (Nopal_web.Renderer.dom_node handle == node);
  Alcotest.(check (option string))
    "an authored autocomplete replaces the declared pair" (Some "off")
    (attr node "autocomplete");
  Alcotest.(check (option string))
    "novalidate is added" (Some "") (attr node "novalidate");
  press_enter (nth_child node 0);
  check_dispatched "the new on_submit answers, once" [ Other_form_submitted ]
    msgs;
  Nopal_web.Renderer.update ~dispatch handle
    (frame ~on_submit:None ~autocomplete:None ~novalidate:false);
  Alcotest.(check (option string))
    "withdrawing autocomplete uncovers the declared pair" (Some "on")
    (attr node "autocomplete");
  Alcotest.(check (option string))
    "novalidate is removed" None (attr node "novalidate");
  press_enter (nth_child node 0);
  check_dispatched "a withdrawn on_submit dispatches nothing more"
    [ Other_form_submitted ] msgs;
  Alcotest.(check int)
    "and no frame's submission navigated" before (navigations ())

(* Mirrors [test_input_typed_fields_survive_caller_pairs_arriving_on_update] in
   test_attr_precedence.ml: the re-assert guard is held still across two
   frames, so only a still typed field can tell the guard apart from its
   absence. Frame 1 authors no attrs; frame 2 adds conflicting
   ["autocomplete"]/["novalidate"] pairs while the typed values stay the same.
   A mutation dropping the guard's [not attrs_written] conjunct lets the
   caller's pairs win here, because [attrs_written] is only true when the
   declared list itself changed. *)
let test_form_typed_fields_survive_caller_pairs_arriving_on_update () =
  let first =
    form ~style:no_layout ~interaction:no_interaction ~attrs:[] ~on_submit:None
      ~autocomplete:(Some On) ~novalidate:true
      [ bare_input () ]
  in
  let second =
    form ~style:no_layout ~interaction:no_interaction
      ~attrs:[ ("autocomplete", "off"); ("novalidate", "") ]
      ~on_submit:None ~autocomplete:(Some On) ~novalidate:true
      [ bare_input () ]
  in
  let handle, node, _msgs, dispatch = render first in
  Nopal_web.Renderer.update ~dispatch handle second;
  Alcotest.(check (option string))
    "the typed autocomplete is re-asserted over the caller's conflicting pair"
    (Some "on") (attr node "autocomplete");
  Alcotest.(check (option string))
    "the typed novalidate is re-asserted over the caller's conflicting pair"
    (Some "") (attr node "novalidate")

(* A type change with a value present, on reconcile: [apply_input_config] must
   run before the ["value"] write, or the browser's own type-based
   sanitisation clears a value that does not fit the new type. dom_shim models
   the one rule this depends on: setting ["type"] to ["number"] sanitises the
   element's CURRENT value if it is not a valid number (see dom_shim.js). With
   [apply_input_config] first, that sanitisation fires against the stale
   Plain-typed value before the new value is written, so the fresh write lands
   after it; the reconcile guard's own [dom_value] read must also happen after
   [apply_input_config], or it compares against the value from before
   sanitisation ran and wrongly concludes the write is redundant. *)
(* The same guarantee at creation: [apply_input_config] must run before the
   ["value"] write there too, or a number input created with a non-numeric
   model value would have the browser sanitise it away before the write ever
   lands. *)
let test_a_number_input_created_with_a_non_numeric_value_keeps_it () =
  let _handle, node, _msgs, _dispatch =
    render (input_with_value ~input_type:(Some Number) "not-a-number")
  in
  Alcotest.(check (option string))
    "the type is number" (Some "number") (attr node "type");
  Alcotest.(check string)
    "the value is not sanitised away" "not-a-number" (value_of node)

let test_input_type_change_with_a_value_present_survives_reconcile () =
  let handle, node, _msgs, dispatch =
    render (input_with_value ~input_type:(Some Plain) "not-a-number")
  in
  Alcotest.(check string)
    "the initial value is written" "not-a-number" (value_of node);
  Nopal_web.Renderer.update ~dispatch handle
    (input_with_value ~input_type:(Some Number) "not-a-number");
  Alcotest.(check (option string))
    "the type is updated" (Some "number") (attr node "type");
  Alcotest.(check string)
    "the value survives the type change" "not-a-number" (value_of node)

let () =
  Alcotest.run "Form render"
    [
      ( "form",
        [
          Alcotest.test_case "renders_a_form_node_with_its_children" `Quick
            test_renders_a_form_node_with_its_children;
          Alcotest.test_case
            "an_unauthored_form_emits_no_autocomplete_or_novalidate_and_neither_dispatches_nor_navigates"
            `Quick test_an_unauthored_form_neither_dispatches_nor_navigates;
          Alcotest.test_case
            "enter_in_a_bare_field_submits_once_and_does_not_navigate" `Quick
            test_enter_in_a_bare_field_submits_once_and_does_not_navigate;
          Alcotest.test_case
            "submit_button_click_submits_once_and_does_not_navigate" `Quick
            test_submit_button_click_submits_once_and_does_not_navigate;
          Alcotest.test_case "untyped_button_in_form_answers_its_own_click_only"
            `Quick test_untyped_button_in_form_answers_its_own_click_only;
          Alcotest.test_case
            "submit_typed_button_click_dispatches_click_then_form" `Quick
            test_submit_typed_button_click_dispatches_click_then_form;
          Alcotest.test_case
            "disabled_submit_button_click_dispatches_nothing_and_does_not_submit"
            `Quick
            test_disabled_submit_button_click_dispatches_nothing_and_does_not_submit;
          Alcotest.test_case
            "enter_in_field_with_disabled_default_button_submits_nothing" `Quick
            test_enter_in_field_with_disabled_default_button_submits_nothing;
          Alcotest.test_case
            "disabled_before_enabled_submit_button_blocks_enter" `Quick
            test_disabled_before_enabled_submit_button_blocks_enter;
          Alcotest.test_case "input_on_submit_inside_a_form_dispatches_once"
            `Quick test_input_on_submit_inside_a_form_dispatches_once;
          Alcotest.test_case "a_fixed_child_of_a_form_does_not_shrink" `Quick
            test_a_fixed_child_of_a_form_does_not_shrink;
          Alcotest.test_case
            "reconcile_updates_autocomplete_novalidate_and_on_submit" `Quick
            test_reconcile_updates_autocomplete_novalidate_and_on_submit;
          Alcotest.test_case
            "form_typed_fields_survive_caller_pairs_arriving_on_update" `Quick
            test_form_typed_fields_survive_caller_pairs_arriving_on_update;
          Alcotest.test_case
            "input_type_change_with_a_value_present_survives_reconcile" `Quick
            test_input_type_change_with_a_value_present_survives_reconcile;
          Alcotest.test_case
            "a_number_input_created_with_a_non_numeric_value_keeps_it" `Quick
            test_a_number_input_created_with_a_non_numeric_value_keeps_it;
        ] );
    ]
