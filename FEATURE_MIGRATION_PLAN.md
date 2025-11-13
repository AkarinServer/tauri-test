# RV Verge 功能移植规划文档

## 项目概述

RV Verge 是 Clash Verge Rev 的轻量化版本，专门针对 RISC-V 设备（如 Lichee RV Dock）进行优化。本文档详细列出了需要从 `clash-verge-rev` 移植到 `rv-verge` 的功能模块、开发阶段和流程。

## 目标

1. **轻量化**：移除重型依赖（如 Monaco Editor），使用更轻量的替代方案
2. **性能优化**：针对 RISC-V 架构进行性能优化
3. **功能完整性**：保留核心功能，确保用户体验
4. **代码简化**：简化代码结构，降低维护成本

## 当前状态

### ✅ 已实现功能

- [x] 基础项目结构
- [x] Tauri 后端框架（完整集成 clash-verge-rev 后端）
- [x] React 前端框架
- [x] 路由系统
- [x] 国际化（i18n）基础（中英文支持）
- [x] 主题系统
- [x] Home 页面完整实现
  - [x] Clash Mode Card（代理模式切换）
  - [x] System Info Card（系统信息显示）
  - [x] Traffic Graph（流量图表）- EnhancedCanvasTrafficGraph
  - [x] Traffic Stats（实时流量统计）- EnhancedTrafficStats
  - [x] IP Info Card（IP 信息显示，精简版）- IpInfoCard
  - [x] Profile Card（配置文件快捷信息）- HomeProfileCard
- [x] Profiles 页面核心功能
  - [x] 配置文件列表显示 - ProfileItem
  - [x] 配置文件导入功能（URL 导入）- import-profile-dialog.tsx
  - [x] 配置文件切换功能
  - [x] 配置文件删除功能（带确认对话框）
- [x] 基础服务层（Services）
  - [x] cmds.ts（Tauri 命令封装）
  - [x] config.ts（SWR 配置）
  - [x] api.ts（IP 信息获取服务）
- [x] Hooks 实现
  - [x] useVerge
  - [x] useTrafficData（流量数据获取）
  - [x] useTrafficMonitor（增强版流量监控，支持数据采样和压缩）
- [x] 窗口管理
- [x] 错误边界
- [x] 类型定义基础
- [x] 性能优化
  - [x] 后端启动性能优化（健康检查间隔优化、主动连接检测）
  - [x] 前端刷新间隔优化（SWR_SLOW_POLL、uptime 刷新优化）
  - [x] 启动诊断工具（debug_startup.rs）

### 🚧 部分实现功能

- [x] Profiles 页面（核心功能已完成，编辑功能待实现）
  - [x] 配置文件列表
  - [x] 配置文件导入
  - [x] 配置文件切换
  - [x] 配置文件删除
  - [ ] 配置文件编辑（轻量化编辑器）

## 功能模块清单

### 1. 页面（Pages）

#### 1.1 Home 页面 (`/`)
- [x] 基础框架
- [x] 流量监控图表（Canvas 实现，性能优化）
- [x] 实时流量统计（上传/下载速度显示）
- [x] IP 信息显示（精简版：国旗 + IP 地址）
- [x] 配置文件快捷切换（显示当前配置信息）
- [x] 系统信息显示（运行模式、运行时间、代理端口）
- [ ] 测试功能
- [ ] TUN 模式显示

#### 1.2 Proxies 页面 (`/proxies`)
- [ ] 代理列表显示
- [ ] 代理组管理
- [ ] 代理选择器
- [ ] 代理链显示
- [ ] 代理提供商管理
- [ ] 代理搜索和过滤
- [ ] 代理延迟测试

#### 1.3 Profiles 页面 (`/profiles`)
- [x] 配置文件列表（ProfileItem 组件）
- [x] 配置文件删除（带确认对话框）
- [x] 配置文件导入（URL 导入，支持剪贴板粘贴）
- [x] 配置文件切换（切换当前使用的配置）
- [ ] 配置文件创建/编辑
- [ ] 配置文件编辑器（轻量化替代 Monaco Editor）
- [ ] 配置文件导出
- [ ] 配置文件验证
- [ ] 配置文件备份/恢复

#### 1.4 Connections 页面 (`/connections`)
- [ ] 连接列表显示
- [ ] 连接详情查看
- [ ] 连接关闭功能
- [ ] 连接搜索和过滤
- [ ] 连接统计信息
- [ ] 连接列管理

#### 1.5 Rules 页面 (`/rules`)
- [ ] 规则列表显示
- [ ] 规则搜索和过滤
- [ ] 规则提供商管理
- [ ] 规则匹配统计
- [ ] 规则编辑器（轻量化）

#### 1.6 Logs 页面 (`/logs`)
- [ ] 日志列表显示
- [ ] 日志级别过滤
- [ ] 日志搜索
- [ ] 日志清理
- [ ] 日志导出
- [ ] 实时日志更新

#### 1.7 Settings 页面 (`/settings`)
- [ ] 基础设置（Basic Settings）
- [ ] Clash 设置（Clash Settings）
- [ ] 系统设置（System Settings）
- [ ] 高级设置（Advanced Settings）
- [ ] 主题设置
- [ ] 快捷键设置
- [ ] 更新设置
- [ ] 备份设置
- [ ] 网络接口设置
- [ ] DNS 设置
- [ ] TUN 设置
- [ ] 系统代理设置

#### 1.8 Unlock 页面 (`/unlock`)
- [ ] 解锁功能
- [ ] 解锁状态显示
- [ ] 解锁配置

#### 1.9 Test 页面 (`/test`)
- [ ] 测试功能
- [ ] 连接测试
- [ ] 延迟测试
- [ ] 配置测试

### 2. 组件（Components）

#### 2.1 Base 组件
- [x] BasePage
- [x] BaseErrorBoundary
- [ ] BaseDialog
- [ ] BaseEmpty
- [ ] BaseLoading
- [ ] BaseLoadingOverlay
- [ ] BaseSearchBox
- [ ] BaseStyledSelect
- [ ] BaseStyledTextField
- [ ] BaseSwitch
- [ ] BaseTooltipIcon
- [ ] BaseFieldset
- [ ] NoticeManager

#### 2.2 Home 组件
- [x] EnhancedCard（通用卡片组件）
- [x] ClashModeCard（代理模式切换卡片）
- [x] SystemInfoCard（系统信息卡片）
- [x] EnhancedTrafficStats（实时流量统计组件）
- [x] EnhancedCanvasTrafficGraph（Canvas 实现的流量图表）
- [x] IPInfoCard（IP 信息卡片，精简版）
- [x] HomeProfileCard（配置文件信息卡片）
- [ ] ProxyTunCard
- [ ] TestCard
- [ ] ClashInfoCard

#### 2.3 Proxy 组件
- [ ] ProxyItem
- [ ] ProxyItemMini
- [ ] ProxyGroups
- [ ] ProxyGroupNavigator
- [ ] ProxyChain
- [ ] ProxyHead
- [ ] ProxyRender
- [ ] ProviderButton
- [ ] useFilterSort
- [ ] useHeadState
- [ ] useRenderList
- [ ] useWindowWidth

#### 2.4 Profile 组件
- [x] ProfileItem（配置文件列表项组件）
- [x] ImportProfileDialog（配置文件导入对话框）
- [ ] ProfileBox
- [ ] ProfileViewer
- [ ] ProfileEditor（轻量化替代 Monaco Editor）
- [ ] ProfileMore
- [ ] ConfirmViewer
- [ ] FileInput
- [ ] GroupItem
- [ ] GroupsEditorViewer
- [ ] ProxiesEditorViewer
- [ ] RulesEditorViewer
- [ ] ProxyItem（Profile 专用）
- [ ] RuleItem（Profile 专用）
- [ ] LogViewer

#### 2.5 Connection 组件
- [ ] ConnectionTable
- [ ] ConnectionItem
- [ ] ConnectionDetail
- [ ] ConnectionColumnManager

#### 2.6 Rule 组件
- [ ] RuleItem
- [ ] ProviderButton

#### 2.7 Log 组件
- [ ] LogItem

#### 2.8 Setting 组件
- [ ] SettingVergeBasic
- [ ] SettingVergeAdvanced
- [ ] SettingClash
- [ ] SettingSystem
- [ ] ConfigViewer
- [ ] ClashCoreViewer
- [ ] ClashPortViewer
- [ ] DNSViewer
- [ ] TUNViewer
- [ ] SysproxyViewer
- [ ] ThemeViewer
- [ ] LayoutViewer
- [ ] HotkeyViewer
- [ ] UpdateViewer
- [ ] BackupViewer
- [ ] AutoBackupSettings
- [ ] BackupHistoryViewer
- [ ] BackupConfigViewer
- [ ] BackupWebDAVDialog
- [ ] NetworkInterfaceViewer
- [ ] WebUIViewer
- [ ] ControllerViewer
- [ ] ExternalControllerCORS
- [ ] LiteModeViewer
- [ ] MiscViewer
- [ ] SettingComp
- [ ] GuardState
- [ ] HotkeyInput
- [ ] PasswordInput
- [ ] ThemeModeSwitch
- [ ] StackModeSwitch

#### 2.9 Layout 组件
- [x] LayoutTraffic（侧边栏流量显示）
- [x] LayoutItem（侧边栏导航项）
- [ ] TrafficGraph（独立流量图表组件）
- [ ] ScrollTopButton
- [ ] UpdateButton
- [ ] UseCustomTheme

#### 2.10 Shared 组件
- [ ] ProxyControlSwitches

#### 2.11 Test 组件
- [ ] TestBox
- [ ] TestItem
- [ ] TestViewer

### 3. Hooks

#### 3.1 核心 Hooks
- [x] useVerge（配置管理）
- [x] useTrafficData（流量数据获取，连接 Mihomo WebSocket）
- [x] useTrafficMonitor（增强版流量监控，支持数据采样和压缩）
- [ ] useClash
- [ ] useCurrentProxy
- [ ] useProxySelection
- [ ] useProfiles
- [ ] useConnectionData
- [ ] useLogData
- [ ] useSystemState
- [ ] useSystemProxyState
- [ ] useMemoryData
- [ ] useListen
- [ ] useVisibility
- [ ] useWindow
- [ ] useCleanup
- [ ] useI18n
- [ ] useServiceInstaller
- [ ] useServiceUninstaller

### 4. Services

#### 4.1 核心 Services
- [x] cmds.ts（Tauri 命令封装，包含 Profile、System、Runtime 等命令）
- [x] config.ts（SWR 配置，包含 SWR_DEFAULTS、SWR_REALTIME、SWR_SLOW_POLL）
- [x] api.ts（IP 信息获取服务，支持多服务商和重试机制）
- [x] i18n.ts
- [x] states.ts
- [ ] noticeService.ts
- [ ] update.ts
- [ ] delay.ts

### 5. Utils

#### 5.1 工具函数
- [x] debounce.ts
- [x] parse-traffic.ts（流量数据解析工具）
- [ ] data-validator.ts
- [ ] get-system.ts
- [ ] helper.ts
- [ ] ignore-case.ts
- [ ] is-async-function.ts
- [ ] noop.ts
- [ ] parse-hotkey.ts
- [ ] traffic-diagnostics.ts
- [ ] truncate-str.ts
- [ ] uri-parser.ts

### 6. 后端（Rust）

#### 6.1 Tauri Commands
- [x] 基础 Commands（系统信息、网络接口等）
- [x] Profile 相关 Commands
  - [x] get_profiles（获取配置文件列表）
  - [x] import_profile（导入配置文件）
  - [x] delete_profile（删除配置文件）
  - [x] switch_profile（切换配置文件）
  - [x] patch_profiles_config（更新配置文件配置）
  - [x] create_profile（创建配置文件）
  - [x] update_profile（更新配置文件）
- [x] System 相关 Commands
  - [x] get_running_mode（获取运行模式）
  - [x] get_app_uptime（获取应用运行时间）
  - [x] get_system_proxy（获取系统代理设置）
- [x] Runtime 相关 Commands
  - [x] get_runtime_config（获取运行时配置）
- [ ] Clash 相关 Commands
- [ ] Connection 相关 Commands
- [ ] Rule 相关 Commands
- [ ] Log 相关 Commands
- [ ] Update 相关 Commands
- [ ] Backup 相关 Commands

#### 6.2 核心模块
- [x] Clash 核心管理（CoreManager，完整集成 clash-verge-rev 后端）
- [x] 配置文件管理（Config、Profiles 模块）
- [x] 系统代理管理（Sysopt 模块）
- [x] 窗口管理（WindowManager）
- [x] 启动性能优化（健康检查优化、主动连接检测、启动诊断工具）
- [ ] 更新管理
- [ ] 备份管理
- [ ] 通知管理

## 开发阶段规划

### 阶段 1：核心功能基础（当前阶段）

**目标**：建立核心功能基础框架

**任务**：
- [x] 项目结构搭建
- [x] 基础服务层实现
- [x] Home 页面基础框架
- [x] Home 页面完整实现
  - [x] 流量监控图表（Canvas 实现）
  - [x] 实时流量统计（上传/下载速度）
  - [x] IP 信息显示（精简版）
  - [x] 配置文件快捷切换（显示当前配置信息）

**预计时间**：1-2 周

**优先级**：P0（最高）

### 阶段 2：代理管理功能

**目标**：实现代理列表、选择、切换等核心功能

**任务**：
- [ ] Proxies 页面实现
- [ ] 代理列表显示
- [ ] 代理选择器
- [ ] 代理组管理
- [ ] 代理延迟测试
- [ ] 代理搜索和过滤
- [ ] 代理相关 Hooks 实现
- [ ] 代理相关组件实现

**预计时间**：2-3 周

**优先级**：P0（最高）

### 阶段 3：配置文件管理

**目标**：实现配置文件的创建、编辑、切换等功能

**任务**：
- [x] Profiles 页面基础实现
- [x] 配置文件列表（ProfileItem 组件）
- [x] 配置文件删除（带确认对话框）
- [x] 配置文件导入（URL 导入，支持剪贴板粘贴）
- [x] 配置文件切换（切换当前使用的配置）
- [ ] 配置文件创建/编辑
- [ ] 配置文件导出
- [ ] 轻量化配置文件编辑器（替代 Monaco Editor）
- [ ] 配置文件验证
- [x] 配置文件相关组件实现（ProfileItem、ImportProfileDialog）

**预计时间**：3-4 周

**优先级**：P0（最高）

**注意事项**：
- 不使用 Monaco Editor，使用轻量化的文本编辑器
- 考虑使用 `react-textarea-code-editor` 或类似的轻量化编辑器
- 实现语法高亮和基本编辑功能

### 阶段 4：连接和规则管理

**目标**：实现连接管理和规则管理功能

**任务**：
- [ ] Connections 页面实现
- [ ] 连接列表显示
- [ ] 连接详情查看
- [ ] 连接关闭功能
- [ ] 连接搜索和过滤
- [ ] Rules 页面实现
- [ ] 规则列表显示
- [ ] 规则搜索和过滤
- [ ] 规则提供商管理
- [ ] 连接和规则相关 Hooks 实现
- [ ] 连接和规则相关组件实现

**预计时间**：2-3 周

**优先级**：P1（高）

### 阶段 5：日志和测试功能

**目标**：实现日志查看和测试功能

**任务**：
- [ ] Logs 页面实现
- [ ] 日志列表显示
- [ ] 日志级别过滤
- [ ] 日志搜索
- [ ] 日志清理
- [ ] 实时日志更新
- [ ] Test 页面实现
- [ ] 测试功能实现
- [ ] 连接测试
- [ ] 延迟测试
- [ ] 日志和测试相关 Hooks 实现
- [ ] 日志和测试相关组件实现

**预计时间**：1-2 周

**优先级**：P1（高）

### 阶段 6：设置功能

**目标**：实现完整的设置功能

**任务**：
- [ ] Settings 页面实现
- [ ] 基础设置
- [ ] Clash 设置
- [ ] 系统设置
- [ ] 高级设置
- [ ] 主题设置
- [ ] 快捷键设置
- [ ] 更新设置
- [ ] 备份设置
- [ ] 网络接口设置
- [ ] DNS 设置
- [ ] TUN 设置
- [ ] 系统代理设置
- [ ] 设置相关组件实现

**预计时间**：3-4 周

**优先级**：P1（高）

### 阶段 7：解锁功能

**目标**：实现解锁功能

**任务**：
- [ ] Unlock 页面实现
- [ ] 解锁功能实现
- [ ] 解锁状态显示
- [ ] 解锁配置

**预计时间**：1 周

**优先级**：P2（中）

### 阶段 8：优化和测试

**目标**：优化性能，完善功能，进行测试

**任务**：
- [ ] 性能优化
- [ ] 代码优化
- [ ] 错误处理完善
- [ ] 单元测试
- [ ] 集成测试
- [ ] RISC-V 设备测试
- [ ] 文档完善

**预计时间**：2-3 周

**优先级**：P1（高）

## 技术决策

### 1. 编辑器选择

**问题**：Clash Verge Rev 使用 Monaco Editor，但 Monaco Editor 非常重，不适合 RISC-V 设备。

**解决方案**：
- 使用轻量化的文本编辑器替代 Monaco Editor
- 推荐方案：
  1. `react-textarea-code-editor`：轻量化的代码编辑器
  2. `@uiw/react-codemirror`：CodeMirror 6 的 React 封装，比 Monaco Editor 轻量
  3. 自定义编辑器：基于 `<textarea>` 或 `<pre>` 实现简单的语法高亮

**推荐**：使用 `@uiw/react-codemirror`，它在功能和性能之间有很好的平衡。

### 2. 数据表格

**问题**：Clash Verge Rev 使用 `@mui/x-data-grid`，但该组件较重。

**解决方案**：
- 使用轻量化的表格组件
- 推荐方案：
  1. `react-virtuoso`：虚拟化列表，已在使用
  2. 自定义表格组件：基于 MUI 的 `Table` 组件
  3. `@tanstack/react-table`：轻量化的表格库

**推荐**：使用 `react-virtuoso` 或自定义表格组件。

### 3. 拖拽排序

**问题**：Clash Verge Rev 使用 `@dnd-kit/*` 进行拖拽排序。

**解决方案**：
- 评估 `@dnd-kit/*` 的性能
- 如果性能不佳，考虑使用更轻量的替代方案
- 或者简化交互，使用按钮进行排序

**推荐**：先使用 `@dnd-kit/*`，如果性能有问题再考虑替代方案。

### 4. Markdown 渲染

**问题**：Clash Verge Rev 使用 `react-markdown` 渲染 Markdown。

**解决方案**：
- `react-markdown` 相对轻量，可以继续使用
- 如果需要更轻量，可以考虑 `marked` + 自定义渲染器

**推荐**：继续使用 `react-markdown`。

## 性能优化策略

### 1. 代码分割

**当前状态**：已禁用代码分割以避免循环依赖问题。

**未来优化**：
- 重新启用代码分割，但使用更合理的分割策略
- 确保 React 核心库独立，避免循环依赖
- 使用动态导入（`React.lazy`）进行路由级别的代码分割

### 2. 虚拟化

**策略**：
- 对于长列表，使用 `react-virtuoso` 进行虚拟化
- 减少 DOM 节点数量，提高渲染性能

### 3. 数据缓存

**策略**：
- 使用 SWR 进行数据缓存和自动重新验证
- 减少不必要的 API 调用
- 实现智能的数据更新策略

### 4. 组件优化

**策略**：
- 使用 `React.memo` 优化组件渲染
- 使用 `useMemo` 和 `useCallback` 优化计算和函数
- 避免不必要的重新渲染

### 5. 资源优化

**策略**：
- 优化图片资源大小
- 使用 SVG 图标代替图片
- 压缩静态资源
- 使用 CDN 加速（如果适用）

## 测试策略

### 1. 单元测试

**目标**：测试工具函数、Hooks、组件等。

**工具**：
- Vitest
- React Testing Library

### 2. 集成测试

**目标**：测试页面、功能模块等。

**工具**：
- Vitest
- React Testing Library
- Playwright（如果需要）

### 3. 性能测试

**目标**：测试应用在 RISC-V 设备上的性能。

**指标**：
- 启动时间
- 页面加载时间
- 内存使用
- CPU 使用
- 交互响应时间

### 4. 兼容性测试

**目标**：测试应用在不同平台上的兼容性。

**平台**：
- macOS（Apple Silicon）
- macOS（Intel）
- Linux（RISC-V）
- Linux（x86_64）
- Linux（ARM64）

## 文档要求

### 1. 代码文档

- [ ] 函数和类注释
- [ ] 类型定义文档
- [ ] 组件使用文档
- [ ] API 文档

### 2. 用户文档

- [ ] 安装指南
- [ ] 使用指南
- [ ] 配置指南
- [ ] 常见问题（FAQ）
- [ ] 故障排除指南

### 3. 开发文档

- [ ] 开发环境搭建
- [ ] 代码规范
- [ ] 提交规范
- [ ] 发布流程
- [ ] 贡献指南

## 风险评估

### 1. 性能风险

**风险**：应用在 RISC-V 设备上性能不佳。

**缓解措施**：
- 持续进行性能测试
- 优化关键路径
- 使用性能分析工具
- 必要时简化功能

### 2. 兼容性风险

**风险**：某些功能在不同平台上不兼容。

**缓解措施**：
- 跨平台测试
- 使用跨平台的 API
- 实现平台特定的适配层

### 3. 功能完整性风险

**风险**：轻量化导致功能缺失。

**缓解措施**：
- 优先实现核心功能
- 保持功能完整性
- 用户反馈收集
- 迭代改进

### 4. 维护风险

**风险**：代码复杂度过高，难以维护。

**缓解措施**：
- 代码审查
- 代码重构
- 文档完善
- 测试覆盖

## 里程碑

### 里程碑 1：核心功能完成（阶段 1-3）

**目标**：完成 Home、Proxies、Profiles 页面。

**预计时间**：6-9 周

**验收标准**：
- Home 页面功能完整
- Proxies 页面功能完整
- Profiles 页面功能完整
- 基本功能可用

### 里程碑 2：完整功能实现（阶段 1-7）

**目标**：完成所有页面和功能。

**预计时间**：14-18 周

**验收标准**：
- 所有页面功能完整
- 所有功能可用
- 性能达标
- 测试通过

### 里程碑 3：优化和发布（阶段 8）

**目标**：优化性能，完善功能，发布版本。

**预计时间**：16-21 周

**验收标准**：
- 性能优化完成
- 测试通过
- 文档完善
- 版本发布

## 下一步行动

### 立即行动（本周）

1. ✅ 完成 Home 页面剩余功能
   - ✅ 流量监控图表
   - ✅ 实时流量统计
   - ✅ IP 信息显示
   - ✅ 配置文件快捷切换

2. 开始 Proxies 页面实现
   - 代理列表显示
   - 代理选择器

3. 完善 Profiles 页面
   - 配置文件编辑功能（轻量化编辑器）

### 短期行动（2-4 周）

1. 完成 Proxies 页面
2. 开始 Profiles 页面
3. 实现配置文件编辑器（轻量化）

### 中期行动（1-2 个月）

1. 完成 Profiles 页面
2. 实现 Connections 和 Rules 页面
3. 实现 Logs 和 Test 页面

### 长期行动（3-6 个月）

1. 完成 Settings 页面
2. 实现 Unlock 功能
3. 性能优化
4. 测试和文档完善

## 参考资料

### 项目文档

- [Clash Verge Rev GitHub](https://github.com/clash-verge-rev/clash-verge-rev)
- [Tauri Documentation](https://tauri.app/)
- [React Documentation](https://react.dev/)
- [Material-UI Documentation](https://mui.com/)

### 技术文档

- [RISC-V 架构文档](https://riscv.org/)
- [Vite Documentation](https://vite.dev/)
- [SWR Documentation](https://swr.vercel.app/)
- [React Router Documentation](https://reactrouter.com/)

## 更新记录

- **2024-11-13**：初始版本创建
- **2024-11-13**：添加功能模块清单和开发阶段规划
- **2024-11-13**：更新已实现功能
  - ✅ Home 页面完整实现（流量图表、流量统计、IP 信息、配置文件卡片）
  - ✅ Profiles 页面核心功能（列表、导入、切换、删除）
  - ✅ 性能优化（后端启动优化、前端刷新间隔优化）
  - ✅ 完整后端集成（clash-verge-rev 后端完整集成）
  - ✅ Hooks 实现（useTrafficData、useTrafficMonitor）
  - ✅ Services 实现（api.ts、cmds.ts 扩展）

## 联系方式

如有问题或建议，请通过以下方式联系：

- GitHub Issues：[https://github.com/AkarinServer/rv-verge/issues](https://github.com/AkarinServer/rv-verge/issues)
- GitHub Discussions：[https://github.com/AkarinServer/rv-verge/discussions](https://github.com/AkarinServer/rv-verge/discussions)

---

**注意**：本文档会根据项目进展持续更新。请定期查看最新版本。


