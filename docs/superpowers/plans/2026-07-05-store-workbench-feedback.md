# Store Workbench Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single-screen layout where the storefront stays visible above the workbench and production-to-sale feedback is obvious.

**Architecture:** Keep core economy rules in `ShopSimulation`, `GameState`, `RecipeBook`, and `ProductionSite`. Move the main scene shell from left-nav pages to a fixed top bar, a 40% storefront area, and a 60% workbench area with vertical tabs. `main_view.gd` remains the UI coordinator and gains focused refresh helpers for storefront, cashier feedback, and top global popups.

**Tech Stack:** Godot 4.6 GDScript, `.tscn` static scene layout, existing `tests/mvp_self_check.gd` headless gate.

---

## File Structure

- Modify: `tests/mvp_self_check.gd`
  - Extend ready-path checks for the new top buttons, storefront nodes, vertical workbench tabs, persistent storefront visibility, and sale feedback.
- Modify: `scenes/Main.tscn`
  - Replace `Root/Body/NavPanel` with a fixed `Root/Body/MainArea` layout containing `StorefrontPanel` and `WorkbenchPanel`.
  - Add top buttons `TaskButton`, `InventoryButton`, and `CatalogButton`.
  - Add `GlobalPopup` and `GlobalPopupText` for global entry content.
- Modify: `scripts/main_view.gd`
  - Update `@onready` paths.
  - Remove `橱窗 / 图鉴 / 升级` from the workbench tab set.
  - Add storefront refresh helpers.
  - Add top button popup handlers for `任务 / 库存 / 图鉴`.
  - Update production sale flow to refresh storefront and cashier feedback.
- Reference only: `docs/superpowers/specs/2026-07-05-store-workbench-feedback-design.zh.md`
  - Source of layout and behavior requirements.

## Task 1: Lock The New Scene Shell In Self-Check

**Files:**
- Modify: `tests/mvp_self_check.gd`

- [ ] **Step 1: Write the failing scene-structure test**

In `_expect_main_scene_structure()`, replace the old nav paths in `required_paths` with the new shell paths:

```gdscript
var required_paths: Array[String] = [
	"Root",
	"Root/TopBar",
	"Root/TopBar/CoinsLabel",
	"Root/TopBar/ReputationLabel",
	"Root/TopBar/LevelLabel",
	"Root/TopBar/TaskButton",
	"Root/TopBar/InventoryButton",
	"Root/TopBar/CatalogButton",
	"Root/Body",
	"Root/Body/MainArea",
	"Root/Body/MainArea/StorefrontPanel",
	"Root/Body/MainArea/StorefrontPanel/DoorAnimationPanel",
	"Root/Body/MainArea/StorefrontPanel/DoorAnimationPanel/DoorFeedbackLabel",
	"Root/Body/MainArea/StorefrontPanel/ShowcasePanel",
	"Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid",
	"Root/Body/MainArea/StorefrontPanel/CashierPanel",
	"Root/Body/MainArea/StorefrontPanel/CashierPanel/CashierFeedback",
	"Root/Body/MainArea/WorkbenchPanel",
	"Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs",
	"Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs/PurchaseButton",
	"Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs/OutputButton",
	"Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs/ResearchButton",
	"Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs/ProductionButton",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/PageTitle",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/PageDescription",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/PurchaseCategoryTabs",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/OutputSiteTabs",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/PrimaryList",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/SecondaryList",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow/ActiveOutputGrid",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow/OutputBagPanel",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow/OutputBagPanel/OutputBagTabs",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow/OutputBagPanel/UnlockedOutputGrid",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/OutputContextMenu",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/SiteOptions",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/ItemOptions",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/RecipeOptions",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/SlotOptions",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/PrimaryActionButton",
	"Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/SecondaryActionButton",
	"Root/StatusBar",
	"Root/StatusBar/StatusLabel",
	"TaskPopup",
	"GlobalPopup",
	"GlobalPopup/GlobalPopupText"
]
```

After `root.call("_ready")`, add these assertions:

```gdscript
var main_area: VBoxContainer = root.get_node("Root/Body/MainArea")
var storefront_panel: HBoxContainer = root.get_node("Root/Body/MainArea/StorefrontPanel")
var workbench_panel: HBoxContainer = root.get_node("Root/Body/MainArea/WorkbenchPanel")
var door_panel: VBoxContainer = root.get_node("Root/Body/MainArea/StorefrontPanel/DoorAnimationPanel")
var showcase_panel: VBoxContainer = root.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel")
var cashier_panel: VBoxContainer = root.get_node("Root/Body/MainArea/StorefrontPanel/CashierPanel")
var workbench_tabs: VBoxContainer = root.get_node("Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs")
var task_button: Button = root.get_node("Root/TopBar/TaskButton")
var inventory_button: Button = root.get_node("Root/TopBar/InventoryButton")
var global_catalog_button: Button = root.get_node("Root/TopBar/CatalogButton")

if main_area == null:
	_fail("MainArea should be a VBoxContainer")
if storefront_panel == null:
	_fail("StorefrontPanel should be an HBoxContainer")
if workbench_panel == null:
	_fail("WorkbenchPanel should be an HBoxContainer")
if door_panel == null:
	_fail("DoorAnimationPanel should be a VBoxContainer")
if showcase_panel == null:
	_fail("ShowcasePanel should be a VBoxContainer")
if cashier_panel == null:
	_fail("CashierPanel should be a VBoxContainer")
if workbench_tabs == null:
	_fail("WorkbenchTabs should be a VBoxContainer")
if task_button.text != "任务":
	_fail("TaskButton text should be 任务")
if inventory_button.text != "库存":
	_fail("InventoryButton text should be 库存")
if global_catalog_button.text != "图鉴":
	_fail("CatalogButton text should be 图鉴")
if door_panel.size_flags_stretch_ratio != 15.0:
	_fail("DoorAnimationPanel stretch ratio should be 15")
if showcase_panel.size_flags_stretch_ratio != 60.0:
	_fail("ShowcasePanel stretch ratio should be 60")
if cashier_panel.size_flags_stretch_ratio != 25.0:
	_fail("CashierPanel stretch ratio should be 25")
if storefront_panel.size_flags_stretch_ratio != 40.0:
	_fail("StorefrontPanel stretch ratio should be 40")
if workbench_panel.size_flags_stretch_ratio != 60.0:
	_fail("WorkbenchPanel stretch ratio should be 60")

var expected_tab_names: Array[String] = ["PurchaseButton", "OutputButton", "ResearchButton", "ProductionButton"]
if workbench_tabs.get_child_count() != expected_tab_names.size():
	_fail("WorkbenchTabs should contain exactly four workbench tab buttons")
for index in range(expected_tab_names.size()):
	var child := workbench_tabs.get_child(index)
	if child.name != expected_tab_names[index]:
		_fail("Workbench tab %d expected %s, got %s" % [index, expected_tab_names[index], child.name])
```

- [ ] **Step 2: Run the self-check to verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL with missing node paths such as `Root/TopBar/TaskButton` or `Root/Body/MainArea/StorefrontPanel`.

- [ ] **Step 3: Commit the failing test**

```powershell
git add -- tests/mvp_self_check.gd
git commit -m "test: lock storefront workbench scene shell"
```

## Task 2: Rebuild The Static Main Scene Layout

**Files:**
- Modify: `scenes/Main.tscn`

- [ ] **Step 1: Update the scene shell**

Edit `scenes/Main.tscn` so the static hierarchy matches the Task 1 paths. Use these layout values:

```ini
[node name="TaskButton" type="Button" parent="Root/TopBar"]
layout_mode = 2
custom_minimum_size = Vector2(82, 34)
text = "任务"

[node name="InventoryButton" type="Button" parent="Root/TopBar"]
layout_mode = 2
custom_minimum_size = Vector2(82, 34)
text = "库存"

[node name="CatalogButton" type="Button" parent="Root/TopBar"]
layout_mode = 2
custom_minimum_size = Vector2(82, 34)
text = "图鉴"

[node name="MainArea" type="VBoxContainer" parent="Root/Body"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 8

[node name="StorefrontPanel" type="HBoxContainer" parent="Root/Body/MainArea"]
layout_mode = 2
size_flags_vertical = 3
size_flags_stretch_ratio = 40.0
theme_override_constants/separation = 8

[node name="DoorAnimationPanel" type="VBoxContainer" parent="Root/Body/MainArea/StorefrontPanel"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
size_flags_stretch_ratio = 15.0
theme_override_constants/separation = 6

[node name="DoorFeedbackLabel" type="Label" parent="Root/Body/MainArea/StorefrontPanel/DoorAnimationPanel"]
layout_mode = 2
size_flags_vertical = 3
text = "店门待开"
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 2

[node name="ShowcasePanel" type="VBoxContainer" parent="Root/Body/MainArea/StorefrontPanel"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
size_flags_stretch_ratio = 60.0
theme_override_constants/separation = 6

[node name="ShowcaseTitle" type="Label" parent="Root/Body/MainArea/StorefrontPanel/ShowcasePanel"]
layout_mode = 2
text = "橱窗"
horizontal_alignment = 1

[node name="ShowcaseGrid" type="GridContainer" parent="Root/Body/MainArea/StorefrontPanel/ShowcasePanel"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/h_separation = 8
theme_override_constants/v_separation = 8
columns = 5

[node name="CashierPanel" type="VBoxContainer" parent="Root/Body/MainArea/StorefrontPanel"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
size_flags_stretch_ratio = 25.0
theme_override_constants/separation = 6

[node name="CashierTitle" type="Label" parent="Root/Body/MainArea/StorefrontPanel/CashierPanel"]
layout_mode = 2
text = "收银台"
horizontal_alignment = 1

[node name="CashierFeedback" type="RichTextLabel" parent="Root/Body/MainArea/StorefrontPanel/CashierPanel"]
layout_mode = 2
size_flags_vertical = 3
bbcode_enabled = true
fit_content = true
scroll_active = false
text = "等待营业"

[node name="WorkbenchPanel" type="HBoxContainer" parent="Root/Body/MainArea"]
layout_mode = 2
size_flags_vertical = 3
size_flags_stretch_ratio = 60.0
theme_override_constants/separation = 8

[node name="WorkbenchTabs" type="VBoxContainer" parent="Root/Body/MainArea/WorkbenchPanel"]
layout_mode = 2
custom_minimum_size = Vector2(112, 0)
theme_override_constants/separation = 8
```

Move the existing `PurchaseButton`, `OutputButton`, `ResearchButton`, and `ProductionButton` under `Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs`. Move the existing `ContentPanel` under `Root/Body/MainArea/WorkbenchPanel`. Remove `ShowcaseButton`, `UpgradeButton`, and the old `FeedbackPanel` from the scene.

Add the global popup:

```ini
[node name="GlobalPopup" type="AcceptDialog" parent="."]
title = "信息"
dialog_text = ""

[node name="GlobalPopupText" type="RichTextLabel" parent="GlobalPopup"]
layout_mode = 2
custom_minimum_size = Vector2(520, 340)
bbcode_enabled = true
fit_content = true
text = ""
```

- [ ] **Step 2: Run the self-check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL in `main_view.gd` ready path because its `@onready` paths still point at the old `Root/Body/NavPanel` and `Root/Body/ContentPanel` hierarchy.

- [ ] **Step 3: Commit the static scene layout**

```powershell
git add -- scenes/Main.tscn
git commit -m "feat: add storefront workbench scene shell"
```

## Task 3: Rebind Main View To The New Shell

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`

- [ ] **Step 1: Write failing behavior checks for persistent storefront**

In `_expect_main_scene_structure()`, update local node lookups to the new paths and add persistence checks after each workbench tab switch:

```gdscript
var output_tabs: TabBar = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/OutputSiteTabs")
var list_row: HSplitContainer = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow")
var output_grid_row: HSplitContainer = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow")
var active_output_grid: GridContainer = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow/ActiveOutputGrid")
var output_bag_tabs: TabBar = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow/OutputBagPanel/OutputBagTabs")
var unlocked_output_grid: GridContainer = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow/OutputBagPanel/UnlockedOutputGrid")
var output_context_menu: PopupMenu = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/OutputContextMenu")
var primary_list: ItemList = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/PrimaryList")
var secondary_list: ItemList = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/SecondaryList")
var recipe_options: OptionButton = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/RecipeOptions")
var slot_options: OptionButton = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/SlotOptions")
var primary_action_button: Button = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/PrimaryActionButton")
var secondary_action_button: Button = root.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/SecondaryActionButton")
var storefront: HBoxContainer = root.get_node("Root/Body/MainArea/StorefrontPanel")

for page in ["purchase", "output", "research", "production"]:
	root.call("_show_page", page)
	if not storefront.visible:
		_fail("storefront should stay visible when workbench page is %s" % page)
```

Replace old assertions for `showcase`, `catalog`, and `upgrade` workbench pages with top popup tests in Task 5.

- [ ] **Step 2: Run the self-check to verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL because `main_view.gd` still binds old node paths.

- [ ] **Step 3: Update `@onready` paths and signal wiring**

In `scripts/main_view.gd`, replace the top node bindings with:

```gdscript
@onready var coins_label: Label = $Root/TopBar/CoinsLabel
@onready var reputation_label: Label = $Root/TopBar/ReputationLabel
@onready var level_label: Label = $Root/TopBar/LevelLabel
@onready var task_button: Button = $Root/TopBar/TaskButton
@onready var inventory_button: Button = $Root/TopBar/InventoryButton
@onready var catalog_button: Button = $Root/TopBar/CatalogButton
@onready var purchase_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs/PurchaseButton
@onready var output_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs/OutputButton
@onready var research_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs/ResearchButton
@onready var production_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchTabs/ProductionButton
@onready var door_feedback_label: Label = $Root/Body/MainArea/StorefrontPanel/DoorAnimationPanel/DoorFeedbackLabel
@onready var showcase_grid: GridContainer = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid
@onready var cashier_feedback: RichTextLabel = $Root/Body/MainArea/StorefrontPanel/CashierPanel/CashierFeedback
@onready var page_title: Label = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/PageTitle
@onready var page_description: RichTextLabel = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/PageDescription
@onready var purchase_category_tabs: TabBar = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/PurchaseCategoryTabs
@onready var output_site_tabs: TabBar = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/OutputSiteTabs
@onready var site_options: OptionButton = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/SiteOptions
@onready var item_options: OptionButton = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/ItemOptions
@onready var recipe_options: OptionButton = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/RecipeOptions
@onready var slot_options: OptionButton = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/OptionRow/SlotOptions
@onready var primary_list: ItemList = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/PrimaryList
@onready var secondary_list: ItemList = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/SecondaryList
@onready var output_grid_row: HSplitContainer = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow
@onready var active_output_grid: GridContainer = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow/ActiveOutputGrid
@onready var output_bag_tabs: TabBar = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow/OutputBagPanel/OutputBagTabs
@onready var unlocked_output_grid: GridContainer = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/OutputGridRow/OutputBagPanel/UnlockedOutputGrid
@onready var output_context_menu: PopupMenu = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/OutputContextMenu
@onready var primary_action_button: Button = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/PrimaryActionButton
@onready var secondary_action_button: Button = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/SecondaryActionButton
@onready var status_label: Label = $Root/StatusBar/StatusLabel
@onready var task_popup: AcceptDialog = $TaskPopup
@onready var global_popup: AcceptDialog = $GlobalPopup
@onready var global_popup_text: RichTextLabel = $GlobalPopup/GlobalPopupText
```

In `_ready()`, remove old `showcase_button` and `upgrade_button` connections. Add:

```gdscript
task_button.pressed.connect(_show_task_global_popup)
inventory_button.pressed.connect(_show_inventory_global_popup)
catalog_button.pressed.connect(_show_catalog_global_popup)
```

Remove `PAGE_SHOWCASE`, `PAGE_CATALOG`, and `PAGE_UPGRADE` from workbench navigation handling. Keep constants only if a task still uses them; otherwise remove their match branches from `_refresh_current_page()` and `_set_navigation_pressed()`.

- [ ] **Step 4: Run the self-check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL on missing storefront refresh helpers and global popup handlers.

- [ ] **Step 5: Commit the rebinding**

```powershell
git add -- scripts/main_view.gd tests/mvp_self_check.gd
git commit -m "feat: bind main view to storefront workbench shell"
```

## Task 4: Add Storefront Refresh And Sale Feedback

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`

- [ ] **Step 1: Write failing sale-feedback assertions**

In `_expect_main_scene_structure()`, after the existing production sale setup, add:

```gdscript
var showcase_grid: GridContainer = root.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid")
var door_feedback_label: Label = root.get_node("Root/Body/MainArea/StorefrontPanel/DoorAnimationPanel/DoorFeedbackLabel")
var cashier_feedback: RichTextLabel = root.get_node("Root/Body/MainArea/StorefrontPanel/CashierPanel/CashierFeedback")

root.set("state", production_sale_state)
root.call("_show_page", "production")
if not _select_option_by_metadata(recipe_options, "sponge_cake"):
	_fail("production page should expose sponge_cake recipe option")
else:
	var stock_before_sale: int = production_sale_state.get_product_count("sponge_cake")
	var coins_before_sale: int = production_sale_state.coins
	root.call("_on_secondary_action")
	if production_sale_state.get_product_count("sponge_cake") >= stock_before_sale:
		_fail("production listing should immediately sell stocked sponge_cake")
	if production_sale_state.coins <= coins_before_sale:
		_fail("production listing sale should increase coins")
	if showcase_grid.get_child_count() == 0:
		_fail("storefront showcase grid should render display slots after listing")
	if not _grid_text_contains(showcase_grid, "海绵杯蛋糕"):
		_fail("storefront showcase should display listed sponge cake")
	if door_feedback_label.text.find("开门") == -1 and door_feedback_label.text.find("营业") == -1:
		_fail("door feedback should show a business trigger message, got %s" % door_feedback_label.text)
	if cashier_feedback.text.find("售出") == -1:
		_fail("cashier feedback should show sold count, got %s" % cashier_feedback.text)
	if cashier_feedback.text.find("金币") == -1:
		_fail("cashier feedback should show coin change, got %s" % cashier_feedback.text)
	if cashier_feedback.text.find("口碑") == -1:
		_fail("cashier feedback should show reputation change, got %s" % cashier_feedback.text)
```

Add this helper near other test helpers:

```gdscript
func _grid_text_contains(grid: GridContainer, expected: String) -> bool:
	for child in grid.get_children():
		if child is Button and (child as Button).text.find(expected) != -1:
			return true
		if child is Label and (child as Label).text.find(expected) != -1:
			return true
	return false
```

- [ ] **Step 2: Run the self-check to verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL because storefront display and cashier feedback are not implemented.

- [ ] **Step 3: Add storefront state and refresh helpers**

In `scripts/main_view.gd`, add this variable with the other UI state fields:

```gdscript
var last_business_feedback := {
	"recipe_name": "",
	"sold_count": 0,
	"earned_coins": 0,
	"earned_reputation": 0,
	"triggered": false
}
```

Add these helpers:

```gdscript
func _refresh_storefront() -> void:
	_refresh_storefront_showcase()
	_refresh_cashier_feedback()


func _refresh_storefront_showcase() -> void:
	_clear_children(showcase_grid)
	for index in range(state.display_slots.size()):
		var displayed: Variant = state.display_slots[index]
		if displayed == null:
			showcase_grid.add_child(_make_storefront_slot_button("槽位 %d\n空" % (index + 1), "暂无上架商品"))
			continue

		var recipe_id := String(displayed)
		var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
		var recipe_name := String(recipe.get("name", recipe_id))
		var stock := state.get_product_count(recipe_id)
		var price := int(recipe.get("price", 0))
		var tags_value: Variant = recipe.get("tags", [])
		var tags_text := ""
		if tags_value is Array:
			var tag_names: Array[String] = []
			for tag in tags_value:
				tag_names.append(String(tag))
			tags_text = "、".join(tag_names)
		var tooltip := "名称：%s\n售价：%d\n库存：%d\n标签：%s\n最近售卖：%s" % [
			recipe_name,
			price,
			stock,
			tags_text,
			_recent_sale_text(recipe_name)
		]
		showcase_grid.add_child(_make_storefront_slot_button("%s\n库存:%d" % [recipe_name, stock], tooltip))


func _make_storefront_slot_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(108, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.disabled = true
	return button


func _recent_sale_text(recipe_name: String) -> String:
	if not bool(last_business_feedback.get("triggered", false)):
		return "暂无营业"
	if String(last_business_feedback.get("recipe_name", "")) != recipe_name:
		return "本轮未售出"
	var sold_count := int(last_business_feedback.get("sold_count", 0))
	if sold_count <= 0:
		return "本轮未售出"
	return "本轮售出 %d 份" % sold_count


func _refresh_cashier_feedback() -> void:
	if not bool(last_business_feedback.get("triggered", false)):
		door_feedback_label.text = "店门待开"
		cashier_feedback.text = "等待营业"
		return

	var sold_count := int(last_business_feedback.get("sold_count", 0))
	var earned_coins := int(last_business_feedback.get("earned_coins", 0))
	var earned_reputation := int(last_business_feedback.get("earned_reputation", 0))
	door_feedback_label.text = "店门已开\n完成一次营业"
	cashier_feedback.text = "收银台 1\n售出 %d 份\n金币 +%d\n口碑 +%d" % [
		sold_count,
		earned_coins,
		earned_reputation
	]


func _record_business_feedback(recipe_id: String, sale_result: Dictionary) -> void:
	last_business_feedback = {
		"recipe_name": _recipe_name(recipe_id),
		"sold_count": int(sale_result.get("sold_count", 0)),
		"earned_coins": int(sale_result.get("earned_coins", 0)),
		"earned_reputation": int(sale_result.get("earned_reputation", 0)),
		"triggered": true
	}
	_refresh_storefront()
```

Call `_refresh_storefront()` at the end of `_refresh_current_page()` after `_refresh_feedback_log()`:

```gdscript
_refresh_feedback_log()
_refresh_storefront()
```

In `_display_selected_product_from_production()`, after `ShopSimulation.run_business(state)`, call:

```gdscript
_record_business_feedback(recipe_id, sale_result)
```

- [ ] **Step 4: Run the self-check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS for storefront sale feedback assertions, or FAIL on exact text mismatches that should be fixed in the helper output.

- [ ] **Step 5: Commit storefront feedback**

```powershell
git add -- scripts/main_view.gd tests/mvp_self_check.gd
git commit -m "feat: show production sale feedback in storefront"
```

## Task 5: Add Top Global Popups For Tasks, Inventory, And Catalog

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`

- [ ] **Step 1: Write failing popup assertions**

In `_expect_main_scene_structure()`, add:

```gdscript
var global_popup: AcceptDialog = root.get_node("GlobalPopup")
var global_popup_text: RichTextLabel = root.get_node("GlobalPopup/GlobalPopupText")
root.call("_show_task_global_popup")
if global_popup.title != "任务":
	_fail("task global popup title should be 任务")
if global_popup_text.text.find("任务") == -1:
	_fail("task global popup should describe task status")

root.call("_show_inventory_global_popup")
if global_popup.title != "库存":
	_fail("inventory global popup title should be 库存")
if global_popup_text.text.find("库存") == -1:
	_fail("inventory global popup should describe inventory")

root.call("_show_catalog_global_popup")
if global_popup.title != "图鉴":
	_fail("catalog global popup title should be 图鉴")
if global_popup_text.text.find("配方") == -1:
	_fail("catalog global popup should describe recipes")
```

- [ ] **Step 2: Run the self-check to verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL because the `_show_*_global_popup` methods do not exist.

- [ ] **Step 3: Add popup handlers and text builders**

In `scripts/main_view.gd`, add:

```gdscript
func _show_task_global_popup() -> void:
	_show_global_popup("任务", _task_global_text())


func _show_inventory_global_popup() -> void:
	_show_global_popup("库存", _inventory_global_text())


func _show_catalog_global_popup() -> void:
	_show_global_popup("图鉴", _catalog_global_text())


func _show_global_popup(title: String, body: String) -> void:
	global_popup.title = title
	global_popup_text.text = body
	global_popup.popup_centered(Vector2i(560, 420))


func _task_global_text() -> String:
	var lines: Array[String] = ["任务"]
	if state.completed_tasks.is_empty():
		lines.append("已完成：暂无")
	else:
		lines.append("已完成：%s" % "、".join(state.completed_tasks))
	if state.pending_notifications.is_empty():
		lines.append("待领取提示：暂无")
	else:
		lines.append("待领取提示：%d 条" % state.pending_notifications.size())
	return "\n".join(lines)


func _inventory_global_text() -> String:
	var lines: Array[String] = ["库存", "食材"]
	for item_id in _sorted_keys(state.ingredient_inventory):
		lines.append("%s x%d" % [_ingredient_name(item_id), state.get_ingredient_count(item_id)])
	lines.append("成品")
	for recipe_id in _sorted_keys(state.product_inventory):
		lines.append("%s x%d" % [_recipe_name(recipe_id), state.get_product_count(recipe_id)])
	lines.append("工具")
	for tool_id in _sorted_keys(state.tool_inventory):
		var tool: Dictionary = catalog.get_tools().get(tool_id, {})
		lines.append("%s x%d" % [String(tool.get("name", tool_id)), state.get_tool_count(tool_id)])
	return "\n".join(lines)


func _catalog_global_text() -> String:
	var lines: Array[String] = ["图鉴", "配方"]
	var recipes := catalog.get_recipes()
	for recipe_id in _sorted_keys(recipes):
		var recipe: Dictionary = recipes[recipe_id]
		var unlock_text := "已解锁" if state.is_recipe_unlocked(recipe_id) else "未解锁"
		lines.append("%s [%s] Lv.%d" % [
			String(recipe.get("name", recipe_id)),
			unlock_text,
			int(recipe.get("unlock_level", 1))
		])
	return "\n".join(lines)
```

- [ ] **Step 4: Run the self-check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS for popup assertions.

- [ ] **Step 5: Commit global popups**

```powershell
git add -- scripts/main_view.gd tests/mvp_self_check.gd
git commit -m "feat: add top global task inventory catalog popups"
```

## Task 6: Remove Old Page Assumptions And Verify End To End

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`
- Modify: `docs/superpowers/specs/2026-07-05-store-workbench-feedback-design.zh.md` only if implementation discovers a design mismatch.

- [ ] **Step 1: Search for obsolete shell paths**

Run:

```powershell
rg -n "Root/Body/NavPanel|Root/Body/ContentPanel|FeedbackPanel|ShowcaseButton|UpgradeButton|PAGE_SHOWCASE|PAGE_UPGRADE" scripts scenes tests
```

Expected: no matches, except historical docs outside `scripts`, `scenes`, and `tests`.

- [ ] **Step 2: Search for obsolete top entry wording in the active spec**

Run:

```powershell
rg -n "装备|任务.*图鉴.*装备" docs/superpowers/specs/2026-07-05-store-workbench-feedback-design.zh.md
```

Expected: no matches.

- [ ] **Step 3: Run parser validation**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --quit
```

Expected: exit code 0 with no GDScript parser errors.

- [ ] **Step 4: Run full MVP self-check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: output contains `MVP_SELF_CHECK_PASS`.

- [ ] **Step 5: Commit final cleanup**

```powershell
git add -- scripts/main_view.gd scenes/Main.tscn tests/mvp_self_check.gd docs/superpowers/specs/2026-07-05-store-workbench-feedback-design.zh.md
git commit -m "test: verify storefront workbench feedback flow"
```

- [ ] **Step 6: Report final status**

Report:

```text
Implemented storefront/workbench split.
Verified with:
- Godot parser validation
- tests/mvp_self_check.gd -> MVP_SELF_CHECK_PASS
```

Also report if Git commit was blocked by a live `.git/index.lock`, and include the exact command output.
