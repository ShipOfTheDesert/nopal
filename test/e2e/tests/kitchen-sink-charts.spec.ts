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

// The donut section draws two donuts over a checkerboard of 40 px cells in a
// 560 x 280 scene. On canvas each hole is sampled at its centre and at a point
// in the opposite-coloured cell: a disc painted over the hole, whatever its
// colour, cannot match both. Every sample is 20 px from its cell's edges and
// well inside its hole, so antialiasing and devicePixelRatio cannot move the
// expected bytes.
const DONUT_SCENE = { width: 560, height: 280 };
const DONUT_CELL = 40;
const DONUT_INNER_RADIUS = 70;
const DONUT_HOLE_CENTRES = [
  { at: "multi-segment hole", cx: 140, cy: 140 },
  { at: "full-turn hole", cx: 420, cy: 140 },
];
const CHECKER_LIGHT = [250, 214, 165, 255];
const CHECKER_DARK = [74, 108, 111, 255];
const DONUT_HOLE_SAMPLES = [
  { at: "multi-segment hole centre", x: 140, y: 140, rgba: CHECKER_LIGHT },
  { at: "multi-segment hole, dark cell", x: 180, y: 140, rgba: CHECKER_DARK },
  { at: "full-turn hole centre", x: 420, y: 140, rgba: CHECKER_DARK },
  { at: "full-turn hole, light cell", x: 460, y: 140, rgba: CHECKER_LIGHT },
];
// One ring pixel per donut, 20 px from its cell's edges and about 89 px from
// the donut centre (between the 70 px hole and the ring's outer edge). A ring
// that was not drawn shows a checker colour here.
const DONUT_RING_SAMPLES = [
  { at: "multi-segment ring", x: 100, y: 60 },
  { at: "full-turn ring", x: 460, y: 60 },
];
const isChecker = (rgba: number[]) =>
  [CHECKER_LIGHT, CHECKER_DARK].some((c) => c.every((b, k) => b === rgba[k]));
const EXPECTED_HOLE_PIXELS = DONUT_HOLE_SAMPLES.map(({ at, rgba }) => ({
  at,
  rgba,
}));

test("donut hole shows the background (canvas)", async ({ page }) => {
  const canvas = page.locator("[data-testid='donut-canvas'] canvas");
  await expect(canvas).toBeVisible();
  const sample = (samples: { at: string; x: number; y: number }[]) =>
    canvas.evaluate((el, samples) => {
      const ctx = (el as HTMLCanvasElement).getContext("2d")!;
      const dpr = window.devicePixelRatio;
      return samples.map(({ at, x, y }) => ({
        at,
        rgba: Array.from(
          ctx.getImageData(Math.round(x * dpr), Math.round(y * dpr), 1, 1).data
        ),
      }));
    }, samples);
  await expect.poll(() => sample(DONUT_HOLE_SAMPLES)).toEqual(
    EXPECTED_HOLE_PIXELS
  );
  const rings = await sample(DONUT_RING_SAMPLES);
  expect(rings.map(({ at, rgba }) => ({ at, checker: isChecker(rgba) }))).toEqual(
    DONUT_RING_SAMPLES.map(({ at }) => ({ at, checker: false }))
  );
});

// SVG is checked pixel by pixel over each whole hole rather than at two
// points: a subpath split paints chords only a few pixels wide, which no
// sample 20 px from a cell edge lands on. The image is rasterised at a fixed
// size, so devicePixelRatio does not enter. The scanned disc stops 3 px inside
// the hole's edge, and pixels within 2 px of a cell boundary are skipped, so
// every pixel compared is a whole checker pixel matched exactly.
test("donut hole shows the background (SVG)", async ({ page }) => {
  const raster = DONUT_SCENE;
  const innerRadiusPx =
    (DONUT_INNER_RADIUS * raster.width) / DONUT_SCENE.width;
  const scanRadius = innerRadiusPx - 3;
  expect(scanRadius).toBe(67);
  const img = page.locator("[data-testid='donut-svg'] img");
  await expect(img).toBeVisible();
  const scans = await img.evaluate(
    async (el, { holes, rings, raster, cell, scanRadius, light, dark }) => {
      const image = el as HTMLImageElement;
      await image.decode();
      // The SVG root carries only a viewBox, so Chromium reports the default
      // 300 x 150 natural size; drawing at that size would resample the
      // checker.
      const offscreen = document.createElement("canvas");
      offscreen.width = raster.width;
      offscreen.height = raster.height;
      const ctx = offscreen.getContext("2d")!;
      ctx.drawImage(image, 0, 0, raster.width, raster.height);
      const pixels = ctx.getImageData(0, 0, raster.width, raster.height).data;
      const nearBoundary = (v: number) => {
        const offset = v % cell;
        return offset < 2 || offset >= cell - 2;
      };
      const ring = rings.map(({ at, x, y }) => {
        const i = (y * raster.width + x) * 4;
        return { at, rgba: [pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]] };
      });
      const holeScans = holes.map(({ at, cx, cy }) => {
        let scanned = 0;
        let mismatched = 0;
        const firstMismatches: { x: number; y: number; rgba: number[] }[] = [];
        const r = Math.floor(scanRadius);
        for (let y = cy - r; y <= cy + r; y++) {
          for (let x = cx - r; x <= cx + r; x++) {
            const centreDx = x + 0.5 - cx;
            const centreDy = y + 0.5 - cy;
            const outside =
              centreDx * centreDx + centreDy * centreDy >
              scanRadius * scanRadius;
            if (outside || nearBoundary(x) || nearBoundary(y)) continue;
            scanned++;
            const lightCell =
              (Math.floor(x / cell) + Math.floor(y / cell)) % 2 === 0;
            const want = lightCell ? light : dark;
            const i = (y * raster.width + x) * 4;
            const got = [pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]];
            if (got.some((byte, k) => byte !== want[k])) {
              mismatched++;
              if (firstMismatches.length < 5)
                firstMismatches.push({ x, y, rgba: got });
            }
          }
        }
        return { at, covered: scanned > 0, mismatched, firstMismatches };
      });
      return { holeScans, ring };
    },
    {
      holes: DONUT_HOLE_CENTRES,
      rings: DONUT_RING_SAMPLES,
      raster,
      cell: DONUT_CELL,
      scanRadius,
      light: CHECKER_LIGHT,
      dark: CHECKER_DARK,
    }
  );
  expect(
    scans.ring.map(({ at, rgba }) => ({ at, checker: isChecker(rgba) }))
  ).toEqual(DONUT_RING_SAMPLES.map(({ at }) => ({ at, checker: false })));
  expect(scans.holeScans).toEqual(
    DONUT_HOLE_CENTRES.map(({ at }) => ({
      at,
      covered: true,
      mismatched: 0,
      firstMismatches: [],
    }))
  );
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
