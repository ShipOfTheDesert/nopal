open Nopal_test.Test_renderer
module E = Nopal_element.Element
module Ix = Nopal_style.Interaction

let ix0 = Ix.default
let s0 = Nopal_style.Style.default
let check_node = Test_util.check_node

type msg =
  | Toggled of bool
  | Selected
  | Changed of string
  | Wrapped_toggle of bool
  | Wrapped_selected
  | Wrapped_changed of string

(* --- Checkbox (4) --- *)

let checkbox_renders_as_checkbox_tag () =
  let r = render (E.checkbox true) in
  check_node "checkbox checked=true renders tag checkbox"
    (Element
       {
         tag = "checkbox";
         style = s0;
         attrs = [ ("checked", "true") ];
         children = [];
         interaction = ix0;
       })
    (tree r)

let checkbox_unchecked_has_checked_false () =
  let r = render (E.checkbox false) in
  Alcotest.(check (option string))
    "checked attr is false" (Some "false")
    (attr "checked" (tree r))

let checkbox_disabled_has_disabled_attr () =
  let r =
    render (E.checkbox ~disabled:true ~on_toggle:(fun b -> Toggled b) false)
  in
  Alcotest.(check (option string))
    "disabled attr is true" (Some "true")
    (attr "disabled" (tree r));
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check bool)
    "disabled checkbox has no handler" true (Result.is_error result)

let checkbox_toggle_fires_negated_state () =
  let r = render (E.checkbox ~on_toggle:(fun b -> Toggled b) true) in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check bool) "toggle succeeds" true (Result.is_ok result);
  (match messages r with
  | [ Toggled false ] -> ()
  | _ -> Alcotest.fail "expected [Toggled false] for checked checkbox");
  clear_messages r;
  let r2 = render (E.checkbox ~on_toggle:(fun b -> Toggled b) false) in
  let result2 = toggle (By_tag "checkbox") r2 in
  Alcotest.(check bool) "toggle succeeds" true (Result.is_ok result2);
  match messages r2 with
  | [ Toggled true ] -> ()
  | _ -> Alcotest.fail "expected [Toggled true] for unchecked checkbox"

(* --- Radio (4) --- *)

let radio_renders_as_radio_tag_with_name () =
  let r = render (E.radio ~name:"color" ()) in
  check_node "radio renders tag radio with name"
    (Element
       {
         tag = "radio";
         style = s0;
         attrs = [ ("name", "color"); ("checked", "false") ];
         children = [];
         interaction = ix0;
       })
    (tree r)

let radio_checked_has_checked_attr () =
  let r = render (E.radio ~name:"color" ~checked:true ()) in
  Alcotest.(check (option string))
    "checked attr is true" (Some "true")
    (attr "checked" (tree r))

let radio_disabled_suppresses_on_select () =
  let r =
    render (E.radio ~name:"color" ~disabled:true ~on_select:Selected ())
  in
  Alcotest.(check (option string))
    "disabled attr is true" (Some "true")
    (attr "disabled" (tree r));
  let result = click (By_tag "radio") r in
  Alcotest.(check bool)
    "disabled radio has no handler" true (Result.is_error result)

let radio_select_fires_message () =
  let r = render (E.radio ~name:"color" ~on_select:Selected ()) in
  let result = click (By_tag "radio") r in
  Alcotest.(check bool) "click succeeds" true (Result.is_ok result);
  match messages r with
  | [ Selected ] -> ()
  | _ -> Alcotest.fail "expected [Selected]"

(* --- Select (5) --- *)

let opts =
  [
    E.select_option ~value:"a" "Alpha";
    E.select_option ~value:"b" "Beta";
    E.select_option ~disabled:true ~value:"c" "Gamma";
  ]

let select_renders_as_select_tag_with_options () =
  let r = render (E.select ~selected:"a" opts) in
  check_node "select renders tag select with option children"
    (Element
       {
         tag = "select";
         style = s0;
         attrs = [ ("selected", "a") ];
         children =
           [
             Element
               {
                 tag = "option";
                 style = s0;
                 attrs = [ ("value", "a"); ("label", "Alpha") ];
                 children = [];
                 interaction = ix0;
               };
             Element
               {
                 tag = "option";
                 style = s0;
                 attrs = [ ("value", "b"); ("label", "Beta") ];
                 children = [];
                 interaction = ix0;
               };
             Element
               {
                 tag = "option";
                 style = s0;
                 attrs =
                   [ ("value", "c"); ("label", "Gamma"); ("disabled", "true") ];
                 children = [];
                 interaction = ix0;
               };
           ];
         interaction = ix0;
       })
    (tree r)

let select_selected_value_in_attrs () =
  let r = render (E.select ~selected:"b" opts) in
  Alcotest.(check (option string))
    "selected attr is b" (Some "b")
    (attr "selected" (tree r))

let select_disabled_option_has_disabled_attr () =
  let r = render (E.select ~selected:"a" opts) in
  let option_nodes = find_all (By_tag "option") (tree r) in
  let third =
    match option_nodes with
    | [ _; _; third ] -> third
    | _ -> Alcotest.fail "expected 3 option children"
  in
  Alcotest.(check (option string))
    "third option disabled" (Some "true") (attr "disabled" third)

let select_disabled_suppresses_on_change () =
  let r =
    render
      (E.select ~disabled:true
         ~on_change:(fun v -> Changed v)
         ~selected:"a" opts)
  in
  Alcotest.(check (option string))
    "disabled attr is true" (Some "true")
    (attr "disabled" (tree r));
  let result = input (By_tag "select") "b" r in
  Alcotest.(check bool)
    "disabled select has no handler" true (Result.is_error result)

let select_change_fires_new_value () =
  let r =
    render (E.select ~on_change:(fun v -> Changed v) ~selected:"a" opts)
  in
  let result = input (By_tag "select") "b" r in
  Alcotest.(check bool) "change succeeds" true (Result.is_ok result);
  match messages r with
  | [ Changed "b" ] -> ()
  | _ -> Alcotest.fail "expected [Changed \"b\"]"

(* --- Map (3) --- *)

let map_transforms_checkbox_msg () =
  let el = E.checkbox ~on_toggle:(fun b -> Toggled b) true in
  let mapped =
    E.map
      (fun m ->
        Wrapped_toggle
          (match m with
          | Toggled b -> b
          | Selected
          | Changed _
          | Wrapped_toggle _
          | Wrapped_selected
          | Wrapped_changed _ ->
              false))
      el
  in
  let r = render mapped in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check bool) "toggle succeeds" true (Result.is_ok result);
  match messages r with
  | [ Wrapped_toggle false ] -> ()
  | _ -> Alcotest.fail "expected [Wrapped_toggle false]"

let map_transforms_radio_msg () =
  let el = E.radio ~name:"color" ~on_select:Selected () in
  let mapped = E.map (fun _m -> Wrapped_selected) el in
  let r = render mapped in
  let result = click (By_tag "radio") r in
  Alcotest.(check bool) "click succeeds" true (Result.is_ok result);
  match messages r with
  | [ Wrapped_selected ] -> ()
  | _ -> Alcotest.fail "expected [Wrapped_selected]"

let map_transforms_select_msg () =
  let el = E.select ~on_change:(fun v -> Changed v) ~selected:"a" opts in
  let mapped =
    E.map
      (fun m ->
        match m with
        | Changed v -> Wrapped_changed v
        | Toggled _
        | Selected
        | Wrapped_toggle _
        | Wrapped_selected
        | Wrapped_changed _ ->
            Wrapped_changed "?")
      el
  in
  let r = render mapped in
  let result = input (By_tag "select") "b" r in
  Alcotest.(check bool) "change succeeds" true (Result.is_ok result);
  match messages r with
  | [ Wrapped_changed "b" ] -> ()
  | _ -> Alcotest.fail "expected [Wrapped_changed \"b\"]"

(* --- Equal (2) --- *)

let equal_checkbox_same_fields () =
  let make () = E.checkbox ~disabled:true true in
  Alcotest.(check bool)
    "same checkbox fields are equal" true
    (E.equal (make ()) (make ()))

let equal_select_different_options () =
  let a = E.select ~selected:"a" [ E.select_option ~value:"a" "Alpha" ] in
  let b =
    E.select ~selected:"a"
      [ E.select_option ~value:"a" "Alpha"; E.select_option ~value:"b" "Beta" ]
  in
  Alcotest.(check bool) "different options not equal" false (E.equal a b)

(* --- Form (4) --- *)

type form_msg =
  | Signed_in
  | Field_entered
  | Carrying of (unit -> unit)
  | Wrapped of form_msg

(* A form's fields, lifted out of the inline record so each case can assert on
   them by name. Every other variant fails the case: these cases are about a
   form, so anything else reaching here is the defect. *)
type form_fields = {
  f_style : Nopal_style.Style.t;
  f_interaction : Ix.t;
  f_attrs : (string * string) list;
  f_children : form_msg E.t list;
  f_on_submit : form_msg option;
  f_autocomplete : E.autocomplete_mode option;
  f_novalidate : bool;
}

let form_fields label (el : form_msg E.t) =
  match el with
  | E.Form
      {
        style;
        interaction;
        attrs;
        children;
        on_submit;
        autocomplete;
        novalidate;
      } ->
      {
        f_style = style;
        f_interaction = interaction;
        f_attrs = attrs;
        f_children = children;
        f_on_submit = on_submit;
        f_autocomplete = autocomplete;
        f_novalidate = novalidate;
      }
  | E.Empty
  | E.Text _
  | E.Box _
  | E.Row _
  | E.Column _
  | E.Button _
  | E.Input _
  | E.Checkbox _
  | E.Radio _
  | E.Select _
  | E.File_input _
  | E.Image _
  | E.Scroll _
  | E.Keyed _
  | E.Draw _
  | E.Virtual_list _ ->
      Alcotest.fail (label ^ ": expected a Form")

(* An input's three typed fields and its submission handler, lifted out of the
   inline record the same way [form_fields] lifts a form's. Every other variant
   fails the case. *)
type input_fields = {
  i_required : bool;
  i_autocomplete : string option;
  i_input_type : E.input_type option;
  i_on_submit : form_msg option;
}

let input_fields label (el : form_msg E.t) =
  match el with
  | E.Input { required; autocomplete; input_type; on_submit; _ } ->
      {
        i_required = required;
        i_autocomplete = autocomplete;
        i_input_type = input_type;
        i_on_submit = on_submit;
      }
  | E.Empty
  | E.Text _
  | E.Box _
  | E.Row _
  | E.Column _
  | E.Form _
  | E.Button _
  | E.Checkbox _
  | E.Radio _
  | E.Select _
  | E.File_input _
  | E.Image _
  | E.Scroll _
  | E.Keyed _
  | E.Draw _
  | E.Virtual_list _ ->
      Alcotest.fail (label ^ ": expected an Input")

let input_type_name (t : E.input_type) =
  match t with
  | E.Plain -> "Plain"
  | E.Password -> "Password"
  | E.Email -> "Email"
  | E.Tel -> "Tel"
  | E.Url -> "Url"
  | E.Number -> "Number"
  | E.Search -> "Search"

(* By name rather than by polymorphic compare, so the testable states its own
   notion of equality. *)
let input_type_testable =
  Alcotest.testable
    (fun ppf t -> Format.pp_print_string ppf (input_type_name t))
    (fun a b -> String.equal (input_type_name a) (input_type_name b))

let equal_autocomplete_mode (a : E.autocomplete_mode) (b : E.autocomplete_mode)
    =
  match (a, b) with
  | E.On, E.On
  | E.Off, E.Off ->
      true
  | (E.On | E.Off), _ -> false

let autocomplete_mode_testable =
  Alcotest.testable
    (fun ppf (m : E.autocomplete_mode) ->
      Format.pp_print_string ppf
        (match m with
        | E.On -> "On"
        | E.Off -> "Off"))
    equal_autocomplete_mode

let padded =
  Nopal_style.Style.with_layout
    (Nopal_style.Style.padding_all 8.0)
    Nopal_style.Style.empty

let hovered : Ix.t =
  { hover = Some Nopal_style.Style.empty; pressed = None; focused = None }

let form_builder_defaults_author_nothing () =
  let f = form_fields "defaults" (E.form [ E.text "a" ]) in
  Alcotest.(check bool)
    "style defaults to Style.empty" true
    (Nopal_style.Style.equal f.f_style Nopal_style.Style.empty);
  Alcotest.(check bool)
    "interaction defaults to Interaction.default" true
    (Ix.equal f.f_interaction Ix.default);
  Alcotest.(check (list (pair string string))) "no attrs" [] f.f_attrs;
  Alcotest.(check int) "the one child is kept" 1 (List.length f.f_children);
  Alcotest.(check bool)
    "no on_submit is authored" true
    (Option.is_none f.f_on_submit);
  Alcotest.(check (option autocomplete_mode_testable))
    "no autocomplete is authored" None f.f_autocomplete;
  Alcotest.(check bool) "novalidate defaults to false" false f.f_novalidate

let form_builder_carries_every_authored_field () =
  let child = E.text "a" in
  let f =
    form_fields "authored"
      (E.form ~style:padded ~interaction:hovered
         ~attrs:[ ("aria-label", "Sign in") ]
         ~on_submit:Signed_in ~autocomplete:E.Off ~novalidate:true [ child ])
  in
  Alcotest.(check bool)
    "style is carried" true
    (Nopal_style.Style.equal f.f_style padded);
  Alcotest.(check bool)
    "interaction is carried" true
    (Ix.equal f.f_interaction hovered);
  Alcotest.(check (list (pair string string)))
    "attrs are carried"
    [ ("aria-label", "Sign in") ]
    f.f_attrs;
  Alcotest.(check bool)
    "children are carried" true
    (List.equal E.equal f.f_children [ child ]);
  (match f.f_on_submit with
  | Some Signed_in -> ()
  | Some (Field_entered | Carrying _ | Wrapped _)
  | None ->
      Alcotest.fail "expected on_submit = Some Signed_in");
  Alcotest.(check (option autocomplete_mode_testable))
    "autocomplete is carried" (Some E.Off) f.f_autocomplete;
  Alcotest.(check bool) "novalidate is carried" true f.f_novalidate;
  (* The other arm of the mode, so a builder that answered one constant would
     not pass. *)
  let on = form_fields "autocomplete on" (E.form ~autocomplete:E.On []) in
  Alcotest.(check (option autocomplete_mode_testable))
    "autocomplete On is carried" (Some E.On) on.f_autocomplete

let form_map_transforms_on_submit_and_children () =
  let el =
    E.form ~style:padded
      ~attrs:[ ("aria-label", "Sign in") ]
      ~on_submit:Signed_in ~autocomplete:E.Off ~novalidate:true
      [ E.input ~on_submit:Field_entered "" ]
  in
  let f = form_fields "mapped" (E.map (fun m -> Wrapped m) el) in
  (match f.f_on_submit with
  | Some (Wrapped Signed_in) -> ()
  | Some (Signed_in | Field_entered | Carrying _ | Wrapped _)
  | None ->
      Alcotest.fail "expected on_submit = Some (Wrapped Signed_in)");
  (match f.f_children with
  | [ child ] -> (
      match (input_fields "mapped child" child).i_on_submit with
      | Some (Wrapped Field_entered) -> ()
      | Some (Signed_in | Field_entered | Carrying _ | Wrapped _)
      | None ->
          Alcotest.fail "expected the child input's on_submit to be mapped")
  | []
  | _ :: _ :: _ ->
      Alcotest.fail "expected exactly one child");
  Alcotest.(check bool)
    "style survives map" true
    (Nopal_style.Style.equal f.f_style padded);
  Alcotest.(check (list (pair string string)))
    "attrs survive map"
    [ ("aria-label", "Sign in") ]
    f.f_attrs;
  Alcotest.(check (option autocomplete_mode_testable))
    "autocomplete survives map" (Some E.Off) f.f_autocomplete;
  Alcotest.(check bool) "novalidate survives map" true f.f_novalidate

let form_equal_distinguishes_each_field () =
  (* [equal] gates reconciliation skipping, so every field it compares needs a
     case here: a dropped conjunct reports two differing forms equal. *)
  let child = E.text "a" in
  let base ?(style = Nopal_style.Style.empty) ?(interaction = Ix.default)
      ?(attrs = [ ("aria-label", "Sign in") ]) ?(children = [ child ])
      ?(on_submit = Some Signed_in) ?(autocomplete = Some E.On)
      ?(novalidate = false) () =
    E.Form
      {
        style;
        interaction;
        attrs;
        children;
        on_submit;
        autocomplete;
        novalidate;
      }
  in
  Alcotest.(check bool)
    "a fresh but equal form is equal" true
    (E.equal (base ()) (base ()));
  let differs label other =
    Alcotest.(check bool) label false (E.equal (base ()) other)
  in
  differs "a different style is not equal" (base ~style:padded ());
  differs "a different interaction is not equal" (base ~interaction:hovered ());
  differs "different attrs are not equal"
    (base ~attrs:[ ("aria-label", "Register") ] ());
  differs "different children are not equal" (base ~children:[ E.text "b" ] ());
  differs "a different on_submit is not equal"
    (base ~on_submit:(Some Field_entered) ());
  differs "an absent on_submit is not equal" (base ~on_submit:None ());
  differs "a different autocomplete is not equal"
    (base ~autocomplete:(Some E.Off) ());
  differs "an absent autocomplete is not equal" (base ~autocomplete:None ());
  differs "a different novalidate is not equal" (base ~novalidate:true ());
  differs "a column holding the same children is not equal"
    (E.column ~attrs:[ ("aria-label", "Sign in") ] [ child ]);
  (* Totality: a 'msg payload carrying a closure must not make equal raise. *)
  let carrying = Some (Carrying (fun () -> ())) in
  Alcotest.(check bool)
    "the same closure-carrying on_submit is equal" true
    (E.equal (base ~on_submit:carrying ()) (base ~on_submit:carrying ()))

(* --- Input's typed fields (2) --- *)

let input_defaults_author_none_of_the_three () =
  let i = input_fields "defaults" (E.input "v") in
  Alcotest.(check bool) "required defaults to false" false i.i_required;
  Alcotest.(check (option string))
    "no autocomplete is authored" None i.i_autocomplete;
  Alcotest.(check (option input_type_testable))
    "no input type is authored" None i.i_input_type;
  (* The affirmative arm: the builder does carry each field when authored, so
     the three absences above are the defaults and not a dropped argument. *)
  let a =
    input_fields "authored"
      (E.input ~required:true ~autocomplete:"username" ~input_type:E.Email "v")
  in
  Alcotest.(check bool) "an authored required is carried" true a.i_required;
  Alcotest.(check (option string))
    "an authored autocomplete is carried" (Some "username") a.i_autocomplete;
  Alcotest.(check (option input_type_testable))
    "an authored input type is carried" (Some E.Email) a.i_input_type

let input_map_and_equal_carry_the_three_fields () =
  let el =
    E.input ~required:true ~autocomplete:"current-password"
      ~input_type:E.Password ~on_submit:Signed_in ""
  in
  let m = input_fields "mapped" (E.map (fun msg -> Wrapped msg) el) in
  Alcotest.(check bool) "required survives map" true m.i_required;
  Alcotest.(check (option string))
    "autocomplete survives map" (Some "current-password") m.i_autocomplete;
  Alcotest.(check (option input_type_testable))
    "input type survives map" (Some E.Password) m.i_input_type;
  (match m.i_on_submit with
  | Some (Wrapped Signed_in) -> ()
  | Some (Signed_in | Field_entered | Carrying _ | Wrapped _)
  | None ->
      Alcotest.fail "expected on_submit = Some (Wrapped Signed_in)");
  (* [equal] gates reconciliation skipping, so each new field needs its own
     conjunct: a dropped one reports two differing inputs equal. *)
  let base ?(required = true) ?(autocomplete = Some "username")
      ?(input_type = Some E.Email) () =
    E.Input
      {
        style = Nopal_style.Style.empty;
        interaction = Ix.default;
        attrs = [];
        value = "v";
        placeholder = "";
        on_change = None;
        on_submit = None;
        on_focus = None;
        on_blur = None;
        on_keydown = None;
        required;
        autocomplete;
        input_type;
      }
  in
  Alcotest.(check bool)
    "a fresh but equal input is equal" true
    (E.equal (base ()) (base ()));
  let differs label other =
    Alcotest.(check bool) label false (E.equal (base ()) other)
  in
  differs "a different required is not equal" (base ~required:false ());
  differs "a different autocomplete is not equal"
    (base ~autocomplete:(Some "email") ());
  differs "an absent autocomplete is not equal" (base ~autocomplete:None ());
  differs "a different input type is not equal"
    (base ~input_type:(Some E.Tel) ());
  differs "an absent input type is not equal" (base ~input_type:None ())

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_element_form"
    [
      ( "checkbox",
        [
          Alcotest.test_case "renders_as_checkbox_tag" `Quick
            checkbox_renders_as_checkbox_tag;
          Alcotest.test_case "unchecked_has_checked_false" `Quick
            checkbox_unchecked_has_checked_false;
          Alcotest.test_case "disabled_has_disabled_attr" `Quick
            checkbox_disabled_has_disabled_attr;
          Alcotest.test_case "toggle_fires_negated_state" `Quick
            checkbox_toggle_fires_negated_state;
        ] );
      ( "radio",
        [
          Alcotest.test_case "renders_as_radio_tag_with_name" `Quick
            radio_renders_as_radio_tag_with_name;
          Alcotest.test_case "checked_has_checked_attr" `Quick
            radio_checked_has_checked_attr;
          Alcotest.test_case "disabled_suppresses_on_select" `Quick
            radio_disabled_suppresses_on_select;
          Alcotest.test_case "select_fires_message" `Quick
            radio_select_fires_message;
        ] );
      ( "select",
        [
          Alcotest.test_case "renders_as_select_tag_with_options" `Quick
            select_renders_as_select_tag_with_options;
          Alcotest.test_case "selected_value_in_attrs" `Quick
            select_selected_value_in_attrs;
          Alcotest.test_case "disabled_option_has_disabled_attr" `Quick
            select_disabled_option_has_disabled_attr;
          Alcotest.test_case "disabled_suppresses_on_change" `Quick
            select_disabled_suppresses_on_change;
          Alcotest.test_case "change_fires_new_value" `Quick
            select_change_fires_new_value;
        ] );
      ( "map",
        [
          Alcotest.test_case "map_transforms_checkbox_msg" `Quick
            map_transforms_checkbox_msg;
          Alcotest.test_case "map_transforms_radio_msg" `Quick
            map_transforms_radio_msg;
          Alcotest.test_case "map_transforms_select_msg" `Quick
            map_transforms_select_msg;
        ] );
      ( "equal",
        [
          Alcotest.test_case "equal_checkbox_same_fields" `Quick
            equal_checkbox_same_fields;
          Alcotest.test_case "equal_select_different_options" `Quick
            equal_select_different_options;
        ] );
      ( "form",
        [
          Alcotest.test_case "form_builder_defaults_author_nothing" `Quick
            form_builder_defaults_author_nothing;
          Alcotest.test_case "form_builder_carries_every_authored_field" `Quick
            form_builder_carries_every_authored_field;
          Alcotest.test_case "form_map_transforms_on_submit_and_children" `Quick
            form_map_transforms_on_submit_and_children;
          Alcotest.test_case "form_equal_distinguishes_each_field" `Quick
            form_equal_distinguishes_each_field;
        ] );
      ( "input_fields",
        [
          Alcotest.test_case "defaults_author_none_of_the_three" `Quick
            input_defaults_author_none_of_the_three;
          Alcotest.test_case "map_and_equal_carry_the_three_fields" `Quick
            input_map_and_equal_carry_the_three_fields;
        ] );
    ]
