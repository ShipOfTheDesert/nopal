# E2E fixtures

Files handed to a real browser input by a Playwright spec. Every file here must
be referenced by at least one spec — an unreferenced fixture pins nothing and
rots silently, so treat one as a missing test rather than a spare file.

## `receipt-sample.txt`

Consumed by `../kitchen-sink-file-input.spec.ts` and
`../kitchen-sink-multipart.spec.ts` via `setInputFiles`, which is what makes the
kitchen sink's file picker dispatch a real selection — and, in the multipart
spec, what puts real bytes on the wire.

Produced with:

```bash
printf 'receipt data\n' > receipt-sample.txt
```

Four properties are load-bearing and asserted by those specs, so do not edit the
file casually:

- **13 bytes.** The file-input spec asserts `file_size=13;`. Any edit changes the
  size.
- **`.txt` extension.** Playwright derives the `File`'s MIME type from the
  extension, and the file-input spec asserts `file_mime="text/plain";` while the
  multipart spec asserts the same type on the uploaded part's headers.
- **The name `receipt-sample.txt`.** Asserted as `file_name="receipt-sample.txt";`,
  as the uploaded part's `filename=`, and mirrored by the native structural suite
  for the same section so all three layers describe the same file.
- **The exact content `receipt data\n`.** The multipart spec compares the
  uploaded file part's payload against it byte for byte — that comparison is what
  distinguishes a real blob upload from an empty or stringified part, so a
  same-size edit still breaks it.

The picker it is dropped into is restricted to `accept="image/*"`. That is not a
mismatch: `accept` is a user-agent picker hint, never a gate on the selection,
and `setInputFiles` bypasses the picker. A plain text file is deliberate — it
keeps the fixture readable and its byte size obvious.
