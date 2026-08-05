# WorkspaceManager

WorkspaceManager 是一个个人桌面环境自动化管理工具，用于管理 Mac mini M4 和 Windows 台式机构成的混合工作环境，目标是让设备电源、显示器输入、Windows 显示模式和键鼠协同自动完成切换，尽量做到无感。

## 核心场景

- Mac mini M4 远程唤醒和睡眠管理
- 显示器输入源自动切换
- Windows 双屏/单屏模式自动切换
- Logitech Flow 键鼠协同
- 桌面快捷控制入口
- 尽量做到无感切换

## 当前状态

项目处于文档与设计阶段，尚未实现任何功能。仓库目前只包含本说明和 `docs/` 下的设计文档。

## 文档

- [需求文档](docs/requirements.md)：产品范围、核心场景和需求清单。
- [架构文档](docs/architecture.md)：模块划分、技术选型和设计约束。
- [决策记录](docs/decisions.md)：重要决策及其理由。

## 计划路线

1. 盘点现有硬件、网络和系统能力。
2. 验证关键自动化能力：远程唤醒、显示器控制、Windows 显示模式、Flow 协同。
3. 实现最小闭环：从控制入口完成一次完整的“切到 Mac”或“切到 Windows”流程。
4. 逐步优化切换耗时、失败恢复和无感程度。

## Learning Branch

This section is created on learning-git branch.
