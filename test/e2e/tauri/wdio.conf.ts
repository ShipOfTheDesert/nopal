import { spawn, type ChildProcess } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import path from "node:path";

// WebdriverIO config for the Tauri (REQ-F5) suite, RFC 0112 Step 7 / Options
// Considered §4 (Option C). Playwright cannot attach to the native WebKit
// webview Tauri renders, so this harness drives `tauri-driver` — the official
// Tauri WebDriver bridge that wraps `WebKitWebDriver` on Linux — and runs
// `invoke('get_telemetry')` inside the webview to read the host-side telemetry
// mirror fed by `Nopal_tauri.Telemetry.expose`.
//
// This config does NOT build the app; it expects the Tauri binary to exist
// already (`cd tauri && npm exec tauri build`). See README.md for the full
// local run sequence (it gates on `main`, not per-PR).

const repoRoot = path.resolve(__dirname, "..", "..", "..");

// The kitchen-sink Tauri binary (productName `nopal-kitchen-sink`). Defaults to
// the release build produced by `npm exec tauri build`; override with
// NOPAL_TAURI_APP to point at a `--debug` build or a bundled location.
const application =
  process.env.NOPAL_TAURI_APP ??
  path.join(
    repoRoot,
    "tauri",
    "src-tauri",
    "target",
    "release",
    "nopal-kitchen-sink"
  );

// `tauri-driver` is a Cargo binary; prefer PATH, fall back to ~/.cargo/bin.
const cargoBin = path.join(homedir(), ".cargo", "bin", "tauri-driver");
const tauriDriverBin = existsSync(cargoBin) ? cargoBin : "tauri-driver";

let tauriDriver: ChildProcess | undefined;

export const config: WebdriverIO.Config = {
  hostname: "127.0.0.1",
  port: 4444,
  // tauri-driver speaks the WebDriver classic protocol; no /wd/hub prefix.
  path: "/",
  specs: ["./*.e2e.ts"],
  // The store relaunch spec restarts the binary via reloadSession(); a single
  // sequential worker keeps the one tauri-driver ↔ one app process invariant.
  maxInstances: 1,
  capabilities: [
    {
      // tauri-driver-specific capability; not in the WebdriverIO type surface.
      // @ts-expect-error — tauri:options is injected by tauri-driver.
      "tauri:options": { application },
    },
  ],
  logLevel: "info",
  reporters: ["spec"],
  framework: "mocha",
  mochaOpts: {
    ui: "bdd",
    // Tauri cold start + the async IPC telemetry round-trip need headroom; the
    // helper polls within this budget rather than racing a fixed delay.
    timeout: 60000,
  },
  // Spawn one tauri-driver for the run; reloadSession() (store relaunch) reuses
  // it to start a fresh app process — the genuine disk-backed-store restart.
  onPrepare: () => {
    tauriDriver = spawn(tauriDriverBin, [], {
      stdio: [null, process.stdout, process.stderr],
    });
    tauriDriver.on("error", (err) => {
      // eslint-disable-next-line no-console
      console.error(
        `nopal-e2e-tauri: failed to spawn tauri-driver (${tauriDriverBin}). ` +
          `Install it with \`cargo install tauri-driver\` and ensure ` +
          `WebKitWebDriver is present (\`sudo apt-get install webkit2gtk-driver\`).`,
        err
      );
    });
  },
  onComplete: () => {
    tauriDriver?.kill();
  },
};
