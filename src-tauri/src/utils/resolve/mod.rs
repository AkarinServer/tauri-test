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
    eprintln!("[Core Startup] ===== resolve_setup_async() called, spawning async task =====");
    AsyncHandler::spawn(|| async {
        eprintln!("[Core Startup] ===== Async task started executing =====");
        eprintln!("[Core Startup] ===== Async initialization flow started =====");
        let async_flow_start = std::time::Instant::now();
        
        // Note: logging! macro may not work before logger is initialized
        // So we use eprintln! for all critical diagnostics
        
        #[cfg(not(feature = "tauri-dev"))]
        {
            eprintln!("[Core Startup] Step 0: Starting logger system initialization");
            eprintln!("[Core Startup] This step will read Config::verge() to get log settings");
            let logger_start = std::time::Instant::now();
            
            eprintln!("[Core Startup] Calling resolve_setup_logger()...");
            resolve_setup_logger().await;
            
            let logger_elapsed = logger_start.elapsed();
            eprintln!("[Core Startup] Step 0 completed: Logger system initialization finished, elapsed: {:?}", logger_elapsed);
            
            // Now that logger is initialized, we can use logging! macro
            logging!(info, Type::Setup, "[resolve_setup_async] 日志系统初始化完成，耗时: {:?}", logger_elapsed);
        }
        
        eprintln!("[Core Startup] Application version: {}", env!("CARGO_PKG_VERSION"));
        // Now logger is initialized, we can use logging! macro
        logging!(
            info,
            Type::ClashVergeRev,
            "Version: {}",
            env!("CARGO_PKG_VERSION")
        );

        // 将非关键初始化移到后台，不阻塞窗口显示
        eprintln!("[Core Startup] Spawning background initialization task...");
        let _background_init = AsyncHandler::spawn(|| async {
            eprintln!("[Core Startup] [background_init] Background initialization task started");
            let start_time = std::time::Instant::now();
            logging!(info, Type::Setup, "开始后台初始化...");
            eprintln!("[Core Startup] [background_init] Starting background tasks...");
            
            futures::join!(
                init_work_config(),
                init_resources(),
                init_startup_script()
            );
            
            let elapsed = start_time.elapsed();
            logging!(info, Type::Setup, "后台初始化完成，耗时: {:?}", elapsed);
            eprintln!("[Core Startup] [background_init] Background initialization completed, elapsed: {:?}", elapsed);
        });

        // 只等待最少的配置初始化，其他都移到后台
        // 添加超时保护，避免配置初始化阻塞启动
        eprintln!("[Core Startup] Step 1: Starting config initialization (timeout: 30s)");
        eprintln!("[Core Startup] Step 1: This will call init_verge_config()");
        let config_start = std::time::Instant::now();
        match with_timeout(
            "init_verge_config",
            std::time::Duration::from_secs(30), // 从10秒增加到30秒
            init_verge_config(),
        ).await {
            Ok(_) => {
                let config_elapsed = config_start.elapsed();
                eprintln!("[Core Startup] Step 1 completed: Config initialization succeeded, elapsed: {:?}", config_elapsed);
                logging!(info, Type::Setup, "配置初始化完成，耗时: {:?}", config_elapsed);
            }
            Err(e) => {
                let config_elapsed = config_start.elapsed();
                eprintln!("[Core Startup] Step 1 failed: Config initialization failed or timeout: {}, elapsed: {:?}", e, config_elapsed);
                logging!(error, Type::Setup, "配置初始化失败或超时: {}", e);
            }
        }
        
        // 配置验证也移到后台，不阻塞窗口显示
        eprintln!("[Core Startup] Spawning config verification task...");
        let _verify_init = AsyncHandler::spawn(|| async {
            eprintln!("[Core Startup] [verify_init] Config verification task started");
            eprintln!("[Core Startup] [verify_init] Starting config verification (timeout: 30s)");
            let verify_start = std::time::Instant::now();
            let verify_result = tokio::time::timeout(
                std::time::Duration::from_secs(30), // 从5秒增加到30秒
                Config::verify_config_initialization()
            ).await;
            
            match verify_result {
                Ok(()) => {
                    let elapsed = verify_start.elapsed();
                    eprintln!("[Core Startup] [verify_init] Config verification completed, elapsed: {:?}", elapsed);
                    logging!(info, Type::Setup, "配置验证完成，耗时: {:?}", elapsed);
                }
                Err(_) => {
                    let elapsed = verify_start.elapsed();
                    eprintln!("[Core Startup] [verify_init] Config verification timeout, elapsed: {:?}", elapsed);
                    logging!(warn, Type::Setup, "配置验证超时，继续运行");
                }
            }
        });
        
        // 立即显示窗口，不等待任何后台初始化
        // 添加超时保护，避免窗口初始化阻塞启动
        eprintln!("[Core Startup] Step 2: Starting window initialization (timeout: 60s)");
        eprintln!("[Core Startup] Step 2: This will call init_window()");
        let window_start = std::time::Instant::now();
        match with_timeout(
            "init_window",
            std::time::Duration::from_secs(60), // 从15秒增加到60秒
            init_window(),
        ).await {
            Ok(_) => {
                let window_elapsed = window_start.elapsed();
                eprintln!("[Core Startup] Step 2 completed: Window initialization succeeded, elapsed: {:?}", window_elapsed);
                logging!(info, Type::Setup, "窗口初始化完成，耗时: {:?}", window_elapsed);
            }
            Err(e) => {
                let window_elapsed = window_start.elapsed();
                eprintln!("[Core Startup] Step 2 failed: Window initialization failed or timeout: {}, elapsed: {:?}", e, window_elapsed);
                logging!(error, Type::Setup, "窗口初始化失败或超时: {}", e);
            }
        }
        
        // 不等待后台初始化，让它们在后台完成
        // 这样可以立即显示窗口，大大加快启动速度

        eprintln!("[Core Startup] Step 3: Starting core initialization task");
        eprintln!("[Core Startup] Step 3: Spawning core_init async task...");
        logging!(info, Type::Setup, "[resolve_setup_async] ===== 开始启动核心初始化任务 =====");
        
        let core_init = AsyncHandler::spawn(|| async {
            eprintln!("[Core Startup] [core_init] ===== Core initialization task started executing =====");
            logging!(info, Type::Setup, "[core_init] ===== 核心初始化任务开始执行 =====");
            let task_start = std::time::Instant::now();
            
            // 添加超时保护
            logging!(info, Type::Setup, "[core_init] 步骤1: 初始化服务管理器 (超时: 30秒)");
            eprintln!("[Core Startup] [core_init] Step 1: Initializing service manager (timeout: 30s)");
            match with_timeout(
                "init_service_manager",
                std::time::Duration::from_secs(30), // 从10秒增加到30秒
                init_service_manager(),
            ).await {
                Ok(_) => {
                    let elapsed = task_start.elapsed();
                    logging!(info, Type::Setup, "[core_init] 步骤1完成: 服务管理器初始化成功，耗时: {:?}", elapsed);
                    eprintln!("[Core Startup] [core_init] Step 1 completed: Service manager initialized, elapsed: {:?}", elapsed);
                }
                Err(e) => {
                    let elapsed = task_start.elapsed();
                    logging!(error, Type::Setup, "[core_init] 步骤1失败: 服务管理器初始化失败或超时: {}, 耗时: {:?}", e, elapsed);
                    eprintln!("[Core Startup] [core_init] Step 1 failed: Service manager initialization failed or timeout: {}, elapsed: {:?}", e, elapsed);
                }
            }
            
            // init_core_manager 已经有超时保护，但这里再加一层诊断
            logging!(info, Type::Setup, "[core_init] 步骤2: 初始化核心管理器 (超时: 10分钟)");
            eprintln!("[Core Startup] [core_init] Step 2: Initializing core manager (timeout: 10 minutes)");
            let core_manager_start = std::time::Instant::now();
            init_core_manager().await;
            let core_manager_elapsed = core_manager_start.elapsed();
            logging!(info, Type::Setup, "[core_init] 步骤2完成: 核心管理器初始化完成，耗时: {:?}", core_manager_elapsed);
            eprintln!("[Core Startup] [core_init] Step 2 completed: Core manager initialization finished, elapsed: {:?}", core_manager_elapsed);
            
            logging!(info, Type::Setup, "[core_init] 步骤3: 初始化系统代理 (超时: 15秒)");
            eprintln!("[Core Startup] [core_init] Step 3: Initializing system proxy (timeout: 15s)");
            match with_timeout(
                "init_system_proxy",
                std::time::Duration::from_secs(15), // 从5秒增加到15秒
                init_system_proxy(),
            ).await {
                Ok(_) => {
                    let elapsed = task_start.elapsed();
                    logging!(info, Type::Setup, "[core_init] 步骤3完成: 系统代理初始化成功，耗时: {:?}", elapsed);
                    eprintln!("[Core Startup] [core_init] Step 3 completed: System proxy initialized, elapsed: {:?}", elapsed);
                }
                Err(e) => {
                    let elapsed = task_start.elapsed();
                    logging!(error, Type::Setup, "[core_init] 步骤3失败: 系统代理初始化失败或超时: {}, 耗时: {:?}", e, elapsed);
                    eprintln!("[Core Startup] [core_init] Step 3 failed: System proxy initialization failed or timeout: {}, elapsed: {:?}", e, elapsed);
                }
            }
            
            logging!(info, Type::Setup, "[core_init] 步骤4: 启动系统代理守护进程");
            eprintln!("[Core Startup] [core_init] Step 4: Starting system proxy guard");
            AsyncHandler::spawn_blocking(init_system_proxy_guard);
            
            let total_elapsed = task_start.elapsed();
            logging!(info, Type::Setup, "[core_init] ===== 核心初始化任务完成，总耗时: {:?} =====", total_elapsed);
            eprintln!("[Core Startup] [core_init] ===== Core initialization task completed, total elapsed: {:?} =====", total_elapsed);
        });

        eprintln!("[Core Startup] Step 4: Preparing system tray initialization");
        let tray_init = async {
            eprintln!("[Core Startup] [tray_init] Starting system tray initialization");
            logging!(info, Type::Setup, "[resolve_setup_async] 开始初始化系统托盘");
            let tray_start = std::time::Instant::now();
            init_tray().await;
            refresh_tray_menu().await;
            let tray_elapsed = tray_start.elapsed();
            eprintln!("[Core Startup] [tray_init] System tray initialization completed, elapsed: {:?}", tray_elapsed);
            logging!(info, Type::Setup, "[resolve_setup_async] 系统托盘初始化完成，耗时: {:?}", tray_elapsed);
        };

        eprintln!("[Core Startup] Step 5: Starting concurrent execution of all initialization tasks");
        eprintln!("[Core Startup] Step 5: This includes: core_init, tray_init, timer, hotkey, lightweight, backup");
        logging!(info, Type::Setup, "[resolve_setup_async] ===== 开始并发执行所有初始化任务 =====");
        let join_start = std::time::Instant::now();
        
        eprintln!("[Core Startup] Step 5: Calling futures::join! to wait for all tasks...");
        let _ = futures::join!(
            core_init,
            tray_init,
            init_timer(),
            init_hotkey(),
            init_auto_lightweight_boot(),
            init_auto_backup(),
        );
        
        let join_elapsed = join_start.elapsed();
        eprintln!("[Core Startup] Step 5 completed: All initialization tasks finished, elapsed: {:?}", join_elapsed);
        logging!(info, Type::Setup, "[resolve_setup_async] ===== 所有初始化任务完成，总耗时: {:?} =====", join_elapsed);
        
        let total_elapsed = async_flow_start.elapsed();
        eprintln!("[Core Startup] ===== Async initialization flow completed, total elapsed: {:?} =====", total_elapsed);
        logging!(info, Type::Setup, "[resolve_setup_async] ===== 异步初始化流程完成，总耗时: {:?} =====", total_elapsed);
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
    eprintln!("[Core Startup] [resolve_setup_logger] ===== Starting logger system initialization =====");
    eprintln!("[Core Startup] [resolve_setup_logger] This will call init::init_logger()");
    eprintln!("[Core Startup] [resolve_setup_logger] Note: init_logger() needs to read Config::verge() first");
    
    let logger_init_start = std::time::Instant::now();
    eprintln!("[Core Startup] [resolve_setup_logger] Calling init::init_logger()...");
    
    if let Err(e) = init::init_logger().await {
        let elapsed = logger_init_start.elapsed();
        eprintln!("[Core Startup] [resolve_setup_logger] ✗ FAILED: Logger initialization failed after {:?}", elapsed);
        eprintln!("[Core Startup] [resolve_setup_logger] Error: {}", e);
        eprintln!("[Core Startup] [resolve_setup_logger] Error details: {:#}", e);
        // Continue running even if logger initialization fails
    } else {
        let elapsed = logger_init_start.elapsed();
        eprintln!("[Core Startup] [resolve_setup_logger] ✓ OK: Logger initialization succeeded, elapsed: {:?}", elapsed);
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
    eprintln!("[Core Startup] Starting core manager initialization...");
    let start_time = std::time::Instant::now();
    
    // 检查当前运行模式
    let current_mode = CoreManager::global().get_running_mode();
    logging!(info, Type::Setup, "[init_core_manager] 当前运行模式: {:?}", current_mode);
    eprintln!("[Core Startup] Current running mode: {:?}", current_mode);
    
    // 使用更详细的诊断包装
    logging!(info, Type::Setup, "[init_core_manager] 调用 CoreManager::global().init()，超时时间: 10分钟");
    eprintln!("[Core Startup] Calling CoreManager::global().init(), timeout: 10 minutes");
    match with_timeout(
        "CoreManager::init",
        std::time::Duration::from_secs(600), // 从5分钟增加到10分钟
        CoreManager::global().init(),
    ).await {
        Ok(Ok(())) => {
            let elapsed = start_time.elapsed();
            let final_mode = CoreManager::global().get_running_mode();
            logging!(info, Type::Setup, "[init_core_manager] ===== 核心管理器初始化成功 =====");
            logging!(info, Type::Setup, "[init_core_manager] 耗时: {:?}", elapsed);
            logging!(info, Type::Setup, "[init_core_manager] 最终运行模式: {:?}", final_mode);
            eprintln!("[Core Startup] ✓ Core manager initialization completed, elapsed: {:?}", elapsed);
            eprintln!("[Core Startup] Final running mode: {:?}", final_mode);
        }
        Ok(Err(e)) => {
            let elapsed = start_time.elapsed();
            let final_mode = CoreManager::global().get_running_mode();
            logging!(error, Type::Setup, "[init_core_manager] ===== 核心管理器初始化失败 =====");
            logging!(error, Type::Setup, "[init_core_manager] 耗时: {:?}", elapsed);
            logging!(error, Type::Setup, "[init_core_manager] 失败原因: {}", e);
            logging!(error, Type::Setup, "[init_core_manager] 失败详情: {:#}", e);
            logging!(error, Type::Setup, "[init_core_manager] 最终运行模式: {:?}", final_mode);
            eprintln!("[Core Startup] ✗ Core manager initialization failed: {}", e);
            eprintln!("[Core Startup] Error details: {:#}", e);
            eprintln!("[Core Startup] Elapsed: {:?}, Final running mode: {:?}", elapsed, final_mode);
        }
        Err(e) => {
            let elapsed = start_time.elapsed();
            let final_mode = CoreManager::global().get_running_mode();
            logging!(error, Type::Setup, "[init_core_manager] ===== 核心管理器初始化超时 =====");
            logging!(error, Type::Setup, "[init_core_manager] 耗时: {:?}", elapsed);
            logging!(error, Type::Setup, "[init_core_manager] 超时原因: {}", e);
            logging!(error, Type::Setup, "[init_core_manager] 最终运行模式: {:?}", final_mode);
            logging!(error, Type::Setup, "[init_core_manager] 注意: 即使超时也继续，让应用能够启动");
            eprintln!("[Core Startup] ✗ Core manager initialization timeout: {}", e);
            eprintln!("[Core Startup] Elapsed: {:?}, Final running mode: {:?}", elapsed, final_mode);
            eprintln!("[Core Startup] Note: Continuing despite timeout to allow app to start");
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
