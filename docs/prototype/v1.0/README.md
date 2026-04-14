# TopOne v1.0 原型入口

## 1. 当前状态

- 当前版本已落库一批来自 `stitch_topone/` 的高保真页面稿。
- 当前仓库以页面截图 `png` + 对应源稿 `html` 配对存档，便于查看页面外观和理解结构。
- 页面结构、交互流程、按钮文案与业务规则以 `docs/requirements/` 与 `docs/ui/README.md` 为准。

## 2. 资产约定

当前资产目录：
- `screens/`：页面级高保真截图与对应 `html` 源稿
- `flows/`：关键交互流程图或录屏占位

当前版本建议：
- 设计源内容继续保留在 Stitch / Figma 等设计工具中
- 仓库内落截图、配套 `html` 与索引说明
- 每张页面稿优先保持 `png + html` 成对存在，便于理解与复用

## 3. 已落库页面清单

| # | 页面名称 | 截图 | 源稿 | 状态 |
|---|---------|------|------|------|
| 01 | 任务列表页（含无任务态承载） | `screens/ios-task-page.png` | `screens/ios-task-page.html` | `已落库` |
| 02 | 创建长期任务输入页 | `screens/ios-goal-create.png` | `screens/ios-goal-create.html` | `已落库` |
| 03 | 完成第二页 / 成就页 | `screens/ios-completion-celebration.png` | `screens/ios-completion-celebration.html` | `已落库` |
| 04 | 任务页左滑操作态 | `screens/ios-task-page-swipe-actions.png` | `screens/ios-task-page-swipe-actions.html` | `已落库` |
| 05 | 强制更换页 | `screens/ios-force-switch.png` | `screens/ios-force-switch.html` | `已落库` |
| 06 | 任务列表页中的专注选择 / 锁定交互参考 | `screens/ios-goal-commitment-lock.png` | `screens/ios-goal-commitment-lock.html` | `已落库` |
| 07 | 奖励池列表页（含新增奖励交互） | `screens/ios-reward-list.png` | `screens/ios-reward-list.html` | `已落库` |
| 08 | 设置页 | `screens/ios-settings.png` | `screens/ios-settings.html` | `已落库` |

## 4. 当前已补齐的补充页面

| # | 页面名称 | 截图 | 源稿 | 状态 |
|---|---------|------|------|------|
| 09 | 奖励池星辰占位页 | `screens/ios-reward-star-mode-placeholder.png` | `screens/ios-reward-star-mode-placeholder.html` | `已落库` |

说明：
- 不再单独要求“无目标空状态首页”，它归入正常的无任务任务列表页。
- 不再单独要求“创建后的承诺页”，当前流程是在任务列表页中选择专注目标。
- 不再单独要求“日常任务详情页”，详情与编辑页视为同一页。
- 不再单独要求“新增奖励页”，新增奖励交互并入奖励池列表页，并由页面右下角的圆形添加按钮触发。
- 不再要求“完成第一页 / 回顾页”。
- `iPadOS` 当前只做尺寸适配，不单独提供额外原型页。

## 5. 关键交互流程

当前 `flows/README.md` 已补入文字版交互流程说明，用于描述现有原型之间的跳转关系与关键操作逻辑；`flows/` 目录下暂时还没有流程图或录屏资产。

当前已经在 `flows/README.md` 中明确记录的关键流程包括：

| # | 流程名称 | 文字说明 | 图像资产 |
|---|---------|---------|---------|
| 01 | 创建长期任务 → 返回任务列表 → 选择专注目标 | `flows/README.md` | `待补齐` |
| 02 | 任务列表页日常使用流程 | `flows/README.md` | `待补齐` |
| 03 | 任务页左滑编辑 / 更新 / 删除 | `flows/README.md` | `待补齐` |
| 04 | 提前更换专注目标 → 强制更换页 | `flows/README.md` | `待补齐` |
| 05 | 奖励池列表页 / 星辰占位模式 / 新增奖励交互 | `flows/README.md` | `待补齐` |
| 06 | 完成长期目标 → 成就页 | `flows/README.md` | `待补齐` |
| 07 | 设置页导航与占位流程 | `flows/README.md` | `待补齐` |

说明：
- 当前版本的交互逻辑已优先通过文字说明固化。
- 如后续需要评审演示，再补对应的流程图、连线稿或录屏文件到 `flows/` 目录。

## 6. 命名说明

本目录已优先采用项目内既有命名规范：
- `ios-*.png`：`iOS` 页面截图
- `ios-*.html`：对应页面源稿
- 页面文件名尽量直接对应 `高保真原型说明.md` 中的页面名或交互语义

如后续从 Stitch / Figma 继续导出，请优先覆盖这些文件名，而不是新增一套平行命名。
