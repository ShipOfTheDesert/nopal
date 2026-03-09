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

### Split `align` Type in `nopal_style`

**Package:** `nopal_style`

The `align` type is shared between `main_align` (maps to `justify-content`) and
`cross_align` (maps to `align-items`). `Space_between` is valid for
`justify-content` but not for `align-items` — CSS silently ignores it. Either
split into `main_align` and `cross_align` types (where only `main_align` carries
`Space_between`), or validate at construction time.

### Redesign Interaction Styling Architecture

**Packages:** `nopal_style`, `nopal_web` (`style_sheet.ml`, `style_css.ml`, `renderer.ml`)

The current interaction styling implementation (PRD 0023) has three known
design limitations that share a root cause: the styling system was not designed
with stylesheet-based rules in mind. A unified redesign should address all three
together.

**1. Per-element `<style>` injection (scalability)**

Each interactive element creates its own `<style>` DOM element in `<head>`,
containing that element's pseudo-class rules. This is O(n) DOM nodes for n
interactive elements. The original RFC design (single `<style>` with
`insertRule`/`deleteRule`) was abandoned because `deleteRule(index)` shifts all
subsequent rule indices, making index tracking unreliable when rules are removed
in arbitrary order.

A redesign should provide O(1) DOM nodes for CSS rule management. Options
include: a single `<style>` element with content rebuilt on change (acceptable
if change frequency is low), an append-only `insertRule` with periodic
compaction, or a stable-key rule registry that avoids index-based deletion.

**2. `!important` on pseudo-class rules (specificity conflict)**

Base styles are applied as inline styles on DOM elements. Inline styles have the
highest CSS specificity, so pseudo-class rules in a stylesheet cannot override
them without `!important`. This works but is a blunt instrument that makes
debugging harder and risks a specificity arms race if future features also need
`!important`.

A redesign should eliminate the need for `!important` by ensuring base styles
and interaction styles use the same styling mechanism. The cleanest approach is
to move base styles to the stylesheet (at least for interactive elements),
allowing pseudo-class rules to override naturally via CSS cascade.

**3. No deduplication of identical interaction styles**

Multiple elements with structurally identical `Interaction.t` values each get
separate class names and rules. A cache keyed on `Interaction.equal` (with
reference counting for cleanup) would eliminate redundant rules.

**Design constraint:** Any redesign must preserve the property that elements
without interaction styles (`Interaction.default`) pay zero cost — no class
name, no stylesheet rules, no DOM attribute changes.

## Performance

Performance-related improvements tracked here. None of these are regressions —
they are optimisation opportunities identified during code review.

### `of_style` Per-Field Comparison

**Package:** `nopal_web` (`style_css.ml`)

`of_style` uses a fast-path check comparing the entire `layout`/`paint` record
against defaults. When any single field differs, all fields in that record are
evaluated. For example, setting only `gap = 10.` also evaluates direction,
alignment, wrap, padding, width, height, and flex_grow. A per-field comparison
would emit only the properties that actually differ from defaults, avoiding
redundant CSS output and unnecessary string formatting.

### Keyed Reconciliation: Skip Reordering When Order Unchanged

**Package:** `nopal_web` (`renderer.ml`)

`reconcile_keyed_children` calls `appendChild` for every child in the new list
to ensure correct DOM order. `appendChild` on an already-present child moves it,
so this is correct, but it performs O(n) DOM operations even when the order has
not changed. Comparing the old key order against the new key order before
touching the DOM would skip reordering entirely in the common case (e.g., only
content within keyed items changed, no reorder).
