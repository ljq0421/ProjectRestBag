# Production Queue and Recipe Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把右侧制作区改为常驻制作队列，为每个配方提供三个纵向真实批次槽，并把“可制作 / 缺材料”移入复用全局外壳的配方选择弹窗，同时把每配方并发上限和自动排程批量统一为三批契约。

**Architecture:** `GameState` 继续持有唯一制作队列与容量规则；`main_view.gd` 只编排结算、弹窗模式、业务操作和刷新顺序；稳定布局全部落在 `.tscn`；新增组件脚本只接收视图字典、渲染节点并发出意图信号，不复制材料、库存、队列或补货业务规则。

**Tech Stack:** Godot 4.6.1、GDScript、`.tscn` 场景、现有 Neighborhood Dessert Theme、Godot `SceneTree` headless self-check。

**Global Constraints:**

- 目标仓库固定为 `D:\Project\ProjectRest\project-rest-new`。
- 保留工作区中与本任务无关的配方图片、图标配置和文档改动；每次提交只暂存本任务文件。
- 不添加旧存档迁移、四至九批截断、退款或超额队列兼容。
- 不改变制作时长、材料开始时扣除、完成时入库、离线完成或营业速度独立等既有契约。
- 加工项目继续即时完成，不进入 `recipe_production_queue`。
- Godot headless 命令必须带可写的日志路径，例如 `--log-file "$env:TEMP\production-queue.log"`，不得使用 `NUL`。

---

## File and Responsibility Map

### Existing files to modify

- `scripts/game_state.gd:21,1598-1784,2592-2640`
  - 三批容量、自动 `1 / 3` 校验、队列摘要来源字段、存档数据清洗。
- `scripts/automation_service.gd:133-166,265-313,316-425`
  - 自动三批原子启动、规则保存校验、完成报告。
- `scripts/ui/pages/kitchen_automation_panel.gd:109-117`
  - 批量选项从 `1 / 5` 改为 `1 / 3`。
- `scenes/ui/pages/production_workbench.tscn`
  - 用标题、队列滚动区和双入口替换内联排程与配方长列表。
- `scenes/main.tscn:1-29,262-347`
  - 注册配方选择与厨房排程两个全局弹窗模式。
- `scripts/main_view.gd:43-60,153-164,400-515,536-615,2774-2791,3743-3990,4076-4207,4514-4550,4782-4792,8811-9051,10376-10412`
  - 业务编排、模式注册、真实操作、教程目标和刷新顺序。
- `tests/recipe_production_timing_self_check.gd`
  - 三批共享容量、第四批拒绝、自动三批和摘要来源。
- `tests/recipe_production_ui_self_check.gd`
  - 从旧九进度条行测试改为常驻三槽队列行为测试。
- `tests/automation_settlement_self_check.gd`
  - 自动三批规则与原子容量测试。
- `tests/research_overlay_production_workbench_self_check.gd`
  - 更新右栏结构契约。
- `tests/tutorial_guide_route_self_check.gd`
  - 更新制作和上架教程的两段真实目标。
- `tests/component_contract_self_check.gd`
  - 注册新增组件场景。

### New files

- `scenes/ui/pages/production_queue_recipe_row.tscn`
- `scripts/ui/pages/production_queue_recipe_row.gd`
  - 单个配方组和三个固定批次槽。
- `scripts/ui/pages/production_workbench.gd`
  - 常驻队列渲染、双入口数量与意图信号。
- `scenes/ui/overlays/production_recipe_picker_overlay.tscn`
- `scripts/ui/overlays/production_recipe_picker_overlay.gd`
  - 双页签、搜索、三列卡片和页脚批量操作。
- `scenes/ui/overlays/production_recipe_card.tscn`
- `scripts/ui/overlays/production_recipe_card.gd`
  - 配方/加工卡片显示与单项操作信号。
- `scenes/ui/overlays/kitchen_schedule_overlay.tscn`
- `scripts/ui/overlays/kitchen_schedule_overlay.gd`
  - 承载现有 `KitchenAutomationPanel`。
- `tests/production_queue_scene_self_check.gd`
  - 右栏和三槽场景结构。
- `tests/production_recipe_picker_self_check.gd`
  - 分类、弹窗刷新和单项/批量操作。
- `tests/production_queue_interaction_self_check.gd`
  - 真实鼠标输入、遮罩、教程和弹窗保持打开。

### Files to retire only after zero-reference proof

- `scenes/ui/pages/recipe_action_row.tscn`
- `scripts/ui/pages/recipe_action_row.gd`
- `scenes/ui/pages/research_craft_page.tscn`
- `scripts/ui/pages/research_craft_page.gd`

These four files are deleted only in the final cleanup task after a repository search proves that no scene, script, or test still references them.

---

## Task 1: Lock the Three-Batch Domain Contract

**Files:**

- Modify: `tests/recipe_production_timing_self_check.gd:31-148`
- Modify: `tests/automation_settlement_self_check.gd:335-425`
- Modify: `scripts/game_state.gd:21,1598-1639,1698-1749,2592-2640`
- Modify: `scripts/automation_service.gd:396-425`
- Modify: `scripts/ui/pages/kitchen_automation_panel.gd:109-117`

- [ ] **Step 1: Rewrite the focused timing assertions before production code**

Replace the nine-batch fixtures with these explicit cases:

```gdscript
func _test_single_recipe_batch_limit() -> void:
	var state = _ready_state()
	for batch_index in range(3):
		_expect(
			state.queue_recipe_production("rice_milk_drink", 1, 1000 + batch_index, "manual"),
			"manual batch %d should fit" % (batch_index + 1)
		)
	var rice_before_fourth := state.get_ingredient_count("rice")
	var water_before_fourth := state.get_ingredient_count("spring_water")
	_expect(
		not state.queue_recipe_production("rice_milk_drink", 1, 1003, "manual"),
		"fourth manual batch should be rejected"
	)
	_expect_equal("fourth rejection keeps rice", state.get_ingredient_count("rice"), rice_before_fourth)
	_expect_equal("fourth rejection keeps water", state.get_ingredient_count("spring_water"), water_before_fourth)
	_expect(
		state.queue_recipe_production("rich_rice_drink", 1, 1003, "manual"),
		"different recipes should keep independent capacity"
	)
```

Add a shared-capacity fixture:

```gdscript
var shared_state = _ready_state()
_expect(shared_state.queue_recipe_production("rice_milk_drink", 1, 1000, "manual"), "manual slot should start")
_expect(
		not shared_state.queue_recipe_production("rice_milk_drink", 3, 1001, "automation", "rule_three"),
		"automation three should reject atomically when only two slots remain"
)
_expect_equal("rejected automation keeps one queue", shared_state.recipe_production_queue.size(), 1)
```

Update the summary fixture to use an automatic three-batch task and assert every `batch_progress` item contains:

```gdscript
_expect_equal("automation source", String(batch.get("source", "")), "automation")
_expect_equal("automation rule id", String(batch.get("automation_rule_id", "")), "rule_three")
```

- [ ] **Step 2: Run the rewritten timing test and confirm the intended failure**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\recipe-production-three-red.log" `
  -s res://tests/recipe_production_timing_self_check.gd
```

Expected: non-zero exit; failures mention the old nine-batch limit, rejected automatic three batches, or missing `source`.

- [ ] **Step 3: Change the authoritative capacity and accepted batch sizes**

In `scripts/game_state.gd`:

```gdscript
const MAX_CONCURRENT_RECIPE_BATCHES := 3
```

In `queue_recipe_production()` and `_sanitize_kitchen_automation_rules()`:

```gdscript
if clean_source == "automation" and batches not in [1, 3]:
	return false
```

```gdscript
if batches not in [1, 3]:
	batches = 1
```

Do not add migration logic around existing queue entries.

- [ ] **Step 4: Expose source identity from the queue summary**

Add the fields to every generated batch:

```gdscript
batch_progress.append({
	"queue_sequence": queue_sequence,
	"batch_index": batch_index,
	"started_at_unix": started_at_unix,
	"ready_at_unix": ready_at_unix,
	"duration_seconds": duration_seconds,
	"remaining_seconds": maxi(0, ready_at_unix - current_time),
	"progress": progress,
	"source": String(queued.get("source", "manual")),
	"automation_rule_id": String(queued.get("automation_rule_id", ""))
})
```

Keep sorting by stable identity. Change `_recipe_batch_progress_less()` so the primary key is `queue_sequence`, followed by `batch_index`; do not use remaining seconds:

```gdscript
func _recipe_batch_progress_less(first: Dictionary, second: Dictionary) -> bool:
	var first_sequence := int(first.get("queue_sequence", 0))
	var second_sequence := int(second.get("queue_sequence", 0))
	if first_sequence != second_sequence:
		return first_sequence < second_sequence
	return int(first.get("batch_index", 0)) < int(second.get("batch_index", 0))
```

- [ ] **Step 5: Make rule saving and the editor use `1 / 3`**

In `scripts/automation_service.gd`:

```gdscript
if batches not in [1, 3]:
	return {}
```

In `scripts/ui/pages/kitchen_automation_panel.gd`:

```gdscript
for batches in [1, 3]:
	batch_option.add_item("每轮 %d 批" % batches)
	batch_option.set_item_metadata(batch_option.item_count - 1, batches)
```

- [ ] **Step 6: Add an automation service assertion for atomic three-batch start**

In `tests/automation_settlement_self_check.gd`, save a three-batch kitchen rule, leave two slots free, call `AutomationService.settle()`, and assert:

```gdscript
_expect_equal("three-batch rule does not partially start", state.recipe_production_queue.size(), 1)
_expect_equal("three-batch rejection keeps milk", state.get_ingredient_count("milk"), milk_before)
_expect_equal(
	"capacity pause reason",
	String(AutomationService.kitchen_rule_status(state, "rule_three").get("reason", {}).get("code", "")),
	"capacity_reached"
)
```

Update `_rule_start_reason()` to check capacity before materials:

```gdscript
if state.active_recipe_production_batch_count(recipe_id) + batches > GameState.MAX_CONCURRENT_RECIPE_BATCHES:
	return {"code": "capacity_reached", "first_stopped_at_unix": now_unix}
```

Add `const GameState = preload("res://scripts/game_state.gd")` to `automation_service.gd`.

- [ ] **Step 7: Run the domain tests**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-production-three.log" -s res://tests/recipe_production_timing_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\automation-three.log" -s res://tests/automation_settlement_self_check.gd
```

Expected:

- `RECIPE_PRODUCTION_TIMING_SELF_CHECK_PASS`
- `AUTOMATION_SETTLEMENT_SELF_CHECK_PASS`

- [ ] **Step 8: Commit only the domain-contract files**

```powershell
git add scripts/game_state.gd scripts/automation_service.gd scripts/ui/pages/kitchen_automation_panel.gd tests/recipe_production_timing_self_check.gd tests/automation_settlement_self_check.gd
git commit -m "feat: limit recipe production to three batches"
```

---

## Task 2: Build the Scene-First Persistent Queue

**Files:**

- Create: `scenes/ui/pages/production_queue_recipe_row.tscn`
- Create: `scripts/ui/pages/production_queue_recipe_row.gd`
- Create: `scripts/ui/pages/production_workbench.gd`
- Modify: `scenes/ui/pages/production_workbench.tscn`
- Create: `tests/production_queue_scene_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`

- [ ] **Step 1: Write the scene contract test first**

The new test must instantiate `production_workbench.tscn` and assert:

```gdscript
_expect(workbench.get_node_or_null("ProductionQueueHeader") != null, "header must be declared")
_expect(workbench.get_node_or_null("ActiveQueueScroll/ActiveQueueRows") != null, "queue scroll must be declared")
_expect(workbench.get_node_or_null("RecipeEntryBar/CraftableRecipesButton") != null, "craftable entry must exist")
_expect(workbench.get_node_or_null("RecipeEntryBar/MissingMaterialsButton") != null, "missing entry must exist")
_expect(workbench.get_node_or_null("RecipeScroll") == null, "legacy recipe scroll must be absent")
_expect(workbench.get_node_or_null("KitchenAutomationPanel") == null, "inline scheduler must be absent")
```

Instantiate `production_queue_recipe_row.tscn` and assert exactly these stable slots exist:

```gdscript
for slot_name in ["BatchSlot1", "BatchSlot2", "BatchSlot3"]:
	_expect(row.get_node_or_null("Content/BatchSlots/%s" % slot_name) != null, "%s must exist" % slot_name)
_expect_equal("three declared slots", row.get_node("Content/BatchSlots").get_child_count(), 3)
```

Assert button stretch ratios are `3.0` and `2.0`, which is the exact layout representation of the approved `60 / 40`.

- [ ] **Step 2: Run the new test and confirm it fails because the scenes do not exist**

Run:

```powershell
Test-Path tests\production_queue_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-queue-scene-red.log" -s res://tests/production_queue_scene_self_check.gd
```

Expected: `Test-Path` is `True`; Godot exits non-zero because the new scene contract is not implemented.

- [ ] **Step 3: Declare the right-column hierarchy in the scene**

Replace the contents of `production_workbench.tscn` with this stable hierarchy:

```text
ProductionWorkbench (VBoxContainer, script)
├── ProductionQueueHeader (HBoxContainer, min height 54)
│   ├── TitleColumn
│   │   ├── QueueTitleLabel
│   │   └── QueueSummaryLabel
│   ├── AutomationPausedLabel
│   └── KitchenScheduleButton
├── ActiveQueueScroll (ScrollContainer, expand vertically)
│   └── ActiveQueueRows (VBoxContainer)
│       └── EmptyQueuePanel
│           ├── EmptyQueueLabel
│           └── EmptyQueueCraftableButton
└── RecipeEntryBar (HBoxContainer, min height 76)
    ├── CraftableRecipesButton (stretch 3)
    └── MissingMaterialsButton (stretch 2)
```

Use theme variations already present in the repository:

- `KitchenScheduleButton`: `DessertSecondaryButton`
- `CraftableRecipesButton`: `DessertRedButton`
- `MissingMaterialsButton`: `DessertSecondaryButton`

Do not create the repeated recipe rows in the scene; only the stable container and empty state belong there.

- [ ] **Step 4: Declare the three-slot recipe row**

The scene must declare:

```text
ProductionQueueRecipeRow (PanelContainer)
└── Content (HBoxContainer)
    ├── RecipeIcon (44×44)
    ├── RecipeSummary (VBoxContainer)
    │   ├── RecipeNameLabel
    │   ├── DeviceNameLabel
    │   └── BatchCountLabel
    └── BatchSlots (VBoxContainer)
        ├── BatchSlot1
        ├── BatchSlot2
        └── BatchSlot3
```

Each `BatchSlotN` declares the same children:

```text
SlotTopRow/BatchLabel
SlotTopRow/SourceLabel
SlotProgress
SlotBottomRow/RemainingLabel
SlotBottomRow/CompletionLabel
```

The empty state is expressed by `occupied = false`, `BatchLabel.text = "空闲"` and a muted `StyleBoxFlat`; no fourth slot may be created dynamically.

- [ ] **Step 5: Implement the row binding interface**

`scripts/ui/pages/production_queue_recipe_row.gd` exposes:

```gdscript
class_name ProductionQueueRecipeRow
extends PanelContainer

const SLOT_COUNT := 3

func configure(entry: Dictionary) -> void:
	set_meta("recipe_id", String(entry.get("recipe_id", "")))
	$Content/RecipeIcon.texture = entry.get("icon") as Texture2D
	$Content/RecipeSummary/RecipeNameLabel.text = String(entry.get("name", ""))
	$Content/RecipeSummary/DeviceNameLabel.text = String(entry.get("device_name", ""))
	refresh_batches(entry.get("batch_progress", []), entry.get("completion_feedback", []))

func refresh_batches(batch_progress_value: Variant, completion_feedback_value: Variant = []) -> void:
	var batches: Array = batch_progress_value if batch_progress_value is Array else []
	var feedback: Array = completion_feedback_value if completion_feedback_value is Array else []
	for slot_index in range(SLOT_COUNT):
		var slot := get_node("Content/BatchSlots/BatchSlot%d" % (slot_index + 1))
		if slot_index < batches.size():
			_apply_occupied_slot(slot, batches[slot_index])
		elif slot_index < batches.size() + feedback.size():
			_apply_completion_slot(slot, feedback[slot_index - batches.size()])
		else:
			_apply_empty_slot(slot)
	$Content/RecipeSummary/BatchCountLabel.text = "%d/3 批" % batches.size()
```

Occupied slot copy:

```gdscript
source_label.text = "自动" if String(batch.get("source", "manual")) == "automation" else "手动"
progress.value = clampf(float(batch.get("progress", 0.0)), 0.0, 1.0)
remaining_label.text = "剩余 %d 秒" % maxi(0, int(batch.get("remaining_seconds", 0)))
```

Completion slot copy:

```gdscript
progress.value = 1.0
completion_label.visible = true
completion_label.text = "+%d 已入库" % maxi(1, int(feedback.get("output_count", 1)))
```

- [ ] **Step 6: Implement the workbench component interface**

`scripts/ui/pages/production_workbench.gd` exposes:

```gdscript
class_name ProductionWorkbench
extends VBoxContainer

signal craftable_requested
signal missing_materials_requested
signal kitchen_schedule_requested

const QueueRowScene := preload("res://scenes/ui/pages/production_queue_recipe_row.tscn")

func _ready() -> void:
	$RecipeEntryBar/CraftableRecipesButton.pressed.connect(func(): craftable_requested.emit())
	$RecipeEntryBar/MissingMaterialsButton.pressed.connect(func(): missing_materials_requested.emit())
	$ProductionQueueHeader/KitchenScheduleButton.pressed.connect(func(): kitchen_schedule_requested.emit())
	$ActiveQueueScroll/ActiveQueueRows/EmptyQueuePanel/EmptyQueueCraftableButton.pressed.connect(
		func(): craftable_requested.emit()
	)

func refresh_queue(entries: Array[Dictionary], active_batch_count: int, automation_paused: bool) -> void:
	# Reuse rows by recipe_id, remove stale rows, then move rows to entry order.
	$ProductionQueueHeader/TitleColumn/QueueSummaryLabel.text = "进行中 %d 种 · %d 批" % [entries.size(), active_batch_count]
	$ProductionQueueHeader/AutomationPausedLabel.visible = automation_paused
	$ActiveQueueScroll/ActiveQueueRows/EmptyQueuePanel.visible = entries.is_empty()

func refresh_entry_counts(craftable_count: int, missing_count: int) -> void:
	$RecipeEntryBar/CraftableRecipesButton.text = "可制作 %d" % craftable_count
	$RecipeEntryBar/MissingMaterialsButton.text = "缺材料 %d" % missing_count

func tutorial_target(kind: String) -> Control:
	return $RecipeEntryBar/CraftableRecipesButton if kind == "craftable" else null
```

Row reuse must use `recipe_id`; do not clear and recreate the whole list on every one-second tick.

- [ ] **Step 7: Run the scene contract tests**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-queue-scene.log" -s res://tests/production_queue_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\component-contract.log" -s res://tests/component_contract_self_check.gd
```

Expected:

- `PRODUCTION_QUEUE_SCENE_SELF_CHECK_PASS`
- existing component contract pass marker

- [ ] **Step 8: Commit the scene components**

```powershell
git add scenes/ui/pages/production_workbench.tscn scenes/ui/pages/production_queue_recipe_row.tscn scripts/ui/pages/production_workbench.gd scripts/ui/pages/production_queue_recipe_row.gd tests/production_queue_scene_self_check.gd tests/component_contract_self_check.gd
git commit -m "feat: add persistent three-slot production queue"
```

---

## Task 3: Build the Recipe Picker and Cards

**Files:**

- Create: `scenes/ui/overlays/production_recipe_picker_overlay.tscn`
- Create: `scripts/ui/overlays/production_recipe_picker_overlay.gd`
- Create: `scenes/ui/overlays/production_recipe_card.tscn`
- Create: `scripts/ui/overlays/production_recipe_card.gd`
- Create: `tests/production_recipe_picker_self_check.gd`

- [ ] **Step 1: Write the component behavior test first**

The test must verify:

- exactly two tabs, text beginning with `可制作` and `缺材料`;
- no node or button whose name/text contains `全部` as a third browsing tab;
- `RecipeGrid.columns == 3`;
- empty page and search-empty copy;
- a timed recipe card displays `1/3` and remaining capacity;
- a processing card hides timed capacity and list action;
- `make_requested`, `process_requested`, `restock_requested`, and `list_requested` emit the correct ID;
- changing search filters only the current tab.

- [ ] **Step 2: Run the test and confirm the missing-scene failure**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-picker-red.log" -s res://tests/production_recipe_picker_self_check.gd
```

Expected: non-zero exit because the picker scene does not exist.

- [ ] **Step 3: Declare the picker scene**

Use this scene hierarchy:

```text
ProductionRecipePickerOverlay (VBoxContainer)
├── PickerToolbar (HBoxContainer)
│   ├── FilterTabs (TabBar: 可制作, 缺材料)
│   └── SearchInput (LineEdit)
├── RecipeScroll (ScrollContainer)
│   └── RecipeGrid (GridContainer, columns = 3)
├── EmptyState (VBoxContainer)
│   ├── EmptyTitle
│   └── EmptyReason
└── PickerFooter (HBoxContainer)
    ├── PrimaryBulkButton
    ├── ListAllButton
    └── ResultStatusLabel
```

The global header and 48×48 close button remain owned by `main.tscn`; do not duplicate them in this scene.

- [ ] **Step 4: Declare the card scene**

Use:

```text
ProductionRecipeCard (PanelContainer)
└── CardContent (VBoxContainer)
    ├── CardHeader (HBoxContainer)
    │   ├── RecipeIcon (64×64)
    │   └── IdentityColumn
    │       ├── RecipeNameLabel
    │       ├── TypeLabel
    │       └── StockLabel
    ├── CapacityLabel
    ├── MaterialsLabel
    ├── ReasonLabel
    └── ActionRow
        ├── PrimaryActionButton
        └── ListButton
```

- [ ] **Step 5: Implement the card as a display-and-signal component**

```gdscript
class_name ProductionRecipeCard
extends PanelContainer

signal make_requested(item_id: String)
signal process_requested(item_id: String)
signal restock_requested(item_id: String)
signal list_requested(item_id: String)

var _entry: Dictionary = {}

func configure(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	var kind := String(entry.get("kind", "recipe"))
	var filter := String(entry.get("filter", "craftable"))
	$CardContent/CapacityLabel.visible = kind == "recipe"
	$CardContent/CapacityLabel.text = "%d/3 制作中 · 还可加入 %d 批" % [
		int(entry.get("active_count", 0)),
		int(entry.get("remaining_capacity", 0))
	]
	$CardContent/ActionRow/PrimaryActionButton.text = "补货" if filter == "missing" else "制作"
	$CardContent/ActionRow/ListButton.visible = kind == "recipe"

func _on_primary_pressed() -> void:
	var item_id := String(_entry.get("id", ""))
	if String(_entry.get("filter", "")) == "missing":
		restock_requested.emit(item_id)
	elif String(_entry.get("kind", "recipe")) == "processing":
		process_requested.emit(item_id)
	else:
		make_requested.emit(item_id)
```

Disabled controls must retain `ReasonLabel` and tooltip copy; do not communicate failure by opacity alone.

- [ ] **Step 6: Implement picker state and rendering**

Public interface:

```gdscript
class_name ProductionRecipePickerOverlay
extends VBoxContainer

signal make_requested(recipe_id: String)
signal process_requested(process_id: String)
signal restock_requested(recipe_id: String)
signal list_requested(recipe_id: String)
signal make_all_requested
signal bulk_restock_requested
signal list_all_requested

enum Filter { CRAFTABLE, MISSING }

func open_with_filter(filter: Filter) -> void
func current_filter() -> Filter
func refresh(entries: Array[Dictionary], permissions: Dictionary) -> void
func set_action_feedback(message: String, positive: bool) -> void
func tutorial_card_target(item_id: String, action: String) -> Control
```

`refresh()` stores the full current-filter entries, applies normalized lowercase search to `search_text`, then reuses cards by `kind:id`. Search fields are supplied as one `search_haystack` string by `main_view.gd`.

Footer behavior:

```gdscript
$PickerFooter/PrimaryBulkButton.text = "制作全部" if _filter == Filter.CRAFTABLE else "一键补货"
$PickerFooter/PrimaryBulkButton.visible = bool(
	permissions.get("make_all", false) if _filter == Filter.CRAFTABLE else permissions.get("bulk_restock", false)
)
$PickerFooter/ListAllButton.visible = bool(permissions.get("list_all", false))
```

The popup does not close after any card or footer action.

- [ ] **Step 7: Run the picker component test**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-picker.log" -s res://tests/production_recipe_picker_self_check.gd
```

Expected: `PRODUCTION_RECIPE_PICKER_SELF_CHECK_PASS`.

- [ ] **Step 8: Commit the picker components**

```powershell
git add scenes/ui/overlays/production_recipe_picker_overlay.tscn scenes/ui/overlays/production_recipe_card.tscn scripts/ui/overlays/production_recipe_picker_overlay.gd scripts/ui/overlays/production_recipe_card.gd tests/production_recipe_picker_self_check.gd
git commit -m "feat: add filtered production recipe picker"
```

---

## Task 4: Register Both New Global Overlay Modes

**Files:**

- Create: `scenes/ui/overlays/kitchen_schedule_overlay.tscn`
- Create: `scripts/ui/overlays/kitchen_schedule_overlay.gd`
- Modify: `scenes/main.tscn:1-29,324-347`
- Modify: `scripts/main_view.gd:153-258,400-515,8811-9051`
- Modify: `tests/research_overlay_production_workbench_self_check.gd`

- [ ] **Step 1: Change the overlay/workbench integration test first**

Update the existing test to assert:

```gdscript
var workbench := view.get_node("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench")
_expect(workbench.get_node_or_null("ActiveQueueScroll/ActiveQueueRows") != null, "production keeps a persistent queue")
_expect(workbench.get_node_or_null("RecipeScroll") == null, "legacy recipe list is gone")
_expect(workbench.get_node_or_null("KitchenAutomationPanel") == null, "scheduler moved out of the workbench")
_expect(view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ProductionRecipePickerOverlay") != null, "picker mode exists")
_expect(view.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/KitchenScheduleOverlay/KitchenAutomationPanel") != null, "scheduler mode owns the existing panel")
```

Press each right-column entry with real signals and assert `global_popup_mode` becomes `production_picker` or `kitchen_schedule`.

- [ ] **Step 2: Run the integration test and confirm it fails on the old hierarchy**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-overlay-red.log" -s res://tests/research_overlay_production_workbench_self_check.gd
```

Expected: non-zero exit with missing new overlay nodes.

- [ ] **Step 3: Create the kitchen schedule wrapper**

Scene:

```text
KitchenScheduleOverlay (VBoxContainer, script)
├── IntroLabel
└── KitchenAutomationPanel (instance of existing scene, expand vertically)
```

Wrapper interface:

```gdscript
class_name KitchenScheduleOverlay
extends VBoxContainer

func panel() -> Control:
	return $KitchenAutomationPanel

func refresh(state) -> void:
	$KitchenAutomationPanel.call("refresh", state)
	$KitchenAutomationPanel.call("focus_rule", "")
```

The existing panel keeps save/remove/pause signals. The wrapper does not duplicate those actions.

- [ ] **Step 4: Register scene instances in the existing mode stack**

Add `ext_resource` entries and these children to `main.tscn`:

```text
GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ProductionRecipePickerOverlay
GlobalOverlayLayer/OverlayFrame/OverlayModeStack/KitchenScheduleOverlay
```

Do not change `DefaultModalSurface`, `OverlayFrame`, `OverlayHeader`, `OverlayCloseReserve`, or `OverlayCloseButton`.

- [ ] **Step 5: Replace the old node bindings**

In `main_view.gd`:

```gdscript
const MODE_PRODUCTION_PICKER := "production_picker"
const MODE_KITCHEN_SCHEDULE := "kitchen_schedule"

@onready var production_recipe_picker_overlay: ProductionRecipePickerOverlay = \
	$GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ProductionRecipePickerOverlay
@onready var kitchen_schedule_overlay: KitchenScheduleOverlay = \
	$GlobalOverlayLayer/OverlayFrame/OverlayModeStack/KitchenScheduleOverlay
@onready var kitchen_automation_panel: Control = \
	$GlobalOverlayLayer/OverlayFrame/OverlayModeStack/KitchenScheduleOverlay/KitchenAutomationPanel
```

Remove `recipe_scroll` and `recipe_rows` bindings.

- [ ] **Step 6: Connect workbench and picker intent signals**

Add guarded connections:

```gdscript
production_workbench.craftable_requested.connect(
	func(): _show_production_picker(ProductionRecipePickerOverlay.Filter.CRAFTABLE)
)
production_workbench.missing_materials_requested.connect(
	func(): _show_production_picker(ProductionRecipePickerOverlay.Filter.MISSING)
)
production_workbench.kitchen_schedule_requested.connect(_show_kitchen_schedule)
production_recipe_picker_overlay.make_requested.connect(_on_recipe_make_pressed)
production_recipe_picker_overlay.process_requested.connect(_on_process_make_pressed)
production_recipe_picker_overlay.restock_requested.connect(_on_recipe_restock_pressed)
production_recipe_picker_overlay.list_requested.connect(_on_recipe_list_pressed)
production_recipe_picker_overlay.make_all_requested.connect(_on_secondary_action)
production_recipe_picker_overlay.bulk_restock_requested.connect(_on_research_bulk_restock_pressed)
production_recipe_picker_overlay.list_all_requested.connect(_on_tertiary_action)
```

- [ ] **Step 7: Add open, visibility and title behavior**

```gdscript
func _show_production_picker(filter: ProductionRecipePickerOverlay.Filter) -> void:
	_open_global_popup_mode(MODE_PRODUCTION_PICKER)
	production_recipe_picker_overlay.open_with_filter(filter)
	_refresh_production_picker()

func _show_kitchen_schedule() -> void:
	_open_global_popup_mode(MODE_KITCHEN_SCHEDULE)
	kitchen_schedule_overlay.refresh(state)
```

In `_show_global_popup_mode()`:

```gdscript
production_recipe_picker_overlay.visible = mode == MODE_PRODUCTION_PICKER
kitchen_schedule_overlay.visible = mode == MODE_KITCHEN_SCHEDULE
```

Titles:

```gdscript
MODE_PRODUCTION_PICKER:
	overlay_title.text = "选择制作项目"
	overlay_summary.text = "制作、补货或上架；全部配方请前往甜品图鉴"
MODE_KITCHEN_SCHEDULE:
	overlay_title.text = "厨房自动排程"
	overlay_summary.text = "设置每轮 1 批或 3 批、目标库存与原料保留"
```

- [ ] **Step 8: Run the overlay integration test**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-overlay.log" -s res://tests/research_overlay_production_workbench_self_check.gd
```

Expected: `RESEARCH_OVERLAY_PRODUCTION_WORKBENCH_SELF_CHECK_PASS`.

- [ ] **Step 9: Commit overlay registration**

```powershell
git add scenes/main.tscn scenes/ui/overlays/kitchen_schedule_overlay.tscn scripts/main_view.gd scripts/ui/overlays/kitchen_schedule_overlay.gd tests/research_overlay_production_workbench_self_check.gd
git commit -m "feat: register production and schedule overlays"
```

---

## Task 5: Bind Queue Entries and Picker Classification

**Files:**

- Modify: `scripts/main_view.gd:2774-2791,4514-4663,4782-4792`
- Modify: `tests/recipe_production_ui_self_check.gd`
- Modify: `tests/production_recipe_picker_self_check.gd`

- [ ] **Step 1: Replace the old row test with classification and queue-entry assertions**

Test these cases in one controlled state:

- `rice_milk_drink` at `0/3` with materials → `craftable`;
- same recipe at `3/3` → absent from both picker filters;
- recipe with missing purchasable ingredient → `missing`, `restockable == true`;
- recipe missing a recipe-produced intermediate → `missing`, visible reason, `restockable == false`;
- locked-device recipe → absent from both filters;
- available processing recipe → craftable with `kind == "processing"` and no capacity;
- queue groups sorted by their earliest `queue_sequence`;
- batches in each group sorted by `queue_sequence`, then `batch_index`.

- [ ] **Step 2: Run the tests and confirm the missing builder methods**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-ui-red.log" -s res://tests/recipe_production_ui_self_check.gd
```

Expected: non-zero exit because `_production_queue_entries()` and `_production_picker_entries()` do not exist.

- [ ] **Step 3: Build queue entries from the single summary source**

Add:

```gdscript
func _production_queue_entries(now_unix: int = -1) -> Array[Dictionary]:
	var summary := state.recipe_production_queue_summary(now_unix)
	var recipes: Dictionary = catalog.get_recipes()
	var entries: Array[Dictionary] = []
	for recipe_id_value in summary.keys():
		var recipe_id := String(recipe_id_value)
		var recipe: Dictionary = recipes.get(recipe_id, {})
		var batch_progress: Array = summary[recipe_id].get("batch_progress", [])
		if recipe.is_empty() or batch_progress.is_empty():
			continue
		entries.append({
			"recipe_id": recipe_id,
			"name": String(recipe.get("name", recipe_id)),
			"device_name": _device_name(String(recipe.get("device", ""))),
			"icon": _material_icon_texture(recipe_id),
			"batch_progress": batch_progress,
			"first_queue_sequence": int((batch_progress[0] as Dictionary).get("queue_sequence", 0)),
			"completion_feedback": _completion_feedback_for_recipe(recipe_id)
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("first_queue_sequence", 0)) < int(b.get("first_queue_sequence", 0))
	)
	return entries
```

Use the returned entries to calculate total batches and call:

```gdscript
production_workbench.refresh_queue(entries, active_batch_count, bool(state.automation_paused))
```

- [ ] **Step 4: Build picker entries without adding a third “all” category**

Use only:

```gdscript
const PICKER_FILTER_CRAFTABLE := "craftable"
const PICKER_FILTER_MISSING := "missing"
```

Timed recipe classification:

```gdscript
var active_count := state.active_recipe_production_batch_count(recipe_id)
if active_count >= GameState.MAX_CONCURRENT_RECIPE_BATCHES:
	continue
var missing_ids := _missing_recipe_material_ids(recipe_id)
var filter := PICKER_FILTER_CRAFTABLE if missing_ids.is_empty() else PICKER_FILTER_MISSING
```

Required entry keys:

```gdscript
{
	"id": recipe_id,
	"kind": "recipe",
	"filter": filter,
	"name": String(recipe.get("name", recipe_id)),
	"icon": _material_icon_texture(recipe_id),
	"stock_count": state.get_product_count(recipe_id),
	"active_count": active_count,
	"remaining_capacity": GameState.MAX_CONCURRENT_RECIPE_BATCHES - active_count,
	"materials_text": _material_stock_requirements(recipe.get("materials", [])),
	"reason": _recipe_missing_material_status(recipe_id),
	"restockable": not (_recipe_restock_quote(recipe_id).get("purchasable_entries", []) as Array).is_empty(),
	"search_haystack": _production_picker_search_haystack(recipe_id, recipe)
}
```

Processing entry uses `kind = "processing"` and omits capacity keys.

Craftable sorting:

```gdscript
remaining_capacity descending, then stable catalog order ascending
```

Missing sorting:

```gdscript
restockable descending, missing material count ascending, then stable catalog order ascending
```

- [ ] **Step 5: Refresh the queue, counts, and open picker together**

Replace `_refresh_production_workbench()` with:

```gdscript
func _refresh_production_workbench() -> void:
	var now_unix := int(Time.get_unix_time_from_system())
	var queue_entries := _production_queue_entries(now_unix)
	var craftable_entries := _production_picker_entries(PICKER_FILTER_CRAFTABLE)
	var missing_entries := _production_picker_entries(PICKER_FILTER_MISSING)
	var active_batches := 0
	for entry in queue_entries:
		active_batches += (entry.get("batch_progress", []) as Array).size()
	production_workbench.refresh_queue(queue_entries, active_batches, bool(state.automation_paused))
	production_workbench.refresh_entry_counts(craftable_entries.size(), missing_entries.size())
	if global_popup_mode == MODE_PRODUCTION_PICKER:
		_refresh_production_picker()
```

`_refresh_production_picker()` supplies the current filter entries and permissions:

```gdscript
{
	"make_all": state.is_feature_unlocked(RESEARCH_MAKE_ALL_FEATURE_ID),
	"bulk_restock": state.is_feature_unlocked(RESEARCH_BULK_RESTOCK_FEATURE_ID),
	"list_all": state.is_feature_unlocked(RESEARCH_LIST_ALL_FEATURE_ID)
}
```

- [ ] **Step 6: Keep action handlers inside the popup**

After `_on_recipe_make_pressed()`, `_on_process_make_pressed()`, `_on_recipe_list_pressed()`, `_make_all_available_products()`, and `_list_all_available_products()`:

```gdscript
_refresh_production_workbench()
if global_popup_mode == MODE_PRODUCTION_PICKER:
	_refresh_production_picker()
```

Do not call `_close_global_popup()`.

Change all nine-batch copy to:

```gdscript
const RECIPE_BATCH_LIMIT_STATUS := "同时制作已达 3 批上限"
```

and:

```gdscript
"没有可开始制作的项目；%d 种商品已达到 3 批上限。" % capped_recipe_count
```

- [ ] **Step 7: Keep restock dialog context and return to the picker**

Before showing `RecipeRestockDialog`, preserve the context in a `main_view.gd` member:

```gdscript
var pending_restock_return_to_picker := false
```

Set it when opening the quote:

```gdscript
pending_restock_return_to_picker = global_popup_mode == MODE_PRODUCTION_PICKER
```

After confirmation, consume it once:

```gdscript
_refresh_production_workbench()
if pending_restock_return_to_picker:
	_refresh_production_picker()
pending_restock_return_to_picker = false
```

The picker remains the visible underlying global mode; the confirmation dialog remains the existing 600×460 modal.

- [ ] **Step 8: Run focused UI and picker tests**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-ui.log" -s res://tests/recipe_production_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-picker-refresh.log" -s res://tests/production_recipe_picker_self_check.gd
```

Expected:

- `RECIPE_PRODUCTION_UI_SELF_CHECK_PASS`
- `PRODUCTION_RECIPE_PICKER_SELF_CHECK_PASS`

- [ ] **Step 9: Commit queue/picker binding**

```powershell
git add scripts/main_view.gd tests/recipe_production_ui_self_check.gd tests/production_recipe_picker_self_check.gd
git commit -m "feat: bind production queue and recipe filters"
```

---

## Task 6: Preserve Visible Completion Feedback

**Files:**

- Modify: `scripts/main_view.gd:536-615`
- Modify: `scripts/game_state.gd:1671-1695`
- Modify: `scripts/automation_service.gd:196-209,316-374`
- Modify: `tests/recipe_production_ui_self_check.gd`
- Modify: `tests/automation_settlement_self_check.gd`

- [ ] **Step 1: Add failing tests for one-second completion ghosts**

The test must:

1. capture a manual slot with stable `queue_sequence`;
2. complete it;
3. assert `_completion_feedback_for_recipe()` returns one item with full progress and output count;
4. advance injected UI time by at least `1000ms`;
5. assert the feedback is gone;
6. repeat for an automated three-batch completion.

Do not use a real one-second sleep. Add an injected `now_msec` parameter to the feedback capture/prune helpers.

- [ ] **Step 2: Extend automation reports with completed queue identities**

Add `completed_recipe_slots: []` to `_new_report()`.

Before `complete_recipe_production()` removes an automatic slot, copy:

```gdscript
var completed_slot := {
	"recipe_id": recipe_id,
	"queue_sequence": int(queued.get("queue_sequence", 0)),
	"source": "automation",
	"batches": made_batches,
	"output_count": output_count
}
```

Return it from `_complete_kitchen_queue()` and append it in `_accumulate_kitchen_result()`.

- [ ] **Step 3: Capture manual completion identities before removal**

In `GameState.complete_ready_manual_recipe_productions()`, extend the result with:

```gdscript
"completed_recipe_slots": []
```

Before calling `complete_recipe_production()`, append a copied identity record with `source = "manual"`. This is a result payload extension, not persisted state.

- [ ] **Step 4: Add a transient feedback buffer in `main_view.gd`**

```gdscript
const PRODUCTION_COMPLETION_FEEDBACK_MSEC := 1000
var production_completion_feedback: Array[Dictionary] = []

func _capture_recipe_completion_feedback(result: Dictionary, now_msec: int = -1) -> void:
	var captured_at := now_msec if now_msec >= 0 else Time.get_ticks_msec()
	for slot_value in result.get("completed_recipe_slots", []):
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = (slot_value as Dictionary).duplicate(true)
		slot["expires_at_msec"] = captured_at + PRODUCTION_COMPLETION_FEEDBACK_MSEC
		production_completion_feedback.append(slot)

func _prune_recipe_completion_feedback(now_msec: int = -1) -> void:
	var current := now_msec if now_msec >= 0 else Time.get_ticks_msec()
	production_completion_feedback = production_completion_feedback.filter(
		func(entry: Dictionary) -> bool: return int(entry.get("expires_at_msec", 0)) > current
	)
```

`_completion_feedback_for_recipe()` filters by `recipe_id` and expands an automated `batches == 3` record into three visual completion slots.

- [ ] **Step 5: Enforce the approved refresh order in the one-second tick**

Refactor the tick body to:

```gdscript
var manual_result := _process_online_recipe_production(now_unix)
_capture_recipe_completion_feedback(manual_result)
var automation_result := _process_online_automation(now_unix)
_capture_recipe_completion_feedback(automation_result)
_prune_recipe_completion_feedback()
_refresh_production_workbench()
```

Remove the old separate `_refresh_recipe_production_statuses()` call.

When a completion occurred, save once after both result captures. Preserve current status and notification behavior.

- [ ] **Step 6: Verify online and offline behavior**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-feedback.log" -s res://tests/recipe_production_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-offline.log" -s res://tests/recipe_production_timing_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\automation-feedback.log" -s res://tests/automation_settlement_self_check.gd
```

Expected: all three pass markers. The offline test must still find exactly one `recipe_production_report` notification and must not find persisted transient feedback.

- [ ] **Step 7: Commit completion feedback**

```powershell
git add scripts/game_state.gd scripts/automation_service.gd scripts/main_view.gd tests/recipe_production_timing_self_check.gd tests/recipe_production_ui_self_check.gd tests/automation_settlement_self_check.gd
git commit -m "feat: show transient production completion feedback"
```

---

## Task 7: Route the Tutorial Through Real Entry and Card Controls

**Files:**

- Modify: `scripts/main_view.gd:877-923,4076-4207`
- Modify: `tests/tutorial_guide_route_self_check.gd`
- Create: `tests/production_queue_interaction_self_check.gd`

- [ ] **Step 1: Write the two-phase tutorial expectations**

The route test must assert:

- craft step with picker closed → `CraftableRecipesButton`;
- after a real click opens the picker → rice milk card `PrimaryActionButton`;
- merely opening or closing the picker does not advance `tutorial_guide_step`;
- a successful real card press starts one queue item and advances only according to existing completion semantics;
- list step opens the relevant picker context and targets the real card `ListButton`.

- [ ] **Step 2: Update tutorial target routing**

Replace the old scan of `recipe_rows`:

```gdscript
func _tutorial_recipe_action_target(action: String) -> Control:
	if action == "make" and global_popup_mode != MODE_PRODUCTION_PICKER:
		return production_workbench.tutorial_target("craftable")
	if global_popup_mode != MODE_PRODUCTION_PICKER:
		_show_production_picker(ProductionRecipePickerOverlay.Filter.CRAFTABLE)
	return production_recipe_picker_overlay.tutorial_card_target("rice_milk_drink", action)
```

If the list target is not on the craftable tab because materials changed, the overlay must still include cards eligible for listing on the open actionable tab; do not introduce an “全部” tab.

- [ ] **Step 3: Verify real input instead of manual signal emission**

`production_queue_interaction_self_check.gd` must synthesize motion, press, and release events at node global centers, as the existing project interaction tests do.

Verify:

- clicking `CraftableRecipesButton` opens the picker;
- clicking a visible card’s real make button queues one batch;
- `global_popup_mode` remains `production_picker`;
- clicking the tab changes visible entries;
- clicking the existing 48×48 global close button closes the picker;
- pressing behind the overlay does not trigger the right-column buttons;
- backdrop behavior remains identical to existing global overlays.

- [ ] **Step 4: Run tutorial and interaction tests**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-tutorial.log" -s res://tests/tutorial_guide_route_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-interaction.log" -s res://tests/production_queue_interaction_self_check.gd
```

Expected:

- existing tutorial route pass marker
- `PRODUCTION_QUEUE_INTERACTION_SELF_CHECK_PASS`

- [ ] **Step 5: Commit tutorial and real-input coverage**

```powershell
git add scripts/main_view.gd tests/tutorial_guide_route_self_check.gd tests/production_queue_interaction_self_check.gd
git commit -m "test: verify production picker tutorial path"
```

---

## Task 8: Retire the Legacy Recipe List and Run Focused Regression

**Files:**

- Delete after proof:
  - `scenes/ui/pages/recipe_action_row.tscn`
  - `scripts/ui/pages/recipe_action_row.gd`
  - `scenes/ui/pages/research_craft_page.tscn`
  - `scripts/ui/pages/research_craft_page.gd`
- Modify as references require:
  - `tests/component_contract_self_check.gd`
  - `tests/neighborhood_dessert_theme_self_check.gd`
  - `tests/showcase_legacy_cleanup_self_check.gd`
  - `tests/test_red_operation_button_scope.py`

- [ ] **Step 1: Prove the legacy renderer has no live references**

Run:

```powershell
Get-ChildItem scripts,scenes,tests -Recurse -File |
  Where-Object { $_.FullName -notmatch '\\__pycache__\\' } |
  Select-String -Encoding UTF8 -Pattern 'recipe_action_row|research_craft_page|ResearchCraftPageRenderer|RecipeRows'
```

Expected: only the four files being retired and tests explicitly scheduled for cleanup appear. If a live scene/script reference remains, remove that reference and rerun before deletion.

- [ ] **Step 2: Delete only the proven-unused legacy files**

Delete the four listed files with `apply_patch`, then update scene/theme/button-scope tests to register the new queue row and recipe card instead of the old action row.

- [ ] **Step 3: Run focused production, popup, restock, automation, and tutorial regression**

```powershell
$tests = @(
  'recipe_production_timing_self_check.gd',
  'recipe_production_ui_self_check.gd',
  'production_queue_scene_self_check.gd',
  'production_recipe_picker_self_check.gd',
  'production_queue_interaction_self_check.gd',
  'automation_settlement_self_check.gd',
  'research_recipe_restock_self_check.gd',
  'research_batch_unlock_self_check.gd',
  'research_overlay_production_workbench_self_check.gd',
  'tutorial_guide_route_self_check.gd',
  'tutorial_guide_dynamic_target_self_check.gd',
  'component_contract_self_check.gd',
  'neighborhood_dessert_theme_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
    --headless `
    --path . `
    --log-file "$env:TEMP\$($test.Replace('.gd', '')).log" `
    -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: exit code `0`; every test prints its pass marker.

- [ ] **Step 4: Run script parsing/import and Python scope tests**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\production-import.log" --quit
python -m unittest tests.test_red_operation_button_scope
```

Expected:

- Godot project loads without parse or missing-resource errors.
- Python unittest reports `OK`.

- [ ] **Step 5: Run the MVP regression**

First verify the file exists:

```powershell
Test-Path tests\mvp_self_check.gd
```

Then:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\production-mvp.log" `
  -s res://tests/mvp_self_check.gd
```

Expected: `MVP_SELF_CHECK_PASS`.

- [ ] **Step 6: Inspect scope and commit cleanup**

```powershell
git status --short
git diff --stat
git diff -- scripts/game_state.gd scripts/automation_service.gd scripts/main_view.gd scenes/main.tscn scenes/ui/pages scenes/ui/overlays tests
```

Confirm unrelated dirty recipe assets and documents are absent from the staged diff.

```powershell
git add `
  scenes/ui/pages/recipe_action_row.tscn `
  scripts/ui/pages/recipe_action_row.gd `
  scenes/ui/pages/research_craft_page.tscn `
  scripts/ui/pages/research_craft_page.gd `
  tests/component_contract_self_check.gd `
  tests/neighborhood_dessert_theme_self_check.gd `
  tests/showcase_legacy_cleanup_self_check.gd `
  tests/test_red_operation_button_scope.py
git commit -m "refactor: retire legacy production recipe list"
```

---

## Task 9: Final Runtime Layout and Interaction Verification

**Files:**

- Modify only if verification finds an actual defect in task-owned files.

- [ ] **Step 1: Run the game at the design resolution**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64.exe" --path .
```

Verify at `1920×1080`:

- right production workbench remains inside the existing approximate `760×858` region;
- header and entry bar stay fixed while only `ActiveQueueScroll` scrolls;
- bottom buttons visually read as `60 / 40`;
- there is no “全部” browsing entry;
- every active recipe shows exactly three vertical slots;
- picker grid has three columns;
- unified overlay frame, backdrop, and 48×48 close slot match the other global modes;
- kitchen scheduler opens from the queue header and is not present inline.

- [ ] **Step 2: Exercise the real player paths**

With real mouse input:

1. open “可制作”;
2. make the same recipe three times;
3. confirm it leaves the picker at `3/3`;
4. confirm the fourth attempt cannot consume materials;
5. wait for one completion and confirm green `+N 已入库` feedback lasts about one second;
6. confirm the recipe returns to the correct tab based on current materials;
7. open “缺材料”, complete and reject restock cases;
8. run a three-batch automation rule;
9. close by the global close button and backdrop;
10. verify the tutorial craft entry/card and list card targets.

- [ ] **Step 3: Inspect the final repository state**

```powershell
git status --short
git log --oneline -10
```

Expected:

- task commits are present in the planned order;
- unrelated pre-existing dirty files remain untouched and unstaged;
- no new temporary save, log, screenshot, or `.godot-user` artifact is tracked.

- [ ] **Step 4: Commit any verification-only correction separately**

Only if Step 1 or Step 2 required a correction:

```powershell
git add `
  scripts/game_state.gd `
  scripts/automation_service.gd `
  scripts/main_view.gd `
  scripts/ui/pages/production_workbench.gd `
  scripts/ui/pages/production_queue_recipe_row.gd `
  scripts/ui/overlays/production_recipe_picker_overlay.gd `
  scripts/ui/overlays/production_recipe_card.gd `
  scripts/ui/overlays/kitchen_schedule_overlay.gd `
  scenes/main.tscn `
  scenes/ui/pages/production_workbench.tscn `
  scenes/ui/pages/production_queue_recipe_row.tscn `
  scenes/ui/overlays/production_recipe_picker_overlay.tscn `
  scenes/ui/overlays/production_recipe_card.tscn `
  scenes/ui/overlays/kitchen_schedule_overlay.tscn `
  tests/recipe_production_timing_self_check.gd `
  tests/recipe_production_ui_self_check.gd `
  tests/production_queue_scene_self_check.gd `
  tests/production_recipe_picker_self_check.gd `
  tests/production_queue_interaction_self_check.gd `
  tests/automation_settlement_self_check.gd `
  tests/research_overlay_production_workbench_self_check.gd `
  tests/tutorial_guide_route_self_check.gd
git commit -m "fix: correct production queue runtime layout"
```

If no correction was needed, do not create an empty commit.

---

## Completion Criteria

Implementation is complete only when all of the following are true:

- `GameState.MAX_CONCURRENT_RECIPE_BATCHES == 3`.
- Manual accepts one batch; automation accepts one or three batches.
- Automatic three-batch start is atomic and shares capacity with manual work.
- The right column permanently shows only the queue, title controls, and `可制作 / 缺材料`.
- Each active recipe row declares exactly three vertical slots.
- Queue and slot ordering use stable queue identity.
- `batch_progress` exposes `source` and `automation_rule_id`.
- The picker contains exactly two filters and a three-column card grid.
- Timed recipes at `3/3` are absent from both picker filters.
- Processing recipes remain immediate and never enter the timed queue.
- Single make/restock/list and unlocked bulk actions still work without closing the picker.
- Kitchen scheduling uses the global overlay and offers only `1 / 3`.
- Online completion shows transient green feedback; offline completion keeps the existing report.
- Craft and list tutorials hit real entry/card controls through real input.
- Focused tests, project import, and `mvp_self_check.gd` all pass with writable log paths.
