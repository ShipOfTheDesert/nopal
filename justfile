default: build test fmt lint

build:
    opam exec -- dune build

build-native:
    opam exec -- dune build lib/nopal_style lib/nopal_draw lib/nopal_element lib/nopal_mvu lib/nopal_test lib/nopal_runtime lib/nopal_router lib/nopal_charts examples/todomvc/todomvc.cma

run:
    opam exec -- dune exec nopal

test:
    opam exec -- dune runtest

test-single-idx SUITE NAME_REGEX CASE:
    opam exec -- dune exec test/test_{{ SUITE }}.exe -- test "{{ NAME_REGEX }}" "{{ CASE }}"

test-list SUITE:
    opam exec -- dune exec test/test_{{ SUITE }}.exe -- list

fmt:
    opam exec -- dune fmt

lint-doc:
    #!/usr/bin/env bash
    set -euo pipefail
    out=$(opam exec -- dune build @doc --force 2>&1)
    printf '%s\n' "$out"
    if printf '%s\n' "$out" | grep -q 'Warning:'; then
        echo 'lint-doc FAIL: odoc warnings present (CI treats these as errors)' >&2
        exit 1
    fi

lint-fmt:
    opam exec -- dune build @fmt

lint-opam:
    opam exec -- opam-dune-lint

lint: lint-doc lint-fmt lint-opam

# Examples

serve-counter: build
    @echo "Serving counter at http://localhost:8000"
    @cp examples/counter/index.html _build/default/examples/counter/
    python3 -m http.server 8000 -d _build/default/examples/counter

serve-todomvc: build
    @echo "Serving todomvc at http://localhost:8000"
    @cp examples/todomvc/index.html _build/default/examples/todomvc/
    python3 -m http.server 8000 -d _build/default/examples/todomvc

serve-kitchen: build
    @echo "Serving kitchen sink at http://localhost:8000"
    @cp examples/kitchen_sink/index.html _build/default/examples/kitchen_sink/
    python3 -m http.server 8000 -d _build/default/examples/kitchen_sink

serve-dashboard: build
    @echo "Serving dashboard at http://localhost:8000"
    @cp examples/dashboard/index.html _build/default/examples/dashboard/
    python3 -m http.server 8000 -d _build/default/examples/dashboard

# E2E

e2e: build
    cd test/e2e && npx playwright test

# Benchmarks

bench-setup:
    cd bench/runner && npm ci --silent
    cd bench/runner && npx playwright install chromium

bench-setup-ci:
    cd bench/runner && npm ci --silent
    cd bench/runner && npx playwright install --with-deps chromium

bench: build
    #!/usr/bin/env bash
    set -euo pipefail
    cd bench/runner
    npx playwright test
    npx tsx bundle-size.ts
    npx tsx collect.ts

bench-compare: bench
    npx tsx bench/runner/compare.ts

# Versioning

version:
    cz version --project

next-version:
    cz bump --dry-run --get-next
