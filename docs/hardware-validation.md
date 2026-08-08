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

---

# 当前结论

硬件切换闭环已验证，项目可以进入最小 MVP 实现。

第一版不实现常驻服务、Agent、mDNS、WebSocket、远程唤醒或 Flow 自动化。
