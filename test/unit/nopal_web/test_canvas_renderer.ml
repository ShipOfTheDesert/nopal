(* FR-7: canvas must fully clear the previous frame at any devicePixelRatio
   (including dpr < 1), and re-apply hidpi scaling when the dpr changes — not
   only when the logical size changes.

   These tests drive Canvas_renderer through the fake C2d in canvas_shim.js,
   which records clearRect in device (backing-store) pixels and tracks the
   active transform scale. See canvas_shim.js for the oracle rationale. *)

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

(* FR-7: at dpr < 1 the clear must cover the full backing store, not the
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

(* FR-7: a devicePixelRatio change with an unchanged logical size must re-run
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
    ]
