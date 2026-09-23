import { test, expect, type Page } from "@playwright/test";
import * as fs from "node:fs";
import * as path from "node:path";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// What a button inside a form dispatches, driven in a real browser cell by cell
// through the matrix in test/e2e/fixtures/button-submit-matrix.tsv.
//
// The structural suite reads the same file, so a line the two renderers answer
// differently fails one of the two builds. Each line is one case: the section
// is put in the line's cell by pressing its own selectors, the line's action is
// performed, and the section's whole ordered dispatch list is compared with the
// line. What was dispatched is read from the MVU telemetry log, the suite's
// correctness contract, because a doubled submit and a single one can leave the
// same text on screen.
//
// The DOM is read as a render gate only — a selector's `aria-pressed`, the
// save button's `aria-disabled` — plus the focus and axe facts, which no
// telemetry event carries.
//
// Headless rAF mitigations: navigate fresh with `goto` and never
// `page.reload()`; wait for the section before interacting.

const SECTION = '[data-testid="button-semantics-section"]';
const PREFIX = "ButtonSemantics:";

const byTestid = (suffix: string): string =>
  `${SECTION} [data-testid="button-semantics-${suffix}"]`;

const FORM = byTestid("form");
const SAVE_BUTTON = byTestid("save-button");

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

type Cell = {
  fieldSet: string;
  buttonState: string;
  action: string;
  expected: string[];
};

const MATRIX = path.join(
  __dirname,
  "..",
  "fixtures",
  "button-submit-matrix.tsv",
);
const HEADER = "field_set\tbutton_state\taction\texpected";
const ACTION = /^(click-button|enter-field)-[12]$/;

// Every line of the matrix that states a cell. Comment lines, the header and
// blank lines state none. A line that does not parse throws, so the file fails
// to load rather than silently stating fewer cells.
function readMatrix(): Cell[] {
  const cells = fs
    .readFileSync(MATRIX, "utf8")
    .split("\n")
    .filter((line) => line !== "" && line !== HEADER && !line.startsWith("#"))
    .map((line) => {
      const columns = line.split("\t");
      if (columns.length !== 4)
        throw new Error(`${line}: not four tab-separated columns`);
      const [fieldSet, buttonState, action, expected] = columns;
      if (!ACTION.test(action))
        throw new Error(`${line}: no such action ${JSON.stringify(action)}`);
      return {
        fieldSet,
        buttonState,
        action,
        expected: expected === "-" ? [] : expected.split(","),
      };
    });
  if (cells.length === 0) throw new Error(`${MATRIX} states no cell`);
  return cells;
}

// Two animation frames after an interaction, the render pass it could have
// invalidated has certainly run. The gate in front of every assertion that a
// message did NOT arrive: without it the absence would be satisfied by a message
// still in flight rather than by a message never sent.
async function settleFrames(page: Page): Promise<void> {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
      }),
  );
}

// Every message this section dispatched since the previous read, in order.
// Scoped by the section's own serializer prefix so another section's traffic
// cannot pad the list.
async function sectionMessages(telemetry: NopalTelemetry): Promise<string[]> {
  const events = await telemetry.events();
  return events.flatMap((e) =>
    e.kind === "message" && e.value.startsWith(PREFIX) ? [e.value] : [],
  );
}

// Puts the form in a cell by pressing the section's own selectors, waits for
// the frame that renders it, and drains the log. The selectors are asserted to
// have dispatched their two selections and nothing else, so a selector that
// submitted the form would fail here rather than pad the case after it.
async function selectCell(
  page: Page,
  telemetry: NopalTelemetry,
  fieldSet: string,
  buttonState: string,
): Promise<void> {
  const fields = byTestid(`fields-${fieldSet}`);
  const buttons = byTestid(`buttons-${buttonState}`);
  await page.locator(fields).click();
  await page.locator(buttons).click();
  await expect(page.locator(fields)).toHaveAttribute("aria-pressed", "true", {
    timeout: SETTLE,
  });
  await expect(page.locator(buttons)).toHaveAttribute("aria-pressed", "true", {
    timeout: SETTLE,
  });
  await settleFrames(page);
  expect(
    await sectionMessages(telemetry),
    "the selectors did not dispatch exactly their two selections",
  ).toEqual([
    `${PREFIX}fields=${fieldSet};`,
    `${PREFIX}buttons=${buttonState};`,
  ]);
}

// Whether the matrix's button-state cell leaves the given button index
// `aria-disabled` at click time. Only these two states ever put a disabled
// button on the page; every other state's buttons are enabled.
function isDisabledButton(buttonState: string, index: string): boolean {
  return (
    buttonState === "submit-disabled" ||
    (buttonState === "disabled-submit-before-enabled-submit" && index === "1")
  );
}

// A matrix action on the rendered cell. A click on a button the cell leaves
// `aria-disabled` is forced, because Playwright counts `aria-disabled` as not
// enabled and would wait for it — the browser still delivers the click, and
// whether it does anything is the case. An enabled button's click keeps
// Playwright's actionability checks (visible, stable, receives events), so a
// covered or hidden enabled button still fails the click.
async function perform(
  page: Page,
  buttonState: string,
  action: string,
): Promise<void> {
  const [kind, index] = [
    action.slice(0, action.lastIndexOf("-")),
    action.slice(action.lastIndexOf("-") + 1),
  ];
  switch (kind) {
    case "click-button":
      await page
        .locator(byTestid(`button-${index}`))
        .click({ force: isDisabledButton(buttonState, index) });
      return;
    case "enter-field":
      await page.locator(byTestid(`field-${index}`)).press("Enter");
      return;
    default:
      throw new Error(`no such action ${JSON.stringify(action)}`);
  }
}

// The whole ordered dispatch list since the last drain equals `tokens`. A
// non-empty list is waited for by its last token first; an empty one is
// asserted only after the frames the action could have scheduled have run.
async function expectDispatches(
  page: Page,
  telemetry: NopalTelemetry,
  tokens: string[],
  what: string,
): Promise<void> {
  const expected = tokens.map((token) => `${PREFIX}${token};`);
  const last = expected[expected.length - 1];
  // waitForNewMessage, not waitForMessage: the composite tests below repeat a
  // token (e.g. "S") across successive interactions on the same page without a
  // fresh navigation between them. waitForMessage matches anywhere in the
  // whole undrained bridge log, so it would resolve on a PRIOR interaction's
  // already-logged token instead of waiting for this one's.
  if (last !== undefined) await telemetry.waitForNewMessage(last, SETTLE);
  await settleFrames(page);
  expect(await sectionMessages(telemetry), what).toEqual(expected);
}

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    FORM,
    { timeout: 10000 },
  );
});

for (const cell of readMatrix()) {
  const expectedText =
    cell.expected.length === 0 ? "-" : cell.expected.join(",");
  test(`${cell.fieldSet} ${cell.buttonState} ${cell.action} ${expectedText}`, async ({
    page,
  }) => {
    const telemetry = new NopalTelemetry(page);
    await selectCell(page, telemetry, cell.fieldSet, cell.buttonState);
    await perform(page, cell.buttonState, cell.action);
    await expectDispatches(
      page,
      telemetry,
      cell.expected,
      `${cell.action} did not dispatch what the matrix states`,
    );
    await telemetry.attachHistory(test.info());
  });
}

test("a disabled Button in a Form submits on neither click nor Enter", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);
  // One text field: with no other submit button, an Enter there submits unless
  // the disabled button blocks it.
  await selectCell(page, telemetry, "text", "submit-disabled");

  await perform(page, "submit-disabled", "click-button-1");
  await expectDispatches(page, telemetry, [], "the disabled button's click");
  await perform(page, "submit-disabled", "enter-field-1");
  await expectDispatches(page, telemetry, [], "Enter with a disabled button");

  // The affirmative arm, on the same form: its enabled twin submits by both
  // routes.
  await selectCell(page, telemetry, "text", "submit-enabled");
  await perform(page, "submit-enabled", "click-button-1");
  await expectDispatches(page, telemetry, ["C1", "S"], "the enabled click");
  await perform(page, "submit-enabled", "enter-field-1");
  await expectDispatches(page, telemetry, ["C1", "S"], "Enter, enabled");
  await telemetry.attachHistory(test.info());
});

test("keyboard activation of a focused disabled button dispatches nothing", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);
  await selectCell(page, telemetry, "text", "submit-disabled");
  const button = page.locator(byTestid("button-1"));

  await button.press("Space");
  await expectDispatches(
    page,
    telemetry,
    [],
    "Space on the focused disabled button",
  );
  await button.press("Enter");
  await expectDispatches(
    page,
    telemetry,
    [],
    "Enter on the focused disabled button",
  );
  await telemetry.attachHistory(test.info());
});

test("a non-submit button does not submit", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await selectCell(page, telemetry, "text", "push-enabled");

  await perform(page, "push-enabled", "click-button-1");
  await expectDispatches(page, telemetry, ["C1"], "the push button's click");

  // The affirmative arm, on the same form: it submits, from its one field.
  await perform(page, "push-enabled", "enter-field-1");
  await expectDispatches(page, telemetry, ["S"], "Enter in the one field");
  await telemetry.attachHistory(test.info());
});

test("a multi-field form with no submit button ignores Enter", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);
  await selectCell(page, telemetry, "text-text", "none");

  await perform(page, "none", "enter-field-1");
  await expectDispatches(page, telemetry, [], "Enter in field 1");
  await perform(page, "none", "enter-field-2");
  await expectDispatches(page, telemetry, [], "Enter in field 2");

  // The affirmative arms, one per condition of the rule: the same two fields
  // with a submit button submit, and one field with no button submits.
  await selectCell(page, telemetry, "text-text", "submit-enabled");
  await perform(page, "submit-enabled", "enter-field-1");
  await expectDispatches(page, telemetry, ["C1", "S"], "two fields, a button");
  await selectCell(page, telemetry, "text", "none");
  await perform(page, "none", "enter-field-1");
  await expectDispatches(page, telemetry, ["S"], "one field, no button");
  await telemetry.attachHistory(test.info());
});

test("self-disabling submit button keeps focus", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  const button = page.locator(SAVE_BUTTON);
  // The node itself, so "still the same button" is identity, not a match on
  // attributes a re-created node would also carry.
  const node = await button.elementHandle({ timeout: SETTLE });
  await telemetry.events();

  await button.click();
  await expectDispatches(
    page,
    telemetry,
    ["save=C", "save=S"],
    "the idle save button's click",
  );
  await expect(button).toHaveAttribute("aria-disabled", "true", {
    timeout: SETTLE,
  });
  await settleFrames(page);
  expect(
    await page.evaluate(
      ([n, sel]) =>
        document.activeElement === n && document.querySelector(sel) === n,
      [node, SAVE_BUTTON] as const,
    ),
    "the button that disabled itself lost focus or was replaced",
  ).toBe(true);

  await button.click({ force: true });
  await expectDispatches(
    page,
    telemetry,
    [],
    "the pending save button's click",
  );
  expect(
    await page.evaluate((n) => document.activeElement === n, node),
    "the pending save button lost focus to its own click",
  ).toBe(true);
  await telemetry.attachHistory(test.info());
});

test("button semantics section has no axe violations", async ({
  page,
}, testInfo) => {
  await assertNoAxeViolations(page, testInfo, SECTION);

  // Again with disabled buttons on the page, in both forms, since a disabled
  // button is announced through attributes the enabled one does not carry.
  const telemetry = new NopalTelemetry(page);
  await selectCell(
    page,
    telemetry,
    "text-password",
    "disabled-submit-before-enabled-submit",
  );
  await page.locator(SAVE_BUTTON).click();
  await expect(page.locator(SAVE_BUTTON)).toHaveAttribute(
    "aria-disabled",
    "true",
    { timeout: SETTLE },
  );
  await assertNoAxeViolations(page, testInfo, SECTION);
});
