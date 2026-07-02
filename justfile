default: build build-native test fmt lint e2e

# Fast check — no e2e, no lint-doc (slow odoc build)
fast: build build-native test fmt lint-fmt lint-opam

build:
    opam exec -- dune build

build-native:
    opam exec -- dune build lib/nopal_style lib/nopal_scene lib/nopal_draw lib/nopal_element lib/nopal_mvu lib/nopal_http lib/nopal_ui lib/nopal_test lib/nopal_runtime lib/nopal_platform lib/nopal_storage lib/nopal_fs_key lib/nopal_navigation lib/nopal_charts lib/nopal_svg examples/todomvc/todomvc.cma

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

# Static bug-class detector (ripgrep-only, no opam build) — see scripts/lint-classes.
lint-classes:
    scripts/lint-classes

# E2E-coverage check: every spec must be wired to a CI-run project — see scripts/check-e2e-wired.
check-e2e-wired:
    scripts/check-e2e-wired

lint: lint-doc lint-fmt lint-opam lint-classes check-e2e-wired

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

serve-http-demo: build
    @echo "Serving http_demo at http://localhost:8000"
    @cp examples/http_demo/index.html _build/default/examples/http_demo/
    python3 -m http.server 8000 -d _build/default/examples/http_demo

# Tauri

tauri-prepare-dev: build
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf tauri/dist
    mkdir -p tauri/dist
    cp examples/kitchen_sink/index.html _build/default/examples/kitchen_sink/main.bc.js tauri/dist/
    cp -r examples/kitchen_sink/assets tauri/dist/assets

tauri-prepare-build: build-release
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf tauri/dist
    mkdir -p tauri/dist
    cp examples/kitchen_sink/index.html _build/default/examples/kitchen_sink/main.bc.js tauri/dist/
    cp -r examples/kitchen_sink/assets tauri/dist/assets

dev-tauri: tauri-prepare-dev
    #!/usr/bin/env bash
    set -euo pipefail
    cleanup() {
        kill $DUNE_PID $SERVE_PID 2>/dev/null || true
        wait $DUNE_PID $SERVE_PID 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM
    # Watch for OCaml changes and rebuild assets
    (while true; do
        opam exec -- dune build 2>&1 | tail -1
        cp _build/default/examples/kitchen_sink/main.bc.js tauri/dist/ 2>/dev/null || true
        sleep 1
    done) &
    DUNE_PID=$!
    # Serve tauri/dist/ on port 1420
    miniserve --port 1420 --index index.html tauri/dist &
    SERVE_PID=$!
    # Launch Tauri dev window
    cd tauri && npm exec tauri dev

build-tauri:
    cd tauri && npm exec tauri build

# Android (Tauri mobile). Both recipes fail fast with an exact remediation
# command if ANDROID_HOME (the Android SDK location) is unset (REQ-F1). The
# guard runs before the JS build so a missing toolchain costs nothing. See
# CONTRIBUTING.md "Compiler targets by platform" for the full Android setup.

# Guard: ANDROID_HOME must be set for any Tauri Android build.
_require-android-home:
    scripts/android-require-home

# Guard: the hand-written native bridge (MainActivity.kt) must still be present —
# `tauri android init` silently regenerates over it (RFC 0116).
_require-native-bridge:
    scripts/android-require-bridge

# guard ANDROID_HOME + native bridge -> build JS (dev) -> `tauri android dev`
dev-android: _require-android-home _require-native-bridge tauri-prepare-dev
    cd tauri && npm exec tauri android dev

# guard ANDROID_HOME + native bridge -> build JS (release) -> `tauri android build` (.apk + .aab)
build-android: _require-android-home _require-native-bridge tauri-prepare-build
    cd tauri && npm exec tauri android build --apk --aab

# Windowed by default; headless for CI: `just run-android pixel7_api34 true`.
# Boot the emulator, build+install+launch the app — in one command.
run-android avd="pixel7_api34" headless="false": _require-android-home _require-native-bridge
    scripts/android-run {{ avd }} {{ headless }}

# Site — assemble examples mini-site into dist/

build-release:
    DUNE_PROFILE=release opam exec -- dune build

site: build-release
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf dist
    mkdir -p dist/counter dist/todomvc dist/kitchen_sink dist/dashboard
    cp examples/index.html dist/
    cp examples/counter/index.html     _build/default/examples/counter/main.bc.js     dist/counter/
    cp examples/todomvc/index.html     _build/default/examples/todomvc/main.bc.js     dist/todomvc/
    cp examples/kitchen_sink/index.html _build/default/examples/kitchen_sink/main.bc.js dist/kitchen_sink/
    cp -r examples/kitchen_sink/assets  dist/kitchen_sink/assets
    cp examples/dashboard/index.html   _build/default/examples/dashboard/main.bc.js   dist/dashboard/
    echo "Site assembled in dist/"

serve-site: site
    @echo "Serving site at http://localhost:8000"
    python3 -m http.server 8000 -d dist

# E2E

e2e: build
    cd test/e2e && npx playwright test

# Build the kitchen-sink Tauri binary, then drive it with the WebdriverIO +
# tauri-driver harness under a virtual display (REQ-F5). Runs as a required
# per-PR gate (feature 0120, Decision 2) in both pr.yaml and main.yaml. Assumes
# `cargo install tauri-driver`, `webkit2gtk-driver`, and `cd test/e2e/tauri &&
# npm ci` are already provisioned — see test/e2e/tauri/README.md.
e2e-tauri: build-tauri
    cd test/e2e/tauri && xvfb-run -a npm test

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
