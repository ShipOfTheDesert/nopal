open Image_test_helpers

let score = approx ~epsilon:1e-9

(* Every fixture pixel is gray, so its luma is its own channel value and a
   fixture's expected score can be read straight off the levels listed here.
   [levels] is row-major, matching the order [Luma.of_buffer] produces. *)
let gray ~context ~width ~height levels =
  gray_buffer_or_fail ~context ~width ~height levels

let test_uniform_scores_zero () =
  let buffer =
    gray ~context:"uniform fixture" ~width:3 ~height:4
      [| 100; 100; 100; 100; 100; 100; 100; 100; 100; 100; 100; 100 |]
  in
  Alcotest.check score "a buffer with no luma variation has no gradient" 0.0
    (Nopal_image.Sharpness.score buffer)

(* Both fixtures are hand-enumerated below; neither expectation is obtained by
   calling the implementation.

   Fixture A is 3 wide by 2 tall with a vertical edge in the last column:

     0   0   200
     0   0   200

   Horizontal pairs, (3-1)*2 = 4: |0-0| |0-200| in each row, so 200 + 200.
   Vertical pairs, 3*(2-1) = 3: every column is constant, so 0.
   Score = (200 + 200) / 7.

   Fixture B is that fixture transposed — 2 wide by 3 tall, edge in the last
   row — so the same 400 now falls entirely on the vertical pairs and the pair
   count is again 7. It is not redundant with A: A's vertical sum is zero, so an
   implementation that counts vertical pairs in the denominator but never adds
   their differences scores A correctly and B as zero. *)
let test_step_edge_matches_hand_computed () =
  let expected = (200.0 +. 200.0) /. 7.0 in
  let horizontal_edge =
    gray ~context:"step edge across columns" ~width:3 ~height:2
      [| 0; 0; 200; 0; 0; 200 |]
  in
  let vertical_edge =
    gray ~context:"step edge across rows" ~width:2 ~height:3
      [| 0; 0; 0; 0; 200; 200 |]
  in
  Alcotest.check score "a single column edge over seven pairs" expected
    (Nopal_image.Sharpness.score horizontal_edge);
  Alcotest.check score "a single row edge over seven pairs" expected
    (Nopal_image.Sharpness.score vertical_edge)

(* Alternating black and white one pixel apart makes every adjacent pair differ
   by the full luma range, so the mean difference is the largest a buffer on a
   0 to 255 scale can produce. *)
let test_checkerboard_is_maximum () =
  let buffer =
    gray ~context:"checkerboard fixture" ~width:4 ~height:3
      [| 255; 0; 255; 0; 0; 255; 0; 255; 255; 0; 255; 0 |]
  in
  Alcotest.check score "every adjacent pair spans the full range" 255.0
    (Nopal_image.Sharpness.score buffer)

(* The only buffer with no adjacent pair at all. The pair count is the divisor,
   so this is the one input where the metric would produce a NaN rather than a
   number; the NaN is asserted against directly so it cannot slip through a
   tolerance check. *)
let test_single_pixel_scores_zero () =
  let buffer = gray ~context:"one pixel" ~width:1 ~height:1 [| 200 |] in
  let result = Nopal_image.Sharpness.score buffer in
  Alcotest.check Alcotest.bool "the score is a number, not NaN" false
    (Float.is_nan result);
  Alcotest.check Alcotest.bool "the score is exactly zero" true
    (Float.equal 0.0 result)

(* A one-pixel-tall strip has no vertical pairs and a one-pixel-wide strip has
   no horizontal pairs, but both still have a gradient along their long axis and
   the metric measures it. This pins that the zero-pair branch covers 1 by 1
   alone: an implementation counting only pixels that have both a right and a
   down neighbour would score both of these as zero. *)
let test_single_row_varying_scores_nonzero () =
  let row = gray ~context:"one row" ~width:4 ~height:1 [| 0; 60; 120; 255 |] in
  let column =
    gray ~context:"one column" ~width:1 ~height:4 [| 0; 60; 120; 255 |]
  in
  let row_score = Nopal_image.Sharpness.score row in
  let column_score = Nopal_image.Sharpness.score column in
  Alcotest.check Alcotest.bool "the row score is a number, not NaN" false
    (Float.is_nan row_score);
  Alcotest.check Alcotest.bool "the row score is above zero" true
    (Float.compare row_score 0.0 > 0);
  Alcotest.check Alcotest.bool "the column score is a number, not NaN" false
    (Float.is_nan column_score);
  Alcotest.check Alcotest.bool "the column score is above zero" true
    (Float.compare column_score 0.0 > 0)

let tests =
  [
    Alcotest.test_case "a uniform buffer scores zero" `Quick
      test_uniform_scores_zero;
    Alcotest.test_case "a step edge matches the hand-computed score" `Quick
      test_step_edge_matches_hand_computed;
    Alcotest.test_case "a one-pixel checkerboard scores the maximum" `Quick
      test_checkerboard_is_maximum;
    Alcotest.test_case "a single pixel scores zero" `Quick
      test_single_pixel_scores_zero;
    Alcotest.test_case "a varying single row scores above zero" `Quick
      test_single_row_varying_scores_nonzero;
  ]

let () = Alcotest.run "Nopal_image.Sharpness" [ ("Sharpness", tests) ]
