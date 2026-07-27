# 产出页布局稳定性修复设计

## 背景与问题

游戏以 1920×1080 为目标页面尺寸。当前从右侧控制台点击“产出”后，四个产地区域以单列形式直接参与 `ListRow` 的最小高度计算，反向撑高 `WorkbenchPanel` 及外层主页面，造成左右两侧页面整体向上偏移。

现有布局自检能够稳定复现：切换前 `StorefrontPanel` 与 `WorkbenchPanel` 的全局 `y` 为 64，进入产出页后变为 54，面板高度由 962 增至 982。

## 已确认方案

采用“固定外层布局、产出内容独立滚动”的方案：

1. 保持农场、林场、养殖场、水塘四个产地区域单列排列。
2. 在 `ListRow` 内为产出页增加独立的纵向滚动容器；滚动只影响产出内容，不改变 `Root`、`Body`、`MainArea`、`StorefrontPanel`、`WorkbenchPanel` 或 `ContentPanel` 的位置与尺寸。
3. 保留现有 `OutputGridRow` 作为四个产地区域的网格内容节点，由滚动容器承载。
4. 将每个 `OutputSiteRegion/OutputSiteBox/OutputSitePager` 移入 `OutputSiteHeader`，放在标题右侧，不再单独占用一行。
5. 标题使用水平扩展填充剩余空间；翻页器保持紧凑宽度，上一页、页码、下一页从左到右排列。

## 场景结构

产出页相关结构调整为：

```text
ListRow
└── OutputScroll
    └── OutputGridRow
        └── OutputSiteRegion
            └── OutputSiteBox
                ├── OutputSiteHeader
                │   ├── OutputSiteTitle
                │   └── OutputSitePager
                │       ├── OutputPrevPageButton
                │       ├── OutputPageLabel
                │       └── OutputNextPageButton
                └── OutputSiteGrid
```

`OutputScroll` 在非产出页面隐藏。进入产出页时只显示 `OutputScroll` 及其内容；页面清理流程必须恢复其隐藏状态，避免跨页面遗留布局状态。

## 行为与兼容约束

- 点击“产出”仍调用现有页面切换与刷新逻辑，不改变生产、收获、托管、翻页等业务行为。
- `OutputGridRow` 仍为 `GridContainer`，仍使用单列区域布局。
- 每个产地每页仍展示 5 个 96×96 产出格子。
- 产地区域标题、托管开关与翻页器必须在同一标题行内，不能覆盖或截断翻页按钮。
- 采购、研发制作、橱窗经营页面的布局和可见性规则保持不变。

## 验证标准

自动化验证通过真实 `OutputButton.pressed` 点击路径执行，并检查：

1. 从采购页点击“产出”后，左右面板及右侧内容区的全局位置、宽高与点击前一致，容差不超过 1 像素。
2. 从研发制作页切回“产出”后，同样不存在外层页面偏移。
3. 产出滚动容器及四个产地区域保持在 1920×1080 可视区域内，超出部分由滚动容器承载。
4. `OutputSitePager` 的父节点为 `OutputSiteHeader`，不再作为 `OutputSiteBox` 的独立行。
5. 现有产出格子、四区域、右侧控制台及 1920×1080 布局自检继续通过。

## 不在本次范围

- 不改变四个产地区域的单列顺序。
- 不缩小 96×96 产出格子。
- 不修改生产时间、产量、托管或翻页规则。
- 不调整左侧 72×72 橱窗格子及配方图标。
