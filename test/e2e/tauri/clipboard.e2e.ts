import { $ } from "@wdio/globals";
import { NopalTelemetryTauri } from "./nopal-telemetry-tauri";

// Clipboard write: the Tauri clipboard-manager plugin is registered and its
// capability is granted. Dropping either turns the outcome into an Error, so
// waiting on the Ok token covers them. It does not cover main.ml selecting the
// Tauri handler (D-18, CONTRIBUTING.md): the web fallback also succeeds in the
// webview. The OS clipboard is deliberately never read back.

describe("Tauri clipboard write", () => {
  it("Copy reports a successful write", async () => {
    const telemetry = new NopalTelemetryTauri();

    await $('[data-testid="clipboard-copy"]').waitForExist({ timeout: 15000 });
    await $('[data-testid="clipboard-copy"]').click();

    await telemetry.assertDispatched("Clipboard:Copy_clicked;");
    await telemetry.assertDispatched("Clipboard:Copy_result:Ok;");
  });
});
