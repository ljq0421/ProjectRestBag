# 产出页格子与背包改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `产出` 页改成固定地点 tab、左侧生产格、右侧分页背包格，并支持生产格解锁、背包页解锁、收获后循环生产、拖回右侧暂停。

**Architecture:** 页面结构必须直接维护在 `scenes/Main.tscn`，脚本不得动态创建页面布局节点；脚本只绑定场景中已有节点、填充格子内容、处理拖拽和按钮行为。生产状态从“无位置数组”升级为“地点 + 格子索引”的存档模型，旧存档加载时迁移到默认解锁格。

**Tech Stack:** Godot 4.6 GDScript, `.tscn` scene files, existing `tests/mvp_self_check.gd` headless self-check.

---

## 文件结构

- Modify: `scenes/Main.tscn`
  - 直接增加或调整产出页需要的 UI 节点：四个地点 tab、左侧生产格 Grid、右侧背包页 TabBar、右侧背包 Grid。
  - 不在 `main_view.gd` 中动态增删这些页面 UI 节点。
- Modify: `scripts/catalog.gd`
  - 把地点调整为 `farm/ranch/forest/pond`，当前仅 `farm` 可用。
  - 补充测试期格子价格和背包页价格常量或 catalog 字段。
- Modify: `scripts/game_state.gd`
  - 新增 `production_slot_unlocks` 和 `production_bag_page_unlocks`。
  - `production_slots` 里的槽增加 `slot_index`。
  - `from_dict` 做旧存档默认和迁移。
- Modify: `scripts/production_site.gd`
  - `start_slot` 增加 `slot_index` 参数，只允许对已解锁且空闲的格子开工。
  - `harvest_slot` 收获后尝试在同一格立刻开始下一轮。
  - `cancel_slot` 继续用于拖回右侧暂停。
  - 新增解锁生产格、解锁背包页的纯逻辑函数。
- Modify: `scripts/main_view.gd`
  - 绑定 `Main.tscn` 中已有节点。
  - 左侧始终刷新 6 个生产格状态。
  - 右侧始终刷新 12 个背包格和 5 个页签。
  - 移除 `暂停产出` 按钮入口，但保留左侧拖回右侧暂停。
- Modify: `scripts/output_cell.gd`
  - 复用现有拖拽格子脚本，增加可选的 `slot_index` / `bag_page` 数据，不承担页面结构职责。
- Modify: `tests/mvp_self_check.gd`
  - 用 TDD 覆盖新存档、新 UI、循环收获、拖拽暂停、解锁生产格、解锁背包页、旧存档迁移。

---

### Task 1: 写失败测试，锁定新页面结构和默认状态

**Files:**
- Modify: `tests/mvp_self_check.gd`

- [ ] **Step 1: 写失败测试**

在现有产出页 UI 自检附近增加断言：

```gdscript
root.call("_show_page", "output")

if output_tabs.tab_count != 4:
	_fail("output page should reserve four site tabs")
if _find_tab_by_metadata(output_tabs, "farm") == -1:
	_fail("output site tabs should include farm")
if _find_tab_by_metadata(output_tabs, "ranch") == -1:
	_fail("output site tabs should include ranch")
if _find_tab_by_metadata(output_tabs, "forest") == -1:
	_fail("output site tabs should include forest")
if _find_tab_by_metadata(output_tabs, "pond") == -1:
	_fail("output site tabs should include pond")

if active_output_grid.get_child_count() != 6:
	_fail("active output grid should render six reserved production cells")
if unlocked_output_grid.get_child_count() != 12:
	_fail("output bag grid should render twelve cells per page")
```

同时检查左侧至少出现 `闲置中` 和 `待解锁`，右侧显示第 1 页已解锁。

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL，失败原因是当前地点 tab 不是四个，左侧/右侧格子数量不符合新设计。

### Task 2: 在 Main.tscn 直接调整产出页 UI 结构

**Files:**
- Modify: `scenes/Main.tscn`

- [ ] **Step 1: 修改场景节点**

在 `.tscn` 中保留现有：

```text
Root/Body/ContentPanel/OptionRow/OutputSiteTabs
Root/Body/ContentPanel/ListRow/OutputGridRow
Root/Body/ContentPanel/ListRow/OutputGridRow/ActiveOutputGrid
Root/Body/ContentPanel/ListRow/OutputGridRow/UnlockedOutputGrid
Root/Body/ContentPanel/OutputContextMenu
```

新增右侧分页节点，作为 `OutputGridRow` 下右侧容器的一部分：

```text
OutputBagPanel: VBoxContainer
OutputBagTabs: TabBar
UnlockedOutputGrid: GridContainer
```

如果需要调整层级，必须在 `Main.tscn` 中完成；`main_view.gd` 只更新对应 `@onready` 路径，不动态创建这些节点。

- [ ] **Step 2: 设置格子 Grid 参数**

在 `.tscn` 中设置：

```text
ActiveOutputGrid.columns = 3
UnlockedOutputGrid.columns = 4
```

左侧 6 格显示为 3x2，右侧 12 格显示为 4x3。

### Task 3: 扩展 catalog 地点和测试价格

**Files:**
- Modify: `scripts/catalog.gd`
- Test: `tests/mvp_self_check.gd`

- [ ] **Step 1: 写失败测试**

把 catalog 自检从 3 个地点改为 4 个地点，并要求包含：

```gdscript
_expect_required_ids("production_sites", production_sites, ["farm", "ranch", "forest", "pond"])
```

测试价格字段：

```gdscript
_expect_array_size("production slot unlock costs", catalog.get_production_slot_unlock_costs(), 5)
_expect_array_size("production bag page unlock costs", catalog.get_production_bag_page_unlock_costs(), 4)
```

- [ ] **Step 2: 实现 catalog**

把 `PRODUCTION_SITES` 改为：

```gdscript
const PRODUCTION_SITES := {
	"farm": {"id": "farm", "name": "农场", "unlock_level": 0, "enabled": true, "base_slots": 6, "duration_seconds": 20, "yield_amount": 3, "cost_rate": 0.3, "items": ["rice_seed", "strawberry", "blueberry", "banana", "apple", "lemon", "red_bean", "honey", "nuts"]},
	"ranch": {"id": "ranch", "name": "牧场", "unlock_level": 2, "enabled": false, "base_slots": 6, "duration_seconds": 20, "yield_amount": 4, "cost_rate": 0.4, "items": ["egg", "milk", "butter", "cream", "cheese", "yogurt"]},
	"forest": {"id": "forest", "name": "林地", "unlock_level": 2, "enabled": false, "base_slots": 6, "duration_seconds": 20, "yield_amount": 3, "cost_rate": 0.4, "items": ["strawberry", "blueberry", "banana", "apple", "lemon", "matcha", "red_bean", "nuts", "cocoa"]},
	"pond": {"id": "pond", "name": "水塘", "unlock_level": 3, "enabled": false, "base_slots": 6, "duration_seconds": 30, "yield_amount": 2, "cost_rate": 0.4, "items": ["spring_water", "sea_salt"]}
}

const PRODUCTION_SLOT_UNLOCK_COSTS := [50, 100, 150, 250, 400]
const PRODUCTION_BAG_PAGE_UNLOCK_COSTS := [100, 200, 400, 800]
```

新增 getters：

```gdscript
func get_production_slot_unlock_costs() -> Array:
	return PRODUCTION_SLOT_UNLOCK_COSTS.duplicate(true)

func get_production_bag_page_unlock_costs() -> Array:
	return PRODUCTION_BAG_PAGE_UNLOCK_COSTS.duplicate(true)
```

### Task 4: 扩展 GameState 存档字段和旧档默认

**Files:**
- Modify: `scripts/game_state.gd`
- Test: `tests/mvp_self_check.gd`

- [ ] **Step 1: 写失败测试**

断言新游戏默认值：

```gdscript
_expect_field_value("default farm production slot unlocks", state.to_dict().get("production_slot_unlocks", {}), "farm", 1)
_expect_field_value("default farm bag page unlocks", state.to_dict().get("production_bag_page_unlocks", {}), "farm", 1)
```

断言旧存档缺字段时也默认：

```gdscript
var defaulted = game_state_script.from_dict({"coins": 120})
_expect_field_value("defaulted production slot unlocks", defaulted.to_dict().get("production_slot_unlocks", {}), "farm", 1)
_expect_field_value("defaulted bag page unlocks", defaulted.to_dict().get("production_bag_page_unlocks", {}), "farm", 1)
```

- [ ] **Step 2: 实现字段**

新增变量：

```gdscript
var production_slot_unlocks: Dictionary = {}
var production_bag_page_unlocks: Dictionary = {}
```

新增默认函数：

```gdscript
static func _default_site_unlocks() -> Dictionary:
	return {"farm": 1, "ranch": 1, "forest": 1, "pond": 1}
```

`new_game()` 初始化两个字典。`to_dict()` 写出两个字典。`from_dict()` 读取、清洗并补默认值。

### Task 5: 改造 ProductionSite 为带格子索引的循环生产

**Files:**
- Modify: `scripts/production_site.gd`
- Test: `tests/mvp_self_check.gd`

- [ ] **Step 1: 写失败测试**

覆盖：

```gdscript
if not production_site_script.start_slot(farm_state, "farm", "strawberry", 0, 1000):
	_fail("start_slot should start production in unlocked slot 0")
if production_site_script.start_slot(farm_state, "farm", "blueberry", 1, 1000):
	_fail("start_slot should reject locked slot 1")
```

收获循环：

```gdscript
var before_count := farm_state.get_ingredient_count("strawberry")
if not production_site_script.harvest_slot(farm_state, 0, 1020):
	_fail("harvest_slot should harvest ready slot")
if farm_state.production_slots.size() != 1:
	_fail("harvest should keep the slot running for next cycle")
if farm_state.get_ingredient_count("strawberry") <= before_count:
	_fail("harvest should add ingredient")
```

- [ ] **Step 2: 实现 start_slot 签名兼容**

实现新签名：

```gdscript
static func start_slot(state, site_id: String, item_id: String, slot_index: int = -1, now_unix: int = -1) -> bool:
```

兼容旧调用：如果 `slot_index < 0`，找该地点第一个已解锁空闲格。

新 slot 写入：

```gdscript
"slot_index": slot_index
```

- [ ] **Step 3: 实现收获后循环**

`harvest_slot` 收获后不要 `remove_at(index)`，而是在同一字典上更新：

```gdscript
slot["started_at_unix"] = current_time
slot["duration_seconds"] = production_duration_seconds(state, site_id, item_id)
slot["ready_at_unix"] = current_time + int(slot["duration_seconds"])
slot["ready"] = false
state.production_slots[index] = slot
```

如果金币不足以支付下一轮成本，则收获成功但移除该 slot，并记录金币不足日志。

### Task 6: 产出页行为绑定到固定场景节点

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `scripts/output_cell.gd`
- Test: `tests/mvp_self_check.gd`

- [ ] **Step 1: 更新节点绑定**

`main_view.gd` 只绑定 `.tscn` 中已有节点：

```gdscript
@onready var output_bag_tabs: TabBar = $Root/Body/ContentPanel/ListRow/OutputGridRow/OutputBagPanel/OutputBagTabs
@onready var unlocked_output_grid: GridContainer = $Root/Body/ContentPanel/ListRow/OutputGridRow/OutputBagPanel/UnlockedOutputGrid
```

不要在代码中创建 `OutputBagPanel`、`OutputBagTabs` 或页面布局节点。

- [ ] **Step 2: 左侧固定刷新 6 格**

`_refresh_output_grids()` 对 `range(6)` 生成内容：

```gdscript
for slot_index in range(6):
	if slot_index >= _unlocked_output_slot_count(selected_output_site_id):
		active_output_grid.add_child(_make_locked_output_slot_cell(slot_index))
	elif _slot_for_site_index(selected_output_site_id, slot_index).is_empty():
		active_output_grid.add_child(_make_idle_output_slot_cell(slot_index))
	else:
		active_output_grid.add_child(_make_active_output_cell(slot_index, slot))
```

- [ ] **Step 3: 右侧固定刷新 12 格**

当前背包页已解锁时显示 12 个格子。产物不足 12 个时补空格。未解锁页显示一个解锁格和 11 个空锁定格。

- [ ] **Step 4: 移除按钮暂停入口**

`_apply_secondary_output_action()` 不再暂停产出。可以隐藏 `secondary_action_button` 或让它在产出页不可见：

```gdscript
secondary_action_button.visible = false
```

保留 `_drop_output_slot_to_unlocked()`，用于左侧拖回右侧暂停。

### Task 7: 解锁生产格和背包页

**Files:**
- Modify: `scripts/production_site.gd`
- Modify: `scripts/main_view.gd`
- Test: `tests/mvp_self_check.gd`

- [ ] **Step 1: 写失败测试**

设置金币后点击左侧待解锁格，断言金币减少、解锁数增加、格子显示 `闲置中`。

设置金币后切到右侧第 2 页并解锁，断言金币减少、背包页解锁数增加、该页显示 12 个背包格。

- [ ] **Step 2: 实现纯逻辑函数**

在 `production_site.gd` 增加：

```gdscript
static func unlock_site_slot(state, site_id: String, slot_index: int) -> bool
static func unlock_bag_page(state, site_id: String, page_index: int) -> bool
```

两者都从 `Catalog` 读取测试价格、检查金币、扣金币、更新 `GameState` 字典并写日志。

- [ ] **Step 3: 绑定 UI 操作**

左侧 `待解锁` 格点击后调用 `_unlock_selected_output_slot(slot_index)`。

右侧未解锁页点击后调用 `_unlock_selected_output_bag_page(page_index)`。

### Task 8: 拖拽规则更新

**Files:**
- Modify: `scripts/main_view.gd`
- Modify: `scripts/output_cell.gd`
- Test: `tests/mvp_self_check.gd`

- [ ] **Step 1: 右拖左**

右侧产物 drag data 包含：

```gdscript
{
	"kind": "unlocked",
	"site_id": selected_output_site_id,
	"item_id": item_id
}
```

左侧 `闲置中` cell drop target 包含 `slot_index`。drop 时调用：

```gdscript
ProductionSite.start_slot(state, selected_output_site_id, item_id, slot_index)
```

- [ ] **Step 2: 左拖右暂停**

左侧生产中 cell drag data 包含：

```gdscript
{
	"kind": "active",
	"slot_index": slot_index,
	"site_id": site_id,
	"item_id": item_id,
	"started_at_unix": int(slot.get("started_at_unix", -1))
}
```

右侧任意已解锁背包格或背包 Grid 接收 active payload，调用 `ProductionSite.cancel_slot(state, state_slot_array_index)`。

### Task 9: 完整验证

**Files:**
- Test: `tests/mvp_self_check.gd`

- [ ] **Step 1: 静态检查**

Run:

```powershell
git diff --check
```

Expected: exit 0，无空白错误。

- [ ] **Step 2: Godot 自检**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected:

```text
MVP_SELF_CHECK_PASS
```

- [ ] **Step 3: 手工审查 UI 约束**

检查 diff：

```powershell
git diff -- scenes/Main.tscn scripts/main_view.gd
```

确认页面结构节点只在 `scenes/Main.tscn` 里增删改；`main_view.gd` 不动态创建页面容器、TabBar、GridContainer，只动态创建格子 cell 内容。

---

## 执行约束

- 不 commit，除非用户明确要求。
- 计划和文档使用中文。
- 页面结构直接修改 `.tscn`。
- 脚本可以创建格子 cell 内容，但不能动态创建或重排页面级 UI 容器。
- 每个实现任务先写失败测试，再写实现，再跑自检。

