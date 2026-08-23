---
tags:
  - workspace-manager
  - hardware
  - validation
  - learning
created: 2026-08-05
---

# WorkspaceManager 硬件能力验证

## 目标

确认 WorkspaceManager 核心自动化能力是否可以实现。

主要验证：

- Mac mini M4 控制能力
- Windows 控制能力
- 显示器输入切换能力
- Logitech Flow 协同能力

---
# 当前硬件连接关系

## 主机

### Mac mini M4

连接：

- 雷鸟 U8 24款 27英寸
- HDMI 直连

---

### Windows Desktop

连接：

- 雷鸟 U8 24款 27英寸
- DP 直连

- BenQ GW2480
- HDMI 输出 → HDMI 转 DP → 显示器 DP 输入

---

## 显示器映射

雷鸟 U8 24款 27英寸：

HDMI → Mac mini M4

DP → Windows Desktop

接口：

- HDMI × 2
- DP × 1
- Type-C × 1


BenQ GW2480：

DP 输入 ← HDMI 转 DP ← Windows Desktop

# 1. Mac mini M4

## 目标

确认 Mac mini M4 是否可以被 WorkspaceManager 控制。

---

## 需要验证

### 远程唤醒

确认：

- 是否支持网络唤醒
- 睡眠状态是否可以被唤醒
- 唤醒耗时

状态：

```
待验证
```

---

### 远程控制

确认：

- SSH 是否可用
- 是否可以执行远程命令
- 是否可以触发睡眠

状态：

```
待验证
```

---

# 2. Windows 台式机

## 目标

确认 Windows 是否可以自动调整工作状态。

---

## 需要验证

### 显示模式切换

目标：

```
双屏模式

↓

单屏模式
```

### 已验证结果（2026-08-08）

Windows 的显示模式切换可以稳定控制，且不会影响当前登录会话：

#### 切到 Mac

在 Windows 上执行：

```text
DisplaySwitch.exe /external
```

结果：

1. Windows 保留 BenQ GW2480，U8 不再输出 Windows DP 信号。
2. U8 检测不到 DP 信号后，自动切换到 Mac 的 HDMI 输入。
3. Mac 通过 U8 显示，流程可重复稳定成功。

#### 切到 Windows

先在 Windows 上执行：

```text
DisplaySwitch.exe /extend
```

然后在 Mac 上执行：

```text
m1ddc display 1 set input 7
```

结果：

1. Windows 恢复 BenQ GW2480 + U8 的扩展桌面。
2. U8 此时仍停留在 Mac HDMI 输入。
3. `m1ddc ... set input 7` 将 U8 切换到 Windows DP 输入。
4. Windows 保持双屏扩展模式，流程可重复稳定成功。

状态：

```
已验证 ✅
```

---

### 电源控制

确认：

- 是否支持远程唤醒
- 是否可以查询状态

状态：

```
待验证
```

---

# 3. 显示器控制

## 目标

确认显示器是否可以自动切换输入源。

---

## 雷鸟 U8

当前状态：

- 型号：雷鸟 U8 24款 27英寸（EDID 产品名 R27U81，制造商 TCL）
- 已使用输入：
  - HDMI：Mac mini M4
  - DP：Windows Desktop
- 接口：HDMI × 2、DP × 1、Type-C × 1

目标：

验证是否可以通过软件控制 HDMI / DP 输入切换。

---

### 验证记录（2026-08-05）

#### ✅ 已验证通过

| 项目 | 结果 | 工具 |
|------|------|------|
| DDC/CI 识别 | ✅ m1ddc 识别 [1] R27U81 | `m1ddc display list` |
| EDID 读取 | ✅ 完整 EDID（TCL / 0x506c / 0x2701） | `m1ddc display list detailed` |
| 亮度控制 | ✅ 读取=54，写入有效 | `m1ddc display 1 get/set luminance` |
| 对比度控制 | ✅ 读取=39 | `m1ddc display 1 get contrast` |
| 亮度/对比度读回 | ✅ 首次读取偶发异常(0/-117)，重读正常（初始化时序问题） | — |

#### ✅ 已验证：输入源切换

| 操作 | 命令 | 结果 |
|------|------|------|
| 切换到 Windows DP | `m1ddc display 1 set input 7` | 稳定切换成功 |
| 输入源读回 | `m1ddc` 输入状态读取 | 不可靠，MVP 不依赖 |

**历史排查（2026-08-05）**：

早期使用 VESA 候选值和 Windows ControlMyMonitor/VCP `0x60` 遍历时，命令返回成功但行为不稳定，且无法可靠读回当前输入源。该路径不纳入 MVP；当前已验证的固定值是 `m1ddc ... set input 7`。

**Windows 侧交叉验证（ControlMyMonitor）**：

- Windows ControlMyMonitor / VCP 输入控制不可靠。
- 该能力不是当前切换流程的必要依赖。

**当前结论**：

- U8 的输入源可以通过 Mac 上的 `m1ddc display 1 set input 7` 稳定切到 Windows DP。
- 切到 Mac 时不需要主动切换 U8；Windows 释放 DP 信号后，U8 会自动回到 Mac HDMI。
- 输入源读回不可靠，不能作为切换成功的判断条件。

状态：

```
输入切换：已验证 ✅（Mac 侧固定命令切到 DP，Windows 释放 DP 后自动回 HDMI）
亮度/对比度：已验证 ✅
```

---

## BenQ 1080P

已验证：

- 型号：BenQ GW2480
- 作为 Windows 的次要显示器使用。
- 切到 Mac 时由 `DisplaySwitch.exe /external` 保留显示。
- 切到 Windows 时由 `DisplaySwitch.exe /extend` 恢复扩展桌面。

状态：

```
Windows 次要显示器：已验证 ✅
输入源自动控制：不纳入 MVP
```

---

# 4. Logitech Flow

## 目标

确认 Flow 是否可以参与自动切换。

---

需要验证：

- 是否提供自动化接口
- 是否可以通过软件控制
- 是否只能手动切换

状态：

```
待验证
```

---

# 5. 网络环境

## 目标

确认设备之间通信条件。

---

需要记录：

- Mac mini IP
- Windows IP
- 网络结构
- 是否固定 IP
- 是否同一局域网

状态：

```
待验证
```

---

# Phase 0 输出

验证结果：

- Windows 显示模式切换：可自动化。
- U8 输入源切换：可通过 Mac 上的固定 `m1ddc` 命令自动化。
- U8 输入源读回：不可靠，不纳入状态判断。
- Windows VCP/ControlMyMonitor 输入控制：不纳入当前方案。
- 远程唤醒、电源管理、Logitech Flow 自动化：仍是后续能力，不阻塞当前 MVP。

MVP 第一版范围：

1. “切到 Mac”：Windows 执行 `DisplaySwitch.exe /external`。
2. “切到 Windows”：Windows 执行 `DisplaySwitch.exe /extend`，Mac 执行 `m1ddc display 1 set input 7`。
3. 用固定硬件配置和命令结果记录操作日志，不读取 U8 当前输入源。

## Phase 1.1 快捷方式验证

验证结果（2026-08-08）：

- Windows 快捷方式可以成功运行对应的 PowerShell 脚本。
- `DisplaySwitch.exe /external` 已验证。
- `DisplaySwitch.exe /extend` 已验证。
- Mac 上的 `m1ddc display 1 set input 7` 已验证。
- 快捷方式文件属于本地用户配置，不纳入仓库跟踪。

本次验证未加入 SSH，未改变 Phase 0 已验证的硬件切换流程。

## Phase 1.3-C 主显示器切换验证

验证结果（2026-08-09）：

- Windows 显示器识别：
  - `DISPLAY1 = TCL2701 / TCL U8`
  - `DISPLAY2 = BNQ78E7 / BenQ GW2480`
- Mac 上的 `m1ddc display 1 set input 7` 已验证，可将 U8 切换到 Windows DP。
- Windows 使用 MultiMonitorTool 的 `/SetPrimary "\\.\DISPLAY1"` 将 U8 设置为主显示器。
- `DisplaySwitch.exe /extend`、SSH 远程 `m1ddc`、U8 输入恢复和主显示器切换组成的完整流程连续 3 次测试通过。

关键硬件约束：

U8 从 Mac HDMI 切换到 Windows DP 后，需要等待约 10 秒完成恢复。之后再执行 Windows 主显示器切换；如果执行过早，MultiMonitorTool 命令可能无法生效。

## Phase 2.1 Workspace Reliability 验证

验证结果（2026-08-11）：

### Health Check

- 已加入 `scripts/health/check-workspace-health.ps1`。
- 切换前检查仓库内的 MultiMonitorTool、Windows 到 Mac 的 SSH 连通性，以及远端 `/opt/homebrew/bin/m1ddc` 是否存在且可执行。
- 健康检查已在 Windows 实机验证通过。

### Launcher Integration

- `switch-to-windows.vbs` 和 `switch-to-mac.vbs` 已接入健康检查。
- 健康检查返回非零退出码时，launcher 会停止执行并显示错误提示，不再继续调用切换脚本。

### Display Readiness Detection

- 已删除 U8 输入切换后的固定 10 秒等待。
- 使用 MultiMonitorTool `/scomma` 导出的显示器状态检测 U8 是否恢复。
- readiness detection 最多等待 20 秒；检测成功后才执行主显示器切换，超时则明确报错。

### Temp File Race Fix

- 每次 `/scomma` 检测使用独立 GUID 临时 CSV。
- CSV 完整读取后清理，并对短暂文件锁进行有限重试。
- 已修复 Windows Error 32 文件占用问题。

### Dynamic Monitor Identification

- 不再依赖固定的 `\\.\DISPLAY1`。
- 根据 `TCL2701` Monitor ID、Short Monitor ID 或包含 `U8` 的 Monitor Name 识别雷鸟 U8。
- 从当前 `/scomma` 结果动态取得 U8 对应的 `\\.\DISPLAYx`，再传给 MultiMonitorTool `/SetPrimary`。
- 已解决显示器重新枚举后 DISPLAY1/DISPLAY2 漂移导致的主屏切换失败。

最终验证：

- Windows 实机连续切换测试通过。
- U8 输入恢复和主显示器切换正常。
- Error 32 未再出现。
- 对应版本标签：`phase-2.1-workspace-reliability`。

## Phase 2.2-B Logging / Diagnostics 验证

验证结果（2026-08-23）：

### Switch to Windows

- Health Check 通过。
- `DisplaySwitch.exe /extend` 执行成功。
- Windows 到 Mac 的 SSH 远程命令执行成功。
- `/opt/homebrew/bin/m1ddc display 1 set input 7` 执行成功，U8 切换到 Windows DP。
- MultiMonitorTool readiness detection 成功识别 U8。
- 本次显示器重新枚举后，U8 的动态映射为 `\\.\DISPLAY2`。
- MultiMonitorTool `/SetPrimary` 执行成功，U8 成为 Windows 主显示器。
- 两次验证样本的完整切换耗时约为 7.4–7.5 秒。

### Switch to Mac

- Health Check 通过。
- 已确认稳定的 Switch to Mac 流程不调用 SSH 或 `m1ddc`。
- Windows 执行 `DisplaySwitch.exe /external` 后释放 U8 的 DP 信号。
- U8 在 DP 信号释放后自动返回 Mac HDMI，实机验证成功。
- 切换成功及总耗时能够正常写入日志。

### DisplaySwitch 空退出码兼容

- Windows 实机验证发现：`DisplaySwitch.exe /external` 成功执行时，PowerShell 的 `$LASTEXITCODE` 可能为 `$null`。
- Logging 初次接入时将空退出码误判为失败，并生成了没有有效退出码的错误信息。
- 当前判断已与 `/extend` 流程保持一致：只有 `$LASTEXITCODE` 非 `$null` 且非 `0` 时才判定失败。
- 修复后不再产生误导性的空 exit code 错误，Switch to Mac 验证通过。

### Logging 结果

- `logs/workspace-switch.log` 已在 Windows 实机生成并由托盘 Open Logs 打开。
- 日志包含时间戳、Health Check、关键切换步骤、动态 DISPLAY 映射、成功或失败结果及总耗时。
- 日志写入保持非阻断，不改变已验证的硬件切换顺序和行为。
- 对应版本标签：`phase-2.2-b-logging`。

---

# 当前结论

硬件切换闭环已验证，项目可以进入最小 MVP 实现。

第一版不实现常驻服务、Agent、mDNS、WebSocket、远程唤醒或 Flow 自动化。
