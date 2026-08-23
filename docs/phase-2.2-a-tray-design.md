# Phase 2.2-A Windows Tray Controller Design

## 1. Goal

为 WorkspaceManager 增加 Windows 系统托盘入口，让用户通过鼠标触发现有的 Mac / Windows 工作区切换流程。

托盘程序只承担 UI 和触发职责。当前稳定链路保持不变：

`tray → VBS launcher → health check → switch script → hardware control`

Windows 继续作为唯一 Controller。本阶段不增加 Mac Agent、Mac 菜单栏程序或双端通信。

## 2. Recommended Technology

推荐使用 Windows PowerShell 5.1 和 .NET WinForms 的 `NotifyIcon` 实现第一版托盘程序。

原因：

- Windows 自带 PowerShell 5.1 和 .NET Framework，无需安装新的运行时。
- WinForms 原生支持系统托盘图标、右键菜单、消息提示和退出事件。
- 可以直接启动现有 VBS launcher，不需要重写切换逻辑。
- 实现规模小，适合当前个人工具和轻量架构。
- 未来可以在同一进程中增加全局快捷键，但第一版无需实现。

暂不推荐：

- AutoHotkey：需要额外安装或打包运行时，并引入新的部署依赖。
- 独立 C# / .NET 应用：结构更正式，但第一版需要项目文件、构建和发布流程，当前收益不足。
- Electron、Web 服务或 WebSocket：明显超出托盘触发层需求。

PowerShell 托盘程序属于当前用户会话中的普通 UI 进程，不注册为 Windows Service。

## 3. Integration with Existing Launchers

托盘菜单应调用以下现有入口：

| Tray action | Existing entry point | Responsibility |
| --- | --- | --- |
| Switch to Windows | `scripts/launcher/switch-to-windows.vbs` | Health Check 后调用现有 Windows 切换脚本 |
| Switch to Mac | `scripts/launcher/switch-to-mac.vbs` | Health Check 后调用现有 Mac 切换脚本 |
| Health Check | `scripts/health/check-workspace-health.ps1` | 独立执行环境检查并显示结果 |

切换菜单应通过 `wscript.exe` 启动现有 VBS 文件。路径基于托盘脚本自身位置推导 WorkspaceManager 根目录，不依赖当前工作目录，也不写死仓库绝对路径。

现有 VBS launcher 必须继续保留，并且仍可脱离托盘程序独立运行。

现有 launcher 在 Health Check 失败时已经负责停止切换并显示错误。第一版托盘程序只表示请求已发起，不应在异步切换脚本尚未结束时误报“切换成功”。完整结果反馈留给后续 Logging / Diagnostics 和 Switch Result Verification。

## 4. Single-Instance Behavior

需要单实例控制。

如果同时运行多个托盘进程，会产生重复图标，也可能让用户在短时间内重复触发硬件切换。建议使用当前 Windows 用户会话范围内的 named mutex：

- 首个进程创建 mutex 并继续运行。
- 后续进程发现 mutex 已存在后立即退出。
- 不使用跨用户或系统服务范围的全局锁。

单实例只约束托盘 UI，不阻止现有 VBS launcher 被快捷方式独立调用。

## 5. Tray Menu

第一版菜单结构：

```text
WorkspaceManager
├── Switch to Windows
├── Switch to Mac
├── ─────────────────
├── Health Check
├── Open Logs
├── ─────────────────
└── Exit
```

行为设计：

- **Switch to Windows**：启动现有 `switch-to-windows.vbs`。
- **Switch to Mac**：启动现有 `switch-to-mac.vbs`。
- **Health Check**：执行现有健康检查，完成后用托盘通知或对话框显示通过或失败。
- **Open Logs**：打开 `logs` 目录；如果日志目录尚不存在，则显示明确提示。Logging / Diagnostics 实现后再提供具体日志文件。
- **Exit**：释放托盘图标和单实例 mutex 后退出，仅关闭托盘 UI，不影响脚本独立使用。

第一版不增加 Settings、状态轮询或当前工作区自动判断。

## 6. Error Presentation

错误提示保持简单：

- 启动入口文件不存在：显示错误对话框，并指出缺失路径。
- Health Check 失败：显示错误对话框或明显的托盘通知；现有 launcher 继续负责阻止切换。
- 无法启动 VBS 或 PowerShell：显示错误对话框。
- 日志目录不存在：显示信息提示，不创建虚假的日志文件。
- 托盘初始化失败：显示错误后退出，不影响现有 launcher。

一般状态可使用短暂托盘通知；需要用户处理的失败使用对话框，避免通知自动消失后无法定位问题。

## 7. Hidden Startup and Lifecycle

建议新增独立 VBS 启动入口，以隐藏 PowerShell 控制台窗口：

`start-workspace-manager-tray.vbs → workspace-manager-tray.ps1`

托盘 PowerShell 脚本启动后进入 WinForms 消息循环，并一直运行到用户选择 Exit 或 Windows 用户会话结束。

第一版不创建 Windows Service，不自动写入注册表，也不自动配置开机启动。后续 Deployment 阶段可以通过用户 Startup 文件夹中的快捷方式启动该 VBS。

## 8. Future Hotkey Extension

第一版不实现全局快捷键。

后续可在托盘进程中使用 Windows `RegisterHotKey` API 注册快捷键，并让快捷键调用与菜单相同的触发函数。这样不会复制切换逻辑。

如果只需要少量固定快捷键，也可以在 Deployment 阶段继续使用 Windows 快捷方式热键，不必立即扩展托盘程序。

## 9. Protecting the Phase 2.1 Stable Core

托盘层不会影响 Phase 2.1，原因如下：

- 不修改 `switch-to-windows-remote.ps1` 或 `switch-to-mac.ps1`。
- 不修改 SSH 参数、m1ddc 命令、MultiMonitorTool 检测或 U8 识别逻辑。
- 不修改现有 VBS launcher 的 Health Check 和隐藏启动行为。
- 托盘退出后，现有 VBS 和 PowerShell 入口仍可独立使用。
- 托盘失败只会失去图形入口，不会改变稳定切换链路。

实现完成后的回归验证应同时覆盖托盘菜单触发和现有 VBS 直接触发，确保两种入口结果一致。

## 10. Expected File Changes

本设计阶段只新增：

- `docs/phase-2.2-a-tray-design.md`

未来实现阶段预计新增：

- `scripts/tray/workspace-manager-tray.ps1`
- `scripts/launcher/start-workspace-manager-tray.vbs`
- `assets/workspace-manager.ico`（可选；没有专用图标时先使用系统图标）

未来部署说明可能更新：

- `docs/setup-guide.md`
- `docs/status.md`

预计不需要修改现有切换脚本或两个现有 VBS launcher。

## 11. Roadmap Alignment

新的 Phase 2.2 顺序为：

1. Phase 2.2-A：Windows Tray Controller
2. Phase 2.2-B：Logging / Diagnostics
3. Phase 2.2-C：Switch Result Verification
4. Phase 2.2-D：Configuration Separation
5. Phase 2.3：Deployment

现有 `phase-2.2-a-logging-design.md` 保留其设计内容，后续实施时按新的路线归入 Phase 2.2-B。本轮不修改该文档或其他现有文档。
