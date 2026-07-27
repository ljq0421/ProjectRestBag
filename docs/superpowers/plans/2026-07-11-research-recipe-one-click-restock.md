# “研发制作”配方一键补货 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为“研发制作”页的每个成品配方行增加一键补货确认流程，按制作一次的缺口购买所有可直购食材，并列出不可直购食材。

**Architecture:** 配方行只发出带 `recipe_id` 的请求；`main_view.gd` 负责报价、原子采购和刷新；独立 `ConfirmationDialog` 场景负责稳定布局与清单展示。确认时重新报价，确保库存或金币变化后仍按最新状态结算。

**Tech Stack:** Godot 4.6.1、GDScript、`.tscn`、仓库内 headless self-check。

## Global Constraints

- 只补足制作当前配方 1 次所需的缺口。
- 不修改 `scripts/catalog.gd` 的采购资格、价格、来源或配方数据。
- 不可直购食材只展示来源限制，不计价、不增加库存。
- 金币不足时整单失败，不允许部分采购。
- 稳定弹框结构放在 `.tscn`；脚本只做数据绑定、状态刷新和信号处理。
- 保留任务开始前已有的工作区改动；未经用户明确要求，不创建 Git commit。
- 所有 Godot headless 命令均从 `project.godot` 所在目录运行，并传入 `--log-file "$env:TEMP\godot-headless.log"`。

## File Structure

- Create `scenes/ui/overlays/recipe_restock_dialog.tscn`：补货确认框结构。
- Create `scripts/ui/overlays/recipe_restock_dialog.gd`：报价展示和确认按钮状态。
- Create `tests/research_recipe_restock_self_check.gd`：聚焦完整补货交互。
- Modify `scenes/Main.tscn`：挂载确认框。
- Modify `scenes/ui/pages/recipe_action_row.tscn`：声明“补货”按钮。
- Modify `scripts/ui/pages/recipe_action_row.gd`：仅为成品配方绑定按钮。
- Modify `scripts/main_view.gd`：报价、弹框、原子采购、保存和刷新。
- Modify `tests/mvp_self_check.gd`：研发制作页入口回归。

---

### Task 1: 缺口报价与原子采购

**Files:**
- Create: `tests/research_recipe_restock_self_check.gd`
- Modify: `scripts/main_view.gd`（配方辅助函数和采购辅助函数附近）

**Interfaces:**
- Consumes: `catalog.get_recipes()`、`catalog.get_ingredients()`、`state.get_ingredient_count()`、`state.add_ingredient()`、`state.coins`、`state.add_log()`、`_is_ingredient_available_for_purchase()`。
- Produces: `_material_requirements(materials: Variant) -> Dictionary`；`_recipe_restock_quote(recipe_id: String) -> Dictionary`；`_purchase_recipe_restock(recipe_id: String) -> Dictionary`。

- [ ] **Step 1: 写失败的聚焦自检**

创建测试并加载真实主场景与可控状态：

```gdscript
extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const GameState := preload("res://scripts/game_state.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var view = MainScene.instantiate()
	root.add_child(view)
	await process_frame
	var state = GameState.new_game()
	state.level = 2
	state.coins = 100
	state.ingredient_inventory.clear()
	state.add_recipe("sponge_cake")
	view.set("state", state)
	var requirements: Dictionary = view.call("_material_requirements", ["sugar", "sugar", "egg"])
	_expect(int(requirements.get("sugar", 0)) == 2, "duplicate materials should aggregate")
	var quote: Dictionary = view.call("_recipe_restock_quote", "sponge_cake")
	_expect(bool(quote.get("ok", false)), "unlocked recipe should produce a quote")
	_expect(quote.get("entries", []) is Array, "quote should expose entries")
	view.free()
	print("RESEARCH_RECIPE_RESTOCK_SELF_CHECK: PASS" if failures.is_empty() else "RESEARCH_RECIPE_RESTOCK_SELF_CHECK: FAIL")
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
```

- [ ] **Step 2: 运行并验证 RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/research_recipe_restock_self_check.gd
```

Expected: FAIL，缺少 `_material_requirements` 或 `_recipe_restock_quote`。

- [ ] **Step 3: 实现最小报价模型**

在 `main_view.gd` 加入：

```gdscript
func _material_requirements(materials_value: Variant) -> Dictionary:
	var result := {}
	if materials_value is Array:
		for value: Variant in materials_value:
			var item_id := String(value)
			if not item_id.is_empty():
				result[item_id] = int(result.get(item_id, 0)) + 1
	return result

func _recipe_restock_quote(recipe_id: String) -> Dictionary:
	var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
	if recipe.is_empty() or state == null or not state.is_recipe_unlocked(recipe_id):
		return {"ok": false, "reason": "配方不可用", "entries": []}
	var entries: Array[Dictionary] = []
	var buyable: Array[Dictionary] = []
	var unavailable: Array[Dictionary] = []
	var total_cost := 0
	var unit_count := 0
	var ingredients := catalog.get_ingredients()
	var requirements := _material_requirements(recipe.get("materials", []))
	for id_value: Variant in requirements.keys():
		var item_id := String(id_value)
		var missing := maxi(int(requirements[item_id]) - state.get_ingredient_count(item_id), 0)
		if missing == 0:
			continue
		var ingredient: Dictionary = ingredients.get(item_id, {})
		var can_buy := _is_ingredient_available_for_purchase(item_id, ingredient)
		var price := int(ingredient.get("price", 0))
		var entry := {"item_id": item_id, "name": _ingredient_name(item_id), "missing": missing,
			"purchasable": can_buy, "unit_price": price, "subtotal": price * missing if can_buy else 0,
			"source": String(ingredient.get("source", "对应产地"))}
		entries.append(entry)
		if can_buy:
			buyable.append(entry)
			total_cost += int(entry.subtotal)
			unit_count += missing
		else:
			unavailable.append(entry)
	return {"ok": true, "recipe_id": recipe_id, "recipe_name": String(recipe.get("name", recipe_id)),
		"entries": entries, "purchasable_entries": buyable, "unavailable_entries": unavailable,
		"total_cost": total_cost, "purchasable_units": unit_count}
```

- [ ] **Step 4: 扩展测试，先验证原子采购失败**

增加可支付和不可支付两个分支：

```gdscript
var before_coins := int(state.coins)
var purchase: Dictionary = view.call("_purchase_recipe_restock", "sponge_cake")
_expect(bool(purchase.get("ok", false)), "affordable quote should purchase")
_expect(int(state.coins) == before_coins - int(quote.total_cost), "purchase should charge exact total")
var poor_state = GameState.new_game()
poor_state.level = 2
poor_state.coins = 0
poor_state.ingredient_inventory.clear()
poor_state.add_recipe("sponge_cake")
view.set("state", poor_state)
var poor_before := poor_state.to_dict()
var failed: Dictionary = view.call("_purchase_recipe_restock", "sponge_cake")
_expect(not bool(failed.get("ok", false)), "unaffordable quote should fail")
_expect(poor_state.to_dict().ingredient_inventory == poor_before.ingredient_inventory, "failure should preserve inventory")
```

运行 Step 2 命令。Expected: FAIL，缺少 `_purchase_recipe_restock`。

- [ ] **Step 5: 实现原子采购并验证 GREEN**

```gdscript
func _purchase_recipe_restock(recipe_id: String) -> Dictionary:
	var quote := _recipe_restock_quote(recipe_id)
	if not bool(quote.get("ok", false)):
		return {"ok": false, "reason": quote.get("reason", "配方不可用"), "quote": quote}
	if quote.entries.is_empty():
		return {"ok": false, "reason": "材料充足", "quote": quote}
	if quote.purchasable_entries.is_empty():
		return {"ok": false, "reason": "没有可直接采购的缺口", "quote": quote}
	if int(state.coins) < int(quote.total_cost):
		return {"ok": false, "reason": "金币不足", "quote": quote}
	state.coins -= int(quote.total_cost)
	for value: Variant in quote.purchasable_entries:
		var entry: Dictionary = value
		state.add_ingredient(String(entry.item_id), int(entry.missing))
		state.add_log("purchase:%s:%d" % [entry.item_id, entry.subtotal])
	return {"ok": true, "reason": "", "quote": quote}
```

运行 Step 2 命令。Expected: exit `0` 且输出 `RESEARCH_RECIPE_RESTOCK_SELF_CHECK: PASS`。

---

### Task 2: 场景优先的确认框

**Files:**
- Create: `scenes/ui/overlays/recipe_restock_dialog.tscn`
- Create: `scripts/ui/overlays/recipe_restock_dialog.gd`
- Modify: `scenes/Main.tscn`
- Modify: `tests/research_recipe_restock_self_check.gd`

**Interfaces:**
- Consumes: Task 1 的 quote 字典。
- Produces: `configure(quote: Dictionary) -> void`；`Body/RestockList`、`Body/TotalLabel`、`Body/HintLabel`；内置 `confirmed` 信号。

- [ ] **Step 1: 先写失败的场景断言**

```gdscript
var dialog = view.get_node_or_null("RecipeRestockDialog")
_expect(dialog is ConfirmationDialog, "Main should mount RecipeRestockDialog")
if dialog != null:
	dialog.call("configure", quote)
	_expect(dialog.get_node("Body/RestockList").text.find("不可直接采购") != -1, "dialog should label unavailable items")
	_expect(dialog.get_node("Body/TotalLabel").text.find(str(quote.total_cost)) != -1, "dialog should show total")
```

运行 Task 1 Step 2 命令。Expected: FAIL，主场景缺少该节点。

- [ ] **Step 2: 创建 `ConfirmationDialog` 场景**

```gdscript
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/ui/overlays/recipe_restock_dialog.gd" id="1_script"]
[node name="RecipeRestockDialog" type="ConfirmationDialog"]
title = "配方一键补货"
initial_position = 2
min_size = Vector2i(560, 420)
ok_button_text = "确认补货"
cancel_button_text = "取消"
script = ExtResource("1_script")
[node name="Body" type="VBoxContainer" parent="."]
custom_minimum_size = Vector2(520, 340)
offset_right = 520.0
offset_bottom = 340.0
[node name="RecipeLabel" type="Label" parent="Body"]
layout_mode = 2
[node name="RestockList" type="RichTextLabel" parent="Body"]
custom_minimum_size = Vector2(0, 220)
layout_mode = 2
size_flags_vertical = 3
[node name="TotalLabel" type="Label" parent="Body"]
layout_mode = 2
[node name="HintLabel" type="Label" parent="Body"]
layout_mode = 2
autowrap_mode = 2
```

- [ ] **Step 3: 实现展示绑定**

```gdscript
extends ConfirmationDialog
@onready var recipe_label: Label = $Body/RecipeLabel
@onready var restock_list: RichTextLabel = $Body/RestockList
@onready var total_label: Label = $Body/TotalLabel
@onready var hint_label: Label = $Body/HintLabel

func configure(quote: Dictionary) -> void:
	recipe_label.text = "当前配方：%s" % quote.recipe_name
	var lines: Array[String] = []
	for value: Variant in quote.entries:
		var entry: Dictionary = value
		if entry.purchasable:
			lines.append("%s ×%d｜单价 %d｜小计 %d 金币" % [entry.name, entry.missing, entry.unit_price, entry.subtotal])
		else:
			lines.append("%s ×%d｜不可直接采购（需通过%s获得）" % [entry.name, entry.missing, entry.source])
	restock_list.text = "\n".join(lines)
	total_label.text = "本次可采购合计：%d 金币" % quote.total_cost
	var can_confirm := not quote.purchasable_entries.is_empty()
	get_ok_button().disabled = not can_confirm
	hint_label.text = "不可直购食材不会计价或加入库存。" if can_confirm else "请先通过对应生产来源获得缺少的食材。"
```

- [ ] **Step 4: 挂载到主场景并验证 GREEN**

将新场景加入 `Main.tscn` 的外部资源并在根节点下实例化：

```gdscript
[node name="RecipeRestockDialog" parent="." instance=ExtResource("10_recipe_restock")]
```

同步增加 `load_steps`。运行 Task 1 Step 2 命令。Expected: PASS，清单和合计断言成立。

---

### Task 3: 配方行入口和确认交互

**Files:**
- Modify: `scenes/ui/pages/recipe_action_row.tscn`
- Modify: `scripts/ui/pages/recipe_action_row.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/research_recipe_restock_self_check.gd`
- Modify: `tests/mvp_self_check.gd`（现有研发制作行断言附近）

**Interfaces:**
- Consumes: Task 1 的报价/采购接口和 Task 2 的 `configure()`/`confirmed`。
- Produces: `_on_recipe_restock_pressed(recipe_id: String) -> void`；`_on_recipe_restock_confirmed() -> void`；`pending_recipe_restock_id: String`。

- [ ] **Step 1: 先写失败的按钮结构测试**

先把 `view.state` 恢复为已执行 `state.add_recipe("sponge_cake")` 的可支付测试状态，再显示研发页并检查行结构：

```gdscript
view.set("state", state)
view.call("_show_page", "research")
var rows = view.get_node("Root/Body/MainArea/WorkbenchPanel/ContentPanel/ListRow/SecondaryList/RecipeScroll/RecipeRows")
for row in rows.get_children():
	if row.has_meta("recipe_id"):
		_expect(row.get_node_or_null("RestockButton") != null, "production row should expose restock")
	if row.has_meta("process_id"):
		_expect(row.get_node_or_null("RestockButton") == null or not row.get_node("RestockButton").visible, "process row should hide restock")
```

在 `mvp_self_check.gd` 的 `rice_milk_drink` 行断言处增加同样的成品行结构检查。运行聚焦测试。Expected: FAIL，按钮缺失。

- [ ] **Step 2: 在配方行场景增加并绑定按钮**

在“制作”和“上架”之间声明：

```gdscript
[node name="RestockButton" type="Button" parent="."]
custom_minimum_size = Vector2(52, 32)
layout_mode = 2
text = "补货"
```

`recipe_action_row.gd` 的 `_bind_nodes()` 绑定 `$RestockButton`；`configure_production()` 连接：

```gdscript
restock_button.visible = true
restock_button.set_meta("recipe_id", recipe_id)
restock_button.set_meta("recipe_action", "restock")
restock_button.pressed.connect(Callable(view, "_on_recipe_restock_pressed").bind(recipe_id))
```

`configure_processing()` 设置 `restock_button.visible = false`。

- [ ] **Step 3: 接入主页面弹框打开逻辑**

```gdscript
@onready var recipe_restock_dialog: ConfirmationDialog = $RecipeRestockDialog
var pending_recipe_restock_id := ""

func _on_recipe_restock_pressed(recipe_id: String) -> void:
	var quote := _recipe_restock_quote(recipe_id)
	if not bool(quote.get("ok", false)):
		_set_status("该配方当前不可补货。")
		return
	if quote.entries.is_empty():
		_set_status("当前配方材料充足。")
		return
	pending_recipe_restock_id = recipe_id
	recipe_restock_dialog.call("configure", quote)
	recipe_restock_dialog.popup_centered(Vector2i(600, 460))
```

在 `_ready()` 中用 `is_connected()` 防重复连接 `recipe_restock_dialog.confirmed`。

- [ ] **Step 4: 写失败的确认交互测试**

断言点击按钮打开弹框；库存充足时不打开；只有不可直购项时 `get_ok_button().disabled`；打开后改变库存再确认时按最新缺口计价；金币不足时金币和库存均不变。

```gdscript
view.call("_on_recipe_restock_pressed", "sponge_cake")
_expect(dialog.visible, "shortage should open dialog")
var latest_quote: Dictionary = view.call("_recipe_restock_quote", "sponge_cake")
var first_buyable: Dictionary = latest_quote.purchasable_entries[0]
state.add_ingredient(String(first_buyable.item_id), 1)
var expected_latest: Dictionary = view.call("_recipe_restock_quote", "sponge_cake")
var coins_before := int(state.coins)
view.call("_on_recipe_restock_confirmed")
_expect(int(state.coins) == coins_before - int(expected_latest.total_cost), "confirm should use latest quote")
```

Expected: FAIL，确认处理函数缺失。

- [ ] **Step 5: 实现确认、反馈、保存和刷新**

```gdscript
func _on_recipe_restock_confirmed() -> void:
	var recipe_id := pending_recipe_restock_id
	pending_recipe_restock_id = ""
	var result := _purchase_recipe_restock(recipe_id)
	var quote: Dictionary = result.get("quote", {})
	if not bool(result.get("ok", false)):
		if String(result.get("reason", "")) == "金币不足":
			_set_status("金币不足，无法补货：需要 %d，当前 %d。" % [quote.get("total_cost", 0), state.coins])
		else:
			_set_status(String(result.get("reason", "补货失败")))
		return
	_save_game()
	_refresh_resource_bar()
	_refresh_current_page()
	var unavailable_names: Array[String] = []
	for value: Variant in quote.get("unavailable_entries", []):
		unavailable_names.append(String(value.get("name", "")))
	var status := "一键补货完成：购买 %d 件，花费 %d 金币。" % [quote.purchasable_units, quote.total_cost]
	if not unavailable_names.is_empty():
		status += " 仍需自产：%s。" % "、".join(unavailable_names)
	_set_status(status)
```

- [ ] **Step 6: 运行聚焦与 MVP 回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/research_recipe_restock_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: 两条命令 exit `0`；聚焦测试输出 `RESEARCH_RECIPE_RESTOCK_SELF_CHECK: PASS`，MVP 自检输出既有 PASS 标记。

---

### Task 4: 最终验证与范围检查

**Files:**
- Verify: Tasks 1-3 的全部文件。

**Interfaces:**
- Consumes: 完整功能。
- Produces: 测试证据和范围受控的 diff。

- [ ] **Step 1: 运行组件与拆分契约**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/main_scene_split_shell_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/component_contract_self_check.gd
```

Expected: 两条命令 exit `0`，无场景缺失或组件类型错误。

- [ ] **Step 2: 运行项目解析检查**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" --quit
```

Expected: exit `0`，无 GDScript parse error 或缺失资源。

- [ ] **Step 3: 审阅范围**

```powershell
git status --short
git diff -- scenes/Main.tscn scenes/ui/pages/recipe_action_row.tscn scripts/ui/pages/recipe_action_row.gd scripts/main_view.gd tests/mvp_self_check.gd
```

另行打开三个新增文件审阅。Expected: 不覆盖任务开始前的 `.gitignore`、配方显示配置、审计文档、其他计划/规格和 `.uid` 改动。

- [ ] **Step 4: 交付**

报告每条验证命令的实际 exit code、修改文件和保留的既有改动；说明未创建 Git commit。
