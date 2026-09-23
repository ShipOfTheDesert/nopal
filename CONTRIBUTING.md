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

## Deferrals and decisions not to cover

Deferring an obligation this document imposes — a browser case, a benchmark run,
a kitchen-sink section — is allowed; leaving it unrecorded is not. Deciding not
to cover something is allowed too, and has to be written as a decision rather
than asserted in passing.

Each record carries a stable `D-n` id — unique across this file, assigned once
and never reused, so a commit message or a PR description can cite it instead of
restating it — and names an owner. The owner is **the change that will discharge
it**, not a person: "whoever adds a router-less example to the repo, in the
change that adds it", never "the team" or "later". One kind of record names no
owner: a decision not to cover whose reasoning does not expire has no change
that would discharge it, so it says so in the owner's place and is challenged by
disagreeing with its argument rather than by waiting for the change that would
close it.

Each record lives beside the rule it defers, so the next reader of that rule
sees the exception: D-1, D-2, D-6, D-10 and D-16 under
[E2E tests](#e2e-tests-playwright), D-3 under [Performance](#performance), D-4
and D-12 under [Kitchen Sink](#kitchen-sink), D-5 and D-7 under
[VIII. Bug-Class Prevention](#viii-bug-class-prevention), D-8, D-9, D-11,
D-13, D-14 and D-15 under [V. Functional Patterns](#v-functional-patterns). D-11 is
discharged; its record stays where it was, because an id is assigned once and
never reused and a reader who meets the id in an older commit message has to be
able to find it.

## Reporting a framework gap

A downstream consumer that cannot do something with Nopal writes it down, and
this is the shape it is written in. The shape exists because the last two
reports to reach this repository each carried claims that were **false at the
consumer's own pin**, and in both cases the framework was asked to build
something it had already shipped.

Every claim is one line, and it carries three things:

```
Nopal-at-pin-<sha> cannot X — verified at HEAD: yes/no — checked against <file:line>
```

- **The pin.** Not "Nopal cannot X". A consumer speaks for the tree it is
  pinned to, and nothing else. `<sha>` is what that consumer's lockfile names.
- **The HEAD answer.** Whether the claim still holds at the tip of `main` at
  the moment the report is written. **A claim false at HEAD is a consumer
  upgrade, not a feature request**, and it is triaged as one: the report says
  which commit closed it and stops there.
- **The citation.** The `<file:line>` the claim was checked against, in this
  repository. A claim with no citation is an impression. The citation is also
  what makes the claim falsifiable by someone who was not there — which is the
  whole of what this section buys.

Verify against **`llms.txt`**. It is tracked, it ships in every clone, and it
is kept current feature by feature. Do not verify against `docs/` — that tree
is in `.git/info/exclude` and reaches nobody (D-5, under
[Deferrals and decisions not to cover](#deferrals-and-decisions-not-to-cover)),
so a claim checked against it cannot be re-checked by the reader. Where
`llms.txt` does not settle the question, cite the `.mli`.

Two failure modes this format is aimed at, both observed:

- **A capability that shipped before the pin.** A consumer pinned at `81455c3`
  (2026-09-12) reported that nothing in Nopal focuses an element from
  application code. `Cmd.focus` is at `lib/nopal_mvu/cmd.mli:89` in that exact
  tree, and `Element.box`'s `~on_focus`/`~on_blur` landed in `ec85d4b`, a week
  before the pin. The claim was written into the consumer's own source as the
  justification for a workaround, where nothing would ever re-check it. The
  HEAD column is what catches this; the citation column is what makes the catch
  cheap.
- **A claim introduced by a re-teller.** A report assembled by summarising a
  consumer's code, rather than by the consumer, attributed to it a lost
  `role="alert"` the consumer had deliberately never rendered — its own comments
  said so. A summary is not a report. Whoever holds the pin writes the claim, or
  the claim names the file it was read out of so the substitution is visible.

A report may of course also carry things this format does not fit — a
measurement, a screenshot, a rendered geometry. Those are welcome and need no
ceremony. The format governs the sentence "Nopal cannot X", and only that.

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

Deferring a browser case is allowed; leaving it unrecorded is not — see
[Deferrals and decisions not to cover](#deferrals-and-decisions-not-to-cover)
for the `D-n` scheme these records follow.
**There is one current deferral (D-1) and four decisions not to cover
(D-2, D-6, D-10 and D-16).**

#### Open deferral D-1 — a relative-scroll request naming a container the frame removed

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

#### Decision not to cover D-2 — no browser case exercises a subscription receiving the back press

**Owner: whoever adds a router-less Tauri example to the repo — the same change
that discharges D-4 — writes the case in that change.**

`Platform_tauri.on_back_pressed` delivers the Android hardware back press as a
msg. Nothing under `test/e2e/` asserts that a subscription receives it, and that
is a decision, not an oversight. The only Tauri-hosted application `just
e2e-tauri` drives is the kitchen sink, which creates `back_router` and calls
`enable_hardware_back`. Subscribing it to `on_back_pressed` as well is cheap and
is the wrong case: the two are independent listeners on one event and both
`.mli` entries tell an application to pick one, so such a case would exercise
the configuration the API documents as a mistake and stand in for the
router-less one it is not. A faithful case needs an application with no router,
which the repo does not have — the same missing example D-4 waits on.

What is covered, observed on 2026-09-01 by reading the sources rather than
inferred: `test/e2e/tauri/back.e2e.ts` invokes the `simulate_back_pressed`
command over real IPC and asserts the resulting `Route_changed` through the
telemetry mirror, and `tauri/src-tauri/src/lib.rs` emits the literal
`nopal:back-pressed` from both that command and the Android `emit_back_pressed`,
which `backends/nopal_tauri/platform_tauri.ml` listens for in both of its
registrations. Delivery into a subscription — one listen, the Rust unit (`null`)
payload, no setup-time dispatch, unlisten, and that the press touches no
`history` — is covered by `test/unit/nopal_tauri/test_back_pressed.ml` against
`tauri_shim.js`.

What that leaves uncovered, stated so the sentence above cannot be read as more
than it is: no test in this repo runs `on_back_pressed` inside a real webview.
The hop being exercised is evidence about the event's transport, reaching the
*other* listener; it says nothing about this subscription's registration against
a real `plugin:event` implementation as opposed to the shim. A defect there
would pass every gate here. The first downstream consumer (grokkr) exercises it
on a handset.

When the case is written it asserts the MVU telemetry log and not the DOM, as
`back.e2e.ts`, `event.e2e.ts`, `store.e2e.ts`, `tray.e2e.ts` and `window.e2e.ts`
do. That is the convention, not a universal: `mobile_signals.e2e.ts` asserts the
DOM on purpose — it reads `[data-testid="safe-area-viz"]`, because a safe-area
inset feeds the viewport rather than a message and so has no telemetry event to
assert, which is the render-correctness case the project's E2E strategy reserves
for DOM assertions; the spec's own header (`:13-20`) states that reasoning at
the site. Observed on 2026-09-01 by reading the six specs: `getText` occurs
exactly once across `test/e2e/tauri/`, at `mobile_signals.e2e.ts:75`. The case
also carries the same `Phase 3: replace with Appium-driven OS event` marker
`simulate_back_pressed` does
(`tauri/src-tauri/src/lib.rs:39`). No mechanical gate is waiting on it: `just
check-e2e-wired` has nothing new to wire.

#### Decision not to cover D-6 — no browser case asserts a chart's axis chrome

**Owner: none, and that is the point.** Every other record here names the change
that discharges it. This one names no change and no moment, because the reason
not to write the case does not expire — a future kitchen-sink section or a
future chart type would face exactly the argument below. Challenge it by
disagreeing with the reasoning, not by waiting for the case.

`Nopal_charts.Axis.config` carries an `appearance` record — the axis line's and
the tick marks' colour and width, the tick length, and the colour and size of
the tick labels and the axis label. `test/e2e/tests/kitchen-sink-charts.spec.ts`
asserts none of it, and will not.

Observed on 2026-09-01 by reading the sources rather than inferred: charts are
`Element.draw` nodes, which `backends/nopal_web/renderer.ml:746` turns into a
single `<canvas>`, and every axis line, tick and label is painted into that
canvas's 2D context by `backends/nopal_web/canvas_renderer.ml`. None of them
reaches a DOM node. So there is nothing for a DOM assertion to read, and the
render-correctness carve-out this project reserves DOM assertions for has no
target: the only browser-side assertion available at all is a pixel sample
through `getImageData`.

Such a sample would depend on the `devicePixelRatio` scale
`Canvas_renderer.setup_hidpi` applies to the context
(`backends/nopal_web/canvas_renderer.ml:7-20`), on the chart's padding
arithmetic putting the axis where the test guessed, and on antialiasing at the
sampled coordinate — it would fail for reasons unrelated to the thing it claims
to check, and a flaky accessibility-adjacent test gets muted rather than fixed.
It would also catch the defect actually worth catching — an appearance field
never reaching the renderer — only when the sampled pixel happens to land on the
axis line.

The substitute is a pair of `Nopal_svg.render` byte comparisons in
`test/unit/nopal_charts/test_axis_svg.ml`: one over a default config, whose
expected string was captured before any renderer read an appearance field, and
one over a config naming a value distinct from the default in all eight fields.
Two fixtures and not one, because a default-only comparison proves nothing
changed rather than proving anything is plumbed through.

What that substitute does not reach, stated so the paragraph above cannot be
read as more than it is: it pins the *scene* a chart produces, not the browser
painting it. A defect in `canvas_renderer.ml`'s stroke or text handling — a
width ignored, a fill dropped — leaves both fixtures green, and no test in this
repo would catch it. That residue is accepted on the same grounds: the
assertion that would cover it is the pixel sample ruled out above.

The existing canvas presence and size assertions in
`kitchen-sink-charts.spec.ts` are unchanged by all of this. They cover a
different failure — a chart not rendering at all — but each of them locates its
subject by a named `data-testid`, so none reads the themed-axis chart
(`[data-testid="themed-axis-chart"]`). The only case that reaches it is the
section-level `charts section renders`, plus the `beforeEach` wait for
`[data-section='charts']`: the themed chart is a sibling of the others inside
that section, so a configuration that crashed the view would take both down with
it. Nothing asserts its canvas size, and nothing asserts its colours.

#### Decision not to cover D-10 — no browser case measures a horizontal minimum

**Owner: whoever first reports a horizontally scrolling row defeated by a
container's automatic minimum, in the change that reports it.**

`Style.layout` carries `min_width` and `min_height`, and both are first-class:
either one set to zero revokes the content-based minimum a flex item is
automatically allowed, which is what stops an ancestor of a scroll container
growing instead of letting that container scroll.
`test/e2e/tests/kitchen-sink-min-size.spec.ts` measures the vertical axis only,
and that is a decision, not an oversight. The kitchen-sink section declares
`min_height` and no `min_width` (`examples/kitchen_sink/sub_min_size.ml`), so
nothing in a browser exercises the horizontal one.

The mechanism is axis-symmetric. The automatic minimum is the item's
content-based minimum on the axis its container lays out, and `min-width: 0`
revokes it on a row exactly as `min-height: 0` revokes it on a column; nothing
in the field, in the emitter or in the reported defect distinguishes the two.
The axes differ only in which container the downstream report happened to be
about — a scrolling column at 200% font scale.

What is covered, and where: both clauses are pinned at the emitter by
`test/unit/nopal_web/test_style_css.ml` — `test_min_width_produces_css` and
`test_min_height_produces_css` assert each declaration on its own,
`test_min_size_zero_produces_css` asserts both axes at zero, and
`test_min_size_absent_when_none` asserts neither appears when unset. The zero
case is the one that carries weight, because zero is the value that does the
work and the neighbouring padding and `gap` idioms in that same emitter drop it.
`test/unit/nopal_style/test_style.ml` covers both fields symmetrically too:
`equal_layout_distinguishes_min_width` and `equal_layout_distinguishes_min_height`
each separate a zero from an unset, against a hand-written `equal_layout` with no
compiler backstop.

What that leaves uncovered, stated so the paragraph above cannot be read as more
than it is: no test in this repository shows a horizontal minimum changing
rendered geometry. The browser case exists to prove the mechanism reaches the
screen at all, and it does that once, on the axis that was actually reported. A
defect reachable only on the horizontal axis — a `min-width` the emitter writes
but a row layout does not honour — would pass every gate here. That is the same
shape D-8 accepts for `Fraction`: the case for not writing the second case is
that no layout has hit it, not that no layout can.

Which is also what discharges this: a report, not a count. A real layout in
which a horizontally scrolling row was pushed out by its container's automatic
minimum, and where that mattered. The change carrying that measurement adds a
horizontal declaration to the kitchen-sink section and the browser case that
measures it, and deletes this record. Nothing mechanical is waiting meanwhile —
`just check-e2e-wired` already matches the existing spec to a CI-run Playwright
project, and a new case inside it wires nothing new.

#### Decision not to cover D-16 — no browser case renders an untyped or a loading button in a form

**Owner: whoever makes a renderer read a button's submit behaviour or its
inertness from anything but the `Button` node's `button_type` and `disabled`
fields, in the change that does it.**

Two mutations leave `test/e2e/tests/kitchen-sink-button-semantics.spec.ts`
green (observed 2026-09-23: the browser spec exits 0 under each mutation), and
that is a decision, not an oversight. Flipping `Element.button`'s
default `button_type` from `Push` to `Submit` passes every browser case, and so
does passing a `Nopal_ui.Button`'s `disabled` alone, so that `loading` no longer
makes the button inert. Every button in the kitchen-sink section
(`examples/kitchen_sink/sub_button_semantics.ml`) names its type, and none is
loading, so neither mutated line reaches the browser.

Both lines are pure OCaml upstream of either renderer. Each one only chooses
the value of a field on the `Button` node, and both renderers read that node
identically. A browser case for either would re-test a value the structural
suite already pins:

- **The default type.** It is pinned by `test/unit/nopal_element/test_element.ml`
  `button_without_button_type_is_push` and by
  `test/unit/nopal_test/test_test_renderer.ml`
  `untyped_button_reports_type_button`. Both go red under the flip (observed
  2026-09-23: `dune runtest` exits 1).
- **Loading makes the button inert.** It is pinned by
  `test/unit/nopal_ui/test_button.ml`: "suppresses click" in the loading group
  and `loading_button_in_form_dispatches_nothing_on_click_or_enter` go red when
  `loading` stops reaching `disabled` (observed 2026-09-23: `dune runtest`
  exits 1).

What the browser does with those fields is covered in the browser. The
spec's `submit-enabled` and `push-enabled` cells measure both values of
`button_type`. Its disabled cells measure an inert button on the click route
and on the Enter route alike, and they go red if the disabled listener stops
cancelling the click.

What that leaves uncovered, stated so the paragraph above cannot be read as more
than it is: no browser case shows that a `Button` built without a type, or one
that is loading, answers as the matrix states. A renderer that derived either
answer from something other than those two fields would pass every browser gate
here. The owner above names that change, and it adds the untyped and loading
cells to the section and the spec, and deletes this record.

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
nopal_image        ← depends on mvu, no platform deps (Buffer, Luma, Sharpness, Config, Processing, Preview, Retention)
nopal_router       ← no platform deps
nopal_runtime      ← depends on mvu + element + lwd
nopal_web          ← depends on runtime + brr + js_of_ocaml
nopal_blob_web     ← depends on brr + js_of_ocaml (session-local blob handle registry
                     + displayable object URLs)
nopal_http_web     ← depends on nopal_http + nopal_blob_web + brr + js_of_ocaml
nopal_image_web    ← depends on nopal_image + nopal_mvu + nopal_blob_web + brr + js_of_ocaml
                     (public module is the three seams — Processing, Preview and
                      Retention; bindings live in the nopal_image_web.internal sub-library)
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

**A Typed Field Outranks the `~attrs` List**
Where an element builder takes both an `~attrs` list and a typed field a backend
renders as an attribute — `placeholder`, a radio's `name`, a picker's
`accept`/`capture`/`multiple`, `disabled`, a container's `focusable`, an input's
`required`/`autocomplete`/`input_type`, a form's `autocomplete`/`novalidate`, a
button's `button_type`/`disabled` — the rule is: **typed-field derivations
beat the `~attrs` list; within the list, the last pair wins.** Those are two
tiers and they are not the same tier. A typed field
sits above the list, so `~attrs` is an escape hatch for keys the DSL does not
model and cannot overrule the ones it does. A pair a component puts into that
list sits inside it, so a caller's later pair of the same name replaces it.

The second tier is the one a `nopal_ui` component author designs against. A
component's own `role`, `aria-describedby` or `data-field` is an ordinary pair
in the list it hands down, so a caller passing the same key through the
component's attributes replaces it. That is deliberate — it is the escape hatch
that keeps a consumer using the component rather than abandoning it — and a
component whose `.mli` promises a caller override is promising this tier, not a
guarantee enforced above it. A component that needs a value a caller cannot
replace needs a typed field, not a list pair.

A derivation that is absent uncovers rather than erases: a picker with no
`capture` leaves a `capture` the caller declared standing, because a typed field
saying nothing is not the same as it saying "no attribute". A derivation declines
in one of two shapes. A `bool` cannot say "no attribute": `true` asserts the key
and `false` emits nothing, so a `false` uncovers a caller's pair rather than
removing it — `disabled`, `multiple`, an input's `required` (with the
`aria-required` it carries), a form's `novalidate` and a button's
`aria-disabled` (from its `disabled`). An option or an empty
list asserts nothing when absent and uncovers the pair the same way — `accept`,
`capture`, an input's `autocomplete` and its `type` from `input_type`, and a
form's `autocomplete`. Some derivations have no absent form and are derived on
every render, so a caller's pair of that key is always replaced: `placeholder`,
a radio's `name`, a checkbox's, radio's or file picker's `type`, and a button's
`type` (from `button_type`, `"button"` when the button names none).

Two renderers enforce this and no more than two, by two different mechanisms:
`nopal_web` applies the declared list before it writes any derivation, and
`nopal_test` appends derived pairs after the declared list and resolves every
lookup to the last pair. The within-list half of the rule is one function,
`Nopal_element.Attrs.resolve`, which both call, so there is a single definition
of what a repeated key answers. `Element.draw` carries neither a `Style.t` nor an
`attrs` list and is structurally outside the rule. A backend nobody has written
is bound by nothing here — a rule holds where a test holds it.

The first tier is a rule both renderers hold on the keys `nopal_web` writes as
real attributes: `disabled`, `accept`, `capture`, `multiple`, `placeholder`, a
radio's `name`, a control's `type`, an input's `required`, `aria-required` and
`autocomplete`, a form's `autocomplete` and `novalidate`, and a button's `type`
and `aria-disabled`. Every one carries the same value in both renderers except
`disabled`, `multiple`, `required` and `novalidate`, which are a presence
attribute (`""`) in the DOM and `"true"` in the structural tree, so the two
agree on which side wins and not on the value; `aria-required` and a button's
`aria-disabled` are `"true"` in both, and a button's `type` is `"button"` or
`"submit"` in both. A checkbox's, radio's or file picker's
`type` is the structural node's tag, while an input's is a pair in both
renderers. A container's `focusable` is a first-tier
derivation in both, but each spells it in its own vocabulary — a tab-order
attribute in the browser, `focusable` in the structural tree — so there is no
shared key to compare. `checked`, `value` and `selected` are outside it. The browser carries those three as JS properties and never as
attributes, so a caller's `("checked", _)`, `("value", _)` or `("selected", _)`
pair reaches the DOM as an ordinary attribute and the typed field does not
overrule it there. `nopal_test` still overlays all three — a faithful read-out
of the typed field — but a structural assertion on one of them states what that
renderer answers and is not evidence about the browser.

Deferring part of the rule is allowed; leaving it unrecorded is not — see
[Deferrals and decisions not to cover](#deferrals-and-decisions-not-to-cover)
for the `D-n` scheme. **One record sits under this rule and it is discharged: the
position a derived pair takes in a node's `attrs` list (D-11).**

**One Submit Contract: the Nearest Handler That Accepts an Enter Consumes It**
An Enter in an `Element.input` can be answered by three handlers, and they are
consulted nearest first. The input's `on_keydown` comes first and is consulted
for every key; its `'msg option` return is the consumption signal — `Some`
dispatches and consumes, `None` declines. The input's `on_submit` comes second
and answers an Enter that `on_keydown` declined or that no `on_keydown` saw; it
answers no other key. The nearest enclosing `Element.form`'s `on_submit` comes
third and answers an Enter neither of the input's handlers did. A handler that
accepts the Enter consumes it, so an Enter reaches at most one of the three and
no handler the application supplied is silently dropped. That is not one
message per Enter: an Enter deferred to the form is the platform's implicit
submission, which clicks the form's default button, so that button's
`on_click` is dispatched before the form's `on_submit`.

The rule exists because three paths deciding independently is how the defect it
replaced arose: supplying `on_keydown` once made the web renderer install no
`on_submit` listener at all, so a handler the application wrote fired never and
reported nothing. The contract is therefore one pure definition,
`Nopal_element.Submit_route.of_key`, which both renderers call and neither
restates; a renderer that routes an Enter by its own logic is the defect coming
back. `element.mli` states the contract once, under *Submit contract*, and
`llms.txt` carries the same text.

Suppression of the platform default is narrower than consumption. Only an Enter
answered by one of the input's own handlers prevents the default, because Enter
is the only key that submits a form implicitly; a consuming `on_keydown` on any
other key leaves that key's default in place, so a keystroke recorder does not
stop its own input receiving text.

The rule has a cost, and it is stated rather than hidden: in a form where one
field carries its own `on_submit`, Enter in that field dispatches a different
message than Enter anywhere else in the form. Author submission at one level —
the form, or each input — and do not mix the two.

What a deferred Enter and a button press then do is the platform's share, and
it sits outside the route. The web renderer leaves it to the browser;
`Test_renderer.click` and `Test_renderer.keydown` model it, so the two
renderers answer it alike. A button submits its form only when it is typed
`Submit`; one that names no type renders `type="button"` and dispatches its
`on_click` alone, and a `("type", _)` pair in `~attrs` never takes effect on a
button. An unanswered Enter in a field clicks the form's first submit button in
tree order, dispatching its `on_click` and then the form's `on_submit`, or
nothing when that button is disabled, even if an enabled submit button follows
it. With no submit button, a form submits on Enter only when it holds a single
field that blocks implicit submission; structurally every `Element.input` is
one and no checkbox, radio, select or file picker is. A disabled button renders
`aria-disabled` rather than the native attribute, stays focusable, and cancels
its own activation, so it dispatches and submits nothing by any route. Because
the structural renderer now models these rules, its answer is only as good as
the model: `test/e2e/fixtures/button-submit-matrix.tsv` is asserted against
both it and Chromium, and a change to either rule changes that matrix first.
Constraint validation is not part of the model: the browser's own validation
(`required`, `pattern`, and the like, on a form without `novalidate`) can block
a submission that the structural renderer reports as dispatched.

**Every Visual Decision a Component Makes Is Overridable**
Every visual decision a `nopal_ui` component makes must be overridable without
abandoning the component. A decision with no override is a fork waiting to
happen, and a fork does not lose only the styling: a downstream consumer forked
a text input because the label's font weight and the label-to-box gap were
unreachable at every configuration, and the fork silently dropped the
label-to-control association the component had been making for it. The visible
cost was three lines of appearance; the invisible cost was the accessible name.

The rule rests on a three-way split, and getting a decision into the wrong
bucket is how the surface goes wrong:

1. **A visual decision** — colour, spacing, typography, a hover or pressed
   treatment — is overridden by a typed `Nopal_style.Style.t` or
   `Nopal_style.Interaction.t`, and never by an `~attrs` pair. A typed override
   cannot collide with the ARIA the component emits, which is the whole reason
   it is the mechanism: a caller restyling a control can never accidentally
   unname it.
2. **A semantic or metadata decision** — a `role`, an `aria-*` association, a
   `data-*` anchor — stays an ordinary pair in the `~attrs` list the component
   hands down. It is caller-replaceable at the second tier of *A Typed Field
   Outranks the `~attrs` List* above, and that is deliberate: the escape hatch is
   what keeps a consumer using the component instead of abandoning it.
3. **A value a caller must not be able to replace** needs a typed field, not a
   list pair. A pair in a list the caller can append to is a default, however the
   `.mli` words it.

**An override that compiles is not an override.** The failure this rule exists to
remove is a knob that does not reach the node, so a new mechanism is demonstrated
by setting it to a **non-default** value and asserting the rendered node changed.
A case that sets an override to the value the component would have used anyway
passes most loudly when the override reached nothing at all.

**Where two overrides land on the same node, the most specific wins and an absent
answer uncovers rather than clears.** A per-element setter answering `Some` beats
the component-wide one; answering `None` leaves the component-wide one standing
rather than blanking the node. That is the same semantics as an absent derivation
in the attribute rule above, and every such ordering is stated at both signatures
rather than left to be discovered.

**A decision that is structural rather than visual is named, not hidden.** Some
decisions must not be reachable — a modal backdrop that does not cover the dialog
is not a backdrop, and a tab bar that does not clear the gesture bar cannot be
tapped. Those are recorded at their own signature, with the reason, and with the
scope stated: whether the component *forces* a field back over the caller's style
(and which other fields still replace as usual), or merely *fills one in* when
the caller expressed no opinion. An uncited forcing is not an exemption; it is an
unreached decision that has not been noticed yet.

**This is checked when a component is added, and when a component gains an
element.** The enumeration — component × visual decision × override mechanism —
lives in `llms.txt` under `### UI Components`, and no cell in it may read "fork".
Adding a component without adding its rows leaves the claim that table makes
false; adding an element inside an existing component without giving it a
mechanism is the same defect one level down, and it is the shape that produced
the fork above.

Deferring part of the rule is allowed; leaving it unrecorded is not — see
[Deferrals and decisions not to cover](#deferrals-and-decisions-not-to-cover)
for the `D-n` scheme. **Two records sit under this rule: a decision not to
cover a toast's message typography and the `llms.txt` prose no test reads
(D-13), and a decision not to cover the invalid appearance of a `required`
input (D-14).**

#### Discharged deferral D-11 — the node `attrs` list order

**Discharged by `test/unit/nopal_ui/test_aria_survival.ml`,
`derived pairs sit at the back`.**

`nopal_test` moved its derived pairs from the front of a node's `attrs` list to
the back, which is what makes the last-pair lookup answer the derivation. Every
lookup on that list was pinned from the start — `attr`, a `By_attr` selector and
the selector an event simulation resolves all assert the winner. The *position*
was not: every whole-node fixture in the suite
(`test/unit/nopal_element/test_element_form.ml`, the three `node` comparisons)
declares no caller `attrs` at all, so `[] @ derived` and `derived @ []` are the
same list and the prepend-to-append move reddened nothing.

This matters because `Test_renderer.node` exposes `attrs` publicly, so a
downstream suite doing whole-list equality on a node sees a changed list with no
compiler help — which is why the move is published in `llms.txt` under
"Attribute answers that moved" rather than left to be discovered.

A labelled `nopal_ui` control is the fixture the record was waiting for: the
component contributes its own naming pairs and its anchor, the caller's `~attrs`
list follows, and the renderer appends what it derives from the typed fields. The
discharging case asserts that node's **whole** list rather than a lookup on it, so
a prepend reddens it even where no derived key collides with a declared one — the
case that `attr`-level pins cannot see. It asserts the resolved winner on the same
fixture too, so the position and the tier are pinned together; that the two wanted
one fixture is what had kept the record open.

#### Decision not to cover D-13 — a toast's message typography, and prose no test reads

**Owner for the typography row: whoever first reports a toast message whose
typography did not follow the toast's own style, in the change that reports it.
Owner for the prose: whoever next edits the audit summary under `llms.txt`
`### UI Components`, in the change that edits it.**

Two parts of the rule's first application are carried by prose rather than by a
test. Both are named here so the rule above is not read as claiming more than it
covers.

**A toast's message typography.** A toast's message is an `Element.text` child of
the toast's own button (`lib/nopal_ui/toast.ml:157`), so the `text` component of
the toast's style reaches it by CSS inheritance and not by any pair on the
message node itself. `nopal_test` models no inheritance, so a structural case
cannot observe that override at all: it would read the message as unstyled while
a browser renders it styled — which is the shape *An override that compiles is
not an override* exists to catch, arriving from the other direction. The proof
that row wants is therefore a web-backend case, and none was written; the row at
`lib/nopal_ui/toast.mli:118-122` states the mechanism and asserts nothing about a
rendered node.

**The precedence rules and the structural exemptions in `llms.txt`.**
`test/unit/nopal_ui/test_change_list.ml` pins the *change list* — each attribute
row and each tree row, in both directions — and nothing else. The four
precedence bullets are pinned indirectly, by component cases in `test_toast.ml`,
`test_button.ml`, `test_data_table.ml`, `test_navigation_bar.ml` and
`test_bottom_tabs.ml`; the four structural exemptions are pinned by nothing.
Nothing mechanical joins either set to the `llms.txt` text, so prose edited
without the components, or components edited without the prose, reddens no test.

Why this is a decision rather than work owed now: an exemption states that a
decision must *not* be reachable, and a test of that asserts the absence of a
mechanism — which passes exactly as loudly for a component that never had the
mechanism as for one that correctly keeps forcing it. Neither part is discharged
by a count. What discharges the typography row is a report of a toast message
whose typography did not follow its style; what discharges the prose is the next
edit to the audit summary, which either brings the text under a test or restates
here why it still is not.

#### Decision not to cover D-14 — a `required` input's invalid appearance

**Owner: the change that adds an `invalid` state to
`Nopal_style.Interaction`, in that change, taken together with an `outline`
field on `Style.paint`.**

`Element.input ~required:true` ships with the browser's own invalid appearance
and nothing else, and no caller can restyle it. It is unreachable rather than
merely unwired: `Nopal_style.Interaction.t` has exactly three states — `hover`,
`pressed`, `focused` — so there is no state for an invalid style to hang on, and
`Style.paint` carries no `outline`; neither an invalid state nor an outline is
spelled anywhere in `nopal_style` or `nopal_web`.

Why this is a decision rather than a violation of the rule above: the rule is
about decisions a *component* makes, and this appearance is the browser's, not a
`nopal_ui` component's. Withholding `required` would not hand a consumer the
styling either — it would only withhold the semantics, the constraint validation
and the `aria-required` exposure, all of which work today. Adding the state here
would widen a form feature into `nopal_style` and the interaction pipeline,
which is a feature of its own and is already owed for `outline`, a gap with no
record of its own until this one. The record is discharged by the change that
gives `Interaction` an `invalid` state and `Style.paint` an `outline`, together,
and demonstrates the override on a `required` input set to a non-default value.

#### Decision not to cover D-15 — `nopal_ui.Text_input` pass-through of the three typed fields

**Owner: whoever next touches `Text_input`, or a follow-up feature, in that
change — routed through 0142's `with_*` convention.**

`lib/nopal_ui/text_input.ml:78` builds its `Element.input` without
`?required`, `?autocomplete` or `?input_type`, so a `Text_input` caller cannot
reach any of the three typed fields that `Element.input` added. This was Part 1
of 0143, which is frozen; the pass-through is Part 2 scope and is recorded here
rather than by editing the frozen Part 1 requirements. The record is discharged
by the change that adds `with_required`, `with_autocomplete` and
`with_input_type` (or equivalents) to `Text_input`, following the `with_*`
convention `Nopal_ui` established in 0142.

**A Typed Size Is a Guarantee, Not a Hint**
`Style.size` states what a dimension of an element is, and a backend has to
deliver it. An element whose size on its parent's main axis is `Fixed` is not
squeezed below that size to make room for a sibling's content, and it does not
collapse away when it holds no content of its own to keep it open. The guarantee
runs in the shrink direction only: `flex_grow` set beside a `Fixed` size still
makes the element larger, and that is the caller asking for it, not the size
being disregarded.
`Fill`, `Hug` and `Fraction` are the flexible spellings and keep giving way —
`Fill` resolves two siblings to half a container each only by giving way — so
freezing them would break every layout in the framework. Which axis is the main
axis belongs to the element's *parent*, never to the element: a renderer deciding
it from the element's own `direction` is wrong by one level of the tree, and a
`Row` inside a `Row` hides that it is. Deferring part of the guarantee is
allowed; leaving it unrecorded is not — see
[Deferrals and decisions not to cover](#deferrals-and-decisions-not-to-cover)
for the `D-n` scheme. **Two records sit under this rule: a decision not to
cover (D-8), and an open deferral naming three routes the guarantee does not
reach (D-9).**

#### Decision not to cover D-8 — a `Fraction` size is still squeezed

**Owner: whoever first reports a `Fraction` size that did not survive, in the
change that reports it.**

The guarantee above is delivered for `Fixed` and for nothing else. `Fraction f`
asks for the fraction `f` of its container on the same axis, is shrunk below it by
the same mechanism under the same pressure, and deliberately keeps that
behaviour.

Two reasons, and one thing this record does not claim. First, nothing has
reported it and nothing here would notice: `grep -rn 'Fraction' lib/ backends/
examples/ --include=*.ml --include=*.mli`, run on 2026-09-12, returned not one
line that constructs a `Fraction` — every hit is the type itself, its equality
arm, the size emitter's arms, or prose — so no example and no view in this
repository uses the spelling. The `Fixed` guarantee, by contrast, was written
against a downstream report of measured columns that had turned fluid. Second,
freezing a percentage is a different judgement from freezing a length. Fractions
summing past the whole are easy to author by accident and are absorbed today by
shrinking, while a set of `Fixed` sizes adding up to more than its container is a
number someone typed; making fractions rigid converts those accidents into
overflow, which may well be right and is a change to argue on its own evidence.

What this record does not claim is that a `Fraction` cannot disappear the way an
empty `Fixed` box did. That disappearance came from the minimum size a squeezed
box is allowed on the web, which is derived from its content and not from the
length it declared, so the same collapse is plausible here; nobody has measured
it either way. The case for leaving `Fraction` alone is that no layout has hit
it, not that no layout can.

Which is also what discharges this: a report, not a count. A real layout where a
`Fraction` was measured smaller than it declared and where that mattered. The
change carrying that measurement extends the guard and deletes this record.

#### Open deferral D-9 — three routes the shrink guard does not reach

The guarantee above is delivered by the web backend emitting `flex-shrink: 0`
beside a `Fixed` main-axis size, and that emission needs the axis of the
element's *parent*. Three routes never supply one, so a `Fixed` size travelling
any of them is an ordinary flex item at the CSS default shrink and is squeezable
exactly as it was before the guarantee existed. What these routes withhold is
the shrink guard specifically, and not every protection a size can have:
`Style.layout`'s `min_width` and `min_height` need no parent axis — a floor is a
statement about one element, not about how it competes with a sibling for room —
so they are emitted wherever `Style_css.of_style` is reached, an interaction
state and the mount root included. The third route below is outside that, and
for a different reason: a `Draw` carries no `Style.t`, so it has nowhere to
declare a floor either. A layout that needs a floor on one of the two routes
that do carry a style can have one; what it cannot have is the `Fixed`
guarantee. Each route is recorded rather than fixed, for the reason given under
it, and each has its own owner.

**An interaction state.** `Style_css.interaction_rules` resolves `hover`,
`focused` and `pressed` with no parent axis, because it is handed an
`Interaction.t` and not a position in the tree. All three fields are full
`Style.t` values, so a size is expressible in them from the public API; where an
interaction state introduces a `Fixed` main-axis size the base style does not
declare, the element is squeezable for exactly as long as that state is active.
Nothing hits this today: every `Interaction.t` constructed in `lib/` and
`examples/` on 2026-09-12 sets paint fields only, and no size is declared in an
interaction style anywhere in the repository. Threading the axis in was weighed
and declined: it widens three signatures, and the interaction dedup key in
`Style_sheet` would have to carry the axis too, or two identical interactions
under different parent axes would share one rule. The limitation is pinned by
"no shrink guard in any state" in `test/unit/nopal_web/test_style_css.ml`, so
changing it is a decision rather than an accident.
**Owner: whoever first declares a size in an interaction style, in the change
that declares it.**

**A `Draw`.** `Element.draw` carries no `Style.t` at all, so the style path is
never walked for it; its size is written as inline `width` and `height` by the
canvas setup that gives it a HiDPI backing store. It is a flex item all the
same, whenever it sits in a `Box`, `Row` or `Column`. This one is structural
rather than hypothetical — the guard cannot reach a `Draw` by any call site,
because there is no style to put it in. Adding the property in the canvas setup
was weighed and declined on two grounds: it writes a CSS string outside the one
module allowed to generate them, and it changes the layout of every chart in the
framework without anyone having asked for that.
**Owner: whoever first reports a `Draw` rendered narrower than the size its
canvas was set up at, in the change that reports it.**

**The mount root.** The renderer creates and reconciles the root element with no
parent axis, because the mount target was not built by this backend and how it
lays its children out is not knowable from inside. That is right when the host
lays nothing out, and wrong when the host page has made the mount target a flex
container: a root sized `Fixed` is then squeezable and nothing here can tell.
A host that hits this today can wrap its root in a container of its own, which
does have an axis.
**Owner: whoever gives the mount API a way to state the host's axis, in the
change that adds it.**

One thing this record does not defer is the tie between the guard's domain and
the set of variants the backend lays out as flex containers.
`Renderer.container_main_axis` answers `Some` for exactly the four variants
that call `apply_container_base_style`, and a comment at each end says so; a
fifth flex container added without a matching arm would un-guard that variant's
children with the whole suite green, so the two are changed together rather than
watched.

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

**There is one current decision not to cover (D-5) and one open deferral
(D-7)** — see [Deferrals and decisions not to cover](#deferrals-and-decisions-not-to-cover)
for the `D-n` scheme.

#### Decision not to cover D-5 — the catalogue pointers name a tree this repository does not ship

**Owner: whoever next adds, removes or renumbers a bug-class rule in this
section, in the change that does it.**

`docs/` is listed in `.git/info/exclude` — `git check-ignore -v docs` names line
12 of that file, and `git ls-files docs` returns nothing — so it is not in any
clone. Every `docs/…` pointer in this repository is therefore dead for everyone
who is not the author on the author's machine. This is the only place the
project says so, and it is said here because this section is where an
implementer is most likely to follow one.

The six pointers above are left standing rather than rewritten:
`docs/ANALYSIS.md` in this section's opening sentence, and
`docs/bug-classes/0001` through `0005` on the five numbered rules. Each rule
states its own guard, names a shipped reference implementation, and for four of
the five names its `just lint-classes` class, so the pointer is decoration on a
rule that is already actionable without it. Rewriting the five paragraphs is a
documentation change of its own and is not part of a feature.

Two other committed sites keep such pointers and are deliberately left too.
`llms.txt` cites the excluded tree six times (`feature 0122` at :2099, `RFC 0110`
at :2452, `ADR 0108` at :2526, `REQ-N1` at :2612, `RFC 0077/0107` at :2652 and
`docs/guides/telemetry-tauri.md` at :2653). Source comments carry 266
`REQ-*`/`NFR-*`/`FR-*` tags across 88 `.ml`/`.mli` files, 18 of them under
`backends/nopal_tauri/`. Two of those now read inconsistently against a file in
their own package, observed on 2026-09-01: `backends/nopal_tauri/os.mli:24`
still tags `NFR-1` on the desktop-zero-inset contract whose tag
`backends/nopal_tauri/platform_tauri.mli` dropped in the same change that added
this record, and `examples/kitchen_sink/main.ml:861-866` still tags
`(REQ-F3, idempotent)`, `(REQ-F4)`, `(feature 0121, FR-1)` and `(NFR-1)` at the
call site of `enable_hardware_back` and `safe_area_source`. Sweeping 266 tags is
not a feature's work either; the inconsistency is recorded here so it is not
rediscovered as a defect. Tags are stripped opportunistically from the files a
change already touches — the change that added this record dropped
`platform_tauri.mli`'s, and the one that added D-6 dropped the eight on
`lib/nopal_charts/axis.mli` and `lib/nopal_charts/bar.mli`, leaving ten tagged
`.mli` files in `lib/nopal_charts/` — so what is deferred here is the sweep, not
the strip.

`scripts/check-e2e-wired` is the one such site that was fixed rather than
deferred. It printed its pointer to a person at the moment its gate failed,
which is the worst place for a reference that cannot be opened; it now states
the rule and cites this section.

#### Open deferral D-7 — a settled upload in the reference capture flow keeps the encode it sent

**Owner: whoever next changes the upload stages of the reference capture flow in
`test/unit/examples/test_image_processing_flow.ml`, in the change that does it.**

That flow is the canonical minimal capture app — picker, `Processing` pass,
upload — and a consumer copies it. It releases the handles it stops holding at
three of its four transitions (cleared picker, replaced selection, retake), added
with the release seam `Nopal_image.Retention` on 2026-09-11. The fourth is not
done: when an upload settles, the `Sending info` payload is dropped, so the
encode it sent becomes unreachable from the model and stays resident for the rest
of the page session — a stranded handle of the same kind the seam exists to
remove, differing only in that it is a reference example rather than a library.

It is deferred rather than fixed because the fix is not local. `Send_finished`'s
arms currently match no stage at all, so releasing there means matching all eight
stages exhaustively — the catch-all `_` this document forbids is not an option —
and that changes behaviour for a reply arriving after the flow has moved on,
which the flow has no case for today. That is a behaviour change with its own
design question, not a line added beside three others, and it was kept out of the
change that added the other three deliberately.

The pattern to copy already exists: the kitchen-sink receipt section covers the
same transition with `test_a_finished_upload_releases_both_handles` in
`test/unit/kitchen_sink/test_receipt_flow_section.ml`, including the reason it is
safe to release there (the section hides its discard control while an upload is
in flight, so the bytes in flight are never the bytes released).

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

Deferring a benchmark obligation is allowed; leaving it unrecorded is not — see
[Deferrals and decisions not to cover](#deferrals-and-decisions-not-to-cover)
for the `D-n` scheme.
**There is one current deferral (D-3).**

### Open deferral D-3 — the committed baseline is stale, so read it relatively

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
Deferring that section is allowed; leaving it unrecorded is not — see
[Deferrals and decisions not to cover](#deferrals-and-decisions-not-to-cover)
for the `D-n` scheme. **There are two current deferrals (D-4 and D-12).**

#### Open deferral D-4 — `Platform_tauri.on_back_pressed`

**Owner: whoever adds a router-less example to the repo, in the change that adds
it.**

`on_back_pressed` delivers the Android hardware back press as a msg, for an
application that installs no `Router`. The kitchen sink cannot demonstrate that,
because it *is* a routed application: it creates `back_router` and calls
`enable_hardware_back`, and the two are independent listeners on one event, so a
kitchen-sink subscription would demonstrate only the double-effect case the docs
tell applications to avoid — not the router-less case the capability exists for.
Showing it properly needs an example with no router, which the repo does not
have.

The missing section is not itself the coverage gap: `test/unit/nopal_tauri/
test_back_pressed.ml` drives the whole path a host emit takes — registration,
delivery of a Rust unit (`null`) payload, no setup-time dispatch, unlisten, and
that the press touches no `history` — against the same `tauri_shim.js` the other
Tauri suites use. What no test in *this* repo covers is this subscription
running inside a real webview. That gap is D-2, which records it as a decision
not to cover, says what the existing Tauri spec does and does not reach, and
names who writes the case.

`nopal_image_web` was the previous one. Its section is the kitchen sink's receipt
flow, and `test/e2e/tests/kitchen-sink-receipt-flow.spec.ts` drives the real
canvas pipeline through it — decode, sharpness, downscale, re-encode, and the
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


#### Open deferral D-12 — the `nopal_ui` overrides with no kitchen-sink demonstration

**Owner: whoever next edits each of the `Button`, `Data_table`, `Modal`,
`Navigation_bar` and `Bottom_tabs` kitchen-sink sub-sections
(`examples/kitchen_sink/kitchen_sink_ui.ml`, `sub_data_table.ml`,
`sub_modal.ml`, `sub_navigation_bar.ml`, `sub_bottom_tabs.ml`) — the
demonstration goes in beside whatever else that change adds, and the component
leaves this record when its own sub-section carries it.**

*Every Visual Decision a Component Makes Is Overridable* gave every `nopal_ui`
component an override for every visual decision it makes. The kitchen sink
followed for five of them in the same change: `Text_input`
(`kitchen_sink_text_input.ml`), `Checkbox`, `Radio_group` and `Select_input`
(`kitchen_sink_form_controls.ml`), and `Toast` (`sub_toast.ml`). It did not
follow for the setters added to `Button`, `Data_table`, `Modal`,
`Navigation_bar` and `Bottom_tabs`: those sub-sections exist, and they are
untouched. **None of the setters on those five components is exercised in a real
browser.** Playwright drives the kitchen sink and nothing else, so a setter with
no section there has no browser-level evidence of any kind.

What they do have is the coverage the rule itself demands, one layer down. Each
is exercised in `test/unit/nopal_ui/` with a **non-default** value and asserted
to change the rendered structural node — never set to the value the component
would have used anyway, which is the pass that means nothing — and each
assertion is mutation-proved: reverting the setter's application in the
component reddens its case. That is what makes this a deferral of the
demonstration rather than of the mechanism.

What the deferral therefore costs is what only a browser shows: that the style
survives the web renderer's own derivations, that an interaction override
resolves in real `:hover` and `:active` rules rather than in the structural
read-out of them, and that nothing in the cascade overrides the override. The
per-component sub-sections are the right home for each, which is why the owner
is the next change to touch one rather than a single change owning all five —
each discharges its own share, and this record shrinks as they land.
