# AI Native 合规检查清单（v1.0）

> 目的：记录本仓库及本版本的合规与交付物核对状态。  
> 范围：`docs/compliance/v1.0/checklist.md`；机器可读：`docs/compliance/v1.0/checklist.json`。

## 人类速览

- 产品版本：`v1.0`
- 总体状态：`🟡 待确认`
- 当前交付阶段（`current_stage`，与 JSON 一致）：`初始化基线`
- 宏观视角（仅人类阅读）：`项目配置阶段（对应微观：初始化基线～技术栈确认）`
- 采用状态图例：`✅ 通过 | ❌ 不通过 | 🟡 人工确认 | 🟣 豁免 | ⚪ 未知`
- 检查人：
- 备注：
- 执行模式：`apply-safe`
- 变更统计：`created=1, patched=0, manual=4`
- 计划变更数：`5`

## 一、项目配置阶段

### 检查项

**说明**：不再单列「约定交付物」表；本表每一行即该微观阶段的验收口径（目录类行与下方路径检查共同覆盖「仓库与协作骨架」等基线）。

| 检查项 | 微观阶段 | 采用状态 | 未使用原因（豁免说明） | 证据 | 负责人 | 下一步动作 | 更新时间 |
|---|---|---|---|---|---|---|---|
| skill（.agent/skills/）：团队 SOP 固化 | 初始化基线 | ✅ 通过 |  | .agent/skills/ |  |  | 2026-04-11T07:58:04.090Z |
| MCP：工具连接层 | 技术栈确认 | 🟣 豁免 | 当前项目暂未引入 MCP，阶段性豁免。 |  |  | 当前交付阶段为 初始化基线，该项在 技术栈确认 开始检查 | 2026-04-11T07:58:04.090Z |
| OpenSpec：变更与任务分解规范库 | 初始化基线 | ✅ 通过 |  | openspec/ |  |  | 2026-04-11T07:58:04.090Z |
| OpenSkills：技能生命周期与同步 | 初始化基线 | 🟡 人工确认 |  |  |  | 需要人工补充证据并确认状态 | 2026-04-11T07:58:04.090Z |
| AGENTS.md：代理入口（与 skills 目录配套） | 初始化基线 | ✅ 通过 |  | AGENTS.md |  |  | 2026-04-11T07:58:04.090Z |
| AI 编码助手 | 初始化基线 | 🟡 人工确认 |  |  |  | 需要人工补充证据并确认状态 | 2026-04-11T07:58:04.090Z |
| Git（仓库版本控制） | 初始化基线 | ✅ 通过 |  | .git |  |  | 2026-04-11T07:58:04.090Z |
| 代码评审（PR/MR） | 初始化基线 | 🟡 人工确认 |  |  |  | 需要人工补充证据并确认状态 | 2026-04-11T07:58:04.090Z |
| 质量工程 / Lint | 技术栈确认 | ⚪ 未知 |  |  |  | 当前交付阶段为 初始化基线，该项在 技术栈确认 开始检查 | 2026-04-11T07:58:04.090Z |
| 质量工程 / Type Check | 技术栈确认 | ⚪ 未知 |  |  |  | 当前交付阶段为 初始化基线，该项在 技术栈确认 开始检查 | 2026-04-11T07:58:04.090Z |
| 质量工程 / Unit Test | 技术栈确认 | ⚪ 未知 |  | unit-test markers found |  | 当前交付阶段为 初始化基线，该项在 技术栈确认 开始检查 | 2026-04-11T07:58:04.090Z |
| CI/CD | 初始化基线 | ✅ 通过 |  | .github/workflows/ |  |  | 2026-04-11T07:58:04.090Z |
| 可观测性：日志、指标与错误追踪 | 技术栈确认 | ⚪ 未知 |  |  |  | 当前交付阶段为 初始化基线，该项在 技术栈确认 开始检查 | 2026-04-11T07:58:04.090Z |
| 路径存在: docs/compliance/v1.0/ | 初始化基线 | ✅ 通过 |  | docs/compliance/v1.0/ |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: docs/product-snapshot/ | 初始化基线 | ✅ 通过 |  | docs/product-snapshot/ |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: docs/requirements/ | 初始化基线 | ✅ 通过 |  | docs/requirements/ |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: docs/design/ | 初始化基线 | ✅ 通过 |  | docs/design/ |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: docs/prototype/ | 初始化基线 | ✅ 通过 |  | docs/prototype/ |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: docs/ui/ | 初始化基线 | ✅ 通过 |  | docs/ui/ |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: docs/glossary/ | 初始化基线 | ✅ 通过 |  | docs/glossary/ |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: docs/decisions/ | 初始化基线 | ✅ 通过 |  | docs/decisions/ |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: openspec/ | 初始化基线 | ✅ 通过 |  | openspec/ |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: AGENTS.md | 初始化基线 | ✅ 通过 |  | AGENTS.md |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: .agent/skills/ | 初始化基线 | ✅ 通过 |  | .agent/skills/ |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: standards/ | 初始化基线 | ✅ 通过 |  | standards/ |  |  | 2026-04-11T07:58:04.092Z |
| 路径存在: .github/workflows/ | 初始化基线 | ✅ 通过 |  | .github/workflows/ |  |  | 2026-04-11T07:58:04.092Z |

## 二、本版本交付（产品版本：v1.0）

### 检查项

**说明**：不再单列「约定交付物」表；本表每一行即本版本在该微观阶段应满足的验收口径（含开发/测试/上线等书面产出行）。

| 检查项 | 微观阶段 | 采用状态 | 未使用原因（豁免说明） | 证据 | 负责人 | 下一步动作 | 更新时间 |
|---|---|---|---|---|---|---|---|
| 本版原型（docs/prototype/） | UI/原型 | ⚪ 未知 |  | docs/prototype/ |  | 当前交付阶段为 初始化基线，该项在 UI/原型 开始检查 | 2026-04-11T07:58:04.090Z |
| UI 规范（docs/ui/） | UI/原型 | ⚪ 未知 |  | docs/ui/ |  | 当前交付阶段为 初始化基线，该项在 UI/原型 开始检查 | 2026-04-11T07:58:04.090Z |
| 任务管理：需求到任务的外部或流程入口 | 需求分析 | ⚪ 未知 |  |  |  | 当前交付阶段为 初始化基线，该项在 需求分析 开始检查 | 2026-04-11T07:58:04.090Z |
| 需求文档（docs/requirements/） | 需求分析 | ⚪ 未知 |  | docs/requirements/ |  | 当前交付阶段为 初始化基线，该项在 需求分析 开始检查 | 2026-04-11T07:58:04.090Z |
| 技术方案文档（docs/design/v1.0/） | 技术方案 | ⚪ 未知 |  |  |  | 当前交付阶段为 初始化基线，该项在 技术方案 开始检查 | 2026-04-11T07:58:04.090Z |
| 开发报告（默认 docs/compliance/v1.0/development-report.md，见 skill） | 开发 | ⚪ 未知 |  |  |  | 当前交付阶段为 初始化基线，该项在 开发 起纳入核对 | 2026-04-11T07:58:04.092Z |
| 测试报告（默认 docs/compliance/v1.0/test-report.md，见 skill） | 测试 | ⚪ 未知 |  |  |  | 当前交付阶段为 初始化基线，该项在 测试 起纳入核对 | 2026-04-11T07:58:04.092Z |
| 上线准备清单（发布说明、回滚等） | 上线准备 | ⚪ 未知 |  |  |  | 当前交付阶段为 初始化基线，该项在 上线准备 起纳入核对 | 2026-04-11T07:58:04.092Z |

## 机器可读

`说明：本节采用英文枚举（pass/fail/manual/waived/unknown）供自动化解析。`

```yaml
schema_version: "1.2"
project_file: "docs/compliance/v1.0/checklist.md"
product_version: "v1.0"
current_stage: "初始化基线"
overall_status: "unknown" # pass | fail | unknown
items:
  - item: "skill（.agent/skills/）：团队 SOP 固化"
    category: "AI 原生协作工具"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - ".agent/skills/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "MCP：工具连接层"
    category: "AI 原生协作工具"
    check_stage: "技术栈确认"
    required_level: "required"
    adoption_status: "waived"
    exception_reason: "当前项目暂未引入 MCP，阶段性豁免。"
    evidence:
      - ""
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 技术栈确认 开始检查"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "OpenSpec：变更与任务分解规范库"
    category: "AI 原生协作工具"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "openspec/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "OpenSkills：技能生命周期与同步"
    category: "AI 原生协作工具"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "manual"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "需要人工补充证据并确认状态"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "AGENTS.md：代理入口（与 skills 目录配套）"
    category: "AI 原生协作工具"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "AGENTS.md"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "AI 编码助手"
    category: "工程基础工具"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "manual"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "需要人工补充证据并确认状态"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "Git（仓库版本控制）"
    category: "工程基础工具"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - ".git"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "代码评审（PR/MR）"
    category: "工程基础工具"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "manual"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "需要人工补充证据并确认状态"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "质量工程 / Lint"
    category: "工程基础工具"
    check_stage: "技术栈确认"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 技术栈确认 开始检查"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "质量工程 / Type Check"
    category: "工程基础工具"
    check_stage: "技术栈确认"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 技术栈确认 开始检查"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "质量工程 / Unit Test"
    category: "工程基础工具"
    check_stage: "技术栈确认"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - "unit-test markers found"
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 技术栈确认 开始检查"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "CI/CD"
    category: "工程基础工具"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - ".github/workflows/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "可观测性：日志、指标与错误追踪"
    category: "工程基础工具"
    check_stage: "技术栈确认"
    required_level: "recommended"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 技术栈确认 开始检查"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "路径存在: docs/compliance/v1.0/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/compliance/v1.0/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: docs/product-snapshot/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/product-snapshot/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: docs/requirements/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/requirements/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: docs/design/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/design/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: docs/prototype/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/prototype/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: docs/ui/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/ui/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: docs/glossary/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/glossary/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: docs/decisions/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/decisions/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: openspec/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "openspec/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: AGENTS.md"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "AGENTS.md"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: .agent/skills/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - ".agent/skills/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: standards/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "standards/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "路径存在: .github/workflows/"
    category: "仓库结构"
    check_stage: "初始化基线"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - ".github/workflows/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "本版原型（docs/prototype/）"
    category: "前端交付资料"
    check_stage: "UI/原型"
    required_level: "recommended"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - "docs/prototype/"
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 UI/原型 开始检查"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "UI 规范（docs/ui/）"
    category: "前端交付资料"
    check_stage: "UI/原型"
    required_level: "recommended"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - "docs/ui/"
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 UI/原型 开始检查"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "任务管理：需求到任务的外部或流程入口"
    category: "工程基础工具"
    check_stage: "需求分析"
    required_level: "recommended"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 需求分析 开始检查"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "需求文档（docs/requirements/）"
    category: "文档交付"
    check_stage: "需求分析"
    required_level: "recommended"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - "docs/requirements/"
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 需求分析 开始检查"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "技术方案文档（docs/design/v1.0/）"
    category: "文档交付"
    check_stage: "技术方案"
    required_level: "recommended"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 技术方案 开始检查"
    updated_at: "2026-04-11T07:58:04.090Z"
  - item: "开发报告（默认 docs/compliance/v1.0/development-report.md，见 skill）"
    category: "阶段书面产出"
    check_stage: "开发"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 开发 起纳入核对"
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "测试报告（默认 docs/compliance/v1.0/test-report.md，见 skill）"
    category: "阶段书面产出"
    check_stage: "测试"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 测试 起纳入核对"
    updated_at: "2026-04-11T07:58:04.092Z"
  - item: "上线准备清单（发布说明、回滚等）"
    category: "阶段书面产出"
    check_stage: "上线准备"
    required_level: "recommended"
    adoption_status: "unknown"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "当前交付阶段为 初始化基线，该项在 上线准备 起纳入核对"
    updated_at: "2026-04-11T07:58:04.092Z"
```
