import * as fs from "fs";
import * as path from "path";

const BASELINE_PATH = path.resolve(__dirname, "../baseline.json");
const RESULTS_PATH = path.resolve(__dirname, "../results.json");
const THRESHOLD = 0.20; // 20%

interface Metric {
  value: number;
  unit: string;
}

interface Baseline {
  version: number;
  timestamp: string;
  runner: string;
  metrics: Record<string, Metric>;
}

function main() {
  if (!fs.existsSync(BASELINE_PATH)) {
    console.error(`Baseline not found: ${BASELINE_PATH}`);
    console.error("Run 'just bench' first and copy results.json to baseline.json.");
    process.exit(1);
  }

  if (!fs.existsSync(RESULTS_PATH)) {
    console.error(`Results not found: ${RESULTS_PATH}`);
    console.error("Run 'just bench' first.");
    process.exit(1);
  }

  const baseline: Baseline = JSON.parse(
    fs.readFileSync(BASELINE_PATH, "utf-8")
  );
  const results: Baseline = JSON.parse(
    fs.readFileSync(RESULTS_PATH, "utf-8")
  );

  const allKeys = new Set([
    ...Object.keys(baseline.metrics),
    ...Object.keys(results.metrics),
  ]);

  let hasRegression = false;

  // Table header
  const header = [
    "Metric".padEnd(35),
    "Baseline".padStart(12),
    "Current".padStart(12),
    "Delta".padStart(10),
    "Status".padStart(8),
  ].join(" | ");

  console.log(header);
  console.log("-".repeat(header.length));

  for (const key of [...allKeys].sort()) {
    const base = baseline.metrics[key];
    const curr = results.metrics[key];

    if (!base) {
      console.log(
        `${key.padEnd(35)} | ${"N/A".padStart(12)} | ${String(curr.value.toFixed(2)).padStart(12)} | ${"new".padStart(10)} | ${"  -".padStart(8)}`
      );
      continue;
    }

    if (!curr) {
      console.log(
        `${key.padEnd(35)} | ${String(base.value.toFixed(2)).padStart(12)} | ${"MISSING".padStart(12)} | ${"???".padStart(10)} | ${"FAIL".padStart(8)}`
      );
      hasRegression = true;
      continue;
    }

    const delta = base.value === 0 ? 0 : (curr.value - base.value) / base.value;
    const deltaStr = `${(delta * 100).toFixed(1)}%`;
    const isRegression = delta > THRESHOLD;

    if (isRegression) hasRegression = true;

    const status = isRegression ? "FAIL" : "OK";

    console.log(
      `${key.padEnd(35)} | ${String(base.value.toFixed(2)).padStart(12)} | ${String(curr.value.toFixed(2)).padStart(12)} | ${deltaStr.padStart(10)} | ${status.padStart(8)}`
    );
  }

  console.log();

  if (hasRegression) {
    console.error("REGRESSION DETECTED: One or more metrics exceeded the 20% threshold.");
    process.exit(1);
  } else {
    console.log("All metrics within threshold. No regressions detected.");
  }
}

main();
