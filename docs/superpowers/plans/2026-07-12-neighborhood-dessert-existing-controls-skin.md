# 邻里甜品店现有控件换肤 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将已生成的邻里甜品店素材接入当前项目真实存在的输入、选择、数值、导航与状态控件，同时保留业务逻辑、稳定节点路径和未使用素材的待用状态。

**Architecture:** 保留 `resources/ui/skin/neighborhood_dessert/*.png` 作为 ImageGen 源图。`tools/build_neighborhood_dessert_skin.py` 为本轮实际控件所需的素材族生成统一裁边、尺寸与 alpha 边界的 `runtime/*.png`，`neighborhood_dessert_theme.tres` 将它们装配为语义 Theme 变体；场景与动态创建路径只赋予 `theme_type_variation`。

**Tech Stack:** Godot 4.6 Theme / `StyleBoxTexture` / GDScript、Python Pillow、PowerShell。

## Global Constraints

- 仅接入已有 UI 控件；不创建侧边 Tab、单选框、滑杆、标题牌、悬挂牌、焦点框、选中框、锁定遮罩或独立阴影节点。
- 不修改业务规则、存档结构、信号名称、稳定节点路径或现有文本。
- 同状态族的运行时 PNG 必须是 RGBA、输出尺寸一致、alpha 边界一致。
- 九宫格边距只能落在直边区；圆角、端点、输入框右侧分隔段和高光边缘不得被拉伸。
- Godot headless 命令必须携带 `--log-file "$env:TEMP\\godot-headless.log"`。
- 工作区已有用户改动；只编辑本计划列出的文件，不提交任何文件，除非用户另行明确授权。

---

### Task 1: 将 Theme 自检扩展为“剩余现有控件”契约

**Files:**
- Modify: `tests/neighborhood_dessert_theme_self_check.gd`
- Test: `tests/neighborhood_dessert_theme_self_check.gd`

**Consumes:** 当前 `Theme`、`Main.tscn`、库存覆盖层、厨房排程面板和产出单元场景。

**Produces:** 对新增 Theme 变体、运行时资源对齐和真实节点映射的可重复失败契约。

- [ ] **Step 1: 写入失败断言。**

  在 `REQUIRED_STYLES` 中加入以下语义变体与必需样式：

  ```gdscript
  "DessertDangerButton": ["normal", "hover", "pressed", "disabled"],
  "DessertTextInput": ["normal", "focus", "read_only"],
  "DessertDropdownInput": ["normal", "hover", "pressed", "disabled"],
  "DessertNumberInput": ["normal", "focus", "read_only"],
  "DessertProgressBar": ["background", "fill"],
  "DessertTopTabBar": ["tab_unselected", "tab_hovered", "tab_selected", "tab_disabled"],
  "DessertPopupMenu": ["panel"],
  "DessertStatusTagNormal": ["normal"],
  "DessertStatusTagPositive": ["normal"],
  "DessertStatusTagWarning": ["normal"],
  "DessertStatusTagNegative": ["normal"],
  ```

  增加 `CheckButton` 图标断言，要求 `DessertToggle` 的 `unchecked`、`checked`、`unchecked_hover`、`checked_hover`、`unchecked_disabled`、`checked_disabled` 均为有效 `Texture2D`。增加 `HScrollBar` 与 `VScrollBar` 的 `scroll`、`grabber`、`grabber_highlight`、`grabber_pressed` 样式断言，并要求所有样式纹理非空。

  增加场景断言：库存搜索框为 `DessertTextInput`；库存排序为 `DessertDropdownInput`；库存/图鉴/采购 `TabBar` 为 `DessertTopTabBar`；产出单元进度条、开关和状态标签分别为 `DessertProgressBar`、`DessertToggle`、`DessertStatusTag*`；厨房 `TargetStockSpin` 为 `DessertNumberInput`、三个 `OptionButton` 为 `DessertDropdownInput`、两个 `CheckButton` 为 `DessertToggle`、移除按钮为 `DessertDangerButton`。

- [ ] **Step 2: 运行自检，确认红灯。**

  Run:

  ```powershell
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/neighborhood_dessert_theme_self_check.gd
  ```

  Expected: exit code `1`，输出至少一条 `NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_FAIL`，原因是新增变体、纹理或节点映射尚不存在。

- [ ] **Step 3: 保持断言最小且可诊断。**

  将新断言复用现有 `_check_variation()`，并新增如下辅助函数，不在测试中硬编码节点实例实现：

  ```gdscript
  func _check_texture_icon(theme: Theme, icon_name: StringName, variation: StringName) -> void:
      var icon := theme.get_icon(icon_name, variation)
      if icon == null:
          _fail("%s/%s texture is missing" % [variation, icon_name])
  ```

- [ ] **Step 4: 暂不让测试变绿。**

  保留失败断言，进入 Task 2 生成缺失运行时资源。

### Task 2: 扩展运行时皮肤构建器并验证源状态对齐

**Files:**
- Modify: `tools/build_neighborhood_dessert_skin.py`
- Create: `resources/ui/skin/neighborhood_dessert/runtime/*.png`（由脚本生成，不手工编辑）
- Test: `tools/build_neighborhood_dessert_skin.py --check`

**Consumes:** 已确认存在的透明源图：`button_danger_*`、`input_text_*`、`input_dropdown_*`、`input_number_*`、`toggle_*`、`progress_*`、`panel_popup_normal`、`tooltip_bubble_normal`、`status_tag_*`、`scrollbar_*`。

**Produces:** Theme 可直接引用的运行时 PNG；状态族拥有统一裁切框和输出尺寸。

- [ ] **Step 1: 为构建器添加所需家族，并先令资源检查失败。**

  将 `FAMILIES` 扩展为：

  ```python
  "button_danger": Family(("normal", "hover", "pressed", "disabled"), (144, 40)),
  "input_text": Family(("normal", "focus", "error", "disabled"), (180, 40)),
  "input_dropdown": Family(("normal", "focus", "error", "disabled"), (180, 40)),
  "input_number": Family(("normal", "focus", "error", "disabled"), (144, 40)),
  "toggle": Family(("off", "on", "hover", "disabled"), (72, 36)),
  "progress_track": Family(("",), (144, 16)),
  "progress_fill_green": Family(("",), (144, 16)),
  "panel_popup": Family(("normal",), (220, 180)),
  "tooltip_bubble": Family(("normal",), (180, 72)),
  "status_tag": Family(("normal", "positive", "warning", "negative"), (96, 28)),
  "scrollbar_track": Family(("",), (18, 120)),
  "scrollbar_thumb": Family(("normal", "hover", "pressed", "disabled"), (18, 48)),
  ```

  为无状态文件实现 `source_path()` 与 `output_path()` 的空状态规则，均返回 `<family>.png`；不得生成带结尾下划线的文件名。

- [ ] **Step 2: 运行构建检查，确认红灯。**

  Run:

  ```powershell
  $python = 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
  & $python tools\build_neighborhood_dessert_skin.py --check
  ```

  Expected: exit code `1`，并报告首个缺失的新增 `runtime/*.png`。

- [ ] **Step 3: 实现横向滚动条派生与输出命名。**

  为 `Family` 增加 `rotate_clockwise: bool = False`，并在 `build_family()` 中在裁切后、缩放前执行：

  ```python
  if family.rotate_clockwise:
      image = image.transpose(Image.Transpose.ROTATE_270)
  ```

  添加 `scrollbar_track_horizontal` 和 `scrollbar_thumb_horizontal` 两个派生家族；它们复用竖向源图、在运行时输出前旋转，输出尺寸分别为 `(120, 18)` 与 `(48, 18)`。`source_path()` 对这两个派生家族去掉 `_horizontal` 后读取竖向源图；`output_path()` 保留 `_horizontal`，供 Theme 引用。

- [ ] **Step 4: 生成全部运行时资源并验证绿灯。**

  Run:

  ```powershell
  $python = 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
  & $python tools\build_neighborhood_dessert_skin.py
  & $python tools\build_neighborhood_dessert_skin.py --check
  ```

  Expected: 两个命令均 exit code `0`；最后一行是 `NEIGHBORHOOD_DESSERT_RUNTIME_SKIN_CHECK_PASS`。

### Task 3: 在集中 Theme 中装配新增控件变体

**Files:**
- Modify: `resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres`
- Test: `tests/neighborhood_dessert_theme_self_check.gd`

**Consumes:** Task 2 的 `runtime/*.png`。

**Produces:** 所有实际控件可使用的语义变体，且每个状态保持同一九宫格与内容边距。

- [ ] **Step 1: 运行 Task 1 自检，确认 Theme 契约仍失败。**

  Run:

  ```powershell
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/neighborhood_dessert_theme_self_check.gd
  ```

  Expected: exit code `1`，缺少新增 Theme 资源或样式。

- [ ] **Step 2: 添加纹理资源与 `StyleBoxTexture`。**

  每个状态族的 `StyleBoxTexture` 必须共享相同的 `texture_margin_*`、`content_margin_*`、`axis_stretch_horizontal` 和 `axis_stretch_vertical`。按以下职责建立变体：

  ```text
  DessertDangerButton      base_type = Button
  DessertTextInput         base_type = LineEdit
  DessertDropdownInput     base_type = OptionButton
  DessertNumberInput       base_type = LineEdit（由 SpinBox 内部输入框使用）
  DessertProgressBar       base_type = ProgressBar
  DessertTopTabBar         base_type = TabBar
  DessertPopupMenu         base_type = PopupMenu
  DessertToggle            base_type = CheckButton
  DessertStatusTag*        base_type = Label
  ```

  `DessertTextInput`、`DessertDropdownInput` 和 `DessertNumberInput` 的错误图只作为错误变体预留，不把验证错误状态伪装成正常交互状态。常规状态映射为 normal/focus/disabled；`read_only` 复用 disabled 边框但保留已有只读文字颜色。

  `DessertToggle` 使用图标而不是 StyleBox：`unchecked = toggle_off`、`checked = toggle_on`、两个 hover 状态复用 `toggle_hover`、两个 disabled 状态复用 `toggle_disabled`。

  `ProgressBar` 使用 `progress_track` 作为 `background`、`progress_fill_green` 作为 `fill`。`TabBar` 使用 top-tab 的 normal/hover/selected/disabled 图。`PopupMenu` 使用 `panel_popup` 作为 panel；全局 `TooltipPanel` 使用 `tooltip_bubble` 作为 panel。`HScrollBar`/`VScrollBar` 分别引用 Task 2 的横向/纵向轨道与滑块。

- [ ] **Step 3: 为状态标签定义明确的颜色职责。**

  `DessertStatusTagNormal` 使用普通米色标签；`DessertStatusTagPositive` 使用绿色标签且使用浅奶油文字；`DessertStatusTagWarning` 使用蜂蜜金标签；`DessertStatusTagNegative` 使用珊瑚红标签且使用浅奶油文字。四种变体的 `normal` 样式都必须是 `StyleBoxTexture`。

- [ ] **Step 4: 运行 Theme 自检，确认仍只因场景映射失败。**

  Run Task 1 的 Godot 命令。

  Expected: exit code `1`；新增 Theme 纹理与样式断言通过，失败信息仅指向尚未设置的场景或运行时控件变体。

### Task 4: 为现有场景和运行时创建路径设置语义变体

**Files:**
- Modify: `scenes/Main.tscn`
- Modify: `scenes/ui/overlays/inventory_overlay.tscn`
- Modify: `scenes/ui/overlays/catalog_overlay.tscn`
- Modify: `scenes/ui/pages/output_cell.tscn`
- Modify: `scenes/ui/pages/kitchen_automation_panel.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `scripts/output_cell.gd`
- Modify: `scripts/ui/pages/kitchen_automation_panel.gd`
- Test: `tests/neighborhood_dessert_theme_self_check.gd`

**Consumes:** Task 3 Theme 变体。

**Produces:** 现有页面和动态控件显示对应皮肤；状态标签随真实业务状态切换，但不改变状态文本。

- [ ] **Step 1: 保留当前场景结构，只添加 `theme_type_variation`。**

  设置下列节点：

  ```text
  InventorySearchInput                 DessertTextInput
  InventorySortButton                  DessertDropdownInput
  PurchaseCategoryTabs                 DessertTopTabBar
  InventoryTabs                        DessertTopTabBar
  CatalogFilterTabs                    DessertTopTabBar
  OutputContextMenu                    DessertPopupMenu
  OutputCell/ProductionProgressBar     DessertProgressBar
  OutputCell/AutomationToggle          DessertToggle
  OutputCell/AutomationStatusLabel     DessertStatusTagNormal
  Kitchen/RecipeOption                 DessertDropdownInput
  Kitchen/BatchOption                  DessertDropdownInput
  Kitchen/PriorityOption               DessertDropdownInput
  Kitchen/TargetStockSpin/LineEdit     DessertNumberInput
  Kitchen/PauseToggle                  DessertToggle
  Kitchen/OfflineToggle                DessertToggle
  Kitchen/SaveRuleButton               DessertPrimaryButton
  Kitchen/RemoveRuleButton             DessertDangerButton
  Kitchen/StatusLabel                  DessertStatusTagNormal
  ```

- [ ] **Step 2: 扩展动态控件创建，先用场景契约验证失败。**

  在 `_ensure_inventory_variant_menu()` 的 `PopupMenu.new()` 后加入：

  ```gdscript
  inventory_variant_menu.theme_type_variation = &"DessertPopupMenu"
  ```

  在 `kitchen_automation_panel.gd` 中为固定与动态 `SpinBox` 的内部输入框应用变体：

  ```gdscript
  func _apply_number_input_skin(spin: SpinBox) -> void:
      var line_edit := spin.get_line_edit()
      if line_edit != null:
          line_edit.theme_type_variation = &"DessertNumberInput"
  ```

  为产出格与厨房状态标签添加不改变文案的变体切换函数。`托管中` 和保存/移除成功使用 `DessertStatusTagPositive`；`未托管` 使用 `DessertStatusTagNormal`；缺料、金币不足、暂停或服务失败使用 `DessertStatusTagWarning`；没有其它可映射的负向状态时不强行设置 `DessertStatusTagNegative`。

- [ ] **Step 3: 运行 Theme 自检，确认绿灯。**

  Run:

  ```powershell
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/neighborhood_dessert_theme_self_check.gd
  ```

  Expected: exit code `0`，输出 `NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_PASS`。

- [ ] **Step 4: 运行与产出、自动化相关的窄范围回归检查。**

  Run:

  ```powershell
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-output.log" -s res://tests/output_layout_self_check.gd
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-automation.log" -s res://tests/automation_settlement_self_check.gd
  ```

  Expected: 两个检查脚本均 exit code `0`；不执行广泛 MVP 套件。

### Task 5: 完整性验证与可视检查

**Files:**
- Modify: `tests/neighborhood_dessert_theme_self_check.gd`（仅在 Task 4 自检暴露遗漏时）
- Verify: `resources/ui/skin/neighborhood_dessert/runtime/*.png`
- Verify: `resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres`

**Consumes:** Tasks 1–4 的实现。

**Produces:** 可交付的“仅现有控件”换肤证据，不对未使用素材宣称已接入。

- [ ] **Step 1: 运行运行时资源检查。**

  Run:

  ```powershell
  $python = 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
  & $python tools\build_neighborhood_dessert_skin.py --check
  ```

  Expected: exit code `0`，输出 `NEIGHBORHOOD_DESSERT_RUNTIME_SKIN_CHECK_PASS`。

- [ ] **Step 2: 运行 Theme 与场景完整性检查。**

  Run Task 4 的 Theme 自检命令。

  Expected: exit code `0`，输出 `NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_PASS`。

- [ ] **Step 3: 检查变更范围与格式。**

  Run:

  ```powershell
  git diff --check
  git status --short
  ```

  Expected: `git diff --check` exit code `0`；只汇报本计划列出的皮肤、Theme、场景、脚本与测试改动，保留并忽略用户已有的无关改动。

- [ ] **Step 4: 在 Godot 编辑器或运行画面中检查。**

  依次打开库存覆盖层、产出页、厨房排程、图鉴筛选；检查输入框右侧分隔区、进度填充、开关状态、Tab、滚动条、弹出菜单、Tooltip 与状态标签。验收条件：无文字跳动、无圆角拉伸、无状态图错位、无点击区域变化。
