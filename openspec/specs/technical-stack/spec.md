# Technical Stack Spec

## Purpose

定义 TopOne 当前版本的技术栈边界、平台结构、本地优先数据策略与工程基线要求，为后续实现与评审提供统一规范依据。

## Scope

本规范确认 TopOne v1 的技术栈边界，仅覆盖：
- `iOS`
- `iPadOS`
- `macOS`

`Android` 与 `Windows` 不在当前规范范围内。

## Requirements

### Requirement: Apple-first client stack
- 系统 MUST 使用 Apple-first native stack 作为 v1 MVP 客户端实现方案。
- 推荐实现 MUST 基于：
  - `Swift 6`
  - `SwiftUI`
- 系统 MUST NOT 以 Flutter / React Native / Tauri / Electron 作为当前 MVP 的主客户端栈。

### Requirement: Platform structure
- `iPadOS` MUST 复用 `iOS` 主体结构，并以放大适配为主。
- `macOS` MUST 采用单独的平台体验设计。
- `macOS` MUST 支持以下三层结构：
  - 桌面常驻展示层
  - 状态栏
  - 主窗口

### Requirement: Local-first persistence
- 系统 MUST 以本地数据为权威数据源。
- 系统 MUST 使用适合 Apple 原生生态的本地持久化方案。
- 推荐方案 SHOULD 为 `SwiftData`。
- 业务规则 MUST 在 domain/service 层实现，而不是只依赖 UI 层约束。

### Requirement: Sync strategy
- 系统 MUST 在无同步情况下保持完整可用。
- 系统 SHOULD 将同步视为后续阶段能力，而不是当前 MVP 的前置依赖。
- 若启用 Apple 设备间同步，系统 SHOULD 使用 `CloudKit private database`。
- 系统 MUST NOT 依赖自建后端作为当前 MVP 的前提条件。

### Requirement: Engineering baseline
- 工程 MUST 提供格式化与 lint 基线。
- 推荐方案 SHOULD 包含：
  - `SwiftFormat`
  - `SwiftLint`
- 工程 MUST 提供构建与类型检查路径。
- 推荐方案 SHOULD 采用 `xcodebuild`。
- 工程 MUST 提供测试基线。
- 推荐方案 SHOULD 包含：
  - `XCTest / Swift Testing`
  - `XCUITest`（少量关键烟雾测试）
- 工程 MUST 提供 CI 验证路径。
- 推荐方案 SHOULD 使用 `GitHub Actions`。

## Deferred

以下内容当前 deferred：
- `Android` runtime stack
- `Windows` runtime stack
- 自建后端
- 多用户 / 协作
- 复杂跨平台同步冲突策略

### Requirement: Future platform expansion
- 系统 MAY 在后续阶段扩展到 `Android` 与 `Windows`。
- 当前将 `Android` 与 `Windows` 标记为 deferred，MUST 被解释为“当前 MVP 不纳入范围”，而不是“永久排除”。
- 系统在未来扩展到 `Android` 与 `Windows` 时，SHOULD 优先复用领域规则、数据模型与同步边界，而不是要求当前 MVP 预先统一跨平台 UI 实现。
- 系统在未来扩展到 `Android` 与 `Windows` 时，MAY 采用各平台最适合的原生实现方案。
