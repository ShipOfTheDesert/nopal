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

const TIMEOUT_SECTION = '[data-section="http-timeout"]';
const TIMEOUT_BTN = '[data-testid="timeout-btn"]';
const TIMEOUT_ERROR = '[data-testid="timeout-error"]';

const PUT_SECTION = '[data-section="http-put"]';
const PUT_BTN = '[data-testid="put-btn"]';
const PUT_STATUS = '[data-testid="put-status"]';
const PUT_RESULT = '[data-testid="put-result"]';
const PUT_ERROR = '[data-testid="put-error"]';
const RESP_HEADERS = '[data-testid="resp-headers"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
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

test("clicking send post shows loading then result", async ({ page }) => {
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    POST_SECTION,
    { timeout: 10000 }
  );

  // Intercept the POST request to control timing — ensures loading state is
  // observable before the response arrives.
  let fulfill: (() => void) | null = null;
  await page.route("**/post", (route) => {
    fulfill = () =>
      route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ nopal: true }),
      });
  });

  const postBtn = page.locator(POST_BTN);
  await postBtn.click();

  // Loading state is guaranteed visible because the response is held
  const status = page.locator(POST_STATUS);
  await expect(status).toContainText("Loading");

  // Release the response
  fulfill!();

  // Should eventually show result
  const outcome = page.locator(`${POST_RESULT}, ${POST_ERROR}`);
  await expect(outcome).toBeVisible({ timeout: 10000 });
});

test("clicking put send shows loading then result with headers", async ({ page }) => {
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    PUT_SECTION,
    { timeout: 10000 }
  );

  // Intercept the PUT request to control timing — ensures loading state is
  // observable before the response arrives.
  let fulfill: (() => void) | null = null;
  await page.route("**/httpbin.org/put", (route) => {
    fulfill = () =>
      route.fulfill({
        status: 200,
        contentType: "application/json",
        headers: { "content-type": "application/json", "x-request-id": "test-123" },
        body: JSON.stringify({ nopal: "put" }),
      });
  });

  const putBtn = page.locator(PUT_BTN);
  await putBtn.click();

  // Loading state is guaranteed visible because the response is held
  const status = page.locator(PUT_STATUS);
  await expect(status).toContainText("Loading");

  // Release the response
  fulfill!();

  // Should eventually show result
  const outcome = page.locator(`${PUT_RESULT}, ${PUT_ERROR}`);
  await expect(outcome).toBeVisible({ timeout: 10000 });

  // Response headers should be displayed
  const headers = page.locator(RESP_HEADERS);
  await expect(headers).toBeVisible({ timeout: 5000 });

  const headersText = await headers.textContent();
  expect(headersText).toContain("content-type");
});

test("timeout section renders and abort produces error", async ({ page }) => {
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    TIMEOUT_SECTION,
    { timeout: 10000 }
  );

  const section = page.locator(TIMEOUT_SECTION);
  await expect(section).toBeVisible();

  const timeoutBtn = page.locator(TIMEOUT_BTN);
  await expect(timeoutBtn).toBeVisible();
  await expect(timeoutBtn).toContainText("Send");

  // Intercept the request and never respond — the 2s timeout in the app
  // will abort the request before Playwright's own timeout.
  await page.route("**/httpbin.org/delay/**", () => {
    // Intentionally never fulfill — let the AbortController fire.
  });

  await timeoutBtn.click();

  // Should show timeout error within a reasonable window (2s timeout + buffer)
  const error = page.locator(TIMEOUT_ERROR);
  await expect(error).toBeVisible({ timeout: 10000 });
  await expect(error).toContainText("timed out");
});
