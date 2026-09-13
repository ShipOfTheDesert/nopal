import { test, expect, type Page } from "@playwright/test";

// A Fixed size must not shrink, measured in the browser.
//
// This suite exists because no other layer can hold the claim. Every container
// this framework renders lays its children out as flex items, and a flex item at
// the CSS default shrink is squeezed below the size it declares as soon as a
// sibling wants more room than the container has; an item with nothing in it
// collapses to its automatic minimum of zero and disappears outright. Whether that
// happened is a property of rendered geometry and of nothing else: the element
// tree is identical either way, and an emitted declaration only says what was
// asked for, not what the browser did with it. So every assertion below is a
// measured rect. The computed declarations this file reads are settle gates and
// fixture checks in front of those measurements, never the contract — a suite
// that asserted the declaration would have passed throughout the entire life of
// the defect it is here to prevent.
//
// There is no telemetry half. The section's two controls change no model state
// any serializer reports, because a shrink guard has no vocabulary in the model
// at all; the observable is geometry, and the DOM is what this project reserves
// for render correctness.
//
// OBSERVED, headless Chromium, 2026-09-12, devicePixelRatio 1: every reading
// this file asserts came back an exact integer, so nothing here carries a
// tolerance. With the guard mutated away — the emitter's Fixed arm returning its
// accumulator untouched, which is the defect's own shape — the same four
// readings were 36.453125 (fixed width beside the unbroken line), 270 (the
// flexible sibling's share once both children shrink), 40 (the fixed height
// with the pair laid out down the page) and 100 (each column). Each case
// therefore discriminates on a value, and by a wide margin.
//
// OBSERVED, 2026-09-12: that mutation removes the guard, and a removal proves
// only that the guard is needed somewhere on the path — deleting a mechanism
// takes its correct effects away along with its incorrect ones, so it cannot say
// whether the guard reads the right dimension or is computed at the right
// moment. Two near-miss mutations were run for those two properties, each the
// shape a later author would plausibly write rather than an absurd one, and each
// reddened the case named beside it:
//
//   - Guard on a Fixed size on either dimension instead of on the one the
//     parent's axis selects. Reddens "fixed width in a column omits the guard",
//     in the shrink guard group of test/unit/nopal_web/test_style_css.ml.
//   - Resolve the parent's axis once when a child is created and reuse it,
//     instead of resolving it again when the parent's own direction changes.
//     Reddens "a parent axis flip restyles children", in
//     test/unit/nopal_web/test_nopal_web.ml.
//
// Three further mutations were run and reddened in the same session: handing no
// parent axis at all from the keyed reconciler's create arm, and swapping the
// axis passed at each of the two places a child is restyled when it gains or
// loses an interaction.
//
// Why each fixture is under pressure, derived from the section's declared sizes
// and confirmed by those readings: a flex item's automatic minimum is the
// smaller of its own definite size and its content's, so the sibling — which
// declares it will take the pair's whole width — can never shrink below the
// pair's width while its line cannot break, and can shrink to its token once it
// can. That is what makes one fixture overflow and the other resolve exactly.
//
// Headless mitigations: navigate fresh with goto and never page.reload(), wait
// for the section before touching a control, and gate every geometry read after
// a click on a declaration the same render pass writes — the model to DOM frame
// is asynchronous, so a rect read immediately after check() is last frame's
// layout.

const SECTION = '[data-testid="fixed-size-section"]';
const PAIR = `${SECTION} [data-testid="fixed-size-pair"]`;
const FIXED = `${SECTION} [data-testid="fixed-size-fixed"]`;
const FLEXIBLE = `${SECTION} [data-testid="fixed-size-flexible"]`;
// The sibling's text carries the wrapping declaration this file gates on. It is
// the flexible box's only child.
const SIBLING_TEXT = `${FLEXIBLE} span`;
const COLUMNS_ROW = `${SECTION} [data-testid="fixed-size-columns"]`;
const WRAP_TOGGLE = `${SECTION} [data-field="fixed-size-wrap"]`;
const STACK_TOGGLE = `${SECTION} [data-field="fixed-size-stack"]`;

const columnSelector = (index: number) =>
  `${SECTION} [data-testid="fixed-size-column-${index}"]`;

// The sizes the section declares, restated here rather than exported from it.
// The section keeps them private on purpose: read back out of the source, every
// assertion below would compare a size with itself and a size changed there
// would stay green.
const PAIR_WIDTH = 360;
const PAIR_HEIGHT = 140;
const FIXED_WIDTH = 120;
const FIXED_HEIGHT = 56;
const COLUMNS_ROW_WIDTH = 300;
const COLUMN_WIDTH = 140;
const COLUMN_COUNT = 3;

// Generous: the first model to DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

type Size = { width: number; height: number };

// Every rect one assertion needs, read in a single evaluation so the numbers
// cannot straddle a frame.
async function sizes(page: Page, selectors: string[]): Promise<Size[]> {
  return await page.evaluate((sels) => {
    return sels.map((sel) => {
      const el = document.querySelector(sel);
      if (el === null) throw new Error(`no element: ${sel}`);
      const rect = el.getBoundingClientRect();
      return { width: rect.width, height: rect.height };
    });
  }, selectors);
}

// The gate in front of a geometry read: a declaration the render pass writes in
// the same frame as the layout it causes. Once the computed value has arrived
// the layout that follows from it is what the next rect read measures, because
// reading a rect flushes layout. Asserting this value would be asserting emitted
// CSS, which is the thing this suite deliberately does not do; waiting for it is
// how the measurement is made to land in the right frame.
async function awaitDeclaration(
  page: Page,
  selector: string,
  property: string,
  value: string
): Promise<void> {
  await page.waitForFunction(
    ([sel, prop, expected]) => {
      const el = document.querySelector(sel);
      if (el === null) return false;
      return (
        window.getComputedStyle(el).getPropertyValue(prop).trim() === expected
      );
    },
    [selector, property, value] as [string, string, string],
    { timeout: SETTLE }
  );
}

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("fixed box keeps its width beside unbreakable content", async ({
  page,
}) => {
  // The reported shape is the section's initial state, so nothing is clicked
  // here: this is a fixture check, not a settle gate. The sibling's line cannot
  // break, which is what makes it demand more room than the pair has.
  await awaitDeclaration(page, SIBLING_TEXT, "white-space", "nowrap");

  const [pair, fixed, flexible] = await sizes(page, [PAIR, FIXED, FLEXIBLE]);

  // Two fixture preconditions, asserted before the contract so a fixture
  // problem cannot masquerade as a contract failure.
  expect(
    pair.width,
    "the pair is not the width it declares, so the room its children compete " +
      "for is not the room this case assumes. The fixed width below is not " +
      "what failed."
  ).toBe(PAIR_WIDTH);
  expect(
    flexible.width,
    "the sibling is not demanding more room than the pair has left beside the " +
      "fixed box, so nothing is squeezing the fixed box and its width below " +
      "would hold for no reason — the section's sibling text needs to be a " +
      "sentence longer than that remainder, with no break opportunity in it. " +
      "The fixed width below is not what failed."
  ).toBeGreaterThan(PAIR_WIDTH - FIXED_WIDTH);

  // The contract, and the only assertion in this feature that could have caught
  // the defect: under that pressure the box renders at the width it declares.
  expect(
    fixed.width,
    "the fixed box was squeezed below the width it declares"
  ).toBe(FIXED_WIDTH);
  // The other dimension, which the parent's axis leaves alone. Asserted here so
  // a guard that reached for the wrong dimension is visible in this case too.
  expect(
    fixed.height,
    "the fixed box lost the height it declares, which the pair's axis does not " +
      "put under pressure at all"
  ).toBe(FIXED_HEIGHT);
});

test("fixed columns stay fixed and overflow rather than turning fluid", async ({
  page,
}) => {
  // The fixture's own arithmetic, checked from the declared sizes rather than
  // from the page: three columns this wide cannot fit a row this narrow, and if
  // a later edit made them fit, every width below would still measure its own
  // declaration while the case proved nothing.
  expect(
    COLUMN_COUNT * COLUMN_WIDTH,
    "the columns no longer add up to more than the row that holds them, so " +
      "nothing is squeezing them"
  ).toBeGreaterThan(COLUMNS_ROW_WIDTH);

  const measured = await sizes(page, [
    COLUMNS_ROW,
    ...Array.from({ length: COLUMN_COUNT }, (_unused, index) =>
      columnSelector(index)
    ),
  ]);
  const [row] = measured;
  const columns = measured.slice(1);

  expect(
    row.width,
    "the row is not the width it declares, so it may have grown to fit its " +
      "columns instead of holding them under pressure. The column widths below " +
      "are not what failed."
  ).toBe(COLUMNS_ROW_WIDTH);

  // The contract: each column keeps its declared width and the row overflows,
  // rather than the row quietly turning fluid and dividing itself three ways.
  columns.forEach((column, index) => {
    expect(
      column.width,
      `column ${index + 1} turned fluid instead of keeping the width it declares`
    ).toBe(COLUMN_WIDTH);
  });
  expect(
    columns.reduce((total, column) => total + column.width, 0),
    "the columns fitted the row, so the row absorbed the overflow instead of " +
      "the columns keeping their sizes"
  ).toBeGreaterThan(row.width);
});

test("flexible sibling still absorbs the remaining space", async ({ page }) => {
  // Letting the sibling's line break drops its own minimum to the one token in
  // it that cannot be divided, which is narrow enough to fit the room left
  // beside the fixed box. The two children still over-declare the pair, so one
  // of them has to give way, and this is the case that says which.
  await page.locator(WRAP_TOGGLE).check();
  await awaitDeclaration(page, SIBLING_TEXT, "white-space", "normal");

  const [pair, fixed, flexible] = await sizes(page, [PAIR, FIXED, FLEXIBLE]);

  expect(
    pair.width,
    "the pair is not the width it declares, so the remainder below is not the " +
      "remainder this case assumes"
  ).toBe(PAIR_WIDTH);

  // The requirement: the flexible path is not frozen. A guard applied to every
  // size, or applied without consulting the axis, would leave this at the pair's
  // whole width and every existing layout in the framework broken with it.
  expect(
    flexible.width,
    "the flexible sibling no longer gives way, so the fix froze the flexible " +
      "path along with the fixed one"
  ).toBeLessThan(PAIR_WIDTH);
  // And the precision: the whole shortfall came out of the sibling, because the
  // fixed box refused its share.
  expect(
    flexible.width,
    "the flexible sibling did not absorb exactly the room the fixed box left " +
      "it, so the shortfall was shared between them"
  ).toBe(PAIR_WIDTH - FIXED_WIDTH);
  expect(
    fixed.width,
    "the fixed box gave up part of the shortfall instead of holding its width"
  ).toBe(FIXED_WIDTH);
});

test("fixed box keeps its height when the parent axis flips", async ({
  page,
}) => {
  // Before the flip the height is the dimension the pair's axis leaves alone,
  // and it holds whether or not anything guards it. Recorded rather than relied
  // on: it is what makes the reading after the flip the same number in a
  // different role.
  const [beforeFlip] = await sizes(page, [FIXED]);
  expect(
    beforeFlip.height,
    "the fixed box does not have the height it declares before the flip, so " +
      "the flip is not what would have taken it"
  ).toBe(FIXED_HEIGHT);

  await page.locator(STACK_TOGGLE).check();
  await awaitDeclaration(page, PAIR, "flex-direction", "column");

  const [pair, fixed, flexible] = await sizes(page, [PAIR, FIXED, FLEXIBLE]);

  expect(
    pair.height,
    "the pair is not the height it declares, so the room its children compete " +
      "for down the page is not the room this case assumes"
  ).toBe(PAIR_HEIGHT);
  expect(
    flexible.height,
    "the sibling did not give way down the page, so nothing was pressing on " +
      "the fixed box's height and the height below would hold for no reason"
  ).toBeLessThan(PAIR_HEIGHT);

  // The contract: the pair changed its own axis, so the fixed box's protected
  // dimension moved from its width to its height without its own style changing
  // at all. An implementation that read the box's own direction, or that decided
  // once when the box was created, leaves this at the squeezed height.
  expect(
    fixed.height,
    "the fixed box was squeezed below the height it declares once the pair " +
      "laid its children down the page"
  ).toBe(FIXED_HEIGHT);
  expect(
    fixed.width,
    "the fixed box lost the width it declares, which the pair's new axis does " +
      "not put under pressure"
  ).toBe(FIXED_WIDTH);
});
