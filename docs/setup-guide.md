# WorkspaceManager 部署指南

> 适用版本：Phase 1.4
> 更新日期：2026-08-10

本文档记录 WorkspaceManager 在当前 Mac mini M4、Windows 台式机、雷鸟 U8 和 BenQ GW2480 环境中的从零部署流程。

## 1. 系统架构

WorkspaceManager 使用 Windows 作为控制入口，不部署常驻服务、Agent 或 GUI。

切换到 Mac：

```text
Windows 快捷方式
→ switch-to-mac.ps1
→ DisplaySwitch.exe /external
→ Windows 保留 BenQ，释放 U8 DP 信号
→ U8 自动切回 Mac HDMI
```

切换到 Windows：

```text
Windows 快捷方式
→ switch-to-windows-remote.ps1
→ DisplaySwitch.exe /extend
→ SSH 调用 Mac m1ddc input 7
→ 等待 U8 的 Windows DP 输入恢复
→ MultiMonitorTool 将 U8 设置为 Windows 主显示器
```

涉及的程序：

| 程序 | 运行位置 | 用途 |
| --- | --- | --- |
| PowerShell | Windows | 执行场景脚本 |
| DisplaySwitch.exe | Windows | 切换 Windows 显示模式 |
| OpenSSH Client | Windows | 调用 Mac 上的 m1ddc |
| MultiMonitorTool.exe | Windows 仓库的 `tools/` | 设置 Windows 主显示器 |
| SSH Remote Login | Mac | 接收 Windows 远程命令 |
| m1ddc | Mac | 控制雷鸟 U8 的输入源 |

## 2. 当前硬件映射

- Mac mini M4 → 雷鸟 U8 HDMI。
- Windows → 雷鸟 U8 DP。
- Windows → BenQ GW2480。
- Windows 显示器识别：
  - `DISPLAY1 = TCL2701 / TCL U8`
  - `DISPLAY2 = BNQ78E7 / BenQ GW2480`
- Mac 上的 U8 显示器编号为 `1`。
- U8 的 Windows DP 输入值为 `7`。

## 3. Mac 配置

### 3.1 开启 SSH

在 macOS 中打开：

```text
系统设置 → 通用 → 共享 → 远程登录
```

开启“远程登录”，并确保用户 `jiaxiangdong` 被允许登录。

当前脚本使用：

```text
jiaxiangdong@192.168.1.134
```

Mac 的局域网地址需要保持为 `192.168.1.134`。建议在路由器中为 Mac 配置 DHCP 地址保留。

首次从 Windows 连接时执行：

```powershell
ssh jiaxiangdong@192.168.1.134
```

确认主机指纹后，退出 SSH 会话。

### 3.2 安装和验证 m1ddc

Mac mini M4 使用 Apple Silicon Homebrew，脚本依赖以下绝对路径：

```text
/opt/homebrew/bin/m1ddc
```

如尚未安装 m1ddc：

```bash
brew install m1ddc
```

检查程序和显示器：

```bash
test -x /opt/homebrew/bin/m1ddc
/opt/homebrew/bin/m1ddc display list
```

验证 U8 输入切换：

```bash
/opt/homebrew/bin/m1ddc display 1 set input 7
```

该命令会实际把 U8 切换到 Windows DP。

## 4. Windows 配置

### 4.1 安装 Git

可以通过 Windows Package Manager 安装 Git for Windows：

```powershell
winget install --id Git.Git -e
```

重新打开 PowerShell 后检查：

```powershell
git --version
ssh -V
```

`ssh -V` 应输出 Windows OpenSSH Client 的版本。若命令不存在，需要先在 Windows“可选功能”中安装 OpenSSH Client。

### 4.2 配置 Windows 到 GitHub 的 SSH

如 Windows 尚无 SSH key：

```powershell
ssh-keygen -t ed25519 -C "WorkspaceManager Windows"
```

默认情况下，公钥位于：

```text
%USERPROFILE%\.ssh\id_ed25519.pub
```

显示公钥：

```powershell
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
```

将公钥添加到 GitHub 账号的 SSH keys，然后验证：

```powershell
ssh -T git@github.com
```

Windows 到 GitHub 的 SSH 只用于 `clone`、`pull` 和 `push`，不参与显示器切换。

### 4.3 Clone 仓库

```powershell
git clone git@github.com:DamoclesJ/WorkspaceManager.git
Set-Location WorkspaceManager
```

确认关键文件存在：

```powershell
Test-Path .\scripts\windows\switch-to-mac.ps1
Test-Path .\scripts\windows\switch-to-windows-remote.ps1
Test-Path .\tools\MultiMonitorTool.exe
```

三个结果都应为 `True`。

远程切换脚本使用 `$PSScriptRoot` 计算 MultiMonitorTool 路径，因此仓库可以放在任意目录，但必须保持仓库内部目录结构不变。

### 4.4 PowerShell 执行方式

建议仅对单次调用使用 `ExecutionPolicy Bypass`，不修改系统全局执行策略。

切到 Mac：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\windows\switch-to-mac.ps1"
```

切到 Windows：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\windows\switch-to-windows-remote.ps1"
```

## 5. SSH 配置说明

### 5.1 Windows → Mac

这条连接用于在 Mac 上远程执行：

```text
/opt/homebrew/bin/m1ddc display 1 set input 7
```

可以使用前面生成的 Windows SSH 公钥。将公钥追加到 Mac 用户的 `~/.ssh/authorized_keys`：

```powershell
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub" | ssh jiaxiangdong@192.168.1.134 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys'
```

验证无密码和非交互调用：

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=5 jiaxiangdong@192.168.1.134 "/opt/homebrew/bin/m1ddc display 1 set input 7"
```

验证命令会实际切换 U8 输入。成功时不应要求输入 Mac 密码。

### 5.2 Windows → GitHub

这条连接用于访问 Git 仓库：

```text
Windows → git@github.com
```

它与 Windows → Mac 的远程控制用途不同。两者可以使用同一个 Windows SSH key，也可以按个人安全策略使用不同 key。

验证命令：

```powershell
ssh -T git@github.com
git remote -v
```

仓库远端应为：

```text
git@github.com:DamoclesJ/WorkspaceManager.git
```

## 6. 快捷方式配置

快捷方式属于 Windows 本地用户配置，不提交到仓库。

假设仓库位于 `D:\WorkspaceManager`，创建两个桌面快捷方式。

切到 Mac 的“目标”：

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\WorkspaceManager\scripts\windows\switch-to-mac.ps1"
```

切到 Windows 的“目标”：

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\WorkspaceManager\scripts\windows\switch-to-windows-remote.ps1"
```

将示例中的 `D:\WorkspaceManager` 替换为实际仓库绝对路径。快捷方式的“起始位置”可以设置为仓库根目录，但远程脚本定位 MultiMonitorTool 不依赖该设置。

首次配置后，建议先在 PowerShell 窗口中运行脚本，确认没有错误，再使用桌面快捷方式。

## 7. 部署验证

### 7.1 切到 Mac

运行 `switch-to-mac.ps1`，确认：

1. Windows 保留 BenQ GW2480。
2. Windows 释放 U8 DP 信号。
3. U8 自动切回 Mac HDMI。

### 7.2 切到 Windows

运行 `switch-to-windows-remote.ps1`，确认：

1. Windows 恢复 U8 + BenQ 扩展桌面。
2. Windows 通过 SSH 调用 Mac m1ddc。
3. U8 切换到 Windows DP。
4. 脚本等待约 10 秒。
5. MultiMonitorTool 将 `\\.\DISPLAY1` 设置为主显示器。

## 8. 已知硬件限制

- U8 输入源读回不可靠，MVP 不根据读回结果判断切换是否成功。
- U8 从 Mac HDMI 切到 Windows DP 后，需要约 10 秒完成恢复；过早设置主显示器可能不生效。
- `input 7`、Mac 显示器编号 `1` 和 Windows 的 `DISPLAY1` 映射都与当前硬件连接绑定。
- Windows 显示器映射当前为 `DISPLAY1 = TCL U8`、`DISPLAY2 = BenQ GW2480`；更换接口、显卡驱动或显示器后需要重新验证。
- Windows → Mac 依赖 Mac 地址 `192.168.1.134` 和用户 `jiaxiangdong`。
- Mac 必须开机、已登录、连接 U8，且 Remote Login 可用。
- MultiMonitorTool 是 Windows x64 可执行文件，位于仓库的 `tools/MultiMonitorTool.exe`。
- 当前没有远程唤醒、输入源状态检测、自动重试、GUI、服务或 Agent。

## 9. 常见故障

### SSH 立即失败

- 检查 Mac 是否开机且地址仍为 `192.168.1.134`。
- 检查 macOS Remote Login 是否开启。
- 手动执行 SSH 验证命令，确认 key 登录仍然有效。

### 找不到 MultiMonitorTool.exe

在仓库根目录执行：

```powershell
Test-Path .\tools\MultiMonitorTool.exe
```

如果返回 `False`，重新拉取完整仓库，并确认安全软件没有隔离该文件。

### U8 已切换，但没有成为主显示器

- 确认 U8 已在 Windows DP 输入下稳定显示。
- 保留脚本中的约 10 秒等待。
- 重新确认 U8 在 Windows 中仍被识别为 `\\.\DISPLAY1`。
