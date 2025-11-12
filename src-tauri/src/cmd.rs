// Basic Tauri commands for RV Verge
// These are placeholder implementations until full functionality is ported

use serde_json::Value;
use tauri::Manager;

// Verge config commands
#[tauri::command]
pub fn get_verge_config() -> Result<serde_json::Map<String, Value>, String> {
    // Return default Verge config
    let mut config = serde_json::Map::new();
    config.insert("theme_mode".to_string(), Value::String("light".to_string()));
    config.insert("theme_blur".to_string(), Value::Bool(false));
    config.insert("traffic_graph".to_string(), Value::Bool(false));
    config.insert("enable_clash_fields".to_string(), Value::Bool(false));
    config.insert("verge_mixed_port".to_string(), Value::Number(7897.into()));
    config.insert("enable_auto_launch".to_string(), Value::Bool(false));
    config.insert("enable_service_mode".to_string(), Value::Bool(false));
    config.insert("enable_silent_start".to_string(), Value::Bool(false));
    config.insert("enable_system_proxy".to_string(), Value::Bool(false));
    config.insert("enable_proxy_guard".to_string(), Value::Bool(false));
    config.insert("system_proxy_bypass".to_string(), Value::String("".to_string()));
    config.insert("proxy_auto_config".to_string(), Value::Bool(false));
    config.insert("proxy_host".to_string(), Value::String("127.0.0.1".to_string()));
    config.insert("proxy_port".to_string(), Value::Number(7897.into()));
    Ok(config)
}

#[tauri::command]
pub fn patch_verge_config(_payload: serde_json::Map<String, Value>) -> Result<(), String> {
    // Placeholder: in the future, this will save config to file
    Ok(())
}

// Clash config commands
#[tauri::command]
pub fn get_runtime_config() -> Result<serde_json::Map<String, Value>, String> {
    // Return default Clash config
    let mut config = serde_json::Map::new();
    config.insert("port".to_string(), Value::Number(7890.into()));
    config.insert("socks-port".to_string(), Value::Number(7891.into()));
    config.insert("mixed-port".to_string(), Value::Number(7897.into()));
    config.insert("allow-lan".to_string(), Value::Bool(false));
    config.insert("mode".to_string(), Value::String("rule".to_string()));
    config.insert("log-level".to_string(), Value::String("info".to_string()));
    Ok(config)
}

#[tauri::command]
pub fn patch_clash_config(_payload: serde_json::Map<String, Value>) -> Result<(), String> {
    // Placeholder: in the future, this will update Clash config
    Ok(())
}

#[tauri::command]
pub fn patch_clash_mode(_mode: String) -> Result<(), String> {
    // Placeholder: in the future, this will change Clash mode
    Ok(())
}

// Profile commands
#[tauri::command]
pub fn get_profiles() -> Result<serde_json::Map<String, Value>, String> {
    // Return empty profiles config
    let mut config = serde_json::Map::new();
    config.insert("current".to_string(), Value::Null);
    config.insert("items".to_string(), Value::Array(vec![]));
    Ok(config)
}

#[tauri::command]
pub fn patch_profiles_config(_profiles: serde_json::Map<String, Value>) -> Result<(), String> {
    // Placeholder: in the future, this will save profiles config
    Ok(())
}

#[tauri::command]
pub fn create_profile(_item: serde_json::Map<String, Value>, _file_data: Option<String>) -> Result<(), String> {
    // Placeholder: in the future, this will create a new profile
    Ok(())
}

#[tauri::command]
pub fn delete_profile(_index: String) -> Result<(), String> {
    // Placeholder: in the future, this will delete a profile
    Ok(())
}

// Clash logs commands
#[tauri::command]
pub fn get_clash_logs() -> Result<Vec<String>, String> {
    // Return empty logs for now
    Ok(vec![])
}

#[tauri::command]
pub fn clear_logs() -> Result<(), String> {
    // Placeholder: in the future, this will clear Clash logs
    Ok(())
}

// System proxy commands
#[tauri::command]
pub fn get_sys_proxy() -> Result<serde_json::Map<String, Value>, String> {
    // Return default system proxy status
    let mut proxy = serde_json::Map::new();
    proxy.insert("enable".to_string(), Value::Bool(false));
    proxy.insert("server".to_string(), Value::String("".to_string()));
    proxy.insert("bypass".to_string(), Value::String("".to_string()));
    Ok(proxy)
}

// Running mode and uptime commands
#[tauri::command]
pub fn get_running_mode() -> Result<String, String> {
    // Return default running mode
    Ok("clash".to_string())
}

#[tauri::command]
pub fn get_app_uptime() -> Result<u64, String> {
    // Return 0 for now (will be implemented later)
    Ok(0)
}

// App commands
#[tauri::command]
pub fn restart_app(app: tauri::AppHandle) -> Result<(), String> {
    // Placeholder: in the future, this will restart the app
    std::thread::spawn(move || {
        std::thread::sleep(std::time::Duration::from_secs(1));
        app.restart();
    });
    Ok(())
}

#[tauri::command]
pub fn exit_app(app: tauri::AppHandle) -> Result<(), String> {
    app.exit(0);
    Ok(())
}

#[tauri::command]
pub fn get_app_dir(app: tauri::AppHandle) -> Result<String, String> {
    let app_dir = app.path().app_data_dir()
        .map_err(|e| format!("Failed to get app dir: {}", e))?
        .to_string_lossy()
        .to_string();
    Ok(app_dir)
}

#[tauri::command]
pub fn open_app_dir(app: tauri::AppHandle) -> Result<(), String> {
    let app_dir = app.path().app_data_dir()
        .map_err(|e| format!("Failed to get app dir: {}", e))?;
    
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg(app_dir)
            .spawn()
            .map_err(|e| format!("Failed to open app dir: {}", e))?;
    }
    
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("explorer")
            .arg(app_dir)
            .spawn()
            .map_err(|e| format!("Failed to open app dir: {}", e))?;
    }
    
    #[cfg(target_os = "linux")]
    {
        std::process::Command::new("xdg-open")
            .arg(app_dir)
            .spawn()
            .map_err(|e| format!("Failed to open app dir: {}", e))?;
    }
    
    Ok(())
}

