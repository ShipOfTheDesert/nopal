open Nopal_test.Test_renderer
module E = Nopal_element.Element

let check_node = Test_util.check_node

type msg =
  | PointerMove of float * float
  | PointerClick of float * float
  | PointerLeave

let pp_selector fmt sel =
  match sel with
  | By_tag t -> Format.fprintf fmt "By_tag %S" t
  | By_text t -> Format.fprintf fmt "By_text %S" t
  | By_attr (k, v) -> Format.fprintf fmt "By_attr (%S, %S)" k v
  | First_child -> Format.fprintf fmt "First_child"
  | Nth_child n -> Format.fprintf fmt "Nth_child %d" n

let error_testable =
  Alcotest.testable
    (fun fmt e ->
      match e with
      | Not_found sel -> Format.fprintf fmt "Not_found (%a)" pp_selector sel
      | No_handler { tag; event } ->
          Format.fprintf fmt "No_handler { tag = %S; event = %S }" tag event)
    ( = )

let msg_testable =
  Alcotest.testable
    (fun fmt m ->
      match m with
      | PointerMove (x, y) -> Format.fprintf fmt "PointerMove (%g, %g)" x y
      | PointerClick (x, y) -> Format.fprintf fmt "PointerClick (%g, %g)" x y
      | PointerLeave -> Format.fprintf fmt "PointerLeave")
    ( = )

let simple_scene = [ Nopal_draw.Scene.rect ~x:0.0 ~y:0.0 ~w:50.0 ~h:50.0 () ]

let test_render_draw_node () =
  let el = E.draw ~width:200.0 ~height:100.0 simple_scene in
  let r = render el in
  check_node "draw renders as canvas"
    (Element
       {
         tag = "canvas";
         style = Nopal_style.Style.default;
         attrs = [ ("width", "200."); ("height", "100."); ("scene-nodes", "1") ];
         children = [];
         interaction = Nopal_style.Interaction.default;
       })
    (tree r)

let test_render_draw_scene_attr () =
  let scene =
    [
      Nopal_draw.Scene.rect ~x:0.0 ~y:0.0 ~w:10.0 ~h:10.0 ();
      Nopal_draw.Scene.circle ~cx:50.0 ~cy:50.0 ~r:25.0 ();
      Nopal_draw.Scene.text ~x:0.0 ~y:0.0 "hello";
    ]
  in
  let el = E.draw ~width:100.0 ~height:100.0 scene in
  let r = render el in
  let canvas = find (By_tag "canvas") (tree r) in
  Alcotest.(check (option string))
    "scene-nodes attr is 3" (Some "3")
    (attr "scene-nodes" (Option.get canvas))

let test_pointer_move_dispatches () =
  let el =
    E.draw
      ~on_pointer_move:(fun pe -> PointerMove (pe.x, pe.y))
      ~width:200.0 ~height:100.0 simple_scene
  in
  let r = render el in
  let result = pointer_move (By_tag "canvas") ~x:10.0 ~y:20.0 r in
  Alcotest.(check (result unit error_testable))
    "pointer_move succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "pointer move message dispatched"
    [ PointerMove (10.0, 20.0) ]
    (messages r)

let test_pointer_click_dispatches () =
  let el =
    E.draw
      ~on_click:(fun pe -> PointerClick (pe.x, pe.y))
      ~width:200.0 ~height:100.0 simple_scene
  in
  let r = render el in
  let result = pointer_click (By_tag "canvas") ~x:30.0 ~y:40.0 r in
  Alcotest.(check (result unit error_testable))
    "pointer_click succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "pointer click message dispatched"
    [ PointerClick (30.0, 40.0) ]
    (messages r)

let test_pointer_leave_dispatches () =
  let el =
    E.draw ~on_pointer_leave:PointerLeave ~width:200.0 ~height:100.0
      simple_scene
  in
  let r = render el in
  let result = pointer_leave (By_tag "canvas") r in
  Alcotest.(check (result unit error_testable))
    "pointer_leave succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "pointer leave message dispatched" [ PointerLeave ] (messages r)

let test_pointer_no_handler () =
  let el = E.draw ~width:200.0 ~height:100.0 simple_scene in
  let r = render el in
  let result_move = pointer_move (By_tag "canvas") ~x:10.0 ~y:20.0 r in
  Alcotest.(check (result unit error_testable))
    "pointer_move returns No_handler"
    (Error (No_handler { tag = "canvas"; event = "pointer_move" }))
    result_move;
  let result_click = pointer_click (By_tag "canvas") ~x:10.0 ~y:20.0 r in
  Alcotest.(check (result unit error_testable))
    "pointer_click returns No_handler"
    (Error (No_handler { tag = "canvas"; event = "pointer_click" }))
    result_click;
  let result_leave = pointer_leave (By_tag "canvas") r in
  Alcotest.(check (result unit error_testable))
    "pointer_leave returns No_handler"
    (Error (No_handler { tag = "canvas"; event = "pointer_leave" }))
    result_leave;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let () =
  Alcotest.run "Test_draw_renderer"
    [
      ( "draw rendering",
        [
          Alcotest.test_case "test_render_draw_node" `Quick
            test_render_draw_node;
          Alcotest.test_case "test_render_draw_scene_attr" `Quick
            test_render_draw_scene_attr;
        ] );
      ( "draw pointer events",
        [
          Alcotest.test_case "test_pointer_move_dispatches" `Quick
            test_pointer_move_dispatches;
          Alcotest.test_case "test_pointer_click_dispatches" `Quick
            test_pointer_click_dispatches;
          Alcotest.test_case "test_pointer_leave_dispatches" `Quick
            test_pointer_leave_dispatches;
          Alcotest.test_case "test_pointer_no_handler" `Quick
            test_pointer_no_handler;
        ] );
    ]
