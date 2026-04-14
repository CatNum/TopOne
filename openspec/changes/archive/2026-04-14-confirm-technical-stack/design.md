# Design

## 1. 推荐结论

TopOne v1 应采用 Apple-first native 技术路线，而不是从第一天就引入跨平台 UI 框架。

推荐冻结如下客户端栈：
- `Swift 6`
- `SwiftUI`
- `SwiftData`
- `WidgetKit`
- `AppIntents`
- `MenuBarExtra`
- `AppKit bridge`（仅 `macOS` 特有能力按需桥接）
- `CloudKit private database`（后续可选同步路径）

## 2. 为什么采用 Apple-first native

### 2.1 产品范围决定实现边界
当前 MVP 范围明确为：
- `iOS`
- `iPadOS`
- `macOS`

其中：
- `iPadOS` 是 `iOS` 的放大适配
- `macOS` 是单独设计的平台

这意味着当前阶段不需要为了未来的 `Android / Windows` 过早引入统一 UI 抽象层。

### 2.2 macOS 系统级触点是产品核心
TopOne 在 `macOS` 上的核心价值不是“被打开”，而是“被看见”。
因此，`macOS` 必须支持：
- 桌面常驻展示层
- 状态栏
- 主窗口

其中桌面常驻展示层与状态栏都需要具备系统级交互能力，这类能力使用 Apple 原生栈更稳定、实现成本更低、体验也更贴近平台习惯。

### 2.3 为什么不采用 Flutter / React Native / Tauri / Electron
这些方案并非不能做，但对当前 TopOne 来说存在明显不利因素：
- 对 `macOS` 常驻展示层与状态栏的能力支持更依赖桥接
- 容易为了未来跨平台而牺牲当前 Apple-first MVP 的体验质量
- 会引入额外的依赖、抽象和工程复杂度
- 当前产品并不需要先解决 Android / Windows 代码复用问题

## 3. 本地数据层设计

### 3.1 总体原则
- 本地优先
- 本地数据是唯一权威数据源
- 即使完全离线，也必须可完整使用
- 业务规则写在 domain/service 层，而不是分散在 UI 中

### 3.2 推荐本地数据方案
使用 `SwiftData` 作为本地持久化方案。

### 3.3 建议核心模型
- `Goal`
- `Task`
- `Reward`
- `RewardDrawRecord`
- `SwitchRecord`
- `AppPreference`

### 3.4 领域规则应覆盖
- 最多 3 个长期目标
- 同时只能有 1 个 `TopOne`
- 只有当前 `TopOne` 的任务可编辑
- `未开始 + 执行中 <= 5`
- `执行中 <= 2`
- 锁定周期与提前切换规则
- 最少理由字数动态变化规则
- 完成条件（`100%` + 成果总结）
- 奖励池按等级随机抽取规则

## 4. 同步策略

### Phase 1A：本地优先
- MVP 先完成单设备体验
- 不依赖同步也可以完整使用

### Phase 1B：Apple 设备间同步
- 若需要跨 Apple 设备同步，优先采用 `CloudKit private database`
- 仅同步个人私有数据
- 不引入自建后端

### 为什么当前不做自建后端
- 产品不商业化
- 当前要求低成本
- 当前范围是个人产品，不涉及协作与多用户共享
- 自建后端会显著增加开发和维护负担

## 5. 工程基线

推荐基线如下：
- `SwiftFormat`
- `SwiftLint`
- `xcodebuild`
- `XCTest / Swift Testing`
- `XCUITest`（少量烟雾测试）
- `GitHub Actions`

### 最小 CI 任务
- `lint`
- `build`
- `test`

### 最小测试重点
- `TopOne` 唯一性
- 任务数量与状态约束
- 提前切换最少理由字数规则
- 完成条件判断
- 奖励抽取规则
- 本地数据读写

## 6. Deferred

当前刻意暂缓：
- Android / Windows runtime stack
- 自建后端
- 多用户 / 协作
- 跨平台复杂冲突解决
- 为未来跨平台提前引入 Flutter / React Native / Tauri / Electron

### 6.1 Deferred 不等于放弃
`Android` 与 `Windows` 当前是明确 deferred，而不是永久不做。

本次不进入实现，只是因为当前 MVP 的首要目标，是先把 Apple-first 体验与系统触点能力做对，而不是为了未来跨平台提前支付额外的工程复杂度。

### 6.2 为什么当前不提前统一跨平台 UI
当前产品的核心价值是“被看见”，而不是通用的信息录入或列表管理。

尤其 `macOS` 的桌面常驻展示层、状态栏、主窗口三层结构，明显依赖原生平台能力与平台交互习惯。若在当前阶段为了未来复用而强行统一 UI，容易：
- 牺牲 Apple-first MVP 的体验质量
- 拉高当前实现成本
- 让工程复杂度先于产品价值增长

### 6.3 后续跨平台真正应共享的内容
未来扩展到 `Android` / `Windows` 时，应优先共享：
- domain rules
- data schema
- sync boundary / protocol
- product principles

具体包括：
- `TopOne` 唯一性、任务数量约束、切换惩罚、完成条件、奖励抽取规则
- `Goal / Task / Reward / RewardDrawRecord / SwitchRecord / AppPreference`
- 哪些数据同步、何时同步、冲突如何处理
- 信息层级、展示优先级、平台触点边界、文案语气

### 6.4 后续跨平台不必强求共享的内容
未来扩展时，不必强求共享 UI 代码。

更合理的做法是：
- 各平台共享产品规则与数据语义
- 各平台按原生能力实现最贴合的 UI 与系统触点

这意味着当前阶段仍不建议以 Flutter / React Native / Tauri / Electron 作为 MVP 主栈，只为了提前统一跨平台 UI。

### 6.5 推荐扩展路径
- Phase 1A：完成 Apple-first、本地优先 MVP
- Phase 1B：在 Apple 生态内验证 `CloudKit private database` 同步路径
- Phase 2：抽象稳定的领域规则、数据 schema、导入导出格式、同步协议
- Phase 3：分别推进 `Android` 与 `Windows` 原生实现

后续扩展时，可优先考虑：
- `Android`：`Kotlin + Jetpack Compose`
- `Windows`：`C# + WinUI 3`

最终选型仍应根据当时的产品范围、系统触点需求与维护成本重新评估。

## 7. 结果

本次设计的结果是：
- 优先把 Apple-first MVP 做对
- 把共享能力放在 domain / persistence / sync abstraction，而不是强行统一 UI
- 让后续开发建立在可执行、可验证、可维护的技术基础上
