import { test, expect, type Page } from "@playwright/test";
import { NopalTelemetry, type TelemetryEvent } from "./nopal-telemetry";

// A real click on the clipboard section's Copy button, with the clipboard
// permission granted and withheld. What the write resolved to is read from the
// MVU telemetry log, and the whole ordered list of the section's messages is
// compared, so a write that resolved twice fails as surely as one that resolved
// wrongly. The status element is read as a render gate only.
//
// Chromium grants a write with `clipboard-write` whether or not a gesture is
// active, so neither case here can show a write that left the click's user
// activation. That placement is pinned by the nopal_web unit suite instead.

const SECTION = '[data-testid="clipboard-section"]';
const KEY = `${SECTION} [data-testid="clipboard-key"]`;
const COPY = `${SECTION} [data-testid="clipboard-copy"]`;
const STATUS = `${SECTION} [data-testid="clipboard-status"]`;
const PREFIX = "Clipboard:";
const FAKE_KEY = "nopal-test-key-7Q2";

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

// Two animation frames after the outcome, a second outcome for the same write
// would have been dispatched. The gate in front of every "exactly one" check.
async function settleFrames(page: Page): Promise<void> {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
      }),
  );
}

function sectionMessages(events: TelemetryEvent[]): string[] {
  return events.flatMap((e) =>
    e.kind === "message" && e.value.startsWith(PREFIX) ? [e.value] : [],
  );
}

// Clicks Copy, waits for an outcome of any kind to be dispatched and for the
// frames after it, and returns every event recorded since the page loaded. The
// wait names no particular outcome, so a wrong one fails on the list compare
// with the list printed, rather than on a timeout.
async function copyAndRead(
  page: Page,
  telemetry: NopalTelemetry,
): Promise<TelemetryEvent[]> {
  await page.locator(COPY).click();
  await telemetry.waitForNewMessage(`${PREFIX}Copy_result:`, SETTLE);
  await settleFrames(page);
  return telemetry.events();
}

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    COPY,
    { timeout: 10000 },
  );
});

test("granted: a real click copies the key and reports Ok", async ({
  page,
  context,
}) => {
  await context.grantPermissions(["clipboard-read", "clipboard-write"]);
  const telemetry = new NopalTelemetry(page);
  await expect(page.locator(KEY)).toHaveText(FAKE_KEY);

  const events = await copyAndRead(page, telemetry);

  expect(sectionMessages(events), "not exactly one Ok outcome").toEqual([
    `${PREFIX}Copy_clicked;`,
    `${PREFIX}Copy_result:Ok;`,
  ]);
  await expect(page.locator(STATUS)).toHaveAttribute("data-status", "copied", {
    timeout: SETTLE,
  });
  expect(
    await page.evaluate(() => navigator.clipboard.readText()),
  ).toEqual(FAKE_KEY);

  // The log covers the write itself — its command event is in it — and still
  // carries the key nowhere.
  expect(
    events.some((e) => e.kind === "command" && e.value === "write_clipboard"),
    "the log does not cover the write",
  ).toBe(true);
  expect(
    events.filter((e) => JSON.stringify(e).includes(FAKE_KEY)),
    "a telemetry event carries the copied key",
  ).toEqual([]);
});

test("denied: a real click reports Not_permitted once", async ({
  page,
  context,
}) => {
  await context.clearPermissions();
  const telemetry = new NopalTelemetry(page);

  const events = await copyAndRead(page, telemetry);

  expect(
    sectionMessages(events),
    "not exactly one Not_permitted outcome",
  ).toEqual([
    `${PREFIX}Copy_clicked;`,
    `${PREFIX}Copy_result:Error Not_permitted;`,
  ]);
  const status = page.locator(STATUS);
  await expect(status).toHaveAttribute("data-status", "not-permitted", {
    timeout: SETTLE,
  });
  await expect(status).toHaveText("Not copied: the platform refused the write");
});
