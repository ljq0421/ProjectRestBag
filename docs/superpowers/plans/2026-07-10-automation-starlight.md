# 食谱星辉与分阶段自动化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现食谱星辉、Lv.3 产地自动收获续产、Lv.4 厨房自动制作、离线链式结算与可解释自动化简报。

**Architecture:** 以 `StarProgressionService` 读取 `game_data.json` 中的星辉与自动化配置，以 `AutomationService` 统一调度产地和厨房的确定性时间事件；`GameState` 只保存长期状态并提供原子变更入口，`ProductionSite` 与现有厨房队列继续拥有真实生产规则。UI 复用当前 `Main.tscn`、图鉴弹层和通知队列，并新增场景化的自动化中枢、厨房排程面板、产出格与自动化简报组件。

**Tech Stack:** Godot 4.6.1、GDScript、JSON 配置、现有 `GameState`/`TaskService`/`ProductionSite`/`SaveSystem`、Godot 头部自检脚本。

## Global Constraints

- 设计依据为 `docs/superpowers/specs/2026-07-10-automation-starlight-design.zh.md`。
- Lv.3 解锁产地自动化：等级 3、累计星辉 12、完成“产地轮转”。
- Lv.4 解锁厨房自动化：等级 4、累计星辉 30、已解锁产地自动化、完成“稳定出品”。
- 基础功能解锁只检查累计星辉，不消耗星辉；升级只消耗可用星辉。
- 自动化使用与手动流程相同的投入、耗时、产量、加速器和配方成长规则。
- 第一版不自动采购、不自动上架、不自动补充橱窗、不自动售卖。
- 手动厨房指令优先于自动规则；自动化不得抢占或取消手动队列。
- 自动化功能任务是并行功能任务，不得成为现有主线升级的前置条件。
- 保留图鉴现有 `CatalogStarLabel` 的“星级完成度”含义；食谱星辉使用独立字段和独立 UI。
- 稳定 UI 结构优先写入 `.tscn`；`main_view.gd` 只负责协调、绑定和状态刷新。
- Godot 头部命令必须从 `D:\Project\ProjectRest\project-rest` 运行，并传入可写的 `--log-file`。
- 不修改用户现有的无关工作区变更。
- 不自动提交 Git；每个任务完成后停在审阅点，只有用户明确要求时才提交。

---

## File Structure

- Create `scripts/star_progression_service.gd`: 加载并校验星辉、功能门槛和自动化升级配置；枚举配方可领取奖励。
- Create `scripts/automation_service.gd`: 管理托管产地、厨房规则、确定性在线/离线事件结算、暂停原因和简报聚合。
- Create `scenes/ui/pages/output_cell.tscn`: 把现有动态产出按钮、进度条和托管状态固化为场景。
- Modify `scripts/output_cell.gd`: 保留拖放行为，显示托管运行或暂停原因；开关位于产地板块标题。
- Create `scenes/ui/pages/kitchen_automation_panel.tscn`: 厨房规则列表、编辑区和全局暂停入口。
- Create `scripts/ui/pages/kitchen_automation_panel.gd`: 渲染并提交厨房规则，不承载生产算法。
- Create `scenes/ui/overlays/automation_overlay.tscn`: 食谱星辉余额、下个解锁目标、产地/厨房升级按钮。
- Create `scripts/ui/overlays/automation_overlay.gd`: 自动化中枢的场景组件逻辑。
- Create `scenes/ui/overlays/automation_report_dialog.tscn`: 离线自动化简报与“前往处理”动作。
- Create `scripts/ui/overlays/automation_report_dialog.gd`: 格式化简报并发出定位请求。
- Create `tests/automation_settlement_self_check.gd`: 使用固定时间戳验证多轮产地、厨房链式供料、优先级、暂停和安全上限。
- Modify `game_data.json`: 增加唯一的星辉奖励、解锁、升级和结算上限配置。
- Modify `scripts/game_state.gd`: 保存星辉、领取键、自动化解锁、升级、托管产地、厨房规则和待展示简报。
- Modify `scripts/task_service.gd`: 加载两条并行功能任务，支持复合事件进度和星辉任务奖励。
- Modify `scripts/production_site.gd`: 提供稳定槽键和可保留暂停槽的结构化收获结果。
- Modify `scripts/save_system.gd`: 用 `AutomationService` 替代旧的单次离线成熟计数，并原子保存结算结果。
- Modify `scenes/Main.tscn`: 新增顶部星辉入口、自动化中枢和自动化简报实例。
- Modify `scenes/ui/overlays/catalog_overlay.tscn`: 新增食谱星辉摘要和“领取全部”，不复用星级完成度标签。
- Modify `scripts/ui/overlays/catalog_overlay.gd`: 发出单配方领取与领取全部信号。
- Modify `scenes/ui/pages/workbench_pages.tscn`: 实例化厨房排程面板，并改用场景化产出格。
- Modify `scripts/main_view.gd`: 连接新组件、刷新状态、调用服务、保存并顺序展示通知/简报。
- Modify `tests/mvp_self_check.gd`: 覆盖字段、迁移、星辉唯一领取、解锁门槛、场景节点和完整流程。
- Modify `tests/task_mainline_self_check.gd`: 覆盖功能任务并行关系与复合进度。
- Modify `tests/component_contract_self_check.gd`: 固定新增 UI 组件的信号契约。
- Modify `tests/main_scene_split_shell_self_check.gd`: 保持 `main_view.gd` 为协调器，禁止把奖励或结算算法塞回视图。

---

### Task 1: 配置化食谱星辉与持久化状态

**Files:**
- Create: `scripts/star_progression_service.gd`
- Modify: `game_data.json`
- Modify: `scripts/game_state.gd`
- Test: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `GameState.unlocked_recipes`, `GameState.recipe_growth`, `GameState.completed_tasks`, `game_data.json.automation`。
- Produces:
  - `StarProgressionService.get_config() -> Dictionary`
  - `StarProgressionService.claimable_recipe_rewards(state, recipe_id: String = "") -> Array[Dictionary]`
  - `StarProgressionService.feature_gate(feature_id: String) -> Dictionary`
  - `StarProgressionService.upgrade_definition(upgrade_id: String) -> Dictionary`
  - `GameState.claim_starlight_reward(reward_key: String, amount: int) -> bool`
  - `GameState.claim_recipe_starlight(recipe_id: String = "") -> Dictionary`
  - `GameState.spend_starlight(amount: int) -> bool`

- [ ] **Step 1: 写入失败的星辉与存档自检**

在 `tests/mvp_self_check.gd` 的脚本路径常量区增加：

```gdscript
const STAR_PROGRESSION_SERVICE_PATH := "res://scripts/star_progression_service.gd"
```

在 `_expect_game_state_behaviors()` 的必需方法列表和新游戏断言中增加：

```gdscript
		"claim_starlight_reward",
		"claim_recipe_starlight",
		"spend_starlight"
```

```gdscript
	_expect_field_value("new game lifetime starlight", state.to_dict(), "recipe_starlight_total", 0)
	_expect_field_value("new game available starlight", state.to_dict(), "recipe_starlight_available", 0)
	_expect_array_size("new game claimed starlight", state.to_dict().get("claimed_starlight_rewards", []), 0)
	_expect_dictionary_size("new game automation unlocks", state.to_dict().get("automation_unlocks", {}), 0)
	_expect_dictionary_size("new game automation upgrades", state.to_dict().get("automation_upgrades", {}), 0)
	if not state.claim_starlight_reward("recipe_unlock:rice_milk_drink", 1):
		_fail("first starlight reward claim should succeed")
	if state.claim_starlight_reward("recipe_unlock:rice_milk_drink", 1):
		_fail("duplicate starlight reward claim should fail")
	_expect_field_value("claimed lifetime starlight", state.to_dict(), "recipe_starlight_total", 1)
	_expect_field_value("claimed available starlight", state.to_dict(), "recipe_starlight_available", 1)
	if not state.spend_starlight(1):
		_fail("available starlight should be spendable")
	_expect_field_value("spent lifetime starlight unchanged", state.to_dict(), "recipe_starlight_total", 1)
	_expect_field_value("spent available starlight", state.to_dict(), "recipe_starlight_available", 0)
```

- [ ] **Step 2: 运行自检并确认按预期失败**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-starlight-red.log" -s res://tests/mvp_self_check.gd
```

Expected: FAIL，指出 `star_progression_service.gd` 或 `GameState.claim_starlight_reward` 不存在。

- [ ] **Step 3: 把自动化数值写入 `game_data.json`**

在根对象加入：

```json
"automation": {
  "event_limit": 10000,
  "feature_unlocks": {
    "output": {"level": 3, "lifetime_starlight": 12, "task_id": "feature_output_automation"},
    "kitchen": {"level": 4, "lifetime_starlight": 30, "task_id": "feature_kitchen_automation", "requires": ["output"]}
  },
  "starlight_rewards": {
    "recipe_unlock": 1,
    "recipe_mastery": {"1": 1, "2": 2, "3": 3},
    "catalog_milestones": {"25": 3, "50": 5, "75": 5, "100": 8},
    "tasks": {
      "main_l0_list_product": 2,
      "main_l1_upgrade": 3,
      "main_l2_upgrade": 4,
      "main_l3_upgrade": 4,
      "main_l4_upgrade": 5,
      "main_l5_mvp_complete": 6,
      "post_rule_understanding": 3,
      "post_growth_showcase": 5,
      "post_signature_window": 8
    }
  },
  "upgrades": {
    "output_capacity_1": {"feature": "output", "cost": 6, "effect": {"managed_output_sites": 2}},
    "offline_duration_1": {"feature": "output", "cost": 8, "effect": {"offline_seconds": 14400}},
    "output_capacity_2": {"feature": "output", "cost": 12, "requires_upgrades": ["output_capacity_1"], "effect": {"managed_output_sites": 3}},
    "offline_duration_2": {"feature": "output", "cost": 16, "requires_upgrades": ["offline_duration_1"], "effect": {"offline_seconds": 28800}},
    "output_capacity_all": {"feature": "output", "cost": 24, "requires_upgrades": ["output_capacity_2"], "effect": {"managed_output_sites": -1}},
    "kitchen_devices_2": {"feature": "kitchen", "cost": 8, "effect": {"managed_kitchen_devices": 2}},
    "kitchen_rules_3": {"feature": "kitchen", "cost": 10, "effect": {"kitchen_rules": 3}},
    "kitchen_priority": {"feature": "kitchen", "cost": 12, "requires_upgrades": ["kitchen_rules_3"], "effect": {"priority_enabled": true}},
    "kitchen_inventory_policy": {"feature": "kitchen", "cost": 16, "requires_upgrades": ["kitchen_priority"], "effect": {"inventory_policy_enabled": true}},
    "kitchen_all": {"feature": "kitchen", "cost": 30, "requires_upgrades": ["kitchen_devices_2", "kitchen_rules_3", "kitchen_priority", "kitchen_inventory_policy"], "effect": {"managed_kitchen_devices": -1, "kitchen_rules": 8}}
  }
}
```

- [ ] **Step 4: 创建只读配置与奖励枚举服务**

创建 `scripts/star_progression_service.gd`，实现以下完整公共骨架；内部 `_load_game_data()`、`_sanitize_dictionary()` 和 `_reward_entry()` 必须返回新副本，不能把 JSON 原对象暴露给调用方：

```gdscript
class_name StarProgressionService
extends RefCounted

const GAME_DATA_PATH := "res://game_data.json"
const Catalog = preload("res://scripts/catalog.gd")


static func get_config() -> Dictionary:
	var data := _load_game_data()
	var raw: Variant = data.get("automation", {})
	return raw.duplicate(true) if raw is Dictionary else {}


static func feature_gate(feature_id: String) -> Dictionary:
	var unlocks: Dictionary = get_config().get("feature_unlocks", {})
	var raw: Variant = unlocks.get(feature_id, {})
	return raw.duplicate(true) if raw is Dictionary else {}


static func upgrade_definition(upgrade_id: String) -> Dictionary:
	var upgrades: Dictionary = get_config().get("upgrades", {})
	var raw: Variant = upgrades.get(upgrade_id, {})
	return raw.duplicate(true) if raw is Dictionary else {}


static func task_starlight_amount(task_id: String) -> int:
	var rewards: Dictionary = get_config().get("starlight_rewards", {})
	var tasks: Dictionary = rewards.get("tasks", {})
	return maxi(0, int(tasks.get(task_id, 0)))


static func claimable_recipe_rewards(state, recipe_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state == null:
		return result
	var rewards: Dictionary = get_config().get("starlight_rewards", {})
	var unlock_amount := maxi(0, int(rewards.get("recipe_unlock", 0)))
	var mastery_rewards: Dictionary = rewards.get("recipe_mastery", {})
	var recipe_ids: Array = state.unlocked_recipes.duplicate()
	for raw_id: Variant in recipe_ids:
		var id := String(raw_id)
		if not recipe_id.is_empty() and id != recipe_id:
			continue
		_append_if_unclaimed(result, state, "recipe_unlock:%s" % id, unlock_amount, id, "解锁配方")
		var mastery := int(state.get_recipe_growth(id).get("mastery_level", 0))
		for level in range(1, mastery + 1):
			_append_if_unclaimed(result, state, "recipe_mastery:%s:%d" % [id, level], int(mastery_rewards.get(str(level), 0)), id, "配方成长")
	if recipe_id.is_empty():
		var task_rewards: Dictionary = rewards.get("tasks", {})
		for task_id_value: Variant in state.completed_tasks:
			var task_id := String(task_id_value)
			_append_if_unclaimed(result, state, "task:%s" % task_id, int(task_rewards.get(task_id, 0)), "", "阶段与挑战")
		var total_recipes := maxi(1, Catalog.new().get_recipes().size())
		var unlocked_count := state.unlocked_recipes.size()
		var milestone_rewards: Dictionary = rewards.get("catalog_milestones", {})
		for percent_value in milestone_rewards.keys():
			var percent := int(percent_value)
			var target := int(ceil(float(total_recipes) * float(percent) / 100.0))
			if unlocked_count >= target:
				_append_if_unclaimed(result, state, "catalog_milestone:%d" % percent, int(milestone_rewards[percent_value]), "", "图鉴里程碑")
	return result


static func _append_if_unclaimed(
	result: Array[Dictionary],
	state,
	reward_key: String,
	amount: int,
	recipe_id: String,
	source: String
) -> void:
	if amount <= 0 or state.claimed_starlight_rewards.has(reward_key):
		return
	result.append({
		"key": reward_key,
		"amount": amount,
		"recipe_id": recipe_id,
		"source": source
	})


static func _load_game_data() -> Dictionary:
	if not FileAccess.file_exists(GAME_DATA_PATH):
		return {}
	var file := FileAccess.open(GAME_DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
```

- [ ] **Step 5: 在 `GameState` 中增加原子星辉状态**

新增字段并在 `new_game()`、`from_dict()`、`to_dict()` 同步：

```gdscript
var recipe_starlight_total: int = 0
var recipe_starlight_available: int = 0
var claimed_starlight_rewards: Array[String] = []
var automation_unlocks: Dictionary = {}
var automation_upgrades: Dictionary = {}
var managed_production_slots: Array[String] = []
var kitchen_automation_rules: Array[Dictionary] = []
var automation_paused: bool = false
var automation_last_settled_unix: int = 0
var pending_automation_report: Dictionary = {}
```

增加原子变更入口：

```gdscript
func claim_starlight_reward(reward_key: String, amount: int) -> bool:
	if reward_key.is_empty() or amount <= 0 or claimed_starlight_rewards.has(reward_key):
		return false
	claimed_starlight_rewards.append(reward_key)
	recipe_starlight_total += amount
	recipe_starlight_available += amount
	add_log("starlight_claim:%s:%d" % [reward_key, amount])
	return true


func claim_recipe_starlight(recipe_id: String = "") -> Dictionary:
	var claimed := 0
	var keys: Array[String] = []
	for reward in StarProgressionService.claimable_recipe_rewards(self, recipe_id):
		var key := String(reward.get("key", ""))
		var amount := int(reward.get("amount", 0))
		if claim_starlight_reward(key, amount):
			claimed += amount
			keys.append(key)
	return {"ok": claimed > 0, "amount": claimed, "keys": keys}


func spend_starlight(amount: int) -> bool:
	if amount <= 0 or recipe_starlight_available < amount:
		return false
	recipe_starlight_available -= amount
	return true
```

`from_dict()` 必须过滤负数、重复领取键、未知托管槽与无效厨房规则；本任务先实现星辉字段，自动化字段的具体清洗在后续任务补齐。

当 `recipe_id` 为空时，`claimable_recipe_rewards()` 还会枚举已经完成但没有 `task:<task_id>` 星辉领取键的阶段/挑战奖励。这是旧存档补发入口；新存档在任务奖励领取时会立即写入同一个唯一键，因此不会重复出现。

同一入口还会按 25%/50%/75%/100% 图鉴完成度枚举 `catalog_milestone:<percent>` 奖励，复用现有图鉴里程碑而不是新增第二套收集节点。

- [ ] **Step 6: 运行自检并确认通过**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-starlight-green.log" -s res://tests/mvp_self_check.gd
```

Expected: `MVP self-check passed.`，且无 parser error。

- [ ] **Step 7: 审阅点（不提交）**

Run:

```powershell
git diff --check -- game_data.json scripts/star_progression_service.gd scripts/game_state.gd tests/mvp_self_check.gd
git status --short
```

Expected: 无 whitespace error；只审阅本任务文件，不提交 Git。

---

### Task 2: 星辉任务奖励与两条并行功能任务

**Files:**
- Modify: `game_data.json`
- Modify: `scripts/task_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `scripts/production_site.gd`
- Test: `tests/task_mainline_self_check.gd`
- Test: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `StarProgressionService.task_starlight_amount(task_id)`、`GameState.claim_starlight_reward()`。
- Produces:
  - `TaskService` 支持 `events: Array[String]` 和 `availability`。
  - `GameState.unlock_automation(feature_id: String) -> bool`
  - `GameState.is_automation_unlocked(feature_id: String) -> bool`
  - `ProductionSite.set_next_item()` 发出 `output_next_set` 任务事件。

- [ ] **Step 1: 写功能任务失败自检**

在 `tests/task_mainline_self_check.gd` 增加：

```gdscript
func _expect_automation_feature_tasks() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.recipe_starlight_total = 12
	var active_ids := _task_ids(TaskService.get_visible_tasks(state))
	_expect(active_ids.has("feature_output_automation"), "Lv.3 and 12 lifetime starlight should expose output automation task")
	_expect(not active_ids.has("feature_kitchen_automation"), "kitchen automation task should remain hidden before Lv.4 and output unlock")
	for site_id in ["farm", "ranch"]:
		for _index in range(3):
			state.record_task_event("harvest", {"site_id": site_id, "item_id": "rice", "amount": 1})
	for _index in range(3):
		state.record_task_event("output_next_set", {"site_id": "farm", "slot_index": _index, "item_id": "rice_seed"})
	_expect(state.is_task_completed("feature_output_automation"), "six harvests across two sites plus three next-item settings should complete output feature task")
	_expect(state.claim_task_reward("feature_output_automation"), "output automation task reward should be claimable")
	_expect(state.is_automation_unlocked("output"), "claiming output feature task should unlock output automation")
```

- [ ] **Step 2: 运行任务自检并确认失败**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-task-red.log" -s res://tests/task_mainline_self_check.gd
```

Expected: FAIL，指出 `feature_output_automation` 不可见或 `unlock_automation` 不存在。

- [ ] **Step 3: 在配置中加入完整功能任务定义**

在 `automation` 下加入：

```json
"feature_tasks": {
  "feature_output_automation": {
    "id": "feature_output_automation",
    "title": "产地轮转",
    "type": "feature",
    "level": 3,
    "source_stage": "自动化",
    "description": "在至少两类产地中手动收获6批，并设置3次下一轮产物。",
    "progress_text": "收获6批/2类产地，设置3次下一轮",
    "events": ["harvest", "output_next_set"],
    "condition": {"kind": "output_automation_practice", "harvest_count": 6, "site_count": 2, "next_set_count": 3},
    "goal": 1,
    "availability": {"min_level": 3, "min_lifetime_starlight": 12},
    "reward": {"unlock_automation": ["output"]},
    "notification_title": "产地管家已开放",
    "notification_body": "选择最多3个产出槽进行自动收获与续产。",
    "sort_order": 350
  },
  "feature_kitchen_automation": {
    "id": "feature_kitchen_automation",
    "title": "稳定出品",
    "type": "feature",
    "level": 4,
    "source_stage": "自动化",
    "description": "使用至少两类设备完成3次批量制作。",
    "progress_text": "批量制作3次/2类设备",
    "events": ["recipe_queue_complete"],
    "condition": {"kind": "kitchen_automation_practice", "completion_count": 3, "device_count": 2, "min_batches": 5},
    "goal": 1,
    "availability": {"min_level": 4, "min_lifetime_starlight": 30, "automation_unlocks": ["output"]},
    "reward": {"unlock_automation": ["kitchen"]},
    "notification_title": "厨房排程台已开放",
    "notification_body": "可以配置1台设备和1条自动制作规则。",
    "sort_order": 450
  }
}
```

- [ ] **Step 4: 让 `TaskService` 读取功能任务和复合事件**

在 `get_task_definitions()` 中把 `StarProgressionService.get_config().get("feature_tasks", {})` 清洗后合并到主线定义。把事件判断替换为：

```gdscript
static func _task_accepts_event(task: Dictionary, event_name: String) -> bool:
	var events_value: Variant = task.get("events", [])
	if events_value is Array and not (events_value as Array).is_empty():
		return (events_value as Array).has(event_name)
	return String(task.get("event", "")) == event_name
```

在 `_is_task_available()` 增加：

```gdscript
var availability: Dictionary = task.get("availability", {})
if int(state.level) < int(availability.get("min_level", task.get("level", 0))):
	return false
if int(state.recipe_starlight_total) < int(availability.get("min_lifetime_starlight", 0)):
	return false
for feature_id in _sanitize_string_array(availability.get("automation_unlocks", [])):
	if not state.is_automation_unlocked(feature_id):
		return false
```

为两种 `condition.kind` 分别累计 `harvest_site_ids`、`harvest_count`、`next_set_count` 或 `device_ids`、`completion_count`，只有全部子条件达标时把顶层 `count` 设为 1。

- [ ] **Step 5: 把阶段星辉和自动化解锁纳入任务领取事务**

把 `claim_task_reward()` 改为在同一次领取中执行：

```gdscript
var task_starlight := StarProgressionService.task_starlight_amount(task_id)
if task_starlight > 0:
	state.claim_starlight_reward("task:%s" % task_id, task_starlight)
for feature_id in _sanitize_string_array(reward.get("unlock_automation", [])):
	state.unlock_automation(feature_id)
```

`_reward_text()` 同步显示“食谱星辉 +N”和“解锁产地管家/厨房排程台”。

- [ ] **Step 6: 在真实事件路径补齐复合任务事件**

`ProductionSite.set_next_item()` 成功后增加：

```gdscript
state.record_task_event("output_next_set", {"site_id": site_id, "slot_index": int(slot.get("slot_index", index)), "item_id": item_id})
```

`GameState.complete_recipe_production()` 在移除队列前保存 `device_id` 和 `batches`，然后增加：

```gdscript
record_task_event("recipe_queue_complete", {
	"recipe_id": recipe_id,
	"device_id": String(slot.get("device_id", "")),
	"batches": int(slot.get("batches", 1)),
	"amount": output_count
})
```

- [ ] **Step 7: 实现自动化解锁状态**

在 `GameState` 增加：

```gdscript
func is_automation_unlocked(feature_id: String) -> bool:
	return bool(automation_unlocks.get(feature_id, false))


func unlock_automation(feature_id: String) -> bool:
	if feature_id.is_empty() or is_automation_unlocked(feature_id):
		return false
	automation_unlocks[feature_id] = true
	add_log("automation_unlock:%s" % feature_id)
	return true
```

- [ ] **Step 8: 运行任务和 MVP 自检**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-task-green.log" -s res://tests/task_mainline_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-mvp-task-green.log" -s res://tests/mvp_self_check.gd
```

Expected: 两个脚本均 PASS；原主线依赖链保持不变。

- [ ] **Step 9: 审阅点（不提交）**

Run `git diff --check -- game_data.json scripts/task_service.gd scripts/game_state.gd scripts/production_site.gd tests/task_mainline_self_check.gd tests/mvp_self_check.gd`，确认无 whitespace error 后停止。

---

### Task 3: 产地托管与多轮自动收获

**Files:**
- Create: `scripts/automation_service.gd`
- Create: `tests/automation_settlement_self_check.gd`
- Modify: `scripts/production_site.gd`
- Modify: `scripts/game_state.gd`

**Interfaces:**
- Consumes: `ProductionSite.production_duration_seconds()`、`ProductionSite` 的投入与产物规则。
- Produces:
  - `ProductionSite.slot_key(site_id: String, slot_index: int) -> String`
  - `ProductionSite.settle_ready_slot(state, array_index: int, event_unix: int, keep_paused: bool) -> Dictionary`
  - `AutomationService.set_output_managed(state, site_id: String, slot_index: int, managed: bool) -> Dictionary`
  - `AutomationService.output_slot_limit(state) -> int`
  - `AutomationService.offline_seconds_limit(state) -> int`
  - `AutomationService.set_global_paused(state, paused: bool) -> void`
  - `AutomationService.settle(state, from_unix: int, to_unix: int, offline_limit_seconds: int = -1) -> Dictionary`

- [ ] **Step 1: 创建固定时间戳失败自检**

创建 `tests/automation_settlement_self_check.gd`，初始化 Lv.3、解锁 output、托管 `farm:0`、投入 4 个种子，并断言从 1000 到 1080 能结算 4 轮 20 秒产出：

```gdscript
extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const ProductionSite = preload("res://scripts/production_site.gd")
const AutomationService = preload("res://scripts/automation_service.gd")

var failures: Array[String] = []


func _init() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 4}
	if not ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000):
		_fail("wheat slot should start")
	if not bool(AutomationService.set_output_managed(state, "farm", 0, true).get("ok", false)):
		_fail("farm:0 should become managed")
	var report := AutomationService.settle(state, 1000, 1080, 7200)
	_expect_equal("wheat harvested", state.get_ingredient_count("wheat"), 12)
	_expect_equal("output cycles", int(report.get("output_cycle_count", 0)), 4)
	_expect_equal("remaining seed", state.get_ingredient_count("wheat_seed"), 0)
	if failures.is_empty():
		print("Automation settlement self-check passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
```

- [ ] **Step 2: 运行并确认因服务缺失而失败**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-automation-red.log" -s res://tests/automation_settlement_self_check.gd
```

Expected: FAIL because `automation_service.gd` does not exist。

- [ ] **Step 3: 为产出槽增加稳定键与结构化结算**

在 `ProductionSite` 增加：

```gdscript
static func slot_key(site_id: String, slot_index: int) -> String:
	return "%s:%d" % [site_id, slot_index]
```

把现有 `harvest_slot()` 保留为兼容包装：

```gdscript
static func harvest_slot(state, index: int, now_unix: int = -1) -> bool:
	return bool(settle_ready_slot(state, index, _now_unix(now_unix), false).get("ok", false))
```

新增 `settle_ready_slot()`，返回：

```gdscript
{
	"ok": true,
	"slot_key": "farm:0",
	"site_id": "farm",
	"slot_index": 0,
	"outputs": {"wheat": 3},
	"restarted": true,
	"pause_reason": {},
	"next_ready_at_unix": 1040
}
```

当 `keep_paused` 为 true 且下一轮投入不足时，不移除槽位，而写入：

```gdscript
slot["automation_paused"] = true
slot["pause_reason"] = {"code": "missing_input", "item_id": restart_item_id, "first_stopped_at_unix": event_unix}
slot["started_at_unix"] = 0
slot["ready_at_unix"] = 0
slot["ready"] = false
```

`is_slot_ready()` 必须在 `automation_paused` 为 true 时返回 false，防止重复收获。

- [ ] **Step 4: 实现托管上限与产地事件循环**

创建 `AutomationService`，首版公共入口：

```gdscript
class_name AutomationService
extends RefCounted

const ProductionSite = preload("res://scripts/production_site.gd")
const StarProgressionService = preload("res://scripts/star_progression_service.gd")


static func set_output_site_managed(state, site_id: String, managed: bool) -> Dictionary:
	if not state.is_automation_unlocked("output"):
		return {"ok": false, "reason": "产地管家尚未解锁"}
	if managed and not state.managed_production_sites.has(site_id):
		var limit := output_site_limit(state)
		if limit >= 0 and state.managed_production_sites.size() >= limit:
			return {"ok": false, "reason": "托管产地已达上限"}
		state.managed_production_sites.append(site_id)
	elif not managed:
		state.managed_production_sites.erase(site_id)
	return {"ok": true, "managed": managed, "site_id": site_id}


static func output_site_limit(state) -> int:
	if bool(state.automation_upgrades.get("output_capacity_all", false)):
		return -1
	if bool(state.automation_upgrades.get("output_capacity_2", false)):
		return 3
	if bool(state.automation_upgrades.get("output_capacity_1", false)):
		return 2
	return 1


static func offline_seconds_limit(state) -> int:
	if bool(state.automation_upgrades.get("offline_duration_2", false)):
		return 28800
	if bool(state.automation_upgrades.get("offline_duration_1", false)):
		return 14400
	return 7200


static func set_global_paused(state, paused: bool) -> void:
	state.automation_paused = paused
	state.add_log("automation_global_pause:%s" % str(paused))


static func settle(state, from_unix: int, to_unix: int, offline_limit_seconds: int = -1) -> Dictionary:
	var end_unix := to_unix
	if offline_limit_seconds >= 0:
		end_unix = mini(end_unix, from_unix + offline_limit_seconds)
	var report := _new_report(from_unix, end_unix)
	var event_limit := maxi(1, int(StarProgressionService.get_config().get("event_limit", 10000)))
	if state.automation_paused:
		return report
	while int(report.get("event_count", 0)) < event_limit:
		var event := _next_output_event(state, from_unix, end_unix)
		if event.is_empty():
			break
		var result := ProductionSite.settle_ready_slot(state, int(event.get("array_index", -1)), int(event.get("at", end_unix)), true)
		_accumulate_output_result(report, result)
	return _finish_report(report, event_limit)
```

下一事件必须使用槽的 `ready_at_unix`，重启时间必须使用事件时间而不是加载时间，才能产生多轮结果。

- [ ] **Step 5: 完成托管状态清洗**

`GameState.from_dict()` 只保留符合 `site_id:slot_index` 格式、地点存在且槽位非负的键；去重并保持玩家顺序。`to_dict()` 使用副本。

`automation_paused` 同步进入新游戏、保存和加载。全局暂停只阻止自动收获、自动续产和新自动厨房队列；已经开始的生产时间仍然推进，恢复自动化后成熟结果才会被处理。

- [ ] **Step 6: 扩展边界自检**

在 `automation_settlement_self_check.gd` 继续覆盖：未托管产地只成熟不收获；同一托管产地内所有已开工格都被结算；种子耗尽后保留暂停槽；`queued_item_id` 在首轮后切换并继续重复；基础托管超过 1 块产地失败；加速器影响每次新循环。

- [ ] **Step 7: 运行产地自动化自检**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-automation-output-green.log" -s res://tests/automation_settlement_self_check.gd
```

Expected: `Automation settlement self-check passed.`。

- [ ] **Step 8: 审阅点（不提交）**

运行 `git diff --check -- scripts/automation_service.gd scripts/production_site.gd scripts/game_state.gd tests/automation_settlement_self_check.gd` 后停止。

---

### Task 4: 厨房规则与产地到厨房的链式结算

**Files:**
- Modify: `scripts/automation_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `tests/automation_settlement_self_check.gd`
- Test: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `GameState.queue_recipe_production()`、`GameState.complete_recipe_production()`。
- Produces:
  - `AutomationService.save_kitchen_rule(state, rule: Dictionary) -> Dictionary`
  - `AutomationService.remove_kitchen_rule(state, rule_id: String) -> bool`
  - `AutomationService.kitchen_rule_status(state, rule_id: String) -> Dictionary`
  - `AutomationService.kitchen_rule_limit(state) -> int`
  - `AutomationService.kitchen_device_limit(state) -> int`
  - `AutomationService.priority_enabled(state) -> bool`
  - `AutomationService.inventory_policy_enabled(state) -> bool`
  - 扩展后的 `AutomationService.settle()` 同时处理产地成熟和厨房完成事件。

- [ ] **Step 1: 写链式供料失败自检**

在 `automation_settlement_self_check.gd` 增加一个固定场景：产地在 1020 产出厨房所需材料，厨房规则随后于同一离线区间开工并完成。断言最终原料减少、甜品增加、`made_count` 增加，并且 `report.product_outputs` 记录结果。

使用如下规则输入：

```gdscript
var rule := {
	"id": "rule_cookie",
	"recipe_id": "butter_cookie",
	"device_id": "oven",
	"batches": 1,
	"target_stock": 3,
	"material_reserves": {},
	"priority": 0,
	"sort_order": 0,
	"allow_offline": true,
	"enabled": true
}
```

- [ ] **Step 2: 运行自检并确认因规则接口缺失而失败**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-kitchen-red.log" -s res://tests/automation_settlement_self_check.gd
```

Expected: FAIL because `save_kitchen_rule` does not exist。

- [ ] **Step 3: 扩展厨房队列来源字段且保持兼容**

把 `GameState.queue_recipe_production()` 签名扩展为：

```gdscript
func queue_recipe_production(
	recipe_id: String,
	batches: int = 1,
	now_unix: int = -1,
	source: String = "manual",
	automation_rule_id: String = ""
) -> bool:
```

队列记录新增：

```gdscript
"source": source if source in ["manual", "automation"] else "manual",
"automation_rule_id": automation_rule_id if source == "automation" else ""
```

`_sanitize_recipe_production_queue()` 同步清洗这两个字段，旧存档默认 `manual`。

- [ ] **Step 4: 实现规则清洗、保存和升级上限**

`save_kitchen_rule()` 必须校验配方、设备、批量只能为 1/5、目标库存非负、保留量非负、规则数上限和托管设备数上限。成功时返回完整清洗后的规则：

```gdscript
{
	"ok": true,
	"rule": sanitized_rule,
	"created": true
}
```

没有 `kitchen_priority` 升级时把 `priority` 强制为 0；没有 `kitchen_inventory_policy` 时把 `material_reserves` 清空。规则 ID 为空时使用 `rule_%d` 与单调递增序号生成，不能使用数组索引作为身份。

`GameState.from_dict()` 清洗旧规则时执行两条不同策略：未知配方/设备的规则删除，并把 `invalid_recipe`/`invalid_device` 警告追加到 `pending_automation_report.pauses`；合法但超过当前规则或设备上限的规则保留原配置，强制 `enabled=false`，暂停原因写 `limit_reached`。不得静默删除超量的合法玩家配置。

上限与能力查询必须使用以下固定规则：

```gdscript
static func kitchen_rule_limit(state) -> int:
	if bool(state.automation_upgrades.get("kitchen_all", false)):
		return 8
	if bool(state.automation_upgrades.get("kitchen_rules_3", false)):
		return 3
	return 1


static func kitchen_device_limit(state) -> int:
	if bool(state.automation_upgrades.get("kitchen_all", false)):
		return -1
	if bool(state.automation_upgrades.get("kitchen_devices_2", false)):
		return 2
	return 1


static func priority_enabled(state) -> bool:
	return bool(state.automation_upgrades.get("kitchen_priority", false))


static func inventory_policy_enabled(state) -> bool:
	return bool(state.automation_upgrades.get("kitchen_inventory_policy", false))
```

- [ ] **Step 5: 把厨房事件合并进统一时间循环**

每次循环按以下顺序执行：

```gdscript
_start_available_kitchen_rules(state, cursor_unix, report, offline_mode)
var event := _next_event(state, cursor_unix, end_unix)
if event.is_empty():
	break
cursor_unix = int(event.get("at", cursor_unix))
match String(event.get("kind", "")):
	"output_ready":
		_accumulate_output_result(report, ProductionSite.settle_ready_slot(state, int(event.get("array_index", -1)), cursor_unix, true))
	"kitchen_ready":
		_accumulate_kitchen_result(report, _complete_kitchen_queue(state, int(event.get("queue_index", -1)), cursor_unix))
```

`_start_available_kitchen_rules()` 必须先跳过有手动队列的设备，再按优先级降序和 `sort_order` 升序选择规则。启动前验证目标库存和保留量，随后调用现有 `queue_recipe_production(..., "automation", rule_id)`，不得复制材料扣除逻辑。

- [ ] **Step 6: 完成结构化暂停原因**

规则状态返回统一结构：

```gdscript
{
	"running": false,
	"paused": true,
	"reason": {
		"code": "material_reserve",
		"item_id": "sugar",
		"required": 5,
		"available": 4,
		"first_stopped_at_unix": 1040
	}
}
```

至少实现 `missing_input`、`insufficient_coins`、`manual_queue_busy`、`target_reached`、`material_reserve`、`invalid_recipe`、`invalid_device` 和 `limit_reached`。

- [ ] **Step 7: 扩展自动化自检**

覆盖：手动队列优先；同设备自动规则按优先级/排序选择；目标库存停止；保留量阻止开工；自动完成推进配方成长；`allow_offline=false` 的规则在线可运行、离线不运行；无自动售卖或上架副作用。

- [ ] **Step 8: 运行厨房与 MVP 自检**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-kitchen-green.log" -s res://tests/automation_settlement_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-kitchen-mvp.log" -s res://tests/mvp_self_check.gd
```

Expected: 两个脚本均 PASS。

- [ ] **Step 9: 审阅点（不提交）**

运行 `git diff --check -- scripts/automation_service.gd scripts/game_state.gd tests/automation_settlement_self_check.gd tests/mvp_self_check.gd` 后停止。

---

### Task 5: 离线结算、原子保存与防重复领取

**Files:**
- Modify: `scripts/save_system.gd`
- Modify: `scripts/automation_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `tests/mvp_self_check.gd`
- Modify: `tests/automation_settlement_self_check.gd`

**Interfaces:**
- Consumes: `AutomationService.settle()`、现有 `_replace_file_with_temp()`。
- Produces:
  - `SaveSystem.load_game(path, broken_path, now_unix: int = -1)` 可注入测试时间。
  - `SaveSystem.apply_offline_automation(state, now_unix: int) -> Dictionary`
  - 成功离线结算后持久化 `automation_last_settled_unix` 与 `pending_automation_report`。

- [ ] **Step 1: 写防重复领取失败自检**

在 `tests/mvp_self_check.gd` 的存档段落创建固定保存：`automation_last_settled_unix=1000`，托管槽 1020 成熟；以 `now_unix=1100` 加载两次，断言第一次增加库存并保存时间 1100，第二次库存不再增加。

- [ ] **Step 2: 运行自检并确认旧加载接口失败**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-offline-red.log" -s res://tests/mvp_self_check.gd
```

Expected: FAIL，指出 `load_game` 不接受固定时间或离线结果重复。

- [ ] **Step 3: 用自动化服务替换旧离线成熟计数**

把 `load_game()` 扩展为：

```gdscript
static func load_game(path: String = SAVE_PATH, broken_path: String = "", now_unix: int = -1):
	# 读取与解析保持现有逻辑
	var state = GameStateScript.from_dict(json.data as Dictionary)
	var current_time := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var report := apply_offline_automation(state, current_time)
	if not report.is_empty() and not save_game(state, path, current_time):
		return GameStateScript.from_dict(json.data as Dictionary)
	return state
```

同时给 `save_game()` 增加可选 `now_unix`，测试时不读取系统时间。

- [ ] **Step 4: 实现离线时长、倒退时间和安全上限**

`apply_offline_automation()`：

```gdscript
static func apply_offline_automation(state, now_unix: int) -> Dictionary:
	var from_unix := maxi(0, int(state.automation_last_settled_unix))
	if from_unix <= 0:
		state.automation_last_settled_unix = now_unix
		return {}
	if now_unix <= from_unix:
		state.pending_automation_report = {
			"duration_seconds": 0,
			"pauses": [{"kind": "system", "key": "clock", "reason": {"code": "clock_rollback", "first_stopped_at_unix": now_unix}}]
		}
		return state.pending_automation_report.duplicate(true)
	var limit_seconds := AutomationService.offline_seconds_limit(state)
	var report := AutomationService.settle(state, from_unix, now_unix, limit_seconds)
	state.automation_last_settled_unix = now_unix
	state.pending_automation_report = report.duplicate(true)
	return report
```

即使时长被 2/4/8 小时上限截断，`automation_last_settled_unix` 也推进到本次加载时间，超出上限部分永久放弃，不能在下一次加载补领。

- [ ] **Step 5: 保留旧未托管槽的成熟提示**

删除 `_apply_offline_ready_state()` 的旧单次计数职责，但在自动化结算后调用 `ProductionSite.evaluate_slots(state, now_unix)`，并把未托管且离线期间成熟的槽数量写回 `offline_ready_count`，保持旧手动玩法提示。

- [ ] **Step 6: 验证失败时回滚原状态**

若原子保存失败，`load_game()` 返回结算前由原 JSON 重建的状态，并不展示简报；日志写 `offline_automation_save_failed`。不得返回已经加库存但未落盘的半完成对象。

- [ ] **Step 7: 运行存档与自动化自检**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-offline-green.log" -s res://tests/mvp_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-offline-automation.log" -s res://tests/automation_settlement_self_check.gd
```

Expected: PASS；重复加载不重复加资源，时间倒退收益为 0，10,000 事件上限产生截断报告。

- [ ] **Step 8: 审阅点（不提交）**

运行 `git diff --check -- scripts/save_system.gd scripts/automation_service.gd scripts/game_state.gd tests/mvp_self_check.gd tests/automation_settlement_self_check.gd` 后停止。

---

### Task 6: 图鉴领取、顶部星辉与自动化升级中枢

**Files:**
- Create: `scenes/ui/overlays/automation_overlay.tscn`
- Create: `scripts/ui/overlays/automation_overlay.gd`
- Modify: `scenes/ui/overlays/catalog_overlay.tscn`
- Modify: `scripts/ui/overlays/catalog_overlay.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `scripts/game_state.gd`
- Test: `tests/component_contract_self_check.gd`
- Test: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: Task 1 星辉接口、`StarProgressionService.upgrade_definition()`。
- Produces:
  - `GameState.purchase_automation_upgrade(upgrade_id: String) -> Dictionary`
  - `CatalogOverlay.catalog_reward_claim_requested(recipe_id)`（已有，接通真实领取）
  - `CatalogOverlay.catalog_reward_claim_all_requested()`（新增）
  - `CatalogOverlay.catalog_milestone_claim_requested(percent: int)`（新增）
  - `AutomationOverlay.upgrade_requested(upgrade_id)`

- [ ] **Step 1: 写场景和信号契约失败自检**

在 `component_contract_self_check.gd` 要求 `catalog_overlay.gd` 暴露 `catalog_reward_claim_all_requested` 和 `catalog_milestone_claim_requested`，`automation_overlay.gd` 暴露 `close_requested`、`upgrade_requested`、`pause_all_requested`。在 `mvp_self_check.gd` 要求节点：

```text
Root/TopBar/StarlightButton
GlobalOverlayLayer/OverlayFrame/OverlayModeStack/AutomationOverlay
GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogSummaryRow/CatalogStarlightLabel
GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogRewardActions/CatalogClaimAllRewardsButton
```

- [ ] **Step 2: 运行契约自检并确认失败**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-ui-contract-red.log" -s res://tests/component_contract_self_check.gd
```

Expected: FAIL，指出新增信号或场景缺失。

- [ ] **Step 3: 实现自动化升级购买事务**

在 `GameState` 增加：

```gdscript
func purchase_automation_upgrade(upgrade_id: String) -> Dictionary:
	if upgrade_id.is_empty() or bool(automation_upgrades.get(upgrade_id, false)):
		return {"ok": false, "reason": "升级已购买或无效"}
	var definition := StarProgressionService.upgrade_definition(upgrade_id)
	if definition.is_empty():
		return {"ok": false, "reason": "升级不存在"}
	var feature_id := String(definition.get("feature", ""))
	if not is_automation_unlocked(feature_id):
		return {"ok": false, "reason": "对应自动化尚未解锁"}
	for required_upgrade in definition.get("requires_upgrades", []):
		if not bool(automation_upgrades.get(String(required_upgrade), false)):
			return {"ok": false, "reason": "需要先完成前置升级"}
	var cost := maxi(0, int(definition.get("cost", 0)))
	if not spend_starlight(cost):
		return {"ok": false, "reason": "食谱星辉不足"}
	automation_upgrades[upgrade_id] = true
	add_log("automation_upgrade:%s:%d" % [upgrade_id, cost])
	return {"ok": true, "cost": cost, "upgrade_id": upgrade_id}
```

- [ ] **Step 4: 扩展图鉴场景而不覆盖现有星级完成度**

在 `CatalogSummaryRow` 增加 `CatalogStarlightLabel`，默认文本“食谱星辉 0｜累计 0”；在摘要行下方新增 `CatalogRewardActions`，其中放置 `CatalogClaimAllRewardsButton`，避免把第三个固定宽度按钮塞进现有 340px 详情动作行。`CatalogStarLabel` 继续显示“星级完成度 N%”。

`catalog_overlay.gd` 新增信号并在 `_ready()` 连接按钮。`main_view.gd` 的 `_on_catalog_claim_reward_pressed()` 改为调用 `state.claim_recipe_starlight(selected_catalog_recipe_id)`；“领取全部”调用 `state.claim_recipe_starlight()`。成功后保存、刷新顶部与图鉴，并通过现有通知队列展示总量。

现有 25%/50%/75%/100% 里程碑按钮改为可交互：未达成显示进度并禁用；达成未领取显示“可领取”；已经存在 `catalog_milestone:<percent>` 领取键时显示“已领取”并禁用。点击时从 `StarProgressionService.claimable_recipe_rewards(state)` 中找到对应 key 并调用 `state.claim_starlight_reward()`。

- [ ] **Step 5: 创建自动化中枢场景**

`automation_overlay.tscn` 至少包含：

```text
AutomationOverlay
  SummaryRow/StarlightBalanceLabel
  SummaryRow/NextUnlockLabel
  OutputSection/OutputStatusLabel
  OutputSection/OutputUpgradeGrid
  KitchenSection/KitchenStatusLabel
  KitchenSection/KitchenUpgradeGrid
  Footer/PauseAllButton
```

升级按钮使用配置 ID 作为 metadata，文本显示“名称｜效果｜消耗 N 星辉”；未解锁、已购买或余额不足时禁用并给出 tooltip。

- [ ] **Step 6: 接入顶部入口和全局弹层模式**

在 `Main.tscn` 的 `LevelLabel` 后增加 `StarlightButton`。在 OverlayModeStack 实例化 `AutomationOverlay`。`main_view.gd` 增加 `automation` 模式，与 task/inventory/catalog 共用背景关闭、标题和互斥切换逻辑。

`pause_all_requested` 调用 `AutomationService.set_global_paused(state, not state.automation_paused)`，保存后刷新中枢、产出格和厨房面板；按钮文本必须在“暂停全部自动化”和“恢复全部自动化”之间切换。

- [ ] **Step 7: 运行契约和 MVP 场景自检**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-ui-contract-green.log" -s res://tests/component_contract_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-ui-mvp.log" -s res://tests/mvp_self_check.gd
```

Expected: PASS；现有图鉴完成度仍显示百分比，食谱星辉独立显示。

在 `mvp_self_check.gd` 同时断言：升级前置未满足时不扣星辉；购买成功只扣可用星辉；图鉴里程碑与阶段补发各只能领取一次。

- [ ] **Step 8: 审阅点（不提交）**

运行 `git diff --check` 限定本任务文件后停止。

---

### Task 7: 场景化产出格与托管交互

**Files:**
- Create: `scenes/ui/pages/output_cell.tscn`
- Modify: `scripts/output_cell.gd`
- Modify: `scenes/ui/pages/workbench_pages.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/output_layout_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `AutomationService.set_output_managed()`、`ProductionSite.slot_key()`。
- Produces:
  - `OutputCell.automation_toggled(site_id: String, slot_index: int, managed: bool)`
  - `OutputCell.configure_automation(managed: bool, available: bool, status_text: String, pause_reason: String)`

- [ ] **Step 1: 写产出格节点失败自检**

在 `output_layout_self_check.gd` 实例化 `output_cell.tscn` 并断言存在 `ProductionProgressBar`、`AutomationToggle`、`AutomationStatusLabel`；未解锁时 toggle 隐藏，托管暂停时状态文本包含具体原因。

- [ ] **Step 2: 运行并确认场景缺失**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-output-cell-red.log" -s res://tests/output_layout_self_check.gd
```

Expected: FAIL because `output_cell.tscn` does not exist。

- [ ] **Step 3: 创建稳定产出格场景**

场景结构：

```text
OutputCell (Button, script=output_cell.gd)
  ProductionProgressBar
  AutomationStatusLabel
  AutomationToggle
```

进度条与状态标签使用 `MOUSE_FILTER_IGNORE`；托管按钮位于右上角，不拦截主按钮拖放区域之外的交互。

- [ ] **Step 4: 扩展 `output_cell.gd`**

增加：

```gdscript
signal automation_toggled(site_id: String, slot_index: int, managed: bool)

func configure_automation(managed: bool, available: bool, status_text: String, pause_reason: String) -> void:
	$AutomationToggle.visible = available
	$AutomationToggle.button_pressed = managed
	$AutomationStatusLabel.visible = available and not status_text.is_empty()
	$AutomationStatusLabel.text = status_text
	$AutomationToggle.tooltip_text = pause_reason if not pause_reason.is_empty() else ("停止托管" if managed else "启用托管")
```

`_ready()` 连接 toggle，并从根按钮 metadata 读取 `site_id`、`slot_index`。

- [ ] **Step 5: 让 `main_view.gd` 实例化场景而非动态拼稳定子节点**

把 `OutputCellButton.new()` 与 `_attach_output_progress_bar()` 替换为 `OutputCellScene.instantiate()`。活动槽根据 `managed_production_slots` 和结构化暂停原因调用 `configure_automation()`；闲置、锁定和背包产物格隐藏托管控件。

托管切换处理：

```gdscript
func _on_output_automation_toggled(site_id: String, slot_index: int, managed: bool) -> void:
	var result := AutomationService.set_output_managed(state, site_id, slot_index, managed)
	_set_status("托管设置已更新。" if bool(result.get("ok", false)) else String(result.get("reason", "无法更新托管设置。")))
	_save_game()
	_refresh_output_page()
```

- [ ] **Step 6: 在线刷新时结算到当前时间**

在现有 `_process()` 的每秒 tick 中、页面专属刷新之前先处理首次时间基线，再调用结算；自动化必须在采购、研发制作或橱窗经营页面停留时也继续运行：

```gdscript
if state.automation_last_settled_unix <= 0:
	state.automation_last_settled_unix = now_unix
else:
	var report := AutomationService.settle(state, state.automation_last_settled_unix, now_unix, -1)
	state.automation_last_settled_unix = now_unix
	if int(report.get("event_count", 0)) > 0:
		_merge_online_automation_feedback(report)
		_save_game()
```

随后只有当前页面是产出页时才调用 `_refresh_output_countdown_texts(now_unix)`。不得每帧保存，只在至少发生一个事件时保存；首次进入只建立时间基线，不能从 Unix 0 开始结算。

- [ ] **Step 7: 运行产出布局、自动化和 MVP 自检**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-output-cell-green.log" -s res://tests/output_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-output-auto.log" -s res://tests/automation_settlement_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-output-mvp.log" -s res://tests/mvp_self_check.gd
```

Expected: 全部 PASS。

- [ ] **Step 8: 审阅点（不提交）**

检查产出格 scene-first 约束、拖放回归和 diff 后停止。

---

### Task 8: 厨房排程面板与自动化简报

**Files:**
- Create: `scenes/ui/pages/kitchen_automation_panel.tscn`
- Create: `scripts/ui/pages/kitchen_automation_panel.gd`
- Create: `scenes/ui/overlays/automation_report_dialog.tscn`
- Create: `scripts/ui/overlays/automation_report_dialog.gd`
- Modify: `scenes/ui/pages/workbench_pages.tscn`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/component_contract_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `AutomationService.save_kitchen_rule()`、`remove_kitchen_rule()`、`kitchen_rule_status()`、`GameState.pending_automation_report`。
- Produces:
  - `KitchenAutomationPanel.rule_save_requested(rule: Dictionary)`
  - `KitchenAutomationPanel.rule_remove_requested(rule_id: String)`
  - `KitchenAutomationPanel.pause_toggled(paused: bool)`
  - `AutomationReportDialog.navigate_requested(kind: String, key: String)`

- [ ] **Step 1: 写组件契约与主场景节点失败自检**

要求以下节点存在：

```text
Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/SecondaryList/KitchenAutomationPanel
AutomationReportDialog
```

要求两个新脚本暴露本任务列出的信号。

- [ ] **Step 2: 运行契约自检并确认失败**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-kitchen-ui-red.log" -s res://tests/component_contract_self_check.gd
```

Expected: FAIL，指出组件或信号缺失。

- [ ] **Step 3: 创建厨房排程面板**

场景结构：

```text
KitchenAutomationPanel
  Header/TitleLabel
  Header/PauseToggle
  LockedMessage
  RuleList
  Editor
    RecipeOption
    BatchOption
    TargetStockSpin
    PriorityOption
    OfflineToggle
    MaterialReserveList
    SaveRuleButton
    RemoveRuleButton
```

未解锁时只显示 Lv.4、累计 30 星辉和前置条件；解锁后显示规则。没有优先级/库存策略升级时，相应控件禁用并在 tooltip 显示解锁方式。

- [ ] **Step 4: 接入研发制作页而不新增主导航页**

在 `workbench_pages.tscn` 的 `SecondaryList` 中，把 `KitchenAutomationPanel` 放在 `RecipeScroll` 之前。`_refresh_research_page()` 在厨房自动化解锁后显示面板，并保留现有配方制作列表；面板折叠时不挤压列表。

保存/删除规则后调用服务、保存存档、刷新面板和配方行。失败时用状态栏显示服务返回的真实原因。

- [ ] **Step 5: 创建自动化简报场景**

场景结构：

```text
AutomationReportDialog (AcceptDialog)
  ReportBody
    SummaryLabel
    OutputList
    ProductList
    GrowthList
    PauseList
    NavigateButton
```

`configure(report)` 格式化时长、原料、甜品、成长、循环和暂停原因；选择暂停项后“前往处理”发出 `kind/key`。

- [ ] **Step 6: 把简报接入现有通知队列顺序**

离线结算有实际事件或暂停原因时，`SaveSystem`/加载协调器增加一条：

```gdscript
state.enqueue_notification("自动化简报", "离线自动化已结算。", {
	"kind": "automation_report"
})
```

若现有 `enqueue_notification()` 只接受两个参数，把第三个 `metadata: Dictionary = {}` 作为兼容可选参数保存到通知记录。`_show_next_notification()` 遇到 `kind=automation_report` 时显示 `AutomationReportDialog`，否则继续使用 `TaskPopup`；两者不得同时弹出。

关闭简报后清空 `pending_automation_report` 并保存。

- [ ] **Step 7: 实现“前往处理”定位**

- `kind=output`：关闭弹窗，切到产出页，切换对应地点页并选中槽位。
- `kind=kitchen`：关闭弹窗，切到研发制作页，展开厨房排程面板并选中规则。
- `kind=system`：只关闭弹窗并在状态栏显示系统时间或事件上限说明。

- [ ] **Step 8: 运行契约、主场景和自动化自检**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-kitchen-ui-green.log" -s res://tests/component_contract_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-kitchen-ui-mvp.log" -s res://tests/mvp_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-kitchen-ui-auto.log" -s res://tests/automation_settlement_self_check.gd
```

Expected: 全部 PASS，简报节点与导航契约存在。

- [ ] **Step 9: 审阅点（不提交）**

检查 scene-first、通知互斥和工作台宽度回归后停止。

---

### Task 9: 全链路回归、架构守卫与规格同步

**Files:**
- Modify: `tests/mvp_self_check.gd`
- Modify: `tests/main_scene_split_shell_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`
- Modify: `docs/superpowers/specs/2026-07-10-automation-starlight-design.zh.md`
- Modify: `doc/2026-07-09-post-mvp-task-completion-plan.md`

**Interfaces:**
- Consumes: Tasks 1-8 的全部公共接口。
- Produces: 可重复执行的完整验证门槛和与运行时一致的项目文档。

- [ ] **Step 1: 增加完整玩家路径自检**

在 `mvp_self_check.gd` 增加一条从旧存档开始的完整路径：补发配方星辉 → 领取到累计 12 → Lv.3 功能任务 → 解锁产地托管 → 离线产出 → 累计 30 → Lv.4 功能任务 → 解锁厨房规则 → 产地供料驱动厨房制作 → 简报保存往返。

关键断言：

```gdscript
if int(state.recipe_starlight_total) < 30:
	_fail("full automation route should reach 30 lifetime starlight")
if not state.is_automation_unlocked("output") or not state.is_automation_unlocked("kitchen"):
	_fail("full automation route should unlock both automation stages")
if state.pending_automation_report.is_empty():
	_fail("offline automation should persist a report for UI consumption")
```

- [ ] **Step 2: 增加架构守卫**

在 `main_scene_split_shell_self_check.gd` 禁止 `main_view.gd` 新增以下算法实现：

```gdscript
"func _settle_automation_event": "main_view.gd must delegate automation settlement to AutomationService",
"func _claimable_starlight_rewards": "main_view.gd must delegate starlight enumeration to StarProgressionService",
"func _consume_automation_materials": "main_view.gd must reuse GameState queue transactions"
```

同时要求 `AutomationService` 和 `StarProgressionService` 存在对应公共方法。

- [ ] **Step 3: 更新后 MVP 任务文档**

在 `doc/2026-07-09-post-mvp-task-completion-plan.md` 的 P5 段落追加完成项，明确：星辉连接配方成长与自动化；Lv.3 只自动产地；Lv.4 才自动厨房；仍不自动上架和售卖。不要覆盖历史版本文档。

- [ ] **Step 4: 校准规格中的实际落点**

在设计规格 UI 段注明：当前项目没有独立升级导航页，第一版通过顶部星辉按钮打开全局“自动化中枢”，它承担规格中的自动化升级页职责；图鉴原“星级完成度”保持不变。

- [ ] **Step 5: 运行全部相关自检**

Run:

```powershell
$tests = @(
  'automation_settlement_self_check.gd',
  'task_mainline_self_check.gd',
  'component_contract_self_check.gd',
  'output_layout_self_check.gd',
  'main_scene_split_shell_self_check.gd',
  'mvp_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-$test.log" -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: 六个脚本全部 PASS，无 parser error、invalid node path 或 save-path 污染。

- [ ] **Step 6: 运行静态差异检查**

Run:

```powershell
git diff --check
git status --short
```

Expected: 无 whitespace error；确认没有覆盖用户原有 `.gitignore`、配方图标生成或 `output/`、`tmp/` 相关变更。

- [ ] **Step 7: 最终审阅点（不提交）**

逐项对照规格第 12 节验收标准，记录每条标准对应的自检脚本和断言位置。向用户报告已修改文件、验证命令与结果；等待用户明确要求后再决定是否提交 Git。

---

## Execution Notes

- 本计划虽然包含星辉、产地自动化、厨房自动化和 UI，但四者共享同一持久化模型、解锁任务与离线时间轴，拆成独立计划会造成不可运行的中间状态，因此保留为一个顺序执行计划。
- Task 1-2 先建立可独立验证的成长资源和解锁门槛；Task 3-5 建立不依赖 UI 的纯运行时；Task 6-8 再接入场景；Task 9 执行最终整合。
- 如果执行时发现 `main_view.gd` 的协调代码继续膨胀，只允许把页面渲染/信号逻辑下沉到本计划列出的组件脚本，不做与自动化无关的重构。
