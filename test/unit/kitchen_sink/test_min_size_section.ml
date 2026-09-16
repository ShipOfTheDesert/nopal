(* The "a floor of zero lets a scrolling descendant scroll" kitchen-sink section,
   read structurally.

   What this file can and cannot see. Whether the band left its container and
   whether the pane scrolls are measurements of rendered geometry, and the
   structural renderer emits no CSS and lays nothing out, so no assertion here
   can witness what the section demonstrates — that half is
   test/e2e/tests/kitchen-sink-min-size.spec.ts's, and nothing in this file may
   be read as evidence for it.

   What is left is still worth pinning, because those measurements rest on it
   entirely. They are meaningful only while the fixture stays overconstrained and
   the control still reaches the column it claims to: a bounded column grown tall
   enough to hold its content, or a toggle that stopped changing anything, would
   leave every geometry assertion green and vacuous. Those are the preconditions,
   and they are what this file holds.

   The control is driven by toggling the rendered checkbox rather than by naming
   the message behind it, so a control the view stopped rendering fails at the
   simulator instead of leaving a case here driving the section by hand. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_min_size
module Style = Nopal_style.Style
module Interaction = Nopal_style.Interaction

let vp = Nopal_element.Viewport.desktop

(* The section driven through the MVU loop rather than by building a model, so a
   state the section can no longer reach cannot keep an assertion alive here. *)
let after msgs =
  fst (run_app ~init:Sub.init ~update:Sub.update ~view:Sub.view msgs)

let rendered_for model = render (Sub.view vp model)
let demo = By_attr ("data-testid", "min-size-demo")
let bounded = By_attr ("data-testid", "min-size-bounded")
let holding = By_attr ("data-testid", "min-size-holding")
let pane = By_attr ("data-testid", "min-size-pane")
let content = By_attr ("data-testid", "min-size-content")
let band = By_attr ("data-testid", "min-size-band")
let floor_control = By_attr ("data-field", "min-size-floor")

let node_in label selector parent =
  match find selector parent with
  | Some node -> node
  | None -> Alcotest.fail (label ^ ": the section renders no such element")

let node_at label selector model =
  node_in label selector (tree (rendered_for model))

let layout_of_node label node =
  match style node with
  | Some s -> s.Style.layout
  | None ->
      Alcotest.fail
        (label ^ ": carries no style, so it declares no geometry at all")

(* Each accessor descends from the element that is supposed to hold it rather
   than searching the whole tree, because the nesting is what the fixture is. A
   pane promoted to a direct child of the bounded column would still be found by
   a tree-wide search, and the section would quietly stop demonstrating anything:
   a scrolling container's own automatic minimum is already zero, so with nothing
   between it and the bounded column there is no growth left to floor. *)
let bounded_node model = node_at "the bounded column" bounded model

let holding_node model =
  node_in "the holding column" holding (bounded_node model)

let pane_node model = node_in "the pane" pane (holding_node model)
let content_node model = node_in "the pane's content" content (pane_node model)

(* The band is looked for inside the bounded column and then denied inside the
   holding column. Beneath the holding column it would be carried down with it
   and could never leave the fixture, so "the band is a sibling of the column
   that gives way" is a precondition of the whole demonstration and not a
   detail of where it is written. *)
let band_node model = node_in "the band" band (bounded_node model)

let floors_to_string (l : Style.layout) =
  let px f =
    match f with
    | Some v -> Printf.sprintf "%g" v
    | None -> "none"
  in
  Printf.sprintf "min_width=%s min_height=%s" (px l.Style.min_width)
    (px l.Style.min_height)

let floors_of_layout name (l : Style.layout) =
  match (l.Style.min_width, l.Style.min_height) with
  | None, None -> []
  | Some _, _
  | None, Some _ ->
      [ name ^ ": " ^ floors_to_string l ]

(* Every element in the section that declares a floor, named by its test id so a
   failure says which one, and by its tag where a view gave it no id. The whole
   tree is walked rather than a named node read: the claim is not only that the
   control reaches the holding column, it is that it reaches nothing else, and an
   element nobody thought to name is exactly where a stray floor would sit.

   The three interaction states are walked beside the base style, and the state a
   floor was found in is named the way the base style's is, so a failure says the
   site and not merely that one exists. They are not a formality: a minimum is
   emitted out of a hover, focused or pressed style exactly as it is out of a base
   one — test_min_size_emitted_in_interaction_style pins that at the emitter — so
   a floor declared in one of them is a live escape from a claim phrased as
   "and on no other element". Each state is a whole style of its own and can
   carry its own floor, which is why each is reported separately rather than
   folded into the element's one line.

   What the walk covers is every [Style.t] a rendered node holds: its base style
   and those three. A floor lives on a [Style.layout] and a node carries no other
   layout, so within this section's element tree nothing of that kind is out of
   reach. It sees declared style and nothing else — what a browser then does with
   a floor is not visible to this renderer at all. *)
let rec declared_floors node =
  match node with
  | Empty -> []
  | Text _ -> []
  | Element { tag; style; attrs; children; interaction } ->
      let name =
        match
          List.find_opt (fun (k, _) -> String.equal k "data-testid") attrs
        with
        | Some (_, id) -> id
        | None -> "<" ^ tag ^ ">"
      in
      let { Interaction.hover; pressed; focused } = interaction in
      let in_state state_name state =
        match state with
        | None -> []
        | Some (s : Style.t) ->
            floors_of_layout (name ^ " (" ^ state_name ^ ")") s.Style.layout
      in
      floors_of_layout name style.Style.layout
      @ in_state "hover" hover
      @ in_state "focused" focused
      @ in_state "pressed" pressed
      @ List.concat_map declared_floors children

let floors_in model = declared_floors (tree (rendered_for model))

let fail_on_error label result =
  match result with
  | Ok () -> ()
  | Error (Not_found _) -> Alcotest.fail (label ^ ": no such control")
  | Error (No_handler { tag; event }) ->
      Alcotest.fail
        (Printf.sprintf "%s: the %s control handles no %s" label tag event)

let single_message label rendered =
  match messages rendered with
  | [ msg ] -> msg
  | [] -> Alcotest.fail (label ^ " dispatched no message")
  | _ :: _ :: _ -> Alcotest.fail (label ^ " dispatched more than one message")

let flip_floor model =
  let label = "the floor control" in
  let rendered = rendered_for model in
  fail_on_error label (toggle floor_control rendered);
  single_message label rendered

(* Sizes are compared as text rather than through a custom testable so a failure
   names the size that was found. Every constructor is spelled out: a size the
   style vocabulary gains later should stop compiling here rather than fall into
   a catch-all and read as one of these. *)
let size_to_string (s : Style.size) =
  match s with
  | Style.Fill -> "Fill"
  | Style.Hug -> "Hug"
  | Style.Fixed f -> Printf.sprintf "Fixed %g" f
  | Style.Fraction f -> Printf.sprintf "Fraction %g" f

let size = Alcotest.(option string)
let declared s = Some (size_to_string s)
let shown = Option.map size_to_string

let settled_height label node =
  match (layout_of_node label node).Style.height with
  | Some (Style.Fixed f) -> f
  | Some Style.Fill
  | Some Style.Hug
  | Some (Style.Fraction _)
  | None ->
      Alcotest.fail
        (label
       ^ ": declares no settled height, so the room in the fixture is whatever \
          the page happens to give it")

(* The reported shape is the one the section opens in, because a section that
   opened already fixed would show the remedy and never the defect. The absence
   is asserted over the whole tree rather than at the holding column alone, so a
   floor declared somewhere nobody named also reddens this.

   The affirmative arm is the control itself: an empty result would stay green if
   the view stopped rendering the section altogether, and reading the checkbox
   back proves the state the emptiness is being claimed about is reachable.

   The interaction states owe a second arm of their own. The section declares
   none, so those three branches of the walk never fire against the rendered tree
   and a walk that read the same state three times, or none of them, would leave
   the emptiness above green for the wrong reason. A node built here rather than
   rendered is what exercises them, which is also why each state is checked by the
   name it reports under. *)
let probe_floor value =
  Style.default
  |> Style.with_layout (fun l -> { l with Style.min_height = Some value })

let probe_node interaction =
  Element
    {
      tag = "div";
      style = Style.default;
      attrs = [ ("data-testid", "probe") ];
      children = [];
      interaction;
    }

let test_init_starts_without_the_minimum () =
  let model = after [] in
  Alcotest.(check bool)
    "the section opens in the reported shape, with the control off" false
    model.Sub.floor_lifted;
  Alcotest.(check bool)
    "and the control is rendered, so the shape is one the reader can leave" true
    (Option.is_some (find floor_control (tree (rendered_for model))));
  Alcotest.(check (list string))
    "no element in the section declares a floor of any kind" []
    (floors_in model);
  Alcotest.(check (list string))
    "and a floor in any of the three interaction states would be reported, \
     each under the state it sits in, so the emptiness above is a statement \
     about every style an element carries"
    [
      "probe (hover): min_width=none min_height=1";
      "probe (focused): min_width=none min_height=2";
      "probe (pressed): min_width=none min_height=3";
    ]
    (declared_floors
       (probe_node
          {
            Interaction.hover = Some (probe_floor 1.0);
            focused = Some (probe_floor 2.0);
            pressed = Some (probe_floor 3.0);
          }))

(* The control reaches the holding column, and reaches nothing else. Both halves
   on the one walk: the initial value alone would be satisfied by a section that
   hard-codes it and ignores the control, and a named-node read would be
   satisfied by a section that floors every box it renders. *)
let test_toggle_sets_the_minimum_on_the_column () =
  let unfloored = after [] in
  let floored = after [ flip_floor unfloored ] in
  Alcotest.(check (list string))
    "the control declares a floor of zero on the holding column, and on no \
     other element, and leaves the other axis alone"
    [ "min-size-holding: min_width=none min_height=0" ]
    (floors_in floored);
  Alcotest.(check (list string))
    "and takes it away again, so the shape the fixture is in is the control's \
     and not a one-way latch"
    []
    (floors_in (after [ flip_floor unfloored; flip_floor floored ]))

(* The precondition every measurement rests on. The pane's content has to be
   taller than the room the bounded column can give it, or the holding column
   never wanted to grow, the band never left, and both browser cases pass while
   measuring a fixture that demonstrates nothing.

   The room is computed from the two settled heights actually rendered rather
   than assumed, so shrinking the content, growing the bounded column or growing
   the band all redden this. The holding column is asserted to declare no height
   of its own in the same breath: one given a settled height is not the element
   that gives way, and a floor on it would then be as inert as a floor on the
   bounded column. *)
let test_fixture_is_overconstrained () =
  let model = after [] in
  let bounded_height =
    settled_height "the bounded column" (bounded_node model)
  in
  let band_height = settled_height "the band" (band_node model) in
  let content_height =
    settled_height "the pane's content" (content_node model)
  in
  Alcotest.check size
    "the holding column declares no height of its own, so it is the element \
     the fixture reduces"
    None
    (shown
       (layout_of_node "the holding column" (holding_node model)).Style.height);
  Alcotest.check size
    "and the pane declares none either, so the room it gets is the room the \
     column has"
    None
    (shown (layout_of_node "the pane" (pane_node model)).Style.height);
  Alcotest.(check bool)
    "the pane's content is taller than the bounded column that holds it" true
    (content_height > bounded_height);
  Alcotest.(check bool)
    "and taller than the room left once the band has taken its own, which is \
     the room the pane can actually be given"
    true
    (content_height > bounded_height -. band_height);
  (* The number is restated here rather than read back out of the node, which is
     what the browser case does with the same size and for the same reason: an
     expected side derived from the node under test compares a size with itself
     and stays green however the section is changed. The settled-height accessor
     above already holds the "settled rather than the page's" half by failing
     when it is not a [Fixed]. *)
  Alcotest.check size
    "the bounded column declares the height both suites are written against, \
     so a size changed in the section reddens here rather than being read back \
     out of it"
    (declared (Style.Fixed 200.))
    (shown
       (layout_of_node "the bounded column" (bounded_node model)).Style.height);
  Alcotest.(check bool)
    "the band is not inside the column that gives way, or it would be carried \
     down with it and could never leave the fixture"
    true
    (Option.is_none (find band (holding_node model)));
  (* The reported shape is the one that escapes, and the section's own root is
     what keeps that escape inside the section's footprint. The overflow is
     visible by design, so a band laid out past the root as well would paint over
     the section below it and take its pointer events — a failure that would
     surface as an unrelated section's browser case going red, with nothing
     pointing back here. In that shape the column that gives way is as tall as
     the pane's content and the band sits beneath it, so that pair is the room
     the root has to hold. *)
  let reserved =
    settled_height "the section's root"
      (node_at "the section's root" demo model)
  in
  Alcotest.(check bool)
    "the section's root reserves at least the room the reported shape takes, \
     so the band that leaves the bounded column stays inside the section"
    true
    (reserved >= content_height +. band_height)

let () =
  Alcotest.run "kitchen_sink_min_size_section"
    [
      ( "the reported shape",
        [
          Alcotest.test_case "the section starts without the minimum" `Quick
            test_init_starts_without_the_minimum;
        ] );
      ( "the control",
        [
          Alcotest.test_case "the toggle sets the minimum on the column" `Quick
            test_toggle_sets_the_minimum_on_the_column;
        ] );
      ( "the fixture",
        [
          Alcotest.test_case "is overconstrained" `Quick
            test_fixture_is_overconstrained;
        ] );
    ]
