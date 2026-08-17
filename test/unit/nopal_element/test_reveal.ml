(* The scroll arithmetic behind a reveal request.

   Every fixture below is a container 300 units tall over 1000 units of content
   unless it says otherwise, so the scrollable range is 0 to 700 and a reader can
   check any expected offset by hand. Measurements share one origin: child_top is
   measured from the top of the content, not from the top of the visible area, so
   it stays put while the container scrolls.

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
        (Reveal.offset_for ~scroll_offset:satisfied_offset
           ~viewport_height:300.0 ~content_height:1000.0 ~child_top:400.0
           ~child_height:60.0 ~align);
      Alcotest.check offset
        (label ^ ": the same fixture one unit down must move the container")
        (Some (satisfied_offset +. 1.0))
        (Reveal.offset_for ~scroll_offset:satisfied_offset
           ~viewport_height:300.0 ~content_height:1000.0 ~child_top:401.0
           ~child_height:60.0 ~align))
    already_satisfied

(* ------------------------------------------------------------------ *)
(* Nearest in each direction                                            *)
(* ------------------------------------------------------------------ *)

(* The container is at the top; the child occupies 500 to 560 and the visible
   band is 0 to 300. The smallest move that shows the whole child puts its bottom
   edge on the fold, at 560 - 300. *)
let test_below_fold_nearest () =
  Alcotest.check offset "the child's bottom edge lands on the fold" (Some 260.0)
    (Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
       ~content_height:1000.0 ~child_top:500.0 ~child_height:60.0
       ~align:Reveal.Nearest)

(* The container is at 600; the child occupies 100 to 160, entirely above the
   visible band. The smallest move in the other direction puts its top edge on
   the top of the band. *)
let test_above_viewport_nearest () =
  Alcotest.check offset "the child's top edge lands on the top of the band"
    (Some 100.0)
    (Reveal.offset_for ~scroll_offset:600.0 ~viewport_height:300.0
       ~content_height:1000.0 ~child_top:100.0 ~child_height:60.0
       ~align:Reveal.Nearest)

(* ------------------------------------------------------------------ *)
(* Each named alignment lands the child where it says                   *)
(* ------------------------------------------------------------------ *)

(* Same fixture for all three: container at the top, child at 500 to 560. The
   expected offsets are asserted, and then the geometric claim each alignment
   makes is asserted from the returned offset, so a coincidentally-correct number
   cannot stand in for the property. *)
let landing_position align =
  match
    Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
      ~content_height:1000.0 ~child_top:500.0 ~child_height:60.0 ~align
  with
  | None ->
      Alcotest.failf "%s: expected an offset for a child below the fold"
        (align_label align)
  | Some o -> o

let test_start_center_end () =
  Alcotest.check offset "start" (Some 500.0)
    (Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
       ~content_height:1000.0 ~child_top:500.0 ~child_height:60.0
       ~align:Reveal.Start);
  Alcotest.check offset "center" (Some 380.0)
    (Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
       ~content_height:1000.0 ~child_top:500.0 ~child_height:60.0
       ~align:Reveal.Center);
  Alcotest.check offset "end" (Some 260.0)
    (Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
       ~content_height:1000.0 ~child_top:500.0 ~child_height:60.0
       ~align:Reveal.End_);
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
   formula. *)
let test_child_taller_than_viewport () =
  List.iter
    (fun align ->
      let label = align_label align in
      let result =
        Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
          ~content_height:2000.0 ~child_top:500.0 ~child_height:800.0 ~align
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
        (Reveal.offset_for ~scroll_offset:500.0 ~viewport_height:300.0
           ~content_height:1000.0 ~child_top:0.0 ~child_height:60.0 ~align))
    all_alignments;
  (* The very last child: start and centre both want to scroll past the end. *)
  List.iter
    (fun align ->
      Alcotest.check offset
        (align_label align ^ ": the last child clamps to the bottom")
        (Some 700.0)
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
           ~content_height:1000.0 ~child_top:940.0 ~child_height:60.0 ~align))
    all_alignments;
  (* Content shorter than the container: nothing can scroll, so a container
     already at rest must not move. *)
  List.iter
    (fun align ->
      Alcotest.check offset
        (align_label align ^ ": content that fits does not scroll")
        None
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
           ~content_height:200.0 ~child_top:100.0 ~child_height:60.0 ~align))
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
        (Reveal.offset_for ~scroll_offset:40.0 ~viewport_height:300.0
           ~content_height:200.0 ~child_top:100.0 ~child_height:60.0 ~align))
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
    (Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
       ~content_height:1000.0 ~child_top:500.0 ~child_height:60.0
       ~align:Reveal.Nearest);
  List.iter
    (fun (label, v) ->
      Alcotest.check offset
        ("scroll_offset = " ^ label)
        None
        (Reveal.offset_for ~scroll_offset:v ~viewport_height:300.0
           ~content_height:1000.0 ~child_top:500.0 ~child_height:60.0
           ~align:Reveal.Nearest);
      Alcotest.check offset
        ("viewport_height = " ^ label)
        None
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:v
           ~content_height:1000.0 ~child_top:500.0 ~child_height:60.0
           ~align:Reveal.Nearest);
      Alcotest.check offset
        ("content_height = " ^ label)
        None
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
           ~content_height:v ~child_top:500.0 ~child_height:60.0
           ~align:Reveal.Nearest);
      Alcotest.check offset ("child_top = " ^ label) None
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
           ~content_height:1000.0 ~child_top:v ~child_height:60.0
           ~align:Reveal.Nearest);
      Alcotest.check offset
        ("child_height = " ^ label)
        None
        (Reveal.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
           ~content_height:1000.0 ~child_top:500.0 ~child_height:v
           ~align:Reveal.Nearest))
    non_finite_values

(* ------------------------------------------------------------------ *)
(* The property no single fixture can pin                               *)
(* ------------------------------------------------------------------ *)

type geometry = {
  scroll_offset : float;
  viewport_height : float;
  content_height : float;
  child_top : float;
  child_height : float;
  align : Reveal.align;
}

let geometry_to_string g =
  Printf.sprintf
    "scroll_offset=%g viewport_height=%g content_height=%g child_top=%g \
     child_height=%g align=%s"
    g.scroll_offset g.viewport_height g.content_height g.child_top
    g.child_height (align_label g.align)

(* Whole numbers, so every expected value below is exact in binary and the
   tolerance guards nothing but the halving that a centre alignment performs.
   The content is built as space above the child, the child, and space below it,
   which is what keeps the child inside the content for every draw — the
   invariant the property depends on and the reason no shrinker is attached: a
   component-wise shrinker moves the four numbers independently and breaks it. *)
let geometry_gen =
  let open QCheck.Gen in
  int_range 1 500 >>= fun viewport ->
  int_range 1 600 >>= fun child_height ->
  int_range 0 1500 >>= fun leading ->
  int_range 0 1500 >>= fun trailing ->
  let content = leading + child_height + trailing in
  let max_scroll = Int.max 0 (content - viewport) in
  int_range 0 max_scroll >>= fun scroll ->
  oneof_list all_alignments >>= fun align ->
  return
    {
      scroll_offset = float_of_int scroll;
      viewport_height = float_of_int viewport;
      content_height = float_of_int content;
      child_top = float_of_int leading;
      child_height = float_of_int child_height;
      align;
    }

let arb_geometry = QCheck.make ~print:geometry_to_string geometry_gen

(* Two claims at once, because either alone is satisfiable by a cheat: an
   implementation returning None for everything stays in range, and one
   returning the child's top for everything reveals the child but leaves the
   range. Applying the result means taking the offset when there is one and
   leaving the container where it is when there is not, which is the whole
   contract a caller acts on. *)
let test_property_offset_within_range =
  QCheck.Test.make ~count:2000 ~name:"property_offset_within_range" arb_geometry
    (fun g ->
      let result =
        Reveal.offset_for ~scroll_offset:g.scroll_offset
          ~viewport_height:g.viewport_height ~content_height:g.content_height
          ~child_top:g.child_top ~child_height:g.child_height ~align:g.align
      in
      let final = Option.value result ~default:g.scroll_offset in
      let max_scroll = Float.max 0.0 (g.content_height -. g.viewport_height) in
      let in_range =
        (not (Float.is_nan final))
        && Float.compare final 0.0 >= 0
        && Float.compare final max_scroll <= 0
      in
      let visible_top = Float.max g.child_top final in
      let visible_bottom =
        Float.min (g.child_top +. g.child_height) (final +. g.viewport_height)
      in
      let visible_extent = Float.max 0.0 (visible_bottom -. visible_top) in
      let expected_extent = Float.min g.child_height g.viewport_height in
      in_range && close ~epsilon:1e-9 visible_extent expected_extent)

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
