import { test, expect } from "@playwright/test";

// Render-correctness DOM checks (ADR 0108): plain-browser markup assertions;
// Tauri `invoke` is absent here. Selectors migrated to the data-action/data-field
// anchors (REQ-F2); the real IPC tray behaviour is in test/e2e/tauri/tray.e2e.ts.
const SECTION = '[data-section="tauri-tray"]';
const HIDE_BTN = '[data-action="tauri-tray-hide-window"]';
const TOOLTIP_INPUT = '[data-field="tauri-tray-tooltip"]';
const SET_TOOLTIP_BTN = '[data-action="tauri-tray-set-tooltip"]';
const SHOW_ICON_BTN = '[data-action="tauri-tray-show-icon"]';
const HIDE_ICON_BTN = '[data-action="tauri-tray-hide-icon"]';

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
