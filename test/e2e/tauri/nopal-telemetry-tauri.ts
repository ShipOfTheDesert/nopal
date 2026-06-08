import { browser } from "@wdio/globals";

// WebdriverIO-side mirror of the OCaml `Nopal_test.Telemetry_test` harness and
// the Playwright `NopalTelemetry` (test/e2e/tests/nopal-telemetry.ts), for the
// Tauri (REQ-F5) layer. Identical substring-fragment matching across the
// language boundary (RFC 0110 / RFC 0112): assertions read the same four event
// shapes the web bridge emits, but from the *host process* via the
// `get_telemetry` IPC command rather than the in-webview bridge.
//
// Two structural differences from the web helper:
//   1. `get_telemetry` returns a *clone* of the host mirror (it does not drain),
//      so there is no snapshot/drain race — every read sees the full log.
//   2. The mirror is fed asynchronously (OCaml `emit` → Rust listener → vec),
//      so every assertion *polls* within a timeout via `browser.waitUntil`
//      instead of reading once. This is the REQ-N2 replacement for a fixed
//      delay: the wait keys off recorded telemetry, never a `setTimeout`.

export type TelemetryEvent =
  | { kind: "message"; value: string }
  | { kind: "model_transition"; before: string; after: string }
  | { kind: "command"; value: string }
  | { kind: "subscription"; value: string };

const DEFAULT_TIMEOUT_MS = 15000;

export class NopalTelemetryTauri {
  // Read (without draining) the host-side telemetry mirror. Runs in the webview
  // and invokes the always-registered `get_telemetry` command, which returns
  // `[]` until the app calls `Nopal_tauri.Telemetry.expose` (it does on
  // kitchen-sink Tauri startup).
  async events(): Promise<TelemetryEvent[]> {
    const raw = await browser.execute(async () => {
      const w = window as unknown as {
        __TAURI_INTERNALS__?: { invoke(cmd: string): Promise<unknown> };
        __TAURI__?: { core?: { invoke(cmd: string): Promise<unknown> } };
      };
      const invoke =
        w.__TAURI_INTERNALS__?.invoke?.bind(w.__TAURI_INTERNALS__) ??
        w.__TAURI__?.core?.invoke?.bind(w.__TAURI__.core);
      if (!invoke) return [];
      return await invoke("get_telemetry");
    });
    return (raw as TelemetryEvent[]) ?? [];
  }

  private async waitUntil(
    predicate: (events: TelemetryEvent[]) => boolean,
    failMessage: (events: TelemetryEvent[]) => string,
    timeoutMs: number
  ): Promise<void> {
    let last: TelemetryEvent[] = [];
    try {
      await browser.waitUntil(
        async () => {
          last = await this.events();
          return predicate(last);
        },
        { timeout: timeoutMs, interval: 200 }
      );
    } catch {
      throw new Error(failMessage(last));
    }
  }

  async assertDispatched(
    fragment: string,
    timeoutMs = DEFAULT_TIMEOUT_MS
  ): Promise<void> {
    await this.waitUntil(
      (events) =>
        events.some((e) => e.kind === "message" && e.value.includes(fragment)),
      (events) =>
        `assertDispatched: no Message contains ${JSON.stringify(fragment)}.\n${dump(events)}`,
      timeoutMs
    );
  }

  async assertSequence(
    fragments: string[],
    timeoutMs = DEFAULT_TIMEOUT_MS
  ): Promise<void> {
    const matched = (events: TelemetryEvent[]): number => {
      let i = 0;
      for (const e of events) {
        if (i >= fragments.length) break;
        if (e.kind === "message" && e.value.includes(fragments[i])) i++;
      }
      return i;
    };
    await this.waitUntil(
      (events) => matched(events) >= fragments.length,
      (events) =>
        `assertSequence: fragment ${JSON.stringify(
          fragments[matched(events)] ?? fragments[fragments.length - 1]
        )} not found in order.\n${dump(events)}`,
      timeoutMs
    );
  }

  async assertModelContains(
    fragment: string,
    timeoutMs = DEFAULT_TIMEOUT_MS
  ): Promise<void> {
    await this.waitUntil(
      (events) =>
        events.some(
          (e) => e.kind === "model_transition" && e.after.includes(fragment)
        ),
      (events) =>
        `assertModelContains: no Model_transition.after contains ${JSON.stringify(
          fragment
        )}.\n${dump(events)}`,
      timeoutMs
    );
  }
}

function dump(events: TelemetryEvent[]): string {
  if (events.length === 0) return "(no telemetry events recorded)";
  return events
    .map((e) => {
      switch (e.kind) {
        case "message":
          return `Message ${e.value}`;
        case "model_transition":
          return `Model_transition ${e.before} -> ${e.after}`;
        case "command":
          return `Command ${e.value}`;
        case "subscription":
          return `Subscription ${e.value}`;
      }
    })
    .join("\n");
}
