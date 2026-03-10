import { test, expect } from "@playwright/test";

const HOVER_BUTTON = '[data-testid="hover-button"]';
const PRESSED_BUTTON = '[data-testid="pressed-button"]';
const HOVER_CARD = '[data-testid="hover-card"]';
const TOGGLE_BTN = '[data-testid="toggle-interaction-btn"]';
const TOGGLE_CARD = '[data-testid="toggle-card"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    HOVER_BUTTON,
    { timeout: 10000 }
  );
});

test("single style element in head", async ({ page }) => {
  const count = await page.evaluate(
    () => document.querySelectorAll('head style[data-nopal]').length
  );
  expect(count).toBe(1);
});

test("no !important in stylesheet rules", async ({ page }) => {
  const hasImportant = await page.evaluate(() => {
    const style = document.querySelector('head style[data-nopal]');
    if (!style) return false;
    const sheet = (style as HTMLStyleElement).sheet;
    if (!sheet) return false;
    for (let i = 0; i < sheet.cssRules.length; i++) {
      if (sheet.cssRules[i].cssText.includes("!important")) {
        return true;
      }
    }
    return false;
  });
  expect(hasImportant).toBe(false);
});

test("shared class for identical interactions", async ({ page }) => {
  // Enable interaction on the toggle-card so it gets the same
  // card_hover_interaction as hover-card
  await page.locator(TOGGLE_BTN).click();

  // Wait for the toggle-card to acquire an interaction class
  await page.waitForFunction(
    (sel) => {
      const el = document.querySelector(sel);
      return el && Array.from(el.classList).some((c) => c.startsWith("_nopal_ix_"));
    },
    TOGGLE_CARD,
    { timeout: 5000 }
  );

  // Both cards should now share the same interaction class name
  const classes = await page.evaluate(
    ([hoverSel, toggleSel]) => {
      const hoverCard = document.querySelector(hoverSel!);
      const toggleCard = document.querySelector(toggleSel!);
      if (!hoverCard || !toggleCard) return { hover: "", toggle: "" };

      // Find classes matching the _nopal_ix_ pattern (interaction classes)
      const getIxClass = (el: Element) =>
        Array.from(el.classList).find((c) => c.startsWith("_nopal_ix_")) || "";
      return {
        hover: getIxClass(hoverCard),
        toggle: getIxClass(toggleCard),
      };
    },
    [HOVER_CARD, TOGGLE_CARD]
  );

  expect(classes.hover).toBeTruthy();
  expect(classes.toggle).toBeTruthy();
  expect(classes.hover).toBe(classes.toggle);
});

test("hover overrides base style", async ({ page }) => {
  const button = page.locator(HOVER_BUTTON);

  // Get base background color before hover
  const bgBase = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  // Hover to trigger :hover pseudo-class
  await button.hover();

  const bgHover = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  // Hover should override the base background via CSS specificity, not !important
  expect(bgBase).not.toBe(bgHover);
  expect(bgHover).toBe("rgb(91, 160, 233)");
});

test("pressed overrides hover", async ({ page }) => {
  const button = page.locator(PRESSED_BUTTON);

  // Hover first
  await button.hover();
  const bgHover = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  expect(bgHover).toBe("rgb(91, 160, 233)");

  // Mouse down to trigger :active which should override :hover
  await page.mouse.down();
  const bgPressed = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  await page.mouse.up();

  expect(bgPressed).not.toBe(bgHover);
  expect(bgPressed).toBe("rgb(42, 106, 184)");
});

test("kitchen sink interactive elements render correctly", async ({ page }) => {
  // Verify all interactive elements are present and have nopal classes
  const elements = await page.evaluate(
    ([hoverBtn, pressedBtn, hoverCard]) => {
      const results: Record<string, { hasBaseClass: boolean; hasIxClass: boolean; visible: boolean }> = {};

      for (const [name, sel] of [
        ["hoverButton", hoverBtn!],
        ["pressedButton", pressedBtn!],
        ["hoverCard", hoverCard!],
      ]) {
        const el = document.querySelector(sel);
        if (!el) {
          results[name] = { hasBaseClass: false, hasIxClass: false, visible: false };
          continue;
        }
        const classes = Array.from(el.classList);
        results[name] = {
          hasBaseClass: classes.some((c) => c.startsWith("_nopal_b_")),
          hasIxClass: classes.some((c) => c.startsWith("_nopal_ix_")),
          visible: el.getBoundingClientRect().height > 0,
        };
      }
      return results;
    },
    [HOVER_BUTTON, PRESSED_BUTTON, HOVER_CARD]
  );

  for (const [name, info] of Object.entries(elements)) {
    expect(info.visible, `${name} should be visible`).toBe(true);
    expect(info.hasBaseClass, `${name} should have a base class`).toBe(true);
    expect(info.hasIxClass, `${name} should have an interaction class`).toBe(true);
  }
});

test("interactive to non-interactive transition removes classes and restores inline styles", async ({ page }) => {
  // toggle-card starts non-interactive. Click to make interactive.
  await page.locator(TOGGLE_BTN).click();

  // Wait for interaction class to appear
  await page.waitForFunction(
    (sel) => {
      const el = document.querySelector(sel);
      return el && Array.from(el.classList).some((c) => c.startsWith("_nopal_ix_"));
    },
    TOGGLE_CARD,
    { timeout: 5000 }
  );

  // Verify it has classes
  const hasClassesBefore = await page.evaluate((sel) => {
    const el = document.querySelector(sel);
    if (!el) return false;
    const classes = Array.from(el.classList);
    return classes.some((c) => c.startsWith("_nopal_ix_"));
  }, TOGGLE_CARD);
  expect(hasClassesBefore).toBe(true);

  // Click again to remove interaction (back to non-interactive)
  await page.locator(TOGGLE_BTN).click();

  // Wait for interaction class to be removed
  await page.waitForFunction(
    (sel) => {
      const el = document.querySelector(sel);
      return el && !Array.from(el.classList).some((c) => c.startsWith("_nopal_ix_"));
    },
    TOGGLE_CARD,
    { timeout: 5000 }
  );

  // Verify classes are gone and element is still visible (inline styles restored)
  const state = await page.evaluate((sel) => {
    const el = document.querySelector(sel);
    if (!el) return { hasIxClass: true, hasBaseClass: true, visible: false };
    const classes = Array.from(el.classList);
    return {
      hasIxClass: classes.some((c) => c.startsWith("_nopal_ix_")),
      hasBaseClass: classes.some((c) => c.startsWith("_nopal_b_")),
      visible: el.getBoundingClientRect().height > 0,
    };
  }, TOGGLE_CARD);

  expect(state.hasIxClass).toBe(false);
  expect(state.hasBaseClass).toBe(false);
  expect(state.visible).toBe(true);
});
