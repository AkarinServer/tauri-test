use super::{CoreManager, RunningMode};
use crate::{
    AsyncHandler,
    config::Config,
    core::{handle, logger::CLASH_LOGGER, service},
    logging,
    process::CommandChildGuard,
    utils::{
        dirs,
        init::sidecar_writer,
        logging::{SharedWriter, Type, write_sidecar_log},
    },
};
use anyhow::Result;
use compact_str::CompactString;
use flexi_logger::DeferredNow;
use log::Level;
use scopeguard::defer;
use tauri_plugin_shell::ShellExt as _;

impl CoreManager {
    pub async fn get_clash_logs(&self) -> Result<Vec<CompactString>> {
        match *self.get_running_mode() {
            RunningMode::Service => service::get_clash_logs_by_service().await,
            RunningMode::Sidecar => Ok(CLASH_LOGGER.get_logs().await),
            RunningMode::NotRunning => Ok(Vec::new()),
        }
    }

    pub(super) async fn start_core_by_sidecar(&self) -> Result<()> {
        logging!(info, Type::Core, "[start_core_by_sidecar] ===== 开始 Sidecar 模式启动 =====");
        let start_time = std::time::Instant::now();

        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤1: 生成运行时配置文件");
        let config_file = match Config::generate_file(crate::config::ConfigType::Run).await {
            Ok(path) => {
                logging!(info, Type::Core, "[start_core_by_sidecar] 配置文件路径: {:?}", path);
                path
            }
            Err(e) => {
                logging!(error, Type::Core, "[start_core_by_sidecar] 生成配置文件失败: {}", e);
                logging!(error, Type::Core, "[start_core_by_sidecar] 错误详情: {:#}", e);
                return Err(e);
            }
        };

        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤2: 获取应用句柄");
        let app_handle = match handle::Handle::app_handle() {
            handle => {
                logging!(info, Type::Core, "[start_core_by_sidecar] 应用句柄获取成功");
                handle
            }
        };

        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤3: 获取 Clash 核心名称");
        let clash_core = Config::verge().await.latest_arc().get_valid_clash_core();
        logging!(info, Type::Core, "[start_core_by_sidecar] Clash 核心: {}", clash_core);

        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤4: 获取配置目录");
        let config_dir = match dirs::app_home_dir() {
            Ok(dir) => {
                logging!(info, Type::Core, "[start_core_by_sidecar] 配置目录: {:?}", dir);
                dir
            }
            Err(e) => {
                logging!(error, Type::Core, "[start_core_by_sidecar] 获取配置目录失败: {}", e);
                logging!(error, Type::Core, "[start_core_by_sidecar] 错误详情: {:#}", e);
                return Err(e);
            }
        };

        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤5: 准备启动 sidecar 进程");
        logging!(info, Type::Core, "[start_core_by_sidecar] 命令: {} -d {:?} -f {:?}", 
                 clash_core, config_dir, config_file);
        
        let config_dir_str = match dirs::path_to_str(&config_dir) {
            Ok(s) => s,
            Err(e) => {
                logging!(error, Type::Core, "[start_core_by_sidecar] 配置目录路径转换失败: {}", e);
                return Err(e);
            }
        };
        
        let config_file_str = match dirs::path_to_str(&config_file) {
            Ok(s) => s,
            Err(e) => {
                logging!(error, Type::Core, "[start_core_by_sidecar] 配置文件路径转换失败: {}", e);
                return Err(e);
            }
        };

        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤6: 创建 sidecar 命令");
        let sidecar_cmd = match app_handle.shell().sidecar(clash_core.as_str()) {
            Ok(cmd) => {
                logging!(info, Type::Core, "[start_core_by_sidecar] Sidecar 命令创建成功");
                cmd
            }
            Err(e) => {
                logging!(error, Type::Core, "[start_core_by_sidecar] 创建 sidecar 命令失败: {}", e);
                logging!(error, Type::Core, "[start_core_by_sidecar] 错误详情: {:#}", e);
                logging!(error, Type::Core, "[start_core_by_sidecar] 可能原因: sidecar 可执行文件不存在或无法访问");
                return Err(anyhow::anyhow!("Failed to create sidecar command: {}", e));
            }
        };

        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤7: 设置命令参数");
        let sidecar_cmd = sidecar_cmd.args([
            "-d",
            config_dir_str,
            "-f",
            config_file_str,
        ]);

        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤8: 启动 sidecar 进程");
        let (mut rx, child) = match sidecar_cmd.spawn() {
            Ok((rx, child)) => {
                let pid = child.pid();
                logging!(info, Type::Core, "[start_core_by_sidecar] Sidecar 进程启动成功，PID: {}", pid);
                (rx, child)
            }
            Err(e) => {
                logging!(error, Type::Core, "[start_core_by_sidecar] 启动 sidecar 进程失败: {}", e);
                logging!(error, Type::Core, "[start_core_by_sidecar] 错误详情: {:#}", e);
                logging!(error, Type::Core, "[start_core_by_sidecar] 可能原因: 进程启动失败、权限不足或资源不足");
                return Err(anyhow::anyhow!("Failed to spawn sidecar process: {}", e));
            }
        };

        let pid = child.pid();
        logging!(info, Type::Core, "[start_core_by_sidecar] Sidecar 进程 PID: {}", pid);
        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤9: 保存子进程句柄");

        self.set_running_child_sidecar(CommandChildGuard::new(child));
        self.set_running_mode(RunningMode::Sidecar);
        logging!(info, Type::Core, "[start_core_by_sidecar] 运行模式已设置为 Sidecar");

        // 关键修复：核心启动后，主动检测连接就绪，而不是等待健康检查
        // 这可以大大减少启动时的等待时间
        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤10: 获取 IPC socket 路径");
        let socket_path_str = crate::config::IClashTemp::guard_external_controller_ipc();
        let socket_path = std::path::PathBuf::from(&socket_path_str);
        logging!(info, Type::Core, "[start_core_by_sidecar] IPC socket 路径: {:?}", socket_path);
        
        let config_file_clone = config_file.clone();
        AsyncHandler::spawn(move || async move {
            use crate::utils::logging::Type;
            use crate::logging;
            use std::time::{Duration, Instant};
            
            logging!(info, Type::Core, "[start_core_by_sidecar] 步骤11: 开始等待核心 socket 就绪");
            logging!(info, Type::Core, "[start_core_by_sidecar] Socket 路径: {:?}", socket_path);
            let start = Instant::now();
            let max_wait = Duration::from_secs(10); // 最多等待10秒
            let mut check_count = 0;
            
            // 每200ms检查一次socket是否就绪
            while start.elapsed() < max_wait {
                check_count += 1;
                if check_count % 5 == 0 {
                    logging!(info, Type::Core, "[start_core_by_sidecar] 已等待 {:?}，检查次数: {}，socket 存在: {}", 
                             start.elapsed(), check_count, socket_path.exists());
                }
                
                if socket_path.exists() {
                    // Socket文件存在，再等待一小段时间确保核心完全启动
                    logging!(info, Type::Core, "[start_core_by_sidecar] Socket 文件已存在，等待核心完全启动");
                    tokio::time::sleep(Duration::from_millis(200)).await;
                    logging!(info, Type::Core, "[start_core_by_sidecar] 核心 socket 已就绪，总耗时: {:?}", start.elapsed());
                    
                    // 主动触发一次连接尝试，加速连接建立
                    logging!(info, Type::Core, "[start_core_by_sidecar] 步骤12: 尝试连接 mihomo API");
                    let mihomo = handle::Handle::mihomo().await;
                    match mihomo.get_base_config().await {
                        Ok(_) => {
                            logging!(info, Type::Core, "[start_core_by_sidecar] mihomo API 连接成功");
                        }
                        Err(e) => {
                            logging!(warn, Type::Core, "[start_core_by_sidecar] mihomo API 连接失败（可能还未完全就绪）: {}", e);
                        }
                    }
                    
                    // 关键修复：核心启动后，重新加载配置以确保端口正确监听
                    let config_file_str = match dirs::path_to_str(&config_file_clone) {
                        Ok(s) => {
                            logging!(info, Type::Core, "[start_core_by_sidecar] 步骤13: 准备重新加载配置");
                            s.to_string()
                        }
                        Err(e) => {
                            logging!(warn, Type::Core, "[start_core_by_sidecar] 无法获取配置文件路径: {}", e);
                            return;
                        }
                    };
                    
                    AsyncHandler::spawn(move || async move {
                        use crate::logging;
                        use crate::utils::logging::Type;
                        use crate::core::handle;
                        
                        logging!(info, Type::Core, "[start_core_by_sidecar] 等待 500ms 后重新加载配置");
                        tokio::time::sleep(Duration::from_millis(500)).await;
                        
                        logging!(info, Type::Core, "[start_core_by_sidecar] 开始重新加载配置");
                        let mihomo_for_reload = handle::Handle::mihomo().await;
                        match mihomo_for_reload.reload_config(true, &config_file_str).await {
                            Ok(_) => {
                                logging!(info, Type::Core, "[start_core_by_sidecar] 配置重新加载成功");
                            }
                            Err(e) => {
                                logging!(warn, Type::Core, "[start_core_by_sidecar] 配置重新加载失败: {}", e);
                                logging!(warn, Type::Core, "[start_core_by_sidecar] 错误详情: {:#}", e);
                            }
                        }
                    });
                    
                    logging!(info, Type::Core, "[start_core_by_sidecar] ===== Sidecar 启动流程完成 =====");
                    return;
                }
                tokio::time::sleep(Duration::from_millis(200)).await;
            }
            
            if !socket_path.exists() {
                logging!(error, Type::Core, "[start_core_by_sidecar] ===== 警告: 核心 socket 在 {:?} 后仍未就绪 =====", start.elapsed());
                logging!(error, Type::Core, "[start_core_by_sidecar] Socket 路径: {:?}", socket_path);
                logging!(error, Type::Core, "[start_core_by_sidecar] 可能原因: 核心进程启动失败、socket 创建失败或路径错误");
            }
        });

        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤14: 设置 sidecar 日志写入器");
        let shared_writer: SharedWriter = match sidecar_writer().await {
            Ok(writer) => {
                logging!(info, Type::Core, "[start_core_by_sidecar] Sidecar 日志写入器创建成功");
                std::sync::Arc::new(tokio::sync::Mutex::new(writer))
            }
            Err(e) => {
                logging!(error, Type::Core, "[start_core_by_sidecar] 创建 sidecar 日志写入器失败: {}", e);
                logging!(error, Type::Core, "[start_core_by_sidecar] 错误详情: {:#}", e);
                return Err(e);
            }
        };

        logging!(info, Type::Core, "[start_core_by_sidecar] 步骤15: 启动 sidecar 输出监听任务");
        AsyncHandler::spawn(move || async move {
            logging!(info, Type::Core, "[start_core_by_sidecar] Sidecar 输出监听任务已启动");
            let mut event_count = 0;
            
            while let Some(event) = rx.recv().await {
                event_count += 1;
                match event {
                    tauri_plugin_shell::process::CommandEvent::Stdout(line) => {
                        let mut now = DeferredNow::default();
                        let message = CompactString::from(String::from_utf8_lossy(&line).as_ref());
                        logging!(debug, Type::Core, "[start_core_by_sidecar] Sidecar stdout[{}]: {}", event_count, message);
                        write_sidecar_log(
                            shared_writer.lock().await,
                            &mut now,
                            Level::Error,
                            &message,
                        );
                        CLASH_LOGGER.append_log(message).await;
                    }
                    tauri_plugin_shell::process::CommandEvent::Stderr(line) => {
                        let mut now = DeferredNow::default();
                        let message = CompactString::from(String::from_utf8_lossy(&line).as_ref());
                        logging!(warn, Type::Core, "[start_core_by_sidecar] Sidecar stderr[{}]: {}", event_count, message);
                        write_sidecar_log(
                            shared_writer.lock().await,
                            &mut now,
                            Level::Error,
                            &message,
                        );
                        CLASH_LOGGER.append_log(message).await;
                    }
                    tauri_plugin_shell::process::CommandEvent::Terminated(term) => {
                        let mut now = DeferredNow::default();
                        let message = if let Some(code) = term.code {
                            CompactString::from(format!("Process terminated with code: {}", code))
                        } else if let Some(signal) = term.signal {
                            CompactString::from(format!("Process terminated by signal: {}", signal))
                        } else {
                            CompactString::from("Process terminated")
                        };
                        logging!(error, Type::Core, "[start_core_by_sidecar] ===== Sidecar 进程已终止 =====");
                        logging!(error, Type::Core, "[start_core_by_sidecar] 终止信息: {}", message);
                        logging!(error, Type::Core, "[start_core_by_sidecar] 退出码: {:?}, 信号: {:?}", term.code, term.signal);
                        write_sidecar_log(
                            shared_writer.lock().await,
                            &mut now,
                            Level::Info,
                            &message,
                        );
                        CLASH_LOGGER.clear_logs().await;
                        
                        // 关键修复：进程终止时，更新运行状态为 NotRunning
                        use crate::core::manager::CoreManager;
                        use crate::core::manager::RunningMode;
                        use crate::logging;
                        use crate::utils::logging::Type;
                        CoreManager::global().set_running_mode(RunningMode::NotRunning);
                        logging!(info, Type::Core, "[start_core_by_sidecar] Sidecar进程已终止，运行状态已更新为NotRunning");
                        
                        break;
                    }
                    _ => {
                        logging!(debug, Type::Core, "[start_core_by_sidecar] 收到其他事件: {:?}", event);
                    }
                }
            }
            
            logging!(warn, Type::Core, "[start_core_by_sidecar] Sidecar 输出监听任务结束，共处理 {} 个事件", event_count);
        });

        let elapsed = start_time.elapsed();
        logging!(info, Type::Core, "[start_core_by_sidecar] ===== Sidecar 启动初始化完成，耗时: {:?} =====", elapsed);
        Ok(())
    }

    pub(super) fn stop_core_by_sidecar(&self) -> Result<()> {
        logging!(info, Type::Core, "Stopping sidecar");
        defer! {
            self.set_running_mode(RunningMode::NotRunning);
        }
        if let Some(child) = self.take_child_sidecar() {
            let pid = child.pid();
            drop(child);
            logging!(trace, Type::Core, "Sidecar stopped (PID: {:?})", pid);
        }
        Ok(())
    }

    pub(super) async fn start_core_by_service(&self) -> Result<()> {
        logging!(info, Type::Core, "Starting core in service mode");
        let config_file = Config::generate_file(crate::config::ConfigType::Run).await?;
        service::run_core_by_service(&config_file).await?;
        self.set_running_mode(RunningMode::Service);
        Ok(())
    }

    pub(super) async fn stop_core_by_service(&self) -> Result<()> {
        logging!(info, Type::Core, "Stopping service");
        defer! {
            self.set_running_mode(RunningMode::NotRunning);
        }
        service::stop_core_by_service().await?;
        Ok(())
    }
}
