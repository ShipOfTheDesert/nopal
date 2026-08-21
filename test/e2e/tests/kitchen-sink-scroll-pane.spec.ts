import { test, expect, type Page } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";

// Relative scroll of a scroll container, driven through the kitchen sink's
// scroll-pane section.
//
// Two layers, deliberately split. That a movement was ASKED FOR is model state
// — a message and a move counter — so it is asserted through the MVU telemetry
// log, which is this suite's primary correctness contract. WHERE the pane came
// to rest is not model state and telemetry has nothing to say about it: the
// application never computes an offset, which is the entire point of expressing
// the request as a multiple of the pane's own visible height. So the offset is
// read off the DOM, which is the render-correctness half the same decision
// reserves the DOM for.
//
// Every expected offset is computed from measurements taken off the page —
// the pane's own `clientHeight`, and a paragraph's own position inside the
// pane's scrollable content. Nothing here names a pixel count. The paragraphs
// wrap, wrapping is font-dependent, and two of them are taller than the pane,
// so a literal would be a number from one machine's line-breaking.
//
// Headless rAF mitigations: navigate fresh with `goto` and never
// `page.reload()`; wait for the section before interacting.
//
// The settle gate for every geometry read is the section's readout text. The
// readout is patched while the tree is reconciled, and both scroll writes for
// that same model run synchronously at the end of that same animation frame —
// the reveal at the end of the render pass, the relative movement immediately
// after it. So a readout naming the new marker and the new move count is proof
// the writes for it have already happened. It is a text gate in front of a
// geometry assertion, so it cannot make the assertion vacuous.

const SECTION = '[data-testid="scroll-pane-section"]';
// The pane is reached by the id it renders with, which is the same string a
// request names it by. Reaching it any other way would leave the id — the whole
// addressing scheme — unasserted.
const PANE = "#scroll-pane-viewport";
const READOUT = `${SECTION} [data-testid="scroll-pane-readout"]`;
const KEYS_TOGGLE = `${SECTION} [data-field="scroll-pane-keys"]`;
const WAYPOINT = `${SECTION} [data-action="scroll-pane-waypoint"]`;
const FOCUS_CONTROL = `${SECTION} [data-action="scroll-pane-focus"]`;
// The row the focus control targets, reached by its own test anchor. The id it
// also carries is what `Cmd.focus` names it by, and is asserted structurally.
const FOCUS_TARGET = `${SECTION} [data-testid="scroll-pane-focus-target"]`;

const paragraph = (index: number) =>
  `${SECTION} [data-testid="scroll-pane-para-${index}"]`;

// The paragraphs the waypoint control cycles through, in cycle order.
const WAYPOINTS = ["para-12", "para-22"];
const WAYPOINT_INDEX = [12, 22];
const FIRST_MARKER = "para-00";

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;
// Sub-pixel slack. Scroll offsets are fractional in Chromium and the browser
// may round a written offset to a device pixel, so an exact landing still
// misses by a fraction.
const TOLERANCE = 2;

type Pane = {
  scrollTop: number;
  viewport: number;
  content: number;
};

// Everything one assertion needs about the pane itself, read in a single
// evaluation so the numbers cannot straddle a frame. `viewport` is the pane's
// client height — the same measurement the backend takes, and the unit a
// request is expressed in.
async function pane(page: Page): Promise<Pane> {
  return await page.evaluate((sel) => {
    const el = document.querySelector(sel);
    if (el === null) throw new Error(`no pane: ${sel}`);
    const container = el as HTMLElement;
    return {
      scrollTop: container.scrollTop,
      viewport: container.clientHeight,
      content: container.scrollHeight,
    };
  }, PANE);
}

// A descendant's top and bottom measured from the top of the pane's scrollable
// content — the origin every offset in this file shares. Read through the live
// rects and the pane's current offset rather than `offsetTop`, which is relative
// to the nearest positioned ancestor and in this page is the document. The
// origin is the pane's padding-box top (`clientTop` past the border), which is
// also the edge the browser's own scroll-into-view aligns to.
async function extentInPane(
  page: Page,
  selector: string
): Promise<{ top: number; bottom: number }> {
  return await page.evaluate(
    ([paneSel, childSel]) => {
      const paneEl = document.querySelector(paneSel);
      const childEl = document.querySelector(childSel);
      if (paneEl === null) throw new Error(`no pane: ${paneSel}`);
      if (childEl === null) throw new Error(`no descendant: ${childSel}`);
      const container = paneEl as HTMLElement;
      const containerRect = container.getBoundingClientRect();
      const childRect = childEl.getBoundingClientRect();
      const contentTop = containerRect.top + container.clientTop;
      return {
        top: childRect.top - contentTop + container.scrollTop,
        bottom: childRect.bottom - contentTop + container.scrollTop,
      };
    },
    [PANE, selector] as [string, string]
  );
}

async function paragraphOffset(page: Page, index: number): Promise<number> {
  return (await extentInPane(page, paragraph(index))).top;
}

// The settle gate, and the assertion that the model reached the view. The
// readout is rendered from the same two model fields the reveal request is
// derived from and the move counter lives in. The count sits inside a longer
// phrase, so "1 movement(s)" cannot be satisfied by "11 movement(s)".
async function awaitReadout(
  page: Page,
  marker: string,
  moves: number
): Promise<void> {
  await expect(page.locator(READOUT)).toContainText(
    `Marker ${marker}, ${moves} movement(s) requested`,
    { timeout: SETTLE }
  );
}

// The chords are a document-level subscription that prevents the browser
// default — the forward one is the browser's own bookmark shortcut — so the
// section leaves them unsubscribed until this box is ticked. Gating on the
// model fragment rather than on the checkbox's own `checked` state is what
// proves the knob reached the subscription: the DOM checkbox flips on click
// whether or not the message ever reached `update`.
async function enableKeys(page: Page, telemetry: NopalTelemetry): Promise<void> {
  await page.locator(KEYS_TOGGLE).check();
  await telemetry.waitForModel("pane_keys=true;", SETTLE);
}

async function pressForward(page: Page): Promise<void> {
  await page.keyboard.press("Control+d");
}

async function pressBack(page: Page): Promise<void> {
  await page.keyboard.press("Control+u");
}

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("the forward chord moves the pane by half its own height", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);
  await enableKeys(page, telemetry);

  const before = await pane(page);
  const pageBefore = await page.evaluate(() => window.scrollY);
  expect(
    before.content,
    "the pane has nothing to scroll, so it could not move either way"
  ).toBeGreaterThan(before.viewport);

  await pressForward(page);
  await awaitReadout(page, FIRST_MARKER, 1);

  // The model half, and the primary contract: the message was dispatched and
  // the model recorded one movement. Trailing ';' on both so a longer
  // constructor name or a two-digit count cannot satisfy the fragment.
  await telemetry.assertDispatched("ScrollPane:Half_page_down;");
  await telemetry.assertRecordContains("scroll_pane", "pane_moves=1;");

  // The render half: the pane sits half its own visible height further on. The
  // expected value is the measured viewport, never a literal.
  const after = await pane(page);
  expect(
    Math.abs(after.scrollTop - before.scrollTop - before.viewport / 2),
    "the pane did not move half its own visible height"
  ).toBeLessThanOrEqual(TOLERANCE);

  // Only the named container's offset is written. A drain that reached for the
  // document instead would drag the page and still move something.
  expect(
    await page.evaluate(() => window.scrollY),
    "the movement dragged the document"
  ).toBe(pageBefore);

  await telemetry.attachHistory(test.info());
});

test("two identical presses move the pane twice", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await enableKeys(page, telemetry);

  const start = await pane(page);
  const step = start.viewport / 2;

  await pressForward(page);
  await awaitReadout(page, FIRST_MARKER, 1);
  const once = (await pane(page)).scrollTop;

  // The second press produces a request identical to the first in every
  // respect. A declaration compared for change would answer "already there"
  // and the pane would sit still; the move counter is what lets the gate above
  // tell the second press from the first, since both emit the same message.
  await pressForward(page);
  await awaitReadout(page, FIRST_MARKER, 2);
  await telemetry.assertRecordContains("scroll_pane", "pane_moves=2;");
  const twice = (await pane(page)).scrollTop;

  expect(
    Math.abs(once - start.scrollTop - step),
    "the first press did not move the pane half its own visible height"
  ).toBeLessThanOrEqual(TOLERANCE);
  expect(
    Math.abs(twice - once - step),
    "the second identical press left the pane where the first put it"
  ).toBeLessThanOrEqual(TOLERANCE);

  await telemetry.attachHistory(test.info());
});

test("the backward chord moves the pane back", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await enableKeys(page, telemetry);

  const start = await pane(page);
  const step = start.viewport / 2;

  // Parked away from the start first, so the backward movement has somewhere to
  // go: a pane already at the top answers every backward request by staying
  // put, and this case would then be green on a section that never moved.
  await pressForward(page);
  await pressForward(page);
  await awaitReadout(page, FIRST_MARKER, 2);
  const parked = (await pane(page)).scrollTop;
  expect(parked, "the pane never left the start").toBeGreaterThan(start.scrollTop);

  await pressBack(page);
  await awaitReadout(page, FIRST_MARKER, 3);
  await telemetry.assertDispatched("ScrollPane:Half_page_up;");
  await telemetry.assertRecordContains("scroll_pane", "pane_moves=3;");

  const back = (await pane(page)).scrollTop;
  expect(back, "the backward chord moved the pane forward").toBeLessThan(parked);
  expect(
    Math.abs(parked - back - step),
    "the backward chord did not move half a visible height"
  ).toBeLessThanOrEqual(TOLERANCE);

  await telemetry.attachHistory(test.info());
});

test("the chords do nothing until the reader asks for them", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  const before = await pane(page);
  await pressForward(page);
  await pressBack(page);

  // Two frames after the presses. A message is processed synchronously and the
  // pass it invalidates is scheduled on the next animation frame, so if either
  // chord had been live its movement would have landed by now.
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
      })
  );

  const events = await telemetry.events();
  expect(
    events.filter(
      (event) =>
        event.kind === "message" && event.value.includes("ScrollPane:")
    ),
    "an unsubscribed chord reached the model"
  ).toEqual([]);
  await awaitReadout(page, FIRST_MARKER, 0);
  expect(
    (await pane(page)).scrollTop,
    "an unsubscribed chord moved the pane"
  ).toBe(before.scrollTop);

  // The affirmative arm on the same fixture: once the gate is on, the same
  // chord does reach the model and does move the pane. Without it the absence
  // above would stay green on a section whose chords had stopped working
  // altogether, or on a pane with nothing to scroll.
  await enableKeys(page, telemetry);
  await pressForward(page);
  await awaitReadout(page, FIRST_MARKER, 1);
  await telemetry.assertRecordContains("scroll_pane", "pane_moves=1;");
  expect(
    Math.abs((await pane(page)).scrollTop - before.scrollTop - before.viewport / 2),
    "the gate was opened and the chord still did nothing"
  ).toBeLessThanOrEqual(TOLERANCE);

  await telemetry.attachHistory(test.info());
});

test("one update revealing and moving lands at the movement, not the reveal", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  const start = await pane(page);
  const step = start.viewport / 2;

  // One click changes the paragraph the pane is asked to bring into view AND
  // asks the pane to back off half a visible height. Both write the same
  // offset, so where the pane ends up is the whole ordering contract: the
  // reveal is applied first and the relative movement second, from wherever the
  // reveal left it.
  for (let cycle = 0; cycle < WAYPOINTS.length; cycle++) {
    await page.locator(WAYPOINT).click();
    await awaitReadout(page, WAYPOINTS[cycle], cycle + 1);

    await telemetry.assertDispatched("ScrollPane:Waypoint_advanced;");
    await telemetry.assertRecordContains(
      "scroll_pane",
      `pane_marker="${WAYPOINTS[cycle]}";`
    );
    await telemetry.assertRecordContains(
      "scroll_pane",
      `pane_moves=${cycle + 1};`
    );

    // Where the reveal alone would have left the pane: the marked paragraph's
    // top at the pane's top. Measured after the fact, and independent of where
    // the pane currently sits.
    const revealOnly = await paragraphOffset(page, WAYPOINT_INDEX[cycle]);
    const settled = await pane(page);
    const landed = settled.scrollTop;

    // The fixture precondition the two assertions below rest on, asserted
    // before them so a fixture problem cannot masquerade as a contract
    // failure. They read `revealOnly` as where the reveal ALONE would have
    // left the pane, which holds only while the reveal does not clamp: a
    // reveal is clamped to the pane's own maximum offset, so a waypoint
    // paragraph with less than a visible height of content beneath it never
    // reaches the pane's top and `revealOnly` overstates the reveal by the
    // shortfall. The paragraphs wrap and wrapping is font-dependent, so
    // whether that holds is a property of the machine and not of the
    // section's source, which is why it is measured rather than assumed.
    expect(
      revealOnly,
      "the waypoint paragraph has less than a visible height of content below " +
        "it, so the reveal clamped short of its top — the kitchen-sink section " +
        "needs more paragraphs after the waypoint. The reveal-then-move " +
        "ordering below is not what failed."
    ).toBeLessThanOrEqual(settled.content - settled.viewport);

    expect(
      landed,
      "the pane came to rest where the reveal alone would have put it, so the " +
        "relative movement was dropped or applied first"
    ).toBeLessThan(revealOnly - TOLERANCE);
    expect(
      Math.abs(revealOnly - landed - step),
      "the pane did not back off half a visible height from the revealed paragraph"
    ).toBeLessThanOrEqual(TOLERANCE);
  }

  await telemetry.attachHistory(test.info());
});

test("a focus batched with a relative movement lands at focus's position", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  const start = await pane(page);
  // A whole visible height, not the half the chords move by. The band below is
  // a viewport minus the focused row's own height, so a whole-viewport movement
  // drained AFTER the focus would leave the pane past the band by at least that
  // row's height — which is what makes the band discriminate the order rather
  // than merely record that focus ran.
  const step = start.viewport;

  // The third stage of the order, and the only one no shim can be trusted
  // about: where a browser's own default scroll-into-view takes the pane when
  // `Cmd.focus` lands on a row that is not visible. One click asks the pane to
  // move forward a whole visible height AND focuses a row far below it. Both
  // write the same offset, focus is drained last, and it takes no
  // `preventScroll` — so the pane comes to rest at focus's position, not at the
  // movement's.
  await page.locator(FOCUS_CONTROL).click();
  await awaitReadout(page, FIRST_MARKER, 1);

  await telemetry.assertDispatched("ScrollPane:Far_row_focused;");
  await telemetry.assertRecordContains("scroll_pane", "pane_moves=1;");
  // The reveal is untouched by this control, so exactly two of the three
  // writers contend and the landing below is the movement against focus.
  await telemetry.assertRecordContains(
    "scroll_pane",
    `pane_marker="${FIRST_MARKER}";`
  );

  const target = await extentInPane(page, FOCUS_TARGET);
  const settled = await pane(page);
  // The band a scroll-into-view leaves the pane in when it brings a row below
  // the pane into view: at least far enough for the row's bottom to reach the
  // pane's bottom, at most far enough for its top to reach the pane's top.
  // Every alignment the CSSOM defines — nearest, centre, start — lands inside
  // it, and the band is derived entirely from the focus target, so it says
  // "focus decided this" without pinning which alignment the browser chose.
  // OBSERVED (headless Chromium 2026-08-20): the pane landed at 2691 for a
  // 21px-tall target at 2790–2811 in a 220px pane — the centred position
  // (2690.5), not the nearest-edge one (2591). That is the browser's own
  // default, not this framework's contract, so it is recorded here rather than
  // asserted: Decision 3 says focus's scroll-into-view wins, and a Chromium
  // that moved to the spec's `nearest` would still honour it.
  const leastVisible = target.bottom - settled.viewport;
  const mostVisible = target.top;

  // Two fixture preconditions, asserted before the contract so a fixture
  // problem cannot masquerade as a contract failure. The row must be reachable
  // without the pane clamping at its own maximum, or the band overstates where
  // focus can take it; and the whole band must sit past the movement's own
  // landing, or the assertions below would hold whichever stage ran last.
  expect(
    mostVisible,
    "the focus target sits too close to the end of the pane, so the browser " +
      "clamped short of bringing it into view — the kitchen-sink section needs " +
      "more paragraphs after the focus target. The ordering below is not what " +
      "failed."
  ).toBeLessThanOrEqual(settled.content - settled.viewport);
  expect(
    leastVisible,
    "the focus target is not far enough down the pane to tell focus's landing " +
      "from the relative movement's"
  ).toBeGreaterThan(start.scrollTop + step + TOLERANCE);

  // The contract. Drained the other way round the pane would sit a whole visible
  // height past focus's own landing, and so past the band by at least the
  // focused row's height; with the focus dropped it would sit at `start + step`,
  // a long way short of it.
  expect(
    settled.scrollTop,
    "the pane came to rest short of showing the focused row, so focus's " +
      "scroll-into-view was not the last thing to write the offset"
  ).toBeGreaterThanOrEqual(leastVisible - TOLERANCE);
  expect(
    settled.scrollTop,
    "the pane came to rest past the focused row, which is where the relative " +
      "movement would leave it if it were drained after the focus"
  ).toBeLessThanOrEqual(mostVisible + TOLERANCE);
  expect(
    Math.abs(settled.scrollTop - (start.scrollTop + step)),
    "the pane came to rest at the relative movement's position, so the focus " +
      "was dropped or applied before it"
  ).toBeGreaterThan(TOLERANCE);

  // The affirmative arm for the geometry: focus actually landed on the row.
  // Without it a pane moved there by anything at all would satisfy the numbers.
  expect(
    await page.evaluate(
      (sel) => document.activeElement === document.querySelector(sel),
      FOCUS_TARGET
    ),
    "the focus command never reached the row"
  ).toBe(true);

  await telemetry.attachHistory(test.info());
});
