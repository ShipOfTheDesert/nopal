open Nopal_draw.Color

let float_eq = Alcotest.float 0.01

let test_rgba_construction () =
  let c = rgba ~r:0.1 ~g:0.2 ~b:0.3 ~a:0.4 in
  Alcotest.(check float_eq) "r" 0.1 c.r;
  Alcotest.(check float_eq) "g" 0.2 c.g;
  Alcotest.(check float_eq) "b" 0.3 c.b;
  Alcotest.(check float_eq) "a" 0.4 c.a

let test_rgb_alpha_default () =
  let c = rgb ~r:0.5 ~g:0.5 ~b:0.5 in
  Alcotest.(check float_eq) "a" 1.0 c.a

let test_hsla_red () =
  let c = hsla ~h:0.0 ~s:1.0 ~l:0.5 ~a:1.0 in
  Alcotest.(check float_eq) "r" 1.0 c.r;
  Alcotest.(check float_eq) "g" 0.0 c.g;
  Alcotest.(check float_eq) "b" 0.0 c.b;
  Alcotest.(check float_eq) "a" 1.0 c.a

let test_hsla_green () =
  let c = hsla ~h:120.0 ~s:1.0 ~l:0.5 ~a:1.0 in
  Alcotest.(check float_eq) "r" 0.0 c.r;
  Alcotest.(check float_eq) "g" 1.0 c.g;
  Alcotest.(check float_eq) "b" 0.0 c.b

let test_hsla_blue () =
  let c = hsla ~h:240.0 ~s:1.0 ~l:0.5 ~a:1.0 in
  Alcotest.(check float_eq) "r" 0.0 c.r;
  Alcotest.(check float_eq) "g" 0.0 c.g;
  Alcotest.(check float_eq) "b" 1.0 c.b

let test_hex_valid_6 () =
  match of_hex "#FF0000" with
  | Ok c ->
      Alcotest.(check float_eq) "r" 1.0 c.r;
      Alcotest.(check float_eq) "g" 0.0 c.g;
      Alcotest.(check float_eq) "b" 0.0 c.b;
      Alcotest.(check float_eq) "a" 1.0 c.a
  | Error e -> Alcotest.fail e

let test_hex_valid_3 () =
  match of_hex "#F00" with
  | Ok c ->
      Alcotest.(check float_eq) "r" 1.0 c.r;
      Alcotest.(check float_eq) "g" 0.0 c.g;
      Alcotest.(check float_eq) "b" 0.0 c.b
  | Error e -> Alcotest.fail e

let test_hex_valid_8 () =
  match of_hex "#FF000080" with
  | Ok c ->
      Alcotest.(check float_eq) "r" 1.0 c.r;
      Alcotest.(check float_eq) "a" 0.502 c.a
  | Error e -> Alcotest.fail e

let test_hex_invalid_format () =
  match of_hex "not-a-color" with
  | Ok _ -> Alcotest.fail "expected Error"
  | Error _ -> ()

let test_hex_invalid_length () =
  match of_hex "#12345" with
  | Ok _ -> Alcotest.fail "expected Error"
  | Error _ -> ()

let test_lerp_endpoints () =
  let a = rgba ~r:0.0 ~g:0.0 ~b:0.0 ~a:1.0 in
  let b = rgba ~r:1.0 ~g:1.0 ~b:1.0 ~a:1.0 in
  let c0 = lerp a b 0.0 in
  Alcotest.(check float_eq) "r at 0" 0.0 c0.r;
  let c1 = lerp a b 1.0 in
  Alcotest.(check float_eq) "r at 1" 1.0 c1.r

let test_lerp_midpoint () =
  let c = lerp black white 0.5 in
  Alcotest.(check float_eq) "r" 0.5 c.r;
  Alcotest.(check float_eq) "g" 0.5 c.g;
  Alcotest.(check float_eq) "b" 0.5 c.b

let test_named_colors () =
  Alcotest.(check float_eq) "red.r" 1.0 red.r;
  Alcotest.(check float_eq) "red.g" 0.0 red.g;
  Alcotest.(check float_eq) "green.g" 1.0 green.g;
  Alcotest.(check float_eq) "blue.b" 1.0 blue.b;
  Alcotest.(check float_eq) "black.r" 0.0 black.r;
  Alcotest.(check float_eq) "white.r" 1.0 white.r;
  Alcotest.(check float_eq) "transparent.a" 0.0 transparent.a

let test_categorical_length () =
  Alcotest.(check int) "length" 10 (Array.length categorical)

let test_sequential_count () =
  let colors = sequential red blue 5 in
  Alcotest.(check int) "count" 5 (List.length colors)

let test_sequential_endpoints () =
  let colors = sequential red blue 5 in
  let first = List.hd colors in
  let last = List.nth colors 4 in
  Alcotest.(check bool) "first is red" true (equal first red);
  Alcotest.(check bool) "last is blue" true (equal last blue)

let test_equal_same () =
  let c = rgba ~r:0.1 ~g:0.2 ~b:0.3 ~a:0.4 in
  Alcotest.(check bool) "same" true (equal c c)

let test_equal_different () =
  Alcotest.(check bool) "different" false (equal red blue)

let () =
  Alcotest.run "Color"
    [
      ( "construction",
        [
          Alcotest.test_case "test_rgba_construction" `Quick
            test_rgba_construction;
          Alcotest.test_case "test_rgb_alpha_default" `Quick
            test_rgb_alpha_default;
          Alcotest.test_case "test_hsla_red" `Quick test_hsla_red;
          Alcotest.test_case "test_hsla_green" `Quick test_hsla_green;
          Alcotest.test_case "test_hsla_blue" `Quick test_hsla_blue;
        ] );
      ( "hex",
        [
          Alcotest.test_case "test_hex_valid_6" `Quick test_hex_valid_6;
          Alcotest.test_case "test_hex_valid_3" `Quick test_hex_valid_3;
          Alcotest.test_case "test_hex_valid_8" `Quick test_hex_valid_8;
          Alcotest.test_case "test_hex_invalid_format" `Quick
            test_hex_invalid_format;
          Alcotest.test_case "test_hex_invalid_length" `Quick
            test_hex_invalid_length;
        ] );
      ( "interpolation",
        [
          Alcotest.test_case "test_lerp_endpoints" `Quick test_lerp_endpoints;
          Alcotest.test_case "test_lerp_midpoint" `Quick test_lerp_midpoint;
        ] );
      ( "named",
        [ Alcotest.test_case "test_named_colors" `Quick test_named_colors ] );
      ( "palettes",
        [
          Alcotest.test_case "test_categorical_length" `Quick
            test_categorical_length;
          Alcotest.test_case "test_sequential_count" `Quick
            test_sequential_count;
          Alcotest.test_case "test_sequential_endpoints" `Quick
            test_sequential_endpoints;
        ] );
      ( "equality",
        [
          Alcotest.test_case "test_equal_same" `Quick test_equal_same;
          Alcotest.test_case "test_equal_different" `Quick test_equal_different;
        ] );
    ]
