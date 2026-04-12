# ADR-001 Apple-first Technical Stack

## 状态

已接受

## 适用版本

- `v1.0`

## 背景

`TopOne v1.0` 当前 MVP 范围覆盖 `iOS`、`iPadOS`、`macOS`。产品核心价值是让当前唯一重要目标持续“被看见”，尤其在 `macOS` 上依赖桌面常驻展示层、状态栏、主窗口等平台级触点。

如果在 MVP 阶段过早引入跨平台 UI 框架，容易为了未来复用牺牲当前 Apple-first 体验质量，并增加工程复杂度。

## 决策

`TopOne v1.0` 采用 Apple-first native 技术路线。

推荐客户端栈：
- `Swift 6`
- `SwiftUI`
- `SwiftData`

平台策略：
- `iPadOS` 复用 `iOS` 主体结构，并以放大适配为主。
- `macOS` 采用独立平台体验设计。
- `macOS` 支持桌面常驻展示层、状态栏、主窗口三层结构。

## 后续跨平台策略

`Android` 与 `Windows` 当前属于 deferred，而不是永久排除。

未来扩展时，应优先复用：
- 领域规则
- 数据模型
- 同步边界
- 产品原则

未来扩展时，不强求复用当前 MVP 的 UI 代码。各平台可采用最贴合自身系统能力的原生实现。

候选方向：
- `Android`：`Kotlin + Jetpack Compose`
- `Windows`：`C# + WinUI 3`

最终选型以后续阶段的产品范围、系统触点需求与维护成本为准。

## 影响

正向影响：
- 降低 MVP 阶段工程复杂度。
- 更好支持 Apple 平台系统级触点。
- 保持 `macOS` 桌面常驻展示体验质量。

代价：
- 当前不会获得 `Android` / `Windows` 的 UI 代码复用。
- 后续跨平台扩展需要重新做平台实现评估。

## 依据

- `openspec/changes/confirm-technical-stack/proposal.md`
- `openspec/changes/confirm-technical-stack/design.md`
- `openspec/changes/confirm-technical-stack/specs/technical-stack/spec.md`
