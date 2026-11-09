open Nopal_test.Test_renderer
module Sw = Nopal_ui.Switch
module E = Nopal_element.Element

type msg = Toggled of bool

let msg_testable =
  Alcotest.testable
    (fun fmt (Toggled v) -> Format.fprintf fmt "Toggled %b" v)
    ( = )

let reason = "Needs a silence threshold."

let base ?(on = false) () =
  Sw.make ~label:"Send an alert" ~on ~on_toggle:(fun v -> Toggled v)

let disabled ?on () =
  Sw.with_availability (Sw.Disabled { reason }) (base ?on ())

let hint_text = "Delivering to host"
let hint () = E.text hint_text
let rendered config = render (Sw.view config)
let button_of what tree = Test_util.find_or_fail what (By_tag "button") tree
let describedby what tree = attr "aria-describedby" (button_of what tree)

let test_click_dispatches_requested_value () =
  List.iter
    (fun (on, checked, requested) ->
      let what = Printf.sprintf "on:%b" on in
      let r = rendered (base ~on ()) in
      Alcotest.(check (option string))
        (what ^ ": role") (Some "switch")
        (attr "role" (button_of what (tree r)));
      Alcotest.(check (option string))
        (what ^ ": aria-checked follows the given value")
        (Some checked)
        (attr "aria-checked" (button_of what (tree r)));
      Alcotest.(check (result unit Test_util.error_testable))
        (what ^ ": click is handled")
        (Ok ())
        (click (By_tag "button") r);
      Alcotest.(check (list msg_testable))
        (what ^ ": the click asks for the opposite value")
        [ Toggled requested ] (messages r))
    [ (true, "true", false); (false, "false", true) ]

let test_disabled_click_dispatches_nothing () =
  (* Affirmative arm on the same label and value: enabled, the click lands. *)
  let enabled = rendered (base ()) in
  Alcotest.(check (result unit Test_util.error_testable))
    "enabled: click is handled" (Ok ())
    (click (By_tag "button") enabled);
  Alcotest.(check (list msg_testable))
    "enabled: the click dispatches" [ Toggled true ] (messages enabled);
  let r = rendered (disabled ()) in
  let button = button_of "disabled" (tree r) in
  Alcotest.(check (option string))
    "disabled: announced as disabled" (Some "true")
    (attr "aria-disabled" button);
  Alcotest.(check bool)
    "disabled: no native disabled, so it stays focusable" false
    (has_attr "disabled" button);
  Alcotest.(check (result unit Test_util.error_testable))
    "disabled: no handler"
    (Error (No_handler { tag = "button"; event = "click" }))
    (click (By_tag "button") r);
  Alcotest.(check (list msg_testable))
    "disabled: nothing dispatched" [] (messages r)

let test_disabled_label_click_dispatches_nothing () =
  (* Affirmative arm: the same label, enabled, reaches the button. *)
  let enabled = rendered (base ()) in
  Alcotest.(check (result unit Test_util.error_testable))
    "enabled: the label press is handled" (Ok ())
    (click (By_tag "label") enabled);
  Alcotest.(check (list msg_testable))
    "enabled: the label press dispatches" [ Toggled true ] (messages enabled);
  let r = rendered (disabled ()) in
  Alcotest.(check (result unit Test_util.error_testable))
    "disabled: the label press has no handler"
    (Error (No_handler { tag = "label"; event = "click" }))
    (click (By_tag "label") r);
  Alcotest.(check (list msg_testable))
    "disabled: nothing dispatched" [] (messages r)

let test_label_click_dispatches_once () =
  List.iter
    (fun on ->
      let what = Printf.sprintf "on:%b" on in
      let r = rendered (base ~on ()) in
      Alcotest.(check (result unit Test_util.error_testable))
        (what ^ ": label press is handled")
        (Ok ()) (click (By_tag "label") r);
      Alcotest.(check (list msg_testable))
        (what ^ ": exactly one toggle")
        [ Toggled (not on) ] (messages r))
    [ true; false ]

let test_description_reason_then_hint () =
  let r = rendered (Sw.with_hint (hint ()) (disabled ())) in
  Alcotest.(check (option string))
    "reason id, then hint id" (Some "send-an-alert-reason send-an-alert-hint")
    (describedby "reason and hint" (tree r))

let test_description_omits_absent_ids () =
  List.iter
    (fun (what, config, expected) ->
      Alcotest.(check (option string))
        what expected
        (describedby what (tree (rendered config))))
    [
      ("neither: no aria-describedby", base (), None);
      ("reason only", disabled (), Some "send-an-alert-reason");
      ("hint only", Sw.with_hint (hint ()) (base ()), Some "send-an-alert-hint");
    ]

(* Whether [node] or any descendant satisfies [p]. *)
let rec exists_in p node =
  p node
  ||
  match node with
  | Element { children; _ } -> List.exists (exists_in p) children
  | Text _
  | Empty ->
      false

let is_text content node =
  match node with
  | Text { content = c; _ } -> String.equal c content
  | Element _
  | Empty ->
      false

let outer_children what tree = Test_util.children_of what tree

let test_reason_is_visible_text () =
  let t = tree (rendered (disabled ())) in
  let reason_box =
    Test_util.find_or_fail "reason box"
      (By_attr ("id", "send-an-alert-reason"))
      t
  in
  Alcotest.(check string)
    "the reason box shows the reason" reason (text_content reason_box);
  Alcotest.(check bool)
    "the reason box is a child of the outer box" true
    (List.exists
       (fun child -> Test_util.node_equal child reason_box)
       (outer_children "disabled" t));
  Alcotest.(check bool)
    "the reason is not inside the button" false
    (exists_in (is_text reason) (button_of "disabled" t));
  Alcotest.(check bool)
    "the reason is not inside the label" false
    (exists_in (is_text reason)
       (Test_util.find_or_fail "label" (By_tag "label") t));
  let enabled = tree (rendered (base ())) in
  Alcotest.(check bool)
    "enabled: no reason box" false
    (Option.is_some (find (By_attr ("id", "send-an-alert-reason")) enabled));
  Alcotest.(check bool)
    "enabled: no reason text" false
    (exists_in (is_text reason) enabled)

let new_tab_path =
  match Nopal_element.Route_path.of_string "/settings/delivery" with
  | Ok path -> path
  | Error
      ( Nopal_element.Route_path.Not_absolute _
      | Nopal_element.Route_path.Protocol_relative _
      | Nopal_element.Route_path.Control_character _ ) ->
      Alcotest.fail "fixture path is refused"

let is_link node =
  match node with
  | Element { tag = "a"; _ } -> true
  | Element _
  | Text _
  | Empty ->
      false

let test_hint_holds_a_link_outside_button_and_label () =
  let link =
    E.link (Nopal_element.Link.New_tab { path = new_tab_path }) (E.text "host")
  in
  let config =
    Sw.with_hint (E.row [ E.text "Delivering to "; link ]) (disabled ())
  in
  let t = tree (rendered config) in
  let hint_box =
    Test_util.find_or_fail "hint box" (By_attr ("id", "send-an-alert-hint")) t
  in
  Alcotest.(check bool)
    "the hint box holds the link" true
    (exists_in is_link hint_box);
  Alcotest.(check bool)
    "the hint box is a child of the outer box" true
    (List.exists
       (fun child -> Test_util.node_equal child hint_box)
       (outer_children "hint" t));
  Alcotest.(check bool)
    "no link inside the button" false
    (exists_in is_link (button_of "hint" t));
  Alcotest.(check bool)
    "no link inside the label" false
    (exists_in is_link (Test_util.find_or_fail "label" (By_tag "label") t))

let test_with_id_moves_every_derived_id () =
  let config = Sw.with_id "alert" (Sw.with_hint (hint ()) (disabled ())) in
  let t = tree (rendered config) in
  Alcotest.(check string) "control_id" "alert" (Sw.control_id config);
  Alcotest.(check string)
    "control_id without with_id is the slugified label" "send-an-alert"
    (Sw.control_id (base ()));
  Alcotest.(check (option string))
    "button id" (Some "alert")
    (attr "id" (button_of "with_id" t));
  Alcotest.(check (option string))
    "label for" (Some "alert")
    (attr "for" (Test_util.find_or_fail "label" (By_tag "label") t));
  Alcotest.(check bool)
    "reason box id" true
    (Option.is_some (find (By_attr ("id", "alert-reason")) t));
  Alcotest.(check bool)
    "hint box id" true
    (Option.is_some (find (By_attr ("id", "alert-hint")) t));
  Alcotest.(check (option string))
    "describedby names the moved ids" (Some "alert-reason alert-hint")
    (describedby "with_id" t)

let test_with_attrs_cannot_replace_description () =
  let config =
    Sw.with_attrs
      [ ("aria-describedby", "caller"); ("data-testid", "alert-switch") ]
      (Sw.with_hint (hint ()) (disabled ()))
  in
  let t = tree (rendered config) in
  Alcotest.(check (option string))
    "the caller's describedby lands on the outer box" (Some "caller")
    (attr "aria-describedby" t);
  Alcotest.(check (option string))
    "the caller's other pairs land on the outer box" (Some "alert-switch")
    (attr "data-testid" t);
  Alcotest.(check (option string))
    "the button keeps reason then hint"
    (Some "send-an-alert-reason send-an-alert-hint")
    (describedby "with_attrs" t);
  Alcotest.(check bool)
    "no caller pair reaches the button" false
    (has_attr "data-testid" (button_of "with_attrs" t))

module S = Nopal_style.Style
module I = Nopal_style.Interaction

(* A style recognisable wherever it lands: a background no other fixture uses
   on an element, and a font size no other fixture uses on a text node. It sets
   no layout, so every structural fill-in still has room to act. *)
let marked n =
  S.default
  |> S.with_paint (fun p -> { p with S.background = Some (S.rgba n n n 1.0) })
  |> S.with_text (fun t ->
      { t with Nopal_style.Text.font_size = Some (Float.of_int n) })

let carries_marker n node =
  match node with
  | Element { style; _ } ->
      Option.equal S.equal_color style.S.paint.S.background
        (Some (S.rgba n n n 1.0))
  | Text { text_style = Some t; _ } ->
      Option.equal Float.equal t.Nopal_style.Text.font_size
        (Some (Float.of_int n))
  | Text { text_style = None; _ }
  | Empty ->
      false

(* Every node of [node] satisfying [p], as its child-index path from the root,
   in depth-first order. *)
let paths_where p node =
  let rec walk rev_path node acc =
    let acc = if p node then List.rev rev_path :: acc else acc in
    match node with
    | Element { children; _ } ->
        List.fold_left
          (fun (i, acc) child -> (i + 1, walk (i :: rev_path) child acc))
          (0, acc) children
        |> snd
    | Text _
    | Empty ->
        acc
  in
  List.rev (walk [] node [])

let path_testable = Alcotest.(list (list int))

(* The node at a child-index path from [node], if there is one. *)
let rec node_at node path =
  match path with
  | [] -> Some node
  | i :: rest -> (
      match node with
      | Element { children; _ } ->
          Option.bind (List.nth_opt children i) (fun child ->
              node_at child rest)
      | Text _
      | Empty ->
          None)

(* Child-index paths in the tree [Switch.view] renders. *)
let row_path = [ 0 ]
let label_path = [ 0; 0 ]
let label_text_path = [ 0; 0; 0 ]
let button_path = [ 0; 1 ]
let track_path = [ 0; 1; 0 ]
let knob_path = [ 0; 1; 0; 0 ]

let marker_paths n config =
  paths_where (carries_marker n) (tree (rendered config))

let check_lands what n config expected =
  Alcotest.check path_testable what expected (marker_paths n config)

(* An [off]/[on] setter: the [off] style lands on [path] while off and the [on]
   style while on, and each reaches nothing in the other state. *)
let check_off_on ~setter ~path ~state ~make_config =
  let config on = setter ~off:(marked 31) ~on:(marked 32) (make_config ~on) in
  let shown, hidden = if state then (32, 31) else (31, 32) in
  let what = Printf.sprintf "on:%b" state in
  check_lands
    (what ^ ": its style lands on its node")
    shown (config state) [ path ];
  check_lands
    (what ^ ": the other state's style lands nowhere")
    hidden (config state) []

let enabled_config ~on = base ~on ()
let disabled_config ~on = disabled ~on ()

let test_override_track_off () =
  check_off_on ~setter:Sw.with_track_style ~path:track_path ~state:false
    ~make_config:enabled_config

let test_override_track_on () =
  check_off_on ~setter:Sw.with_track_style ~path:track_path ~state:true
    ~make_config:enabled_config

let test_override_knob_off () =
  check_off_on ~setter:Sw.with_knob_style ~path:knob_path ~state:false
    ~make_config:enabled_config

let test_override_knob_on () =
  check_off_on ~setter:Sw.with_knob_style ~path:knob_path ~state:true
    ~make_config:enabled_config

(* A disabled setter lands on a disabled switch over the enabled style, and
   leaves an enabled switch on its enabled style. *)
let check_disabled_off_on ~setter ~enabled_setter ~path ~state =
  check_off_on ~setter ~path ~state ~make_config:disabled_config;
  let what = Printf.sprintf "on:%b" state in
  let both on =
    setter ~off:(marked 31) ~on:(marked 32)
      (enabled_setter ~off:(marked 33) ~on:(marked 33) (disabled ~on ()))
  in
  check_lands
    (what ^ ": disabled, the enabled style is displaced")
    33 (both state) [];
  let enabled =
    setter ~off:(marked 31) ~on:(marked 32)
      (enabled_setter ~off:(marked 33) ~on:(marked 33) (base ~on:state ()))
  in
  check_lands (what ^ ": enabled, the enabled style stands") 33 enabled [ path ];
  check_lands
    (what ^ ": enabled, the disabled style lands nowhere")
    (if state then 32 else 31)
    enabled []

let test_override_disabled_track_off () =
  check_disabled_off_on ~setter:Sw.with_disabled_track_style
    ~enabled_setter:Sw.with_track_style ~path:track_path ~state:false

let test_override_disabled_track_on () =
  check_disabled_off_on ~setter:Sw.with_disabled_track_style
    ~enabled_setter:Sw.with_track_style ~path:track_path ~state:true

let test_override_disabled_knob_off () =
  check_disabled_off_on ~setter:Sw.with_disabled_knob_style
    ~enabled_setter:Sw.with_knob_style ~path:knob_path ~state:false

let test_override_disabled_knob_on () =
  check_disabled_off_on ~setter:Sw.with_disabled_knob_style
    ~enabled_setter:Sw.with_knob_style ~path:knob_path ~state:true

let test_override_label () =
  check_lands "the label element and its text" 41
    (Sw.with_label_style (marked 41) (base ()))
    [ label_path; label_text_path ]

let test_override_hint () =
  (* The hint is the caller's element, so only its box is ours to style. *)
  check_lands "the hint box only" 42
    (Sw.with_hint_style (marked 42) (Sw.with_hint (hint ()) (base ())))
    [ [ 1 ] ]

let test_override_reason () =
  check_lands "the reason box and its text" 43
    (Sw.with_reason_style (marked 43) (disabled ()))
    [ [ 1 ]; [ 1; 0 ] ]

let test_override_layout () =
  check_lands "the outer box only" 44
    (Sw.with_style (marked 44) (base ()))
    [ [] ]

let direction_at path config =
  match Option.bind (node_at (tree (rendered config)) path) style with
  | Some s -> s.S.layout.S.direction
  | None -> None

let direction_testable =
  Alcotest.testable
    (fun fmt d ->
      Format.pp_print_string fmt
        (match d with
        | S.Row_dir -> "Row_dir"
        | S.Column_dir -> "Column_dir"))
    ( = )

let test_override_row () =
  check_lands "the label/button row only" 45
    (Sw.with_row_style (marked 45) (base ()))
    [ row_path ];
  Alcotest.(check (option direction_testable))
    "a row style naming no direction is filled in as a row" (Some S.Row_dir)
    (direction_at row_path (Sw.with_row_style (marked 45) (base ())));
  let column =
    marked 45
    |> S.with_layout (fun l -> { l with S.direction = Some S.Column_dir })
  in
  Alcotest.(check (option direction_testable))
    "a row style naming its own direction keeps it" (Some S.Column_dir)
    (direction_at row_path (Sw.with_row_style column (base ())))

let test_override_button () =
  check_lands "the button only" 46
    (Sw.with_button_style (marked 46) (base ()))
    [ button_path ]

let button_style config =
  match style (button_of "button" (tree (rendered config))) with
  | Some s -> s
  | None -> Alcotest.fail "the button is not an element"

let paddings (s : S.t) =
  [
    s.layout.padding_top;
    s.layout.padding_right;
    s.layout.padding_bottom;
    s.layout.padding_left;
  ]

let border_testable =
  Alcotest.testable
    (fun fmt (b : S.border) ->
      Format.fprintf fmt "{width=%g; style=%s; radius=%g}" b.width
        (match b.style with
        | S.Solid -> "Solid"
        | S.Dashed -> "Dashed"
        | S.Dotted -> "Dotted"
        | S.No_border -> "No_border")
        b.radius)
    (fun a b ->
      Float.equal a.width b.width
      && a.style = b.style
      && Float.equal a.radius b.radius
      && S.equal_color a.color b.color)

let no_border : S.border =
  {
    width = 0.;
    style = S.No_border;
    color = S.transparent;
    radius = 0.;
    corners = None;
  }

let color_testable =
  Alcotest.testable
    (fun fmt c -> Format.pp_print_string fmt (Test_util.color_to_string c))
    S.equal_color

let test_button_chrome_is_a_structural_fill_in () =
  let default = button_style (base ()) in
  Alcotest.(check (option color_testable))
    "default: transparent background" (Some S.Transparent)
    default.paint.background;
  Alcotest.(check (option border_testable))
    "default: no border" (Some no_border) default.paint.border;
  Alcotest.(check (list (option (float 0.))))
    "default: no padding"
    [ Some 0.; Some 0.; Some 0.; Some 0. ]
    (paddings default);
  let padded =
    button_style
      (Sw.with_button_style
         (S.default |> S.with_layout (S.padding_all 6.))
         (base ()))
  in
  Alcotest.(check (list (option (float 0.))))
    "the caller's padding is kept"
    [ Some 6.; Some 6.; Some 6.; Some 6. ]
    (paddings padded);
  Alcotest.(check (option color_testable))
    "padding set, the background is still filled in" (Some S.Transparent)
    padded.paint.background;
  Alcotest.(check (option border_testable))
    "padding set, the border is still filled in" (Some no_border)
    padded.paint.border;
  let painted_border : S.border =
    {
      width = 1.;
      style = S.Solid;
      color = S.hex "#123456";
      radius = 3.;
      corners = None;
    }
  in
  let painted =
    button_style
      (Sw.with_button_style
         (S.default
         |> S.with_paint (fun p ->
             {
               p with
               S.background = Some (S.hex "#abcdef");
               border = Some painted_border;
             }))
         (base ()))
  in
  Alcotest.(check (option color_testable))
    "the caller's background is kept"
    (Some (S.hex "#abcdef"))
    painted.paint.background;
  Alcotest.(check (option border_testable))
    "the caller's border is kept" (Some painted_border) painted.paint.border

let focused_of config =
  match interaction (button_of "focus" (tree (rendered config))) with
  | Some i -> i.I.focused
  | None -> Alcotest.fail "the button is not an element"

let test_override_focus_ring () =
  let ring = { I.default with focused = Some (marked 51) } in
  let t = tree (rendered (Sw.with_focus_ring ring (base ()))) in
  let has_ring node =
    match interaction node with
    | Some { I.focused = Some s; _ } ->
        Option.equal S.equal_color s.S.paint.S.background
          (Some (S.rgba 51 51 51 1.0))
    | Some { I.focused = None; _ }
    | None ->
        false
  in
  Alcotest.check path_testable "the button's focused style, no other node"
    [ button_path ] (paths_where has_ring t);
  (* The default ring: a spread shadow with no offset and no blur, carrying a
     corner radius of its own. *)
  match focused_of (base ()) with
  | None -> Alcotest.fail "no default ring"
  | Some s ->
      Alcotest.(check (option (list (float 0.))))
        "default ring: x, y, blur, spread"
        (Some [ 0.; 0.; 0.; 2. ])
        (Option.map
           (fun (sh : S.shadow) -> [ sh.x; sh.y; sh.blur; sh.spread ])
           s.S.paint.S.shadow);
      Alcotest.(check (option (float 0.)))
        "default ring: its own corner radius" (Some 12.)
        (Option.map (fun (b : S.border) -> b.radius) s.S.paint.S.border)

let node_style what path config =
  match Option.bind (node_at (tree (rendered config)) path) style with
  | Some s -> s
  | None -> Alcotest.fail (what ^ ": no element at the path")

let test_disabled_style_defaults_to_enabled_style () =
  List.iter
    (fun on ->
      let what = Printf.sprintf "on:%b" on in
      List.iter
        (fun (part, path) ->
          Alcotest.check Test_util.style_testable
            (Printf.sprintf "%s: default disabled %s is the enabled one" what
               part)
            (node_style part path (base ~on ()))
            (node_style part path (disabled ~on ())))
        [ ("track", track_path); ("knob", knob_path) ];
      let styled config =
        config
        |> Sw.with_track_style ~off:(marked 61) ~on:(marked 62)
        |> Sw.with_knob_style ~off:(marked 63) ~on:(marked 64)
      in
      let track_mark, knob_mark = if on then (62, 64) else (61, 63) in
      check_lands
        (what ^ ": a disabled track takes the caller's enabled style")
        track_mark
        (styled (disabled ~on ()))
        [ track_path ];
      check_lands
        (what ^ ": a disabled knob takes the caller's enabled style")
        knob_mark
        (styled (disabled ~on ()))
        [ knob_path ])
    [ false; true ]

let align_testable =
  Alcotest.testable
    (fun fmt (a : S.align) ->
      Format.pp_print_string fmt
        (match a with
        | Start -> "Start"
        | Center -> "Center"
        | End_ -> "End_"
        | Space_between -> "Space_between"))
    S.equal_align

let track_align config =
  (node_style "track" track_path config).S.layout.main_align

let test_track_alignment_is_structural () =
  List.iter
    (fun (on, expected) ->
      let what = Printf.sprintf "on:%b" on in
      Alcotest.(check (option align_testable))
        (what ^ ": default") (Some expected)
        (track_align (base ~on ()));
      Alcotest.(check (option align_testable))
        (what ^ ": a caller track style naming no alignment")
        (Some expected)
        (track_align
           (Sw.with_track_style ~off:(marked 71) ~on:(marked 72) (base ~on ())));
      Alcotest.(check (option align_testable))
        (what ^ ": a caller disabled track style naming no alignment")
        (Some expected)
        (track_align
           (Sw.with_disabled_track_style ~off:(marked 71) ~on:(marked 72)
              (disabled ~on ())));
      Alcotest.(check (option direction_testable))
        (what ^ ": a caller track style naming no direction is a row")
        (Some S.Row_dir)
        (direction_at track_path
           (Sw.with_track_style ~off:(marked 71) ~on:(marked 72) (base ~on ()))))
    [ (false, S.Start); (true, S.End_) ];
  let centred =
    marked 73
    |> S.with_layout (fun l ->
        { l with S.main_align = Some (Center : S.align) })
  in
  Alcotest.(check (option align_testable))
    "a caller style naming its own alignment keeps it" (Some S.Center)
    (track_align
       (Sw.with_track_style ~off:centred ~on:centred (base ~on:true ())))

(* Forced colours turn both backgrounds into the page colour, and a 2px solid
   track border and a 1px solid knob border are what survive there, measured
   in Chromium. *)
let test_default_track_and_knob_carry_borders () =
  let width_and_style what path config =
    match (node_style what path config).S.paint.S.border with
    | Some b -> Some (b.width, b.style = S.Solid)
    | None -> None
  in
  List.iter
    (fun (state, config) ->
      Alcotest.(check (option (pair (float 0.) bool)))
        (state ^ ": the track has a 2px solid border")
        (Some (2., true))
        (width_and_style "track" track_path config);
      Alcotest.(check (option (pair (float 0.) bool)))
        (state ^ ": the knob has a 1px solid border")
        (Some (1., true))
        (width_and_style "knob" knob_path config))
    [
      ("off", base ~on:false ());
      ("on", base ~on:true ());
      ("disabled off", disabled ~on:false ());
      ("disabled on", disabled ~on:true ());
    ]

let () =
  Alcotest.run "switch"
    [
      ( "switch",
        [
          Alcotest.test_case "click_dispatches_requested_value" `Quick
            test_click_dispatches_requested_value;
          Alcotest.test_case "disabled_click_dispatches_nothing" `Quick
            test_disabled_click_dispatches_nothing;
          Alcotest.test_case "disabled_label_click_dispatches_nothing" `Quick
            test_disabled_label_click_dispatches_nothing;
          Alcotest.test_case "label_click_dispatches_once" `Quick
            test_label_click_dispatches_once;
          Alcotest.test_case "description_reason_then_hint" `Quick
            test_description_reason_then_hint;
          Alcotest.test_case "description_omits_absent_ids" `Quick
            test_description_omits_absent_ids;
          Alcotest.test_case "reason_is_visible_text" `Quick
            test_reason_is_visible_text;
          Alcotest.test_case "hint_holds_a_link_outside_button_and_label" `Quick
            test_hint_holds_a_link_outside_button_and_label;
          Alcotest.test_case "with_id_moves_every_derived_id" `Quick
            test_with_id_moves_every_derived_id;
          Alcotest.test_case "with_attrs_cannot_replace_description" `Quick
            test_with_attrs_cannot_replace_description;
          Alcotest.test_case "override_reaches_node_track_off" `Quick
            test_override_track_off;
          Alcotest.test_case "override_reaches_node_track_on" `Quick
            test_override_track_on;
          Alcotest.test_case "override_reaches_node_knob_off" `Quick
            test_override_knob_off;
          Alcotest.test_case "override_reaches_node_knob_on" `Quick
            test_override_knob_on;
          Alcotest.test_case "override_reaches_node_disabled_track_off" `Quick
            test_override_disabled_track_off;
          Alcotest.test_case "override_reaches_node_disabled_track_on" `Quick
            test_override_disabled_track_on;
          Alcotest.test_case "override_reaches_node_disabled_knob_off" `Quick
            test_override_disabled_knob_off;
          Alcotest.test_case "override_reaches_node_disabled_knob_on" `Quick
            test_override_disabled_knob_on;
          Alcotest.test_case "override_reaches_node_label" `Quick
            test_override_label;
          Alcotest.test_case "override_reaches_node_hint" `Quick
            test_override_hint;
          Alcotest.test_case "override_reaches_node_reason" `Quick
            test_override_reason;
          Alcotest.test_case "override_reaches_node_layout" `Quick
            test_override_layout;
          Alcotest.test_case "override_reaches_node_row" `Quick
            test_override_row;
          Alcotest.test_case "override_reaches_node_button" `Quick
            test_override_button;
          Alcotest.test_case "override_reaches_node_focus_ring" `Quick
            test_override_focus_ring;
          Alcotest.test_case "button_chrome_is_a_structural_fill_in" `Quick
            test_button_chrome_is_a_structural_fill_in;
          Alcotest.test_case "disabled_style_defaults_to_enabled_style" `Quick
            test_disabled_style_defaults_to_enabled_style;
          Alcotest.test_case "track_alignment_is_structural" `Quick
            test_track_alignment_is_structural;
          Alcotest.test_case "default_track_and_knob_carry_borders" `Quick
            test_default_track_and_knob_carry_borders;
        ] );
    ]
