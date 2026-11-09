open Nopal_test.Test_renderer
module RG = Nopal_ui.Radio_group

type msg = Selected of string | Label_clicked of string

let msg_testable =
  Alcotest.testable
    (fun fmt -> function
      | Selected v -> Format.fprintf fmt "Selected %s" v
      | Label_clicked v -> Format.fprintf fmt "Label_clicked %s" v)
    ( = )

let option_specs = [ ("a", "Alpha"); ("b", "Beta"); ("c", "Gamma") ]

let options =
  List.map (fun (value, label) -> RG.radio_option ~value label) option_specs

let base_config =
  {
    (RG.make ~label:"Pick one" ~options ~selected:"b") with
    on_select = Some (fun v -> Selected v);
  }

(* --- Structure --- *)

let test_container_has_radiogroup_role () =
  let r = render (RG.view base_config) in
  let root = tree r in
  Alcotest.(check (option string))
    "role is radiogroup" (Some "radiogroup") (attr "role" root)

let test_container_has_aria_label () =
  let r = render (RG.view base_config) in
  let root = tree r in
  Alcotest.(check (option string))
    "aria-label matches" (Some "Pick one") (attr "aria-label" root)

let test_renders_all_options () =
  let r = render (RG.view base_config) in
  let radios = find_all (By_tag "radio") (tree r) in
  Alcotest.(check int) "one radio per option" 3 (List.length radios)

let test_selected_radio_is_checked () =
  let r = render (RG.view base_config) in
  let radios = find_all (By_tag "radio") (tree r) in
  let checked_values =
    List.filter_map
      (fun n ->
        match attr "checked" n with
        | Some "true" -> attr "name" n
        | Some _
        | None ->
            None)
      radios
  in
  Alcotest.(check int) "exactly one checked" 1 (List.length checked_values)

let test_unselected_radios_not_checked () =
  let r = render (RG.view base_config) in
  let radios = find_all (By_tag "radio") (tree r) in
  let unchecked =
    List.filter (fun n -> attr "checked" n = Some "false") radios
  in
  Alcotest.(check int) "two unchecked" 2 (List.length unchecked)

(* --- Name --- *)

let test_name_auto_generated_from_label () =
  let r = render (RG.view base_config) in
  let radios = find_all (By_tag "radio") (tree r) in
  List.iter
    (fun n ->
      Alcotest.(check (option string))
        "name is slugified label" (Some "pick-one") (attr "name" n))
    radios

let test_name_override () =
  let config = { base_config with name = Some "custom" } in
  let r = render (RG.view config) in
  let radios = find_all (By_tag "radio") (tree r) in
  List.iter
    (fun n ->
      Alcotest.(check (option string))
        "name is custom" (Some "custom") (attr "name" n))
    radios

(* --- Disabled --- *)

let test_group_disabled_disables_all_radios () =
  let config = { base_config with disabled = true } in
  let r = render (RG.view config) in
  let radios = find_all (By_tag "radio") (tree r) in
  List.iter
    (fun n ->
      Alcotest.(check (option string))
        "disabled is true" (Some "true") (attr "disabled" n))
    radios

let test_group_disabled_suppresses_on_select () =
  let config = { base_config with disabled = true } in
  let r = render (RG.view config) in
  let result = click (By_tag "radio") r in
  (match result with
  | Ok () -> Alcotest.fail "expected click to fail on disabled radio"
  | Error _ -> ());
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

let test_option_disabled_disables_single_radio () =
  let opts =
    [
      RG.radio_option ~value:"a" "Alpha";
      RG.radio_option ~disabled:true ~value:"b" "Beta";
      RG.radio_option ~value:"c" "Gamma";
    ]
  in
  let config =
    {
      (RG.make ~label:"Pick one" ~options:opts ~selected:"a") with
      on_select = Some (fun v -> Selected v);
    }
  in
  let r = render (RG.view config) in
  let radios = find_all (By_tag "radio") (tree r) in
  let disabled_states =
    List.map (fun n -> attr "disabled" n = Some "true") radios
  in
  Alcotest.(check (list bool))
    "only second disabled" [ false; true; false ] disabled_states

(* --- Events --- *)

let test_on_select_dispatches () =
  let config =
    {
      (RG.make ~label:"Pick one" ~options ~selected:"b") with
      on_select = Some (fun v -> Selected v);
    }
  in
  let r = render (RG.view config) in
  let result = click (By_tag "radio") r in
  Alcotest.(check (result unit Test_util.error_testable))
    "click ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "selected first option" [ Selected "a" ] (messages r)

(* --- Label elements, identifiers and association --- *)

let style_testable = Test_util.style_testable
let text_style_testable = Test_util.text_style_testable
let bold_label_style = Test_util.bold_label_style

let wide_row_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      { l with Nopal_style.Style.gap = Some 12.0 })

let padded_group_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      { l with Nopal_style.Style.gap = Some 20.0 })

let find_or_fail = Test_util.find_or_fail
let group_label = "Pick one"
let base () = RG.make ~label:group_label ~options ~selected:"b"

let test_option_label_box_carries_the_generated_id () =
  let r = render (RG.view (base ())) in
  List.iter
    (fun (value, label) ->
      let id = "pick-one-" ^ value ^ "-label" in
      let label_node =
        find_or_fail
          ("expected a label element carrying id=" ^ id)
          (By_attr ("id", id))
          (tree r)
      in
      Alcotest.(check string) "label text" label (text_content label_node);
      match label_node with
      | Element { tag = "box"; children = [ Text _ ]; _ } -> ()
      | Element { tag; _ } ->
          Alcotest.failf
            "the generated id sits on a %s rather than on a label element \
             wrapping the option's text"
            tag
      | Empty
      | Text _ ->
          Alcotest.fail "expected the generated id on an element")
    option_specs

let test_option_is_named_by_labelledby_and_not_by_label () =
  let config = base () in
  let r = render (RG.view config) in
  List.iter
    (fun (value, label) ->
      let radio =
        find_or_fail
          ("expected the radio option for value " ^ value)
          (By_attr ("id", RG.option_id config ~value))
          (tree r)
      in
      match attr "aria-labelledby" radio with
      | None -> Alcotest.fail "expected aria-labelledby on the radio option"
      | Some target ->
          let named =
            find_or_fail "aria-labelledby names no element in the tree"
              (By_attr ("id", target))
              (tree r)
          in
          Alcotest.(check string)
            "the named element is the option's visible label" label
            (text_content named);
          Alcotest.(check (option string))
            "aria-label no longer names the option" None
            (attr "aria-label" radio))
    option_specs

let test_tree_without_the_visible_label_setter () =
  let r = render (RG.view (base ())) in
  (match tree r with
  | Element
      { tag = "box"; children = [ Element { tag = "box"; children; _ } ]; _ } ->
      Alcotest.(check int)
        "the options box holds one row per option and nothing else" 3
        (List.length children);
      List.iter
        (fun child ->
          match child with
          | Element { tag = "row"; children = [ radio; label ]; _ } -> (
              (match radio with
              | Element { tag = "radio"; _ } -> ()
              | Element { tag; _ } ->
                  Alcotest.failf "expected a radio first in the row, got %s" tag
              | Empty
              | Text _ ->
                  Alcotest.fail "expected a radio element first in the row");
              match label with
              | Element { tag = "box"; _ } -> ()
              | Element { tag; _ } ->
                  Alcotest.failf "expected the label box second, got %s" tag
              | Empty
              | Text _ ->
                  Alcotest.fail "expected the label element second in the row")
          | Element { tag; _ } ->
              Alcotest.failf
                "expected only option rows under the group, found a %s" tag
          | Empty
          | Text _ ->
              Alcotest.fail "expected only option rows under the group")
        children
  | Element { tag; _ } ->
      Alcotest.failf
        "expected a box holding only the options box at the top level, got %s"
        tag
  | Empty
  | Text _ ->
      Alcotest.fail "expected an element at the top level");
  Alcotest.(check bool)
    "no group label node appears without the setter" false
    (Option.is_some (find (By_attr ("id", "pick-one-label")) (tree r)))

let test_group_keeps_aria_label_without_the_setter () =
  let r = render (RG.view (base ())) in
  let root = tree r in
  Alcotest.(check (option string))
    "the group is still named by aria-label" (Some group_label)
    (attr "aria-label" root);
  Alcotest.(check (option string))
    "and carries no aria-labelledby, which would have no target" None
    (attr "aria-labelledby" root);
  Alcotest.(check (option string))
    "role is unchanged" (Some "radiogroup") (attr "role" root)

let test_visible_label_switches_the_group_to_labelledby () =
  let config = RG.with_visible_label true (base ()) in
  let r = render (RG.view config) in
  let root = tree r in
  Alcotest.(check (option string))
    "the group's name moves to aria-labelledby" (Some "pick-one-label")
    (attr "aria-labelledby" root);
  Alcotest.(check (option string))
    "and aria-label is gone, so the two cannot disagree" None
    (attr "aria-label" root);
  let label_node =
    find_or_fail "expected the group label element"
      (By_attr ("id", "pick-one-label"))
      root
  in
  Alcotest.(check string)
    "the group label renders the group's label text" group_label
    (text_content label_node);
  match root with
  | Element { children = [ first; Element { children = rows; _ } ]; _ } -> (
      Alcotest.(check int)
        "the option rows are still all there, in the options box" 3
        (List.length rows);
      match first with
      | Element { tag = "box"; _ } -> ()
      | Element { tag; _ } ->
          Alcotest.failf "expected the group label first, got %s" tag
      | Empty
      | Text _ ->
          Alcotest.fail "expected the group label element first")
  | Element _ -> Alcotest.fail "expected the group label and the options box"
  | Empty
  | Text _ ->
      Alcotest.fail "expected an element at the top level"

let test_with_id_overrides_every_generated_id () =
  let config = RG.with_id "fruit" (RG.with_visible_label true (base ())) in
  let r = render (RG.view config) in
  let root = tree r in
  Alcotest.(check (option string))
    "the group id" (Some "fruit") (attr "id" root);
  Alcotest.(check (option string))
    "the group's labelledby follows it" (Some "fruit-label")
    (attr "aria-labelledby" root);
  List.iter
    (fun (value, _label) ->
      let radio =
        find_or_fail
          ("expected the radio option at the explicit id for " ^ value)
          (By_attr ("id", "fruit-" ^ value))
          root
      in
      Alcotest.(check (option string))
        "the option's labelledby follows it"
        (Some ("fruit-" ^ value ^ "-label"))
        (attr "aria-labelledby" radio);
      Alcotest.(check bool)
        "the slug-derived option id is replaced, not joined" false
        (Option.is_some (find (By_attr ("id", "pick-one-" ^ value)) root));
      Alcotest.(check (option string))
        "the E2E anchor stays on the group name" (Some "pick-one")
        (attr "data-field" radio))
    option_specs;
  Alcotest.(check bool)
    "the slug-derived group label id is replaced, not joined" false
    (Option.is_some (find (By_attr ("id", "pick-one-label")) root))

let test_control_id_and_option_id_name_the_rendered_ids () =
  let derived = base () in
  Alcotest.(check string)
    "the group id derives from the label" "pick-one" (RG.control_id derived);
  Alcotest.(check (option string))
    "the accessor names the rendered group"
    (Some (RG.control_id derived))
    (attr "id" (tree (render (RG.view derived))));
  List.iter
    (fun (value, _label) ->
      Alcotest.(check string)
        "the option id derives from the label and the value"
        ("pick-one-" ^ value)
        (RG.option_id derived ~value);
      Alcotest.(check bool)
        "the accessor names a rendered option" true
        (Option.is_some
           (find
              (By_attr ("id", RG.option_id derived ~value))
              (tree (render (RG.view derived))))))
    option_specs;
  let explicit = RG.with_id "fruit" derived in
  Alcotest.(check string)
    "explicit id wins for the group" "fruit" (RG.control_id explicit);
  Alcotest.(check string)
    "explicit id wins for an option" "fruit-b"
    (RG.option_id explicit ~value:"b")

let test_option_label_style_reaches_the_option_label () =
  let r =
    render (RG.view (RG.with_option_label_style bold_label_style (base ())))
  in
  List.iter
    (fun (value, label) ->
      let label_node =
        find_or_fail "expected the option label element"
          (By_attr ("id", "pick-one-" ^ value ^ "-label"))
          (tree r)
      in
      Alcotest.(check (option style_testable))
        "option label style on the label box" (Some bold_label_style)
        (style label_node);
      let text_node =
        find_or_fail "expected the option label's text node" (By_text label)
          label_node
      in
      Alcotest.(check (option text_style_testable))
        "the style's text component reaches the text node"
        (Some bold_label_style.Nopal_style.Style.text) (text_style text_node))
    option_specs

let test_option_row_style_reaches_the_option_row () =
  let r =
    render (RG.view (RG.with_option_row_style wide_row_style (base ())))
  in
  let rows = find_all (By_tag "row") (tree r) in
  Alcotest.(check int) "one row per option" 3 (List.length rows);
  List.iter
    (fun row ->
      Alcotest.(check (option style_testable))
        "row style on the radio-to-label row" (Some wide_row_style) (style row))
    rows

let test_group_style_reaches_the_group () =
  let r = render (RG.view (RG.with_group_style padded_group_style (base ()))) in
  Alcotest.(check (option style_testable))
    "group style on the group container" (Some padded_group_style)
    (style (tree r));
  let radios = find_all (By_tag "radio") (tree r) in
  Alcotest.(check int) "one radio per option" 3 (List.length radios);
  List.iter
    (fun radio ->
      let carries_the_group_style =
        match style radio with
        | Some s -> Nopal_style.Style.equal s padded_group_style
        | None -> false
      in
      Alcotest.(check bool)
        "and not on the radio inputs, which have their own field" false
        carries_the_group_style)
    radios

let test_label_style_reaches_the_group_label () =
  let config =
    RG.with_label_style bold_label_style (RG.with_visible_label true (base ()))
  in
  let r = render (RG.view config) in
  let label_node =
    find_or_fail "expected the group label element"
      (By_attr ("id", "pick-one-label"))
      (tree r)
  in
  Alcotest.(check (option style_testable))
    "label style on the group label box" (Some bold_label_style)
    (style label_node);
  let text_node =
    find_or_fail "expected the group label's text node" (By_text group_label)
      label_node
  in
  Alcotest.(check (option text_style_testable))
    "the style's text component reaches the text node"
    (Some bold_label_style.Nopal_style.Style.text) (text_style text_node)

let test_option_label_click_dispatches_the_option_value () =
  let without = render (RG.view (base ())) in
  Alcotest.(check bool)
    "no pointer handler on the option label without the setter" true
    (Result.is_error
       (box_pointer_down
          (By_attr ("id", "pick-one-b-label"))
          ~x:0.0 ~y:0.0 without));
  let r =
    render
      (RG.view (RG.with_on_label_click (fun v -> Label_clicked v) (base ())))
  in
  let result =
    box_pointer_down (By_attr ("id", "pick-one-c-label")) ~x:3.0 ~y:4.0 r
  in
  Alcotest.(check (result unit Test_util.error_testable))
    "pointer down ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "the clicked option's value is carried" [ Label_clicked "c" ] (messages r)

(* --- Hidden inputs and option-row interaction --- *)

let hidden () = RG.with_hidden_inputs (base ())

let option_label_selector config ~value =
  By_attr ("id", RG.option_id config ~value ^ "-label")

let check_option_inputs what config ~presentation ~label_tag ~names_its_radio =
  let r = render (RG.view config) in
  List.iter
    (fun (value, _) ->
      let oid = RG.option_id config ~value in
      Alcotest.(
        check (result Test_util.presentation_testable Test_util.error_testable))
        (what ^ ": radio " ^ value ^ " presentation")
        (Ok presentation)
        (radio_presentation (By_attr ("id", oid)) r);
      let label_node =
        find_or_fail
          (what ^ ": expected the label element of option " ^ value)
          (option_label_selector config ~value)
          (tree r)
      in
      Alcotest.(check string)
        (what ^ ": option " ^ value ^ " label element")
        label_tag
        (Test_util.tag_of what label_node);
      let expected_for = if names_its_radio then Some oid else None in
      Alcotest.(check (option string))
        (what ^ ": option " ^ value ^ " label for")
        expected_for (attr "for" label_node))
    option_specs

let test_hidden_inputs_reach_every_option () =
  check_option_inputs "hidden inputs" (hidden ())
    ~presentation:Nopal_style.Presentation.Visually_hidden ~label_tag:"label"
    ~names_its_radio:true;
  check_option_inputs "default inputs" (base ())
    ~presentation:Nopal_style.Presentation.Visible ~label_tag:"box"
    ~names_its_radio:false

let check_no_label_handler what config =
  let r = render (RG.view config) in
  List.iter
    (fun (value, _) ->
      match
        box_pointer_down (option_label_selector config ~value) ~x:0.0 ~y:0.0 r
      with
      | Error (No_handler _) -> ()
      | Error e ->
          Alcotest.failf "%s: option %s's label: expected No_handler, got %s"
            what value
            (Format.asprintf "%a" (Alcotest.pp Test_util.error_testable) e)
      | Ok () ->
          Alcotest.failf "%s: option %s's label carries a pointer handler" what
            value)
    option_specs;
  Alcotest.(check (list msg_testable))
    (what ^ ": nothing dispatched")
    [] (messages r)

let clicked v = Label_clicked v

let test_on_label_click_unrepresentable_when_hidden () =
  check_no_label_handler "label click, then hidden inputs"
    (RG.with_hidden_inputs (RG.with_on_label_click clicked (base ())));
  check_no_label_handler "hidden inputs, then label click"
    (RG.with_on_label_click clicked (RG.with_hidden_inputs (base ())));
  let visible = RG.with_on_label_click clicked (base ()) in
  let r = render (RG.view visible) in
  Alcotest.(check (result unit Test_util.error_testable))
    "visible inputs: the label carries the pointer handler" (Ok ())
    (box_pointer_down
       (option_label_selector visible ~value:"a")
       ~x:0.0 ~y:0.0 r);
  Alcotest.(check (list msg_testable))
    "visible inputs: the pressed option's value is dispatched"
    [ Label_clicked "a" ] (messages r)

let test_hidden_label_keeps_label_id_and_style () =
  let config = RG.with_option_label_style bold_label_style (hidden ()) in
  let r = render (RG.view config) in
  List.iter
    (fun (value, label) ->
      let oid = RG.option_id config ~value in
      let radio =
        find_or_fail
          ("expected the radio for option " ^ value)
          (By_attr ("id", oid))
          (tree r)
      in
      Alcotest.(check (option string))
        "the radio is still named by the option's label id"
        (Some (oid ^ "-label"))
        (attr "aria-labelledby" radio);
      let label_node =
        find_or_fail
          ("expected the label element of option " ^ value)
          (By_attr ("id", oid ^ "-label"))
          (tree r)
      in
      Alcotest.(check string)
        "the label id sits on the native label" "label"
        (Test_util.tag_of "option label" label_node);
      Alcotest.(check (option style_testable))
        "option label style on the native label" (Some bold_label_style)
        (style label_node);
      Alcotest.(check string) "label text" label (text_content label_node);
      let text_node =
        find_or_fail "expected the option label's text node" (By_text label)
          label_node
      in
      Alcotest.(check (option text_style_testable))
        "the style's text component reaches the text node"
        (Some bold_label_style.Nopal_style.Style.text) (text_style text_node))
    option_specs

let row_ring : Nopal_style.Interaction.t =
  {
    hover = None;
    pressed = None;
    focused = None;
    focused_within = Some wide_row_style;
  }

let rec elements node =
  match node with
  | Element { children; _ } -> node :: List.concat_map elements children
  | Empty
  | Text _ ->
      []

let carries_row_ring node =
  match interaction node with
  | Some i -> Nopal_style.Interaction.equal i row_ring
  | None -> false

let test_with_option_row_interaction_reaches_every_row () =
  let r =
    render (RG.view (RG.with_option_row_interaction row_ring (base ())))
  in
  let rows = find_all (By_tag "row") (tree r) in
  Alcotest.(check int) "one row per option" 3 (List.length rows);
  List.iter
    (fun row ->
      Alcotest.(check bool)
        "the row carries the interaction" true (carries_row_ring row))
    rows;
  let others =
    List.filter
      (fun node -> Test_util.tag_of "element" node <> "row")
      (elements (tree r))
  in
  Alcotest.(check (list string))
    "no other node carries the interaction" []
    (List.map
       (Test_util.tag_of "element")
       (List.filter carries_row_ring others))

(* --- The outer box and the options box --- *)

let options_row_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      {
        l with
        Nopal_style.Style.direction = Some Nopal_style.Style.Row_dir;
        gap = Some 6.0;
      })

(* An option row holds the radio and the option's label box, in that order. *)
let check_option_rows what rows =
  Alcotest.(check int) (what ^ ": one row per option") 3 (List.length rows);
  List.iter
    (fun row ->
      match row with
      | Element
          { tag = "row"; children = [ Element { tag = "radio"; _ }; _ ]; _ } ->
          ()
      | Element { tag; _ } ->
          Alcotest.failf "%s: expected an option row, found a %s" what tag
      | Empty
      | Text _ ->
          Alcotest.failf "%s: expected an option row element" what)
    rows

let options_box_rows what node =
  match node with
  | Element { tag = "box"; children; _ } -> children
  | Element { tag; _ } ->
      Alcotest.failf "%s: expected the options box, found a %s" what tag
  | Empty
  | Text _ ->
      Alcotest.failf "%s: expected the options box element" what

let children_of what node =
  match node with
  | Element { children; _ } -> children
  | Empty
  | Text _ ->
      Alcotest.failf "%s: expected an element" what

let attrs_of what node =
  match node with
  | Element { attrs; _ } -> attrs
  | Empty
  | Text _ ->
      Alcotest.failf "%s: expected an element" what

let test_label_and_options_are_separate_boxes () =
  let root = tree (render (RG.view (RG.with_visible_label true (base ())))) in
  match children_of "the group" root with
  | [ label; options ] ->
      Alcotest.(check (option string))
        "the first child is the group label" (Some "pick-one-label")
        (attr "id" label);
      Alcotest.(check string)
        "the group label holds the label text and no option" group_label
        (text_content label);
      check_option_rows "the options box"
        (options_box_rows "the second child" options)
  | children ->
      Alcotest.failf
        "expected the group to hold exactly the label and the options box, got \
         %d children"
        (List.length children)

let test_options_box_present_without_visible_label () =
  List.iter
    (fun (mode, config) ->
      let root = tree (render (RG.view config)) in
      (match children_of mode root with
      | [ options ] ->
          check_option_rows mode
            (options_box_rows (mode ^ ": the child") options);
          Alcotest.(check (option style_testable))
            (mode ^ ": the options box has the default style")
            (style (tree (render (Nopal_element.Element.box []))))
            (style options)
      | children ->
          Alcotest.failf
            "%s: expected the options box as the group's only child, got %d \
             children"
            mode (List.length children));
      Alcotest.(check bool)
        (mode ^ ": no group label node")
        false
        (Option.is_some (find (By_attr ("id", "pick-one-label")) root)))
    [
      ("without the setter", base ());
      ("with false", RG.with_visible_label false (base ()));
    ]

let test_options_style_reaches_options_box () =
  List.iter
    (fun visible ->
      let config =
        base ()
        |> RG.with_visible_label visible
        |> RG.with_group_style padded_group_style
        |> RG.with_options_style options_row_style
      in
      let root = tree (render (RG.view config)) in
      let options =
        match List.rev (children_of "the group" root) with
        | last :: _ -> last
        | [] -> Alcotest.fail "expected the group to hold the options box"
      in
      check_option_rows "the styled options box"
        (options_box_rows "the last child" options);
      Alcotest.(check (option style_testable))
        "the options style is the options box's style" (Some options_row_style)
        (style options);
      Alcotest.(check (option style_testable))
        "the group style stays on the group, not the options style"
        (Some padded_group_style) (style root))
    [ true; false ]

let test_group_container_is_a_box () =
  List.iter
    (fun (mode, config) ->
      match tree (render (RG.view config)) with
      | Element { tag = "box"; attrs; _ } ->
          Alcotest.(check (option string))
            (mode ^ ": the box is the radiogroup")
            (Some "radiogroup")
            (List.assoc_opt "role" attrs)
      | Element { tag; _ } ->
          Alcotest.failf "%s: expected the radiogroup to be a box, got a %s"
            mode tag
      | Empty
      | Text _ ->
          Alcotest.failf "%s: expected an element at the top level" mode)
    [
      ("without a visible label", base ());
      ("with a visible label", RG.with_visible_label true (base ()));
    ]

let test_role_and_name_stay_on_outer_box () =
  List.iter
    (fun (mode, visible, naming) ->
      let config =
        {
          (RG.with_visible_label visible (RG.with_id "fruit" (base ()))) with
          attrs = [ ("data-testid", "fruit-group") ];
        }
      in
      let root = tree (render (RG.view config)) in
      Alcotest.(check (list (pair string string)))
        (mode ^ ": the outer box carries role, name, id and attrs, in order")
        [
          ("role", "radiogroup");
          naming;
          ("id", "fruit");
          ("data-testid", "fruit-group");
        ]
        (attrs_of "the group" root);
      let options =
        match List.rev (children_of "the group" root) with
        | last :: _ -> last
        | [] -> Alcotest.fail "expected the group to hold the options box"
      in
      check_option_rows mode
        (options_box_rows (mode ^ ": the options box") options);
      Alcotest.(check (list (pair string string)))
        (mode ^ ": the options box carries no attribute")
        []
        (attrs_of "the options box" options))
    [
      ("without a visible label", false, ("aria-label", group_label));
      ("with a visible label", true, ("aria-labelledby", "fruit-label"));
    ]

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_ui_radio_group"
    [
      ( "structure",
        [
          Alcotest.test_case "container has radiogroup role" `Quick
            test_container_has_radiogroup_role;
          Alcotest.test_case "container has aria label" `Quick
            test_container_has_aria_label;
          Alcotest.test_case "renders all options" `Quick
            test_renders_all_options;
          Alcotest.test_case "selected radio is checked" `Quick
            test_selected_radio_is_checked;
          Alcotest.test_case "unselected radios not checked" `Quick
            test_unselected_radios_not_checked;
        ] );
      ( "name",
        [
          Alcotest.test_case "name auto generated from label" `Quick
            test_name_auto_generated_from_label;
          Alcotest.test_case "name override" `Quick test_name_override;
        ] );
      ( "disabled",
        [
          Alcotest.test_case "group disabled disables all radios" `Quick
            test_group_disabled_disables_all_radios;
          Alcotest.test_case "group disabled suppresses on_select" `Quick
            test_group_disabled_suppresses_on_select;
          Alcotest.test_case "option disabled disables single radio" `Quick
            test_option_disabled_disables_single_radio;
        ] );
      ( "events",
        [
          Alcotest.test_case "on_select dispatches" `Quick
            test_on_select_dispatches;
          Alcotest.test_case "option label click dispatches the option value"
            `Quick test_option_label_click_dispatches_the_option_value;
        ] );
      ( "label element, identifier and association",
        [
          Alcotest.test_case "option label box carries the generated id" `Quick
            test_option_label_box_carries_the_generated_id;
          Alcotest.test_case "option is named by labelledby and not by label"
            `Quick test_option_is_named_by_labelledby_and_not_by_label;
          Alcotest.test_case "tree without the visible label setter" `Quick
            test_tree_without_the_visible_label_setter;
          Alcotest.test_case "group keeps aria label without the setter" `Quick
            test_group_keeps_aria_label_without_the_setter;
          Alcotest.test_case "visible label switches the group to labelledby"
            `Quick test_visible_label_switches_the_group_to_labelledby;
          Alcotest.test_case "with_id overrides every generated id" `Quick
            test_with_id_overrides_every_generated_id;
          Alcotest.test_case "control_id and option_id name the rendered ids"
            `Quick test_control_id_and_option_id_name_the_rendered_ids;
        ] );
      ( "style overrides",
        [
          Alcotest.test_case "option label style reaches the option label"
            `Quick test_option_label_style_reaches_the_option_label;
          Alcotest.test_case "option row style reaches the option row" `Quick
            test_option_row_style_reaches_the_option_row;
          Alcotest.test_case "group style reaches the group" `Quick
            test_group_style_reaches_the_group;
          Alcotest.test_case "label style reaches the group label" `Quick
            test_label_style_reaches_the_group_label;
        ] );
      ( "hidden inputs and option-row interaction",
        [
          Alcotest.test_case "hidden_inputs_reach_every_option" `Quick
            test_hidden_inputs_reach_every_option;
          Alcotest.test_case "on_label_click_unrepresentable_when_hidden" `Quick
            test_on_label_click_unrepresentable_when_hidden;
          Alcotest.test_case "hidden_label_keeps_label_id_and_style" `Quick
            test_hidden_label_keeps_label_id_and_style;
          Alcotest.test_case "with_option_row_interaction_reaches_every_row"
            `Quick test_with_option_row_interaction_reaches_every_row;
        ] );
      ( "outer box and options box",
        [
          Alcotest.test_case "label_and_options_are_separate_boxes" `Quick
            test_label_and_options_are_separate_boxes;
          Alcotest.test_case "options_box_present_without_visible_label" `Quick
            test_options_box_present_without_visible_label;
          Alcotest.test_case "options_style_reaches_options_box" `Quick
            test_options_style_reaches_options_box;
          Alcotest.test_case "group_container_is_a_box" `Quick
            test_group_container_is_a_box;
          Alcotest.test_case "role_and_name_stay_on_outer_box" `Quick
            test_role_and_name_stay_on_outer_box;
        ] );
    ]
