# Interaction Record 示例

## 示例 1：成功采用新实践

```markdown
## Interaction Record（交互记录）
- context: 当前任务需求跨度大，过去常在中后期返工，需要更稳定的拆解方式。
- hypothesis: 如果每一步只做一个目标并附带一次验收，返工率会下降。
- decision: 将“单步执行 + 即时验证”设为默认执行流程。
- why: 在当前阶段，降低交付风险比追求一次性速度更重要；小步失败更易定位与回滚。
- action: 将一次大改拆成 4 个微步骤，并在每步完成后立即验证。
- outcome: 本次任务返工轮次由 3 次降到 1 次，且未发生跨文件回滚。
- risk: 当任务数量较多时，细粒度步骤会增加协作成本。
- next: 在后续 3 个任务复用该流程，并持续记录返工轮次。
```

## 示例 2：失败尝试后的策略调整

```markdown
## Interaction Record（交互记录）
- context: 为了加快交付，尝试将全部产物一次性生成后再统一校验。
- hypothesis: 一次性生成可以减少上下文切换并缩短总耗时。
- decision: 先完整生成，再统一验证。
- why: 在时间压力下，优先尝试吞吐量更高的路径。
- action: 未设置中间检查点，直接生成整套产物后再跑验证。
- outcome: 需求一致性校验失败，2 份产物需重写，净耗时上升约 30%。
- risk: 批量优先策略会掩盖早期冲突，导致后置修复成本上升。
- next: 切回分阶段生成，并在每个产物后设置 checkpoint validation（检查点验证）。
```

## 示例 3：基于证据进行策略切换

```markdown
## Interaction Record（交互记录）
- context: 团队对“优先响应速度”还是“优先决策可追溯性”存在分歧。
- hypothesis: 以可追溯性优先的结构化回复会提升长期决策质量。
- decision: 切换为固定结构回复：current state、factors、plan、risks、boundaries。
- why: 历史问题主要来自决策依据缺失，而不是响应速度不足。
- action: 连续 5 次交互采用结构化回复格式。
- outcome: 平均每个任务的追问次数从 4 次降到 1 次。
- risk: 对简单问题可能出现回复偏长、阅读负担上升。
- next: 为简单请求增加 lightweight 模式，但保留核心决策追踪字段。
```

## 使用说明

- 每条记录只绑定一个主决策。
- `outcome` 必须至少包含一个可观察信号（次数、比例、耗时或明确行为变化）。
- 若尚未执行，`outcome` 必须标记为 `not validated` 并说明原因。
