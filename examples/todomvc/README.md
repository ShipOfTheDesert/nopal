# TodoMVC

A full TodoMVC implementation using Nopal's MVU architecture, demonstrating
routing, keyed lists, editing, persistence, and event handling.

## What it shows

- Add, toggle, edit, and delete todos
- Filter by All / Active / Completed via hash-based routing
- Toggle all and clear completed bulk actions
- LocalStorage persistence across page reloads
- Keyed list rendering for efficient updates
- `todomvc.ml` imports only `nopal_element`, `nopal_style`, `nopal_mvu`, and
  `nopal_router` — no platform dependencies

## Build and run

```bash
# From the repository root:
just serve-todomvc
```

This builds the project and serves TodoMVC at `http://localhost:8000`.

## Build only

```bash
just build
```

The compiled JS is at `_build/default/examples/todomvc/main.bc.js`.

## Run tests

### Unit tests

```bash
just test
```

Unit tests live in `test/unit/todomvc/`.

### E2E tests

```bash
cd test/e2e
npm install
npx playwright install chromium
npx playwright test
```

For headed (visual) mode:

```bash
npx playwright test --headed
```

Note: Playwright auto-starts its own server on port 3000 (via `npx serve`),
separate from `just serve-todomvc` which uses port 8000. Both can run
simultaneously.

## Native build

The todomvc library (excluding `main.ml`) compiles on native OCaml without
js_of_ocaml:

```bash
just build-native
```
