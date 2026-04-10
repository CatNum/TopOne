# Changelog

All notable changes to this skill are documented in this file.

## [Unreleased]

### Changed
- 背景：合规检查在不同项目间口径不一致，且模板语言与治理字段不足，导致结果不可比、不可追溯。
- 动作：在 `SKILL.md` 合并“工具清单+判断依据”，按“必须/建议”分级并新增统一落库规则；在 `references/compliance-status.template.md` 完成中文化，并补充 `exception_reason/owner/next_action/updated_at` 与阻断项 `waived` 机制。
- 结果：检查标准统一为 skill 规则层，项目实例只填结果与证据；跨项目输出格式一致、可审计且中英文认知成本降低。
- 影响：执行检查时需补齐负责人、下一步与更新时间，文档维护成本上升但治理质量显著提升。
- 时间：2026-04-10


- 背景：`ai-native-standard-flow` 作为标准流程 skill，需要更强约束与可追溯性。
- 动作：补充强制核心仓库结构、CI 门禁分层、风险与边界、标准工作流，并统一 references 路径。
- 结果：流程执行条件更明确，主流程与参考资料关系更稳定。
- 影响：流程文档维护成本略增，但可核对性和一致性提升。
- 时间：2026-04-10

### Added
- 背景：`ai-interaction-evolution-tracker` 需要明确服务对象并沉淀优化证据。
- 动作：将其规则绑定到 `ai-native-standard-flow`，新增缺陷检查维度和变更沉淀要求。
- 结果：流程优化由“口头说明”升级为“可落库、可复盘”。
- 影响：每次流程优化都需要同步更新本文件。
- 时间：2026-04-10

## [0.1.0] - 2026-04-10

### Added
- 背景：首次建立 AI 标准化流程 skill。
- 动作：新增 `SKILL.md`、`references/ai-native-tools-and-config.md`、`references/ai-native-one-page.md`。
- 结果：形成可执行的 AI Native 标准流程规范。
- 影响：为后续迭代提供统一流程基线。
- 时间：2026-04-10
