import * as fs from "fs";
import * as path from "path";

const BUNDLE_PATH = path.resolve(
  __dirname,
  "../../_build/default/bench/jsfb/main.bc.js"
);
const RESULTS_DIR = path.join(__dirname, "results");

function main() {
  if (!fs.existsSync(BUNDLE_PATH)) {
    console.error(`Bundle not found: ${BUNDLE_PATH}`);
    console.error("Run 'opam exec -- dune build' first.");
    process.exit(1);
  }

  const stats = fs.statSync(BUNDLE_PATH);
  const sizeBytes = stats.size;

  console.log(`Bundle size: ${sizeBytes} bytes (${(sizeBytes / 1024).toFixed(1)} KB)`);

  if (!fs.existsSync(RESULTS_DIR)) {
    fs.mkdirSync(RESULTS_DIR, { recursive: true });
  }

  const result = [
    {
      name: "main_bc_js",
      value: sizeBytes,
      unit: "bytes",
    },
  ];

  fs.writeFileSync(
    path.join(RESULTS_DIR, "bundle.json"),
    JSON.stringify(result, null, 2)
  );
}

main();
