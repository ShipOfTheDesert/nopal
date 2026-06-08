import { $, browser } from "@wdio/globals";
import { NopalTelemetryTauri } from "./nopal-telemetry-tauri";

// REQ-F5 (RFC 0112, Step 7 / Options Considered §4): a store value survives a
// real process relaunch.
//
// Relaunch semantics: the kitchen-sink intercepts window-close to *hide* (not
// quit), so closing the window would NOT restart the process. A genuine restart
// is a WebdriverIO `reloadSession()` — it tears down the WebDriver session, so
// tauri-driver kills the app binary and launches a fresh one. Session A's
// `save` flushes `nopal_store.json` to the app-data dir; session B is a new
// process that lazily reloads that file and reads the value back. We assert
// purely via each process's own `get_telemetry` mirror.

const KEY = "e2e-relaunch-key";
const VALUE = "e2e-relaunch-value-42";

describe("Tauri store (REQ-F5)", () => {
  it("store value survives a real relaunch", async () => {
    // ---- Session A: set + save, then the binary exits on session teardown ----
    const sessionA = new NopalTelemetryTauri();

    await $('[data-action="tauri-store-set"]').waitForExist({ timeout: 15000 });
    await $('[data-field="tauri-store-key"]').setValue(KEY);
    await $('[data-field="tauri-store-value"]').setValue(VALUE);

    await $('[data-action="tauri-store-set"]').click();
    await sessionA.assertDispatched("TauriStoreSet");
    await sessionA.assertDispatched("TauriStoreSetOk");

    await $('[data-action="tauri-store-save"]').click();
    // Gate the relaunch on the committed-to-disk signal, not the bare dispatch,
    // so the new process is guaranteed to see the persisted value.
    await sessionA.assertDispatched("TauriStoreSaveOk");

    // ---- Relaunch: fresh binary, fresh in-process telemetry mirror ----
    await browser.reloadSession();

    // ---- Session B: read the persisted value back from the new process ----
    const sessionB = new NopalTelemetryTauri();

    await $('[data-action="tauri-store-get"]').waitForExist({ timeout: 15000 });
    await $('[data-field="tauri-store-key"]').setValue(KEY);
    await $('[data-action="tauri-store-get"]').click();

    // The read-back value is carried on the Get-result message fragment, proving
    // persistence via the *new* process's mirror (the old one died with it).
    await sessionB.assertDispatched(`TauriStoreGetValue:${VALUE}`);
    await sessionB.assertModelContains(`tauri_store=${VALUE}`);
  });
});
