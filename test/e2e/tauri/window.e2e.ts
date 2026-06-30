import { $, browser } from "@wdio/globals";
import { NopalTelemetryTauri } from "./nopal-telemetry-tauri";

// REQ-F5 (RFC 0112, Step 7): window title + visibility transitions are
// observable through the host-side IPC telemetry mirror. We drive the real
// kitchen-sink controls (migrated to data-action/data-field anchors, REQ-F2)
// and assert the resulting messages and model transitions via `get_telemetry`,
// not the DOM.
//
// Ordering note: we end on `hide`, so no interaction is attempted against a
// hidden OS window. The title set and the visible→hidden transition are
// sufficient to prove the IPC path; `set-focus`/`show` are exercised elsewhere.

const NEW_TITLE = "Nopal E2E Window";

describe("Tauri window (REQ-F5)", () => {
  it("title and visibility transitions are observable via IPC telemetry", async () => {
    const telemetry = new NopalTelemetryTauri();

    // Wait for the window section to render before driving it.
    await $('[data-action="tauri-window-set-title"]').waitForExist({
      timeout: 15000,
    });

    // 1. Set the window title → message + model title transition.
    //    The field is a controlled input pre-filled with the default title.
    //    `setValue` (clearValue + addValue) clears the DOM only — under
    //    WebKitWebDriver the clear fires no `input` event, so the model keeps
    //    the old title and the typed text concatenates onto it. Delete to empty
    //    with real key events (each fires `input`), confirm the model reached
    //    empty, then type, so the model actually ends at NEW_TITLE.
    const titleField = $('[data-field="tauri-window-title"]');
    await titleField.click();
    await browser.keys("End");
    const existing = await titleField.getValue();
    await browser.keys(Array(existing.length).fill("Backspace"));
    await telemetry.assertModelContains('win_title=""');
    await titleField.addValue(NEW_TITLE);
    await $('[data-action="tauri-window-set-title"]').click();
    await telemetry.assertDispatched("SetTauriWindowTitle");
    await telemetry.assertModelContains(`win_title=${JSON.stringify(NEW_TITLE)}`);

    // 2. Query visibility → GotTauriVisible:true + model win_visible=true.
    await $('[data-action="tauri-window-query-visible"]').click();
    await telemetry.assertDispatched("QueryTauriVisible");
    await telemetry.assertDispatched("GotTauriVisible:true");
    await telemetry.assertModelContains("win_visible=true");

    // 3. Hide → message + the visible→hidden model transition (asserted last so
    //    we never click a control on a hidden window).
    await $('[data-action="tauri-window-hide"]').click();
    await telemetry.assertDispatched("HideTauriWindow");
    await telemetry.assertModelContains("win_visible=false");

    // Sequence across the whole interaction (in-order, gaps allowed).
    await telemetry.assertSequence([
      "SetTauriWindowTitle",
      "QueryTauriVisible",
      "HideTauriWindow",
    ]);

    // Restore visibility so a subsequent spec in the session starts clean.
    await browser.execute(async () => {
      const w = window as unknown as {
        __TAURI_INTERNALS__?: { invoke(c: string, a?: unknown): Promise<unknown> };
      };
      await w.__TAURI_INTERNALS__?.invoke("plugin:window|show", {
        label: "main",
      });
    });
  });
});
