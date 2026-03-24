import { test, expect } from "@playwright/test";

const SECTION = '[data-section="tauri-window"]';
const SHOW_BTN = '[data-testid="show-btn"]';
const HIDE_BTN = '[data-testid="hide-btn"]';
const QUERY_VISIBLE_BTN = '[data-testid="query-visible-btn"]';
const SET_FOCUS_BTN = '[data-testid="set-focus-btn"]';
const CENTER_BTN = '[data-testid="center-btn"]';

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
