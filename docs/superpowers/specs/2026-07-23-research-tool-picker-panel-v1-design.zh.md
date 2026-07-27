# 研发工具选择弹窗 `panel_v1` 替换设计

## 目标

将 `project-rest-new` 研发区中点击工具槽位后出现的 `ResearchToolPickerPopup` 替换为 `panel_v1` 视觉外框，并将弹窗从当前 `420×210` 扩大为 `720×408`。扩大后的弹窗需要让标题、边框和六张工具卡具有更舒展的比例，同时保持工具选择的业务规则和交互语义不变。

## 范围

本次只调整研发工具选择弹窗的外框、尺寸与内部几何：

- 修改 `scenes/ui/pages/workbench_pages.tscn` 中 `ResearchToolPickerPopup` 及其现有内容节点的样式和布局参数。
- 修改 `scripts/main_view.gd` 中弹窗打开尺寸与工具卡尺寸常量。
- 扩展 `tests/research_input_strip_self_check.gd` 对新视觉和交互契约的断言。

以下内容不在本次范围内：

- 不修改设备解锁、排序、研发结果或研发提示规则。
- 不修改存档结构。
- 不新增确认按钮、关闭按钮、筛选或分页。
- 不重做六张工具卡的按钮皮肤、图标或名称底条。
- 不修改其他工作台弹窗或全局覆盖层。

## 资源策略

视觉源文件为 `res://resources/ui/skin_v1/panel_v1.png`。该源图为 `2720×1536`、约 `5.5 MB`，不直接绑定到运行时弹窗。实现继续遵循项目现有素材流水线，使用由源图生成的：

`res://resources/ui/skin/neighborhood_dessert/runtime/panel_v1.png`

弹窗面板使用 `StyleBoxTexture`，四边 `texture_margin` 均为 `52px`。这与项目现有 `DessertModalPanel` 和研发进度弹窗的 `panel_v1` 用法一致，可以保护装饰边框不被拉伸，同时避免为单个小弹窗加载大尺寸源纹理。

## 场景与布局

稳定结构继续保留在 `.tscn`，不在脚本中创建或重排节点。保留现有层级：

```text
ResearchToolPickerPopup
└── ToolPickerMargin
    └── ToolPickerBox
        ├── ToolPickerTitle
        └── ToolPickerGrid
```

具体几何契约如下：

- `ResearchToolPickerPopup` 固定打开尺寸为 `720×408`，保持居中弹出。
- `ResearchToolPickerPopup` 直接设置 `panel_v1` 的 `StyleBoxTexture`；不新增 `NinePatchRect` 背景节点。
- `ToolPickerMargin` 填满弹窗，内容安全区为左右 `64px`、上下 `48px`。
- `ToolPickerBox` 的标题与工具网格间距为 `16px`。
- `ToolPickerTitle` 文本保持“选择研发工具”，居中显示，字号为 `24px`。
- `ToolPickerGrid` 保持 `3` 列，水平和垂直间距均为 `16px`，整体在内容区居中。
- 每张工具卡尺寸为 `168×120`。
- 工具卡继续实例化 `research_input_slot.tscn`，沿用现有设备图标、名称底条、焦点模式、鼠标光标和按钮主题。

在只有部分设备解锁时，网格仍按现有顺序从左到右、从上到下填充，不人为补齐占位卡。空列表沿用现有行为，仅保留标题和空网格；本次不引入新的空状态文案。

## 交互与状态

打开流程保持现有职责：

1. 玩家点击研发工具槽位。
2. `_fill_research_tool_picker()` 重新读取当前已解锁设备并生成工具卡。
3. `ResearchToolPickerPopup` 以 `720×408` 居中打开。

选择流程保持不变：

1. 玩家点击一张工具卡。
2. `selected_research_tool_id` 更新为对应设备 ID。
3. 弹窗立即关闭。
4. 当前工具槽、研发提示面板、状态栏和教程目标依次刷新。

不增加二次确认步骤。打开、关闭或选择工具不会清空已选研发材料，也不会改变其他工作台弹窗状态。

## 验证

扩展 `tests/research_input_strip_self_check.gd`，至少验证：

- 点击工具槽位能打开 `ResearchToolPickerPopup`。
- 弹窗尺寸为 `720×408`。
- 弹窗面板使用来自运行时 `panel_v1` 的 `StyleBoxTexture`，四边纹理边距均为 `52px`。
- 内容安全区为左右 `64px`、上下 `48px`。
- 标题字号为 `24px`。
- 工具网格为 `3` 列，水平和垂直间距均为 `16px`。
- 六个设备全部解锁时产生六张 `168×120` 工具卡。
- 选择工具后仍会更新选择、关闭弹窗并在离开再返回研发区后保留选择。
- 已选研发材料不因弹窗打开或工具切换而丢失。

验证顺序：

1. 运行 `research_input_strip_self_check.gd`。
2. 运行与研发区几何相邻的 `layout_refinement_self_check.gd`。
3. 运行项目无界面加载检查。
4. 运行 `git diff --check` 并审核定向差异。

所有 Godot 头部命令必须显式传入位于可写目录的 `--log-file`，不得使用默认 `user://logs` 或 `NUL`。

## 完成标准

- 研发工具选择弹窗在 1920×1080 基准画面中以 `720×408` 居中显示。
- `panel_v1` 装饰边框清晰、比例正常、无拉伸失真。
- 六张工具卡在 3×2 网格中完整显示，图标和名称不裁切。
- 工具选择与研发材料状态保持现有语义。
- 相关专项检查通过，且没有修改本设计范围之外的用户工作区文件。
