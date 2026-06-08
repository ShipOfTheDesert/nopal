import { test } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// Per-component E2E for nopal_ui Data_table (RFC 0112, Step 5). Drives the
// intrinsic `data-action="datatable-sort"` / `data-field=<column key>` anchor
// (Task 1) and asserts the sort message via telemetry (REQ-N2). The field
// anchor tracks the configured column key ("name"), not the header copy.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForFunction before asserting.

const SORT_NAME = '[data-action="datatable-sort"][data-field="name"]';

const SETTLE = 15000;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SORT_NAME,
    { timeout: 10000 }
  );
});

test("sort header click dispatches Sort via telemetry", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(SORT_NAME).click();
  await telemetry.waitForMessage("Sort:name", SETTLE);

  await telemetry.assertDispatched("Sort:name");
});

test("data-table section passes axe", async ({ page }, testInfo) => {
  await assertNoAxeViolations(
    page,
    testInfo,
    '[data-testid="data-table-section"]'
  );
});
