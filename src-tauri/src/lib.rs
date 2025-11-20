#![allow(non_snake_case)]
#![recursion_limit = "512"]

mod cmd;
pub mod config;
mod constants;
mod core;
mod enhance;
mod feat;
mod module;
mod process;
pub mod utils;
use crate::constants::files;
#[cfg(target_os = "linux")]
use crate::utils::linux;
use crate::{
    core::{EventDrivenProxyManager, handle},
    process::AsyncHandler,
    utils::{resolve, server},
};
use anyhow::Result;
use once_cell::sync::OnceCell;
use rust_i18n::i18n;
use tauri::{AppHandle, Manager as _};
#[cfg(target_os = "macos")]
use tauri_plugin_autostart::MacosLauncher;
use tauri_plugin_deep_link::DeepLinkExt as _;
use utils::logging::Type;

i18n!("locales", fallback = "zh");

pub static APP_HANDLE: OnceCell<AppHandle> = OnceCell::new();
/// Application initialization helper functions
mod app_init {
    use super::*;

    /// Initialize singleton monitoring for other instances
    pub fn init_singleton_check() -> Result<()> {
        // 添加超时，避免单例检查阻塞启动
        AsyncHandler::block_on(async move {
            logging!(info, Type::Setup, "开始检查单例实例...");
            let start_time = std::time::Instant::now();
            
            let check_result = tokio::time::timeout(
                std::time::Duration::from_secs(2), // 2秒超时
                server::check_singleton()
            ).await;
            
            match check_result {
                Ok(Ok(())) => {
                    let elapsed = start_time.elapsed();
                    logging!(info, Type::Setup, "单例检查完成，耗时: {:?}", elapsed);
                    Ok(())
                }
                Ok(Err(e)) => {
                    logging!(error, Type::Setup, "单例检查失败: {}", e);
                    Err(e)
                }
                Err(_) => {
                    logging!(warn, Type::Setup, "单例检查超时，继续启动");
                    // 超时则继续启动，不阻塞
                    Ok(())
                }
            }
        })
    }

    /// Setup plugins for the Tauri builder
    pub fn setup_plugins(builder: tauri::Builder<tauri::Wry>) -> tauri::Builder<tauri::Wry> {
        #[allow(unused_mut)]
        let mut builder = builder
            .plugin(tauri_plugin_notification::init())
            // .plugin(tauri_plugin_updater::Builder::new().build()) // 暂时禁用 updater 插件
            .plugin(tauri_plugin_clipboard_manager::init())
            .plugin(tauri_plugin_process::init())
            .plugin(tauri_plugin_global_shortcut::Builder::new().build())
            .plugin(tauri_plugin_fs::init())
            .plugin(tauri_plugin_dialog::init())
            .plugin(tauri_plugin_shell::init())
            .plugin(tauri_plugin_deep_link::init())
            .plugin(tauri_plugin_http::init())
            .plugin(
                tauri_plugin_mihomo::Builder::new()
                    .protocol(tauri_plugin_mihomo::models::Protocol::LocalSocket)
                    .socket_path(crate::config::IClashTemp::guard_external_controller_ipc())
                    .pool_config(
                        tauri_plugin_mihomo::IpcPoolConfigBuilder::new()
                            .min_connections(0)
                            .max_connections(20)
                            .idle_timeout(std::time::Duration::from_millis(500))
                            // 关键修复：将健康检查间隔从10秒减少到1秒，避免启动时长时间等待
                            .health_check_interval(std::time::Duration::from_secs(1))
                            .build(),
                    )
                    .build(),
            );

        // Devtools plugin only in debug mode with feature tauri-dev
        // to avoid duplicated registering of logger since the devtools plugin also registers a logger
        #[cfg(all(debug_assertions, not(feature = "tokio-trace"), feature = "tauri-dev"))]
        {
            builder = builder.plugin(tauri_plugin_devtools::init());
        }
        builder
    }

    /// Setup deep link handling
    pub fn setup_deep_links(app: &tauri::App) -> Result<(), Box<dyn std::error::Error>> {
        #[cfg(any(target_os = "linux", all(debug_assertions, windows)))]
        {
            logging!(info, Type::Setup, "注册深层链接...");
            app.deep_link().register_all()?;
        }

        app.deep_link().on_open_url(|event| {
            let urls = event.urls();
            AsyncHandler::spawn(move || async move {
                if let Some(url) = urls.first()
                    && let Err(e) = resolve::resolve_scheme(url.as_ref()).await
                {
                    logging!(error, Type::Setup, "Failed to resolve scheme: {}", e);
                }
            });
        });

        Ok(())
    }

    /// Setup autostart plugin
    pub fn setup_autostart(app: &tauri::App) -> Result<(), Box<dyn std::error::Error>> {
        #[cfg(target_os = "macos")]
        let mut auto_start_plugin_builder = tauri_plugin_autostart::Builder::new();
        #[cfg(not(target_os = "macos"))]
        let auto_start_plugin_builder = tauri_plugin_autostart::Builder::new();

        #[cfg(target_os = "macos")]
        {
            auto_start_plugin_builder = auto_start_plugin_builder
                .macos_launcher(MacosLauncher::LaunchAgent)
                .app_name(&app.config().identifier);
        }
        app.handle().plugin(auto_start_plugin_builder.build())?;
        Ok(())
    }

    /// Setup window state management
    pub fn setup_window_state(app: &tauri::App) -> Result<(), Box<dyn std::error::Error>> {
        logging!(info, Type::Setup, "初始化窗口状态管理...");
        let window_state_plugin = tauri_plugin_window_state::Builder::new()
            .with_filename(files::WINDOW_STATE)
            .with_state_flags(tauri_plugin_window_state::StateFlags::default())
            .build();
        app.handle().plugin(window_state_plugin)?;
        Ok(())
    }

    pub fn generate_handlers()
    -> impl Fn(tauri::ipc::Invoke<tauri::Wry>) -> bool + Send + Sync + 'static {
        tauri::generate_handler![
            cmd::get_sys_proxy,
            cmd::get_auto_proxy,
            cmd::open_app_dir,
            cmd::open_logs_dir,
            cmd::open_web_url,
            cmd::open_core_dir,
            cmd::open_app_log,
            cmd::open_core_log,
            cmd::get_portable_flag,
            cmd::get_network_interfaces,
            cmd::get_system_hostname,
            cmd::restart_app,
            cmd::start_core,
            cmd::stop_core,
            cmd::restart_core,
            cmd::notify_ui_ready,
            cmd::update_ui_stage,
            cmd::get_running_mode,
            cmd::get_app_uptime,
            cmd::get_auto_launch_status,
            cmd::is_admin,
            cmd::get_app_version,
            cmd::entry_lightweight_mode,
            cmd::exit_lightweight_mode,
            cmd::install_service,
            cmd::uninstall_service,
            cmd::reinstall_service,
            cmd::repair_service,
            cmd::is_service_available,
            cmd::get_clash_info,
            cmd::patch_clash_config,
            cmd::patch_clash_mode,
            cmd::change_clash_core,
            cmd::get_runtime_config,
            cmd::get_runtime_yaml,
            cmd::get_runtime_exists,
            cmd::get_runtime_logs,
            cmd::get_runtime_proxy_chain_config,
            cmd::update_proxy_chain_config_in_runtime,
            cmd::invoke_uwp_tool,
            cmd::copy_clash_env,
            cmd::sync_tray_proxy_selection,
            cmd::save_dns_config,
            cmd::apply_dns_config,
            cmd::check_dns_config_exists,
            cmd::get_dns_config_content,
            cmd::validate_dns_config,
            cmd::get_clash_logs,
            cmd::get_verge_config,
            cmd::patch_verge_config,
            cmd::test_delay,
            cmd::get_app_dir,
            cmd::copy_icon_file,
            cmd::download_icon_cache,
            cmd::clear_all_data,
            cmd::open_devtools,
            cmd::exit_app,
            cmd::get_network_interfaces_info,
            cmd::get_profiles,
            cmd::enhance_profiles,
            cmd::patch_profiles_config,
            cmd::patch_profiles_config_by_profile_index,
            cmd::view_profile,
            cmd::patch_profile,
            cmd::create_profile,
            cmd::import_profile,
            cmd::reorder_profile,
            cmd::update_profile,
            cmd::delete_profile,
            cmd::read_profile_file,
            cmd::save_profile_file,
            cmd::get_next_update_time,
            cmd::script_validate_notice,
            cmd::validate_script_file,
            cmd::create_local_backup,
            cmd::list_local_backup,
            cmd::delete_local_backup,
            cmd::restore_local_backup,
            cmd::export_local_backup,
            cmd::create_webdav_backup,
            cmd::save_webdav_config,
            cmd::list_webdav_backup,
            cmd::delete_webdav_backup,
            cmd::restore_webdav_backup,
            cmd::export_diagnostic_info,
            cmd::get_system_info,
            cmd::get_unlock_items,
            cmd::check_media_unlock,
        ]
    }
}

pub fn run() {
    // Output to stderr first, so it's visible
    eprintln!("[RV Verge] ===== run() function started =====");
    eprintln!("[RV Verge] Application starting...");
    
    // Try to output logs, even if logger may not be initialized yet
    logging!(info, Type::Setup, "Application starting...");
    
    eprintln!("[RV Verge] Starting singleton check...");
    match app_init::init_singleton_check() {
        Ok(_) => {
            eprintln!("[RV Verge] OK: Singleton check passed");
            logging!(info, Type::Setup, "Singleton check passed");
        }
        Err(e) => {
            eprintln!("[RV Verge] FAILED: Singleton check failed: {}, application will exit", e);
            eprintln!("[RV Verge] ===== Application startup failed =====");
            logging!(error, Type::Setup, "Singleton check failed: {}, application will exit", e);
            return;
        }
    }

    eprintln!("[RV Verge] Initializing portable mode flag...");
    let _ = utils::dirs::init_portable_flag();

    #[cfg(target_os = "linux")]
    {
        eprintln!("[RV Verge] Configuring Linux environment...");
        linux::configure_environment();
    }

    eprintln!("[RV Verge] Setting up Tauri plugins...");
    let builder = app_init::setup_plugins(tauri::Builder::default())
        .setup(|app| {
            eprintln!("[RV Verge] ===== Tauri setup callback started =====");
            logging!(info, Type::Setup, "Starting application initialization...");
            eprintln!("[RV Verge] Setting global app handle...");

            #[allow(clippy::expect_used)]
            APP_HANDLE
                .set(app.app_handle().clone())
                .expect("failed to set global app handle");
            eprintln!("[RV Verge] OK: Global app handle set");

            eprintln!("[RV Verge] Setting up autostart...");
            if let Err(e) = app_init::setup_autostart(app) {
                eprintln!("[RV Verge] FAILED: Autostart setup failed: {}", e);
                logging!(error, Type::Setup, "Failed to setup autostart: {}", e);
            } else {
                eprintln!("[RV Verge] OK: Autostart setup completed");
            }

            eprintln!("[RV Verge] Setting up deep links...");
            if let Err(e) = app_init::setup_deep_links(app) {
                eprintln!("[RV Verge] FAILED: Deep links setup failed: {}", e);
                logging!(error, Type::Setup, "Failed to setup deep links: {}", e);
            } else {
                eprintln!("[RV Verge] OK: Deep links setup completed");
            }

            eprintln!("[RV Verge] Setting up window state...");
            if let Err(e) = app_init::setup_window_state(app) {
                eprintln!("[RV Verge] FAILED: Window state setup failed: {}", e);
                logging!(error, Type::Setup, "Failed to setup window state: {}", e);
            } else {
                eprintln!("[RV Verge] OK: Window state setup completed");
            }

            eprintln!("[RV Verge] Setting up resolve handlers...");
            resolve::resolve_setup_handle();
            eprintln!("[RV Verge] Starting async initialization...");
            resolve::resolve_setup_async();
            eprintln!("[RV Verge] Starting sync initialization...");
            resolve::resolve_setup_sync();

            logging!(info, Type::Setup, "Initialization started");
            eprintln!("[RV Verge] ===== Tauri setup callback completed =====");
            Ok(())
        })
        .invoke_handler(app_init::generate_handlers());

    eprintln!("[RV Verge] OK: Builder constructed");
    eprintln!("[RV Verge] Preparing to run Tauri application...");

    mod event_handlers {
        #[cfg(target_os = "macos")]
        use crate::module::lightweight;
        #[cfg(target_os = "macos")]
        use crate::utils::window_manager::WindowManager;
        use crate::{
            config::Config,
            core::{self, handle, hotkey},
            logging,
            process::AsyncHandler,
            utils::logging::Type,
        };
        use tauri::AppHandle;
        #[cfg(target_os = "macos")]
        use tauri::Manager as _;

        pub fn handle_ready_resumed(_app_handle: &AppHandle) {
            if handle::Handle::global().is_exiting() {
                logging!(debug, Type::System, "应用正在退出，跳过处理");
                return;
            }

            logging!(info, Type::System, "应用就绪");
            handle::Handle::global().init();

            #[cfg(target_os = "macos")]
            if let Some(window) = _app_handle.get_webview_window("main") {
                let _ = window.set_title("RV Verge");
            }
        }

        #[cfg(target_os = "macos")]
        pub async fn handle_reopen(has_visible_windows: bool) {
            handle::Handle::global().init();

            if lightweight::is_in_lightweight_mode() {
                lightweight::exit_lightweight_mode().await;
                return;
            }

            if !has_visible_windows {
                handle::Handle::global().set_activation_policy_regular();
                let _ = WindowManager::show_main_window().await;
            }
        }

        pub fn handle_window_close(api: &tauri::WindowEvent) {
            #[cfg(target_os = "macos")]
            handle::Handle::global().set_activation_policy_accessory();

            if core::handle::Handle::global().is_exiting() {
                return;
            }

            if let tauri::WindowEvent::CloseRequested { api, .. } = api {
                api.prevent_close();
                if let Some(window) = core::handle::Handle::get_window() {
                    let _ = window.hide();
                }
            }
        }

        pub fn handle_window_focus(focused: bool) {
            AsyncHandler::spawn(move || async move {
                let is_enable_global_hotkey = Config::verge()
                    .await
                    .data_arc()
                    .enable_global_hotkey
                    .unwrap_or(true);

                if focused {
                    #[cfg(target_os = "macos")]
                    {
                        use crate::core::hotkey::SystemHotkey;
                        let _ = hotkey::Hotkey::global()
                            .register_system_hotkey(SystemHotkey::CmdQ)
                            .await;
                        let _ = hotkey::Hotkey::global()
                            .register_system_hotkey(SystemHotkey::CmdW)
                            .await;
                    }
                    let _ = hotkey::Hotkey::global().init(true).await;
                    return;
                }

                #[cfg(target_os = "macos")]
                {
                    use crate::core::hotkey::SystemHotkey;
                    let _ = hotkey::Hotkey::global().unregister_system_hotkey(SystemHotkey::CmdQ);
                    let _ = hotkey::Hotkey::global().unregister_system_hotkey(SystemHotkey::CmdW);
                }

                if !is_enable_global_hotkey {
                    let _ = hotkey::Hotkey::global().reset();
                }
            });
        }

        #[cfg(target_os = "macos")]
        pub fn handle_window_destroyed() {
            use crate::core::hotkey::SystemHotkey;
            AsyncHandler::spawn(move || async move {
                let _ = hotkey::Hotkey::global().unregister_system_hotkey(SystemHotkey::CmdQ);
                let _ = hotkey::Hotkey::global().unregister_system_hotkey(SystemHotkey::CmdW);
                let is_enable_global_hotkey = Config::verge()
                    .await
                    .data_arc()
                    .enable_global_hotkey
                    .unwrap_or(true);
                if !is_enable_global_hotkey {
                    let _ = hotkey::Hotkey::global().reset();
                }
            });
        }
    }

    #[cfg(feature = "clippy")]
    let context = tauri::test::mock_context(tauri::test::noop_assets());
    #[cfg(feature = "clippy")]
    let app = builder.build(context).unwrap_or_else(|e| {
        eprintln!("[RV Verge] App 构建失败 (clippy): {}", e);
        logging!(
            error,
            Type::Setup,
            "Failed to build Tauri application: {}",
            e
        );
        std::process::exit(1);
    });

    #[cfg(not(feature = "clippy"))]
    let app = {
        eprintln!("[RV Verge] Starting to build App...");
        match builder.build(tauri::generate_context!()) {
            Ok(app) => {
                eprintln!("[RV Verge] OK: App built successfully");
                app
            }
            Err(e) => {
                eprintln!("[RV Verge] FAILED: App build failed: {}", e);
                logging!(
                    error,
                    Type::Setup,
                    "Failed to build Tauri application: {}",
                    e
                );
                std::process::exit(1);
            }
        }
    };

    eprintln!("[RV Verge] ===== Starting Tauri application =====");
    eprintln!("[RV Verge] Calling app.run()...");
    app.run(|app_handle, e| {
        // Output event info
        match e {
            tauri::RunEvent::Ready => {
                eprintln!("[RV Verge] OK: Application ready (Ready)");
            }
            tauri::RunEvent::Resumed => {
                eprintln!("[RV Verge] OK: Application resumed (Resumed)");
            }
            tauri::RunEvent::Exit => {
                eprintln!("[RV Verge] ===== Application exiting (Exit) =====");
            }
            _ => {}
        }
        
        // Handle events
        match e {
            tauri::RunEvent::Ready | tauri::RunEvent::Resumed => {
                if core::handle::Handle::global().is_exiting() {
                    return;
                }
                event_handlers::handle_ready_resumed(app_handle);
            }
            #[cfg(target_os = "macos")]
            tauri::RunEvent::Reopen {
                has_visible_windows,
                ..
            } => {
                if core::handle::Handle::global().is_exiting() {
                    return;
                }
                AsyncHandler::spawn(move || async move {
                    event_handlers::handle_reopen(has_visible_windows).await;
                });
            }
            tauri::RunEvent::ExitRequested { api, code, .. } => {
                AsyncHandler::block_on(async {
                    let _ = handle::Handle::mihomo()
                        .await
                        .clear_all_ws_connections()
                        .await;
                });

                if core::handle::Handle::global().is_exiting() {
                    return;
                }

                if code.is_none() {
                    api.prevent_exit();
                }
            }
            tauri::RunEvent::Exit => {
                let handle = core::handle::Handle::global();
                if !handle.is_exiting() {
                    handle.set_is_exiting();
                    EventDrivenProxyManager::global().notify_app_stopping();
                    feat::clean();
                }
            }
            tauri::RunEvent::WindowEvent { label, event, .. } if label == "main" => match event {
                tauri::WindowEvent::CloseRequested { .. } => {
                    event_handlers::handle_window_close(&event);
                }
                tauri::WindowEvent::Focused(focused) => {
                    event_handlers::handle_window_focus(focused);
                }
                #[cfg(target_os = "macos")]
                tauri::WindowEvent::Destroyed => {
                    event_handlers::handle_window_destroyed();
                }
                _ => {}
            },
            _ => {}
        }
    });
}
