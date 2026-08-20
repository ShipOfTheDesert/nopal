import { test, expect, type Page } from "@playwright/test";
import { NopalTelemetry, type TelemetryEvent } from "./nopal-telemetry";

// E2E for the key-capture subscription in the kitchen sink's Subscriptions
// section. The correctness oracle is the MVU telemetry log, never the DOM: DOM
// assertions are reserved for render correctness and accessibility, and the
// section's readout is render correctness, whereas the string a subscription
// handler actually received is model state — and that string is what changed.
//
// Two token vocabularies meet in this file and must not be allowed to converge.
// Playwright presses "Control+d"; the string a Nopal subscription matches on is
// "Ctrl+d". Copying either spelling into the other produces a test that passes
// for the wrong reason or fails for no reason.
//
// Every assertion compares a WHOLE captured key string. "d" is a substring of
// "Ctrl+d", so a containment check against the raw message value would pass on
// the wrong key; `capturedKeys` strips the message prefix so `toContain`
// compares array elements by equality instead of searching inside a string.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto`, never `page.reload`, and wait for the section to exist before
// pressing a key.
//
// What this does NOT cover: one engine and one keyboard layout. These cases run
// under the chromium project against a US layout, so they say nothing about the
// WebKitGTK, WKWebView and Android System WebView runtimes the framework also
// ships through, nor about a layout on which the letter case or the shifted
// punctuation mapping differs.

const SECTION = '[data-testid="subscriptions-section"]';
const CAPTURE = "Subs:KeyCaptured:";

// A key nothing on the page subscribes to, pressed last in every case below.
// The capture handler receives every keydown in order, so once the sentinel is
// in the telemetry log the presses before it are too. Gating on the sentinel
// rather than on the key under test is what keeps the wait from becoming the
// assertion: the sentinel arrives whether or not the modifier fold is correct,
// so a wrong fold fails on an `expect` that prints the keys actually captured
// instead of on a wait that times out saying only that something was missing.
const SENTINEL = "z";

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a display-server-less machine.
const SETTLE = 15000;

async function gotoFresh(page: Page): Promise<void> {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
}

// The key strings the capture subscription received, in order — one entry per
// keydown, with the message prefix removed so each entry is the whole key
// string and nothing else.
function capturedKeys(events: TelemetryEvent[]): string[] {
  return events.flatMap((e) =>
    e.kind === "message" && e.value.startsWith(CAPTURE)
      ? [e.value.slice(CAPTURE.length)]
      : []
  );
}

// Press the descriptors in order, then the sentinel, and return every key the
// capture subscription reported. `press` takes Playwright's own key
// descriptors; what comes back is Nopal's folded key strings.
async function capturedAfter(
  page: Page,
  telemetry: NopalTelemetry,
  descriptors: string[]
): Promise<string[]> {
  for (const descriptor of descriptors) await page.keyboard.press(descriptor);
  await page.keyboard.press(SENTINEL);
  await telemetry.waitForMessage(`${CAPTURE}${SENTINEL}`, SETTLE);
  return capturedKeys(await telemetry.events());
}

test("a held Ctrl reaches the subscription as the Ctrl+d chord", async ({
  page,
}) => {
  await gotoFresh(page);
  const telemetry = new NopalTelemetry(page);

  const captured = await capturedAfter(page, telemetry, ["Control+d"]);

  // Affirmative arm for the absence below, on this same press: without it,
  // "no bare d was captured" would hold just as well for a page that captured
  // nothing at all.
  expect(captured).toContain("Ctrl+d");
  expect(captured).not.toContain("d");
});

test("a bare key is still delivered without a prefix", async ({ page }) => {
  await gotoFresh(page);
  const telemetry = new NopalTelemetry(page);

  const captured = await capturedAfter(page, telemetry, ["d"]);

  expect(captured).toContain("d");
  expect(captured).not.toContain("Ctrl+d");
});

test("the Ctrl keypress itself is reported as Control, unprefixed", async ({
  page,
}) => {
  await gotoFresh(page);
  const telemetry = new NopalTelemetry(page);

  const captured = await capturedAfter(page, telemetry, ["Control"]);

  // A real engine reports a modifier's own keydown with that modifier's flag
  // already set, so this is the one place the "a modifier keypress carries no
  // prefixes" rule is exercised against flags a browser produced rather than
  // flags a test supplied. Note the two vocabularies meeting: the key name is
  // "Control", the prefix token is "Ctrl+".
  expect(captured).toContain("Control");
  expect(captured).not.toContain("Ctrl+Control");
});

test("Shift held while the Ctrl key goes down reports bare Control", async ({
  page,
}) => {
  await gotoFresh(page);
  const telemetry = new NopalTelemetry(page);

  // The one output this feature changes that a browser could already produce.
  // "Shift+Control" is a Playwright descriptor, not a Nopal key string: it holds
  // Shift down, presses Control while Shift is still held, then releases both.
  // So the Control keydown arrives with shiftKey already true — flags an engine
  // produced, not flags a test supplied, which is the whole point of the case.
  // The previous fold prefixed that keydown and reported "Shift+Control"; the
  // modifier-keypress rule reports the bare name instead.
  const captured = await capturedAfter(page, telemetry, ["Shift+Control"]);

  expect(captured).toContain("Control");
  expect(captured).not.toContain("Shift+Control");
});

test("a question mark typed through Shift arrives as the Shift+? chord", async ({
  page,
}) => {
  await gotoFresh(page);
  const telemetry = new NopalTelemetry(page);

  // "Slash" is the code-form descriptor and is required here. Playwright's US
  // layout table carries a shifted variant only for entries keyed by code, so
  // "Shift+Slash" reports key = "?" the way a physical keyboard does, while the
  // literal form "Shift+/" reports "/" and would assert against a driver
  // artifact rather than against the browser.
  const captured = await capturedAfter(page, telemetry, ["Shift+Slash"]);

  // The contract a downstream consumer is about to depend on: the question mark
  // is only ever reachable with Shift held, so its subscription string carries
  // the prefix and the bare punctuation mark matches nothing. The negative is
  // the load-bearing half — bare "?" is what a subscriber would guess.
  expect(captured).toContain("Shift+?");
  expect(captured).not.toContain("?");
});
