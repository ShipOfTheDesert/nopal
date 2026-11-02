import { test, expect, type Locator, type Page } from "@playwright/test";
import { assertNoAxeViolations } from "./axe";
import { NopalTelemetry } from "./nopal-telemetry";

// A checkbox drawn from its declared style instead of the platform's. Every
// toggle is asserted through the MVU telemetry log; computed style is read only
// to prove what the browser actually paints. The expected values are the
// kitchen-sink section's own design values, not anything read back from the
// renderer.

const SECTION = '[data-testid="drawn-checkbox-section"]';
const UNTICKED = '[data-testid="drawn-checkbox-unticked"]';
const TICKED = '[data-testid="drawn-checkbox-ticked"]';
const FOCUS_RING = '[data-testid="drawn-checkbox-focus-ring"]';
const INLINE = '[data-testid="drawn-checkbox-inline"]';
const HOVER_BACKGROUND = '[data-testid="drawn-checkbox-hover-background"]';

const FIELD = "rgb(255, 253, 249)";
const TICKED_FILL = "rgb(2, 64, 58)";
const HOVER_FILL = "rgb(230, 239, 238)";
const RING = "rgba(2, 64, 58, 0.5) 0px 0px 0px 2px";
const TICK_IMAGE = /data:image\/svg\+xml/;

// Generous: the first model-to-DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

function toggled(example: string, ticked: boolean): string {
  return `DrawnCheckbox:Toggled:${example}:${ticked};`;
}

async function gotoSection(page: Page): Promise<void> {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
}

// Moves keyboard focus onto `target` by pressing Tab from the control before it,
// so the browser treats the focus as keyboard focus and `:focus-visible` holds.
async function tabTo(page: Page, from: Locator, target: Locator) {
  await from.focus();
  await page.keyboard.press("Tab");
  await expect(target).toBeFocused();
}

test.describe("default viewport", () => {
  test.beforeEach(async ({ page }) => {
    await gotoSection(page);
  });

  test("unticked box paints the declared style", async ({ page }) => {
    const box = page.locator(UNTICKED);
    await expect(box).not.toBeChecked();

    const cs = await box.evaluate((el) => {
      const s = getComputedStyle(el);
      return {
        width: s.width,
        height: s.height,
        borderWidths: [
          s.borderTopWidth,
          s.borderRightWidth,
          s.borderBottomWidth,
          s.borderLeftWidth,
        ],
        radius: s.borderTopLeftRadius,
        background: s.backgroundColor,
        backgroundImage: s.backgroundImage,
        appearance: s.appearance,
        margins: [s.marginTop, s.marginRight, s.marginBottom, s.marginLeft],
      };
    });

    expect(cs).toEqual({
      width: "18px",
      height: "18px",
      borderWidths: ["1px", "1px", "1px", "1px"],
      radius: "4px",
      background: FIELD,
      backgroundImage: "none",
      appearance: "none",
      margins: ["0px", "0px", "0px", "0px"],
    });
  });

  test("ticked box fills and shows tick", async ({ page }) => {
    const telemetry = new NopalTelemetry(page);
    const box = page.locator(UNTICKED);
    await expect(box).toHaveCSS("background-image", "none");

    await box.click();
    await telemetry.waitForNewMessage(toggled("Unticked_start", true), SETTLE);

    await expect(box).toBeChecked();
    await expect(box).toHaveCSS("background-color", TICKED_FILL);
    await expect(box).toHaveCSS("border-top-color", TICKED_FILL);
    await expect(box).toHaveCSS("background-image", TICK_IMAGE);
  });

  test("ticked style with a background still shows the tick", async ({
    page,
  }) => {
    const box = page.locator(TICKED);
    await expect(box).toBeChecked();

    const cs = await box.evaluate((el) => {
      const s = getComputedStyle(el);
      return { color: s.backgroundColor, image: s.backgroundImage };
    });

    expect(cs.color).toBe(TICKED_FILL);
    expect(cs.image).toMatch(TICK_IMAGE);
  });

  test("hover background leaves the ticked fill", async ({ page }) => {
    const telemetry = new NopalTelemetry(page);
    const box = page.locator(HOVER_BACKGROUND);

    // Unticked, the hover rule is live and paints its own background.
    await box.hover();
    await expect(box).toHaveCSS("background-color", HOVER_FILL);

    await box.click();
    await telemetry.waitForNewMessage(
      toggled("Hover_background", true),
      SETTLE
    );

    // Still hovered, now ticked: the ticked fill wins.
    await box.hover();
    await expect(box).toBeChecked();
    await expect(box).toHaveCSS("background-color", TICKED_FILL);
    await expect(box).toHaveCSS("background-image", TICK_IMAGE);
  });

  test("inline base still loses to ticked", async ({ page }) => {
    const telemetry = new NopalTelemetry(page);
    const box = page.locator(INLINE);
    await expect(box).toHaveCSS("background-color", FIELD);

    await box.click();
    await telemetry.waitForNewMessage(toggled("No_interaction", true), SETTLE);

    await expect(box).toBeChecked();
    await expect(box).toHaveCSS("background-color", TICKED_FILL);
    await expect(box).toHaveCSS("background-image", TICK_IMAGE);
  });

  test("disabled ticked example shows its disabled style", async ({ page }) => {
    const box = page.locator('[data-testid="drawn-checkbox-disabled"]');
    await expect(box).toBeChecked();
    await expect(box).toBeDisabled();
    await expect(box).toHaveCSS("background-color", "rgb(157, 179, 176)");
    await expect(box).toHaveCSS("background-image", TICK_IMAGE);
  });

  test("focused style is the declared ring", async ({ page }) => {
    const box = page.locator(FOCUS_RING);
    await expect(box).toHaveCSS("box-shadow", "none");

    await tabTo(page, page.locator(TICKED), box);

    await expect(box).toHaveCSS("box-shadow", RING);
  });

  test("no focused style keeps browser ring", async ({ page }) => {
    const box = page.locator(INLINE);
    await expect(box).toHaveCSS("outline-style", "none");

    await tabTo(page, page.locator(FOCUS_RING), box);

    const outlineStyle = await box.evaluate(
      (el) => getComputedStyle(el).outlineStyle
    );
    expect(outlineStyle).not.toBe("none");
  });

  test("drawn checkbox toggles from keyboard", async ({ page }) => {
    const telemetry = new NopalTelemetry(page);
    const box = page.locator(UNTICKED);

    await box.focus();
    await page.keyboard.press("Space");
    await telemetry.waitForNewMessage(toggled("Unticked_start", true), SETTLE);
    await expect(box).toBeChecked();

    await page.keyboard.press("Space");
    await telemetry.waitForNewMessage(toggled("Unticked_start", false), SETTLE);
    await expect(box).not.toBeChecked();
  });

  test("section has no axe violations", async ({ page }, testInfo) => {
    await assertNoAxeViolations(page, testInfo, SECTION);
  });
});

test.describe("forced colours", () => {
  // The `forcedColors` context option leaves the media query unmatched in this
  // Playwright's Chromium; emulating the media feature on the page matches it.
  test.beforeEach(async ({ page }) => {
    await page.emulateMedia({ forcedColors: "active" });
    await gotoSection(page);
  });

  test("forced colours falls back", async ({ page }) => {
    expect(
      await page.evaluate(() => matchMedia("(forced-colors: active)").matches)
    ).toBe(true);

    const box = page.locator(TICKED);
    await expect(box).toBeChecked();
    await expect(box).toHaveAttribute("data-nopal-drawn-checkbox", "");

    const cs = await box.evaluate((el) => {
      const s = getComputedStyle(el);
      return {
        appearance: s.appearance,
        image: s.backgroundImage,
        color: s.backgroundColor,
      };
    });

    expect(cs.appearance).not.toBe("none");
    expect(cs.image).toBe("none");
    expect(cs.color).not.toBe(TICKED_FILL);
  });
});

test.describe("compact viewport", () => {
  test.use({ viewport: { width: 375, height: 812 } });

  test.beforeEach(async ({ page }) => {
    await gotoSection(page);
  });

  test("compact viewport sizes to 20px", async ({ page }) => {
    const box = page.locator(UNTICKED);
    await expect(box).toHaveCSS("width", "20px");
    await expect(box).toHaveCSS("height", "20px");
  });
});
