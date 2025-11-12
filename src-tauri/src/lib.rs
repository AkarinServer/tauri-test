#![allow(non_snake_case)]
#![recursion_limit = "512"]

mod cmd;

use tauri::Manager;

pub fn run() {
    // Minimal Tauri application setup for testing
    // Full implementation will be added in next steps

    let builder = tauri::Builder::default()
        .plugin(tauri_plugin_notification::init())
        // TODO: Add updater plugin when update server is ready
        // .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_clipboard_manager::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_deep_link::init())
        .plugin(tauri_plugin_http::init())
        // TODO: Add mihomo plugin when config module is ready
        // .plugin(tauri_plugin_mihomo::Builder::new()...)
        .invoke_handler(tauri::generate_handler![
            cmd::get_verge_config,
            cmd::patch_verge_config,
            cmd::get_runtime_config,
            cmd::patch_clash_config,
            cmd::patch_clash_mode,
            cmd::get_profiles,
            cmd::patch_profiles_config,
            cmd::create_profile,
            cmd::delete_profile,
            cmd::get_clash_logs,
            cmd::clear_logs,
            cmd::get_sys_proxy,
            cmd::get_running_mode,
            cmd::get_app_uptime,
            cmd::restart_app,
            cmd::exit_app,
            cmd::get_app_dir,
            cmd::open_app_dir,
        ])
        .setup(|app| {
            // Basic setup - just log that app is starting
            println!("RV Verge - Application starting...");
            
            // Get the main window and set title
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.set_title("RV Verge");
            }
            
            Ok(())
        });

    builder
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

