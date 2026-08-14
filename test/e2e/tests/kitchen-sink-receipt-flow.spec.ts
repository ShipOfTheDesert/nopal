import { test, expect, type Page } from "@playwright/test";
import * as fs from "node:fs";
import * as path from "node:path";
import { NopalTelemetry, recordSlice } from "./nopal-telemetry";
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
// The before/after pair, and each half of it. `Element.image` carries no
// per-element attributes, so the section hangs the anchor on the wrapper around
// each picture and the `<img>` is selected through it. Rendered only once both
// object URLs have arrived, so finding either half at all is part of what the
// preview tests assert.
const ORIGINAL_HALF = `${SECTION} [data-testid="receipt-flow-preview-original"]`;
const PROCESSED_HALF = `${SECTION} [data-testid="receipt-flow-preview-processed"]`;
const ORIGINAL_IMG = `${ORIGINAL_HALF} img`;
const PROCESSED_IMG = `${PROCESSED_HALF} img`;
// The headings. Read inside their own half rather than against the section:
// "Original" is a short enough word that a section-wide match would be
// satisfied by copy belonging to something else, and the whole content of the
// pair is which picture is which.
const ORIGINAL_LABEL = "Original";
const PROCESSED_LABEL = "As uploaded";

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
//
// Raised from four with the preview tests. The longest `SETTLE`-bounded chain
// is still four — the axe-with-previews test waits on the message, the model
// and each of the two images — but those tests put work inside the same budget
// that the old figure did not account for: an axe scan of a section that now
// carries two decoded photographs, and, in the re-selection loop, three
// complete decode/scale/encode passes rather than one. The extra `SETTLE` is
// headroom for that, so a slow box still fails on the wait it is in rather than
// on the enclosing test timeout.
const CHAINED_WAITS = 5;
const TEST_TIMEOUT = CHAINED_WAITS * SETTLE + 30000;

// This section's own record inside the kitchen sink's single serialized model.
// The scoping matters: the sink serialises every section into one string, and
// two of them emit a field named `upload=` — this section and the file-input
// section above it — so a bare substring match is ambiguous for that field.
// `NopalTelemetry.assertRecordContains` owns the extraction; every fragment
// passed to it carries its trailing ';' so a match is bounded on the right.
// The left is bounded by nothing, which matters for exactly one field in this
// record: `original_byte_size=` ends in `byte_size=`, so a fragment naming the
// processed length is satisfiable by the picked photo's fragment whenever the
// two lengths coincide. Assertions on `byte_size=` therefore go through
// `recordInt` below, which anchors; every other field name here is a suffix of
// no other, so `assertRecordContains` stays correct for them.
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

// One half of the rendered pair as the browser's own decoder describes it.
// `naturalWidth`/`naturalHeight` are the intrinsic size found inside the
// encoded bytes, untouched by the fixed CSS width the section draws at, so they
// are the one place in this repo where the processed image is measured rather
// than described.
interface DecodedPreview {
  src: string;
  width: number;
  height: number;
}

// Wait until both halves of the pair are on screen carrying object URLs the
// browser has actually decoded, then read them.
//
// `naturalWidth > 0` is the load-bearing clause. A canvas that encoded nothing —
// a black frame, a zero-byte re-encode, a handle pointing at the wrong blob —
// still yields a perfectly valid `blob:` URL and still renders as an `<img>`; it
// is only the decoder producing pixels that says the bytes leaving the device
// are a picture. That is the failure this whole feature exists to make visible,
// so it is the one the gate is written against.
//
// `stale` excludes URLs a previous selection minted. A re-selection unmounts the
// pair and mounts a new one, so without it a wait entered while the previous
// pair is still on screen resolves immediately on the photograph it is meant to
// be replacing. Every selection mints its own URLs, so "not one of these" is a
// signal only the current selection can produce — which is what `waitForModel`
// cannot be here, since `previews=ready;` is byte-identical on every selection
// and the log it reads is never drained.
async function waitForDecodedPair(
  page: Page,
  stale: string[]
): Promise<{ original: DecodedPreview; processed: DecodedPreview }> {
  await page.waitForFunction(
    ([originalSel, processedSel, seen]: [string, string, string[]]) => {
      const decoded = (sel: string): boolean => {
        const img = document.querySelector(sel) as HTMLImageElement | null;
        if (img === null) return false;
        return (
          img.src.startsWith("blob:") &&
          img.naturalWidth > 0 &&
          !seen.includes(img.src)
        );
      };
      return decoded(originalSel) && decoded(processedSel);
    },
    [ORIGINAL_IMG, PROCESSED_IMG, stale] as [string, string, string[]],
    { timeout: SETTLE }
  );

  const pair = await page.evaluate(
    ([originalSel, processedSel]: [string, string]) => {
      const read = (sel: string) => {
        const img = document.querySelector(sel) as HTMLImageElement | null;
        if (img === null) return null;
        return {
          src: img.src,
          width: img.naturalWidth,
          height: img.naturalHeight,
        };
      };
      return { original: read(originalSel), processed: read(processedSel) };
    },
    [ORIGINAL_IMG, PROCESSED_IMG] as [string, string]
  );

  // Not defensive: a selection landing between the wait and the read unmounts
  // the pair, and a helper that returned zeroes for that would make every
  // dimension assertion below fail on a number rather than on what happened.
  if (pair.original === null || pair.processed === null)
    throw new Error(
      "the preview pair left the page between the decode gate and the read"
    );
  return { original: pair.original, processed: pair.processed };
}

// One integer field out of a serialized record. Anchored on both sides — a field
// is preceded by the start of the record or by the space that separates it from
// the previous one, and terminated by its own ';'. The left anchor is the whole
// point: `original_byte_size=` ends in `byte_size=`, so an unanchored search for
// the processed length finds the picked photo's fragment and reports it as the
// processed one, which is exactly the reading this test exists to disprove.
function recordInt(record: string, field: string): number {
  const match = new RegExp(`(?:^|\\s)${field}=(\\d+);`).exec(record);
  if (match === null)
    throw new Error(`no ${field}=<integer>; fragment in record: ${record}`);
  return Number(match[1]);
}

// The most recent serialized record under `name`. Read off the drained slice
// rather than through `assertRecordContains`, which answers from the whole log
// and per fragment: the two lengths below are compared against each other, so
// they have to be read out of one model state rather than out of two that
// happened to satisfy one fragment each.
async function latestRecord(
  telemetry: NopalTelemetry,
  name: string
): Promise<string> {
  const events = await telemetry.events();
  const records = events
    .flatMap((e) =>
      e.kind === "model_transition" ? [recordSlice(e.after, name)] : []
    )
    .filter((slice): slice is string => slice !== null);
  const latest = records[records.length - 1];
  if (latest === undefined)
    throw new Error(`no ${name} record was recorded on the model`);
  return latest;
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
  //
  // Read through `recordInt` rather than asserted as a fragment: the record also
  // carries `original_byte_size=`, which ends in `byte_size=`, so a substring
  // assertion on the processed length is satisfied by the picked photo's
  // fragment the moment the two coincide. Nothing stops them coinciding — a
  // photograph the encoder returns at its own length is the ordinary outcome for
  // an already-small one — and the failure would be silent rather than red.
  const record = await latestRecord(telemetry, RECORD);
  expect(recordInt(record, "byte_size")).toBe(file.body.length);
  expect(file.body.length).not.toBe(fs.statSync(SHARP).size);

  // Where the upload ended up, scoped to this section's record — the file-input
  // section emits a field of the same name into the same model string.
  await telemetry.assertRecordContains(RECORD, "upload=ok:201;");

  // Render correctness: the outcome is something the person looking at the
  // section can see, not only something the telemetry records.
  await expect(page.locator(UPLOAD_STATUS)).toHaveText("Uploaded (HTTP 201)", {
    timeout: SETTLE,
  });

  // No `events()` here, unlike the ordering tests above: `latestRecord` already
  // drained, and the snapshot it left is the whole log since page load. A second
  // drain would advance the cursor past it and attach the empty slice recorded
  // since — the artifact would survive and say nothing.
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

test("renders decoded before/after previews", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(PICKER).setInputFiles(SHARP);
  await telemetry.waitForMessage("ReceiptProcessed:ok;", SETTLE);

  // The correctness claim, in the vocabulary the section owns for it: the
  // serialized model is this suite's contract and the DOM assertions below are
  // reserved for what only a rendered page can say. The `previews=` prefix is
  // carried deliberately, not for symmetry: the preview failure tags reuse
  // words the `processing=` vocabulary also uses — `blob_not_found` is spelled
  // the same in both — so a bare `ready;`-shaped fragment would not say which
  // state machine reached it. This is also the first proof anywhere
  // that `main.ml`'s preview-backend registration is reached in a browser; the
  // unit suites register their own.
  await telemetry.waitForModel("previews=ready;", SETTLE);
  await telemetry.assertRecordContains(RECORD, "previews=ready;");

  // Render correctness, and the reason the feature exists. The model holding
  // two URLs says nothing about whether a browser can turn them into pictures —
  // see `waitForDecodedPair`, where the decode clause is argued.
  const pair = await waitForDecodedPair(page, []);

  expect(pair.original.src).toMatch(/^blob:/);
  expect(pair.processed.src).toMatch(/^blob:/);
  // Both axes, not only the one the decode gate reads: an image whose decoder
  // reported a width and no height is not a picture either, and the gate above
  // would let it through.
  expect(pair.original.width).toBeGreaterThan(0);
  expect(pair.original.height).toBeGreaterThan(0);
  expect(pair.processed.width).toBeGreaterThan(0);
  expect(pair.processed.height).toBeGreaterThan(0);

  // Two different object URLs. One photograph shown twice under two headings
  // satisfies every assertion above and is precisely the near-miss a
  // before/after pair is vulnerable to.
  expect(pair.original.src).not.toBe(pair.processed.src);

  // Which picture is which. A pair a reviewer cannot label is two photographs,
  // not a before and an after, so the headings are part of the render contract
  // rather than decoration. Scoped inside each half for the reason recorded at
  // the constants.
  await expect(page.locator(ORIGINAL_HALF)).toContainText(ORIGINAL_LABEL);
  await expect(page.locator(PROCESSED_HALF)).toContainText(PROCESSED_LABEL);

  await telemetry.events();
  await telemetry.attachHistory(test.info());
});

test("processed preview is downscaled", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(PICKER).setInputFiles(SHARP);
  await telemetry.waitForMessage("ReceiptProcessed:ok;", SETTLE);
  await telemetry.waitForModel("previews=ready;", SETTLE);

  const pair = await waitForDecodedPair(page, []);

  // The decoded size of the bytes a server would receive. Everywhere else in
  // this suite these two numbers are the model describing itself; here they are
  // Chromium's decoder reporting what it found inside the encoded JPEG, which
  // is the difference between a downscale that was recorded and a downscale
  // that happened. Nothing in this repository could say that until the pair was
  // rendered: the unit suites feed the section a stub, and the image package's
  // own suites run against a fake canvas.
  expect(pair.processed.width).toBe(STORED_WIDTH);
  expect(pair.processed.height).toBe(STORED_HEIGHT);

  // The affirmative arm for that pin: the photograph that went in really was
  // larger, so the numbers above are a resize and not a fixture that happened
  // to arrive already at the cap.
  expect(pair.original.width).toBeGreaterThan(pair.processed.width);
  expect(pair.original.height).toBeGreaterThan(pair.processed.height);

  // ...and the same shape. A pass that cropped, or that scaled the two axes
  // independently, still lands on the cap along the long edge and is still
  // wrong. Within a pixel, because the pass rounds to whole pixels. Derived
  // from what the original decoded to rather than from a fixture constant, so
  // replacing the fixture does not silently turn this into a tautology.
  const proportional =
    (pair.original.width * pair.processed.height) / pair.original.height;
  expect(Math.abs(pair.processed.width - proportional)).toBeLessThanOrEqual(1);

  // The picture on screen is the blob the model measured, not some other one:
  // the decoder's numbers and the model's numbers are the same numbers.
  await telemetry.assertRecordContains(RECORD, `width=${STORED_WIDTH};`);
  await telemetry.assertRecordContains(RECORD, `height=${STORED_HEIGHT};`);

  await telemetry.events();
  await telemetry.attachHistory(test.info());
});

test("re-selecting recovers the pair for every photo", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);
  const picker = page.locator(PICKER);

  // Three selections, alternating fixtures so each pass has a genuinely
  // different photograph to describe. A section that quietly kept the pair it
  // was already holding would still be showing the previous receipt.
  const shots = [SHARP, BLURRED, SHARP];
  const seen: string[] = [];

  for (const shot of shots) {
    await picker.setInputFiles(shot);

    // The gate, and the reason it is a DOM gate: see `waitForDecodedPair`.
    const pair = await waitForDecodedPair(page, seen);

    // Read as a drained slice for the same reason. `assertRecordContains` reads
    // the log whole and undrained, so from the second selection on it would be
    // answered by the first one's `previews=ready;` forever. `events()`
    // advances a cursor, so this is the model reaching `ready` again for THIS
    // photograph.
    await telemetry.events();
    await telemetry.assertModelContains("previews=ready;");

    seen.push(pair.original.src, pair.processed.src);
  }

  // Six distinct object URLs: every selection minted its own pair rather than
  // re-showing one it was already holding. Nothing here can count how many of
  // them are still live — no browser API enumerates the blob-URL registry — so
  // the release is proven at the structural layer by
  // `test_reshoot_loop_leak_count`, and this is the browser's half of that
  // claim: the mints are counted here, the releases are counted there. The gap
  // is deliberate, not an omission.
  //
  // That absence was measured rather than assumed, with a page holding two live
  // `blob:` URLs both mounted as `<img src>`. In this project's Chromium:
  //
  //   performance.getEntriesByType("resource")
  //     -> ["http://localhost:3000/kitchen_sink/main.bc.js",
  //         "http://localhost:3000/kitchen_sink/assets/placeholder.png"]
  //   performance.getEntriesByType("navigation")
  //     -> ["http://localhost:3000/kitchen_sink/"]
  //
  // Neither live URL appears in either, and sweeping every one of the thirteen
  // `PerformanceObserver.supportedEntryTypes` for a name containing "blob:"
  // returned nothing at all. `Object.getOwnPropertyNames(URL)` is
  // ["length","name","prototype","canParse","parse","createObjectURL",
  // "revokeObjectURL"] — the registry has a mint and a release and no reader.
  // Re-run that probe before reopening this gap.
  expect(new Set(seen).size).toBe(shots.length * 2);

  await telemetry.attachHistory(test.info());
});

test("a platform that mints no object URLs reports a preview failure", async ({
  page,
}) => {
  // The one place a preview failure tag is produced by a browser. Everywhere
  // else the `previews=failed:` vocabulary is driven through the structural
  // suite's stub — yet the argument for carrying the `previews=` prefix at all
  // is made here, in the browser layer, against a collision with `processing=`'s
  // vocabulary (`blob_not_found` is spelled the same in both). A vocabulary no
  // browser has ever emitted cannot demonstrate that; this case makes it
  // demonstrable rather than asserted.
  //
  // Driven by taking `URL.createObjectURL` away before the bundle boots, not by
  // a hook in the section: `Blob_store.object_url` probes for the member and
  // answers `None` when it is absent, the seam turns a resolvable handle with no
  // URL into `Url_unavailable`, and nothing else in the application mints an
  // object URL — the decode path is `createImageBitmap` — so the processing pass
  // is untouched by the removal. A hardened, proxied or policy-restricted global
  // is the real condition this reproduces.
  await page.addInitScript(() => {
    delete (URL as unknown as Record<string, unknown>).createObjectURL;
  });
  // An init script applies from the next navigation onward and `beforeEach` has
  // already navigated, so the page is re-entered here. `goto` rather than
  // `reload`, for the reason recorded in this file's header.
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    PICKER,
    { timeout: 10000 }
  );

  const telemetry = new NopalTelemetry(page);

  await page.locator(PICKER).setInputFiles(SHARP);
  await telemetry.waitForMessage("ReceiptProcessed:ok;", SETTLE);
  await telemetry.waitForModel("previews=failed:url_unavailable;", SETTLE);

  // The tag, not merely the failure: the three preview errors have three
  // different remedies — an unregistered backend is a wiring bug in `main.ml`, a
  // missing blob is a handle that was let go, and this is the platform declining
  // — so a bare `failed:` would not say which one a browser actually produced.
  await telemetry.assertRecordContains(
    RECORD,
    "previews=failed:url_unavailable;"
  );

  // The affirmative arm for the tag above, and the whole reason the preview
  // failure is a state of its own: a picture that cannot be shown is not a photo
  // that failed to process. Without these two the assertion would be satisfied
  // by a section that fell over entirely, which is the failure mode the separate
  // vocabulary exists to distinguish.
  await telemetry.assertRecordContains(RECORD, "processing=ready;");
  await telemetry.assertRecordContains(RECORD, "upload=idle;");

  // Render correctness: the pass that succeeded is still readable on screen, and
  // the pair is genuinely absent rather than mounted empty or mounted broken —
  // an `<img>` with a `src` the browser cannot resolve would satisfy a weaker
  // check and is exactly what a section ignoring the failure would produce.
  await expect(page.locator(METADATA)).toContainText(
    `${STORED_WIDTH} by ${STORED_HEIGHT} pixels`,
    { timeout: SETTLE }
  );
  await expect(page.locator(ORIGINAL_IMG)).toHaveCount(0);
  await expect(page.locator(PROCESSED_IMG)).toHaveCount(0);

  await telemetry.events();
  await telemetry.attachHistory(test.info());
});

test("the pair reports the payload it saved", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  // The photograph's own length, measured on disk rather than written here as a
  // constant. It is the same file `setInputFiles` hands the browser, so
  // replacing the fixture cannot leave this pinning a number nothing produces —
  // the precedent is the multipart test, which reads the encoded part's length
  // off the model for the same reason in the other direction.
  const picked = fs.statSync(SHARP).size;

  await page.locator(PICKER).setInputFiles(SHARP);
  await telemetry.waitForMessage("ReceiptProcessed:ok;", SETTLE);
  await telemetry.waitForModel("previews=ready;", SETTLE);

  // The correctness claim, in the model, and the half of it a spec can name in
  // advance: the length the section reports for the picked photo is that file's
  // own length, not the encoder's and not the decoded bitmap's.
  await telemetry.assertRecordContains(RECORD, `original_byte_size=${picked};`);

  const record = await latestRecord(telemetry, RECORD);
  const original = recordInt(record, "original_byte_size");
  const processed = recordInt(record, "byte_size");

  // The affirmative arms for the comparison below. An ordering between two
  // numbers says nothing until both are known to have been produced: a section
  // reporting nothing, or reporting a zero-byte encode, satisfies "smaller"
  // perfectly well and is the failure this suite exists to catch.
  expect(original).toBe(picked);
  expect(processed).toBeGreaterThan(0);

  // The payload proof, beside the pixel proof its siblings make: the bytes that
  // would leave the device are fewer than the bytes that were picked. Compared
  // rather than pinned — how far Chromium's encoder gets is its own number.
  expect(processed).toBeLessThan(original);

  // Render correctness: both numbers reach the person looking at the pair, each
  // under the photograph it describes. Asserted inside each half, because a
  // section-wide match is satisfied by two labels naming one length, which is
  // the near-miss a before/after readout is most vulnerable to. The processed
  // half's number and its direction are one assertion because they are one
  // sentence — and the two directions share no wording, so a growth rendered as
  // a reduction fails here rather than reading as a smaller number.
  await expect(page.locator(ORIGINAL_HALF)).toContainText(`${original} bytes`, {
    timeout: SETTLE,
  });
  await expect(page.locator(PROCESSED_HALF)).toContainText(
    `${processed} bytes, reduced to`,
    { timeout: SETTLE }
  );

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

test("axe passes with previews present", async ({ page }, testInfo) => {
  const telemetry = new NopalTelemetry(page);

  await page.locator(PICKER).setInputFiles(SHARP);
  await telemetry.waitForMessage("ReceiptProcessed:ok;", SETTLE);
  await telemetry.waitForModel("previews=ready;", SETTLE);

  // The affirmative arm. A zero-violation scan of a section that rendered no
  // pictures is vacuous, and the pictures are the entire subject here: an
  // `<img>` with no accessible name is a wcag2a failure, so a scan taken before
  // they mount reports clean about two elements it never saw.
  //
  // The sibling scan above does reach them today — measured, by giving one
  // preview a whitespace-only alt and watching both tests go red — but only by
  // timing accident: it waits on `ReceiptProcessed:ok;`, which the section
  // records before either object URL exists, and it asserts nothing about the
  // pair. A mint that arrived one frame later would leave it green over a
  // section with no images in it. This is the scan that cannot: the model gate
  // above says the pair is in the model and the two waits below say it is on
  // the page, and with the pictures suppressed this test fails on them while
  // the sibling stays green.
  await expect(page.locator(ORIGINAL_IMG)).toBeVisible({ timeout: SETTLE });
  await expect(page.locator(PROCESSED_IMG)).toBeVisible({ timeout: SETTLE });

  await assertNoAxeViolations(page, testInfo, SECTION);

  await telemetry.attachHistory(testInfo);
});
