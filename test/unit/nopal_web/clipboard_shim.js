// Supplementary shim for test_mount_clipboard.ml (loaded after dom_shim.js and
// mount_shim.js).
//
// dom_shim's navigator has no `clipboard`, which is what a browser answers on
// an insecure origin, so a page that installs nothing here sees the
// asynchronous Clipboard API as absent. `__nopal_clipboard.install(mode, ...)`
// replaces `navigator.clipboard` with one of the shapes a browser can present:
//
//   - "absent":         no `navigator.clipboard` at all
//   - "no_write_text":  a clipboard object without `writeText`
//   - "resolve":        `writeText` fulfils
//   - "reject":         `writeText` rejects with a DOMException (name, message)
//   - "reject_none":    `writeText` rejects with no reason at all
//   - "reject_null":    `writeText` rejects with null
//   - "reject_string":  `writeText` rejects with a bare string (message)
//   - "throw_string":   `writeText` throws a bare string (message), not an Error
//   - "throw":          `writeText` throws a TypeError (message) synchronously
//   - "reject_then_throw": `writeText` returns a promise already rejected with
//                       NotAllowedError, whose `then` accepts the callbacks and
//                       then throws (message) — two candidate outcomes for one
//                       write, one before the caller's code returns and one on
//                       a later turn
//
// Every installed `writeText` records the text it was called with in `calls`
// at the moment it is called, and refuses a call whose receiver is not the
// clipboard object, as a browser's does ("Illegal invocation").
//
// Settlement never happens before `writeText` returns: a promise's callbacks
// are parked on `pending` and run only when the test calls `flush()`, which
// drains to quiescence behind a step cap. That is the turn boundary a real
// promise has, made explicit so the test needs no async harness. What it does
// not model is ordering between this queue and any other event source.
(function () {
  const DRAIN_LIMIT = 100;
  const state = { calls: [], pending: [] };

  function parked(settle) {
    return {
      then: function (onFulfilled, onRejected) {
        state.pending.push(function () {
          settle(onFulfilled, onRejected);
        });
      },
    };
  }

  function clipboardWith(behaviour) {
    const clipboard = {};
    clipboard.writeText = function (text) {
      if (this !== clipboard) throw new TypeError("Illegal invocation");
      state.calls.push(text);
      return behaviour();
    };
    return clipboard;
  }

  state.install = function (mode, name, message) {
    state.calls = [];
    state.pending = [];
    const nav = globalThis.navigator;
    switch (mode) {
      case "absent":
        delete nav.clipboard;
        break;
      case "no_write_text":
        nav.clipboard = {};
        break;
      case "resolve":
        nav.clipboard = clipboardWith(function () {
          return parked(function (onFulfilled) {
            onFulfilled(undefined);
          });
        });
        break;
      case "reject":
        nav.clipboard = clipboardWith(function () {
          return parked(function (_onFulfilled, onRejected) {
            onRejected(new DOMException(message, name));
          });
        });
        break;
      case "reject_none":
        nav.clipboard = clipboardWith(function () {
          return parked(function (_onFulfilled, onRejected) {
            onRejected(undefined);
          });
        });
        break;
      case "reject_null":
        nav.clipboard = clipboardWith(function () {
          return parked(function (_onFulfilled, onRejected) {
            onRejected(null);
          });
        });
        break;
      case "reject_string":
        nav.clipboard = clipboardWith(function () {
          return parked(function (_onFulfilled, onRejected) {
            onRejected(message);
          });
        });
        break;
      case "throw_string":
        nav.clipboard = clipboardWith(function () {
          throw message;
        });
        break;
      case "throw":
        nav.clipboard = clipboardWith(function () {
          throw new TypeError(message);
        });
        break;
      case "reject_then_throw":
        nav.clipboard = clipboardWith(function () {
          return {
            then: function (_onFulfilled, onRejected) {
              state.pending.push(function () {
                onRejected(new DOMException("denied", "NotAllowedError"));
              });
              throw new Error(message);
            },
          };
        });
        break;
      default:
        throw new Error("clipboard_shim: unknown mode " + mode);
    }
  };

  state.flush = function () {
    let steps = 0;
    while (state.pending.length > 0) {
      if (++steps > DRAIN_LIMIT) throw new Error("the queue did not drain");
      state.pending.shift()();
    }
  };

  globalThis.__nopal_clipboard = state;
})();
