# AI Native 合规状态

> 目的：记录当前项目是否采用 AI Native 标准必需项。
> 范围：项目实例文件应放在仓库根目录：`ai-native-compliance.md`。

## 人类速览

- 总体状态：`❌ 不通过`
- 采用状态图例：`✅ 通过 | ❌ 不通过 | 🟡 人工确认 | 🟣 豁免 | ⚪ 未知`
- 检查人：
- 备注：
- 执行模式：`apply-safe`
- 变更统计：`created=4, patched=0, manual=4`
- 计划变更数：`8`
- 机器可读文件：`ai-native-compliance.json`

## 检查项

| 检查项 | 采用状态 | 未使用原因（豁免说明） | 证据 | 负责人 | 下一步动作 | 更新时间 |
|---|---|---|---|---|---|---|
| skill（.agent/skills/） | ✅ 通过 |  | .agent/skills/ |  |  | 2026-04-10T08:36:46.061Z |
| MCP | 🟡 人工确认 |  |  |  | 需要人工补充证据并确认状态 | 2026-04-10T08:36:46.061Z |
| OpenSpec | ✅ 通过 |  | openspec/ |  |  | 2026-04-10T08:36:46.061Z |
| OpenSkills | 🟡 人工确认 |  | skill directory or script signal |  | 需要人工补充证据并确认状态 | 2026-04-10T08:36:46.061Z |
| AGENTS.md | ✅ 通过 |  | AGENTS.md |  |  | 2026-04-10T08:36:46.061Z |
| AI 编码助手 | 🟡 人工确认 |  |  |  | 需要人工补充证据并确认状态 | 2026-04-10T08:36:46.061Z |
| 版本与评审 | ✅ 通过 |  | .git |  |  | 2026-04-10T08:36:46.061Z |
| 质量工程 / Lint | ❌ 不通过 |  |  |  |  | 2026-04-10T08:36:46.061Z |
| 质量工程 / Type Check | ❌ 不通过 |  |  |  |  | 2026-04-10T08:36:46.061Z |
| 质量工程 / Unit Test | ❌ 不通过 |  |  |  |  | 2026-04-10T08:36:46.061Z |
| CI/CD | ✅ 通过 |  | .github/workflows/ |  |  | 2026-04-10T08:36:46.061Z |
| 原型资料（docs/prototype/） | ✅ 通过 |  | docs/prototype/ |  |  | 2026-04-10T08:36:46.061Z |
| UI 规范资料（docs/ui/） | ✅ 通过 |  | docs/ui/ |  |  | 2026-04-10T08:36:46.061Z |
| 任务管理 | 🟡 人工确认 |  |  |  | 需要人工补充证据并确认状态 | 2026-04-10T08:36:46.061Z |
| 可观测性 | 🟡 人工确认 |  |  |  | 需要人工补充证据并确认状态 | 2026-04-10T08:36:46.061Z |
| 路径存在: docs/requirements/ | ✅ 通过 |  | docs/requirements/ |  |  | 2026-04-10T08:36:46.063Z |
| 路径存在: docs/design/ | ✅ 通过 |  | docs/design/ |  |  | 2026-04-10T08:36:46.063Z |
| 路径存在: docs/prototype/ | ✅ 通过 |  | docs/prototype/ |  |  | 2026-04-10T08:36:46.063Z |
| 路径存在: docs/ui/ | ✅ 通过 |  | docs/ui/ |  |  | 2026-04-10T08:36:46.063Z |
| 路径存在: docs/glossary/ | ✅ 通过 |  | docs/glossary/ |  |  | 2026-04-10T08:36:46.063Z |
| 路径存在: docs/decisions/ | ✅ 通过 |  | docs/decisions/ |  |  | 2026-04-10T08:36:46.063Z |
| 路径存在: openspec/ | ✅ 通过 |  | openspec/ |  |  | 2026-04-10T08:36:46.063Z |
| 路径存在: AGENTS.md | ✅ 通过 |  | AGENTS.md |  |  | 2026-04-10T08:36:46.063Z |
| 路径存在: .agent/skills/ | ✅ 通过 |  | .agent/skills/ |  |  | 2026-04-10T08:36:46.063Z |
| 路径存在: standards/ | ✅ 通过 |  | standards/ |  |  | 2026-04-10T08:36:46.063Z |
| 路径存在: .github/workflows/ | ✅ 通过 |  | .github/workflows/ |  |  | 2026-04-10T08:36:46.063Z |

## 机器可读

`说明：本节采用英文枚举（pass/fail/manual/waived/unknown）供自动化解析。`

```yaml
schema_version: "1.1"
project_file: "ai-native-compliance.md"
overall_status: "fail" # pass | fail | unknown
items:
  - item: "skill（.agent/skills/）"
    category: "AI 原生协作工具"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - ".agent/skills/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "MCP"
    category: "AI 原生协作工具"
    required_level: "required"
    adoption_status: "manual"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "需要人工补充证据并确认状态"
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "OpenSpec"
    category: "AI 原生协作工具"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "openspec/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "OpenSkills"
    category: "AI 原生协作工具"
    required_level: "required"
    adoption_status: "manual"
    exception_reason: ""
    evidence:
      - "skill directory or script signal"
    owner: ""
    next_action: "需要人工补充证据并确认状态"
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "AGENTS.md"
    category: "AI 原生协作工具"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "AGENTS.md"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "AI 编码助手"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "manual"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "需要人工补充证据并确认状态"
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "版本与评审"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - ".git"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "质量工程 / Lint"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "fail"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "质量工程 / Type Check"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "fail"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "质量工程 / Unit Test"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "fail"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "CI/CD"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - ".github/workflows/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "原型资料（docs/prototype/）"
    category: "前端交付资料"
    required_level: "recommended"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/prototype/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "UI 规范资料（docs/ui/）"
    category: "前端交付资料"
    required_level: "recommended"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/ui/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "任务管理"
    category: "工程基础工具"
    required_level: "recommended"
    adoption_status: "manual"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "需要人工补充证据并确认状态"
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "可观测性"
    category: "工程基础工具"
    required_level: "recommended"
    adoption_status: "manual"
    exception_reason: ""
    evidence:
      - ""
    owner: ""
    next_action: "需要人工补充证据并确认状态"
    updated_at: "2026-04-10T08:36:46.061Z"
  - item: "路径存在: docs/requirements/"
    category: "仓库结构"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/requirements/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.063Z"
  - item: "路径存在: docs/design/"
    category: "仓库结构"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/design/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.063Z"
  - item: "路径存在: docs/prototype/"
    category: "仓库结构"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/prototype/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.063Z"
  - item: "路径存在: docs/ui/"
    category: "仓库结构"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/ui/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.063Z"
  - item: "路径存在: docs/glossary/"
    category: "仓库结构"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/glossary/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.063Z"
  - item: "路径存在: docs/decisions/"
    category: "仓库结构"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "docs/decisions/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.063Z"
  - item: "路径存在: openspec/"
    category: "仓库结构"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "openspec/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.063Z"
  - item: "路径存在: AGENTS.md"
    category: "仓库结构"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "AGENTS.md"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.063Z"
  - item: "路径存在: .agent/skills/"
    category: "仓库结构"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - ".agent/skills/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.063Z"
  - item: "路径存在: standards/"
    category: "仓库结构"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - "standards/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.063Z"
  - item: "路径存在: .github/workflows/"
    category: "仓库结构"
    required_level: "required"
    adoption_status: "pass"
    exception_reason: ""
    evidence:
      - ".github/workflows/"
    owner: ""
    next_action: ""
    updated_at: "2026-04-10T08:36:46.063Z"
```
