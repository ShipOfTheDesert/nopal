import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

const TABLE_SECTION = '[data-testid="data-table-section"]';
const TABLE = '[data-testid="data-table"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    TABLE,
    { timeout: 10000 }
  );
});

test("table renders with data", async ({ page }) => {
  const table = page.locator(TABLE);
  await expect(table).toBeVisible();
  await expect(table).toHaveAttribute("role", "table");

  // 1 header row + 5 data rows = 6 rows
  const rows = table.locator('[role="row"]');
  await expect(rows).toHaveCount(6);
});

test("click column header triggers sort", async ({ page }) => {
  const nameHeader = page.locator(`${TABLE} [role="columnheader"]`, {
    hasText: "Name",
  });

  // Click once — ascending
  await nameHeader.click();
  await expect(nameHeader).toHaveAttribute("aria-sort", "ascending");

  // Click again — descending
  await nameHeader.click();
  await expect(nameHeader).toHaveAttribute("aria-sort", "descending");
});

test("non-sorted columns have no aria-sort", async ({ page }) => {
  const nameHeader = page.locator(`${TABLE} [role="columnheader"]`, {
    hasText: "Name",
  });
  const ageHeader = page.locator(`${TABLE} [role="columnheader"]`, {
    hasText: "Age",
  });
  const cityHeader = page.locator(`${TABLE} [role="columnheader"]`, {
    hasText: "City",
  });

  // Sort by Name
  await nameHeader.click();
  await expect(nameHeader).toHaveAttribute("aria-sort", "ascending");

  // Age and City should have no aria-sort
  await expect(ageHeader).not.toHaveAttribute("aria-sort");
  await expect(cityHeader).not.toHaveAttribute("aria-sort");
});

test("rows reorder on sort", async ({ page }) => {
  // Before sorting, data is in original order: Alice, Bob, Carol, Dave, Eve
  const cells = page.locator(`${TABLE} [role="row"] [role="cell"]`);

  // Sort by Age ascending — Bob(25), Dave(28), Alice(30), Eve(32), Carol(35)
  const ageHeader = page.locator(`${TABLE} [role="columnheader"]`, {
    hasText: "Age",
  });
  await ageHeader.click();
  await expect(ageHeader).toHaveAttribute("aria-sort", "ascending");

  // First data row, first cell should be Bob (youngest)
  // Each row has 3 cells; skip header row's cells.
  // Data cells start at index 0 of data rows.
  const dataRows = page.locator(`${TABLE} [role="row"]`);
  // Row 0 is header, row 1 is first data row
  const firstDataRowCells = dataRows.nth(1).locator('[role="cell"]');
  await expect(firstDataRowCells.first()).toHaveText("Bob");

  // Last data row should be Carol (oldest)
  const lastDataRowCells = dataRows.nth(5).locator('[role="cell"]');
  await expect(lastDataRowCells.first()).toHaveText("Carol");
});

test("axe accessibility audit", async ({ page }) => {
  const results = await new AxeBuilder({ page })
    .include(TABLE_SECTION)
    .analyze();
  expect(results.violations).toEqual([]);
});
