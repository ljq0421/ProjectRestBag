# 橱窗销售脉冲反馈 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变当前左橱窗、右侧四页工作台结构的前提下，让真实自动成交产生可解释的销售脉冲，并让右侧“橱窗经营”提供不会重复入账的集中收银回放。

**Architecture:** `_process_showcase_sales()` 与 `_sell_ready_showcase_slot()` 继续承担唯一真实成交；`ShowcaseRuleService` 输出同源归因和关系上下文；瞬态 `ShowcaseFeedbackDirector` 只管理三秒连售、三件显示上限和溢出压缩；`GameState.cashier_summary` 是唯一持久化收银汇总。左侧表现层消费瞬态批次，右侧橱窗经营消费并清空已入账汇总，任何表现路径都不修改金币或口碑。

**Tech Stack:** Godot 4.6.1、GDScript、scene-first `.tscn` UI、现有 `ShopSimulation` / `ShowcaseRuleService` / `GameState`、Godot headless self-check。

## Global Constraints

- 保持 `StorefrontPanel.size_flags_stretch_ratio = 63.0`、`WorkbenchPanel.size_flags_stretch_ratio = 37.0`。
- 保持采购、产出、研发制作、橱窗经营四个右侧页面，以及 `Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid` 直接路径。
- 保持 10x10 物理棋盘、中心 6x6 初始开放区和外围锁定格语义。
- 自动成交立即增加金币、口碑、任务进度和配方成长；“集中收银”只查看并清空已入账汇总，绝不能再次增加经济数值。
- UI 只消费 `ShowcaseRuleService` 的真实结果；不得在 UI 层重新推导位置、相邻、套装或冲突规则。
- 左侧反馈层必须 `mouse_filter = Control.MOUSE_FILTER_IGNORE`；浮字、关系线、金币轨迹和回放不得阻塞拖拽、旋转、移动或页面切换。
- 一个视觉批次最多显示 3 个单件反馈；其余合并为 `+N 件`；三秒内同一套装更新同一个连售计数。
- 即时反馈最多显示 1 条主要正向原因和 1 条主要负向原因；完整原因保留在右侧账单和最近收银。
- 不新增顾客寻路、排队、取货或全屏结算弹窗，不调整既有橱窗规则数值。
- 当前工作树已有无关改动。未获用户明确授权不得提交 Git，也不得改写、清理或暂存无关文件。
- 所有 Godot headless 命令从 `D:\Project\ProjectRest\project-rest` 运行，并显式传入 `--log-file "$env:TEMP\godot-headless.log"`。

---

## File Structure

- Modify: `scripts/shop_simulation.gd` — 在现有相邻、套装和冲突 breakdown 中附带稳定的关联配方与套装元数据，不改变倍率。
- Modify: `scripts/showcase_rule_service.gd` — 输出可重建最终售价的归因，以及 UI 可直接消费的套装/关联/冲突上下文。
- Create: `scripts/ui/storefront/showcase_feedback_director.gd` — 纯 `RefCounted` 瞬态队列；负责三秒连售、三件上限和溢出压缩，不引用节点、不保存经济数据。
- Modify: `scripts/game_state.gd` — 持久化唯一 `cashier_summary`，累计商品/套装贡献和最近 12 条安全事件；旧存档回退为空。
- Modify: `scripts/main_view.gd` — 使用同源规则完成售卖、生成事件、写汇总、调度左侧脉冲和消费右侧账单。
- Modify: `scenes/Main.tscn` — 新增根级鼠标穿透反馈层，不进入 `MainArea` 布局。
- Modify: `scenes/ui/storefront/showcase_board.tscn` — 新增左侧本轮累计筹码，不改变 `ShowcaseGrid` 路径。
- Create: `tests/showcase_sale_feedback_self_check.gd` — 覆盖瞬态批次、持久化汇总、旧存档和消费幂等性。
- Modify: `tests/showcase_bonus_reason_self_check.gd` — 覆盖同源归因、稳定套装 ID 和冲突关联。
- Modify: `tests/storefront_grid_layout_self_check.gd` — 覆盖 63/37、10x10、反馈层鼠标穿透和直接路径。
- Modify: `tests/right_console_experience_self_check.gd` — 覆盖集中收银原位账单、六分区和不重复入账。
- Modify: `tests/component_contract_self_check.gd` — 锁定反馈组件与场景节点职责。
- Modify: `tests/mvp_self_check.gd` — 走真实自动成交、左侧反馈、汇总消费和重复点击路径。

---

### Task 1: 为真实规则结果补齐售卖归因与关系元数据

**Files:**

- Modify: `scripts/shop_simulation.gd:123-224, 330-540`
- Modify: `scripts/showcase_rule_service.gd:1-240`
- Modify: `tests/showcase_bonus_reason_self_check.gd`

**Interfaces:**

- Produces: `ShowcaseRuleService.sale_attribution(base_price: int, final_price: int, bonus: Dictionary) -> Dictionary`。
- Produces: `ShowcaseRuleService.sale_context(bonus: Dictionary) -> Dictionary`。
- `sale_context()` returns `groups`、`related_recipe_ids`、`conflict_recipe_ids`。
- `sale_attribution()` returns `base_coins`、`position_adjacency_coins`、`set_growth_coins`、`other_delta`、`conflict_loss`，且严格满足 `base + position_adjacency + set_growth + other_delta - conflict_loss == final_price`。

- [ ] **Step 1: 写归因和关系元数据的失败断言**

在 `tests/showcase_bonus_reason_self_check.gd` 顶部加入：

```gdscript
const SHOP_SIMULATION := preload("res://scripts/shop_simulation.gd")
```

在现有 `bonus` 断言后，先用纯规则输入验证真实套装和冲突计算会附加关系元数据：

```gdscript
var relation_cells := {
	"tea_item": [Vector2i(1, 1)],
	"crisp_item": [Vector2i(1, 2)],
	"rich_item": [Vector2i(1, 3)]
}
var relation_recipes := {
	"tea_item": {"name": "茶饮", "tags": ["茶香", "清凉"]},
	"crisp_item": {"name": "脆点", "tags": ["香脆"]},
	"rich_item": {"name": "浓点", "tags": ["浓郁"]}
}
var set_parts: Dictionary = SHOP_SIMULATION._calc_set_bonuses(relation_cells, relation_recipes, {
	"set_test": {"set_name": "测试下午茶", "required_tags": ["茶香", "香脆", "浓郁"], "min_item_count": 3, "price_bonus_pct": 10, "speed_bonus_pct": 5}
})
var tea_set_part: Dictionary = set_parts.get("tea_item", {})
var actual_groups: Array = tea_set_part.get("groups", [])
if actual_groups.size() != 1 or String((actual_groups[0] as Dictionary).get("id", "")) != "set_test":
	_fail("real set calculation should expose stable group metadata")
var actual_related_ids: Array = tea_set_part.get("related_recipe_ids", [])
if not actual_related_ids.has("crisp_item"):
	_fail("real set calculation should expose related members")
var conflict_parts: Dictionary = SHOP_SIMULATION._calc_conflict_penalties(relation_cells, relation_recipes, {
	"penalty_002": {"penalty_name": "测试口感冲突", "conflict_tags": ["清凉", "浓郁"], "price_penalty_pct": -5}
})
var tea_conflict_part: Dictionary = conflict_parts.get("tea_item", {})
var actual_conflict_ids: Array = tea_conflict_part.get("related_recipe_ids", [])
if not actual_conflict_ids.has("rich_item"):
	_fail("real conflict calculation should expose conflicting recipes")
```

随后加入归因与上下文的独立合约；它不依赖当前平衡数值：

```gdscript
var synthetic_bonus := {
	"price_multiplier": 1.2,
	"breakdown": {
		"zone": {"price_pct": 10.0},
		"adjacency_tag": {"price_pct": 5.0, "related_recipe_ids": ["butter_cookie"]},
		"set": {
			"price_pct": 12.0,
			"groups": [{"id": "set_001", "label": "经典下午茶三件套", "recipe_ids": ["sponge_cake", "butter_cookie"]}],
			"related_recipe_ids": ["butter_cookie"]
		},
		"growth": {"price_pct": 3.0},
		"conflict": {"price_pct": -5.0, "related_recipe_ids": ["mint_mousse"]}
	}
}
var attribution := ShowcaseRuleService.sale_attribution(100, 120, synthetic_bonus)
var rebuilt := int(attribution.get("base_coins", 0)) \
		+ int(attribution.get("position_adjacency_coins", 0)) \
		+ int(attribution.get("set_growth_coins", 0)) \
		+ int(attribution.get("other_delta", 0)) \
		- int(attribution.get("conflict_loss", 0))
if rebuilt != 120:
	_fail("sale attribution should exactly reconstruct final price")
if int(attribution.get("conflict_loss", 0)) <= 0:
	_fail("negative conflict price pct should expose a visible loss")
var context := ShowcaseRuleService.sale_context(synthetic_bonus)
var groups: Array = context.get("groups", [])
if groups.size() != 1 or String((groups[0] as Dictionary).get("id", "")) != "set_001":
	_fail("sale context should preserve stable set ids")
var related_recipe_ids: Array = context.get("related_recipe_ids", [])
if not related_recipe_ids.has("butter_cookie"):
	_fail("sale context should expose positive related recipes")
var conflict_recipe_ids: Array = context.get("conflict_recipe_ids", [])
if not conflict_recipe_ids.has("mint_mousse"):
	_fail("sale context should expose conflicting recipes")
```

- [ ] **Step 2: 运行红灯验证**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_bonus_reason_self_check.gd
```

Expected: FAIL，缺少 `sale_attribution()` 或 `sale_context()`。

- [ ] **Step 3: 在规则计算层附加稳定关系数据**

在 `scripts/shop_simulation.gd` 的 `_append_bonus_reason()` 后加入两个通用 helper：

```gdscript
static func _append_related_recipe(target: Dictionary, recipe_id: String) -> void:
	if recipe_id.is_empty():
		return
	var ids: Array = target.get("related_recipe_ids", [])
	if not ids.has(recipe_id):
		ids.append(recipe_id)
	target["related_recipe_ids"] = ids


static func _append_set_group(target: Dictionary, set_id: String, set_name: String, recipe_ids: Array) -> void:
	var groups: Array = target.get("groups", [])
	for group_value in groups:
		if group_value is Dictionary and String((group_value as Dictionary).get("id", "")) == set_id:
			return
	groups.append({
		"id": set_id,
		"label": set_name,
		"recipe_ids": recipe_ids.duplicate()
	})
	target["groups"] = groups
```

在 `_calc_adjacency_tag_bonuses()` 的标签规则命中分支、追加原因后加入：

```gdscript
_append_related_recipe(result[recipe_id_a], String(recipe_id_b))
_append_related_recipe(result[recipe_id_b], String(recipe_id_a))
```

在 `_calc_set_bonuses()` 的 `for recipe_id in component` 分支、追加套装原因后加入：

```gdscript
_append_set_group(result[recipe_id], String(set_id), set_name, component)
for member_id in component:
	if String(member_id) != String(recipe_id):
		_append_related_recipe(result[recipe_id], String(member_id))
```

在 `_calc_conflict_penalties()` 的三个惩罚入口附加真实关联对象：

```gdscript
# penalty_001：同类扎堆
for related_id in group:
	if String(related_id) != String(recipe_id):
		_append_related_recipe(result[recipe_id], String(related_id))

# penalty_002：相邻口味冲突
_append_related_recipe(result[id_a], String(id_b))
_append_related_recipe(result[id_b], String(id_a))

# penalty_003：饱腹主餐压制甜品
_append_related_recipe(result[neighbor_id], String(recipe_id))
```

这些字段只附加到 breakdown，不改变 `price_pct`、`speed_pct` 或现有 reason 文案。

- [ ] **Step 4: 实现可精确对账的归因和上下文**

在 `scripts/showcase_rule_service.gd` 添加：

```gdscript
static func sale_attribution(base_price: int, final_price: int, bonus: Dictionary) -> Dictionary:
	var safe_base := maxi(0, base_price)
	var safe_final := maxi(0, final_price)
	var breakdown: Dictionary = bonus.get("breakdown", {})
	var conflict_pct := minf(0.0, _part_price_pct(breakdown.get("conflict", {})))
	var conflict_loss := maxi(0, int(round(float(safe_base) * absf(conflict_pct) / 100.0)))
	var positive_pool := maxi(0, safe_final - safe_base + conflict_loss)
	var position_weight := maxf(0.0, _part_price_pct(breakdown.get("zone", {}))) \
			+ maxf(0.0, _part_price_pct(breakdown.get("adjacency_tag", {})))
	var set_weight := maxf(0.0, _part_price_pct(breakdown.get("set", {}))) \
			+ maxf(0.0, _part_price_pct(breakdown.get("growth", {})))
	var known_weight := position_weight + set_weight
	var position_coins := 0
	var set_coins := 0
	if known_weight > 0.0:
		position_coins = int(round(float(positive_pool) * position_weight / known_weight))
		set_coins = positive_pool - position_coins
	var other_delta := safe_final - safe_base - position_coins - set_coins + conflict_loss
	return {
		"base_coins": safe_base,
		"position_adjacency_coins": position_coins,
		"set_growth_coins": set_coins,
		"other_delta": other_delta,
		"conflict_loss": conflict_loss
	}


static func sale_context(bonus: Dictionary) -> Dictionary:
	var breakdown: Dictionary = bonus.get("breakdown", {})
	var set_part: Dictionary = breakdown.get("set", {})
	var groups: Array = set_part.get("groups", [])
	var related: Array[String] = []
	for key in ["adjacency_tag", "set"]:
		_append_unique_strings(related, (breakdown.get(key, {}) as Dictionary).get("related_recipe_ids", []))
	var conflicts: Array[String] = []
	_append_unique_strings(conflicts, (breakdown.get("conflict", {}) as Dictionary).get("related_recipe_ids", []))
	return {
		"groups": groups.duplicate(true),
		"related_recipe_ids": related,
		"conflict_recipe_ids": conflicts
	}


static func _part_price_pct(part_value: Variant) -> float:
	if not part_value is Dictionary:
		return 0.0
	return float((part_value as Dictionary).get("price_pct", 0.0))


static func _append_unique_strings(target: Array[String], values: Variant) -> void:
	if not values is Array:
		return
	for value in values as Array:
		var text := String(value)
		if not text.is_empty() and not target.has(text):
			target.append(text)
```

`other_delta` 是精确对账余项，吸收变体、主题、道具、黄金 C 位额外倍率和逐层取整；UI 不把它伪装成某条具体规则。

- [ ] **Step 5: 运行绿灯验证**

Run the Step 2 command.

Expected: `SHOWCASE_BONUS_REASON_SELF_CHECK_PASS`，且现有 tooltip/售卖原因断言继续通过。

---

### Task 2: 建立只管理瞬态节奏的反馈导演

**Files:**

- Create: `scripts/ui/storefront/showcase_feedback_director.gd`
- Create: `tests/showcase_sale_feedback_self_check.gd`

**Interfaces:**

- Produces: `enqueue_sale(event: Dictionary, now_msec: int) -> void`。
- Produces: `drain_visual_batch() -> Dictionary`。
- Batch fields: `events`、`overflow_count`、`overflow_coins`、`combo_key`、`combo_label`、`combo_count`、`combo_coins`。
- Invariant: 导演不引用 `GameState`、不保存收银汇总、不修改金币。

- [ ] **Step 1: 写失败的三件上限、溢出和连售断言**

创建 `tests/showcase_sale_feedback_self_check.gd`：

```gdscript
extends SceneTree

const DIRECTOR := preload("res://scripts/ui/storefront/showcase_feedback_director.gd")

var failed := false


func _init() -> void:
	var director = DIRECTOR.new()
	for amount in [48, 32, 51, 27]:
		director.enqueue_sale({
			"recipe_id": "sponge_cake",
			"anchor_slot": 22,
			"cell_indices": [22, 23, 32, 33],
			"earned_coins": amount,
			"combo_key": "set_001",
			"combo_label": "经典下午茶三件套"
		}, 1000)
	var batch: Dictionary = director.drain_visual_batch()
	var visible_events: Array = batch.get("events", [])
	if visible_events.size() != 3:
		_fail("visual batch should expose at most three individual events")
	if int(batch.get("overflow_count", 0)) != 1 or int(batch.get("overflow_coins", 0)) != 27:
		_fail("visual batch should aggregate hidden events without losing coins")
	if int(batch.get("combo_count", 0)) != 4 or int(batch.get("combo_coins", 0)) != 158:
		_fail("same set inside three seconds should update one combo total")
	var drained_again: Dictionary = director.drain_visual_batch()
	var drained_events: Array = drained_again.get("events", [])
	if not drained_events.is_empty():
		_fail("draining a visual batch should clear transient events")
	if failed:
		quit(1)
	print("SHOWCASE_SALE_FEEDBACK_SELF_CHECK_PASS")
	quit(0)


func _fail(message: String) -> void:
	failed = true
	push_error(message)
```

- [ ] **Step 2: 运行红灯验证**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_sale_feedback_self_check.gd
```

Expected: FAIL，导演文件尚不存在。

- [ ] **Step 3: 实现纯瞬态导演**

创建 `scripts/ui/storefront/showcase_feedback_director.gd`：

```gdscript
class_name ShowcaseFeedbackDirector
extends RefCounted

const MAX_VISIBLE_EVENTS := 3
const COMBO_WINDOW_MSEC := 3000

var _pending: Array[Dictionary] = []
var _combo_key := ""
var _combo_label := ""
var _combo_count := 0
var _combo_coins := 0
var _combo_deadline_msec := -1


func enqueue_sale(raw_event: Dictionary, now_msec: int) -> void:
	var event := _normalize_event(raw_event, now_msec)
	var key := String(event.get("combo_key", ""))
	if not key.is_empty() and key == _combo_key and now_msec <= _combo_deadline_msec:
		_combo_count += 1
		_combo_coins += int(event.get("earned_coins", 0))
	else:
		_combo_key = key
		_combo_label = String(event.get("combo_label", ""))
		_combo_count = 1
		_combo_coins = int(event.get("earned_coins", 0))
	_combo_deadline_msec = now_msec + COMBO_WINDOW_MSEC
	event["combo_count"] = _combo_count
	event["combo_coins"] = _combo_coins
	_pending.append(event)


func drain_visual_batch() -> Dictionary:
	var visible: Array[Dictionary] = []
	var overflow_count := 0
	var overflow_coins := 0
	for index in range(_pending.size()):
		var event: Dictionary = _pending[index]
		if index < MAX_VISIBLE_EVENTS:
			visible.append(event.duplicate(true))
		else:
			overflow_count += 1
			overflow_coins += int(event.get("earned_coins", 0))
	_pending.clear()
	return {
		"events": visible,
		"overflow_count": overflow_count,
		"overflow_coins": overflow_coins,
		"combo_key": _combo_key,
		"combo_label": _combo_label,
		"combo_count": _combo_count,
		"combo_coins": _combo_coins
	}


func _normalize_event(raw_event: Dictionary, now_msec: int) -> Dictionary:
	var event := raw_event.duplicate(true)
	event["recipe_id"] = String(event.get("recipe_id", ""))
	event["anchor_slot"] = int(event.get("anchor_slot", -1))
	event["earned_coins"] = maxi(0, int(event.get("earned_coins", 0)))
	event["earned_reputation"] = maxi(0, int(event.get("earned_reputation", 0)))
	event["combo_key"] = String(event.get("combo_key", ""))
	event["combo_label"] = String(event.get("combo_label", ""))
	event["timestamp_msec"] = maxi(0, now_msec)
	return event
```

- [ ] **Step 4: 运行定向验证**

Run the Step 2 command.

Expected: `SHOWCASE_SALE_FEEDBACK_SELF_CHECK_PASS`。

---

### Task 3: 持久化唯一的已入账收银汇总

**Files:**

- Modify: `scripts/game_state.gd:1-190, 974-1030`
- Modify: `tests/showcase_sale_feedback_self_check.gd`

**Interfaces:**

- Produces: `GameState.cashier_summary: Dictionary`。
- Produces: `append_cashier_sale(event: Dictionary) -> void`。
- Produces: `consume_cashier_summary() -> Dictionary`。
- Invariant: `consume_cashier_summary()` 只清空汇总，不修改 `coins`、`reputation`、`business_runs` 或库存。

- [ ] **Step 1: 扩展失败自检为累计、存档和幂等合约**

在 `tests/showcase_sale_feedback_self_check.gd` 顶部加入：

```gdscript
const GAME_STATE := preload("res://scripts/game_state.gd")
```

在 `_init()` 的导演断言后调用 `_expect_state_summary_contract()`，并加入：

```gdscript
func _expect_state_summary_contract() -> void:
	var state = GAME_STATE.new_game()
	state.coins = 500
	var event := {
		"recipe_id": "sponge_cake",
		"recipe_name": "海绵杯蛋糕",
		"anchor_slot": 22,
		"cell_indices": [22, 23, 32, 33],
		"related_slots": [24],
		"conflict_slots": [25],
		"earned_coins": 48,
		"earned_reputation": 1,
		"attribution": {
			"base_coins": 40,
			"position_adjacency_coins": 5,
			"set_growth_coins": 6,
			"other_delta": 0,
			"conflict_loss": 3
		},
		"groups": [{"id": "set_001", "label": "经典下午茶三件套", "recipe_ids": ["sponge_cake"]}]
	}
	state.append_cashier_sale(event)
	state.append_cashier_sale(event)
	if int(state.cashier_summary.get("sold_count", 0)) != 2:
		_fail("cashier summary should accumulate every credited sale")
	if int(state.cashier_summary.get("earned_coins", 0)) != 96:
		_fail("cashier summary should preserve credited coin totals")
	var restored = GAME_STATE.from_dict(state.to_dict())
	if int(restored.cashier_summary.get("earned_coins", 0)) != 96:
		_fail("cashier summary should survive save and load")
	var coins_before := int(restored.coins)
	var consumed: Dictionary = restored.consume_cashier_summary()
	if int(consumed.get("earned_coins", 0)) != 96:
		_fail("consuming summary should return the viewed totals")
	if int(restored.coins) != coins_before:
		_fail("consuming summary must not credit already credited coins")
	if not restored.cashier_summary.is_empty():
		_fail("consuming summary should clear it exactly once")
	if not GAME_STATE.from_dict({"coins": 77}).cashier_summary.is_empty():
		_fail("legacy saves should default cashier summary to empty")
```

- [ ] **Step 2: 运行红灯验证**

Run the Task 2 Step 2 command.

Expected: FAIL，缺少 `append_cashier_sale()` 或存档字段。

- [ ] **Step 3: 实现汇总字段、累计和消费**

在 `GameState` 的 `pending_automation_report` 后加入：

```gdscript
var cashier_summary: Dictionary = {}
```

在 `new_game()` 初始化区加入 `state.cashier_summary = {}`；在 `from_dict()` 加入：

```gdscript
state.cashier_summary = state._sanitize_cashier_summary(data.get("cashier_summary", {}))
```

在 `to_dict()` 返回字典加入：

```gdscript
"cashier_summary": cashier_summary.duplicate(true),
```

在公开状态方法区加入：

```gdscript
func append_cashier_sale(event: Dictionary) -> void:
	if cashier_summary.is_empty():
		cashier_summary = {
			"sold_count": 0,
			"earned_coins": 0,
			"earned_reputation": 0,
			"base_coins": 0,
			"position_adjacency_coins": 0,
			"set_growth_coins": 0,
			"other_delta": 0,
			"conflict_loss": 0,
			"per_recipe": {},
			"per_group": {},
			"recent_events": []
		}
	var attribution: Dictionary = event.get("attribution", {})
	cashier_summary["sold_count"] = int(cashier_summary.get("sold_count", 0)) + 1
	cashier_summary["earned_coins"] = int(cashier_summary.get("earned_coins", 0)) + maxi(0, int(event.get("earned_coins", 0)))
	cashier_summary["earned_reputation"] = int(cashier_summary.get("earned_reputation", 0)) + maxi(0, int(event.get("earned_reputation", 0)))
	for key in ["base_coins", "position_adjacency_coins", "set_growth_coins", "other_delta", "conflict_loss"]:
		cashier_summary[key] = int(cashier_summary.get(key, 0)) + int(attribution.get(key, 0))
	_accumulate_cashier_recipe(event)
	_accumulate_cashier_groups(event)
	var recent: Array = cashier_summary.get("recent_events", [])
	recent.append(_sanitize_cashier_event(event))
	while recent.size() > 12:
		recent.pop_front()
	cashier_summary["recent_events"] = recent


func consume_cashier_summary() -> Dictionary:
	var result := cashier_summary.duplicate(true)
	cashier_summary = {}
	return result


func _accumulate_cashier_recipe(event: Dictionary) -> void:
	var recipe_id := String(event.get("recipe_id", ""))
	if recipe_id.is_empty():
		return
	var totals: Dictionary = cashier_summary.get("per_recipe", {})
	var entry: Dictionary = totals.get(recipe_id, {
		"recipe_id": recipe_id,
		"label": String(event.get("recipe_name", recipe_id)),
		"sold_count": 0,
		"earned_coins": 0,
		"last_anchor_slot": -1
	})
	entry["sold_count"] = int(entry.get("sold_count", 0)) + 1
	entry["earned_coins"] = int(entry.get("earned_coins", 0)) + int(event.get("earned_coins", 0))
	entry["last_anchor_slot"] = int(event.get("anchor_slot", -1))
	totals[recipe_id] = entry
	cashier_summary["per_recipe"] = totals


func _accumulate_cashier_groups(event: Dictionary) -> void:
	var groups: Array = event.get("groups", [])
	if groups.is_empty():
		return
	var amount := maxi(0, int((event.get("attribution", {}) as Dictionary).get("set_growth_coins", 0)))
	var quotient := int(amount / groups.size())
	var remainder := amount % groups.size()
	var totals: Dictionary = cashier_summary.get("per_group", {})
	for index in range(groups.size()):
		if not groups[index] is Dictionary:
			continue
		var group: Dictionary = groups[index]
		var group_id := String(group.get("id", ""))
		if group_id.is_empty():
			continue
		var entry: Dictionary = totals.get(group_id, {"id": group_id, "label": String(group.get("label", group_id)), "trigger_count": 0, "contribution": 0})
		entry["trigger_count"] = int(entry.get("trigger_count", 0)) + 1
		entry["contribution"] = int(entry.get("contribution", 0)) + quotient + (1 if index < remainder else 0)
		totals[group_id] = entry
	cashier_summary["per_group"] = totals
```

加入安全事件与存档清洗 helper：

```gdscript
func _sanitize_cashier_event(event: Dictionary) -> Dictionary:
	return {
		"recipe_id": String(event.get("recipe_id", "")),
		"recipe_name": String(event.get("recipe_name", "")),
		"anchor_slot": int(event.get("anchor_slot", -1)),
		"cell_indices": _sanitize_int_array(event.get("cell_indices", [])),
		"related_slots": _sanitize_int_array(event.get("related_slots", [])),
		"conflict_slots": _sanitize_int_array(event.get("conflict_slots", [])),
		"earned_coins": maxi(0, int(event.get("earned_coins", 0))),
		"earned_reputation": maxi(0, int(event.get("earned_reputation", 0))),
		"attribution": _sanitize_dictionary(event.get("attribution", {})),
		"groups": _sanitize_array(event.get("groups", []))
	}


func _sanitize_cashier_summary(raw_value: Variant) -> Dictionary:
	if not raw_value is Dictionary:
		return {}
	var raw: Dictionary = raw_value
	if int(raw.get("sold_count", 0)) <= 0:
		return {}
	var recent: Array = []
	for event_value in _sanitize_array(raw.get("recent_events", [])):
		if event_value is Dictionary:
			recent.append(_sanitize_cashier_event(event_value))
	while recent.size() > 12:
		recent.pop_front()
	return {
		"sold_count": maxi(0, int(raw.get("sold_count", 0))),
		"earned_coins": maxi(0, int(raw.get("earned_coins", 0))),
		"earned_reputation": maxi(0, int(raw.get("earned_reputation", 0))),
		"base_coins": maxi(0, int(raw.get("base_coins", 0))),
		"position_adjacency_coins": int(raw.get("position_adjacency_coins", 0)),
		"set_growth_coins": int(raw.get("set_growth_coins", 0)),
		"other_delta": int(raw.get("other_delta", 0)),
		"conflict_loss": maxi(0, int(raw.get("conflict_loss", 0))),
		"per_recipe": _sanitize_dictionary(raw.get("per_recipe", {})),
		"per_group": _sanitize_dictionary(raw.get("per_group", {})),
		"recent_events": recent
	}


func _sanitize_int_array(raw_value: Variant) -> Array[int]:
	var result: Array[int] = []
	if raw_value is Array:
		for value in raw_value as Array:
			result.append(int(value))
	return result
```

- [ ] **Step 4: 运行绿灯验证**

Run the Task 2 Step 2 command.

Expected: `SHOWCASE_SALE_FEEDBACK_SELF_CHECK_PASS`。

---

### Task 4: 将真实自动成交接入统一事件，并拆开收银语义

**Files:**

- Modify: `scripts/main_view.gd:1-230, 2069-2180, 4110-4250`
- Modify: `tests/mvp_self_check.gd:4609-4660`

**Interfaces:**

- Consumes: Task 1 的 `sale_attribution()` / `sale_context()`、Task 2 的导演、Task 3 的 `append_cashier_sale()`。
- Produces: `_make_showcase_sale_feedback_event(...) -> Dictionary`。
- Produces: `_record_showcase_sale_feedback(event: Dictionary) -> void`。
- Produces: `_show_cashier_summary() -> bool`。
- Invariant: `_show_cashier_summary()` 不调用 `_process_showcase_sales()`、`_sell_ready_showcase_slot()`，也不修改金币或口碑。

- [ ] **Step 1: 在真实 timed sale 路径加入失败断言**

在 `tests/mvp_self_check.gd` 现有 `_process_showcase_sales(listed_ready_at)` 成功断言后、保存 `coins_after_sale`：

```gdscript
var coins_after_sale := int(production_sale_state.coins)
if int(production_sale_state.cashier_summary.get("sold_count", 0)) != 1:
	_fail("automatic showcase sale should append exactly one credited summary event")
if int(production_sale_state.cashier_summary.get("earned_coins", 0)) != coins_after_sale - coins_before_ready_sale:
	_fail("cashier summary should equal the real automatic coin delta")
if not root.has_method("_show_cashier_summary"):
	_fail("main view should expose presentation-only concentrated receipt")
elif not bool(root.call("_show_cashier_summary")):
	_fail("concentrated receipt should consume an existing credited summary")
if int(production_sale_state.coins) != coins_after_sale:
	_fail("concentrated receipt must not double-credit coins")
if not production_sale_state.cashier_summary.is_empty():
	_fail("concentrated receipt should clear the viewed summary")
if bool(root.call("_show_cashier_summary")):
	_fail("repeated concentrated receipt should be idempotent")
```

在该测试块进入自动成交前保存：

```gdscript
var coins_before_ready_sale := int(production_sale_state.coins)
```

- [ ] **Step 2: 运行红灯验证**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: FAIL，自动成交尚未写 `cashier_summary` 或缺少 `_show_cashier_summary()`。

- [ ] **Step 3: 建立事件和真实成交接线**

在 `main_view.gd` preload 区加入：

```gdscript
const ShowcaseFeedbackDirector = preload("res://scripts/ui/storefront/showcase_feedback_director.gd")
```

在状态字段区加入：

```gdscript
var showcase_feedback_director := ShowcaseFeedbackDirector.new()
var last_cashier_summary: Dictionary = {}
```

将 `_sell_ready_showcase_slot()` 的 bonus 入口替换为：

```gdscript
var rule_result := ShowcaseRuleService.calculate(state, catalog.get_recipes(), catalog.get_display_rules())
var bonus: Dictionary = (rule_result.get("items", {}) as Dictionary).get(recipe_id, {})
var price := int(round(float(base_price) * float(bonus.get("price_multiplier", 1.0))))
var reputation_gain := 1
var sale_event := _make_showcase_sale_feedback_event(slot_index, recipe_id, base_price, price, reputation_gain, bonus)
```

删除原位置重复的 `var reputation_gain := 1`，确保事件和真实售卖使用同一个值。

`sale_event` 必须在扣减橱窗库存前构建，避免售罄时丢失格子和关系信息；只有 `sold == true` 且金币、口碑、任务和成长都更新后，才调用：

```gdscript
_record_showcase_sale_feedback(sale_event)
```

调用位置固定在 `state.record_task_event("business_result", sale_result)` 之后、现有 `_record_business_feedback(recipe_id, sale_result)` 之前，确保任务/成长已经落账，同时保留现有最近反馈刷新。

加入事件 helper：

```gdscript
func _make_showcase_sale_feedback_event(slot_index: int, recipe_id: String, base_price: int, final_price: int, reputation_gain: int, bonus: Dictionary) -> Dictionary:
	var context := ShowcaseRuleService.sale_context(bonus)
	var groups: Array = context.get("groups", [])
	var combo_key := ""
	var combo_label := ""
	if not groups.is_empty() and groups[0] is Dictionary:
		combo_key = String((groups[0] as Dictionary).get("id", ""))
		combo_label = String((groups[0] as Dictionary).get("label", ""))
	return {
		"recipe_id": recipe_id,
		"recipe_name": _recipe_name(recipe_id),
		"anchor_slot": slot_index,
		"cell_indices": _showcase_slot_indices_for_recipe(recipe_id),
		"related_slots": _showcase_anchor_slots_for_recipe_ids(context.get("related_recipe_ids", [])),
		"conflict_slots": _showcase_anchor_slots_for_recipe_ids(context.get("conflict_recipe_ids", [])),
		"base_price": base_price,
		"final_price": final_price,
		"earned_coins": final_price,
		"earned_reputation": reputation_gain,
		"reasons": bonus.get("reasons", []),
		"attribution": ShowcaseRuleService.sale_attribution(base_price, final_price, bonus),
		"groups": groups.duplicate(true),
		"combo_key": combo_key,
		"combo_label": combo_label
	}


func _showcase_slot_indices_for_recipe(recipe_id: String) -> Array[int]:
	var result: Array[int] = []
	for cell_value in state.get_display_item_cells(recipe_id):
		if cell_value is Vector2i:
			var slot_index := _showcase_slot_index_for_cell(cell_value)
			if slot_index >= 0 and not result.has(slot_index):
				result.append(slot_index)
	return result


func _showcase_anchor_slots_for_recipe_ids(recipe_ids: Variant) -> Array[int]:
	var result: Array[int] = []
	if recipe_ids is Array:
		for recipe_id_value in recipe_ids as Array:
			var slot_index := _display_anchor_slot_index_for_recipe(String(recipe_id_value))
			if slot_index >= 0 and not result.has(slot_index):
				result.append(slot_index)
	return result


func _record_showcase_sale_feedback(event: Dictionary) -> void:
	state.append_cashier_sale(event)
	showcase_feedback_director.enqueue_sale(event, Time.get_ticks_msec())
```

Task 4 只建立事件与汇总，不调用尚未实现的表现方法。不要在 `_record_showcase_sale_feedback()` 内再次 `_save_game()`；现有 `_process()` 在成功售卖后已经保存，避免每笔成交写盘两次。Task 5 增加表现方法后，再在这里添加 deferred 播放。

- [ ] **Step 4: 将旧“结算到期”改为只消费汇总**

删除 `_settle_ready_showcase_goods()` 的 while 售卖循环，将 `_on_primary_action()` 的橱窗经营分支改为 `_show_cashier_summary()`。新增：

```gdscript
func _show_cashier_summary() -> bool:
	var summary := state.consume_cashier_summary()
	if summary.is_empty():
		_set_status("暂无新的营业汇总；自动成交金币已经入账。")
		return false
	last_cashier_summary = summary
	cashier_receipt_text = "本轮已入账\n售出 %d 件\n金币 +%d\n口碑 +%d" % [
		int(summary.get("sold_count", 0)),
		int(summary.get("earned_coins", 0)),
		int(summary.get("earned_reputation", 0))
	]
	_refresh_storefront_manage_sections()
	_set_status("集中收银：查看本轮已入账金币 +%d。" % int(summary.get("earned_coins", 0)))
	return true
```

`_on_primary_action()` 末尾现有 `_save_game()` 负责持久化汇总消费结果。保留 `_process_showcase_sales()` 每秒自动成交语义，不新增第二条售卖入口。

- [ ] **Step 5: 运行真实路径绿灯验证**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_sale_feedback_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: 两项 PASS；金币只在 `_sell_ready_showcase_slot()` 变化一次。

---

### Task 5: 添加鼠标穿透的左侧脉冲、关系线和金币轨迹

**Files:**

- Modify: `scenes/Main.tscn`
- Modify: `scenes/ui/storefront/showcase_board.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/storefront_grid_layout_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**Interfaces:**

- Consumes: `showcase_feedback_director.drain_visual_batch()`。
- Produces: `_play_pending_showcase_sale_feedback()`、`_play_showcase_sale_pulse(event)`、`_spawn_showcase_relation_line()`、`_refresh_showcase_pulse_summary()`。
- Invariant: 根级反馈层不进入 `MainArea`，不会改变 63/37；所有临时节点鼠标穿透并在 tween 结束后释放。

- [ ] **Step 1: 写场景和输入失败断言**

在 `tests/storefront_grid_layout_self_check.gd` 加入：

```gdscript
var feedback_layer: Control = main.get_node_or_null("ShowcaseFeedbackLayer")
if feedback_layer == null:
	_fail("main scene should provide root showcase feedback layer")
elif feedback_layer.mouse_filter != Control.MOUSE_FILTER_IGNORE:
	_fail("showcase feedback layer must not intercept drag input")
var pulse_summary: Label = main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcasePulseSummary")
if pulse_summary == null:
	_fail("showcase board should expose credited round summary")
elif pulse_summary.mouse_filter != Control.MOUSE_FILTER_IGNORE:
	_fail("showcase pulse summary must not intercept drag input")
if main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") != showcase_grid:
	_fail("feedback additions must preserve direct ShowcaseGrid path")
```

在 `tests/component_contract_self_check.gd::_check_scene_mounts()` 的 `Main` 实例检查中加入：

```gdscript
if main.get_node_or_null("ShowcaseFeedbackLayer") == null:
	_fail("Main should mount ShowcaseFeedbackLayer outside MainArea")
if main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcasePulseSummary") == null:
	_fail("ShowcaseBoard should mount ShowcasePulseSummary")
if not ResourceLoader.exists("res://scripts/ui/storefront/showcase_feedback_director.gd"):
	_fail("ShowcaseFeedbackDirector script is missing")
```

- [ ] **Step 2: 运行红灯验证**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/storefront_grid_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/component_contract_self_check.gd
```

Expected: FAIL，缺少反馈层和累计筹码。

- [ ] **Step 3: 在 `.tscn` 添加稳定节点**

在 `scenes/Main.tscn` 的根 `Main` 下、`Root` 之后添加：

```tscn
[node name="ShowcaseFeedbackLayer" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
```

在 `scenes/ui/storefront/showcase_board.tscn` 的 `ShowcaseTitle` 后添加：

```tscn
[node name="ShowcasePulseSummary" type="Label" parent="."]
layout_mode = 2
text = "本轮已入账 +0｜0 件"
horizontal_alignment = 2
mouse_filter = 2
```

不得移动或重命名 `ShowcaseGrid`。

- [ ] **Step 4: 实现批次播放和安全的瞬态节点**

在 `main_view.gd` 绑定：

```gdscript
@onready var showcase_feedback_layer: Control = $ShowcaseFeedbackLayer
@onready var showcase_pulse_summary: Label = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcasePulseSummary
```

加入批次播放：

```gdscript
func _play_pending_showcase_sale_feedback() -> void:
	var batch := showcase_feedback_director.drain_visual_batch()
	for event_value in batch.get("events", []):
		if event_value is Dictionary:
			_play_showcase_sale_pulse(event_value)
	var overflow_count := int(batch.get("overflow_count", 0))
	if overflow_count > 0:
		_spawn_showcase_feedback_label(
			"+%d 件｜+%d" % [overflow_count, int(batch.get("overflow_coins", 0))],
			_showcase_summary_center(),
			Color(1.0, 0.82, 0.35),
			0.65
		)
	if int(batch.get("combo_count", 0)) > 1 and not String(batch.get("combo_key", "")).is_empty():
		_spawn_showcase_feedback_label(
			"%s x%d｜+%d" % [String(batch.get("combo_label", "套装连售")), int(batch.get("combo_count", 0)), int(batch.get("combo_coins", 0))],
			_showcase_summary_center() + Vector2(0, 24),
			Color(1.0, 0.72, 0.24),
			0.9
		)
	_refresh_showcase_pulse_summary()
```

Task 5 在 `_record_showcase_sale_feedback()` 末尾加入：

```gdscript
call_deferred("_play_pending_showcase_sale_feedback")
```

实现单件脉冲、金币轨迹和关系线：

```gdscript
func _play_showcase_sale_pulse(event: Dictionary) -> void:
	var anchor_slot := int(event.get("anchor_slot", -1))
	var source_center := _showcase_slot_center(anchor_slot)
	if source_center == Vector2.INF:
		source_center = _showcase_summary_center()
	var conflict_loss := int((event.get("attribution", {}) as Dictionary).get("conflict_loss", 0))
	var pulse_color := Color(1.0, 0.77, 0.28) if conflict_loss <= 0 else Color(0.88, 0.38, 0.34)
	var pulse_slots: Array = event.get("cell_indices", [])
	if pulse_slots.is_empty():
		pulse_slots = [anchor_slot]
	for pulse_slot_value in pulse_slots:
		_spawn_showcase_pulse_rect(int(pulse_slot_value), pulse_color)
	_spawn_showcase_feedback_label("+%d" % int(event.get("earned_coins", 0)), source_center, pulse_color, 0.48)
	var reason_text := _showcase_sale_pulse_reason_text(event)
	if not reason_text.is_empty():
		_spawn_showcase_feedback_label(reason_text, source_center + Vector2(0, 18), Color(0.95, 0.88, 0.72), 0.62)
	_spawn_showcase_coin_flight(source_center, _showcase_summary_center())
	for target_value in event.get("related_slots", []):
		var target := _showcase_slot_center(int(target_value))
		if target != Vector2.INF:
			_spawn_showcase_relation_line(source_center, target, Color(0.96, 0.68, 0.24))
	for target_value in event.get("conflict_slots", []):
		var target := _showcase_slot_center(int(target_value))
		if target != Vector2.INF:
			_spawn_showcase_relation_line(source_center, target, Color(0.86, 0.27, 0.25))


func _showcase_slot_center(slot_index: int) -> Vector2:
	if slot_index < 0 or slot_index >= showcase_grid.get_child_count():
		return Vector2.INF
	var control := showcase_grid.get_child(slot_index) as Control
	if control == null:
		return Vector2.INF
	return control.get_global_rect().get_center() - showcase_feedback_layer.global_position


func _showcase_summary_center() -> Vector2:
	return showcase_pulse_summary.get_global_rect().get_center() - showcase_feedback_layer.global_position


func _spawn_showcase_feedback_label(text: String, position: Vector2, color: Color, duration: float) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = position - Vector2(24, 12)
	showcase_feedback_layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 28.0, duration)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration)
	tween.tween_callback(label.queue_free)


func _spawn_showcase_relation_line(from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 3.0
	line.default_color = color
	showcase_feedback_layer.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.5)
	tween.tween_callback(line.queue_free)


func _showcase_sale_pulse_reason_text(event: Dictionary) -> String:
	var positive := ""
	var negative := ""
	for reason_value in event.get("reasons", []):
		if not reason_value is Dictionary:
			continue
		var reason: Dictionary = reason_value
		var text := String(reason.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		if String(reason.get("source", "")) == "conflict":
			if negative.is_empty():
				negative = "减损：%s" % text.left(14)
		elif positive.is_empty():
			positive = "增益：%s" % text.left(14)
	var parts: Array[String] = []
	if not positive.is_empty():
		parts.append(positive)
	if not negative.is_empty():
		parts.append(negative)
	return "｜".join(parts)
```

实现两个剩余瞬态 helper；它们只创建 `ShowcaseFeedbackLayer` 子节点，不修改真实格子控件：

```gdscript
func _spawn_showcase_pulse_rect(slot_index: int, color: Color) -> void:
	if slot_index < 0 or slot_index >= showcase_grid.get_child_count():
		return
	var source := showcase_grid.get_child(slot_index) as Control
	if source == null:
		return
	var source_rect := source.get_global_rect()
	var pulse := ColorRect.new()
	pulse.color = Color(color.r, color.g, color.b, 0.35)
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.position = source_rect.position - showcase_feedback_layer.global_position
	pulse.size = source_rect.size
	pulse.pivot_offset = pulse.size * 0.5
	showcase_feedback_layer.add_child(pulse)
	var tween := create_tween()
	tween.tween_property(pulse, "scale", Vector2(1.08, 1.08), 0.10)
	tween.tween_property(pulse, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(pulse, "modulate:a", 0.0, 0.22)
	tween.tween_callback(pulse.queue_free)


func _spawn_showcase_coin_flight(from: Vector2, to: Vector2) -> void:
	var coin := Label.new()
	coin.text = "●"
	coin.modulate = Color(1.0, 0.78, 0.22)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.position = from - Vector2(6, 8)
	showcase_feedback_layer.add_child(coin)
	var tween := create_tween()
	tween.tween_property(coin, "position", to - Vector2(6, 8), 0.34)
	tween.parallel().tween_property(coin, "scale", Vector2(0.7, 0.7), 0.34)
	tween.tween_callback(coin.queue_free)
```

在 `_refresh_storefront()` 或 `_refresh_storefront_showcase()` 末尾调用：

```gdscript
func _refresh_showcase_pulse_summary() -> void:
	var summary: Dictionary = state.cashier_summary
	showcase_pulse_summary.text = "本轮已入账 +%d｜%d 件" % [
		int(summary.get("earned_coins", 0)),
		int(summary.get("sold_count", 0))
	]
```

- [ ] **Step 5: 运行布局与真实反馈验证**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/storefront_grid_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/layout_refinement_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/component_contract_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: 四项 PASS；63/37、10x10、中心 6x6、直接 `ShowcaseGrid` 路径和拖拽能力不变。

---

### Task 6: 完成右侧原位账单、贡献回放和最终门禁

**Files:**

- Modify: `scripts/main_view.gd:2030-2180, 4110-4250`
- Modify: `tests/right_console_experience_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**Interfaces:**

- Consumes: `state.cashier_summary` 与 `last_cashier_summary`。
- Produces: `_cashier_summary_text(summary)`、`_cashier_best_entry(entries)`、`_cashier_next_step_text(summary)`、`_show_cashier_summary_replay(summary)`。
- Invariant: 保留经营概览、集中收银、当前加成、最近收银、经营风险、橱窗扩张六个分区；不创建 modal。

- [ ] **Step 1: 写右侧语义和不重复入账失败断言**

在 `tests/right_console_experience_self_check.gd` 的橱窗经营分支中，将旧“结算到期”断言改为：

```gdscript
var storefront_receipt_label: RichTextLabel = storefront_manage_panel.get_node_or_null("StorefrontManageSections/StorefrontReceiptPanel/StorefrontReceiptLabel")
if settle_label != null and settle_label.text.find("集中收银") == -1:
	_fail("storefront settle section should explain concentrated receipt")
if primary_action.text != "集中收银":
	_fail("storefront primary action should review credited summary")
state.append_cashier_sale({
	"recipe_id": "sponge_cake",
	"recipe_name": "海绵杯蛋糕",
	"anchor_slot": 22,
	"cell_indices": [22, 23, 32, 33],
	"related_slots": [24],
	"conflict_slots": [25],
	"earned_coins": 80,
	"earned_reputation": 2,
	"attribution": {"base_coins": 60, "position_adjacency_coins": 10, "set_growth_coins": 15, "other_delta": 0, "conflict_loss": 5},
	"groups": [{"id": "set_001", "label": "经典下午茶三件套", "recipe_ids": ["sponge_cake"]}]
})
var coins_before_receipt := int(state.coins)
primary_action.emit_signal("pressed")
await process_frame
if int(state.coins) != coins_before_receipt:
	_fail("concentrated receipt must not double-credit coins")
if not state.cashier_summary.is_empty():
	_fail("concentrated receipt should consume viewed summary")
if storefront_receipt_label.text.find("基础收入") == -1 or storefront_receipt_label.text.find("冲突损失") == -1:
	_fail("receipt section should show attribution after concentrated receipt")
```

继续保留六个 `PanelContainer`、`ListRow.visible == false`、扩张入口和四页切换断言。

- [ ] **Step 2: 运行红灯验证**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/right_console_experience_self_check.gd
```

Expected: FAIL，按钮和文案仍使用旧“结算到期”语义，或账单缺少归因。

- [ ] **Step 3: 实现原位账单、最佳贡献和可执行建议**

在 `_refresh_storefront_manage_page()` 将主按钮文案改为 `集中收银`。将 `_storefront_settle_text()` 改为读取 `state.cashier_summary`：

```gdscript
func _storefront_settle_text(_snapshot: Dictionary) -> String:
	var summary: Dictionary = state.cashier_summary
	if summary.is_empty():
		return "集中收银\n暂无新的营业汇总。自动成交收益会立即入账。"
	return "集中收银\n已入账 %d 件｜金币 +%d｜口碑 +%d\n点击下方「集中收银」查看贡献，金币不会重复增加。" % [
		int(summary.get("sold_count", 0)),
		int(summary.get("earned_coins", 0)),
		int(summary.get("earned_reputation", 0))
	]
```

在 `_storefront_overview_text()` 计算 `next_step` 时，把未查看汇总放在最高优先级：

```gdscript
if not state.cashier_summary.is_empty():
	next_step = "查看本轮已入账汇总"
elif ready_count > 0:
	next_step = "自动成交处理中"
elif listed_stock > 0:
	next_step = "等待顾客结账或继续补货"
```

加入账单格式化：

```gdscript
func _cashier_summary_text(summary: Dictionary) -> String:
	var best_recipe := _cashier_best_entry(summary.get("per_recipe", {}))
	var best_group := _cashier_best_entry(summary.get("per_group", {}), "contribution")
	var lines: Array[String] = [
		"本轮营业｜金币已入账",
		"售出 %d 件｜金币 +%d｜口碑 +%d" % [int(summary.get("sold_count", 0)), int(summary.get("earned_coins", 0)), int(summary.get("earned_reputation", 0))],
		"基础收入 +%d" % int(summary.get("base_coins", 0)),
		"位置与相邻 %+d" % int(summary.get("position_adjacency_coins", 0)),
		"套装与成长 %+d" % int(summary.get("set_growth_coins", 0)),
		"其他净影响 %+d" % int(summary.get("other_delta", 0)),
		"冲突损失 -%d" % int(summary.get("conflict_loss", 0))
	]
	if not best_recipe.is_empty():
		lines.append("最佳商品：%s｜+%d" % [String(best_recipe.get("label", "")), int(best_recipe.get("earned_coins", 0))])
	if not best_group.is_empty():
		lines.append("最佳套装：%s｜额外 +%d" % [String(best_group.get("label", "")), int(best_group.get("contribution", 0))])
	lines.append(_cashier_next_step_text(summary))
	return "\n".join(lines)


func _cashier_best_entry(entries_value: Variant, amount_key: String = "earned_coins") -> Dictionary:
	if not entries_value is Dictionary:
		return {}
	var best: Dictionary = {}
	for entry_value in (entries_value as Dictionary).values():
		if entry_value is Dictionary and (best.is_empty() or int((entry_value as Dictionary).get(amount_key, 0)) > int(best.get(amount_key, 0))):
			best = (entry_value as Dictionary).duplicate(true)
	return best


func _cashier_next_step_text(summary: Dictionary) -> String:
	if int(summary.get("conflict_loss", 0)) <= 0:
		return "下轮优化：继续围绕本轮最佳商品和套装补货。"
	for event_value in summary.get("recent_events", []):
		if event_value is Dictionary:
			var conflict_slots: Array = (event_value as Dictionary).get("conflict_slots", [])
			if not conflict_slots.is_empty():
				return "下轮优化：移动 %s，减少红色关系线对应的冲突。" % String((event_value as Dictionary).get("recipe_name", "冲突商品"))
	return "下轮优化：存在冲突损失，优先调整红色提示商品。"
```

实现原位回放，不创建弹窗：

```gdscript
func _show_cashier_summary_replay(summary: Dictionary) -> void:
	cashier_receipt_text = _cashier_summary_text(summary)
	_refresh_storefront_manage_sections()
	var recent: Array = summary.get("recent_events", [])
	for index in range(mini(3, recent.size())):
		var event_value = recent[recent.size() - 1 - index]
		if event_value is Dictionary:
			_play_showcase_sale_pulse(event_value)
```

将 Task 4 的 `_show_cashier_summary()` 中最小 `cashier_receipt_text` 赋值替换为 `_show_cashier_summary_replay(summary)`，其余“只消费、不入账”逻辑保持不变。

用以下实现替换 `_storefront_receipt_text()`，确保页面刷新后仍优先显示刚查看的账单，再追加现有最近售出原因：

```gdscript
func _storefront_receipt_text() -> String:
	var lines: Array[String] = ["最近收银"]
	if not last_cashier_summary.is_empty():
		for line in _cashier_summary_text(last_cashier_summary).split("\n", false):
			var text := String(line).strip_edges()
			if not text.is_empty():
				lines.append(text)
	else:
		for line in cashier_receipt_text.split("\n", false):
			var text := String(line).strip_edges()
			if not text.is_empty() and text != "橱窗加成":
				lines.append(text)
	var sale_lines := _recent_sale_bonus_lines()
	if sale_lines.is_empty():
		lines.append("最近售出：暂无")
	else:
		lines.append("最近售出")
		lines.append_array(sale_lines.slice(0, mini(3, sale_lines.size())))
	return "\n".join(lines)
```

`_storefront_receipt_text()` 在 `last_cashier_summary` 非空时优先显示 `_cashier_summary_text(last_cashier_summary)`，之后再追加现有最近售出文本。集中收银完成后不自动切页；再次点击保持空状态并只更新状态栏。

- [ ] **Step 4: 运行全部相关门禁**

Run:

```powershell
$tests = @(
  'showcase_sale_feedback_self_check.gd',
  'showcase_bonus_reason_self_check.gd',
  'storefront_grid_layout_self_check.gd',
  'right_console_experience_self_check.gd',
  'layout_refinement_self_check.gd',
  'component_contract_self_check.gd',
  'main_scene_split_shell_self_check.gd',
  'mvp_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: 每项输出自己的 PASS 标记，最终退出码为 0。

- [ ] **Step 5: 手动验证真实交互并检查范围**

1. 从库存拖一件成品到左侧中心开放格，确认拖拽没有被反馈层拦截。
2. 等待倒计时自然结束，确认库存减少、顶部金币立即增加、左侧对应格出现脉冲和 `+金额`。
3. 保持右侧在采购、产出或研发制作，确认自动成交不会强制切换页面。
4. 让同一套装在三秒内连续成交，确认更新一个连售计数；制造四件同批成交时，最多三件单独显示，其余显示 `+N 件`。
5. 制造相邻冲突，确认红色关系线和损失提示清楚但不阻塞操作。
6. 进入橱窗经营点击集中收银，确认右侧六分区原位显示账单、左侧回放贡献、金币不再增加。
7. 再次点击，确认显示“暂无新的营业汇总”，不补发金币。
8. 保存并重新载入未查看汇总，确认账单仍在；载入旧存档，确认汇总为空。

Run targeted scope checks:

```powershell
git status --short
git diff --check -- scripts/shop_simulation.gd scripts/showcase_rule_service.gd scripts/game_state.gd scripts/main_view.gd scenes/Main.tscn scenes/ui/storefront/showcase_board.tscn tests/showcase_bonus_reason_self_check.gd tests/showcase_sale_feedback_self_check.gd tests/storefront_grid_layout_self_check.gd tests/right_console_experience_self_check.gd tests/component_contract_self_check.gd tests/mvp_self_check.gd
```

Expected: 本任务只新增或修改计划列出的功能文件；原有无关工作树改动保持原样；目标文件无空白错误；不提交 Git。

---

## Plan Self-Review

- Spec coverage: Task 1 覆盖同源原因、套装 ID、关系对象和精确对账；Task 2 覆盖三秒连售、三件上限和溢出压缩；Task 3 覆盖唯一持久化汇总、旧存档和消费幂等性；Task 4 覆盖真实自动成交、一次入账和旧收银路径拆分；Task 5 覆盖左侧脉冲、关系线、金币轨迹与输入穿透；Task 6 覆盖右侧原位账单、最佳商品/套装、冲突建议、贡献回放和总门禁。
- Placeholder scan: 无占位符、泛化错误处理步骤或未定义的跨任务接口。
- Type consistency: 规则层输出配方 ID 与整数 slot；Task 4 生成 JSON 安全的 `cell_indices` / `related_slots` / `conflict_slots`；Task 2 只保存瞬态队列；Task 3 的 `cashier_summary` 是唯一持久化汇总；Task 5/6 只消费事件与汇总，不重新计算经济数值。
- Scope check: 六个任务围绕同一个售卖反馈闭环，按规则数据 -> 瞬态节奏 -> 持久化汇总 -> 真实接线 -> 左侧表现 -> 右侧复盘顺序推进；采购、产出、研发制作和顾客系统均不在改造范围内。

## Execution Handoff

计划执行时优先使用 `superpowers:executing-plans` 在当前会话分批实施并设置检查点。只有用户明确要求子代理并行时，才改用 `superpowers:subagent-driven-development`；无论哪种方式，都先保留当前脏工作树基线，不提交 Git。
