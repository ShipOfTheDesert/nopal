open Nopal_scene

let test_rect () =
  match Scene.rect ~x:10.0 ~y:20.0 ~w:100.0 ~h:50.0 () with
  | Scene.Rect { x; y; w; h; _ } ->
      Alcotest.(check (float 0.001)) "x" 10.0 x;
      Alcotest.(check (float 0.001)) "y" 20.0 y;
      Alcotest.(check (float 0.001)) "w" 100.0 w;
      Alcotest.(check (float 0.001)) "h" 50.0 h
  | _ -> Alcotest.fail "expected Rect"

let test_circle () =
  match Scene.circle ~cx:50.0 ~cy:50.0 ~r:25.0 () with
  | Scene.Circle { cx; cy; r; _ } ->
      Alcotest.(check (float 0.001)) "cx" 50.0 cx;
      Alcotest.(check (float 0.001)) "cy" 50.0 cy;
      Alcotest.(check (float 0.001)) "r" 25.0 r
  | _ -> Alcotest.fail "expected Circle"

let test_text () =
  match Scene.text ~x:10.0 ~y:20.0 "Hello" with
  | Scene.Text { content; _ } ->
      Alcotest.(check string) "content" "Hello" content
  | _ -> Alcotest.fail "expected Text"

let test_group () =
  let g = Scene.group [ Scene.circle ~cx:0.0 ~cy:0.0 ~r:10.0 () ] in
  match g with
  | Scene.Group { children; _ } ->
      Alcotest.(check int) "children" 1 (List.length children)
  | _ -> Alcotest.fail "expected Group"

let test_equal () =
  let a = Scene.rect ~x:1.0 ~y:2.0 ~w:3.0 ~h:4.0 () in
  let b = Scene.rect ~x:1.0 ~y:2.0 ~w:3.0 ~h:4.0 () in
  let c = Scene.rect ~x:1.0 ~y:2.0 ~w:99.0 ~h:4.0 () in
  Alcotest.(check bool) "same" true (Scene.equal a b);
  Alcotest.(check bool) "diff" false (Scene.equal a c)

let () =
  Alcotest.run "Nopal_scene.Scene"
    [
      ( "scene",
        [
          Alcotest.test_case "rect" `Quick test_rect;
          Alcotest.test_case "circle" `Quick test_circle;
          Alcotest.test_case "text" `Quick test_text;
          Alcotest.test_case "group" `Quick test_group;
          Alcotest.test_case "equal" `Quick test_equal;
        ] );
    ]
