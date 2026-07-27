# panel_v1 全局大面板背景替换设计

## 目标

将 `res://resources/ui/skin_v1/panel_v1.png` 的浅金色花纹边框用于 `project-rest-new` 的大面积页面、抽屉与弹窗背景。保留既有控件状态、文字、布局和交互行为。

## 范围

纳入替换：

- 主题中的主面板、工作台、展示板、模态面板和通知对话框。
- 已在场景中覆写、且实际绘制页面、抽屉或弹窗背景的 `PanelContainer` / `PopupPanel`。
- 商店与图鉴页面各自的全尺寸背景。

明确不替换：

- 卡槽、指标小卡、标签、输入框、按钮、进度条、选项卡及其他有状态控件。
- 纯结构用途或刻意透明的容器；它们不应凭借本次替换新增可见底图。

## 实现设计

`panel_v1.png` 是 2720x1536，而当前主题的九宫格纹理为 220--320 像素宽。直接将原图用作 `StyleBoxTexture` 会使固定边角大于若干现有弹窗，因此保留原图不改动，并生成与当前主题像素密度匹配的运行时缩小副本。

运行时副本为 320x181，保持原始宽高比，并通过 `StyleBoxTexture` 使用 52px 九宫格切片：固定外框与四角花纹，拉伸中央留白。新样式沿用当前样式的 content margin，避免改变控件内容位置；仅更新纹理及其对应切片边距。

主题资源成为主入口：`DessertMainPanel`、`DessertWorkbenchPanel`、`DessertShowcaseBoard`、`DessertModalPanel` 和 `DessertNoticeDialog` 共用该背景样式。全页 `PageBackground`、设备成长抽屉、图鉴详情弹窗与研发进度弹窗同步改为同一运行时副本；其原有尺寸、锚点、层级和脚本绑定不变。

商店的 `PurchasePopupBackground` 和图鉴的 `CatalogPopupBackground` 从整图拉伸的 `TextureRect` 改为 `NinePatchRect`，直接复用同一运行时纹理与 52px 切片边距。两个节点保持原节点名、全尺寸锚点、层级、鼠标穿透及互斥显示逻辑；脚本中的节点类型同步收窄为 `NinePatchRect`。原商店插画和图鉴书页纹理不再绑定到这两个页面背景，但源文件不在本次任务中删除。

## 验证

- 静态审计主题和场景，确认纳入范围的背景都引用新皮肤，排除项没有被改写。
- 更新商店与图鉴背景自检，确认二者使用 `NinePatchRect`、`panel_v1`、52px 切片，并继续按页面模式互斥显示。
- 以 Godot headless 方式加载项目和相关 UI 自检，并写入可写的 `--log-file`。
- 执行 `git diff --check`，同时核查不相关的现有工作区改动未被触碰。
