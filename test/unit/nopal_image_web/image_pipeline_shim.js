// Fake browser image pipeline, so the canvas bindings and the processing
// pipeline can run under Node.js via js_of_ocaml without a real browser.
//
// This is a NEW fake rather than an extension of test/unit/nopal_web/canvas_shim.js:
// that one models the mounted-canvas lifecycle (backing-store sizing, transform
// tracking, clearRect in device pixels) and records nothing at all for decode,
// draw, encode or pixel read, which are the only four calls this pipeline makes.
//
// It is self-contained: it installs its own `document` when there is none, so no
// dom_shim.js is needed. Load it alone.
//
// ## What it records — globalThis.__imagePipeline
//
//   calls        ordered stage names: "decode" | "draw" | "encode" | "pixels"
//                | "release". The pipeline's observable sequence. A stage is
//                recorded when the pipeline CALLS it, not when the answer comes
//                back, so the sequence is the same whether an answer is
//                deferred or not.
//   draws        one { width, height } per drawImage, in call order — the target
//                size, which is what distinguishes the upload pass from the
//                metric pass.
//   encodes      one { mime, quality, qualityType } per toBlob.
//   pixelReads   count of COMPLETED getImageData calls (a throwing one records
//                its attempt in `calls` but crosses no pixels).
//   releases     count of ImageBitmap.close() calls.
//   source       { width, height } the next decode yields. reset() sets it to
//                0 x 0 so a test that forgets to state its fixture fails loudly
//                rather than inheriting a plausible size.
//   fail         per-stage injection switches for the way the PLATFORM fails
//                that stage: createImageBitmap rejects, getContext("2d")
//                returns null, toBlob calls back with null, getImageData
//                throws. `fail.contextForWidth` starves ONE canvas rather than
//                every canvas — see below.
//   throws       per-stage injection switches for a SYNCHRONOUS refusal,
//                carrying a message that names no stage at all. A browser
//                refuses each of these calls synchronously in real conditions
//                — a missing API is a TypeError, a tainted canvas is a
//                SecurityError — and the neutral message is what makes a
//                classifier that substring-matched the text fail: only the
//                stage that raised can name the arm.
//   rejectWith   the SHAPE the injected decode rejection carries. A rejected
//                promise is not required to carry an Error, and the binding
//                that turns one into a sentence has an arm per shape:
//                  "error"             new Error(state.rejection)   [default]
//                  "nothing"           undefined
//                  "bare-string"       state.rejection, as a plain string
//                  "nonstring-message" an object whose `message` is a number
//                                      and whose toString is state.rejection
//                The last two are what a `message` property read with an
//                unchecked cast would get wrong.
//
// ## Asynchrony — globalThis.__imagePipeline.flush()
//
//   createImageBitmap and toBlob answer on a LATER turn, as they do in a
//   browser: each parks its continuation on a queue instead of calling it
//   before returning. flush() drains that queue, running continuations in the
//   order they were parked and including any parked while draining, and a test
//   calls it after starting the pipeline.
//
//   This is the difference that matters, not a detail: with a synchronous
//   answer, every delivery happens inside the task body's own exception guard,
//   and the window where a browser continuation delivers ALONGSIDE an outcome
//   its region already produced cannot be reached at all. Parking makes the
//   guard have returned by the time the continuation runs, which is the real
//   interleaving. A synchronous fake is the convenient choice here, not the
//   platform's, so it is not the one taken.
//
// ## Where it deliberately models the browser rather than the convenient thing
//
//   - A fresh canvas element starts at the browser's real 300 x 150 default
//     backing store. A create_canvas that forgets to write width/height is
//     therefore visible, instead of silently getting the size it wanted.
//   - getImageData returns sw * sh * 4 bytes taken from its ARGUMENTS, which is
//     what the real API does (out-of-bounds region is padded, not clipped).
//   - The encoded blob's byte length is deliberately unrelated to any config
//     number, so a result that echoes the request instead of measuring the
//     produced blob cannot pass.
//   - Each stage fails the way the platform fails it: createImageBitmap
//     REJECTS, getContext("2d") returns NULL, toBlob calls back with NULL,
//     getImageData THROWS. A fake whose getContext can never return null makes
//     the canvas-unavailable arm unreachable.
//   - fail.contextForWidth starves the canvas of one given width rather than
//     every canvas. The pipeline allocates two canvases at two different sizes,
//     so a switch that starved both could only ever exercise whichever comes
//     first, leaving the second pass's failure arm unreachable.
//   - throws.bitmap refuses the decoded image's own width/height. A decoded
//     image can be questioned and refuse — a bitmap detached by another holder
//     does exactly that — and it is the one refusal that happens after the
//     decode with no canvas in play.
//
// ## Where it deliberately does not model the browser
//
//   flush() drains to quiescence synchronously rather than yielding to a real
//   microtask queue, so a test can assert after it without an async harness.
//   What that costs is ordering BETWEEN the queue and other event sources —
//   nothing in this pipeline has any — not the turn boundary itself, which is
//   modelled.
//
// ## Maintenance checklist (run when the bindings change)
//
// canvas_ffi.ml reaches these names and nothing else. If a binding is renamed
// or re-routed and this shim is not updated, it under-records and the tests
// silently weaken. Re-verify against backends/nopal_image_web/canvas_ffi.ml:
//   - decode        -> globalThis.createImageBitmap(blob)
//   - bitmap_width  -> bitmap.width / bitmap.height
//   - release       -> bitmap.close()
//   - create_canvas -> document.createElement("canvas"), then .width / .height
//   - context_2d    -> canvas.getContext("2d")
//   - draw          -> ctx.drawImage(bitmap, 0, 0, w, h)
//   - encode        -> canvas.toBlob(cb, mime, quality)
//   - read_pixels   -> ctx.canvas.width / .height, then ctx.getImageData(...)

(function () {
  // The message every injected synchronous refusal carries. It deliberately
  // names no stage, no API and no failure kind, so nothing downstream can
  // recover the stage by reading it.
  const REFUSAL = "the platform refused this call for a reason it does not name";

  // The words an injected decode rejection carries, whatever shape it takes.
  const REJECTION = "the shim was asked to fail the decode";

  // A parked continuation that is still parked after this many drain steps
  // means the queue is feeding itself; failing loudly beats a test hanging.
  const DRAIN_LIMIT = 1000;

  const state = {
    calls: [],
    draws: [],
    encodes: [],
    pixelReads: 0,
    releases: 0,
    source: { width: 0, height: 0 },
    pending: [],
    rejectWith: "error",
    fail: {
      decode: false,
      context: false,
      contextForWidth: 0,
      encode: false,
      pixels: false,
    },
    throws: {
      decode: false,
      bitmap: false,
      context: false,
      encode: false,
      pixels: false,
    },
  };

  state.reset = function () {
    state.calls.length = 0;
    state.draws.length = 0;
    state.encodes.length = 0;
    state.pixelReads = 0;
    state.releases = 0;
    state.source = { width: 0, height: 0 };
    state.pending.length = 0;
    state.rejectWith = "error";
    state.fail = {
      decode: false,
      context: false,
      contextForWidth: 0,
      encode: false,
      pixels: false,
    };
    state.throws = {
      decode: false,
      bitmap: false,
      context: false,
      encode: false,
      pixels: false,
    };
  };

  // Runs every parked continuation, including ones parked while draining, in
  // the order they were parked. reset() empties the queue instead of running
  // it, so a case that never flushed cannot leak work into the next one.
  state.flush = function () {
    let steps = 0;
    while (state.pending.length > 0) {
      steps++;
      if (steps > DRAIN_LIMIT) {
        throw new Error("the shim's deferred queue did not drain");
      }
      const next = state.pending.shift();
      next();
    }
  };

  // Published so a test can assert the browser's own words reached the caller
  // without restating the sentence and letting the two drift apart. reset()
  // leaves them alone: they are constants, not fixture state.
  state.refusal = REFUSAL;
  state.rejection = REJECTION;

  globalThis.__imagePipeline = state;

  // The value an injected decode rejection carries. A rejection is whatever the
  // rejecting code passed, so every shape here is one a browser or a library
  // can actually produce.
  function rejectionValue() {
    switch (state.rejectWith) {
      case "nothing":
        return undefined;
      case "bare-string":
        return REJECTION;
      case "nonstring-message":
        return {
          message: 42,
          toString: function () {
            return REJECTION;
          },
        };
      default:
        return new Error(REJECTION);
    }
  }

  function makeBitmap(width, height) {
    return {
      get width() {
        if (state.throws.bitmap) throw new Error(REFUSAL);
        return width;
      },
      get height() {
        if (state.throws.bitmap) throw new Error(REFUSAL);
        return height;
      },
      close: function () {
        state.calls.push("release");
        state.releases++;
      },
    };
  }

  // A real createImageBitmap reads the size out of the encoded bytes. Node
  // decodes nothing, so the size comes from state.source instead — which keeps
  // the property that matters: the decoded size is NOT derived from anything
  // the pipeline passes in, so a pipeline echoing its own config cannot match it.
  globalThis.createImageBitmap = function (_blob) {
    state.calls.push("decode");
    if (state.throws.decode) throw new Error(REFUSAL);
    const rejected = state.fail.decode;
    const bitmap = makeBitmap(state.source.width, state.source.height);
    // A thenable rather than a real promise: the binding bridges the decode
    // with one `.then` hop, and parking the continuation is what puts it on a
    // later turn without a scheduler.
    return {
      then: function (onFulfilled, onRejected) {
        state.pending.push(function () {
          if (rejected) onRejected(rejectionValue());
          else onFulfilled(bitmap);
        });
      },
    };
  };

  function makeContext(canvas) {
    return {
      canvas: canvas,
      drawImage: function (image, _dx, _dy, dw, dh) {
        state.calls.push("draw");
        state.draws.push({
          width: dw,
          height: dh,
          sourceWidth: image.width,
          sourceHeight: image.height,
        });
      },
      getImageData: function (sx, sy, sw, sh) {
        state.calls.push("pixels");
        if (state.throws.pixels) throw new Error(REFUSAL);
        if (state.fail.pixels) {
          throw new Error("the shim was asked to fail the pixel read");
        }
        state.pixelReads++;
        return {
          x: sx,
          y: sy,
          width: sw,
          height: sh,
          data: new Uint8ClampedArray(sw * sh * 4),
        };
      },
    };
  }

  function makeCanvas() {
    // The browser's default backing store, not the size anyone asked for.
    let width = 300;
    let height = 150;
    let context = null;
    const canvas = {
      get width() {
        return width;
      },
      set width(v) {
        width = v | 0;
      },
      get height() {
        return height;
      },
      set height(v) {
        height = v | 0;
      },
      getContext: function (kind) {
        if (String(kind) !== "2d") return null;
        if (state.throws.context) throw new Error(REFUSAL);
        if (state.fail.context) return null;
        if (state.fail.contextForWidth === width) return null;
        if (!context) context = makeContext(canvas);
        return context;
      },
      toBlob: function (callback, mime, quality) {
        state.calls.push("encode");
        state.encodes.push({
          mime: mime,
          quality: quality,
          qualityType: typeof quality,
        });
        if (state.throws.encode) throw new Error(REFUSAL);
        const failed = state.fail.encode;
        // The size is read now, not when the continuation runs: a real encoder
        // has already sampled the backing store by the time it calls back.
        const encodedWidth = width;
        state.pending.push(function () {
          if (failed) return callback(null);
          // Length chosen to track the canvas but match no config value.
          const bytes = new Uint8Array(encodedWidth * 3 + 7);
          callback(new Blob([bytes], { type: mime }));
        });
      },
    };
    return canvas;
  }

  if (!globalThis.document) globalThis.document = {};
  const doc = globalThis.document;
  const originalCreateElement = doc.createElement;
  doc.createElement = function (tag) {
    if (String(tag).toLowerCase() === "canvas") return makeCanvas();
    if (originalCreateElement) return originalCreateElement.call(doc, tag);
    return {};
  };
})();
