## Context

`bootstrap-swift-engineering-baseline` 已经建立可构建、可测试的 Apple-first Swift 工程，但当前 `Goal` 仍是占位模型，`GoalService` 也只返回占位数据。根据 `docs/requirements/core-models.md` 与 `docs/requirements/interaction-flows.md`，TopOne 的后续功能都依赖长期目标与当前唯一 TopOne 的基础规则，因此本 change 先建立目标基础能力。

当前约束：
- 技术栈保持 `Swift 6` + `SwiftUI` + `SwiftData`。
- 数据权威源为本地持久化。
- 当前验证链路以 `macOS` scheme 为主，避免依赖本机 iOS Simulator runtime。
- 本轮只做目标基础能力，不扩大到任务、奖励、完成归档或桌面常驻完整体验。

## Goals / Non-Goals

**Goals:**
- 建立长期目标 `Goal` 的最小可用字段：标题、是否当前 TopOne、手动进度、创建时间、锁定截止时间。
- 实现同一时刻最多一个当前 TopOne 的应用服务规则。
- 提供创建目标、读取目标、设为 TopOne、更新进度的服务入口。
- 在主界面展示空状态或当前 TopOne 的基础信息。
- 用测试覆盖标题长度、进度边界和唯一 TopOne 规则。

**Non-Goals:**
- 不实现日常任务池。
- 不实现奖励池与奖励抽取。
- 不实现强制切换理由与锁定期处罚完整流程。
- 不实现完成归档。
- 不实现 macOS 桌面常驻层与状态栏完整交互。
- 不引入 CloudKit 或跨设备同步。

## Decisions

### 1. 先让 `Goal` 成为真实 SwiftData 模型

选择：在现有 `Domain/Models/Goal.swift` 上扩展字段与初始化约束，而不是新增并行模型。

原因：工程基线已经把 `Goal` 注册进 `SwiftData` schema，沿用该模型可以减少迁移复杂度，并让后续任务、奖励与展示能力围绕同一个实体演进。

备选：先建立纯 Swift domain struct，再映射到 SwiftData model。该方案能更强地区分领域层和存储层，但当前阶段会增加样板代码，不利于快速建立 MVP 基础闭环。

### 2. 当前 TopOne 唯一性由应用服务维护

选择：由 `GoalService` 在设定当前 TopOne 时取消其他目标的当前状态。

原因：`SwiftData` 不直接提供跨对象唯一约束的简单声明式机制，应用服务集中维护规则更直接，也便于测试。

备选：在 UI 层手动控制唯一性。该方案会让规则分散到页面逻辑，后续 macOS 状态栏、桌面常驻层和 iOS 页面复用时容易产生不一致。

### 3. 进度使用 0 到 1 的 `Double`

选择：`Goal.progress` 保持 `Double`，服务层对输入做 0...1 边界限制。

原因：当前设计中展示为手动百分比，内部用 0...1 可减少 UI 与业务计算的混淆。

备选：使用 0 到 100 的整数。该方案更贴近用户输入，但后续动画、图形展示和比例计算需要反复转换。

### 4. 主界面先展示目标基础状态

选择：`TopOneRootView` 先根据目标状态展示空状态或当前 TopOne 卡片，不在本轮拆出完整页面系统。

原因：当前目标是验证数据与服务闭环，不应提前实现完整 iOS/macOS 信息架构。

备选：直接实现任务页、奖励池页、设置页三栏/三 tab 结构。该方案更接近最终产品，但会把本 change 扩大到页面架构与导航设计，偏离目标基础能力。

## Risks / Trade-offs

- `Goal` 同时承担领域与 SwiftData 存储职责 → 后续复杂规则增加时，可再拆出纯领域规则对象或 service 方法。
- 当前唯一 TopOne 规则依赖服务入口 → 后续 UI 与批处理必须统一通过 `GoalService` 修改当前目标。
- 标题与进度校验先做最小规则 → 后续若加入更细的中文字符长度与提示规则，可在服务层继续收敛。
- macOS-only 测试链路不能覆盖 iOS 视觉行为 → 安装 iOS Simulator runtime 后再补 iOS scheme 测试。
