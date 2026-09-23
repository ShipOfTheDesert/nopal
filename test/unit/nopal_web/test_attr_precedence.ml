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

   Some keys are spelled identically in both backends and carry the same value,
   so a case can assert the derived value itself: [placeholder], [name],
   [accept]/[capture] on a configured picker, and an input's [autocomplete],
   [type] and [aria-required], and a button's [aria-disabled]. The rest are comparable only on *which side
   wins*, because the two backends deliberately spell them differently —
   [disabled] and an input's [required] are presence attributes in the DOM and
   ["true"] pairs in the structural tree, and in both they are absent rather
   than false when the derivation declines, while a container's focusability is [tabindex] in one
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
  (* A checkbox's [type] has no structural counterpart — the tag carries it
     there — so this one is a web-side case by construction, not an omission.
     An input's [input_type] does have one, and is compared in both below. *)
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

(* Every field of each button fixture is written out: starting from
   [Button.default] and modifying one would inherit behaviour the case never
   asked for. *)
let button_fixture ~disabled ~loading attrs : msg Button.config =
  {
    Button.variant = Button.Primary;
    disabled;
    loading;
    on_click = None;
    style = None;
    interaction = None;
    attrs;
    disabled_style = None;
    loading_style = None;
    button_type = E.Push;
  }

let test_button_aria_is_overridable_through_config_attrs () =
  check_override ~marker:("data-case", "button") ~name:"aria-busy"
    ~expected:(Some "false")
    (Button.view
       (button_fixture ~disabled:false ~loading:true
          [ ("data-case", "button"); ("aria-busy", "false") ])
       (E.text "Save"))

(* A disabled button's [aria-disabled] is derived from the element's typed
   state, not contributed by the component, so it is the one ARIA key of the
   button that a caller's pair does not replace. *)
let test_button_aria_disabled_outranks_config_attrs () =
  let marker = ("data-case", "button-disabled") in
  let element =
    Button.view
      (button_fixture ~disabled:true ~loading:false
         [ marker; ("aria-disabled", "false") ])
      (E.text "Save")
  in
  check_opt "web keeps the derived aria-disabled" (Some "true")
    (marked_web_attr ~marker element ~name:"aria-disabled");
  check_opt "structural keeps the derived aria-disabled" (Some "true")
    (marked_structural_attr ~marker element ~name:"aria-disabled")

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

(* An input's typed [required], [autocomplete] and [input_type]. Every key they
   derive but one is spelled identically in both backends, so the value itself
   is compared; [required] is a presence attribute in the DOM and a ["true"]
   pair in the structural tree, the split [disabled] has, so each spelling is
   named for what it is. [aria-required] is an ordinary ["true"] string in both.
   The caller's pairs carry a value no derivation produces, so reading one back
   names its source. *)

let input_callers_pairs =
  [
    ("required", "caller");
    ("aria-required", "caller");
    ("autocomplete", "caller");
    ("type", "caller");
  ]

(* A button's type has no absent form: it is derived on every render, so a
   caller's pair of that key is replaced whichever way the typed field points. *)
let test_typed_button_type_outranks_attrs_type_pair () =
  let button ?button_type caller =
    E.button ?button_type ~attrs:[ ("type", caller) ] (E.text "Go")
  in
  check_opt "structural: an untyped button overrules a caller's submit"
    (Some "button")
    (structural_attr (button "submit") "type");
  check_opt "structural: a submit button overrules a caller's button"
    (Some "submit")
    (structural_attr (button ~button_type:E.Submit "button") "type")

let test_typed_button_type_outranks_attrs_type_pair_web () =
  let button ?button_type caller =
    E.button ?button_type ~attrs:[ ("type", caller) ] (E.text "Go")
  in
  check_opt "web: an untyped button overrules a caller's submit" (Some "button")
    (web_attr (button "submit") "type");
  check_opt "web: a submit button overrules a caller's button" (Some "submit")
    (web_attr (button ~button_type:E.Submit "button") "type");
  check_opt "web: a type change on update reaches the node" (Some "submit")
    (web_attr_after_update
       ~first:(E.button (E.text "Go"))
       ~second:(E.button ~button_type:E.Submit (E.text "Go"))
       "type");
  (* The typed field is held still, so only the re-assert on a re-applied
     declared list keeps it standing. *)
  check_opt "web: the type survives a caller's pair arriving on update"
    (Some "submit")
    (web_attr_after_update
       ~first:(E.button ~button_type:E.Submit (E.text "Go"))
       ~second:(button ~button_type:E.Submit "button")
       "type")

(* [disabled] is a bool, so [false] uncovers a caller's ["aria-disabled"] rather
   than removing it, on create and on the frame it falls. *)
let test_disabled_derives_aria_disabled_over_attrs_web () =
  let button ?(attrs = []) ~disabled () =
    E.button ~disabled ~attrs (E.text "Save")
  in
  let callers = [ ("aria-disabled", "false") ] in
  check_opt "web: disabled overrules a caller's aria-disabled" (Some "true")
    (web_attr (button ~attrs:callers ~disabled:true ()) "aria-disabled");
  check_opt "web: enabled uncovers a caller's aria-disabled" (Some "false")
    (web_attr (button ~attrs:callers ~disabled:false ()) "aria-disabled");
  check_opt "web: enabled with no caller pair emits none" None
    (web_attr (button ~disabled:false ()) "aria-disabled");
  check_opt "web: disabled survives a caller's pair arriving on update"
    (Some "true")
    (web_attr_after_update ~first:(button ~disabled:true ())
       ~second:(button ~attrs:callers ~disabled:true ())
       "aria-disabled");
  check_opt "web: falling uncovers the caller's pair" (Some "false")
    (web_attr_after_update
       ~first:(button ~attrs:callers ~disabled:true ())
       ~second:(button ~attrs:callers ~disabled:false ())
       "aria-disabled");
  check_opt "web: falling with no caller pair removes it" None
    (web_attr_after_update ~first:(button ~disabled:true ())
       ~second:(button ~disabled:false ())
       "aria-disabled")

let authored_input ?(attrs = []) () =
  E.input ~attrs ~required:true ~autocomplete:"username" ~input_type:E.Email "v"

let test_the_three_new_derivations_answer_alike_in_both_renderers () =
  let authored = authored_input ~attrs:input_callers_pairs () in
  check_opt "web emits the derived required as a presence attribute" (Some "")
    (web_attr authored "required");
  check_opt "structural emits the derived required" (Some "true")
    (structural_attr authored "required");
  List.iter
    (fun (key, expected) ->
      check_opt
        (Printf.sprintf "web keeps the derived %s" key)
        (Some expected) (web_attr authored key);
      check_opt
        (Printf.sprintf "structural keeps the derived %s" key)
        (Some expected)
        (structural_attr authored key))
    [
      ("aria-required", "true"); ("autocomplete", "username"); ("type", "email");
    ];
  (* Absent, each field uncovers the caller's pair in both. *)
  let absent = E.input ~attrs:input_callers_pairs "v" in
  List.iter
    (fun (key, value) ->
      check_opt
        (Printf.sprintf "web uncovers the caller's %s" key)
        (Some value) (web_attr absent key);
      check_opt
        (Printf.sprintf "structural uncovers the caller's %s" key)
        (Some value)
        (structural_attr absent key))
    input_callers_pairs;
  (* Every arm of the type, against one literal token per arm, in both. *)
  List.iter
    (fun (input_type, token) ->
      let el = E.input ~input_type "v" in
      check_opt
        (Printf.sprintf "web writes type=%s" token)
        (Some token) (web_attr el "type");
      check_opt
        (Printf.sprintf "structural writes type=%s" token)
        (Some token)
        (structural_attr el "type"))
    [
      (E.Plain, "text");
      (E.Password, "password");
      (E.Email, "email");
      (E.Tel, "tel");
      (E.Url, "url");
      (E.Number, "number");
      (E.Search, "search");
    ]

(* The input's re-assert guard, held still across the two frames for the reason
   the cases above it give: only a still field can tell the guard apart from its
   absence. *)
let test_input_typed_fields_survive_caller_pairs_arriving_on_update () =
  let first = authored_input () in
  let second = authored_input ~attrs:input_callers_pairs () in
  List.iter
    (fun (key, expected) ->
      check_opt
        (Printf.sprintf "the input's derived %s is re-asserted" key)
        (Some expected)
        (web_attr_after_update ~first ~second key))
    [
      ("required", "");
      ("aria-required", "true");
      ("autocomplete", "username");
      ("type", "email");
    ]

(* A field that falls away between frames: where the caller declared the key,
   the pair is uncovered; where nobody did, the attribute is removed rather
   than left over from the previous render. Each field falls on its own, so a
   reconcile guard that overlooked one field could not be carried by another
   field changing in the same frame. *)
let test_input_typed_fields_that_fall_uncover_or_remove () =
  (* Each builder authors one field and nothing else; the caller's pairs all
     carry ["caller"]. *)
  let authoring_one =
    [
      ( (fun attrs -> E.input ~attrs ~required:true "v"),
        [ "required"; "aria-required" ] );
      ( (fun attrs -> E.input ~attrs ~autocomplete:"username" "v"),
        [ "autocomplete" ] );
      ((fun attrs -> E.input ~attrs ~input_type:E.Email "v"), [ "type" ]);
    ]
  in
  List.iter
    (fun (authored, keys) ->
      List.iter
        (fun key ->
          check_opt
            (Printf.sprintf "a fallen field uncovers the caller's %s" key)
            (Some "caller")
            (web_attr_after_update
               ~first:(authored input_callers_pairs)
               ~second:(E.input ~attrs:input_callers_pairs "v")
               key);
          check_opt
            (Printf.sprintf "a fallen field removes an undeclared %s" key)
            None
            (web_attr_after_update ~first:(authored []) ~second:(E.input "v")
               key))
        keys)
    authoring_one

(* A form's typed [autocomplete] and [novalidate], on the same terms as an
   input's typed fields above: both are spelled identically in both backends
   ([autocomplete] as its wire token, [novalidate] as a presence attribute),
   so the derived value itself is compared, the caller's pair is uncovered
   when the field is absent, and the derivation is re-asserted across an
   update rather than only on first render. *)

let form_callers_pairs =
  [ ("autocomplete", "caller"); ("novalidate", "caller") ]

let authored_form ?(attrs = []) () =
  E.form ~attrs ~autocomplete:E.Off ~novalidate:true []

let test_form_typed_fields_answer_alike_in_both_renderers () =
  let authored = authored_form ~attrs:form_callers_pairs () in
  check_opt "web keeps the derived autocomplete" (Some "off")
    (web_attr authored "autocomplete");
  check_opt "structural keeps the derived autocomplete" (Some "off")
    (structural_attr authored "autocomplete");
  check_opt "web emits the derived novalidate as a presence attribute" (Some "")
    (web_attr authored "novalidate");
  check_opt "structural emits the derived novalidate" (Some "true")
    (structural_attr authored "novalidate");
  (* Absent, each field uncovers the caller's pair in both. *)
  let absent = E.form ~attrs:form_callers_pairs [] in
  List.iter
    (fun key ->
      check_opt
        (Printf.sprintf "web uncovers the caller's %s" key)
        (Some "caller") (web_attr absent key);
      check_opt
        (Printf.sprintf "structural uncovers the caller's %s" key)
        (Some "caller")
        (structural_attr absent key))
    [ "autocomplete"; "novalidate" ]

let test_form_typed_fields_survive_caller_pairs_arriving_on_update () =
  let first = authored_form () in
  let second = authored_form ~attrs:form_callers_pairs () in
  check_opt "the form's derived autocomplete is re-asserted" (Some "off")
    (web_attr_after_update ~first ~second "autocomplete");
  check_opt "the form's derived novalidate is re-asserted" (Some "")
    (web_attr_after_update ~first ~second "novalidate")

(* The submit contract: which handler answers a keydown on an input. Both
   renderers take the answer from [Nopal_element.Submit_route], and this case
   drives the same inputs through each and compares the ordered dispatch lists
   against one literal expectation, so the two cannot agree on a wrong answer
   any more than they can disagree. The web side fires a real [keydown] through
   dom_shim, whose events start with [defaultPrevented] false as a browser's do,
   so the per-key suppression read back is the renderer's own doing. The web
   side is driven twice — through [create] and through reconciliation onto a
   handler-less input — because the two paths wire the listener separately. *)

let fire_keydown node key =
  let ev =
    Jv.new'
      (Jv.get Jv.global "KeyboardEvent")
      [|
        Jv.of_string "keydown";
        Jv.obj [| ("key", Jv.of_string key); ("cancelable", Jv.of_bool true) |];
      |]
  in
  ignore (Jv.call node "dispatchEvent" [| ev |]);
  Jv.to_bool (Jv.get ev "defaultPrevented")

let mount_created element ~dispatch ~parent =
  Nopal_web.Renderer.create ~dispatch ~parent element

let mount_reconciled element ~dispatch ~parent =
  let handle = Nopal_web.Renderer.create ~dispatch ~parent (E.input "v") in
  Nopal_web.Renderer.update ~dispatch handle element;
  handle

let web_keydown_answers ~mount keys =
  let sent = ref [] in
  let dispatch msg = sent := msg :: !sent in
  let handle = mount ~dispatch ~parent:(fresh_parent ()) in
  let node = Nopal_web.Renderer.dom_node handle in
  let prevented = List.map (fire_keydown node) keys in
  (List.rev !sent, prevented)

let structural_keydown_answers element keys =
  let rendered = TR.render element in
  let results =
    List.map (fun key -> TR.keydown (TR.By_tag "input") key rendered) keys
  in
  (TR.messages rendered, results)

let check_submit_contract ~label ~keys ~dispatched ~prevented element =
  let web_via label' mount =
    let sent, suppressed = web_keydown_answers ~mount:(mount element) keys in
    Alcotest.(check (list string))
      (Printf.sprintf "%s: web dispatches, %s" label label')
      dispatched sent;
    Alcotest.(check (list bool))
      (Printf.sprintf "%s: web suppresses the default, per key, %s" label label')
      prevented suppressed
  in
  web_via "created" mount_created;
  web_via "reconciled" mount_reconciled;
  let sent, results = structural_keydown_answers element keys in
  Alcotest.(check (list string))
    (Printf.sprintf "%s: structural dispatches" label)
    dispatched sent;
  Alcotest.(check (list (result unit Test_util.error_testable)))
    (Printf.sprintf "%s: structural answers every key" label)
    (List.map (fun _ -> Ok ()) keys)
    results

(* The form path: one form holding a bare field, a field with its own
   [on_submit] and a field whose [on_keydown] consumes every key, each found by
   a marker of its own. Enter is pressed in each in turn and the whole ordered
   dispatch list compared against one literal. The web side leans on dom_shim's
   model of the platform default — a text field's uncancelled Enter clicks the
   form's first submit button, and a submission nothing cancels is recorded as a
   navigation — so the form's message arriving there is the platform's
   submission reaching the renderer's listener, not a shortcut. The fixture
   carries a submit button for that reason: with three text fields and no
   submit button a browser submits nothing on Enter, and the structural
   renderer, which models that rule, answers the same. *)

let form_fields = [ "bare"; "submitting"; "consuming" ]
let field_marker name = ("data-field", name)

let three_path_form ?on_submit () =
  E.form ?on_submit
    [
      E.row [ E.input ~attrs:[ field_marker "bare" ] "v" ];
      E.input
        ~attrs:[ field_marker "submitting" ]
        ~on_submit:"field submitted" "v";
      E.input
        ~attrs:[ field_marker "consuming" ]
        ~on_keydown:(fun key -> Some ("key " ^ key))
        "v";
      E.button ~button_type:E.Submit (E.text "Sign in");
    ]

(* The same shape with no handler anywhere, for the reconcile path to patch. *)
let unhandled_three_path_form () =
  E.form
    [
      E.row [ E.input "v" ];
      E.input "v";
      E.input "v";
      E.button ~button_type:E.Submit (E.text "Sign in");
    ]

let navigations () =
  Jv.Int.get (Jv.get (Jv.get Jv.global "document") "_navigations") "length"

let web_form_answers ~reconcile element =
  let sent = ref [] in
  let dispatch msg = sent := msg :: !sent in
  let parent = fresh_parent () in
  let handle =
    match reconcile with
    | false -> Nopal_web.Renderer.create ~dispatch ~parent element
    | true ->
        let handle =
          Nopal_web.Renderer.create ~dispatch ~parent
            (unhandled_three_path_form ())
        in
        Nopal_web.Renderer.update ~dispatch handle element;
        handle
  in
  let root = Nopal_web.Renderer.dom_node handle in
  let before = navigations () in
  let prevented =
    List.map
      (fun name ->
        let key, value = field_marker name in
        let node =
          Jv.call root "querySelector"
            [| Jv.of_string (Printf.sprintf "[%s=%s]" key value) |]
        in
        fire_keydown node "Enter")
      form_fields
  in
  (List.rev !sent, navigations () - before, prevented)

let structural_form_answers element =
  let rendered = TR.render element in
  let results =
    List.map
      (fun name ->
        let key, value = field_marker name in
        TR.keydown (TR.By_attr (key, value)) "Enter" rendered)
      form_fields
  in
  (TR.messages rendered, results)

let check_form_submit_contract ~label ~dispatched ~prevented ~results element =
  let web_via label' ~reconcile =
    let sent, navigated, prevented' = web_form_answers ~reconcile element in
    Alcotest.(check (list string))
      (Printf.sprintf "%s: web dispatches, %s" label label')
      dispatched sent;
    Alcotest.(check int)
      (Printf.sprintf "%s: web never navigates, %s" label label')
      0 navigated;
    Alcotest.(check (list bool))
      (Printf.sprintf "%s: web suppresses the default, per field, %s" label
         label')
      prevented prevented'
  in
  web_via "created" ~reconcile:false;
  web_via "reconciled" ~reconcile:true;
  let sent, results' = structural_form_answers element in
  Alcotest.(check (list string))
    (Printf.sprintf "%s: structural dispatches" label)
    dispatched sent;
  Alcotest.(check (list (result unit Test_util.error_testable)))
    (Printf.sprintf "%s: structural answers every field" label)
    results results'

let test_the_submit_contract_answers_alike_in_both_renderers () =
  (* The form path: the nearest handler that accepts each Enter answers it,
     once, and the default is suppressed for every field either way it is
     answered. *)
  check_form_submit_contract ~label:"three paths in a submitting form"
    ~dispatched:[ "form submitted"; "field submitted"; "key Enter" ]
    ~prevented:[ false; true; true ] ~results:[ Ok (); Ok (); Ok () ]
    (three_path_form ~on_submit:"form submitted" ());
  (* A form that authors no [on_submit] still cancels its submission and
     dispatches nothing for the bare field; the other two fields answer as
     before, which is the affirmative arm for that silence. The bare field's
     Enter reaches no handler in the structural tree — there is no form
     [on_submit] to defer to — while the web platform still submits and
     cancels the form itself, so only the structural side sees the miss. *)
  check_form_submit_contract ~label:"three paths in a form without on_submit"
    ~dispatched:[ "field submitted"; "key Enter" ]
    ~prevented:[ false; true; true ]
    ~results:
      [
        Error (TR.No_handler { tag = "input"; event = "keydown" }); Ok (); Ok ();
      ]
    (three_path_form ());
  (* An [on_keydown] that declines Enter no longer silences [on_submit]. *)
  check_submit_contract ~label:"declining on_keydown beside on_submit"
    ~keys:[ "Enter"; "Escape"; "a" ] ~dispatched:[ "submitted"; "escaped" ]
    ~prevented:[ true; false; false ]
    (E.input ~on_submit:"submitted"
       ~on_keydown:(function
         | "Escape" -> Some "escaped"
         | _ -> None)
       "v");
  (* A consuming [on_keydown] answers the Enter, and [on_submit] does not;
     consumption suppresses the default for the Enter alone. *)
  check_submit_contract ~label:"consuming on_keydown beside on_submit"
    ~keys:[ "Enter"; "a" ] ~dispatched:[ "key Enter"; "key a" ]
    ~prevented:[ true; false ]
    (E.input ~on_submit:"submitted"
       ~on_keydown:(fun key -> Some ("key " ^ key))
       "v");
  (* [on_submit] alone answers Enter and no other key. *)
  check_submit_contract ~label:"on_submit alone" ~keys:[ "a"; "Enter" ]
    ~dispatched:[ "submitted" ] ~prevented:[ false; true ]
    (E.input ~on_submit:"submitted" "v")

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
          Alcotest.test_case "button aria-disabled" `Quick
            test_button_aria_disabled_outranks_config_attrs;
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
          Alcotest.test_case "button aria-busy" `Quick
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
          Alcotest.test_case "input typed fields re-asserted" `Quick
            test_input_typed_fields_survive_caller_pairs_arriving_on_update;
          Alcotest.test_case "input typed fields fall, uncover or remove" `Quick
            test_input_typed_fields_that_fall_uncover_or_remove;
          Alcotest.test_case "form typed fields answer alike in both" `Quick
            test_form_typed_fields_answer_alike_in_both_renderers;
          Alcotest.test_case "form typed fields re-asserted" `Quick
            test_form_typed_fields_survive_caller_pairs_arriving_on_update;
        ] );
      ( "attr_precedence",
        [
          Alcotest.test_case
            "the_three_new_derivations_answer_alike_in_both_renderers" `Quick
            test_the_three_new_derivations_answer_alike_in_both_renderers;
          Alcotest.test_case "typed_button_type_outranks_attrs_type_pair" `Quick
            test_typed_button_type_outranks_attrs_type_pair;
          Alcotest.test_case "typed_button_type_outranks_attrs_type_pair_web"
            `Quick test_typed_button_type_outranks_attrs_type_pair_web;
          Alcotest.test_case "disabled_derives_aria_disabled_over_attrs_web"
            `Quick test_disabled_derives_aria_disabled_over_attrs_web;
        ] );
      ( "the submit contract",
        [
          Alcotest.test_case
            "the_submit_contract_answers_alike_in_both_renderers" `Quick
            test_the_submit_contract_answers_alike_in_both_renderers;
        ] );
    ]
