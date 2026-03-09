import { test, expect } from "@playwright/test";
import * as fs from "fs";
import * as path from "path";
import { TimingResult, median } from "./utils";

const RUNS = 5;
const RESULTS_DIR = path.join(__dirname, "results");

test.describe("custom benchmarks", () => {
  const results: TimingResult[] = [];

  test.beforeAll(() => {
    if (!fs.existsSync(RESULTS_DIR)) {
      fs.mkdirSync(RESULTS_DIR, { recursive: true });
    }
  });

  test.afterAll(() => {
    fs.writeFileSync(
      path.join(RESULTS_DIR, "custom.json"),
      JSON.stringify(results, null, 2)
    );
  });

  test("incremental update 1000", async ({ page }) => {
    const values: number[] = [];

    for (let i = 0; i < RUNS; i++) {
      await page.goto("/");
      await page.waitForLoadState("load");

      // Create 1000 rows
      await page.click("#run");
      await page.waitForFunction(
        () => document.querySelectorAll("#tbody > *").length === 1000,
        { timeout: 30_000 }
      );

      // Snapshot the first row text before update (canonical jsfb updates index 0, 10, 20...)
      const before = await page.evaluate(() => {
        const row = document.querySelectorAll("#tbody > *")[0];
        return row?.textContent ?? "";
      });

      // Mark start, dispatch, then wait for DOM to reflect the change
      await page.evaluate(() => {
        performance.clearMarks();
        performance.clearMeasures();
        performance.mark("inc-start");

        const dispatch = (window as any).__nopal_bench_dispatch;
        dispatch("update_every_10th");
      });

      // Wait for the DOM to actually render the update (rAF cycle)
      await page.waitForFunction(
        (prev) => {
          const row = document.querySelectorAll("#tbody > *")[0];
          return row?.textContent !== prev && (row?.textContent?.includes(" !!!") ?? false);
        },
        before,
        { timeout: 10_000 }
      );

      // Mark end after DOM has updated
      const duration = await page.evaluate(() => {
        performance.mark("inc-end");
        performance.measure("incremental", "inc-start", "inc-end");
        const entries = performance.getEntriesByName("incremental", "measure");
        return entries[entries.length - 1].duration;
      });

      values.push(duration);
    }

    const result: TimingResult = {
      name: "incremental_update_1000",
      values,
      median: median(values),
      unit: "ms",
    };
    results.push(result);

    expect(result.median).toBeGreaterThan(0);
  });

  test("message throughput 10000", async ({ page }) => {
    const values: number[] = [];

    for (let i = 0; i < RUNS; i++) {
      await page.goto("/");
      await page.waitForLoadState("load");

      // Dispatch 10,000 messages in a tight loop and measure total time
      const duration = await page.evaluate(() => {
        const dispatch = (window as any).__nopal_bench_dispatch;
        if (!dispatch) throw new Error("__nopal_bench_dispatch not found");

        performance.clearMarks();
        performance.clearMeasures();
        performance.mark("throughput-start");

        for (let j = 0; j < 10_000; j++) {
          dispatch("select");
        }

        performance.mark("throughput-end");
        performance.measure("throughput", "throughput-start", "throughput-end");
        const entries = performance.getEntriesByName("throughput", "measure");
        return entries[entries.length - 1].duration;
      });

      values.push(duration);
    }

    const result: TimingResult = {
      name: "message_throughput_10000",
      values,
      median: median(values),
      unit: "ms",
    };
    results.push(result);

    expect(result.median).toBeGreaterThan(0);
  });
});
