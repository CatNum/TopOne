## Why

`confirm-technical-stack` 已经冻结了 TopOne 的 Apple-first 技术方向，但仓库当前仍没有任何可运行的 Swift 工程、测试入口或应用级 CI 基线。现在需要先建立最小工程骨架，把已确认的技术栈落成可构建、可验证、可继续迭代的实现起点。

## What Changes

- 建立 Apple-first 的最小 Swift 工程基线，覆盖 `iOS`、`iPadOS`、`macOS` 的工程入口与目标组织方式。
- 建立与现有技术方案一致的基础目录分层，为 `Domain`、`Persistence`、`Application`、`Presentation`、`PlatformAdapters` 留出清晰边界。
- 建立 `SwiftData` 的最小持久化承载方式，使后续核心模型可以在明确边界内逐步落地。
- 建立最小工程验证链路：`SwiftFormat`、`SwiftLint`、`xcodebuild`、单元测试入口、GitHub Actions workflow。
- 明确本轮只做工程基线，不混入大规模业务页面实现、CloudKit 落地或复杂平台交互增强。

## Capabilities

### New Capabilities
- `engineering-baseline`: 定义 TopOne Apple-first 工程骨架、最小构建/测试路径、基础持久化边界与 CI 验证链路。

### Modified Capabilities
- 无

## Impact

- 影响 `openspec/changes/bootstrap-swift-engineering-baseline/` 下的新 artifact。
- 后续实现将影响 Swift 工程目录、测试目录与 `.github/workflows/`。
- 引入 `SwiftFormat`、`SwiftLint`、`xcodebuild` 与测试基线作为工程依赖和验证入口。
