default: build test fmt lint

build:
    opam exec -- dune build

build-native:
    opam exec -- dune build lib/nopal_style lib/nopal_element lib/nopal_mvu lib/nopal_test lib/nopal_runtime

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
    out=$(opam exec -- dune build @doc 2>&1)
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
    @ln -sf ../../_build/default/examples/counter/main.bc.js examples/counter/main.bc.js
    python3 -m http.server 8000 -d examples/counter

# Versioning

version:
    cz version --project

next-version:
    cz bump --dry-run --get-next
