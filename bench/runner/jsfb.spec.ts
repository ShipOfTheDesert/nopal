import { test, expect, Page } from "@playwright/test";
import * as fs from "fs";
import * as path from "path";
import { TimingResult, median } from "./utils";

const RUNS = 5;
const RESULTS_DIR = path.join(__dirname, "results");

async function waitForRows(page: Page, count: number) {
  await page.waitForFunction(
    (n) => document.querySelectorAll("#tbody > *").length === n,
    count,
    { timeout: 30_000 }
  );
}

async function timeOperation(
  page: Page,
  name: string,
  action: () => Promise<void>,
  verify: () => Promise<void>,
  setup?: () => Promise<void>
): Promise<TimingResult> {
  const values: number[] = [];

  for (let i = 0; i < RUNS; i++) {
    // Run setup before timing (e.g. create rows needed by the operation)
    if (setup) {
      await setup();
    }

    // Clear performance entries
    await page.evaluate(() => {
      performance.clearMarks();
      performance.clearMeasures();
    });

    // Mark start
    await page.evaluate((n) => performance.mark(`${n}-start`), name);

    // Perform the operation
    await action();

    // Wait for DOM to settle
    await verify();

    // Mark end and measure
    await page.evaluate((n) => {
      performance.mark(`${n}-end`);
      performance.measure(n, `${n}-start`, `${n}-end`);
    }, name);

    const duration = await page.evaluate((n) => {
      const entries = performance.getEntriesByName(n, "measure");
      return entries[entries.length - 1].duration;
    }, name);

    values.push(duration);

    // Reset for next run — navigate fresh
    if (i < RUNS - 1) {
      await page.goto("/");
      await page.waitForLoadState("load");
    }
  }

  return { name, values, median: median(values), unit: "ms" };
}

test.describe("jsfb benchmarks", () => {
  const results: TimingResult[] = [];

  test.beforeAll(() => {
    if (!fs.existsSync(RESULTS_DIR)) {
      fs.mkdirSync(RESULTS_DIR, { recursive: true });
    }
  });

  test.afterAll(() => {
    fs.writeFileSync(
      path.join(RESULTS_DIR, "jsfb.json"),
      JSON.stringify(results, null, 2)
    );
  });

  test("create 1000 rows", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("load");

    const result = await timeOperation(
      page,
      "create_1000",
      async () => {
        await page.click("#run");
      },
      async () => {
        await waitForRows(page, 1000);
      }
    );
    results.push(result);

    // DOM correctness check
    await page.goto("/");
    await page.waitForLoadState("load");
    await page.click("#run");
    await waitForRows(page, 1000);
    const count = await page.locator("#tbody > *").count();
    expect(count).toBe(1000);
  });

  test("replace 1000 rows", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("load");

    const result = await timeOperation(
      page,
      "replace_1000",
      async () => {
        await page.click("#run");
      },
      async () => {
        await waitForRows(page, 1000);
      },
      async () => {
        await page.click("#run");
        await waitForRows(page, 1000);
      }
    );
    results.push(result);
  });

  test("partial update", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("load");

    const result = await timeOperation(
      page,
      "partial_update",
      async () => {
        await page.click("#update");
      },
      async () => {
        await page.waitForFunction(() => {
          const rows = document.querySelectorAll("#tbody > *");
          if (rows.length < 1) return false;
          const firstRow = rows[0];
          return firstRow?.textContent?.includes(" !!!");
        });
      },
      async () => {
        await page.click("#run");
        await waitForRows(page, 1000);
      }
    );
    results.push(result);
  });

  test("select row", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("load");

    const result = await timeOperation(
      page,
      "select_row",
      async () => {
        const firstRowButton = page.locator("#tbody > * >> nth=0 >> button >> nth=0");
        await firstRowButton.click();
      },
      async () => {
        await page.waitForFunction(() => {
          const rows = document.querySelectorAll("#tbody > *");
          return rows.length > 0 && (rows[0]?.querySelector("[data-selected]") !== null
            || rows[0]?.getAttribute("data-selected") === "true");
        });
      },
      async () => {
        await page.click("#run");
        await waitForRows(page, 1000);
      }
    );
    results.push(result);
  });

  test("swap rows", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("load");

    const result = await timeOperation(
      page,
      "swap_rows",
      async () => {
        await page.click("#swaprows");
      },
      async () => {
        await waitForRows(page, 1000);
      },
      async () => {
        await page.click("#run");
        await waitForRows(page, 1000);
      }
    );
    results.push(result);
  });

  test("remove row", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("load");

    const result = await timeOperation(
      page,
      "remove_row",
      async () => {
        const deleteButton = page.locator("#tbody > * >> nth=0 >> button >> nth=1");
        await deleteButton.click();
      },
      async () => {
        await waitForRows(page, 999);
      },
      async () => {
        await page.click("#run");
        await waitForRows(page, 1000);
      }
    );
    results.push(result);
  });

  test("create 10000 rows", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("load");

    const result = await timeOperation(
      page,
      "create_10000",
      async () => {
        await page.click("#runlots");
      },
      async () => {
        await waitForRows(page, 10000);
      }
    );
    results.push(result);
  });

  test("append 1000 rows", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("load");

    const result = await timeOperation(
      page,
      "append_1000",
      async () => {
        await page.click("#add");
      },
      async () => {
        await waitForRows(page, 2000);
      },
      async () => {
        await page.click("#run");
        await waitForRows(page, 1000);
      }
    );
    results.push(result);
  });

  test("clear rows", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("load");

    const result = await timeOperation(
      page,
      "clear_rows",
      async () => {
        await page.click("#clear");
      },
      async () => {
        await waitForRows(page, 0);
      },
      async () => {
        await page.click("#run");
        await waitForRows(page, 1000);
      }
    );
    results.push(result);
  });
});
