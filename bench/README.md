# Benchmark Suite

Performance tracking for Nopal using the industry-standard
[js-framework-benchmark](https://github.com/krausest/js-framework-benchmark) operations
plus Nopal-specific incremental update and message throughput benchmarks.

## Running Benchmarks

```bash
just bench            # Build + run full suite, outputs bench/results.json
just bench-compare    # Run suite + compare against bench/baseline.json
```

`just bench` builds the jsfb app, launches a headless Chromium browser via
Playwright, runs all 9 jsfb operations and 2 custom benchmarks (each
measured as the median of 5 runs), measures bundle size, and aggregates
everything into `bench/results.json`.

`just bench-compare` runs the suite and then compares each metric against
`bench/baseline.json`. Any metric that regresses more than 20% causes a
non-zero exit.

## Baseline Schema

`bench/baseline.json` uses a unified format:

```json
{
  "version": 1,
  "timestamp": "2026-03-09T12:00:00Z",
  "runner": "local | github-actions",
  "metrics": {
    "jsfb/create_1000":                 { "value": 45.2,    "unit": "ms" },
    "jsfb/replace_1000":                { "value": 48.1,    "unit": "ms" },
    "jsfb/partial_update":              { "value": 12.3,    "unit": "ms" },
    "jsfb/select_row":                  { "value": 2.1,     "unit": "ms" },
    "jsfb/swap_rows":                   { "value": 3.4,     "unit": "ms" },
    "jsfb/remove_row":                  { "value": 5.2,     "unit": "ms" },
    "jsfb/create_10000":                { "value": 410.5,   "unit": "ms" },
    "jsfb/append_1000":                 { "value": 42.8,    "unit": "ms" },
    "jsfb/clear_rows":                  { "value": 8.7,     "unit": "ms" },
    "custom/incremental_update_1000":   { "value": 1.8,     "unit": "ms" },
    "custom/message_throughput_10000":   { "value": 25.3,    "unit": "ms" },
    "bundle/main_bc_js":                { "value": 3094210, "unit": "bytes" }
  }
}
```

Fields:

- **version** — Schema version (currently `1`)
- **timestamp** — ISO 8601 timestamp of when the results were collected
- **runner** — `"local"` for developer machines, `"github-actions"` in CI
- **metrics** — Map of metric name to `{ value, unit }` pairs

Metric naming convention: `<category>/<operation_name>`

| Category | Metrics |
|----------|---------|
| `jsfb/`  | The 9 standard js-framework-benchmark operations |
| `custom/`| Nopal-specific benchmarks (incremental update, message throughput) |
| `bundle/`| Bundle size measurements |

## Updating the Baseline

The baseline is updated **manually** — it is never auto-updated by CI or
scripts. This is intentional: baseline changes should be deliberate and
reviewed.

To update:

1. Run `just bench` on a quiet machine (close other applications, avoid
   background load)
2. Review the output in `bench/results.json`
3. Copy the results to the baseline: `cp bench/results.json bench/baseline.json`
4. Commit the updated baseline with a message explaining why (e.g.,
   "perf: update benchmark baseline after Lwd upgrade")

## Caveats

**Shared CI runners produce noisy measurements.** GitHub Actions runners
are shared infrastructure with variable load. Benchmark timings from CI
should be treated as approximate. The 20% regression threshold is
intentionally loose to account for this variance. CI benchmark failures
are reported as warnings (annotations), not as blocking status checks.

**Developer machine results are informational only.** Absolute timings vary
significantly between machines. Use `just bench-compare` to measure
relative changes against your local baseline, not to compare across
machines. When evaluating performance, focus on the delta (%) rather than
absolute values.

**Absolute values include rendering pipeline latency.** Timings measure
wall-clock time from operation trigger through rAF scheduling and DOM
mutation to verification — not pure framework update time. This is standard
for jsfb-style benchmarks and correct for regression detection. When
comparing absolute values to other frameworks, keep in mind that the
measurement includes Playwright IPC and browser rendering overhead.

**Median of 5 runs.** Each operation is run 5 times and the median is
taken. This reduces the impact of outliers but does not eliminate variance
entirely. For high-confidence measurements, run on a quiet machine and
consider increasing the run count in the Playwright specs.

## Project Structure

```
bench/
  baseline.json           — Committed performance baseline
  results.json            — Latest run output (gitignored)
  jsfb/
    jsfb.ml + .mli        — MVU app (all 9 jsfb operations)
    main.ml               — Thin mounting layer (only file importing nopal_web)
    index.html            — HTML host with jsfb-compliant DOM structure
    dune                  — Build config
  runner/
    playwright.config.ts  — Headless Chromium config
    jsfb.spec.ts          — 9 jsfb operation benchmarks
    custom.spec.ts        — Incremental update + message throughput benchmarks
    bundle-size.ts        — Bundle size measurement
    collect.ts            — Aggregates results into unified schema
    compare.ts            — Compares against baseline, 20% threshold
```
