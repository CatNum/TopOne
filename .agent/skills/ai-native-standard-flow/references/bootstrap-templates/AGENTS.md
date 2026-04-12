# AGENTS.md

> 本文件是 AI 代理的统一上下文入口。请在项目初始化后根据实际情况完善各节内容。
> 随项目成长持续更新——把你会告诉新队友的信息写在这里。

## 当前交付状态（摘要）

**权威来源**：仓库根 `ai-native-automation.config.json` 中的 `productVersion`（产品版本目录名）与 `currentStage`（统一微观阶段）。合规脚本与 `docs/compliance/<productVersion>/` 均以此为准。**对该 JSON 的关键变更须由人类确认后落盘**；AI 可协助起草或说明，不得在人类未确认时擅自写入并当作已生效。

以下为给人看的速览（**与配置文件保持一致**；推进版本或阶段时**只改该 JSON**（经人类确认），再同步更新下面两行或改为「见配置文件」即可）：

- 产品版本（`productVersion`）：
- 当前阶段（`currentStage`）：`初始化基线 | 技术栈确认 | 需求分析 | UI/原型 | 技术方案 | 开发 | 测试 | 上线准备`（择一）

## 项目概览

<!-- TODO: 用 1-3 句话描述本项目是什么、解决什么问题 -->

- 项目名称：
- 技术栈：
- 仓库结构：monolith / monorepo / microservice（删除不适用项）

## 常用命令

<!-- TODO: 补充实际命令 -->

```bash
# 安装依赖
# npm install / pnpm install / yarn

# 启动开发服务器
# npm run dev

# 运行测试
# npm test

# Lint 检查
# npm run lint

# 类型检查
# npm run type-check

# 构建
# npm run build

# AI Native 项目初始化（仅运行一次，创建目录与模板文件）
node ".agent/skills/ai-native-standard-flow/scripts/bootstrap.js" --repo .

# AI Native 合规检查（迭代中反复运行，写入 checklist.*）
node ".agent/skills/ai-native-standard-flow/scripts/check-compliance.js" --repo .
```

## 代码规范

<!-- TODO: 补充项目实际规范，或引用 standards/ 目录 -->

- 详见 `standards/coding-standards.md`
- 详见 `standards/project-structure-standards.md`

## 文档结构

- `docs/requirements/` — 需求文档 / PRD（增量，按版本区块维护；页面结构、交互流程、业务规则写这里）
- `docs/design/` — 技术方案（按版本目录化；只写架构、接口、数据流、技术权衡）
- `docs/prototype/` — 高保真原型（按版本目录化；只放 Figma、截图、录屏等可视化证据）
- `docs/product-snapshot/` — 当前产品全量快照
- `docs/decisions/` — 关键决策（ADR，append-only）
- `docs/compliance/` — 合规清单 `checklist.*`（脚本）与 `progress.md`（版本进度，人主导；按产品版本子目录）
- `openspec/` — 任务分解与变更推进规范库

## 评审与提交规范

<!-- TODO: 补充 PR/commit 规范，或引用 standards/review-checklist.md -->

- 详见 `standards/review-checklist.md`
- 高风险模块（支付/权限/数据一致性）变更必须人工拍板

## 可用技能

<available_skills>
<!-- TODO: 运行 npx openskills sync 后此处会自动填充，或手动列出 .agent/skills/ 下的技能 -->
- ai-native-standard-flow: AI Native 标准协作流程（需求→交付全链路）
</available_skills>
