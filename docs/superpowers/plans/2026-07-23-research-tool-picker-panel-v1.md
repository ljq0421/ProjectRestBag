# 研发工具选择弹窗 `panel_v1` 实施计划

设计依据：`docs/superpowers/specs/2026-07-23-research-tool-picker-panel-v1-design.zh.md`

## 目标

把研发工具选择弹窗改为 `panel_v1` 外框和 `720×408` 居中布局，工具卡扩大为 `168×120` 的 3×2 网格，同时保持设备筛选、选择、关闭和状态刷新行为不变。

## 任务 1：先锁定失败的专项契约

修改 `tests/research_input_strip_self_check.gd`：

- 断言弹窗打开尺寸为 `720×408`。
- 断言弹窗面板为 `StyleBoxTexture`，纹理来自运行时 `panel_v1`，四边纹理边距为 `52px`。
- 断言内容边距、标题字号、网格列数与间距。
- 断言六张工具卡均为 `168×120`。
- 保留并加强选择后关闭、选择保留和研发材料不丢失断言。

先运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\research-tool-picker-red.log" `
  -s res://tests/research_input_strip_self_check.gd
```

确认测试因旧尺寸或旧样式失败。

## 任务 2：修改场景和尺寸常量

修改 `scenes/ui/pages/workbench_pages.tscn`：

- 引用 `resources/ui/skin/neighborhood_dessert/runtime/panel_v1.png`。
- 为 `ResearchToolPickerPopup` 增加四边 `52px` 的 `StyleBoxTexture`。
- 将弹窗尺寸设为 `720×408`。
- 将 `ToolPickerMargin` 设为铺满弹窗，内容边距左右 `64px`、上下 `48px`。
- 标题字号设为 `24px`，标题与网格间距设为 `16px`。
- 网格保持 3 列，水平和垂直间距设为 `16px`，并在内容区居中。

修改 `scripts/main_view.gd`：

- 将研发工具选择卡尺寸改为 `168×120`。
- 增加或复用一个 `Vector2i(720, 408)` 弹窗尺寸常量。
- `_on_research_tool_slot_pressed()` 使用该常量居中打开弹窗。

不修改工具选择回调、研发规则或存档结构。

## 任务 3：专项与相邻回归

依次运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\research-tool-picker-green.log" `
  -s res://tests/research_input_strip_self_check.gd

& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\research-tool-picker-layout.log" `
  -s res://tests/layout_refinement_self_check.gd

& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\research-tool-picker-load.log" `
  --quit
```

最后运行 `git diff --check`，并只审核本计划列出的场景、脚本、测试和计划文档差异。保留工作区内既有配方图片及其他无关改动。
