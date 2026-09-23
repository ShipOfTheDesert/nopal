open Nopal_test.Test_renderer
module E = Nopal_element.Element

type msg =
  | Click
  | DblClick
  | Blur
  | Focus
  | BoxFocus
  | BoxBlur
  | KeyDown of string
  | Toggled of bool
  | Submitted
  | FormSubmitted
[@@warning "-37"]

let error_testable = Test_util.error_testable

let msg_testable =
  Alcotest.testable
    (fun fmt m ->
      match m with
      | Click -> Format.fprintf fmt "Click"
      | DblClick -> Format.fprintf fmt "DblClick"
      | Blur -> Format.fprintf fmt "Blur"
      | Focus -> Format.fprintf fmt "Focus"
      | BoxFocus -> Format.fprintf fmt "BoxFocus"
      | BoxBlur -> Format.fprintf fmt "BoxBlur"
      | KeyDown s -> Format.fprintf fmt "KeyDown %S" s
      | Toggled b -> Format.fprintf fmt "Toggled %b" b
      | Submitted -> Format.fprintf fmt "Submitted"
      | FormSubmitted -> Format.fprintf fmt "FormSubmitted")
    ( = )

let test_dblclick_dispatches_message () =
  let r = render (E.button ~on_dblclick:DblClick (E.text "ok")) in
  let result = dblclick (By_tag "button") r in
  Alcotest.(check (result unit error_testable))
    "dblclick succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "dblclick message dispatched" [ DblClick ] (messages r)

let test_dblclick_no_handler_returns_error () =
  let r = render (E.button (E.text "no handler")) in
  let result = dblclick (By_tag "button") r in
  Alcotest.(check (result unit error_testable))
    "dblclick returns No_handler"
    (Error (No_handler { tag = "button"; event = "dblclick" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let test_blur_dispatches_message () =
  let r = render (E.input ~on_blur:Blur "val") in
  let result = blur (By_tag "input") r in
  Alcotest.(check (result unit error_testable)) "blur succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "blur message dispatched" [ Blur ] (messages r)

let test_blur_no_handler_returns_error () =
  let r = render (E.input "val") in
  let result = blur (By_tag "input") r in
  Alcotest.(check (result unit error_testable))
    "blur returns No_handler"
    (Error (No_handler { tag = "input"; event = "blur" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let test_input_focus_simulation () =
  let r = render (E.input ~on_focus:Focus "val") in
  let result = focus (By_tag "input") r in
  Alcotest.(check (result unit error_testable)) "focus succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "focus message dispatched" [ Focus ] (messages r)

let test_box_focus_simulation () =
  let r = render (E.box ~on_focus:BoxFocus [ E.text "panel" ]) in
  let result = box_focus (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "box_focus succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "box focus message dispatched" [ BoxFocus ] (messages r)

let test_box_blur_simulation () =
  let r = render (E.box ~on_blur:BoxBlur [ E.text "panel" ]) in
  let result = box_blur (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "box_blur succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "box blur message dispatched" [ BoxBlur ] (messages r)

(* The fixture carries the sibling edge, so the absence below is caused by
   [on_focus] being unset and not by the box failing to register a handler
   entry at all; [box_blur] on the same fixture is the affirmative arm that
   proves it. A [box_focus] copy-pasted from [box_blur] reads [on_blur] here
   and dispatches, which is the defect this case exists to catch. *)
let test_box_focus_no_handler () =
  let r = render (E.box ~on_blur:BoxBlur [ E.text "panel" ]) in
  let result = box_focus (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "box_focus returns No_handler with the focus tag"
    (Error (No_handler { tag = "box"; event = "focus" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r));
  let affirmative = box_blur (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "same fixture is registered and its blur edge fires" (Ok ()) affirmative;
  Alcotest.(check (list msg_testable))
    "box blur message dispatched" [ BoxBlur ] (messages r)

let test_box_blur_no_handler () =
  let r = render (E.box ~on_focus:BoxFocus [ E.text "panel" ]) in
  let result = box_blur (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "box_blur returns No_handler with the blur tag"
    (Error (No_handler { tag = "box"; event = "blur" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r));
  let affirmative = box_focus (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "same fixture is registered and its focus edge fires" (Ok ()) affirmative;
  Alcotest.(check (list msg_testable))
    "box focus message dispatched" [ BoxFocus ] (messages r)

let test_keydown_dispatches_message () =
  let handler key = Some (KeyDown key) in
  let r = render (E.input ~on_keydown:handler "val") in
  let result = keydown (By_tag "input") "Escape" r in
  Alcotest.(check (result unit error_testable))
    "keydown succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "keydown message dispatched" [ KeyDown "Escape" ] (messages r)

let test_keydown_handler_returns_none () =
  let handler _key = None in
  let r = render (E.input ~on_keydown:handler "val") in
  let result = keydown (By_tag "input") "a" r in
  Alcotest.(check (result unit error_testable))
    "keydown succeeds" (Ok ()) result;
  Alcotest.(check int) "no messages dispatched" 0 (List.length (messages r))

let test_keydown_no_handler_returns_error () =
  let r = render (E.input "val") in
  let result = keydown (By_tag "input") "Escape" r in
  Alcotest.(check (result unit error_testable))
    "keydown returns No_handler"
    (Error (No_handler { tag = "input"; event = "keydown" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

(* The submit contract on an input: [on_keydown] is consulted first and a [Some]
   consumes the key; an Enter it declines goes on to the input's [on_submit].
   Every case asserts the whole ordered dispatch list, so a double dispatch and a
   silent drop both show. *)

let test_keydown_enter_reaches_on_submit_when_on_keydown_declines () =
  let r =
    render (E.input ~on_submit:Submitted ~on_keydown:(fun _key -> None) "val")
  in
  let result = keydown (By_tag "input") "Enter" r in
  Alcotest.(check (result unit error_testable))
    "keydown succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "the declined Enter dispatches on_submit, once" [ Submitted ] (messages r)

let test_keydown_enter_consumed_by_on_keydown_does_not_reach_on_submit () =
  let r =
    render
      (E.input ~on_submit:Submitted
         ~on_keydown:(fun key -> Some (KeyDown key))
         "val")
  in
  let result = keydown (By_tag "input") "Enter" r in
  Alcotest.(check (result unit error_testable))
    "keydown succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "the consuming on_keydown answers the Enter and on_submit does not"
    [ KeyDown "Enter" ] (messages r)

let test_keydown_on_a_non_enter_key_never_reaches_on_submit () =
  let r = render (E.input ~on_submit:Submitted "val") in
  let other = keydown (By_tag "input") "a" r in
  Alcotest.(check (result unit error_testable))
    "a non-Enter key on an input with on_submit is answered, not No_handler"
    (Ok ()) other;
  Alcotest.(check (list msg_testable))
    "the non-Enter key dispatches nothing" [] (messages r);
  (* Affirmative arm on the same fixture: Enter does reach on_submit, so the
     silence above is the key's doing and not the fixture's. *)
  let enter = keydown (By_tag "input") "Enter" r in
  Alcotest.(check (result unit error_testable))
    "Enter on the same input succeeds" (Ok ()) enter;
  Alcotest.(check (list msg_testable))
    "only the Enter dispatched on_submit" [ Submitted ] (messages r)

(* ---- the form node ---- *)

(* Every field spelled out, nothing inherited: the style lays children across,
   so a node that carried a default style instead would read back differently. *)
let across =
  Nopal_style.Style.
    {
      layout = { default_layout with direction = Some Row_dir };
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

let hover_interaction =
  Nopal_style.Interaction.
    { hover = Some across; pressed = None; focused = None }

let form_record ~attrs ~on_submit ~autocomplete ~novalidate children : msg E.t =
  Form
    {
      style = across;
      interaction = hover_interaction;
      attrs;
      children;
      on_submit;
      autocomplete;
      novalidate;
    }

let test_renders_a_form_node_with_its_children () =
  let r =
    render
      (form_record
         ~attrs:[ ("aria-label", "Sign in") ]
         ~on_submit:(Some FormSubmitted) ~autocomplete:(Some E.Off)
         ~novalidate:true
         [ E.text "Email"; E.input "v" ])
  in
  let node = tree r in
  (match node with
  | Element
      { tag; children = [ Text { content; _ }; Element { tag = child; _ } ]; _ }
    ->
      Alcotest.(check string) "the node is a form" "form" tag;
      Alcotest.(check string) "its first child is the text" "Email" content;
      Alcotest.(check string) "its second child is the input" "input" child
  | Element _
  | Text _
  | Empty ->
      Alcotest.fail "expected a form node holding a text and an input");
  Alcotest.(check bool)
    "the style is carried" true
    (Option.equal Nopal_style.Style.equal (Some across) (style node));
  Alcotest.(check bool) "the interaction is carried" true (has_hover node);
  Alcotest.(check (option string))
    "the caller's pair is kept" (Some "Sign in") (attr "aria-label" node);
  Alcotest.(check (option string))
    "autocomplete is derived from the typed field" (Some "off")
    (attr "autocomplete" node);
  Alcotest.(check (option string))
    "novalidate is derived from the typed field" (Some "true")
    (attr "novalidate" node);
  (* Absence is spelled as the web renderer spells it: a declining field
     contributes no pair, so the caller's own pair for that key is uncovered
     rather than erased, and where neither speaks there is nothing to read. *)
  let unauthored =
    tree
      (render
         (form_record ~attrs:[] ~on_submit:None ~autocomplete:None
            ~novalidate:false []))
  in
  Alcotest.(check (option string))
    "an unauthored form has no autocomplete" None
    (attr "autocomplete" unauthored);
  Alcotest.(check (option string))
    "an unauthored form has no novalidate" None
    (attr "novalidate" unauthored);
  let uncovered =
    tree
      (render
         (form_record
            ~attrs:[ ("autocomplete", "on"); ("novalidate", "caller") ]
            ~on_submit:None ~autocomplete:None ~novalidate:false []))
  in
  Alcotest.(check (option string))
    "a declining autocomplete uncovers the caller's pair" (Some "on")
    (attr "autocomplete" uncovered);
  Alcotest.(check (option string))
    "a declining novalidate uncovers the caller's pair" (Some "caller")
    (attr "novalidate" uncovered);
  let overridden =
    tree
      (render
         (form_record
            ~attrs:[ ("autocomplete", "on"); ("novalidate", "caller") ]
            ~on_submit:None ~autocomplete:(Some E.Off) ~novalidate:true []))
  in
  Alcotest.(check (option string))
    "an authored autocomplete beats the caller's pair" (Some "off")
    (attr "autocomplete" overridden);
  Alcotest.(check (option string))
    "an authored novalidate beats the caller's pair" (Some "true")
    (attr "novalidate" overridden)

(* ---- an input's typed required, autocomplete and input_type ---- *)

let input_node el = tree (render (el : msg E.t))

(* The caller's own pair for every key the three fields derive, each carrying a
   value no derivation produces, so reading one back names its source. *)
let callers_pairs =
  [
    ("required", "caller");
    ("aria-required", "caller");
    ("autocomplete", "caller");
    ("type", "caller");
  ]

let test_required_emits_required_and_aria_required () =
  let node = input_node (E.input ~required:true "v") in
  Alcotest.(check (option string))
    "required is derived" (Some "true") (attr "required" node);
  Alcotest.(check (option string))
    "aria-required is derived with it" (Some "true")
    (attr "aria-required" node);
  (* The absence arm, on the same builder: a field that is not required says
     nothing under either key. *)
  let optional = input_node (E.input ~required:false "v") in
  Alcotest.(check (option string))
    "a field that is not required has no required" None
    (attr "required" optional);
  Alcotest.(check (option string))
    "a field that is not required has no aria-required" None
    (attr "aria-required" optional)

let test_an_absent_typed_field_leaves_the_callers_attrs_pair_standing () =
  let node = input_node (E.input ~attrs:callers_pairs "v") in
  List.iter
    (fun (key, value) ->
      Alcotest.(check (option string))
        (Printf.sprintf "the caller's %s stands" key)
        (Some value) (attr key node))
    callers_pairs;
  (* [required] has no absent form of its own: [false] is how it says nothing,
     and it uncovers exactly as the two options do. *)
  let declined =
    input_node (E.input ~attrs:callers_pairs ~required:false "v")
  in
  Alcotest.(check (option string))
    "a declining required uncovers the caller's required" (Some "caller")
    (attr "required" declined);
  Alcotest.(check (option string))
    "a declining required uncovers the caller's aria-required" (Some "caller")
    (attr "aria-required" declined)

let test_an_authored_typed_field_replaces_the_callers_attrs_pair () =
  let node =
    input_node
      (E.input ~attrs:callers_pairs ~required:true ~autocomplete:"username"
         ~input_type:E.Email "v")
  in
  Alcotest.(check (option string))
    "the derived required replaces the caller's" (Some "true")
    (attr "required" node);
  Alcotest.(check (option string))
    "the derived aria-required replaces the caller's" (Some "true")
    (attr "aria-required" node);
  Alcotest.(check (option string))
    "the derived autocomplete replaces the caller's" (Some "username")
    (attr "autocomplete" node);
  Alcotest.(check (option string))
    "the derived type replaces the caller's" (Some "email") (attr "type" node)

let test_each_input_type_arm_emits_its_token () =
  List.iter
    (fun (input_type, token) ->
      Alcotest.(check (option string))
        (Printf.sprintf "input_type %s emits type=%s" token token)
        (Some token)
        (attr "type" (input_node (E.input ~input_type "v"))))
    [
      (E.Plain, "text");
      (E.Password, "password");
      (E.Email, "email");
      (E.Tel, "tel");
      (E.Url, "url");
      (E.Number, "number");
      (E.Search, "search");
    ]

(* ---- the submit contract across all three paths ---- *)

(* One form holding the three shapes an input can take: a bare field, which
   defers Enter to the form; a field with its own [on_submit], which answers
   Enter itself; and a field whose [on_keydown] consumes every key. The bare
   field sits inside a row, so reaching the form is a walk up the ancestry and
   not a look at the immediate parent. With three fields, the form submits on
   Enter only through its submit button, which authors no [on_click] so that
   the form's message is the whole answer. *)
let three_path_form ?on_submit () =
  E.form ?on_submit
    [
      E.row [ E.input ~attrs:[ ("data-field", "bare") ] "v" ];
      E.input ~attrs:[ ("data-field", "submitting") ] ~on_submit:Submitted "v";
      E.input
        ~attrs:[ ("data-field", "consuming") ]
        ~on_keydown:(fun key -> Some (KeyDown key))
        "v";
      E.button ~button_type:E.Submit (E.text "Go");
    ]

let field name = By_attr ("data-field", name)

let test_one_fixture_answers_all_three_paths_in_order () =
  let r = render (three_path_form ~on_submit:FormSubmitted ()) in
  (* Pressed through [List.map], which applies in order; a list literal of the
     four calls would evaluate them right to left. *)
  let results =
    List.map
      (fun (name, key) -> keydown (field name) key r)
      [
        ("bare", "a");
        ("bare", "Enter");
        ("submitting", "Enter");
        ("consuming", "Enter");
      ]
  in
  Alcotest.(check (list (result unit error_testable)))
    "every keydown is answered"
    [ Ok (); Ok (); Ok (); Ok () ]
    results;
  Alcotest.(check (list msg_testable))
    "a non-Enter key reaches no form; each Enter is answered by the nearest \
     handler that accepts it, once"
    [ FormSubmitted; Submitted; KeyDown "Enter" ]
    (messages r)

let test_input_on_submit_inside_a_form_dispatches_once () =
  let r = render (three_path_form ~on_submit:FormSubmitted ()) in
  let result = keydown (field "submitting") "Enter" r in
  Alcotest.(check (result unit error_testable))
    "keydown succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "the input's own on_submit answers, and the form's does not" [ Submitted ]
    (messages r);
  (* Affirmative arm on the same fixture: the form does dispatch, for the bare
     field, so its silence above is the input's consumption and not a form
     this renderer failed to reach. *)
  let bare = keydown (field "bare") "Enter" r in
  Alcotest.(check (result unit error_testable))
    "Enter in the bare field succeeds" (Ok ()) bare;
  Alcotest.(check (list msg_testable))
    "the bare field's Enter reaches the form"
    [ Submitted; FormSubmitted ]
    (messages r)

(* Every container arm that threads the enclosing [~form] through to its
   descendants must actually carry it down to a bare input, not just accept the
   label. One table, one wrapper per arm, each wrapping the same bare input
   inside the same form; a mutation that dropped the thread on any one arm (e.g.
   passing [~form:no_form] instead of [~form]) would strand that
   arm's Enter with no form to answer it, and this table catches exactly
   that arm without disturbing the others. *)
let test_container_arms_thread_form_submit_to_a_nested_input () =
  let wrappers : (string * (msg E.t -> msg E.t)) list =
    [
      ("box", fun input -> E.box [ input ]);
      ("column", fun input -> E.column [ input ]);
      ("scroll", fun input -> E.scroll input);
      ("keyed", fun input -> E.keyed "k" input);
    ]
  in
  List.iter
    (fun (name, wrap) ->
      let r =
        render
          (E.form ~on_submit:FormSubmitted
             [ wrap (E.input ~attrs:[ ("data-field", "bare") ] "v") ])
      in
      let result = keydown (field "bare") "Enter" r in
      Alcotest.(check (result unit error_testable))
        (name ^ ": keydown succeeds")
        (Ok ()) result;
      Alcotest.(check (list msg_testable))
        (name ^ ": Enter in the nested bare field reaches the enclosing form")
        [ FormSubmitted ] (messages r))
    wrappers

(* ---- the two submit simulators ---- *)

let test_submit_and_submit_form_reach_different_handlers () =
  let r =
    render
      (E.form ~on_submit:FormSubmitted [ E.input ~on_submit:Submitted "v" ])
  in
  let on_input = submit (By_tag "input") r in
  Alcotest.(check (result unit error_testable))
    "submit reaches the input" (Ok ()) on_input;
  let on_form = submit_form (By_tag "form") r in
  Alcotest.(check (result unit error_testable))
    "submit_form reaches the form" (Ok ()) on_form;
  Alcotest.(check (list msg_testable))
    "each dispatched its own node's message, once"
    [ Submitted; FormSubmitted ]
    (messages r);
  Alcotest.(check (result unit error_testable))
    "submit does not reach a form's on_submit"
    (Error (No_handler { tag = "form"; event = "submit" }))
    (submit (By_tag "form") r);
  Alcotest.(check (result unit error_testable))
    "submit_form does not reach an input's on_submit"
    (Error (No_handler { tag = "input"; event = "submit" }))
    (submit_form (By_tag "input") r);
  Alcotest.(check (list msg_testable))
    "neither crossed call dispatched"
    [ Submitted; FormSubmitted ]
    (messages r)

let test_submit_form_on_a_form_without_on_submit_is_no_handler () =
  let r =
    render
      (E.column
         [
           E.form ~attrs:[ ("data-form", "silent") ] [ E.input "v" ];
           E.form
             ~attrs:[ ("data-form", "submitting") ]
             ~on_submit:FormSubmitted
             [ E.input "v" ];
         ])
  in
  let silent = By_attr ("data-form", "silent") in
  Alcotest.(check (result unit error_testable))
    "submit_form on a form without on_submit is No_handler"
    (Error (No_handler { tag = "form"; event = "submit" }))
    (submit_form silent r);
  (* Enter in that form's bare field defers to a form that answers nothing, so
     nothing a keydown can reach exists — the same answer a bare field outside
     any form gives. *)
  Alcotest.(check (result unit error_testable))
    "Enter in its bare field reaches nothing"
    (Error (No_handler { tag = "input"; event = "keydown" }))
    (keydown (By_tag "input") "Enter" r);
  Alcotest.(check (list msg_testable)) "nothing dispatched" [] (messages r);
  (* Affirmative arm on the same tree: the sibling form authors on_submit, and
     both simulators reach it. *)
  let submitting = By_attr ("data-form", "submitting") in
  Alcotest.(check (result unit error_testable))
    "submit_form on the submitting form succeeds" (Ok ())
    (submit_form submitting r);
  Alcotest.(check (list msg_testable))
    "and dispatches its message" [ FormSubmitted ] (messages r)

(* ---- the platform's share: a button's click and an Enter left to the form ---- *)

let button_in_form ?on_click ?(disabled = false) button_type =
  render
    (E.form ~on_submit:FormSubmitted
       [ E.input "v"; E.button ~button_type ~disabled ?on_click (E.text "Go") ])

let test_click_submit_button_in_form_appends_click_then_submit () =
  let r = button_in_form ~on_click:Click E.Submit in
  Alcotest.(check (result unit error_testable))
    "click succeeds" (Ok ())
    (click (By_tag "button") r);
  Alcotest.(check (list msg_testable))
    "the button's click, then the form's submit" [ Click; FormSubmitted ]
    (messages r)

let test_click_submit_button_without_on_click_appends_submit_only () =
  let r = button_in_form E.Submit in
  Alcotest.(check (result unit error_testable))
    "click succeeds" (Ok ())
    (click (By_tag "button") r);
  Alcotest.(check (list msg_testable))
    "the form's submit alone" [ FormSubmitted ] (messages r)

let test_click_push_button_in_form_appends_click_only () =
  let r = button_in_form ~on_click:Click E.Push in
  Alcotest.(check (result unit error_testable))
    "click succeeds" (Ok ())
    (click (By_tag "button") r);
  Alcotest.(check (list msg_testable))
    "the button's click alone" [ Click ] (messages r)

let test_click_disabled_submit_button_is_no_handler () =
  let r = button_in_form ~on_click:Click ~disabled:true E.Submit in
  Alcotest.(check (result unit error_testable))
    "a disabled button answers no click"
    (Error (No_handler { tag = "button"; event = "click" }))
    (click (By_tag "button") r);
  Alcotest.(check (list msg_testable)) "nothing dispatched" [] (messages r);
  let enabled = button_in_form ~on_click:Click ~disabled:false E.Submit in
  Alcotest.(check (result unit error_testable))
    "its enabled twin answers" (Ok ())
    (click (By_tag "button") enabled);
  Alcotest.(check (list msg_testable))
    "and dispatches its click, then the form's submit" [ Click; FormSubmitted ]
    (messages enabled)

(* A submit button with no enclosing form dispatches its own [on_click] alone:
   there is no form to reach, so [Implicit_submission.click]'s [form_submit]
   is [None] here, the same as it is for a push button. The affirmative twin
   is the same button inside a form authoring [on_submit], which does reach
   it: see test_click_submit_button_in_form_appends_click_then_submit. *)
let test_click_submit_button_outside_a_form_appends_click_only () =
  let r =
    render (E.button ~button_type:E.Submit ~on_click:Click (E.text "Go"))
  in
  Alcotest.(check (result unit error_testable))
    "click succeeds" (Ok ())
    (click (By_tag "button") r);
  Alcotest.(check (list msg_testable))
    "the button's click alone, no form to reach" [ Click ] (messages r)

(* A submit button inside a form that authors no [on_submit] dispatches its
   own [on_click] alone: [form_submit] is [None] because the form has nothing
   to contribute, not because no form encloses the button. *)
let test_click_submit_button_in_form_without_on_submit_appends_click_only () =
  let r =
    render
      (E.form
         [
           E.input "v";
           E.button ~button_type:E.Submit ~on_click:Click (E.text "Go");
         ])
  in
  Alcotest.(check (result unit error_testable))
    "click succeeds" (Ok ())
    (click (By_tag "button") r);
  Alcotest.(check (list msg_testable))
    "the button's click alone, the form authors no on_submit" [ Click ]
    (messages r)

let test_keydown_enter_multi_field_no_submit_button_appends_nothing () =
  let form fields =
    render
      (E.form ~on_submit:FormSubmitted
         (List.init fields (fun i ->
              E.input ~attrs:[ ("data-field", string_of_int i) ] "v")))
  in
  let r = form 2 in
  Alcotest.(check (result unit error_testable))
    "nothing a keydown reaches answers the Enter"
    (Error (No_handler { tag = "input"; event = "keydown" }))
    (keydown (field "0") "Enter" r);
  Alcotest.(check (list msg_testable)) "nothing dispatched" [] (messages r);
  let one = form 1 in
  Alcotest.(check (result unit error_testable))
    "with one field, the Enter is answered" (Ok ())
    (keydown (field "0") "Enter" one);
  Alcotest.(check (list msg_testable))
    "and the form submits" [ FormSubmitted ] (messages one)

let test_keydown_enter_with_enabled_default_button_appends_click_then_submit ()
    =
  let r =
    render
      (E.form ~on_submit:FormSubmitted
         [
           E.input ~attrs:[ ("data-field", "first") ] "v";
           E.input "v";
           E.button ~button_type:E.Submit ~on_click:Click (E.text "Go");
         ])
  in
  Alcotest.(check (result unit error_testable))
    "keydown succeeds" (Ok ())
    (keydown (field "first") "Enter" r);
  Alcotest.(check (list msg_testable))
    "the default button's click, then the form's submit"
    [ Click; FormSubmitted ] (messages r)

let test_toggle_checked_dispatches_false () =
  let r = render (E.checkbox ~on_toggle:(fun b -> Toggled b) true) in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check (result unit error_testable)) "toggle succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "toggle dispatches Toggled false" [ Toggled false ] (messages r)

let test_toggle_unchecked_dispatches_true () =
  let r = render (E.checkbox ~on_toggle:(fun b -> Toggled b) false) in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check (result unit error_testable)) "toggle succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "toggle dispatches Toggled true" [ Toggled true ] (messages r)

let test_toggle_disabled_returns_error () =
  let r =
    render (E.checkbox ~on_toggle:(fun b -> Toggled b) ~disabled:true false)
  in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check (result unit error_testable))
    "toggle returns No_handler"
    (Error (No_handler { tag = "checkbox"; event = "toggle" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let test_toggle_non_checkbox_returns_error () =
  let r = render (E.button ~on_click:Click (E.text "not a checkbox")) in
  let result = toggle (By_tag "button") r in
  Alcotest.(check (result unit error_testable))
    "toggle returns No_handler"
    (Error (No_handler { tag = "button"; event = "toggle" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let test_toggle_not_found_returns_error () =
  let r = render (E.box [ E.text "hello" ]) in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check (result unit error_testable))
    "toggle returns Not_found" (Error (Not_found (By_tag "checkbox"))) result

let () =
  Alcotest.run "event_simulation"
    [
      ( "dblclick",
        [
          Alcotest.test_case "dispatches_message" `Quick
            test_dblclick_dispatches_message;
          Alcotest.test_case "no_handler_returns_error" `Quick
            test_dblclick_no_handler_returns_error;
        ] );
      ( "blur",
        [
          Alcotest.test_case "dispatches_message" `Quick
            test_blur_dispatches_message;
          Alcotest.test_case "no_handler_returns_error" `Quick
            test_blur_no_handler_returns_error;
        ] );
      ( "focus",
        [
          Alcotest.test_case "input_dispatches_message" `Quick
            test_input_focus_simulation;
        ] );
      ( "box_focus",
        [
          Alcotest.test_case "dispatches_message" `Quick
            test_box_focus_simulation;
          Alcotest.test_case "no_handler_returns_error" `Quick
            test_box_focus_no_handler;
        ] );
      ( "box_blur",
        [
          Alcotest.test_case "dispatches_message" `Quick
            test_box_blur_simulation;
          Alcotest.test_case "no_handler_returns_error" `Quick
            test_box_blur_no_handler;
        ] );
      ( "keydown",
        [
          Alcotest.test_case "dispatches_message" `Quick
            test_keydown_dispatches_message;
          Alcotest.test_case "handler_returns_none" `Quick
            test_keydown_handler_returns_none;
          Alcotest.test_case "no_handler_returns_error" `Quick
            test_keydown_no_handler_returns_error;
        ] );
      ( "submit_contract",
        [
          Alcotest.test_case
            "keydown_enter_reaches_on_submit_when_on_keydown_declines" `Quick
            test_keydown_enter_reaches_on_submit_when_on_keydown_declines;
          Alcotest.test_case
            "keydown_enter_consumed_by_on_keydown_does_not_reach_on_submit"
            `Quick
            test_keydown_enter_consumed_by_on_keydown_does_not_reach_on_submit;
          Alcotest.test_case
            "keydown_on_a_non_enter_key_never_reaches_on_submit" `Quick
            test_keydown_on_a_non_enter_key_never_reaches_on_submit;
          Alcotest.test_case "one_fixture_answers_all_three_paths_in_order"
            `Quick test_one_fixture_answers_all_three_paths_in_order;
          Alcotest.test_case "input_on_submit_inside_a_form_dispatches_once"
            `Quick test_input_on_submit_inside_a_form_dispatches_once;
          Alcotest.test_case
            "container_arms_thread_form_submit_to_a_nested_input" `Quick
            test_container_arms_thread_form_submit_to_a_nested_input;
        ] );
      ( "form",
        [
          Alcotest.test_case "renders_a_form_node_with_its_children" `Quick
            test_renders_a_form_node_with_its_children;
        ] );
      ( "input_fields",
        [
          Alcotest.test_case "required_emits_required_and_aria_required" `Quick
            test_required_emits_required_and_aria_required;
          Alcotest.test_case
            "an_absent_typed_field_leaves_the_callers_attrs_pair_standing"
            `Quick
            test_an_absent_typed_field_leaves_the_callers_attrs_pair_standing;
          Alcotest.test_case
            "an_authored_typed_field_replaces_the_callers_attrs_pair" `Quick
            test_an_authored_typed_field_replaces_the_callers_attrs_pair;
          Alcotest.test_case "each_input_type_arm_emits_its_token" `Quick
            test_each_input_type_arm_emits_its_token;
        ] );
      ( "test_renderer",
        [
          Alcotest.test_case "submit_and_submit_form_reach_different_handlers"
            `Quick test_submit_and_submit_form_reach_different_handlers;
          Alcotest.test_case
            "submit_form_on_a_form_without_on_submit_is_no_handler" `Quick
            test_submit_form_on_a_form_without_on_submit_is_no_handler;
        ] );
      ( "platform_submission",
        [
          Alcotest.test_case
            "click_submit_button_in_form_appends_click_then_submit" `Quick
            test_click_submit_button_in_form_appends_click_then_submit;
          Alcotest.test_case
            "click_submit_button_without_on_click_appends_submit_only" `Quick
            test_click_submit_button_without_on_click_appends_submit_only;
          Alcotest.test_case "click_push_button_in_form_appends_click_only"
            `Quick test_click_push_button_in_form_appends_click_only;
          Alcotest.test_case "click_disabled_submit_button_is_no_handler" `Quick
            test_click_disabled_submit_button_is_no_handler;
          Alcotest.test_case
            "click_submit_button_outside_a_form_appends_click_only" `Quick
            test_click_submit_button_outside_a_form_appends_click_only;
          Alcotest.test_case
            "click_submit_button_in_form_without_on_submit_appends_click_only"
            `Quick
            test_click_submit_button_in_form_without_on_submit_appends_click_only;
          Alcotest.test_case
            "keydown_enter_multi_field_no_submit_button_appends_nothing" `Quick
            test_keydown_enter_multi_field_no_submit_button_appends_nothing;
          Alcotest.test_case
            "keydown_enter_with_enabled_default_button_appends_click_then_submit"
            `Quick
            test_keydown_enter_with_enabled_default_button_appends_click_then_submit;
        ] );
      ( "toggle",
        [
          Alcotest.test_case "checked_dispatches_false" `Quick
            test_toggle_checked_dispatches_false;
          Alcotest.test_case "unchecked_dispatches_true" `Quick
            test_toggle_unchecked_dispatches_true;
          Alcotest.test_case "disabled_returns_error" `Quick
            test_toggle_disabled_returns_error;
          Alcotest.test_case "non_checkbox_returns_error" `Quick
            test_toggle_non_checkbox_returns_error;
          Alcotest.test_case "not_found_returns_error" `Quick
            test_toggle_not_found_returns_error;
        ] );
    ]
