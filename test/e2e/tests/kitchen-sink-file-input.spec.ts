import { test, expect } from "@playwright/test";
import * as path from "node:path";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// File-input E2E for the kitchen sink. The selection contract — what actually
// reached the model — is asserted through the MVU telemetry log, which is this
// suite's primary correctness channel; the DOM is read only for the picker
// configuration, a pure render concern with no model-side shadow. `accept`,
// `capture` and `multiple` reach `nopal_test` as node attributes too, so what
// this spec adds is that the renderer writes them to a real `<input>` in the
// forms a user agent expects — comma-joined, wire-tokened, present/absent.
//
// Headless Chromium without a display server can stall requestAnimationFrame,
// which is what drives the model→DOM frame here. Mitigations: navigate fresh
// with `goto` and never `page.reload()`, `waitForFunction` before interacting,
// and gate the behavioural wait on `waitForMessage` rather than a fixed delay.

const SECTION = '[data-testid="file-input-section"]';
// Anchored by the section's call-site `data-field`, not `By_tag`-style tag
// matching: the file input renders as an `<input>` like every text field on the
// page, so a tag-shaped selector would resolve by document order.
const PICKER = `${SECTION} [data-field="receipt-image"]`;

const FIXTURE = path.join(__dirname, "fixtures", "receipt-sample.txt");

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a display-server-less machine.
const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    PICKER,
    { timeout: 10000 }
  );
});

test("file input renders accept, capture and multiple", async ({ page }) => {
  const picker = page.locator(PICKER);

  await expect(picker).toHaveAttribute("type", "file");
  await expect(picker).toHaveAttribute("accept", "image/*");
  await expect(picker).toHaveAttribute("capture", "environment");

  // The section configures a single-file picker, so `multiple` must be absent
  // rather than present-and-false — an `<input multiple="false">` still accepts
  // several files. The two assertions above are this one's affirmative arm on
  // the same locator: they prove the renderer does write picker attributes to
  // this element, so the absence below cannot pass merely because attribute
  // writing stopped altogether.
  const hasMultiple = await picker.evaluate((el) => el.hasAttribute("multiple"));
  expect(hasMultiple).toBe(false);
});

test("selecting a fixture dispatches file metadata", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(PICKER).setInputFiles(FIXTURE);
  await telemetry.waitForMessage("FilesSelected:1;", SETTLE);

  await telemetry.assertDispatched("FilesSelected:1;");

  // Every fragment carries its trailing ';' so a substring match is bounded on
  // both sides. Without it `file_size=13` is satisfied by a 130-byte file, and
  // the assertion would pass on a value it never meant. `last_modified` is
  // deliberately not asserted: it is a float the fixture's mtime decides, so
  // there is no stable value to pin.
  await telemetry.assertModelContains("file_count=1;");
  await telemetry.assertModelContains('file_name="receipt-sample.txt";');
  await telemetry.assertModelContains('file_mime="text/plain";');
  await telemetry.assertModelContains("file_size=13;");

  await telemetry.attachHistory(test.info());
});

// FR-3: clearing the picker dispatches with an empty list rather than
// dispatching nothing. The renderer and the test renderer both pin this, but
// the browser is the only place the empty `FileList` is real rather than
// simulated, and a silently-dropped event is exactly bug-class 1.
test("clearing the picker dispatches an empty selection", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  const picker = page.locator(PICKER);

  // Affirmative arm: the model must actually hold a file before the clear, or
  // `file_count=0;` below would be satisfied by a picker that never worked.
  await picker.setInputFiles(FIXTURE);
  await telemetry.waitForMessage("FilesSelected:1;", SETTLE);
  await telemetry.assertModelContains("file_count=1;");

  await picker.setInputFiles([]);
  await telemetry.waitForMessage("FilesSelected:0;", SETTLE);
  await telemetry.assertModelContains("file_count=0;");

  await telemetry.attachHistory(test.info());
});

test("file input section has no accessibility violations", async ({
  page,
}, testInfo) => {
  // Covers the label-association requirement: the picker has no `<label for>` of
  // its own, so its accessible name comes from the call-site `aria-label`, and
  // axe's `label` rule (wcag2a) fails an `<input type="file">` that has none.
  await assertNoAxeViolations(page, testInfo, SECTION);
});
