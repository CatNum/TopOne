# TopOne

TopOne 是一个 Apple-first 的 AI Native 项目，当前聚焦 `iOS`、`iPadOS`、`macOS` 三端的原生应用基线建设。

当前仓库已经完成：
- 技术栈确认（`Swift 6` + `SwiftUI` + `SwiftData`）
- 最小 Swift 工程基线落地
- 本地 `format` / `lint` / `build` / `test` 验证链路
- GitHub Actions 工程基线工作流

## 当前状态

- 当前阶段：`初始化基线`
- 已完成 OpenSpec change：`confirm-technical-stack`
- 已完成 OpenSpec change：`bootstrap-swift-engineering-baseline`
- 下一步：进入第一个功能型 change，实现核心业务能力

版本级进度见 `docs/compliance/v1.0/progress.md`。

## 技术栈

- 语言：`Swift 6`
- UI：`SwiftUI`
- 本地持久化：`SwiftData`
- 工程生成：`XcodeGen`
- 代码格式化：`SwiftFormat`
- 代码检查：`SwiftLint`
- 构建与测试：`xcodebuild`
- 规范与变更管理：`OpenSpec`

## 工程结构

- `App/`：应用入口与平台壳层
- `Application/`：应用服务
- `Domain/`：领域模型
- `Persistence/`：持久化边界
- `Presentation/`：界面层状态与展示逻辑
- `PlatformAdapters/`：平台特定适配
- `Tests/`：最小测试入口
- `openspec/`：变更提案、设计、任务与规范
- `docs/`：需求、设计、原型、决策、合规进度等文档

## 本地开发

### 前置依赖

需要本机具备：
- `Xcode`
- `xcodebuild`
- `xcodegen`
- `swiftformat`
- `swiftlint`

如果命令缺失，可用 Homebrew 安装：

```bash
brew install xcodegen swiftformat swiftlint
```

### 生成工程

```bash
xcodegen generate
```

生成结果：`TopOne.xcodeproj`

### 常用命令

格式化：

```bash
./scripts/format.sh
```

静态检查：

```bash
./scripts/lint.sh
```

构建：

```bash
./scripts/build.sh
```

测试：

```bash
./scripts/test.sh
```

## 当前验证策略

当前默认验证链路以 `macOS` scheme 为主，因此在**没有安装 iOS Simulator runtime** 的机器上也能完成基线验证。

这意味着：
- 共享层开发不会被阻塞
- `macOS` 构建与测试可以继续推进
- 后续若要开展 `iOS/iPadOS` 界面调试与设备行为验证，仍建议安装对应 Simulator runtime

## 相关入口

- 工程定义：`project.yml`
- 工程文件：`TopOne.xcodeproj`
- OpenSpec 任务：`openspec/changes/bootstrap-swift-engineering-baseline/tasks.md`
- 版本进度：`docs/compliance/v1.0/progress.md`
- 技术设计：`docs/design/v1.0/README.md`
- 关键决策：`docs/decisions/v1.0/README.md`

## CI

GitHub Actions 工作流见：`.github/workflows/engineering-baseline.yml`

该工作流会执行：
- 工程生成
- 格式检查
- lint
- build
- test
