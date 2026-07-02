# Tauri E2E suite (REQ-F5)

WebdriverIO + `tauri-driver` harness for the desktop-only behavioural contract
(RFC 0112, Step 7 / Options Considered §4, Option C). Playwright cannot drive the
native WebKit webview Tauri renders, so these specs use `tauri-driver` (the
official Tauri WebDriver bridge over `WebKitWebDriver`) and read telemetry from
the **host process** via the `get_telemetry` IPC command.

These specs run as a **required per-PR gate** (feature 0120, Decision 2): the
`e2e-tauri` job in both `pr.yaml` and `main.yaml` builds the Tauri binary and
drives the suite under `xvfb`. Promoting it off "`main`-only" is the audit's fix
for the "e2e CI never runs against HEAD" miss (the tray E2E that never exercised
the `Store` breakage); `check-e2e-wired` (FR-6) guarantees every spec is matched
by a project this job runs.

## What's here

| File | Role |
|------|------|
| `wdio.conf.ts` | WebdriverIO config; spawns `tauri-driver`, points at the built binary |
| `nopal-telemetry-tauri.ts` | `NopalTelemetryTauri` — substring-fragment asserts over `get_telemetry`, mirroring the web `NopalTelemetry` |
| `tray.e2e.ts` | `simulate_tray_click` → `TrayClicked` via the host mirror |
| `window.e2e.ts` | title + visibility transitions via IPC telemetry |
| `store.e2e.ts` | store value survives a real relaunch (`reloadSession()`) |
| `event.e2e.ts` | `Event.emit` → real event bus → `Event.listen` → `TauriEventReceived` |

## Local run (Linux)

`tauri-driver` is a **Cargo** binary, not an npm package. One-time setup:

```bash
# Debian/Ubuntu
sudo apt-get install -y webkit2gtk-driver xvfb

# Arch (the Bazzite `dev` distrobox) — install BOTH the webview (webkit2gtk-4.1,
# what wry renders into) and the driver (WebKitWebDriver ships only in
# webkitgtk-6.0). `-Syu` so the two land at the same WebKitGTK version.
sudo pacman -Syu --needed webkit2gtk-4.1 webkitgtk-6.0 xorg-server-xvfb

cargo install tauri-driver
cd test/e2e/tauri && npm install
```

> **Validated on Arch** (the `dev` distrobox, WebKitGTK 2.52.4): `WebKitWebDriver`
> from `webkitgtk-6.0` (GTK4 API) drives wry's `webkit2gtk-4.1` (GTK3 API) webview
> fine — **as long as both packages are the same WebKitGTK version**. The
> automation protocol is keyed to the engine version, not the GTK API binding, so
> keep the two in lockstep across upgrades (a skew is what breaks session attach).
>
> **Node 22 is required.** `tauri-driver`'s legacy HTTP stack trips Node ≥24's
> stricter `undici`, which rejects session creation with `UND_ERR_INVALID_ARG`
> (every spec fails instantly at `POST /session`). CI pins Node 22 via
> `actions/setup-node`; on Arch install `nodejs-lts-jod`.

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
