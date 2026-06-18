# Tauri E2E suite (REQ-F5)

WebdriverIO + `tauri-driver` harness for the desktop-only behavioural contract
(RFC 0112, Step 7 / Options Considered §4, Option C). Playwright cannot drive the
native WebKit webview Tauri renders, so these specs use `tauri-driver` (the
official Tauri WebDriver bridge over `WebKitWebDriver`) and read telemetry from
the **host process** via the `get_telemetry` IPC command.

These specs gate on **`main` only**, not per-PR (`WebKitWebDriver` + `xvfb` are
heavy and `tauri-driver` flakes are off the PR critical path — RFC Risk list).
Task 8 wires the `just e2e-tauri` target and the `main`-only CI job.

## What's here

| File | Role |
|------|------|
| `wdio.conf.ts` | WebdriverIO config; spawns `tauri-driver`, points at the built binary |
| `nopal-telemetry-tauri.ts` | `NopalTelemetryTauri` — substring-fragment asserts over `get_telemetry`, mirroring the web `NopalTelemetry` |
| `tray.e2e.ts` | `simulate_tray_click` → `TrayClicked` via the host mirror |
| `window.e2e.ts` | title + visibility transitions via IPC telemetry |
| `store.e2e.ts` | store value survives a real relaunch (`reloadSession()`) |

## Local run (Linux)

`tauri-driver` is a **Cargo** binary, not an npm package. One-time setup:

```bash
# Debian/Ubuntu
sudo apt-get install -y webkit2gtk-driver xvfb

# Arch (the Bazzite `dev` distrobox) — WebKitWebDriver ships in webkitgtk-6.0
sudo pacman -S --needed webkitgtk-6.0 xorg-server-xvfb

cargo install tauri-driver
cd test/e2e/tauri && npm install
```

> On Arch, `WebKitWebDriver` comes from `webkitgtk-6.0` while Tauri's webview is
> `webkit2gtk-4.1`; if `tauri-driver` can't find a matching driver, check that the
> `WebKitWebDriver` on `PATH` lines up with the webview version. (This suite is
> `main`-only and hasn't been validated on Arch — patches welcome.)

Build the kitchen-sink Tauri binary (release; the config defaults to
`tauri/src-tauri/target/release/nopal-kitchen-sink`):

```bash
cd tauri && npm exec tauri build
```

Run the suite under a virtual display:

```bash
cd test/e2e/tauri && xvfb-run -a npm test
# or, against a debug build:
NOPAL_TAURI_APP=../../../tauri/src-tauri/target/debug/nopal-kitchen-sink \
  xvfb-run -a npm test
```

## Notes

- The kitchen-sink feeds the host mirror by calling
  `Nopal_tauri.Telemetry.expose` on Tauri startup (`examples/kitchen_sink/main.ml`);
  without it `get_telemetry` returns `[]`.
- Relaunch in `store.e2e.ts` is a WebdriverIO `reloadSession()` (binary exits,
  fresh launch), **not** a window close — close is intercepted to hide.
- Assertions go only through telemetry (REQ-N2); DOM is touched solely to trigger
  actions. Waits poll `get_telemetry`, never a fixed delay.
