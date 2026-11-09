import { test, expect, type Locator, type Page } from "@playwright/test";
import { assertNoAxeViolations } from "./axe";
import { NopalTelemetry } from "./nopal-telemetry";

// A switch: a button with role="switch" and aria-checked, named by a separate
// label, with a visible reason when disabled and an optional hint beneath it.
// Every dispatch, and every absence of one, is asserted as the section's exact
// list of telemetry messages, so a press that dispatched twice fails as surely
// as one that dispatched nothing. The DOM is read only for the role, the state,
// the description, the ring and the forced-colours geometry. Expected values
// are the kitchen-sink section's design values and the component's default
// track geometry, converted by hand, not read back from the page.

const SECTION = '[data-testid="switch-section"]';
const BEFORE = '[data-testid="switch-before"]';
const AFTER = '[data-testid="switch-after"]';
const LINK = '[data-testid="switch-dropped-alerts-link"]';
const PREFIX = "Switch:";

const LABEL = "Send an alert when it goes silent";
const REASON = "Needs a silence threshold.";
const STARTS_ON_HINT = "Delivering to alerts.example.com";
const DROPPED_HINT = "Off, so alerts are being dropped. See the dropped alerts";

const STARTS_ON = "switch-starts-on";
const STARTS_OFF = "switch-starts-off";
const DISABLED = "switch-disabled";

const START_PATH = "/kitchen_sink/";
const DROPPED_PATH = "/kitchen_sink/?switch=dropped-alerts";

// The section's ring: spread 3 in rgba(11, 97, 88, 0.5), radius 12. The
// component's own default ring is a 2px spread in #1a73e8; the section's must
// differ from it, or the computed value could not tell the override from the
// default.
const RING = "rgba(11, 97, 88, 0.5) 0px 0px 0px 3px";
const DEFAULT_RING = "rgb(26, 115, 232) 0px 0px 0px 2px";
const RING_RADIUS = "12px";

// The default track is 36px of content inside 2px of padding and a 2px border;
// the knob is a 16px disc. Off, the knob starts after the border and padding,
// 4px in. On, it ends 4px before the far edge: 44 − 4 − 16 = 24px in.
const KNOB_OFFSET_OFF = 4;
const KNOB_OFFSET_ON = 24;

// Generous: the first model-to-DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

const button = (page: Page, id: string): Locator => page.locator(`#${id}`);
const label = (page: Page, id: string): Locator =>
  page.locator(`label[for="${id}"]`);

function toggled(ctor: string, on: boolean): string {
  return `${PREFIX}${ctor}:${on};`;
}

// No pending timers, then one painted frame: a zero-delay timer runs after any
// timer already due, and the runtime renders on animation frames, so after this
// every message the interaction caused is in the log and on the page.
async function settle(page: Page): Promise<void> {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => {
        setTimeout(() => requestAnimationFrame(() => resolve()), 0);
      })
  );
}

// Every message this section dispatched since the previous read, in order.
// Scoped by the section's serializer prefix so another section's traffic cannot
// pad the list.
async function sectionMessages(telemetry: NopalTelemetry): Promise<string[]> {
  const events = await telemetry.events();
  return events.flatMap((e) =>
    e.kind === "message" && e.value.startsWith(PREFIX) ? [e.value] : []
  );
}

// The section's whole dispatch list since the last read equals `expected`. A
// non-empty list is waited for by its last message first; an empty one is
// asserted only after the settle, when anything the action caused would show.
async function expectDispatches(
  page: Page,
  telemetry: NopalTelemetry,
  expected: string[],
  what: string
): Promise<void> {
  const last = expected[expected.length - 1];
  if (last !== undefined) await telemetry.waitForNewMessage(last, SETTLE);
  await settle(page);
  expect(await sectionMessages(telemetry), what).toEqual(expected);
}

// Keyboard focus by Tab from the control before `target`, so the browser
// treats it as keyboard focus and `:focus-visible` holds.
async function tabTo(page: Page, from: Locator, target: Locator) {
  await from.focus();
  await page.keyboard.press("Tab");
  await expect(target).toBeFocused();
}

// The browser's own accessibility node for the element at `selector`, read
// from Chromium's AX tree.
async function axNode(
  page: Page,
  selector: string
): Promise<{ role?: string; name?: string; description?: string }> {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("DOM.enable");
  await cdp.send("Accessibility.enable");
  const { root } = await cdp.send("DOM.getDocument");
  const { nodeId } = await cdp.send("DOM.querySelector", {
    nodeId: root.nodeId,
    selector,
  });
  const { nodes } = await cdp.send("Accessibility.getPartialAXTree", {
    nodeId,
    fetchRelatives: false,
  });
  await cdp.detach();
  const node = nodes[0];
  return {
    role: node?.role?.value as string | undefined,
    name: node?.name?.value as string | undefined,
    description: node?.description?.value as string | undefined,
  };
}

type Geometry = {
  offset: number;
  trackBackground: string;
  trackBorder: string[];
  knobBorder: string[];
};

// The knob's left edge measured from the track's, and the track's and knob's
// borders. The track is the button's only child, the knob the track's.
async function geometry(page: Page, id: string): Promise<Geometry> {
  return button(page, id).evaluate((el) => {
    const track = el.firstElementChild as HTMLElement;
    const knob = track.firstElementChild as HTMLElement;
    const border = (node: HTMLElement) => {
      const s = getComputedStyle(node);
      return [
        `${s.borderTopStyle} ${s.borderTopWidth}`,
        `${s.borderRightStyle} ${s.borderRightWidth}`,
        `${s.borderBottomStyle} ${s.borderBottomWidth}`,
        `${s.borderLeftStyle} ${s.borderLeftWidth}`,
      ];
    };
    return {
      offset:
        knob.getBoundingClientRect().left - track.getBoundingClientRect().left,
      trackBackground: getComputedStyle(track).backgroundColor,
      trackBorder: border(track),
      knobBorder: border(knob),
    };
  });
}

async function gotoSection(page: Page): Promise<void> {
  await page.goto(START_PATH);
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
  // Actionability wait for the first interaction, without clicking.
  await page.locator(BEFORE).click({ trial: true });
}

test.describe("default colours", () => {
  test.beforeEach(async ({ page }) => {
    await gotoSection(page);
  });

  test("finds switch by role and name with aria-checked", async ({ page }) => {
    const section = page.locator(SECTION);
    await expect(
      section.getByRole("switch", { name: LABEL, exact: true })
    ).toHaveCount(3);
    await expect(
      section.getByRole("switch", { name: LABEL, checked: true })
    ).toHaveCount(1);

    for (const [id, checked] of [
      [STARTS_ON, "true"],
      [STARTS_OFF, "false"],
      [DISABLED, "false"],
    ] as const) {
      const sw = button(page, id);
      await expect(sw).toHaveRole("switch");
      await expect(sw).toHaveAccessibleName(LABEL);
      await expect(sw).toHaveAttribute("aria-checked", checked);
      const ax = await axNode(page, `#${id}`);
      expect(ax.role, id).toBe("switch");
      expect(ax.name, id).toBe(LABEL);
    }
    await expect(button(page, DISABLED)).toHaveAttribute(
      "aria-disabled",
      "true"
    );
    await expect(button(page, STARTS_OFF)).not.toHaveAttribute(
      "aria-disabled",
      /.*/
    );
  });

  test("click, Space, Enter, label each toggle once", async ({ page }) => {
    const telemetry = new NopalTelemetry(page);
    const sw = button(page, STARTS_OFF);
    await telemetry.events();

    // Each press asks for the opposite of the rendered value, so the four
    // presses alternate, and each must be the only message it caused.
    await sw.click();
    await expectDispatches(
      page,
      telemetry,
      [toggled("Starts_off_toggled", true)],
      "a click on the off switch"
    );
    await expect(sw).toHaveAttribute("aria-checked", "true");

    await sw.press("Space");
    await expectDispatches(
      page,
      telemetry,
      [toggled("Starts_off_toggled", false)],
      "Space on the on switch"
    );
    await expect(sw).toHaveAttribute("aria-checked", "false");

    await sw.press("Enter");
    await expectDispatches(
      page,
      telemetry,
      [toggled("Starts_off_toggled", true)],
      "Enter on the off switch"
    );
    await expect(sw).toHaveAttribute("aria-checked", "true");

    await label(page, STARTS_OFF).click();
    await expectDispatches(
      page,
      telemetry,
      [toggled("Starts_off_toggled", false)],
      "a press on the on switch's label"
    );
    await expect(sw).toHaveAttribute("aria-checked", "false");
    await telemetry.attachHistory(test.info());
  });

  test("disabled takes focus and dispatches nothing", async ({ page }) => {
    const telemetry = new NopalTelemetry(page);
    const sw = button(page, DISABLED);
    await telemetry.events();

    // In the tab order: Tab from the enabled switch before it lands on it.
    await tabTo(page, button(page, STARTS_OFF), sw);

    // Playwright refuses to click an aria-disabled button, or a label naming
    // one, unless forced; the browser still delivers the click.
    await sw.click({ force: true });
    await expectDispatches(page, telemetry, [], "a click on the disabled switch");
    await expect(sw).toBeFocused();

    await sw.press("Space");
    await expectDispatches(page, telemetry, [], "Space on the disabled switch");

    await sw.press("Enter");
    await expectDispatches(page, telemetry, [], "Enter on the disabled switch");

    await label(page, DISABLED).click({ force: true });
    await expectDispatches(
      page,
      telemetry,
      [],
      "a press on the disabled switch's label"
    );
    await expect(sw).toBeFocused();
    await expect(sw).toHaveAttribute("aria-checked", "false");

    // The same log, read the same way, does record a press: the enabled switch
    // above dispatches exactly once, so the empty lists above are the disabled
    // switch holding, not the log being deaf.
    await button(page, STARTS_OFF).click();
    await expectDispatches(
      page,
      telemetry,
      [toggled("Starts_off_toggled", true)],
      "a click on the enabled switch after the disabled presses"
    );
    await telemetry.attachHistory(test.info());
  });

  test("accessible description is reason then hint", async ({ page }) => {
    const disabled = await axNode(page, `#${DISABLED}`);
    expect(disabled.description).toBe(`${REASON} ${DROPPED_HINT}`);

    const startsOn = await axNode(page, `#${STARTS_ON}`);
    expect(startsOn.description).toBe(STARTS_ON_HINT);

    // No reason and no hint: nothing describes it.
    await expect(button(page, STARTS_OFF)).not.toHaveAttribute(
      "aria-describedby",
      /.*/
    );
    const startsOff = await axNode(page, `#${STARTS_OFF}`);
    expect(startsOff.description ?? "").toBe("");

    // The reason is visible text, not only a description.
    await expect(page.locator(`#${DISABLED}-reason`)).toBeVisible();
    await expect(page.locator(`#${DISABLED}-reason`)).toHaveText(REASON);
  });

  test("focus ring computed style equals declared", async ({ page }) => {
    expect(RING).not.toBe(DEFAULT_RING);
    for (const [from, id] of [
      [BEFORE, STARTS_ON],
      [`#${STARTS_OFF}`, DISABLED],
    ] as const) {
      const sw = button(page, id);
      await expect(sw, `${id} before focus`).toHaveCSS("box-shadow", "none");

      await tabTo(page, page.locator(from), sw);
      await settle(page);
      await expect(sw, `${id} on keyboard focus`).toHaveCSS("box-shadow", RING);
      await expect(sw).toHaveCSS("border-top-left-radius", RING_RADIUS);
      await expect(sw).toHaveCSS("border-bottom-right-radius", RING_RADIUS);
    }
  });

  test("hint link is reachable and navigates", async ({ page }) => {
    const telemetry = new NopalTelemetry(page);
    const link = page.locator(LINK);
    await expect(link).toHaveAttribute("href", DROPPED_PATH);
    await expect(page.locator(`#${DISABLED}-hint`)).toContainText(
      "See the dropped alerts"
    );

    // Reachable by keyboard: the next tab stop after the disabled switch.
    await tabTo(page, button(page, DISABLED), link);

    // A value on `window` is lost by any page load, so its survival shows the
    // link was followed in-app.
    await page.evaluate(() => {
      (window as unknown as { __switchMarker: number }).__switchMarker = 1;
    });
    await telemetry.events();

    await page.keyboard.press("Enter");
    await expectDispatches(
      page,
      telemetry,
      [`${PREFIX}Dropped_alerts_followed;`],
      "Enter on the hint's link"
    );
    await expect
      .poll(() => {
        const url = new URL(page.url());
        return url.pathname + url.search;
      })
      .toBe(DROPPED_PATH);
    expect(
      await page.evaluate(
        () =>
          (window as unknown as { __switchMarker?: number }).__switchMarker
      )
    ).toBe(1);
    await telemetry.attachHistory(test.info());
  });

  test("section has no axe violations", async ({ page }, testInfo) => {
    await assertNoAxeViolations(page, testInfo, SECTION);
  });
});

test.describe("forced colours", () => {
  // The `forcedColors` context option leaves the media query unmatched in this
  // Playwright's Chromium; emulating the media feature on the page matches it.
  test.beforeEach(async ({ page }) => {
    await page.emulateMedia({ forcedColors: "active" });
    await gotoSection(page);
  });

  test("forced colours: knob offset differs on vs off, border survives", async ({
    page,
  }) => {
    expect(
      await page.evaluate(() => matchMedia("(forced-colors: active)").matches)
    ).toBe(true);

    const on = await geometry(page, STARTS_ON);
    const off = await geometry(page, STARTS_OFF);

    // The backgrounds no longer tell the states apart...
    expect(on.trackBackground).toBe(off.trackBackground);
    // ...so the knob's place in the track and the borders carry the state.
    expect(on.offset).not.toBeCloseTo(off.offset, 0);
    expect(off.offset).toBeCloseTo(KNOB_OFFSET_OFF, 1);
    expect(on.offset).toBeCloseTo(KNOB_OFFSET_ON, 1);
    for (const g of [on, off]) {
      expect(g.trackBorder).toEqual(Array(4).fill("solid 2px"));
      expect(g.knobBorder).toEqual(Array(4).fill("solid 1px"));
    }

    // The knob follows the value: the off switch, pressed, moves its knob to
    // the on place.
    const telemetry = new NopalTelemetry(page);
    await telemetry.events();
    await button(page, STARTS_OFF).click();
    await expectDispatches(
      page,
      telemetry,
      [toggled("Starts_off_toggled", true)],
      "a click on the off switch under forced colours"
    );
    await expect(button(page, STARTS_OFF)).toHaveAttribute(
      "aria-checked",
      "true"
    );
    expect((await geometry(page, STARTS_OFF)).offset).toBeCloseTo(
      KNOB_OFFSET_ON,
      1
    );
  });
});
