# 合规检查清单（按版本）

每个**产品发布版本**在 `docs/compliance/<版本>/` 下维护：

- `checklist.md`：人类可读（项目配置阶段 + 本版本交付两节；由 `check-compliance.js` 生成）
- `checklist.json`：机器可读（与 `checklist.md` 同步；由脚本生成）
- `progress.md`：**版本级任务与进度**（人与 AI 维护；脚本不覆盖）

`<版本>` 须与 `ai-native-automation.config.json` 的 `productVersion` 及 `docs/design/`、`docs/prototype/` 等版本目录一致。新开版本时复制本目录结构（含 `progress.md` 模板）并更新配置中的 `productVersion`。

## 目录职责对齐

- `docs/requirements/`：需求 / PRD，包含页面结构、交互流程、业务规则与验收标准
- `docs/design/<版本>/`：技术方案，包含架构、接口、数据流与技术权衡
- `docs/prototype/<版本>/`：高保真原型入口与原型资产

当前合规检查仍以结构存在性与约定路径为主，不根据正文语义判断内容是否写对目录；目录边界主要通过 skill 与模板在初始化时预防。
