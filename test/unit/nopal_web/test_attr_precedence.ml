(* Attribute precedence parity between the two backends.

   A component derives attributes a caller never writes — [placeholder], [name],
   [accept], [capture], [type], [disabled] — and a caller supplies its own
   through [~attrs]. When the two name the same key, one of them wins, and until
   this suite existed the two backends answered that differently: the test
   renderer prepended its derived pairs and resolved first-wins, while the web
   renderer applied [~attrs] last and let the caller clobber the derivation. A
   structural suite could therefore assert the opposite of what shipped.

   The rule both backends now hold has two tiers: a derived attribute wins over
   a caller pair of the same key, and within the caller's own list a duplicate
   key resolves to the LAST pair. The second tier is what a component's own
   ARIA sits inside — it is an ordinary list pair, not a derivation — which is
   why [Modal], [Navigation_bar], [Bottom_tabs] and [Button] can each promise in
   their [.mli] that a caller's attributes beat it.

   Three keys are spelled identically in both backends and carry the same value,
   so a case can assert the derived value itself: [placeholder], [name] and
   [accept]/[capture] on a configured picker. The rest are comparable only on
   *which side wins*, because the two backends deliberately spell them
   differently — [disabled] is a presence attribute in the DOM and a ["true"]
   pair in the structural tree, and in both it is absent rather than false when
   the derivation declines, while a container's focusability is [tabindex] in one
   and the DSL's own word [focusable] in the other (test_renderer.ml, Box arm).
   Those cases assert that the caller's value is not what is read back, which is
   the whole of what parity can mean there. *)

module E = Nopal_element.Element
module TR = Nopal_test.Test_renderer
module Modal = Nopal_ui.Modal
module Navigation_bar = Nopal_ui.Navigation_bar
module Bottom_tabs = Nopal_ui.Bottom_tabs
module Button = Nopal_ui.Button

(* The components under the four published contracts carry behavioural fields of
   their own, so the cases below need a message type rather than a unit one.
   Plain strings, so no constructor goes unused. *)
type msg = string

let dispatch (_ : msg) = ()

let dom_attr node name =
  let v = Jv.call node "getAttribute" [| Jv.of_string name |] in
  if Jv.is_null v then None else Some (Jv.to_string v)

let fresh_parent () = Brr.El.v (Jstr.v "div") []

let web_attr element name =
  let parent = fresh_parent () in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent element in
  dom_attr (Nopal_web.Renderer.dom_node handle) name

let web_attr_after_update ~first ~second name =
  let parent = fresh_parent () in
  let handle = Nopal_web.Renderer.create ~dispatch ~parent first in
  Nopal_web.Renderer.update ~dispatch handle second;
  dom_attr (Nopal_web.Renderer.dom_node handle) name

(* [TR.By_tag] matches a tag exactly and there is no wildcard selector, so the
   node under test is named rather than searched for: every fixture below hands
   this its own element, which is the root of the tree that element renders to.
   A wrapped fixture belongs in [marked_structural_attr], which finds its node by
   marker instead of assuming a position. *)
let structural_attr element name = TR.attr name (TR.tree (TR.render element))

(* A published contract sits on a node that is not always the root of its own
   tree: [Bottom_tabs.view] returns a column whose [role="tablist"] row is a
   grandchild. Each contract case therefore marks the node it means with a
   caller pair of its own and looks that marker up in each backend, from a
   wrapping box so that a root-level marker is reachable too. The marker names a
   key no component derives, so finding the node never depends on the very
   override the case is there to verify. Its value is a bare identifier: the
   selector goes through dom_shim's unquoted [attr=ident] grammar, the one shape
   the renderer itself builds. *)
let marked_web_attr ~marker element ~name =
  let key, value = marker in
  let parent = fresh_parent () in
  let handle =
    Nopal_web.Renderer.create ~dispatch ~parent (E.box [ element ])
  in
  let found =
    Jv.call
      (Nopal_web.Renderer.dom_node handle)
      "querySelector"
      [| Jv.of_string (Printf.sprintf "[%s=%s]" key value) |]
  in
  if Jv.is_null found then None else dom_attr found name

let marked_structural_attr ~marker element ~name =
  let key, value = marker in
  let rendered = TR.render (E.box [ element ]) in
  match TR.find (TR.By_attr (key, value)) (TR.tree rendered) with
  | Some node -> TR.attr name node
  | None -> None

let check_opt = Alcotest.(check (option string))

(* One body per contract, so a case states the component, the key it collides
   with and the value it expects, and nothing else. *)
let check_override ~marker ~name ~expected element =
  check_opt "web gives the caller's pair the node" expected
    (marked_web_attr ~marker element ~name);
  check_opt "structural gives the caller's pair the node" expected
    (marked_structural_attr ~marker element ~name)

(* The three keys both backends spell the same way and give the same value. *)

let test_placeholder_is_derived_in_both () =
  let el =
    E.input ~placeholder:"real" ~attrs:[ ("placeholder", "hijacked") ] "v"
  in
  check_opt "web keeps the derived placeholder" (Some "real")
    (web_attr el "placeholder");
  check_opt "structural keeps the derived placeholder" (Some "real")
    (structural_attr el "placeholder")

let test_radio_name_is_derived_in_both () =
  let el = E.radio ~attrs:[ ("name", "hijacked") ] ~name:"group" () in
  check_opt "web keeps the derived name" (Some "group") (web_attr el "name");
  check_opt "structural keeps the derived name" (Some "group")
    (structural_attr el "name")

let test_accept_is_derived_in_both () =
  let el =
    E.file_input ~accept:[ "image/png" ] ~attrs:[ ("accept", "*/*") ] ()
  in
  check_opt "web keeps the derived accept" (Some "image/png")
    (web_attr el "accept");
  check_opt "structural keeps the derived accept" (Some "image/png")
    (structural_attr el "accept")

let test_capture_is_derived_in_both () =
  let el =
    E.file_input ~capture:E.Environment ~attrs:[ ("capture", "user") ] ()
  in
  check_opt "web keeps the derived capture" (Some "environment")
    (web_attr el "capture");
  check_opt "structural keeps the derived capture" (Some "environment")
    (structural_attr el "capture")

(* Keys the two backends spell differently: parity is which side wins. *)

let test_disabled_caller_value_never_wins () =
  let el =
    E.checkbox ~disabled:true ~attrs:[ ("disabled", "hijacked") ] false
  in
  (* The affirmative arm. Without it a backend that emitted no [disabled] at all
     would satisfy both non-equality arms below while pinning nothing. The two
     spellings are deliberately different — a presence attribute in the DOM, a
     ["true"] pair in the structural tree — so each is named for what it actually
     is rather than compared to the other. *)
  check_opt "web emits the derived disabled as a presence attribute" (Some "")
    (web_attr el "disabled");
  check_opt "structural emits the derived disabled" (Some "true")
    (structural_attr el "disabled");
  Alcotest.(check bool)
    "web does not read back the caller's disabled" false
    (Option.equal String.equal (web_attr el "disabled") (Some "hijacked"));
  Alcotest.(check bool)
    "structural does not read back the caller's disabled" false
    (Option.equal String.equal
       (structural_attr el "disabled")
       (Some "hijacked"))

let test_type_is_derived_on_the_web_side () =
  (* [type] has no structural counterpart — the tag carries it there — so this
     one is a web-side case by construction, not an omission. *)
  let el = E.checkbox ~attrs:[ ("type", "text") ] false in
  check_opt "web keeps the derived input type" (Some "checkbox")
    (web_attr el "type")

let test_focusable_tab_order_still_wins () =
  (* [apply_focusable] already emitted after the declared attributes and already
     documented the rule; this guards the reordering against undoing it. *)
  let el = E.box ~focusable:true ~attrs:[ ("tabindex", "5") ] [] in
  check_opt "web keeps the derived tab order" (Some "0")
    (web_attr el "tabindex")

(* A typed field that declines to assert a value uncovers whatever the caller
   declared for that name; it does not erase the key. The fixture supplies
   that pair: a picker that declared nothing would read [None] in both backends
   whatever the uncover branch did, so it would prove nothing at all. *)

let test_absent_derivation_uncovers_the_caller_pair () =
  let el = E.file_input ~attrs:[ ("capture", "user") ] () in
  check_opt "web uncovers the caller's capture" (Some "user")
    (web_attr el "capture");
  check_opt "structural uncovers the caller's capture" (Some "user")
    (structural_attr el "capture")

(* The second tier, on a key neither backend derives: nothing above the list is
   involved, so this is the list's own resolution and nothing else. *)

let test_caller_duplicate_resolves_to_the_last_pair () =
  let el =
    E.box ~attrs:[ ("data-duplicate", "first"); ("data-duplicate", "last") ] []
  in
  check_opt "web resolves a duplicated caller key to the last pair"
    (Some "last")
    (web_attr el "data-duplicate");
  check_opt "structural resolves a duplicated caller key to the last pair"
    (Some "last")
    (structural_attr el "data-duplicate")

(* The two tiers meet here, and this is the case the backends disagreed on: the
   derivation is absent, so the uncover branch resolves the declared list, and
   it has to resolve it the same way the list is resolved everywhere else. *)

let test_absent_derivation_uncovers_the_last_caller_pair () =
  let el =
    E.file_input ~attrs:[ ("capture", "first"); ("capture", "last") ] ()
  in
  check_opt "web uncovers the last of the caller's pairs" (Some "last")
    (web_attr el "capture");
  check_opt "structural uncovers the last of the caller's pairs" (Some "last")
    (structural_attr el "capture")

(* The four published override contracts. A component's own ARIA is an ordinary
   pair inside the caller's list, not a derivation, so a caller's later pair
   beats it; each [.mli] says so and none of them was verified before now. *)

let test_modal_aria_is_overridable_through_config_attrs () =
  (* modal.mli:41-42, against the dialog's own [("role", "dialog")]. *)
  let config =
    Modal.make ~open_:true ~title_id:"modal-title" ~on_close:"close"
      ~body:(E.text "body")
    |> Modal.with_attrs [ ("data-case", "modal"); ("role", "alertdialog") ]
  in
  check_override ~marker:("data-case", "modal") ~name:"role"
    ~expected:(Some "alertdialog") (Modal.view config)

let test_navigation_bar_aria_is_overridable_through_config_attrs () =
  (* navigation_bar.mli:50-51, against the container's [("role", "tablist")]. *)
  let config =
    Navigation_bar.make
      ~items:[ Navigation_bar.item ~id:"one" "One" ]
      ~active:"one"
      ~on_select:(fun id -> id)
    |> Navigation_bar.with_attrs
         [ ("data-case", "nav"); ("role", "navigation") ]
  in
  check_override ~marker:("data-case", "nav") ~name:"role"
    ~expected:(Some "navigation")
    (Navigation_bar.view config)

let test_bottom_tabs_aria_is_overridable_through_bar_attrs () =
  (* bottom_tabs.mli:88-89, against the tab bar's [("role", "tablist")]. The bar
     is a grandchild of the view's root, which is what the marker is for. *)
  let config =
    Bottom_tabs.make
      ~tabs:
        [
          Bottom_tabs.tab ~id:"home" ~label:"Home"
            ~stack:(Nopal_navigation.Nav_stack.create "home-screen")
            ();
        ]
      ~active:"home"
      ~render_screen:(fun screen -> E.text screen)
      ~on_select:(fun id -> id)
      ~on_back:"back" ~safe_area_bottom:0
    |> Bottom_tabs.with_bar_attrs
         [ ("data-case", "tabs"); ("role", "navigation") ]
  in
  check_override ~marker:("data-case", "tabs") ~name:"role"
    ~expected:(Some "navigation") (Bottom_tabs.view config)

let test_button_aria_is_overridable_through_config_attrs () =
  (* button.mli:31-32, against the disabled button's [("aria-disabled",
     "true")]. Every field is written out: starting from [Button.default] and
     modifying one would inherit behaviour this case never asked for. *)
  let config : msg Button.config =
    {
      Button.variant = Button.Primary;
      disabled = true;
      loading = false;
      on_click = None;
      style = None;
      interaction = None;
      attrs = [ ("data-case", "button"); ("aria-disabled", "false") ];
      disabled_style = None;
      loading_style = None;
    }
  in
  check_override ~marker:("data-case", "button") ~name:"aria-disabled"
    ~expected:(Some "false")
    (Button.view config (E.text "Save"))

(* --- The two naming keys the labelled controls introduce.

   A control's [id] and the [aria-labelledby] pointing at its own label box are
   ordinary attribute pairs, not derivations, so nothing above decides them — but
   the question 0141 answered for a derived attribute still has to be answered
   here: a structural assertion on either key is evidence about the browser only
   if the browser writes the key at all, and on the element kind that carries it.
   The four controls put these two keys on five different element kinds — a box
   for every label, and an input, a checkbox, a select and a radio for the
   controls — which is the axis a divergence would run along.

   Each control is located by a caller marker pushed through [config.attrs], a
   key no component derives, so finding the node never depends on the keys under
   test; a radio, whose attrs are fixed by the component, is located by its group
   field anchor instead. Each label box is located by the very [id] the case
   expects, which is what makes the read affirmative: a backend that writes no
   [id] on a box finds no node and answers [None] against a literal.

   Every fixture is a complete record literal. Starting from [make] and setting
   one field would inherit behavioural defaults the case never asked for. *)

let naming_marker = ("data-case", "naming")

let text_input_fixture () : msg Nopal_ui.TextInput.config =
  {
    Nopal_ui.TextInput.label = "Email address";
    value = "someone@example.com";
    placeholder = None;
    error = None;
    disabled = false;
    id = None;
    on_change = None;
    on_submit = None;
    on_blur = None;
    style = None;
    interaction = None;
    attrs = [ naming_marker ];
    label_style = None;
    wrapper_style = None;
    error_style = None;
    on_label_click = None;
  }

let checkbox_fixture () : msg Nopal_ui.Checkbox.config =
  {
    Nopal_ui.Checkbox.label = "Accept terms";
    checked = false;
    disabled = false;
    on_toggle = None;
    style = None;
    interaction = None;
    attrs = [ naming_marker ];
    id = None;
    label_style = None;
    row_style = None;
    on_label_click = None;
  }

let select_input_fixture () : msg Nopal_ui.Select_input.config =
  {
    Nopal_ui.Select_input.label = "Country";
    options = [ E.select_option ~value:"mx" "Mexico" ];
    selected = "mx";
    placeholder = None;
    disabled = false;
    on_change = None;
    style = None;
    interaction = None;
    attrs = [ naming_marker ];
    id = None;
    label_style = None;
    wrapper_style = None;
    on_label_click = None;
  }

let radio_group_fixture ~visible_label : msg Nopal_ui.Radio_group.config =
  {
    Nopal_ui.Radio_group.label = "Colour";
    options = [ Nopal_ui.Radio_group.radio_option ~value:"red" "Red" ];
    selected = "red";
    disabled = false;
    name = None;
    on_select = None;
    style = None;
    interaction = None;
    attrs = [ naming_marker ];
    id = None;
    visible_label;
    label_style = None;
    group_style = None;
    option_label_style = None;
    option_row_style = None;
    on_label_click = None;
  }

(* Same two reads as [check_override], a different claim: not that the caller's
   pair won, but that both backends answer a component-derived naming pair with
   the same value. *)
let check_naming ~marker ~name ~expected element =
  check_opt
    (name ^ " reads the same in the web backend")
    expected
    (marked_web_attr ~marker element ~name);
  check_opt
    (name ^ " reads the same in the structural backend")
    expected
    (marked_structural_attr ~marker element ~name)

(* What this case does NOT cover, stated rather than left to be found: a label
   box is located by the id it is expected to carry, so the case pins the VALUE
   both backends answer and not the node the id sits on. A mutation moving the id
   outwards to the wrapper is answered by the wrapper here and stays green.
   Placement is a single-renderer question and is pinned structurally, by
   [test_aria_survival.ml] (which requires the id-carrying node to be a label
   element) and by [test_text_input.ml]'s association cases. *)
let test_generated_id_resolves_identically_in_both_backends () =
  let control ~marker ~expected element =
    check_naming ~marker ~name:"id" ~expected:(Some expected) element
  in
  let label ~id element =
    check_naming ~marker:("id", id) ~name:"id" ~expected:(Some id) element
  in
  let text_input = Nopal_ui.TextInput.view (text_input_fixture ()) in
  control ~marker:naming_marker ~expected:"email-address" text_input;
  label ~id:"email-address-label" text_input;
  let checkbox = Nopal_ui.Checkbox.view (checkbox_fixture ()) in
  control ~marker:naming_marker ~expected:"accept-terms" checkbox;
  label ~id:"accept-terms-label" checkbox;
  let select = Nopal_ui.Select_input.view (select_input_fixture ()) in
  control ~marker:naming_marker ~expected:"country" select;
  label ~id:"country-label" select;
  let radios =
    Nopal_ui.Radio_group.view (radio_group_fixture ~visible_label:(Some true))
  in
  (* the group's own id, then the one option's, then both label boxes *)
  control ~marker:naming_marker ~expected:"colour" radios;
  control ~marker:("data-field", "colour") ~expected:"colour-red" radios;
  label ~id:"colour-label" radios;
  label ~id:"colour-red-label" radios

let test_labelledby_resolves_identically_in_both_backends () =
  let named ~marker ~expected element =
    check_naming ~marker ~name:"aria-labelledby" ~expected:(Some expected)
      element;
    check_naming ~marker ~name:"aria-label" ~expected:None element
  in
  named ~marker:naming_marker ~expected:"email-address-label"
    (Nopal_ui.TextInput.view (text_input_fixture ()));
  named ~marker:naming_marker ~expected:"accept-terms-label"
    (Nopal_ui.Checkbox.view (checkbox_fixture ()));
  named ~marker:naming_marker ~expected:"country-label"
    (Nopal_ui.Select_input.view (select_input_fixture ()));
  let radios =
    Nopal_ui.Radio_group.view (radio_group_fixture ~visible_label:(Some true))
  in
  named ~marker:naming_marker ~expected:"colour-label" radios;
  named ~marker:("data-field", "colour") ~expected:"colour-red-label" radios;
  (* The affirmative arm for the four [aria-label] absences above: a group with
     no visible label element has nothing to point at, so it is still named by
     [aria-label] — in both backends. An absence that held because neither
     backend wrote any naming pair at all would fail here. *)
  let unlabelled =
    Nopal_ui.Radio_group.view (radio_group_fixture ~visible_label:None)
  in
  check_naming ~marker:naming_marker ~name:"aria-label"
    ~expected:(Some "Colour") unlabelled;
  check_naming ~marker:naming_marker ~name:"aria-labelledby" ~expected:None
    unlabelled

(* Reconciliation runs a different code path from creation, and a rule that
   holds only on the first frame is not a rule. *)

let test_derived_still_wins_after_update () =
  let first =
    E.input ~placeholder:"first" ~attrs:[ ("placeholder", "hijacked") ] "v"
  in
  let second =
    E.input ~placeholder:"second" ~attrs:[ ("placeholder", "hijacked") ] "v"
  in
  check_opt "web keeps the derived placeholder across an update" (Some "second")
    (web_attr_after_update ~first ~second "placeholder")

let test_derived_wins_when_the_caller_pair_arrives_on_update () =
  let first = E.input ~placeholder:"real" "v" in
  let second =
    E.input ~placeholder:"real" ~attrs:[ ("placeholder", "hijacked") ] "v"
  in
  check_opt "a caller pair added on update does not clobber the derivation"
    (Some "real")
    (web_attr_after_update ~first ~second "placeholder")

(* One case per arm that guards its re-assert on whether the declared list was
   re-applied. The typed field is deliberately held still across the two frames:
   a frame where it changed re-asserts on its own value and would stay green with
   the guard dropped, so only a still field can tell the guard apart from its
   absence. Each arm is listed separately because the guard is instantiated per
   arm — proving one says nothing about the next. *)

let test_checkbox_disabled_survives_a_caller_pair_arriving_on_update () =
  let first = E.checkbox ~disabled:true false in
  let second =
    E.checkbox ~disabled:true ~attrs:[ ("disabled", "hijacked") ] false
  in
  check_opt "the checkbox's derived disabled is re-asserted" (Some "")
    (web_attr_after_update ~first ~second "disabled")

let test_radio_disabled_survives_a_caller_pair_arriving_on_update () =
  let first = E.radio ~name:"group" ~disabled:true () in
  let second =
    E.radio ~name:"group" ~disabled:true ~attrs:[ ("disabled", "hijacked") ] ()
  in
  check_opt "the radio's derived disabled is re-asserted" (Some "")
    (web_attr_after_update ~first ~second "disabled")

let select_options =
  [ E.select_option ~value:"a" "A"; E.select_option ~value:"b" "B" ]

let test_select_disabled_survives_a_caller_pair_arriving_on_update () =
  let first = E.select ~disabled:true ~selected:"a" select_options in
  let second =
    E.select ~disabled:true
      ~attrs:[ ("disabled", "hijacked") ]
      ~selected:"a" select_options
  in
  check_opt "the select's derived disabled is re-asserted" (Some "")
    (web_attr_after_update ~first ~second "disabled")

let test_file_config_survives_a_caller_pair_arriving_on_update () =
  let first = E.file_input ~capture:E.Environment () in
  let second =
    E.file_input ~capture:E.Environment ~attrs:[ ("capture", "user") ] ()
  in
  check_opt "the picker's derived capture is re-asserted" (Some "environment")
    (web_attr_after_update ~first ~second "capture")

(* [type] is a constant derivation, so nothing about it can change between two
   frames — which is exactly why the reconcile arms did not write it at all, and
   why a caller pair arriving on update used to turn a checkbox into a text
   field. *)

let test_checkbox_type_survives_a_caller_pair_arriving_on_update () =
  let first = E.checkbox false in
  let second = E.checkbox ~attrs:[ ("type", "text") ] false in
  check_opt "the checkbox keeps its input type across an update"
    (Some "checkbox")
    (web_attr_after_update ~first ~second "type")

let test_radio_type_survives_a_caller_pair_arriving_on_update () =
  let first = E.radio ~name:"group" () in
  let second = E.radio ~name:"group" ~attrs:[ ("type", "text") ] () in
  check_opt "the radio keeps its input type across an update" (Some "radio")
    (web_attr_after_update ~first ~second "type")

let test_file_type_survives_a_caller_pair_arriving_on_update () =
  let first = E.file_input () in
  let second = E.file_input ~attrs:[ ("type", "text") ] () in
  check_opt "the picker keeps its input type across an update" (Some "file")
    (web_attr_after_update ~first ~second "type")

(* And the other half of the same hazard: a caller pair that goes away. The
   removal pass deletes the key outright, so a derivation the reconcile arm does
   not re-write disappears with it. *)

let test_checkbox_type_survives_a_caller_pair_removed_on_update () =
  let first = E.checkbox ~attrs:[ ("type", "text") ] false in
  let second = E.checkbox false in
  check_opt "the checkbox keeps its input type when the caller pair goes away"
    (Some "checkbox")
    (web_attr_after_update ~first ~second "type")

(* A tab order the caller declared twice resolves the way every other declared
   list does — last pair — at the one point that reads it back, when the typed
   flag falls and uncovers it. *)

let test_fallen_focusable_uncovers_the_last_caller_pair () =
  let attrs = [ ("tabindex", "1"); ("tabindex", "2") ] in
  let first = E.box ~focusable:true ~attrs [] in
  let second = E.box ~focusable:false ~attrs [] in
  check_opt "the uncovered tab order is the last pair the caller declared"
    (Some "2")
    (web_attr_after_update ~first ~second "tabindex")

let () =
  Alcotest.run "attr precedence"
    [
      ( "identical spelling in both backends",
        [
          Alcotest.test_case "placeholder" `Quick
            test_placeholder_is_derived_in_both;
          Alcotest.test_case "radio name" `Quick
            test_radio_name_is_derived_in_both;
          Alcotest.test_case "file accept" `Quick test_accept_is_derived_in_both;
          Alcotest.test_case "file capture" `Quick
            test_capture_is_derived_in_both;
        ] );
      ( "winner only",
        [
          Alcotest.test_case "disabled" `Quick
            test_disabled_caller_value_never_wins;
          Alcotest.test_case "input type" `Quick
            test_type_is_derived_on_the_web_side;
          Alcotest.test_case "focusable tab order" `Quick
            test_focusable_tab_order_still_wins;
        ] );
      ( "an absent derivation uncovers the caller",
        [
          Alcotest.test_case "capture the caller declared" `Quick
            test_absent_derivation_uncovers_the_caller_pair;
          Alcotest.test_case "the last capture the caller declared" `Quick
            test_absent_derivation_uncovers_the_last_caller_pair;
        ] );
      ( "within the caller's own list",
        [
          Alcotest.test_case "a duplicate key resolves to the last pair" `Quick
            test_caller_duplicate_resolves_to_the_last_pair;
        ] );
      ( "the four published override contracts",
        [
          Alcotest.test_case "modal role" `Quick
            test_modal_aria_is_overridable_through_config_attrs;
          Alcotest.test_case "navigation bar role" `Quick
            test_navigation_bar_aria_is_overridable_through_config_attrs;
          Alcotest.test_case "bottom tabs bar role" `Quick
            test_bottom_tabs_aria_is_overridable_through_bar_attrs;
          Alcotest.test_case "button aria-disabled" `Quick
            test_button_aria_is_overridable_through_config_attrs;
        ] );
      ( "the naming keys in both backends",
        [
          Alcotest.test_case "a generated id" `Quick
            test_generated_id_resolves_identically_in_both_backends;
          Alcotest.test_case "aria-labelledby, and no aria-label" `Quick
            test_labelledby_resolves_identically_in_both_backends;
        ] );
      ( "reconciliation",
        [
          Alcotest.test_case "derived wins across an update" `Quick
            test_derived_still_wins_after_update;
          Alcotest.test_case "caller pair added on update" `Quick
            test_derived_wins_when_the_caller_pair_arrives_on_update;
          Alcotest.test_case "checkbox disabled re-asserted" `Quick
            test_checkbox_disabled_survives_a_caller_pair_arriving_on_update;
          Alcotest.test_case "radio disabled re-asserted" `Quick
            test_radio_disabled_survives_a_caller_pair_arriving_on_update;
          Alcotest.test_case "select disabled re-asserted" `Quick
            test_select_disabled_survives_a_caller_pair_arriving_on_update;
          Alcotest.test_case "file capture re-asserted" `Quick
            test_file_config_survives_a_caller_pair_arriving_on_update;
          Alcotest.test_case "checkbox type re-asserted" `Quick
            test_checkbox_type_survives_a_caller_pair_arriving_on_update;
          Alcotest.test_case "radio type re-asserted" `Quick
            test_radio_type_survives_a_caller_pair_arriving_on_update;
          Alcotest.test_case "file type re-asserted" `Quick
            test_file_type_survives_a_caller_pair_arriving_on_update;
          Alcotest.test_case "checkbox type survives a removed pair" `Quick
            test_checkbox_type_survives_a_caller_pair_removed_on_update;
          Alcotest.test_case "fallen focusable uncovers the last pair" `Quick
            test_fallen_focusable_uncovers_the_last_caller_pair;
        ] );
    ]
