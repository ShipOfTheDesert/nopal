// Minimal Tauri runtime stub for the nopal_tauri subscription / back-button
// tests (loaded via this test target's (javascript_files ...) list).
//
// `Platform_tauri.{on_safe_area_change, on_keyboard_height_change,
// safe_area_source, enable_hardware_back}` all reach `Event.listen`, which calls
// `__TAURI_INTERNALS__.transformCallback` and `__TAURI_INTERNALS__.invoke`. Under
// Node there is no Tauri host, so without this stub those setups throw before the
// behaviour under test (the synchronous degenerate-value dispatch / the
// idempotency guard) can be observed.
//
// It counts `plugin:event|listen` invocations on
// `globalThis.__nopal_listen_count` so the idempotency test can assert that a
// repeated `enable_hardware_back` registers no additional listener, and exposes
// `globalThis.__nopal_deliver(name, payload)` to synchronously invoke the
// handlers registered for `name` — mirroring how the real Tauri internals
// dispatch a host `app.emit` to in-webview listeners (payload arrives verbatim,
// including `null` for Rust unit payloads).
(function () {
  var nextId = 1;
  var callbacks = {}; // handler id -> raw Event.listen callback
  var listeners = {}; // event name -> [handler id]
  globalThis.__nopal_listen_count = 0;
  globalThis.__nopal_deliver = function (name, payload) {
    var ids = listeners[name] || [];
    for (var i = 0; i < ids.length; i++) {
      callbacks[ids[i]]({ event: name, id: ids[i], payload: payload });
    }
  };
  globalThis.__TAURI_INTERNALS__ = {
    // Real Tauri returns a numeric handler id and retains the callback; the id
    // is all `Event.listen` reads (`Jv.to_int`). The callback is retained so
    // `__nopal_deliver` can dispatch to it.
    transformCallback: function (cb) {
      var id = nextId++;
      callbacks[id] = cb;
      return id;
    },
    // `Ipc.invoke` calls this synchronously and awaits the returned Promise.
    // `plugin:event|listen` records the handler against the event name and
    // resolves to a numeric event id (Fut expects u32); every other command
    // resolves to 0.
    invoke: function (cmd, args) {
      if (cmd === "plugin:event|listen") {
        globalThis.__nopal_listen_count += 1;
        (listeners[args.event] = listeners[args.event] || []).push(
          args.handler
        );
        return Promise.resolve(nextId++);
      }
      return Promise.resolve(0);
    },
  };
})();
