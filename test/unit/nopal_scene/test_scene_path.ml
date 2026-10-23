open Nopal_scene

let test_arc_to_keeps_direction () =
  let arc direction =
    Path.arc_to ~cx:1. ~cy:2. ~r:3. ~start_angle:0.5 ~end_angle:1.5 ~direction
  in
  match (arc Path.Clockwise, arc Path.Anticlockwise) with
  | ( Path.Arc_to
        { direction = Path.Clockwise; cx; cy; r; start_angle; end_angle },
      Path.Arc_to { direction = Path.Anticlockwise; _ } ) ->
      Alcotest.(check (list (float 0.)))
        "fields kept" [ 1.; 2.; 3.; 0.5; 1.5 ]
        [ cx; cy; r; start_angle; end_angle ]
  | _ -> Alcotest.fail "arc_to must keep the direction it was given"

let test_segment_equality_sees_direction () =
  let arc direction =
    Path.arc_to ~cx:1. ~cy:2. ~r:3. ~start_angle:0.5 ~end_angle:1.5 ~direction
  in
  Alcotest.(check bool)
    "same direction equal" true
    (Path.equal_segment (arc Path.Clockwise) (arc Path.Clockwise));
  Alcotest.(check bool)
    "different direction differs" false
    (Path.equal_segment (arc Path.Clockwise) (arc Path.Anticlockwise))

let test_direction_printer_and_equality () =
  Alcotest.(check string)
    "clockwise name" "Clockwise"
    (Format.asprintf "%a" Path.pp_direction Path.Clockwise);
  Alcotest.(check string)
    "anticlockwise name" "Anticlockwise"
    (Format.asprintf "%a" Path.pp_direction Path.Anticlockwise);
  Alcotest.(check bool)
    "equal" true
    (Path.equal_direction Path.Clockwise Path.Clockwise);
  Alcotest.(check bool)
    "differ" false
    (Path.equal_direction Path.Clockwise Path.Anticlockwise)

let () =
  Alcotest.run "scene_path"
    [
      ( "arc",
        [
          Alcotest.test_case "arc_to keeps direction" `Quick
            test_arc_to_keeps_direction;
          Alcotest.test_case "segment equality sees direction" `Quick
            test_segment_equality_sees_direction;
          Alcotest.test_case "direction printer and equality" `Quick
            test_direction_printer_and_equality;
        ] );
    ]
