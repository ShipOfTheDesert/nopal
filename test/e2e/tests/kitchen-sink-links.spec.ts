import { test, expect, type Page } from "@playwright/test";
import { NopalTelemetry, type TelemetryEvent } from "./nopal-telemetry";

// Real clicks and keys on the links section's two anchors. Whether a click was
// followed in-app is read from the MVU telemetry log, as the whole ordered list
// of the section's messages, so a click that dispatched twice fails as surely
// as one that dispatched nothing. A click left to the browser is shown by the
// page the browser opened for it, on the same fixture as the empty list.

const SECTION = '[data-testid="links-section"]';
const ROUTE_LINK = `${SECTION} [data-testid="links-route-link"]`;
const EXTERNAL_LINK = `${SECTION} [data-testid="links-external-link"]`;
const CURRENT_ROUTE = `${SECTION} [data-testid="links-current-route"]`;
const PREFIX = "Links:";
const FOLLOWED = `${PREFIX}Followed:Target;`;
const START_PATH = "/kitchen_sink/";
const TARGET_PATH = "/kitchen_sink/?links=target";

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

// Two animation frames after the interaction, a dispatch it caused would have
// been recorded. The gate in front of every "exactly these messages" check.
async function settleFrames(page: Page): Promise<void> {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
      }),
  );
}

function sectionMessages(events: TelemetryEvent[]): string[] {
  return events.flatMap((e) =>
    e.kind === "message" && e.value.startsWith(PREFIX) ? [e.value] : [],
  );
}

function pathOf(page: Page): string {
  const url = new URL(page.url());
  return url.pathname + url.search;
}

// A value on `window` is lost by any page load, so its survival shows the
// click was followed without one.
async function setMarker(page: Page): Promise<void> {
  await page.evaluate(() => {
    (window as unknown as { __linkMarker: number }).__linkMarker = 1;
  });
}

async function readMarker(page: Page): Promise<unknown> {
  return page.evaluate(
    () => (window as unknown as { __linkMarker?: number }).__linkMarker,
  );
}

// A click the browser keeps opens the route in a new page, and the original
// page dispatches nothing and stays where it was.
async function expectLeftToBrowser(
  page: Page,
  click: () => Promise<void>,
): Promise<void> {
  const telemetry = new NopalTelemetry(page);
  await telemetry.events();
  const opened = page.context().waitForEvent("page", { timeout: SETTLE });

  await click();
  const newPage = await opened;
  await newPage.waitForURL(new URL(TARGET_PATH, page.url()).href, {
    timeout: SETTLE,
  });
  await settleFrames(page);

  expect(
    sectionMessages(await telemetry.events()),
    "a message was dispatched",
  ).toEqual([]);
  expect(pathOf(page)).toEqual(START_PATH);
  await expect(page.locator(CURRENT_ROUTE)).toHaveAttribute(
    "data-route",
    "start",
  );
}

test.describe("links section", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(START_PATH, { waitUntil: "load" });
    await page.waitForFunction(
      (sel) => document.querySelector(sel) !== null,
      ROUTE_LINK,
      { timeout: 10000 },
    );
  });

  test("a plain click on the route link follows it without a page load", async ({
    page,
  }) => {
    const telemetry = new NopalTelemetry(page);
    await telemetry.events();
    expect(pathOf(page)).toEqual(START_PATH);
    await setMarker(page);

    await page.locator(ROUTE_LINK).click();
    await telemetry.waitForNewMessage(FOLLOWED, SETTLE);
    await settleFrames(page);

    expect(sectionMessages(await telemetry.events())).toEqual([FOLLOWED]);
    expect(pathOf(page)).toEqual(TARGET_PATH);
    expect(await readMarker(page), "the page was reloaded").toBe(1);
    await expect(page.locator(CURRENT_ROUTE)).toHaveAttribute(
      "data-route",
      "target",
      { timeout: SETTLE },
    );
  });

  test("the external link carries its URL and cannot reach back to the page", async ({
    page,
  }) => {
    const link = page.locator(EXTERNAL_LINK);
    expect(await link.evaluate((el) => el.tagName)).toEqual("A");
    expect(await link.getAttribute("href")).toEqual("https://ocaml.org/");
    expect(await link.getAttribute("rel")).toEqual("noopener noreferrer");
  });

  test("Tab reaches the route link and Enter follows it", async ({ page }) => {
    const telemetry = new NopalTelemetry(page);
    await telemetry.events();
    // A click on the section's text, which takes no focus itself, sets where
    // the browser's next Tab starts, so the anchor is reached by Tab alone.
    await page
      .locator(SECTION)
      .getByText("A link to a route of this page")
      .click();

    await page.keyboard.press("Tab");
    await expect(page.locator(ROUTE_LINK)).toBeFocused();

    await page.keyboard.press("Enter");
    await telemetry.waitForNewMessage(FOLLOWED, SETTLE);
    await settleFrames(page);

    expect(sectionMessages(await telemetry.events())).toEqual([FOLLOWED]);
    expect(pathOf(page)).toEqual(TARGET_PATH);
  });
});
