import { test, expect } from "@playwright/test";
import * as fs from "fs";
import * as path from "path";
import { TimingResult, median } from "./utils";

const RUNS = 5;
const RESULTS_DIR = path.join(__dirname, "results");
const CHARTS_URL = "http://localhost:3002";

test.describe("chart benchmarks", () => {
  const results: TimingResult[] = [];

  test.beforeAll(() => {
    if (!fs.existsSync(RESULTS_DIR)) {
      fs.mkdirSync(RESULTS_DIR, { recursive: true });
    }
  });

  test.afterAll(() => {
    fs.writeFileSync(
      path.join(RESULTS_DIR, "charts.json"),
      JSON.stringify(results, null, 2)
    );
  });

  test("candlestick 1k candles", async ({ page }) => {
    const values: number[] = [];

    for (let i = 0; i < RUNS; i++) {
      await page.goto(CHARTS_URL);
      await page.waitForLoadState("load");

      // Click clear to reset
      await page.click("#clear");
      await page.waitForTimeout(100);

      const duration = await page.evaluate(() => {
        performance.clearMarks();
        performance.clearMeasures();
        performance.mark("bench-start");
      }).then(() =>
        page.click("#candlestick-1k").then(() =>
          page.waitForFunction(
            () => {
              const output = document.querySelector("#chart-output");
              return output && output.children.length > 0 &&
                output.innerHTML.includes("canvas");
            },
            { timeout: 30_000 }
          ).then(() =>
            page.evaluate(() => {
              performance.mark("bench-end");
              performance.measure("candlestick", "bench-start", "bench-end");
              const entries = performance.getEntriesByName("candlestick", "measure");
              return entries[entries.length - 1].duration;
            })
          )
        )
      );

      values.push(duration);
    }

    const result: TimingResult = {
      name: "candlestick_1k",
      values,
      median: median(values),
      unit: "ms",
    };
    results.push(result);
    expect(result.median).toBeGreaterThan(0);
  });

  test("heat map 50x50", async ({ page }) => {
    const values: number[] = [];

    for (let i = 0; i < RUNS; i++) {
      await page.goto(CHARTS_URL);
      await page.waitForLoadState("load");

      await page.click("#clear");
      await page.waitForTimeout(100);

      const duration = await page.evaluate(() => {
        performance.clearMarks();
        performance.clearMeasures();
        performance.mark("bench-start");
      }).then(() =>
        page.click("#heatmap-50x50").then(() =>
          page.waitForFunction(
            () => {
              const output = document.querySelector("#chart-output");
              return output && output.children.length > 0 &&
                output.innerHTML.includes("canvas");
            },
            { timeout: 30_000 }
          ).then(() =>
            page.evaluate(() => {
              performance.mark("bench-end");
              performance.measure("heatmap", "bench-start", "bench-end");
              const entries = performance.getEntriesByName("heatmap", "measure");
              return entries[entries.length - 1].duration;
            })
          )
        )
      );

      values.push(duration);
    }

    const result: TimingResult = {
      name: "heat_map_50x50",
      values,
      median: median(values),
      unit: "ms",
    };
    results.push(result);
    expect(result.median).toBeGreaterThan(0);
  });

  test("line 100k clipped to 500", async ({ page }) => {
    const values: number[] = [];

    for (let i = 0; i < RUNS; i++) {
      await page.goto(CHARTS_URL);
      await page.waitForLoadState("load");

      await page.click("#clear");
      await page.waitForTimeout(100);

      const duration = await page.evaluate(() => {
        performance.clearMarks();
        performance.clearMeasures();
        performance.mark("bench-start");
      }).then(() =>
        page.click("#line-100k").then(() =>
          page.waitForFunction(
            () => {
              const output = document.querySelector("#chart-output");
              return output && output.children.length > 0 &&
                output.innerHTML.includes("canvas");
            },
            { timeout: 60_000 }
          ).then(() =>
            page.evaluate(() => {
              performance.mark("bench-end");
              performance.measure("line100k", "bench-start", "bench-end");
              const entries = performance.getEntriesByName("line100k", "measure");
              return entries[entries.length - 1].duration;
            })
          )
        )
      );

      values.push(duration);
    }

    const result: TimingResult = {
      name: "line_100k_clipped",
      values,
      median: median(values),
      unit: "ms",
    };
    results.push(result);
    expect(result.median).toBeGreaterThan(0);
  });

  test("lttb 100k to 1k", async ({ page }) => {
    const values: number[] = [];

    for (let i = 0; i < RUNS; i++) {
      await page.goto(CHARTS_URL);
      await page.waitForLoadState("load");

      await page.click("#clear");
      await page.waitForTimeout(100);

      const duration = await page.evaluate(() => {
        performance.clearMarks();
        performance.clearMeasures();
        performance.mark("bench-start");
      }).then(() =>
        page.click("#lttb-100k").then(() =>
          page.waitForFunction(
            () => {
              const output = document.querySelector("#chart-output");
              return output && output.textContent?.includes("lttb done");
            },
            { timeout: 60_000 }
          ).then(() =>
            page.evaluate(() => {
              performance.mark("bench-end");
              performance.measure("lttb", "bench-start", "bench-end");
              const entries = performance.getEntriesByName("lttb", "measure");
              return entries[entries.length - 1].duration;
            })
          )
        )
      );

      values.push(duration);
    }

    const result: TimingResult = {
      name: "lttb_100k_to_1k",
      values,
      median: median(values),
      unit: "ms",
    };
    results.push(result);
    expect(result.median).toBeGreaterThan(0);
  });
});
