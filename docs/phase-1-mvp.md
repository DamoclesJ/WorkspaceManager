# WorkspaceManager Phase 1 MVP

> 状态：实现中  
> 更新日期：2026-08-08

## 目标

用最简单的本地脚本复现 Phase 0 已验证的两条切换流程，不引入服务、Agent、SSH、GUI 或配置系统。

## MVP 范围

### 切换到 Mac

在 Windows 上执行：

```powershell
scripts\windows\switch-to-mac.ps1
```

脚本调用：

```text
DisplaySwitch.exe /external
```

预期结果：

- Windows 保留 BenQ GW2480。
- Windows 释放雷鸟 U8 的 DP 信号。
- U8 自动切回 Mac HDMI。

### 切换到 Windows

先在 Windows 上执行：

```powershell
scripts\windows\switch-to-windows.ps1
```

脚本调用：

```text
DisplaySwitch.exe /extend
```

再在 Mac 上执行：

```bash
./scripts/mac/switch-input-to-windows.sh
```

脚本调用：

```text
m1ddc display 1 set input 7
```

预期结果：

- Windows 恢复雷鸟 U8 + BenQ GW2480 扩展桌面。
- U8 切换到 Windows DP。

## 文件职责

| 文件 | 运行平台 | 职责 |
| --- | --- | --- |
| `scripts/windows/switch-to-mac.ps1` | Windows | 执行 `/external`，释放 U8 的 Windows DP 信号 |
| `scripts/windows/switch-to-windows.ps1` | Windows | 执行 `/extend`，恢复 Windows 扩展桌面 |
| `scripts/mac/switch-input-to-windows.sh` | Mac | 使用 `m1ddc` 将 U8 切换到 Windows DP |

## 使用约束

- 两台主机需要处于已登录、可操作状态。
- 不读取 U8 当前输入源。
- 不使用 Windows ControlMyMonitor 或 VCP 输入控制。
- 雷鸟 U8 在 Mac 上的显示器编号固定为 `1`。
- `input 7` 是当前已验证的 Windows DP 输入值。
- 切换到 Windows 需要分别在 Windows 和 Mac 上执行脚本；本阶段不做远程调用。

## 成功判断

MVP 只检查底层命令是否执行成功。显示器当前输入源不通过程序读回判断，最终结果以已验证的硬件行为为准。

## 暂不实现

- SSH 或其他远程调用。
- GUI、菜单栏和系统托盘入口。
- 常驻服务、Agent、WebSocket、mDNS。
- 配置文件、数据库和动态硬件发现。
- 远程唤醒、睡眠控制和 Logitech Flow 自动化。
