import * as fs from "fs";
import * as path from "path";

const RESULTS_DIR = path.join(__dirname, "results");
const OUTPUT_PATH = path.resolve(__dirname, "../results.json");

interface CollectResult {
  name: string;
  values?: number[];
  value?: number;
  median?: number;
  unit: string;
}

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

function readJsonFile(filePath: string): CollectResult[] {
  if (!fs.existsSync(filePath)) return [];
  return JSON.parse(fs.readFileSync(filePath, "utf-8"));
}

function main() {
  const metrics: Record<string, Metric> = {};

  // Read jsfb results
  const jsfbResults = readJsonFile(path.join(RESULTS_DIR, "jsfb.json"));
  for (const r of jsfbResults) {
    metrics[`jsfb/${r.name}`] = {
      value: r.median ?? r.value ?? 0,
      unit: r.unit,
    };
  }

  // Read custom results
  const customResults = readJsonFile(path.join(RESULTS_DIR, "custom.json"));
  for (const r of customResults) {
    metrics[`custom/${r.name}`] = {
      value: r.median ?? r.value ?? 0,
      unit: r.unit,
    };
  }

  // Read charts results
  const chartsResults = readJsonFile(path.join(RESULTS_DIR, "charts.json"));
  for (const r of chartsResults) {
    metrics[`charts/${r.name}`] = {
      value: r.median ?? r.value ?? 0,
      unit: r.unit,
    };
  }

  // Read virtual list results
  const virtualListResults = readJsonFile(path.join(RESULTS_DIR, "virtual_list.json"));
  for (const r of virtualListResults) {
    metrics[`virtual_list/${r.name}`] = {
      value: r.median ?? r.value ?? 0,
      unit: r.unit,
    };
  }

  // Read bundle results
  const bundleResults = readJsonFile(path.join(RESULTS_DIR, "bundle.json"));
  for (const r of bundleResults) {
    metrics[`bundle/${r.name}`] = {
      value: r.value ?? r.median ?? 0,
      unit: r.unit,
    };
  }

  const baseline: Baseline = {
    version: 1,
    timestamp: new Date().toISOString(),
    runner: process.env.CI ? "github-actions" : "local",
    metrics,
  };

  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(baseline, null, 2) + "\n");
  console.log(`Collected ${Object.keys(metrics).length} metrics to ${OUTPUT_PATH}`);
}

main();
