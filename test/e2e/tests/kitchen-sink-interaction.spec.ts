import { test, expect } from "@playwright/test";

const HOVER_BUTTON = '[data-testid="hover-button"]';
const PRESSED_BUTTON = '[data-testid="pressed-button"]';
const FOCUS_INPUT = '[data-testid="focus-input"]';
const HOVER_CARD = '[data-testid="hover-card"]';
const SPREAD_RING_INPUT = '[data-testid="spread-ring-input"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    HOVER_BUTTON,
    { timeout: 10000 }
  );
});

test("hover changes background color", async ({ page }) => {
  const button = page.locator(HOVER_BUTTON);
  const bgBefore = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  await button.hover();

  const bgAfter = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  expect(bgBefore).not.toBe(bgAfter);
  // Hover color is #5ba0e9 = rgb(91, 160, 233)
  expect(bgAfter).toBe("rgb(91, 160, 233)");
});

test("pressed changes background color", async ({ page }) => {
  const button = page.locator(PRESSED_BUTTON);

  // Hover first to get hover state
  await button.hover();
  const bgHover = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  // Mouse down to trigger :active (pressed) state
  await page.mouse.down();

  const bgPressed = await button.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  await page.mouse.up();

  expect(bgHover).not.toBe(bgPressed);
  // Pressed color is #2a6ab8 = rgb(42, 106, 184)
  expect(bgPressed).toBe("rgb(42, 106, 184)");
});

test("focus-visible shows focus ring", async ({ page }) => {
  const input = page.locator(FOCUS_INPUT);

  const borderBefore = await input.evaluate(
    (el) => getComputedStyle(el).borderWidth
  );

  // Programmatic .focus() on <input> reliably triggers :focus-visible because
  // inputs always match :focus-visible in Chromium. This would NOT work for
  // <button> elements — only keyboard-initiated focus triggers :focus-visible
  // there. If we add button focus tests, use Tab-based navigation instead.
  // The same rule is why no case in this file drives focus with .click(): a
  // mouse click legitimately does not match :focus-visible, so a ring asserted
  // after a click would pin the opposite of the intended behaviour instead of
  // catching a regression.
  await input.focus();

  const borderAfter = await input.evaluate(
    (el) => getComputedStyle(el).borderWidth
  );

  // Focus ring has border-width 2px vs base 1px
  expect(borderBefore).toBe("1px");
  expect(borderAfter).toBe("2px");
});

test("spread focus ring appears without layout shift", async ({ page }) => {
  const input = page.locator(SPREAD_RING_INPUT);

  // boundingBox() is viewport-relative, and focusing an off-screen control
  // scrolls the page to it — which would move y without anything having been
  // laid out differently. Bring it into view first so the comparison below is
  // about the element's own geometry.
  await input.scrollIntoViewIfNeeded();

  // The ring element's own box is the weaker half of the claim — box-shadow
  // never contributes to a border box in any conforming browser, so it barely
  // can move. What the section actually demonstrates is that nothing *after*
  // the ring is displaced, so measure a stable control rendered later in the
  // same section too. Both baselines are taken after the scroll above and
  // .focus() does not scroll an already-visible control, so the comparison is
  // about layout rather than scroll position.
  const following = page.locator(HOVER_CARD);

  const boxBefore = await input.boundingBox();
  const followingBefore = await following.boundingBox();
  const shadowBefore = await input.evaluate(
    (el) => getComputedStyle(el).boxShadow
  );

  await input.focus();

  const shadowAfter = await input.evaluate(
    (el) => getComputedStyle(el).boxShadow
  );
  const boxAfter = await input.boundingBox();
  const followingAfter = await following.boundingBox();

  expect(shadowBefore).toBe("none");
  // Read from a real getComputedStyle in headless Chromium, not predicted:
  // the browser hoists the colour to the front and spells every length in px,
  // including the fourth (spread) one this ring exists to set.
  expect(shadowAfter).toBe("rgba(74, 144, 217, 0.6) 0px 0px 0px 3px");

  // The reason the ring is built from a shadow spread rather than a wider
  // border: box-shadow is painted, never laid out, so the control keeps its
  // exact geometry across focus. The border-built control above does not —
  // pointing this assertion at it was tried, and it goes 195x29 -> 197x31 as
  // the 1px border becomes 2px, pushing everything after it down.
  expect(boxBefore).not.toBeNull();
  expect(boxAfter).toEqual(boxBefore);

  // The load-bearing half: the next control down keeps its y. This is not a
  // tautology — the same two lines aimed at the border-built input above were
  // run and failed, HOVER_CARD's y going 471.59 -> 473.59 as that control's
  // 1px border becomes 2px on focus and pushes everything after it down.
  expect(followingBefore).not.toBeNull();
  expect(followingAfter!.y).toBe(followingBefore!.y);
});

test("clickable box hover highlight", async ({ page }) => {
  const card = page.locator(HOVER_CARD);
  const bgBefore = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  await card.hover();

  const bgAfter = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  expect(bgBefore).not.toBe(bgAfter);
  // Hover color is #d0e4f7 = rgb(208, 228, 247)
  expect(bgAfter).toBe("rgb(208, 228, 247)");
});

test("interaction reconciliation updates hover behavior", async ({ page }) => {
  const toggleBtn = page.locator('[data-testid="toggle-interaction-btn"]');
  const card = page.locator('[data-testid="toggle-card"]');

  // Card starts without interaction — hover should not change background
  const bgBeforeHover = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  await card.hover();
  const bgAfterHoverOff = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  expect(bgBeforeHover).toBe(bgAfterHoverOff);

  // Move mouse away before clicking toggle
  await page.mouse.move(0, 0);

  // Enable interaction via toggle
  await toggleBtn.click();

  // Now hover should change background
  const bgBeforeHover2 = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  await card.hover();
  const bgAfterHoverOn = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  expect(bgBeforeHover2).not.toBe(bgAfterHoverOn);
  // Hover color is #d0e4f7 = rgb(208, 228, 247)
  expect(bgAfterHoverOn).toBe("rgb(208, 228, 247)");

  // Move mouse away before clicking toggle again
  await page.mouse.move(0, 0);

  // Disable interaction via toggle
  await toggleBtn.click();

  // Hover should no longer change background
  const bgBeforeHover3 = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  await card.hover();
  const bgAfterHoverOff2 = await card.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  expect(bgBeforeHover3).toBe(bgAfterHoverOff2);
});

test("no style change on non-interactive element", async ({ page }) => {
  // Target a plain text label near the interaction section
  const label = page.getByText("Button with hover highlight:");
  const bgBefore = await label.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  await label.hover();

  const bgAfter = await label.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  expect(bgBefore).toBe(bgAfter);
});
