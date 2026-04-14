# ADR-004 iOS iPadOS Sync Strategy

## 状态

已接受

## 适用版本

- `v1.0`

## 背景

在保持 local-first 前提下，当前版本已经明确只聚焦 `iOS`、`iPadOS`，因此需要把 Apple 设备间同步策略进一步落到当前版本的明确实现方向，而不是停留在泛化表述。

## 决策

`TopOne v1.0` 当前版本在 `iOS` / `iPadOS` 设备间同步优先采用 `CloudKit private database`。

具体规则：
- 本地数据仍是权威数据源。
- 单设备闭环仍是最小可用前提。
- 多设备同步目标限定为 `iOS` / `iPadOS` Apple 设备间同步。
- 当前不引入自建后端。

## 影响

正向影响：
- 让当前版本同步方向更明确。
- 便于后续围绕 `SwiftData` 与 Apple 生态同步能力收敛实现边界。

代价：
- 需要在模型与持久化层提前考虑 `CloudKit private database` 的同步约束。

## 依据

- `docs/design/v1.0/README.md`
- `docs/requirements/business-rules.md`
- `docs/requirements/interaction-flows.md`
