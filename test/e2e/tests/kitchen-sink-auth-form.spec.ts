import { test, expect, type Page } from "@playwright/test";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// The kitchen sink's auth-shaped form, driven in a real browser.
//
// How many times the form submitted is asserted on the MVU telemetry log — the
// ordered list of messages the section dispatched — because that is this
// suite's correctness contract, and because "exactly once" is a claim about
// dispatches that no rendered counter can make: a double dispatch and a single
// one can leave the same text on screen for a frame. Every case enumerates the
// section's whole dispatch list over the interaction rather than looking for a
// message, so a doubled submit and a dropped one both redden it.
//
// The DOM is read in two places only. The landmark and the axe scan are
// accessibility facts with no telemetry event to carry them. The `novalidate`
// attribute is read as a render gate, not as an assertion: the model flipping
// the flag and the next frame writing it onto the form are two steps apart, and
// a click between them would submit the form it had before.
//
// Headless rAF mitigations: navigate fresh with `goto` and never
// `page.reload()`; wait for the section before interacting.

const SECTION = '[data-testid="auth-form-section"]';
const FORM = `${SECTION} [data-testid="auth-form"]`;
const EMAIL = `${SECTION} [data-testid="auth-email"]`;
const PASSWORD = `${SECTION} [data-testid="auth-password"]`;
const CODE = `${SECTION} [data-testid="auth-code"]`;
const SUBMIT = `${SECTION} [data-testid="auth-submit"]`;
const NOVALIDATE = `${SECTION} [data-testid="auth-novalidate"]`;
// The record this section contributes to the page's single serialized model.
const RECORD = "auth_form";
// The name the form's `aria-label` gives it, which is what makes it a landmark.
const FORM_NAME = "Demo sign-in";

const VALID_EMAIL = "ada@example.com";
const VALID_PASSWORD = "hunter22";

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a machine with no display server.
const SETTLE = 15000;

// Two animation frames after an interaction, the render pass it could have
// invalidated has certainly run. The gate in front of every assertion that a
// message did NOT arrive: without it the absence would be satisfied by a message
// still in flight rather than by a message never sent.
async function settleFrames(page: Page): Promise<void> {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
      })
  );
}

// Every message this section dispatched since the previous read, in order.
// Scoped by the section's own serializer prefix so another section's traffic
// cannot pad the list.
async function sectionMessages(telemetry: NopalTelemetry): Promise<string[]> {
  const events = await telemetry.events();
  return events.flatMap((e) =>
    e.kind === "message" && e.value.startsWith("AuthForm:") ? [e.value] : []
  );
}

// Both required fields filled with values the browser's own validation accepts,
// each waited for in the model, then the log drained so the next read holds only
// what the caller does after this. A form whose required fields are satisfied is
// the fixture on which a missing submission can only mean the submission was
// suppressed — not that validation stopped it.
async function fillCredentials(
  page: Page,
  telemetry: NopalTelemetry
): Promise<void> {
  await page.locator(EMAIL).fill(VALID_EMAIL);
  await telemetry.waitForModel(`auth_email="${VALID_EMAIL}";`, SETTLE);
  await page.locator(PASSWORD).fill(VALID_PASSWORD);
  await telemetry.waitForModel(
    `auth_password_length=${VALID_PASSWORD.length};`,
    SETTLE
  );
  await telemetry.events();
}

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    FORM,
    { timeout: 10000 }
  );
});

test("submits once on Enter from either field", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  await fillCredentials(page, telemetry);

  await page.locator(EMAIL).press("Enter");
  await telemetry.waitForModel("auth_submits=1;", SETTLE);
  await settleFrames(page);
  expect(
    await sectionMessages(telemetry),
    "Enter in the email field did not submit the form exactly once"
  ).toEqual(["AuthForm:Submitted;"]);

  await page.locator(PASSWORD).press("Enter");
  await telemetry.waitForModel("auth_submits=2;", SETTLE);
  await settleFrames(page);
  expect(
    await sectionMessages(telemetry),
    "Enter in the password field did not submit the form exactly once"
  ).toEqual(["AuthForm:Submitted;"]);

  await telemetry.assertRecordContains(
    RECORD,
    "auth_code_confirms=0; auth_submits=2;"
  );
  await telemetry.attachHistory(test.info());
});

test("submits once on button click and does not navigate", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  // The navigation guard, installed after the page's own load so it counts only
  // what the submit causes. A form's platform submission navigates the main
  // frame — to the same path with a query appended, for a form with no action —
  // and that commit is what this listener sees.
  let navigations = 0;
  page.on("framenavigated", (frame) => {
    if (frame === page.mainFrame()) navigations += 1;
  });
  const urlBefore = page.url();

  await fillCredentials(page, telemetry);

  await page.locator(SUBMIT).click();
  await telemetry.waitForModel("auth_submits=1;", SETTLE);
  await settleFrames(page);

  // The button carries no message of its own, so the one dispatch is the form's.
  expect(
    await sectionMessages(telemetry),
    "the click did not submit the form exactly once"
  ).toEqual(["AuthForm:Submitted;"]);
  expect(page.url(), "the submission changed the page's URL").toBe(urlBefore);
  expect(navigations, "the submission navigated the page").toBe(0);

  // A reload would have rebuilt the model from `init`; the values typed before
  // the click surviving it is the model-side half of the same guard.
  await telemetry.assertRecordContains(
    RECORD,
    `auth_email="${VALID_EMAIL}"; auth_password_length=${VALID_PASSWORD.length}; ` +
      "auth_code_confirms=0; auth_submits=1;"
  );
  await telemetry.attachHistory(test.info());
});

test("required blocks submission, novalidate allows it", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  // Both required fields left empty, validation on: the page's initial state.
  await telemetry.events();

  await page.locator(SUBMIT).click();
  await page.locator(EMAIL).press("Enter");
  await settleFrames(page);
  expect(
    await sectionMessages(telemetry),
    "an empty required field did not block the submission"
  ).toEqual([]);

  // The affirmative arm, on the same empty fields: with validation skipped, the
  // same submit goes through. Without it, the absence above would stay green on
  // a form that could not submit at all.
  await page.locator(NOVALIDATE).click();
  await telemetry.waitForModel("auth_novalidate=true;", SETTLE);
  await expect(page.locator(FORM)).toHaveAttribute("novalidate", "", {
    timeout: SETTLE,
  });
  await telemetry.events();

  await page.locator(SUBMIT).click();
  await telemetry.waitForModel("auth_submits=1;", SETTLE);
  await settleFrames(page);
  expect(
    await sectionMessages(telemetry),
    "with novalidate the empty form did not submit exactly once"
  ).toEqual(["AuthForm:Submitted;"]);

  await telemetry.assertRecordContains(
    RECORD,
    'auth_email=""; auth_password_length=0; auth_code_confirms=0; ' +
      "auth_submits=1; auth_novalidate=true;"
  );
  await telemetry.attachHistory(test.info());
});

test("a consuming on_keydown suppresses the form submit", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  // Filled, so the form is one Enter away from submitting: a submission that
  // does not happen from the code field is the field's doing, not validation's.
  await fillCredentials(page, telemetry);

  await page.locator(CODE).press("Enter");
  await telemetry.waitForModel("auth_code_confirms=1;", SETTLE);
  await settleFrames(page);
  expect(
    await sectionMessages(telemetry),
    "the code field's Enter went on to submit the form"
  ).toEqual(["AuthForm:Code_confirmed;"]);

  // The affirmative arm, on the same filled form: Enter in a field that does
  // not answer it submits.
  await page.locator(EMAIL).press("Enter");
  await telemetry.waitForModel("auth_submits=1;", SETTLE);
  await settleFrames(page);
  expect(
    await sectionMessages(telemetry),
    "Enter in the email field did not submit the form exactly once"
  ).toEqual(["AuthForm:Submitted;"]);

  await telemetry.assertRecordContains(
    RECORD,
    "auth_code_confirms=1; auth_submits=1;"
  );
  await telemetry.attachHistory(test.info());
});

test("the form is a landmark and axe reports no violations", async ({
  page,
}, testInfo) => {
  const landmark = page.getByRole("form", { name: FORM_NAME });
  await expect(landmark).toHaveCount(1);
  await expect(landmark).toHaveAttribute("data-testid", "auth-form");

  await assertNoAxeViolations(page, testInfo, SECTION);
});
