import { test, expect, type Page } from "@playwright/test";
import { assertNoAxeViolations } from "./axe";
import { NopalTelemetry } from "./nopal-telemetry";

// A radio group whose options are laid out in a row under a visible label,
// built from setters alone. Geometry is read from the browser because a
// direction can be reported by the element tree and still be overridden by the
// renderer; only the computed layout shows what the user sees. The expected
// direction and order are the kitchen-sink section's own design values.

const SECTION = '[data-testid="radio-row-section"]';
const GROUP = '[data-testid="radio-row-group"]';
const LABEL = "#radio-row-size-label";
const SMALL = "#radio-row-size-small";
const MEDIUM = "#radio-row-size-medium";
const LARGE = "#radio-row-size-large";
const BEFORE = '[data-testid="radio-row-before"]';
const AFTER = '[data-testid="radio-row-after"]';

// Generous: the first model-to-DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

async function gotoSection(page: Page): Promise<void> {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
}

// The options box is the radios' shared grandparent. Each radio sits in its
// own option row, so `../..` from any radio must reach the same element, and
// that element must be a direct child of the group.
async function optionsBox(page: Page) {
  const box = page.locator(SMALL).locator("xpath=../..");
  const shape = await box.evaluate(
    (el, sels) => {
      const radios = sels.radios.map((s) => document.querySelector(s));
      return {
        sharedByAllRadios: radios.every(
          (r) => r !== null && r.parentElement?.parentElement === el
        ),
        parentIsGroup: el.parentElement === document.querySelector(sels.group),
        rows: el.children.length,
        role: el.getAttribute("role"),
      };
    },
    { radios: [SMALL, MEDIUM, LARGE], group: GROUP }
  );
  expect(shape).toEqual({
    sharedByAllRadios: true,
    parentIsGroup: true,
    rows: 3,
    role: null,
  });
  return box;
}

test.beforeEach(async ({ page }) => {
  await gotoSection(page);
});

test("options box lays out in a row", async ({ page }) => {
  const box = await optionsBox(page);
  await expect(box).toHaveCSS("flex-direction", "row");

  const rows = await Promise.all(
    [SMALL, MEDIUM, LARGE].map((sel) =>
      page.locator(sel).locator("xpath=..").boundingBox()
    )
  );
  const [small, medium, large] = rows.map((r) => {
    expect(r).not.toBeNull();
    return r!;
  });

  expect(Math.abs(medium.y - small.y)).toBeLessThanOrEqual(1);
  expect(Math.abs(large.y - small.y)).toBeLessThanOrEqual(1);
  expect(medium.x).toBeGreaterThan(small.x);
  expect(large.x).toBeGreaterThan(medium.x);
});

test("label sits above the options", async ({ page }) => {
  const box = await optionsBox(page);
  const label = await page.locator(LABEL).boundingBox();
  const options = await box.boundingBox();
  expect(label).not.toBeNull();
  expect(options).not.toBeNull();

  expect(label!.y + label!.height).toBeLessThanOrEqual(options!.y);
  expect(Math.abs(label!.x - options!.x)).toBeLessThanOrEqual(1);
});

test("arrow keys move the choice", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  const medium = page.locator(MEDIUM);
  const large = page.locator(LARGE);
  await expect(medium).toBeChecked();
  await expect(large).not.toBeChecked();

  await medium.focus();
  await page.keyboard.press("ArrowRight");
  await telemetry.waitForMessage("RadioRow:Selected:large;", SETTLE);

  await telemetry.assertDispatched("RadioRow:Selected:large;");
  await expect(large).toBeChecked();
});

test("group is one tab stop", async ({ page }) => {
  await page.locator(BEFORE).focus();
  await page.keyboard.press("Tab");
  await expect(page.locator(MEDIUM)).toBeFocused();

  await page.keyboard.press("Tab");
  await expect(page.locator(AFTER)).toBeFocused();
});

test("section has no axe violations", async ({ page }, testInfo) => {
  await assertNoAxeViolations(page, testInfo, SECTION);
});
