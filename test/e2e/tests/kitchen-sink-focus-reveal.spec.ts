import { test, expect, type Page } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// Focus and blur events, driven through the kitchen sink's focus-revealed-note
// section with the keyboard alone.
//
// Correctness is asserted on the MVU telemetry log — which message the container
// dispatched and what the model became — because that is this suite's primary
// contract. The DOM is read only as render evidence: that the container is in
// the natural tab order at all, and that the note the model claims is revealed
// is really on screen. Neither of those is derivable from telemetry, and neither
// stands in for it.
//
// Every interaction here is a Tab. Keyboard reachability is the whole point of a
// focusable container, so a programmatic `.focus()` on the container would
// assert nothing it exists to provide. The one click in this file is on the
// reset control, and it is there to establish where the keyboard starts from.
// (An unrelated finding recorded in kitchen-sink-interaction.spec.ts — that a
// programmatic focus matches :focus-visible on an input but not on a button —
// is about which style rule applies, not about whether a listener fires, and
// says nothing either way about the events asserted here.)
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` and never `page.reload()`; wait for the section before interacting.
// The reveal lands on a later frame than the keypress that caused it, so every
// Tab that depends on the note being on screen waits for the note first — a
// spec that pressed Tab twice in a row would step straight past it.
//
// The one pair of consecutive Tabs here is in "Tab away hides the panel", and
// it is safe for a reason worth stating rather than deriving. The first of the
// two moves focus from the container onto the control already inside the note,
// and a move between two nodes inside the same container is not an edge: the
// backend's containment guard drops it, so no message is dispatched, no model
// changes, and no render can intervene between the two presses. The second Tab
// therefore starts from a DOM that nothing has touched. Any pair where the
// first press could dispatch needs the wait, or `settleFrames` below.

const SECTION = '[data-testid="focus-reveal-section"]';
const RESET = `${SECTION} [data-action="focus-reveal-reset"]`;
const NOTE = `${SECTION} [data-testid="focus-reveal-note"]`;
// The record this section contributes to the page's single serialized model.
const RECORD = "focus_reveal";

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

// What currently holds focus, named by the hook the section put on it. Enough to
// tell the container, the control inside its note and the anchor apart, and
// `null` for anything else — which is all this spec needs to say.
async function focusedName(page: Page): Promise<string | null> {
  return await page.evaluate(() => {
    const el = document.activeElement;
    if (el === null) return null;
    return el.getAttribute("data-testid") ?? el.getAttribute("data-action");
  });
}

// Two animation frames after a keypress, the render pass that keypress could
// have invalidated has certainly run. The gate in front of the assertion that
// nothing happened: without it the absence would be satisfied by a message still
// in flight rather than by a message never sent.
async function settleFrames(page: Page): Promise<void> {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
      })
  );
}

// The deterministic starting point. The reset control is the last focusable
// thing before the container, so one Tab from here reaches the container no
// matter how many sections are added above this one — a spec that counted tabs
// from page load would instead land on the wrong element, silently, the day
// anyone inserted one.
//
// That the click leaves focus on the control is asserted rather than assumed:
// if it did not, the Tab after it would start from wherever focus happened to
// be and every case below would be measuring something else.
async function anchorOnReset(
  page: Page,
  telemetry: NopalTelemetry
): Promise<void> {
  await page.locator(RESET).click();
  await telemetry.waitForMessage("FocusReveal:Demo_reset;", SETTLE);
  expect(
    await focusedName(page),
    "the anchor did not take focus, so the Tab after it starts from nowhere known"
  ).toBe("focus-reveal-reset");
}

// One Tab from the anchor onto the container, waiting for the reveal it causes.
// Returns with the note attached, which is the precondition for reaching into
// it.
async function tabOntoContainer(
  page: Page,
  telemetry: NopalTelemetry
): Promise<void> {
  await page.keyboard.press("Tab");
  await telemetry.waitForModel("focus_edges=1;", SETTLE);
  await expect(page.locator(NOTE)).toBeVisible({ timeout: SETTLE });
}

// Every message this section dispatched since the previous read, in order.
// Scoped by the section's own serializer prefix so another section's traffic
// cannot pad the sequence.
async function sectionMessages(telemetry: NopalTelemetry): Promise<string[]> {
  const events = await telemetry.events();
  return events.flatMap((e) =>
    e.kind === "message" && e.value.startsWith("FocusReveal:") ? [e.value] : []
  );
}

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("Tab focuses the box and reveals the panel", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await anchorOnReset(page, telemetry);

  await expect(page.locator(NOTE)).toHaveCount(0);

  await page.keyboard.press("Tab");

  // Render evidence, and the only place the container's presence in the natural
  // tab order is observable: a container the keyboard cannot reach would leave
  // focus on the anchor and every assertion below unreachable.
  expect(await focusedName(page), "Tab did not reach the container").toBe(
    "focus-reveal-box"
  );

  await telemetry.waitForModel("focus_edges=1;", SETTLE);

  // The contract: the arrival became a message, and the model the message
  // produced both revealed the note and counted exactly one edge. Asserted as
  // one fragment so the two cannot be satisfied by two different transitions.
  await telemetry.assertDispatched("FocusReveal:Focus_entered;");
  await telemetry.assertRecordContains(
    RECORD,
    "focus_note=true; focus_edges=1;"
  );

  // Render evidence: what the model says is revealed is on screen.
  await expect(page.locator(NOTE)).toBeVisible({ timeout: SETTLE });

  await telemetry.attachHistory(test.info());
});

test("Tab away hides the panel", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await anchorOnReset(page, telemetry);
  await tabOntoContainer(page, telemetry);

  // Out of the container, by way of the control inside the note — the only
  // route forward from here, and the departure is the second Tab, not the
  // first. The pair the header comment names: the first press dispatches
  // nothing, so there is no render to step past between them.
  await page.keyboard.press("Tab");
  await page.keyboard.press("Tab");

  expect(
    await focusedName(page),
    "focus is still on the container, so nothing departed"
  ).not.toBe("focus-reveal-box");

  await telemetry.waitForModel("focus_edges=2;", SETTLE);
  await telemetry.assertDispatched("FocusReveal:Focus_left;");
  await telemetry.assertRecordContains(
    RECORD,
    "focus_note=false; focus_edges=2;"
  );

  // Render evidence: the note the model no longer reveals is off screen.
  await expect(page.locator(NOTE)).toHaveCount(0, { timeout: SETTLE });

  await telemetry.attachHistory(test.info());
});

test("Tab onto the inner child keeps the panel", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await anchorOnReset(page, telemetry);
  await tabOntoContainer(page, telemetry);

  // Into the note's own control. The platform reports the move on the container
  // as well as on the two elements, and reporting it as a departure would take
  // the note — and the control the user is standing on — off the screen.
  await page.keyboard.press("Tab");
  expect(
    await focusedName(page),
    "Tab did not reach the control inside the note"
  ).toBe("focus-reveal-ack");
  await settleFrames(page);
  await expect(page.locator(NOTE)).toBeVisible();

  // The affirmative arm on the same fixture: one more Tab does leave the
  // container and does take the note away. Without it, a run whose Tabs had
  // stopped moving focus at all would keep the absence above green.
  await page.keyboard.press("Tab");
  await telemetry.waitForModel("focus_edges=2;", SETTLE);
  await expect(page.locator(NOTE)).toHaveCount(0, { timeout: SETTLE });

  // The whole sequence, enumerated rather than sampled. A container that
  // reported the move into its own note would have written a departure and an
  // arrival between the two edges below, and the count would have reached four;
  // an assertion that merely looked for a departure at the end would not see it.
  expect(
    await sectionMessages(telemetry),
    "the move within the container was reported as an edge"
  ).toEqual([
    "FocusReveal:Demo_reset;",
    "FocusReveal:Focus_entered;",
    "FocusReveal:Focus_left;",
  ]);

  await telemetry.attachHistory(test.info());
});

test("axe accessibility audit", async ({ page }, testInfo) => {
  const telemetry = new NopalTelemetry(page);
  await anchorOnReset(page, telemetry);

  // Audited with the note revealed, because that is the only state in which the
  // container holds another interactive element — the arrangement this section
  // could plausibly get wrong.
  await tabOntoContainer(page, telemetry);

  await assertNoAxeViolations(page, testInfo, SECTION);
});
