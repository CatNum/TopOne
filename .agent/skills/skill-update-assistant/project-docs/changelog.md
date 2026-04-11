# Changelog

本项目文档的所有重要变更都记录在此文件中。

格式遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)。
每条版本记录建议包含并可核对以下字段（**顺序**）：`**时间** / 背景 / 动作 / 结果 / 影响`。其中 **时间** 须为 **东八区（UTC+8）**、**精确到秒**，格式 **`YYYY-MM-DD HH:mm:ss`**（例：`2020-06-01 10:10:46`）。
每条记录之间保留两个空行，避免渲染时段落粘连。

## [Unreleased]

### Added
- 待补充。

### Changed

- **时间** `2026-04-11 18:24:55`（东八区 UTC+8，秒级） **背景** 版本记录须将时间列置于首位，并固定东八区、秒级时间格式。**动作** 已更新 `references/detailed-principles.md`、`SKILL.md`、本文件说明段。**结果** 字段顺序为「时间 / 背景 / 动作 / 结果 / 影响」；时间格式 `YYYY-MM-DD HH:mm:ss`（例：`2020-06-01 10:10:46`）。**影响** 以 `detailed-principles.md` 为审核对照时可据此验收 changelog 条目。


## [1.0.0] - 2026-03-23

### Added
- 建立 `project-docs/` 统一目录，并新增三文档治理结构：
  - `project-docs/design.md`
  - `project-docs/changelog.md`
  - `project-docs/resume-interview.md`
- 明确 skill 更新后需同步更新三文档，确保设计与变更可追溯。

### Changed
- 将目录根 `changelog.md` 的历史说明迁移到 `project-docs/changelog.md` 管理。
- 明确 `changelog.md` 使用版本号与日期记录发布历史。

