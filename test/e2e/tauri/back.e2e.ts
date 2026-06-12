import { $, browser } from "@wdio/globals";
import { NopalTelemetryTauri } from "./nopal-telemetry-tauri";

// REQ-F3 (RFC 0116): the Android hardware-back button round-trips through real
// IPC into a router pop. `simulate_back_pressed` (registered Rust command) emits
// the same `nopal:back-pressed` event a real hardware back press would; the
// kitchen-sink's `Platform_tauri.enable_hardware_back` listener turns that into
// `window.history.back()`, whose `popstate` drives the back-demo's
// `Router.on_navigate` consumer to dispatch `Route_changed`. We assert via the
// host `get_telemetry` mirror — never the DOM — so this proves the full
// `nopal:back-pressed → history.back() → popstate → on_navigate → Route_changed`
// chain the browser-only `router-navigation.spec.ts` cannot reach (it has no
// Tauri-event source).
//
// We first push the demo to `Back_detail` (and assert the model moved there) so
// the post-back return to `Back_home` is a genuine pop, not the initial route
// false-passing the assertion.

// Mirror of the tray spec's invoke helper: the kitchen-sink runs under Tauri, so
// the low-level invoke surface is on `__TAURI_INTERNALS__` (with the older
// `__TAURI__.core` shape as a fallback).
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

describe("Tauri back button (REQ-F3)", () => {
  it("simulate_back_pressed navigates the router back", async () => {
    const telemetry = new NopalTelemetryTauri();

    // Wait for the back-demo section to render before driving it.
    await $('[data-action="back-demo-push"]').waitForExist({ timeout: 15000 });

    // 1. Push one step deep → Back_demo_push + the Home→Detail model transition.
    //    Asserting the model reached Back_detail makes the later return to
    //    Back_home a real pop, not the untouched initial route.
    await $('[data-action="back-demo-push"]').click();
    await telemetry.assertDispatched("Back_demo_push");
    await telemetry.assertModelContains("back_route=Back_detail;");

    // 2. Fire the hardware-back IPC → nopal:back-pressed → history.back() →
    //    popstate → on_navigate → Route_changed Back_home.
    await invoke("simulate_back_pressed");

    // 3. The pop surfaces as Route_changed:Back_home and the model returns to
    //    Back_home (trailing ';' guards against prefix-aliasing a longer route).
    await telemetry.assertDispatched("Route_changed:Back_home");
    await telemetry.assertModelContains("back_route=Back_home;");

    // In-order across the whole interaction (gaps allowed).
    await telemetry.assertSequence(["Back_demo_push", "Route_changed:Back_home"]);
  });
});
