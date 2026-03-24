import { test, expect } from "@playwright/test";

const SECTION = '[data-section="tauri-tray"]';
const HIDE_BTN = '[data-testid="tray-hide-btn"]';
const TOOLTIP_INPUT = '[data-testid="tray-tooltip-input"]';
const SET_TOOLTIP_BTN = '[data-testid="tray-set-tooltip-btn"]';
const SHOW_ICON_BTN = '[data-testid="tray-show-btn"]';
const HIDE_ICON_BTN = '[data-testid="tray-hide-icon-btn"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("tray section renders with heading and hide button", async ({ page }) => {
  const section = page.locator(SECTION);
  await expect(section.getByText("Tray", { exact: true })).toBeVisible();

  const hideBtn = page.locator(HIDE_BTN);
  await expect(hideBtn).toBeVisible();
  await expect(hideBtn).toContainText("Hide to Tray");
});

test("tray tooltip controls render", async ({ page }) => {
  const input = page.locator(TOOLTIP_INPUT);
  await expect(input).toBeVisible();

  const setBtn = page.locator(SET_TOOLTIP_BTN);
  await expect(setBtn).toBeVisible();
  await expect(setBtn).toContainText("Set Tooltip");
});

test("tray visibility controls render", async ({ page }) => {
  const showBtn = page.locator(SHOW_ICON_BTN);
  await expect(showBtn).toBeVisible();
  await expect(showBtn).toContainText("Show Tray Icon");

  const hideBtn = page.locator(HIDE_ICON_BTN);
  await expect(hideBtn).toBeVisible();
  await expect(hideBtn).toContainText("Hide Tray Icon");
});

test("tray instructions render", async ({ page }) => {
  const section = page.locator(SECTION);
  await expect(
    section.getByText("Click the tray icon to restore the window")
  ).toBeVisible();
});
