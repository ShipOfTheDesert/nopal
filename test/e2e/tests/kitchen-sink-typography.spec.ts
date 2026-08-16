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

  // Text color. Read off the span the color is authored on, never off the
  // container: the container carries only the test anchor, and a color that
  // reached it instead would still cascade down and look identical here.
  const computedTextColor = async (testid: string) => {
    const el = section.locator(`[data-testid="${testid}"] span`);
    await expect(el).toBeVisible();
    return el.evaluate((node) => getComputedStyle(node).color);
  };

  // Asserted in the computed rgb()/rgba() form the browser reports, never the
  // authored "#c0392b" / "rebeccapurple" spelling — the authored string is an
  // input to the style system, not something the rendered page ever shows.
  const hexColor = await computedTextColor("text-color-hex");
  expect(hexColor).toBe("rgb(192, 57, 43)");

  // The fractional alpha is what makes this row a distinct oracle: a
  // translucent color computes to an "rgba(...)" string, where the hex and
  // named rows above both compute to an opaque "rgb(...)". Keep the alpha on an
  // integral 8-bit boundary — 0.6 x 255 is exactly 153, so it round-trips
  // through the browser's 8-bit color storage unchanged. A "nicer" 0.7 is
  // 178.5, and this expectation would no longer be exact.
  const rgbaColor = await computedTextColor("text-color-rgba");
  expect(rgbaColor).toBe("rgba(30, 120, 200, 0.6)");

  const namedColor = await computedTextColor("text-color-named");
  expect(namedColor).toBe("rgb(102, 51, 153)");

  // An unset color is inert: the row that authors none is left at whatever its
  // container inherits. Compared against that container rather than against a
  // literal black, so the assertion states the inheritance relationship instead
  // of pinning the page's current default color.
  const inheritedTestid = "text-color-inherited";
  const inheritedColor = await computedTextColor(inheritedTestid);
  const containerColor = await section
    .locator(`[data-testid="${inheritedTestid}"]`)
    .evaluate((el) => getComputedStyle(el).color);
  expect(inheritedColor).toBe(containerColor);

  // Affirmative arm for the assertion above. The uncolored row is built by the
  // same helper as the three colored ones and differs from them in nothing but
  // whether a color was authored, so "it matches its container" is a real
  // observation only while an authored color does not.
  expect(inheritedColor).not.toBe(hexColor);
  expect(inheritedColor).not.toBe(rgbaColor);
  expect(inheritedColor).not.toBe(namedColor);

  // The color is a property of the text, not of the box around it. Without
  // this line the assertions above would read the same on a page that colored
  // the container and let the cascade carry it into the span, so the anchor
  // container is checked to be left at the same inherited color as the
  // uncolored row's.
  const hexContainerColor = await section
    .locator('[data-testid="text-color-hex"]')
    .evaluate((el) => getComputedStyle(el).color);
  expect(hexContainerColor).toBe(containerColor);
});
