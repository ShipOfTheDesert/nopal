# Nopal — Project State, Architecture & Bug Analysis

> Date: 2026-06-11. Audited at HEAD `a47f71c` (feat: nav stack & bottom tabs #61)
> plus the uncommitted F-3b working tree. `dune build` and `dune runtest` both
> pass at the time of this analysis — see "Why green tests coexist with all
> this" below for why that is not contradictory.

## TL;DR

The project is in good shape structurally — Phase 1 is complete, Phase 2 is
~85% done, the dependency architecture is genuinely clean, and the build/tests
pass. But the audit found a cluster of real correctness bugs concentrated in
exactly two places: **runtime/subscription lifecycle** (the MVU loop can
permanently wedge; five documented `Sub` constructors are silent no-ops) and
**keyed DOM reconciliation** (three related holes causing permanent node
duplication and focus loss). Separately, the committed Tauri binding layer is
in worse shape than its green tests suggest: `Store` is entirely
non-functional against the pinned plugin version, and most Tauri ops swallow
errors in a way that hangs `Task` chains forever.

## Current state

- **Done:** All of Phase 1; Phase 2 features F-12/13/14/14b (Tauri
  shell/FFI/platform/Task.t), F-17 UI library, F-1 offline storage (#58), F-2
  telemetry + E2E suite (#59/#60, ADR 0108), F-3a Nav_stack + Bottom_tabs
  (#61).
- **In progress (uncommitted, Task 8/8):** F-3b mobile build pipeline (PRD
  0115 / RFC 0116) — Android/iOS builds, safe-area + keyboard-height signals,
  hardware back, iOS CI. Pixel 7 manual acceptance has passed per the RFC's
  post-implementation notes.
- **Remaining Phase 2:** F-4 real app prototype, F-5 Tauri/native benchmarks.
- **Phase 3:** Impeller native renderer (unscoped).
- `CLAUDE.md`'s Current State block is accurate; planning docs, PRD 0115, RFC
  0116, and the ADRs are internally consistent.

## Architecture: what's sound

The non-negotiable rules are actually holding. No Brr/js_of_ocaml types leak
into the pure packages (verified via dune deps for `nopal_element`,
`nopal_style`, `nopal_scene`, `nopal_navigation`, `nopal_mvu`, `nopal_test`);
`Nav_stack` is total and correct; `Router`/`Platform.NAV` are sound; no
`style:string`, no partial list functions, mutable fields carry justifying
comments; the uncommitted mobile work keeps `nopal_web` Tauri-agnostic via an
opaque `safe_area_source` function and keeps the kitchen-sink App module
platform-pure.

The single most valuable change in the working tree is the `event.ml` Tauri
2.10 wire-format fix — at HEAD, **every** Tauri event listener fails silently
(missing `target` arg, wrapped handler id, error swallowed), which means the
committed tray e2e cannot actually have been exercising the committed code
path.

## High-severity bugs (committed code)

1. **MVU loop wedges permanently after any exception** —
   `lib/nopal_runtime/runtime.ml:133-149`. `dispatch` sets
   `processing <- true` with no `Fun.protect`; if `update`, `subscriptions`, a
   `Perform` thunk, or a telemetry serializer raises, the flag never resets
   and every later dispatch silently enqueues forever. The app dies with no
   error. The codebase elsewhere anticipates raising `update`s, so this is
   reachable.

2. **Five public `Sub` constructors are silently inert on every platform** —
   `Sub.every`, `on_keydown`, `on_keyup`, `on_resize`,
   `on_visibility_change` are documented in `lib/nopal_mvu/sub.mli:16-33` but
   no interpreter exists: `Sub_manager.diff`
   (`lib/nopal_runtime/sub_manager.ml:6-12`) handles only `Custom`, and
   `nopal_web` interprets only `on_keydown_prevent` and viewport changes. The
   `extract_*` helpers have zero non-test call sites. Either implement them or
   remove them from the `.mli` before any external adoption — a silent no-op
   API is the worst failure mode for a framework.

3. **`Nopal_tauri.Store` is entirely non-functional** —
   `backends/nopal_tauri/store.ml:4-6` sends
   `("store", "nopal_store.json")` to `tauri-plugin-store` 2.4.2, which
   requires an `rid` obtained from `plugin:store|load` — never called. Every
   `get/set/delete/clear/save` fails arg deserialization; the kitchen-sink
   Store section can only ever show errors.

4. **Keyed reconciliation has three related holes** in
   `backends/nopal_web/renderer.ml`:
   - Old non-keyed children are orphaned when new children are all keyed
     (`renderer.ml:954-975`) — the old node stays in the DOM forever,
     listeners leaked.
   - A keyed child whose root variant changes (Box↔Text etc.) loses its
     `data-key` on replace (`renderer.ml:925-936`, `:1035-1043`), then
     duplicates permanently on the next frame.
   - Reordering unconditionally re-appends every keyed child
     (`renderer.ml:946-951`), which blurs focused inputs and resets
     scroll/selection — editing an input inside a keyed list loses focus on
     *any* model change. This is the TodoMVC-edit-row scenario keyed rendering
     exists for.

## Medium-severity bugs

- **Tauri task error paths never resolve** — systemic across `window.ml` (all
  14 ops), `os.ml`, `app.ml`, `tray.ml`, and `event.ml` emit: on IPC failure
  they `Console.error` and never call `resolve`, so any `Cmd.task` chain
  hangs forever. `store.ml` and both storage backends do it right (resolve a
  `result`); converting the rest is the single highest-leverage systemic fix,
  and it would have surfaced bug #3 and the tray issues immediately instead
  of hiding them.
- **`Tray.set_icon/set_tooltip/set_visible` can never work** —
  `backends/nopal_tauri/tray.ml:69-115` uses `rid = 0`, but the tray is built
  in Rust (or ksni on Linux) and has no webview resource id.
  `Tray.on_double_click` is also dead: no Rust path ever emits `"Double"`,
  and click semantics differ per OS.
- **Late async completions raise after shutdown** —
  `lib/nopal_runtime/runtime.ml:152-162` guards `schedule_after` against
  shutdown but not the `dispatch` closure given to `Perform`/`Task`; an HTTP
  response arriving after shutdown raises `Invalid_argument` inside a JS
  callback. In-flight tasks are never cancelled at shutdown.
- **`Cmd.focus` races the deferred render** — focus runs synchronously in
  dispatch but the DOM patches on the next rAF, so focusing an element
  created by the same `update` silently no-ops
  (`lib/nopal_mvu/cmd.ml:94`, `backends/nopal_web/nopal_web.ml:62-65`).
- **Stale inline styles are never cleared** —
  `backends/nopal_web/renderer.ml:903-915` applies new props but does not
  remove ones absent from the new style (removing a background leaves it
  painted). Relatedly, interactive styles are diffed by physical equality
  (`renderer.ml:1061-1090`), so every interactive element churns the CSSOM
  (delete/insert rule + class swap) on every damaged frame, with unbounded
  class-name growth in `style_sheet.ml`.
- **Test renderer can't reach handlers in a scrolled `Virtual_list`** —
  `lib/nopal_test/test_renderer.ml:360-368` registers handlers under absolute
  item indices but `resolve_path` (`:633-641`) assigns positional ones; any
  nonzero scroll offset makes `click`/`input` return `No_handler`. All
  current tests use `offset:0.0`, which is why CI is green. This is
  load-bearing test infrastructure.
- **`Task.cancellable` can drop its result** —
  `lib/nopal_mvu/task.ml:22-44`: if cancellation aborts the underlying I/O
  after the synchronous prefix, neither `Ok` nor `Error "cancelled"` is
  delivered, violating the `.mli` contract. Cancellation is also signalled by
  the magic string `"cancelled"`, which `nopal_http` pattern-matches —
  indistinguishable from a genuine error string.
- **IndexedDB connections never closed** —
  `backends/nopal_storage_web/nopal_storage_web.ml:11-16` opens a fresh DB
  per operation; a future schema-version upgrade will block on the un-closed
  handles.
- **`Downsample.lttb` raises on `target <= 1`** — reachable via
  `target_for_width` on a zero-width container
  (`lib/nopal_charts/downsample.ml:11-17`); violates the no-raise rule on a
  public API.

## Low-severity / latent issues

- `renderer.ml:1210` sets `input.value` unconditionally each damaged frame:
  caret jumps to end whenever `update` transforms the value; IME composition
  hazard.
- Telemetry semantics diverge: browser `getEvents` drains
  (`telemetry_bridge.ml:80-87`), host `get_telemetry` does not, and Rust
  `TelemetryMirror` grows unbounded (`tauri/src-tauri/src/lib.rs:10-18`).
- `lib.rs:93` `tray.spawn().unwrap()` panics the tray thread on hosts without
  a StatusNotifier watcher.
- `nopal_web.drive` re-extracts subscriptions every rAF frame even when idle;
  rAF loop, ResizeObserver, and global keydown listener have no unmount path
  — multiple mounts leak.
- Keyed `Empty` children (comment nodes) cannot carry `data-key` and leak one
  orphaned comment node per reconcile.
- `canvas_renderer.ml:294-301` `clear_rect` under-clears when
  `devicePixelRatio < 1`; dpr changes never re-run `setup_hidpi` unless
  logical size changed.
- Select reconcile: a `selected` value matching no option silently leaves the
  browser-chosen first option — DOM diverges from model.
- `Sub_manager.diff` re-entrancy edges: a raising `setup` leaves a permanent
  no-op placeholder; duplicate subscription keys are silently first-wins with
  no report.
- `Element.equal` uses polymorphic `=` on `'msg` payloads (raises on
  closures) and ignores all `Draw` handler fields (test-only callers today).
- `nopal_http.default_cancellable_backend` permanently wraps the backend
  registered at module init; later-registered backends are bypassed for
  direct users of that constant.

## Issues in the uncommitted mobile work (F-3b, Task 8/8)

The new work is architecturally clean and the tests are substantive, but four
things are worth fixing before commit:

1. **iOS safe-area regression** (`examples/kitchen_sink/main.ml:705-712`):
   `safe_area_source` is gated on `has_tauri ()`, which is true on iOS — but
   there is no iOS native bridge, so the source delivers zero insets *and*
   disables the CSS `env(safe-area-inset-*)` fallback that the new
   `viewport-fit=cover` would have made work in WKWebView. iOS is strictly
   worse than not passing the source at all. Gate it on Android.
2. **Hardware back is not actually wired**: `emit_back_pressed` in
   `tauri/src-tauri/src/lib.rs:853` is dead code and `MainActivity.kt` has no
   back interception — only the debug `simulate_back_pressed` command emits
   the event. Real-device back works only via wry's generated `canGoBack()`
   fallback, so the `.mli` doc and RFC claim ("fired by the Android hardware
   back button") is currently false and the e2e proves only the simulated
   chain. Either wire `OnBackPressedCallback` in `MainActivity.kt` or correct
   the docs.
3. **Fresh-clone Android builds fail late and dangerously**: `gen/android` is
   gitignored except `MainActivity.kt`, so `just dev-android` on a fresh
   checkout fails deep inside Tauri — and the documented remedy,
   `tauri android init`, silently overwrites the hand-written safe-area/IME
   bridge in `MainActivity.kt`. Add a guard in the justfile that detects the
   missing project and prints the init + `git checkout -- MainActivity.kt`
   sequence.
4. **Listener-cleanup race pattern**
   (`backends/nopal_tauri/platform_tauri.ml:187-222`, same shape as the
   committed tray code): if a `Sub.custom` cleanup runs before the async
   `plugin:event|listen` promise resolves, the unlisten is stashed where
   nothing reads it and the native listener leaks for the page lifetime. Low
   impact today, but this is now the template for all future Tauri subs.

Minor: `.github/workflows/ios.yml:47` uses `dune-cache-prefix` (invalid
input; should be `cache-prefix`, copying a pre-existing typo in
`.github/actions/ocaml-deps/action.yaml:12`); the simulator grep extracts
"iPhone 16" from "iPhone 16 Pro" lines and the bundle-id grep needs `-F`;
`MainActivity.kt`'s `report()` interpolates payloads into a JS string (safe
with the current numeric grammar, JS-injection-shaped for future payloads)
and its fixed 600/1800 ms inset re-dispatch can lose initial insets on slow
first loads.

## Why green tests coexist with all this

A pattern worth naming: most of these bugs live behind **silently swallowed
errors** (Tauri ops that log-and-never-resolve, `Event.listen` rejections
discarded at HEAD) or **untested parameter regions** (virtual list at offset
0, keyed lists that never transition variants, subs nobody returns). The
telemetry-based E2E strategy (ADR 0108) is good, but it can only see messages
that get dispatched — it is structurally blind to "the effect never fired at
all." The log-and-never-resolve pattern defeats it by construction.

## Recommended priority order

1. Exception-safe the dispatch loop (`Fun.protect` in `process_queue`) and
   guard late `dispatch` after shutdown — small, fixes the worst failure
   mode.
2. Make all Tauri ops resolve `('a, error) result` like `store.ml` already
   does — systemic, unhides everything else.
3. Fix or delete the five inert `Sub` constructors and the dead `Tray` rid-0
   ops / `on_double_click` from the public `.mli`s.
4. Fix the three keyed-reconciliation holes plus move-only-when-out-of-place
   reordering, with tests for the keyed↔non-keyed and variant-change
   transitions.
5. Rewrite `Store` against the `plugin:store|load`/rid protocol.
6. The four uncommitted-work fixes above, before F-3b lands.
7. Fix the test-renderer virtual-list path resolution so future virtual-list
   tests can scroll.

Future work after that is as planned: F-4 real app prototype (which would
have surfaced several of these bugs — another argument for doing it next),
F-5 benchmarks, then Phase 3 Impeller.

## Prevention: keeping these bug classes from recurring

Almost every finding above is an instance of one of five *classes*. Fixing
the instances without naming the classes guarantees recurrence. Two
complementary defenses: capture the class as a process artifact (the
`/compound` approach), and make the class unrepresentable in types where
OCaml lets you.

### 1. Silent no-op effects → make completion a type obligation

The class behind the Tauri `log-and-never-resolve` ops, the dead `Sub`
constructors, and the focus race: an effect whose failure or absence produces
*nothing* — no message, no error, no test signal.

**Type-level fix:** an effect that can fail must have type
`('a, error) result Task.t`, never `unit Task.t` with errors logged. The
caller is then forced by the compiler to write the `Error` branch, and the
telemetry layer sees a dispatched message either way. Enforce structurally:
give `nopal_tauri` one private `invoke : string -> Jv.t -> (Jv.t, error) result Task.t`
helper that *always* resolves, and forbid raw IPC elsewhere — then a binding
author cannot write the swallowing version. `store.ml` and the storage
backends already prove the pattern works; promote it from convention to the
only available primitive.

**Type-level fix for Subs:** the interpreter, not the constructor list, is
the contract. Replace the `extract_*` helpers (which let a backend ignore
variants it doesn't know) with a required exhaustive interpretation — e.g.
each backend implements
`val interpret : 'msg Sub.atom -> (unit -> unit) (* cleanup *)` via a
`match` with no catch-all (already a repo rule). Adding a `Sub` constructor
then breaks every backend's compile until it is implemented or explicitly
mapped to `Unsupported`, which must itself dispatch a visible diagnostic.
A public constructor that no backend interprets becomes a compile error
instead of a silent runtime no-op.

### 2. Stringly-typed protocols → parse, don't pattern-match strings

The class behind `Error "cancelled"`, the tray `"Left"`/`"Double"` strings,
and the `MainActivity.kt` `top=..;` payload grammar.

**Type-level fix:** dedicated variants at every boundary the OCaml side owns:
`type task_outcome = Resolved of ('a, error) result | Cancelled` (so
cancellation cannot collide with a user error string);
`type tray_click = Single | Double` decoded once at the FFI edge with an
explicit `Unknown of string` arm that dispatches a diagnostic. For payloads
crossing the Kotlin/Rust/JS boundary, define the schema once (a tiny decoder
module with QCheck round-trip tests) instead of ad-hoc `Jv.to_string` casts —
that also catches the `()`-payload-is-null case in `Event.listen`.

### 3. Resource handles faked as ambient values → abstract types from smart constructors

The class behind `Store` sending a filename where a `rid` belongs and
`Tray` invoking with `rid = 0`.

**Type-level fix:** if the remote API hands out a handle, model it as an
abstract type whose only constructor is the call that creates it:
`Store.load : string -> (Store.t, error) result Task.t` and every operation
takes a `Store.t`. With `type t` abstract in the `.mli`, "use a store you
never loaded" is unrepresentable. Same for tray handles: if OCaml cannot
obtain a real rid (the tray lives in Rust), then the `.mli` must not offer
`set_icon` at all — delete capability you cannot implement rather than
shipping a typed lie.

**Process fix:** any binding to an external protocol (Tauri plugin, IPC
schema) needs one *contract test against the real counterpart* — a minimal
headless Tauri run asserting one round-trip per plugin. The `Store` and
`Event.listen` breakages were both version-pinned protocol mismatches that no
amount of OCaml-side unit testing could see, and the tray e2e that should
have caught it evidently doesn't run against HEAD in CI. Rule: an e2e file
that CI doesn't execute is treated as a failing test.

### 4. Lifecycle flags as bare mutable state → state machines and `Fun.protect`

The class behind the wedged `processing` flag, dispatch-after-shutdown, the
unlisten race (twice), and `enable_hardware_back`'s set-before-success flag.

**Type-level fix:** replace independent booleans with one variant:
`type lifecycle = Created | Running | Processing | Shut_down`, and make
state transitions the only mutation, each via a function that matches
exhaustively on the current state — illegal transitions become visible
`match` arms you must decide about, not forgotten resets. Every
flag-set-then-effect sequence wraps the effect in `Fun.protect ~finally`.
For the async-unlisten race, write the fix once as a reusable
`Tauri_subscription.make` (handles the cancelled-before-registered case
internally) and make it the only way `nopal_tauri` creates a `Sub.custom` —
the race was found in three places because the pattern is copy-pasted.

### 5. Partial functions hidden behind "callers are currently safe" → totalize public APIs

The class behind `Downsample.lttb` raising on small targets, `Element.equal`'s
polymorphic compare, and the test renderer's index mismatch.

**Type-level fix:** public functions over constrained domains take a
validated type (`Target.of_int : int -> Target.t option`) or return
`result` — the existing repo rule, applied to *math* parameters, not just
I/O. Where invariants span two functions (handler registration paths vs.
path resolution in `test_renderer.ml`), express the invariant once: a single
`Path.of_virtual_item` used by both writer and reader, so they cannot
disagree about absolute vs. positional indexing.

### The /compound loop, made specific

Capturing these as a solutions library only works if it is wired into the
workflow, not aspirational. Concretely:

1. **On every bug fix, record the class, not the instance.** A
   `docs/bug-classes/` entry (or `/compound` solution) with: the class name,
   the type-level guard that prevents it, and a greppable detection pattern
   (e.g. `rg 'Console.error' backends/ | rg -v resolve` for class 1;
   `rg 'Error "' lib/ backends/` for class 2).
2. **Promote recurring classes into CLAUDE.md's "What Must Never Happen"** —
   it already encodes earlier lessons (`raise`, `style:string`, catch-all
   `_`); these five belong beside them: *never log-and-not-resolve a Task;
   never expose a `Sub`/element constructor without an interpreter in every
   backend in the same PR; never represent a remote handle as a constant;
   never mutate a lifecycle flag outside its transition function; e2e files
   must run in CI.*
3. **Make detection executable.** Each class with a greppable signature gets
   a `just lint-classes` check (ripgrep-based is fine) that CI runs — the
   same idea as `just build-native` already enforcing the dependency
   direction. Conventions that are checked survive; conventions that are
   remembered don't.
4. **Negative-path tests as a PR gate.** Every new effectful binding ships a
   test where the underlying call *fails* and asserts a message is still
   dispatched. This is the telemetry-visible complement to class 1 and would
   have caught most of the Tauri findings.
