# Engineering Baseline Spec

## Purpose

定义 TopOne 当前工程基线能力，确保仓库具备可构建、可验证、可持续扩展的 Apple-first 应用工程入口与验证链路。

## Requirements

### Requirement: Apple-first 应用工程入口
项目 MUST 为 `iOS`、`iPadOS` 和 `macOS` 提供一个可构建的 Apple-first 应用工程入口，使后续实现能够基于真实 Swift 工程推进，而不是仅停留在文档层。

#### Scenario: 工程入口已建立
- **WHEN** 贡献者在本规范应用后检查仓库
- **THEN** 仓库中存在一个可作为已确认 Apple-first 技术栈实现入口的 Swift 应用工程结构

### Requirement: 分层模块边界
项目 MUST 为 `App`、`Domain`、`Persistence`、`Application`、`Presentation`、`PlatformAdapters` 和 `Tests` 定义清晰的工程边界，并与既有技术方案保持一致。

#### Scenario: 代码放置位置明确
- **WHEN** 贡献者开始实现领域规则、持久化逻辑或平台特定行为
- **THEN** 项目结构为每类关注点提供明确放置位置，而不是混杂在一个无分层模块中

### Requirement: SwiftData 持久化边界
项目 MUST 建立一个最小可用的 `SwiftData` 持久化边界，用于承载技术栈变更中已确认的 local-first 数据模型。

#### Scenario: 本地持久化接入点明确
- **WHEN** 后续 change 开始实现 `Goal`、`Task`、`Reward` 或相关模型
- **THEN** 这些模型可以挂接到预定义的 `SwiftData` 集成边界，而不是临时引入持久化实现

### Requirement: 工程验证工具链
项目 MUST 提供一条最小工程验证路径，覆盖 Apple-first 代码库的格式化、lint、构建与测试执行。

#### Scenario: 可执行本地验证
- **WHEN** 贡献者准备验证代码变更
- **THEN** 仓库中定义了 Swift 代码库的具体格式化、lint、构建和测试入口

### Requirement: 应用变更的 CI 基线
项目 MUST 提供一个 GitHub Actions 基线 workflow，用于通过自动化检查验证 Swift 工程基线。

#### Scenario: 仓库具备自动化基线检查
- **WHEN** Swift 应用代码被引入并在仓库中发生变更
- **THEN** GitHub Actions 提供一条可运行工程基线验证流程的自动化路径

### Requirement: 基线 change 保持聚焦实现地基
本 change MUST 建立工程基线基础设施，而不扩展到大规模业务功能开发。

#### Scenario: 基线范围保持聚焦
- **WHEN** 本 change 被实现
- **THEN** 它建立的是项目结构、验证路径和持久化边界，而不要求同时完成完整产品流程或高级平台能力
