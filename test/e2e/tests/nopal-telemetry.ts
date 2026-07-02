import type { Page, TestInfo } from "@playwright/test";

// Playwright-side mirror of the OCaml `Nopal_test.Telemetry_test` harness
// (RFC 0110). It wraps the `window.__nopal_telemetry__` bridge that
// `Nopal_web.mount_with_telemetry` installs — and which `Nopal_web.mount`
// deliberately does NOT — so the cross-language assertion contract is symmetric:
// fragment (substring) matching against Message events, in-order-with-gaps for
// sequences, and a human-readable dump attached on failure (REQ-F3/F7).

export type TelemetryEvent =
  | { kind: "message"; value: string }
  | { kind: "model_transition"; before: string; after: string }
  | { kind: "command"; value: string }
  | { kind: "subscription"; value: string };

export class NopalTelemetry {
  private readonly page: Page;
  // The in-webview bridge's getEvents() is non-draining and bounded (feature
  // 0120, Decision N: host, browser, and Rust mirrors all read without draining
  // so they cannot diverge). This helper restores "read = drain" at the client
  // side via a consumed cursor, so each events() call yields only what was
  // recorded since the previous call — the contract every spec here is written
  // against. A snapshot caches that slice so multiple assertions plus
  // attachHistory read the same checkpoint rather than each advancing the cursor.
  private snapshot: TelemetryEvent[] | null = null;
  private consumed = 0;

  constructor(page: Page) {
    this.page = page;
  }

  // Fetch the events recorded since the previous call (client-side drain over the
  // non-draining bridge), caching the result. Call again to read the next slice
  // after driving more interactions.
  async events(): Promise<TelemetryEvent[]> {
    const all = (await this.page.evaluate(() => {
      const bridge = (window as { __nopal_telemetry__?: { getEvents(): unknown } })
        .__nopal_telemetry__;
      return bridge ? bridge.getEvents() : [];
    })) as TelemetryEvent[];
    // A fresh navigation re-creates the bridge with an empty log; if it shrank
    // below the cursor the log was reset, so treat the whole log as new.
    if (all.length < this.consumed) this.consumed = 0;
    this.snapshot = all.slice(this.consumed);
    this.consumed = all.length;
    return this.snapshot;
  }

  private async current(): Promise<TelemetryEvent[]> {
    if (this.snapshot === null) await this.events();
    return this.snapshot as TelemetryEvent[];
  }

  // Resolves when a Message containing `fragment` is recorded; rejects on
  // timeout. Backed by the bridge's own promise so it observes the live event
  // stream (the REQ-F2 replacement for waitForTimeout).
  async waitForMessage(fragment: string, timeoutMs: number): Promise<void> {
    await this.page.evaluate(
      ([f, t]) =>
        (
          window as unknown as {
            __nopal_telemetry__: {
              waitForMessage(f: string, t: number): Promise<void>;
            };
          }
        ).__nopal_telemetry__.waitForMessage(f as string, t as number),
      [fragment, timeoutMs] as [string, number]
    );
  }

  async assertDispatched(fragment: string): Promise<void> {
    const events = await this.current();
    const ok = events.some(
      (e) => e.kind === "message" && e.value.includes(fragment)
    );
    if (!ok)
      throw new Error(
        `assertDispatched: no Message contains ${JSON.stringify(fragment)}.\n${dump(events)}`
      );
  }

  async assertSequence(fragments: string[]): Promise<void> {
    const events = await this.current();
    let i = 0;
    for (const e of events) {
      if (i >= fragments.length) break;
      if (e.kind === "message" && e.value.includes(fragments[i])) i++;
    }
    if (i < fragments.length)
      throw new Error(
        `assertSequence: fragment ${JSON.stringify(fragments[i])} not found in order.\n${dump(events)}`
      );
  }

  async assertModelContains(fragment: string): Promise<void> {
    const events = await this.current();
    const ok = events.some(
      (e) => e.kind === "model_transition" && e.after.includes(fragment)
    );
    if (!ok)
      throw new Error(
        `assertModelContains: no Model_transition.after contains ${JSON.stringify(fragment)}.\n${dump(events)}`
      );
  }

  async attachHistory(testInfo: TestInfo): Promise<void> {
    const events = await this.current();
    await testInfo.attach("nopal-telemetry-history", {
      body: dump(events),
      contentType: "text/plain",
    });
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
