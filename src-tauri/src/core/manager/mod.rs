mod config;
mod lifecycle;
mod state;

use anyhow::Result;
use arc_swap::{ArcSwap, ArcSwapOption};
use std::{fmt, sync::Arc, time::Instant};

use crate::process::CommandChildGuard;
use crate::singleton_lazy;

#[derive(Debug, Clone, serde::Serialize, PartialEq, Eq)]
pub enum RunningMode {
    Service,
    Sidecar,
    NotRunning,
}

impl fmt::Display for RunningMode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Service => write!(f, "Service"),
            Self::Sidecar => write!(f, "Sidecar"),
            Self::NotRunning => write!(f, "NotRunning"),
        }
    }
}

#[derive(Debug)]
pub struct CoreManager {
    state: ArcSwap<State>,
    last_update: ArcSwapOption<Instant>,
}

#[derive(Debug)]
struct State {
    running_mode: ArcSwap<RunningMode>,
    child_sidecar: ArcSwapOption<CommandChildGuard>,
}

impl Default for State {
    fn default() -> Self {
        Self {
            running_mode: ArcSwap::new(Arc::new(RunningMode::NotRunning)),
            child_sidecar: ArcSwapOption::new(None),
        }
    }
}

impl Default for CoreManager {
    fn default() -> Self {
        Self {
            state: ArcSwap::new(Arc::new(State::default())),
            last_update: ArcSwapOption::new(None),
        }
    }
}

impl CoreManager {
    pub fn get_running_mode(&self) -> Arc<RunningMode> {
        Arc::clone(&self.state.load().running_mode.load())
    }

    pub fn take_child_sidecar(&self) -> Option<CommandChildGuard> {
        self.state
            .load()
            .child_sidecar
            .swap(None)
            .and_then(|arc| Arc::try_unwrap(arc).ok())
    }

    pub fn get_last_update(&self) -> Option<Arc<Instant>> {
        self.last_update.load_full()
    }

    pub fn set_running_mode(&self, mode: RunningMode) {
        let state = self.state.load();
        state.running_mode.store(Arc::new(mode));
    }

    pub fn set_running_child_sidecar(&self, child: CommandChildGuard) {
        let state = self.state.load();
        state.child_sidecar.store(Some(Arc::new(child)));
    }

    pub fn set_last_update(&self, time: Instant) {
        self.last_update.store(Some(Arc::new(time)));
    }

    pub async fn init(&self) -> Result<()> {
        logging!(info, Type::Core, "[CoreManager::init] ===== 核心管理器初始化开始 =====");
        let start_time = std::time::Instant::now();
        let current_mode = self.get_running_mode();
        logging!(info, Type::Core, "[CoreManager::init] 当前运行模式: {:?}", current_mode);
        
        logging!(info, Type::Core, "[CoreManager::init] 调用 start_core() 启动核心");
        match self.start_core().await {
            Ok(_) => {
                let elapsed = start_time.elapsed();
                logging!(info, Type::Core, "[CoreManager::init] ===== 核心管理器初始化成功，耗时: {:?} =====", elapsed);
                Ok(())
            }
            Err(e) => {
                let elapsed = start_time.elapsed();
                logging!(error, Type::Core, "[CoreManager::init] ===== 核心管理器初始化失败，耗时: {:?} =====", elapsed);
                logging!(error, Type::Core, "[CoreManager::init] 失败原因: {}", e);
                logging!(error, Type::Core, "[CoreManager::init] 失败详情: {:#}", e);
                Err(e)
            }
        }
    }
}

singleton_lazy!(CoreManager, CORE_MANAGER, CoreManager::default);
