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
// The stub never delivers a native event — only the synchronous setup path is
// exercised. It counts `plugin:event|listen` invocations on
// `globalThis.__nopal_listen_count` so the idempotency test can assert that a
// repeated `enable_hardware_back` registers no additional listener.
(function () {
  var nextId = 1;
  globalThis.__nopal_listen_count = 0;
  globalThis.__TAURI_INTERNALS__ = {
    // Real Tauri returns a numeric handler id and retains the callback; the id
    // is all `Event.listen` reads (`Jv.to_int`).
    transformCallback: function (_cb) {
      return nextId++;
    },
    // `Ipc.invoke` calls this synchronously and awaits the returned Promise.
    // `plugin:event|listen` resolves to a numeric event id (Fut expects u32);
    // every other command resolves to 0.
    invoke: function (cmd, _args) {
      if (cmd === "plugin:event|listen") {
        globalThis.__nopal_listen_count += 1;
        return Promise.resolve(nextId++);
      }
      return Promise.resolve(0);
    },
  };
})();
