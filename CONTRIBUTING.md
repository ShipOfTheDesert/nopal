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

Deferring a browser case is allowed; leaving it unrecorded is not.
**There is one current deferral.**

#### Open deferral — a relative-scroll request naming a container the frame removed

**Owner: whoever adds a kitchen-sink section whose scroll container comes and
goes with the model, in the change that adds it.**

`test/unit/nopal_web/dom_shim.js` resolves an id against every element
`createElement` has produced and never prunes that registry, so a container the
frame just removed still answers to its id and takes a real `scrollTop` write,
where a browser answers `null` and the request evaporates. Pruning the registry
is not the fix: renderer tests mount into a detached parent a browser would
already answer `null` for, so pruning would change what every existing case in
that suite means. The case cannot be expressed in the Alcotest suites at all and
belongs to a Playwright one — and no current spec removes a container while a
request for it is in flight.

Nothing observable is lost today, because both branches are no-ops on screen;
that is why no browser case was written rather than an oversight. The owner
above writes it — remove the container in the same update that issues the
request, assert the page does not move — at the moment a section makes the
removal reachable.

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

#### Tauri E2E on a Wayland host

```bash
GDK_BACKEND=x11 just e2e-tauri
```

`just e2e-tauri` drives the built binary under `xvfb-run`, which puts a virtual
X server in `DISPLAY`. On a Wayland desktop `WAYLAND_DISPLAY` is set too — and
it survives into a distrobox container — so GTK prefers the Wayland backend,
the window is created on the real compositor instead of the virtual X server,
and it is never mapped. An unmapped GTK window has no frame clock, so
`requestAnimationFrame` never fires inside the webview: measured at **0 callbacks
in 2 seconds**, against 134 with `GDK_BACKEND=x11`.

That is invisible to five of the six specs, because they assert through IPC and
the telemetry mirror, which do not need a frame. The sixth,
`mobile_signals.e2e.ts`, is the only one asserting a DOM change — the safe-area
inset readout, which is render correctness rather than model state and so has
nothing for telemetry to assert. It is therefore the only one that goes red, and
it goes red with no browser error, no failed `invoke`, and a correctly delivered
event, which reads exactly like an application bug. CI is unaffected: its runner
has no Wayland session, so the X11 backend is already the only one available.
Export the variable in your container shell profile if you run this gate often.

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

### Android device confirmation (manual, not a gate)

No CI job runs Nopal on an Android device, so nothing here goes red when
Android behaviour regresses. The one on-device confirmation that exists was
made by hand by **Miguel Lopez V** on **2026-08-11**, on his own machine and
under his own authorisation: on a Pixel-7 AVD (x86_64, google_apis,
API 35 / Android 15, Android System WebView 124.0.6367.219) built with
tauri-cli 2.10.1, wry 0.54.4 and NDK r27c, the kitchen sink's receipt-capture
section opened Android's system photo picker, and the selection reached the
file-input change handler and ran through processing to a settled upload.

Read that as a dated observation on one stack, not a supported guarantee — a
green `just` says nothing about it, and a wry or WebView upgrade can break it
with no test going red. Two gaps it explicitly leaves open, each with an owner:

- **Camera capture on physical hardware.** `capture="environment"` resolved to
  the picker on the AVD, which has no camera, so which of picker-vs-camera a
  handset chooses is still unknown. Whoever first ships a feature that depends
  on the camera intent must re-confirm it on a real device in that same change,
  before writing UI copy that promises a camera.
- **Automated on-device coverage.** Owned by the Phase 3 implementer, in the
  feature that introduces the mobile E2E harness. Until that lands, an Android
  change is confirmed by hand or not at all, and a PR touching Tauri's mobile
  path should say which of the two happened — and, when it was by hand, who
  ran it and on what date.

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
nopal_mvu          ← depends on element for the types Cmd/Sub/App carry,
                     no platform deps
nopal_element      ← depends on scene + style, no platform deps, no browser types
nopal_style        ← no platform deps
nopal_scene        ← depends on style, no platform deps (Color, Paint, Transform, Path, Scene)
nopal_draw         ← depends on scene + style (Scale + higher-level Path algorithms)
nopal_http         ← depends on mvu, no platform deps
nopal_image        ← depends on mvu, no platform deps (Buffer, Luma, Sharpness, Config, Processing, Preview)
nopal_router       ← no platform deps
nopal_runtime      ← depends on mvu + element + lwd
nopal_web          ← depends on runtime + brr + js_of_ocaml
nopal_blob_web     ← depends on brr + js_of_ocaml (session-local blob handle registry
                     + displayable object URLs)
nopal_http_web     ← depends on nopal_http + nopal_blob_web + brr + js_of_ocaml
nopal_image_web    ← depends on nopal_image + nopal_mvu + nopal_blob_web + brr + js_of_ocaml
                     (public module is the two seams — Processing and Preview;
                      bindings live in the nopal_image_web.internal sub-library)
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

Deferring a benchmark obligation is allowed; leaving it unrecorded is not.
**There is one current deferral.**

### Open deferral — the committed baseline is stale, so read it relatively

**Owner: the developer preparing the next change to `nopal_runtime` or
`nopal_web`, before claiming `bench-compare` green.**

`bench/baseline.json` was last regenerated in PR #64, on a different machine.
It has drifted far enough that an absolute reading against it is no longer a
reliable gate: on current developer hardware every runtime metric comes in
**15% to 63% faster** than the number committed beside it, while
`bundle/main_bc_js` comes in about **6% larger**. A 20% degradation introduced
by a real change disappears into that headroom on the runtime metrics, and
absolute readings also swing hard between sessions on the same machine — one
branch was measured at **473.4 / 483.9 / 462.9 ms** on `jsfb/create_10000` in
one session and **313.3 / 316.5 / 322.7 ms** in another, against the same
unchanged working tree. A 170 ms spread is wider than the 20% gate being read
against it.

**The reliable check is the branch against its own merge base, on one machine
within one session,** so the machine is constant and the diff is the only
variable:

```bash
just bench-compare                               # branch, idle machine
git stash && just bench-compare && git stash pop # same machine, same session, at the merge base
```

That is a supplement to the rule above, not a relaxation of it: a metric
degrading by more than 20% still blocks merge, and a base comparison is how you
find out whether the degradation is yours.

This procedure was run on **2026-08-20**, on the branch that added
`Cmd.scroll_by` — the change whose measurements produced the spread quoted
above. Both runs reported all 18 metrics within threshold. On
`jsfb/create_10000`, against a committed baseline of 388.60 ms, the branch
measured **316.30 ms** and its merge base **331.10 ms**: the branch is 14.80 ms
(−4.5%) *faster* than the tree it was built on, and no metric moved against the
branch by more than 4.2%. The over-the-gate session was therefore variance and
not the change. The per-metric table is carried in that change's pull request
description; the conclusion above is the part this file needs.

`bench/baseline.json` is deliberately left untouched, and stays that way until
someone regenerates it on purpose, as a change of its own with its own
reasoning. Re-baselining absorbs whichever session happens to be current into
the committed gate, destroys the evidence anyone would need to attribute the
drift later, and silently raises the regression ceiling for every future
change. Until then: record the red runs alongside the green ones rather than
the run that suited you, never re-run until green, and never re-baseline to
absorb an inflated number.

## Kitchen Sink

Every PR that adds a new element, style feature, or interaction pattern
must add a corresponding section to `examples/kitchen_sink/` in the same
PR. The kitchen sink must always compile and render without errors.

A backend package that adds no element, style feature or interaction pattern —
`nopal_http_web`, `nopal_blob_web`, `nopal_image_web` — does not trigger the
rule by itself. It does still need a section before the capability can be said
to work in a real browser, because the kitchen sink is what Playwright drives.
Deferring that section is allowed; leaving it unrecorded is not. **There are no
current deferrals.**

`nopal_image_web` was the last one. Its section is the kitchen sink's receipt
flow, and `test/e2e/tests/kitchen-sink-receipt-flow.spec.ts` drives the real
canvas pipeline through it — decode, downscale, re-encode, sharpness, and the
multipart upload of the processed handle.

That section now also renders the photograph it picked and the photograph it
would send, side by side and labelled, from object URLs minted by
`nopal_blob_web` and reached through the `Nopal_image.Preview` seam. The point
is the one no assertion covers: compression artefacts on small text, a rotated
image and a silently black canvas encode all produce a valid handle and a
plausible byte count, and are obvious to a person looking at the pair. What the
pair did make assertable is that the browser decodes both halves
(`naturalWidth > 0`, so not a black or empty encode) and that the processed half
is smaller than the original by the section's own cap while holding the
fixture's aspect ratio.

Each half is labelled with the byte length of the picture it shows, and the
as-uploaded half with its share of the original, so the payload change is read
off the same pair as the fidelity change. Both lengths are on the wire as
integers — the picked file's beside the encoded one — and the share is not: a
rendered percentage is a float by another name, and a spec asserting on one would
have to reimplement its rounding rule. The spec computes the relationship itself
from the two integers.

Three things about that suite are worth knowing before extending it. Headless
Chromium is the only browser it has run under, and the encoded byte counts and
raw sharpness scores that browser produces are its own rather than a contract —
so assert on the order two photographs come out in, never on a number. The
picked photograph's length is the exception that proves it: that number is the
fixture's own length on disk, so the payload test reads it with `fs.statSync`
and compares the encoded length against it rather than pinning either. It does
not reach the `Canvas_unavailable` or `Pixel_read_failed` arms: neither is
reachable from a page that renders with a backend registered, so both stay
covered by the package's fake-canvas unit suites under Node alone. And it does
not count live object URLs, because no browser API enumerates the blob-URL
registry — measured against a page holding two live `blob:` URLs rather than
argued from memory, with the observed output recorded beside the claim in
`test/e2e/tests/kitchen-sink-receipt-flow.spec.ts` (`re-selecting recovers the
pair for every photo`); re-run that probe before reopening the gap. So the claim
that a re-shoot loop leaves exactly the pair on screen live is made by the
structural suite's counting stub
(`test/unit/kitchen_sink/test_receipt_flow_section.ml`,
`test_reshoot_loop_leak_count`) and the browser only shows that each selection
mints URLs it has not shown before.

All three are decisions not to cover, rather than work owed to anyone. Whoever
meets a browser that refuses a 2D context or a pixel read owns reopening the
second one, in the change that meets it; whoever finds an API that reports live
object URLs owns the third, in the change that would use it.

The one preview state that is worth driving from the page is the failure. The
section's `previews=` vocabulary reuses words `processing=` also uses, and the
browser is where that collision is real, so the suite takes
`URL.createObjectURL` away before the bundle boots and asserts the resulting
`previews=failed:url_unavailable;` beside an untouched `processing=ready;`. It
costs no production hook: the store probes for the member and reports its
absence, and the decode path is `createImageBitmap`, so the pass itself does not
notice.
