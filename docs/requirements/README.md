# Requirements

记录需求背景、目标、范围、约束、业务规则与验收标准。

## 文档策略

`docs/requirements/` 维护当前版本的需求 / PRD。

规则：
- 当前版本需求统一维护在本目录。
- `README.md` 作为索引入口。
- 具体内容可按主题拆分为多个文件。
- 页面结构、交互流程、按钮跳转、业务规则统一维护在本目录中。
- 技术方案不写在本目录，统一维护在 `docs/design/<version>/`。

## 当前版本

- 版本：`v1.0`
- 状态：进行中

## 文档索引

建议按以下顺序阅读：

| 顺序 | 文档 | 内容 |
|------|------|------|
| 1 | [Product Positioning](./product-positioning.md) | 产品定位、宗旨、平台范围、非目标 |
| 2 | [Core Models](./core-models.md) | 核心对象、等级体系、奖励池定义 |
| 3 | [Business Rules](./business-rules.md) | 目标管理、任务约束、切换规则、完成与奖励规则 |
| 4 | [Interaction Flows](./interaction-flows.md) | 页面结构、关键流程、跨端交互规则 |

## 与其他文档的关系

- 技术方案：`docs/design/`
- 高保真原型：`docs/prototype/`
- UI 规范：`docs/ui/`
- 决策记录：`docs/decisions/`（按版本目录维护）
