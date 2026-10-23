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
//     the full clear: a correct full clear must cover the whole backing store at ANY
//     devicePixelRatio, including dpr < 1 where a logical-rect clear leaves a
//     strip uncleared. We encode the BROWSER contract (clearRect is affected
//     by the current transform) so the renderer's under-clear fails loudly.
//   - canvas.width / canvas.height — the backing store, updated by setup_hidpi;
//     lets a dpr change be observed as a re-setup.
//   - ctx._lastFill / ctx._lastStroke — the Path2D most recently filled or
//     stroked. Its _calls lists every moveTo, lineTo, arc and closePath made on
//     it, in order. An arc records all six arguments; an omitted anticlockwise
//     is recorded as false, the platform default, so a renderer that forgets
//     to pass it is seen running clockwise.
//
// Load order matters: dom_shim.js must run first (it defines document).
//
// ## Maintenance Checklist (run when upgrading Brr)
//
// Brr_canvas's C2d binding routes each call through Jv.call on the context
// object. If a Brr upgrade renames or re-routes any of the methods below,
// this shim under-records and the clear and arc tests silently weaken. Re-verify
// against _opam/lib/brr/brr_canvas.ml:
//   - C2d.get_context  -> canvas.getContext("2d", attrs)
//   - C2d.canvas       -> reads ctx.canvas
//   - C2d.save/restore -> ctx.save() / ctx.restore()
//   - C2d.reset_transform -> ctx.resetTransform()
//   - C2d.scale        -> ctx.scale(sx, sy)
//   - C2d.clear_rect   -> ctx.clearRect(x, y, w, h)
//   - Canvas.w/h/set_w/set_h -> canvas.width / canvas.height
//   - C2d.fill / C2d.stroke -> ctx.fill(path, rule) / ctx.stroke(path)
//   - C2d.Path.create  -> new Path2D() (Brr reads globalThis.Path2D at load)
//   - C2d.Path.move_to -> path.moveTo(x, y)
//   - C2d.Path.line_to -> path.lineTo(x, y)
//   - C2d.Path.arc     -> path.arc(cx, cy, r, start, stop, anticlockwise)
//   - C2d.Path.ccurve_to -> path.bezierCurveTo(cx, cy, cx', cy', x, y)
//   - C2d.Path.qcurve_to -> path.quadraticCurveTo(cx, cy, x, y)
//   - C2d.Path.close   -> path.closePath()

(function () {
  const doc = globalThis.document;
  if (!doc) throw new Error("canvas_shim.js must load after dom_shim.js");
  const origCreate = doc.createElement;

  globalThis.Path2D = function Path2D() {
    this._calls = [];
  };
  Path2D.prototype.moveTo = function (x, y) {
    this._calls.push({ op: "moveTo", x: x, y: y });
  };
  Path2D.prototype.lineTo = function (x, y) {
    this._calls.push({ op: "lineTo", x: x, y: y });
  };
  Path2D.prototype.arc = function (cx, cy, r, start, stop, anticlockwise) {
    this._calls.push({
      op: "arc",
      cx: cx,
      cy: cy,
      r: r,
      start: start,
      stop: stop,
      anticlockwise: anticlockwise === undefined ? false : !!anticlockwise,
    });
  };
  Path2D.prototype.bezierCurveTo = function (c1x, c1y, c2x, c2y, x, y) {
    this._calls.push({
      op: "bezierCurveTo",
      c1x: c1x,
      c1y: c1y,
      c2x: c2x,
      c2y: c2y,
      x: x,
      y: y,
    });
  };
  Path2D.prototype.quadraticCurveTo = function (cx, cy, x, y) {
    this._calls.push({ op: "quadraticCurveTo", cx: cx, cy: cy, x: x, y: y });
  };
  Path2D.prototype.closePath = function () {
    this._calls.push({ op: "closePath" });
  };

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
      _lastFill: null,
      _lastStroke: null,
      fill(path) {
        ctx._lastFill = path;
      },
      stroke(path) {
        ctx._lastStroke = path;
      },
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
