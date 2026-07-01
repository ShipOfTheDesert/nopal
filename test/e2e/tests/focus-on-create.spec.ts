import { test, expect } from "@playwright/test";

// FR-3: Cmd.focus must focus its target even when that element is created by
// the same update that issues the focus. The "Create & Focus" control renders
// no input until clicked; its update both creates the input and issues
// Cmd.focus for it in the same step. Before the deferred-focus fix the focus
// ran before the rAF DOM patch and silently no-opped.
const CREATE_BUTTON = '[data-action="focus-on-create"]';
const CREATED_INPUT = "#created-input";

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  // rAF-driven mount: wait for the control before interacting (headless guard).
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    CREATE_BUTTON,
    { timeout: 10000 }
  );
});

test("focuses an input created by the same update", async ({ page }) => {
  // The input does not exist until the button's update creates it.
  expect(await page.locator(CREATED_INPUT).count()).toBe(0);

  await page.click(CREATE_BUTTON);

  // The rAF DOM patch inserts the new input.
  await page.waitForSelector(CREATED_INPUT, { timeout: 5000 });

  // The focus issued in the same update must land on the freshly created input.
  await page.waitForFunction(
    (sel) => document.activeElement === document.querySelector(sel),
    CREATED_INPUT,
    { timeout: 5000 }
  );
  const activeId = await page.evaluate(() => document.activeElement?.id);
  expect(activeId).toBe("created-input");
});
