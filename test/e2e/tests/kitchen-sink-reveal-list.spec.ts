import { test, expect, type Page } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";

// Reveal-a-child-in-a-scroll-container E2E, driven through the kitchen sink's
// reveal-list section.
//
// Two layers, deliberately split. Which row the model has selected is model
// state, so it is asserted through the MVU telemetry log — that is the primary
// correctness contract for this suite (ADR 0108). Where the container came to
// rest is not model state and telemetry has nothing to say about it: no message
// and no serialized field carries a scroll offset, because the feature's whole
// point is that the application never computes one. So the offset, the row's
// box and the page's own scroll position are read off the DOM, which is the
// render-correctness half the same decision reserves the DOM for.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` and never `page.reload()`; wait for the section before interacting.
//
// The settle gate for every geometry read is the section's readout text. The
// readout is patched while the tree is reconciled and the container is moved at
// the END of that same render pass, so a readout naming the new selection is
// proof the scroll write for that selection has already happened. It is a text
// gate in front of a geometry assertion, so it cannot make the assertion
// vacuous.

const SECTION = '[data-testid="reveal-list-section"]';
const FRAME = `${SECTION} [data-testid="reveal-list-frame"]`;
// `Element.scroll` takes no attrs — that gap is what the feature exists to
// close — so the container is reached as the only child of the frame box.
const CONTAINER = `${FRAME} > div`;
const READOUT = `${SECTION} [data-testid="reveal-list-readout"]`;
const KEYS_TOGGLE = `${SECTION} [data-field="reveal-keys"]`;

const row = (index: number) => `${SECTION} [data-testid="reveal-list-row-${index}"]`;
const alignControl = (token: string) =>
  `${SECTION} [data-action="reveal-align-${token}"]`;

// Row keys are file paths because the first consumer keys its rows by path.
const key = (index: number) => `notes/${String(index).padStart(2, "0")}.md`;
// The one row whose key carries a double quote and a backslash. Five bytes that
// a selector built by string concatenation would mangle.
const HOSTILE_INDEX = 27;
const HOSTILE_KEY = 'notes/quote"and\\slash.md';
// The same key as OCaml's `%S` writes it into the telemetry model.
const HOSTILE_KEY_SERIALIZED = 'notes/quote\\"and\\\\slash.md';

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;
// Sub-pixel slack. Scroll offsets are fractional in Chromium, so an alignment
// that lands a row exactly where it says still misses by a fraction of a pixel.
const TOLERANCE = 2;

type Geometry = {
  scrollTop: number;
  contentTop: number;
  contentBottom: number;
  rowTop: number;
  rowBottom: number;
};

// Everything one assertion needs about where the container and one row are,
// read in a single evaluation so the two rects cannot straddle a frame.
// `contentTop` is the top of the scrollable content, which sits `clientTop`
// (the container's top border) below the top of its border box — the same
// origin the renderer measures `child_top` from.
async function geometry(page: Page, index: number): Promise<Geometry> {
  return await page.evaluate(
    ([containerSel, rowSel]) => {
      const container = document.querySelector(containerSel);
      const target = document.querySelector(rowSel);
      if (container === null) throw new Error(`no container: ${containerSel}`);
      if (target === null) throw new Error(`no row: ${rowSel}`);
      const el = container as HTMLElement;
      const containerRect = el.getBoundingClientRect();
      const rowRect = target.getBoundingClientRect();
      const contentTop = containerRect.top + el.clientTop;
      return {
        scrollTop: el.scrollTop,
        contentTop,
        contentBottom: contentTop + el.clientHeight,
        rowTop: rowRect.top,
        rowBottom: rowRect.bottom,
      };
    },
    [CONTAINER, row(index)] as [string, string]
  );
}

async function scrollTop(page: Page): Promise<number> {
  return await page.evaluate((sel) => {
    const container = document.querySelector(sel);
    if (container === null) throw new Error(`no container: ${sel}`);
    return (container as HTMLElement).scrollTop;
  }, CONTAINER);
}

function expectRowFullyVisible(g: Geometry, what: string): void {
  expect(g.rowTop, `${what}: row's top is above the container's`).toBeGreaterThanOrEqual(
    g.contentTop - TOLERANCE
  );
  expect(
    g.rowBottom,
    `${what}: row's bottom is below the container's`
  ).toBeLessThanOrEqual(g.contentBottom + TOLERANCE);
}

// The settle gate. Also the assertion that the selection reached the view: the
// readout is rendered from the same model field the reveal request is derived
// from.
async function awaitSelection(
  page: Page,
  selected: string,
  align: string
): Promise<void> {
  await expect(page.locator(READOUT)).toContainText(
    `Selected ${selected}, aligned ${align}`,
    { timeout: SETTLE }
  );
}

// The settle gate for the one case whose render pass changes nothing visible.
// A message is processed synchronously and the pass it invalidates is scheduled
// on the next animation frame, so two frames after the model recorded the
// transition that pass has certainly run — reveal drain included. Every other
// case gets the same guarantee from the readout text and does not need this.
async function awaitRenderedFrame(page: Page): Promise<void> {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
      })
  );
}

// The arrow keys are a document-level subscription that prevents the browser
// default, so the section leaves them unsubscribed until this box is ticked.
// Gating on the model fragment rather than on the checkbox's own `checked`
// state is what proves the knob reached the subscription: the DOM checkbox
// flips on click whether or not the message ever reached `update`.
async function enableKeys(page: Page, telemetry: NopalTelemetry): Promise<void> {
  await page.locator(KEYS_TOGGLE).check();
  await telemetry.waitForModel("reveal_keys=true;", SETTLE);
}

async function pressDown(page: Page, times: number): Promise<void> {
  for (let i = 0; i < times; i++) await page.keyboard.press("ArrowDown");
}

async function pressUp(page: Page, times: number): Promise<void> {
  for (let i = 0; i < times; i++) await page.keyboard.press("ArrowUp");
}

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("selection below the fold scrolls the container", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await enableKeys(page, telemetry);

  const before = await scrollTop(page);

  await pressDown(page, 3);
  await awaitSelection(page, key(3), "nearest");

  // The model half (the primary contract): the message was dispatched and the
  // model's selected key advanced. Trailing ';' on both so a longer key or a
  // longer constructor name cannot satisfy the fragment.
  await telemetry.assertDispatched("Reveal:Select_next;");
  await telemetry.assertRecordContains("reveal_list", `reveal_key="${key(3)}";`);

  // The render half: the container moved, and the selected row is inside it.
  // The rows are deliberately of unequal height, so an implementation that
  // multiplied an index by a fixed row height cannot land here.
  const g = await geometry(page, 3);
  expect(g.scrollTop, "container did not move").toBeGreaterThan(before);
  expectRowFullyVisible(g, "row 3 after revealing it");

  await telemetry.attachHistory(test.info());
});

test("selection upward scrolls back", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await enableKeys(page, telemetry);

  await pressDown(page, 6);
  await awaitSelection(page, key(6), "nearest");
  const down = await geometry(page, 6);
  expect(down.scrollTop, "container did not move down").toBeGreaterThan(0);
  expectRowFullyVisible(down, "row 6 after revealing it");

  await pressUp(page, 4);
  await awaitSelection(page, key(2), "nearest");

  await telemetry.assertDispatched("Reveal:Select_previous;");
  await telemetry.assertRecordContains("reveal_list", `reveal_key="${key(2)}";`);

  const up = await geometry(page, 2);
  expect(up.scrollTop, "container did not move back up").toBeLessThan(
    down.scrollTop
  );
  expectRowFullyVisible(up, "row 2 after revealing it");

  await telemetry.attachHistory(test.info());
});

test("selecting an already-visible row does not scroll", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await enableKeys(page, telemetry);

  // Revealing row 4 under `nearest` brings its bottom edge to the container's
  // bottom, which leaves the row above it wholly inside — asserted below rather
  // than assumed, because the rows wrap and wrapping is font-dependent.
  await pressDown(page, 4);
  await awaitSelection(page, key(4), "nearest");

  const settled = await geometry(page, 3);
  expectRowFullyVisible(settled, "row 3 before it is selected");

  await pressUp(page, 1);
  await awaitSelection(page, key(3), "nearest");
  await telemetry.assertRecordContains("reveal_list", `reveal_key="${key(3)}";`);

  const unmoved = await geometry(page, 3);
  expect(
    unmoved.scrollTop,
    "container was rewritten with an offset it already held"
  ).toBe(settled.scrollTop);

  // The affirmative arm on the same fixture: one row further up is NOT wholly
  // visible, and selecting it does move the container. Without this the
  // absence above would stay green if arrow keys stopped selecting anything.
  await pressUp(page, 1);
  await awaitSelection(page, key(2), "nearest");
  const moved = await geometry(page, 2);
  expect(moved.scrollTop, "container did not move for a row off-screen").toBeLessThan(
    settled.scrollTop
  );
  expectRowFullyVisible(moved, "row 2 after revealing it");

  await telemetry.attachHistory(test.info());
});

test("a manual scroll survives a re-render", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  // The one place this spec writes a scroll offset: it is standing in for a
  // reader dragging the container away from the selected row.
  await page.evaluate((sel) => {
    const container = document.querySelector(sel);
    if (container === null) throw new Error(`no container: ${sel}`);
    (container as HTMLElement).scrollTop = 1500;
  }, CONTAINER);
  const parked = await scrollTop(page);
  expect(parked, "manual scroll did not take").toBeGreaterThan(0);

  // A render pass that changes the model but not the reveal request. Ticking
  // the keyboard gate is one; the selected key is still the first row's.
  await enableKeys(page, telemetry);
  await awaitRenderedFrame(page);
  await telemetry.assertRecordContains("reveal_list", `reveal_key="${key(0)}";`);
  expect(
    await scrollTop(page),
    "an unchanged request snapped the reader back"
  ).toBe(parked);

  // The affirmative arm on the same fixture: once the request DOES change, the
  // same container moves. The absence above is edge-triggering, not inertness.
  await pressDown(page, 1);
  await awaitSelection(page, key(1), "nearest");
  expect(
    await scrollTop(page),
    "a changed request left the container alone"
  ).not.toBe(parked);

  await telemetry.attachHistory(test.info());
});

test("focus is not moved", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await enableKeys(page, telemetry);

  // Ticking the box focuses it, so the reference is taken AFTER that and the
  // comparison spans the reveal alone. Held as an element reference rather than
  // a tag name or an id, so the assertion is identity and not resemblance.
  await page.evaluate(() => {
    (window as unknown as Record<string, unknown>).__revealFocusBefore =
      document.activeElement;
  });
  const before = await scrollTop(page);

  await pressDown(page, 3);
  await awaitSelection(page, key(3), "nearest");

  const unchanged = await page.evaluate(
    () =>
      document.activeElement ===
      (window as unknown as Record<string, unknown>).__revealFocusBefore
  );
  expect(unchanged, "the reveal moved focus").toBe(true);

  // The affirmative arm: focus stayed put across a reveal that happened.
  const after = await geometry(page, 3);
  expect(after.scrollTop, "no reveal happened to hold focus across").toBeGreaterThan(
    before
  );
  expectRowFullyVisible(after, "row 3 after revealing it");

  await telemetry.attachHistory(test.info());
});

test("the page does not scroll", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await enableKeys(page, telemetry);

  const pageBefore = await page.evaluate(() => window.scrollY);
  const before = await scrollTop(page);

  await pressDown(page, 3);
  await awaitSelection(page, key(3), "nearest");

  expect(
    await page.evaluate(() => window.scrollY),
    "the reveal dragged the document"
  ).toBe(pageBefore);

  // The affirmative arm: the document held still across a reveal that moved the
  // declaring container, which is the whole difference from the focus-command
  // workaround this feature replaces.
  const after = await geometry(page, 3);
  expect(after.scrollTop, "no reveal happened to hold the page across").toBeGreaterThan(
    before
  );
  expectRowFullyVisible(after, "row 3 after revealing it");

  await telemetry.attachHistory(test.info());
});

test("a hostile key resolves", async ({ page }) => {
  const pageErrors: string[] = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));

  const telemetry = new NopalTelemetry(page);
  await enableKeys(page, telemetry);

  await pressDown(page, HOSTILE_INDEX);
  await awaitSelection(page, HOSTILE_KEY, "nearest");
  await telemetry.assertRecordContains(
    "reveal_list",
    `reveal_key="${HOSTILE_KEY_SERIALIZED}";`
  );

  // The row carries the five bytes as written — the key is not pre-escaped
  // anywhere on the way to the DOM, so escaping is purely the selector's
  // business at the point the query is built.
  expect(await page.locator(row(HOSTILE_INDEX)).getAttribute("data-key")).toBe(
    HOSTILE_KEY
  );

  const g = await geometry(page, HOSTILE_INDEX);
  expect(g.scrollTop, "the punctuated key resolved to nothing").toBeGreaterThan(0);
  expectRowFullyVisible(g, "the row whose key carries a quote and a backslash");

  // A selector built by concatenation raises rather than matching nothing, so
  // an unhandled error here is the failure mode this case exists to exclude.
  expect(pageErrors, "the page raised while resolving the key").toEqual([]);

  await telemetry.attachHistory(test.info());
});

test("each alignment lands the row where it says", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await enableKeys(page, telemetry);

  // Row 10 is far from both ends of the list, so no alignment's answer is
  // clamped to the scrollable range and each of the four lands somewhere
  // different.
  await pressDown(page, 10);
  await awaitSelection(page, key(10), "nearest");

  const nearest = await geometry(page, 10);
  expectRowFullyVisible(nearest, "nearest");

  await page.locator(alignControl("start")).click();
  await awaitSelection(page, key(10), "start");
  await telemetry.assertRecordContains("reveal_list", "reveal_align=start;");
  const start = await geometry(page, 10);
  expect(
    Math.abs(start.rowTop - start.contentTop),
    "start did not put the row's top at the container's top"
  ).toBeLessThanOrEqual(TOLERANCE);

  await page.locator(alignControl("center")).click();
  await awaitSelection(page, key(10), "center");
  await telemetry.assertRecordContains("reveal_list", "reveal_align=center;");
  const center = await geometry(page, 10);
  expect(
    Math.abs(
      (center.rowTop + center.rowBottom) / 2 -
        (center.contentTop + center.contentBottom) / 2
    ),
    "center did not put the row's centre at the container's centre"
  ).toBeLessThanOrEqual(TOLERANCE);

  await page.locator(alignControl("end")).click();
  await awaitSelection(page, key(10), "end");
  await telemetry.assertRecordContains("reveal_list", "reveal_align=end;");
  const end = await geometry(page, 10);
  expect(
    Math.abs(end.rowBottom - end.contentBottom),
    "end did not put the row's bottom at the container's bottom"
  ).toBeLessThanOrEqual(TOLERANCE);

  // The three named alignments are three different resting places, so an
  // implementation that answered any two of them with the same offset — a
  // swapped token, a shared fallback — cannot satisfy all three above.
  expect(new Set([start.scrollTop, center.scrollTop, end.scrollTop]).size).toBe(3);

  await telemetry.attachHistory(test.info());
});
