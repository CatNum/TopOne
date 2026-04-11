# Changelog

All notable changes to this skill are documented in this file.

## [Unreleased]

### Added
- 背景：`check-compliance.js` 同时承担项目初始化（scaffold）和合规检查两个职责，导致 CI 语义模糊、阅读困难。
- 动作：拆分为 `bootstrap.js`（初始化，只跑一次，始终 exit 0）+ `check-compliance.js`（合规检查，迭代中反复跑，fail/unknown 时 exit 1）；提取共享代码到 `scripts/lib/core.js`；更新 `SKILL.md` 执行方式说明与 `bootstrap-templates/AGENTS.md` 常用命令。
- 时间：2026-04-11

- 背景：版本级任务与进度需与合规目录同仓、且不与脚本生成物混写。
- 动作：新增 `docs/compliance/<版本>/progress.md` bootstrap 模板；`safeAdd` 纳入；README / `SKILL.md` / `compliance-status.template.md` 说明分工（脚本只写 `checklist.*`）；`compliance-status.template.md` 补充 `progress.md` 初始化模板路径与「人主导、AI 协助」维护说明；对齐 `SKILL.md` / `bootstrap-templates/AGENTS.md` / `ai-native-tools-and-config.md` / 检查项模板脚注；**`currentStage` / `productVersion` 权威在根目录配置**，`checklist.*` 为脚本回写镜像。
- 时间：2026-04-11

### Changed
- 背景：`productVersion` / `currentStage` 需在 Agent 入口可见且与自动化一致。
- 动作：`references/bootstrap-templates/AGENTS.md` 增加「当前交付状态」节，明确以 `ai-native-automation.config.json` 为权威。
- 时间：2026-04-11

- 背景：Git 与评审混在一行；开发/测试报告路径未在 skill 固化；版本节缺少需求/技术方案检查行。
- 动作：检查项拆为 `git` + `versionReview`（代码评审）；`SKILL.md` 约定开发/测试报告默认路径；新增 `requirementsDoc` / `designDoc` 与 `defaultCheckStage`；模板与 `compliance-status` 示例同步。
- 时间：2026-04-11

- 背景：约定交付物与检查项若分表或「再抄成行」会语义重复；检查项文字又与「微观阶段」等列叠床架屋。
- 动作：**单表、单行单义**——删除脚本中合成交付物重复行；`ITEM_DEFS` 与「阶段书面产出」行写清口径且不重复列信息；模板与 `compliance-status` 示例表同步收敛；`buildVersionGateItems` 类目为「阶段书面产出」。
- 时间：2026-04-11

- 背景：合规清单需按宏观两阶段拆分呈现，且应随产品版本落库而非固定仓库根。
- 动作：新增 `references/checklist-project-config.template.md` 与 `references/checklist-version-delivery.template.md`；`compliance-status.template.md` 改为合并说明与示例；默认输出改为 `docs/compliance/<productVersion>/checklist.{md,json}`；脚本渲染两节检查表、补充开发/测试/上线准备阶段书面产出行；bootstrap 增加 `docs/compliance/`；配置增加 `productVersion`。
- 时间：2026-04-11

- 背景：skill 文档与模板中迁移/别名说明过多，阅读噪音大。
- 动作：`SKILL.md`、合规模板、one-page 仅保留最终微观阶段枚举与字段语义；脚本注释收敛，别名对象改名为 `STAGE_ALIASES`（行为不变）。
- 时间：2026-04-11

- 背景：独立「需求评审」「方案评审」与「需求分析」「技术方案」重复；开发/测试阶段缺少可核对交付物。
- 动作：微观阶段收敛为 8 步（去掉 `需求评审`、`方案评审`，合并语义）；`开发`/`测试` 约定以**开发报告**/**测试报告**为阶段通过条件（路径项目自定）；脚本对旧枚举名做别名归并；模板增加「各微观阶段约定交付物」表。
- 结果：阶段更少、门禁与交付物更可执行。
- 影响：若配置或历史报告仍写 `需求评审`/`方案评审`，会自动映射为 `需求分析`/`技术方案`。
- 时间：2026-04-11

- 背景：合规需同时表达「治理五段」与「版本交付微观链」，多字段（`project_phase` / `macro_lifecycle` / `delivery_step`）对机器与表格不友好。
- 动作：合并为统一微观阶段枚举（`current_stage` / `check_stage`）；`ai-native-automation.config.json` 使用 `currentStage` 与 `toolChecks.*.checkStage`；脚本保留对旧 `projectPhase` / `checkPhase` 的映射与读取；`ai-native-compliance.json` schema 升至 1.2；人类速览中保留宏观说明但不写入机器字段。
- 结果：表格与 AI 消费字段仅含微观阶段；宏观「项目配置 / 版本交付循环」仅供人类阅读。
- 影响：依赖 `check_phase` / `project_phase` 的自动化需改为 `check_stage` / `current_stage`。
- 时间：2026-04-11

- 背景：阶段模型原先过粗（初始化/技术栈确认后/迭代/上线准备），难以承载“每版本规划”与“实施验证”的门禁分层。
- 动作：统一升级为五阶段模型：初始化阶段、技术栈确认阶段、版本规划阶段、实施与验证阶段、上线准备阶段；同步模板、配置、脚本与文档枚举。
- 结果：阶段定义与检查规则更细粒度，能够支持 MVP/生产级不同节奏下的治理分支。
- 影响：项目覆盖配置若使用旧阶段枚举需迁移到新枚举。
- 时间：2026-04-10

- 背景：合规模板已引入项目阶段与检查阶段字段，但脚本与文档未完全对齐，导致阶段化规则无法真实生效。
- 动作：在脚本中引入 `projectPhase/checkPhase` 判定，报告同步输出阶段列与阶段字段；在 `SKILL.md` 与 one-page 明确“未到阶段不阻断”的规则。
- 结果：阶段化门禁从“模板约定”升级为“自动化可执行规则”。
- 影响：初始化阶段不再因技术栈未确认的 Lint/TypeCheck/UnitTest 被误阻断。
- 时间：2026-04-10

- 背景：前端项目在 AI Coding 场景下需要原型与 UI 资料作为稳定输入，但自动化检查未覆盖该维度。
- 动作：将 `docs/prototype/`、`docs/ui/` 纳入强制目录基线与脚本检查，并扩展默认配置与引导模板。
- 结果：合规检查可直接反映前端原型/UI 资料是否齐备。
- 影响：前端项目初始化时需补齐原型和 UI 文档目录。
- 时间：2026-04-10

- 背景：报告存在“人类可读”和“机器可读”语义分层，但缺少统一元信息，且 `manual` 状态可能被误解。
- 动作：增强 md/json 报告格式（状态语义说明、计划变更统计、机器可读文件指针），并将 required 出现 `manual` 时总体状态设为 `unknown`。
- 结果：状态表达更一致，自动化消费更稳定。
- 影响：部分历史“通过”结果会因为 `manual` 变为 `unknown`，需人工确认后闭环。
- 时间：2026-04-10

- 背景：`plan/apply-safe` 执行策略需要更细粒度控制，以适配不同团队流程。
- 动作：新增 `executionPolicy.planWritesReports` 开关，支持 `plan` 模式按策略选择是否落库报告。
- 结果：团队可在“仅演练计划”与“计划也沉淀报告”之间按需切换。
- 影响：配置复杂度略升，但流程灵活性提升。
- 时间：2026-04-10

- 背景：模板与状态文案中文化后，自动化输出仍缺少“人类可读中文图标状态”和“机器可读英文枚举”的明确分层约束。
- 动作：在 `SKILL.md` 与 `ai-native-one-page.md` 明确双轨状态规则，并在脚本输出的 Markdown 报告中加入状态图例与机器可读说明。
- 结果：人类阅读与自动化解析口径统一，减少状态语义误解。
- 影响：团队在看报告时按中文图标判断，在接入工具链时按英文枚举解析。
- 时间：2026-04-10

- 背景：`apply-safe` 自动补齐模板后，团队可能误把占位内容当最终文档使用。
- 动作：在工作流与脚本日志新增“模板仅供参考，需人工完善”的后置提醒，并输出本次新增模板文件清单。
- 结果：自动化与人工完善职责边界更清晰。
- 影响：执行后需要额外完成人工完善步骤，流程更稳健。
- 时间：2026-04-10

- 背景：仅有合规检查输出不足以支撑“自动化接入”，缺少执行策略、变更计划与安全落地机制。
- 动作：将脚本升级为 `collect -> plan -> apply -> report` 四阶段执行器，新增 `--mode plan|apply-safe`、`--dry-run`、`--apply`，并默认采用安全落地策略。
- 结果：可先生成变更计划，再执行安全接入，复检后统一落库。
- 影响：脚本能力增强后，项目接入可自动补齐基础配置，但危险覆盖仍受限。
- 时间：2026-04-10

- 背景：当前 skill 具备流程与清单，但缺少“可配置、可执行、可回写”的自动化闭环，导致跨项目落地成本高。
- 动作：在 `SKILL.md` 新增“自动化自定义设置”章节，定义配置覆盖机制、执行入口、状态语义与阻断规则。
- 结果：从“人工阅读规范”升级为“配置驱动 + 脚本执行 + 自动落库”的可执行流程。
- 影响：团队需新增并维护项目级 `ai-native-automation.config.json`（可选），并将脚本接入日常检查流程。
- 时间：2026-04-10

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
- 背景：需要将“可自动接入项目的通用配置”落地为可复用资产。
- 动作：新增 `references/bootstrap-templates/` 模板集（docs 与 standards 基线文件），并在脚本中接入 `safe_add` 自动补齐逻辑；新增 `ai-native-compliance.json` 机器可读报告。
- 结果：在 `apply-safe` 模式下可自动创建缺失基础文件，并同时生成 `md + json` 双报告。
- 影响：manual 项（如 MCP、AI 编码助手）继续保留人工确认点，避免误判。
- 时间：2026-04-10

- 背景：需要为“通用必需项 + 项目差异项”提供统一配置承载，避免规则散落在文档。
- 动作：新增 `references/automation-config.template.json` 作为自动化默认配置模板；新增 `scripts/check-compliance.js` 作为最小可运行检查脚本。
- 结果：可在仓库根目录自动生成/更新 `ai-native-compliance.md`，并以退出码表达阻断结果。
- 影响：脚本对“manual”项保留人工确认，自动化边界更清晰。
- 时间：2026-04-10

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
