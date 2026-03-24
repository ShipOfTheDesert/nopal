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

### Animation System

**Package:** `nopal_animate` (new package)
**Depends on:** `nopal_element`, `nopal_style`, `nopal_mvu`

A framework-wide animation system for Nopal. Animations touch multiple layers
of the framework — element transitions, style property interpolation, draw
scene transforms, chart data updates, and route transitions — so the animation
primitive must be general enough to serve all of them from a single model.

The system should provide:

- A **declarative animation description type** (`'a Animation.t`) that specifies
  start value, end value, duration, easing function, and delay. Animations are
  values, not imperative callbacks — they compose with the MVU architecture.
- **Style property interpolation** for `nopal_style` types: colour (HSL
  channel-wise), dimensions (float), opacity, padding, gap, border radius.
  Interpolators are typed so only compatible start/end values compile.
- **Element transitions** driven by model changes: when a style property changes
  between renders, the transition animates from the old value to the new value
  over the specified duration. The runtime manages in-flight transitions.
- **Draw scene animation** for `nopal_draw`: transform interpolation (translate,
  rotate, scale), colour interpolation, path morphing (same-segment-count paths
  interpolated point-wise). This enables animated charts, progress indicators,
  and interactive visualisations.
- **Chart data transitions** for `nopal_charts`: when data changes between
  renders, bar heights, line positions, pie segment angles, and scatter point
  positions animate smoothly from old values to new values. The chart library
  provides animation-aware rendering that the animation system drives.
- **Route transitions**: enter/exit animations for views during navigation,
  composable with the router.
- **Easing functions**: linear, ease-in, ease-out, ease-in-out, cubic-bezier
  (custom control points), spring (mass/stiffness/damping). Easing is a
  pure `float -> float` function — no platform dependency.
- **Stagger and sequence combinators**: delay-offset animations across a list
  of elements (e.g. staggered bar chart entrance), sequence multiple animations
  with completion callbacks via `Cmd.t`.

The animation system must compile on native OCaml without js_of_ocaml. The
runtime integration (requestAnimationFrame on web, display link on native) is
a backend concern — `nopal_animate` defines the description, `nopal_web` and
future backends interpret it. Animation tick rate is controlled by the backend;
the animation module itself is pure computation over time values.

MVU integration: animations produce `Cmd.t` values for scheduling ticks and
`Sub.t` values for ongoing animations. The application model holds animation
state; `update` advances animations via a tick message. This keeps all state
visible and testable — `nopal_test` can advance animations via the virtual
clock without a real timer.

### Trading and Financial Chart Extensions (`nopal_charts`) [x]

**Package:** `nopal_charts` (extension)
**Depends on:** `nopal_charts`, `nopal_draw`

Extend `nopal_charts` with features required for trading and financial data
visualisation. This is a primary use case for the charting library and warrants
dedicated chart types and scale utilities beyond the initial release.

The extension should provide:

- **Logarithmic scales.** A `Log` scale type in addition to the existing
  `Linear` scale, essential for price charts where percentage changes matter
  more than absolute changes. Log scales must handle the domain constraint
  (min > 0) gracefully, with a clear error or fallback when zero/negative
  values are present. Tick generation for log scales should produce ticks at
  powers of 10 (or subdivisions) rather than linear intervals.

- **Time series X axis.** A time-aware X axis that accepts Unix timestamps or
  a date representation and formats tick labels appropriately for the zoom
  level: seconds/minutes for intraday, days for weekly, months for yearly.
  Requires a minimal date formatting utility (not a full date library — just
  enough for axis labels). Tick placement should snap to natural time
  boundaries (start of hour, start of day, start of month) rather than
  uniform intervals.

- **Stacked bar charts.** Bars within a category stacked vertically, each
  segment representing a series value. Requires computing cumulative offsets
  per category and rendering segments bottom-to-top. Hit testing returns the
  specific segment (series + datum), not just the category. Tooltip shows the
  segment value and total.

- **Candlestick charts.** OHLC (open, high, low, close) candlestick chart
  for price data. Each candlestick is a composite shape: a thin vertical line
  (wick) from low to high, and a filled/hollow rectangle (body) from open to
  close. Body colour indicates direction (close > open = bullish, close < open
  = bearish). Configuration accepts colour for bullish/bearish candles.
  Hit testing covers the full wick-to-wick range. Tooltip shows all four OHLC
  values plus volume if provided.

- **Waterfall charts.** A bar chart variant showing cumulative effect of
  sequential positive and negative values. Each bar starts where the previous
  bar ended. Running total bars (e.g. subtotals) are visually distinguished.
  Connector lines between bars show the flow. Useful for P&L breakdowns and
  fund flow visualisation.

- **Volume overlay.** A secondary Y axis with a bar chart overlay on the lower
  portion of a price chart, sharing the same X (time) axis. This is the
  standard trading chart layout: price (line or candlestick) on the primary
  axis, volume bars on a secondary axis occupying the bottom 20-30% of the
  chart area.

- **Crosshair cursor.** A vertical + horizontal line following the cursor
  position, snapping to the nearest data point on the X axis. Axis labels
  update to show the crosshair position values. Standard in trading terminals.

All extensions must compile on native OCaml without js_of_ocaml (same
constraint as `nopal_charts` itself).

### Redesign Interaction Styling Architecture [x]

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

### Multi-Pane Wheel Zoom in Kitchen Sink

**Package:** `examples/kitchen_sink/`

The multi-pane synchronized chart layout in the kitchen sink demonstrates
drag-to-pan but does not wire an `~on_wheel` handler to `Chart_pane.view`.
Add wheel-to-zoom support to the multi-pane demo so that scrolling inside
any pane zooms all panes via the shared `Domain_window.t`. The E2E test
"multi-pane synchronized zoom" currently only asserts that rendering does
not crash — update it to verify that the domain window actually changes
after a wheel event.

### Multi-Browser E2E Testing

**Package:** `test/e2e/`

Add Firefox and WebKit Playwright projects to the E2E test configuration. The
interaction styling redesign (PRD 0029) relies on `CSSStyleSheet.insertRule` /
`deleteRule` with index tracking. While the CSSOM spec is clear, browser
implementation differences in rule index shifting after deletion are a known
risk (see RFC 0030 risk list). Currently only Chromium is tested.

The Playwright config should add `firefox` and `webkit` projects for the
`kitchen-sink` test suite, particularly for `interaction-styling.spec.ts`.
This verifies REQ-N4 (cross-browser support).

### Typed Error Results for Tauri Task Bindings

**Package:** `nopal_tauri` (`window.ml`, `tray.ml`)

All Tauri task bindings (`Window.show`, `Window.hide`, `Tray.set_tooltip`, etc.)
currently log IPC errors to the console but never resolve the `Task.t`, leaving
it permanently pending. This is benign — the MVU loop is event-driven and does
not block — but it means any state transition depending on the completion message
silently never happens.

The solution should change the return type from `unit Task.t` to
`(unit, string) result Task.t` (or a dedicated error type), so callers receive
`Ok ()` on success and `Error msg` on failure. This is a project-wide migration
affecting all ~20 existing Tauri task bindings in both `Window` and `Tray`. All
callers in examples and application code would need to handle the `Error` arm.

This should be done as a single coordinated migration rather than piecemeal per
module, to keep the API surface consistent.

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
