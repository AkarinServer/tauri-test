use anyhow::Result;

use crate::{
    config::Config,
    core::{
        CoreManager, Timer, handle,
        hotkey::Hotkey,
        service::{SERVICE_MANAGER, ServiceManager, is_service_ipc_path_exists},
        sysopt,
        tray::Tray,
    },
    logging, logging_error,
    module::{auto_backup::AutoBackupManager, lightweight::auto_lightweight_boot, signal},
    process::AsyncHandler,
    utils::{init, logging::Type, server, window_manager::WindowManager, debug_startup::with_timeout},
};

pub mod dns;
pub mod scheme;
pub mod ui;
pub mod window;
pub mod window_script;

pub fn resolve_setup_handle() {
    init_handle();
}

pub fn resolve_setup_sync() {
    AsyncHandler::spawn(|| async {
        AsyncHandler::spawn_blocking(init_scheme);
        AsyncHandler::spawn_blocking(init_embed_server);
        AsyncHandler::spawn_blocking(init_signal);
    });
}

pub fn resolve_setup_async() {
    AsyncHandler::spawn(|| async {
        #[cfg(not(feature = "tauri-dev"))]
        resolve_setup_logger().await;
        logging!(
            info,
            Type::ClashVergeRev,
            "Version: {}",
            env!("CARGO_PKG_VERSION")
        );

        // 将非关键初始化移到后台，不阻塞窗口显示
        let _background_init = AsyncHandler::spawn(|| async {
            let start_time = std::time::Instant::now();
            logging!(info, Type::Setup, "开始后台初始化...");
            
            futures::join!(
                init_work_config(),
                init_resources(),
                init_startup_script()
            );
            
            let elapsed = start_time.elapsed();
            logging!(info, Type::Setup, "后台初始化完成，耗时: {:?}", elapsed);
        });

        // 只等待最少的配置初始化，其他都移到后台
        // 添加超时保护，避免配置初始化阻塞启动
        let config_start = std::time::Instant::now();
        match with_timeout(
            "init_verge_config",
            std::time::Duration::from_secs(10), // 10秒超时
            init_verge_config(),
        ).await {
            Ok(_) => {
                let config_elapsed = config_start.elapsed();
                logging!(info, Type::Setup, "配置初始化完成，耗时: {:?}", config_elapsed);
            }
            Err(e) => {
                logging!(error, Type::Setup, "配置初始化失败或超时: {}", e);
                eprintln!("[启动诊断] ✗ 配置初始化失败或超时: {}", e);
            }
        }
        
        // 配置验证也移到后台，不阻塞窗口显示
        let _verify_init = AsyncHandler::spawn(|| async {
            let verify_start = std::time::Instant::now();
            let verify_result = tokio::time::timeout(
                std::time::Duration::from_secs(5), // 5秒超时
                Config::verify_config_initialization()
            ).await;
            
            match verify_result {
                Ok(()) => {
                    let elapsed = verify_start.elapsed();
                    logging!(info, Type::Setup, "配置验证完成，耗时: {:?}", elapsed);
                }
                Err(_) => {
                    logging!(warn, Type::Setup, "配置验证超时，继续运行");
                }
            }
        });
        
        // 立即显示窗口，不等待任何后台初始化
        // 添加超时保护，避免窗口初始化阻塞启动
        let window_start = std::time::Instant::now();
        match with_timeout(
            "init_window",
            std::time::Duration::from_secs(15), // 15秒超时
            init_window(),
        ).await {
            Ok(_) => {
                let window_elapsed = window_start.elapsed();
                logging!(info, Type::Setup, "窗口初始化完成，耗时: {:?}", window_elapsed);
            }
            Err(e) => {
                logging!(error, Type::Setup, "窗口初始化失败或超时: {}", e);
                eprintln!("[启动诊断] ✗ 窗口初始化失败或超时: {}", e);
            }
        }
        
        // 不等待后台初始化，让它们在后台完成
        // 这样可以立即显示窗口，大大加快启动速度

        let core_init = AsyncHandler::spawn(|| async {
            // 添加超时保护
            match with_timeout(
                "init_service_manager",
                std::time::Duration::from_secs(10),
                init_service_manager(),
            ).await {
                Ok(_) => {}
                Err(e) => {
                    logging!(error, Type::Setup, "服务管理器初始化失败或超时: {}", e);
                }
            }
            
            // init_core_manager 已经有超时保护，但这里再加一层诊断
            init_core_manager().await;
            
            match with_timeout(
                "init_system_proxy",
                std::time::Duration::from_secs(5),
                init_system_proxy(),
            ).await {
                Ok(_) => {}
                Err(e) => {
                    logging!(error, Type::Setup, "系统代理初始化失败或超时: {}", e);
                }
            }
            
            AsyncHandler::spawn_blocking(init_system_proxy_guard);
        });

        let tray_init = async {
            init_tray().await;
            refresh_tray_menu().await;
        };

        let _ = futures::join!(
            core_init,
            tray_init,
            init_timer(),
            init_hotkey(),
            init_auto_lightweight_boot(),
            init_auto_backup(),
        );
    });
}

pub async fn resolve_reset_async() -> Result<(), anyhow::Error> {
    sysopt::Sysopt::global().reset_sysproxy().await?;
    CoreManager::global().stop_core().await?;

    #[cfg(target_os = "macos")]
    {
        use dns::restore_public_dns;
        restore_public_dns().await;
    }

    Ok(())
}

pub fn init_handle() {
    handle::Handle::global().init();
}

pub(super) fn init_scheme() {
    logging_error!(Type::Setup, init::init_scheme());
}

#[cfg(not(feature = "tauri-dev"))]
pub(super) async fn resolve_setup_logger() {
    eprintln!("[RV Verge] Starting to initialize logger system...");
    if let Err(e) = init::init_logger().await {
        eprintln!("[RV Verge] FAILED: Logger initialization failed: {}", e);
        // Continue running even if logger initialization fails
    } else {
        eprintln!("[RV Verge] OK: Logger initialization succeeded");
    }
}

pub async fn resolve_scheme(param: &str) -> Result<()> {
    logging_error!(Type::Setup, scheme::resolve_scheme(param).await);
    Ok(())
}

pub(super) fn init_embed_server() {
    server::embed_server();
}

pub(super) async fn init_resources() {
    logging_error!(Type::Setup, init::init_resources().await);
}

pub(super) async fn init_startup_script() {
    logging_error!(Type::Setup, init::startup_script().await);
}

pub(super) async fn init_timer() {
    logging_error!(Type::Setup, Timer::global().init().await);
}

pub(super) async fn init_hotkey() {
    logging_error!(Type::Setup, Hotkey::global().init(false).await);
}

pub(super) async fn init_auto_lightweight_boot() {
    logging_error!(Type::Setup, auto_lightweight_boot().await);
}

pub(super) async fn init_auto_backup() {
    logging_error!(Type::Setup, AutoBackupManager::global().init().await);
}

pub(super) fn init_signal() {
    logging!(info, Type::Setup, "Initializing signal handlers...");
    signal::register();
}

pub async fn init_work_config() {
    logging_error!(Type::Setup, init::init_config().await);
}

pub(super) async fn init_tray() {
    if std::env::var("CLASH_VERGE_DISABLE_TRAY").unwrap_or_default() == "1" {
        return;
    }
    logging_error!(Type::Setup, Tray::global().init().await);
}

pub(super) async fn init_verge_config() {
    eprintln!("[启动诊断] 开始初始化 verge 配置...");
    let start = std::time::Instant::now();
    
    match Config::init_config().await {
        Ok(_) => {
            let elapsed = start.elapsed();
            logging!(info, Type::Setup, "verge 配置初始化完成，耗时: {:?}", elapsed);
            eprintln!("[启动诊断] ✓ verge 配置初始化完成，耗时: {:?}", elapsed);
        }
        Err(e) => {
            let elapsed = start.elapsed();
            logging!(error, Type::Setup, "verge 配置初始化失败: {} (耗时: {:?})", e, elapsed);
            eprintln!("[启动诊断] ✗ verge 配置初始化失败: {} (耗时: {:?})", e, elapsed);
        }
    }
}

pub(super) async fn init_service_manager() {
    clash_verge_service_ipc::set_config(ServiceManager::config()).await;
    if !is_service_ipc_path_exists() {
        return;
    }
    if SERVICE_MANAGER.lock().await.init().await.is_ok() {
        logging_error!(Type::Setup, SERVICE_MANAGER.lock().await.refresh().await);
    }
}

pub(super) async fn init_core_manager() {
    // 添加超时和日志，避免核心启动阻塞太久
    logging!(info, Type::Setup, "[init_core_manager] ===== 开始初始化核心管理器 =====");
    eprintln!("[启动诊断] 开始初始化核心管理器...");
    let start_time = std::time::Instant::now();
    
    // 检查当前运行模式
    let current_mode = CoreManager::global().get_running_mode();
    logging!(info, Type::Setup, "[init_core_manager] 当前运行模式: {:?}", current_mode);
    
    // 使用更详细的诊断包装
    logging!(info, Type::Setup, "[init_core_manager] 调用 CoreManager::global().init()，超时时间: 5分钟");
    match with_timeout(
        "CoreManager::init",
        std::time::Duration::from_secs(300), // 5分钟超时
        CoreManager::global().init(),
    ).await {
        Ok(Ok(())) => {
            let elapsed = start_time.elapsed();
            let final_mode = CoreManager::global().get_running_mode();
            logging!(info, Type::Setup, "[init_core_manager] ===== 核心管理器初始化成功 =====");
            logging!(info, Type::Setup, "[init_core_manager] 耗时: {:?}", elapsed);
            logging!(info, Type::Setup, "[init_core_manager] 最终运行模式: {:?}", final_mode);
            eprintln!("[启动诊断] ✓ 核心管理器初始化完成，耗时: {:?}", elapsed);
        }
        Ok(Err(e)) => {
            let elapsed = start_time.elapsed();
            let final_mode = CoreManager::global().get_running_mode();
            logging!(error, Type::Setup, "[init_core_manager] ===== 核心管理器初始化失败 =====");
            logging!(error, Type::Setup, "[init_core_manager] 耗时: {:?}", elapsed);
            logging!(error, Type::Setup, "[init_core_manager] 失败原因: {}", e);
            logging!(error, Type::Setup, "[init_core_manager] 失败详情: {:#}", e);
            logging!(error, Type::Setup, "[init_core_manager] 最终运行模式: {:?}", final_mode);
            eprintln!("[启动诊断] ✗ 核心管理器初始化失败: {}", e);
            eprintln!("[启动诊断] 错误详情: {:#}", e);
        }
        Err(e) => {
            let elapsed = start_time.elapsed();
            let final_mode = CoreManager::global().get_running_mode();
            logging!(error, Type::Setup, "[init_core_manager] ===== 核心管理器初始化超时 =====");
            logging!(error, Type::Setup, "[init_core_manager] 耗时: {:?}", elapsed);
            logging!(error, Type::Setup, "[init_core_manager] 超时原因: {}", e);
            logging!(error, Type::Setup, "[init_core_manager] 最终运行模式: {:?}", final_mode);
            logging!(error, Type::Setup, "[init_core_manager] 注意: 即使超时也继续，让应用能够启动");
            eprintln!("[启动诊断] ✗ 核心管理器初始化超时: {}", e);
            // 即使超时也继续，让应用能够启动
        }
    }
}

pub(super) async fn init_system_proxy() {
    logging_error!(
        Type::Setup,
        sysopt::Sysopt::global().update_sysproxy().await
    );
}

pub(super) fn init_system_proxy_guard() {
    logging_error!(Type::Setup, sysopt::Sysopt::global().init_guard_sysproxy());
}

pub(super) async fn refresh_tray_menu() {
    logging_error!(Type::Setup, Tray::global().update_part().await);
}

pub(super) async fn init_window() {
    logging!(info, Type::Window, "开始初始化窗口...");
    let is_silent_start = Config::verge()
        .await
        .data_arc()
        .enable_silent_start
        .unwrap_or(false);
    logging!(info, Type::Window, "静默启动模式: {}", is_silent_start);
    #[cfg(target_os = "macos")]
    if is_silent_start {
        use crate::core::handle::Handle;
        Handle::global().set_activation_policy_accessory();
    }
    let result = WindowManager::create_window(!is_silent_start).await;
    if result {
        logging!(info, Type::Window, "窗口创建成功");
    } else {
        logging!(error, Type::Window, "窗口创建失败");
    }
}
