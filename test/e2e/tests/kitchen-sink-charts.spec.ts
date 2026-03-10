import { test, expect } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    () => document.querySelector("[data-section='charts']") !== null,
    { timeout: 10000 }
  );
});

test("charts section renders", async ({ page }) => {
  const section = page.locator("[data-section='charts']");
  await expect(section).toBeVisible();
  await expect(section).toContainText("Charts");
});

test("bar chart canvas present", async ({ page }) => {
  const barChart = page.locator("[data-testid='bar-chart']");
  await expect(barChart).toBeVisible();
  const canvas = barChart.locator("canvas");
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

test("bar chart hover tooltip", async ({ page }) => {
  const barChart = page.locator("[data-testid='bar-chart']");
  const canvas = barChart.locator("canvas");
  await expect(canvas).toBeVisible();

  // No tooltip before hover
  const tooltipsBefore = barChart.locator("[data-testid='chart-tooltip']");
  await expect(tooltipsBefore).toHaveCount(0);

  // Hover over a bar area (canvas-relative coordinates)
  await canvas.hover({ position: { x: 100, y: 150 } });

  // Tooltip should appear
  const tooltip = barChart.locator("[data-testid='chart-tooltip']");
  await expect(tooltip).toBeVisible({ timeout: 5000 });
});

test("bar chart hover leave", async ({ page }) => {
  const barChart = page.locator("[data-testid='bar-chart']");
  const canvas = barChart.locator("canvas");
  await expect(canvas).toBeVisible();

  // Hover to trigger tooltip
  await canvas.hover({ position: { x: 100, y: 150 } });
  const tooltip = barChart.locator("[data-testid='chart-tooltip']");
  await expect(tooltip).toBeVisible({ timeout: 5000 });

  // Move away from the chart entirely (hover the page title)
  await page.locator("[data-section='charts']").locator("text=Charts").first().hover();

  // Tooltip should disappear
  await expect(tooltip).toHaveCount(0, { timeout: 5000 });
});

test("line chart hover crosshair", async ({ page }) => {
  const lineChart = page.locator("[data-testid='line-chart']");
  await expect(lineChart).toBeVisible();
  const canvas = lineChart.locator("canvas");
  await expect(canvas).toBeVisible();

  // Hover over the line chart area
  await canvas.hover({ position: { x: 200, y: 125 } });

  // Line chart should show tooltip on hover
  const tooltip = lineChart.locator("[data-testid='chart-tooltip']");
  await expect(tooltip).toBeVisible({ timeout: 5000 });
});

test("pie chart hover offset", async ({ page }) => {
  const pieChart = page.locator("[data-testid='pie-chart']");
  await expect(pieChart).toBeVisible();
  const canvas = pieChart.locator("canvas");
  await expect(canvas).toBeVisible();

  // Hover over the right side of the pie (where the largest segment is)
  await canvas.hover({ position: { x: 130, y: 80 } });

  // Pie chart should show tooltip on hover
  const tooltip = pieChart.locator("[data-testid='chart-tooltip']");
  await expect(tooltip).toBeVisible({ timeout: 5000 });
});

test("scatter chart hover", async ({ page }) => {
  const scatterChart = page.locator("[data-testid='scatter-chart']");
  await expect(scatterChart).toBeVisible();
  const canvas = scatterChart.locator("canvas");
  await expect(canvas).toBeVisible();

  // Hover over several positions until we hit a circle
  // Point (60, 30, 12) with default padding (50,40,20,40), 400x250:
  // chart area: x=50..380, y=40..210, domains X:(10,80) Y:(10,50)
  // cx = 50 + (60-10)/(80-10)*330 ≈ 286, cy = 210 - (30-10)/(50-10)*170 = 125
  const positions = [
    { x: 286, y: 125 },
    { x: 200, y: 100 },
    { x: 150, y: 150 },
    { x: 100, y: 125 },
    { x: 330, y: 80 },
  ];
  for (const pos of positions) {
    await canvas.hover({ position: pos });
    const t = scatterChart.locator("[data-testid='chart-tooltip']");
    if ((await t.count()) > 0) break;
  }

  // Scatter chart should show tooltip on hover
  const tooltip = scatterChart.locator("[data-testid='chart-tooltip']");
  await expect(tooltip).toBeVisible({ timeout: 5000 });
});

test("sparkline renders", async ({ page }) => {
  const sparklineRow = page.locator("[data-testid='sparkline-row']");
  await expect(sparklineRow).toBeVisible();
  // Should contain text labels and canvas elements
  await expect(sparklineRow).toContainText("Trend:");
  await expect(sparklineRow).toContainText("Growth:");
  const canvases = sparklineRow.locator("canvas");
  const count = await canvases.count();
  expect(count).toBe(2);
});

test("legend renders entries", async ({ page }) => {
  const legend = page.locator("[data-testid='chart-legend']");
  await expect(legend).toBeVisible();
  await expect(legend).toContainText("Revenue");
  await expect(legend).toContainText("Costs");
  await expect(legend).toContainText("Product A");
  await expect(legend).toContainText("Product B");
});

test("dashboard cross-chart hover", async ({ page }) => {
  // Hovering on the bar chart should also affect the line chart
  // (both share chart_hover state via model.chart_hover)
  const barChart = page.locator("[data-testid='bar-chart']");
  const lineChart = page.locator("[data-testid='line-chart']");
  const barCanvas = barChart.locator("canvas");

  // No tooltip on line chart before hover
  const lineTooltip = lineChart.locator("[data-testid='chart-tooltip']");
  await expect(lineTooltip).toHaveCount(0);

  // Hover over a bar in the bar chart
  await barCanvas.hover({ position: { x: 100, y: 150 } });

  // Both bar chart AND line chart should show tooltips (shared hover state)
  const barTooltip = barChart.locator("[data-testid='chart-tooltip']");
  await expect(barTooltip).toBeVisible({ timeout: 5000 });
  await expect(lineTooltip).toBeVisible({ timeout: 5000 });
});
