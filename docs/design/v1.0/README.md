# TopOne v1.0 技术方案

## 1. 问题描述

本版本需要在 Apple-first 前提下，完成 `TopOne` 的 MVP 技术闭环：
- 支持 `iOS` / `iPadOS` / `macOS`
- 维护长期目标、日常任务、奖励池与完成记录
- 以本地数据为权威源，优先保证单机可用性

产品规则、页面结构与交互流程以 `docs/requirements/` 为准；本文只描述技术实现方案。

## 2. 已冻结前提

- 技术栈：`Swift 6` + `SwiftUI` + `SwiftData`
- 客户端策略：Apple-first native
- 数据策略：local-first，后续如需 Apple 设备间同步，优先 `CloudKit private database`

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
- `Domain`：长期目标、日常任务、奖励、切换记录、完成记录等领域模型与规则
- `Persistence`：基于 `SwiftData` 的本地持久化
- `Application`：目标切换、任务完成、奖励抽取、完成归档等应用服务
- `Presentation`：按平台组织的 `SwiftUI` 页面与状态绑定
- `PlatformAdapters`：`macOS` 桌面常驻层、状态栏、平台级能力封装

## 5. 核心数据模型

建议至少覆盖以下实体：

| 实体 | 作用 | 关键字段 |
|------|------|---------|
| `Goal` | 长期目标 | 标题、是否当前 TopOne、锁定截止时间、手动进度、阶段信息 |
| `Task` | 日常任务 | 标题、状态、开始时间、结束时间、等级、所属 Goal |
| `Reward` | 奖励池条目 | 内容、等级 |
| `RewardDrawRecord` | 奖励抽取记录 | 来源任务、抽中奖励、抽取时间 |
| `SwitchRecord` | 提前切换记录 | 原目标、新目标、理由、最少字数门槛、时间 |
| `CompletionRecord` | 完成记录 | 完成目标、成果总结、完成时间、奖励结果 |
| `AppPreference` | 偏好与展示配置 | 常驻层位置、锁定状态、展示开关 |

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
- 如满足完成条件，写入 `CompletionRecord`

### 6.3 系统展示同步
- `macOS` 常驻层与状态栏只读取当前 `TopOne` 的必要字段
- 展示层不直接承担复杂编辑逻辑
- 主窗口负责完整管理能力

## 7. 状态与存储

- 数据权威源：本地持久化
- UI 状态：由 `SwiftUI` 视图状态与应用服务结果驱动
- 同步边界：MVP 阶段不依赖云端；未来扩展时以本地模型为基础映射到 `CloudKit`
- 平台差异：
  - `iOS` / `iPadOS` 复用主体信息架构
  - `macOS` 保留桌面常驻层、状态栏、主窗口三层能力

## 8. 技术权衡

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| Apple-first native | 系统能力贴合、桌面触点更自然 | 平台覆盖范围有限 | 采用 |
| 跨平台统一 UI | 共享成本看似更低 | 当前会牺牲 Apple 体验与交付速度 | 本版不采用 |
| Local-first | MVP 落地快、复杂度低 | 多设备同步需后续补充 | 采用 |

## 9. 遗留风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| `macOS` 常驻展示与状态栏能力实现复杂 | 影响桌面端核心体验 | 优先做最小闭环，再逐步增强 |
| 奖励抽取与完成归档规则后续可能细化 | 影响领域模型稳定性 | 领域层保持规则集中管理 |
| 后续引入同步时可能需要模型调整 | 影响存储层演进 | 先保持实体边界清晰，避免 UI 直接耦合存储实现 |
