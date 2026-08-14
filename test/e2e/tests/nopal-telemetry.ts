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
    const all = await this.readAll();
    // A fresh navigation re-creates the bridge with an empty log; if it shrank
    // below the cursor the log was reset, so treat the whole log as new.
    if (all.length < this.consumed) this.consumed = 0;
    this.snapshot = all.slice(this.consumed);
    this.consumed = all.length;
    return this.snapshot;
  }

  // The bridge log, whole and undrained. The one place the in-webview bridge's
  // shape is written down: every read below goes through here rather than
  // re-declaring the `window.__nopal_telemetry__` cast, so a spec that needs a
  // non-draining read cannot end up carrying its own copy of it.
  private async readAll(): Promise<TelemetryEvent[]> {
    return (await this.page.evaluate(() => {
      const bridge = (window as { __nopal_telemetry__?: { getEvents(): unknown } })
        .__nopal_telemetry__;
      return bridge ? bridge.getEvents() : [];
    })) as TelemetryEvent[];
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

  // Resolves once a Model_transition whose `after` contains `fragment` has been
  // recorded; rejects on timeout. Polls the live bridge log, so it can be used as
  // a gate between two interactions in the same test.
  //
  // Deliberately not interchangeable with `waitForMessage`, which matches
  // messages already in the log: a second interaction that emits the same message
  // as the first (`ReceiptProcessed:ok;` for a second photo) resolves the wait
  // immediately on the first one's entry, and the assertions after it then race
  // the result still in flight. That is measured, not assumed — in the
  // receipt-flow spec, `waitForMessage` in place of this helper failed both
  // ordering tests 3 runs out of 3, on the model fragment being absent. Gating on
  // a *model* fragment that only the second interaction can produce is what
  // separates the two passes.
  //
  // Reads here are non-draining, so waiting cannot consume the slice `events()`
  // and the assertions after it are reading.
  async waitForModel(fragment: string, timeoutMs: number): Promise<void> {
    await this.page.waitForFunction(
      (f) => {
        const bridge = (
          window as unknown as {
            __nopal_telemetry__?: {
              getEvents(): { kind: string; after?: string }[];
            };
          }
        ).__nopal_telemetry__;
        if (bridge === undefined) return false;
        return bridge
          .getEvents()
          .some(
            (e) => e.kind === "model_transition" && (e.after ?? "").includes(f)
          );
      },
      fragment,
      { timeout: timeoutMs }
    );
  }

  // Model assertion scoped to one named `record={…}` inside the serialized model.
  // A page that serialises several sections into a single model string can carry
  // the same field name in more than one of them (two kitchen-sink sections emit
  // `upload=`), so for those fields a bare substring match against the whole
  // string says nothing about which section produced it.
  //
  // Two deliberate differences from `assertModelContains`. Reads are non-draining
  // and cover the whole log since page load, so an assertion routed through here
  // cannot consume the checkpoint its sibling assertions in the same test are
  // reading. The cost is that a fragment the model has since moved away from
  // still satisfies it, so a test that can reach the same fragment twice has to
  // gate on something that tells the two apart.
  async assertRecordContains(record: string, fragment: string): Promise<void> {
    const events = await this.readAll();
    const records = events
      .flatMap((e) => (e.kind === "model_transition" ? [e.after] : []))
      .map((after) => recordSlice(after, record))
      .filter((slice): slice is string => slice !== null);
    if (records.some((slice) => slice.includes(fragment))) return;
    const dump =
      records.length === 0
        ? `(no ${record} record recorded)`
        : records.join("\n");
    throw new Error(
      `assertRecordContains: no ${record} record contains ` +
        `${JSON.stringify(fragment)}.\n${dump}`
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

// One named `record={…}` out of a serialized model string — the shape a
// kitchen-sink section contributes to the page's single model. `null` when the
// model carries no such record, which is what a section that has not been
// registered, or a misspelled record name, looks like. A record holds no nested
// braces, so the first `}` after the opening one closes it.
//
// Exported so a spec that has to read a value out of a record rather than assert
// a fragment against it — a number the browser produced, which no spec can name
// in advance — extracts it the same way `assertRecordContains` does, rather than
// carrying a second copy of the record shape.
export function recordSlice(model: string, record: string): string | null {
  const prefix = `${record}={`;
  const start = model.indexOf(prefix);
  if (start === -1) return null;
  const open = start + prefix.length;
  const close = model.indexOf("}", open);
  if (close === -1) return null;
  return model.slice(open, close);
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
