import { test, expect } from "@playwright/test";

// Render-correctness DOM checks (ADR 0108): plain-browser markup assertions;
// Tauri `invoke` is absent here. Selectors migrated to the data-action/data-field
// anchors (REQ-F2); the real IPC tray behaviour is in test/e2e/tauri/tray.e2e.ts.
// REQ-F7 reduced the tray surface to single-click hide/restore only — the icon,
// tooltip, and visibility controls are gone.
const SECTION = '[data-section="tauri-tray"]';
const HIDE_BTN = '[data-action="tauri-tray-hide-window"]';

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

test("tray instructions render", async ({ page }) => {
  const section = page.locator(SECTION);
  await expect(
    section.getByText("Click the tray icon to restore the window")
  ).toBeVisible();
});

test("removed tray controls are absent", async ({ page }) => {
  await expect(
    page.locator('[data-field="tauri-tray-tooltip"]')
  ).toHaveCount(0);
  await expect(
    page.locator('[data-action="tauri-tray-set-tooltip"]')
  ).toHaveCount(0);
  await expect(
    page.locator('[data-action="tauri-tray-show-icon"]')
  ).toHaveCount(0);
  await expect(
    page.locator('[data-action="tauri-tray-hide-icon"]')
  ).toHaveCount(0);
});
