# Phase 2.2 Plan

> 状态：规划中
> 更新日期：2026-08-11

## Goal

提升 WorkspaceManager 的可维护性、诊断能力和长期稳定性。

## Planned Features

### Phase 2.2-A Logging / Diagnostics

目标：增加切换过程日志。

日志记录：

- 切换方向
- 开始时间
- Health Check 结果
- SSH 状态
- m1ddc 执行结果
- U8 检测结果
- DISPLAY 映射
- SetPrimary 结果
- 总耗时

要求：

- 日志失败不能影响切换。

---

### Phase 2.2-B Switch Result Verification

目标：增加切换后的结果确认。

包括：

- 主屏状态验证
- U8 是否成为 Primary
- 必要时自动重试

---

### Phase 2.2-C Configuration Separation

目标：减少脚本硬编码。

考虑将以下内容迁移到独立配置文件：

- Mac SSH 地址
- 用户名
- U8 Monitor ID
- 超时时间

迁移应保持当前已验证的切换流程和默认行为不变。

---

### Phase 2.2-D Deployment Improvements

目标：改善新机器部署体验。

包括：

- 快捷方式创建
- 环境检查
- 初始化流程

---

## Planning Constraints

- Phase 2.2 先完成规划，当前不实现代码。
- 以 Phase 2.1 Workspace Reliability 作为稳定回归基线。
- 保持现有 launcher → health check → switch script → hardware control 架构。

