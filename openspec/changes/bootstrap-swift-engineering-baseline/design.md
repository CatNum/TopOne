## Context

`confirm-technical-stack` 已经把 TopOne v1 的技术方向冻结为 Apple-first native、`SwiftData` local-first、后续 Apple 设备间同步优先 `CloudKit private database`。但仓库当前仍缺少任何实际 Swift 工程入口、测试运行路径、lint 配置和应用级 CI，因此后续所有实现任务都还没有稳定落点。

当前设计约束包括：
- 本轮必须围绕 `iOS`、`iPadOS`、`macOS` 的统一工程基线展开
- 必须与 `docs/design/v1.0/README.md` 中的模块边界保持一致
- 必须优先建立“可构建、可验证、可扩展”的骨架，而不是直接进入业务页面开发
- 必须为后续 `SwiftData` 模型、领域规则、测试与 CI 留出明确承载位置

## Goals / Non-Goals

**Goals:**
- 建立 Apple-first 的最小 Swift 工程入口与目标组织方式
- 建立与既有技术方案一致的目录和模块边界
- 为 `SwiftData` 提供最小可用的持久化承载边界
- 建立 `SwiftFormat`、`SwiftLint`、`xcodebuild`、单元测试与 GitHub Actions 的最小工程链路
- 让后续 OpenSpec change 可以基于明确的工程地基继续推进实现

**Non-Goals:**
- 不在本轮实现完整业务页面
- 不在本轮落地 CloudKit 同步
- 不在本轮完成 `macOS` 桌面常驻展示层的最终交互体验
- 不在本轮细化所有领域规则或奖励系统细节

## Decisions

### 1. 先建立单一工程基线，再进入功能实现
- 选择：优先建立可运行工程骨架，而不是继续细化产品文档或直接写业务页面
- 原因：当前主要缺口不是方向不清，而是仓库缺少应用工程入口和验证链路
- 备选方案：先开功能型 change
- 不采用原因：没有工程地基时，功能实现会缺少统一目录、验证命令和 CI 入口

### 2. 工程结构按职责分层，与现有设计文档对齐
- 选择：围绕 `App`、`Domain`、`Persistence`、`Application`、`PlatformAdapters`、`Tests` 建立基础布局
- 原因：这与 `docs/design/v1.0/README.md` 已确认的模块划分一致，便于后续逐步填充实现
- 备选方案：先做单目录简单堆叠
- 不采用原因：会让后续领域规则、平台适配和持久化边界更快耦合在一起

### 3. `SwiftData` 只建立最小持久化承载边界
- 选择：本轮只建立 `SwiftData` 的起始承载位置与接入点，不一次性实现全部模型和规则
- 原因：当前 change 目标是工程基线，不是完整业务实现
- 备选方案：一次性把 `Goal`、`Task`、`Reward` 等全部模型都实现完
- 不采用原因：范围会膨胀到功能实现层，削弱工程基线 change 的聚焦性

### 4. 验证链路以最小可执行为原则
- 选择：建立 `SwiftFormat`、`SwiftLint`、`xcodebuild build/test`、基础 GitHub Actions workflow
- 原因：这些工具已经在上一条技术栈 change 中被确认，需要在本轮落成真实入口
- 备选方案：只建工程，不建验证链路
- 不采用原因：会导致“能写代码但无法形成稳定门禁”，不符合 AI Native 流程要求

## Risks / Trade-offs

- [Risk] Xcode 工程组织方式早期选择不当 → Mitigation：本轮只建立最小骨架，避免过早拆成过多 target 或 package
- [Risk] 工程基线 change 被功能实现需求挤占 → Mitigation：任务明确限制在骨架、验证链路、持久化边界，不做大规模页面开发
- [Risk] `SwiftData` 接口过早固化 → Mitigation：只定义接入边界和基础容器，不冻结完整模型细节
- [Risk] CI 先建后续仍需调整 → Mitigation：先建立最小 lint/build/test workflow，后续随真实工程扩展再演进

## Migration Plan

1. 创建 OpenSpec change 并冻结工程基线范围
2. 初始化 Swift 工程、目录和最小 App 入口
3. 建立 `SwiftData` 的最小承载边界与测试入口
4. 接入 lint、build、test 与 GitHub Actions
5. 回写 `docs/compliance/v1.0/progress.md` 等状态文档

回滚策略：如工程组织方式验证后不合适，可在功能开发大规模开始前调整工程结构；本轮不涉及线上迁移与数据迁移。

## Open Questions

- 工程基线最终采用单一 `xcodeproj` 还是 `xcworkspace + packages`，需要在实现时结合最小可维护性再确认
- `iOS`、`iPadOS`、`macOS` target 是一次性全部拉起，还是先以共享主体 + `macOS` 骨架占位的形式初始化，需要在实现时权衡复杂度
- `SwiftFormat` 与 `SwiftLint` 的规则集采用最小默认配置还是项目定制配置，需要在实施时结合团队偏好决定
