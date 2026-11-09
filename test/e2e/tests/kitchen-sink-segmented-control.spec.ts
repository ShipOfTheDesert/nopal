import { test, expect, type Page } from "@playwright/test";
import { assertNoAxeViolations } from "./axe";
import { NopalTelemetry } from "./nopal-telemetry";

// A segmented control: a row of visually hidden native radios, each wrapped in
// a segment box with its label, a divider between neighbours, and a ring on the
// segment holding focus. Every selection is asserted through the MVU telemetry
// log. Computed style and geometry are read only to prove what the browser
// paints. The expected values are the kitchen-sink section's design values,
// converted from their hex form, not read back from the page.

const SECTION = '[data-testid="segmented-control-section"]';
const BEFORE = '[data-testid="segmented-control-before"]';
const AFTER = '[data-testid="segmented-control-after"]';

type Control = { id: string; values: string[]; initial: string };

const THRESHOLD: Control = {
  id: "segmented-threshold",
  values: ["none", "15m", "1h", "1d", "custom"],
  initial: "1h",
};
const WINDOW: Control = {
  id: "segmented-window",
  values: ["7d", "30d", "90d", "all"],
  initial: "30d",
};
const REFUSING: Control = {
  id: "segmented-refusing",
  values: ["kept", "refused"],
  initial: "kept",
};
const CONTROLS = [THRESHOLD, WINDOW, REFUSING];

// #02403A, #FFFDF9, #CFC6B8 and the ring's rgba(11,97,88,0.35) with a 2px spread.
const SELECTED_FILL = "rgb(2, 64, 58)";
const SELECTED_TEXT = "rgb(255, 253, 249)";
const SELECTED_WEIGHT = "500";
const DIVIDER_FILL = "rgb(207, 198, 184)";
const NO_FILL = "rgba(0, 0, 0, 0)";
const RING = "rgba(11, 97, 88, 0.35) 0px 0px 0px 2px";
const RING_SPREAD = 2;
// The outline is 1px wide with radius 6, so an end segment's outer corners
// round to 5px and its inner corners stay square.
const OUTER_RADIUS = "5px";
const INNER_RADIUS = "0px";

// Generous: the first model-to-DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

function radio(control: Control, value: string): string {
  return `#${control.id}-${value}`;
}

function label(control: Control, value: string): string {
  return `#${control.id}-${value}-label`;
}

// Each segment box is its radio's parent.
function segment(page: Page, control: Control, value: string) {
  return page.locator(radio(control, value)).locator("xpath=..");
}

function message(ctor: string, value: string): string {
  return `SegmentedControl:${ctor}:${value};`;
}

// One painted frame, with no timer: the runtime renders on animation frames,
// so after this the DOM reflects every message dispatched before it.
async function nextFrame(page: Page): Promise<void> {
  await page.evaluate(
    () => new Promise<void>((resolve) => requestAnimationFrame(() => resolve()))
  );
}

async function gotoSection(page: Page): Promise<void> {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
  // Actionability wait for the first interaction, without clicking.
  await page.locator(BEFORE).click({ trial: true });
}

async function expectSelected(
  page: Page,
  control: Control,
  selected: string
): Promise<void> {
  for (const value of control.values) {
    const on = value === selected;
    if (on) await expect(page.locator(radio(control, value))).toBeChecked();
    else await expect(page.locator(radio(control, value))).not.toBeChecked();
    await expect(segment(page, control, value)).toHaveCSS(
      "background-color",
      on ? SELECTED_FILL : NO_FILL
    );
  }
}

async function expectRingOnlyOn(
  page: Page,
  control: Control,
  focused: string
): Promise<void> {
  for (const value of control.values) {
    const seg = segment(page, control, value);
    if (value === focused) {
      await expect(seg).toHaveCSS("box-shadow", RING);
      await expect(seg).toHaveCSS("z-index", "1");
    } else {
      await expect(seg).toHaveCSS("box-shadow", "none");
    }
  }
}

async function messageCount(
  telemetry: NopalTelemetry,
  prefix: string
): Promise<number> {
  const events = await telemetry.events();
  return events.filter((e) => e.kind === "message" && e.value.includes(prefix))
    .length;
}

type Rect = { left: number; top: number; right: number; bottom: number };

function overlaps(a: Rect, b: Rect): boolean {
  return (
    Math.min(a.right, b.right) - Math.max(a.left, b.left) > 0.5 &&
    Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) > 0.5
  );
}

function contains(outer: Rect, inner: Rect): boolean {
  return (
    inner.left >= outer.left - 0.5 &&
    inner.top >= outer.top - 0.5 &&
    inner.right <= outer.right + 0.5 &&
    inner.bottom <= outer.bottom + 0.5
  );
}

test.beforeEach(async ({ page }) => {
  await gotoSection(page);
});

test("selected fill and text equal declared", async ({ page }) => {
  for (const control of CONTROLS) {
    await expectSelected(page, control, control.initial);
    for (const value of control.values) {
      const text = page.locator(label(control, value));
      if (value === control.initial) {
        await expect(text).toHaveCSS("color", SELECTED_TEXT);
        await expect(text).toHaveCSS("font-weight", SELECTED_WEIGHT);
      } else {
        await expect(text).not.toHaveCSS("color", SELECTED_TEXT);
      }
    }
  }
});

test("press moves selection and fill", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await expectSelected(page, WINDOW, "30d");

  await telemetry.events();
  await page.locator(label(WINDOW, "90d")).click();
  await telemetry.waitForNewMessage(message("Window_selected", "90d"), SETTLE);
  await nextFrame(page);

  await expectSelected(page, WINDOW, "90d");
  // Counted on the slice since the press, so a duplicate dispatch from the one
  // press would show here as 2.
  expect(await messageCount(telemetry, "SegmentedControl:")).toBe(1);
  await telemetry.assertDispatched(message("Window_selected", "90d"));
});

test("refused selection snaps back", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await expectSelected(page, REFUSING, "kept");

  await telemetry.events();
  await page.locator(label(REFUSING, "refused")).click();
  await telemetry.waitForNewMessage(
    message("Refusing_selected", "refused"),
    SETTLE
  );
  await nextFrame(page);

  // The press reached update: the message is in the log. The update kept the
  // old value, so the checked radio and the fill are back on it.
  await telemetry.events();
  await telemetry.assertDispatched(message("Refusing_selected", "refused"));
  await expectSelected(page, REFUSING, "kept");
});

test("Tab lands on selected with ring; ArrowRight moves all three", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(BEFORE).focus();
  await page.keyboard.press("Tab");
  await nextFrame(page);
  await expect(page.locator(radio(THRESHOLD, "1h"))).toBeFocused();
  await expectRingOnlyOn(page, THRESHOLD, "1h");

  await telemetry.events();
  await page.keyboard.press("ArrowRight");
  await telemetry.waitForNewMessage(
    message("Threshold_selected", "1d"),
    SETTLE
  );
  await nextFrame(page);
  await expect(page.locator(radio(THRESHOLD, "1d"))).toBeFocused();
  await expectSelected(page, THRESHOLD, "1d");
  await expectRingOnlyOn(page, THRESHOLD, "1d");

  // One tab stop per control: the next Tab leaves for the next control's
  // selected segment, then for the third, then past the section.
  await page.keyboard.press("Tab");
  await nextFrame(page);
  await expect(page.locator(radio(WINDOW, "30d"))).toBeFocused();
  await page.keyboard.press("Tab");
  await nextFrame(page);
  await expect(page.locator(radio(REFUSING, "kept"))).toBeFocused();
  await page.keyboard.press("Tab");
  await nextFrame(page);
  await expect(page.locator(AFTER)).toBeFocused();
});

test("ring unclipped on first and last", async ({ page }) => {
  for (const control of CONTROLS) {
    const first = control.values[0];
    const last = control.values[control.values.length - 1];
    for (const [value, outer, inner] of [
      [first, "left", "right"],
      [last, "right", "left"],
    ] as const) {
      const seg = segment(page, control, value);
      await seg.scrollIntoViewIfNeeded();

      // Inside the section, nothing between the segment and the section may
      // clip. Above it, the page's own scroll container does, so there the ring
      // box must fit inside that container's rect.
      const walk = await seg.evaluate((el, section) => {
        const toRect = (b: DOMRect) => ({
          left: b.left,
          top: b.top,
          right: b.right,
          bottom: b.bottom,
        });
        const inside: string[] = [];
        const above: { left: number; top: number; right: number; bottom: number }[] = [];
        let reachedSection = false;
        for (
          let node = el.parentElement;
          node !== null && node !== document.body;
          node = node.parentElement
        ) {
          const s = getComputedStyle(node);
          const clips = s.overflowX !== "visible" || s.overflowY !== "visible";
          if (!reachedSection) {
            if (clips) inside.push(`${node.tagName}: ${s.overflowX}/${s.overflowY}`);
            reachedSection = node.matches(section);
          } else if (clips) {
            above.push(toRect(node.getBoundingClientRect()));
          }
        }
        return {
          inside,
          above,
          reachedSection,
          segment: toRect(el.getBoundingClientRect()),
        };
      }, SECTION);
      expect(walk.reachedSection).toBe(true);
      expect(walk.inside).toEqual([]);

      const ring: Rect = {
        left: walk.segment.left - RING_SPREAD,
        top: walk.segment.top - RING_SPREAD,
        right: walk.segment.right + RING_SPREAD,
        bottom: walk.segment.bottom + RING_SPREAD,
      };
      const viewport = page.viewportSize()!;
      const clips: Rect[] = [
        { left: 0, top: 0, right: viewport.width, bottom: viewport.height },
        ...walk.above,
      ];
      for (const clip of clips) expect(contains(clip, ring)).toBe(true);

      await expect(seg).toHaveCSS(`border-top-${outer}-radius`, OUTER_RADIUS);
      await expect(seg).toHaveCSS(
        `border-bottom-${outer}-radius`,
        OUTER_RADIUS
      );
      await expect(seg).toHaveCSS(`border-top-${inner}-radius`, INNER_RADIUS);
      await expect(seg).toHaveCSS(
        `border-bottom-${inner}-radius`,
        INNER_RADIUS
      );

      // Focus without selecting: the ring is painted on this end segment.
      await page.locator(radio(control, value)).focus();
      await nextFrame(page);
      await expect(seg).toHaveCSS("box-shadow", RING);
      await expect(seg).toHaveCSS("z-index", "1");
    }
  }
});

test("dividers n−1, none first", async ({ page }) => {
  for (const control of CONTROLS) {
    const first = segment(page, control, control.values[0]);
    const children = await first.evaluate((el) =>
      Array.from(el.parentElement!.children).map((child) => ({
        segment: child.querySelector('input[type="radio"]') !== null,
        background: getComputedStyle(child).backgroundColor,
        width: child.getBoundingClientRect().width,
      }))
    );

    const n = control.values.length;
    expect(children.length).toBe(2 * n - 1);
    expect(children[0].segment).toBe(true);
    expect(children[children.length - 1].segment).toBe(true);
    // Segments and dividers alternate, so every divider sits between two
    // segments and there are n − 1 of them.
    children.forEach((child, i) => expect(child.segment).toBe(i % 2 === 0));
    const dividers = children.filter((child) => !child.segment);
    expect(dividers.length).toBe(n - 1);
    for (const divider of dividers) {
      expect(divider.background).toBe(DIVIDER_FILL);
      expect(divider.width).toBeCloseTo(1, 1);
    }
  }
});

test("forced colours: radios visible, no overlap", async ({ page }) => {
  // The `forcedColors` context option leaves the media query unmatched in this
  // Playwright's Chromium; emulating the media feature on the page matches it.
  await page.emulateMedia({ forcedColors: "active" });
  await nextFrame(page);
  expect(
    await page.evaluate(() => matchMedia("(forced-colors: active)").matches)
  ).toBe(true);

  for (const control of CONTROLS) {
    const rects = await page.evaluate(
      ({ id, values }) =>
        values.map((value) => {
          const r = document.getElementById(`${id}-${value}`)!;
          const l = document.getElementById(`${id}-${value}-label`)!;
          const toRect = (el: Element) => {
            const b = el.getBoundingClientRect();
            return { left: b.left, top: b.top, right: b.right, bottom: b.bottom };
          };
          return {
            radio: toRect(r),
            label: toRect(l),
            segment: toRect(r.parentElement!),
          };
        }),
      { id: control.id, values: control.values }
    );

    rects.forEach((own, i) => {
      expect(own.radio.right - own.radio.left).toBeGreaterThan(1);
      expect(own.radio.bottom - own.radio.top).toBeGreaterThan(1);
      expect(contains(own.segment, own.radio)).toBe(true);
      expect(overlaps(own.radio, own.label)).toBe(false);
      rects.forEach((other, j) => {
        if (i !== j) expect(overlaps(own.radio, other.segment)).toBe(false);
      });
    });
  }
});

test("axe green", async ({ page }, testInfo) => {
  await assertNoAxeViolations(page, testInfo, SECTION);

  const section = page.locator(SECTION);
  const groups = section.getByRole("radiogroup");
  await expect(groups).toHaveCount(CONTROLS.length);
  await expect(
    section.getByRole("radiogroup", { name: "Alert threshold", exact: true })
  ).toHaveCount(1);
  await expect(
    section.getByRole("radio", { name: "1 hour", exact: true })
  ).toBeChecked();
});
