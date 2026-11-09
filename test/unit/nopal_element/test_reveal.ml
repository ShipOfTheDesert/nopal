(* The scroll arithmetic behind a reveal request.

   The arithmetic names no axis, so one call answers for either. Every fixture
   below is told as a vertical one — a container 300 units tall over 1000 units
   of content — unless it says otherwise, so the scrollable range is 0 to 700 and
   a reader can check any expected offset by hand. The horizontal fixtures say so
   and use a narrower geometry of their own. Measurements share one origin:
   child_start is measured from the start edge of the content, not from the start
   edge of the visible area, so it stays put while the container scrolls.

   Alignments are carried in lists paired with a label rather than passed to
   Reveal.align_token, because align_token is itself under test at the bottom of
   this file: a labeller built from it could not produce a wrong name, and a
   failure message naming the wrong alignment is worse than no name at all. *)

module Reveal = Nopal_element.Reveal

let align_label align =
  match align with
  | Reveal.Nearest -> "nearest"
  | Reveal.Start -> "start"
  | Reveal.Center -> "center"
  | Reveal.End_ -> "end"

let all_alignments =
  [ Reveal.Nearest; Reveal.Start; Reveal.Center; Reveal.End_ ]

(* NaN-aware on both sides: a bare tolerance test passes for NaN against
   anything, because every comparison with NaN is false. *)
let close ~epsilon a b =
  (not (Float.is_nan a))
  && (not (Float.is_nan b))
  && Float.compare (Float.abs (a -. b)) epsilon <= 0

let offset = Alcotest.option (Alcotest.float 1e-9)

(* ------------------------------------------------------------------ *)
(* A child already sitting where its alignment asks                     *)
(* ------------------------------------------------------------------ *)

(* One fixture, one scroll offset per alignment: the offset at which that
   alignment is already satisfied. Each absence assertion is paired with the same
   fixture shifted one unit down the content, which must produce an offset one
   unit larger — without that arm the whole case would still pass against an
   implementation that never returns anything. *)
let already_satisfied =
  [
    (* The child's bottom edge is flush with the visible bottom, so it is fully
       visible and nearest has nothing to do; one unit down and it is past the
       fold. *)
    (Reveal.Nearest, 160.0);
    (Reveal.Start, 400.0);
    (Reveal.Center, 280.0);
    (Reveal.End_, 160.0);
  ]

let test_visible_child_no_offset () =
  List.iter
    (fun (align, satisfied_offset) ->
      let label = align_label align in
      Alcotest.check offset
        (label ^ ": already satisfied, so the container must not move")
        None
        (Reveal.offset_for ~scroll_offset:satisfied_offset ~viewport:300.0
           ~content:1000.0 ~child_start:400.0 ~child_extent:60.0 ~align);
      Alcotest.check offset
        (label ^ ": the same fixture one unit down must move the container")
        (Some (satisfied_offset +. 1.0))
        (Reveal.offset_for ~scroll_offset:satisfied_offset ~viewport:300.0
           ~content:1000.0 ~child_start:401.0 ~child_extent:60.0 ~align))
    already_satisfied

(* ------------------------------------------------------------------ *)
(* Nearest in each direction                                            *)
(* ------------------------------------------------------------------ *)

(* The container is at the top; the child occupies 500 to 560 and the visible
   band is 0 to 300. The smallest move that shows the whole child puts its bottom
   edge on the fold, at 560 - 300. *)
let test_below_fold_nearest () =
  Alcotest.check offset "the child's bottom edge lands on the fold" (Some 260.0)
    (Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:1000.0
       ~child_start:500.0 ~child_extent:60.0 ~align:Reveal.Nearest)

(* The container is at 600; the child occupies 100 to 160, entirely above the
   visible band. The smallest move in the other direction puts its top edge on
   the top of the band. *)
let test_above_viewport_nearest () =
  Alcotest.check offset "the child's top edge lands on the top of the band"
    (Some 100.0)
    (Reveal.offset_for ~scroll_offset:600.0 ~viewport:300.0 ~content:1000.0
       ~child_start:100.0 ~child_extent:60.0 ~align:Reveal.Nearest)

(* ------------------------------------------------------------------ *)
(* Each named alignment lands the child where it says                   *)
(* ------------------------------------------------------------------ *)

(* Same fixture for all three: container at the top, child at 500 to 560. The
   expected offsets are asserted, and then the geometric claim each alignment
   makes is asserted from the returned offset, so a coincidentally-correct number
   cannot stand in for the property. *)
let landing_position align =
  match
    Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:1000.0
      ~child_start:500.0 ~child_extent:60.0 ~align
  with
  | None ->
      Alcotest.failf "%s: expected an offset for a child below the fold"
        (align_label align)
  | Some o -> o

let test_start_center_end () =
  Alcotest.check offset "start" (Some 500.0)
    (Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:1000.0
       ~child_start:500.0 ~child_extent:60.0 ~align:Reveal.Start);
  Alcotest.check offset "center" (Some 380.0)
    (Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:1000.0
       ~child_start:500.0 ~child_extent:60.0 ~align:Reveal.Center);
  Alcotest.check offset "end" (Some 260.0)
    (Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:1000.0
       ~child_start:500.0 ~child_extent:60.0 ~align:Reveal.End_);
  let start_offset = landing_position Reveal.Start in
  Alcotest.check Alcotest.bool "start puts the child's top on the band's top"
    true
    (close ~epsilon:1e-9 (500.0 -. start_offset) 0.0);
  let center_offset = landing_position Reveal.Center in
  Alcotest.check Alcotest.bool
    "center puts the child's centre on the band's centre" true
    (close ~epsilon:1e-9
       (500.0 +. (60.0 /. 2.0))
       (center_offset +. (300.0 /. 2.0)));
  let end_offset = landing_position Reveal.End_ in
  Alcotest.check Alcotest.bool
    "end puts the child's bottom on the band's bottom" true
    (close ~epsilon:1e-9 (500.0 +. 60.0) (end_offset +. 300.0))

(* ------------------------------------------------------------------ *)
(* A child taller than the container                                    *)
(* ------------------------------------------------------------------ *)

(* No alignment can show all 800 units of the child in a 300-unit band, so every
   alignment shows its beginning and none scrolls past it. A centre or end
   alignment computed naively would land at 750 or 1000 respectively, both past
   the child's top edge, so the assertion separates the fallback from the
   formula. The container starts at the top, where the child does not yet cover
   the band, so nearest takes the same fallback as the named alignments; the
   covering cases below are the ones where it does not. *)
let test_child_taller_than_viewport () =
  List.iter
    (fun align ->
      let label = align_label align in
      let result =
        Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:2000.0
          ~child_start:500.0 ~child_extent:800.0 ~align
      in
      Alcotest.check offset
        (label ^ ": lands on the child's top edge")
        (Some 500.0) result;
      match result with
      | None ->
          Alcotest.failf "%s: expected an offset for an oversized child" label
      | Some o ->
          Alcotest.check Alcotest.bool
            (label ^ ": does not scroll past the child's top edge")
            true
            (Float.compare o 500.0 <= 0))
    all_alignments

(* The same 800-unit child at 500 to 1300 in 2000 units of content, with the
   300-unit band scrolled to 600 to 900: the child fills the band from edge to
   edge. Nearest asks only that the child be seen, and it already fills
   everything there is to see, so a reader partway down a long item keeps their
   place. The affirmative arm is the same fixture under start, which asks for an
   edge rather than for visibility and still moves to it — without it, an
   implementation that never answers would pass. *)
let test_covering_oversized_child_nearest_no_offset_y () =
  Alcotest.check offset "nearest leaves a child that fills the band alone" None
    (Reveal.offset_for ~scroll_offset:600.0 ~viewport:300.0 ~content:2000.0
       ~child_start:500.0 ~child_extent:800.0 ~align:Reveal.Nearest);
  Alcotest.check offset "start on the same fixture still moves to the top edge"
    (Some 500.0)
    (Reveal.offset_for ~scroll_offset:600.0 ~viewport:300.0 ~content:2000.0
       ~child_start:500.0 ~child_extent:800.0 ~align:Reveal.Start)

(* The same numbers told sideways: a row 800 units wide, starting 500 units into
   2000 units of sideways content, seen through a band 300 units wide that the
   reader has scrolled 600 units to the right. A full-width row in a vertical
   list is this case, and resetting the sideways position on every reveal of it
   is the defect the rule exists to prevent.

   The band's end edge flush with the row's end edge, at 1000, still counts as
   covered; one unit further, at 1001, the band shows content past the row and
   nearest falls back to the row's start edge. Those two arms pin the boundary
   as inclusive, which a strict comparison would get wrong in one direction. *)
let test_covering_oversized_child_nearest_no_offset_x () =
  Alcotest.check offset "nearest leaves a row that fills the band alone" None
    (Reveal.offset_for ~scroll_offset:600.0 ~viewport:300.0 ~content:2000.0
       ~child_start:500.0 ~child_extent:800.0 ~align:Reveal.Nearest);
  Alcotest.check offset "the row's end edge flush with the band's is covered"
    None
    (Reveal.offset_for ~scroll_offset:1000.0 ~viewport:300.0 ~content:2000.0
       ~child_start:500.0 ~child_extent:800.0 ~align:Reveal.Nearest);
  Alcotest.check offset "one unit past the row's end edge is not covered"
    (Some 500.0)
    (Reveal.offset_for ~scroll_offset:1001.0 ~viewport:300.0 ~content:2000.0
       ~child_start:500.0 ~child_extent:800.0 ~align:Reveal.Nearest)

(* A browser measures a child's edges as fractions and the band as rounded
   integers, so a full-width row scrolled to the far end of its list can end at
   999.6 while the band ends at 1000. That row still covers the band and keeps
   the sideways position; a row ending 1.5 short does not, and moves to its
   start edge. Without the second arm an implementation that always answers
   [None] would pass. *)
let test_covering_tolerates_fractional_edges () =
  Alcotest.check offset "a row ending 0.4 short of the band's end is covered"
    None
    (Reveal.offset_for ~scroll_offset:700.0 ~viewport:300.0 ~content:2000.0
       ~child_start:200.0 ~child_extent:799.6 ~align:Reveal.Nearest);
  Alcotest.check offset "a row ending 1.5 short of the band's end is not"
    (Some 200.0)
    (Reveal.offset_for ~scroll_offset:700.0 ~viewport:300.0 ~content:2000.0
       ~child_start:200.0 ~child_extent:798.5 ~align:Reveal.Nearest)

(* The named alignments ask for an edge, not for visibility, so a child that
   already fills the band is still moved to its start edge under each of them —
   the covering rule belongs to nearest alone. *)
let test_oversized_child_named_alignments_keep_start_edge () =
  List.iter
    (fun align ->
      Alcotest.check offset
        (align_label align ^ ": a covering child still moves to its start edge")
        (Some 500.0)
        (Reveal.offset_for ~scroll_offset:600.0 ~viewport:300.0 ~content:2000.0
           ~child_start:500.0 ~child_extent:800.0 ~align))
    [ Reveal.Start; Reveal.Center; Reveal.End_ ]

(* An oversized child that is only partly in the band does not cover it, so
   nearest keeps the start-edge fallback from either side: with the band at 300
   to 600 the child starts inside it and runs past its end, and with the band at
   1100 to 1400 the child ends inside it, leaving the band's tail empty. *)
let test_oversized_child_nearest_not_covering_moves_to_start () =
  Alcotest.check offset "child starting inside the band moves to its start edge"
    (Some 500.0)
    (Reveal.offset_for ~scroll_offset:300.0 ~viewport:300.0 ~content:2000.0
       ~child_start:500.0 ~child_extent:800.0 ~align:Reveal.Nearest);
  Alcotest.check offset "child ending inside the band moves to its start edge"
    (Some 500.0)
    (Reveal.offset_for ~scroll_offset:1100.0 ~viewport:300.0 ~content:2000.0
       ~child_start:500.0 ~child_extent:800.0 ~align:Reveal.Nearest)

(* ------------------------------------------------------------------ *)
(* The same arithmetic along a horizontal axis                          *)
(* ------------------------------------------------------------------ *)

(* A row of tabs 80 units wide in a container 320 units wide over 1000 units of
   sideways content, so the scrollable range is 0 to 680. Every value is worked
   by hand from those three numbers:
   - a tab at 600 to 680 with the row at rest is past the end edge, and nearest
     brings its end edge to the band's end edge at 680 - 320 = 360;
   - a tab at 100 to 180 with the row scrolled to 500 is past the start edge, and
     nearest brings its start edge to the band's start edge at 100;
   - a tab at 600 to 680 with the row scrolled to 500 sits inside 500 to 820, so
     nearest leaves it alone;
   - from rest, start puts the tab at 600 to 680 at 600, center at
     600 + (80 - 320) / 2 = 480, and end at 360;
   - the last tab, at 920 to 1000, under start would ask for 920 and is clamped
     to the end of the range at 680. *)
let test_horizontal_mirror_per_alignment () =
  let tab ~scroll_offset ~child_start ~align =
    Reveal.offset_for ~scroll_offset ~viewport:320.0 ~content:1000.0
      ~child_start ~child_extent:80.0 ~align
  in
  Alcotest.check offset "nearest, tab past the end edge" (Some 360.0)
    (tab ~scroll_offset:0.0 ~child_start:600.0 ~align:Reveal.Nearest);
  Alcotest.check offset "nearest, tab past the start edge" (Some 100.0)
    (tab ~scroll_offset:500.0 ~child_start:100.0 ~align:Reveal.Nearest);
  Alcotest.check offset "nearest, tab already fully visible" None
    (tab ~scroll_offset:500.0 ~child_start:600.0 ~align:Reveal.Nearest);
  Alcotest.check offset "start" (Some 600.0)
    (tab ~scroll_offset:0.0 ~child_start:600.0 ~align:Reveal.Start);
  Alcotest.check offset "center" (Some 480.0)
    (tab ~scroll_offset:0.0 ~child_start:600.0 ~align:Reveal.Center);
  Alcotest.check offset "end" (Some 360.0)
    (tab ~scroll_offset:0.0 ~child_start:600.0 ~align:Reveal.End_);
  Alcotest.check offset "start, the last tab clamps to the end of the range"
    (Some 680.0)
    (tab ~scroll_offset:0.0 ~child_start:920.0 ~align:Reveal.Start)

(* A row whose tabs exactly fill its 320-unit container has nowhere to scroll,
   so no alignment moves it, wherever the tab sits. The affirmative arm widens
   the content by one unit and puts the last tab at its end: every alignment now
   asks for the one offset the range gained, so the absence above is the
   content fitting and not the fixture failing to reach the arithmetic. *)
let test_non_overflowing_axis_no_offset () =
  List.iter
    (fun align ->
      let label = align_label align in
      List.iter
        (fun child_start ->
          Alcotest.check offset
            (Printf.sprintf "%s: tab at %g in content that fits" label
               child_start)
            None
            (Reveal.offset_for ~scroll_offset:0.0 ~viewport:320.0 ~content:320.0
               ~child_start ~child_extent:80.0 ~align))
        [ 0.0; 120.0; 240.0 ];
      Alcotest.check offset
        (label ^ ": one unit of overflow reveals the last tab")
        (Some 1.0)
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport:320.0 ~content:321.0
           ~child_start:241.0 ~child_extent:80.0 ~align))
    all_alignments

(* ------------------------------------------------------------------ *)
(* Clamping to what the container can actually take                     *)
(* ------------------------------------------------------------------ *)

let test_clamps_to_scrollable_range () =
  (* The very first child: centre and end both want a negative offset. *)
  List.iter
    (fun align ->
      Alcotest.check offset
        (align_label align ^ ": the first child clamps to the top")
        (Some 0.0)
        (Reveal.offset_for ~scroll_offset:500.0 ~viewport:300.0 ~content:1000.0
           ~child_start:0.0 ~child_extent:60.0 ~align))
    all_alignments;
  (* The very last child: start and centre both want to scroll past the end. *)
  List.iter
    (fun align ->
      Alcotest.check offset
        (align_label align ^ ": the last child clamps to the bottom")
        (Some 700.0)
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:1000.0
           ~child_start:940.0 ~child_extent:60.0 ~align))
    all_alignments;
  (* Content shorter than the container: nothing can scroll, so a container
     already at rest must not move. *)
  List.iter
    (fun align ->
      Alcotest.check offset
        (align_label align ^ ": content that fits does not scroll")
        None
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:200.0
           ~child_start:100.0 ~child_extent:60.0 ~align))
    all_alignments;
  (* The affirmative arm for the case above: the same unscrollable container
     holding an offset outside its own range is corrected back into it, so the
     absence assertion cannot be passing because the code path was never
     reached. *)
  List.iter
    (fun align ->
      Alcotest.check offset
        (align_label align
        ^ ": an out-of-range offset on that container is corrected")
        (Some 0.0)
        (Reveal.offset_for ~scroll_offset:40.0 ~viewport:300.0 ~content:200.0
           ~child_start:100.0 ~child_extent:60.0 ~align))
    all_alignments

(* ------------------------------------------------------------------ *)
(* Measurements that are not numbers                                    *)
(* ------------------------------------------------------------------ *)

(* A backend that fails to measure hands back NaN or an infinity rather than
   raising, and an unguarded formula turns either into a poisoned scroll write.
   The base fixture is asserted first so each substitution below is demonstrably
   the reason its arm yields nothing. *)
let non_finite_values =
  [
    ("nan", Float.nan);
    ("infinity", Float.infinity);
    ("neg_infinity", Float.neg_infinity);
  ]

let test_non_finite_measurement_no_offset () =
  Alcotest.check offset "the base fixture does produce an offset" (Some 260.0)
    (Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:1000.0
       ~child_start:500.0 ~child_extent:60.0 ~align:Reveal.Nearest);
  List.iter
    (fun (label, v) ->
      Alcotest.check offset
        ("scroll_offset = " ^ label)
        None
        (Reveal.offset_for ~scroll_offset:v ~viewport:300.0 ~content:1000.0
           ~child_start:500.0 ~child_extent:60.0 ~align:Reveal.Nearest);
      Alcotest.check offset ("viewport = " ^ label) None
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport:v ~content:1000.0
           ~child_start:500.0 ~child_extent:60.0 ~align:Reveal.Nearest);
      Alcotest.check offset ("content = " ^ label) None
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:v
           ~child_start:500.0 ~child_extent:60.0 ~align:Reveal.Nearest);
      Alcotest.check offset ("child_start = " ^ label) None
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:1000.0
           ~child_start:v ~child_extent:60.0 ~align:Reveal.Nearest);
      Alcotest.check offset
        ("child_extent = " ^ label)
        None
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport:300.0 ~content:1000.0
           ~child_start:500.0 ~child_extent:v ~align:Reveal.Nearest))
    non_finite_values

(* ------------------------------------------------------------------ *)
(* The property no single fixture can pin                               *)
(* ------------------------------------------------------------------ *)

type geometry = {
  scroll_offset : float;
  viewport : float;
  content : float;
  child_start : float;
  child_extent : float;
  align : Reveal.align;
}

let geometry_to_string g =
  Printf.sprintf
    "scroll_offset=%g viewport=%g content=%g child_start=%g child_extent=%g \
     align=%s"
    g.scroll_offset g.viewport g.content g.child_start g.child_extent
    (align_label g.align)

let geometry_of_ints ~scroll ~viewport ~leading ~child_extent ~trailing ~align =
  {
    scroll_offset = float_of_int scroll;
    viewport = float_of_int viewport;
    content = float_of_int (leading + child_extent + trailing);
    child_start = float_of_int leading;
    child_extent = float_of_int child_extent;
    align;
  }

(* Whole numbers, so every expected value below is exact in binary and the
   tolerance guards nothing but the halving that a centre alignment performs.
   The content is built as space before the child, the child, and space after
   it, which is what keeps the child inside the content for every draw — the
   invariant the property depends on and the reason no shrinker is attached: a
   component-wise shrinker moves the four numbers independently and breaks it.
   Nothing here names an axis: a draw is a vertical container or a horizontal
   one equally. *)
let any_geometry_gen =
  let open QCheck.Gen in
  int_range 1 500 >>= fun viewport ->
  int_range 1 600 >>= fun child_extent ->
  int_range 0 1500 >>= fun leading ->
  int_range 0 1500 >>= fun trailing ->
  let max_scroll = Int.max 0 (leading + child_extent + trailing - viewport) in
  int_range 0 max_scroll >>= fun scroll ->
  oneof_list all_alignments >>= fun align ->
  return
    (geometry_of_ints ~scroll ~viewport ~leading ~child_extent ~trailing ~align)

(* Content no longer than the container, so the axis does not overflow and the
   only offset the container can hold is 0. The general generator above reaches
   this shape only when both spacers happen to draw small, which is rare enough
   to leave the claim it supports thinly tested; drawing it on purpose makes it
   a quarter of every run. *)
let fitting_geometry_gen =
  let open QCheck.Gen in
  int_range 1 500 >>= fun viewport ->
  int_range 1 viewport >>= fun child_extent ->
  int_range 0 (viewport - child_extent) >>= fun leading ->
  int_range 0 (viewport - child_extent - leading) >>= fun trailing ->
  oneof_list all_alignments >>= fun align ->
  int_range (-100) 700 >>= fun scroll ->
  return
    (geometry_of_ints ~scroll ~viewport ~leading ~child_extent ~trailing ~align)

let geometry_gen =
  QCheck.Gen.oneof_weighted [ (3, any_geometry_gen); (1, fitting_geometry_gen) ]

let arb_geometry = QCheck.make ~print:geometry_to_string geometry_gen

(* Three claims at once, because each alone is satisfiable by a cheat: an
   implementation returning None for everything stays in range and leaves a
   fitting axis alone, and one returning the child's start edge for everything
   reveals the child but leaves the range. Applying the result means taking the
   offset when there is one and leaving the container where it is when there is
   not, which is the whole contract a caller acts on. The third claim is the
   untouched axis: content that does not overflow answers None when the offset
   is already 0 and Some 0. from any other, out-of-range included, so a reveal never writes to an axis it has no
   reason to move. *)
let test_property_offset_within_range =
  QCheck.Test.make ~count:2000 ~name:"property_offset_within_range" arb_geometry
    (fun g ->
      let result =
        Reveal.offset_for ~scroll_offset:g.scroll_offset ~viewport:g.viewport
          ~content:g.content ~child_start:g.child_start
          ~child_extent:g.child_extent ~align:g.align
      in
      let final = Option.value result ~default:g.scroll_offset in
      let max_scroll = Float.max 0.0 (g.content -. g.viewport) in
      let in_range =
        (not (Float.is_nan final))
        && Float.compare final 0.0 >= 0
        && Float.compare final max_scroll <= 0
      in
      let visible_start = Float.max g.child_start final in
      let visible_end =
        Float.min (g.child_start +. g.child_extent) (final +. g.viewport)
      in
      let visible_extent = Float.max 0.0 (visible_end -. visible_start) in
      let expected_extent = Float.min g.child_extent g.viewport in
      let untouched_when_fitting =
        Float.compare g.content g.viewport > 0
        || Option.equal Float.equal result
             (if Float.equal g.scroll_offset 0.0 then None else Some 0.0)
      in
      in_range
      && close ~epsilon:1e-9 visible_extent expected_extent
      && untouched_when_fitting)

(* ------------------------------------------------------------------ *)
(* The declaration itself, and when it must be acted on                 *)
(* ------------------------------------------------------------------ *)

(* Thunks, not values. Two calls give two distinct heap blocks whose fields are
   equal, and the key is concatenated rather than written as one literal so the
   two keys are distinct blocks too — which is what a view rebuilding its output
   every frame produces. Binding one shared value instead would let an
   implementation comparing with == pass every case below vacuously. *)
let alpha_start () = Reveal.start ("al" ^ "pha")
let alpha_center () = Reveal.center ("al" ^ "pha")
let beta_start () = Reveal.start ("be" ^ "ta")

(* The whole edge-trigger policy is one total function over two options, so the
   whole policy is one table. Three rows expect no reveal and three expect one,
   built from the same declarations, so neither a predicate that always answers
   true nor one that always answers false survives. *)
let should_reveal_cases =
  [
    ("no declaration on either pass", None, None, false);
    ("a container created with a declaration", None, Some (alpha_start ()), true);
    ("the declaration withdrawn", Some (alpha_start ()), None, false);
    ( "the same declaration rebuilt by a fresh view call",
      Some (alpha_start ()),
      Some (alpha_start ()),
      false );
    ("the key changed", Some (alpha_start ()), Some (beta_start ()), true);
    ( "the alignment changed",
      Some (alpha_start ()),
      Some (alpha_center ()),
      true );
  ]

let test_should_reveal_transitions () =
  List.iter
    (fun (label, previous, next, expected) ->
      Alcotest.check Alcotest.bool label expected
        (Reveal.should_reveal ~previous ~next))
    should_reveal_cases

let test_equal_key_and_align () =
  Alcotest.check Alcotest.bool
    "a rebuilt declaration equals the one it replaces" true
    (Reveal.equal (alpha_start ()) (alpha_start ()));
  Alcotest.check Alcotest.bool "a different key is not equal" false
    (Reveal.equal (alpha_start ()) (beta_start ()));
  Alcotest.check Alcotest.bool "a different alignment is not equal" false
    (Reveal.equal (alpha_start ()) (alpha_center ()));
  (* All sixteen alignment pairs on one key, so the alignment cannot be compared
     for one constructor and ignored for the other three. *)
  List.iteri
    (fun i a ->
      List.iteri
        (fun j b ->
          Alcotest.check Alcotest.bool
            (Printf.sprintf "%s against %s" (align_label a) (align_label b))
            (Int.equal i j)
            (Reveal.equal
               { Reveal.key = "row"; align = a }
               { Reveal.key = "row"; align = b }))
        all_alignments)
    all_alignments

(* The exact spellings are pinned, not only their distinctness: a token function
   that swapped two alignments would keep four distinct tokens and project every
   scroll node with the wrong one. *)
let expected_tokens =
  [
    (Reveal.Nearest, "nearest");
    (Reveal.Start, "start");
    (Reveal.Center, "center");
    (Reveal.End_, "end");
  ]

let test_align_token_distinct () =
  List.iter
    (fun (align, token) ->
      Alcotest.check Alcotest.string
        (align_label align ^ ": token")
        token (Reveal.align_token align))
    expected_tokens;
  let tokens = List.map Reveal.align_token all_alignments in
  Alcotest.check Alcotest.int "one token per alignment, all distinct"
    (List.length all_alignments)
    (List.length (List.sort_uniq String.compare tokens))

let () =
  (* Fixed seed: a counterexample must reproduce across runs, which it does not
     if qcheck-alcotest seeds from the clock. *)
  let rand = Random.State.make [| 0x0129_0001 |] in
  Alcotest.run "nopal_element_reveal"
    [
      ( "offset_for",
        [
          Alcotest.test_case "visible_child_no_offset" `Quick
            test_visible_child_no_offset;
          Alcotest.test_case "below_fold_nearest" `Quick test_below_fold_nearest;
          Alcotest.test_case "above_viewport_nearest" `Quick
            test_above_viewport_nearest;
          Alcotest.test_case "start_center_end" `Quick test_start_center_end;
          Alcotest.test_case "child_taller_than_viewport" `Quick
            test_child_taller_than_viewport;
          Alcotest.test_case "covering_oversized_child_nearest_no_offset_y"
            `Quick test_covering_oversized_child_nearest_no_offset_y;
          Alcotest.test_case "covering_oversized_child_nearest_no_offset_x"
            `Quick test_covering_oversized_child_nearest_no_offset_x;
          Alcotest.test_case "covering_tolerates_fractional_edges" `Quick
            test_covering_tolerates_fractional_edges;
          Alcotest.test_case "oversized_child_named_alignments_keep_start_edge"
            `Quick test_oversized_child_named_alignments_keep_start_edge;
          Alcotest.test_case
            "oversized_child_nearest_not_covering_moves_to_start" `Quick
            test_oversized_child_nearest_not_covering_moves_to_start;
          Alcotest.test_case "horizontal_mirror_per_alignment" `Quick
            test_horizontal_mirror_per_alignment;
          Alcotest.test_case "non_overflowing_axis_no_offset" `Quick
            test_non_overflowing_axis_no_offset;
          Alcotest.test_case "clamps_to_scrollable_range" `Quick
            test_clamps_to_scrollable_range;
          Alcotest.test_case "non_finite_measurement_no_offset" `Quick
            test_non_finite_measurement_no_offset;
        ]
        @ List.map
            (QCheck_alcotest.to_alcotest ~rand ~speed_level:`Quick)
            [ test_property_offset_within_range ] );
      ( "should_reveal",
        [
          Alcotest.test_case "should_reveal_transitions" `Quick
            test_should_reveal_transitions;
        ] );
      ( "value",
        [
          Alcotest.test_case "equal_key_and_align" `Quick
            test_equal_key_and_align;
          Alcotest.test_case "align_token_distinct" `Quick
            test_align_token_distinct;
        ] );
    ]
