(* Canvas must fully clear the previous frame at any devicePixelRatio
   (including dpr < 1), and re-apply hidpi scaling when the dpr changes — not
   only when the logical size changes. Every arc segment must reach the
   platform as the sweep the shared arc table gives it, or not at all.

   These tests drive Canvas_renderer through the fake C2d in canvas_shim.js,
   which records clearRect in device (backing-store) pixels, tracks the active
   transform scale, and records the calls made on each Path2D. See
   canvas_shim.js for the oracle rationale. *)

open Brr_canvas

let set_dpr dpr = Jv.set Jv.global "devicePixelRatio" (Jv.of_float dpr)

(* A fresh <canvas> and its recording 2D context. *)
let make_canvas () =
  let el = Brr.El.v (Jstr.v "canvas") [] in
  let canvas = Canvas.of_el el in
  let ctx = C2d.get_context canvas in
  (el, canvas, ctx)

let device_clear el =
  let ctx_jv = Jv.get (Brr.El.to_jv el) "_ctx" in
  let last = Jv.get ctx_jv "_lastClear" in
  (Jv.to_float (Jv.get last "deviceW"), Jv.to_float (Jv.get last "deviceH"))

(* At dpr < 1 the clear must cover the full backing store, not the
   logical rect. The buggy clear runs under the dpr scale, so it clears only
   (logical * dpr) device pixels — a strip is left painted. *)
let test_canvas_clears_below_unit_dpr () =
  set_dpr 0.5;
  let el, _canvas, ctx = make_canvas () in
  Nopal_web.Canvas_renderer.setup_hidpi el ctx ~width:100.0 ~height:80.0;
  Nopal_web.Canvas_renderer.render ctx [];
  let backing_w = Jv.to_float (Jv.get (Brr.El.to_jv el) "width") in
  let backing_h = Jv.to_float (Jv.get (Brr.El.to_jv el) "height") in
  let cleared_w, cleared_h = device_clear el in
  Alcotest.(check (float 0.001))
    "clear covers full backing-store width" backing_w cleared_w;
  Alcotest.(check (float 0.001))
    "clear covers full backing-store height" backing_h cleared_h

(* A devicePixelRatio change with an unchanged logical size must re-run
   setup_hidpi (re-sizing the backing store and re-applying scale). A pure
   size-equality guard misses this and leaves the canvas at the stale dpr. *)
let test_canvas_resetup_on_dpr_change () =
  set_dpr 1.0;
  let el, _canvas, ctx = make_canvas () in
  Nopal_web.Canvas_renderer.setup_hidpi el ctx ~width:100.0 ~height:80.0;
  let backing_at name = Jv.to_int (Jv.get (Brr.El.to_jv el) name) in
  Alcotest.(check int) "initial backing width" 100 (backing_at "width");
  set_dpr 2.0;
  Nopal_web.Canvas_renderer.resize_if_needed el ctx ~width:100.0 ~height:80.0;
  Alcotest.(check int)
    "backing width re-sized to new dpr" 200 (backing_at "width");
  Alcotest.(check int)
    "backing height re-sized to new dpr" 160 (backing_at "height");
  (* Unchanged dpr + size must not re-setup (no further backing-store writes). *)
  let writes_before = Jv.to_int (Jv.get (Brr.El.to_jv el) "_sizeWrites") in
  Nopal_web.Canvas_renderer.resize_if_needed el ctx ~width:100.0 ~height:80.0;
  let writes_after = Jv.to_int (Jv.get (Brr.El.to_jv el) "_sizeWrites") in
  Alcotest.(check int)
    "unchanged dpr/size performs no backing-store write" writes_before
    writes_after

type path_call =
  | Move of float * float
  | Line of float * float
  | Arc of {
      cx : float;
      cy : float;
      r : float;
      start : float;
      stop : float;
      anticlockwise : bool;
    }
  | Close

let decode_call call =
  let num name = Jv.to_float (Jv.get call name) in
  match Jv.to_string (Jv.get call "op") with
  | "moveTo" -> Move (num "x", num "y")
  | "lineTo" -> Line (num "x", num "y")
  | "arc" ->
      Arc
        {
          cx = num "cx";
          cy = num "cy";
          r = num "r";
          start = num "start";
          stop = num "stop";
          anticlockwise = Jv.to_bool (Jv.get call "anticlockwise");
        }
  | "closePath" -> Close
  | op -> Alcotest.failf "the shim recorded an unknown path call %S" op

(* The calls made on the Path2D the renderer filled for a single filled path
   holding [segments]. *)
let filled_path_calls segments =
  let el, _canvas, ctx = make_canvas () in
  Nopal_web.Canvas_renderer.render ctx
    [
      Nopal_scene.Scene.path
        ~fill:(Nopal_scene.Paint.Solid Nopal_scene.Color.black) segments;
    ];
  let filled = Jv.get (Jv.get (Brr.El.to_jv el) "_ctx") "_lastFill" in
  match Jv.is_null filled with
  | true -> Alcotest.fail "the renderer filled no path"
  | false -> Jv.to_list decode_call (Jv.get filled "_calls")

let arc_lead = (1., 2.)
let arc_tail = (3., 4.)

let arc_row_calls (row : Arc_cases.row) =
  let lead_x, lead_y = arc_lead in
  let tail_x, tail_y = arc_tail in
  filled_path_calls
    [
      Nopal_scene.Path.move_to ~x:lead_x ~y:lead_y;
      Nopal_scene.Path.arc_to ~cx:row.cx ~cy:row.cy ~r:row.r
        ~start_angle:row.start_angle ~end_angle:row.end_angle
        ~direction:row.direction;
      Nopal_scene.Path.line_to ~x:tail_x ~y:tail_y;
    ]

let sweep_tolerance = 1e-9

(* The sweep the platform draws for an arc whose stop lies on the side of its
   start that [anticlockwise] names: an anticlockwise sweep counts as negative.
   A stop on the other side makes the platform wrap the long way round, which a
   renderer passing a resolved sweep never asks for. *)
let platform_sweep ~start ~stop ~anticlockwise =
  let sweep = stop -. start in
  match anticlockwise with
  | true when sweep <= 0. -> sweep
  | false when sweep >= 0. -> sweep
  | true
  | false ->
      Alcotest.failf "stop %g lies the wrong side of start %g for %s" stop start
        (match anticlockwise with
        | true -> "anticlockwise"
        | false -> "clockwise")

(* The platform receives the start angle reduced into [0, 2π): the same direction
   as the row's, wherever the row's angle is small enough for that to be
   checkable. *)
let check_reduced_start (row : Arc_cases.row) start =
  Alcotest.(check bool)
    "start reduced" true
    (start >= 0. && start < 2. *. Float.pi);
  match Float.abs row.start_angle < 1e6 with
  | false -> ()
  | true ->
      Alcotest.(check (float sweep_tolerance))
        "start cos"
        (Float.cos row.start_angle)
        (Float.cos start);
      Alcotest.(check (float sweep_tolerance))
        "start sin"
        (Float.sin row.start_angle)
        (Float.sin start)

let check_sweep_row (row : Arc_cases.row) sweep =
  match arc_row_calls row with
  | [ Move (mx, my); Arc arc; Line (lx, ly) ] ->
      Alcotest.(check (pair (float 0.) (float 0.)))
        "lead move kept" arc_lead (mx, my);
      Alcotest.(check (pair (float 0.) (float 0.)))
        "tail line kept" arc_tail (lx, ly);
      Alcotest.(check (float 0.)) "cx" row.cx arc.cx;
      Alcotest.(check (float 0.)) "cy" row.cy arc.cy;
      Alcotest.(check (float 0.)) "r" row.r arc.r;
      check_reduced_start row arc.start;
      (match Float.abs sweep >= 2. *. Float.pi with
      | false -> ()
      | true ->
          (* Exact: the platform recomputes stop - start, so a full turn that
             rounds below 2π reaches it as a partial arc. *)
          Alcotest.(check bool)
            "full turn survives the platform's subtraction" true
            (Float.abs (arc.stop -. arc.start) >= 2. *. Float.pi));
      Alcotest.(check (float sweep_tolerance))
        "sweep" sweep
        (platform_sweep ~start:arc.start ~stop:arc.stop
           ~anticlockwise:arc.anticlockwise)
  | _ -> Alcotest.fail "expected exactly a move, one arc and a line"

let check_invalid_row (row : Arc_cases.row) =
  match arc_row_calls row with
  | [ Move (mx, my); Line (lx, ly) ] ->
      Alcotest.(check (pair (float 0.) (float 0.)))
        "lead move kept" arc_lead (mx, my);
      Alcotest.(check (pair (float 0.) (float 0.)))
        "tail line kept" arc_tail (lx, ly)
  | _ -> Alcotest.fail "an invalid arc must add no call to the path"

let arc_table_case (row : Arc_cases.row) =
  Alcotest.test_case row.name `Quick (fun () ->
      match row.expected with
      | Arc_cases.Invalid -> check_invalid_row row
      | Arc_cases.Sweep sweep -> check_sweep_row row sweep)

(* An arc with no subpath before it: the renderer adds no move or line of its
   own, the platform's arc() starts the subpath. *)
let test_leading_arc_adds_only_the_arc () =
  match
    filled_path_calls
      [
        Nopal_scene.Path.arc_to ~cx:0. ~cy:0. ~r:1. ~start_angle:0.
          ~end_angle:1. ~direction:Nopal_scene.Path.Clockwise;
      ]
  with
  | [ Arc _ ] -> ()
  | _ -> Alcotest.fail "a leading arc must record exactly one arc call"

let test_line_after_invalid_arc_adds_no_move () =
  let invalid =
    Nopal_scene.Path.arc_to ~cx:0. ~cy:0. ~r:(-1.) ~start_angle:0. ~end_angle:1.
      ~direction:Nopal_scene.Path.Clockwise
  in
  (* The renderer inserts no move of its own: leaving a line with no subpath to
     become one is the platform's rule, which SVG output mirrors with an M. *)
  match filled_path_calls [ invalid; Nopal_scene.Path.line_to ~x:5. ~y:5. ] with
  | [ Line (x, y) ] ->
      Alcotest.(check (pair (float 0.) (float 0.))) "line kept" (5., 5.) (x, y)
  | _ -> Alcotest.fail "expected exactly the line call"

let () =
  Alcotest.run "canvas_renderer"
    [
      ( "clear",
        [
          Alcotest.test_case "full clear at dpr < 1" `Quick
            test_canvas_clears_below_unit_dpr;
        ] );
      ( "hidpi",
        [
          Alcotest.test_case "re-setup on dpr change" `Quick
            test_canvas_resetup_on_dpr_change;
        ] );
      ("canvas_renderer/arc_table", List.map arc_table_case Arc_cases.rows);
      ( "canvas_renderer/arc_invalid",
        [
          Alcotest.test_case "line after invalid arc adds no move" `Quick
            test_line_after_invalid_arc_adds_no_move;
          Alcotest.test_case "leading arc adds only the arc" `Quick
            test_leading_arc_adds_only_the_arc;
        ] );
    ]
