import { test, expect, type Page } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";

// Reveal along the horizontal axis, and along both axes at once, driven through
// the kitchen sink's reveal-tabs section.
//
// Two layers, split as in the reveal-list spec. Which tab is chosen and which
// alignment is in force are model state, asserted through the MVU telemetry log,
// the primary correctness contract for these suites. Where a container came to
// rest is not model state — no message and no serialized field carries a scroll
// offset — so offsets and boxes are read off the DOM, which is reserved for
// render correctness like this.
//
// Headless Chromium with no display server can stall requestAnimationFrame, so
// each test navigates fresh with `goto`, never `page.reload()`, and waits for
// the section before interacting.
//
// Every geometry read happens after the render its own action triggered: the
// readout naming the new state first, then two animation frames. The readout is
// patched in the same render pass whose end moves the containers, and the two
// frames cover the one case whose pass changes nothing visible.
//
// The geometry is fixed by the section, so every expected offset below is worked
// by hand from it rather than read back from a first run:
// - the strip is 320px wide over ten 100px tabs edge to edge, so tab i spans
//   [100i, 100i + 100] and `scrollLeft` ranges over [0, 680];
// - the grid is 240x200 over eight 120px columns and twelve 60px rows, so
//   `scrollLeft` ranges over [0, 720] and `scrollTop` over [0, 520]; the cell it
//   names spans x [720, 840] and y [540, 600], short of both far ends.

const SECTION = '[data-testid="reveal-tabs-section"]';
const STRIP = `${SECTION} [data-testid="reveal-tabs-strip"]`;
const GRID = `${SECTION} [data-testid="reveal-tabs-grid"]`;
const READOUT = `${SECTION} [data-testid="reveal-tabs-readout"]`;
const CHOICE = `${SECTION} [data-field="reveal-tabs-choice"]`;
const RTL_STRIP = `${SECTION} [data-testid="reveal-tabs-rtl-strip"]`;
const VERTICAL_STRIP = `${SECTION} [data-testid="reveal-tabs-vertical-strip"]`;
const COVER_LIST = `${SECTION} [data-testid="reveal-tabs-cover-list"]`;
const FAR_CELL = `${SECTION} [data-testid="reveal-tabs-cell-9-6"]`;

const tab = (index: number) => `${SECTION} [data-testid="reveal-tabs-tab-${index}"]`;
const rtlTab = (index: number) =>
  `${SECTION} [data-testid="reveal-tabs-rtl-tab-${index}"]`;
const verticalTab = (index: number) =>
  `${SECTION} [data-testid="reveal-tabs-vertical-tab-${index}"]`;
const coverRow = (index: number) =>
  `${SECTION} [data-testid="reveal-tabs-cover-row-${index}"]`;
const tabKey = (index: number) => `tab-${String(index).padStart(2, "0")}`;
const alignControl = (token: string) =>
  `${SECTION} [data-action="reveal-tabs-align-${token}"]`;

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;
// Sub-pixel slack. Scroll offsets can be fractional in Chromium.
const TOLERANCE = 2;

type Geometry = {
  clientWidth: number;
  clientHeight: number;
  scrollLeft: number;
  scrollTop: number;
  contentLeft: number;
  contentRight: number;
  contentTop: number;
  contentBottom: number;
  childLeft: number;
  childRight: number;
  childTop: number;
  childBottom: number;
};

// Everything one assertion needs about a container and one child, read in a
// single evaluation so the two rects cannot straddle a frame. The visible
// content box starts `clientLeft`/`clientTop` (the borders) inside the border
// box, which is the origin the renderer measures a child's start edge from.
async function geometry(
  page: Page,
  containerSel: string,
  childSel: string
): Promise<Geometry> {
  return await page.evaluate(
    ([cSel, kSel]) => {
      const container = document.querySelector(cSel);
      const child = document.querySelector(kSel);
      if (container === null) throw new Error(`no container: ${cSel}`);
      if (child === null) throw new Error(`no child: ${kSel}`);
      const el = container as HTMLElement;
      const box = el.getBoundingClientRect();
      const rect = child.getBoundingClientRect();
      const contentLeft = box.left + el.clientLeft;
      const contentTop = box.top + el.clientTop;
      return {
        clientWidth: el.clientWidth,
        clientHeight: el.clientHeight,
        scrollLeft: el.scrollLeft,
        scrollTop: el.scrollTop,
        contentLeft,
        contentRight: contentLeft + el.clientWidth,
        contentTop,
        contentBottom: contentTop + el.clientHeight,
        childLeft: rect.left,
        childRight: rect.right,
        childTop: rect.top,
        childBottom: rect.bottom,
      };
    },
    [containerSel, childSel] as [string, string]
  );
}

function expectFullyVisible(g: Geometry, what: string): void {
  expect(g.childLeft, `${what}: left edge is outside the container`).toBeGreaterThanOrEqual(
    g.contentLeft - TOLERANCE
  );
  expect(g.childRight, `${what}: right edge is outside the container`).toBeLessThanOrEqual(
    g.contentRight + TOLERANCE
  );
  expect(g.childTop, `${what}: top edge is outside the container`).toBeGreaterThanOrEqual(
    g.contentTop - TOLERANCE
  );
  expect(g.childBottom, `${what}: bottom edge is outside the container`).toBeLessThanOrEqual(
    g.contentBottom + TOLERANCE
  );
}

function expectOffset(actual: number, expected: number, what: string): void {
  expect(
    Math.abs(actual - expected),
    `${what}: expected ${expected}, read ${actual}`
  ).toBeLessThanOrEqual(TOLERANCE);
}

// A message is processed synchronously and the pass it invalidates runs on the
// next animation frame, so two frames later that pass — reveal drain included —
// has certainly run.
async function awaitRenderedFrame(page: Page): Promise<void> {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
      })
  );
}

// The settle gate, and the proof that the state reached the view: the readout is
// rendered from the same model fields both reveal requests are derived from.
async function awaitState(page: Page, chosen: string, align: string): Promise<void> {
  await expect(page.locator(READOUT)).toHaveText(`Chosen ${chosen}, aligned ${align}`, {
    timeout: SETTLE,
  });
  await awaitRenderedFrame(page);
}

// Chooses a tab through the select, then gates on the model having recorded it.
// `events()` takes a fresh slice first: `assertDispatched` reads the cached one,
// which an earlier choice in the same test would otherwise have left stale.
async function choose(
  page: Page,
  telemetry: NopalTelemetry,
  index: number
): Promise<void> {
  await page.locator(CHOICE).selectOption(tabKey(index));
  await awaitState(page, tabKey(index), "nearest");
  await telemetry.events();
  await telemetry.assertDispatched(`Reveal_tabs:Choose:"${tabKey(index)}";`);
  await telemetry.assertRecordContains("reveal_tabs", `reveal_tab="${tabKey(index)}";`);
}

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("the last tab is revealed on arrival", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await awaitState(page, tabKey(9), "nearest");

  // No interaction: the request was present on the strip's first render. Tab 9
  // spans [900, 1000]; under nearest its right edge meets the strip's, at 680.
  const g = await geometry(page, STRIP, tab(9));
  expect(g.scrollLeft, "the strip did not move sideways on arrival").toBeGreaterThan(0);
  expectOffset(g.scrollLeft, 680, "strip scrollLeft on arrival");
  expectFullyVisible(g, "tab 9 on arrival");

  // Nothing in this section was dispatched, so what moved the strip was the
  // first render's request and not a message.
  const sectionMessages = (await telemetry.events()).filter(
    (e) => e.kind === "message" && e.value.includes("Reveal_tabs:")
  );
  expect(sectionMessages, "a section message was dispatched before any interaction").toEqual(
    []
  );

  // The affirmative arm on the same filter: choosing a tab dispatches exactly
  // one section message, so an empty result above is not a filter that matches
  // nothing.
  // Not through `choose`, which takes the slice itself and would leave this
  // filter an empty one.
  await page.locator(CHOICE).selectOption(tabKey(0));
  await awaitState(page, tabKey(0), "nearest");
  const afterChoice = (await telemetry.events()).filter(
    (e) => e.kind === "message" && e.value.includes("Reveal_tabs:")
  );
  expect(afterChoice, "choosing a tab did not dispatch exactly one section message").toHaveLength(
    1
  );

  await telemetry.attachHistory(test.info());
});

test("choosing the last tab under Nearest reveals it", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await awaitState(page, tabKey(9), "nearest");

  // To the start first. Re-choosing tab 9 where it is would be an unchanged
  // request, which reveals nothing, so the strip is taken to the start by
  // revealing tab 0 — itself a nearest reveal off the left edge, from 680 to 0.
  await choose(page, telemetry, 0);
  const atStart = await geometry(page, STRIP, tab(0));
  expectOffset(atStart.scrollLeft, 0, "strip scrollLeft after revealing tab 0");
  expectFullyVisible(atStart, "tab 0 after revealing it");

  // Tab 9 is now wholly off the right edge.
  const hidden = await geometry(page, STRIP, tab(9));
  expect(hidden.childLeft, "tab 9 was already in view").toBeGreaterThan(hidden.contentRight);

  await choose(page, telemetry, 9);
  const g = await geometry(page, STRIP, tab(9));
  expect(g.scrollLeft, "the strip did not move sideways").toBeGreaterThan(0);
  expectOffset(g.scrollLeft, 680, "strip scrollLeft after revealing tab 9");
  expectFullyVisible(g, "tab 9 after revealing it");

  await telemetry.attachHistory(test.info());
});

test("an already-visible tab leaves scrollLeft untouched", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await awaitState(page, tabKey(9), "nearest");

  // Off the strip's far end first. On arrival the strip sits at 680, the end of
  // its range, where every alignment of tabs 7 to 9 clamps to the same 680 — so
  // "not moved" there could not tell nearest from start. Tab 5 spans [500, 600];
  // nearest brings its left edge to the strip's, at 500.
  await choose(page, telemetry, 5);
  const settled = await geometry(page, STRIP, tab(5));
  expectOffset(settled.scrollLeft, 500, "strip scrollLeft after revealing tab 5");
  expectFullyVisible(settled, "tab 5 after revealing it");

  // Tab 6 spans [600, 700], wholly inside [500, 820]. From 500, start would write
  // 600, center 490 and end 380, so only nearest leaves the strip where it is.
  const before = await geometry(page, STRIP, tab(6));
  expectFullyVisible(before, "tab 6 before it is chosen");

  await choose(page, telemetry, 6);
  const unmoved = await geometry(page, STRIP, tab(6));
  expect(
    unmoved.scrollLeft,
    "the strip moved for a tab that was already in view"
  ).toBe(settled.scrollLeft);

  // The affirmative arm on the same fixture: tab 4 spans [400, 500], just off the
  // left edge, and choosing it does move the strip — to 400. Without this the
  // absence above would stay green if choosing a tab revealed nothing at all.
  await choose(page, telemetry, 4);
  const moved = await geometry(page, STRIP, tab(4));
  expectOffset(moved.scrollLeft, 400, "strip scrollLeft after revealing tab 4");
  expectFullyVisible(moved, "tab 4 after revealing it");

  await telemetry.attachHistory(test.info());
});

test("the two-way grid reveals on both axes", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await awaitState(page, tabKey(9), "nearest");

  // On arrival, under nearest, the cell's right edge (840) meets the grid's and
  // its bottom edge (600) meets the grid's, so the offsets are 840 - clientWidth
  // and 600 - clientHeight. Those come from the sizes the container reports, so
  // they hold whatever space a scrollbar takes: 600 and 400 only when it takes
  // none. Both are short of the far ends (720, 520) in any case, so a grid that
  // merely scrolled to its corner fails.
  const arrival = await geometry(page, GRID, FAR_CELL);
  expectOffset(arrival.scrollLeft, 840 - arrival.clientWidth, "grid scrollLeft on arrival");
  expectOffset(arrival.scrollTop, 600 - arrival.clientHeight, "grid scrollTop on arrival");
  expectFullyVisible(arrival, "the named cell on arrival");

  // One alignment governs both axes, and a changed alignment is a changed
  // request: center puts the cell's centre (780, 570) at the grid's centre, so
  // x moves to 780 - clientWidth / 2 and y to 570 - clientHeight / 2 (660 and
  // 470 with no scrollbar), both within range.
  await page.locator(alignControl("center")).click();
  await awaitState(page, tabKey(9), "center");
  await telemetry.events();
  await telemetry.assertDispatched("Reveal_tabs:Align:center;");
  await telemetry.assertRecordContains("reveal_tabs", "reveal_tabs_align=center;");

  const centred = await geometry(page, GRID, FAR_CELL);
  expectOffset(
    centred.scrollLeft,
    780 - centred.clientWidth / 2,
    "grid scrollLeft under center"
  );
  expectOffset(
    centred.scrollTop,
    570 - centred.clientHeight / 2,
    "grid scrollTop under center"
  );
  expect(
    Math.abs(
      (centred.childLeft + centred.childRight) / 2 -
        (centred.contentLeft + centred.contentRight) / 2
    ),
    "center did not put the cell's horizontal centre at the grid's"
  ).toBeLessThanOrEqual(TOLERANCE);
  expect(
    Math.abs(
      (centred.childTop + centred.childBottom) / 2 -
        (centred.contentTop + centred.contentBottom) / 2
    ),
    "center did not put the cell's vertical centre at the grid's"
  ).toBeLessThanOrEqual(TOLERANCE);

  await telemetry.attachHistory(test.info());
});

// Two strips whose x axis runs reversed: the renderer must write no scrollLeft
// to them. Each is first scrolled by hand to -500, so tab 0, which starts at
// the right-hand start edge, lies wholly past the right edge of the visible
// range. That position is what makes a wrong write detectable at all. A
// reversed strip's scrollLeft only ranges over [-680, 0], and the reveal
// arithmetic counts up from 0, so from rest at 0 a wrongly treated axis finds
// the tab "already at 0" and writes nothing either way; from -500 it would
// write 0. The writes themselves are recorded, by a setter installed on each
// element before the choice, and the first strip, in the same setting (at 680,
// tab 0 off its left edge), must be seen to receive its write.
async function spyOnScroll(
  page: Page,
  sel: string,
  prop: "scrollLeft" | "scrollTop"
): Promise<void> {
  await page.evaluate(
    ([s, p]) => {
      const el = document.querySelector(s) as HTMLElement & {
        __writes?: Record<string, number[]>;
      };
      el.__writes = { ...(el.__writes ?? {}), [p]: [] };
      const desc = Object.getOwnPropertyDescriptor(Element.prototype, p)!;
      Object.defineProperty(el, p, {
        configurable: true,
        get() {
          return desc.get!.call(this);
        },
        set(v: number) {
          el.__writes![p].push(v);
          desc.set!.call(this, v);
        },
      });
    },
    [sel, prop] as [string, string]
  );
}

async function writesTo(
  page: Page,
  sel: string,
  prop: "scrollLeft" | "scrollTop" = "scrollLeft"
): Promise<number[]> {
  return await page.evaluate(
    ([s, p]) =>
      (document.querySelector(s) as HTMLElement & { __writes: Record<string, number[]> })
        .__writes[p],
    [sel, prop] as [string, string]
  );
}
async function chooseWithReversedStrip(
  page: Page,
  telemetry: NopalTelemetry,
  stripSel: string,
  tabSel: (i: number) => string,
  reversedTab: number
): Promise<void> {
  await page.evaluate((sel) => {
    (document.querySelector(sel) as HTMLElement).scrollLeft = -500;
  }, stripSel);
  await awaitRenderedFrame(page);
  const reversedBefore = await geometry(page, stripSel, tabSel(reversedTab));
  expectOffset(reversedBefore.scrollLeft, -500, "reversed strip before the choice");
  const wide = await page.evaluate(
    (sel) => {
      const el = document.querySelector(sel) as HTMLElement;
      return { scrollWidth: el.scrollWidth, clientWidth: el.clientWidth };
    },
    stripSel
  );
  expect(
    wide.scrollWidth,
    "the reversed strip does not overflow along x, so it proves nothing"
  ).toBeGreaterThan(wide.clientWidth);
  const outside = (g: Geometry) =>
    g.childRight <= g.contentLeft + TOLERANCE || g.childLeft >= g.contentRight - TOLERANCE;
  expect(outside(reversedBefore), "the chosen tab is already in view").toBe(true);

  // The first strip sits at 680 (tab 9 revealed on arrival), so it is the one
  // that must move when tab 0 is chosen.
  const ltrBefore = await geometry(page, STRIP, tab(reversedTab));
  expectOffset(ltrBefore.scrollLeft, 680, "left-to-right strip before the choice");

  await spyOnScroll(page, STRIP, "scrollLeft");
  await spyOnScroll(page, stripSel, "scrollLeft");
  await spyOnScroll(page, stripSel, "scrollTop");
  await choose(page, telemetry, reversedTab);

  expect(
    (await writesTo(page, STRIP)).length,
    "the left-to-right strip received no write, so the spy sees nothing"
  ).toBeGreaterThan(0);
  expect(
    await writesTo(page, stripSel),
    "scrollLeft was written on a strip whose x axis runs reversed"
  ).toEqual([]);
  expect(
    await writesTo(page, stripSel, "scrollTop"),
    "scrollTop was written on a strip whose x axis runs reversed"
  ).toEqual([]);

  const ltrAfter = await geometry(page, STRIP, tab(reversedTab));
  expectOffset(ltrAfter.scrollLeft, 0, "left-to-right strip scrollLeft after the choice");
  expectFullyVisible(ltrAfter, "the chosen tab on the left-to-right strip");

  const reversedAfter = await geometry(page, stripSel, tabSel(reversedTab));
  expect(
    reversedAfter.scrollLeft,
    "scrollLeft moved on a strip whose x axis runs reversed"
  ).toBe(reversedBefore.scrollLeft);
  expect(outside(reversedAfter), "the chosen tab moved into view on the reversed strip").toBe(
    true
  );
}

test("a dir=rtl strip is not written when a tab is chosen", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await awaitState(page, tabKey(9), "nearest");
  const mode = await page.evaluate((sel) => {
    const cs = getComputedStyle(document.querySelector(sel) as HTMLElement);
    return [cs.writingMode, cs.direction];
  }, RTL_STRIP);
  expect(mode, "the strip is not horizontal-tb under rtl").toEqual(["horizontal-tb", "rtl"]);

  await chooseWithReversedStrip(page, telemetry, RTL_STRIP, rtlTab, 0);
  await telemetry.attachHistory(test.info());
});

test("a vertical-rl, ltr strip is not written when a tab is chosen", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await awaitState(page, tabKey(9), "nearest");

  // The mode is set from outside, since the view carries no writing mode. The
  // direction stays ltr: this is the case a direction-only check gets wrong.
  await page.evaluate((sel) => {
    (document.querySelector(sel) as HTMLElement).style.writingMode = "vertical-rl";
  }, VERTICAL_STRIP);
  await awaitRenderedFrame(page);
  const mode = async () =>
    await page.evaluate((sel) => {
      const cs = getComputedStyle(document.querySelector(sel) as HTMLElement);
      return [cs.writingMode, cs.direction];
    }, VERTICAL_STRIP);
  expect(await mode(), "the mode was not applied").toEqual(["vertical-rl", "ltr"]);

  await chooseWithReversedStrip(page, telemetry, VERTICAL_STRIP, verticalTab, 0);

  // The mode must have survived the re-render, or "unchanged" proves nothing.
  expect(await mode(), "the writing mode did not survive the re-render").toEqual([
    "vertical-rl",
    "ltr",
  ]);
  await telemetry.attachHistory(test.info());
});

// The grid overflows on both axes, so it can be made y-reversed with x forward
// (vertical-lr under rtl) and still receive a scrollLeft write: the x write is
// the positive control inside the same element, and a forward-mode reveal first
// shows the same element does receive scrollTop writes when its y is forward.
test("a y-reversed grid is not written on y when the alignment changes", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await awaitState(page, tabKey(9), "nearest");
  await spyOnScroll(page, GRID, "scrollTop");
  await spyOnScroll(page, GRID, "scrollLeft");

  // Positive control, forward container: a changed alignment moves it on y.
  await page.locator(alignControl("start")).click();
  await awaitState(page, tabKey(9), "start");
  expect(
    (await writesTo(page, GRID, "scrollTop")).length,
    "the forward grid received no scrollTop write, so the spy sees nothing"
  ).toBeGreaterThan(0);

  // Now the mode, set from outside as for the vertical strip.
  await page.evaluate((sel) => {
    const el = document.querySelector(sel) as HTMLElement;
    el.style.writingMode = "vertical-lr";
    el.style.direction = "rtl";
  }, GRID);
  await awaitRenderedFrame(page);
  const mode = async () =>
    await page.evaluate((sel) => {
      const cs = getComputedStyle(document.querySelector(sel) as HTMLElement);
      return [cs.writingMode, cs.direction];
    }, GRID);
  expect(await mode(), "the mode was not applied").toEqual(["vertical-lr", "rtl"]);

  // Guard 1: overflows on y, scrolled by hand to a negative scrollTop, and the
  // cell lies outside the visible y range. A y-reversed scrollTop ranges over
  // [-max, 0], and the reveal arithmetic counts up from 0.
  await page.evaluate((sel) => {
    (document.querySelector(sel) as HTMLElement).scrollTop = -100;
  }, GRID);
  await awaitRenderedFrame(page);
  const before = await geometry(page, GRID, FAR_CELL);
  const size = await page.evaluate((sel) => {
    const el = document.querySelector(sel) as HTMLElement;
    return { scrollHeight: el.scrollHeight, clientHeight: el.clientHeight };
  }, GRID);
  expect(size.scrollHeight, "the grid does not overflow along y").toBeGreaterThan(
    size.clientHeight
  );
  expect(before.scrollTop, "scrollTop is not negative, so the axis is not reversed").toBeLessThan(
    0
  );
  expect(
    before.childBottom <= before.contentTop + TOLERANCE ||
      before.childTop >= before.contentBottom - TOLERANCE,
    "the cell is already in the visible y range"
  ).toBe(true);

  await spyOnScroll(page, GRID, "scrollTop");
  await spyOnScroll(page, GRID, "scrollLeft");
  await page.locator(alignControl("center")).click();
  await awaitState(page, tabKey(9), "center");
  await telemetry.events();
  await telemetry.assertDispatched("Reveal_tabs:Align:center;");

  expect(
    await writesTo(page, GRID, "scrollTop"),
    "scrollTop was written on a container whose y axis runs reversed"
  ).toEqual([]);
  // Guard 2: the mode survived the re-render, or "unchanged" proves nothing.
  expect(await mode(), "the mode did not survive the re-render").toEqual([
    "vertical-lr",
    "rtl",
  ]);
  const after = await geometry(page, GRID, FAR_CELL);
  expect(after.scrollTop, "scrollTop moved on a y-reversed container").toBe(before.scrollTop);

  await telemetry.attachHistory(test.info());
});

// Decision 3 / the covering rule: a row wider than the list covers its width,
// so under nearest a reveal leaves scrollLeft alone and moves only scrollTop.
// The rows are a fractional number of pixels wide (the column is 700.4px).
test("a covering row leaves scrollLeft alone under Nearest", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await awaitState(page, tabKey(9), "nearest");

  // Scroll sideways by hand to a non-zero offset, and read it back: that is the
  // value that must survive.
  await page.evaluate((sel) => {
    (document.querySelector(sel) as HTMLElement).scrollLeft = 100;
  }, COVER_LIST);
  await awaitRenderedFrame(page);
  const before = await geometry(page, COVER_LIST, coverRow(0));
  expect(before.scrollLeft, "the list did not scroll sideways").toBeGreaterThan(0);

  const rowWidth = before.childRight - before.childLeft;
  expect(
    Number.isInteger(rowWidth),
    `the row's rect width ${rowWidth} is a whole number, so the fractional case is not exercised`
  ).toBe(false);
  expect(rowWidth, "the row does not cover the list's width").toBeGreaterThan(before.clientWidth);
  // Row 0 is off the top (the list arrived at its far end), so it must move.
  expect(before.childBottom, "row 0 is already in view").toBeLessThanOrEqual(
    before.contentTop + TOLERANCE
  );

  await spyOnScroll(page, COVER_LIST, "scrollLeft");
  await spyOnScroll(page, COVER_LIST, "scrollTop");
  await choose(page, telemetry, 0);

  expect(
    (await writesTo(page, COVER_LIST, "scrollTop")).length,
    "the list received no scrollTop write, so the reveal did not run"
  ).toBeGreaterThan(0);
  expect(
    await writesTo(page, COVER_LIST, "scrollLeft"),
    "scrollLeft was written for a row that covers the list's width"
  ).toEqual([]);
  const after = await geometry(page, COVER_LIST, coverRow(0));
  expect(after.scrollLeft, "scrollLeft did not survive the reveal").toBe(before.scrollLeft);
  expectOffset(after.scrollTop, 0, "cover list scrollTop after revealing row 0");

  await telemetry.attachHistory(test.info());
});
