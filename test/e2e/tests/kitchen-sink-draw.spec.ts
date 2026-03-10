import { test, expect } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  // Wait for the Nopal app to mount
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    "[data-section='draw']",
    { timeout: 10000 }
  );
});

test("draw section renders", async ({ page }) => {
  const drawSection = page.locator("[data-section='draw']");
  await expect(drawSection).toBeVisible();
  await expect(drawSection).toContainText("2D Drawing");
});

test("canvas elements present", async ({ page }) => {
  const canvases = page.locator("[data-section='draw'] canvas");
  // At least one canvas element should be present
  const count = await canvases.count();
  expect(count).toBeGreaterThanOrEqual(1);
});

test("pointer interaction", async ({ page }) => {
  // Find the interactive canvas (with aria-label)
  const canvas = page.locator("canvas[aria-label='Interactive drawing']");
  await expect(canvas).toBeVisible();

  // The coordinate display should start with no coordinates
  const coordDisplay = page.locator("[data-section='draw-coords']");
  await expect(coordDisplay).toBeVisible();

  // Move mouse over the canvas to trigger pointermove event
  await canvas.hover();

  // After hovering, text should contain coordinate values
  await expect(coordDisplay).toContainText("Pointer: (");
});

test("high-dpi canvas sizing", async ({ page }) => {
  const canvas = page.locator("[data-section='draw'] canvas").first();
  await expect(canvas).toBeVisible();

  // The canvas CSS size should match the specified logical dimensions.
  // The buffer size should be >= the CSS size (equal at 1x DPR, larger at higher DPR).
  const sizing = await canvas.evaluate((el) => {
    const canvas = el as HTMLCanvasElement;
    const cssWidth = canvas.getBoundingClientRect().width;
    const cssHeight = canvas.getBoundingClientRect().height;
    return {
      bufferWidth: canvas.width,
      bufferHeight: canvas.height,
      cssWidth,
      cssHeight,
    };
  });

  // CSS dimensions should match the specified 500x60 logical size
  expect(sizing.cssWidth).toBe(500);
  expect(sizing.cssHeight).toBe(60);

  // Buffer should be at least as large as CSS (accounts for HiDPI scaling)
  expect(sizing.bufferWidth).toBeGreaterThanOrEqual(sizing.cssWidth);
  expect(sizing.bufferHeight).toBeGreaterThanOrEqual(sizing.cssHeight);
});
