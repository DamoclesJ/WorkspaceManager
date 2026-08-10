# WorkspaceManager Status

> Last updated: 2026-08-11

## Current Stable Version

- `phase-2.1-workspace-reliability`

## Current Capabilities

- Windows ↔ Mac 双向工作区切换。
- Windows 通过 SSH 控制 Mac 上的 `m1ddc`。
- Windows 使用 MultiMonitorTool 切换主显示器。
- 使用 VBS hidden launcher 隐藏启动 PowerShell。
- 切换前执行 Workspace health check。
- 雷鸟 U8 DP 输入切换。
- Display readiness detection。
- 基于 `TCL2701` / `U8` 的动态显示器识别。

## Architecture Overview

当前稳定执行链路：

`launcher → health check → switch script → hardware control`

- Launcher：VBS 隐藏启动入口。
- Health check：检查 MultiMonitorTool、SSH 和远端 `m1ddc`。
- Switch script：编排 Windows 显示模式、Mac 输入切换和 Windows 主屏切换。
- Hardware control：使用 DisplaySwitch、SSH、m1ddc 和 MultiMonitorTool 控制当前硬件。

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

## Next Planned Phase

Phase 2.2：

- Logging / Diagnostics
- Reliability improvements
