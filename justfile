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

_require-android-home:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "${ANDROID_HOME:-}" ]; then
        echo 'error: ANDROID_HOME is not set - the Android SDK location is required to' >&2
        echo 'build the Tauri Android app. Install the SDK + NDK via Android Studio,' >&2
        echo 'then run:' >&2
        echo '' >&2
        echo '    export ANDROID_HOME="$HOME/Android/Sdk"' >&2
        echo '' >&2
        echo '(on macOS the default SDK path is "$HOME/Library/Android/sdk"). Persist it' >&2
        echo 'in your shell profile, then re-run this command. See CONTRIBUTING.md' >&2
        echo '"Compiler targets by platform" for the full Android toolchain setup.' >&2
        exit 1
    fi

# Fail loudly if `tauri android init` has clobbered the hand-written native
# bridge (RFC 0116). MainActivity.kt is the one tracked file in the otherwise
# generated/gitignored gen/android tree; a regeneration silently overwrites it
# with Tauri's default stub, which builds fine but drops safe-area/keyboard.
_require-native-bridge:
    #!/usr/bin/env bash
    set -euo pipefail
    activity='tauri/src-tauri/gen/android/app/src/main/java/run/nopal/kitchen_sink/MainActivity.kt'
    if [ ! -f "$activity" ] || ! grep -q 'report_safe_area' "$activity"; then
        echo "error: the hand-written Android native bridge is missing from" >&2
        echo "  $activity" >&2
        echo '' >&2
        echo '`tauri android init` regenerates this file with a default stub, dropping the' >&2
        echo 'RFC 0116 safe-area / soft-keyboard reads. Restore the tracked version with:' >&2
        echo '' >&2
        echo "    git checkout -- $activity" >&2
        echo '' >&2
        exit 1
    fi

# guard ANDROID_HOME + native bridge -> build JS (dev) -> `tauri android dev`
dev-android: _require-android-home _require-native-bridge tauri-prepare-dev
    cd tauri && npm exec tauri android dev

# guard ANDROID_HOME + native bridge -> build JS (release) -> `tauri android build` (.apk + .aab)
build-android: _require-android-home _require-native-bridge tauri-prepare-build
    cd tauri && npm exec tauri android build --apk --aab

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
# tauri-driver harness under a virtual display (REQ-F5). Main-only: the
# WebKitWebDriver + xvfb toolchain is off the per-PR critical path. Assumes
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
