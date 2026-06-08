import { browser } from "@wdio/globals";
import { NopalTelemetryTauri } from "./nopal-telemetry-tauri";

// REQ-F5 (RFC 0112, Step 7): a synthetic tray click round-trips through real IPC
// into an MVU message. `simulate_tray_click` (registered Rust command) emits the
// same `nopal:tray-click` event a real tray click would; the kitchen-sink
// subscription `Nopal_tauri.Tray.on_click App.TrayClicked` turns that into the
// `TrayClicked` message, which `Telemetry.expose` mirrors to the host log. We
// assert via that host mirror — never the DOM — so this proves the IPC path the
// browser-only specs cannot.

async function invoke(cmd: string): Promise<void> {
  await browser.execute(async (command) => {
    const w = window as unknown as {
      __TAURI_INTERNALS__?: { invoke(c: string): Promise<unknown> };
      __TAURI__?: { core?: { invoke(c: string): Promise<unknown> } };
    };
    const fn =
      w.__TAURI_INTERNALS__?.invoke?.bind(w.__TAURI_INTERNALS__) ??
      w.__TAURI__?.core?.invoke?.bind(w.__TAURI__.core);
    if (fn) await fn(command);
  }, cmd);
}

describe("Tauri tray (REQ-F5)", () => {
  it("simulate_tray_click produces the tray message", async () => {
    const telemetry = new NopalTelemetryTauri();

    await invoke("simulate_tray_click");

    // The mirror is fed asynchronously after the emit; assertDispatched polls.
    await telemetry.assertDispatched("TrayClicked");
  });
});
