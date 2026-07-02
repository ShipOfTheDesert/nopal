import { $ } from "@wdio/globals";
import { NopalTelemetryTauri } from "./nopal-telemetry-tauri";

// REQ-F5 / FR-5 (feature 0120): the Tauri `event` plugin emit→listen round-trip
// against the *real* counterpart (ADR 0108 no-mock-IPC). The kitchen-sink
// registers `Nopal_tauri.Event.listen "nopal:kitchen-sink"` (on Tauri startup
// and again via the "Start Listening" button), and "Emit Event" calls
// `Nopal_tauri.Event.emit "nopal:kitchen-sink" "hello from nopal"`. Tauri's
// event bus broadcasts the emit back to the same window's listener, which
// dispatches `TauriEventReceived payload`. We assert purely via the host-side
// `get_telemetry` mirror — never the DOM — so this proves the IPC event path
// the browser-only specs cannot see, and that the protocol matches the pinned
// plugin version.

const EMIT_PAYLOAD = "hello from nopal";

describe("Tauri event (REQ-F5)", () => {
  it("emit round-trips back through a real listen", async () => {
    const telemetry = new NopalTelemetryTauri();

    // Drive the listen registration on demand (not just the startup one) so the
    // round-trip exercises the button-triggered `Event.listen` path.
    await $('[data-action="tauri-event-listen"]').waitForExist({
      timeout: 15000,
    });
    await $('[data-action="tauri-event-listen"]').click();

    // Gate the emit on a listener actually being ready — `Event.listen`
    // registration is async and unbuffered, so emitting before it attaches
    // would drop the event. `TauriListenReady` fires once registration
    // completes (its `on_unlisten` callback runs).
    await telemetry.assertDispatched("TauriListenReady");

    await $('[data-action="tauri-event-emit"]').click();

    // The emit is echoed by Tauri's event bus to the same window's listener,
    // which carries the payload on the received-message fragment.
    await telemetry.assertDispatched(`TauriEventReceived:${EMIT_PAYLOAD}`);
  });
});
