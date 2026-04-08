# 简历与面试素材

## 项目概览
- 项目名称：`skill-update-assistant`
- 业务目标：将 skill 变更从“直接改”升级为“先审核、再优化、后落地”。
- 技术栈：Markdown、Mermaid、规则审计流程、OpenSkills 生态。
- 我的角色：流程设计与规范落地推动者。

## 关键成果（STAR）
### 成果 1：建立 skill 变更审核门禁
- Situation（场景）：skill 变更常出现规则漂移、边界模糊。
- Task（任务）：沉淀统一审核标准并前置到改动前。
- Action（行动）：固化 §A/§B 审核逻辑，要求结论与依据可核对。
- Result（结果，尽量量化）：显著降低“改了但不可验证”的返工风险。

### 成果 2：建立文档化收尾机制
- Situation（场景）：变更后缺少一致化文档沉淀，历史难追踪。
- Task（任务）：把收尾动作标准化并纳入流程。
- Action（行动）：加入 `openskills sync` 与 `project-docs` 三文档更新要求。
- Result（结果，尽量量化）：变更可追溯性提升，协作沟通成本降低。

## 可量化指标
- 稳定性：审核前置后，低质量变更进入主分支概率下降。
- 效率：复盘与审阅所需检索成本下降（集中在 `project-docs/`）。

## 简历可复用 Bullet
### 中文
- 设计并落地 skill 变更审核与收尾流程，建立“审核依据可核对 + 文档统一沉淀”的治理机制。

### English
- Designed and operationalized a skill-change governance workflow with auditable review criteria and unified documentation artifacts.

## 面试深挖问答提纲
- Q1：为什么不直接修改 skill，而要先审核？
  - A：先审核能约束变更质量，减少后续返工和规则漂移。
- Q2：如何保证改动可追溯？
  - A：统一落在 `project-docs` 三文档，并要求 changelog 版本化。
