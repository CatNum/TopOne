# UI

> 模板提示：本文仅供参考，请结合项目实际进行人工完善与确认。

## 目录结构

```
docs/ui/
├── README.md          # 本文：组件清单 + 页面规格入口
├── tokens/
│   └── design-tokens.json   # 设计令牌（颜色/字体/间距），机器可读
└── specs/
    └── *.png / *.pdf        # 从 Figma 导出的组件规格图
```

## 设计令牌

> 设计令牌是 UI 规范的机器可读形式，前端代码直接消费。
> 源文件：[`tokens/design-tokens.json`](./tokens/design-tokens.json)

如需修改设计令牌（颜色、字体、间距等），修改 `design-tokens.json`，不要只改 README 表格。

## 组件清单

| 组件名 | 状态 | 规格导出 | Figma 链接 | 备注 |
|--------|------|---------|-----------|------|
| （示例）Button | 已定稿 | [`specs/button.png`](./specs/) | | 含 primary/secondary/disabled 三态 |

## 页面规格入口

> 各页面完整视觉规格，建议从 Figma 导出 PNG 存入 `specs/`，并在此登记。

| 页面/模块 | 规格文件 | Figma 链接 | 负责设计师 |
|---------|---------|-----------|----------|
| | | | |
