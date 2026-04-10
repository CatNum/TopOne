# ai-interaction-evolution-tracker

## 作用

将每次有意义的人机交互沉淀为结构化证据，持续形成 AI Native 流程演进记录。

## 何时使用

当你在对话中出现以下诉求时，建议触发本 skill：
- 讨论流程优化、方法迭代、决策依据。
- 复盘“做了什么、效果如何、为什么这样做”。
- 需要形成可追溯的交互记录与周期总结。

## 如何调用（建议话术）

- “请用 `ai-interaction-evolution-tracker` 记录这次交互，并给出一条完整 Interaction Record。”
- “把这次实践按 `context/hypothesis/decision/why/action/outcome/risk/next` 结构沉淀。”
- “基于最近 1 周的交互记录，输出 Workflow Evolution Summary。”

## 最小输出要求

每条记录必须包含且仅包含一条主决策，字段如下：
- `context`
- `hypothesis`
- `decision`
- `why`
- `action`
- `outcome`
- `risk`
- `next`

当记录触发“稳定可复用优化”并已落地到流程 skill 时，必须额外更新 changelog：
- 文件：`.agent/skills/ai-native-standard-flow/changelog.md`
- 规则：每次优化都要追加一条记录，禁止只在对话里说明。
- 最小字段：`背景`、`动作`、`结果`、`影响`

## 常见误用

- 把闲聊或状态同步也写入记录（应跳过无价值交互）。
- `outcome` 没有证据（只有主观判断，没有可观察信号）。
- 一条记录混入多个决策（导致后续无法比较效果）。
- `next` 写成长期愿景而不是可验证动作。
- 未执行也写成“已验证结论”（应标记 `not validated`）。
- 已更新流程 skill 但未新增对应 changelog 文件。

## 相关文件

- 核心规则：`SKILL.md`
- 填写示例：`examples.md`
- 标准流程 skill：`.agent/skills/ai-native-standard-flow/SKILL.md`
