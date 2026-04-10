# AI Native 合规状态

> 目的：记录当前项目是否采用 AI Native 标准必需项。
> 范围：项目实例文件应放在仓库根目录：`ai-native-compliance.md`。

## 人类速览

- 总体状态：`✅ 通过 | ❌ 不通过`
- 采用状态图例：`✅ 通过 | ❌ 不通过 | 🟡 人工确认 | 🟣 豁免 | ⚪ 未知`
- 检查人：
- 备注：

## 检查项

| 检查项 | 采用状态 | 未使用原因（豁免说明） | 证据 | 负责人 | 下一步动作 | 更新时间 |
|---|---|---|---|---|---|---|
| **AI 原生协作工具（必须）** |  |  |  |  |  |  |
| skill（.agent/skills/） | ⚪ 未知 |  |  |  |  |  |
| MCP | ⚪ 未知 |  |  |  |  |  |
| OpenSpec | ⚪ 未知 |  |  |  |  |  |
| OpenSkills | ⚪ 未知 |  |  |  |  |  |
| AGENTS.md | ⚪ 未知 |  |  |  |  |  |
| **工程基础工具（必须）** |  |  |  |  |  |  |
| AI 编码助手 | 🟡 人工确认 |  |  |  |  |  |
| 版本与评审 | ⚪ 未知 |  |  |  |  |  |
| 质量工程 / Lint | ⚪ 未知 |  |  |  |  |  |
| 质量工程 / Type Check | ⚪ 未知 |  |  |  |  |  |
| 质量工程 / Unit Test | ⚪ 未知 |  |  |  |  |  |
| CI/CD | ⚪ 未知 |  |  |  |  |  |
| **前端交付资料（建议）** |  |  |  |  |  |  |
| 原型资料（docs/prototype/） | ⚪ 未知 |  |  |  |  |  |
| UI 规范资料（docs/ui/） | ⚪ 未知 |  |  |  |  |  |
| **工程基础工具（建议）** |  |  |  |  |  |  |
| 任务管理 | 🟡 人工确认 |  |  |  |  |  |
| 可观测性 | ⚪ 未知 |  |  |  |  |  |

## 机器可读

```yaml
schema_version: "1.0"
project_file: "ai-native-compliance.md"
overall_status: "unknown" # pass | fail | unknown
items:
  - item: "skill（.agent/skills/）"
    category: "AI 原生协作工具"
    required_level: "required" # required | recommended
    adoption_status: "unknown" # pass | waived | manual | fail | unknown
    exception_reason: "" # 当 adoption_status=waived 时必填
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "MCP"
    category: "AI 原生协作工具"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "OpenSpec"
    category: "AI 原生协作工具"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "OpenSkills"
    category: "AI 原生协作工具"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "AGENTS.md"
    category: "AI 原生协作工具"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "AI 编码助手"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "manual"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "版本与评审"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "质量工程 / Lint"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "质量工程 / Type Check"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "质量工程 / Unit Test"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "CI/CD"
    category: "工程基础工具"
    required_level: "required"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "原型资料（docs/prototype/）"
    category: "前端交付资料"
    required_level: "recommended"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "UI 规范资料（docs/ui/）"
    category: "前端交付资料"
    required_level: "recommended"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "任务管理"
    category: "工程基础工具"
    required_level: "recommended"
    adoption_status: "manual"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
  - item: "可观测性"
    category: "工程基础工具"
    required_level: "recommended"
    adoption_status: "unknown"
    exception_reason: ""
    evidence: []
    owner: ""
    next_action: ""
    updated_at: ""
```
