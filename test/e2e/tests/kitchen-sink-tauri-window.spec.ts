import { test, expect } from "@playwright/test";

// Render-correctness DOM checks (ADR 0108): these run in a plain browser where
// Tauri `invoke` is absent, so they assert markup only. Selectors migrated to
// the data-action/data-field anchors (REQ-F2); the real IPC behaviour is in
// test/e2e/tauri/window.e2e.ts.
const SECTION = '[data-section="tauri-window"]';
const SHOW_BTN = '[data-action="tauri-window-show"]';
const HIDE_BTN = '[data-action="tauri-window-hide"]';
const QUERY_VISIBLE_BTN = '[data-action="tauri-window-query-visible"]';
const SET_FOCUS_BTN = '[data-action="tauri-window-set-focus"]';
const CENTER_BTN = '[data-action="tauri-window-center"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("window visibility controls render", async ({ page }) => {
  const showBtn = page.locator(SHOW_BTN);
  const hideBtn = page.locator(HIDE_BTN);
  const queryBtn = page.locator(QUERY_VISIBLE_BTN);

  await expect(showBtn).toBeVisible();
  await expect(showBtn).toContainText("Show");

  await expect(hideBtn).toBeVisible();
  await expect(hideBtn).toContainText("Hide");

  await expect(queryBtn).toBeVisible();
  await expect(queryBtn).toContainText("Query Visible");

  // Status text should render with initial value
  const section = page.locator(SECTION);
  await expect(section.getByText(/Visible:/)).toBeVisible();
});

test("window focus button renders", async ({ page }) => {
  const focusBtn = page.locator(SET_FOCUS_BTN);
  await expect(focusBtn).toBeVisible();
  await expect(focusBtn).toContainText("Set Focus");
});

test("window center button renders", async ({ page }) => {
  const centerBtn = page.locator(CENTER_BTN);
  await expect(centerBtn).toBeVisible();
  await expect(centerBtn).toContainText("Center");
});
