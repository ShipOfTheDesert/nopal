# Counter

A minimal MVU counter demonstrating Nopal's core architecture: model, update,
view, and subscriptions.

## What it shows

- Increment, decrement, and reset a counter
- Decrement clamps at zero (count never goes negative)
- Styled with `nopal_style` (no CSS strings)
- `counter.ml` imports only `nopal_element`, `nopal_style`, and `nopal_mvu` —
  no platform dependencies

## Build and run

```bash
# From the repository root:
just serve-counter
```

This builds the project and serves the counter at `http://localhost:8000`.

## Build only

```bash
just build
```

The compiled JS is at `_build/default/examples/counter/main.bc.js`.

## Run tests

```bash
just test
```

Unit tests live in `test/unit/counter/`.

## Native build

The counter library (excluding `main.ml`) compiles on native OCaml without
js_of_ocaml:

```bash
just build-native
```
