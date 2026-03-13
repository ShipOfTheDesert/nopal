open Nopal_scene.Color

let float_eq = Alcotest.float 0.01

let test_rgb () =
  let c = rgb ~r:0.5 ~g:0.6 ~b:0.7 in
  Alcotest.(check float_eq) "r" 0.5 c.r;
  Alcotest.(check float_eq) "g" 0.6 c.g;
  Alcotest.(check float_eq) "b" 0.7 c.b;
  Alcotest.(check float_eq) "a" 1.0 c.a

let test_rgba () =
  let c = rgba ~r:0.1 ~g:0.2 ~b:0.3 ~a:0.4 in
  Alcotest.(check float_eq) "a" 0.4 c.a

let test_hsl () =
  let c = hsl ~h:0.0 ~s:1.0 ~l:0.5 in
  Alcotest.(check float_eq) "r" 1.0 c.r;
  Alcotest.(check float_eq) "g" 0.0 c.g

let test_of_hex () =
  match of_hex "#FF0000" with
  | Ok c -> Alcotest.(check float_eq) "r" 1.0 c.r
  | Error e -> Alcotest.fail e

let test_lerp () =
  let c = lerp black white 0.5 in
  Alcotest.(check float_eq) "r" 0.5 c.r

let test_equal () =
  Alcotest.(check bool) "same" true (equal red red);
  Alcotest.(check bool) "diff" false (equal red blue)

let test_categorical () =
  Alcotest.(check int) "length" 10 (Array.length categorical)

let test_sequential () =
  let colors = sequential red blue 3 in
  Alcotest.(check int) "count" 3 (List.length colors);
  Alcotest.(check bool) "first" true (equal (List.hd colors) red)

let () =
  Alcotest.run "Nopal_scene.Color"
    [
      ( "color",
        [
          Alcotest.test_case "rgb" `Quick test_rgb;
          Alcotest.test_case "rgba" `Quick test_rgba;
          Alcotest.test_case "hsl" `Quick test_hsl;
          Alcotest.test_case "of_hex" `Quick test_of_hex;
          Alcotest.test_case "lerp" `Quick test_lerp;
          Alcotest.test_case "equal" `Quick test_equal;
          Alcotest.test_case "categorical" `Quick test_categorical;
          Alcotest.test_case "sequential" `Quick test_sequential;
        ] );
    ]
