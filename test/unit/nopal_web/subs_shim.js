// Supplementary shim for test_subscriptions.ml (loaded after dom_shim.js).
//
// The subscription interpreter (Nopal_web.web_interpret_atom) registers
// window/document event listeners and setInterval timers via raw Jv calls that
// the base dom_shim does not provide on the global/document objects:
//
//   - window.addEventListener / removeEventListener / dispatchEvent: dom_shim
//     wires these onto element nodes only, not the window (globalThis) or
//     document objects. The keydown/keyup/resize interpreters listen on window;
//     visibility listens on document. This stub gives both objects a real
//     listener registry whose dispatchEvent fires the shimmed fake events
//     (which already carry preventDefault / defaultPrevented), so a test can
//     fire an event and assert on both dispatch and preventDefault.
//
//   - setInterval / clearInterval: the every interpreter schedules a repeating
//     timer. Node's real setInterval would keep the process alive and fire on
//     wall-clock time, neither suitable for a synchronous unit test. This stub
//     captures live interval callbacks in a registry; __nopal_fire_intervals
//     fires every live one and clearInterval removes it, so a test drives ticks
//     explicitly and a cleared interval provably stops firing.
//
// Scoped to the test_subscriptions target via its (javascript_files ...) list;
// the shared dom_shim.js is unchanged so other nopal_web tests are unaffected.
(function () {
  function makeListenerHost(host) {
    const listeners = {};
    host.addEventListener = function (type, fn) {
      (listeners[type] = listeners[type] || []).push(fn);
    };
    host.removeEventListener = function (type, fn) {
      const arr = listeners[type];
      if (arr) {
        const idx = arr.indexOf(fn);
        if (idx >= 0) arr.splice(idx, 1);
      }
    };
    host.dispatchEvent = function (ev) {
      const arr = listeners[ev.type];
      if (arr) for (const fn of [...arr]) fn(ev);
      return !ev.defaultPrevented;
    };
  }

  makeListenerHost(globalThis);
  makeListenerHost(globalThis.document);

  const intervals = {};
  let intervalId = 0;
  globalThis.setInterval = function (cb, _ms) {
    const id = ++intervalId;
    intervals[id] = cb;
    return id;
  };
  globalThis.clearInterval = function (id) {
    delete intervals[id];
  };
  globalThis.__nopal_fire_intervals = function () {
    let n = 0;
    for (const id in intervals) {
      intervals[id]();
      n++;
    }
    return n;
  };
})();
