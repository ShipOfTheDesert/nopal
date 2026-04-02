# Tauri v2 System Tray on Linux with `ksni`

## The Problem

Tauri v2's built-in tray icon uses `libappindicator` on Linux, which:

1. Requires a context menu to be attached or the icon won't appear on GNOME
2. Always shows the menu on any click — no way to distinguish left vs right click
3. Never fires click events to your app code

The `ksni` crate implements the StatusNotifierItem D-Bus protocol directly in
pure Rust, giving you proper **double-click to activate** behavior on GNOME
(matching apps like GlobalProtect).

## Prerequisites

- Ubuntu/GNOME with the AppIndicator extension (installed by default on Ubuntu):
  ```bash
  sudo apt install gnome-shell-extension-appindicator libayatana-appindicator3-dev
  ```
- A Tauri v2 project (`npm create tauri-app@latest`)
- A PNG icon at `src-tauri/icons/icon.png` (at least 64x64, RGBA)

## Step 1 — Add dependencies to `Cargo.toml`

```toml
[dependencies]
tauri = { version = "2", features = ["image-png", "tray-icon"] }
# ... your other deps

# ksni + image only needed on Linux
[target.'cfg(target_os = "linux")'.dependencies]
ksni = { version = "0.3", features = ["blocking"] }
image = { version = "0.25", default-features = false, features = ["png"] }
```

The `tray-icon` feature is still needed for macOS/Windows. The `image` crate
decodes the PNG into RGBA pixels that ksni sends over D-Bus.

## Step 2 — Remove `trayIcon` from `tauri.conf.json`

Do **not** declare a `trayIcon` in the config. The tray is created entirely from
Rust code, platform-conditionally:

```json
{
  "app": {
    "windows": [{ "title": "My App", "width": 1024, "height": 768 }],
    "security": { "csp": null }
  }
}
```

## Step 3 — Write `src/lib.rs`

```rust
#[cfg(not(target_os = "linux"))]
use tauri::{Emitter, Manager};

// -- Linux: ksni-based tray (pure Rust StatusNotifierItem) -----------
#[cfg(target_os = "linux")]
mod tray_linux {
    use image::GenericImageView;
    use ksni::blocking::TrayMethods;
    use tauri::{AppHandle, Emitter, Manager};

    struct AppTray {
        app_handle: AppHandle,
    }

    impl std::fmt::Debug for AppTray {
        fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
            f.debug_struct("AppTray").finish()
        }
    }

    impl ksni::Tray for AppTray {
        // false = double-click calls activate(), single-click does nothing
        // true  = any click shows the menu
        const MENU_ON_ACTIVATE: bool = false;

        fn id(&self) -> String {
            "my-app-id".into()
        }

        fn title(&self) -> String {
            "My App".into()
        }

        fn icon_pixmap(&self) -> Vec<ksni::Icon> {
            let png_bytes = include_bytes!("../icons/icon.png");
            let img = image::load_from_memory(png_bytes)
                .expect("failed to decode tray icon PNG");
            let (w, h) = img.dimensions();
            let mut data = img.into_rgba8().into_raw();
            // SNI protocol expects ARGB in network byte order -- rotate RGBA -> ARGB
            for pixel in data.chunks_exact_mut(4) {
                pixel.rotate_right(1);
            }
            vec![ksni::Icon {
                width: w as i32,
                height: h as i32,
                data,
            }]
        }

        fn activate(&mut self, _x: i32, _y: i32) {
            // Called on double-click on GNOME
            if let Some(win) = self.app_handle.get_webview_window("main") {
                let _ = win.show();
                let _ = win.set_focus();
            }
            // Optional: emit event to frontend JS
            let _ = self.app_handle.emit("tray-click", "activate");
        }

        // Return empty vec for no context menu (GlobalProtect style).
        // Or add menu items for a right-click context menu:
        //
        // fn menu(&self) -> Vec<ksni::MenuItem<Self>> {
        //     use ksni::menu::*;
        //     vec![
        //         StandardItem {
        //             label: "Show Window".into(),
        //             activate: Box::new(|this: &mut Self| this.activate(0, 0)),
        //             ..Default::default()
        //         }.into(),
        //         ksni::MenuItem::Separator,
        //         StandardItem {
        //             label: "Quit".into(),
        //             icon_name: "application-exit".into(),
        //             activate: Box::new(|this: &mut Self| this.app_handle.exit(0)),
        //             ..Default::default()
        //         }.into(),
        //     ]
        // }
    }

    pub fn setup(app: &tauri::App) {
        let app_handle = app.handle().clone();
        std::thread::spawn(move || {
            let tray = AppTray { app_handle };
            let _handle = tray.spawn().unwrap();
            loop {
                std::thread::park();
            }
        });
    }
}

// -- App entry point -------------------------------------------------
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            // Linux: use ksni (pure Rust SNI over D-Bus)
            #[cfg(target_os = "linux")]
            tray_linux::setup(app);

            // macOS/Windows: use Tauri's built-in tray
            #[cfg(not(target_os = "linux"))]
            {
                let handle = app.handle().clone();
                let icon = tauri::image::Image::from_bytes(
                    include_bytes!("../icons/icon.png"),
                )
                .expect("failed to load tray icon");
                let menu = tauri::menu::MenuBuilder::new(app)
                    .text("show", "Show Window")
                    .separator()
                    .text("quit", "Quit")
                    .build()?;
                app.on_menu_event(move |app_handle, event| {
                    match event.id().as_ref() {
                        "show" => {
                            if let Some(win) = app_handle.get_webview_window("main") {
                                let _ = win.show();
                                let _ = win.set_focus();
                            }
                            let _ = handle.emit("tray-click", "activate");
                        }
                        "quit" => app_handle.exit(0),
                        _ => {}
                    }
                });
                let _tray = tauri::tray::TrayIconBuilder::with_id("main")
                    .icon(icon)
                    .icon_as_template(false)
                    .menu(&menu)
                    .tooltip("My App")
                    .build(app)?;
            }

            Ok(())
        })
        // Intercept window close: hide instead of quit so tray icon stays alive.
        // Double-clicking the tray icon calls activate() which shows the window.
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

## Step 4 — Capabilities

In `src-tauri/capabilities/default.json`, include these permissions (needed for
the macOS/Windows path and for event communication):

```json
{
  "permissions": [
    "core:default",
    "core:event:allow-emit",
    "core:event:allow-listen",
    "core:window:allow-show",
    "core:window:allow-hide",
    "core:window:allow-set-focus",
    "core:tray:default",
    "core:menu:default"
  ]
}
```

## Step 5 — Listen to tray events from JavaScript (optional)

If your frontend needs to react to tray activation:

```javascript
import { listen } from '@tauri-apps/api/event';

await listen('tray-click', (event) => {
  console.log('Tray activated:', event.payload);
});
```

## Behavior Summary

| Action | Linux (GNOME) | macOS / Windows |
|---|---|---|
| Close window (X) | Hides to tray | Hides to tray |
| Single left-click tray | Nothing | Shows menu |
| Double left-click tray | Shows/focuses window | N/A |
| Right-click tray | Nothing | Shows menu |

The `.on_window_event` handler in Step 3 intercepts the close button and hides
the window instead of quitting. The app keeps running in the tray. Double-click
(Linux) or "Show Window" menu item (macOS/Windows) brings it back.

To actually quit the app, add a "Quit" button in your frontend that calls
`appWindow.close()` after setting a flag, or uncomment the right-click context
menu in the ksni implementation (see Step 3 comments). With a menu present,
GNOME changes behavior to: single-click shows menu after a short delay,
double-click activates.

## Why This Works

- **ksni** registers a StatusNotifierItem on D-Bus with the `Activate` method
  and `ItemIsMenu: false`
- The **GNOME AppIndicator extension** introspects the D-Bus interface, sees
  `Activate` is available, and routes double-click to it
- **No libappindicator dependency** — ksni uses `zbus` (pure Rust D-Bus)
  directly
- On macOS/Windows, Tauri's built-in tray works correctly out of the box since
  those platforms have proper click event support

## Background / Why Not Tauri's Built-in Tray on Linux

Tauri's tray uses `libappindicator` on Linux which implements the
StatusNotifierItem spec incompletely — it never registers the `Activate` D-Bus
method, so the GNOME extension has no way to call it. This is a 15-year-old
upstream bug (Ubuntu Bug #522152). The `show_menu_on_left_click(false)` setting
has no effect on Linux. Tauri has an open PR (#12319) to add a `linux-ksni`
feature but it has not been released.

Apps affected by this same limitation: Telegram, Discord, Steam, all Electron
apps. They all fall back to menu-only tray interaction on GNOME.
