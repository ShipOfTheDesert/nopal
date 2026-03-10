import { test, expect } from "@playwright/test";

const SECTION = '[data-section="typography"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("typography section renders", async ({ page }) => {
  const section = page.locator(SECTION);
  await expect(section).toBeVisible();

  // Heading scale: h1–h4 with decreasing font sizes
  const h1 = section.locator('[data-testid="heading-h1"] span');
  const h4 = section.locator('[data-testid="heading-h4"] span');
  await expect(h1).toBeVisible();
  await expect(h4).toBeVisible();
  const h1Size = await h1.evaluate(
    (el) => parseFloat(getComputedStyle(el).fontSize)
  );
  const h4Size = await h4.evaluate(
    (el) => parseFloat(getComputedStyle(el).fontSize)
  );
  expect(h1Size).toBeGreaterThan(h4Size);

  // Body copy with line height
  const body = section.locator('[data-testid="body-copy"] span');
  await expect(body).toBeVisible();
  const lineHeight = await body.evaluate(
    (el) => getComputedStyle(el).lineHeight
  );
  expect(lineHeight).not.toBe("normal");

  // Monospace block
  const mono = section.locator('[data-testid="monospace-block"] span');
  await expect(mono).toBeVisible();
  const fontFamily = await mono.evaluate(
    (el) => getComputedStyle(el).fontFamily
  );
  expect(fontFamily).toContain("monospace");

  // Weight scale: all 9 weights present
  for (const weight of [
    "100", "200", "300", "400", "500", "600", "700", "800", "900",
  ]) {
    const weightEl = section.locator(`[data-testid="weight-${weight}"] span`);
    await expect(weightEl).toBeVisible();
    const fw = await weightEl.evaluate(
      (el) => getComputedStyle(el).fontWeight
    );
    expect(fw).toBe(weight);
  }

  // Ellipsis truncation — check the container which has overflow/text-overflow
  const ellipsis = section.locator('[data-testid="ellipsis-text"] span');
  await expect(ellipsis).toBeVisible();
  const overflow = await ellipsis.evaluate(
    (el) => getComputedStyle(el).textOverflow
  );
  expect(overflow).toBe("ellipsis");

  // Text alignment — text-align is on the container div, not the span
  for (const align of ["left", "center", "right", "justify"]) {
    const alignContainer = section.locator(`[data-testid="align-${align}"]`);
    await expect(alignContainer).toBeVisible();
    const ta = await alignContainer.evaluate(
      (el) => getComputedStyle(el).textAlign
    );
    expect(ta).toBe(align === "justify" ? "justify" : align);
  }

  // Italic text
  const italicEl = section.locator('[data-testid="italic-text"] span');
  await expect(italicEl).toBeVisible();
  const fontStyle = await italicEl.evaluate(
    (el) => getComputedStyle(el).fontStyle
  );
  expect(fontStyle).toBe("italic");

  // Text transforms
  for (const transform of ["uppercase", "lowercase", "capitalize"]) {
    const transformEl = section.locator(
      `[data-testid="transform-${transform}"] span`
    );
    await expect(transformEl).toBeVisible();
    const tt = await transformEl.evaluate(
      (el) => getComputedStyle(el).textTransform
    );
    expect(tt).toBe(transform);
  }
});
