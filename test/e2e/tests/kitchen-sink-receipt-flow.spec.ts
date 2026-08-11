import { test, expect } from "@playwright/test";
import * as fs from "node:fs";
import * as path from "node:path";
import { NopalTelemetry } from "./nopal-telemetry";
import { assertNoAxeViolations } from "./axe";

// Receipt-flow E2E for the kitchen sink. This is the only place in the
// repository where a sharpness score is taken off real pixels: the unit suites
// feed the section a stub backend, and the image package's own suites run
// against a fake canvas under Node, so neither can tell an ordering contract
// from a constant. Here the fixtures go through the shipped browser canvas
// pipeline and the model is read back off the MVU telemetry bridge, which is
// this suite's primary correctness channel.
//
// Both directions are asserted on purpose. A metric replaced by a constant
// still satisfies exactly one of them — whichever one the constant happens to
// agree with — so a single arm would keep passing through the regression this
// spec exists to catch.
//
// Headless Chromium without a display server can stall requestAnimationFrame,
// which drives the model→DOM frame here. Mitigations, as in the sibling
// file-input spec: navigate fresh with `goto` and never `page.reload()`,
// `waitForFunction` before interacting, and gate every behavioural wait on the
// telemetry stream rather than on a fixed delay.

const SECTION = '[data-testid="receipt-flow-section"]';
// Anchored by the section's call-site `data-field`: the picker renders as an
// `<input>` like every text field on the page, and the file-input section
// carries a second file picker of its own, so a tag-shaped selector would
// resolve by document order into the wrong section.
const PICKER = `${SECTION} [data-field="receipt-photo"]`;
// The metadata readout. Telemetry owns the correctness contract, and a DOM
// assertion is reserved for render correctness — which is what this is: the
// dimensions the model holds become visible to a person only here, so nothing
// in the telemetry can say whether the readout agrees with them.
const METADATA = `${SECTION} [data-testid="receipt-flow-metadata"]`;
// Where the upload outcome is rendered. Same reservation as METADATA: the model
// says what happened, and this is the only surface on which a person sees it.
const UPLOAD_STATUS = `${SECTION} [data-testid="receipt-flow-upload"]`;
// The note field is a `Nopal_ui.TextInput`, which anchors itself by its
// configured id rather than by a call-site attribute.
const NOTE = `${SECTION} [data-field="receipt-note"]`;
// Rendered only while a measured photo is still the section's to decide about,
// and only on the accept side of the threshold — so finding it at all is part of
// what the upload test asserts.
const ACCEPT = `${SECTION} [data-field="receipt-accept"]`;
// The other verdict control, rendered under exactly the same conditions but on
// the re-shoot side of the threshold. A different element with a different
// label, so it is neither scanned nor clicked by anything that only ever drives
// the sharp fixture.
const RESHOOT = `${SECTION} [data-field="receipt-reshoot"]`;

const SHARP = path.join(__dirname, "fixtures", "receipt-sharp.jpg");
const BLURRED = path.join(__dirname, "fixtures", "receipt-blurred.jpg");
// A truncated copy of the sharp fixture: a genuine JPEG header with the scan
// data cut away, so what fails is the decode and not the file type.
const CORRUPT = path.join(__dirname, "fixtures", "receipt-corrupt.jpg");

// The section's own endpoint, deliberately not the one the file-input section
// posts to — both sections render on the same page, so an interception here must
// not catch the other's uploads. Intercepted and never reached: nothing in the
// repo serves it, so an unmatched pattern would surface as a network failure
// rather than as a silently unasserted request.
const UPLOAD_URL = "**/api/receipt-capture";

// Typed into the note field and expected back on the wire. Deliberately not a
// value the section could produce on its own, so a field carrying a default
// cannot pass for a field carrying what the user typed.
const NOTE_TEXT = "lunch with the desert ship crew";

// What the section stores for either fixture. Both are 1200x1600, and the
// section caps the stored long edge at 1400, so the pipeline scales by 1400/1600
// — a real resize rather than a no-op, which is what makes this pair the
// model's answer and not the fixture's own size. Deterministic integer
// arithmetic, unlike the score, so it is safe to pin exactly.
const STORED_WIDTH = 1050;
const STORED_HEIGHT = 1400;

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a display-server-less machine, and a 250 kB JPEG has to be
// decoded, scaled and re-encoded before the model moves at all.
const SETTLE = 20000;

// Playwright's per-test default is 30s, which is less than the budget above
// actually needs: every test here chains at least three `SETTLE`-bounded waits,
// and the upload tests chain four. Without this, a run that legitimately used
// the documented budget would die on the enclosing test timeout rather than on
// the wait it was in, reporting "test timeout exceeded" instead of naming the
// message or model fragment that never arrived — and that only ever happens on a
// loaded box, which is exactly when the diagnostic is worth having. Sized off
// `SETTLE` rather than written as a number so the two cannot drift apart, plus
// headroom for the navigation and the `setInputFiles` handoffs. Precedent:
// `storage.spec.ts`, which pays the same headless warm-up twice.
const CHAINED_WAITS = 4;
const TEST_TIMEOUT = CHAINED_WAITS * SETTLE + 30000;

// This section's own record inside the kitchen sink's single serialized model.
// The scoping matters: the sink serialises every section into one string, and
// two of them emit a field named `upload=` — this section and the file-input
// section above it — so a bare substring match is ambiguous for that field.
// `NopalTelemetry.assertRecordContains` owns the extraction; every fragment
// passed to it carries its trailing ';' so a match is bounded on both sides.
const RECORD = "receipt_flow";

// The comparison field, used as the gate between two photos in one test. It is
// emitted only once a previous score exists, which no first photo can produce,
// so waiting on it is what separates the second pass from the first —
// `waitForMessage("ReceiptProcessed:ok;")` cannot, since the first photo already
// recorded that message. See `NopalTelemetry.waitForModel`, which carries the
// measured evidence for that.
const COMPARISON = "sharper_than_previous=";

interface MultipartPart {
  headers: string;
  body: string;
}

// Split a multipart/form-data payload into its parts, keyed by the part's
// `name`. Hand-rolled rather than fed to a parser library, as in the sibling
// multipart spec: the point is to read exactly what Chromium wrote, and a
// tolerant parser that normalises headers would hide the details being pinned.
// The payload is read as latin1 so one byte is one character — the file part
// here is JPEG, and a utf8 decode would neither round-trip the bytes nor report
// their length.
function parseMultipart(
  raw: string,
  boundary: string
): Map<string, MultipartPart> {
  const parts = new Map<string, MultipartPart>();
  for (const chunk of raw.split(`--${boundary}`)) {
    const split = chunk.indexOf("\r\n\r\n");
    if (split === -1) continue; // preamble, epilogue, and the closing `--`
    const headers = chunk.slice(0, split).trim();
    const name = /name="([^"]*)"/.exec(headers)?.[1];
    if (name === undefined) continue;
    // A part body is terminated by the CRLF that precedes the next boundary
    // line; everything before it is payload.
    parts.set(name, {
      headers,
      body: chunk.slice(split + 4).replace(/\r\n$/, ""),
    });
  }
  return parts;
}

test.beforeEach(async ({ page }) => {
  // Applied here rather than repeated in each test: every test in this file
  // chains `SETTLE`-bounded waits, and the budget is the same for all of them.
  test.setTimeout(TEST_TIMEOUT);

  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    PICKER,
    { timeout: 10000 }
  );
});

test("sharp then blurred records not sharper", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  const picker = page.locator(PICKER);

  await picker.setInputFiles(SHARP);
  await telemetry.waitForMessage("ReceiptProcessed:ok;", SETTLE);

  // First slice: the sharp photo alone. Its dimensions are the affirmative arm
  // for the comparison below — without them, a `sharper_than_previous=` that
  // never appeared and one that appeared for a photo the pipeline never
  // processed would fail the same way.
  await telemetry.assertModelContains(`width=${STORED_WIDTH};`);
  await telemetry.assertModelContains(`height=${STORED_HEIGHT};`);

  // Render correctness: the readout shows the same dimensions the model holds.
  // The encoded byte size is deliberately left out — it is whatever Chromium's
  // JPEG encoder produced, which is not a stable value to pin.
  await expect(page.locator(METADATA)).toContainText(
    `${STORED_WIDTH} by ${STORED_HEIGHT} pixels`,
    { timeout: SETTLE }
  );

  // Attached here, before the second slice advances the cursor: the helper's
  // reads drain, so one attachment at the end would carry only the second
  // photo's events and silently omit the first's.
  await telemetry.attachHistory(test.info());

  await picker.setInputFiles(BLURRED);
  await telemetry.waitForModel(COMPARISON, SETTLE);

  // Second slice, taken after the interaction rather than before it. The helper
  // caches whatever `events()` last read, so advancing the cursor ahead of the
  // second photo would freeze an empty snapshot and every assertion below would
  // fail on it regardless of what the model did.
  await telemetry.events();

  // The comparison outcome, not the two scores it was reached from: float
  // rendering is not a stable assertion surface. The trailing ';' bounds the
  // match, so `=false;` cannot be satisfied by a value that merely starts the
  // same way.
  await telemetry.assertModelContains("sharper_than_previous=false;");

  await telemetry.attachHistory(test.info());
});

test("blurred then sharp records sharper", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  const picker = page.locator(PICKER);

  await picker.setInputFiles(BLURRED);
  await telemetry.waitForMessage("ReceiptProcessed:ok;", SETTLE);

  // Affirmative arm, as above: the blurred photo really did reach the pipeline
  // before the sharp one is offered for comparison against it.
  await telemetry.assertModelContains(`width=${STORED_WIDTH};`);
  await telemetry.assertModelContains(`height=${STORED_HEIGHT};`);

  await telemetry.attachHistory(test.info());

  await picker.setInputFiles(SHARP);
  await telemetry.waitForModel(COMPARISON, SETTLE);

  await telemetry.events();

  // The mutation-resistant arm. The sibling test asserts the opposite value
  // through the same code path, so a metric that answers a constant fails one
  // of the two whichever constant it answers.
  await telemetry.assertModelContains("sharper_than_previous=true;");

  await telemetry.attachHistory(test.info());
});

test("corrupt image surfaces decode failure", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(PICKER).setInputFiles(CORRUPT);
  await telemetry.waitForMessage("ReceiptProcessed:error;", SETTLE);

  // The stage that failed, under its own tag. `failed:` alone would be
  // satisfied by any of the five failure kinds, and a missing blob handle and an
  // undecodable file have different remedies — this is the assertion that says
  // which one a real browser produced from a real truncated JPEG.
  await telemetry.assertRecordContains(
    RECORD,
    "processing=failed:decode_failed;"
  );

  // Render correctness, and the affirmative arm for the tag above: the platform
  // writes the reason and the readout is the only place a person sees it, so a
  // section that recorded the right tag and told nobody would still be wrong.
  // The reason text itself is Chromium's wording, not this repo's, so it is not
  // pinned.
  await expect(page.locator(METADATA)).toContainText("Processing failed:", {
    timeout: SETTLE,
  });

  await telemetry.attachHistory(test.info());
});

test("accept uploads the processed blob and the text field", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  // Collected into an array rather than into `let`s the route callback assigns:
  // TypeScript's control-flow analysis does not track assignments made inside a
  // nested function, so a `let x: Buffer | null = null` stays narrowed to `null`
  // at the assertions below.
  const captured: { contentType: string | null; payload: Buffer | null }[] = [];

  await page.route(UPLOAD_URL, async (route) => {
    const request = route.request();
    captured.push({
      contentType: await request.headerValue("content-type"),
      payload: request.postDataBuffer(),
    });
    await route.fulfill({
      status: 201,
      contentType: "text/plain",
      body: "stored",
    });
  });

  await page.locator(PICKER).setInputFiles(SHARP);
  await telemetry.waitForMessage("ReceiptProcessed:ok;", SETTLE);

  await page.locator(NOTE).fill(NOTE_TEXT);
  await telemetry.waitForMessage("ReceiptNoteChanged;", SETTLE);

  // Finding this control is itself part of the contract: it is rendered only
  // for a photo that cleared the threshold, so a click that lands proves the
  // sharp fixture was measured and accepted rather than merely processed.
  await page.locator(ACCEPT).click();
  await telemetry.waitForMessage("ReceiptUploadFinished:ok:201;", SETTLE);

  expect(captured).toHaveLength(1);
  const { contentType, payload } = captured[0];

  // No `Content-Type` is set by the backend precisely so the user agent can
  // generate one — a hand-written header would carry a boundary that does not
  // match the encoded body. Asserting the boundary is present is what proves
  // the generation happened.
  expect(contentType).toMatch(/^multipart\/form-data; boundary=.+$/);
  const boundary = /boundary=(.+)$/.exec(contentType!)![1];

  expect(payload).not.toBeNull();
  const parts = parseMultipart(payload!.toString("latin1"), boundary);

  // Exactly the two parts the section builds, in the order it builds them. An
  // extra or a missing part is as wrong as a malformed one.
  expect([...parts.keys()]).toEqual(["note", "receipt"]);

  expect(parts.get("note")!.body).toBe(NOTE_TEXT);

  const file = parts.get("receipt")!;
  // Filename and MIME are per-part overrides the section declares off its own
  // encode format, describing the bytes it produced rather than the ones the
  // user picked. Both have to survive into the part's own headers.
  expect(file.headers).toMatch(/filename="receipt\.jpg"/);
  expect(file.headers).toMatch(/Content-Type:\s*image\/jpeg/i);

  // The bytes are a JPEG the pipeline encoded, not a stringified handle and not
  // an empty part: SOI at the front, EOI at the back.
  expect(file.body.slice(0, 3)).toBe("\xff\xd8\xff");
  expect(file.body.slice(-2)).toBe("\xff\xd9");

  // The processed handle, not the selected one. Two independent statements of
  // it: the payload is not the file on disk, and its length is exactly the
  // encoded size the model recorded for the processing pass. The encoder's
  // output size is Chromium's number, so it is read out of the model rather
  // than written here.
  await telemetry.assertRecordContains(RECORD, `byte_size=${file.body.length};`);
  expect(file.body.length).not.toBe(fs.statSync(SHARP).size);

  // Where the upload ended up, scoped to this section's record — the file-input
  // section emits a field of the same name into the same model string.
  await telemetry.assertRecordContains(RECORD, "upload=ok:201;");

  // Render correctness: the outcome is something the person looking at the
  // section can see, not only something the telemetry records.
  await expect(page.locator(UPLOAD_STATUS)).toHaveText("Uploaded (HTTP 201)", {
    timeout: SETTLE,
  });

  await telemetry.events();
  await telemetry.attachHistory(test.info());
});

test("a refused receipt is reported as a rejection", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  // The reply is written here rather than left to the server, as in the accept
  // test above: nothing in the repo serves this endpoint, so the status the
  // section reasons about is the one this route decides to answer with.
  await page.route(UPLOAD_URL, async (route) => {
    await route.fulfill({
      status: 404,
      contentType: "text/plain",
      body: "no such receipt book",
    });
  });

  await page.locator(PICKER).setInputFiles(SHARP);
  await telemetry.waitForMessage("ReceiptProcessed:ok;", SETTLE);

  await page.locator(ACCEPT).click();
  await telemetry.waitForMessage("ReceiptUploadFinished:rejected:404;", SETTLE);

  // A request that completed and a receipt that was stored are different claims.
  // This is the one place a real browser says so: the section tags a non-2xx
  // reply as a refusal rather than folding it in with the successes, which is
  // exactly where its `upload=` vocabulary is wider than the file-input
  // section's — that one would serialise this same reply as `upload=ok:404;`.
  // Scoped to this section's record for that very reason.
  await telemetry.assertRecordContains(RECORD, "upload=rejected:404;");

  // Render correctness: a refusal is something the person looking at the section
  // can see, and it reads differently from a success rather than merely carrying
  // a different number.
  await expect(page.locator(UPLOAD_STATUS)).toHaveText(
    "The server refused this receipt (HTTP 404)",
    { timeout: SETTLE }
  );

  await telemetry.attachHistory(test.info());
});

test("re-shooting keeps the comparison against the discarded photo", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);
  const picker = page.locator(PICKER);

  await picker.setInputFiles(BLURRED);
  await telemetry.waitForMessage("ReceiptProcessed:ok;", SETTLE);

  // Finding this control is part of the contract, as ACCEPT is in the upload
  // test: it is offered only for a measured photo that fell short of the
  // threshold, so a click that lands proves the blurred fixture was measured and
  // refused rather than merely processed.
  await page.locator(RESHOOT).click();
  await telemetry.waitForMessage("ReceiptReshootClicked;", SETTLE);

  // The photo really is gone from the section — the affirmative half of the
  // claim below, which is about what survives it.
  await expect(page.locator(METADATA)).toContainText("No receipt selected", {
    timeout: SETTLE,
  });

  await telemetry.attachHistory(test.info());

  await picker.setInputFiles(SHARP);
  await telemetry.waitForModel(COMPARISON, SETTLE);

  // Second slice, taken after the interaction: the helper caches whatever
  // `events()` last read, so advancing the cursor ahead of the second photo
  // would freeze an empty snapshot.
  await telemetry.events();

  // What the re-shoot is for. The discarded photo's score is the only thing the
  // replacement can be measured against, so a re-shoot that dropped it would
  // leave this fragment absent — and a re-shoot that kept the wrong one would
  // report `false`, since the blurred photo it replaced is the one the sharp
  // photo beats.
  await telemetry.assertRecordContains(RECORD, "sharper_than_previous=true;");

  await telemetry.attachHistory(test.info());
});

test("receipt section has no axe violations", async ({ page }, testInfo) => {
  // The idle section: the picker has no `<label for>` of its own, so its
  // accessible name comes from the call-site `aria-label`, and axe's `label`
  // rule (wcag2a) fails an `<input type="file">` that has none.
  await assertNoAxeViolations(page, testInfo, SECTION);

  const telemetry = new NopalTelemetry(page);
  await page.locator(PICKER).setInputFiles(SHARP);
  await telemetry.waitForMessage("ReceiptProcessed:ok;", SETTLE);

  // The measured section. Scanned separately because the metadata readout, the
  // calibration note and the accept control do not exist until a photo has been
  // through the pipeline — an idle-only scan would assert almost none of what
  // this section renders.
  await assertNoAxeViolations(page, testInfo, SECTION);

  // The re-shoot side of the verdict. The scan above reaches only one of the two
  // controls the section can offer, and they are different elements with
  // different labels, so a re-shoot control that named itself badly would never
  // have been scanned at all. Gated on the comparison fragment rather than on
  // `ReceiptProcessed:ok;`, which the sharp photo above has already recorded.
  await page.locator(PICKER).setInputFiles(BLURRED);
  await telemetry.waitForModel(COMPARISON, SETTLE);

  // The affirmative arm for the scan below: a zero-violation result over a tree
  // that never contained the control would be vacuous.
  await expect(page.locator(RESHOOT)).toBeVisible({ timeout: SETTLE });
  await assertNoAxeViolations(page, testInfo, SECTION);
});
