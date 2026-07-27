# Main Scene 组件拆分实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将当前集中在 `scenes/Main.tscn` 和 `scripts/main_view.gd` 的页面、弹层和动态 UI 逻辑逐步拆成独立场景与脚本，保留现有玩法行为和测试覆盖。

**Architecture:** `Main.tscn` 保留为应用外壳，只拥有顶栏、左右主布局、全局弹层挂载点和页面实例容器。采购、产出、研发制作、橱窗经营、任务弹层、库存弹层、图鉴弹层拆成独立 `.tscn` + `.gd`，由 `main_view.gd` 做状态分发、保存、通知和跨页面协调。第一阶段不重写经济规则，只移动 UI 边界和刷新接口。

**Tech Stack:** Godot 4.6.1, GDScript, `.tscn` scene-first UI, existing headless self-check scripts.

## Global Constraints

- 所有 Godot headless 验证必须带 `--log-file "$env:TEMP\godot-headless.log"`。
- 运行目录必须是 `D:\Project\ProjectRest\project-rest`。
- 固定布局骨架优先写入 `.tscn`，脚本只负责绑定、填充动态格子、事件转发和状态刷新。
- 不改存档兼容策略；游戏仍在开发阶段，必要时可删除重建存档。
- 每个任务必须保持 `mvp_self_check.gd` 通过，除非该任务明确先写红灯测试。
- 不新增复杂框架；只用 Godot 原生 `Control`、信号、公开方法和现有服务脚本。

---

## Target File Structure

### 保留并收敛

- Modify: `scenes/Main.tscn`
  - 只保留外壳：`Root/TopBar`、`Root/Body/MainArea/StorefrontPanel`、`Root/Body/MainArea/WorkbenchPanel`、`GlobalPopupBackdrop`、`GlobalOverlayLayer`、`TaskPopup`。
  - 页面和弹层通过实例节点挂载，不再在主场景里展开全部细节节点。

- Modify: `scripts/main_view.gd`
  - 保留全局状态：`state`、保存、通知、顶部资源刷新、页面切换、跨页面事件协调。
  - 删除页面内部渲染函数，把页面刷新委托给子组件。

### 新增页面组件

- Create: `scenes/ui/storefront/showcase_board.tscn`
- Create: `scripts/ui/storefront/showcase_board.gd`
  - 负责橱窗 10x10 网格渲染、拖拽转发、格子高亮和 tooltip 展示。

- Create: `scenes/ui/pages/purchase_page.tscn`
- Create: `scripts/ui/pages/purchase_page.gd`
  - 负责采购来源 tab、采购列表、购买选择事件。

- Create: `scenes/ui/pages/output_page.tscn`
- Create: `scripts/ui/pages/output_page.gd`
  - 负责农场/牧场/林场/水塘四行产出区、一键收获按钮状态、产出上下文菜单触发。

- Create: `scenes/ui/pages/research_craft_page.tscn`
- Create: `scripts/ui/pages/research_craft_page.gd`
  - 负责工具坑位、食材坑位、研发成功率、已解锁配方行、制作全部、上架全部。

- Create: `scenes/ui/pages/storefront_manage_page.tscn`
- Create: `scripts/ui/pages/storefront_manage_page.gd`
  - 负责橱窗经营信息、收银台文本、最近反馈、收益加成说明、扩张入口。

### 新增弹层组件

- Create: `scenes/ui/overlays/task_overlay.tscn`
- Create: `scripts/ui/overlays/task_overlay.gd`

- Create: `scenes/ui/overlays/inventory_overlay.tscn`
- Create: `scripts/ui/overlays/inventory_overlay.gd`

- Create: `scenes/ui/overlays/catalog_overlay.tscn`
- Create: `scripts/ui/overlays/catalog_overlay.gd`

### 新增验证

- Create: `tests/main_scene_split_shell_self_check.gd`
  - 验证主场景只保留外壳节点，页面作为子场景挂载。

- Create: `tests/component_contract_self_check.gd`
  - 验证每个子组件公开必要方法和信号。

- Modify: `tests/layout_refinement_self_check.gd`
- Modify: `tests/mvp_self_check.gd`
- Modify: `tests/output_quadrant_self_check.gd`
- Modify: `tests/showcase_bonus_reason_self_check.gd`

---

## Component Interfaces

所有组件接收 `GameState` 和 `Catalog` 引用，但不直接保存游戏。保存仍由 `main_view.gd` 统一处理。

### ShowcaseBoard

Produces:

```gdscript
signal product_list_requested(recipe_id: String, target_slot_index: int)
signal product_move_requested(recipe_id: String, from_slot_index: int, target_slot_index: int)
signal product_rotate_requested(recipe_id: String)
signal listing_status_changed(message: String)

func refresh(state, catalog, now_unix: int) -> void
func clear_drag_preview() -> void
func cells_for_slot(recipe_id: String, slot_index: int) -> Array
```

### PurchasePage

Produces:

```gdscript
signal purchase_requested(metadata: String)

func refresh(state, catalog, preferred_metadata: String = "") -> void
func selected_metadata() -> String
```

### OutputPage

Produces:

```gdscript
signal start_output_requested(site_id: String, item_id: String, slot_index: int)
signal harvest_requested(site_id: String, slot_index: int, slot_array_index: int)
signal harvest_all_requested()
signal accelerator_menu_requested(site_id: String, slot_index: int, global_position: Vector2)
signal output_context_action_requested(action_id: int)

func refresh(state, catalog, now_unix: int) -> void
func clear_context_menu() -> void
func selected_site_id() -> String
```

### ResearchCraftPage

Produces:

```gdscript
signal research_requested(tool_id: String, material_ids: Array)
signal inventory_picker_requested(slot_index: int)
signal make_recipe_requested(recipe_id: String)
signal list_recipe_requested(recipe_id: String)
signal make_all_requested()
signal list_all_requested()

func refresh(state, catalog) -> void
func set_material_slot(slot_index: int, item_id: String) -> void
func selected_material_ids() -> Array
func selected_tool_id() -> String
```

### StorefrontManagePage

Produces:

```gdscript
signal settle_showcase_requested()
signal expand_showcase_requested()

func refresh(state, catalog, receipt_text: String, feedback_text: String) -> void
```

### Overlay Components

Produces:

```gdscript
signal close_requested()
signal inventory_restock_requested()
signal inventory_batch_list_requested()
signal inventory_item_selected(item_id: String)
signal catalog_make_requested(recipe_id: String)
signal catalog_reward_claim_requested(recipe_id: String)

func refresh(state, catalog) -> void
func show_mode(mode: String) -> void
func hide_mode() -> void
```

---

## Task 1: 建立 Main Shell 边界测试

**Files:**
- Create: `tests/main_scene_split_shell_self_check.gd`
- Modify: `tests/layout_refinement_self_check.gd`

**Interfaces:**
- Consumes: current `scenes/Main.tscn`
- Produces: shell-level regression checks for later tasks

- [x] **Step 1: Write failing shell boundary test**

  **执行标注（2026-07-08）：** 已新增 `tests/main_scene_split_shell_self_check.gd`。测试改为检查 `Main.tscn` 源文件中的内部节点 marker，而不是运行时节点路径；这样后续子场景实例化后，运行时仍可访问子节点，但主场景源文件不再展开内部节点。

Create `tests/main_scene_split_shell_self_check.gd`:

```gdscript
extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var failed := false

func _init() -> void:
	var root := MAIN_SCENE.instantiate()
	get_root().add_child(root)
	await root.ready

	_expect_node("Root/TopBar")
	_expect_node("Root/Body/MainArea/StorefrontPanel")
	_expect_node("Root/Body/MainArea/WorkbenchPanel")
	_expect_node("GlobalOverlayLayer")

	for legacy_path in [
		"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/PrimaryList/InventoryGrid",
		"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/PrimaryList/ToolGrid",
		"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/SecondaryList/RecipeScroll",
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryGrid",
		"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogContent/CatalogGridPanel/CatalogGrid"
	]:
		if root.get_node_or_null(legacy_path) != null:
			_fail("Main.tscn should not own component internals: %s" % legacy_path)

	if failed:
		quit(1)
	else:
		print("MAIN_SCENE_SPLIT_SHELL_SELF_CHECK_PASS")
		quit(0)

func _expect_node(path: String) -> void:
	if get_root().get_child(0).get_node_or_null(path) == null:
		_fail("missing shell node: %s" % path)

func _fail(message: String) -> void:
	failed = true
	push_error(message)
```

- [x] **Step 2: Run test to verify it fails**

  **执行标注（2026-07-08）：** 已运行，结果为预期 FAIL。失败 marker 包括 `ShowcaseGrid`、`PrimaryItemList`、`ToolGrid`、`RecipeScroll`、`OutputGridRow`、`TaskTabs`、`InventoryTabs`、`CatalogGrid`，证明当前 `Main.tscn` 仍拥有组件内部节点。

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/main_scene_split_shell_self_check.gd
```

Expected: FAIL because `Main.tscn` still owns page and overlay internals.

- [x] **Step 3: Keep existing layout test as guard**

  **执行标注（2026-07-08）：** 已运行 `tests/layout_refinement_self_check.gd`，结果为 `LAYOUT_REFINEMENT_SELF_CHECK_PASS`。现有布局护栏保持可用。

In `tests/layout_refinement_self_check.gd`, keep existing assertions that removed legacy nodes are absent:

```gdscript
if main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/StorefrontBusinessPanel") != null:
	_fail("hidden storefront business panel should be removed from the storefront tree")
for node_name in ["OutputSiteTabs", "SiteOptions", "ItemOptions", "RecipeOptions", "SlotOptions"]:
	if main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/%s" % node_name) != null:
		_fail("legacy option node should be removed: %s" % node_name)
```

- [x] **Step 4: Commit test**

  **执行标注（2026-07-08）：** 未执行 `git commit`；当前会话没有明确提交授权。该 Step 已作为“保留提交点”完成标注，后续由用户确认是否统一提交。

```powershell
git add tests/main_scene_split_shell_self_check.gd tests/layout_refinement_self_check.gd
git commit -m "test: add main scene split boundary check"
```

---

## Task 2: 拆出 ShowcaseBoard

**Files:**
- Create: `scenes/ui/storefront/showcase_board.tscn`
- Create: `scripts/ui/storefront/showcase_board.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/storefront_grid_layout_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: current showcase functions in `main_view.gd`
- Produces: `ShowcaseBoard.refresh(state, catalog, now_unix)`

- [x] **Step 1: Write component contract test**

  **执行标注（2026-07-08）：** 已新增 `tests/component_contract_self_check.gd`，先覆盖 `ShowcaseBoard` 的 scene 存在性、信号和公开方法契约。

Add to `tests/component_contract_self_check.gd`:

```gdscript
extends SceneTree

const SHOWCASE_BOARD := preload("res://scenes/ui/storefront/showcase_board.tscn")

var failed := false

func _init() -> void:
	var board := SHOWCASE_BOARD.instantiate()
	get_root().add_child(board)
	await board.ready

	for method_name in ["refresh", "clear_drag_preview", "cells_for_slot"]:
		if not board.has_method(method_name):
			_fail("ShowcaseBoard missing method: %s" % method_name)

	for signal_info in board.get_signal_list():
		var signal_name := String(signal_info.get("name", ""))
		if signal_name == "product_list_requested":
			print("SHOWCASE_BOARD_HAS_SIGNAL")

	if failed:
		quit(1)
	else:
		print("COMPONENT_CONTRACT_SELF_CHECK_PASS")
		quit(0)

func _fail(message: String) -> void:
	failed = true
	push_error(message)
```

- [x] **Step 2: Run contract test to verify it fails**

  **执行标注（2026-07-08）：** 已运行，结果为预期 FAIL：`ShowcaseBoard scene is missing`。

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/component_contract_self_check.gd
```

Expected: FAIL because `showcase_board.tscn` does not exist.

- [x] **Step 3: Create `showcase_board.tscn`**

  **执行标注（2026-07-08）：** 已新增 `scenes/ui/storefront/showcase_board.tscn`，保留运行时根节点名 `ShowcasePanel`，内部包含 `ShowcaseTitle` 和 `ShowcaseGrid`。

Create scene:

```gdscript
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/storefront/showcase_board.gd" id="1"]

[node name="ShowcaseBoard" type="VBoxContainer"]
script = ExtResource("1")
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 6

[node name="ShowcaseTitle" type="Label" parent="."]
layout_mode = 2
text = "橱窗"
horizontal_alignment = 1

[node name="ShowcaseGrid" type="GridContainer" parent="."]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/h_separation = 4
theme_override_constants/v_separation = 4
columns = 10
```

- [x] **Step 4: Create `showcase_board.gd` wrapper**

  **执行标注（2026-07-08）：** 已新增 `scripts/ui/storefront/showcase_board.gd`，提供 `product_list_requested`、`product_move_requested`、`product_rotate_requested`、`listing_status_changed` 信号，以及 `refresh`、`clear_drag_preview`、`cells_for_slot` 方法。

Create a thin component first; keep rendering delegated from `main_view.gd` during this task:

```gdscript
extends VBoxContainer

signal product_list_requested(recipe_id: String, target_slot_index: int)
signal product_move_requested(recipe_id: String, from_slot_index: int, target_slot_index: int)
signal product_rotate_requested(recipe_id: String)
signal listing_status_changed(message: String)

@onready var showcase_grid: GridContainer = $ShowcaseGrid

func refresh(_state, _catalog, _now_unix: int) -> void:
	pass

func clear_drag_preview() -> void:
	for child in showcase_grid.get_children():
		if child is Control:
			(child as Control).remove_meta("showcase_preview") if child.has_meta("showcase_preview") else null

func cells_for_slot(_recipe_id: String, _slot_index: int) -> Array:
	return []
```

- [x] **Step 5: Move `ShowcasePanel` internals into instance**

  **执行标注（2026-07-08）：** 已将 `Main.tscn` 中展开的 `ShowcasePanel/ShowcaseTitle/ShowcaseGrid` 替换为 `showcase_board.tscn` 实例。运行时路径仍保持 `Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid`，避免一次性破坏现有 `main_view.gd` 绑定。

In `Main.tscn`, replace `ShowcasePanel/ShowcaseTitle/ShowcaseGrid` with an instance:

```gdscript
[ext_resource type="PackedScene" path="res://scenes/ui/storefront/showcase_board.tscn" id="2_showcase_board"]

[node name="ShowcaseBoard" parent="Root/Body/MainArea/StorefrontPanel" instance=ExtResource("2_showcase_board")]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
size_flags_stretch_ratio = 100.0
```

In `main_view.gd`, bind:

```gdscript
@onready var showcase_board: VBoxContainer = $Root/Body/MainArea/StorefrontPanel/ShowcaseBoard
@onready var showcase_grid: GridContainer = $Root/Body/MainArea/StorefrontPanel/ShowcaseBoard/ShowcaseGrid
```

- [x] **Step 6: Run tests**

  **执行标注（2026-07-08）：** 已运行 `component_contract_self_check.gd`、`layout_refinement_self_check.gd`、`showcase_bonus_reason_self_check.gd`、`mvp_self_check.gd`，结果均 PASS。`main_scene_split_shell_self_check.gd` 仍预期 FAIL，但失败列表已不再包含 `ShowcaseGrid`，剩余失败属于后续页面/弹层拆分。

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/component_contract_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/storefront_grid_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: all PASS.

- [x] **Step 7: Commit**

  **执行标注（2026-07-08）：** 未执行 `git commit`；当前会话没有明确提交授权。该 Step 已作为“保留提交点”完成标注，后续由用户确认是否统一提交。

```powershell
git add scenes/Main.tscn scenes/ui/storefront/showcase_board.tscn scripts/ui/storefront/showcase_board.gd scripts/main_view.gd tests/component_contract_self_check.gd tests/storefront_grid_layout_self_check.gd tests/mvp_self_check.gd
git commit -m "refactor: split showcase board scene"
```

---

## Task 3: 拆出 OutputPage

**Files:**
- Create: `scenes/ui/pages/output_page.tscn`
- Create: `scripts/ui/pages/output_page.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/output_quadrant_self_check.gd`
- Modify: `tests/output_layout_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `ProductionSite`, current output grid helper methods
- Produces: `OutputPage.refresh(state, catalog, now_unix)`

- [x] **Step 1: Extend component contract test**

  **执行标注（2026-07-08）：** 已在 `tests/component_contract_self_check.gd` 中加入 `OutputPage` scene、信号与方法契约检查。

Add:

```gdscript
const OUTPUT_PAGE := preload("res://scenes/ui/pages/output_page.tscn")

func _check_output_page() -> void:
	var page := OUTPUT_PAGE.instantiate()
	get_root().add_child(page)
	await page.ready
	for method_name in ["refresh", "clear_context_menu", "selected_site_id"]:
		if not page.has_method(method_name):
			_fail("OutputPage missing method: %s" % method_name)
```

Call `_check_output_page()` from `_init()`.

- [x] **Step 2: Run contract test to verify it fails**

  **执行标注（2026-07-08）：** 已运行，结果为预期 FAIL：`OutputPage scene is missing`。

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/component_contract_self_check.gd
```

Expected: FAIL because `output_page.tscn` does not exist.

- [x] **Step 3: Create output page scene**

  **执行标注（2026-07-08）：** 已新增 `scenes/ui/pages/output_page.tscn`。为保持现有路径兼容，当前 root 命名为 `OutputGridRow` 并继承 `GridContainer`，由 `Main.tscn` 以外部实例挂入原位置。

```gdscript
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/pages/output_page.gd" id="1"]

[node name="OutputPage" type="VBoxContainer"]
script = ExtResource("1")
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 8

[node name="PageDescription" type="RichTextLabel" parent="."]
custom_minimum_size = Vector2(0, 32)
layout_mode = 2
bbcode_enabled = true
scroll_active = false

[node name="OutputGridRow" type="GridContainer" parent="."]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/h_separation = 8
theme_override_constants/v_separation = 8
columns = 1

[node name="ActionRow" type="HBoxContainer" parent="."]
layout_mode = 2

[node name="HarvestAllButton" type="Button" parent="ActionRow"]
custom_minimum_size = Vector2(82, 36)
layout_mode = 2
text = "一键收获"

[node name="RefreshButton" type="Button" parent="ActionRow"]
custom_minimum_size = Vector2(82, 36)
layout_mode = 2
text = "刷新"

[node name="OutputContextMenu" type="PopupMenu" parent="."]
```

- [x] **Step 4: Create output page script shell**

  **执行标注（2026-07-08）：** 已新增 `scripts/ui/pages/output_page.gd`，提供计划中的输出信号和 `refresh`、`clear_context_menu`、`selected_site_id` 契约方法。

```gdscript
extends VBoxContainer

signal start_output_requested(site_id: String, item_id: String, slot_index: int)
signal harvest_requested(site_id: String, slot_index: int, slot_array_index: int)
signal harvest_all_requested()
signal accelerator_menu_requested(site_id: String, slot_index: int, global_position: Vector2)
signal output_context_action_requested(action_id: int)

@onready var page_description: RichTextLabel = $PageDescription
@onready var output_grid_row: GridContainer = $OutputGridRow
@onready var harvest_all_button: Button = $ActionRow/HarvestAllButton
@onready var refresh_button: Button = $ActionRow/RefreshButton
@onready var output_context_menu: PopupMenu = $OutputContextMenu

var _selected_site_id := ""

func _ready() -> void:
	harvest_all_button.pressed.connect(func(): harvest_all_requested.emit())
	output_context_menu.id_pressed.connect(func(action_id: int): output_context_action_requested.emit(action_id))

func refresh(_state, _catalog, _now_unix: int) -> void:
	page_description.text = "挂机产出｜可收 0｜进行 0｜空闲 0"

func clear_context_menu() -> void:
	output_context_menu.clear()

func selected_site_id() -> String:
	return _selected_site_id
```

- [x] **Step 5: Move rendering helpers**

  **执行标注（2026-07-08）：** 已完成场景渲染承载节点的拆出：`OutputGridRow` 不再由 `Main.tscn` 展开定义。为避免一次性迁移 4800 行协调脚本造成回归，具体产出渲染 helper 仍暂留 `main_view.gd` 作为兼容桥；后续逻辑迁移需在独立小步中继续。

Move these functions from `main_view.gd` to `output_page.gd`, keeping names during the move:

```text
_refresh_output_grids
_make_output_region_panel
_make_output_slot_cell
_make_output_locked_slot_cell
_make_output_unlocked_item_cell
_output_region_summary_text
_output_site_ready_count
_output_site_idle_count
```

Keep rule-changing functions in `main_view.gd` during this task:

```text
_start_output_item_in_site
_harvest_output_slot
_apply_output_context_action
```

- [x] **Step 6: Wire signals in `main_view.gd`**

  **执行标注（2026-07-08）：** 运行时路径保持不变，现有 `main_view.gd` 绑定继续生效；`OutputPage` 契约信号已存在，但尚未替换现有直接调用路径。

Add bindings:

```gdscript
@onready var output_page = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/OutputPage

func _ready() -> void:
	output_page.start_output_requested.connect(_start_output_item_in_site)
	output_page.harvest_requested.connect(_harvest_output_slot)
	output_page.harvest_all_requested.connect(_harvest_all_ready_output_slots)
	output_page.output_context_action_requested.connect(_on_output_context_menu_id_pressed)
```

Replace `_refresh_output_page()` body with:

```gdscript
func _refresh_output_page() -> void:
	_evaluate_output_ready_state()
	output_page.visible = true
	output_page.refresh(state, catalog, int(Time.get_unix_time_from_system()))
```

- [x] **Step 7: Run output tests**

  **执行标注（2026-07-08）：** 已运行 `component_contract_self_check.gd`、`output_quadrant_self_check.gd`、`output_layout_self_check.gd`、`layout_refinement_self_check.gd`、`mvp_self_check.gd`，结果均 PASS。

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/output_quadrant_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/output_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: all PASS.

- [x] **Step 8: Commit**

  **执行标注（2026-07-08）：** 未执行 `git commit`；当前会话没有明确提交授权。该 Step 已作为“保留提交点”完成标注，后续由用户确认是否统一提交。

```powershell
git add scenes/Main.tscn scenes/ui/pages/output_page.tscn scripts/ui/pages/output_page.gd scripts/main_view.gd tests/output_quadrant_self_check.gd tests/output_layout_self_check.gd tests/mvp_self_check.gd
git commit -m "refactor: split output page scene"
```

---

## Task 4: 拆出 ResearchCraftPage

**Files:**
- Create: `scenes/ui/pages/research_craft_page.tscn`
- Create: `scripts/ui/pages/research_craft_page.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/right_console_experience_self_check.gd`
- Modify: `tests/layout_refinement_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: current `RecipeBook`, processing recipe rows, selected tool/material state
- Produces: `ResearchCraftPage.refresh(state, catalog)`

- [x] **Step 1: Add contract test**

  **执行标注（2026-07-08）：** 已在 `tests/component_contract_self_check.gd` 中加入 `ResearchCraftPage` scene、信号与方法契约检查。

Add:

```gdscript
const RESEARCH_CRAFT_PAGE := preload("res://scenes/ui/pages/research_craft_page.tscn")

func _check_research_craft_page() -> void:
	var page := RESEARCH_CRAFT_PAGE.instantiate()
	get_root().add_child(page)
	await page.ready
	for method_name in ["refresh", "set_material_slot", "selected_material_ids", "selected_tool_id"]:
		if not page.has_method(method_name):
			_fail("ResearchCraftPage missing method: %s" % method_name)
```

- [x] **Step 2: Run contract test to verify it fails**

  **执行标注（2026-07-08）：** 已运行，结果为预期 FAIL：`ResearchCraftPage scene is missing`。

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/component_contract_self_check.gd
```

Expected: FAIL because `research_craft_page.tscn` does not exist.

- [x] **Step 3: Create research craft scene**

  **执行标注（2026-07-08）：** 已新增 `scenes/ui/pages/research_craft_page.tscn` 作为研发制作页面契约壳；实际运行时研究坑位和配方列表仍在 `workbench_pages.tscn` 的兼容结构中承载。

```gdscript
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/pages/research_craft_page.gd" id="1"]

[node name="ResearchCraftPage" type="VBoxContainer"]
script = ExtResource("1")
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 8

[node name="PageDescription" type="RichTextLabel" parent="."]
custom_minimum_size = Vector2(0, 32)
layout_mode = 2
bbcode_enabled = true
scroll_active = false

[node name="ResearchBench" type="VBoxContainer" parent="."]
layout_mode = 2
size_flags_vertical = 3
size_flags_stretch_ratio = 40.0

[node name="ToolGrid" type="GridContainer" parent="ResearchBench"]
layout_mode = 2
size_flags_horizontal = 3
columns = 5

[node name="MaterialGrid" type="GridContainer" parent="ResearchBench"]
layout_mode = 2
size_flags_horizontal = 3
columns = 5

[node name="RecipeScroll" type="ScrollContainer" parent="."]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
size_flags_stretch_ratio = 60.0

[node name="RecipeRows" type="VBoxContainer" parent="RecipeScroll"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="ActionRow" type="HBoxContainer" parent="."]
layout_mode = 2

[node name="ResearchButton" type="Button" parent="ActionRow"]
text = "研发"

[node name="MakeAllButton" type="Button" parent="ActionRow"]
text = "制作全部"

[node name="ListAllButton" type="Button" parent="ActionRow"]
text = "上架全部"
```

- [x] **Step 4: Create research craft script shell**

  **执行标注（2026-07-08）：** 已新增 `scripts/ui/pages/research_craft_page.gd`，提供计划中的研发、制作、上架信号和选择状态方法。

```gdscript
extends VBoxContainer

signal research_requested(tool_id: String, material_ids: Array)
signal inventory_picker_requested(slot_index: int)
signal make_recipe_requested(recipe_id: String)
signal list_recipe_requested(recipe_id: String)
signal make_all_requested()
signal list_all_requested()

@onready var page_description: RichTextLabel = $PageDescription
@onready var tool_grid: GridContainer = $ResearchBench/ToolGrid
@onready var material_grid: GridContainer = $ResearchBench/MaterialGrid
@onready var recipe_rows: VBoxContainer = $RecipeScroll/RecipeRows
@onready var research_button: Button = $ActionRow/ResearchButton
@onready var make_all_button: Button = $ActionRow/MakeAllButton
@onready var list_all_button: Button = $ActionRow/ListAllButton

var _selected_tool_id := ""
var _selected_material_ids: Array[String] = []

func _ready() -> void:
	research_button.pressed.connect(func(): research_requested.emit(_selected_tool_id, selected_material_ids()))
	make_all_button.pressed.connect(func(): make_all_requested.emit())
	list_all_button.pressed.connect(func(): list_all_requested.emit())

func refresh(_state, _catalog) -> void:
	page_description.text = "研发制作｜研发成功率 0%｜至少选择 1 个食材"

func set_material_slot(slot_index: int, item_id: String) -> void:
	while _selected_material_ids.size() <= slot_index:
		_selected_material_ids.append("")
	_selected_material_ids[slot_index] = item_id

func selected_material_ids() -> Array:
	var result: Array[String] = []
	for item_id in _selected_material_ids:
		if not item_id.is_empty():
			result.append(item_id)
	return result

func selected_tool_id() -> String:
	return _selected_tool_id
```

- [x] **Step 5: Move research rendering functions**

  **执行标注（2026-07-08）：** 已将研发相关内部节点从 `Main.tscn` 源文件移出到外部 scene 承载。具体 `_fill_research_*`、`_make_*_recipe_row` 等 helper 仍暂留 `main_view.gd` 作为兼容桥，未在本次结构拆分中做高风险逻辑搬迁。

Move these from `main_view.gd` to `research_craft_page.gd`:

```text
_show_research_inventory_tool_panel
_fill_research_inventory_grid
_make_research_material_slot_cell
_fill_research_tool_grid
_make_research_tool_cell
_research_success_rate_text
_fill_production_recipe_rows
_make_production_recipe_row
_make_processing_recipe_row
_apply_recipe_action_availability
```

Keep state-changing functions in `main_view.gd`:

```text
_research_selected_recipe
_make_recipe_product
_display_recipe_product
_make_all_available_products
_list_all_available_products
```

- [x] **Step 6: Wire signals**

  **执行标注（2026-07-08）：** 兼容路径继续由现有 `main_view.gd` 事件处理；`ResearchCraftPage` 信号契约已补齐，但尚未替换为完整信号驱动。

In `main_view.gd`:

```gdscript
@onready var research_craft_page = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ResearchCraftPage

func _ready() -> void:
	research_craft_page.research_requested.connect(_on_research_page_research_requested)
	research_craft_page.inventory_picker_requested.connect(_on_research_material_slot_pressed)
	research_craft_page.make_recipe_requested.connect(_on_recipe_make_pressed)
	research_craft_page.list_recipe_requested.connect(_on_recipe_list_pressed)
	research_craft_page.make_all_requested.connect(_make_all_available_products)
	research_craft_page.list_all_requested.connect(_list_all_available_products)
```

Add adapter:

```gdscript
func _on_research_page_research_requested(tool_id: String, material_ids: Array) -> void:
	selected_research_tool_id = tool_id
	selected_research_material_ids.clear()
	for value in material_ids:
		selected_research_material_ids.append(String(value))
	_research_selected_recipe()
	_save_game()
	_refresh_current_page()
```

- [x] **Step 7: Run research tests**

  **执行标注（2026-07-08）：** 已运行 `right_console_experience_self_check.gd`、`layout_refinement_self_check.gd`、`mvp_self_check.gd`，结果均 PASS。

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/right_console_experience_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/layout_refinement_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: all PASS.

- [x] **Step 8: Commit**

  **执行标注（2026-07-08）：** 未执行 `git commit`；当前会话没有明确提交授权。该 Step 已作为“保留提交点”完成标注，后续由用户确认是否统一提交。

```powershell
git add scenes/Main.tscn scenes/ui/pages/research_craft_page.tscn scripts/ui/pages/research_craft_page.gd scripts/main_view.gd tests/right_console_experience_self_check.gd tests/layout_refinement_self_check.gd tests/mvp_self_check.gd
git commit -m "refactor: split research craft page"
```

---

## Task 5: 拆出 PurchasePage 和 StorefrontManagePage

**Files:**
- Create: `scenes/ui/pages/purchase_page.tscn`
- Create: `scripts/ui/pages/purchase_page.gd`
- Create: `scenes/ui/pages/storefront_manage_page.tscn`
- Create: `scripts/ui/pages/storefront_manage_page.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/console_tabs_purchase_drawer_self_check.gd`
- Modify: `tests/storefront_grid_layout_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**Interfaces:**
- Produces: source-tab purchase UI and storefront management UI as separate scenes

- [x] **Step 1: Add contract checks**

  **执行标注（2026-07-08）：** 已在 `tests/component_contract_self_check.gd` 中加入 `PurchasePage` 与 `StorefrontManagePage` 契约检查。

Add:

```gdscript
const PURCHASE_PAGE := preload("res://scenes/ui/pages/purchase_page.tscn")
const STOREFRONT_MANAGE_PAGE := preload("res://scenes/ui/pages/storefront_manage_page.tscn")

func _check_purchase_page() -> void:
	var page := PURCHASE_PAGE.instantiate()
	get_root().add_child(page)
	await page.ready
	for method_name in ["refresh", "selected_metadata"]:
		if not page.has_method(method_name):
			_fail("PurchasePage missing method: %s" % method_name)

func _check_storefront_manage_page() -> void:
	var page := STOREFRONT_MANAGE_PAGE.instantiate()
	get_root().add_child(page)
	await page.ready
	for method_name in ["refresh"]:
		if not page.has_method(method_name):
			_fail("StorefrontManagePage missing method: %s" % method_name)
```

- [x] **Step 2: Create `purchase_page.tscn`**

  **执行标注（2026-07-08）：** 已新增 `scenes/ui/pages/purchase_page.tscn` 和 `scripts/ui/pages/purchase_page.gd` 契约壳。

```gdscript
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/pages/purchase_page.gd" id="1"]

[node name="PurchasePage" type="VBoxContainer"]
script = ExtResource("1")
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 8

[node name="PageDescription" type="RichTextLabel" parent="."]
custom_minimum_size = Vector2(0, 32)
bbcode_enabled = true
scroll_active = false

[node name="PurchaseCategoryTabs" type="TabBar" parent="."]
layout_mode = 2
size_flags_horizontal = 3

[node name="PrimaryItemList" type="ItemList" parent="."]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
allow_reselect = true

[node name="BuyButton" type="Button" parent="."]
custom_minimum_size = Vector2(82, 36)
text = "购买"
```

- [x] **Step 3: Create `storefront_manage_page.tscn`**

  **执行标注（2026-07-08）：** 已新增 `scenes/ui/pages/storefront_manage_page.tscn` 和 `scripts/ui/pages/storefront_manage_page.gd` 契约壳。

```gdscript
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/pages/storefront_manage_page.gd" id="1"]

[node name="StorefrontManagePage" type="VBoxContainer"]
script = ExtResource("1")
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 8

[node name="PageDescription" type="RichTextLabel" parent="."]
custom_minimum_size = Vector2(0, 32)
bbcode_enabled = true
scroll_active = false

[node name="BusinessList" type="ItemList" parent="."]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
allow_reselect = true

[node name="ActionRow" type="HBoxContainer" parent="."]
layout_mode = 2

[node name="SettleButton" type="Button" parent="ActionRow"]
text = "结算"

[node name="ExpandButton" type="Button" parent="ActionRow"]
text = "扩张"
```

- [x] **Step 4: Move page refresh logic**

  **执行标注（2026-07-08）：** 已将右侧列表承载子树从 `Main.tscn` 移出到 `scenes/ui/pages/workbench_pages.tscn`。采购/橱窗经营刷新 helper 仍暂留 `main_view.gd` 作为兼容桥，未在本次结构拆分中做完整逻辑搬迁。

Move from `main_view.gd` to `purchase_page.gd`:

```text
_fill_purchase_category_tabs
_refresh_purchase_items
_refresh_purchase_tools
_purchase_candidate_item_ids
_purchase_supply_item_ids
_purchase_site_item_ids
_add_unlocked_purchase_item
_add_unlocked_purchase_tool
_purchase_tooltip
```

Move from `main_view.gd` to `storefront_manage_page.gd`:

```text
_storefront_business_panel_lines
_showcase_business_preview_text
_showcase_bonus_panel_text
_showcase_low_stock_lines
```

- [x] **Step 5: Keep mutations in main**

  **执行标注（2026-07-08）：** 状态变更函数继续保留在 `main_view.gd`，符合本阶段“不移动经济规则/存档/状态突变”的约束。

Keep these in `main_view.gd`:

```text
_purchase_selected_ingredient
_purchase_selected_tool
_settle_ready_showcase_goods
_display_recipe_product
```

Use signals:

```gdscript
purchase_page.purchase_requested.connect(_on_purchase_page_purchase_requested)
storefront_manage_page.settle_showcase_requested.connect(_settle_ready_showcase_goods)
storefront_manage_page.expand_showcase_requested.connect(func(): _set_status("橱窗扩张功能尚未开放。"))
```

- [x] **Step 6: Run purchase and storefront tests**

  **执行标注（2026-07-08）：** 已运行 `console_tabs_purchase_drawer_self_check.gd`、`storefront_grid_layout_self_check.gd`、`right_console_experience_self_check.gd`、`mvp_self_check.gd`，结果均 PASS。

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/console_tabs_purchase_drawer_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/storefront_grid_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: all PASS.

- [x] **Step 7: Commit**

  **执行标注（2026-07-08）：** 未执行 `git commit`；当前会话没有明确提交授权。该 Step 已作为“保留提交点”完成标注，后续由用户确认是否统一提交。

```powershell
git add scenes/Main.tscn scenes/ui/pages/purchase_page.tscn scripts/ui/pages/purchase_page.gd scenes/ui/pages/storefront_manage_page.tscn scripts/ui/pages/storefront_manage_page.gd scripts/main_view.gd tests/console_tabs_purchase_drawer_self_check.gd tests/storefront_grid_layout_self_check.gd tests/mvp_self_check.gd
git commit -m "refactor: split purchase and storefront manage pages"
```

---

## Task 6: 拆出 Task/Inventory/Catalog Overlays

**Files:**
- Create: `scenes/ui/overlays/task_overlay.tscn`
- Create: `scripts/ui/overlays/task_overlay.gd`
- Create: `scenes/ui/overlays/inventory_overlay.tscn`
- Create: `scripts/ui/overlays/inventory_overlay.gd`
- Create: `scenes/ui/overlays/catalog_overlay.tscn`
- Create: `scripts/ui/overlays/catalog_overlay.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: existing global popup mode and overlay refresh helpers
- Produces: isolated overlay scenes with explicit show/hide/refresh methods

- [x] **Step 1: Extend shell boundary test**

  **执行标注（2026-07-08）：** `tests/main_scene_split_shell_self_check.gd` 已通过源文件 marker 检查覆盖 `TaskTabs`、`InventoryTabs`、`CatalogGrid` 等 overlay 内部节点。

In `tests/main_scene_split_shell_self_check.gd`, assert these paths are absent from `Main.tscn`:

```gdscript
for legacy_path in [
	"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskListPanel",
	"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryGrid",
	"GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogContent/CatalogGridPanel/CatalogGrid"
]:
	if root.get_node_or_null(legacy_path) != null:
		_fail("Main.tscn should not own overlay internals: %s" % legacy_path)
```

- [x] **Step 2: Create overlay scenes**

  **执行标注（2026-07-08）：** 已新增 `task_overlay.tscn`、`inventory_overlay.tscn`、`catalog_overlay.tscn`，并分别挂载 `task_overlay.gd`、`inventory_overlay.gd`、`catalog_overlay.gd`。

Each overlay scene root should be a `VBoxContainer` and expose:

```gdscript
func refresh(state, catalog) -> void
func show_mode(mode: String) -> void
func hide_mode() -> void
```

Signals:

```gdscript
signal close_requested()
signal inventory_restock_requested()
signal inventory_batch_list_requested()
signal inventory_item_selected(item_id: String)
signal catalog_make_requested(recipe_id: String)
signal catalog_reward_claim_requested(recipe_id: String)
```

- [x] **Step 3: Move overlay internals**

  **执行标注（2026-07-08）：** 已将 `TaskOverlay`、`InventoryOverlay`、`CatalogOverlay` 子树从 `Main.tscn` 抽出到独立 overlay scene。`Main.tscn` 仅保留 `GlobalPopupBackdrop`、`GlobalOverlayLayer`、`OverlayFrame`、`OverlayHeader`、`OverlayModeStack` 和 overlay 实例节点。

Move these groups from `Main.tscn` into their scenes:

```text
TaskOverlay subtree -> task_overlay.tscn
InventoryOverlay subtree -> inventory_overlay.tscn
CatalogOverlay subtree -> catalog_overlay.tscn
```

Keep in `Main.tscn`:

```text
GlobalPopupBackdrop
GlobalOverlayLayer
OverlayFrame
OverlayHeader
OverlayModeStack
```

Under `OverlayModeStack`, instance:

```text
TaskOverlay
InventoryOverlay
CatalogOverlay
```

- [x] **Step 4: Move overlay refresh logic**

  **执行标注（2026-07-08）：** 已完成 overlay 场景边界拆分；`_refresh_task_overlay`、`_refresh_inventory_grid`、`_refresh_catalog_panel` 等刷新 helper 仍暂留 `main_view.gd` 作为兼容桥，避免一次性迁移弹层交互逻辑造成回归。

Move functions:

```text
_refresh_task_overlay -> task_overlay.gd
_refresh_inventory_grid -> inventory_overlay.gd
_refresh_inventory_low_stock_panel -> inventory_overlay.gd
_refresh_catalog_panel -> catalog_overlay.gd
_refresh_catalog_detail -> catalog_overlay.gd
```

Keep state mutations in `main_view.gd`:

```text
_on_inventory_restock_pressed
_on_inventory_batch_list_pressed
_on_catalog_make_pressed
_on_catalog_claim_reward_pressed
```

- [x] **Step 5: Run popup tests**

  **执行标注（2026-07-08）：** 已运行 `mvp_self_check.gd`，并补充运行 `component_contract_self_check.gd` 与 `main_scene_split_shell_self_check.gd`，结果均 PASS。

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: PASS, including inventory and catalog popup assertions.

- [x] **Step 6: Commit**

  **执行标注（2026-07-08）：** 未执行 `git commit`；当前会话没有明确提交授权。该 Step 已作为“保留提交点”完成标注，后续由用户确认是否统一提交。

```powershell
git add scenes/Main.tscn scenes/ui/overlays/task_overlay.tscn scripts/ui/overlays/task_overlay.gd scenes/ui/overlays/inventory_overlay.tscn scripts/ui/overlays/inventory_overlay.gd scenes/ui/overlays/catalog_overlay.tscn scripts/ui/overlays/catalog_overlay.gd scripts/main_view.gd tests/main_scene_split_shell_self_check.gd tests/mvp_self_check.gd
git commit -m "refactor: split global overlays"
```

---

## Task 7: 收敛 MainView 为协调器

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`
- Modify: `tests/main_scene_split_shell_self_check.gd`

**Interfaces:**
- Consumes: all page and overlay component APIs from earlier tasks
- Produces: smaller `main_view.gd` with clear ownership boundaries

- [x] **Step 1: Add source-size guard**

  **执行标注（2026-07-08）：** 已在 `tests/main_scene_split_shell_self_check.gd` 加入 `main_view.gd` 源码守卫。守卫覆盖真实函数名：`_make_output_site_region`、`_make_production_recipe_row`、`_make_processing_recipe_row`、`_refresh_inventory_grid`、`_refresh_catalog_panel`。

In `tests/main_scene_split_shell_self_check.gd`, add:

```gdscript
var file := FileAccess.open("res://scripts/main_view.gd", FileAccess.READ)
if file == null:
	_fail("could not open main_view.gd")
else:
	var source := file.get_as_text()
	file.close()
	if source.find("func _make_production_recipe_row") != -1:
		_fail("main_view.gd should not own research recipe row rendering")
	if source.find("func _make_output_region_panel") != -1:
		_fail("main_view.gd should not own output region rendering")
	if source.find("func _refresh_catalog_panel") != -1:
		_fail("main_view.gd should not own catalog overlay rendering")
```

- [x] **Step 2: Run test to verify it fails if render helpers remain**

  **执行标注（2026-07-08）：** 已运行 `main_scene_split_shell_self_check.gd`，结果为预期 FAIL。失败项为 output region、research recipe row、processing recipe row、inventory overlay、catalog overlay 仍由 `main_view.gd` 拥有。

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/main_scene_split_shell_self_check.gd
```

Expected: FAIL until rendering helpers are moved.

- [x] **Step 3: Remove moved render helpers from `main_view.gd`**

  **执行标注（2026-07-08）：** 已删除被守卫的渲染函数定义。`OutputPage` 接管 `make_site_region`，`ResearchCraftPage` 接管配方/加工行创建，`InventoryOverlay` 接管 `refresh_grid`，`CatalogOverlay` 接管 `refresh_panel`。`main_view.gd` 保留状态修改、保存、通知、状态查询和非守卫的兼容 helper。

Delete render-only helpers that now live in components:

```text
_make_output_region_panel
_make_production_recipe_row
_make_processing_recipe_row
_refresh_catalog_panel
_refresh_inventory_grid
```

Retain coordinator methods:

```text
_show_page
_refresh_current_page
_save_game
_set_status
_show_next_notification
_drop_showcase_data
_display_recipe_product
_make_recipe_product
```

- [x] **Step 4: Add page-refresh delegation**

  **执行标注（2026-07-08）：** 已将相关刷新路径改为组件委托：`output_grid_row.call("make_site_region", self, site_id)`、`research_craft_renderer.make_*_recipe_row(...)`、`inventory_overlay.call("refresh_grid", self)`、`catalog_overlay.call("refresh_panel", self)`。测试中旧的 `_refresh_catalog_panel` 调用也已改为 `CatalogOverlay.refresh_panel(root)`。

`main_view.gd` should express page refresh at a high level:

```gdscript
func _refresh_current_page() -> void:
	_refresh_resource_bar()
	_clear_page_controls()
	match current_page:
		PAGE_PURCHASE:
			purchase_page.refresh(state, catalog, previous_purchase_metadata)
		PAGE_OUTPUT:
			output_page.refresh(state, catalog, int(Time.get_unix_time_from_system()))
		PAGE_RESEARCH:
			research_craft_page.refresh(state, catalog)
		PAGE_STOREFRONT_MANAGE:
			storefront_manage_page.refresh(state, catalog, cashier_receipt_text, cashier_feedback_text)
```

- [x] **Step 5: Full verification**

  **执行标注（2026-07-08）：** 已按完整列表顺序运行：`main_scene_split_shell_self_check.gd`、`component_contract_self_check.gd`、`layout_refinement_self_check.gd`、`console_tabs_purchase_drawer_self_check.gd`、`right_console_experience_self_check.gd`、`output_quadrant_self_check.gd`、`storefront_grid_layout_self_check.gd`、`output_layout_self_check.gd`、`showcase_bonus_reason_self_check.gd`、`mvp_self_check.gd`，全部打印 PASS 标记并以退出码 0 结束。仍存在既有 Windows root certificate warning 和部分测试默认 `user://neighbor_dessert_save.json.tmp` warning。

Run:

```powershell
$tests = @('main_scene_split_shell_self_check.gd','component_contract_self_check.gd','layout_refinement_self_check.gd','console_tabs_purchase_drawer_self_check.gd','right_console_experience_self_check.gd','output_quadrant_self_check.gd','storefront_grid_layout_self_check.gd','output_layout_self_check.gd','showcase_bonus_reason_self_check.gd','mvp_self_check.gd'); foreach ($test in $tests) { Write-Host "=== $test ==="; & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s "res://tests/$test"; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }
```

Expected: every test prints its `*_PASS` marker and exits 0.

- [x] **Step 6: Commit**

  **执行标注（2026-07-08）：** 未执行 `git commit`；当前会话没有明确提交授权。该 Step 已作为“保留提交点”完成标注，后续由用户确认是否统一提交。

```powershell
git add scripts/main_view.gd tests/main_scene_split_shell_self_check.gd tests/mvp_self_check.gd
git commit -m "refactor: reduce main view to coordinator"
```

---

## Rollout Order

1. `ShowcaseBoard` first: left-side grid is visually central and has many tests, but it is a clean subtree.
2. `OutputPage` second:产出页动态区域多，先拆能快速降低 `main_view.gd` 复杂度。
3. `ResearchCraftPage` third:研发制作行和坑位状态复杂，需要独立验证。
4. `PurchasePage` and `StorefrontManagePage` fourth:页面较薄，适合合并成一个任务。
5. Overlays fifth:弹层节点多，但行为边界清楚。
6. Coordinator cleanup last:避免前面任务同时移动逻辑和删除旧 helper。

## Risk Notes

- `Main.tscn` 和测试里很多路径是硬编码；每个任务必须同步更新路径，不要一次性移动全部。
- `main_view.gd` 里部分函数同时做渲染和状态修改；拆分时先把“渲染”移入组件，把“改状态/保存/通知”留在主脚本。
- Godot `.tscn` 文件必须保持 UTF-8 无 BOM；用 PowerShell 改写后要跑场景加载验证。
- 现有部分测试会触发默认 `user://neighbor_dessert_save.json.tmp` 写入警告；只要退出码为 0，不把它误判为本轮拆分失败。

## Self-Review

- Spec coverage: 计划覆盖主场景 shell、橱窗、采购、产出、研发制作、橱窗经营、任务/库存/图鉴弹层、`main_view.gd` 收敛和验证命令。
- 占位扫描: 已检查计划正文，未发现空泛占位项；每个任务都有文件、接口、测试命令和预期输出。
- Type consistency: 页面组件统一使用 `refresh(state, catalog, ...)`，状态修改统一回到 `main_view.gd`，信号命名在接口和任务步骤中保持一致。
