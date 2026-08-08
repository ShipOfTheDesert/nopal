# E2E fixtures

Files handed to a real browser input by a Playwright spec. Every file here must
be referenced by at least one spec — an unreferenced fixture pins nothing and
rots silently, so treat one as a missing test rather than a spare file.

## `receipt-sample.txt`

Consumed by `../kitchen-sink-file-input.spec.ts` via `setInputFiles`, which is
what makes the kitchen sink's file picker dispatch a real selection.

Produced with:

```bash
printf 'receipt data\n' > receipt-sample.txt
```

Three properties are load-bearing and asserted by the spec, so do not edit the
file casually:

- **13 bytes.** The spec asserts `file_size=13;`. Any edit changes the size.
- **`.txt` extension.** Playwright derives the `File`'s MIME type from the
  extension, and the spec asserts `file_mime="text/plain";`.
- **The name `receipt-sample.txt`.** Asserted as `file_name="receipt-sample.txt";`,
  and mirrored by the native structural suite for the same section so both
  layers describe the same file.

The picker it is dropped into is restricted to `accept="image/*"`. That is not a
mismatch: `accept` is a user-agent picker hint, never a gate on the selection,
and `setInputFiles` bypasses the picker. A plain text file is deliberate — it
keeps the fixture readable and its byte size obvious.
