# TopOne v1.0 技术方案

## 1. 问题描述

本版本需要在 Apple-first 前提下，完成 `TopOne` 的 MVP 技术闭环：
- 支持 `iOS` / `iPadOS`
- 维护长期目标、日常任务、奖励池、成就档案与完成记录
- 以本地数据为权威源，优先保证单机可用性

产品规则、页面结构与交互流程以 `docs/requirements/` 为准；本文只描述技术实现方案。

## 2. 已冻结前提

- 技术栈：`Swift 6` + `SwiftUI` + `SwiftData`
- 客户端策略：Apple-first native
- 数据策略：local-first，`iOS` / `iPadOS` 设备间同步优先采用 `CloudKit private database`

相关决策见：
- `docs/decisions/v1.0/README.md`
- `openspec/changes/confirm-technical-stack/design.md`
- `openspec/changes/confirm-technical-stack/specs/technical-stack/spec.md`

## 3. 方案边界

### 3.1 本文覆盖
- 客户端模块拆分
- 核心数据模型
- 数据流与状态管理边界
- 本地存储方案
- 多端共享与差异化实现边界

### 3.2 本文不覆盖
- 页面文案
- 页面跳转与交互剧本
- 高保真页面表现

以上内容分别由 `docs/requirements/` 与 `docs/prototype/` 承担。

## 4. 模块划分

建议按职责拆分为以下模块：
- `Domain`：长期目标、日常任务、奖励、成就档案、切换记录、完成记录等领域模型与规则
- `Persistence`：基于 `SwiftData` + `CloudKit private database` 的数据持久化与同步边界
- `Application`：目标切换、任务完成、奖励抽取、成就归档等应用服务
- `Presentation`：按平台组织的 `SwiftUI` 页面与状态绑定

## 5. 核心数据模型

建议至少覆盖以下实体：

| 实体 | 作用 | 关键字段 |
|------|------|---------|
| `Goal` | 长期目标 | 标题、是否当前 TopOne、锁定截止时间（用于计算剩余锁定时间倒计时）、手动进度、阶段信息、所属分组、Rank |
| `Task` | 日常任务 | 标题、状态、开始时间、结束时间、等级、所属 Goal |
| `Reward` | 奖励池条目 | 内容、等级 |
| `RewardDrawRecord` | 奖励抽取记录 | 来源任务、抽中奖励、抽取时间 |
| `AchievementRecord` | 成就档案条目 | 对应长期目标、抽中奖励、归档时间 |
| `SwitchRecord` | 提前切换记录 | 原目标、新目标、理由、最少字数门槛、时间 |
| `CompletionRecord` | 完成记录 | 完成目标、成果总结、完成时间、奖励结果 |

## 6. 数据流

### 6.1 目标切换
- 用户发起切换
- 应用服务校验锁定期与理由门槛
- 写入 `SwitchRecord`
- 更新 `Goal` 当前状态
- 刷新任务区与系统展示位

### 6.2 任务完成
- 更新 `Task` 状态与结束时间
- 根据任务等级从对应奖励池抽取奖励
- 写入 `RewardDrawRecord`
- 将抽中奖励永久写入 `AchievementRecord`
- 如满足完成条件，写入 `CompletionRecord`

### 6.3 数据同步
- 本地 `SwiftData` 为权威数据源
- `iOS` / `iPadOS` 设备间同步通过 `CloudKit private database`
- 展示层不直接承担复杂编辑逻辑

## 7. 状态与存储

- 数据权威源：本地持久化
- UI 状态：由 `SwiftUI` 视图状态与应用服务结果驱动
- 同步边界：`iOS` / `iPadOS` 设备间同步优先采用 `CloudKit private database`
- 平台差异：
  - `iOS` / `iPadOS` 复用主体信息架构

## 8. 技术权衡

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| Apple-first native | 系统能力贴合、桌面触点更自然 | 平台覆盖范围有限 | 采用 |
| 跨平台统一 UI | 共享成本看似更低 | 当前会牺牲 Apple 体验与交付速度 | 本版不采用 |
| Local-first | MVP 落地快、复杂度低 | 多设备同步需后续补充 | 采用 |

## 9. 遗留风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 奖励抽取、成就档案与完成归档规则后续可能细化 | 影响领域模型稳定性 | 领域层保持规则集中管理 |
| `CloudKit private database` 引入后可能带来模型同步约束 | 影响存储层演进 | 先保持实体边界清晰，避免 UI 直接耦合存储实现 |
