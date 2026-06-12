import { $, browser } from "@wdio/globals";
import { NopalTelemetryTauri } from "./nopal-telemetry-tauri";

// REQ-F4 / REQ-F5 (RFC 0116): the native mobile-signal bridge round-trips
// through real IPC. The Android `MainActivity` reads `WindowInsets` / the IME
// height and invokes the registered Rust commands `report_safe_area` /
// `report_keyboard_height`; each re-emits via `app.emit` (the only path that
// reaches the in-webview `plugin:event|listen` handlers the OCaml
// `Platform_tauri` subscriptions register). Here we drive those two commands
// directly — standing in for the Kotlin caller — and assert the value reaches
// the OCaml side.
//
// Two assertion surfaces, by design:
//   - keyboard height feeds `App.KeyboardHeightChanged`, a real message, so it
//     is proven via the host `get_telemetry` mirror (ADR 0108: telemetry is the
//     primary correctness contract).
//   - safe-area insets feed the *viewport* (via `mount`'s `safe_area_source`),
//     not a message, so there is no telemetry event to assert. Its observable
//     effect is render correctness — the live inset readout — which ADR 0108
//     reserves for DOM assertions. We read `[data-testid="safe-area-viz"]`.

// Invoke a registered command with an args object. Mirrors the tray/window
// specs' invoke surface (`__TAURI_INTERNALS__`, `__TAURI__.core` fallback).
async function invoke(cmd: string, args: Record<string, unknown>): Promise<void> {
  await browser.execute(
    async (command, commandArgs) => {
      const w = window as unknown as {
        __TAURI_INTERNALS__?: { invoke(c: string, a?: unknown): Promise<unknown> };
        __TAURI__?: { core?: { invoke(c: string, a?: unknown): Promise<unknown> } };
      };
      const fn =
        w.__TAURI_INTERNALS__?.invoke?.bind(w.__TAURI_INTERNALS__) ??
        w.__TAURI__?.core?.invoke?.bind(w.__TAURI__.core);
      if (fn) await fn(command, commandArgs);
    },
    cmd,
    args
  );
}

describe("Tauri mobile signals (REQ-F4 / REQ-F5)", () => {
  it("report_keyboard_height round-trips into KeyboardHeightChanged", async () => {
    const telemetry = new NopalTelemetryTauri();

    // Wait for the app to have mounted (its mobile section renders the readout).
    await $('[data-testid="keyboard-height"]').waitForExist({ timeout: 15000 });

    // Native IME read → report_keyboard_height → nopal:keyboard-height →
    // on_keyboard_height_change → KeyboardHeightChanged 336. The setup degenerate
    // dispatch is 0, so :336 cannot false-pass from startup.
    await invoke("report_keyboard_height", { payload: "336" });
    await telemetry.assertDispatched("KeyboardHeightChanged:336");

    // Keyboard hidden again → 0.
    await invoke("report_keyboard_height", { payload: "0" });
    await telemetry.assertDispatched("KeyboardHeightChanged:0");

    await telemetry.assertSequence([
      "KeyboardHeightChanged:336",
      "KeyboardHeightChanged:0",
    ]);
  });

  it("report_safe_area round-trips into the live inset readout", async () => {
    const viz = $('[data-testid="safe-area-viz"]');
    await viz.waitForExist({ timeout: 15000 });

    // Native WindowInsets read → report_safe_area → nopal:safe-area →
    // safe_area_source → viewport. The "Responsive Design" inset readout renders
    // each value as "<n>px"; assert the injected top/bottom surface there.
    await invoke("report_safe_area", { payload: "top=51;right=0;bottom=24;left=0;" });

    await browser.waitUntil(
      async () => {
        const text = await viz.getText();
        return text.includes("51px") && text.includes("24px");
      },
      {
        timeout: 10000,
        timeoutMsg: "safe-area readout never reflected the injected insets",
      }
    );
  });
});
