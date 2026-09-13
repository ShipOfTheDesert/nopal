(* The "a Fixed size must not shrink" kitchen-sink section, read structurally.

   What this file can and cannot see. Whether a declared size survived being laid
   out is a measurement of rendered geometry, and the structural renderer emits no
   CSS and lays nothing out, so no assertion here can witness the rule the section
   demonstrates — that half is the browser spec's, and nothing in this file may be
   read as evidence for it.

   What is left is still worth pinning, because the browser spec rests on it
   entirely. Its measurements are only meaningful while each fixture stays
   overconstrained and each control still reaches the style it claims to: a row
   widened past its columns, or a toggle that stopped changing anything, would
   leave every geometry assertion green and vacuous. Those are the preconditions,
   and they are what this file holds.

   Both controls are driven by toggling the rendered checkbox rather than by
   naming the message behind it, so a control the view stopped rendering fails at
   the simulator instead of leaving a case here driving the section by hand. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_fixed_size
module Style = Nopal_style.Style
module Text = Nopal_style.Text

let vp = Nopal_element.Viewport.desktop

(* The section driven through the MVU loop rather than by building a model, so a
   state the section can no longer reach cannot keep an assertion alive here. *)
let after msgs =
  fst (run_app ~init:Sub.init ~update:Sub.update ~view:Sub.view msgs)

let rendered_for model = render (Sub.view vp model)
let pair = By_attr ("data-testid", "fixed-size-pair")
let fixed_box = By_attr ("data-testid", "fixed-size-fixed")
let flexible_box = By_attr ("data-testid", "fixed-size-flexible")
let columns_row = By_attr ("data-testid", "fixed-size-columns")

let column index =
  By_attr ("data-testid", Printf.sprintf "fixed-size-column-%d" index)

let wrap_control = By_attr ("data-field", "fixed-size-wrap")
let stack_control = By_attr ("data-field", "fixed-size-stack")

let node_at label selector model =
  match find selector (tree (rendered_for model)) with
  | Some node -> node
  | None -> Alcotest.fail (label ^ ": the section renders no such element")

let layout_of label selector model =
  match style (node_at label selector model) with
  | Some s -> s.Style.layout
  | None ->
      Alcotest.fail (label ^ ": carries no style, so it declares no size at all")

(* Sizes are compared as text rather than through a custom testable so a failure
   names the size that was found. Every constructor is spelled out: a size the
   style vocabulary gains later should stop compiling here rather than fall into a
   catch-all and read as one of these. *)
let size_to_string (s : Style.size) =
  match s with
  | Style.Fill -> "Fill"
  | Style.Hug -> "Hug"
  | Style.Fixed f -> Printf.sprintf "Fixed %g" f
  | Style.Fraction f -> Printf.sprintf "Fraction %g" f

let size = Alcotest.(option string)
let declared s = Some (size_to_string s)
let shown = Option.map size_to_string

let direction_to_string (d : Style.direction) =
  match d with
  | Style.Row_dir -> "Row_dir"
  | Style.Column_dir -> "Column_dir"

let wrapping_to_string (o : Text.text_overflow) =
  match o with
  | Text.Clip -> "Clip"
  | Text.Ellipsis -> "Ellipsis"
  | Text.Wrap -> "Wrap"
  | Text.No_wrap -> "No_wrap"

(* The token's own node, found by the token rather than by a testid, because the
   sibling's text style lives on the text node and the token is the only text in
   the section that could be carrying it. *)
let sibling_text label model =
  match
    find (By_text Sub.unbreakable_token) (node_at label flexible_box model)
  with
  | Some node -> node
  | None ->
      Alcotest.fail
        (label ^ ": no text node in the sibling holds the unbreakable token")

let sibling_wrapping label model =
  match text_style (sibling_text label model) with
  | None ->
      Alcotest.fail
        (label
       ^ ": the sibling's text carries no style, so its wrapping is whatever \
          the platform defaults to")
  | Some t -> Option.map wrapping_to_string t.Text.text_overflow

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

let flip label selector model =
  let rendered = rendered_for model in
  fail_on_error label (toggle selector rendered);
  single_message label rendered

let flip_wrap model = flip "the wrapping control" wrap_control model
let flip_stack model = flip "the axis control" stack_control model
let fixed_width_of label model = (layout_of label fixed_box model).Style.width
let fixed_height_of label model = (layout_of label fixed_box model).Style.height

(* The shape the whole section is about: one box that declares a size, one that
   declares it will give way, side by side in a container too small for both.
   Without this the browser spec could be measuring a box that declares nothing,
   and "the width equals the declared size" would be a statement about a default.
   The pair's own declared size is asserted with them, because the room the
   sibling has to give up is the difference between the two and a pair widened to
   fit both children would take all the pressure off. *)
let test_the_pair_pairs_a_fixed_box_with_a_flexible_one () =
  let model = after [] in
  let pair_layout = layout_of "the pair" pair model in
  Alcotest.check size "the pair declares the width the two children share"
    (declared (Style.Fixed 360.0))
    (shown pair_layout.Style.width);
  Alcotest.check size "and the height they share once the axis flips"
    (declared (Style.Fixed 140.0))
    (shown pair_layout.Style.height);
  Alcotest.check size
    "the fixed box declares a width on the across-the-page axis"
    (declared (Style.Fixed 120.0))
    (shown (fixed_width_of "the fixed box" model));
  Alcotest.check size "and a height on the down-the-page one"
    (declared (Style.Fixed 56.0))
    (shown (fixed_height_of "the fixed box" model));
  Alcotest.check size
    "the sibling declares it will take whatever room is left, which is what \
     makes the pair overconstrained on both axes at once"
    (declared Style.Fill)
    (shown (layout_of "the sibling" flexible_box model).Style.width);
  Alcotest.check size "on both axes" (declared Style.Fill)
    (shown (layout_of "the sibling" flexible_box model).Style.height)

(* The sibling's content, and the one property of it the browser spec depends on
   without being able to check. A token with a space or a hyphen in it has a
   break opportunity, so the sibling's minimum width collapses to a fragment and
   the fixture stops applying any pressure — while every geometry assertion stays
   green, because a Fixed box under no pressure also keeps its width. *)
let test_the_sibling_holds_an_unbreakable_token () =
  let model = after [] in
  let breakable c = Char.equal c ' ' || Char.equal c '-' in
  Alcotest.(check bool)
    "the token offers a line nowhere to break" false
    (String.exists breakable Sub.unbreakable_token);
  Alcotest.(check bool)
    "the token is long enough to be a demand rather than a word" true
    (String.length Sub.unbreakable_token >= 12);
  (* And the bound in the other direction, which the browser spec depends on just
     as hard and cannot explain if it breaks. With wrapping on, the sibling's
     minimum width is this token, and it has to fit the 240px the pair leaves
     beside the fixed box: that remainder is exactly what
     test/e2e/tests/kitchen-sink-fixed-size.spec.ts reads back as the sibling's
     width, so a token wider than it clamps the sibling at its own minimum and
     the assertion fails naming geometry rather than naming the token that caused
     it. This is the cheap red in front of that confusing one.

     Observed 2026-09-12, headless Chromium, at the 16px face the section
     inherits: the token renders 151.14px wide, a little over 9.4px a character.
     Twelve pixels a character is the assumed cap, chosen to leave room for a
     default face wider than that one, and it puts twenty characters inside
     240px. *)
  Alcotest.(check bool)
    "the token is short enough to fit the room left beside the fixed box once \
     its line may break, which is what the browser case measuring that \
     remainder needs in order to measure anything"
    true
    (String.length Sub.unbreakable_token <= 20);
  Alcotest.(check bool)
    "the sibling is the element that holds it" true
    (Option.is_some
       (find (By_text Sub.unbreakable_token)
          (node_at "the sibling" flexible_box model)));
  let sibling = text_content (node_at "the sibling" flexible_box model) in
  Alcotest.(check bool)
    "with breakable text around it, so switching the wrapping changes what the \
     sibling demands"
    true
    (String.length sibling > String.length Sub.unbreakable_token
    && String.exists breakable sibling)

(* The wrapping control reaches the sibling's text style. Both arms on the one
   fixture: the initial value alone would be satisfied by a section that hard-codes
   it and ignores the control, which is the whole failure this case exists for. *)
let test_the_wrap_control_reaches_the_sibling () =
  let unbroken = after [] in
  Alcotest.(check (option string))
    "the section starts with the sibling refusing to break its line"
    (Some "No_wrap")
    (sibling_wrapping "the initial sibling" unbroken);
  let broken = after [ flip_wrap unbroken ] in
  Alcotest.(check (option string))
    "and the control lets it break" (Some "Wrap")
    (sibling_wrapping "the sibling after the control" broken);
  let unbroken_again = after [ flip_wrap unbroken; flip_wrap broken ] in
  Alcotest.(check (option string))
    "and stop again, so the demand the fixture applies is the control's and \
     not a one-way latch"
    (Some "No_wrap")
    (sibling_wrapping "the sibling after the control twice" unbroken_again)

(* The axis control reaches the pair's own direction, and the fixed box's style
   does not move with it. That second half is the point: the box that has to keep
   its size is the one whose declaration never changed, so whatever protects it
   cannot be reading the box's own style.

   The direction is asserted as Some on both arms rather than left absent on one.
   A Box with no direction is laid out down the page by this backend even though
   CSS reads an absent flex-direction as across, so an absent direction would make
   the across-the-page arm silently the same as the other one. *)
let test_the_axis_control_reaches_the_pair () =
  let across = after [] in
  Alcotest.(check (option string))
    "the section starts with the pair across the page"
    (Some (direction_to_string Style.Row_dir))
    (Option.map direction_to_string
       (layout_of "the pair" pair across).Style.direction);
  let down = after [ flip_stack across ] in
  Alcotest.(check (option string))
    "and the control turns it down the page"
    (Some (direction_to_string Style.Column_dir))
    (Option.map direction_to_string
       (layout_of "the pair" pair down).Style.direction);
  Alcotest.check size
    "the fixed box still declares the width it declared across the page"
    (declared (Style.Fixed 120.0))
    (shown (fixed_width_of "the fixed box down" down));
  Alcotest.check size "and the height"
    (declared (Style.Fixed 56.0))
    (shown (fixed_height_of "the fixed box down" down))

(* The second fixture's precondition. Three columns declared wider in total than
   the row that holds them is what turns "the columns kept their widths" into a
   claim; a row widened to fit them would leave the browser assertion green and
   saying nothing. The row's width is read rather than assumed, and the sum is
   computed from the columns actually rendered, so removing a column reddens this
   too. *)
let fixed_width label selector model =
  match (layout_of label selector model).Style.width with
  | Some (Style.Fixed f) -> f
  | Some Style.Fill
  | Some Style.Hug
  | Some (Style.Fraction _)
  | None ->
      Alcotest.fail (label ^ ": declares no fixed width to overflow with")

let test_the_columns_are_declared_wider_than_their_row () =
  let model = after [] in
  let widths =
    List.init 3 (fun index ->
        fixed_width (Printf.sprintf "column %d" index) (column index) model)
  in
  List.iteri
    (fun index width ->
      Alcotest.(check (float 0.001))
        (Printf.sprintf "column %d declares the same width as its siblings"
           index)
        140.0 width;
      Alcotest.check size
        (Printf.sprintf
           "column %d declares a height too, off the row's main axis" index)
        (declared (Style.Fixed 40.0))
        (shown
           (layout_of (Printf.sprintf "column %d" index) (column index) model)
             .Style.height))
    widths;
  let row_width = fixed_width "the columns row" columns_row model in
  Alcotest.(check (float 0.001))
    "the row declares the width the columns have to fit into" 300.0 row_width;
  Alcotest.(check bool)
    "and the columns ask for more of it than there is, so keeping their widths \
     has to overflow the row"
    true
    (List.fold_left ( +. ) 0.0 widths > row_width)

let () =
  Alcotest.run "kitchen_sink_fixed_size_section"
    [
      ( "the pair",
        [
          Alcotest.test_case "a fixed box beside a flexible one" `Quick
            test_the_pair_pairs_a_fixed_box_with_a_flexible_one;
          Alcotest.test_case "the sibling holds an unbreakable token" `Quick
            test_the_sibling_holds_an_unbreakable_token;
        ] );
      ( "the controls",
        [
          Alcotest.test_case "the wrap control reaches the sibling" `Quick
            test_the_wrap_control_reaches_the_sibling;
          Alcotest.test_case "the axis control reaches the pair" `Quick
            test_the_axis_control_reaches_the_pair;
        ] );
      ( "the columns",
        [
          Alcotest.test_case "declared wider than their row" `Quick
            test_the_columns_are_declared_wider_than_their_row;
        ] );
    ]
