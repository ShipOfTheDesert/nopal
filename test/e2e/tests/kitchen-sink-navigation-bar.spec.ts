import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const NAV_SECTION = '[data-testid="navigation-bar-section"]';
const NAV_BAR = '[data-testid="navigation-bar"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    NAV_BAR,
    { timeout: 10000 }
  );
});

test("tab click switches content", async ({ page }) => {
  // Default is Home
  await expect(page.locator('[data-testid="nav-content-home"]')).toBeVisible();

  // Click Settings tab
  await page.locator('[data-testid="nav-tab-settings"]').click();
  await expect(
    page.locator('[data-testid="nav-content-settings"]')
  ).toBeVisible();
  await expect(
    page.locator('[data-testid="nav-content-home"]')
  ).not.toBeVisible();

  // Click About tab
  await page.locator('[data-testid="nav-tab-about"]').click();
  await expect(
    page.locator('[data-testid="nav-content-about"]')
  ).toBeVisible();
  await expect(
    page.locator('[data-testid="nav-content-settings"]')
  ).not.toBeVisible();
});

test("active tab is visually distinct", async ({ page }) => {
  // Home is active by default
  const homeTab = page.locator('[data-testid="nav-tab-home"]');
  const settingsTab = page.locator('[data-testid="nav-tab-settings"]');

  const homeBg = await homeTab.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );
  const settingsBg = await settingsTab.evaluate(
    (el) => getComputedStyle(el).backgroundColor
  );

  expect(homeBg).not.toEqual(settingsBg);
});

test("clicking active tab does not change state", async ({ page }) => {
  // Home is active by default — record current content
  const homeContent = page.locator('[data-testid="nav-content-home"]');
  await expect(homeContent).toBeVisible();

  // Click the already-active Home tab
  await page.locator('[data-testid="nav-tab-home"]').click();

  // Content should remain the same
  await expect(homeContent).toBeVisible();
  await expect(
    page.locator('[data-testid="nav-content-settings"]')
  ).not.toBeVisible();
  await expect(
    page.locator('[data-testid="nav-content-about"]')
  ).not.toBeVisible();
});

test("axe accessibility audit", async ({ page }) => {
  const results = await new AxeBuilder({ page })
    .include(NAV_SECTION)
    .analyze();
  expect(results.violations).toEqual([]);
});
