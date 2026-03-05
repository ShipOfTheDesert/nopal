# Nopal
**A Cross-Platform UI Framework for OCaml**
[nopal.run](https://nopal.run) · Project Overview & Planning · v0.1

---

## 1. Project Description

Nopal is a cross-platform UI framework for OCaml, enabling developers to build local-first applications targeting desktop, mobile, and web from a single OCaml codebase. It follows the MVU (Model-View-Update) architecture, uses Lwd for fine-grained reactive updates, and compiles to JavaScript via js_of_ocaml for web and Tauri webview targets.

The name comes from the nopal cactus — a desert plant deeply rooted in arid terrain, resilient, and surprisingly useful. Like OCaml itself, it looks unconventional but rewards those who work with it.

The framework is built library-first: every concern is a separate opam package with explicit, enforced dependency boundaries. The element DSL is backend-agnostic by design, enabling multiple rendering backends without changes to application code.

---

## 2. Motivation & Goals

OCaml developers currently have no mature, cross-platform UI framework that feels native to the language. Existing options require adopting foreign ecosystems (Flutter/Dart, React/JS) or accepting significant limitations (terminal-only, web-only, or years of build effort for a native renderer).

**Nopal's goals:**

- One OCaml codebase targets web, desktop (macOS, Windows, Linux), and mobile (iOS, Android)
- MVU architecture that feels familiar to Elm users but is idiomatic OCaml
- Local-first by default — offline capable, no server required for core functionality
- Productive within 2 months, not years — PoC proves the design, MVP ships real apps
- Library-first: zero coupling between layers, every boundary enforced structurally
- Fast enough — not the fastest, but with observable, trackable performance from day one

---

## 3. Tech Stack

### Core OCaml Libraries

| Library | Role |
|---|---|
| `lwd` | Reactive primitives, dependency tracking, incremental computation |
| `js_of_ocaml` | Compile OCaml to JavaScript for web and Tauri webview targets |
| `brr` | Browser API bindings for js_of_ocaml (web backend only) |
| `routes` | Type-safe bidirectional routing (parse ↔ serialize) |
| `alcotest` | Unit and integration test runner |
| `qcheck` | Property-based testing |

### Platform & Tooling

| Tool | Role |
|---|---|
| Tauri | Desktop (macOS/Windows/Linux) and mobile (iOS/Android) shell — wraps web output in a native webview |
| Playwright + TypeScript | E2E tests — covers web and Tauri WebDriver; isolated to `test/e2e/` |
| js-framework-benchmark | Performance baseline — compatible implementation for regression tracking |
| dune | Build system; enforces opam package boundaries |

### Future / Phase 3

| Tool | Role |
|---|---|
| Impeller | Native GPU renderer (Flutter's renderer) — bindings TBD post-Phase 2 |
| Tyxml | HTML string renderer for server-side / prerender backend (additive, Phase 2+) |

---

## 4. Architecture Overview

Every layer is a separate opam package. Dependency arrows flow strictly downward — no upward imports, no circular dependencies.

```
nopal_mvu          (Cmd, Sub, App)           ← no UI deps
nopal_element      (Element.t DSL)           ← no platform deps
nopal_style        (layout/paint)            ← no platform deps
nopal_router       (type-safe routing)       ← no platform deps
nopal_runtime      (Lwd integration)         ← depends on mvu + element
nopal_web          (js_of_ocaml + Brr)       ← depends on runtime
nopal_html         (Tyxml renderer, future)  ← depends on element only
nopal_test         (pure OCaml test renderer)← depends on element only
```

The element DSL (`nopal_element`) is the critical abstraction boundary. View functions in application code import only `nopal_element` — never `nopal_web` or any Brr type. The web renderer is a separate interpreter. This structural separation means a server-side HTML renderer, a test renderer, or a native renderer can be added without touching application code.

---

## 5. Design Principles & Constraints

### Non-Negotiable Principles

- **Library-first** — Every concern lives in its own opam package with explicit deps. The compiler enforces boundaries, not convention.
- **Backend-agnostic DSL** — View functions never import platform-specific types. `Element.t` is a pure description.
- **Tested from day one** — Every PR includes unit tests (Alcotest), structural tests (`nopal_test` renderer), and E2E tests (Playwright) where applicable.
- **Visual confirmation at every phase** — A kitchen sink example app is maintained alongside the framework and updated with every new feature.
- **Performance observable** — Benchmark suite runs from Phase 1. Regressions are visible before they ship.
- **Local-first** — Offline capability is a first-class concern, not an afterthought. No framework feature should require a server.

### Important Constraints

- **OCaml 5.2+ required** — Needed for Tauri toolchain compatibility and modern language features.
- **js_of_ocaml output size** — Bundle size is tracked as a benchmark metric from Phase 1. Avoid unnecessary dependencies.
- **No React mental model** — The framework is MVU + reactive primitives. VDOM diffing is not used. Component thinking is discouraged in favour of function composition.
- **Tauri Rust surface is minimal** — Rust is used only as Tauri's shell. No application logic lives in Rust. The Rust footprint should stay invisible to framework users.
- **Style system is platform-agnostic** — CSS class strings must not appear in the element DSL. The style system uses a typed layout/paint model that maps to CSS on web and to native layout constraints later.
- **SEO is out of scope for PoC/MVP** — The framework targets `app.domain.com` deployments. Public marketing sites use a separate Astro stack. The DSL's backend-agnosticism preserves a future SSR/prerender path.

---

## 6. Phases & Features

| Phase | Name | Goal |
|---|---|---|
| **PoC** | Foundation | Prove the architecture — MVU + Lwd runtime, backend-agnostic DSL, web renderer, tested and benchmarked |
| **MVP** | Tauri + Advanced | Ship real apps — Tauri desktop/mobile integration, advanced components, full E2E suite |
| **Phase 3** | Native Backend | Impeller bindings — native GPU rendering without a webview (post-MVP, future work) |

### Phase 1 — PoC Features

- `nopal_mvu` — Cmd, Sub, App module — the MVU core with no UI dependencies
- `nopal_element` — Backend-agnostic Element DSL — Box, Row, Column, Text, Button, Input, Image, Scroll, Keyed, Empty, Map
- `nopal_style` — Typed layout/paint style system — flexbox-inspired constraints, no CSS strings in the DSL
- `nopal_runtime` — Lwd integration — connects MVU loop to reactive rendering, manages subscriptions
- `nopal_web` — Web renderer — js_of_ocaml + Brr, interprets `Element.t` into DOM, handles events
- `nopal_router` — Type-safe bidirectional router — variant routes, platform-agnostic Platform module
- `nopal_test` — Pure OCaml test renderer — structural assertions without a browser, validates DSL boundary
- Counter example — Hello-world developer example — smoke test for the full stack
- TodoMVC example + E2E — First meaningful example with full Playwright E2E test suite
- Kitchen sink — Living visual reference — every built component rendered in one place
- Benchmark suite — js-framework-benchmark compatible implementation + bundle size tracking

### Phase 2 — MVP Features

- Tauri integration — Desktop (macOS/Windows/Linux) and mobile (iOS/Android) via Tauri webview
- `Platform_tauri` — Tauri implementation of the Platform module — navigation, storage, native APIs
- `nopal_web_components` — Advanced component library — forms, data tables, modals, toasts, navigation
- Offline storage — Local-first storage abstraction — IndexedDB on web, Tauri filesystem on desktop
- E2E suite expansion — Playwright E2E extended to cover Tauri WebDriver for desktop targets
- Real app prototype — A non-trivial application built with Nopal to validate the full stack

### Phase 3 — Native Backend (Future)

- Impeller bindings — OCaml bindings to Flutter's Impeller GPU renderer — post-MVP after renderer research
- `nopal_native` — Native backend implementation of the Platform module
- Native layout engine — Map `nopal_style` constraints to native layout primitives
- Native test hooks — Custom test interface for the scene graph — compensates for immature native desktop UI testing tooling

---

## 7. Testing Strategy

| Layer | Approach |
|---|---|
| Unit / logic | Alcotest — pure OCaml, no browser, fast CI. Covers Cmd, Sub, update logic, router parsing. |
| Structural UI | `nopal_test` renderer — renders `Element.t` to an inspectable tree. Assert on structure, simulate events, validate DSL boundary. No browser required. |
| E2E web | Playwright + TypeScript — real browser, headless. Full interaction testing. Isolated to `test/e2e/`. |
| E2E desktop | Playwright via Tauri WebDriver — same test suite reused for desktop target in Phase 2. |
| Native desktop | Custom renderer test hooks (Phase 3) — query scene graph directly, bypass UI automation fragility. |
| Performance | js-framework-benchmark suite + bundle size tracked per build. CI fails on significant regression. |

---

## 8. Performance & Benchmarking

The goal is not to be the fastest framework. The goal is to be fast enough — and to always know how fast that is.

### Tracked Metrics

- **Render time for N items** — Time to first meaningful paint with lists of 100 / 1000 / 10000 items
- **Incremental update cost** — Rerender cost when one item in a list of N changes
- **Message throughput** — Dispatch M messages in rapid succession, measure frame budget compliance
- **Bundle size** — js_of_ocaml output size tracked per build — dead code elimination verified

### Benchmark Tooling

- **js-framework-benchmark** — Compatible implementation from Phase 1 — provides shared vocabulary for "fast enough" and catches regressions against the wider ecosystem
- **Custom dashboard example (future)** — A complex live-updating dashboard added in Phase 2 as a realistic worst-case scenario benchmark

---

## 9. Open Items & Future Decisions

| Item | Notes |
|---|---|
| Animation system | Not in scope for PoC or MVP. Design deferred. |
| Accessibility | Not in scope for PoC. Platform-specific accessibility APIs need research. |
| SSR / Prerender | Out of scope for PoC/MVP. DSL backend-agnosticism preserves the path. Prerendering via headless snapshot is viable when needed. |
| Style system evolution | Phase 1 ships a minimal typed layout/paint system. Advanced features (themes, responsive breakpoints, animations) are future work. |
| opam publishing | Packages are developed locally. opam publishing strategy TBD after Phase 1. |
| Project name conflicts | Verify "nopal" is clear on opam before publishing packages. |
