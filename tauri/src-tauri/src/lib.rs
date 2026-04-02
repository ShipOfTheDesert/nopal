#[cfg(not(target_os = "linux"))]
use tauri::{Emitter, Manager};

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
            let _handle = tray.spawn().unwrap();
            // Keep thread alive — ksni runs its D-Bus event loop internally
            loop {
                std::thread::park();
            }
        });
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_store::Builder::new().build())
        .setup(|app| {
            #[cfg(target_os = "linux")]
            tray_linux::setup(app);

            #[cfg(not(target_os = "linux"))]
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
        })
        // Intercept window close: hide instead of quit so tray icon stays alive
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
