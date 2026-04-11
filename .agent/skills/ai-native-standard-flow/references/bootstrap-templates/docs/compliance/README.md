# 合规检查清单（按版本）

每个**产品发布版本**在 `docs/compliance/<版本>/` 下维护：

- `checklist.md`：人类可读（项目配置阶段 + 本版本交付两节；由 `check-compliance.js` 生成）
- `checklist.json`：机器可读（与 `checklist.md` 同步；由脚本生成）
- `progress.md`：**版本级任务与进度**（人与 AI 维护；脚本不覆盖）

`<版本>` 须与 `ai-native-automation.config.json` 的 `productVersion` 及 `docs/design/`、`docs/prototype/` 等版本目录一致。新开版本时复制本目录结构（含 `progress.md` 模板）并更新配置中的 `productVersion`。
