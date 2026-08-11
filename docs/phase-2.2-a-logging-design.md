# Phase 2.2-A Logging / Diagnostics Design

## 1. Logging Goals

日志系统用于提升 WorkspaceManager 的可维护性和故障定位能力，主要目标包括：

- 在切换失败时定位具体失败步骤。
- 追踪显示器重新枚举以及 DISPLAY 映射变化。
- 分析各步骤和整个切换流程的性能耗时。

## 2. Logging Scope

### 切换方向

记录以下切换方向：

- Windows → Mac
- Mac → Windows

### 关键步骤

日志应覆盖以下事件：

- launcher 启动
- health check 结果
- SSH 连接结果
- m1ddc 执行结果
- MultiMonitorTool 检测结果
- U8 当前 DISPLAY 映射
- SetPrimary 结果
- 总耗时

每次切换应尽可能记录开始时间、步骤结果、失败原因和总耗时。敏感信息不应写入日志，例如 SSH 私钥内容或密码。

## 3. File Location

日志文件位置：

logs/workspace-switch.log

设计原则：

- 日志目录应在首次写入时自动创建；目录已存在时直接复用。
- 保留历史日志，避免每次切换覆盖已有记录。
- 应限制日志文件大小，超过限制后采用简单轮转或归档策略，避免日志无限增长。
- 日志路径应基于 WorkspaceManager 根目录计算，不依赖当前工作目录。

具体大小限制和轮转数量在实现阶段确定，并保持轻量。

## 4. Failure Handling

- 日志写入失败不能影响切换流程。
- 无权限写日志时，切换仍应继续执行。
- 日志目录创建失败、文件被占用或磁盘写入失败时，应尽可能在控制台或现有错误提示中提供诊断信息，但不能将日志故障误报为硬件切换故障。
- 日志记录操作应使用独立的错误处理，避免覆盖或改变切换脚本原有的退出码和错误判断。

## 5. Implementation Plan

未来接入时按以下方向实施：

### PowerShell 脚本

- 在切换脚本启动时初始化日志上下文和开始时间。
- 在现有关键步骤完成后写入结构一致的日志事件。
- 记录命令结果和耗时，但不记录敏感凭据。
- 在脚本结束时写入成功、失败或超时结果以及总耗时。
- 将日志写入封装为不会抛出阻断性错误的辅助逻辑。

### VBS launcher（如需要）

- 记录 launcher 启动和 health check 的最终结果。
- 继续保持隐藏窗口和现有路径自适应行为。
- 不在 launcher 中重复记录 PowerShell 已记录的切换步骤。

接入实现应保持 Phase 2.1 的切换顺序、健康检查和显示器 readiness detection 行为不变。

