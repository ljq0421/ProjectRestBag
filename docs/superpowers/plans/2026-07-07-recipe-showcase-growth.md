# Recipe Showcase Growth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the MVP recipe and showcase product growth system described in `docs/superpowers/specs/2026-07-07-recipe-showcase-growth-design.zh.md`.

**Architecture:** Add a focused `RecipeGrowthService` for thresholds, trait generation, and bonus math; keep persistent per-recipe state in `GameState`; wire production and sale events through existing `RecipeBook`, `ShopSimulation`, and timed showcase sale paths. UI stays in `main_view.gd`, displaying growth stage and active traits without changing the scene tree.

**Tech Stack:** Godot 4.6.1, GDScript, existing headless self-check script `tests/mvp_self_check.gd`, existing JSON-backed catalog/display-rule loaders in `scripts/catalog.gd`.

## Global Constraints

- Do not replace `doc/橱窗配方布局设计.md`; implement growth as a layer over existing adjacent bonus, conflict penalty, set bonus, and zone rules.
- Growth MVP sources are making products, selling products, and triggering positive adjacent/set showcase bonuses.
- Conflict penalties do not count as growth sources.
- One product can gain at most 1 `adjacency_trigger_count` per sale result.
- MVP stores `mastery_level`, `made_count`, `sold_count`, `adjacency_trigger_count`, `display_traits`, and `selected_display_traits`.
- Mastery levels are `0=试作品`, `1=稳定款`, `2=人气款`, `3=招牌款`.
- Thresholds are: level 1 at made 5 and sold 3; level 2 at made 15 and sold 10; level 3 at made 40, sold 25, and positive adjacency 10.
- MVP unlocks 1 neighbor trait at 人气款 and 1 shape trait at 招牌款.
- Do not hand-author growth trees for all 149 recipes; generate traits from recipe tags and display shape, with small explicit overrides only for representative products.
- Keep docs and comments Chinese-facing where they are user-visible; method and field names remain English to match existing code.
- Do not commit automatically unless the user explicitly requests it.

---

## File Structure

- Create `scripts/recipe_growth_service.gd`: pure static service for default growth records, thresholds, trait generation, mastery naming, and growth bonus calculation.
- Modify `scripts/game_state.gd`: persist `recipe_growth`, expose record/query methods, sanitize saved growth data, and enqueue growth notifications.
- Modify `scripts/recipe_book.gd`: record made counts after successful product creation.
- Modify `scripts/shop_simulation.gd`: record sold counts and positive showcase-adjacency growth during business-run sales; apply growth bonuses after existing showcase rules.
- Modify `scripts/main_view.gd`: record timed showcase sales and display growth stage/traits in showcase buttons, tooltips, and catalog details.
- Modify `tests/mvp_self_check.gd`: extend the durable headless gate with persistence, threshold, event, bonus, and UI-text checks.

---

### Task 1: Growth State And Service

**Files:**
- Create: `scripts/recipe_growth_service.gd`
- Modify: `scripts/game_state.gd`
- Test: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `Catalog.get_recipes()`, `Catalog.get_recipe_display_config()`.
- Produces:
  - `RecipeGrowthService.default_growth(recipe_id: String) -> Dictionary`
  - `RecipeGrowthService.evaluate_growth(recipe_id: String, growth: Dictionary, recipe: Dictionary, display_config: Dictionary) -> Dictionary`
  - `RecipeGrowthService.mastery_name(level: int) -> String`
  - `RecipeGrowthService.growth_bonus(recipe_id: String, growth: Dictionary, recipe: Dictionary, display_config: Dictionary) -> Dictionary`
  - `GameState.get_recipe_growth(recipe_id: String) -> Dictionary`
  - `GameState.record_recipe_made(recipe_id: String, amount: int) -> Dictionary`
  - `GameState.record_recipe_sold(recipe_id: String, amount: int, positive_adjacency: bool = false) -> Dictionary`
  - `GameState.recipe_growth_stage_name(recipe_id: String) -> String`

- [ ] **Step 1: Add failing self-check coverage**

In `tests/mvp_self_check.gd`, add `const RECIPE_GROWTH_SERVICE_PATH := "res://scripts/recipe_growth_service.gd"` next to the existing script path constants.

In `_expect_game_state_behaviors()`, add these required methods to the `_expect_methods("GameState.new_game()", state, [...])` list:

```gdscript
		"get_recipe_growth",
		"record_recipe_made",
		"record_recipe_sold",
		"recipe_growth_stage_name"
```

Still in `_expect_game_state_behaviors()`, after the task progress assertions, add:

```gdscript
	_expect_dictionary_size("new game recipe growth", state.to_dict().get("recipe_growth", {}), 0)
	var initial_growth: Dictionary = state.get_recipe_growth("butter_cookie")
	_expect_field_value("default butter mastery", initial_growth, "mastery_level", 0)
	_expect_field_value("default butter made count", initial_growth, "made_count", 0)
	_expect_field_value("default butter sold count", initial_growth, "sold_count", 0)
	_expect_field_value("default butter adjacency count", initial_growth, "adjacency_trigger_count", 0)
	_expect_array_size("default butter display traits", initial_growth.get("display_traits", []), 0)
	if state.recipe_growth_stage_name("butter_cookie") != "试作品":
		_fail("default butter_cookie growth stage should be 试作品")
	state.record_recipe_made("butter_cookie", 5)
	state.record_recipe_sold("butter_cookie", 3, false)
	var stable_growth: Dictionary = state.get_recipe_growth("butter_cookie")
	_expect_field_value("stable butter mastery", stable_growth, "mastery_level", 1)
	if state.recipe_growth_stage_name("butter_cookie") != "稳定款":
		_fail("butter_cookie should become 稳定款 after 5 made and 3 sold")
	state.record_recipe_made("butter_cookie", 10)
	state.record_recipe_sold("butter_cookie", 7, true)
	var popular_growth: Dictionary = state.get_recipe_growth("butter_cookie")
	_expect_field_value("popular butter mastery", popular_growth, "mastery_level", 2)
	if not (popular_growth.get("display_traits", []) as Array).has("tea_partner"):
		_fail("popular butter_cookie should unlock tea_partner from classic crunchy cookie tags")
	state.record_recipe_made("butter_cookie", 25)
	state.record_recipe_sold("butter_cookie", 15, true)
	for _growth_index in range(9):
		state.record_recipe_sold("butter_cookie", 0, true)
	var signature_growth: Dictionary = state.get_recipe_growth("butter_cookie")
	_expect_field_value("signature butter mastery", signature_growth, "mastery_level", 3)
	if not (signature_growth.get("display_traits", []) as Array).has("gift_box_shape"):
		_fail("signature butter_cookie should unlock gift_box_shape")
	var restored_growth_state = game_state_script.from_dict(state.to_dict())
	_expect_field_value("restored butter mastery", restored_growth_state.get_recipe_growth("butter_cookie"), "mastery_level", 3)
```

- [ ] **Step 2: Run self-check and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL because `recipe_growth_service.gd` and `GameState.get_recipe_growth` do not exist.

- [ ] **Step 3: Create `scripts/recipe_growth_service.gd`**

Create:

```gdscript
extends RefCounted

const MASTERY_TRIAL := 0
const MASTERY_STABLE := 1
const MASTERY_POPULAR := 2
const MASTERY_SIGNATURE := 3

const MASTERY_NAMES := {
	MASTERY_TRIAL: "试作品",
	MASTERY_STABLE: "稳定款",
	MASTERY_POPULAR: "人气款",
	MASTERY_SIGNATURE: "招牌款"
}

const LEVEL_THRESHOLDS := {
	MASTERY_STABLE: {"made_count": 5, "sold_count": 3, "adjacency_trigger_count": 0},
	MASTERY_POPULAR: {"made_count": 15, "sold_count": 10, "adjacency_trigger_count": 0},
	MASTERY_SIGNATURE: {"made_count": 40, "sold_count": 25, "adjacency_trigger_count": 10}
}

const TAG_TRAITS := [
	{"id": "summer_fresh", "tags": ["果香", "清爽"], "price_pct": 0.0, "speed_pct": 5.0, "label": "夏日清爽"},
	{"id": "rich_bittersweet", "tags": ["苦甜", "浓郁"], "price_pct": 5.0, "speed_pct": 0.0, "label": "醇厚苦甜"},
	{"id": "sweet_salty_bridge", "tags": ["甜", "咸香"], "price_pct": 0.0, "speed_pct": 6.0, "label": "咸甜桥梁"},
	{"id": "soft_sweet_hot", "tags": ["软糯", "甜"], "price_pct": 0.0, "speed_pct": 5.0, "label": "软糯热卖"},
	{"id": "tea_partner", "tags": ["经典", "香脆"], "price_pct": 0.0, "speed_pct": 5.0, "label": "茶点搭档"},
	{"id": "classic_display", "tags": ["经典"], "price_pct": 0.0, "speed_pct": 3.0, "label": "经典陈列"},
	{"id": "light_fresh", "tags": ["低负担", "清爽"], "price_pct": 3.0, "speed_pct": 3.0, "label": "轻食推荐"}
]

const SHAPE_TRAITS := {
	"迷你款": {"id": "gift_box_shape", "price_pct": 8.0, "speed_pct": -3.0, "label": "礼盒装"},
	"横盘款": {"id": "gift_box_shape", "price_pct": 8.0, "speed_pct": -3.0, "label": "礼盒装"},
	"竖杯款": {"id": "small_fast_shape", "price_pct": -3.0, "speed_pct": 6.0, "label": "小份走量"},
	"中块款": {"id": "large_signature_shape", "price_pct": 10.0, "speed_pct": -5.0, "label": "大份招牌"},
	"招牌款": {"id": "large_signature_shape", "price_pct": 10.0, "speed_pct": -5.0, "label": "大份招牌"}
}


static func default_growth(_recipe_id: String) -> Dictionary:
	return {
		"mastery_level": MASTERY_TRIAL,
		"made_count": 0,
		"sold_count": 0,
		"adjacency_trigger_count": 0,
		"display_traits": [],
		"selected_display_traits": []
	}


static func sanitize_growth(recipe_id: String, raw_value: Variant, recipe: Dictionary, display_config: Dictionary) -> Dictionary:
	var growth := default_growth(recipe_id)
	if raw_value is Dictionary:
		var raw: Dictionary = raw_value
		growth["mastery_level"] = clampi(int(raw.get("mastery_level", 0)), 0, MASTERY_SIGNATURE)
		growth["made_count"] = maxi(0, int(raw.get("made_count", 0)))
		growth["sold_count"] = maxi(0, int(raw.get("sold_count", 0)))
		growth["adjacency_trigger_count"] = maxi(0, int(raw.get("adjacency_trigger_count", 0)))
		growth["display_traits"] = _sanitize_string_array(raw.get("display_traits", []))
		growth["selected_display_traits"] = _sanitize_string_array(raw.get("selected_display_traits", growth["display_traits"]))
	return evaluate_growth(recipe_id, growth, recipe, display_config)


static func evaluate_growth(recipe_id: String, growth: Dictionary, recipe: Dictionary, display_config: Dictionary) -> Dictionary:
	var level := MASTERY_TRIAL
	for candidate in [MASTERY_STABLE, MASTERY_POPULAR, MASTERY_SIGNATURE]:
		var threshold: Dictionary = LEVEL_THRESHOLDS[candidate]
		if int(growth.get("made_count", 0)) >= int(threshold.get("made_count", 0)) \
				and int(growth.get("sold_count", 0)) >= int(threshold.get("sold_count", 0)) \
				and int(growth.get("adjacency_trigger_count", 0)) >= int(threshold.get("adjacency_trigger_count", 0)):
			level = candidate
	growth["mastery_level"] = level
	var traits: Array[String] = []
	if level >= MASTERY_POPULAR:
		var tag_trait := _tag_trait_for_recipe(recipe)
		if not tag_trait.is_empty():
			traits.append(tag_trait)
	if level >= MASTERY_SIGNATURE:
		var shape_trait := _shape_trait_for_recipe(recipe_id, display_config)
		if not shape_trait.is_empty() and not traits.has(shape_trait):
			traits.append(shape_trait)
	growth["display_traits"] = traits
	growth["selected_display_traits"] = traits.duplicate()
	return growth


static func mastery_name(level: int) -> String:
	return String(MASTERY_NAMES.get(clampi(level, 0, MASTERY_SIGNATURE), "试作品"))


static func growth_bonus(recipe_id: String, growth: Dictionary, recipe: Dictionary, display_config: Dictionary) -> Dictionary:
	var level := clampi(int(growth.get("mastery_level", 0)), 0, MASTERY_SIGNATURE)
	var price_pct := 0.0
	var speed_pct := 0.0
	if level >= MASTERY_POPULAR:
		price_pct += 5.0
	if level >= MASTERY_SIGNATURE:
		price_pct += 8.0
		speed_pct += 5.0
	for trait_id in _sanitize_string_array(growth.get("selected_display_traits", growth.get("display_traits", []))):
		var trait_bonus := _trait_bonus(recipe_id, trait_id, recipe, display_config)
		price_pct += float(trait_bonus.get("price_pct", 0.0))
		speed_pct += float(trait_bonus.get("speed_pct", 0.0))
	price_pct = clampf(price_pct, -15.0, 20.0)
	speed_pct = clampf(speed_pct, -15.0, 20.0)
	return {
		"price_pct": price_pct,
		"speed_pct": speed_pct,
		"price_multiplier": 1.0 + price_pct / 100.0,
		"speed_multiplier": 1.0 + speed_pct / 100.0,
		"mastery_level": level,
		"mastery_name": mastery_name(level),
		"traits": _sanitize_string_array(growth.get("display_traits", [])),
		"trait_labels": trait_labels(growth.get("display_traits", []))
	}


static func trait_labels(traits_value: Variant) -> Array[String]:
	var labels: Array[String] = []
	for trait_id in _sanitize_string_array(traits_value):
		labels.append(_trait_label(trait_id))
	return labels


static func has_positive_showcase_growth_source(bonus: Dictionary) -> bool:
	var breakdown: Dictionary = bonus.get("breakdown", {})
	if breakdown.has("adjacency_tag"):
		var adjacency: Dictionary = breakdown.get("adjacency_tag", {})
		if float(adjacency.get("price_pct", 0.0)) > 0.0 or float(adjacency.get("speed_pct", 0.0)) > 0.0:
			return true
	if breakdown.has("set"):
		var set_bonus: Dictionary = breakdown.get("set", {})
		if float(set_bonus.get("price_pct", 0.0)) > 0.0 or float(set_bonus.get("speed_pct", 0.0)) > 0.0:
			return true
	return false


static func _tag_trait_for_recipe(recipe: Dictionary) -> String:
	var tags: Array = recipe.get("tags", [])
	for entry in TAG_TRAITS:
		var required: Array = entry.get("tags", [])
		var matches_all := true
		for tag in required:
			if not tags.has(tag):
				matches_all = false
				break
		if matches_all:
			return String(entry.get("id", ""))
	return ""


static func _shape_trait_for_recipe(recipe_id: String, display_config: Dictionary) -> String:
	var recipe_display: Dictionary = display_config.get("recipes", {}).get(recipe_id, {})
	var shape_category := String(recipe_display.get("shape_category", ""))
	return String(SHAPE_TRAITS.get(shape_category, {}).get("id", ""))


static func _trait_bonus(recipe_id: String, trait_id: String, recipe: Dictionary, display_config: Dictionary) -> Dictionary:
	for entry in TAG_TRAITS:
		if String(entry.get("id", "")) == trait_id:
			return {"price_pct": float(entry.get("price_pct", 0.0)), "speed_pct": float(entry.get("speed_pct", 0.0))}
	var recipe_display: Dictionary = display_config.get("recipes", {}).get(recipe_id, {})
	var shape_category := String(recipe_display.get("shape_category", ""))
	var shape_trait: Dictionary = SHAPE_TRAITS.get(shape_category, {})
	if String(shape_trait.get("id", "")) == trait_id:
		return {"price_pct": float(shape_trait.get("price_pct", 0.0)), "speed_pct": float(shape_trait.get("speed_pct", 0.0))}
	return {"price_pct": 0.0, "speed_pct": 0.0}


static func _trait_label(trait_id: String) -> String:
	for entry in TAG_TRAITS:
		if String(entry.get("id", "")) == trait_id:
			return String(entry.get("label", trait_id))
	for shape_trait in SHAPE_TRAITS.values():
		if String(shape_trait.get("id", "")) == trait_id:
			return String(shape_trait.get("label", trait_id))
	return trait_id


static func _sanitize_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		var text := String(item)
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result
```

- [ ] **Step 4: Add `GameState` persistence and APIs**

In `scripts/game_state.gd`, add the preload:

```gdscript
const RecipeGrowthService = preload("res://scripts/recipe_growth_service.gd")
```

Add the field after `display_items`:

```gdscript
var recipe_growth: Dictionary = {}
```

In `new_game()`, after `state.display_items = {}`:

```gdscript
	state.recipe_growth = {}
```

In `from_dict(data)`, after display items are loaded:

```gdscript
	state.recipe_growth = state._sanitize_recipe_growth(data.get("recipe_growth", {}))
```

In `to_dict()`, after `"display_items": _serialize_display_items(),`:

```gdscript
		"recipe_growth": recipe_growth.duplicate(true),
```

Add public methods near `is_recipe_unlocked()`:

```gdscript
func get_recipe_growth(recipe_id: String) -> Dictionary:
	if recipe_id.is_empty() or not _recipes().has(recipe_id):
		return RecipeGrowthService.default_growth(recipe_id)
	if not recipe_growth.has(recipe_id):
		recipe_growth[recipe_id] = RecipeGrowthService.default_growth(recipe_id)
	_update_recipe_growth(recipe_id, false)
	return recipe_growth[recipe_id].duplicate(true)


func record_recipe_made(recipe_id: String, amount: int) -> Dictionary:
	if recipe_id.is_empty() or amount <= 0 or not _recipes().has(recipe_id):
		return {}
	_ensure_recipe_growth(recipe_id)
	var growth: Dictionary = recipe_growth[recipe_id]
	growth["made_count"] = maxi(0, int(growth.get("made_count", 0))) + amount
	recipe_growth[recipe_id] = growth
	return _update_recipe_growth(recipe_id, true)


func record_recipe_sold(recipe_id: String, amount: int, positive_adjacency: bool = false) -> Dictionary:
	if recipe_id.is_empty() or not _recipes().has(recipe_id):
		return {}
	_ensure_recipe_growth(recipe_id)
	var growth: Dictionary = recipe_growth[recipe_id]
	if amount > 0:
		growth["sold_count"] = maxi(0, int(growth.get("sold_count", 0))) + amount
	if positive_adjacency:
		growth["adjacency_trigger_count"] = maxi(0, int(growth.get("adjacency_trigger_count", 0))) + 1
	recipe_growth[recipe_id] = growth
	return _update_recipe_growth(recipe_id, true)


func recipe_growth_stage_name(recipe_id: String) -> String:
	return RecipeGrowthService.mastery_name(int(get_recipe_growth(recipe_id).get("mastery_level", 0)))
```

Add private helpers near the existing sanitizer helpers:

```gdscript
func _ensure_recipe_growth(recipe_id: String) -> void:
	if not recipe_growth.has(recipe_id):
		recipe_growth[recipe_id] = RecipeGrowthService.default_growth(recipe_id)


func _update_recipe_growth(recipe_id: String, notify: bool) -> Dictionary:
	var recipes := _recipes()
	if not recipes.has(recipe_id):
		return {}
	var before_level := int(recipe_growth.get(recipe_id, {}).get("mastery_level", 0))
	var catalog := Catalog.new()
	var updated := RecipeGrowthService.evaluate_growth(
		recipe_id,
		recipe_growth.get(recipe_id, RecipeGrowthService.default_growth(recipe_id)),
		recipes[recipe_id],
		catalog.get_recipe_display_config()
	)
	recipe_growth[recipe_id] = updated
	var after_level := int(updated.get("mastery_level", 0))
	if notify and after_level > before_level:
		var recipe_name := String(recipes[recipe_id].get("name", recipe_id))
		enqueue_notification("%s 成长为%s" % [recipe_name, RecipeGrowthService.mastery_name(after_level)], "制作、售卖和橱窗搭配让这道配方更成熟了。")
		add_log("recipe_growth:%s:%d" % [recipe_id, after_level])
	return updated.duplicate(true)


func _sanitize_recipe_growth(raw_value: Variant) -> Dictionary:
	var result := {}
	if not raw_value is Dictionary:
		return result
	var recipes := _recipes()
	var catalog := Catalog.new()
	var display_config := catalog.get_recipe_display_config()
	var raw: Dictionary = raw_value
	for recipe_id_value in raw.keys():
		var recipe_id := String(recipe_id_value)
		if not recipes.has(recipe_id):
			continue
		result[recipe_id] = RecipeGrowthService.sanitize_growth(recipe_id, raw[recipe_id_value], recipes[recipe_id], display_config)
	return result
```

- [ ] **Step 5: Run self-check and verify it passes for Task 1**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS and output contains `MVP_SELF_CHECK_PASS`.

---

### Task 2: Production And Sale Event Wiring

**Files:**
- Modify: `scripts/recipe_book.gd`
- Modify: `scripts/shop_simulation.gd`
- Modify: `scripts/main_view.gd`
- Test: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `GameState.record_recipe_made(recipe_id, amount)`, `GameState.record_recipe_sold(recipe_id, amount, positive_adjacency)`, `RecipeGrowthService.has_positive_showcase_growth_source(bonus)`.
- Produces: production and sale paths that update `recipe_growth` without changing existing task events.

- [ ] **Step 1: Add failing production/sale checks**

In `_expect_recipe_book_behaviors()`, after the existing `production_result` assertions for `sponge_cake`, add:

```gdscript
	var production_growth: Dictionary = production_state.get_recipe_growth("sponge_cake")
	_expect_field_value("sponge made count after one batch", production_growth, "made_count", 3)
```

After the existing `batch_result` assertions, add:

```gdscript
	var batch_growth: Dictionary = batch_state.get_recipe_growth("sponge_cake")
	_expect_field_value("sponge made count after five batches", batch_growth, "made_count", 15)
```

In the sale section of `_expect_shop_simulation_behaviors()` or the function that currently builds `sale_state`, after `ShopSimulation.run_business(sale_state, ...)`, add:

```gdscript
	var sale_growth: Dictionary = sale_state.get_recipe_growth("sponge_cake")
	if int(sale_growth.get("sold_count", 0)) <= 0:
		_fail("ShopSimulation.run_business should record sold_count for sold sponge_cake")
```

In the timed showcase sale check, after `_sell_ready_showcase_slot(...)` succeeds, add:

```gdscript
	var timed_sale_growth: Dictionary = scene.state.get_recipe_growth("sponge_cake")
	if int(timed_sale_growth.get("sold_count", 0)) <= 0:
		_fail("timed showcase sale should record sold_count for sponge_cake")
```

- [ ] **Step 2: Run self-check and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL because production and sales do not yet record recipe growth.

- [ ] **Step 3: Wire production counts**

In `scripts/recipe_book.gd`, inside `make_product()`, after `state.add_product(recipe_id, output_count)` succeeds and before `_add_log(...)`, add:

```gdscript
	if state.has_method("record_recipe_made"):
		state.record_recipe_made(recipe_id, output_count)
```

- [ ] **Step 4: Wire business-run sale counts and adjacency source**

In `scripts/shop_simulation.gd`, add the preload below the `Catalog` preload:

```gdscript
const RecipeGrowthService = preload("res://scripts/recipe_growth_service.gd")
```

Inside `run_business()`, after stock removal succeeds and before reputation is applied, add:

```gdscript
		var product_bonus: Dictionary = product_bonuses.get(recipe_id, {})
		var positive_adjacency := RecipeGrowthService.has_positive_showcase_growth_source(product_bonus)
		if state.has_method("record_recipe_sold"):
			state.record_recipe_sold(recipe_id, 1, positive_adjacency)
```

This records at most one adjacency growth event per sold item because `record_recipe_sold()` only receives a boolean.

- [ ] **Step 5: Wire timed showcase sale counts**

In `scripts/main_view.gd`, add the preload near existing preloads:

```gdscript
const RecipeGrowthService = preload("res://scripts/recipe_growth_service.gd")
```

In `_sell_ready_showcase_slot(slot_index: int, now_unix: int)`, after `sold` is confirmed and before `_record_business_feedback(...)`, add:

```gdscript
	var positive_adjacency := RecipeGrowthService.has_positive_showcase_growth_source(bonus)
	if state.has_method("record_recipe_sold"):
		state.record_recipe_sold(recipe_id, 1, positive_adjacency)
```

- [ ] **Step 6: Run self-check and verify it passes for Task 2**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS and output contains `MVP_SELF_CHECK_PASS`.

---

### Task 3: Growth Bonuses In Showcase Calculation

**Files:**
- Modify: `scripts/shop_simulation.gd`
- Test: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `GameState.get_recipe_growth(recipe_id)`, `RecipeGrowthService.growth_bonus(...)`.
- Produces: `product_bonuses[recipe_id].breakdown["growth"]` with `price_pct`, `speed_pct`, `mastery_name`, `traits`, and `trait_labels`; final `price_multiplier` and `speed_multiplier` include growth after existing zone/adjacency/set/conflict rules.

- [ ] **Step 1: Add failing bonus checks**

In the existing shop-simulation bonus self-check, set up a state with `sponge_cake` in display, then add:

```gdscript
	growth_bonus_state.record_recipe_made("sponge_cake", 40)
	growth_bonus_state.record_recipe_sold("sponge_cake", 25, false)
	for _growth_index in range(10):
		growth_bonus_state.record_recipe_sold("sponge_cake", 0, true)
	var growth_bonuses: Dictionary = shop_simulation_script._calculate_all_product_bonuses(
		growth_bonus_state,
		catalog.get_recipes(),
		catalog.get_display_rules()
	)
	var sponge_bonus: Dictionary = growth_bonuses.get("sponge_cake", {})
	if not sponge_bonus.get("breakdown", {}).has("growth"):
		_fail("showcase bonuses should include growth breakdown for signature sponge_cake")
	if float(sponge_bonus.get("price_multiplier", 1.0)) <= 1.0:
		_fail("signature sponge_cake should increase final price multiplier")
```

- [ ] **Step 2: Run self-check and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL because `_calculate_all_product_bonuses()` does not apply growth.

- [ ] **Step 3: Apply growth after existing showcase rules**

In `scripts/shop_simulation.gd`, after the golden C-zone multiplier block and before `return bonuses`, add:

```gdscript
	var catalog := Catalog.new()
	var display_config := catalog.get_recipe_display_config()
	for recipe_id in bonuses.keys():
		if not state.has_method("get_recipe_growth"):
			continue
		var recipe: Dictionary = recipes.get(recipe_id, {})
		if recipe.is_empty():
			continue
		var growth: Dictionary = state.get_recipe_growth(String(recipe_id))
		var growth_bonus: Dictionary = RecipeGrowthService.growth_bonus(String(recipe_id), growth, recipe, display_config)
		if float(growth_bonus.get("price_pct", 0.0)) == 0.0 and float(growth_bonus.get("speed_pct", 0.0)) == 0.0:
			continue
		bonuses[recipe_id].price_multiplier *= float(growth_bonus.get("price_multiplier", 1.0))
		bonuses[recipe_id].speed_multiplier *= float(growth_bonus.get("speed_multiplier", 1.0))
		bonuses[recipe_id].breakdown["growth"] = growth_bonus
```

- [ ] **Step 4: Run self-check and verify it passes for Task 3**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS and output contains `MVP_SELF_CHECK_PASS`.

---

### Task 4: UI Text And Final Verification

**Files:**
- Modify: `scripts/main_view.gd`
- Test: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `GameState.recipe_growth_stage_name(recipe_id)`, `GameState.get_recipe_growth(recipe_id)`, `RecipeGrowthService.trait_labels(traits)`.
- Produces: showcase slot text with mastery suffix and tooltip/catalog detail text with stage, progress, traits, and next condition.

- [ ] **Step 1: Add failing UI text checks**

In the main-scene structure self-check, after listing `sponge_cake` into the showcase and before final assertions, add:

```gdscript
	scene.state.record_recipe_made("sponge_cake", 15)
	scene.state.record_recipe_sold("sponge_cake", 10, false)
	scene._refresh_storefront_showcase()
	if not _grid_text_contains(scene.showcase_grid, "人气"):
		_fail("storefront showcase should show recipe growth stage text")
	var showcase_tooltip_found := false
	for child in scene.showcase_grid.get_children():
		if child is Button and String((child as Button).tooltip_text).find("成长阶段") != -1:
			showcase_tooltip_found = true
			break
	if not showcase_tooltip_found:
		_fail("storefront showcase tooltip should show recipe growth details")
	scene._refresh_catalog_panel()
	if not _item_list_text_contains(scene.catalog_detail_list, "成长阶段"):
		_fail("catalog details should show recipe growth stage")
```

This reuses the existing `_item_list_text_contains(item_list: ItemList, expected: String) -> bool` helper in `tests/mvp_self_check.gd`.

- [ ] **Step 2: Run self-check and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL because the UI does not yet show growth state.

- [ ] **Step 3: Add growth labels to showcase slot text**

In `scripts/main_view.gd`, add this helper near `_recipe_name()`:

```gdscript
func _recipe_growth_label(recipe_id: String) -> String:
	if state == null or not state.has_method("recipe_growth_stage_name"):
		return ""
	var label := state.recipe_growth_stage_name(recipe_id)
	return label if label != "试作品" else ""
```

Modify `_showcase_slot_text()` by replacing the two return lines for non-empty slots with:

```gdscript
	var display_name := _recipe_name(recipe_id)
	var growth_label := _recipe_growth_label(recipe_id)
	if not growth_label.is_empty():
		display_name = "%s·%s" % [display_name, growth_label]
	if remaining <= 0:
		return "%s\nx%d\n待售" % [display_name, quantity]
	return "%s\nx%d\n%d秒" % [display_name, quantity, remaining]
```

- [ ] **Step 4: Add growth details to showcase tooltips**

Add helper methods near `_showcase_slot_tooltip()`:

```gdscript
func _recipe_growth_detail_text(recipe_id: String) -> String:
	if state == null or not state.has_method("get_recipe_growth"):
		return "成长阶段：试作品"
	var growth: Dictionary = state.get_recipe_growth(recipe_id)
	var stage := state.recipe_growth_stage_name(recipe_id)
	var traits_value: Variant = growth.get("display_traits", [])
	var trait_labels: Array[String] = RecipeGrowthService.trait_labels(traits_value)
	var trait_text := "无" if trait_labels.is_empty() else "、".join(trait_labels)
	return "成长阶段：%s\n制作：%d 售卖：%d 相邻：%d\n特性：%s" % [
		stage,
		int(growth.get("made_count", 0)),
		int(growth.get("sold_count", 0)),
		int(growth.get("adjacency_trigger_count", 0)),
		trait_text
	]
```

Modify `_showcase_slot_tooltip()` return string to include growth details:

```gdscript
	return "名称：%s\n售价：%d\n上架数量：%d\n库存剩余：%d\n标签：%s\n%s\n%s\n最近售卖：%s" % [
		_recipe_name(recipe_id),
		int(recipe.get("price", 0)),
		maxi(1, int(slot.get("quantity", 1))),
		state.get_product_count(recipe_id),
		"、".join(tag_names),
		sale_text,
		_recipe_growth_detail_text(recipe_id),
		_recent_sale_text(_recipe_name(recipe_id))
	]
```

- [ ] **Step 5: Add growth details to catalog panel**

In `_refresh_catalog_panel()`, replace the unlocked detail `catalog_detail_list.add_item(...)` call with:

```gdscript
			catalog_detail_list.add_item("食材：%s\n工具：%s\n%s" % [
				_unlocked_recipe_material_text(recipe),
				_device_name(String(recipe.get("device", ""))),
				_recipe_growth_detail_text(recipe_id)
			])
```

- [ ] **Step 6: Run final self-check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS and output contains `MVP_SELF_CHECK_PASS`.

- [ ] **Step 7: Run parse/load gate**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --quit
```

Expected: exit code 0 with no parse errors.

- [ ] **Step 8: Run whitespace check**

Run:

```powershell
git diff --check
```

Expected: no output and exit code 0.

---

## Self-Review Checklist

- Spec coverage: Tasks 1-4 cover persistent growth fields, four mastery stages, made/sold/adjacency counts, trait generation, growth bonuses, UI display, and save/load.
- Existing showcase rules remain authoritative: Task 3 applies growth after existing zone, adjacency, set, and conflict calculation and Task 1/2 only count positive adjacency/set sources.
- MVP exclusions preserved: no NPC/customer branch, no manual trait choice UI, no hand-authored 149-recipe trees, no complex direction-only abilities.
- Verification commands: each task ends with `mvp_self_check`; final task adds headless parse/load and `git diff --check`.
