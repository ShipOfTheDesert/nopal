// Supplementary shim for the mount/drive tests (loaded after dom_shim.js).
//
// `Nopal_web.drive` touches two browser APIs the base dom_shim does not cover,
// and one it covers in a way that is unsafe for a synchronous unit test:
//
//   - ResizeObserver: drive constructs `new ResizeObserver(cb)` and calls
//     `.observe(target)`. dom_shim has no ResizeObserver, so without this stub
//     drive throws at construction. The stub never fires the callback — viewport
//     changes are out of scope for these tests.
//
//   - requestAnimationFrame: dom_shim implements it as `setTimeout(cb, 0)`, and
//     drive's rAF callback reschedules itself every frame. Under Node that is an
//     infinite macrotask loop that prevents the test process from exiting. These
//     tests only assert on drive's synchronous startup (bridge install, initial
//     render, recording), never on a later frame, so we override rAF to a no-op.
//
// Scoped to this test target via its `(javascript_files ...)` list; the shared
// dom_shim.js is unchanged so the other nopal_web tests keep their rAF behaviour.

// The rAF and ResizeObserver callbacks are captured on globalThis
// (`__nopal_raf_cb` / `__nopal_resize_cb`) but never auto-invoked, so the rAF
// loop stays a no-op for tests that only assert on synchronous startup while
// tests that need to drive a frame or a resize (the safe-area passthrough) can
// fire them explicitly.
(function () {
  globalThis.requestAnimationFrame = function (cb) {
    globalThis.__nopal_raf_cb = cb;
    return 0;
  };
  globalThis.cancelAnimationFrame = function () {};
  if (typeof globalThis.ResizeObserver === "undefined") {
    globalThis.ResizeObserver = function (cb) {
      globalThis.__nopal_resize_cb = cb;
      return {
        observe: function () {},
        unobserve: function () {},
        disconnect: function () {},
      };
    };
  }
})();
