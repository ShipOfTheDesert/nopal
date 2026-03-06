# Nopal Roadmap

## Future Work

### Async and Time-Based Test Utilities

**Package:** `nopal_test` (extension)
**Depends on:** `nopal_test`, `nopal_mvu`

Extend `nopal_test` with support for testing time-dependent and asynchronous
behavior: subscriptions (`Sub.every`, `Sub.on_keydown`, `Sub.on_resize`,
`Sub.custom`), delayed commands (`Cmd.after`), and async commands (`Cmd.async`,
`Cmd.task`). Today `nopal_test` covers synchronous rendering, querying, event
simulation, and pure MVU loop cycles. It cannot test code that depends on the
passage of time, deferred message dispatch, or subscription lifecycle.

The solution should provide:

- A **virtual clock** that the test controls, so `Cmd.after` and `Sub.every`
  resolve deterministically without real wall-clock delays.
- A **subscription test harness** that activates, fires, and deactivates
  subscriptions based on model changes, letting tests assert which
  subscriptions are active and what messages they produce.
- An **async command resolver** that captures pending async/task commands and
  lets tests supply results (success or failure) manually, keeping tests
  deterministic and independent of real I/O.
- A **step-based test runner** (extending `run_app`) that interleaves message
  dispatch, subscription ticks, and async resolution in a controlled sequence,
  returning intermediate or final model + rendered output at each step.

All utilities must compile on native OCaml without js_of_ocaml (same constraint
as `nopal_test` itself). The virtual clock and async resolver must not use
`Unix` or any OS-level timer — they are pure bookkeeping driven by explicit
test steps.

### Style Assertion Helpers

**Package:** `nopal_test` (extension)
**Depends on:** `nopal_test`, `nopal_style`

Add helpers to `nopal_test` for asserting on specific style property values of
rendered elements. Currently `nopal_test` renders `Element.t` into a structural
node tree but does not expose style information — style assertion helpers were
explicitly out of scope for the initial structural test renderer (PRD 0007).

The solution should provide:

- Query functions to extract the `Style.t` associated with a rendered element
  (by selector or from a found node).
- Assertion helpers for common style properties: direction, alignment, size,
  color, padding, gap, border, opacity, overflow.
- Readable test output showing expected vs actual style values on failure.

All utilities must compile on native OCaml without js_of_ocaml (same constraint
as `nopal_test` itself).

Typical test scenario: "Given a counter app with `Sub.every 1000ms Tick`,
advance the virtual clock by 3000ms, assert that 3 `Tick` messages were
dispatched and the model reflects them." Or: "Given an app that issues
`Cmd.async fetch_data`, resolve the pending command with `Ok data`, assert
the model updated correctly."
