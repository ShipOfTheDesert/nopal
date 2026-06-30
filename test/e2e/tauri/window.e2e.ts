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
    //    Native typing is hostile here: WebKitWebDriver's clearValue fires no
    //    `input` event (so the model keeps the old title and typed text
    //    concatenates), and array `browser.keys` deletes flake. Set the value
    //    and dispatch the `input` event the renderer listens for directly —
    //    deterministic, and it drives the same on_change path the UI uses.
    await browser.execute(
      (sel, value) => {
        const el = document.querySelector(sel) as HTMLInputElement | null;
        if (el === null) return;
        el.value = value;
        el.dispatchEvent(new Event("input", { bubbles: true }));
      },
      '[data-field="tauri-window-title"]',
      NEW_TITLE
    );
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
