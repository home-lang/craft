// Tauri Hello World - Benchmark App
//
// Minimal Tauri app for startup time measurement.
// Build: cd src-tauri && cargo build --release
// Run:   ./target/release/tauri-hello-world
//
// Set BENCHMARK=1 to auto-quit after app is initialized.
// The setup() callback fires after windows are created from config
// but before the event loop processes paint events.

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            if std::env::var("BENCHMARK").unwrap_or_default() == "1" {
                let handle = app.handle().clone();
                // Exit from a spawned thread so the event loop can start briefly.
                // This gives the window time to be shown before we exit.
                std::thread::spawn(move || {
                    // Small yield to let the run-loop tick once (window creation)
                    std::thread::sleep(std::time::Duration::from_millis(50));
                    println!("ready");
                    handle.exit(0);
                });
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
