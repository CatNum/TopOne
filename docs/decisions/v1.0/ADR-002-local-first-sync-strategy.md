# ADR-002 Local-first Sync Strategy

## 状态

已接受

## 适用版本

- `v1.0`

## 背景

`TopOne v1.0` 不计划商业化，当前目标是以最低复杂度完成可用 MVP。产品的核心数据是个人目标、任务、奖励池与完成记录，必须在无网络或无同步的情况下仍可完整使用。

因此，当前阶段不应把自建后端或复杂跨平台同步作为 MVP 前置条件。

## 决策

`TopOne v1.0` 采用 local-first 数据策略。

具体规则：
- 本地数据是权威数据源。
- MVP 在无同步情况下必须完整可用。
- Apple 平台本地持久化优先采用 `SwiftData`。
- 业务规则必须在 domain / service 层承载，不只依赖 UI 层约束。

同步策略：
- `Phase 1A`：本地优先，先完成单设备闭环。
- `Phase 1B`：如需 Apple 设备间同步，优先采用 `CloudKit private database`。
- 当前不引入自建后端。

## Deferred

以下能力后续再评估：
- 自建后端
- 多用户 / 协作
- 复杂跨平台同步冲突策略
- `Android` / `Windows` 跨平台同步落地方案

## 影响

正向影响：
- 降低 MVP 交付复杂度。
- 用户离线时仍可完整使用。
- 保持个人数据优先留在本地。

代价：
- 多设备同步体验不会在 MVP 初始阶段成为前置能力。
- 后续引入同步时，需要基于稳定数据模型补充同步协议和冲突规则。

## 依据

- `openspec/changes/confirm-technical-stack/design.md`
- `openspec/changes/confirm-technical-stack/specs/technical-stack/spec.md`
