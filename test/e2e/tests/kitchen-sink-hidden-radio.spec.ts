import { test, expect, type Page } from "@playwright/test";
import { assertNoAxeViolations } from "./axe";
import { NopalTelemetry } from "./nopal-telemetry";

// A radio group whose inputs are visually hidden: each option row shows only
// its label, and a ring on the row marks the focused option. Every selection is
// asserted through the MVU telemetry log; geometry and computed style are read
// only to prove what the browser paints. The expected values are the
// kitchen-sink section's own design values.

const SECTION = '[data-testid="hidden-radio-section"]';
const BEFORE = '[data-testid="hidden-radio-before"]';
const AFTER = '[data-testid="hidden-radio-after"]';

const VALUES = ["standard", "express", "overnight"] as const;
type Value = (typeof VALUES)[number];

const LABELS: Record<Value, string> = {
  standard: "Standard",
  express: "Express",
  overnight: "Overnight",
};

const RING = "rgba(2, 64, 58, 0.5) 0px 0px 0px 2px";

// Generous: the first model-to-DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

function radio(value: Value): string {
  return `#hidden-radio-shipping-${value}`;
}

function label(value: Value): string {
  return `#hidden-radio-shipping-${value}-label`;
}

function selected(value: Value): string {
  return `HiddenRadio:Selected:${value};`;
}

// Each option row is its radio's parent.
function row(page: Page, value: Value) {
  return page.locator(radio(value)).locator("xpath=..");
}

async function gotoSection(page: Page): Promise<void> {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
  // Actionability wait for the first interaction, without clicking.
  await page.locator(BEFORE).click({ trial: true });
}

async function radioBox(page: Page, value: Value) {
  const box = await page.locator(radio(value)).boundingBox();
  expect(box).not.toBeNull();
  return box!;
}

async function expectRingOnlyOn(
  page: Page,
  focused: Value | null
): Promise<void> {
  for (const value of VALUES) {
    await expect(row(page, value)).toHaveCSS(
      "box-shadow",
      value === focused ? RING : "none"
    );
  }
}

async function selectMessageCount(
  telemetry: NopalTelemetry
): Promise<number> {
  const events = await telemetry.events();
  return events.filter(
    (e) => e.kind === "message" && e.value.includes("HiddenRadio:Selected:")
  ).length;
}

test.beforeEach(async ({ page }) => {
  await gotoSection(page);
});

test("hidden radio takes no layout space", async ({ page }) => {
  for (const value of VALUES) {
    const box = await radioBox(page, value);
    expect(box.width).toBeLessThanOrEqual(1);
    expect(box.height).toBeLessThanOrEqual(1);

    const edges = await page.evaluate(
      ([radioSel, labelSel]) => {
        const r = document.querySelector(radioSel)!.parentElement!;
        const s = getComputedStyle(r);
        const l = document.querySelector(labelSel)!;
        return {
          contentLeft:
            r.getBoundingClientRect().left +
            parseFloat(s.borderLeftWidth) +
            parseFloat(s.paddingLeft),
          labelLeft: l.getBoundingClientRect().left,
        };
      },
      [radio(value), label(value)] as [string, string]
    );
    expect(edges.labelLeft).toBeCloseTo(edges.contentLeft, 1);
  }
});

test("Tab reaches the group once, arrows change selection", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);
  await expect(page.locator(radio("express"))).toBeChecked();

  await page.locator(BEFORE).focus();
  await page.keyboard.press("Tab");
  await expect(page.locator(radio("express"))).toBeFocused();
  await expectRingOnlyOn(page, "express");

  await telemetry.events();
  await page.keyboard.press("ArrowRight");
  await telemetry.waitForNewMessage(selected("overnight"), SETTLE);
  await expect(page.locator(radio("overnight"))).toBeChecked();
  await expectRingOnlyOn(page, "overnight");

  await telemetry.events();
  await page.keyboard.press("ArrowLeft");
  await telemetry.waitForNewMessage(selected("express"), SETTLE);
  await expect(page.locator(radio("express"))).toBeChecked();
  await expectRingOnlyOn(page, "express");

  await page.keyboard.press("Tab");
  await expect(page.locator(AFTER)).toBeFocused();
});

test("label press selects and focuses; arrow moves; row rings", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);
  await expect(page.locator(radio("standard"))).not.toBeChecked();
  await expectRingOnlyOn(page, null);

  await telemetry.events();
  await page.locator(label("standard")).click();
  await telemetry.waitForNewMessage(selected("standard"), SETTLE);
  await expect(page.locator(radio("standard"))).toBeChecked();
  await expect(page.locator(radio("standard"))).toBeFocused();
  // A duplicate dispatch could land a frame after the first. `events()` drains
  // the buffer, so wait out a settle window and count once, not before it.
  await page.waitForTimeout(500);
  expect(await selectMessageCount(telemetry)).toBe(1);
  await telemetry.assertDispatched(selected("standard"));

  await page.keyboard.press("ArrowRight");
  await telemetry.waitForNewMessage(selected("express"), SETTLE);
  await expect(page.locator(radio("express"))).toBeChecked();
  await expectRingOnlyOn(page, "express");
});

test("forced colours shows the radio again", async ({ page }) => {
  for (const value of VALUES) {
    const box = await radioBox(page, value);
    expect(box.width).toBeLessThanOrEqual(1);
    expect(box.height).toBeLessThanOrEqual(1);
  }

  // The `forcedColors` context option leaves the media query unmatched in this
  // Playwright's Chromium; emulating the media feature on the page matches it.
  await page.emulateMedia({ forcedColors: "active" });
  expect(
    await page.evaluate(() => matchMedia("(forced-colors: active)").matches)
  ).toBe(true);

  for (const value of VALUES) {
    const box = await radioBox(page, value);
    expect(box.width).toBeGreaterThan(1);
    expect(box.height).toBeGreaterThan(1);
  }
});

test("axe green; role, name, checked present", async ({ page }, testInfo) => {
  await assertNoAxeViolations(page, testInfo, SECTION);

  const section = page.locator(SECTION);
  for (const value of VALUES) {
    const byRole = section.getByRole("radio", {
      name: LABELS[value],
      exact: true,
    });
    await expect(byRole).toHaveCount(1);
    await expect(byRole).toHaveAttribute("id", radio(value).slice(1));
    if (value === "express") await expect(byRole).toBeChecked();
    else await expect(byRole).not.toBeChecked();
  }

  // The absence below reads every radio in the section, so it must find all three.
  const radios = section.locator('input[type="radio"]');
  await expect(radios).toHaveCount(VALUES.length);
  const ariaHidden = await radios.evaluateAll((els) =>
    els.map((el) => el.getAttribute("aria-hidden"))
  );
  expect(ariaHidden).toEqual([null, null, null]);
});
