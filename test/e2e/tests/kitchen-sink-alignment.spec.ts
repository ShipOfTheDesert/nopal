import { test, expect, type Page } from "@playwright/test";

// Alignment renders as written, measured in the browser.
//
// An emitted declaration says what was asked for, and the structural suite can
// see only that. A token the platform does not accept is dropped without a
// diagnostic, and the property then computes to its initial value, `normal`,
// which lays out as stretch on the cross axis. So each row's computed value is
// compared with the token its alignment emits, and the one value per axis whose
// geometry differs from its neighbours is measured as well.
//
// The tokens and the section's sizes are restated here rather than read back
// out of the page, so a change on either side reddens this file instead of
// being compared with itself.
//
// Headless mitigations: navigate fresh with goto and never page.reload(), and
// wait for the section before reading it.

const SECTION = '[data-testid="alignment-section"]';
const row = (testid: string) => `${SECTION} [data-testid="${testid}"]`;

const MAIN_TOKENS: Array<[string, string]> = [
  ["align-main-start", "flex-start"],
  ["align-main-center", "center"],
  ["align-main-end", "flex-end"],
  ["align-main-space-between", "space-between"],
];

const CROSS_TOKENS: Array<[string, string]> = [
  ["align-cross-start", "flex-start"],
  ["align-cross-center", "center"],
  ["align-cross-end", "flex-end"],
  ["align-cross-stretch", "stretch"],
];

const MAIN_ROW_WIDTH = 300;
const BOX_WIDTH = 40;
const CROSS_ROW_HEIGHT = 100;
const CROSS_BOX_HEIGHTS = [20, 40, 60];

// Generous: the first model to DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

type Rect = { left: number; right: number; height: number };
type Geometry = { content: Rect; children: Rect[] };

// The row's content box and its children's border boxes, read in a single
// evaluation so they cannot straddle a frame.
async function geometry(page: Page, selector: string): Promise<Geometry> {
  return await page.evaluate((sel) => {
    const el = document.querySelector(sel);
    if (el === null) throw new Error(`no element: ${sel}`);
    const r = el.getBoundingClientRect();
    const cs = getComputedStyle(el);
    const px = (v: string) => parseFloat(v);
    const top = r.top + px(cs.borderTopWidth) + px(cs.paddingTop);
    const bottom = r.bottom - px(cs.borderBottomWidth) - px(cs.paddingBottom);
    const content = {
      left: r.left + px(cs.borderLeftWidth) + px(cs.paddingLeft),
      right: r.right - px(cs.borderRightWidth) - px(cs.paddingRight),
      height: bottom - top,
    };
    const children = Array.from(el.children).map((c) => {
      const b = c.getBoundingClientRect();
      return { left: b.left, right: b.right, height: b.height };
    });
    return { content, children };
  }, selector);
}

async function measured(
  page: Page,
  selector: string,
  claim: (g: Geometry) => void
): Promise<void> {
  await expect(async () => claim(await geometry(page, selector))).toPass({
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

test("cross-axis computed align-items equals the value set", async ({
  page,
}) => {
  for (const [testid, token] of CROSS_TOKENS) {
    await expect(page.locator(row(testid))).toHaveCSS("align-items", token, {
      timeout: SETTLE,
    });
  }
});

test("main-axis computed justify-content equals the value set", async ({
  page,
}) => {
  for (const [testid, token] of MAIN_TOKENS) {
    await expect(page.locator(row(testid))).toHaveCSS(
      "justify-content",
      token,
      { timeout: SETTLE }
    );
  }
});

test("space-between places children at both ends", async ({ page }) => {
  await measured(page, row("align-main-space-between"), (g) => {
    // Preconditions: a row with room to spare, so ends that touch its edges
    // cannot be explained by the children filling it.
    expect(g.content.right - g.content.left, "row width").toBe(MAIN_ROW_WIDTH);
    expect(g.children.length, "child count").toBe(3);
    for (const c of g.children) {
      expect(c.right - c.left, "child width").toBe(BOX_WIDTH);
    }

    const first = g.children[0];
    const last = g.children[g.children.length - 1];
    expect(first.left - g.content.left, "first child's left inset").toBe(0);
    expect(g.content.right - last.right, "last child's right inset").toBe(0);
  });
});

test("cross stretch fills the row height", async ({ page }) => {
  await measured(page, row("align-cross-stretch"), (g) => {
    expect(g.content.height, "row height").toBe(CROSS_ROW_HEIGHT);
    expect(g.children.length, "child count").toBe(3);
    for (const c of g.children) {
      expect(c.height, "stretched child height").toBe(g.content.height);
    }
  });

  // The affirmative arm: on the start row the same row height leaves each
  // child at the height it declares.
  await measured(page, row("align-cross-start"), (g) => {
    expect(g.content.height, "row height").toBe(CROSS_ROW_HEIGHT);
    expect(
      g.children.map((c) => c.height),
      "start children's heights"
    ).toEqual(CROSS_BOX_HEIGHTS);
  });
});
