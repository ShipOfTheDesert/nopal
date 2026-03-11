open Nopal_charts
open Nopal_draw

let color_testable =
  Alcotest.testable
    (fun fmt (c : Color.t) ->
      Format.fprintf fmt "{ r=%.3f; g=%.3f; b=%.3f; a=%.3f }" c.r c.g c.b c.a)
    Color.equal

let low = Color.rgb ~r:0.0 ~g:0.0 ~b:1.0
let high = Color.rgb ~r:1.0 ~g:0.0 ~b:0.0
let mid = Color.rgb ~r:1.0 ~g:1.0 ~b:1.0

let test_sequential_at_min () =
  let scale = Color_scale.sequential ~low ~high in
  let result = Color_scale.apply scale ~min:0.0 ~max:100.0 0.0 in
  Alcotest.check color_testable "at min returns low" low result

let test_sequential_at_max () =
  let scale = Color_scale.sequential ~low ~high in
  let result = Color_scale.apply scale ~min:0.0 ~max:100.0 100.0 in
  Alcotest.check color_testable "at max returns high" high result

let test_sequential_at_midpoint () =
  let scale = Color_scale.sequential ~low ~high in
  let result = Color_scale.apply scale ~min:0.0 ~max:100.0 50.0 in
  let expected = Color.lerp low high 0.5 in
  Alcotest.check color_testable "at midpoint returns interpolated" expected
    result

let test_sequential_clamp_below () =
  let scale = Color_scale.sequential ~low ~high in
  let result = Color_scale.apply scale ~min:0.0 ~max:100.0 (-10.0) in
  Alcotest.check color_testable "below min clamps to low" low result

let test_sequential_clamp_above () =
  let scale = Color_scale.sequential ~low ~high in
  let result = Color_scale.apply scale ~min:0.0 ~max:100.0 200.0 in
  Alcotest.check color_testable "above max clamps to high" high result

let test_diverging_at_midpoint () =
  let scale = Color_scale.diverging ~low ~mid ~high () in
  let result = Color_scale.apply scale ~min:(-100.0) ~max:100.0 0.0 in
  Alcotest.check color_testable "at midpoint returns mid" mid result

let test_diverging_below_midpoint () =
  let scale = Color_scale.diverging ~low ~mid ~high () in
  let result = Color_scale.apply scale ~min:(-100.0) ~max:100.0 (-50.0) in
  let expected = Color.lerp low mid 0.5 in
  Alcotest.check color_testable "below midpoint interpolates low->mid" expected
    result

let test_diverging_above_midpoint () =
  let scale = Color_scale.diverging ~low ~mid ~high () in
  let result = Color_scale.apply scale ~min:(-100.0) ~max:100.0 50.0 in
  let expected = Color.lerp mid high 0.5 in
  Alcotest.check color_testable "above midpoint interpolates mid->high" expected
    result

let test_diverging_at_min () =
  let scale = Color_scale.diverging ~low ~mid ~high () in
  let result = Color_scale.apply scale ~min:(-100.0) ~max:100.0 (-100.0) in
  Alcotest.check color_testable "at min returns low" low result

let test_diverging_at_max () =
  let scale = Color_scale.diverging ~low ~mid ~high () in
  let result = Color_scale.apply scale ~min:(-100.0) ~max:100.0 100.0 in
  Alcotest.check color_testable "at max returns high" high result

let test_diverging_custom_midpoint () =
  let scale = Color_scale.diverging ~low ~mid ~high ~midpoint:25.0 () in
  let result = Color_scale.apply scale ~min:0.0 ~max:100.0 25.0 in
  Alcotest.check color_testable "custom midpoint returns mid" mid result

let () =
  Alcotest.run "Color_scale"
    [
      ( "sequential",
        [
          Alcotest.test_case "at min" `Quick test_sequential_at_min;
          Alcotest.test_case "at max" `Quick test_sequential_at_max;
          Alcotest.test_case "at midpoint" `Quick test_sequential_at_midpoint;
          Alcotest.test_case "clamp below" `Quick test_sequential_clamp_below;
          Alcotest.test_case "clamp above" `Quick test_sequential_clamp_above;
        ] );
      ( "diverging",
        [
          Alcotest.test_case "at midpoint" `Quick test_diverging_at_midpoint;
          Alcotest.test_case "below midpoint" `Quick
            test_diverging_below_midpoint;
          Alcotest.test_case "above midpoint" `Quick
            test_diverging_above_midpoint;
          Alcotest.test_case "at min" `Quick test_diverging_at_min;
          Alcotest.test_case "at max" `Quick test_diverging_at_max;
          Alcotest.test_case "custom midpoint" `Quick
            test_diverging_custom_midpoint;
        ] );
    ]
