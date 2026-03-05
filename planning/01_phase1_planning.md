# Nopal — Phase 1 (PoC)
**Detailed Feature Planning · For use with Claude Code PRD generation**

---

## How to Use This Document

This document defines every feature in Phase 1 (PoC) in sequential build order. Each feature entry is designed to be handed to Claude Code to generate a full PRD (Product Requirements Document) for that feature. Features are ordered by dependency — each one can be built on top of the previous without forward references.

Each feature specifies: the opam package it lives in, its dependencies, detailed functional requirements, the OCaml API surface it should expose, what tests are required, what the acceptance criteria are, and any critical constraints Claude Code must respect when generating the PRD.

> **Non-negotiable:** Every feature must include tests before it is considered done. No exceptions. The test type (unit, structural, E2E) is specified per feature.

---

## Phase 1 Goal

Prove the Nopal architecture. By the end of Phase 1, a developer should be able to write a TodoMVC app in OCaml using Nopal, compile it to JavaScript, run it in a browser, and have it covered by Playwright E2E tests. Every architectural boundary should be structurally enforced and validated by the test renderer.

### Sequential Build Order

```
F-01  nopal_mvu          — MVU core (no UI deps)
F-02  nopal_element      — Backend-agnostic Element DSL
F-03  nopal_style        — Typed layout/paint style system
F-04  nopal_test         — Pure OCaml structural test renderer
F-05  nopal_runtime      — Lwd integration + MVU loop
F-06  nopal_web          — js_of_ocaml + Brr web renderer
F-07  nopal_router       — Type-safe bidirectional router
F-08  Counter example    — Hello world, smoke test
F-09  TodoMVC + E2E      — First real example + Playwright suite
F-10  Kitchen sink       — Living visual reference app
F-11  Benchmark suite    — Performance baseline from day one
```

---

## F-01 — MVU Core

**Package:** `nopal_mvu`
**Depends on:** Nothing — zero external deps beyond OCaml stdlib
**Produces:** `nopal_mvu` opam package
**Test type:** Alcotest unit tests — 100% of logic paths covered
**PR includes:** Library + tests. No examples yet.

### Purpose

`nopal_mvu` is the heart of the framework. It defines the MVU runtime contract: the types and combinators for commands, subscriptions, and the application entry point. It has zero UI dependencies — it knows nothing about DOM, Brr, or js_of_ocaml. It must compile cleanly on native OCaml, not just js_of_ocaml.

### Cmd Module

Commands represent side effects that the runtime should execute on behalf of the application after an update. The Cmd module must expose:

- **`Cmd.none`** — The no-op command. Used when update produces no side effects.
- **`Cmd.batch`** — Combine a list of commands into one. Must be flattened at runtime — no nested batches in the dispatch queue.
- **`Cmd.perform`** — Wrap a `unit -> unit` thunk as a command. The simplest escape hatch for synchronous side effects.
- **`Cmd.async`** — Wrap an Lwt promise (`unit Lwt.t`) as a command. Primary mechanism for async operations.
- **`Cmd.task`** — Wrap a function `unit -> msg Lwt.t` — runs async and dispatches the resulting message on completion.
- **`Cmd.after`** — Delay dispatch of a message by N milliseconds. Used for debouncing and timed transitions.

> **Constraint:** `Cmd.t` must be an opaque type. Application code must not pattern-match on it. Only the runtime interprets commands.

### Sub Module

Subscriptions represent ongoing event sources that the runtime manages. The framework — not the application — is responsible for setting up and tearing down subscriptions as the subscription set changes between updates.

- **`Sub.none`** — No subscriptions.
- **`Sub.batch`** — Combine multiple subscriptions.
- **`Sub.every`** — Fire a message on a timer interval (milliseconds). Runtime must set up a single interval and clear it on unsubscribe.
- **`Sub.on_keydown`** — Subscribe to global keydown events. Callback receives key string and produces a message.
- **`Sub.on_keyup`** — Subscribe to global keyup events.
- **`Sub.on_resize`** — Subscribe to window resize events. Callback receives (width, height) and produces a message.
- **`Sub.on_visibility_change`** — Subscribe to document visibility changes (tab focus/blur). Produces a bool message.
- **`Sub.custom`** — Escape hatch — takes a unique string key, a setup function (`dispatch -> cleanup`), and allows arbitrary native subscriptions. The key is used to detect changes between renders.

> **Constraint:** Subscriptions must be diffed between renders using their identity key. If the same `Sub.every 1000` appears in two consecutive subscription results, only one interval must be running — not two.

### App Module

The App module defines the signature every Nopal application must implement, and provides the run function that the web backend calls.

```ocaml
module type App = sig
  type model
  type msg
  val init : unit -> model * msg Cmd.t
  val update : model -> msg -> model * msg Cmd.t
  val view : model -> msg Element.t
  val subscriptions : model -> msg Sub.t
end
```

The `view` function is typed as returning `msg Element.t` where `Element.t` is defined in `nopal_element`. The App module in `nopal_mvu` must declare a dependency on `nopal_element` for this type. This is the one intentional coupling: MVU needs the element type to define the view signature.

> **Constraint:** No platform or renderer module may be imported from `nopal_mvu`. The `App.run` function is not defined here — it is defined in `nopal_runtime`, which wires the MVU loop to Lwd.

### Tests Required

- **`Cmd.batch` flattening** — Nested batches produce a flat list of effects in correct order
- **`Cmd.after` timing** — Message is dispatched after the specified delay, not before
- **`Cmd.task` delivery** — Async task result is dispatched as a message
- **Sub diffing** — Identical subscriptions across two renders do not cause double registration
- **`Sub.batch` merging** — All subscriptions in a batch are registered
- **Full MVU loop** — `init → update → update` cycle with commands exercised end to end using a mock dispatch

---

## F-02 — Backend-Agnostic Element DSL

**Package:** `nopal_element`
**Depends on:** `nopal_mvu` (for msg type parameter only)
**Produces:** `nopal_element` opam package
**Test type:** Alcotest — structural equality tests on `Element.t` values
**PR includes:** Library + tests. No renderer yet.

### Purpose

`nopal_element` defines `Element.t` — the pure description type that all view functions return. It is the critical abstraction boundary of the entire framework. View functions in application code import only this module. No Brr, no DOM, no js_of_ocaml type must appear here.

> **Constraint:** This package must have zero dependencies on js_of_ocaml, Brr, or any browser API. The OCaml compiler must be able to build this package on native OCaml without js_of_ocaml installed. This is verified by the CI build matrix.

### Element Type

`Element.t` is a polymorphic variant type parameterised over `msg` — the message type of the application. Every interactive element carries msg-typed event handlers.

```ocaml
type 'msg t =
  | Empty
  | Text of string
  | Box    of { style: Style.t; children: 'msg t list }
  | Row    of { style: Style.t; children: 'msg t list }
  | Column of { style: Style.t; children: 'msg t list }
  | Button of { style: Style.t; label: 'msg t; on_click: 'msg option }
  | Input  of { style: Style.t; value: string; placeholder: string option;
                on_change: (string -> 'msg) option;
                on_submit: 'msg option }
  | Image  of { src: string; alt: string; style: Style.t }
  | Scroll of { style: Style.t; child: 'msg t }
  | Keyed  of { key: string; child: 'msg t }
  | Map    of { f: ('a -> 'msg); child: 'a t }
```

The `Map` constructor is essential for component composition — it lets a child component with its own message type be embedded in a parent by mapping its messages. This is the primary mechanism for building reusable components without global message types.

### Builder Functions

Every constructor has an ergonomic builder function with labelled optional arguments. Raw variant construction should not be required in application code.

```ocaml
val empty  : 'msg t
val text   : string -> 'msg t
val box    : ?style:Style.t -> 'msg t list -> 'msg t
val row    : ?style:Style.t -> 'msg t list -> 'msg t
val column : ?style:Style.t -> 'msg t list -> 'msg t
val button : ?style:Style.t -> ?on_click:'msg -> 'msg t -> 'msg t
val input  : ?style:Style.t -> ?placeholder:string
          -> ?on_change:(string -> 'msg) -> ?on_submit:'msg
          -> string -> 'msg t
val image  : ?style:Style.t -> alt:string -> string -> 'msg t
val scroll : ?style:Style.t -> 'msg t -> 'msg t
val keyed  : string -> 'msg t -> 'msg t
val map    : ('a -> 'msg) -> 'a t -> 'msg t
```

### Critical Design Rules

- **No CSS strings** — `style:string` is forbidden. All styling goes through the `Style.t` type defined in `nopal_style`.
- **No event objects** — Event handlers receive domain values (`string` for input, `unit` for click), not raw browser event objects. This is what makes the DSL backend-agnostic.
- **Keyed is explicit** — The `Keyed` wrapper is opt-in. The renderer uses the key for reconciliation. Application code wraps dynamic list items in `Keyed`.
- **Map enables composition** — Child components have their own `msg` type and are lifted into parent context via `Element.map`. This is the primary composition primitive.

### Tests Required

- **Builder defaults** — All optional arguments default correctly, empty style applied when omitted
- **Map lifting** — `Element.map` correctly transforms msg type through nested structure
- **Keyed identity** — Two `Keyed` elements with same key but different children are considered same identity
- **Text equality** — Structural equality on `Text` nodes
- **Deep nesting** — `Column` containing `Row` containing `Button` with `on_click` round-trips through equality

---

## F-03 — Style System

**Package:** `nopal_style`
**Depends on:** Nothing — zero deps beyond stdlib
**Produces:** `nopal_style` opam package
**Test type:** Alcotest — value construction, defaults, CSS mapping
**PR includes:** Library + tests + CSS generation for web backend

### Purpose

`nopal_style` defines the typed style system. It separates layout (how elements are positioned and sized) from paint (visual appearance). This separation maps cleanly to CSS flexbox on web, and will map to native layout constraints in Phase 3, without requiring changes to application code.

> **Constraint:** No CSS string must appear in the application-facing API. The web backend (`nopal_web`) is responsible for translating `Style.t` to CSS. This translation is an internal concern of the renderer, not the application.

### Layout Type

Layout describes spatial constraints — how an element sizes itself and arranges its children.

```ocaml
type direction = Row | Column
type align     = Start | Center | End | Stretch | Space_between | Space_around
type size      = Fill | Hug | Px of int | Fraction of float

type layout = {
  direction   : direction;
  align_main  : align;    (* justify-content *)
  align_cross : align;    (* align-items *)
  wrap        : bool;
  gap         : int;      (* px, uniform gap *)
  padding     : int * int * int * int;  (* top right bottom left *)
  width       : size;
  height      : size;
  grow        : float option;  (* flex-grow *)
}
```

### Paint Type

Paint describes visual appearance — color, borders, shadows, opacity, radius.

```ocaml
type color =
  | Rgba        of int * int * int * float
  | Hex         of string
  | Named       of string
  | Transparent

type border_style = Solid | Dashed | Dotted | None

type border = {
  width  : int;
  style  : border_style;
  color  : color;
  radius : int;
}

type paint = {
  background    : color option;
  border        : border option;
  opacity       : float;
  shadow        : (int * int * int * color) option;  (* x y blur color *)
  overflow_hidden : bool;
}
```

### Style Type and Defaults

```ocaml
type t = {
  layout : layout;
  paint  : paint;
}

val default     : t
val layout      : layout -> t -> t
val paint       : paint -> t -> t
val with_layout : (layout -> layout) -> t -> t
val with_paint  : (paint -> paint) -> t -> t
```

A `default` style produces a zero-gap, `Hug`-width, `Hug`-height, `Column`-direction, transparent, no-border element. Elements with no explicit style applied take up only as much space as their content requires and do not impose layout on their children.

### CSS Generation

The web backend requires a function to translate `Style.t` to CSS. This lives in `Style.Css` — a separate submodule — so native backends do not pull in CSS logic.

```ocaml
(* In Style.Css — web backend uses this *)
val to_inline : Style.t -> string
val to_attrs  : Style.t -> (string * string) list
```

> **Constraint:** `Size.Fill` translates to `width:100%` / `height:100%` in CSS. `Size.Hug` translates to `width:fit-content` / `height:fit-content`. These must be verified in the test suite against known-good CSS output.

### Tests Required

- **Default style** — Default produces expected zero values throughout
- **CSS translation** — Key layout combinations produce correct CSS strings (Fill, Hug, Px, direction, gap, padding)
- **Color rendering** — Rgba, Hex, Named, Transparent each produce correct CSS color strings
- **Border radius** — Border radius applies correctly in CSS output
- **Immutable update** — `with_layout` and `with_paint` produce new values without mutating original

---

## F-04 — Structural Test Renderer

**Package:** `nopal_test`
**Depends on:** `nopal_element`, `nopal_style`
**Produces:** `nopal_test` opam package
**Test type:** Self-testing — Alcotest tests of the test renderer itself
**PR includes:** Library + self-tests. Used by all subsequent features.

### Purpose

`nopal_test` is a pure OCaml renderer that interprets `Element.t` into an inspectable tree structure. It enables structural assertions and event simulation without a browser. It also serves as the primary validation that the backend-agnostic DSL boundary is working — if `nopal_test` can be built without importing Brr or js_of_ocaml, the boundary holds.

> **Constraint:** `nopal_test` must compile on native OCaml. If it ever requires js_of_ocaml to build, the DSL boundary has been violated. This must be enforced in the CI matrix with a native build step.

### Node Type

```ocaml
type attr = { name: string; value: string }

type node =
  | Text    of string
  | Element of {
      tag      : string;
      attrs    : attr list;
      children : node list;
    }
  | Empty

type 'msg rendered = {
  tree     : node;
  dispatch : 'msg -> unit;
  messages : 'msg list ref;
}
```

### API

```ocaml
(* Render an element to an inspectable tree *)
val render : 'msg Element.t -> 'msg rendered

(* Query *)
val find        : node -> selector -> node option
val find_all    : node -> selector -> node list
val text_content: node -> string
val has_attr    : node -> string -> bool
val attr        : node -> string -> string option

(* Simulate events — dispatches message, returns updated messages list *)
val click  : 'msg rendered -> selector -> 'msg list
val input  : 'msg rendered -> selector -> string -> 'msg list
val submit : 'msg rendered -> selector -> 'msg list

(* Selector type *)
type selector =
  | Tag          of string
  | Text_contains of string
  | Has_attr     of string * string
  | First
  | Nth          of int
```

The `rendered` value holds a mutable `messages` ref that accumulates dispatched messages across multiple event simulations. Tests inspect this list to verify the correct message sequence was produced.

### Full MVU Loop Testing

`nopal_test` also provides a helper for testing a complete MVU update cycle without a browser:

```ocaml
val run_app :
  (module Nopal_mvu.App.S with type msg = 'msg and type model = 'model) ->
  steps:('msg list) ->
  ('model * node)
```

This allows tests to say "given this app, dispatch these messages in order, and assert on the final model and rendered output" without any browser or runtime involvement.

### Tests Required

- **Render Text** — `Text` element produces `Text` node with correct content
- **Render Box** — `Box` with children produces `Element` with correct child count
- **Button click** — Click simulation dispatches `on_click` message
- **Input change** — Input simulation dispatches `on_change` message with correct string
- **Map lifting** — Messages from a mapped child are correctly lifted to parent type
- **Selector queries** — `find`/`find_all` locate correct nodes by tag, text content, attribute
- **`run_app` cycle** — Counter app (increment 3 times) produces model with `count=3` and correct rendered output

---

## F-05 — Lwd Runtime

**Package:** `nopal_runtime`
**Depends on:** `nopal_mvu`, `nopal_element`, `lwd` (opam)
**Produces:** `nopal_runtime` opam package
**Test type:** Alcotest — MVU loop, subscription lifecycle, Lwd integration
**PR includes:** Library + tests. Platform-agnostic.

### Purpose

`nopal_runtime` wires the MVU loop to Lwd's reactive primitives. It owns the main dispatch queue, drives the update/view cycle, manages subscription lifecycle, and exposes the reactive element tree that backend renderers subscribe to. It is platform-agnostic — it does not know about DOM or Brr.

### Runtime Core

The runtime maintains:

- **`model_var`** — An `Lwd.var` holding the current model. Changing it triggers reactive recomputation downstream.
- **Dispatch queue** — A queue of pending messages. Processed synchronously in batches to avoid mid-update re-renders.
- **Subscription manager** — Diffs the current `Sub.t` against the previous one, sets up new subscriptions, tears down removed ones.
- **Command executor** — Processes `Cmd.t` values — runs thunks, schedules async tasks, wires timer delays.

```ocaml
type 'msg t

(* Create a runtime from an App module *)
val create : (module Nopal_mvu.App.S
               with type msg = 'msg
               and type model = 'model) -> 'msg t

(* The reactive element tree — backends subscribe to this *)
val view : 'msg t -> 'msg Element.t Lwd.t

(* Dispatch a message into the loop *)
val dispatch : 'msg t -> 'msg -> unit

(* Start the runtime — sets up initial subscriptions, runs init cmd *)
val start : 'msg t -> unit
```

### Lwd Integration

The model is stored in an `Lwd.var`. The view function is lifted into `Lwd.map` so that when the model changes, Lwd propagates the change only to the parts of the element tree that depend on the changed model values. This is the incremental update story — not VDOM diffing, but reactive dependency tracking.

> **Constraint:** The runtime must guarantee that `view` is never called while a dispatch is in progress. Recursive dispatch (a message handler that immediately dispatches another message) must be queued, not recursed. Failing to handle this causes stack overflows on rapid message sequences.

### Subscription Lifecycle

After every update, the runtime calls `subscriptions(model)` and diffs the result against the previous subscription tree using the identity keys from `Sub.custom` and the type tags of built-in subscriptions. Subscriptions added since the last update are started. Subscriptions removed since the last update are stopped. Unchanged subscriptions are left running.

### Tests Required

- **Dispatch queuing** — Recursive dispatch from within `update` is queued and processed after current update completes
- **Lwd propagation** — Changing model via dispatch causes `Lwd.t` to emit new value
- **Subscription start** — New subscription after update is started exactly once
- **Subscription stop** — Removed subscription after update is stopped exactly once
- **Subscription stability** — Identical subscriptions across updates do not cause restart
- **Command execution** — `Cmd.task` dispatches returned message after completion
- **`Cmd.after` timing** — Message is dispatched after specified delay
- **Init command** — Command returned from `init` is executed on `start`

---

## F-06 — Web Renderer

**Package:** `nopal_web`
**Depends on:** `nopal_runtime`, `nopal_element`, `nopal_style`, `js_of_ocaml`, `brr`
**Produces:** `nopal_web` opam package
**Test type:** `nopal_test` structural tests + manual visual verification in browser
**PR includes:** Library + tests + Counter example compiling and running in browser

### Purpose

`nopal_web` is the first concrete backend. It subscribes to the runtime's reactive element tree and interprets `Element.t` into real DOM nodes using Brr. It handles DOM event wiring, reconciliation via `Keyed` nodes, and translates `Style.t` to CSS inline styles.

> **Constraint:** No application code and no `nopal_element` code may import from `nopal_web`. The dependency is strictly one-way: `nopal_web` imports `nopal_element`, never the reverse.

### Renderer Architecture

The renderer maintains a live DOM tree that it patches in response to Lwd changes. It does not use virtual DOM diffing — instead, it uses Lwd's dependency tracking to know which subtrees need updating. When a portion of the `Lwd.t` tree emits a new value, only that portion of the DOM is patched.

**Reconciliation strategy for lists:**

- **Unkeyed children** — Patched in order — existing DOM nodes reused by position, surplus nodes removed, new nodes appended.
- **Keyed children** — DOM nodes are matched by key. Nodes with matching keys are moved/reused. New keys create new DOM nodes. Missing keys have their DOM nodes removed. This is the mechanism for efficient list reordering.

### Element Mapping

| Element | DOM tag | Notes |
|---|---|---|
| `Box` | `div` | Style applied as inline CSS |
| `Row` | `div` | Style with `flex-direction:row` |
| `Column` | `div` | Style with `flex-direction:column` |
| `Text` | `span` | No style applied unless wrapped |
| `Button` | `button` | `on_click` wired to click event |
| `Input` | `input` | `on_change` wired to input event, `on_submit` to keydown Enter |
| `Image` | `img` | `src` and `alt` attributes set |
| `Scroll` | `div` | `overflow:auto` applied |
| `Keyed` | (child tag) | `data-key` attribute set for reconciliation |
| `Empty` | (nothing) | Comment node or empty text node as placeholder |

### Entry Point

```ocaml
(* Mount a Nopal app onto a DOM element *)
val mount :
  (module Nopal_mvu.App.S with type msg = 'msg and type model = 'model) ->
  into:Brr.El.t ->
  unit
```

The `mount` function creates a runtime, starts it, subscribes to the reactive element tree, and performs the initial render into the target DOM element. It also wires up any platform-level event listeners required by active subscriptions.

### Tests Required

- **DOM mount** — `mount` produces a DOM tree with the correct root structure for a simple app
- **Text render** — `Text` element produces a `span` with correct text content in DOM
- **Button event** — Click on button DOM node dispatches correct message to runtime
- **Input event** — Typing into input DOM node dispatches `on_change` with correct string
- **Keyed reconciliation** — Reordering a keyed list reuses DOM nodes by key (verified via node identity)
- **Style CSS** — Element with non-default style has correct inline CSS applied to DOM node
- **Lwd update** — Dispatching a message causes only the affected DOM subtree to update, not full re-render

---

## F-07 — Type-Safe Router

**Package:** `nopal_router`
**Depends on:** `nopal_mvu`, `routes` (opam). No browser deps.
**Produces:** `nopal_router` opam package
**Test type:** Alcotest — parse/serialize round-trips, platform integration
**PR includes:** Library + tests + `Platform_web` implementation

### Purpose

`nopal_router` provides type-safe bidirectional routing. Routes are defined as OCaml variant types. The router converts between URL strings and route values in both directions. It is platform-agnostic — navigation operations go through a `Platform` module signature, with a web implementation using the browser History API and a future Tauri implementation using Tauri's navigation APIs.

### Route Definition

Application code defines routes as a variant type and provides parse/`to_path` functions using the `routes` library:

```ocaml
module type Route = sig
  type t
  val parse   : string -> t option
  val to_path : t -> string
end

(* Example application route definition *)
type route = Home | About | Item of int | Not_found

let parse = Routes.(match_path (
  (s "about" /? nil) |> map (fun () -> About)
  </> (s "items" / int /? nil) |> map (fun id -> Item id)
  </> nil |> map (fun () -> Home)
))
```

### Platform Signature

```ocaml
module type Platform = sig
  val get_path     : unit -> string
  val push_state   : string -> unit
  val replace_state: string -> unit
  val back         : unit -> unit
  val forward      : unit -> unit
  (* Returns cleanup function *)
  val on_navigate  : (string -> unit) -> (unit -> unit)
end
```

`Platform_web` implements this using the browser History API and the `popstate` event. `Platform_tauri` will implement it in Phase 2. Application code depends only on the `Platform` signature, never a concrete implementation.

### Router API

```ocaml
(* Create a router — wires navigation subscription *)
val create :
  (module Route with type t = 'route) ->
  (module Platform) ->
  not_found:'route ->
  'route Router.t

(* Use in App subscriptions to receive route changes *)
val on_navigate : 'route Router.t -> ('route -> 'msg) -> 'msg Sub.t

(* Navigate programmatically from update *)
val push    : 'route Router.t -> 'route -> 'msg Cmd.t
val replace : 'route Router.t -> 'route -> 'msg Cmd.t
val back    : 'route Router.t -> 'msg Cmd.t

(* Read current route — for use in view *)
val current : 'route Router.t -> 'route
```

### Tests Required

- **Parse round-trip** — `to_path (parse path) = path` for all defined routes
- **Not found** — Unmatched path returns `not_found` route
- **`push` cmd** — `Router.push` produces a command that calls `Platform.push_state` with correct path
- **`on_navigate` sub** — Navigation event triggers subscription with parsed route
- **Dynamic segment** — Route with `int` segment parses and serializes correctly
- **`Platform_web`** — `Platform_web.push_state` calls `window.history.pushState` with correct arguments

---

## F-08 — Counter Example

**Package:** `examples/counter`
**Depends on:** `nopal_web`, `nopal_mvu`, `nopal_element`, `nopal_style`
**Produces:** Runnable web app + opam example package
**Test type:** `nopal_test` structural tests — no Playwright for this example
**PR includes:** Example + tests + `dune build` confirmed + README with build instructions

### Purpose

The counter example is the hello world of Nopal. It is the first thing a new developer sees. It must demonstrate the complete MVU loop — `init`, `update`, `view` — in the simplest possible way. It is also the smoke test that the full stack (`nopal_mvu` + `nopal_element` + `nopal_style` + `nopal_web`) compiles and runs in a browser.

### Requirements

- Displays a count starting at 0
- Has an Increment button, a Decrement button, and a Reset button
- Count cannot go below 0 (Decrement disabled or ignored at 0)
- Uses `nopal_style` for all styling — no inline CSS strings anywhere
- Must be buildable with a single `dune build` command
- Must open in a browser after running a simple static server

> **Constraint:** The counter example must not import `nopal_web` directly in its App module. The App module imports only `nopal_mvu` and `nopal_element`. The web mounting code is a separate thin `main.ml` entry point. This demonstrates the correct application architecture.

### Tests Required

- **Init** — Initial model has `count = 0`
- **Increment** — Increment message increases count by 1
- **Decrement** — Decrement message decreases count by 1
- **Decrement floor** — Decrement at 0 does not go below 0
- **Reset** — Reset message sets count to 0 from any value
- **View structure** — Rendered tree contains three buttons and a text node with count value

---

## F-09 — TodoMVC + Playwright E2E

**Package:** `examples/todomvc`
**Depends on:** `nopal_web`, `nopal_router`, `nopal_runtime` + Playwright (TypeScript, `test/e2e/`)
**Produces:** Full TodoMVC app + complete Playwright E2E test suite
**Test type:** `nopal_test` structural + Playwright E2E (headless Chromium)
**PR includes:** Example + structural tests + E2E tests + CI configuration for Playwright

### Purpose

TodoMVC is the standard benchmark for UI frameworks. It exercises list rendering, keyed updates, input handling, filtering, conditional rendering, local state persistence, and routing — all the things Counter does not. It is the first example with full Playwright E2E tests and the first to validate that the complete stack works end to end in a real browser.

### Feature Requirements

The TodoMVC implementation must conform to the official TodoMVC spec (todomvc.com):

- **Add todo** — Typing in the header input and pressing Enter adds a new todo item
- **Complete todo** — Clicking the checkbox marks a todo as complete
- **Complete all** — The toggle-all checkbox marks all todos complete/incomplete
- **Delete todo** — The × button removes a todo
- **Edit todo** — Double-clicking a todo label makes it editable; Enter or blur saves; Escape cancels
- **Filter** — Footer links filter by All / Active / Completed — uses router for URL state
- **Clear completed** — Button removes all completed todos
- **Item count** — Footer shows count of active items remaining
- **Persistence** — Todos persist across page refresh using localStorage (web) — via a platform storage abstraction

> **Constraint:** The filter state must be driven by the router (URL hash or path). Navigating directly to `/completed` must show only completed todos. This validates the router integration end to end.

### Playwright E2E Suite

The E2E suite lives in `test/e2e/` and uses TypeScript + Playwright. It must cover:

- **Add todo** — Type text, press Enter, assert todo appears in list
- **Complete todo** — Click checkbox, assert item has completed class
- **Delete todo** — Hover item, click ×, assert item removed
- **Edit todo** — Double-click, type new text, press Enter, assert label updated
- **Edit cancel** — Double-click, type, press Escape, assert original text restored
- **Filter all** — Click All filter, assert all todos visible
- **Filter active** — Click Active filter, assert only active todos visible
- **Filter completed** — Click Completed, assert only completed todos visible
- **Clear completed** — Add two todos, complete one, click Clear, assert one todo remains
- **Persistence** — Add todo, reload page, assert todo still present
- **URL routing** — Navigate directly to `/completed` URL, assert filter is active

CI must run Playwright in headless Chromium. The Playwright config must be committed. A `npm install && npx playwright test` command must run the full suite from a clean checkout.

---

## F-10 — Kitchen Sink

**Package:** `examples/kitchen_sink`
**Depends on:** `nopal_web` + all `nopal_*` libraries
**Produces:** Runnable web app — living visual reference
**Test type:** None — this is a manual visual tool, not an automated test
**PR includes:** Initial app with every element from `nopal_element` rendered. Updated with each subsequent feature PR.

### Purpose

The kitchen sink is the developer's visual reference. It renders every element, style variant, and interaction pattern that Nopal supports in one place. It is the first thing to open when debugging visual issues, and the first thing a new contributor should run to see the framework in action.

It is not a polished demo — it is a technical reference. Each section is labelled with the element name and the code used to produce it.

### Sections to Include at F-10

- **Typography** — Text in various sizes and colors using `nopal_style`
- **Layout** — Box, Row, Column with various alignment and gap combinations
- **Buttons** — Default, styled, disabled
- **Inputs** — Text input with `on_change`, with placeholder, with `on_submit`
- **Images** — Image element with alt text
- **Scroll** — Scroll container with overflow content
- **Keyed lists** — Dynamic list with add/remove/reorder controls
- **Nested layout** — Complex nested Row/Column structures
- **Map/composition** — A sub-component with its own message type composed via `Element.map`

> **Constraint:** The kitchen sink must always compile and run. It is a living document. Every future PR that adds a new component or style feature must add a corresponding section here as part of the same PR.

---

## F-11 — Benchmark Suite

**Package:** `bench/`
**Depends on:** `nopal_web` + js-framework-benchmark tooling
**Produces:** Benchmark implementation + CI performance tracking
**Test type:** Performance — not a correctness test
**PR includes:** Benchmark implementation + baseline measurements + CI config that fails on significant regression

### Purpose

The benchmark suite establishes a performance baseline for Nopal from day one. The goal is not to be the fastest framework. The goal is to always know how fast Nopal is, to track changes over time, and to catch regressions before they reach users.

### js-framework-benchmark Implementation

Nopal must implement the standard [js-framework-benchmark](https://github.com/krausest/js-framework-benchmark) suite. This provides:

- A shared vocabulary for "fast enough" relative to other frameworks
- Standard operations: create 1000 rows, replace 1000 rows, partial update, select row, swap rows, remove row, create 10000 rows, append 1000 rows, clear rows
- Automated measurement infrastructure already built by the benchmark project

The Nopal implementation follows the same structure as other framework implementations in the benchmark repo. It must pass the benchmark's correctness checks (DOM structure assertions) before timing results are meaningful.

### Additional Tracked Metrics

- **Bundle size** — js_of_ocaml output size in bytes, tracked per build. Reported in CI.
- **Incremental update** — Custom benchmark: update one row in a list of 1000. Measures Lwd incremental performance specifically.
- **Message throughput** — Custom benchmark: dispatch 10000 messages in a tight loop. Measures dispatch queue overhead.

### CI Integration

Benchmark results are committed as a baseline JSON file. CI compares current results against the baseline and fails if any metric degrades by more than 20%. The threshold is intentionally loose — this is a regression detector, not a strict performance gate. Baselines are updated manually when intentional architectural changes affect performance.

> **Constraint:** Benchmark measurements are only meaningful when run in a consistent environment. CI benchmarks run on a dedicated runner with no other processes. Developer machine benchmarks are informational only.

---

## Phase 1 Completion Checklist

At the end of Phase 1, all of the following must be true:

1. All 7 opam packages build cleanly on both js_of_ocaml and native OCaml (`nopal_mvu`, `nopal_element`, `nopal_style`, `nopal_test`, `nopal_runtime`, `nopal_web`, `nopal_router`)
2. `nopal_test` builds without js_of_ocaml — verifying the backend-agnostic DSL boundary structurally
3. Counter example runs in browser with full `nopal_test` unit test coverage
4. TodoMVC passes all Playwright E2E tests in headless Chromium in CI
5. Kitchen sink app opens in browser and renders all elements without errors
6. Benchmark suite produces js-framework-benchmark results and a committed baseline JSON
7. No view function in any example imports from `nopal_web` or any Brr type
