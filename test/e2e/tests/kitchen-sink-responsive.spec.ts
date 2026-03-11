import { test, expect } from "@playwright/test";

const BOTTOM_NAV = '[data-testid="bottom-nav"]';
const SIDEBAR = '[data-testid="sidebar"]';
const GRID_1COL = '[data-testid="grid-1col"]';
const GRID_2COL = '[data-testid="grid-2col"]';
const GRID_3COL = '[data-testid="grid-3col"]';
const VIEWPORT_INFO = '[data-testid="viewport-info"]';
const SAFE_AREA_VIZ = '[data-testid="safe-area-viz"]';

test.describe("compact layout at 375px", () => {
  test.use({ viewport: { width: 375, height: 812 } });

  test("shows compact layout", async ({ page }) => {
    await page.goto("/kitchen_sink/");
    await page.waitForFunction(
      (sel) => document.querySelector(sel) !== null,
      BOTTOM_NAV,
      { timeout: 10000 }
    );

    // Bottom nav visible, sidebar not present
    await expect(page.locator(BOTTOM_NAV)).toBeVisible();
    expect(await page.locator(SIDEBAR).count()).toBe(0);

    // 1-column grid visible
    await expect(page.locator(GRID_1COL)).toBeVisible();
    expect(await page.locator(GRID_2COL).count()).toBe(0);
    expect(await page.locator(GRID_3COL).count()).toBe(0);
  });
});

test.describe("medium layout at 768px", () => {
  test.use({ viewport: { width: 768, height: 1024 } });

  test("shows medium layout", async ({ page }) => {
    await page.goto("/kitchen_sink/");
    await page.waitForFunction(
      (sel) => document.querySelector(sel) !== null,
      GRID_2COL,
      { timeout: 10000 }
    );

    // Medium uses compact fallback for nav (no ~medium branch), so bottom-nav
    await expect(page.locator(BOTTOM_NAV)).toBeVisible();
    expect(await page.locator(SIDEBAR).count()).toBe(0);

    // 2-column grid visible
    await expect(page.locator(GRID_2COL)).toBeVisible();
    expect(await page.locator(GRID_1COL).count()).toBe(0);
    expect(await page.locator(GRID_3COL).count()).toBe(0);
  });
});

test.describe("expanded layout at 1440px", () => {
  test.use({ viewport: { width: 1440, height: 900 } });

  test("shows expanded layout", async ({ page }) => {
    await page.goto("/kitchen_sink/");
    await page.waitForFunction(
      (sel) => document.querySelector(sel) !== null,
      SIDEBAR,
      { timeout: 10000 }
    );

    // Sidebar visible, bottom nav not present
    await expect(page.locator(SIDEBAR)).toBeVisible();
    expect(await page.locator(BOTTOM_NAV).count()).toBe(0);

    // 3-column grid visible
    await expect(page.locator(GRID_3COL)).toBeVisible();
    expect(await page.locator(GRID_1COL).count()).toBe(0);
    expect(await page.locator(GRID_2COL).count()).toBe(0);
  });
});

test.describe("resize transition", () => {
  test("layout updates when crossing breakpoint", async ({ page }) => {
    // Start at expanded size
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto("/kitchen_sink/");
    await page.waitForFunction(
      (sel) => document.querySelector(sel) !== null,
      SIDEBAR,
      { timeout: 10000 }
    );

    // Verify expanded layout
    await expect(page.locator(SIDEBAR)).toBeVisible();
    await expect(page.locator(GRID_3COL)).toBeVisible();

    // Resize to compact
    await page.setViewportSize({ width: 375, height: 812 });

    // Wait for layout to update — bottom-nav should appear
    await expect(page.locator(BOTTOM_NAV)).toBeVisible({ timeout: 5000 });
    await expect(page.locator(GRID_1COL)).toBeVisible({ timeout: 5000 });

    // Sidebar and 3-col grid should be gone
    expect(await page.locator(SIDEBAR).count()).toBe(0);
    expect(await page.locator(GRID_3COL).count()).toBe(0);
  });
});

test.describe("safe area rendering", () => {
  test.use({ viewport: { width: 1440, height: 900 } });

  test("safe area visualization section renders", async ({ page }) => {
    await page.goto("/kitchen_sink/");
    await page.waitForFunction(
      (sel) => document.querySelector(sel) !== null,
      SAFE_AREA_VIZ,
      { timeout: 10000 }
    );

    const safeArea = page.locator(SAFE_AREA_VIZ);
    await expect(safeArea).toBeVisible();

    // Should contain the heading and inset labels
    await expect(safeArea.getByText("Safe Area Insets")).toBeVisible();
    await expect(safeArea.getByText("Top")).toBeVisible();
    await expect(safeArea.getByText("Right")).toBeVisible();
    await expect(safeArea.getByText("Bottom")).toBeVisible();
    await expect(safeArea.getByText("Left")).toBeVisible();
  });
});

test.describe("viewport info panel", () => {
  test.use({ viewport: { width: 1440, height: 900 } });

  test("shows current dimensions and class", async ({ page }) => {
    await page.goto("/kitchen_sink/");
    await page.waitForFunction(
      (sel) => document.querySelector(sel) !== null,
      VIEWPORT_INFO,
      { timeout: 10000 }
    );

    const info = page.locator(VIEWPORT_INFO);
    await expect(info).toBeVisible();

    // Should show viewport info heading
    await expect(info.getByText("Viewport Info")).toBeVisible();

    // Should show width and height
    await expect(info.getByText(/Width:.*px/)).toBeVisible();
    await expect(info.getByText(/Height:.*px/)).toBeVisible();

    // Should show size class
    await expect(info.getByText(/Class:.*Expanded/)).toBeVisible();

    // Should show orientation
    await expect(info.getByText(/Orientation:/)).toBeVisible();
  });
});
