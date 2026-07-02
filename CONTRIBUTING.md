# Contributing to Nopal

## Development Setup

Nopal builds against a **local OCaml 5.3.0 opam switch**. From the repo root:

```bash
opam switch create . 5.3.0 --no-install -y          # one-time: create the local switch
eval $(opam env)                                    # fish: eval (opam env)
opam install . --deps-only --with-test --with-dev-setup -y
just                                                # build + test + fmt + lint + e2e
```

- `--with-test` pulls the test deps (alcotest).
- `--with-dev-setup` pulls the pinned dev tooling (ocamlformat, odoc,
  opam-dune-lint, ocaml-lsp-server) — without it `just fmt`/`just lint` fail.

On an immutable/atomic Linux host (Bazzite, Fedora Silverblue/Kinoite, …) run
all of the above **inside a container** — see
[Bazzite / immutable hosts (distrobox)](#bazzite--immutable-hosts-distrobox).

### Bazzite / immutable hosts (distrobox)

On atomic distros the host filesystem is read-only, so don't layer the
OCaml/Rust/Node toolchains onto it — do development inside a
[distrobox](https://distrobox.it/) (or toolbox) container. The reference
container is Arch-based:

```bash
distrobox create --name dev --image archlinux:latest
distrobox enter dev
```

Inside the container install the system dependencies (pacman):

```bash
# Core toolchain
sudo pacman -S --needed base-devel git just opam nodejs npm
# Tauri desktop builds (optional)
sudo pacman -S --needed gtk3 webkit2gtk-4.1
# Playwright e2e — Chromium runtime libs (see "E2E tests" below)
sudo pacman -S --needed at-spi2-core libcups cairo pango nss mesa \
    libxkbcommon alsa-lib libdrm libxcomposite libxdamage libxrandr \
    libxfixes libxext libxrender dbus expat
```

then run the opam bootstrap from "Development Setup" above.

**Run the toolchain only inside the container.** Your home directory — and
therefore each repo's local `_opam` switch and `~/.opam` — is bind-mounted into
both the host and the container. Running `opam`/`dune`/`just` from the **host**
relinks OCaml's native runtime with the host toolchain and corrupts the switch
for the container too (symptom: `relocation R_X86_64_32 ... can not be used when
making a PIE object`, and `ocamlc -where` pointing at `/var/home/...`). Recovery
from a corrupted switch is a clean rebuild: `rm -rf _opam && opam switch create .
5.3.0 --no-install -y` then the deps install above.

To avoid the trap entirely, add a **host-side shell guard** that blocks the
toolchain outside the container — it's the only thing that reliably stops the
muscle memory. For fish, in a host-only config (one that early-returns when
`/run/.containerenv` exists), wrap the commands so they fail fast on the host:

```fish
for c in opam dune just ocaml ocamlfind cargo npm node
    function $c --wraps=$c --inherit-variable c
        echo "⛔ '$c' blocked on the host — run it in the dev container." >&2
        echo "   distrobox enter dev   (bypass: command $c …)" >&2
        return 1
    end
end
```

> **Path note:** the host sees the repo under `/var/home/...`, the container
> under `/home/...`. opam keys switches by canonical path, so a switch created in
> one environment won't auto-detect in the other — always create and use it from
> the container.

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

On Arch (the distrobox container) Chromium needs system libraries that
`npx playwright install-deps` can't provide there; install them via pacman (see
the list in [Bazzite / immutable hosts](#bazzite--immutable-hosts-distrobox)).
If `npx playwright install chromium` stalls part-way on a slow/flaky connection,
fetch the browser zips directly with a resumable download instead — get the URLs
from `npx playwright install chromium --dry-run`, then
`curl -fL -C - --retry 8 -O <url>`, unzip into `~/.cache/ms-playwright/<browser>-<rev>/`,
and `touch ~/.cache/ms-playwright/<browser>-<rev>/INSTALLATION_COMPLETE`.

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

### Mobile Development (Tauri)

Nopal targets Android and iOS through Tauri's mobile webview. Android has
local `just` targets for the inner dev loop; iOS is built and smoke-tested
in CI (no contributor Mac hardware required — see below).

```bash
just dev-android      # build JS (dev) + launch the kitchen sink on an emulator/device
just build-android    # build JS (release) + produce an installable .apk and a Play .aab
```

Both recipes verify `ANDROID_HOME` is set before doing any work and halt
with an exact, copy-pasteable remediation command if it is absent, so a
misconfigured toolchain fails fast instead of deep inside the Tauri build.

The Android and iOS toolchain prerequisites are documented in
[Compiler targets by platform](#compiler-targets-by-platform) below.

## Compiler targets by platform

A single OCaml codebase compiles to every supported target. The compiler
choice is deliberately **uniform** — there is no per-platform compiler
branch — with one hard constraint on iOS.

| Target | Renderer | Compiler | Status |
|---|---|---|---|
| Web (SPA) | `nopal_web` (DOM) | `js_of_ocaml` | Default, shipped |
| Tauri desktop | `nopal_web` (webview) | `js_of_ocaml` | Default, shipped |
| Tauri Android | `nopal_web` (webview) | `js_of_ocaml` | Default, shipped |
| Tauri iOS | `nopal_web` (webview) | `js_of_ocaml` | Default, Simulator-validated in CI |

**`js_of_ocaml` is the default compiler for all four targets** — web, Tauri
desktop, Tauri Android, and Tauri iOS. Keeping the compiler uniform means
the same JS bundle semantics (and the same `nopal_web` renderer) run
everywhere, so a behaviour proven on web or desktop carries to mobile.

**`wasm_of_ocaml` is viable on Android but not the tested default.**
Chromium's Android WebView supports WasmGC, so a `wasm_of_ocaml` build can
in principle run there. Nopal does not test or ship it; it remains an
opt-in experiment, not a supported target.

**`wasm_of_ocaml` is blocked on iOS.** WKWebView prohibits JIT compilation,
which `wasm_of_ocaml`'s WasmGC output requires, so it cannot run inside the
iOS webview at all. This is the one hard platform constraint, and the
reason the compiler choice stays uniformly `js_of_ocaml` rather than
diverging to Wasm on capable platforms.

### Android toolchain prerequisites

`just dev-android` / `just build-android` require:

- **Android Studio** with the **SDK** and **NDK** installed (the NDK is
  needed to cross-compile Tauri's Rust core for the device ABIs).
- **`ANDROID_HOME`** exported to the SDK location. Persist it in your shell
  profile:

  ```bash
  export ANDROID_HOME="$HOME/Android/Sdk"
  # macOS default: export ANDROID_HOME="$HOME/Library/Android/sdk"
  ```

- The **Rust toolchain** (via [rustup](https://rustup.rs/)) and the Tauri
  system dependencies already required for desktop builds.

### iOS toolchain (CI only)

iOS is built and smoke-tested on a GitHub-hosted **`macos-latest`** runner
(`.github/workflows/ios.yml`), which ships Xcode and the iOS Simulator.
Simulator builds run **unsigned**, so iOS stays continuously validated
without any contributor Mac hardware or signing credentials. IPA generation
(signing/packaging) and interactive Simulator visual QA are tracked as
Phase 3 work, not Phase 2.

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
nopal_test         ← depends on element + style + mvu + runtime (must build on native OCaml)
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

### VIII. Bug-Class Prevention

The 2026-06-11 audit (`docs/ANALYSIS.md`) found that almost every bug is an
instance of one of five recurring *classes*. Each class has a type-level guard
(a shipped reference implementation that makes the class unrepresentable) and,
where a greppable signature exists, a `just lint-classes` check that fails a PR
before review. The five rules — enforced beside the `raise`, `style:string`, and
catch-all-`_` rules above — with their catalogue entry:

1. **Never log-and-not-resolve an effect.** An op that can fail resolves its
   `('a, error) result` exactly once — route it through
   `Nopal_tauri.Ipc.invoke_result`, never a `Console.error`-and-drop.
   (`docs/bug-classes/0001`; lint-classes class 1.)
2. **Never use a bare string as a protocol token.** Decode a wire/status token
   into a typed variant once at the FFI edge (e.g. `Tray.click_type`,
   `Task.outcome`);
   keep string `Error`s as human-readable messages only.
   (`docs/bug-classes/0002`; lint-classes class 2.)
3. **Never represent a remote resource handle as a constant.** A handle a remote
   API hands out is an abstract type whose only constructor is the call that
   creates it (e.g. `Store.t` from `Store.load`) — never a literal `rid`.
   (`docs/bug-classes/0003`; lint-classes class 3.)
4. **Never mutate a lifecycle flag outside its transition function.** Replace
   independent lifecycle booleans with one variant whose transitions are the only
   mutation, each matching exhaustively on the current state (e.g. the runtime
   `phase`, `Tauri_subscription`'s `Pending | Active | Cancelled`).
   (`docs/bug-classes/0004`; no grep — type guard + review only.)
5. **Never ship a partial public function.** A public function over a constrained
   domain is total (returns `result`, takes a refined type, or matches
   exhaustively) — no `List.hd`/`Option.get`/`Result.get_ok` on a `lib/`/`backends/`
   path, no raise on an "callers are currently safe" sub-domain.
   (`docs/bug-classes/0005`; lint-classes class 5.)

A sixth, cross-cutting rule from the same audit: **an E2E spec that CI does not
execute is a failing test** — every spec must be wired to a CI-run Playwright
project, enforced by `just check-e2e-wired`.

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
