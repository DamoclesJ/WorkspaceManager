# WorkspaceManager Status

> Last updated: 2026-08-23

## Current Stable Version

- `phase-2.2-b-logging`

## Completed Phases

- Phase 2.2-A — Windows Tray Controller：已完成并通过 Windows 实机验证。
- Phase 2.2-B — Logging / Diagnostics：已完成并通过 Windows 实机双向切换验证。

## Current Phase

- Phase 2.2-C — Desktop Ready：实现已完成，等待 Windows 实机验证。

## Current Capabilities

- Windows ↔ Mac 双向工作区切换。
- Windows 通过 SSH 控制 Mac 上的 `m1ddc`。
- Windows 使用 MultiMonitorTool 切换主显示器。
- 使用 VBS hidden launcher 隐藏启动 PowerShell。
- 使用 Windows Tray Controller 作为托盘触发入口。
- Tray 支持当前用户级别的 Start with Windows 开关。
- Tray 优先加载 `assets/workspace-manager.ico`，资源缺失或加载失败时使用 Windows 默认图标。
- 切换前执行 Workspace health check。
- 雷鸟 U8 DP 输入切换。
- Display readiness detection。
- 基于 `TCL2701` / `U8` 的动态显示器识别。
- 使用 `logs/workspace-switch.log` 记录 Health Check、切换步骤、动态 DISPLAY 映射、结果和耗时。

## Architecture Overview

当前稳定执行链路：

`tray → launcher → health check → switch script → hardware control`

- Tray：Windows 系统托盘 UI / Trigger Layer。
- Launcher：VBS 隐藏启动入口。
- Health check：检查 MultiMonitorTool、SSH 和远端 `m1ddc`。
- Switch script：编排 Windows 显示模式、Mac 输入切换和 Windows 主屏切换。
- Hardware control：使用 DisplaySwitch、SSH、m1ddc 和 MultiMonitorTool 控制当前硬件。
- Logging：以非阻断方式记录 launcher、Health Check 和切换脚本结果。

## Hardware Constraints

- U8 切换到 Windows DP 后，需要等待 Windows 完成显示器枚举和恢复。
- Windows 的 `DISPLAY1` / `DISPLAY2` 编号不保证固定。
- 系统使用 `TCL2701` Monitor ID 或包含 `U8` 的 Monitor Name 识别雷鸟 U8。

## Verified Environment

Windows：

- OpenSSH Client
- PowerShell
- MultiMonitorTool

Mac：

- Remote Login
- m1ddc
- Homebrew

## Known Limitations

- 依赖局域网 SSH。
- 依赖固定的 Mac SSH 地址。
- 当前未实现自动 IP 发现。
- 正式的 `assets/workspace-manager.ico` 尚待单独设计。

## Recommended Daily Use

`Windows 登录 → WorkspaceManager Tray 自动启动 → 通过 Tray 切换 Windows / Mac 工作区`

Windows Tray Controller 是当前正式用户入口；现有 VBS 和 PowerShell 脚本继续作为可独立运行的备用入口。

## Next Validation

Phase 2.2-C — Desktop Ready Windows 实机验证：

- 验证正式图标加载和默认图标 fallback。
- 验证 Start with Windows 的状态读取、启用和关闭。
- 注销并重新登录，确认 Tray 自动启动且保持单实例。
- 回归验证现有 Tray 菜单和双向切换流程。
