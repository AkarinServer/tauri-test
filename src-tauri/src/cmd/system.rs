use super::CmdResult;
use crate::{
    core::{CoreManager, handle},
    logging,
    module::sysinfo::PlatformSpecification,
    utils::logging::Type,
};
#[cfg(target_os = "windows")]
use deelevate::{PrivilegeLevel, Token};
use once_cell::sync::Lazy;
use tauri_plugin_clipboard_manager::ClipboardExt as _;
use tokio::time::Instant;

// 存储应用启动时间的全局变量
static APP_START_TIME: Lazy<Instant> = Lazy::new(Instant::now);
#[cfg(not(target_os = "windows"))]
static APPS_RUN_AS_ADMIN: Lazy<bool> = Lazy::new(|| unsafe { libc::geteuid() } == 0);
#[cfg(target_os = "windows")]
static APPS_RUN_AS_ADMIN: Lazy<bool> = Lazy::new(|| {
    Token::with_current_process()
        .and_then(|token| token.privilege_level())
        .map(|level| level != PrivilegeLevel::NotPrivileged)
        .unwrap_or(false)
});

#[tauri::command]
pub async fn export_diagnostic_info() -> CmdResult<()> {
    let sysinfo = PlatformSpecification::new_sync();
    let info = format!("{sysinfo:?}");

    let app_handle = handle::Handle::app_handle();
    let cliboard = app_handle.clipboard();
    if cliboard.write_text(info).is_err() {
        logging!(error, Type::System, "Failed to write to clipboard");
    }
    Ok(())
}

#[tauri::command]
pub async fn get_system_info() -> CmdResult<String> {
    let sysinfo = PlatformSpecification::new_sync();
    let info = format!("{sysinfo:?}");
    Ok(info)
}

/// 获取当前内核运行模式
#[tauri::command]
pub async fn get_running_mode() -> CmdResult<String> {
    use crate::core::manager::RunningMode;
    
    logging!(info, Type::Cmd, "[get_running_mode] 命令被调用");
    
    let mode = CoreManager::global().get_running_mode();
    let stored_mode = (*mode).clone();
    logging!(info, Type::Cmd, "[get_running_mode] 存储的运行模式: {:?}", stored_mode);
    
    // 关键修复：如果存储的状态是NotRunning，但实际有sidecar进程在运行，则返回Sidecar
    // 这可以修复状态不同步的问题
    if matches!(stored_mode, RunningMode::NotRunning) {
        logging!(info, Type::Cmd, "[get_running_mode] 状态为 NotRunning，检查实际运行状态");
        
        // 检查Unix socket是否存在（最可靠的检查方式，不破坏状态）
        let socket_path = crate::config::IClashTemp::guard_external_controller_ipc();
        let socket_path_buf = std::path::PathBuf::from(&socket_path);
        logging!(info, Type::Cmd, "[get_running_mode] Socket 路径: {:?}", socket_path_buf);
        logging!(info, Type::Cmd, "[get_running_mode] Socket 存在: {}", socket_path_buf.exists());
        
        if socket_path_buf.exists() {
            // Socket存在，说明核心在运行，更新状态
            logging!(info, Type::Cmd, "[get_running_mode] Socket 存在，核心实际在运行，更新状态为 Sidecar");
            CoreManager::global().set_running_mode(RunningMode::Sidecar);
            return Ok("Sidecar".to_string());
        }
        
        logging!(info, Type::Cmd, "[get_running_mode] Socket 不存在，确认状态为 NotRunning");
        // 检查是否有sidecar进程在运行（通过检查进程是否存在）
        // 注意：不能使用take_child_sidecar，因为它会移除child
        // 我们通过检查Unix socket来判断，这是最可靠的方式
    }
    
    let result = format!("{}", stored_mode);
    logging!(info, Type::Cmd, "[get_running_mode] 返回运行模式: {}", result);
    Ok(result)
}

/// 获取应用的运行时间（毫秒）
#[tauri::command]
pub fn get_app_uptime() -> CmdResult<u128> {
    Ok(APP_START_TIME.elapsed().as_millis())
}

/// 检查应用是否以管理员身份运行
#[tauri::command]
pub fn is_admin() -> CmdResult<bool> {
    Ok(*APPS_RUN_AS_ADMIN)
}

/// 获取应用版本号
#[tauri::command]
pub fn get_app_version() -> CmdResult<String> {
    let app_handle = handle::Handle::app_handle();
    let version = app_handle.package_info().version.to_string();
    Ok(version)
}
