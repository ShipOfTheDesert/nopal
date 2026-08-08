import { test, expect } from "@playwright/test";
import * as path from "node:path";
import { NopalTelemetry } from "./nopal-telemetry";

// Multipart upload E2E for the kitchen sink's file-input section. This is the
// only layer where the multipart body is encoded by a real user agent rather
// than by a polyfill, so this spec owns the *wire format*: the boundary the
// platform generates, the part headers Chromium writes, and the bytes of the
// picked file arriving intact. The unit suites pin the FormData entries; only a
// browser can say what actually goes on the socket.
//
// The failure arm is asserted through the MVU telemetry log instead, which is
// this suite's primary correctness channel — an unresolvable handle produces no
// request at all, so there is no wire to read and the model is the only place
// the outcome is observable.
//
// Headless Chromium without a display server can stall requestAnimationFrame,
// which drives the model→DOM frame here. Mitigations, as in the sibling
// file-input spec: navigate fresh with `goto` and never `page.reload()`,
// `waitForFunction` before interacting, and gate behavioural waits on
// `waitForMessage` rather than a fixed delay.

const SECTION = '[data-testid="file-input-section"]';
// Anchored by each control's call-site `data-field`: the picker renders as an
// `<input>` and the two upload controls as `<button>`s, so a tag-shaped selector
// would resolve by document order across the whole page.
const PICKER = `${SECTION} [data-field="receipt-image"]`;
const UPLOAD = `${SECTION} [data-field="receipt-upload"]`;
const DANGLING = `${SECTION} [data-field="receipt-upload-dangling"]`;
// The rendered outcome. Telemetry owns the correctness contract (ADR 0108), but
// the status line is the only place a human sees `Nopal_http.message`, and a
// `data-testid` nothing asserts on is a missing test rather than spare markup.
const STATUS = `${SECTION} [data-testid="file-input-upload-status"]`;

const FIXTURE = path.join(__dirname, "fixtures", "receipt-sample.txt");
// The same 13 bytes the fixture holds. Asserted as the file part's payload so
// an empty part cannot pass a field-name-only check.
const FIXTURE_BYTES = "receipt data\n";

// The section's upload endpoint. Intercepted here and never reached: nothing in
// the repo serves it, so an unmatched pattern would surface as a network error
// rather than a silently-unasserted request.
const UPLOAD_URL = "**/api/receipt-upload";

// The handle the section fabricates to make the unresolvable-handle path
// reachable from the UI. Quoted because the model serialiser emits it with %S.
const DANGLING_TAG = 'error:invalid_blob:"no-such-receipt-blob";';

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a display-server-less machine.
const SETTLE = 15000;

interface MultipartPart {
  headers: string;
  body: string;
}

// Split a multipart/form-data payload into its parts, keyed by the part's
// `name`. Hand-rolled rather than fed to a parser library because the point of
// the spec is to read exactly what Chromium wrote — a tolerant parser that
// normalises headers would hide the very details being pinned.
function parseMultipart(raw: string, boundary: string): Map<string, MultipartPart> {
  const parts = new Map<string, MultipartPart>();
  for (const chunk of raw.split(`--${boundary}`)) {
    const split = chunk.indexOf("\r\n\r\n");
    if (split === -1) continue; // preamble, epilogue, and the closing `--`
    const headers = chunk.slice(0, split).trim();
    const name = /name="([^"]*)"/.exec(headers)?.[1];
    if (name === undefined) continue;
    // A part body is terminated by the CRLF that precedes the next boundary
    // line; everything before it is payload, including any trailing newline the
    // file itself carries.
    parts.set(name, { headers, body: chunk.slice(split + 4).replace(/\r\n$/, "") });
  }
  return parts;
}

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/", { waitUntil: "load" });
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    PICKER,
    { timeout: 10000 }
  );
});

test("uploads a multipart body with file and string parts", async ({ page }) => {
  const telemetry = new NopalTelemetry(page);

  // Collected into an array rather than into `let`s the route callback assigns:
  // TypeScript's control-flow analysis does not track assignments made inside a
  // nested function, so a `let x: Buffer | null = null` stays narrowed to `null`
  // at the assertions below and `x!` resolves to `never`.
  const captured: { contentType: string | null; payload: Buffer | null }[] = [];

  await page.route(UPLOAD_URL, async (route) => {
    const request = route.request();
    captured.push({
      contentType: await request.headerValue("content-type"),
      payload: request.postDataBuffer(),
    });
    await route.fulfill({ status: 201, contentType: "text/plain", body: "stored" });
  });

  await page.locator(PICKER).setInputFiles(FIXTURE);
  await telemetry.waitForMessage("FilesSelected:1;", SETTLE);

  await page.locator(UPLOAD).click();
  await telemetry.waitForMessage("UploadResult:ok:201;", SETTLE);

  expect(captured).toHaveLength(1);
  const { contentType, payload } = captured[0];

  // No `Content-Type` is set by the backend precisely so the user agent can
  // generate one — a hand-written header would carry a boundary that does not
  // match the encoded body. Asserting the boundary is present is what proves
  // the generation happened.
  expect(contentType).toMatch(/^multipart\/form-data; boundary=.+$/);
  const boundary = /boundary=(.+)$/.exec(contentType!)![1];

  expect(payload).not.toBeNull();
  const parts = parseMultipart(payload!.toString("utf8"), boundary);

  // Render correctness: the status line is what a human reads, and it is the
  // only surface `Nopal_http.message` reaches.
  await expect(page.locator(STATUS)).toHaveText("Uploaded (HTTP 201)");

  // Exactly the two parts the section builds — an extra or missing part is as
  // wrong as a malformed one.
  expect([...parts.keys()]).toEqual(["caption", "receipt"]);

  expect(parts.get("caption")!.body).toBe("kitchen sink receipt");

  const file = parts.get("receipt")!;
  // Filename and MIME are per-part overrides the section declares; both have to
  // survive into the part's own headers, not just into the FormData entry.
  expect(file.headers).toMatch(/filename="receipt-sample\.txt"/);
  expect(file.headers).toMatch(/Content-Type:\s*text\/plain/i);
  // The bytes themselves. A part that resolved to an empty or stringified blob
  // would still carry the right name and filename, so the payload is the only
  // assertion that distinguishes a real upload from a plausible-looking one.
  expect(file.body).toBe(FIXTURE_BYTES);

  await telemetry.attachHistory(test.info());
});

test("dangling handle surfaces Invalid_blob and sends nothing", async ({
  page,
}) => {
  const telemetry = new NopalTelemetry(page);

  let requests = 0;
  await page.route(UPLOAD_URL, async (route) => {
    requests += 1;
    await route.fulfill({ status: 200, contentType: "text/plain", body: "stored" });
  });

  await page.locator(DANGLING).click();
  await telemetry.waitForMessage(`UploadResult:${DANGLING_TAG}`, SETTLE);
  // The model fragment, with its trailing ';', is the correctness contract: a
  // network failure and an unresolvable handle have different remedies and the
  // telemetry has to say which one happened.
  await telemetry.assertModelContains(`upload=${DANGLING_TAG}`);
  // Nothing was sent. A body whose string field is perfectly good and whose
  // file part cannot be resolved must not reach the server partially.
  expect(requests).toBe(0);
  // What the user is actually told. The rendering names the handle, so a
  // dangling upload is diagnosable from the screen and not only from telemetry.
  await expect(page.locator(STATUS)).toContainText("no-such-receipt-blob");

  // Attached here, before the affirmative arm advances the cursor: the helper's
  // reads drain, so one attachment at the end of this test would carry only
  // whichever slice was current and silently omit the other.
  await telemetry.attachHistory(test.info());

  // Affirmative arm for the count above, on the same route and the same page:
  // a resolvable handle does issue exactly one request, so the absence assertion
  // cannot be passing because the route pattern never matches anything.
  await page.locator(PICKER).setInputFiles(FIXTURE);
  await telemetry.waitForMessage("FilesSelected:1;", SETTLE);
  await page.locator(UPLOAD).click();
  await telemetry.waitForMessage("UploadResult:ok:200;", SETTLE);
  expect(requests).toBe(1);

  // Second slice: the affirmative arm's own events, drained past the checkpoint
  // the attachment above captured.
  await telemetry.events();
  await telemetry.attachHistory(test.info());
});
