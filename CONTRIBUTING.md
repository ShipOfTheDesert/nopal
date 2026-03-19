# Contributing to Nopal

## Development Setup

```bash
opam install . --deps-only --with-test
dune build
dune test
```

## Running Tests

### All at once

```bash
just                  # build + unit tests + fmt + lint (run before every commit)
```

### Unit tests (Alcotest)

```bash
just test             # run all unit tests via dune
```

Unit tests live under `test/unit/` and are organized per package:

```
test/unit/nopal_element/    # Element.t constructors, map, equal, events
test/unit/nopal_http/       # HTTP type construction + Cmd pipeline
test/unit/nopal_test/       # test_renderer simulation (click, blur, keydown…)
test/unit/nopal_web/        # web renderer reconciliation
test/unit/todomvc/          # TodoMVC model + structural view tests
```

### Native build check

```bash
just build-native     # verify DSL packages compile without js_of_ocaml
```

Required for any change touching `nopal_element`, `nopal_style`,
`nopal_test`, or `nopal_router`.

### E2E tests (Playwright)

```bash
cd test/e2e
npm install                       # first time only
npx playwright install chromium   # first time only
npx playwright test               # headless
npx playwright test --headed      # visual debug mode
```

The Playwright config auto-starts a local server (`npx serve` on port 3000)
that builds and serves the TodoMVC example. Tests run against headless
Chromium by default.

E2E tests live in `test/e2e/tests/` and cover every interactive example.

### Desktop Development (Tauri)

Tauri builds require two additional tools:

- **Rust toolchain** — Install via [rustup](https://rustup.rs/). The stable
  channel is sufficient.
- **miniserve** — Static file server used during dev mode. Install with
  `cargo install miniserve`.

Tauri system dependencies (GTK, WebKit, etc.) are also required on Linux.
See the [Tauri prerequisites](https://v2.tauri.app/start/prerequisites/)
for your platform.

```bash
just dev-tauri         # dune watch + miniserve + Tauri dev window (kitchen sink)
just build-tauri       # production build — outputs binary to tauri/src-tauri/target/release/bundle/
```

`dev-tauri` launches a full dev loop: it builds assets, starts a dune
polling rebuild, serves `tauri/dist/` via miniserve on port 1420, and
opens the Tauri window. File changes trigger a rebuild automatically.

`build-tauri` produces an optimized release binary bundled with the
kitchen sink frontend.

## Coding Principles

These principles govern every contribution. Listed in priority order.

### I. Library-First / Separation of Concerns

Nopal is a collection of independent opam packages. Every concern lives in
its own package with explicit, minimal dependencies. The compiler enforces
boundaries — not convention.

**Package hierarchy (dependencies flow strictly downward):**

```
nopal_mvu          ← no UI deps, no platform deps
nopal_element      ← depends on scene + style, no platform deps, no browser types
nopal_style        ← no platform deps
nopal_scene        ← depends on style, no platform deps (Color, Paint, Transform, Path, Scene)
nopal_draw         ← depends on scene + style (Scale + higher-level Path algorithms)
nopal_http         ← depends on mvu, no platform deps
nopal_router       ← no platform deps
nopal_runtime      ← depends on mvu + element + lwd
nopal_web          ← depends on runtime + brr + js_of_ocaml
nopal_http_web     ← depends on nopal_http + brr + js_of_ocaml
nopal_test         ← depends on element + style + mvu (must build on native OCaml)
```

A module is acceptable when it is:
- Self-contained with explicit, minimal dependencies
- Independently testable
- Documented with `(** ... *)` doc comments at every public value

**The DSL boundary is sacred.** `nopal_element` and all view functions in
application code must never import `nopal_web`, `Brr`, or any js_of_ocaml
type. If `nopal_test` requires js_of_ocaml to build, the boundary has been
violated.

**No platform types in view functions.** Event handlers in `Element.t`
receive domain values (`string`, `unit`) — never raw browser event objects.
This is what makes the DSL backend-agnostic.

### II. Test-First

All implementation follows strict TDD:
1. Write tests defining the intended behaviour
2. Confirm tests fail (`dune test` output required as evidence)
3. Write the minimum implementation to make them pass
4. Refactor under green

No `.ml` implementation file is merged without a corresponding test that
was written first and initially failed.

**Three test layers, all mandatory where applicable:**

| Layer | Tool | When required |
|---|---|---|
| Unit / logic | Alcotest | Every library module |
| Structural UI | `nopal_test` renderer | Every feature touching `Element.t` |
| E2E | Playwright (TypeScript) | Every example with user interaction |

The `nopal_test` renderer must be used to validate DSL boundary compliance
on every PR that touches `nopal_element` or any view function.

### III. Simplicity Gate

Keep the public API surface minimal. Each module exposes a focused interface
via its `.mli` file. Additional public modules require documented
justification.

The element DSL has a fixed minimal set: `Box`, `Row`, `Column`, `Text`,
`Button`, `Input`, `Image`, `Scroll`, `Keyed`, `Empty`, `Map`. New
primitive elements require strong justification and a cross-platform
viability argument.

### IV. Reversible by Default

Prefer approaches that are easy to change. The web renderer is accessed
through `nopal_web` only — swapping or adding a backend (Tauri, native,
server-side HTML) affects only that backend package. The DSL and MVU core
never change to accommodate a new renderer.

### V. Functional Patterns

**Immutable by Default**
All records are immutable unless mutation is explicitly justified.
`mutable` fields require a comment: `(* mutable: justified because ... *)`.

**Errors as Values**
Never `raise` for expected failure cases. All fallible public functions
return `('a, error) result`.

**Pattern Matching Over Conditionals**
Exhaustive `match` on variants. Never use catch-all `_` where the compiler
can enforce exhaustiveness. When adding a new element type or message
variant, the compiler must guide all necessary changes.

**MVU Pattern (Pure Core, Reactive Shell)**

All application logic lives in the pure MVU layer:

1. **Pure core** (`nopal_mvu`, `nopal_element`, `nopal_style`, `nopal_router`):
   takes data as input, returns data as output. `App.update` takes a model
   and a message and returns a new model and a `Cmd.t` — a pure description
   of what to do, not a side effect.
2. **Reactive shell** (`nopal_runtime`, `nopal_web`): a thin boundary that
   interprets `Cmd.t` values, manages subscription lifecycle, and renders
   `Element.t` trees into the platform target.

No business logic may live in the runtime or renderer. If you find yourself
adding `if/then` logic to `nopal_runtime` or `nopal_web` that encodes
application behaviour, it belongs in the pure core instead.

**No CSS Strings in View Code**
`style:string` is forbidden in view functions. All styling goes through
`nopal_style`'s typed layout/paint API. CSS generation is an internal
concern of `nopal_web`, never application code.

**Composition Over Inheritance**
Use modules, functors, and first-class modules for polymorphism.
No class hierarchies.

### VI. No Inline Helpers

Helper functions belong in dedicated modules with tests and `.mli` files,
never inline in unrelated modules.

### VII. Quality Gate

Every commit must pass:

```bash
just    # build + test + fmt + lint
```

The native build check is also mandatory for any PR touching
`nopal_element`, `nopal_style`, `nopal_test`, or `nopal_router`:

```bash
just build-native   # must succeed without js_of_ocaml
```

## Commit Style

Conventional Commits: `type(scope): description`
Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, `perf`
Scopes match package names: `mvu`, `element`, `style`, `runtime`, `web`,
`router`, `test`, `counter`, `todomvc`, `kitchen-sink`, `bench`

Examples:
- `feat(mvu): add Cmd.after with millisecond delay`
- `feat(element): add Scroll element with overflow semantics`
- `test(todomvc): add Playwright E2E for filter routing`
- `fix(web): correct keyed reconciliation on list reorder`
- `perf(runtime): batch subscription diffs to avoid redundant restarts`
- `refactor(style): separate CSS generation into Style.Css submodule`

## Branch Naming

Feature branches follow the feature numbering from the Phase 1 planning
document:

```
feat/f01-mvu-core
feat/f02-element-dsl
feat/f03-style-system
feat/f04-test-renderer
feat/f05-lwd-runtime
feat/f06-web-renderer
feat/f07-router
feat/f08-counter-example
feat/f09-todomvc-e2e
feat/f10-kitchen-sink
feat/f11-benchmark-suite
```

## Performance

The benchmark suite runs from Phase 1. Every PR that touches `nopal_runtime`
or `nopal_web` must be accompanied by a benchmark run showing no regression
against the committed baseline JSON in `bench/baseline.json`.

```bash
just bench          # run benchmark suite
just bench-compare  # compare against baseline
```

A metric degrading by more than 20% blocks merge. Bundle size is tracked
alongside runtime performance — avoid adding dependencies that inflate
js_of_ocaml output without justification.

## Kitchen Sink

Every PR that adds a new element, style feature, or interaction pattern
must add a corresponding section to `examples/kitchen_sink/` in the same
PR. The kitchen sink must always compile and render without errors.
