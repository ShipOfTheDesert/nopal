import { test, expect } from "@playwright/test";

const SECTION_SELECTOR = "[data-section='chart-extensions']";

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION_SELECTOR,
    { timeout: 10000 }
  );
});

test("heat map renders grid", async ({ page }) => {
  const heatMap = page.locator("[data-testid='heat-map-sequential']");
  await expect(heatMap).toBeVisible();
  const canvas = heatMap.locator("canvas");
  await expect(canvas).toBeVisible();

  // Verify canvas has expected dimensions
  const size = await canvas.evaluate((el) => {
    const c = el as HTMLCanvasElement;
    return {
      w: c.getBoundingClientRect().width,
      h: c.getBoundingClientRect().height,
    };
  });
  expect(size.w).toBe(400);
  expect(size.h).toBe(250);

  // Diverging heat map should also render
  const diverging = page.locator("[data-testid='heat-map-diverging']");
  await expect(diverging).toBeVisible();
  const divCanvas = diverging.locator("canvas");
  await expect(divCanvas).toBeVisible();
});

test("heat map hover tooltip", async ({ page }) => {
  const heatMap = page.locator("[data-testid='heat-map-sequential']");
  const canvas = heatMap.locator("canvas");
  await expect(canvas).toBeVisible();

  // No tooltip before hover
  const tooltipBefore = heatMap.locator("[data-testid='chart-tooltip']");
  await expect(tooltipBefore).toHaveCount(0);

  // Hover over a cell in the grid — ~30% from left and top to land inside the data area
  const bbox = await canvas.boundingBox();
  expect(bbox).not.toBeNull();
  await canvas.hover({
    position: {
      x: Math.round(bbox!.width * 0.3), // ~30% across the grid
      y: Math.round(bbox!.height * 0.3), // ~30% down the grid
    },
  });

  // Tooltip should appear with P&L data
  const tooltip = heatMap.locator("[data-testid='chart-tooltip']");
  await expect(tooltip).toBeVisible({ timeout: 5000 });
});

test("candlestick chart renders", async ({ page }) => {
  const candlestick = page.locator("[data-testid='candlestick-chart']");
  await expect(candlestick).toBeVisible();
  const canvas = candlestick.locator("canvas");
  await expect(canvas).toBeVisible();

  // Verify canvas has expected dimensions
  const size = await canvas.evaluate((el) => {
    const c = el as HTMLCanvasElement;
    return {
      w: c.getBoundingClientRect().width,
      h: c.getBoundingClientRect().height,
    };
  });
  expect(size.w).toBe(400);
  expect(size.h).toBe(250);
});

test("candlestick hover shows OHLC", async ({ page }) => {
  const candlestick = page.locator("[data-testid='candlestick-chart']");
  const canvas = candlestick.locator("canvas");
  await expect(canvas).toBeVisible();

  // No tooltip before hover
  const tooltipBefore = candlestick.locator("[data-testid='chart-tooltip']");
  await expect(tooltipBefore).toHaveCount(0);

  const bbox = await canvas.boundingBox();
  expect(bbox).not.toBeNull();

  // 10 candles across the chart area (with padding). Sweep from ~20% to ~85%
  // of chart width, stepping by ~8% per candle, at vertical center.
  const candleRatios = [0.21, 0.29, 0.37, 0.46, 0.54, 0.62, 0.71, 0.79, 0.87];
  for (const ratio of candleRatios) {
    await canvas.hover({
      position: {
        x: Math.round(bbox!.width * ratio), // candle center position
        y: Math.round(bbox!.height * 0.5),  // vertical center of chart
      },
    });
    const t = candlestick.locator("[data-testid='chart-tooltip']");
    if ((await t.count()) > 0) break;
  }

  // Tooltip should appear with OHLC data
  const tooltip = candlestick.locator("[data-testid='chart-tooltip']");
  await expect(tooltip).toBeVisible({ timeout: 5000 });
  // Verify it contains OHLC format
  const text = await tooltip.textContent();
  expect(text).toMatch(/O:\d+\s*H:\d+\s*L:\d+\s*C:\d+/);
});

test("drawdown chart renders", async ({ page }) => {
  const drawdown = page.locator("[data-testid='drawdown-chart']");
  await expect(drawdown).toBeVisible();
  const canvas = drawdown.locator("canvas");
  await expect(canvas).toBeVisible();

  // Verify canvas has expected dimensions
  const size = await canvas.evaluate((el) => {
    const c = el as HTMLCanvasElement;
    return {
      w: c.getBoundingClientRect().width,
      h: c.getBoundingClientRect().height,
    };
  });
  expect(size.w).toBe(400);
  expect(size.h).toBe(250);
});

test("multi-pane layout renders", async ({ page }) => {
  const multiPane = page.locator("[data-testid='multi-pane-chart']");
  await expect(multiPane).toBeVisible();

  // Multi-pane should contain multiple canvas elements (one per pane)
  const canvases = multiPane.locator("canvas");
  const count = await canvases.count();
  expect(count).toBeGreaterThanOrEqual(3);

  // Overall container should have the combined height (250 * 2 = 500)
  for (let i = 0; i < count; i++) {
    await expect(canvases.nth(i)).toBeVisible();
  }
});

test("multi-pane synchronized pan", async ({ page }) => {
  const multiPane = page.locator("[data-testid='multi-pane-chart']");
  await expect(multiPane).toBeVisible();

  // Get the overlay element that handles pan/zoom events
  const box = multiPane.locator("div").first();

  // Perform a drag to trigger pan — start at center, drag left by 25% of width
  const boundingBox = await box.boundingBox();
  expect(boundingBox).not.toBeNull();
  const startX = boundingBox!.x + boundingBox!.width * 0.5;  // center of chart
  const startY = boundingBox!.y + boundingBox!.height * 0.5; // center of chart
  const dragDistance = boundingBox!.width * 0.25; // drag left by 25% of width

  await page.mouse.move(startX, startY);
  await page.mouse.down();
  await page.mouse.move(startX - dragDistance, startY, { steps: 5 });
  await page.mouse.up();

  // After panning, the panzoom line chart (which shares domain_window)
  // should still render without errors
  const panzoom = page.locator("[data-testid='panzoom-line-chart']");
  const panzoomCanvas = panzoom.locator("canvas");
  await expect(panzoomCanvas).toBeVisible();
});

test("multi-pane synchronized zoom", async ({ page }) => {
  const multiPane = page.locator("[data-testid='multi-pane-chart']");
  await expect(multiPane).toBeVisible();

  // Get the overlay element for wheel events
  const box = multiPane.locator("div").first();
  const boundingBox = await box.boundingBox();
  expect(boundingBox).not.toBeNull();

  // Zoom at the center of the element
  const centerX = boundingBox!.x + boundingBox!.width * 0.5;
  const centerY = boundingBox!.y + boundingBox!.height * 0.5;

  // Perform a wheel scroll to trigger zoom
  await page.mouse.move(centerX, centerY);
  await page.mouse.wheel(0, -100);

  // After zooming, the panzoom line chart (which shares domain_window)
  // should still render without errors
  const panzoom = page.locator("[data-testid='panzoom-line-chart']");
  const panzoomCanvas = panzoom.locator("canvas");
  await expect(panzoomCanvas).toBeVisible();
});

test("pan and zoom on line chart", async ({ page }) => {
  const panzoom = page.locator("[data-testid='panzoom-line-chart']");
  await expect(panzoom).toBeVisible();
  const canvas = panzoom.locator("canvas");
  await expect(canvas).toBeVisible();

  // Verify canvas has expected wider dimensions (400 * 1.5 = 600)
  const size = await canvas.evaluate((el) => {
    const c = el as HTMLCanvasElement;
    return {
      w: c.getBoundingClientRect().width,
      h: c.getBoundingClientRect().height,
    };
  });
  expect(size.w).toBe(600);
  expect(size.h).toBe(250);

  // Hover at ~30% across and vertical center to trigger hover interaction
  const bbox = await canvas.boundingBox();
  expect(bbox).not.toBeNull();
  await canvas.hover({
    position: {
      x: Math.round(bbox!.width * 0.3), // ~30% across the chart data area
      y: Math.round(bbox!.height * 0.5), // vertical center
    },
  });

  // The basic line chart (in the charts section) should show a tooltip
  // because it shares model.chart_hover and has format_tooltip set
  const lineChart = page.locator("[data-testid='line-chart']");
  const tooltip = lineChart.locator("[data-testid='chart-tooltip']");
  await expect(tooltip).toBeVisible({ timeout: 5000 });
});
