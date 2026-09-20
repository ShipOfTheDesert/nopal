import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { assertNoAxeViolations } from "./axe";

const SECTION = '[data-testid="text-input-section"]';
const INPUT_DEFAULT = '[data-testid="text-input-default"]';
const INPUT_PLACEHOLDER = '[data-testid="text-input-placeholder"]';
const INPUT_ERROR = '[data-testid="text-input-error"]';
const INPUT_DISABLED = '[data-testid="text-input-disabled"]';

// The restyled input is the same TextInput component with three overrides
// applied — the label's weight, the label-to-box gap and the error slot's
// colour, i.e. exactly the three things a downstream consumer forked the
// component for. RESTYLED is the wrapper the section puts around it so axe can
// be scoped to it alone; the ids below are what the component derives from the
// label "Delivery note" with no explicit id.
const RESTYLED = '[data-testid="text-input-restyled"]';
const RESTYLED_INPUT = '[data-testid="text-input-restyled-input"]';
const RESTYLED_ID = "delivery-note";
const RESTYLED_LABEL_ID = "delivery-note-label";

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    INPUT_DEFAULT,
    { timeout: 10000 }
  );
});

test("renders all states", async ({ page }) => {
  await expect(page.locator(INPUT_DEFAULT)).toBeVisible();
  await expect(page.locator(INPUT_PLACEHOLDER)).toBeVisible();
  await expect(page.locator(INPUT_ERROR)).toBeVisible();
  await expect(page.locator(INPUT_DISABLED)).toBeVisible();
});

test("typing updates value", async ({ page }) => {
  const input = page.locator(INPUT_DEFAULT);
  await input.fill("hello nopal");
  await expect(input).toHaveValue("hello nopal");
});

test("error message displayed", async ({ page }) => {
  // Named by the error slot's own id rather than by `[role="alert"]` within the
  // section: the section now holds two inputs with an error, so the role alone
  // no longer identifies one. The id is what `aria-describedby` points at.
  const errorAlert = page.locator(`${SECTION} #with-error-error`);
  await expect(errorAlert).toHaveAttribute("role", "alert");
  await expect(errorAlert).toBeVisible();
  await expect(errorAlert).toContainText("This field is required");
});

test("submitting dispatches on enter", async ({ page }) => {
  const input = page.locator(INPUT_DEFAULT);
  await input.fill("submit me");
  await input.press("Enter");
  // After submit, the input should still contain the value (no reset in this demo)
  await expect(input).toHaveValue("submit me");
});

test("axe-core zero violations", async ({ page }) => {
  const results = await new AxeBuilder({ page })
    .include(SECTION)
    .analyze();
  expect(results.violations).toEqual([]);
});

test("restyled text input keeps the component", async ({ page }) => {
  const input = page.locator(RESTYLED_INPUT);
  await expect(input).toBeVisible();

  // The component's own naming, unchanged by the restyle: one accessible name,
  // and it is the visible label. Both arms matter — the absent `aria-label`
  // alone would also "pass" on an input that was never found.
  await expect(input).toHaveAttribute("aria-labelledby", RESTYLED_LABEL_ID);
  await expect(input).toHaveAttribute("id", RESTYLED_ID);
  await expect(input).not.toHaveAttribute("aria-label", /.*/);

  // The E2E selector contract is undisturbed: `data-field` still carries the
  // control's own identifier.
  await expect(input).toHaveAttribute("data-field", RESTYLED_ID);

  const label = page.locator(`#${RESTYLED_LABEL_ID}`);
  await expect(label).toHaveText("Delivery note");

  // The three overrides reached the browser. Non-default values, so a knob that
  // compiled without being wired would leave these at the inherited defaults.
  await expect(label).toHaveCSS("font-weight", "600");
  await expect(page.locator(`${RESTYLED} [role="alert"]`)).toHaveCSS(
    "color",
    "rgb(179, 38, 30)"
  );
  const gap = await page.locator(RESTYLED).evaluate((el) => {
    const column = el.firstElementChild;
    if (column === null) return "no-column";
    return window.getComputedStyle(column).rowGap;
  });
  expect(gap).toBe("28px");
});

test("label click focuses the input", async ({ page }) => {
  const input = page.locator(RESTYLED_INPUT);
  await expect(input).toBeVisible();

  await page.locator(`#${RESTYLED_LABEL_ID}`).click();

  // The label box is not focusable, so a pointer-down on it moves no focus by
  // itself: this can only be true if the dispatched message reached `update`
  // and `update` answered with `Cmd.focus (TextInput.control_id config)`.
  //
  // `toBeFocused` is the auto-retrying form of `document.activeElement === el`,
  // and the retry is load-bearing rather than slack: the web backend queues a
  // focus request during dispatch and drains it in the rAF loop, so the input
  // is still `BODY`'s successor for one frame after the click returns. Measured
  // on 2026-09-20 — reading `document.activeElement` immediately gives `BODY`
  // and reading it 500ms later gives the input.
  await expect(input).toBeFocused();

  // Stated once without the matcher's help, so the case says what it means by
  // focused rather than delegating the whole claim to a matcher name.
  const focusedId = await page.evaluate(() =>
    document.activeElement === null ? "none" : document.activeElement.id
  );
  expect(focusedId).toBe(RESTYLED_ID);
});

test("restyled text input is axe-clean", async ({ page }, testInfo) => {
  await assertNoAxeViolations(page, testInfo, RESTYLED);
});
