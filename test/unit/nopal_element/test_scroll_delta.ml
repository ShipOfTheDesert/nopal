(* The scroll arithmetic behind a relative-movement request.

   Every fixture below is a container 300 units tall over 1000 units of content
   unless it says otherwise, so the scrollable range is 0 to 700 and a reader can
   check any expected offset by hand. The three measurements share one origin,
   the top of the container's scrollable content, and a delta of 1.0 means one
   whole visible height toward the end.

   Deltas are drawn from halves throughout, here and in the generator below, so
   every product of a delta and a whole viewport height is exact in binary and
   the tolerance below guards nothing that the arithmetic itself introduces. *)

module Scroll_delta = Nopal_element.Scroll_delta

(* NaN-aware on both sides: a bare tolerance test passes for NaN against
   anything, because every comparison with NaN is false. *)
let close ~epsilon a b =
  (not (Float.is_nan a))
  && (not (Float.is_nan b))
  && Float.compare (Float.abs (a -. b)) epsilon <= 0

let offset = Alcotest.option (Alcotest.float 1e-9)

(* The standard container: 300 visible over 1000 of content, so 0 to 700. *)
let on_standard ~scroll_offset delta =
  Scroll_delta.offset_for ~scroll_offset ~viewport_height:300.0
    ~content_height:1000.0
    (Scroll_delta.viewports delta)

(* ------------------------------------------------------------------ *)
(* The requested fraction of the container's own visible height         *)
(* ------------------------------------------------------------------ *)

let test_moves_by_the_requested_fraction () =
  Alcotest.check offset "half a visible height from the top" (Some 150.0)
    (on_standard ~scroll_offset:0.0 0.5);
  Alcotest.check offset "a whole visible height from the top" (Some 300.0)
    (on_standard ~scroll_offset:0.0 1.0);
  Alcotest.check offset "half a visible height from part way down" (Some 250.0)
    (on_standard ~scroll_offset:100.0 0.5);
  (* The fraction is of the container's own height, not of its content: the
     same delta against a container half as tall must move half as far. *)
  Alcotest.check offset "the fraction follows the visible height" (Some 75.0)
    (Scroll_delta.offset_for ~scroll_offset:0.0 ~viewport_height:150.0
       ~content_height:1000.0
       (Scroll_delta.viewports 0.5))

(* ------------------------------------------------------------------ *)
(* Clamping to what the container can actually take                     *)
(* ------------------------------------------------------------------ *)

(* Both fixtures would land outside the scrollable range without the clamp —
   at 900 and at -200 respectively — so each expectation separates the clamp
   from the formula rather than merely agreeing with it. *)
let test_clamps_at_the_end () =
  Alcotest.check offset "past the end lands on the last reachable offset"
    (Some 700.0)
    (on_standard ~scroll_offset:600.0 1.0);
  Alcotest.check offset "past the start lands on the first reachable offset"
    (Some 0.0)
    (on_standard ~scroll_offset:100.0 (-1.0))

(* ------------------------------------------------------------------ *)
(* Nothing left to give                                                 *)
(* ------------------------------------------------------------------ *)

(* Content well over the visible height and a non-zero delta in both cases, so
   neither absence is the absence of a container that could not have moved. The
   affirmative arm on each fixture is the same container asked to move the other
   way, which does produce an offset. *)
let test_none_when_already_at_the_end () =
  Alcotest.check offset "a further move at the end asks for nothing" None
    (on_standard ~scroll_offset:700.0 0.5);
  Alcotest.check offset "the same fixture asked to move back does move"
    (Some 550.0)
    (on_standard ~scroll_offset:700.0 (-0.5));
  Alcotest.check offset "a further move at the start asks for nothing" None
    (on_standard ~scroll_offset:0.0 (-0.5));
  Alcotest.check offset "the same fixture asked to move on does move"
    (Some 150.0)
    (on_standard ~scroll_offset:0.0 0.5)

(* ------------------------------------------------------------------ *)
(* A container that cannot scroll at all                                *)
(* ------------------------------------------------------------------ *)

let deltas_both_ways = [ -3.0; -1.0; -0.5; 0.5; 1.0; 3.0 ]

(* 300 visible over 200 of content: the scrollable range is the single offset 0,
   so no delta can move it. The affirmative arm is the same unscrollable
   container holding an offset outside its own range, which is corrected back
   into it — without it the whole case would still pass against an
   implementation that never returns anything. *)
let test_none_when_container_cannot_scroll () =
  List.iter
    (fun delta ->
      Alcotest.check offset
        (Printf.sprintf "delta %g on content that fits" delta)
        None
        (Scroll_delta.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
           ~content_height:200.0
           (Scroll_delta.viewports delta)))
    deltas_both_ways;
  List.iter
    (fun delta ->
      Alcotest.check offset
        (Printf.sprintf "delta %g corrects an out-of-range offset there" delta)
        (Some 0.0)
        (Scroll_delta.offset_for ~scroll_offset:40.0 ~viewport_height:300.0
           ~content_height:200.0
           (Scroll_delta.viewports delta)))
    deltas_both_ways

(* ------------------------------------------------------------------ *)
(* Measurements that are not numbers                                    *)
(* ------------------------------------------------------------------ *)

(* A backend that fails to measure hands back NaN or an infinity rather than
   raising, and an unguarded formula turns either into a poisoned scroll write.
   A delta computed by an application can arrive the same way. The base fixture
   is asserted first so each substitution below is demonstrably the reason its
   arm yields nothing. *)
let non_finite_values =
  [
    ("nan", Float.nan);
    ("infinity", Float.infinity);
    ("neg_infinity", Float.neg_infinity);
  ]

let test_none_on_non_finite () =
  Alcotest.check offset "the base fixture does produce an offset" (Some 150.0)
    (on_standard ~scroll_offset:0.0 0.5);
  List.iter
    (fun (label, v) ->
      Alcotest.check offset
        ("scroll_offset = " ^ label)
        None
        (Scroll_delta.offset_for ~scroll_offset:v ~viewport_height:300.0
           ~content_height:1000.0
           (Scroll_delta.viewports 0.5));
      Alcotest.check offset
        ("viewport_height = " ^ label)
        None
        (Scroll_delta.offset_for ~scroll_offset:0.0 ~viewport_height:v
           ~content_height:1000.0
           (Scroll_delta.viewports 0.5));
      Alcotest.check offset
        ("content_height = " ^ label)
        None
        (Scroll_delta.offset_for ~scroll_offset:0.0 ~viewport_height:300.0
           ~content_height:v
           (Scroll_delta.viewports 0.5));
      Alcotest.check offset ("delta = " ^ label) None
        (on_standard ~scroll_offset:0.0 v))
    non_finite_values

(* ------------------------------------------------------------------ *)
(* A product that overflows the float range                             *)
(* ------------------------------------------------------------------ *)

(* Every value here is finite, the delta included, and yet 1e306 visible heights
   of 300 units each is 3e308 — past the largest float there is — so the target
   overflows to an infinity before the clamp ever sees it. The request is still
   answerable: the clamp lands it on an offset the container can take. This is
   what makes checking each input in turn, rather than inferring finiteness from
   the arithmetic, observable rather than merely asserted — a guard reading the
   overflowed target would answer nothing to either arm below. Both directions,
   so neither arm can be satisfied by an implementation that always clamps to
   the same end. *)
let test_overflowing_product_still_lands_in_range () =
  Alcotest.check offset "a delta whose product overflows lands at the end"
    (Some 700.0)
    (on_standard ~scroll_offset:0.0 1e306);
  Alcotest.check offset "the same magnitude back lands at the start" (Some 0.0)
    (on_standard ~scroll_offset:700.0 (-1e306))

(* ------------------------------------------------------------------ *)
(* The sign convention                                                  *)
(* ------------------------------------------------------------------ *)

(* Positive moves toward the end and negative back toward the start, asserted
   as a pair from one offset so a sign flip cannot satisfy both. *)
let test_negative_delta_moves_back () =
  Alcotest.check offset "half a visible height back" (Some 250.0)
    (on_standard ~scroll_offset:400.0 (-0.5));
  Alcotest.check offset "a whole visible height back" (Some 100.0)
    (on_standard ~scroll_offset:400.0 (-1.0));
  Alcotest.check offset "the same magnitude forward from the same offset"
    (Some 550.0)
    (on_standard ~scroll_offset:400.0 0.5)

(* ------------------------------------------------------------------ *)
(* Two requests are the same request                                    *)
(* ------------------------------------------------------------------ *)

(* Thunks, not values, so each call is the fresh request an update rebuilding
   its command every message produces. The multiple goes through
   Sys.opaque_identity rather than being written as a literal, and that is
   load-bearing rather than decorative: the constructor takes a float, so a
   literal argument lets the compiler fold the whole application into one static
   block and hand the same value back to both calls. Measured, not assumed —
   with a plain literal, two calls compare physically equal under ocamlopt, and
   an implementation comparing with == would pass the first case below while
   comparing nothing. The distinctness guard immediately under this keeps that
   from going quiet again. *)
let half () = Scroll_delta.viewports (Sys.opaque_identity 0.5)
let whole () = Scroll_delta.viewports (Sys.opaque_identity 1.0)

let test_equal_compares_the_multiple () =
  Alcotest.check Alcotest.bool
    "the fixture builds a fresh value, so == cannot stand in for equal" false
    (half () == half ());
  Alcotest.check Alcotest.bool "a rebuilt request equals the one it replaces"
    true
    (Scroll_delta.equal (half ()) (half ()));
  Alcotest.check Alcotest.bool "a different multiple is not equal" false
    (Scroll_delta.equal (half ()) (whole ()));
  Alcotest.check Alcotest.bool "the sign is part of the request" false
    (Scroll_delta.equal
       (Scroll_delta.viewports (Sys.opaque_identity 0.5))
       (Scroll_delta.viewports (Sys.opaque_identity (-0.5))))

(* ------------------------------------------------------------------ *)
(* The properties no single fixture can pin                             *)
(* ------------------------------------------------------------------ *)

type geometry = {
  scroll_offset : float;
  viewport_height : float;
  content_height : float;
  delta : float;
}

let geometry_to_string g =
  Printf.sprintf
    "scroll_offset=%g viewport_height=%g content_height=%g delta=%g"
    g.scroll_offset g.viewport_height g.content_height g.delta

(* Whole numbers for the three measurements and halves for the delta, so every
   expected value is exact in binary. The current offset is drawn from the whole
   content rather than from the scrollable range, so a container holding an
   offset outside its own range is generated too — that is the state a shrinking
   container leaves behind, and the one the clamp has to correct. *)
let geometry_gen =
  let open QCheck.Gen in
  int_range 1 500 >>= fun viewport ->
  int_range 1 2000 >>= fun content ->
  int_range 0 content >>= fun scroll ->
  int_range (-8) 8 >>= fun half_steps ->
  return
    {
      scroll_offset = float_of_int scroll;
      viewport_height = float_of_int viewport;
      content_height = float_of_int content;
      delta = float_of_int half_steps /. 2.0;
    }

let arb_geometry = QCheck.make ~print:geometry_to_string geometry_gen

let apply g =
  Scroll_delta.offset_for ~scroll_offset:g.scroll_offset
    ~viewport_height:g.viewport_height ~content_height:g.content_height
    (Scroll_delta.viewports g.delta)

let max_scroll_of g = Float.max 0.0 (g.content_height -. g.viewport_height)

(* Two claims, because reachability alone is satisfied by an implementation that
   never returns anything: the offset a caller ends up at is always one the
   container can take, and — for a container whose current offset is already
   inside its own range — a positive delta never moves it back and a negative
   one never moves it on. The second is the sign convention stated as a property
   rather than as four fixtures. *)
let test_prop_result_is_always_reachable =
  QCheck.Test.make ~count:2000 ~name:"prop_result_is_always_reachable"
    arb_geometry (fun g ->
      let result = apply g in
      let final = Option.value result ~default:g.scroll_offset in
      let max_scroll = max_scroll_of g in
      let reachable =
        (not (Float.is_nan final))
        && Float.compare final 0.0 >= 0
        && Float.compare final max_scroll <= 0
      in
      let started_in_range =
        Float.compare g.scroll_offset 0.0 >= 0
        && Float.compare g.scroll_offset max_scroll <= 0
      in
      let direction_held =
        (not started_in_range)
        || Float.compare g.delta 0.0 = 0
        ||
        if Float.compare g.delta 0.0 > 0 then
          Float.compare final g.scroll_offset >= 0
        else Float.compare final g.scroll_offset <= 0
      in
      reachable && direction_held)

(* The oracle restates the clamp deliberately, because what this pins is not the
   formula — the fixtures above do that — but the equivalence: nothing is
   returned exactly when the reachable target is the offset the container
   already holds. The second claim needs no oracle and kills the cheat the first
   one cannot see: a returned offset is never the current one, so no request
   ever resolves to a write that changes nothing. *)
let test_prop_none_iff_no_movement =
  QCheck.Test.make ~count:2000 ~name:"prop_none_iff_no_movement" arb_geometry
    (fun g ->
      let result = apply g in
      let target = g.scroll_offset +. (g.delta *. g.viewport_height) in
      let expected = Float.min (max_scroll_of g) (Float.max 0.0 target) in
      let agrees_on_absence =
        Bool.equal (Option.is_none result)
          (Float.equal expected g.scroll_offset)
      in
      let never_a_no_op_write =
        match result with
        | None -> true
        | Some o ->
            (not (Float.equal o g.scroll_offset))
            && close ~epsilon:1e-9 o expected
      in
      agrees_on_absence && never_a_no_op_write)

let () =
  (* Fixed seed: a counterexample must reproduce across runs, which it does not
     if qcheck-alcotest seeds from the clock. *)
  let rand = Random.State.make [| 0x0131_0001 |] in
  Alcotest.run "nopal_element_scroll_delta"
    [
      ( "offset_for",
        [
          Alcotest.test_case "moves_by_the_requested_fraction" `Quick
            test_moves_by_the_requested_fraction;
          Alcotest.test_case "clamps_at_the_end" `Quick test_clamps_at_the_end;
          Alcotest.test_case "none_when_already_at_the_end" `Quick
            test_none_when_already_at_the_end;
          Alcotest.test_case "none_when_container_cannot_scroll" `Quick
            test_none_when_container_cannot_scroll;
          Alcotest.test_case "none_on_non_finite" `Quick test_none_on_non_finite;
          Alcotest.test_case "overflowing_product_still_lands_in_range" `Quick
            test_overflowing_product_still_lands_in_range;
          Alcotest.test_case "negative_delta_moves_back" `Quick
            test_negative_delta_moves_back;
        ]
        @ List.map
            (QCheck_alcotest.to_alcotest ~rand ~speed_level:`Quick)
            [
              test_prop_result_is_always_reachable;
              test_prop_none_iff_no_movement;
            ] );
      ( "value",
        [
          Alcotest.test_case "equal_compares_the_multiple" `Quick
            test_equal_compares_the_multiple;
        ] );
    ]
