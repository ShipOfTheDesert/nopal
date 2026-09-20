(* Every ARIA association and every E2E anchor survives every style override.

   A component's accessible name, its role and its [data-*] anchors are not the
   caller's to move through a style. So applying every style and interaction
   override a component offers — each at a NON-DEFAULT value, because matching
   defaults are not evidence of anything — has to leave every one of those pairs
   answering exactly what it answered before. An override through the [~attrs]
   list is the documented escape hatch and is deliberately outside that
   criterion: no fixture below declares [attrs] except the last case, which is
   about a node's attribute list ORDER rather than about survival.

   Each case also asserts that the overrides actually landed on the nodes it then
   reads the pairs off. Without that arm a survival case passes most loudly when
   the override reached nothing at all, which is the failure the override surface
   exists to remove.

   {2 What this file covers, and what covers the rest}

   Eleven components were audited. [Slug] renders nothing and emits no pair, so
   it has no case anywhere and its absence here is not an omission. Of the
   remaining ten, four already carry a case that applies every override their
   component offers and asserts every pair, so they are not written again here:

   - [Data_table] — [test_data_table.ml],
     [test_role_and_aria_sort_are_unchanged_under_every_style_override]
   - [Modal] — [test_modal.ml],
     [test_dialog_aria_is_unchanged_under_every_style_override]
   - [Navigation_bar] — [test_navigation_bar.ml],
     [test_role_tab_and_aria_selected_survive_every_style_override]
   - [Bottom_tabs] — [test_bottom_tabs.ml],
     [test_tablist_and_tabpanel_roles_survive_every_style_override], which also
     pins the two structural exemptions and the gutter's partial one

   The six below are the ones with no such case. The four labelled controls had
   none at all, and they are the only components whose ARIA answers moved.
   [Toast] and [Button] each had one that applied the two new setters but left
   [config.style] and [config.interaction] unset, so neither exercised the
   COMBINED configuration where their newly published precedence rules live.

   {2 What a structural assertion here is evidence about}

   [id], [aria-labelledby], [aria-label], [aria-describedby], [role],
   [aria-disabled], [aria-busy], [aria-live] and every [data-*] anchor are
   ordinary attribute pairs in both renderers, spelled the same way and carrying
   the same value, so an assertion on one of them speaks for the browser as well.
   The two keys that are new here — [id] and [aria-labelledby] on a control and
   on its label — are pinned across the two backends by
   [test/unit/nopal_web/test_attr_precedence.ml]. [aria-label]'s disappearance is
   the absence of a pair the component used to contribute rather than a
   derivation declining, so it too is observable in both.

   A style override's RENDERED effect is asserted nowhere here. The browser sees
   a computed style and not which override produced it; reachability is this
   layer's job and appearance is not. *)

open Nopal_test.Test_renderer
module E = Nopal_element.Element
module S = Nopal_style.Style
module I = Nopal_style.Interaction
module TI = Nopal_ui.TextInput
module CB = Nopal_ui.Checkbox
module SI = Nopal_ui.Select_input
module RG = Nopal_ui.Radio_group
module B = Nopal_ui.Button
module T = Nopal_ui.Toast

(* A plain string message, so no constructor can go unused and no case needs a
   message type richer than "something was dispatched". Nothing below asserts on
   a dispatch; these are render-only cases. *)
type msg = string

(* --- Non-default values. Five distinguishable styles and two interactions, so
   a case can tell one override's answer from another's. --- *)

let bg hex =
  {
    S.default with
    paint = { S.default_paint with background = Some (S.hex hex) };
  }

let red = bg "#ff0000"
let blue = bg "#0000ff"
let green = bg "#00ff00"
let amber = bg "#ffaa00"
let violet = bg "#8800ff"
let hover_blue = { I.default with hover = Some blue }
let pressed_amber = { I.default with pressed = Some amber }

(* --- Reading a rendered tree --- *)

let find_or_fail = Test_util.find_or_fail

let attrs_of node =
  match node with
  | Element { attrs; _ } -> attrs
  | Empty
  | Text _ ->
      Alcotest.fail "expected an element node"

let check_key what node name expected =
  Alcotest.(check (option string)) what expected (attr name node)

(* A node carrying the label's id is not yet the label. A container that merely
   wraps the label carries the same text, so a mutation moving the id outwards to
   the wrapper satisfies every assertion made on "the node with that id" and the
   placement half of the association goes unpinned. The node a control points at
   is therefore required to BE a label element: a box whose only child is the
   label's own text node. *)
let label_box_or_fail root ~id ~text =
  let node =
    find_or_fail ("expected the label box " ^ id) (By_attr ("id", id)) root
  in
  (match node with
  | Element { tag = "box"; children = [ Text { content; _ } ]; _ } ->
      Alcotest.(check string)
        ("the label box " ^ id ^ " wraps its own text and nothing else")
        text content
  | Element _
  | Empty
  | Text _ ->
      Alcotest.fail ("the id " ^ id ^ " does not sit on a label element"));
  node

let check_style what expected node =
  Alcotest.(check bool) what true (Option.equal S.equal expected (style node))

let check_interaction what expected node =
  Alcotest.(check bool)
    what true
    (Option.equal I.equal expected (interaction node))

(* --- Text_input --- *)

let text_input_config () : msg TI.config =
  {
    TI.label = "Email address";
    value = "someone@example.com";
    placeholder = Some "you@example.com";
    error = Some "That address is not valid";
    disabled = false;
    id = None;
    on_change = Some (fun v -> v);
    on_submit = Some "submitted";
    on_blur = Some "blurred";
    style = Some red;
    interaction = Some hover_blue;
    attrs = [];
    label_style = Some green;
    wrapper_style = Some amber;
    error_style = Some violet;
    on_label_click = Some "label-clicked";
  }

let test_text_input_aria_survives_every_style_override () =
  let root = tree (render (TI.view (text_input_config ()))) in
  let input = find_or_fail "expected an input" (By_tag "input") root in
  check_key "the input keeps its id" input "id" (Some "email-address");
  check_key "the input is named by its own label" input "aria-labelledby"
    (Some "email-address-label");
  check_key "aria-label no longer names the input" input "aria-label" None;
  check_key "the field anchor is unmoved" input "data-field"
    (Some "email-address");
  check_key "the error slot still describes the input" input "aria-describedby"
    (Some "email-address-error");
  let label =
    label_box_or_fail root ~id:"email-address-label" ~text:"Email address"
  in
  check_key "the label box carries the id the input points at" label "id"
    (Some "email-address-label");
  let error =
    find_or_fail "expected the error slot" (By_attr ("role", "alert")) root
  in
  check_key "the error slot keeps its role" error "role" (Some "alert");
  check_key "the error slot keeps its id" error "id"
    (Some "email-address-error");
  (* and the overrides did reach the nodes those pairs were read off *)
  check_style "the input carries its style override" (Some red) input;
  check_interaction "the input carries its interaction override"
    (Some hover_blue) input;
  check_style "the label box carries its style override" (Some green) label;
  check_style "the error slot carries its style override" (Some violet) error;
  check_style "the wrapper carries its style override" (Some amber) root

(* --- Checkbox --- *)

let checkbox_config () : msg CB.config =
  {
    CB.label = "Accept terms";
    checked = true;
    disabled = false;
    on_toggle = Some (fun b -> string_of_bool b);
    style = Some red;
    interaction = Some hover_blue;
    attrs = [];
    id = Some "agreement";
    label_style = Some green;
    row_style = Some amber;
    on_label_click = Some "label-clicked";
  }

let test_checkbox_aria_survives_every_style_override () =
  let root = tree (render (CB.view (checkbox_config ()))) in
  let box = find_or_fail "expected a checkbox" (By_tag "checkbox") root in
  check_key "the checkbox keeps the id override" box "id" (Some "agreement");
  check_key "the checkbox is named by its own label" box "aria-labelledby"
    (Some "agreement-label");
  check_key "aria-label no longer names the checkbox" box "aria-label" None;
  (* the anchor stays on the label slug and is NOT moved by the id override *)
  check_key "the field anchor is unmoved" box "data-field" (Some "accept-terms");
  let label =
    label_box_or_fail root ~id:"agreement-label" ~text:"Accept terms"
  in
  check_key "the label box carries the id the checkbox points at" label "id"
    (Some "agreement-label");
  check_style "the checkbox carries its style override" (Some red) box;
  check_interaction "the checkbox carries its interaction override"
    (Some hover_blue) box;
  check_style "the label box carries its style override" (Some green) label;
  check_style "the row carries its style override" (Some amber) root

(* --- Select_input --- *)

let select_input_config () : msg SI.config =
  {
    SI.label = "Country";
    options =
      [
        E.select_option ~value:"mx" "Mexico";
        E.select_option ~value:"ca" "Canada";
      ];
    selected = "mx";
    placeholder = Some "Pick one";
    disabled = false;
    on_change = Some (fun v -> v);
    style = Some red;
    interaction = Some hover_blue;
    attrs = [];
    id = Some "country-picker";
    label_style = Some green;
    wrapper_style = Some amber;
    on_label_click = Some "label-clicked";
  }

let test_select_input_aria_survives_every_style_override () =
  let root = tree (render (SI.view (select_input_config ()))) in
  let sel = find_or_fail "expected a select" (By_tag "select") root in
  check_key "the select keeps the id override" sel "id" (Some "country-picker");
  check_key "the select is named by its own label" sel "aria-labelledby"
    (Some "country-picker-label");
  check_key "aria-label no longer names the select" sel "aria-label" None;
  check_key "the open anchor survives" sel "data-action" (Some "select-open");
  (* the anchor stays on the label slug and is NOT moved by the id override *)
  check_key "the field anchor is unmoved" sel "data-field" (Some "country");
  let label =
    label_box_or_fail root ~id:"country-picker-label" ~text:"Country"
  in
  check_key "the label box carries the id the select points at" label "id"
    (Some "country-picker-label");
  check_style "the select carries its style override" (Some red) sel;
  check_interaction "the select carries its interaction override"
    (Some hover_blue) sel;
  check_style "the label box carries its style override" (Some green) label;
  check_style "the wrapper carries its style override" (Some amber) root

(* --- Radio_group.

   Two options, so a per-option id is discriminated rather than accidentally
   equal to its sibling's. Both arms of the visible-label setter are exercised on
   the same override set: with it the group's name moves to [aria-labelledby],
   without it the group keeps [aria-label] — which is the affirmative arm for the
   absence asserted in the first. [with_label_style] reaches nothing in the
   second arm by design, so that arm asserts the naming and the option pairs
   only. --- *)

let radio_group_config ~visible_label : msg RG.config =
  {
    RG.label = "Favourite colour";
    options =
      [
        RG.radio_option ~value:"red" "Red";
        RG.radio_option ~value:"green" "Green";
      ];
    selected = "red";
    disabled = false;
    name = None;
    on_select = Some (fun v -> v);
    style = Some red;
    interaction = Some hover_blue;
    attrs = [];
    id = Some "palette";
    visible_label;
    label_style = Some green;
    group_style = Some amber;
    option_label_style = Some violet;
    option_row_style = Some blue;
    on_label_click = Some (fun v -> v);
  }

let radio_of root ~value =
  find_or_fail
    ("expected the " ^ value ^ " radio")
    (By_attr ("id", "palette-" ^ value))
    root

let check_option root ~value ~label_text =
  let radio = radio_of root ~value in
  check_key (value ^ " keeps its id") radio "id" (Some ("palette-" ^ value));
  check_key
    (value ^ " is named by its own label")
    radio "aria-labelledby"
    (Some ("palette-" ^ value ^ "-label"));
  check_key ("aria-label no longer names " ^ value) radio "aria-label" None;
  (* the anchor is the group name and is NOT moved by the id override *)
  check_key
    (value ^ " keeps the group field anchor")
    radio "data-field" (Some "favourite-colour");
  let label =
    label_box_or_fail root ~id:("palette-" ^ value ^ "-label") ~text:label_text
  in
  check_key
    (value ^ "'s label box carries the id the radio points at")
    label "id"
    (Some ("palette-" ^ value ^ "-label"));
  check_style (value ^ "'s radio carries its style override") (Some red) radio;
  check_interaction
    (value ^ "'s radio carries its interaction override")
    (Some hover_blue) radio;
  check_style
    (value ^ "'s label box carries its style override")
    (Some violet) label

let test_radio_group_aria_survives_every_style_override () =
  let with_label =
    tree (render (RG.view (radio_group_config ~visible_label:(Some true))))
  in
  check_key "the group keeps its role" with_label "role" (Some "radiogroup");
  check_key "the group keeps its id" with_label "id" (Some "palette");
  check_key "the group is named by its visible label" with_label
    "aria-labelledby" (Some "palette-label");
  check_key "and no longer by aria-label" with_label "aria-label" None;
  let group_label =
    label_box_or_fail with_label ~id:"palette-label" ~text:"Favourite colour"
  in
  check_key "the group label box carries the id the group points at" group_label
    "id" (Some "palette-label");
  check_style "the group label box carries its style override" (Some green)
    group_label;
  check_style "the group carries its style override" (Some amber) with_label;
  check_option with_label ~value:"red" ~label_text:"Red";
  check_option with_label ~value:"green" ~label_text:"Green";
  Alcotest.(check int)
    "still one radio per option" 2
    (List.length (find_all (By_tag "radio") with_label));
  (* and the option-row override landed: one row per option, each carrying it *)
  let rows = find_all (By_tag "row") with_label in
  Alcotest.(check int) "one option row per option" 2 (List.length rows);
  List.iter
    (check_style "an option row carries its style override" (Some blue))
    rows;
  (* The affirmative arm for the aria-label absence above, on the same override
     set: without the setter the group is still named, by aria-label. *)
  let without_label =
    tree (render (RG.view (radio_group_config ~visible_label:None)))
  in
  check_key "the group keeps its role" without_label "role" (Some "radiogroup");
  check_key "the group keeps its id" without_label "id" (Some "palette");
  check_key "the group is still named by aria-label" without_label "aria-label"
    (Some "Favourite colour");
  check_key "and points at no label element" without_label "aria-labelledby"
    None;
  check_style "the group still carries its style override" (Some amber)
    without_label;
  check_option without_label ~value:"red" ~label_text:"Red";
  check_option without_label ~value:"green" ~label_text:"Green"

(* --- Toast. The combined configuration: the stack style, the per-variant style,
   the per-variant interaction AND the uniform [config.interaction], which the
   per-variant one outranks. --- *)

let toast_config () : msg T.config =
  {
    T.dismiss = (fun id -> id);
    style = Some amber;
    interaction = Some pressed_amber;
    attrs = [];
    toast_style = Some (fun _variant -> red);
    toast_interaction = Some (fun _variant -> hover_blue);
  }

(* The expected variant word and announcement urgency are written out rather
   than taken from [Toast.aria_live_for], so the oracle is the published contract
   and not whatever the component currently answers. Every variant is present, so
   both urgencies are exercised. *)
let expected_variants =
  [
    (T.Info, "info", "polite");
    (T.Success, "success", "polite");
    (T.Warning, "warning", "assertive");
    (T.Error, "error", "assertive");
  ]

(* Each toast is carried beside the two values its node is expected to answer, so
   the case walks one list. Two lists walked in step would be a [List.iter2] that
   raises the day one of them gains a row. *)
let expected_toasts =
  List.mapi
    (fun i (variant, word, live) ->
      ( {
          T.id = "t" ^ string_of_int i ^ "-" ^ word;
          variant;
          message = "Message " ^ string_of_int i;
        },
        word,
        live ))
    expected_variants

let toasts = List.map (fun (t, _word, _live) -> t) expected_toasts

let test_toast_aria_survives_every_style_override () =
  let config = toast_config () in
  let root = tree (render (T.view config toasts)) in
  check_style "the stack carries its style override" (Some amber) root;
  Alcotest.(check int)
    "still one element per toast" (List.length toasts)
    (List.length (find_all (By_attr ("data-action", "toast-dismiss")) root));
  List.iter
    (fun ((t : T.toast), word, live) ->
      let node =
        find_or_fail
          ("expected the " ^ t.id ^ " toast")
          (By_attr ("data-testid", "toast-" ^ t.id))
          root
      in
      check_key
        (t.id ^ " keeps its testid")
        node "data-testid"
        (Some ("toast-" ^ t.id));
      check_key
        (t.id ^ " keeps the dismiss anchor")
        node "data-action" (Some "toast-dismiss");
      check_key (t.id ^ " keeps its variant") node "data-variant" (Some word);
      check_key
        (t.id ^ " keeps its announcement urgency")
        node "aria-live" (Some live);
      check_key
        (t.id ^ " keeps its accessible name")
        node "aria-label"
        (Some ("Dismiss: " ^ t.message));
      check_style
        (t.id ^ " carries the per-variant style override")
        (Some red) node;
      (* the per-variant interaction outranks the uniform one, which is set here
         precisely so the ordering is being exercised rather than assumed *)
      check_interaction
        (t.id ^ " carries the per-variant interaction override")
        (Some hover_blue) node)
    expected_toasts

(* --- Button. The combined configuration: both state flags, both state styles,
   and the base style and interaction the existing case leaves unset. --- *)

let button_config () : msg B.config =
  {
    B.variant = B.Destructive;
    disabled = true;
    loading = true;
    on_click = Some "clicked";
    style = Some amber;
    interaction = Some hover_blue;
    attrs = [];
    disabled_style = Some red;
    loading_style = Some green;
  }

let test_button_aria_survives_every_style_override () =
  let root = tree (render (B.view (button_config ()) (E.text "Delete"))) in
  let node = find_or_fail "expected a button" (By_tag "button") root in
  check_key "the button keeps aria-disabled" node "aria-disabled" (Some "true");
  check_key "the button keeps aria-busy" node "aria-busy" (Some "true");
  check_key "the button keeps its variant" node "data-variant"
    (Some "destructive");
  (* disabled outranks loading, and both outrank the base style; the base style
     is set here so the ordering is exercised rather than assumed *)
  check_style "the disabled style wins" (Some red) node;
  check_interaction "the interaction override reaches the button"
    (Some hover_blue) node

(* --- A node's attribute list order.

   Not a survival case. A lookup on a node's [attrs] resolves a repeated key to
   the LAST pair, and every lookup in the structural renderer is pinned; the
   POSITION a pair takes in that list is what nothing pinned, because no fixture
   carried both a caller pair and a renderer-derived pair at once. A labelled
   control does: the component contributes its naming pairs and its anchor, the
   caller's own list follows, and the renderer appends what it derives from the
   typed fields. The whole list is asserted, so any reorder reddens.

   The same fixture pins the tier a caller's pair sits in: the caller's
   [aria-labelledby] comes after the component's and therefore wins the lookup,
   which is how a caller replaces a component's ARIA and why the component's
   [.mli] tells them to point it at an element of their own. --- *)

let d11_config () : msg CB.config =
  {
    CB.label = "Accept terms";
    checked = true;
    disabled = true;
    on_toggle = Some (fun b -> string_of_bool b);
    style = Some red;
    interaction = Some hover_blue;
    attrs =
      [ ("data-case", "list-order"); ("aria-labelledby", "caller-target") ];
    id = None;
    label_style = Some green;
    row_style = Some amber;
    on_label_click = Some "label-clicked";
  }

let test_derived_pairs_sit_after_the_component_and_caller_pairs () =
  let root = tree (render (CB.view (d11_config ()))) in
  let box = find_or_fail "expected a checkbox" (By_tag "checkbox") root in
  Alcotest.(check (list (pair string string)))
    "component pairs, then the caller's list, then the derived pairs"
    [
      ("id", "accept-terms");
      ("aria-labelledby", "accept-terms-label");
      ("data-field", "accept-terms");
      ("data-case", "list-order");
      ("aria-labelledby", "caller-target");
      ("checked", "true");
      ("disabled", "true");
    ]
    (attrs_of box);
  check_key "and the lookup answers the caller's later pair" box
    "aria-labelledby" (Some "caller-target")

let () =
  Alcotest.run "nopal_ui_aria_survival"
    [
      ( "aria survives every style override",
        [
          Alcotest.test_case "text input" `Quick
            test_text_input_aria_survives_every_style_override;
          Alcotest.test_case "checkbox" `Quick
            test_checkbox_aria_survives_every_style_override;
          Alcotest.test_case "select input" `Quick
            test_select_input_aria_survives_every_style_override;
          Alcotest.test_case "radio group" `Quick
            test_radio_group_aria_survives_every_style_override;
          Alcotest.test_case "toast" `Quick
            test_toast_aria_survives_every_style_override;
          Alcotest.test_case "button" `Quick
            test_button_aria_survives_every_style_override;
        ] );
      ( "a node's attribute list order",
        [
          Alcotest.test_case "derived pairs sit at the back" `Quick
            test_derived_pairs_sit_after_the_component_and_caller_pairs;
        ] );
    ]
