(* Two robustness claims about the metric that no single hand-computed fixture
   can pin.

   Every fixture here is gray, so a pixel's luminance is its own channel value.
   That keeps both claims about the metric's traversal rather than about the
   luminance weighting, which its own suite already covers, and it lets the blur
   below work on one level per pixel instead of three channels — for a gray
   pixel those are the same operation. *)

open Image_test_helpers
module Buffer = Nopal_image.Buffer
module Sharpness = Nopal_image.Sharpness

let levels_to_string levels =
  String.concat " " (Array.to_list (Array.map string_of_int levels))

(* A 3 by 3 box blur averaging over whatever part of the window is in bounds, so
   a corner averages four levels and an edge six. Integer division truncates,
   which keeps the result inside 0 to 255 without a rounding helper. The centre
   offset is always in bounds, so the divisor is never zero.

   This is test scaffolding — the library neither offers nor needs a blur. *)
let window_offsets =
  [
    (-1, -1); (0, -1); (1, -1); (-1, 0); (0, 0); (1, 0); (-1, 1); (0, 1); (1, 1);
  ]

let box_blur ~width ~height levels =
  Array.init (width * height) (fun index ->
      let x = index mod width and y = index / width in
      let total, count =
        List.fold_left
          (fun (total, count) (dx, dy) ->
            let nx = x + dx and ny = y + dy in
            if nx < 0 || ny < 0 || nx >= width || ny >= height then
              (total, count)
            else (total + levels.((ny * width) + nx), count + 1))
          (0, 0) window_offsets
      in
      total / count)

(* Quarter turn clockwise. The result is [height] wide and [width] tall, and its
   pixel at [(x, y)] is the source pixel at [(y, height - 1 - x)] — the source's
   leftmost column, read bottom to top, becomes the result's top row. *)
let rotate_clockwise ~width ~height levels =
  Array.init (width * height) (fun index ->
      let x = index mod height and y = index / height in
      levels.(((height - 1 - x) * width) + y))

(* Large enough that a single unlucky draw cannot make the buffer near-uniform,
   small enough that five hundred property runs stay instant. *)
let noise_width = 8
let noise_height = 8

let noisy_levels_gen =
  QCheck.Gen.array_size
    (QCheck.Gen.return (noise_width * noise_height))
    (QCheck.Gen.int_range 0 255)

(* No shrinker, and the two reasons were each observed rather than reasoned
   about. Both runs below used a copy of this property with a shrinking
   arbitrary substituted and an unrelated defect injected so that shrinking
   would actually run.

   1. The stock array arbitrary shrinks the array's LENGTH as well as its
      elements, which breaks the width-by-height invariant [Buffer.create]
      enforces. Observed with [QCheck.array_size (Gen.return 64) …]:

        raised exception `Failure("Invalid image dimensions: rgba byte length 0
          does not match 8 by 8 at 4 bytes per pixel")`
        on ` (after 1 shrink steps)`

      One step, an empty array, and the report is the unreachable arm below
      rather than any counterexample.

   2. With an element-only shrinker — length fixed, each level driven toward
      zero — the minimised counterexample is the uniform buffer:

        test `blur lowers score (WITH shrinker)` failed on >= 1 cases:
        0 0 0 0 0 0 0 0 ... 0 0 0 0  (after 64 shrink steps)

      For an all-zero buffer the property is false by construction — the source
      scores 0.0, so the "above zero" clause fails — not because the metric has
      a defect. The reader would be sent after a bug that is not there.

   The printed levels are therefore what reproduces a failure. *)
let arb_noisy_levels = QCheck.make ~print:levels_to_string noisy_levels_gen

(* Blurring removes the high-frequency detail the metric exists to measure, so
   the blurred copy must score strictly lower.

   The "strictly" matters and the "above zero" clause is what makes it
   meaningful: a metric that returned a constant, or zero for everything, would
   satisfy an "is not greater than" assertion for every input. Demanding that the
   source scores above zero first means the comparison is made against a real
   gradient, so it can only pass because blurring actually moved the number
   down. *)
let test_blur_strictly_decreases_score =
  QCheck.Test.make ~count:500
    ~name:"box blurring a noisy buffer strictly lowers its sharpness score"
    arb_noisy_levels (fun levels ->
      let build levels =
        match gray_buffer ~width:noise_width ~height:noise_height levels with
        | Ok buffer -> buffer
        | Error error ->
            (* Unreachable: the generated array holds exactly one level per
               pixel of a fixed positive size, and the blur returns one level
               per pixel at the same dimensions while averaging values already
               in 0 to 255. This arm terminates rather than returning [false]
               because reaching it means [Buffer.create]'s own invariant broke,
               not that the metric violated the property under test — reporting
               it as a counterexample would send the reader after a metric bug
               that is not there. Nothing was asserted, so [failwith] says that
               where [Alcotest.fail] would misreport it as an assertion
               failure. *)
            failwith
              ("unreachable: Buffer.create rejected a generated fixture: "
              ^ Nopal_image.message error)
      in
      let source_score = Sharpness.score (build levels) in
      let blurred_score =
        Sharpness.score
          (build (box_blur ~width:noise_width ~height:noise_height levels))
      in
      (not (Float.is_nan source_score))
      && (not (Float.is_nan blurred_score))
      && Float.compare source_score 0.0 > 0
      && Float.compare blurred_score source_score < 0)

(* A quarter turn maps every horizontally adjacent pair onto a vertically
   adjacent one and back, so it preserves both the multiset of adjacent
   differences and the pair count. Summing over both axes and normalizing by the
   pair count therefore leaves the score unchanged, and an image held sideways
   scores the same as one held upright.

   The fixture is 4 by 3 with no symmetry of its own, so the rotation genuinely
   rearranges it rather than reproducing it.

     89  109    2   50
    162  120  197   17
    154  244  217  251

   The assertion carries a tolerance rather than demanding bit equality: the two
   orientations add the same differences in a different order, and IEEE double
   addition is not associative, so the last bits can differ. This fixture is one
   of the ones that do differ — rather than say so in prose, the test asserts it
   below, so the tolerance is demonstrably load-bearing on every run and a later
   tightening to an exact comparison fails immediately rather than lying dormant
   until some future fixture change makes the suite flaky.

   Both scores are also required to be above zero. Without that, an
   implementation returning a constant would satisfy "the rotation did not
   change the score" for every fixture. *)
let fixture_width = 4
let fixture_height = 3
let fixture_levels = [| 89; 109; 2; 50; 162; 120; 197; 17; 154; 244; 217; 251 |]

let test_rotation_preserves_score () =
  let upright =
    gray_buffer_or_fail ~context:"upright fixture" ~width:fixture_width
      ~height:fixture_height fixture_levels
  in
  let rotated =
    gray_buffer_or_fail ~context:"rotated fixture" ~width:fixture_height
      ~height:fixture_width
      (rotate_clockwise ~width:fixture_width ~height:fixture_height
         fixture_levels)
  in
  let upright_score = Sharpness.score upright in
  let rotated_score = Sharpness.score rotated in
  Alcotest.check Alcotest.bool "the upright score is a number, not NaN" false
    (Float.is_nan upright_score);
  Alcotest.check Alcotest.bool "the upright fixture has a real gradient" true
    (Float.compare upright_score 0.0 > 0);
  Alcotest.check Alcotest.bool "the rotated fixture has a real gradient" true
    (Float.compare rotated_score 0.0 > 0);
  Alcotest.check Alcotest.bool "a quarter turn leaves the score unchanged" true
    (close ~epsilon:1e-9 upright_score rotated_score);
  Alcotest.check Alcotest.bool
    "this fixture's two scores are not bit-identical, so the tolerance is \
     load-bearing"
    false
    (same_bits upright_score rotated_score)

let () =
  (* Fixed seed: a counterexample must reproduce across runs, which it does not
     if qcheck-alcotest seeds from the clock. *)
  let rand = Random.State.make [| 0x0124_0006 |] in
  Alcotest.run "Nopal_image.Sharpness properties"
    [
      ( "Sharpness properties",
        List.map
          (QCheck_alcotest.to_alcotest ~rand ~speed_level:`Quick)
          [ test_blur_strictly_decreases_score ]
        @ [
            Alcotest.test_case "a quarter turn preserves the score" `Quick
              test_rotation_preserves_score;
          ] );
    ]
