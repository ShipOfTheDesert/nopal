// Minimal Tauri runtime stub for the nopal_tauri subscription / back-button /
// Tauri_subscription tests (loaded via each test target's (javascript_files)).
//
// `Platform_tauri.{on_safe_area_change, on_keyboard_height_change,
// safe_area_source, enable_hardware_back}` and `Tauri_subscription.make` all
// reach the Tauri event IPC, which calls `__TAURI_INTERNALS__.transformCallback`
// and `__TAURI_INTERNALS__.invoke`. Under Node there is no Tauri host, so without
// this stub those setups throw before the behaviour under test can be observed.
//
// It exposes:
//   - `__nopal_listen_count`: count of `plugin:event|listen` invocations, so the
//     idempotency test can assert a repeated `enable_hardware_back` registers no
//     additional listener.
//   - `__nopal_deliver(name, payload)`: synchronously invoke the handlers
//     registered for `name`, mirroring how Tauri dispatches a host `app.emit` to
//     in-webview listeners (payload arrives verbatim, including `null` for Rust
//     unit payloads).
//   - `__nopal_unlisten_count`: count of `plugin:event|unlisten` invocations.
//   - `__nopal_console_errors`: captured `console.error` messages (Brr.Console's
//     output, i.e. the runtime on_error default path under jsoo).
//   - `__nopal_resolve_listen()` / `__nopal_reject_listen()`: drive the in-flight
//     `plugin:event|listen` resolutions. `invoke` returns a SYNCHRONOUS thenable
//     whose `.then` stores its continuations, so a test resolves/rejects the
//     registration explicitly and the OCaml `then'` continuation fires
//     synchronously (real Tauri returns a genuine async Promise here — that
//     async window is exactly what Tauri_subscription's state machine guards).
//   - `__nopal_reset_subs()`: reset the per-test counters and pending queue.
//   - `__nopal_set_invoke_failure(bool)`: when true, every non-listen/unlisten
//     `invoke` rejects SYNCHRONOUSLY with a serde-style plain string (the shape
//     tauri-plugin command errors take), so the result-typed Window/App/Event
//     ops (REQ-F5) resolve `Error` observably inside a synchronous Alcotest case
//     instead of hanging. Default false; reset by `__nopal_reset_subs`.
//   - `__nopal_set_os_platform(str)`: define `__TAURI_OS_PLUGIN_INTERNALS__`
//     with the given `platform` string so `Os.platform` can be driven to its
//     unknown-platform `Error` path.
(function () {
  var nextId = 1;
  var callbacks = {}; // handler id -> raw Event.listen callback
  var listeners = {}; // event name -> [handler id]
  var pendingListens = []; // [{onF, onR}] awaiting explicit resolution
  var stores = {}; // store rid -> { key: value } (plugin:store mock, REQ-F6)
  var nextStoreRid = 9000;
  // Host-side telemetry mirror model (RFC 0110 Layer 3 / feature 0120 FR-7). A
  // small cap keeps the drop-oldest bound cheap to exercise; it models the real
  // Rust `TelemetryMirror` drop-oldest semantics, not its production N.
  var telemetryMirror = [];
  var TELEMETRY_CAP = 4;
  globalThis.__nopal_telemetry_cap = TELEMETRY_CAP;
  globalThis.__nopal_listen_count = 0;
  globalThis.__nopal_unlisten_count = 0;
  globalThis.__nopal_console_errors = [];
  globalThis.__nopal_fail_invoke = false;

  // Capture Brr.Console.error output (the runtime on_error default path under
  // jsoo) so a test can assert a registration failure was reported. Recorded
  // rather than re-printed: a test that deliberately fails a registration would
  // otherwise dump an alarming stack trace into the test log.
  if (!globalThis.console) globalThis.console = {};
  globalThis.console.error = function () {
    globalThis.__nopal_console_errors.push(String(arguments[0]));
  };

  globalThis.__nopal_deliver = function (name, payload) {
    var ids = listeners[name] || [];
    for (var i = 0; i < ids.length; i++) {
      callbacks[ids[i]]({ event: name, id: ids[i], payload: payload });
    }
  };
  globalThis.__nopal_resolve_listen = function () {
    var q = pendingListens;
    pendingListens = [];
    for (var i = 0; i < q.length; i++) {
      q[i].onF(nextId++);
    }
    return q.length;
  };
  globalThis.__nopal_reject_listen = function () {
    var q = pendingListens;
    pendingListens = [];
    for (var i = 0; i < q.length; i++) {
      q[i].onR(new Error("listen rejected by test"));
    }
    return q.length;
  };
  globalThis.__nopal_reset_subs = function () {
    pendingListens = [];
    stores = {};
    telemetryMirror = [];
    globalThis.__nopal_unlisten_count = 0;
    globalThis.__nopal_console_errors = [];
    globalThis.__nopal_fail_invoke = false;
  };
  globalThis.__nopal_set_invoke_failure = function (fail) {
    globalThis.__nopal_fail_invoke = fail;
  };
  globalThis.__nopal_set_os_platform = function (platform) {
    globalThis.__TAURI_OS_PLUGIN_INTERNALS__ = { platform: platform };
  };
  // Push an event into the host mirror, dropping the oldest past TELEMETRY_CAP
  // (drop-oldest), mirroring the bounded Rust `TelemetryMirror` (feature 0120).
  globalThis.__nopal_seed_telemetry = function (kind, value) {
    telemetryMirror.push({ kind: kind, value: value });
    if (telemetryMirror.length > TELEMETRY_CAP) telemetryMirror.shift();
  };

  globalThis.__TAURI_INTERNALS__ = {
    // Real Tauri returns a numeric handler id and retains the callback; the id
    // is all the listen path reads (`Jv.to_int`). The callback is retained so
    // `__nopal_deliver` can dispatch to it.
    transformCallback: function (cb) {
      var id = nextId++;
      callbacks[id] = cb;
      return id;
    },
    invoke: function (cmd, args) {
      if (cmd === "plugin:event|listen") {
        globalThis.__nopal_listen_count += 1;
        (listeners[args.event] = listeners[args.event] || []).push(
          args.handler
        );
        // A synchronous thenable: `.then` records its continuations rather than
        // resolving, so a test drives registration explicitly. The returned
        // inner thenable satisfies promise chaining (`Fut`/`then'` ignore it).
        return {
          then: function (onF, onR) {
            pendingListens.push({ onF: onF, onR: onR });
            return { then: function () {} };
          },
        };
      }
      if (cmd === "plugin:event|unlisten") {
        globalThis.__nopal_unlisten_count += 1;
        return Promise.resolve(0);
      }
      // tauri-plugin-store v2 (REQ-F6): rid-keyed key-value store. `load`
      // returns a fresh resource id and creates the backing map; every other
      // command threads `args.rid`. Resolved through the same SYNCHRONOUS
      // thenable so a round-trip settles inside a synchronous test; a real
      // host resolves these asynchronously. `__nopal_fail_invoke` rejects so
      // the rid-keyed failure path is observable. `get` resolves the v2
      // `[value, found]` pair; `delete` resolves the existed flag.
      if (cmd.indexOf("plugin:store|") === 0) {
        var sub = cmd.slice("plugin:store|".length);
        return {
          then: function (onF, onR) {
            if (globalThis.__nopal_fail_invoke) {
              onR("simulated tauri failure: " + cmd);
              return { then: function () {} };
            }
            if (sub === "load") {
              var rid = nextStoreRid++;
              stores[rid] = {};
              onF(rid);
            } else {
              var st = stores[args.rid] || {};
              var has = Object.prototype.hasOwnProperty.call(st, args.key);
              if (sub === "set") {
                st[args.key] = args.value;
                onF(null);
              } else if (sub === "get") {
                onF([has ? st[args.key] : null, has]);
              } else if (sub === "delete") {
                delete st[args.key];
                onF(has);
              } else if (sub === "clear") {
                stores[args.rid] = {};
                onF(null);
              } else {
                // save (and any other rid-keyed command): no readback value.
                onF(null);
              }
            }
            return { then: function () {} };
          },
        };
      }
      // Host-side telemetry mirror read (RFC 0110 Layer 3 / feature 0120 FR-7).
      // Returns a NON-draining clone of the bounded mirror — modelling the Rust
      // `get_telemetry`, which returns `log.clone()` and never drains — so the
      // OCaml `Nopal_tauri.Telemetry.get_telemetry` consumer is exercised against
      // the agreed host contract. Resolved through the same synchronous thenable.
      if (cmd === "get_telemetry") {
        var snapshot = telemetryMirror.slice();
        return {
          then: function (onF, onR) {
            if (globalThis.__nopal_fail_invoke) onR("simulated tauri failure: " + cmd);
            else onF(snapshot);
            return { then: function () {} };
          },
        };
      }
      // Every other command (Window/App/Event.emit ops) returns a SYNCHRONOUS
      // thenable so a result-typed op resolves observably inside a synchronous
      // test: success calls `onF(0)`, and `__nopal_fail_invoke` rejects via
      // `onR` with a serde-style plain string (the shape the real plugin sends
      // for a command error). A real Tauri host returns a genuine async Promise
      // here; the single `then'` on the OCaml side settles either way.
      return {
        then: function (onF, onR) {
          if (globalThis.__nopal_fail_invoke) {
            onR("simulated tauri failure: " + cmd);
          } else {
            onF(0);
          }
          return { then: function () {} };
        },
      };
    },
  };
})();
