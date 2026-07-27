# “研发制作”全配方一键补货 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在“研发制作”页增加页面级“一键补货”，按所有已解锁成品配方和所有当前可用加工配方各执行一次的合并需求，整单购买可直购缺口。

**Architecture:** `main_view.gd` 把需求聚合、库存抵扣、报价和原子购买拆成共享 helper，单配方与页面批量补货使用同一套材料分类与采购规则。`Main.tscn` 声明独立批量按钮；现有 `RecipeRestockDialog` 泛化为单配方/页面批量通用展示，确认时由主视图重新报价。

**Tech Stack:** Godot 4.6.1、GDScript、`.tscn`、SceneTree headless 自检。

## Global Constraints

- 范围包含所有已解锁成品配方和所有当前可用加工配方，每个目标只计算 1 次。
- 同种材料跨目标累加后只抵扣一次当前真实库存；尚未执行的加工产出不能抵扣成品缺口。
- 只购买可直接采购食材；不可直购项展示但不计价。
- 金币不足整单失败；确认时重新报价；成功只保存一次、刷新一次。
- 稳定按钮结构写入 `.tscn`。
- Godot headless 命令必须显式传入 `--log-file "$env:TEMP\godot-headless.log"`。
- 保留工作区现有库存图标相关未提交修改；未经明确要求不创建 commit。

## File Map

- Modify `tests/research_recipe_restock_self_check.gd`：批量需求、报价、原子性、确认重算和按钮状态。
- Modify `scripts/main_view.gd`：共享报价 helper、批量需求/购买、按钮与确认分发。
- Modify `scenes/Main.tscn`：声明 `BulkRestockButton`。
- Modify `scripts/ui/overlays/recipe_restock_dialog.gd`：通用范围与金币不足展示。
- Modify `scenes/ui/overlays/recipe_restock_dialog.tscn`：泛化固定文案。
- Modify `tests/component_contract_self_check.gd`：锁定场景节点。

---

### Task 1: 聚合批量需求并生成共享报价

**Files:**
- Modify: `tests/research_recipe_restock_self_check.gd`
- Modify: `scripts/main_view.gd:3087-3152`

**Interfaces:**
- Consumes: `_unlocked_recipe_ids()`、`_available_process_ids()`、当前 `state` 与 `catalog`。
- Produces: `_merge_material_requirements(target, materials_value)`、`_research_bulk_restock_requirements()`、`_restock_quote_for_requirements(requirements, quote_name, quote_kind)`、`_research_bulk_restock_quote()`。

- [ ] **Step 1: 写失败测试**

在聚焦自检的 `_material_requirements()` 断言后加入：

```gdscript
var bulk_state = GameState.new_game()
bulk_state.level = 2
bulk_state.coins = 9999
bulk_state.ingredient_inventory.clear()
bulk_state.product_inventory.clear()
bulk_state.add_recipe("sponge_cake")
bulk_state.add_recipe("cream_shortcake")
view.set("state", bulk_state)
_expect(view.has_method("_research_bulk_restock_requirements"), "main view should aggregate bulk restock requirements")
_expect(view.has_method("_research_bulk_restock_quote"), "main view should quote bulk restock")
if view.has_method("_research_bulk_restock_requirements"):
	var actual: Dictionary = view.call("_research_bulk_restock_requirements")
	var expected := {}
	var recipes: Dictionary = view.get("catalog").get_recipes()
	var processes: Dictionary = view.get("catalog").get_processing_recipes()
	for recipe_id in view.call("_unlocked_recipe_ids"):
		for value: Variant in recipes.get(recipe_id, {}).get("materials", []):
			var id := String(value)
			expected[id] = int(expected.get(id, 0)) + 1
	for process_id in view.call("_available_process_ids"):
		for value: Variant in processes.get(process_id, {}).get("materials", []):
			var id := String(value)
			expected[id] = int(expected.get(id, 0)) + 1
	_expect(actual == expected, "bulk requirements should include every unlocked recipe and available process once")
	bulk_state.add_ingredient("sugar", 1)
	var quote: Dictionary = view.call("_research_bulk_restock_quote")
	var sugar_missing := -1
	var sponge_missing := -1
	for value: Variant in quote.get("entries", []):
		var entry: Dictionary = value
		if String(entry.get("item_id", "")) == "sugar": sugar_missing = int(entry.get("missing", -1))
		if String(entry.get("item_id", "")) == "sponge_cake": sponge_missing = int(entry.get("missing", -1))
	_expect(sugar_missing == maxi(int(expected.get("sugar", 0)) - 1, 0), "shared inventory should be subtracted once after aggregation")
	_expect(sponge_missing > 0, "planned output should not satisfy a current product shortage")
```

- [ ] **Step 2: 运行 RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/research_recipe_restock_self_check.gd
```

Expected: exit `1`，报告缺少批量需求或报价 helper。

- [ ] **Step 3: 实现最小共享 helper**

```gdscript
func _merge_material_requirements(target: Dictionary, materials_value: Variant) -> void:
	if not materials_value is Array: return
	for value: Variant in materials_value:
		var id := String(value)
		if not id.is_empty(): target[id] = int(target.get(id, 0)) + 1

func _research_bulk_restock_requirements() -> Dictionary:
	var result := {}
	var recipes := catalog.get_recipes()
	for id in _unlocked_recipe_ids():
		_merge_material_requirements(result, recipes.get(id, {}).get("materials", []))
	var processes := catalog.get_processing_recipes()
	for id in _available_process_ids():
		_merge_material_requirements(result, processes.get(id, {}).get("materials", []))
	return result
```

把现有 `_recipe_restock_quote()` 中从 `entries` 初始化到返回字典的代码移入：

```gdscript
func _restock_quote_for_requirements(requirements: Dictionary, quote_name: String, quote_kind: String) -> Dictionary:
	var entries: Array[Dictionary] = []
	var purchasable_entries: Array[Dictionary] = []
	var unavailable_entries: Array[Dictionary] = []
	var total_cost := 0
	var purchasable_units := 0
	var ingredients := catalog.get_ingredients()
	var recipes := catalog.get_recipes()
	for material_id_value: Variant in requirements.keys():
		var material_id := String(material_id_value)
		var required := int(requirements.get(material_id, 0))
		var available: int = state.get_ingredient_count(material_id) if ingredients.has(material_id) else state.get_product_count(material_id)
		var missing := maxi(required - available, 0)
		if missing == 0: continue
		var ingredient: Dictionary = ingredients.get(material_id, {})
		var material_recipe: Dictionary = recipes.get(material_id, {})
		var purchasable := not ingredient.is_empty() and _is_ingredient_available_for_purchase(material_id, ingredient)
		var unit_price := int(ingredient.get("price", 0))
		var entry := {
			"item_id": material_id,
			"name": String(material_recipe.get("name", material_id)) if ingredient.is_empty() else _ingredient_name(material_id),
			"missing": missing, "purchasable": purchasable, "unit_price": unit_price,
			"subtotal": unit_price * missing if purchasable else 0,
			"source": "制作" if not material_recipe.is_empty() else String(ingredient.get("source", "对应产地"))
		}
		entries.append(entry)
		if purchasable:
			purchasable_entries.append(entry)
			total_cost += int(entry.get("subtotal", 0))
			purchasable_units += missing
		else:
			unavailable_entries.append(entry)
	return {
		"ok": true, "quote_name": quote_name, "quote_kind": quote_kind,
		"entries": entries, "purchasable_entries": purchasable_entries,
		"unavailable_entries": unavailable_entries, "total_cost": total_cost,
		"purchasable_units": purchasable_units, "available_coins": int(state.coins)
	}
```

单配方报价先校验再委托，并补回 `recipe_id`/`recipe_name`；批量报价为：

```gdscript
func _research_bulk_restock_quote() -> Dictionary:
	if state == null:
		return {"ok": false, "reason": "当前状态不可用", "entries": []}
	return _restock_quote_for_requirements(_research_bulk_restock_requirements(), "全部配方与加工", "research_bulk")
```

- [ ] **Step 4: 运行 GREEN**

重复 Step 2。Expected: 新增批量需求/报价断言通过，原单配方报价断言仍通过。

---

### Task 2: 实现整单购买与确认时重算

**Files:**
- Modify: `tests/research_recipe_restock_self_check.gd`
- Modify: `scripts/main_view.gd:2413-2454,3155-3177`

**Interfaces:**
- Consumes: `_research_bulk_restock_quote()`、`_purchase_inventory_item()`。
- Produces: `_purchase_restock_quote()`、`_purchase_research_bulk_restock()`、`_on_research_bulk_restock_pressed()`。

- [ ] **Step 1: 写原子性失败测试**

```gdscript
_expect(view.has_method("_purchase_research_bulk_restock"), "main view should expose atomic bulk purchase")
if view.has_method("_purchase_research_bulk_restock"):
	var poor = GameState.new_game()
	poor.level = 2
	poor.coins = 0
	poor.ingredient_inventory.clear()
	poor.add_recipe("butter_cookie")
	view.set("state", poor)
	var before: Dictionary = poor.ingredient_inventory.duplicate(true)
	var failed: Dictionary = view.call("_purchase_research_bulk_restock")
	_expect(String(failed.get("reason", "")) == "金币不足", "bulk purchase should report insufficient coins")
	_expect(int(poor.coins) == 0 and poor.ingredient_inventory == before, "failed bulk purchase should be atomic")
	var latest = GameState.new_game()
	latest.level = 2
	latest.coins = 9999
	latest.ingredient_inventory.clear()
	latest.add_recipe("butter_cookie")
	view.set("state", latest)
	var opened: Dictionary = view.call("_research_bulk_restock_quote")
	latest.add_ingredient("sugar", 1)
	var current: Dictionary = view.call("_research_bulk_restock_quote")
	var coins_before := int(latest.coins)
	var result: Dictionary = view.call("_purchase_research_bulk_restock")
	_expect(bool(result.get("ok", false)), "affordable bulk purchase should succeed")
	_expect(int(latest.coins) == coins_before - int(current.get("total_cost", 0)), "bulk purchase should charge the latest quote")
	_expect(int(current.get("total_cost", 0)) <= int(opened.get("total_cost", 0)), "new stock should not increase confirmation cost")
```

- [ ] **Step 2: 运行 RED**

重复 Task 1 Step 2。Expected: exit `1`，报告缺少 atomic bulk purchase。

- [ ] **Step 3: 实现共享原子购买**

```gdscript
func _purchase_restock_quote(quote: Dictionary) -> Dictionary:
	if not bool(quote.get("ok", false)): return {"ok": false, "reason": String(quote.get("reason", "补货不可用")), "quote": quote}
	if quote.get("entries", []).is_empty(): return {"ok": false, "reason": "材料充足", "quote": quote}
	if quote.get("purchasable_entries", []).is_empty(): return {"ok": false, "reason": "没有可直接采购的缺口", "quote": quote}
	if int(state.coins) < int(quote.get("total_cost", 0)): return {"ok": false, "reason": "金币不足", "quote": quote}
	for value: Variant in quote.get("purchasable_entries", []):
		var entry: Dictionary = value
		for _unit in range(int(entry.get("missing", 0))):
			_purchase_inventory_item(String(entry.get("item_id", "")), false)
	return {"ok": true, "reason": "", "quote": quote}

func _purchase_recipe_restock(recipe_id: String) -> Dictionary:
	return _purchase_restock_quote(_recipe_restock_quote(recipe_id))

func _purchase_research_bulk_restock() -> Dictionary:
	return _purchase_restock_quote(_research_bulk_restock_quote())
```

新增 `pending_research_bulk_restock := false`。批量打开 handler 设置该值并清空 `pending_recipe_restock_id`；单配方打开时清空该值。现有 `_on_recipe_restock_confirmed()` 开头改为：

```gdscript
var is_bulk := pending_research_bulk_restock
pending_research_bulk_restock = false
var recipe_id := pending_recipe_restock_id
pending_recipe_restock_id = ""
var result: Dictionary = _purchase_research_bulk_restock() if is_bulk else _purchase_recipe_restock(recipe_id)
```

其余失败处理、保存一次、资源栏刷新一次、页面刷新一次与不可直购提示复用现有代码；批量成功前缀用“全部配方一键补货完成”。

- [ ] **Step 4: 运行 GREEN**

重复 Task 1 Step 2。Expected: 原子性与确认时重算断言通过。

---

### Task 3: 增加批量按钮并泛化确认框

**Files:**
- Modify: `scenes/Main.tscn:328-338`
- Modify: `scripts/main_view.gd:113-123,250-268,2034-2053,5065-5114`
- Modify: `scripts/ui/overlays/recipe_restock_dialog.gd`
- Modify: `scenes/ui/overlays/recipe_restock_dialog.tscn`
- Modify: `tests/research_recipe_restock_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`

**Interfaces:** Produces scene node `.../RightActionHalf/BulkRestockButton` and dialog support for `quote_kind=research_bulk`。

- [ ] **Step 1: 写按钮与弹窗失败测试**

```gdscript
var bulk_button := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/RightActionHalf/BulkRestockButton") as Button
_expect(bulk_button != null, "research page should declare BulkRestockButton")
var poor = GameState.new_game()
poor.level = 2
poor.coins = 0
poor.ingredient_inventory.clear()
poor.add_recipe("butter_cookie")
view.set("state", poor)
view.call("_show_page", "research")
_expect(bulk_button != null and bulk_button.visible and not bulk_button.disabled, "purchasable shortage should allow opening bulk quote")
view.call("_on_research_bulk_restock_pressed")
_expect(dialog.visible and dialog.get_ok_button().disabled, "insufficient coins should disable confirmation")
_expect(String(dialog.get_node("Body/HintLabel").text).find("金币不足") != -1, "dialog should explain insufficient coins")
```

在组件契约检查加入：

```gdscript
var bulk_button = main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/RightActionHalf/BulkRestockButton")
if not bulk_button is Button:
	_fail("Main should declare research BulkRestockButton")
```

- [ ] **Step 2: 运行 RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/research_recipe_restock_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/component_contract_self_check.gd
```

Expected: 两者因缺少 `BulkRestockButton` 失败。

- [ ] **Step 3: 在 `Main.tscn` 声明按钮**

```ini
[node name="BulkRestockButton" type="Button" parent="Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/RightActionHalf"]
visible = false
custom_minimum_size = Vector2(82, 36)
layout_mode = 2
theme_type_variation = &"DessertSecondaryButton"
text = "一键补货"
```

- [ ] **Step 4: 绑定并刷新按钮**

新增 onready：

```gdscript
@onready var bulk_restock_button: Button = $Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/RightActionHalf/BulkRestockButton
```

在 `_ready()` 防重复连接：

```gdscript
var bulk_handler := Callable(self, "_on_research_bulk_restock_pressed")
if not bulk_restock_button.pressed.is_connected(bulk_handler):
	bulk_restock_button.pressed.connect(bulk_handler)
```

在 `_clear_page_controls()` 中默认隐藏并复位：

```gdscript
bulk_restock_button.visible = false
bulk_restock_button.disabled = false
bulk_restock_button.tooltip_text = ""
```

在 `_refresh_research_page()` 中设置：

```gdscript
bulk_restock_button.visible = true
var bulk_quote := _research_bulk_restock_quote()
var reason := ""
if bulk_quote.get("entries", []).is_empty():
	reason = "所有配方与加工的食材均已充足"
elif bulk_quote.get("purchasable_entries", []).is_empty():
	reason = "当前空缺食材无法通过采购获得"
bulk_restock_button.disabled = not reason.is_empty()
bulk_restock_button.tooltip_text = reason
```

- [ ] **Step 5: 泛化弹窗**

`RecipeLabel` 默认文字改为“补货范围”。`configure()` 使用：

```gdscript
var kind := String(quote.get("quote_kind", "recipe"))
recipe_label.text = "补货范围：%s" % String(quote.get("quote_name", "全部配方与加工")) if kind == "research_bulk" else "当前配方：%s" % String(quote.get("recipe_name", ""))
var cost := int(quote.get("total_cost", 0))
var coins := int(quote.get("available_coins", 0))
total_label.text = "本次可采购：%d 件｜合计：%d 金币" % [int(quote.get("purchasable_units", 0)), cost]
var has_items := not quote.get("purchasable_entries", []).is_empty()
get_ok_button().disabled = not has_items or coins < cost
hint_label.text = "请先通过对应生产来源获得缺少的食材。" if not has_items else ("金币不足：需要 %d，当前 %d。整单不会购买。" % [cost, coins] if coins < cost else "不可直购食材不会计价或加入库存。")
```

- [ ] **Step 6: 运行 GREEN 与结构回归**

重复 Step 2，然后运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/main_scene_split_shell_self_check.gd
```

Expected: `RESEARCH_RECIPE_RESTOCK_SELF_CHECK: PASS`、`COMPONENT_CONTRACT_SELF_CHECK_PASS`、`MAIN_SCENE_SPLIT_SHELL_SELF_CHECK_PASS`。

---

### Task 4: 完整验证与差异审计

**Files:** Verify all Task 1–3 files only.

- [ ] **Step 1: 解析检查**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" --quit
```

Expected: exit `0`，无脚本或场景解析错误。

- [ ] **Step 2: 重新运行三个自检**

运行 Task 3 Step 2 与 Step 6 的三个命令。Expected: 三个 PASS 标记且 exit `0`。

- [ ] **Step 3: 补丁检查**

```powershell
git diff --check
rg -n "<<<<<<<|=======|>>>>>>>" scenes/Main.tscn scripts/main_view.gd scripts/ui/overlays/recipe_restock_dialog.gd tests/research_recipe_restock_self_check.gd tests/component_contract_self_check.gd
```

Expected: `git diff --check` exit `0`；冲突标记搜索无输出。

- [ ] **Step 4: 审计范围并交付**

```powershell
git status --short
git diff -- scenes/Main.tscn scripts/main_view.gd scripts/ui/overlays/recipe_restock_dialog.gd scenes/ui/overlays/recipe_restock_dialog.tscn tests/research_recipe_restock_self_check.gd tests/component_contract_self_check.gd
```

逐项确认：成品与加工均计入、共享材料累加、库存只抵扣一次、计划产出不抵扣、不可直购不计价、金币不足整单失败、确认重算、按钮提示、单次保存刷新、行级补货未回归。保留并说明无关工作区改动，不提交 Git。
