# 合规检查清单（按版本）

每个**产品发布版本**在 `docs/compliance/<版本>/` 下维护一份合并清单：

- `checklist.md`：人类可读（项目配置阶段 + 本版本交付两节；检查表各行即验收口径，不另表维护约定交付物）
- `checklist.json`：机器可读（与 `checklist.md` 同步）

`<版本>` 须与 `ai-native-automation.config.json` 的 `productVersion` 及 `docs/design/`、`docs/prototype/` 等版本目录一致。新开版本时复制本目录结构并更新配置中的 `productVersion`。
