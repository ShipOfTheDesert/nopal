open Nopal_draw

let tolerance = 1e-9

let pp_resolved ppf = function
  | Arc.Invalid -> Format.pp_print_string ppf "Invalid"
  | Arc.Sweep { start; sweep } ->
      Format.fprintf ppf "Sweep {start %.17g; sweep %.17g}" start sweep

(* A row pins the sweep only; the start must be the reduced start angle. *)
let equal_resolved expected actual =
  match (expected, actual) with
  | Arc_cases.Invalid, Arc.Invalid -> true
  | Arc_cases.Sweep e, Arc.Sweep { start; sweep } ->
      Float.abs (e -. sweep) <= tolerance
      && start >= 0.
      && start < 2. *. Float.pi
  | Arc_cases.Invalid, Arc.Sweep _
  | Arc_cases.Sweep _, Arc.Invalid ->
      false

let check_start (row : Arc_cases.row) = function
  | Arc.Sweep { start; _ } when Float.abs row.start_angle <= 1e6 ->
      (* Beyond 1e6 the float cos/sin of the raw angle loses the digits the
         comparison needs, so huge angles are checked by range only. *)
      Alcotest.(check (float tolerance))
        (row.name ^ ": cos start") (cos row.start_angle) (cos start);
      Alcotest.(check (float tolerance))
        (row.name ^ ": sin start") (sin row.start_angle) (sin start)
  | Arc.Sweep _
  | Arc.Invalid ->
      ()

let table_case (row : Arc_cases.row) =
  Alcotest.test_case row.name `Quick (fun () ->
      let actual =
        Arc.resolve row.direction ~cx:row.cx ~cy:row.cy ~r:row.r
          ~start_angle:row.start_angle ~end_angle:row.end_angle
      in
      Alcotest.(check bool)
        (Format.asprintf "%s: got %a" row.name pp_resolved actual)
        true
        (equal_resolved row.expected actual);
      check_start row actual)

let check_bounded direction ~start_angle ~end_angle =
  let label = Format.asprintf "%g to %g" start_angle end_angle in
  match
    ( direction,
      Arc.resolve direction ~cx:0. ~cy:0. ~r:1. ~start_angle ~end_angle )
  with
  | Path.Clockwise, Arc.Sweep { sweep = s; _ } ->
      Alcotest.(check bool) label true (s >= 0. && s <= 2. *. Float.pi)
  | Path.Anticlockwise, Arc.Sweep { sweep = s; _ } ->
      Alcotest.(check bool) label true (s <= 0. && s >= -2. *. Float.pi)
  | (Path.Clockwise | Path.Anticlockwise), Arc.Invalid ->
      Alcotest.failf "%s: a finite arc resolved to Invalid" label

let test_overflowing_difference_stays_in_range () =
  let big = Float.max_float in
  List.iter
    (fun direction ->
      check_bounded direction ~start_angle:(-.big) ~end_angle:big;
      check_bounded direction ~start_angle:big ~end_angle:(-.big))
    [ Path.Clockwise; Path.Anticlockwise ]

let () =
  Alcotest.run "Arc"
    [
      ("arc/table", List.map table_case Arc_cases.rows);
      ( "arc/bounds",
        [
          Alcotest.test_case "overflowing difference stays in range" `Quick
            test_overflowing_difference_stays_in_range;
        ] );
    ]
