# Tasks

## 1. 冻结 Apple-first runtime stack
- [x] 确认 `Swift 6 + SwiftUI` 为 Apple-first MVP 客户端栈
- [x] 确认 `iPadOS` 复用 `iOS` 主体结构
- [x] 确认 `macOS` 采用独立体验，不直接照搬 iOS

## 2. 冻结本地数据模型与领域规则边界
- [x] 确认 `SwiftData` 为本地权威数据源
- [x] 明确核心实体：`Goal / Task / Reward / RewardDrawRecord / SwitchRecord / AppPreference`
- [x] 明确关键规则必须由 domain/service 层承载

## 3. 冻结 MVP 本地优先 / 后续 CloudKit 同步策略
- [x] 确认 `Phase 1A` 为本地优先、无同步也可完整使用
- [x] 确认 `Phase 1B` 为 `CloudKit private database` 同步 Apple 设备私有数据
- [x] 明确当前不引入自建后端

## 4. 冻结 macOS 核心系统触点技术路径
- [x] 确认 `macOS` 需要支持桌面常驻展示层、状态栏、主窗口三层结构
- [x] 确认桌面常驻展示层的能力边界由原生窗口 / 平台桥接实现
- [x] 确认状态栏由原生能力支持，不走跨平台替代路径

## 5. 建立工程基线
- [x] 确认 `SwiftFormat` 与 `SwiftLint`
- [x] 确认 `xcodebuild` 用于构建与类型检查
- [x] 确认 `XCTest / Swift Testing` 用于单元测试
- [x] 确认 `XCUITest` 用于少量关键烟雾测试
- [x] 确认使用 `GitHub Actions` 建立 lint / build / test workflow

## 6. 回写文档
- [x] 更新 `docs/decisions/README.md` 与 `docs/decisions/v1.0/README.md`
- [x] 推进 `docs/plan-overview.md` 中 D1 / D2 / D3 的状态
- [x] 更新 `docs/compliance/v1.0/progress.md`
- [x] 视情况新增 ADR 文档
