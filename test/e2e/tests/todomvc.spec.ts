import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";

// TodoMVC converted to the telemetry approach (RFC 0112, Step 3). Behavioural
// assertions go only through the telemetry log (REQ-N2): DOM input/clicks
// trigger the actions, but every check reads the recorded Message /
// Model_transition events — never DOM text. Waits gate on `waitForMessage`,
// never on a fixed delay (REQ-N2).
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before driving the input.

const TITLE_INPUT = '[data-field="todo-title"]';

function todoToggle(id: number) {
  return `button[data-action="toggle-${id}"]`;
}

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a display-server-less machine.
const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  // Each Playwright test gets a fresh browser context, so localStorage is empty.
  await page.goto("/todomvc/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    TITLE_INPUT,
    { timeout: 10000 }
  );
});

test("adding a todo dispatches Add and model holds the title", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  const input = page.locator(TITLE_INPUT);
  await input.fill("Buy milk");
  await input.press("Enter");
  // Gate on the recorded message rather than a fixed delay.
  await telemetry.waitForMessage("Add", SETTLE);

  await telemetry.assertDispatched("Add");
  // Behaviour is proven via the model fragment, not the rendered DOM text.
  await telemetry.assertModelContains("Buy milk");
});

test("toggling completes the item", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  const input = page.locator(TITLE_INPUT);
  await input.fill("Buy milk");
  await input.press("Enter");
  await telemetry.waitForMessage("Add", SETTLE);

  // The toggle control only renders once the todo exists; click auto-waits.
  await page.locator(todoToggle(1)).click();
  await telemetry.waitForMessage("Toggle", SETTLE);

  await telemetry.assertSequence(["Add", "Toggle"]);
  await telemetry.assertModelContains("completed=1;");
});
