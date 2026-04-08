# Changelog

本项目文档的所有重要变更都记录在此文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)。

## [Unreleased]

### Added
- 待补充。

### Changed
- 待补充。

## [1.0.0] - 2026-03-23

### Added
- 首次发布 `design-changelog-maintainer` 技能。
- 新增基于仓库根 `DESIGN-CHANGELOG.yml` 的多项目作用域识别规则。
- 新增基于 Keep a Changelog 分类的变更记录策略。
- 新增 `design.md` 演进式更新策略，并要求在影响流程/架构时使用 Mermaid。
- 新增关键技术决策的 ADR 记录要求与模板。
- 新增作用域歧义与禁止编造实现细节的防护约束。
- 建立 `project-docs/` 统一目录，新增三文档治理结构：
  - `project-docs/design.md`
  - `project-docs/changelog.md`
  - `project-docs/resume-interview.md`
- 新增本项目设计文档，明确模块边界、核心流程与 ADR。
- 新增面试与简历素材文档，用于沉淀 STAR、量化结果和问答提纲。

### Changed
- 重构 `SKILL.md` 以对齐 `skill-creator` 规范：
  - 增加 YAML frontmatter（`name`、`description`），提升触发与发现稳定性；
  - 增加双语元信息块（`名称（中文）`、`描述（中文）`）；
  - 正文改为中文优先，同时保留 trigger-critical 英文术语。
- 技能职责扩展为维护第三份文档 `resume-interview.md`，并约定每个项目目录各维护一份。
- 新增 `resume-interview.md` 的职责定义、建议骨架（STAR/量化指标/简历 Bullet/面试问答）与触发更新规则。
- 统一文档落盘目录约定为 `<project-path>/project-docs/`，三份文档集中管理。
- 新增“自检清单（Self-check）”机制，并将其纳入执行流程，要求输出前完成一致性校验。
- 将“当前 skill 的文档维护目标”从双文档扩展为三文档协同，覆盖工程追踪与面试复盘两个场景。
- 明确文档输出与自检的联动关系：更新后需通过一致性检查再交付。
