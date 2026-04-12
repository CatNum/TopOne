# Decisions

记录关键决策、备选方案和取舍依据，保证可追溯。

## 目录职责

`docs/decisions/` 采用“根目录索引 + 版本目录承载 ADR”的结构。

规则：
- 根目录 `README.md` 只负责说明规则与维护版本索引。
- 每个产品版本在 `docs/decisions/<version>/` 下维护该版本的 ADR。
- ADR 文件名格式仍为 `ADR-NNN-简短标题.md`。
- ADR 内部仍应注明状态；适用版本可保留为补充信息。
- 已有 ADR 原则上不修改；如决策被推翻，新建 ADR 并引用原条目。

## 版本索引

| 版本 | 状态 | 说明 |
|------|------|------|
| [v1.0](./v1.0/README.md) | 当前 | `TopOne v1.0` 关键决策入口 |

## 当前活跃 OpenSpec 变更

- `confirm-technical-stack`：冻结 Apple-first 客户端栈、本地数据层、同步策略与工程基线。
- 任务清单：`openspec/changes/confirm-technical-stack/tasks.md`
