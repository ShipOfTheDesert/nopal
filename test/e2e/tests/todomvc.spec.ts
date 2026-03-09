import { test, expect } from "@playwright/test";

const TODO_INPUT = 'input[placeholder="What needs to be done?"]';
const TOGGLE_ALL = 'button[data-action="toggle-all"]';
const MAIN_SECTION = '[data-section="main"]';
const FOOTER_SECTION = '[data-section="footer"]';
const TODO_COUNT = '[data-section="todo-count"]';

function todoToggle(id: number) {
  return `button[data-action="toggle-${id}"]`;
}

function todoLabel(id: number) {
  return `button[data-action="edit-${id}"]`;
}

function todoDelete(id: number) {
  return `button[data-action="delete-${id}"]`;
}

const EDIT_INPUT = 'input[data-action="edit-input"]';

test.beforeEach(async ({ page }) => {
  // Clear localStorage and navigate fresh
  await page.goto("/todomvc/");
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: "load" });
  // Wait for the Nopal app to mount and render the header input
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    TODO_INPUT,
    { timeout: 10000 }
  );
});

test("add a new todo", async ({ page }) => {
  const input = page.locator(TODO_INPUT);
  await input.fill("Buy milk");
  await input.press("Enter");

  // Verify todo appears
  await expect(page.locator(todoLabel(1))).toHaveText("Buy milk");

  // Verify input is cleared
  await expect(input).toHaveValue("");

  // Empty input does not create a todo
  await input.press("Enter");
  // Still only one todo label button
  const labels = page.locator(`${MAIN_SECTION} button[data-action^="edit-"]`);
  await expect(labels).toHaveCount(1);
});

test("complete a todo", async ({ page }) => {
  const input = page.locator(TODO_INPUT);
  await input.fill("Buy milk");
  await input.press("Enter");

  // Click toggle checkbox
  await page.click(todoToggle(1));

  // Verify marked completed (toggle text changes to [x])
  await expect(page.locator(todoToggle(1))).toHaveText("[x]");
});

test("toggle all todos", async ({ page }) => {
  const input = page.locator(TODO_INPUT);
  await input.fill("Todo 1");
  await input.press("Enter");
  await input.fill("Todo 2");
  await input.press("Enter");

  // Toggle all to completed
  await page.click(TOGGLE_ALL);
  await expect(page.locator(todoToggle(1))).toHaveText("[x]");
  await expect(page.locator(todoToggle(2))).toHaveText("[x]");

  // Toggle all back to active
  await page.click(TOGGLE_ALL);
  await expect(page.locator(todoToggle(1))).toHaveText("[ ]");
  await expect(page.locator(todoToggle(2))).toHaveText("[ ]");
});

test("delete a todo", async ({ page }) => {
  const input = page.locator(TODO_INPUT);
  await input.fill("Buy milk");
  await input.press("Enter");

  // Click destroy button
  await page.click(todoDelete(1));

  // Verify removed
  await expect(page.locator(todoLabel(1))).toHaveCount(0);
});

test("edit a todo", async ({ page }) => {
  const input = page.locator(TODO_INPUT);
  await input.fill("Buy milk");
  await input.press("Enter");

  // Double-click label to enter edit mode
  await page.dblclick(todoLabel(1));

  // Edit input should appear with current text
  const editInput = page.locator(EDIT_INPUT);
  await expect(editInput).toBeVisible();

  // Clear and type new text
  await editInput.fill("Buy cheese");
  await editInput.press("Enter");

  // Verify updated
  await expect(page.locator(todoLabel(1))).toHaveText("Buy cheese");
});

test("cancel editing with Escape", async ({ page }) => {
  const input = page.locator(TODO_INPUT);
  await input.fill("Buy milk");
  await input.press("Enter");

  // Double-click to edit
  await page.dblclick(todoLabel(1));
  const editInput = page.locator(EDIT_INPUT);
  await editInput.fill("Changed text");
  await editInput.press("Escape");

  // Original text restored
  await expect(page.locator(todoLabel(1))).toHaveText("Buy milk");
});

test("filter active todos", async ({ page }) => {
  const input = page.locator(TODO_INPUT);
  await input.fill("Active todo");
  await input.press("Enter");
  await input.fill("Completed todo");
  await input.press("Enter");

  // Complete the second one
  await page.click(todoToggle(2));

  // Click "Active" filter (scoped to footer to avoid matching todo labels)
  await page
    .locator(FOOTER_SECTION)
    .getByRole("button", { name: "Active", exact: true })
    .click();

  // Only active todo visible
  await expect(page.locator(todoLabel(1))).toBeVisible();
  await expect(page.locator(todoLabel(2))).toHaveCount(0);
});

test("filter completed todos", async ({ page }) => {
  const input = page.locator(TODO_INPUT);
  await input.fill("Active todo");
  await input.press("Enter");
  await input.fill("Completed todo");
  await input.press("Enter");

  // Complete the second one
  await page.click(todoToggle(2));

  // Click "Completed" filter (scoped to footer to avoid matching todo labels)
  await page
    .locator(FOOTER_SECTION)
    .getByRole("button", { name: "Completed", exact: true })
    .click();

  // Only completed todo visible
  await expect(page.locator(todoLabel(1))).toHaveCount(0);
  await expect(page.locator(todoLabel(2))).toBeVisible();
});

test("clear completed", async ({ page }) => {
  const input = page.locator(TODO_INPUT);
  await input.fill("Todo 1");
  await input.press("Enter");
  await input.fill("Todo 2");
  await input.press("Enter");

  // Complete first todo
  await page.click(todoToggle(1));

  // Click "Clear completed"
  await page
    .locator(FOOTER_SECTION)
    .getByRole("button", { name: "Clear completed", exact: true })
    .click();

  // Only active todo remains
  await expect(page.locator(todoLabel(1))).toHaveCount(0);
  await expect(page.locator(todoLabel(2))).toBeVisible();
});

test("persist todos across reload", async ({ page }) => {
  const input = page.locator(TODO_INPUT);
  await input.fill("Persistent todo");
  await input.press("Enter");

  // Reload page
  await page.reload();

  // Todo should still be present
  await expect(page.locator(todoLabel(1))).toHaveText("Persistent todo");
});

test("direct URL navigation to filter", async ({ page }) => {
  const input = page.locator(TODO_INPUT);
  await input.fill("Active todo");
  await input.press("Enter");
  await input.fill("Completed todo");
  await input.press("Enter");

  // Complete the second one
  await page.click(todoToggle(2));

  // Navigate directly to /#/completed (hash-based routing)
  await page.goto("/todomvc/#/completed");

  // Only completed todo visible
  await expect(page.locator(todoLabel(1))).toHaveCount(0);
  await expect(page.locator(todoLabel(2))).toBeVisible();
});
