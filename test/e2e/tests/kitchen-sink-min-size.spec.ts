import { test, expect, type Page } from "@playwright/test";

// A floor of zero lets a scrolling descendant scroll, measured in the browser.
//
// This suite exists because no other layer can hold the claim. Every element
// this framework renders is an item of its container's layout, and the platform
// gives such an item an automatic minimum equal to its own content: an element
// wrapped around a scrolling child grows to fit that child instead of letting it
// scroll, and whatever follows it inside a container of a settled height is laid
// out past that container's bottom edge. Whether that happened is a property of
// rendered geometry and of nothing else. The element tree is identical in both
// shapes — the structural suite beside this one can see only that the control
// reaches the column it claims to and that the fixture is still overconstrained
// — and an emitted declaration says what was asked for, never what the browser
// did with it.
//
// So there is no telemetry half here, and that is not an omission. Telemetry is
// this project's primary correctness contract and the DOM is reserved for render
// correctness; a minimum size has no vocabulary in the model at all, so the only
// state a serializer could report is the checkbox, which would prove that a
// control was clicked and nothing about what the page then looked like.
//
// Every assertion below is a measured rect or a scroll metric, and this file
// reads no computed declaration anywhere, not even to wait on one. That is
// deliberate rather than incidental. The model to DOM frame is asynchronous, so
// a measurement taken straight after a click is last frame's layout and needs a
// settle condition; the obvious one — wait for the declaration the click causes
// — cannot be used here, because this section's control changes exactly one
// declaration and it is the one under test. Gating on it would make every
// assertion in the second case unreachable whenever the emitter is the thing
// that broke, leaving a computed-CSS read as the only discriminating check in a
// suite written precisely because a computed-CSS read cannot see this defect.
// So the measurement is its own settle condition: each block below is retried
// until it passes or the budget runs out, and a failure reports a number.
//
// OBSERVED, headless Chromium, 2026-09-15, devicePixelRatio 1. In the reported
// shape the pane is handed the whole of its content, so it has nothing to scroll
// in (scrollHeight and clientHeight both 260) and the band is laid out exactly
// 92px past the bottom edge of the column that is supposed to hold it. With the
// floor declared the column gives way, the pane is reduced to the room left
// beside the band (clientHeight 168 against an unchanged scrollHeight of 260)
// and the band's bottom edge lands exactly on the container's. Every height came
// back an exact integer, so nothing here carries a tolerance. The page-absolute
// edges did not: they carry a fractional part, and they differ by thousands of
// pixels between the two cases — 10092.59375 against 581.59375 for the same
// container — which is what checking a control far down a long page does to the
// document under the viewport. Both edges move together, and each case compares
// them only with each other inside a single evaluation, so that is inert; but it
// is why no case compares a page-absolute edge with a literal.
//
// What this file does NOT cover, so that its silence is not read as assurance:
// only the vertical axis is measured. A floor on the horizontal axis exists and
// has the same job against a horizontally scrolling row, but this section
// declares none and no case here touches one; that axis is pinned at the
// emitter, where both clauses are asserted, and nowhere in a browser.
//
// OBSERVED, 2026-09-15: with the emitter's two minimum clauses routed through a
// formatter that drops a zero — the shape two neighbouring idioms in that same
// function already have, so the plausible mistake rather than an absurd one —
// the second case below fails on a value, and on the first contract it reaches:
// the band's bottom edge measures 673.59375 against a container bottom of
// 581.59375, the same 92px overhang the reported shape has. So it discriminates
// on the zero that motivates the whole change, not merely on the field existing.
// The first case stays green under that mutation, which is the right shape: it
// pins the shape the section starts in, which no emitter change can reach.
//
// The sizes the section declares are restated here rather than read back out of
// it. The section keeps them private on purpose: derived from the page, every
// precondition below would compare a size with itself and a size changed there
// would stay green.
//
// Headless mitigations: navigate fresh with goto and never page.reload(), and
// wait for the section before touching the control.

const SECTION = '[data-testid="min-size-section"]';
const BOUNDED = `${SECTION} [data-testid="min-size-bounded"]`;
const PANE = `${SECTION} [data-testid="min-size-pane"]`;
const CONTENT = `${SECTION} [data-testid="min-size-content"]`;
const BAND = `${SECTION} [data-testid="min-size-band"]`;
const FLOOR_TOGGLE = `${SECTION} [data-field="min-size-floor"]`;

// The section renders two further test ids, and neither is read here. The
// holding column's is what the structural suite uses to say the control reaches
// that column and no other, which is a statement about declared style; the
// section root's is the footprint reservation that keeps the escaped band out of
// the section below, which is a declared height. Both are assertions about the
// element tree, and the structural suite is where the element tree can be seen.

const BOUNDED_HEIGHT = 200;
const BAND_HEIGHT = 32;
const CONTENT_HEIGHT = 260;

// Generous: the first model to DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

type Geometry = {
  boundedBottom: number;
  boundedHeight: number;
  bandBottom: number;
  bandHeight: number;
  contentHeight: number;
  paneScrollHeight: number;
  paneClientHeight: number;
};

// Every number one assertion needs, read in a single evaluation so they cannot
// straddle a frame.
async function geometry(page: Page): Promise<Geometry> {
  return await page.evaluate(
    ([boundedSel, paneSel, contentSel, bandSel]) => {
      const pick = (selector: string): HTMLElement => {
        const el = document.querySelector(selector);
        if (el === null) throw new Error(`no element: ${selector}`);
        return el as HTMLElement;
      };
      const bounded = pick(boundedSel).getBoundingClientRect();
      const pane = pick(paneSel);
      const content = pick(contentSel).getBoundingClientRect();
      const band = pick(bandSel).getBoundingClientRect();
      return {
        boundedBottom: bounded.bottom,
        boundedHeight: bounded.height,
        bandBottom: band.bottom,
        bandHeight: band.height,
        contentHeight: content.height,
        paneScrollHeight: pane.scrollHeight,
        paneClientHeight: pane.clientHeight,
      };
    },
    [BOUNDED, PANE, CONTENT, BAND] as [string, string, string, string]
  );
}

// The settle condition and the assertion in one. The block is re-measured until
// it holds, so the frame the numbers come from is the frame in which they mean
// something, and a block that never holds fails on the reading it last saw
// rather than on a wait that expired somewhere else.
async function measured(
  page: Page,
  claim: (geometry: Geometry) => void
): Promise<void> {
  await expect(async () => claim(await geometry(page))).toPass({
    timeout: SETTLE,
  });
}

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("without the minimum the trailing band leaves its container", async ({
  page,
}) => {
  // The reported shape is the section's initial state, so nothing is clicked
  // here.
  await measured(page, (geometry) => {
    // Preconditions, asserted before the contract so a fixture problem cannot
    // masquerade as a contract failure.
    expect(
      geometry.boundedHeight,
      "the bounded column is not the height it declares, so the room its " +
        "children compete for is not the room this case assumes. The band " +
        "below is not what failed."
    ).toBe(BOUNDED_HEIGHT);
    expect(
      geometry.contentHeight,
      "the pane's content is not the height it declares, so the pane may not " +
        "be overflowing at all. The band below is not what failed."
    ).toBe(CONTENT_HEIGHT);
    expect(
      geometry.bandHeight,
      "the band is not the height it declares, so the room it leaves the pane " +
        "in the arithmetic below is not the room it actually leaves"
    ).toBe(BAND_HEIGHT);
    expect(
      geometry.contentHeight,
      "the pane's content now fits the room left in the bounded column once " +
        "the band has taken its own, so nothing is pushing on the fixture and " +
        "both assertions below would hold for no reason"
    ).toBeGreaterThan(BOUNDED_HEIGHT - BAND_HEIGHT);

    // The defect, pinned. The column wrapped around the pane cannot be reduced
    // below its own content, so it takes the whole fixture and the band is laid
    // out past the bottom edge of the container that is supposed to hold it.
    expect(
      geometry.bandBottom,
      "the band stayed inside its container with no floor declared, so " +
        "something else is now lifting the automatic minimum and this section " +
        "no longer shows the shape the feature is about"
    ).toBeGreaterThan(geometry.boundedBottom);

    // The other half of the same defect, and the reason it matters: the pane
    // was handed the whole of its content, so there is nothing left to scroll.
    expect(
      geometry.paneClientHeight,
      "the pane was not handed the whole of its content, so the column did " +
        "give way and the absence of scrolling below would not be caused by " +
        "what this case claims"
    ).toBe(CONTENT_HEIGHT);
    expect(
      geometry.paneScrollHeight,
      "the pane has content to scroll with no floor declared, which is the " +
        "remedy rather than the defect"
    ).toBeLessThanOrEqual(geometry.paneClientHeight);
  });
});

test("with the minimum the band stays inside and the pane scrolls", async ({
  page,
}) => {
  await page.locator(FLOOR_TOGGLE).check();

  await measured(page, (geometry) => {
    // The container did not move. Everything below is about what happens inside
    // it, so a container that grew would make each of those readings true for
    // the wrong reason.
    expect(
      geometry.boundedHeight,
      "the bounded column changed height when the floor was declared, so the " +
        "readings below are not about the same container"
    ).toBe(BOUNDED_HEIGHT);
    expect(
      geometry.bandHeight,
      "the band changed height when the floor was declared, so it is not the " +
        "column that gave way"
    ).toBe(BAND_HEIGHT);
    expect(
      geometry.contentHeight,
      "the pane's content shrank instead of overflowing, so the pane has room " +
        "for it and the scrolling below would not be caused by what this case " +
        "claims"
    ).toBe(CONTENT_HEIGHT);

    // The contract. The floor lets the column be reduced below its own content,
    // so the band comes back inside the container that declares the room.
    expect(
      geometry.bandBottom,
      "the band is still laid out past the bottom edge of the container that " +
        "holds it, so the floor did not reach the layout"
    ).toBeLessThanOrEqual(geometry.boundedBottom);

    // And the overflow the column gave up is handed to the pane, which is what
    // the floor is for.
    expect(
      geometry.paneClientHeight,
      "the pane was not reduced to the room left beside the band, so the " +
        "column gave up a different amount than the fixture declares"
    ).toBe(BOUNDED_HEIGHT - BAND_HEIGHT);
    expect(
      geometry.paneScrollHeight,
      "the pane has nothing to scroll, so the content it cannot show was lost " +
        "rather than handed to it"
    ).toBeGreaterThan(geometry.paneClientHeight);
  });
});
