open Nopal_test.Test_renderer
module SC = Nopal_ui.Segmented_control
module S = Nopal_style.Style

type msg = Selected of string

let msg_testable =
  Alcotest.testable
    (fun fmt (Selected v) -> Format.fprintf fmt "Selected %s" v)
    ( = )

let path_testable = Alcotest.(list (list int))

let segments_of values =
  List.map (fun v -> SC.segment ~value:v (String.uppercase_ascii v)) values

let base ?(values = [ "a"; "b"; "c" ]) ?(selected = "b") () =
  SC.make ~label:"Window" ~segments:(segments_of values) ~selected
    ~on_select:(fun v -> Selected v)

(* A style recognisable wherever it lands: a background no other fixture uses
   on an element, and a font size no other fixture uses on a text node. *)
let marked n =
  S.default
  |> S.with_paint (fun p -> { p with S.background = Some (S.rgba n n n 1.0) })
  |> S.with_text (fun t ->
      { t with Nopal_style.Text.font_size = Some (Float.of_int n) })

let background node =
  match style node with
  | Some s -> s.S.paint.S.background
  | None -> None

let carries_marker n node =
  let marker = Some (S.rgba n n n 1.0) in
  match node with
  | Element _ -> Option.equal S.equal_color (background node) marker
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

let children_of = Test_util.children_of

let segments_box what tree =
  match children_of what tree with
  | [ _label; segments ] -> segments
  | []
  | [ _ ]
  | _ :: _ :: _ :: _ ->
      Alcotest.failf "%s: expected a group label and a segments box" what

type child_kind = Segment | Divider | Other

let kind_of node =
  match node with
  | Element { tag = "box"; children = []; _ } -> Divider
  | Element { tag = "box"; children; _ }
    when List.exists (fun c -> Test_util.tag_or_kind c = "radio") children ->
      Segment
  | Element _
  | Text _
  | Empty ->
      Other

let kind_testable =
  Alcotest.testable
    (fun fmt k ->
      Format.pp_print_string fmt
        (match k with
        | Segment -> "Segment"
        | Divider -> "Divider"
        | Other -> "Other"))
    ( = )

let test_divider_count () =
  List.iter
    (fun (values, expected) ->
      let what = Printf.sprintf "%d segments" (List.length values) in
      let segments =
        segments_box what (tree (render (SC.view (base ~values ()))))
      in
      Alcotest.(check (list kind_testable))
        (what ^ ": segments alternate with dividers, segments at both ends")
        expected
        (List.map kind_of (children_of what segments)))
    [
      ([], []);
      ([ "a" ], [ Segment ]);
      ([ "a"; "b" ], [ Segment; Divider; Segment ]);
      ( [ "a"; "b"; "c"; "d"; "e" ],
        [
          Segment;
          Divider;
          Segment;
          Divider;
          Segment;
          Divider;
          Segment;
          Divider;
          Segment;
        ] );
    ]

let test_role_name_checked () =
  let r = render (SC.view (base ())) in
  let t = tree r in
  Alcotest.(check (option string))
    "the outer box is a radio group" (Some "radiogroup") (attr "role" t);
  Alcotest.(check (option string))
    "named by the visible label" (Some "window-label")
    (attr "aria-labelledby" t);
  let group_label =
    Test_util.find_or_fail "group label" (By_attr ("id", "window-label")) t
  in
  Alcotest.(check string)
    "the label element shows the label text" "Window" (text_content group_label);
  List.iter
    (fun (value, checked) ->
      let radio_id = "window-" ^ value in
      let label_id = radio_id ^ "-label" in
      let radio =
        Test_util.find_or_fail (value ^ ": radio") (By_attr ("id", radio_id)) t
      in
      Alcotest.(check string)
        (value ^ ": a radio") "radio"
        (Test_util.tag_of (value ^ ": radio") radio);
      Alcotest.(
        check (result Test_util.presentation_testable Test_util.error_testable))
        (value ^ ": visually hidden")
        (Ok Nopal_style.Presentation.Visually_hidden)
        (radio_presentation (By_attr ("id", radio_id)) r);
      Alcotest.(check (option string))
        (value ^ ": named by its label")
        (Some label_id)
        (attr "aria-labelledby" radio);
      Alcotest.(check (option string))
        (value ^ ": checked follows selected")
        (Some checked) (attr "checked" radio);
      let label =
        Test_util.find_or_fail (value ^ ": label") (By_attr ("id", label_id)) t
      in
      Alcotest.(check string)
        (value ^ ": a native label")
        "label"
        (Test_util.tag_of (value ^ ": label") label);
      Alcotest.(check (option string))
        (value ^ ": for its radio")
        (Some radio_id) (attr "for" label);
      Alcotest.(check string)
        (value ^ ": shows the segment text")
        (String.uppercase_ascii value)
        (text_content label))
    [ ("a", "false"); ("b", "true"); ("c", "false") ]

let opacity_of node =
  match style node with
  | Some s -> s.S.paint.S.opacity
  | None -> Alcotest.fail "expected an element"

let test_selected_style_follows_value () =
  let plain = marked 11 |> S.with_paint (fun p -> { p with S.opacity = 0.5 }) in
  let styled selected =
    base ~selected ()
    |> SC.with_segment_style plain
    |> SC.with_selected_segment_style (marked 12)
    |> SC.with_segment_label_style (marked 13)
    |> SC.with_selected_segment_label_style (marked 14)
  in
  List.iter
    (fun (selected, at, others) ->
      let t = tree (render (SC.view (styled selected))) in
      let label_paths = List.map (fun p -> p @ [ 1 ]) in
      let text_paths = List.map (fun p -> p @ [ 1; 0 ]) in
      Alcotest.check path_testable
        (selected ^ ": the selected style is on the selected segment only")
        [ at ]
        (paths_where (carries_marker 12) t);
      Alcotest.check path_testable
        (selected ^ ": the plain style is on every other segment")
        others
        (paths_where (carries_marker 11) t);
      Alcotest.check path_testable
        (selected ^ ": the selected label style is on its label and text only")
        (label_paths [ at ] @ text_paths [ at ])
        (paths_where (carries_marker 14) t);
      Alcotest.check path_testable
        (selected ^ ": the plain label style is on every other label")
        (List.sort compare (label_paths others @ text_paths others))
        (paths_where (carries_marker 13) t);
      let selected_segment =
        Test_util.find_or_fail "segments box" (Nth_child 1) t
        |> children_of "segments"
        |> List.filteri (fun i _ -> [ 1; i ] = at)
      in
      match selected_segment with
      | [ segment ] ->
          Alcotest.(check (float 0.))
            (selected ^ ": replaced, not merged: the plain opacity is gone")
            1.0 (opacity_of segment)
      | []
      | _ :: _ :: _ ->
          Alcotest.fail "expected exactly one selected segment")
    [
      ("b", [ 1; 2 ], [ [ 1; 0 ]; [ 1; 4 ] ]);
      ("c", [ 1; 4 ], [ [ 1; 0 ]; [ 1; 2 ] ]);
    ];
  let unstyled_selected =
    tree
      (render
         (SC.view
            (base ()
            |> SC.with_segment_style plain
            |> SC.with_segment_label_style (marked 13))))
  in
  Alcotest.check path_testable
    "with no selected style, every segment carries the plain style"
    [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ]
    (paths_where (carries_marker 11) unstyled_selected);
  Alcotest.check path_testable
    "with no selected label style, every label carries the plain style"
    [
      [ 1; 0; 1 ];
      [ 1; 0; 1; 0 ];
      [ 1; 2; 1 ];
      [ 1; 2; 1; 0 ];
      [ 1; 4; 1 ];
      [ 1; 4; 1; 0 ];
    ]
    (paths_where (carries_marker 13) unstyled_selected)

let has_focused_within_marker n node =
  match interaction node with
  | Some { Nopal_style.Interaction.focused_within = Some s; _ } ->
      Option.equal S.equal_color s.S.paint.S.background
        (Some (S.rgba n n n 1.0))
  | Some { Nopal_style.Interaction.focused_within = None; _ }
  | None ->
      false

let test_each_override_reaches_its_node () =
  let all_segments = [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ] in
  let labels_and_texts =
    [
      [ 1; 0; 1 ];
      [ 1; 0; 1; 0 ];
      [ 1; 2; 1 ];
      [ 1; 2; 1; 0 ];
      [ 1; 4; 1 ];
      [ 1; 4; 1; 0 ];
    ]
  in
  List.iter
    (fun (setter, set, expected) ->
      let t = tree (render (SC.view (set (marked 21) (base ())))) in
      Alcotest.check path_testable
        (setter ^ " lands on its nodes and no other")
        expected
        (paths_where (carries_marker 21) t))
    [
      ("with_group_style", SC.with_group_style, [ [] ]);
      ("with_label_style", SC.with_label_style, [ [ 0 ]; [ 0; 0 ] ]);
      ("with_segments_style", SC.with_segments_style, [ [ 1 ] ]);
      ("with_segment_style", SC.with_segment_style, all_segments);
      ("with_segment_label_style", SC.with_segment_label_style, labels_and_texts);
      ( "with_selected_segment_style",
        SC.with_selected_segment_style,
        [ [ 1; 2 ] ] );
      ( "with_selected_segment_label_style",
        SC.with_selected_segment_label_style,
        [ [ 1; 2; 1 ]; [ 1; 2; 1; 0 ] ] );
      ("with_divider_style", SC.with_divider_style, [ [ 1; 1 ]; [ 1; 3 ] ]);
    ];
  let t =
    tree
      (render
         (SC.view
            (base ()
            |> SC.with_attrs
                 [
                   ("data-testid", "mine");
                   ("data-extra", "1");
                   ("aria-describedby", "hint");
                 ])))
  in
  Alcotest.check path_testable "with_attrs lands on the outer box only" [ [] ]
    (paths_where (fun n -> attr "data-testid" n = Some "mine") t);
  Alcotest.(check (list (option string)))
    "with_attrs adds its pairs and leaves the role and naming in place"
    [ Some "hint"; Some "1"; Some "radiogroup"; Some "window-label" ]
    [
      attr "aria-describedby" t;
      attr "data-extra" t;
      attr "role" t;
      attr "aria-labelledby" t;
    ];
  let ring =
    { Nopal_style.Interaction.default with focused_within = Some (marked 22) }
  in
  let t =
    tree (render (SC.view (base () |> SC.with_segment_interaction ring)))
  in
  Alcotest.check path_testable
    "with_segment_interaction lands on every segment and no other node"
    all_segments
    (paths_where (has_focused_within_marker 22) t);
  let t = tree (render (SC.view (base () |> SC.with_id "mine"))) in
  Alcotest.check path_testable "with_id: only the outer box carries the id"
    [ [] ]
    (paths_where (fun n -> attr "id" n = Some "mine") t);
  Alcotest.(check (list (option string)))
    "with_id: every derived id moves with it"
    [
      Some "mine-label";
      Some "mine-label";
      Some "mine-b";
      Some "mine-b-label";
      Some "mine-b";
    ]
    [
      attr "aria-labelledby" t;
      Option.bind (find (Nth_child 0) t) (attr "id");
      Option.bind
        (find (By_attr ("aria-labelledby", "mine-b-label")) t)
        (attr "id");
      Option.bind (find (By_attr ("for", "mine-b")) t) (attr "id");
      Some (SC.option_id (base () |> SC.with_id "mine") ~value:"b");
    ];
  Alcotest.(check string)
    "with_id: the control id accessor answers it" "mine"
    (SC.control_id (base () |> SC.with_id "mine"));
  let t = tree (render (SC.view (base () |> SC.with_name "pick"))) in
  Alcotest.check path_testable
    "with_name: every radio, and nothing else, carries the name"
    [ [ 1; 0; 0 ]; [ 1; 2; 0 ]; [ 1; 4; 0 ] ]
    (paths_where (fun n -> attr "name" n = Some "pick") t);
  Alcotest.check path_testable "with_name: no node keeps the label-derived name"
    []
    (paths_where (fun n -> attr "name" n = Some "window") t);
  Alcotest.check path_testable "with_name: the ids stay on the label" [ [] ]
    (paths_where (fun n -> attr "id" n = Some "window") t)

let test_select_dispatches_value () =
  List.iter
    (fun value ->
      let r = render (SC.view (base ())) in
      Alcotest.(check (result unit Test_util.error_testable))
        (value ^ ": pressing its label")
        (Ok ())
        (click (By_attr ("for", "window-" ^ value)) r);
      Alcotest.(check (list msg_testable))
        (value ^ ": dispatches its value")
        [ Selected value ] (messages r))
    [ "a"; "b"; "c" ]

let node_at what path tree =
  List.fold_left
    (fun node i ->
      match List.nth_opt (children_of what node) i with
      | Some child -> child
      | None -> Alcotest.failf "%s: no child %d" what i)
    tree path

let style_at what path tree =
  match style (node_at what path tree) with
  | Some s -> s
  | None -> Alcotest.failf "%s: expected an element" what

let corners_testable =
  Alcotest.testable
    (fun fmt (c : S.corners) ->
      Format.fprintf fmt "{tl=%g; tr=%g; br=%g; bl=%g}" c.top_left c.top_right
        c.bottom_right c.bottom_left)
    (fun (a : S.corners) (b : S.corners) ->
      Float.equal a.top_left b.top_left
      && Float.equal a.top_right b.top_right
      && Float.equal a.bottom_right b.bottom_right
      && Float.equal a.bottom_left b.bottom_left)

let corners ~tl ~tr ~br ~bl : S.corners =
  { top_left = tl; top_right = tr; bottom_right = br; bottom_left = bl }

let corners_at what path tree =
  Option.bind (style_at what path tree).S.paint.S.border (fun b -> b.S.corners)

let border ?corners:c ~radius ~width () : S.border =
  { width; style = S.Solid; color = S.rgba 0 0 0 1.0; radius; corners = c }

let with_border b style =
  S.with_paint (fun p -> { p with S.border = Some b }) style

(* The design the control was specified against draws its container with a
   1px border at a 6px radius, so the segments inside it round by 5px. *)
let container = S.default |> with_border (border ~radius:6. ~width:1. ())

let check_corners what expected paths tree =
  List.iter2
    (fun e path ->
      Alcotest.(check (option corners_testable))
        (Printf.sprintf "%s: segment at %s" what
           (String.concat "." (List.map string_of_int path)))
        e
        (corners_at what path tree))
    expected paths

let check_border_fields what ~width ~style ~color paths tree =
  List.iter
    (fun path ->
      let label field =
        Printf.sprintf "%s: %s of segment at %s" what field
          (String.concat "." (List.map string_of_int path))
      in
      match (style_at what path tree).S.paint.S.border with
      | None -> Alcotest.failf "%s: expected a border" (label "border")
      | Some b ->
          Alcotest.(check (float 0.)) (label "width") width b.width;
          Alcotest.(check bool) (label "style") true (b.style = style);
          Alcotest.(check bool)
            (label "color") true
            (S.equal_color b.color color))
    paths

let first_end = Some (corners ~tl:5. ~tr:0. ~br:0. ~bl:5.)
let last_end = Some (corners ~tl:0. ~tr:5. ~br:5. ~bl:0.)

let test_end_corners_from_container () =
  let t =
    tree (render (SC.view (base () |> SC.with_segments_style container)))
  in
  check_corners "radius 6, width 1"
    [ first_end; None; last_end ]
    [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ]
    t;
  let t =
    tree
      (render
         (SC.view
            (base ~values:[ "a" ] ~selected:"a" ()
            |> SC.with_segments_style container)))
  in
  check_corners "a lone segment"
    [ Some (corners ~tl:5. ~tr:5. ~br:5. ~bl:5.) ]
    [ [ 1; 0 ] ]
    t;
  let zero = Some (corners ~tl:0. ~tr:0. ~br:0. ~bl:0.) in
  let t =
    tree (render (SC.view (base () |> SC.with_segments_style (marked 31))))
  in
  check_corners "no border on the segments style" [ zero; None; zero ]
    [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ]
    t;
  check_border_fields "no border on the segments style" ~width:0.
    ~style:S.No_border ~color:S.Transparent
    [ [ 1; 0 ]; [ 1; 4 ] ]
    t;
  let t = tree (render (SC.view (base ()))) in
  check_corners "no segments style" [ zero; None; zero ]
    [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ]
    t;
  check_border_fields "no segments style" ~width:0. ~style:S.No_border
    ~color:S.Transparent
    [ [ 1; 0 ]; [ 1; 4 ] ]
    t;
  let t =
    tree
      (render
         (SC.view
            (base ~values:[ "a" ] ~selected:"a" ()
            |> SC.with_segments_style
                 (S.default |> with_border (border ~radius:1. ~width:3. ())))))
  in
  check_corners "a border wider than its radius floors at 0" [ zero ]
    [ [ 1; 0 ] ]
    t;
  let t =
    tree
      (render
         (SC.view
            (base ~values:[ "a" ] ~selected:"a" ()
            |> SC.with_segments_style
                 (S.default
                 |> with_border
                      {
                        (border ~radius:6. ~width:1. ()) with
                        style = S.No_border;
                      }))))
  in
  check_corners "a border that paints no line subtracts no width"
    [ Some (corners ~tl:6. ~tr:6. ~br:6. ~bl:6.) ]
    [ [ 1; 0 ] ]
    t;
  let per_corner =
    S.default
    |> with_border
         (border
            ~corners:(corners ~tl:10. ~tr:8. ~br:6. ~bl:4.)
            ~radius:0. ~width:2. ())
  in
  let t =
    tree (render (SC.view (base () |> SC.with_segments_style per_corner)))
  in
  check_corners "a container rounding each corner by its own radius"
    [
      Some (corners ~tl:8. ~tr:0. ~br:0. ~bl:2.);
      None;
      Some (corners ~tl:0. ~tr:6. ~br:4. ~bl:0.);
    ]
    [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ]
    t;
  let column =
    container
    |> S.with_layout (fun l -> { l with S.direction = Some S.Column_dir })
  in
  let t = tree (render (SC.view (base () |> SC.with_segments_style column))) in
  check_corners "segments laid out in a column round top and bottom"
    [
      Some (corners ~tl:5. ~tr:5. ~br:0. ~bl:0.);
      None;
      Some (corners ~tl:0. ~tr:0. ~br:5. ~bl:5.);
    ]
    [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ]
    t;
  let caller_corners = corners ~tl:9. ~tr:9. ~br:9. ~bl:9. in
  let segment =
    S.default
    |> with_border (border ~corners:caller_corners ~radius:0. ~width:2. ())
  in
  let t =
    tree
      (render
         (SC.view
            (base ()
            |> SC.with_segments_style container
            |> SC.with_segment_style segment)))
  in
  check_corners "the end corners replace a segment style's own corners"
    [ first_end; Some caller_corners; last_end ]
    [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ]
    t;
  Alcotest.(check (list (option (float 0.))))
    "the rest of a segment style's border is kept on every segment"
    [ Some 2.; Some 2.; Some 2. ]
    (List.map
       (fun path ->
         Option.map
           (fun (b : S.border) -> b.width)
           (style_at "segment border" path t).S.paint.S.border)
       [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ]);
  check_border_fields "a bordered end segment" ~width:2. ~style:S.Solid
    ~color:(S.rgba 0 0 0 1.0)
    [ [ 1; 0 ]; [ 1; 4 ] ]
    t

let test_end_corners_apply_to_selected_style_too () =
  List.iter
    (fun (selected, at, expected) ->
      let t =
        tree
          (render
             (SC.view
                (base ~selected ()
                |> SC.with_segments_style container
                |> SC.with_selected_segment_style (marked 12))))
      in
      Alcotest.check path_testable
        (selected ^ ": the selected style is on the end segment")
        [ at ]
        (paths_where (carries_marker 12) t);
      check_corners (selected ^ ": selected end segment") [ expected ] [ at ] t)
    [ ("a", [ 1; 0 ], first_end); ("c", [ 1; 4 ], last_end) ]

let interaction_of what node =
  match interaction node with
  | Some i -> i
  | None -> Alcotest.failf "%s: expected an element" what

let ring_z_index what path tree =
  match (interaction_of what (node_at what path tree)).focused_within with
  | Some s -> Some s.S.layout.S.z_index
  | None -> None

let test_ring_layer_raised () =
  let ring z_index =
    {
      Nopal_style.Interaction.hover = None;
      pressed = None;
      focused = None;
      focused_within =
        Some (marked 22 |> S.with_layout (fun l -> { l with S.z_index }));
    }
  in
  let segments = [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ] in
  List.iter
    (fun (what, given, expected) ->
      let t =
        tree (render (SC.view (base () |> SC.with_segment_interaction given)))
      in
      Alcotest.(check (list (option (option int))))
        what
        [ expected; expected; expected ]
        (List.map (fun path -> ring_z_index what path t) segments))
    [
      ("a ring with no layer is raised to 1", ring None, Some (Some 1));
      ("a ring's own layer is kept", ring (Some 7), Some (Some 7));
    ];
  let t = tree (render (SC.view (base ()))) in
  Alcotest.(check (list bool))
    "no interaction is added when none is set" [ true; true; true ]
    (List.map
       (fun path ->
         not
           (Nopal_style.Interaction.has_any
              (interaction_of "unset" (node_at "unset" path t))))
       segments);
  let hover_only =
    {
      Nopal_style.Interaction.hover = Some (marked 23);
      pressed = None;
      focused = None;
      focused_within = None;
    }
  in
  let t =
    tree (render (SC.view (base () |> SC.with_segment_interaction hover_only)))
  in
  Alcotest.(check (list bool))
    "an interaction with no focused_within reaches every segment unchanged"
    [ true; true; true ]
    (List.map
       (fun path ->
         Nopal_style.Interaction.equal hover_only
           (interaction_of "hover only" (node_at "hover only" path t)))
       segments)

let position_testable =
  Alcotest.testable
    (fun fmt p ->
      Format.pp_print_string fmt
        (match p with
        | S.Pos_static -> "Pos_static"
        | S.Pos_relative -> "Pos_relative"
        | S.Pos_absolute -> "Pos_absolute"
        | S.Pos_fixed -> "Pos_fixed"))
    ( = )

let test_segments_position_relative () =
  let positions t paths =
    List.map
      (fun path -> (style_at "position" path t).S.layout.S.position)
      paths
  in
  let segments = [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ] in
  let t = tree (render (SC.view (base ()))) in
  Alcotest.(check (list (option position_testable)))
    "every segment is relatively positioned"
    [ Some S.Pos_relative; Some S.Pos_relative; Some S.Pos_relative ]
    (positions t segments);
  Alcotest.(check (list (option position_testable)))
    "no divider is positioned" [ None; None ]
    (positions t [ [ 1; 1 ]; [ 1; 3 ] ]);
  let static =
    S.default
    |> S.with_layout (fun l -> { l with S.position = Some S.Pos_static })
  in
  let t =
    tree
      (render
         (SC.view
            (base ()
            |> SC.with_segment_style static
            |> SC.with_selected_segment_style (marked 12))))
  in
  Alcotest.(check (list (option position_testable)))
    "a caller's position is kept, and a selected style without one is filled"
    [ Some S.Pos_static; Some S.Pos_relative; Some S.Pos_static ]
    (positions t segments)

let direction_testable =
  Alcotest.testable
    (fun fmt d ->
      Format.pp_print_string fmt
        (match d with
        | S.Row_dir -> "Row_dir"
        | S.Column_dir -> "Column_dir"))
    ( = )

let test_direction_reaches_box () =
  let direction path t = (style_at "direction" path t).S.layout.S.direction in
  let column =
    S.default
    |> S.with_layout (fun l -> { l with S.direction = Some S.Column_dir })
  in
  let t = tree (render (SC.view (base ()))) in
  Alcotest.(check string)
    "the segments container is a box" "box"
    (Test_util.tag_of "segments" (node_at "segments" [ 1 ] t));
  Alcotest.(check (option direction_testable))
    "the segments box lays out in a row by default" (Some S.Row_dir)
    (direction [ 1 ] t);
  let t = tree (render (SC.view (base () |> SC.with_segments_style column))) in
  Alcotest.(check (option direction_testable))
    "a column in the segments style reaches the segments box"
    (Some S.Column_dir) (direction [ 1 ] t);
  let t = tree (render (SC.view (base () |> SC.with_segment_style column))) in
  Alcotest.(check (list (option direction_testable)))
    "a column in the segment style reaches every segment box"
    [ Some S.Column_dir; Some S.Column_dir; Some S.Column_dir ]
    (List.map (fun path -> direction path t) [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ]);
  let t = tree (render (SC.view (base ()))) in
  Alcotest.(check (list (option direction_testable)))
    "a segment box lays out in a row when no direction is set"
    [ Some S.Row_dir; Some S.Row_dir; Some S.Row_dir ]
    (List.map (fun path -> direction path t) [ [ 1; 0 ]; [ 1; 2 ]; [ 1; 4 ] ])

let test_label_fills_segment () =
  let labels = [ [ 1; 0; 1 ]; [ 1; 2; 1 ]; [ 1; 4; 1 ] ] in
  let grows t =
    List.map (fun path -> (style_at "label" path t).S.layout.S.flex_grow) labels
  in
  let t = tree (render (SC.view (base ()))) in
  Alcotest.(check (list (option (float 0.))))
    "every label grows to fill its segment"
    [ Some 1.; Some 1.; Some 1. ]
    (grows t);
  Alcotest.(check (list bool))
    "the segment text stays unstyled with no label style" [ true; true; true ]
    (List.map
       (fun path ->
         match node_at "text" (path @ [ 0 ]) t with
         | Text { text_style = None; _ } -> true
         | Text { text_style = Some _; _ }
         | Element _
         | Empty ->
             false)
       labels);
  let fixed =
    S.default |> S.with_layout (fun l -> { l with S.flex_grow = Some 0. })
  in
  let t =
    tree
      (render
         (SC.view
            (base ()
            |> SC.with_segment_label_style fixed
            |> SC.with_selected_segment_label_style (marked 14))))
  in
  Alcotest.(check (list (option (float 0.))))
    "a caller's growth is kept, and a selected style without one is filled"
    [ Some 0.; Some 1.; Some 0. ]
    (grows t)

let () =
  Alcotest.run "Segmented_control"
    [
      ( "segmented_control",
        [
          Alcotest.test_case "divider_count" `Quick test_divider_count;
          Alcotest.test_case "role_name_checked" `Quick test_role_name_checked;
          Alcotest.test_case "selected_style_follows_value" `Quick
            test_selected_style_follows_value;
          Alcotest.test_case "each_override_reaches_its_node" `Quick
            test_each_override_reaches_its_node;
          Alcotest.test_case "select_dispatches_value" `Quick
            test_select_dispatches_value;
          Alcotest.test_case "end_corners_from_container" `Quick
            test_end_corners_from_container;
          Alcotest.test_case "end_corners_apply_to_selected_style_too" `Quick
            test_end_corners_apply_to_selected_style_too;
          Alcotest.test_case "ring_layer_raised" `Quick test_ring_layer_raised;
          Alcotest.test_case "segments_position_relative" `Quick
            test_segments_position_relative;
          Alcotest.test_case "direction_reaches_box" `Quick
            test_direction_reaches_box;
          Alcotest.test_case "label_fills_segment" `Quick
            test_label_fills_segment;
        ] );
    ]
