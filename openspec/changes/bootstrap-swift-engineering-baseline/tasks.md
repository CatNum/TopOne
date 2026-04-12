## 1. 初始化工程骨架

- [x] 1.1 选择并创建最小 Swift 工程入口（`xcodeproj` 或等效工程结构）
- [x] 1.2 建立 `iOS` / `iPadOS` / `macOS` 的基础 target 与共享入口组织方式
- [x] 1.3 创建与技术方案一致的基础目录结构（`App`、`Domain`、`Persistence`、`Application`、`Presentation`、`PlatformAdapters`、`Tests`）

## 2. 建立最小应用与持久化边界

- [x] 2.1 创建最小 App 启动入口与占位主界面
- [x] 2.2 建立 `SwiftData` 的最小接入边界与容器初始化位置
- [x] 2.3 为后续核心模型实现预留清晰的持久化与应用服务放置点

## 3. 建立本地验证链路

- [x] 3.1 接入 `SwiftFormat` 并提供可执行格式化命令
- [x] 3.2 接入 `SwiftLint` 并提供可执行 lint 命令
- [x] 3.3 建立 `xcodebuild` 的 build / test 验证命令
- [x] 3.4 添加最小测试入口，验证工程可运行测试链路

## 4. 建立 CI 与文档回写

- [x] 4.1 创建 GitHub Actions workflow，运行最小 lint / build / test 流程
- [x] 4.2 更新 `docs/compliance/v1.0/progress.md` 记录工程基线推进状态
- [x] 4.3 在实现完成后回写 OpenSpec change 任务状态并准备进入后续功能实现 change
