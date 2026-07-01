// Canvas 2D shim layered on top of dom_shim.js, so Canvas_renderer tests can
// run under Node.js via js_of_ocaml without a real browser.
//
// dom_shim.js provides document/createElement/style but no <canvas> backing
// store and no 2D context. This shim augments document.createElement: a
// "canvas" element gains integer width/height properties (the backing store
// Brr's Canvas.w/h read and set) and a getContext("2d") that returns a fake
// C2d which RECORDS the calls Canvas_renderer makes.
//
// The recorded state the tests assert on:
//   - ctx._lastClear.deviceW / deviceH — the clearRect region expressed in
//     device (backing-store) pixels, i.e. the logical rect multiplied by the
//     transform scale active at the time of the call. This is the oracle for
//     FR-7: a correct full clear must cover the whole backing store at ANY
//     devicePixelRatio, including dpr < 1 where a logical-rect clear leaves a
//     strip uncleared. We encode the BROWSER contract (clearRect is affected
//     by the current transform) so the renderer's under-clear fails loudly.
//   - canvas.width / canvas.height — the backing store, updated by setup_hidpi;
//     lets a dpr change be observed as a re-setup.
//
// Load order matters: dom_shim.js must run first (it defines document).
//
// ## Maintenance Checklist (run when upgrading Brr)
//
// Brr_canvas's C2d binding routes each call through Jv.call on the context
// object. If a Brr upgrade renames or re-routes any of the methods below,
// this shim under-records and the FR-7 tests silently weaken. Re-verify
// against _opam/lib/brr/brr_canvas.ml:
//   - C2d.get_context  -> canvas.getContext("2d", attrs)
//   - C2d.canvas       -> reads ctx.canvas
//   - C2d.save/restore -> ctx.save() / ctx.restore()
//   - C2d.reset_transform -> ctx.resetTransform()
//   - C2d.scale        -> ctx.scale(sx, sy)
//   - C2d.clear_rect   -> ctx.clearRect(x, y, w, h)
//   - Canvas.w/h/set_w/set_h -> canvas.width / canvas.height

(function () {
  const doc = globalThis.document;
  if (!doc) throw new Error("canvas_shim.js must load after dom_shim.js");
  const origCreate = doc.createElement;

  function makeContext(canvas) {
    const ctx = {
      canvas: canvas,
      // Active transform scale (device pixels per logical unit), as mutated by
      // scale/resetTransform and saved/restored by save/restore.
      _scaleX: 1,
      _scaleY: 1,
      _stack: [],
      _clearCount: 0,
      _lastClear: null,
      save() {
        ctx._stack.push([ctx._scaleX, ctx._scaleY]);
      },
      restore() {
        const s = ctx._stack.pop();
        if (s) {
          ctx._scaleX = s[0];
          ctx._scaleY = s[1];
        }
      },
      resetTransform() {
        ctx._scaleX = 1;
        ctx._scaleY = 1;
      },
      scale(sx, sy) {
        ctx._scaleX *= sx;
        ctx._scaleY *= sy;
      },
      clearRect(x, y, w, h) {
        ctx._clearCount++;
        ctx._lastClear = {
          x: x,
          y: y,
          w: w,
          h: h,
          deviceW: w * ctx._scaleX,
          deviceH: h * ctx._scaleY,
        };
      },
    };
    return ctx;
  }

  doc.createElement = function (tag) {
    const el = origCreate.call(doc, tag);
    if (String(tag).toLowerCase() === "canvas") {
      // Browser canvas defaults; set_w/set_h overwrite these.
      let _w = 300;
      let _h = 150;
      // _sizeWrites counts width/height assignments so a test can assert that
      // an unchanged (same logical size, same dpr) reconcile does NOT re-setup.
      el._sizeWrites = 0;
      Object.defineProperty(el, "width", {
        get() {
          return _w;
        },
        set(v) {
          _w = v | 0;
          el._sizeWrites++;
        },
        configurable: true,
      });
      Object.defineProperty(el, "height", {
        get() {
          return _h;
        },
        set(v) {
          _h = v | 0;
          el._sizeWrites++;
        },
        configurable: true,
      });
      let _ctx = null;
      el.getContext = function (kind) {
        if (String(kind) !== "2d") return null;
        if (!_ctx) {
          _ctx = makeContext(el);
          // C2d.t is abstract (no to_jv), so expose the recording context on
          // the canvas element for the OCaml test to read back.
          el._ctx = _ctx;
        }
        return _ctx;
      };
    }
    return el;
  };
})();
