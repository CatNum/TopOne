# 简历与面试素材

## 项目概览
- 项目名称：`design-changelog-maintainer`
- 业务目标：在多项目仓库中自动维护设计、变更与面试素材文档，提升工程可追溯性与复盘效率。
- 技术栈：Markdown 文档规范、Keep a Changelog、Mermaid、ADR。
- 我的角色：产品驱动下的方案设计者与实现者（规则制定、结构设计、模板落地、质量约束）。

## 关键成果（STAR）

### 成果 1：构建多项目文档治理能力
- Situation（场景）：仓库包含多个项目，文档作用域混杂，变更记录易串写。
- Task（任务）：建立可配置的多项目作用域机制，确保文档更新可定位、可审计。
- Action（行动）：定义 `DESIGN-CHANGELOG.yml` 作为 scope 唯一来源，设计匹配优先级与歧义阻断规则。
- Result（结果，尽量量化）：将“误更新错误作用域”的风险从高频人工判断降为规则化校验，形成可复用治理基线。

### 成果 2：落地三文档协同与统一目录
- Situation（场景）：仅靠 `design.md`、`changelog.md` 无法覆盖面试准备场景。
- Task（任务）：在不破坏现有工程语义的前提下扩展第三文档。
- Action（行动）：引入 `resume-interview.md`，并统一文档路径为 `<project-path>/project-docs/`，补齐模板与输出契约。
- Result（结果，尽量量化）：实现工程文档与面试素材一体化沉淀，减少面试前临时整理时间。

### 成果 3：建立自检机制提高交付一致性
- Situation（场景）：多文档更新时容易出现分类、路径、内容不同步。
- Task（任务）：在交付前增加强约束质量门禁。
- Action（行动）：定义 Self-check 清单（scope、路径、分类、Mermaid、ADR、STAR、输出完整性等）。
- Result（结果，尽量量化）：将文档交付从“写完即交”升级为“自检通过再交付”，显著降低返工沟通。

## 可量化指标
- 性能：文档更新流程标准化，减少重复解释与重复整理开销。
- 稳定性：通过 scope 唯一匹配 + 待确认机制，降低误写概率。
- 成本：通过统一模板复用，降低后续项目复制成本。
- 研发效率：把“变更记录 + 设计复盘 + 面试准备”合并为单次工作流。

## 简历可复用 Bullet
### 中文
- 设计并落地多项目文档治理方案，基于配置驱动实现作用域隔离，统一维护 `design/changelog/resume-interview` 三类文档，并通过自检清单提升交付一致性与可追溯性。
- 主导构建面向工程与面试双场景的文档体系，将技术决策（ADR）、变更日志和个人贡献沉淀打通，显著降低复盘与面试准备成本。

### English
- Designed and implemented a configuration-driven documentation governance workflow for multi-project repositories, standardizing `design/changelog/resume-interview` artifacts with scope isolation and self-check gates.
- Built an interview-ready documentation pipeline that unifies ADRs, change logs, and personal impact narratives, improving traceability and reducing preparation overhead.

## 面试深挖问答提纲
- Q1：为什么要做三文档而不是继续两文档？
  - A：两文档覆盖工程追踪，但不覆盖个人贡献表达；三文档把“工程事实”和“面试叙事”分层，互相引用且不混淆。
- Q2：如何避免多项目仓库中误更新错误目录？
  - A：通过 `DESIGN-CHANGELOG.yml` 作为唯一来源，使用 name/alias 匹配优先级，歧义时强制中断并要求确认。
- Q3：如何保证文档质量不是主观随意？
  - A：引入 Self-check 清单做交付门禁，覆盖路径、分类、ADR、Mermaid、STAR 与输出完整性。
