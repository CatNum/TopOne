# scripts — AI Native 自动化脚本

## 重点

- **两个脚本，职责分离**：`bootstrap.js` 负责项目初始化（只跑一次），`check-compliance.js` 负责合规检查（迭代中反复跑），不要混用。
- **共享代码在 `lib/core.js`**：常量、工具函数、配置加载、状态收集、bootstrap 动作引擎均在此，两个脚本通过 `require("./lib/core")` 引入。
- **退出码语义不同**：`bootstrap.js` 始终 exit 0（不做 CI 门禁）；`check-compliance.js` 在 `overall_status=fail/unknown` 时 exit 1，可直接接入 CI 流水线。

## 文件结构

```
scripts/
├── lib/
│   └── core.js          # 共享模块（常量、工具、配置、collectState、bootstrap 引擎）
├── bootstrap.js          # 项目初始化，仅运行一次
└── check-compliance.js   # 合规检查，迭代中反复运行
```

## bootstrap.js — 项目初始化

**何时运行**：项目接入 AI Native 工作流时运行一次，之后无需再跑。

**做什么**：
- 扫描 `requiredPaths` 和 `changeRules.safeAdd`，创建缺失的目录和模板文件
- 从 `references/bootstrap-templates/` 复制占位模板（如 `AGENTS.md`、`progress.md` 等）
- 打印 `created/patched/manual` 统计，提示需要人工完善的模板文件

**不做什么**：不写 `checklist.md` / `checklist.json`，不做任何合规判断。

```bash
# 查看会创建哪些文件（不实际写入）
node ".agent/skills/ai-native-standard-flow/scripts/bootstrap.js" --repo . --mode plan

# 执行初始化
node ".agent/skills/ai-native-standard-flow/scripts/bootstrap.js" --repo .
```

## check-compliance.js — 合规检查

**何时运行**：每次推进版本阶段、补齐工具链、或 CI 流水线中自动触发。

**做什么**：
- 检测工具链状态（git、lint、typeCheck、unitTest、CI/CD、skills、openSpec 等）
- 按 `currentStage` 做阶段门禁（未到阶段的检查项保持 `unknown`，不计入阻断）
- 写入 `docs/compliance/<productVersion>/checklist.md`（仅人类可读表格）和 `checklist.json`（唯一机器可读文件）
- 对已人工确认为 `pass` / `waived` 的项，若本次自动检查只能得到 `manual`，则保留原确认结果，不做回退覆盖
- `plan` 模式默认不写 `checklist.*`，避免污染已确认结果
- `overall_status=fail/unknown` 时 exit 1，可阻断 CI

**不做什么**：不创建目录或模板文件（那是 bootstrap 的职责）。

```bash
# 检查并写入报告
node ".agent/skills/ai-native-standard-flow/scripts/check-compliance.js" --repo .

# 仅检查；默认不写文件，只有 planWritesReports=true 时才会写文件
node ".agent/skills/ai-native-standard-flow/scripts/check-compliance.js" --repo . --mode plan
```

## lib/core.js — 共享模块

两个脚本共用的代码，不直接执行。包含：

| 分类 | 内容 |
|---|---|
| 常量 | `ITEM_DEFS`、`STAGE_ORDER`、`MACRO1_STAGES`、动作类型常量等 |
| 阶段逻辑 | `normalizeStage`、`resolveCurrentStage`、`isStageReached` |
| I/O 工具 | `readJson`、`exists`、`readUtf8`、`writeUtf8`、`ensureDir`、`detectByMarkers`、`nowIso`（东八区 `YYYY-MM-DD HH:mm:ss`） |
| 配置加载 | `loadConfig`、`deepMerge`、`normalizeConfig` |
| 状态收集 | `collectState`（检测仓库中工具链与文档的实际状态） |
| Bootstrap 引擎 | `templateRoot`、`addAction`、`planChanges`、`applyActions` |

## 配置

两个脚本共用同一套配置加载逻辑（优先级从高到低）：

1. `--config <path>` 显式指定
2. 仓库根 `ai-native-automation.config.json`（项目覆盖）
3. `references/automation-config.template.json`（默认模板）

`productVersion` 和 `currentStage` 以仓库根配置文件为**唯一权威**，关键变更须由人类确认后落盘。
