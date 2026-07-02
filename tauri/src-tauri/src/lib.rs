use serde_json::Value;
use std::collections::VecDeque;
use std::sync::Mutex;
use tauri::{Emitter, Listener, Manager};

// Bound on the host mirror: beyond this many events the oldest are dropped
// (drop-oldest). Kept in parity with the OCaml `Nopal_runtime.Telemetry`
// `log_capacity` so the host and browser mirrors agree and neither grows
// unbounded (feature 0120 FR-7).
const TELEMETRY_CAPACITY: usize = 10_000;

// Host-side mirror of the in-webview telemetry log (RFC 0110, Layer 3). Always
// compiled, but inert until the OCaml side calls `Nopal_tauri.Telemetry.expose`,
// which registers a forwarder that emits each event as `nopal:telemetry`. The
// listener registered in `run`'s setup appends those into this bounded deque, so
// `get_telemetry` can return the log from outside the webview. A `VecDeque` gives
// O(1) drop-oldest (`pop_front`) once the cap is reached.
struct TelemetryMirror(Mutex<VecDeque<Value>>);

#[tauri::command]
fn get_telemetry(mirror: tauri::State<'_, TelemetryMirror>) -> Vec<Value> {
    // Non-draining read: clone the mirror (oldest first) without emptying it, so
    // repeated reads see the same log — matching the browser `getEvents` bridge
    // (feature 0120 FR-7).
    match mirror.0.lock() {
        Ok(log) => log.iter().cloned().collect(),
        Err(_) => Vec::new(),
    }
}

#[tauri::command]
fn simulate_tray_click(app: tauri::AppHandle) {
    // Reuse the real tray-click signal; only the trigger is synthetic (REQ-F6).
    let _ = app.emit("nopal:tray-click", "Left");
}

#[tauri::command]
fn simulate_back_pressed(app: tauri::AppHandle) {
    // Phase 3: replace with Appium-driven OS event.
    // Desktop has no hardware back button, so nothing listens — a no-op there.
    let _ = app.emit("nopal:back-pressed", ());
}

// Bridge for native (Android) WindowInsets / IME reads → the OCaml mobile-signal
// subscriptions. The Kotlin `MainActivity` reads the real values and invokes
// these commands through the webview IPC; the command re-emits via `app.emit`,
// which (unlike a JS-side `plugin:event|emit`) is delivered to the in-webview
// `plugin:event|listen` handlers the OCaml `Platform_tauri` subscriptions
// register. Payload grammar matches `mobile_signals` and the OCaml parsers.
//
// These are registered on every platform (not `#[cfg(target_os = "android")]`)
// on purpose: it lets the IPC round-trip be exercised on the desktop
// `tauri-driver` CI lane (mobile_signals.e2e.ts), where no Android host exists.
// Inert in production off Android (nothing else invokes them); the worst a stray
// in-webview call can do is push a cosmetic mobile-signal value — acceptable for
// a local-first, first-party-content webview.
#[tauri::command]
fn report_safe_area(app: tauri::AppHandle, payload: String) {
    let _ = app.emit("nopal:safe-area", payload);
}

#[tauri::command]
fn report_keyboard_height(app: tauri::AppHandle, payload: String) {
    let _ = app.emit("nopal:keyboard-height", payload);
}

#[cfg(target_os = "linux")]
mod tray_linux {
    use image::GenericImageView;
    use ksni::blocking::TrayMethods;
    use tauri::{AppHandle, Emitter, Manager};

    struct NopalTray {
        app_handle: AppHandle,
    }

    impl std::fmt::Debug for NopalTray {
        fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
            f.debug_struct("NopalTray").finish()
        }
    }

    impl ksni::Tray for NopalTray {
        const MENU_ON_ACTIVATE: bool = false;

        fn id(&self) -> String {
            "nopal-kitchen-sink".into()
        }

        fn title(&self) -> String {
            "Nopal Kitchen Sink".into()
        }

        fn icon_pixmap(&self) -> Vec<ksni::Icon> {
            let png_bytes = include_bytes!("../icons/icon.png");
            let img = image::load_from_memory(png_bytes)
                .expect("failed to decode tray icon PNG");
            let (w, h) = img.dimensions();
            let mut data = img.into_rgba8().into_raw();
            // StatusNotifierItem expects ARGB in network byte order
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
            if let Some(win) = self.app_handle.get_webview_window("main") {
                let _ = win.show();
                let _ = win.set_focus();
            }
            let _ = self.app_handle.emit("nopal:tray-click", "Left");
        }

        // No menu — single left-click does nothing, double-click activates.
        // This matches GlobalProtect's behavior on GNOME.
    }

    pub fn setup(app: &tauri::App) {
        let app_handle = app.handle().clone();
        std::thread::spawn(move || {
            let tray = NopalTray { app_handle };
            match tray.spawn() {
                Ok(_handle) => {
                    // Keep thread alive — ksni runs its D-Bus event loop internally
                    loop {
                        std::thread::park();
                    }
                }
                // No StatusNotifier watcher on the session bus (headless CI, a
                // minimal WM, GNOME without the AppIndicator extension): register
                // fails. Log and let the tray thread exit instead of panicking —
                // the rest of the app runs fine without a tray icon.
                Err(err) => {
                    eprintln!("nopal: tray unavailable, continuing without it: {err}");
                }
            }
        });
    }
}

// Mobile signal emission (Android). Tauri v2 exposes no Rust API for safe-area
// insets, soft-keyboard height, or hardware-back interception — the real values
// come from the Android side (`WindowInsets` / IME via JNI or a Kotlin plugin)
// and require an initialized `gen/android` project, which lands with the Android
// build pipeline (RFC 0116, Task 7). Until then this emits structurally-correct
// events with the documented payload grammar and stub (zero) values.
//
// Two distinct "zero" semantics — do not conflate (RFC 0116 Decision 1):
//   - Desktop: this module is `#[cfg(target_os = "android")]`, so desktop never
//     runs it. No native event fires; the OCaml `Sub.custom` setup dispatches
//     zero insets / 0 keyboard height once. Zero is the correct PERMANENT
//     production value for desktop, not a placeholder.
//   - Android (here): zero is a TEMPORARY stub for the JNI/Kotlin inset + IME
//     reads (Task 7 / follow-up). The event names and payload format are the
//     stable contract and must not change; only the stubbed reads are replaced.
#[cfg(target_os = "android")]
mod mobile_signals {
    use tauri::{AppHandle, Emitter};

    // Payload: "top=<i>;right=<i>;bottom=<i>;left=<i>;" — each field carries a
    // trailing ';' so no field substring-aliases another (undelimited-telemetry-
    // fragment-aliasing). Parsed by `Platform_tauri.parse_safe_area`.
    pub fn emit_safe_area(app: &AppHandle, top: i32, right: i32, bottom: i32, left: i32) {
        let payload = format!("top={top};right={right};bottom={bottom};left={left};");
        let _ = app.emit("nopal:safe-area", payload);
    }

    // Payload: "<i>" logical px — keyboard height when shown, 0 when hidden.
    // Parsed by `Platform_tauri.parse_keyboard_height`.
    pub fn emit_keyboard_height(app: &AppHandle, height: i32) {
        let _ = app.emit("nopal:keyboard-height", format!("{height}"));
    }

    // Reuse the same event `simulate_back_pressed` emits, so the OCaml
    // `enable_hardware_back` listener treats the real Android hardware-back
    // button and the debug command identically. Wired to the actual Android
    // back signal when `gen/android` exists (Task 7); kept here so the on-change
    // emit contract is co-located with the others.
    #[allow(dead_code)]
    pub fn emit_back_pressed(app: &AppHandle) {
        let _ = app.emit("nopal:back-pressed", ());
    }

    // Emitted once when the webview is ready: current insets + keyboard height.
    // Values are the Android zero-stub (see module note); the per-signal
    // emitters above are the hook the native change-callbacks call on
    // orientation / IME-visibility change.
    pub fn emit_startup(app: &AppHandle) {
        emit_safe_area(app, 0, 0, 0, 0);
        emit_keyboard_height(app, 0);
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = tauri::Builder::default()
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_fs::init())
        .manage(TelemetryMirror(Mutex::new(VecDeque::new())))
        .invoke_handler(tauri::generate_handler![
            get_telemetry,
            simulate_tray_click,
            simulate_back_pressed,
            report_safe_area,
            report_keyboard_height
        ])
        .setup(|app| {
            // Feed the host-side mirror from the in-webview forwarder
            // (RFC 0110, Layer 3). Inert until `Nopal_tauri.Telemetry.expose`
            // starts emitting `nopal:telemetry`.
            let mirror_handle = app.handle().clone();
            app.listen("nopal:telemetry", move |event| {
                if let Ok(value) = serde_json::from_str::<Value>(event.payload()) {
                    if let Some(state) = mirror_handle.try_state::<TelemetryMirror>() {
                        if let Ok(mut log) = state.0.lock() {
                            // Drop-oldest once at capacity so the mirror cannot
                            // grow unbounded (feature 0120 FR-7).
                            if log.len() >= TELEMETRY_CAPACITY {
                                log.pop_front();
                            }
                            log.push_back(value);
                        }
                    }
                }
            });

            // Emit the current mobile signals once the webview is ready. On
            // desktop this is compiled out (zero is delivered by the OCaml
            // subscription setup instead); see the `mobile_signals` note.
            #[cfg(target_os = "android")]
            mobile_signals::emit_startup(app.handle());

            #[cfg(target_os = "linux")]
            tray_linux::setup(app);

            #[cfg(all(desktop, not(target_os = "linux")))]
            {
                let handle = app.handle().clone();
                let icon = tauri::image::Image::from_bytes(
                    include_bytes!("../icons/icon.png"),
                )
                .expect("failed to load tray icon from PNG bytes");
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
                            let _ = handle.emit("nopal:tray-click", "Left");
                        }
                        "quit" => {
                            app_handle.exit(0);
                        }
                        _ => {}
                    }
                });
                let _tray = tauri::tray::TrayIconBuilder::with_id("main")
                    .icon(icon)
                    .icon_as_template(false)
                    .menu(&menu)
                    .tooltip("Nopal Kitchen Sink")
                    .build(app)?;
            }

            Ok(())
        });

    // Intercept window close: hide instead of quit so the tray icon stays
    // alive. Desktop-only — mobile webviews expose no `Window::hide`, and the
    // hide-on-close affordance has no analogue on Android/iOS.
    #[cfg(desktop)]
    let builder = builder.on_window_event(|window, event| {
        if let tauri::WindowEvent::CloseRequested { api, .. } = event {
            api.prevent_close();
            let _ = window.hide();
        }
    });

    builder
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
