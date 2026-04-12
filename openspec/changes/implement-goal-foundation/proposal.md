## Why

工程基线已经建立，但当前应用仍只有占位模型与占位界面，无法支撑 TopOne 的核心体验。下一步需要先落地长期目标与当前 TopOne 的基础能力，让后续任务、奖励、切换、桌面展示等功能都有稳定的数据与业务起点。

## What Changes

- 建立长期目标 `Goal` 的可用领域模型与 SwiftData 持久化字段。
- 实现当前 `TopOne` 的基础选择规则：同一时刻最多一个长期目标处于当前状态。
- 提供目标创建、查询、设为 TopOne、进度更新的最小应用服务。
- 建立主界面的基础目标展示与空状态入口。
- 增加针对目标基础规则的测试覆盖。
- 不在本 change 中实现日常任务、奖励池、强制切换理由、完成归档或 macOS 桌面常驻层完整交互。

## Capabilities

### New Capabilities
- `goal-foundation`: 覆盖长期目标创建、当前 TopOne 选择、手动进度维护、空状态与基础展示能力。

### Modified Capabilities
- 无

## Impact

- 影响 `Domain/Models/Goal.swift` 的字段与规则承载方式。
- 影响 `Persistence/Storage/PersistenceController.swift` 的模型注册与容器初始化。
- 影响 `Application/Services/GoalService.swift` 的应用服务边界。
- 影响 `Presentation/` 与 `App/Shared/TopOneRootView.swift` 的基础展示。
- 影响 `Tests/TopOneCoreTests/` 的测试覆盖。
