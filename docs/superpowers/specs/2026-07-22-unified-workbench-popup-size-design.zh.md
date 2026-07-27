# 七个功能弹窗统一尺寸设计

## 背景

右下 `WorkbenchLauncher` 的 7 个功能入口分别打开星辉、任务、库存、图鉴、采购、产出和橱窗经营弹窗。当前运行时存在三套外框几何：图鉴使用响应式图鉴尺寸，采购使用独立的 7:4 尺寸，其余 5 个模式使用紧凑尺寸，因此切换模式时弹窗会改变宽高和位置。

当前 `DefaultModalSurface`、`PurchasePopupBackground` 和 `CatalogPopupBackground` 已经使用同一份 `panel_v1.png` 视觉资源。采购和图鉴的独立背景节点不再表达不同视觉语义，属于冗余结构。

## 目标

- 7 个功能弹窗统一使用当前图鉴弹窗的响应式外框尺寸和居中位置。
- 不同功能弹窗之间切换时，外框宽高和位置不跳变。
- 删除采购、图鉴的冗余背景节点，统一使用 `DefaultModalSurface`。
- 保留采购现有内容边距，避免采购控件贴近装饰边缘。
- 不改变弹窗内部内容、功能解锁、按钮切换和关闭语义。

## 运行时设计

将当前图鉴的宽高比、最大视口占比和 anchor 计算提升为全局弹窗唯一外框几何来源。`_apply_global_overlay_layout()` 不再根据模式选择采购、图鉴或紧凑外框尺寸，而是对 7 个功能模式统一应用同一组响应式 anchors、零 offsets 和外框最小尺寸设置。

模式仍可影响内部内容框：采购应用现有 `PURCHASE_OVERLAY_CONTENT_MARGINS`，图鉴保留现有 `CATALOG_OVERLAY_FRAME_OFFSETS`，其余模式保留现有默认 frame offsets 和零额外边距。这样只统一外框边界与位置，不改变各模式已经确认的内部排版；各模式内部容器继续依靠现有 size flags 和滚动区域适配可用空间。

## 场景清理

从 `Main.tscn` 删除：

- `GlobalOverlayLayer/PurchasePopupBackground`
- `GlobalOverlayLayer/CatalogPopupBackground`

`GlobalOverlayLayer/DefaultModalSurface` 保留并在 7 个功能模式及关闭复位状态下作为唯一背景。删除 `main_view.gd` 中两个冗余背景节点引用和按模式切换可见性的分支。

本次不改 `panel_v1.png`、主题资源或其他弹窗/抽屉的背景结构。

## 验证

聚焦测试应覆盖：

1. 在 `1920×1080` 下依次打开 7 个模式，记录并比较 `GlobalOverlayLayer` 的全局矩形，要求完全一致且居中。
2. 在 `1280×720` 下重复检查，要求响应式缩放后仍一致、居中且不超出视口。
3. 逐个切换模式，确认外框矩形不发生跳变。
4. 确认 `PurchasePopupBackground` 和 `CatalogPopupBackground` 已不存在，`DefaultModalSurface` 在每个模式下可见。
5. 确认采购模式继续应用现有内容边距，离开采购后恢复零额外边距。
6. 保留并运行“同按钮关闭、不同按钮直接切换”的真实鼠标回归。

## 非目标

- 不重新排版任一弹窗内部内容。
- 不改变采购分类区、图鉴卡片、库存网格或其他业务组件。
- 不修改功能入口的解锁条件、tooltip 或角标。
- 不处理本次验证中可能出现的无关既有基线失败。
