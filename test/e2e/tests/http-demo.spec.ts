import { test, expect } from "@playwright/test";

const GET_BTN = '[data-testid="get-btn"]';
const GET_STATUS = '[data-testid="get-status"]';
const GET_RESULT = '[data-testid="get-result"]';

const POST_BTN = '[data-testid="post-btn"]';
const POST_STATUS = '[data-testid="post-status"]';
const POST_RESULT = '[data-testid="post-result"]';

const PUT_BTN = '[data-testid="put-btn"]';
const PUT_STATUS = '[data-testid="put-status"]';
const PUT_RESULT = '[data-testid="put-result"]';

const DELETE_BTN = '[data-testid="delete-btn"]';
const DELETE_STATUS = '[data-testid="delete-status"]';
const DELETE_RESULT = '[data-testid="delete-result"]';

const DECODE_BTN = '[data-testid="decode-btn"]';
const DECODE_RESULT = '[data-testid="decode-result"]';

const TIMEOUT_BTN = '[data-testid="timeout-btn"]';
const TIMEOUT_ERROR = '[data-testid="timeout-error"]';

test("GET: clicking fetch shows loading then success", async ({ page }) => {
  await page.goto("/http_demo/");

  // Intercept GET to control timing so loading state is observable
  let fulfill: (() => void) | null = null;
  await page.route("**/jsonplaceholder.typicode.com/todos/1", (route) => {
    fulfill = () =>
      route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          userId: 1,
          id: 1,
          title: "delectus aut autem",
          completed: false,
        }),
      });
  });

  const getBtn = page.locator(GET_BTN);
  await getBtn.click();

  // Should show loading state
  const status = page.locator(GET_STATUS);
  await expect(status).toContainText("Loading");

  // Release the response
  fulfill!();

  // Should show result
  const result = page.locator(GET_RESULT);
  await expect(result).toBeVisible({ timeout: 10000 });
  const text = await result.textContent();
  expect(text).toContain("delectus aut autem");
});

test("POST: clicking send shows loading then success", async ({ page }) => {
  await page.goto("/http_demo/");

  // Intercept POST to control timing
  let fulfill: (() => void) | null = null;
  await page.route("**/jsonplaceholder.typicode.com/posts", (route) => {
    if (route.request().method() === "POST") {
      fulfill = () =>
        route.fulfill({
          status: 201,
          contentType: "application/json",
          body: JSON.stringify({
            id: 101,
            title: "nopal",
            body: "test",
            userId: 1,
          }),
        });
    } else {
      route.continue();
    }
  });

  const postBtn = page.locator(POST_BTN);
  await postBtn.click();

  // Should show loading state
  const status = page.locator(POST_STATUS);
  await expect(status).toContainText("Loading");

  // Release the response
  fulfill!();

  // Should show result
  const result = page.locator(POST_RESULT);
  await expect(result).toBeVisible({ timeout: 10000 });
  const text = await result.textContent();
  expect(text).toContain("nopal");
});

test("PUT: clicking send shows loading then success", async ({ page }) => {
  await page.goto("/http_demo/");

  // Intercept PUT to control timing
  let fulfill: (() => void) | null = null;
  await page.route("**/jsonplaceholder.typicode.com/posts/1", (route) => {
    if (route.request().method() === "PUT") {
      fulfill = () =>
        route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({
            id: 1,
            title: "updated",
            body: "via nopal",
          }),
        });
    } else {
      route.continue();
    }
  });

  const putBtn = page.locator(PUT_BTN);
  await putBtn.click();

  // Should show loading state
  const status = page.locator(PUT_STATUS);
  await expect(status).toContainText("Loading");

  // Release the response
  fulfill!();

  // Should show result
  const result = page.locator(PUT_RESULT);
  await expect(result).toBeVisible({ timeout: 10000 });
  const text = await result.textContent();
  expect(text).toContain("updated");
});

test("DELETE: clicking delete shows loading then success", async ({
  page,
}) => {
  await page.goto("/http_demo/");

  // Intercept DELETE to control timing
  let fulfill: (() => void) | null = null;
  await page.route("**/jsonplaceholder.typicode.com/posts/1", (route) => {
    if (route.request().method() === "DELETE") {
      fulfill = () =>
        route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify({}),
        });
    } else {
      route.continue();
    }
  });

  const deleteBtn = page.locator(DELETE_BTN);
  await deleteBtn.click();

  // Should show loading state
  const status = page.locator(DELETE_STATUS);
  await expect(status).toContainText("Loading");

  // Release the response
  fulfill!();

  // Should show result
  const result = page.locator(DELETE_RESULT);
  await expect(result).toBeVisible({ timeout: 10000 });
});

test("typed decode: clicking decode shows structured todo fields", async ({
  page,
}) => {
  await page.goto("/http_demo/");

  // Intercept GET to control response
  let fulfill: (() => void) | null = null;
  await page.route("**/jsonplaceholder.typicode.com/todos/1", (route) => {
    fulfill = () =>
      route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          userId: 1,
          id: 1,
          title: "delectus aut autem",
          completed: false,
        }),
      });
  });

  const decodeBtn = page.locator(DECODE_BTN);
  await decodeBtn.click();

  // Release the response
  fulfill!();

  // Should show structured fields
  const result = page.locator(DECODE_RESULT);
  await expect(result).toBeVisible({ timeout: 10000 });
  const text = await result.textContent();
  expect(text).toContain("userId:");
  expect(text).toContain("title:");
  expect(text).toContain("completed:");
});

test("timeout: request with short timeout shows timeout error", async ({
  page,
}) => {
  await page.goto("/http_demo/");

  // Intercept the delay endpoint and never fulfill — the OCaml timeout fires
  await page.route("**/httpbin.org/delay/**", () => {
    // intentionally never fulfilled
  });

  const timeoutBtn = page.locator(TIMEOUT_BTN);
  await timeoutBtn.click();

  // Should eventually show timeout error
  const error = page.locator(TIMEOUT_ERROR);
  await expect(error).toBeVisible({ timeout: 15000 });
  const text = await error.textContent();
  expect(text).toContain("timed out");
});

test("network error: invalid URL shows error state", async ({ page }) => {
  await page.goto("/http_demo/");

  // Intercept and abort the request to simulate network failure
  await page.route("**/httpbin.org/delay/**", (route) => {
    route.abort("connectionrefused");
  });

  const timeoutBtn = page.locator(TIMEOUT_BTN);
  await timeoutBtn.click();

  // Should show error but NOT "timed out" — it's a network error
  const error = page.locator(TIMEOUT_ERROR);
  await expect(error).toBeVisible({ timeout: 10000 });
  const text = await error.textContent();
  expect(text).not.toContain("timed out");
});
