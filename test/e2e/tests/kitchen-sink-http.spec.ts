import { test, expect } from "@playwright/test";

const SECTION = '[data-section="http"]';
const FETCH_BTN = '[data-testid="fetch-btn"]';
const HTTP_STATUS = '[data-testid="http-status"]';
const HTTP_RESULT = '[data-testid="http-result"]';
const HTTP_ERROR = '[data-testid="http-error"]';

const POST_SECTION = '[data-section="http-post"]';
const POST_BTN = '[data-testid="post-btn"]';
const POST_STATUS = '[data-testid="post-status"]';
const POST_RESULT = '[data-testid="post-result"]';
const POST_ERROR = '[data-testid="post-error"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("http section renders with fetch button", async ({ page }) => {
  const section = page.locator(SECTION);
  await expect(section).toBeVisible();

  const fetchBtn = page.locator(FETCH_BTN);
  await expect(fetchBtn).toBeVisible();
  await expect(fetchBtn).toContainText("Fetch");
});

test("clicking fetch shows loading then result", async ({ page }) => {
  const fetchBtn = page.locator(FETCH_BTN);
  await fetchBtn.click();

  // Should show loading state
  const status = page.locator(HTTP_STATUS);
  await expect(status).toContainText("Loading");

  // Should eventually show result (success or error — both prove the MVU loop works)
  const outcome = page.locator(`${HTTP_RESULT}, ${HTTP_ERROR}`);
  await expect(outcome).toBeVisible({ timeout: 10000 });
});

test("result displays response content", async ({ page }) => {
  const fetchBtn = page.locator(FETCH_BTN);
  await fetchBtn.click();

  // Wait for either success or error outcome
  const outcome = page.locator(`${HTTP_RESULT}, ${HTTP_ERROR}`);
  await expect(outcome).toBeVisible({ timeout: 10000 });

  const text = await outcome.textContent();
  expect(text).toBeTruthy();
  expect(text!.length).toBeGreaterThan(0);
});

test("post section renders with send button", async ({ page }) => {
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    POST_SECTION,
    { timeout: 10000 }
  );

  const section = page.locator(POST_SECTION);
  await expect(section).toBeVisible();

  const postBtn = page.locator(POST_BTN);
  await expect(postBtn).toBeVisible();
  await expect(postBtn).toContainText("Send");
});

test("clicking send shows loading then result", async ({ page }) => {
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    POST_SECTION,
    { timeout: 10000 }
  );

  const postBtn = page.locator(POST_BTN);
  await postBtn.click();

  // Should show loading state
  const status = page.locator(POST_STATUS);
  await expect(status).toContainText("Loading");

  // Should eventually show result (success or error — both prove the MVU loop works)
  const outcome = page.locator(`${POST_RESULT}, ${POST_ERROR}`);
  await expect(outcome).toBeVisible({ timeout: 10000 });
});
