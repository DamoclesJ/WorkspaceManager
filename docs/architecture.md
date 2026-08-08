# WorkspaceManager 架构文档

> 状态：草案  
> 最后更新：2026-08-08
> 说明：Phase 0 的核心显示切换能力已验证；本文档描述当前 MVP 的最小实现方向。

## 1. 架构目标

- 本地优先，不依赖云服务。
- 控制端和被控端职责清晰，平台能力集中隔离。
- 所有自动化操作幂等、可校验、可回退。
- 场景切换由编排层驱动，单项能力可独立调用。
- 避免过早引入通用抽象，先以最小闭环验证可行性。

## 2. 当前状态

- 硬件显示切换闭环已验证，尚未实现业务代码。
- Windows 使用 `DisplaySwitch.exe` 控制显示模式。
- Mac 使用 `m1ddc display 1 set input 7` 将 U8 切换到 Windows DP。
- 不依赖 U8 输入源读回，也不依赖 Windows ControlMyMonitor/VCP 输入控制。
- 下一步是实现两个固定场景命令和一个轻量控制入口。

## 3. 硬件环境（Hardware Profile）

当前项目强依赖具体硬件环境，以下配置用于定义自动化边界，避免实现时重新猜测环境。

### 3.1 Display

- 雷鸟 U8 4K 显示器
  - HDMI：连接 Mac mini M4
  - DP：连接 Windows
- BenQ 1080P 显示器
  - 当前主要连接 Windows

### 3.2 Input

- Logitech MX Master 3S
- Logitech Flow
  - Device 1：Mac
  - Device 2：Windows

### 3.3 Host

- Mac mini M4
- Windows Desktop

## 4. MVP 阶段范围

Control Hub、Agent、mDNS、WebSocket 等设计保留为长期方向，第一阶段不引入复杂分布式架构。

MVP 只实现已验证的显示切换闭环：

1. 一个控制入口。
2. 执行“切到 Mac”或“切到 Windows”的完整流程。
3. 保持两台机器已登录且可执行命令。
4. 记录命令执行结果和时间，不读取 U8 当前输入源。

以下内容暂不纳入 MVP：

- 远程唤醒和睡眠。
- Logitech Flow 自动触发或状态读取。
- U8 输入源读回。
- Windows ControlMyMonitor/VCP 输入控制。
- Agent、mDNS、WebSocket、云服务和复杂状态同步。

## 5. 总体架构

### 5.1 MVP 控制入口

第一版使用一个轻量启动入口和两个场景脚本，不部署常驻服务。

建议以 Windows 端作为启动入口：

- “切到 Mac”只执行 `DisplaySwitch.exe /external`。
- “切到 Windows”先执行 `DisplaySwitch.exe /extend`，再调用 Mac 上的 `m1ddc display 1 set input 7`。
- Mac 端命令可先通过 SSH 或一个用户手动启动的本地脚本提供；只有确认远程执行在当前用户会话中稳定后，才封装成一键调用。
- 每个场景只报告命令成功/失败和固定步骤结果，不尝试推断 U8 当前输入源。

Windows 端可以先用 PowerShell 脚本和桌面快捷方式作为控制入口；菜单栏、托盘或常驻程序留到后续迭代。

### 5.2 控制中枢（长期方向）

长期方向上，控制中枢运行在其中一台主机上的常驻程序，提供：

- 快捷控制入口。
- 场景编排。
- 设备状态展示。
- 与各平台 Agent 通信。

部署策略：

- 初期优先部署在 Mac mini M4 或主要控制端。
- Mac mini 长期开机适合作为控制节点，macOS 菜单栏自动化体验较好。
- 根据稳定性和扩展需求，再考虑将控制中枢独立化。

### 5.3 平台 Agent

每台被管主机上运行轻量 Agent，负责执行本机能力：

- Mac Agent：电源管理、显示相关能力，以及可选的 Flow 状态检查。
- Windows Agent：显示模式切换、电源能力，以及可选的 Flow 状态检查。

### 5.4 设备控制层

- 显示器输入源控制。
- 局域网唤醒。
- 操作系统电源和显示 API。

### 5.5 协调层

- 局域网内的设备发现与通信。
- 鉴权和命令校验。
- 操作结果上报。

## 6. 建议模块划分

### 6.1 场景编排模块

负责将“切到 Mac”或“切到 Windows”展开为有序步骤，并在每一步校验结果。

### 6.2 主机管理模块

负责主机注册、状态查询和电源控制。

### 6.3 显示器管理模块

负责显示器输入源切换，维护“显示器接口到主机”的固定映射。MVP 不把输入源查询作为前置条件或成功判断。

### 6.4 Windows 显示模式模块

负责双屏/单屏模式切换；MVP 阶段直接调用 Windows `DisplaySwitch.exe`，不引入 Agent。

### 6.5 Flow 协同模块

- Flow 是辅助输入协同能力，不作为完整切换流程成功与否的唯一条件。
- 负责 Flow 状态的检测、可选触发和人工切换提示。
- 无法自动控制 Flow 时，应提供提示或人工切换方案。

### 6.6 配置与状态模块

负责保存硬件映射、场景定义、最近状态和操作日志。

### 6.7 界面模块

提供菜单栏或托盘等快捷入口，不直接调用平台能力。

## 7. 核心切换流程

MVP 采用固定步骤，不先读取完整设备状态，也不依赖 U8 输入源读回。

### 7.1 切到 Mac

1. 在 Windows 执行 `DisplaySwitch.exe /external`。
2. Windows 保留 BenQ GW2480，释放 U8 的 DP 输出。
3. U8 因 DP 信号消失自动切换到 Mac HDMI。
4. 记录 Windows 命令结果。

### 7.2 切到 Windows

1. 在 Windows 执行 `DisplaySwitch.exe /extend`。
2. Windows 恢复 BenQ GW2480 + U8 的扩展桌面。
3. 在 Mac 执行 `m1ddc display 1 set input 7`。
4. U8 切换到 Windows DP，记录两条命令的结果。

每一步都应保留手动执行方式。MVP 的失败处理是停止后续步骤并显示失败命令，不尝试通过不可靠的输入源读回进行自动修复。

## 8. 核心数据概念

### 8.1 Host

- 主机标识。
- 主机类型：Mac 或 Windows。
- 网络地址和唤醒方式。
- 当前电源状态。

### 8.2 Display

- 显示器标识。
- 输入接口列表。
- 每台主机的输入源映射。
- 当前输入源（可选；MVP 不依赖读取）。

### 8.3 Scene

- 场景名称，例如“切到 Mac”。
- 目标主机。
- 目标显示器状态。
- 目标 Windows 显示模式。
- Flow 处理策略（辅助项，允许失败降级）。
- Scene 表示目标状态，而不是一组待执行命令。

### 8.4 Transition

- 目标场景。
- 步骤序列。
- 每一步的执行状态。
- 最终结果和错误信息。
- Transition 表示从当前状态到达 Scene 目标状态的过程。

### 8.5 状态模型说明

系统不是简单执行命令，而是管理目标状态。

Mac 工作模式：

- Mac mini awake
- 雷鸟 U8 输入源自动回到 HDMI
- Windows 显示模式 = `DisplaySwitch.exe /external` 的外接显示器模式（保留 BenQ）
- 输入设备切换到 Mac

Windows 工作模式：

- Windows awake
- Windows 执行 `DisplaySwitch.exe /extend`
- 显示器输入源切换到 Windows DP
- Windows 双屏扩展模式启用
- 输入设备切换到 Windows

切换成功应以目标状态是否达成来判断，而不是以某条命令是否执行。

## 9. 技术候选

| 能力 | 候选方案 | 备注 |
| --- | --- | --- |
| 快捷入口 | 原生菜单栏/托盘、Tauri、Electron | 待确认 |
| Mac 电源 | pmset、Wake on Demand、SSH/远程命令 | 需要验证远程唤醒路径 |
| Windows 电源/显示 | PowerShell、Win32 API、MultiMonitorTool 等工具 | 需要验证显示模式切换稳定性 |
| 显示器输入源 | DDC/CI、显示器厂商接口、红外/串口控制 | 依赖具体显示器 |
| 局域网通信 | 本地 HTTP/WebSocket + mDNS 发现 | 需要鉴权 |
| 配置存储 | 本地 JSON/YAML 或轻量数据库 | 待确认 |

Agent、mDNS 和 WebSocket 属于长期方向，MVP 阶段不引入复杂分布式架构。

## 10. 设计约束

- 所有操作必须幂等。
- 自动化失败不得造成设备无法手动恢复。
- 不删除、修改用户工作数据或系统关键配置。
- 平台相关能力不得散落在编排逻辑中。
- 通信仅限局域网，默认不暴露到公网。
- 先验证可行性，再实现完整架构。

## 11. 未决问题

- 控制中枢长期运行形态是继续留在 Mac mini 上，还是独立化？
- 显示器输入源控制具体使用哪种协议？
- Logitech Flow 能否通过公开接口自动化？
- Windows 远程唤醒是否纳入 MVP？
- 配置存储和通信协议最终采用什么方案？
