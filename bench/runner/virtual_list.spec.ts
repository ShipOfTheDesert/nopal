import { test, expect } from "@playwright/test";
import * as fs from "fs";
import * as path from "path";
import { TimingResult, median } from "./utils";

const RUNS = 5;
const RESULTS_DIR = path.join(__dirname, "results");
const VL_URL = "http://localhost:3003";

test.describe("virtual list benchmarks", () => {
  const results: TimingResult[] = [];

  test.beforeAll(() => {
    if (!fs.existsSync(RESULTS_DIR)) {
      fs.mkdirSync(RESULTS_DIR, { recursive: true });
    }
  });

  test.afterAll(() => {
    fs.writeFileSync(
      path.join(RESULTS_DIR, "virtual_list.json"),
      JSON.stringify(results, null, 2)
    );
  });

  test("initial render 10000 items", async ({ page }) => {
    const values: number[] = [];

    for (let i = 0; i < RUNS; i++) {
      await page.goto(VL_URL);
      await page.waitForSelector("[data-bench-row]", { timeout: 10_000 });

      // Measure from navigationStart to now (DOM is ready with virtual list)
      const duration = await page.evaluate(() => {
        const navStart = performance.timing.navigationStart;
        return performance.now() + (performance.timeOrigin - navStart);
      });

      // Verify virtualisation is active: few DOM nodes, not 10,000
      const rowCount = await page.evaluate(() => {
        return document.querySelectorAll("[data-bench-row]").length;
      });

      expect(rowCount).toBeLessThan(100);
      expect(rowCount).toBeGreaterThan(0);

      values.push(duration);
    }

    const result: TimingResult = {
      name: "initial_render_10000",
      values,
      median: median(values),
      unit: "ms",
    };
    results.push(result);
    expect(result.median).toBeGreaterThan(0);
  });

  test("scroll 10000 items", async ({ page }) => {
    const values: number[] = [];

    for (let i = 0; i < RUNS; i++) {
      await page.goto(VL_URL);
      await page.waitForLoadState("load");

      // Wait for virtual list to be rendered
      await page.waitForSelector("[data-bench-row]", { timeout: 10_000 });

      // Dispatch a series of scroll positions and measure total time
      const duration = await page.evaluate(() => {
        const dispatch = (window as any).__nopal_bench_dispatch;
        if (!dispatch) throw new Error("__nopal_bench_dispatch not found");

        performance.clearMarks();
        performance.clearMeasures();
        performance.mark("scroll-start");

        // Simulate scrolling through the list in increments
        for (let offset = 0; offset <= 390_000; offset += 1000) {
          dispatch(`scroll:${offset}`);
        }

        performance.mark("scroll-end");
        performance.measure("scroll", "scroll-start", "scroll-end");
        const entries = performance.getEntriesByName("scroll", "measure");
        return entries[entries.length - 1].duration;
      });

      values.push(duration);
    }

    const result: TimingResult = {
      name: "scroll_10000",
      values,
      median: median(values),
      unit: "ms",
    };
    results.push(result);
    expect(result.median).toBeGreaterThan(0);
  });
});
