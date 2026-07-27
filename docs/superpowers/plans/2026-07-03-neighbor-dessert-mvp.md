# Neighbor Dessert MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Godot MVP described in `doc/v3.md`: a playable single-screen dessert-shop loop with purchasing, farm/ranch/pond production, recipe discovery, production, display sales, upgrades, encyclopedia, local save, and automated self-checks.

**Architecture:** Keep gameplay rules in small script modules and keep `main_view.gd` focused on UI rendering and button wiring. Static data lives in `catalog.gd`; mutable state lives in `game_state.gd`; rule modules operate on `GameState` dictionaries and return structured results for the UI and tests.

**Tech Stack:** Godot 4.6, GDScript, `Control` UI scene, JSON save under `user://neighbor_dessert_save.json`, headless verification via `D:\Godot\Godot_v4.6.1-stable_win64_console.exe --headless --path . -s res://tests/mvp_self_check.gd`.

---

## Source Spec

Implement against `D:\Project\ProjectRest\project-rest\doc\v3.md`.

Core MVP requirements:

- 20 core ingredients plus `sea_salt` as the pond test ingredient.
- Farm, ranch, and pond production slots advanced by business runs.
- 4 devices.
- 18 recipes including the `sponge_cake -> cream_shortcake` compound chain.
- Purchasing, research, making products, display slots, business simulation, upgrades, encyclopedia, JSON save.
- Single main UI with tabs: purchase, production sites, research, make, display, encyclopedia, upgrade.

## File Structure

Create these files:

- `res://scripts/catalog.gd`  
  Static dictionaries for ingredients, production sites, devices, recipes, customers, upgrades, labels, and unlock helpers.

- `res://scripts/game_state.gd`  
  Mutable save data, inventory helpers, logs, upgrade helpers, display slots, and production slot storage.

- `res://scripts/production_site.gd`  
  Farm/ranch/pond start, cancel, progress, and harvest rules.

- `res://scripts/recipe_book.gd`  
  Research matching, failure hints, recipe unlocks, and product making.

- `res://scripts/shop_simulation.gd`  
  Customer generation, product scoring, sale simulation, reputation and coin rewards.

- `res://scripts/save_system.gd`  
  JSON save/load with defaults and broken-save recovery.

- `res://scripts/main_view.gd`  
  Runtime UI: resource bar, navigation, content panels, feedback, status.

- `res://scenes/Main.tscn`  
  Main `Control` scene attached to `main_view.gd`.

- `res://tests/mvp_self_check.gd`  
  Headless test runner for catalog integrity and end-to-end MVP flows.

Modify:

- `res://project.godot`  
  Set `application/run/main_scene="res://scenes/Main.tscn"` after the scene exists.

## Task 1: Static Catalog

**Files:**
- Create: `D:\Project\ProjectRest\project-rest\scripts\catalog.gd`
- Create: `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`

- [ ] **Step 1: Create failing catalog integrity checks**

Create `tests/mvp_self_check.gd` with this initial test runner:

```gdscript
extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")

var failures: Array[String] = []

func _init() -> void:
	_run()
	if failures.is_empty():
		print("MVP_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _run() -> void:
	_assert_true(Catalog.INGREDIENTS.size() == 21, "expected 21 ingredients")
	_assert_true(Catalog.DEVICES.size() == 4, "expected 4 devices")
	_assert_true(Catalog.RECIPES.size() == 18, "expected 18 recipes")
	_assert_true(Catalog.PRODUCTION_SITES.size() == 3, "expected 3 production sites")
	_assert_true(Catalog.CUSTOMERS.size() == 6, "expected 6 customers")
	_assert_unique(Catalog.INGREDIENTS.keys(), "ingredient ids")
	_assert_unique(Catalog.DEVICES.keys(), "device ids")
	_assert_unique(Catalog.RECIPES.keys(), "recipe ids")
	for recipe_id in Catalog.RECIPES.keys():
		var recipe: Dictionary = Catalog.RECIPES[recipe_id]
		_assert_true(Catalog.DEVICES.has(recipe.device), "recipe %s references unknown device %s" % [recipe_id, recipe.device])
		for material_id in recipe.materials:
			var exists := Catalog.INGREDIENTS.has(material_id) or Catalog.RECIPES.has(material_id)
			_assert_true(exists, "recipe %s references unknown material %s" % [recipe_id, material_id])

func _assert_unique(values: Array, label: String) -> void:
	var seen := {}
	for value in values:
		_assert_true(not seen.has(value), "%s duplicate %s" % [label, value])
		seen[value] = true

func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
```

- [ ] **Step 2: Run test and verify it fails because catalog does not exist**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL with an error that `res://scripts/catalog.gd` cannot be loaded.

- [ ] **Step 3: Create catalog data**

Create `scripts/catalog.gd`:

```gdscript
extends RefCounted
class_name Catalog

const INITIAL_COINS := 120
const INITIAL_REPUTATION := 0
const INITIAL_SHOP_LEVEL := 1
const MAX_FEEDBACK_LOG := 20

const INGREDIENTS := {
	"flour": {"name": "面粉", "type": "基底", "price": 4, "unlock_level": 1, "source": "purchase", "tags": ["经典"]},
	"egg": {"name": "鸡蛋", "type": "基底", "price": 5, "unlock_level": 1, "source": "ranch", "tags": ["经典"]},
	"milk": {"name": "牛奶", "type": "乳制", "price": 5, "unlock_level": 1, "source": "ranch", "tags": ["清爽"]},
	"sugar": {"name": "砂糖", "type": "调味", "price": 3, "unlock_level": 1, "source": "purchase", "tags": ["甜"]},
	"butter": {"name": "黄油", "type": "乳制", "price": 6, "unlock_level": 1, "source": "ranch", "tags": ["浓郁"]},
	"strawberry": {"name": "草莓", "type": "水果", "price": 8, "unlock_level": 1, "source": "farm", "tags": ["果香", "清爽"]},
	"cream": {"name": "奶油", "type": "乳制", "price": 8, "unlock_level": 2, "source": "ranch", "tags": ["浓郁"]},
	"chocolate": {"name": "巧克力", "type": "风味", "price": 9, "unlock_level": 2, "source": "purchase", "tags": ["苦甜", "浓郁"]},
	"blueberry": {"name": "蓝莓", "type": "水果", "price": 9, "unlock_level": 2, "source": "farm", "tags": ["果香", "清爽"]},
	"banana": {"name": "香蕉", "type": "水果", "price": 7, "unlock_level": 2, "source": "farm", "tags": ["甜", "果香"]},
	"apple": {"name": "苹果", "type": "水果", "price": 7, "unlock_level": 2, "source": "farm", "tags": ["果香"]},
	"lemon": {"name": "柠檬", "type": "水果", "price": 7, "unlock_level": 2, "source": "farm", "tags": ["清爽"]},
	"matcha": {"name": "抹茶", "type": "风味", "price": 10, "unlock_level": 3, "source": "purchase", "tags": ["苦甜", "清爽"]},
	"coffee": {"name": "咖啡", "type": "风味", "price": 10, "unlock_level": 3, "source": "purchase", "tags": ["苦甜"]},
	"red_bean": {"name": "红豆", "type": "风味", "price": 9, "unlock_level": 3, "source": "farm", "tags": ["甜", "经典"]},
	"cheese": {"name": "芝士", "type": "乳制", "price": 11, "unlock_level": 3, "source": "ranch", "tags": ["浓郁"]},
	"honey": {"name": "蜂蜜", "type": "调味", "price": 8, "unlock_level": 3, "source": "farm", "tags": ["甜"]},
	"nuts": {"name": "坚果", "type": "配料", "price": 9, "unlock_level": 4, "source": "farm", "tags": ["香脆"]},
	"yogurt": {"name": "酸奶", "type": "乳制", "price": 9, "unlock_level": 4, "source": "ranch", "tags": ["清爽"]},
	"cocoa": {"name": "可可粉", "type": "风味", "price": 10, "unlock_level": 4, "source": "purchase", "tags": ["苦甜"]},
	"sea_salt": {"name": "海盐", "type": "水产", "price": 6, "unlock_level": 3, "source": "pond", "tags": ["清爽"]},
}

const PRODUCTION_SITES := {
	"farm": {"name": "农场", "unlock_level": 1, "slots": 2, "turns": 2, "cost_rate": 0.3, "yield": 3, "items_by_level": {1: ["strawberry"], 2: ["blueberry", "banana", "apple", "lemon"], 3: ["red_bean", "honey"], 4: ["nuts"]}},
	"ranch": {"name": "牧场", "unlock_level": 2, "slots": 1, "turns": 2, "cost_rate": 0.4, "yield": 4, "items_by_level": {2: ["egg", "milk", "cream"], 3: ["cheese"], 4: ["yogurt"]}},
	"pond": {"name": "鱼塘", "unlock_level": 3, "slots": 1, "turns": 3, "cost_rate": 0.4, "yield": 2, "items_by_level": {3: ["sea_salt"]}},
}

const DEVICES := {
	"mixer": {"name": "搅拌台", "unlock_level": 1},
	"oven": {"name": "烤箱", "unlock_level": 1},
	"chiller": {"name": "冷藏柜", "unlock_level": 2},
	"griddle": {"name": "煎烤盘", "unlock_level": 3},
}

const RECIPES := {
	"sponge_cake": {"name": "海绵杯蛋糕", "device": "oven", "materials": ["flour", "egg", "sugar"], "price": 18, "yield": 3, "unlock_level": 1, "tags": ["经典", "甜"]},
	"butter_cookie": {"name": "黄油曲奇", "device": "oven", "materials": ["flour", "butter", "sugar"], "price": 16, "yield": 4, "unlock_level": 1, "tags": ["经典", "香脆"]},
	"strawberry_milk": {"name": "草莓牛乳杯", "device": "mixer", "materials": ["strawberry", "milk", "sugar"], "price": 17, "yield": 3, "unlock_level": 1, "tags": ["果香", "清爽"]},
	"milk_pudding": {"name": "牛奶布丁", "device": "chiller", "materials": ["milk", "egg", "sugar"], "price": 20, "yield": 3, "unlock_level": 2, "tags": ["清爽", "经典"]},
	"cream_shortcake": {"name": "鲜奶油小蛋糕", "device": "mixer", "materials": ["sponge_cake", "cream", "strawberry"], "price": 28, "yield": 2, "unlock_level": 2, "tags": ["果香", "浓郁"]},
	"chocolate_cookie": {"name": "巧克力曲奇", "device": "oven", "materials": ["flour", "butter", "chocolate"], "price": 24, "yield": 4, "unlock_level": 2, "tags": ["苦甜", "香脆"]},
	"blueberry_mousse": {"name": "蓝莓慕斯杯", "device": "chiller", "materials": ["blueberry", "cream", "sugar"], "price": 26, "yield": 3, "unlock_level": 2, "tags": ["果香", "清爽"]},
	"banana_pancake": {"name": "香蕉松饼", "device": "griddle", "materials": ["flour", "milk", "banana"], "price": 25, "yield": 3, "unlock_level": 3, "tags": ["甜", "果香"]},
	"lemon_tart": {"name": "柠檬小塔", "device": "oven", "materials": ["flour", "butter", "lemon"], "price": 27, "yield": 2, "unlock_level": 3, "tags": ["清爽", "经典"]},
	"matcha_pudding": {"name": "抹茶布丁", "device": "chiller", "materials": ["milk", "egg", "matcha"], "price": 29, "yield": 3, "unlock_level": 3, "tags": ["苦甜", "清爽"]},
	"coffee_mousse": {"name": "咖啡慕斯", "device": "chiller", "materials": ["coffee", "cream", "sugar"], "price": 30, "yield": 3, "unlock_level": 3, "tags": ["苦甜", "浓郁"]},
	"redbean_pancake": {"name": "红豆煎饼", "device": "griddle", "materials": ["flour", "red_bean", "milk"], "price": 28, "yield": 3, "unlock_level": 3, "tags": ["甜", "经典"]},
	"cheesecake": {"name": "芝士蛋糕", "device": "oven", "materials": ["cheese", "egg", "sugar"], "price": 34, "yield": 2, "unlock_level": 3, "tags": ["浓郁", "经典"]},
	"honey_yogurt": {"name": "蜂蜜酸奶杯", "device": "mixer", "materials": ["yogurt", "honey", "blueberry"], "price": 32, "yield": 3, "unlock_level": 4, "tags": ["清爽", "果香"]},
	"apple_crumble": {"name": "苹果坚果酥", "device": "oven", "materials": ["apple", "nuts", "butter"], "price": 36, "yield": 2, "unlock_level": 4, "tags": ["果香", "香脆"]},
	"cocoa_brownie": {"name": "可可布朗尼", "device": "oven", "materials": ["cocoa", "chocolate", "butter"], "price": 38, "yield": 2, "unlock_level": 4, "tags": ["苦甜", "浓郁"]},
	"matcha_redbean": {"name": "抹茶红豆杯", "device": "mixer", "materials": ["matcha", "red_bean", "cream"], "price": 36, "yield": 2, "unlock_level": 4, "tags": ["苦甜", "甜"]},
	"community_parfait": {"name": "邻街招牌芭菲", "device": "chiller", "materials": ["cream", "strawberry", "yogurt"], "price": 42, "yield": 2, "unlock_level": 5, "tags": ["果香", "清爽", "招牌"]},
}

const CUSTOMERS := {
	"student": {"name": "放学学生", "preferences": ["甜", "低价"], "budget": 20, "unlock_level": 1},
	"office_worker": {"name": "加班白领", "preferences": ["苦甜", "浓郁"], "budget": 35, "unlock_level": 2},
	"family": {"name": "亲子家庭", "preferences": ["果香", "经典"], "budget": 40, "unlock_level": 2},
	"fitness_neighbor": {"name": "健身居民", "preferences": ["清爽", "低负担"], "budget": 35, "unlock_level": 3},
	"old_regular": {"name": "老街熟客", "preferences": ["经典", "甜"], "budget": 30, "unlock_level": 3},
	"blogger": {"name": "探店博主", "preferences": ["招牌", "稀有"], "budget": 50, "unlock_level": 5},
}

const UPGRADES := {
	1: {"customer_count": 6, "display_slots": 3},
	2: {"cost_coins": 180, "cost_reputation": 8, "customer_count": 8, "display_slots": 4},
	3: {"cost_coins": 360, "cost_reputation": 22, "customer_count": 10, "display_slots": 4},
	4: {"cost_coins": 680, "cost_reputation": 48, "customer_count": 12, "display_slots": 5},
	5: {"cost_coins": 1100, "cost_reputation": 85, "customer_count": 14, "display_slots": 5},
}

static func is_unlocked(entry: Dictionary, shop_level: int) -> bool:
	return int(entry.get("unlock_level", 1)) <= shop_level
```

- [ ] **Step 4: Run catalog test**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS and output includes `MVP_SELF_CHECK_PASS`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/catalog.gd tests/mvp_self_check.gd
git commit -m "feat: add dessert shop catalog data"
```

## Task 2: Game State and Save System

**Files:**
- Create: `D:\Project\ProjectRest\project-rest\scripts\game_state.gd`
- Create: `D:\Project\ProjectRest\project-rest\scripts\save_system.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`

- [ ] **Step 1: Extend self-check for initial state and inventory**

Add these preloads and checks to `tests/mvp_self_check.gd`:

```gdscript
const GameState = preload("res://scripts/game_state.gd")
const SaveSystem = preload("res://scripts/save_system.gd")

func _run_game_state_checks() -> void:
	var state := GameState.new()
	state.new_game()
	_assert_true(state.coins == 120, "initial coins should be 120")
	_assert_true(state.reputation == 0, "initial reputation should be 0")
	_assert_true(state.shop_level == 1, "initial shop level should be 1")
	_assert_true(state.display_slots.size() == 3, "initial display slots should be 3")
	_assert_true(state.has_ingredient("flour", 0), "has_ingredient should accept zero requirement")
	state.add_ingredient("flour", 3)
	_assert_true(state.has_ingredient("flour", 3), "flour inventory should be 3")
	_assert_true(state.consume_ingredient("flour", 2), "consume flour should succeed")
	_assert_true(state.ingredient_inventory["flour"] == 1, "flour inventory should decrease")
```

Call `_run_game_state_checks()` from `_run()`.

- [ ] **Step 2: Run test and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL because `game_state.gd` and `save_system.gd` are missing.

- [ ] **Step 3: Implement `game_state.gd`**

Create `scripts/game_state.gd`:

```gdscript
extends RefCounted
class_name GameState

const Catalog = preload("res://scripts/catalog.gd")

var coins: int
var reputation: int
var shop_level: int
var ingredient_inventory: Dictionary
var product_inventory: Dictionary
var production_slots: Array
var unlocked_recipes: Array[String]
var display_slots: Array
var discovered_hints: Dictionary
var feedback_log: Array[String]
var business_runs: int

func new_game() -> void:
	coins = Catalog.INITIAL_COINS
	reputation = Catalog.INITIAL_REPUTATION
	shop_level = Catalog.INITIAL_SHOP_LEVEL
	ingredient_inventory = {}
	product_inventory = {}
	production_slots = []
	unlocked_recipes = []
	discovered_hints = {}
	feedback_log = []
	business_runs = 0
	_resize_display_slots()

func _resize_display_slots() -> void:
	var count := int(Catalog.UPGRADES[shop_level].display_slots)
	while display_slots.size() < count:
		display_slots.append("")
	while display_slots.size() > count:
		display_slots.pop_back()

func add_log(message: String) -> void:
	feedback_log.push_front(message)
	while feedback_log.size() > Catalog.MAX_FEEDBACK_LOG:
		feedback_log.pop_back()

func add_ingredient(id: String, amount: int) -> void:
	ingredient_inventory[id] = int(ingredient_inventory.get(id, 0)) + amount

func has_ingredient(id: String, amount: int) -> bool:
	return int(ingredient_inventory.get(id, 0)) >= amount

func consume_ingredient(id: String, amount: int) -> bool:
	if not has_ingredient(id, amount):
		return false
	ingredient_inventory[id] = int(ingredient_inventory[id]) - amount
	return true

func add_product(id: String, amount: int) -> void:
	product_inventory[id] = int(product_inventory.get(id, 0)) + amount

func has_product(id: String, amount: int) -> bool:
	return int(product_inventory.get(id, 0)) >= amount

func consume_product(id: String, amount: int) -> bool:
	if not has_product(id, amount):
		return false
	product_inventory[id] = int(product_inventory[id]) - amount
	return true

func can_afford(amount: int) -> bool:
	return coins >= amount

func spend_coins(amount: int) -> bool:
	if not can_afford(amount):
		return false
	coins -= amount
	return true

func add_recipe(recipe_id: String) -> void:
	if not unlocked_recipes.has(recipe_id):
		unlocked_recipes.append(recipe_id)

func is_recipe_unlocked(recipe_id: String) -> bool:
	return unlocked_recipes.has(recipe_id)

func set_display_slot(index: int, recipe_id: String) -> bool:
	if index < 0 or index >= display_slots.size():
		return false
	if recipe_id != "" and not is_recipe_unlocked(recipe_id):
		return false
	display_slots[index] = recipe_id
	return true

func can_upgrade() -> bool:
	var next_level := shop_level + 1
	if not Catalog.UPGRADES.has(next_level):
		return false
	var upgrade: Dictionary = Catalog.UPGRADES[next_level]
	return coins >= int(upgrade.cost_coins) and reputation >= int(upgrade.cost_reputation)

func upgrade() -> bool:
	if not can_upgrade():
		return false
	var upgrade_data: Dictionary = Catalog.UPGRADES[shop_level + 1]
	coins -= int(upgrade_data.cost_coins)
	reputation -= int(upgrade_data.cost_reputation)
	shop_level += 1
	_resize_display_slots()
	add_log("店铺升级到 %d 级。" % shop_level)
	return true

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"coins": coins,
		"reputation": reputation,
		"shop_level": shop_level,
		"ingredient_inventory": ingredient_inventory,
		"product_inventory": product_inventory,
		"production_slots": production_slots,
		"unlocked_recipes": unlocked_recipes,
		"display_slots": display_slots,
		"discovered_hints": discovered_hints,
		"feedback_log": feedback_log,
		"business_runs": business_runs,
	}

func from_dict(data: Dictionary) -> void:
	new_game()
	coins = int(data.get("coins", coins))
	reputation = int(data.get("reputation", reputation))
	shop_level = int(data.get("shop_level", shop_level))
	ingredient_inventory = data.get("ingredient_inventory", {})
	product_inventory = data.get("product_inventory", {})
	production_slots = data.get("production_slots", [])
	unlocked_recipes.assign(data.get("unlocked_recipes", []))
	display_slots = data.get("display_slots", display_slots)
	discovered_hints = data.get("discovered_hints", {})
	feedback_log.assign(data.get("feedback_log", []))
	business_runs = int(data.get("business_runs", 0))
	_resize_display_slots()
```

- [ ] **Step 4: Implement `save_system.gd`**

Create `scripts/save_system.gd`:

```gdscript
extends RefCounted
class_name SaveSystem

const GameState = preload("res://scripts/game_state.gd")
const SAVE_PATH := "user://neighbor_dessert_save.json"

static func save_game(state: GameState, path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state.to_dict(), "\t"))
	return true

static func load_game(path: String = SAVE_PATH) -> GameState:
	var state := GameState.new()
	state.new_game()
	if not FileAccess.file_exists(path):
		return state
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return state
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_backup_broken(path)
		return state
	state.from_dict(parsed)
	return state

static func _backup_broken(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".broken"))
```

- [ ] **Step 5: Run test**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add scripts/game_state.gd scripts/save_system.gd tests/mvp_self_check.gd
git commit -m "feat: add game state and save system"
```

## Task 3: Farm, Ranch, and Pond Production Sites

**Files:**
- Create: `D:\Project\ProjectRest\project-rest\scripts\production_site.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`

- [ ] **Step 1: Add failing production-site self-check**

Add this preload:

```gdscript
const ProductionSite = preload("res://scripts/production_site.gd")
```

Add and call this function from `_run()`:

```gdscript
func _run_production_site_checks() -> void:
	var state := GameState.new()
	state.new_game()
	var start_result := ProductionSite.start_slot(state, "farm", "strawberry")
	_assert_true(start_result.success, "farm strawberry start should succeed")
	_assert_true(state.production_slots.size() == 1, "one production slot should exist")
	ProductionSite.advance_after_business(state)
	_assert_true(not ProductionSite.harvest_slot(state, 0).success, "immature slot should not harvest")
	ProductionSite.advance_after_business(state)
	var harvest_result := ProductionSite.harvest_slot(state, 0)
	_assert_true(harvest_result.success, "mature farm slot should harvest")
	_assert_true(state.ingredient_inventory.get("strawberry", 0) == 3, "farm should produce 3 strawberries")
	state.shop_level = 3
	var pond_result := ProductionSite.start_slot(state, "pond", "sea_salt")
	_assert_true(pond_result.success, "pond sea salt start should succeed at level 3")
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL because `production_site.gd` is missing.

- [ ] **Step 3: Implement production-site rules**

Create `scripts/production_site.gd`:

```gdscript
extends RefCounted
class_name ProductionSite

const Catalog = preload("res://scripts/catalog.gd")
const GameState = preload("res://scripts/game_state.gd")

static func start_slot(state: GameState, site_id: String, item_id: String) -> Dictionary:
	if not Catalog.PRODUCTION_SITES.has(site_id):
		return {"success": false, "message": "未知产出场景。"}
	var site: Dictionary = Catalog.PRODUCTION_SITES[site_id]
	if state.shop_level < int(site.unlock_level):
		return {"success": false, "message": "%s 尚未解锁。" % site.name}
	if not _site_can_produce(site, state.shop_level, item_id):
		return {"success": false, "message": "%s 当前不能产出该食材。" % site.name}
	if _active_slot_count(state, site_id) >= int(site.slots):
		return {"success": false, "message": "%s 槽位已满。" % site.name}
	var ingredient: Dictionary = Catalog.INGREDIENTS[item_id]
	var cost := int(ceil(float(ingredient.price) * float(site.cost_rate)))
	if not state.spend_coins(cost):
		return {"success": false, "message": "金币不足，无法安排产出。"}
	state.production_slots.append({
		"site_id": site_id,
		"item_id": item_id,
		"turns_remaining": int(site.turns),
		"yield": int(site.yield),
	})
	state.add_log("%s 开始准备%s，预计 %d 轮营业后收获。" % [site.name, ingredient.name, int(site.turns)])
	return {"success": true, "message": "已安排产出。"}

static func cancel_slot(state: GameState, index: int) -> Dictionary:
	if index < 0 or index >= state.production_slots.size():
		return {"success": false, "message": "产出槽位不存在。"}
	state.production_slots.remove_at(index)
	state.add_log("取消了一个产出任务。")
	return {"success": true, "message": "已取消。"}

static func advance_after_business(state: GameState) -> void:
	for slot in state.production_slots:
		slot.turns_remaining = max(0, int(slot.turns_remaining) - 1)

static func harvest_slot(state: GameState, index: int) -> Dictionary:
	if index < 0 or index >= state.production_slots.size():
		return {"success": false, "message": "产出槽位不存在。"}
	var slot: Dictionary = state.production_slots[index]
	if int(slot.turns_remaining) > 0:
		return {"success": false, "message": "还需要 %d 轮营业后才能收获。" % int(slot.turns_remaining)}
	var item_id := String(slot.item_id)
	var amount := int(slot.yield)
	state.add_ingredient(item_id, amount)
	state.production_slots.remove_at(index)
	state.add_log("%s 收获 x%d。" % [Catalog.INGREDIENTS[item_id].name, amount])
	return {"success": true, "message": "收获完成。", "item_id": item_id, "amount": amount}

static func _active_slot_count(state: GameState, site_id: String) -> int:
	var count := 0
	for slot in state.production_slots:
		if String(slot.site_id) == site_id:
			count += 1
	return count

static func _site_can_produce(site: Dictionary, shop_level: int, item_id: String) -> bool:
	var items_by_level: Dictionary = site.items_by_level
	for level in items_by_level.keys():
		if int(level) <= shop_level and items_by_level[level].has(item_id):
			return true
	return false
```

- [ ] **Step 4: Run test**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/production_site.gd tests/mvp_self_check.gd
git commit -m "feat: add farm ranch pond production"
```

## Task 4: Recipe Research and Product Making

**Files:**
- Create: `D:\Project\ProjectRest\project-rest\scripts\recipe_book.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`

- [ ] **Step 1: Add failing recipe checks**

Add preload:

```gdscript
const RecipeBook = preload("res://scripts/recipe_book.gd")
```

Add and call:

```gdscript
func _run_recipe_checks() -> void:
	var state := GameState.new()
	state.new_game()
	for item in ["flour", "egg", "sugar", "butter", "strawberry", "milk"]:
		state.add_ingredient(item, 10)
	var research := RecipeBook.research(state, "oven", ["flour", "egg", "sugar"])
	_assert_true(research.success, "sponge cake research should succeed")
	_assert_true(state.is_recipe_unlocked("sponge_cake"), "sponge cake should be unlocked")
	var make_result := RecipeBook.make_product(state, "sponge_cake", 1)
	_assert_true(make_result.success, "sponge cake make should succeed")
	_assert_true(state.product_inventory.get("sponge_cake", 0) == 3, "sponge cake yield should be 3")
	var fail_result := RecipeBook.research(state, "mixer", ["flour", "egg", "sugar"])
	_assert_true(not fail_result.success, "wrong device should fail")
	_assert_true(String(fail_result.message).contains("设备") or String(fail_result.message).contains("不适合"), "wrong device hint should mention device")
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL because `recipe_book.gd` is missing.

- [ ] **Step 3: Implement recipe research and making**

Create `scripts/recipe_book.gd`:

```gdscript
extends RefCounted
class_name RecipeBook

const Catalog = preload("res://scripts/catalog.gd")
const GameState = preload("res://scripts/game_state.gd")

static func research(state: GameState, device_id: String, material_ids: Array) -> Dictionary:
	if material_ids.size() < 2 or material_ids.size() > 3:
		return {"success": false, "message": "请选择 2-3 个材料。"}
	for material_id in material_ids:
		if not _consume_material(state, String(material_id), 1):
			return {"success": false, "message": "材料库存不足。"}
	var recipe_id := _find_matching_recipe(state.shop_level, device_id, material_ids)
	if recipe_id != "":
		state.add_recipe(recipe_id)
		var reward := 1 + int(Catalog.RECIPES[recipe_id].unlock_level)
		state.reputation += reward
		state.add_log("新品研发成功：%s。" % Catalog.RECIPES[recipe_id].name)
		return {"success": true, "recipe_id": recipe_id, "message": "新品研发成功。"}
	var hint := _build_failure_hint(state.shop_level, device_id, material_ids)
	state.discovered_hints[str(material_ids)] = hint
	state.add_log("试做失败：%s" % hint)
	return {"success": false, "message": hint}

static func make_product(state: GameState, recipe_id: String, batches: int) -> Dictionary:
	if not state.is_recipe_unlocked(recipe_id):
		return {"success": false, "message": "配方尚未解锁。"}
	if batches != 1 and batches != 5:
		return {"success": false, "message": "只能制作 1 次或 5 次。"}
	var recipe: Dictionary = Catalog.RECIPES[recipe_id]
	for material_id in recipe.materials:
		if not _has_material(state, String(material_id), batches):
			return {"success": false, "message": "缺少%s。" % _material_name(String(material_id))}
	for material_id in recipe.materials:
		_consume_material(state, String(material_id), batches)
	var amount := int(recipe.yield) * batches
	state.add_product(recipe_id, amount)
	state.add_log("制作%s x%d。" % [recipe.name, amount])
	return {"success": true, "amount": amount, "message": "制作完成。"}

static func _find_matching_recipe(shop_level: int, device_id: String, material_ids: Array) -> String:
	var selected := _as_set(material_ids)
	var candidates: Array[String] = []
	for recipe_id in Catalog.RECIPES.keys():
		var recipe: Dictionary = Catalog.RECIPES[recipe_id]
		if String(recipe.device) != device_id:
			continue
		if int(recipe.unlock_level) > shop_level:
			continue
		var required := _as_set(recipe.materials)
		var all_required_present := true
		for required_id in required.keys():
			if not selected.has(required_id):
				all_required_present = false
		if all_required_present:
			candidates.append(recipe_id)
	candidates.sort_custom(func(a: String, b: String) -> bool:
		return Catalog.RECIPES[a].materials.size() > Catalog.RECIPES[b].materials.size()
	)
	return candidates[0] if not candidates.is_empty() else ""

static func _build_failure_hint(shop_level: int, device_id: String, material_ids: Array) -> String:
	var selected := _as_set(material_ids)
	for recipe_id in Catalog.RECIPES.keys():
		var recipe: Dictionary = Catalog.RECIPES[recipe_id]
		if int(recipe.unlock_level) <= shop_level and _sets_equal(selected, _as_set(recipe.materials)) and String(recipe.device) != device_id:
			return "这个组合也许不适合当前设备。"
	for recipe_id in Catalog.RECIPES.keys():
		var recipe: Dictionary = Catalog.RECIPES[recipe_id]
		if String(recipe.device) != device_id:
			continue
		var missing := []
		for material_id in recipe.materials:
			if not selected.has(material_id):
				missing.append(material_id)
		if missing.size() == 1:
			return "味道接近了，但还缺少某种%s。" % _material_type(String(missing[0]))
	for recipe_id in Catalog.RECIPES.keys():
		var recipe: Dictionary = Catalog.RECIPES[recipe_id]
		if String(recipe.device) == device_id and int(recipe.unlock_level) > shop_level:
			var required := _as_set(recipe.materials)
			var overlaps := 0
			for material_id in selected.keys():
				if required.has(material_id):
					overlaps += 1
			if overlaps >= 2:
				return "店铺经验还不足以稳定制作这种新品。"
	return "这次试做没有形成稳定商品。"

static func _has_material(state: GameState, material_id: String, amount: int) -> bool:
	if Catalog.INGREDIENTS.has(material_id):
		return state.has_ingredient(material_id, amount)
	return state.has_product(material_id, amount)

static func _consume_material(state: GameState, material_id: String, amount: int) -> bool:
	if Catalog.INGREDIENTS.has(material_id):
		return state.consume_ingredient(material_id, amount)
	return state.consume_product(material_id, amount)

static func _material_name(material_id: String) -> String:
	if Catalog.INGREDIENTS.has(material_id):
		return Catalog.INGREDIENTS[material_id].name
	return Catalog.RECIPES[material_id].name

static func _material_type(material_id: String) -> String:
	if Catalog.INGREDIENTS.has(material_id):
		return Catalog.INGREDIENTS[material_id].type
	return "成品"

static func _as_set(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		result[String(value)] = true
	return result

static func _sets_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key):
			return false
	return true
```

- [ ] **Step 4: Run test**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/recipe_book.gd tests/mvp_self_check.gd
git commit -m "feat: add recipe research and making"
```

## Task 5: Shop Simulation and Business Runs

**Files:**
- Create: `D:\Project\ProjectRest\project-rest\scripts\shop_simulation.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`

- [ ] **Step 1: Add failing shop simulation checks**

Add preload:

```gdscript
const ShopSimulation = preload("res://scripts/shop_simulation.gd")
```

Add and call:

```gdscript
func _run_shop_checks() -> void:
	var state := GameState.new()
	state.new_game()
	state.add_recipe("sponge_cake")
	state.add_product("sponge_cake", 6)
	_assert_true(state.set_display_slot(0, "sponge_cake"), "display slot should accept unlocked recipe")
	var before_coins := state.coins
	var result := ShopSimulation.run_business(state)
	_assert_true(result.sold_count > 0, "business run should sell at least one product")
	_assert_true(state.coins > before_coins, "business run should increase coins")
	_assert_true(state.reputation > 0, "business run should increase reputation")
	_assert_true(state.business_runs == 1, "business run count should advance")
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: FAIL because `shop_simulation.gd` is missing.

- [ ] **Step 3: Implement shop simulation**

Create `scripts/shop_simulation.gd`:

```gdscript
extends RefCounted
class_name ShopSimulation

const Catalog = preload("res://scripts/catalog.gd")
const GameState = preload("res://scripts/game_state.gd")
const ProductionSite = preload("res://scripts/production_site.gd")

static func run_business(state: GameState) -> Dictionary:
	var customers := _generate_customers(state.shop_level)
	var sold_count := 0
	var earned_coins := 0
	var earned_reputation := 0
	var feedback: Array[String] = []
	for customer_id in customers:
		var customer: Dictionary = Catalog.CUSTOMERS[customer_id]
		var choice := _choose_product(state, customer)
		if choice.recipe_id == "":
			feedback.append("%s没有找到合适的甜品。" % customer.name)
			continue
		var recipe: Dictionary = Catalog.RECIPES[choice.recipe_id]
		state.consume_product(choice.recipe_id, 1)
		state.coins += int(recipe.price)
		var rep_gain := 1 + int(choice.matches)
		if customer_id == "blogger" and recipe.tags.has("招牌"):
			rep_gain += 3
		state.reputation += rep_gain
		sold_count += 1
		earned_coins += int(recipe.price)
		earned_reputation += rep_gain
		feedback.append("%s买走了%s。" % [customer.name, recipe.name])
	state.business_runs += 1
	ProductionSite.advance_after_business(state)
	state.add_log("营业结束：售出 %d 件，获得 %d 金币，%d 口碑。" % [sold_count, earned_coins, earned_reputation])
	for line in feedback:
		state.add_log(line)
	return {
		"sold_count": sold_count,
		"earned_coins": earned_coins,
		"earned_reputation": earned_reputation,
		"feedback": feedback,
	}

static func _generate_customers(shop_level: int) -> Array[String]:
	var count := int(Catalog.UPGRADES[shop_level].customer_count)
	var pool: Array[String] = []
	for customer_id in Catalog.CUSTOMERS.keys():
		if int(Catalog.CUSTOMERS[customer_id].unlock_level) <= shop_level:
			pool.append(customer_id)
	var result: Array[String] = []
	for i in count:
		result.append(pool[i % pool.size()])
	if shop_level == 1:
		for i in min(3, result.size()):
			result[i] = "student"
	if shop_level >= 5 and not result.has("blogger"):
		result[0] = "blogger"
	return result

static func _choose_product(state: GameState, customer: Dictionary) -> Dictionary:
	var best := {"recipe_id": "", "score": 0, "matches": 0}
	for recipe_id in state.display_slots:
		if recipe_id == "" or not state.has_product(recipe_id, 1):
			continue
		var recipe: Dictionary = Catalog.RECIPES[recipe_id]
		var score_data := _score_product(recipe, customer)
		if int(score_data.score) > int(best.score):
			best = {"recipe_id": recipe_id, "score": int(score_data.score), "matches": int(score_data.matches)}
	return best if int(best.score) > 0 else {"recipe_id": "", "score": 0, "matches": 0}

static func _score_product(recipe: Dictionary, customer: Dictionary) -> Dictionary:
	var matches := 0
	for preference in customer.preferences:
		if recipe.tags.has(preference):
			matches += 1
	var score := matches * 10
	if customer.preferences.has("低价") and int(recipe.price) <= 20:
		score += 8
	if customer.preferences.has("招牌") and recipe.tags.has("招牌"):
		score += 12
	score -= max(0, int(recipe.price) - int(customer.budget))
	return {"score": score, "matches": matches}
```

- [ ] **Step 4: Run test**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/shop_simulation.gd tests/mvp_self_check.gd
git commit -m "feat: add shop business simulation"
```

## Task 6: Main Scene and UI Shell

**Files:**
- Create: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`
- Create: `D:\Project\ProjectRest\project-rest\scenes\Main.tscn`
- Modify: `D:\Project\ProjectRest\project-rest\project.godot`

- [ ] **Step 1: Create UI script**

Create `scripts/main_view.gd` with a code-built UI shell:

```gdscript
extends Control

const Catalog = preload("res://scripts/catalog.gd")
const GameState = preload("res://scripts/game_state.gd")
const SaveSystem = preload("res://scripts/save_system.gd")
const ProductionSite = preload("res://scripts/production_site.gd")
const RecipeBook = preload("res://scripts/recipe_book.gd")
const ShopSimulation = preload("res://scripts/shop_simulation.gd")

var state: GameState
var top_bar: Label
var content: VBoxContainer
var feedback: RichTextLabel
var status_bar: Label

func _ready() -> void:
	state = SaveSystem.load_game()
	_build_ui()
	_show_purchase()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	top_bar = Label.new()
	root.add_child(top_bar)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var nav := VBoxContainer.new()
	body.add_child(nav)
	for item in [
		["采购", _show_purchase],
		["产出", _show_sites],
		["研发", _show_research],
		["生产", _show_make],
		["橱窗", _show_display],
		["图鉴", _show_book],
		["升级", _show_upgrade],
	]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		nav.add_child(button)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	feedback = RichTextLabel.new()
	feedback.custom_minimum_size = Vector2(280, 0)
	body.add_child(feedback)
	status_bar = Label.new()
	root.add_child(status_bar)
	_refresh_common()

func _clear_content() -> void:
	for child in content.get_children():
		child.queue_free()

func _refresh_common() -> void:
	top_bar.text = "金币 %d | 口碑 %d | 等级 %d | 顾客 %d" % [state.coins, state.reputation, state.shop_level, Catalog.UPGRADES[state.shop_level].customer_count]
	feedback.text = "\n".join(state.feedback_log)

func _show_purchase() -> void:
	_clear_content()
	content.add_child(_label("采购"))
	for id in Catalog.INGREDIENTS.keys():
		var ingredient: Dictionary = Catalog.INGREDIENTS[id]
		if not Catalog.is_unlocked(ingredient, state.shop_level):
			continue
		var button := Button.new()
		button.text = "%s 价格%d 库存%d" % [ingredient.name, ingredient.price, state.ingredient_inventory.get(id, 0)]
		button.pressed.connect(func(): _buy_ingredient(id, 5))
		content.add_child(button)
	_refresh_common()

func _buy_ingredient(id: String, amount: int) -> void:
	var price := int(Catalog.INGREDIENTS[id].price) * amount
	if state.spend_coins(price):
		state.add_ingredient(id, amount)
		state.add_log("购买%s x%d。" % [Catalog.INGREDIENTS[id].name, amount])
		SaveSystem.save_game(state)
	status_bar.text = "采购完成"
	_show_purchase()

func _show_sites() -> void:
	_clear_content()
	content.add_child(_label("产出"))
	for site_id in Catalog.PRODUCTION_SITES.keys():
		var site: Dictionary = Catalog.PRODUCTION_SITES[site_id]
		content.add_child(_label(site.name))
		for item_id in Catalog.INGREDIENTS.keys():
			var start := Button.new()
			start.text = "安排%s" % Catalog.INGREDIENTS[item_id].name
			start.pressed.connect(func(): _start_site(site_id, item_id))
			content.add_child(start)
	for i in state.production_slots.size():
		var harvest := Button.new()
		var slot: Dictionary = state.production_slots[i]
		harvest.text = "收获槽位%d：%s 剩余%d轮" % [i + 1, Catalog.INGREDIENTS[slot.item_id].name, int(slot.turns_remaining)]
		harvest.pressed.connect(func(): _harvest_slot(i))
		content.add_child(harvest)
	_refresh_common()

func _start_site(site_id: String, item_id: String) -> void:
	status_bar.text = ProductionSite.start_slot(state, site_id, item_id).message
	SaveSystem.save_game(state)
	_show_sites()

func _harvest_slot(index: int) -> void:
	status_bar.text = ProductionSite.harvest_slot(state, index).message
	SaveSystem.save_game(state)
	_show_sites()

func _show_research() -> void:
	_clear_content()
	content.add_child(_label("研发先使用自检覆盖核心逻辑；UI 版本在后续任务补充选择器。"))
	_refresh_common()

func _show_make() -> void:
	_clear_content()
	content.add_child(_label("生产"))
	for recipe_id in state.unlocked_recipes:
		var button := Button.new()
		button.text = "制作%s" % Catalog.RECIPES[recipe_id].name
		button.pressed.connect(func(): _make_recipe(recipe_id))
		content.add_child(button)
	_refresh_common()

func _make_recipe(recipe_id: String) -> void:
	status_bar.text = RecipeBook.make_product(state, recipe_id, 1).message
	SaveSystem.save_game(state)
	_show_make()

func _show_display() -> void:
	_clear_content()
	content.add_child(_label("橱窗"))
	var run := Button.new()
	run.text = "开始营业"
	run.pressed.connect(func(): _run_business())
	content.add_child(run)
	for i in state.display_slots.size():
		content.add_child(_label("槽位%d：%s" % [i + 1, state.display_slots[i]]))
	_refresh_common()

func _run_business() -> void:
	ShopSimulation.run_business(state)
	SaveSystem.save_game(state)
	_show_display()

func _show_book() -> void:
	_clear_content()
	content.add_child(_label("图鉴"))
	for recipe_id in Catalog.RECIPES.keys():
		var prefix := "已解锁" if state.is_recipe_unlocked(recipe_id) else "未解锁"
		content.add_child(_label("%s：%s" % [prefix, Catalog.RECIPES[recipe_id].name]))
	_refresh_common()

func _show_upgrade() -> void:
	_clear_content()
	content.add_child(_label("升级"))
	var button := Button.new()
	button.text = "升级店铺"
	button.disabled = not state.can_upgrade()
	button.pressed.connect(func(): _upgrade())
	content.add_child(button)
	_refresh_common()

func _upgrade() -> void:
	state.upgrade()
	SaveSystem.save_game(state)
	_show_upgrade()

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
```

- [ ] **Step 2: Create scene**

Create `scenes/Main.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main_view.gd" id="1"]

[node name="MainView" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
```

- [ ] **Step 3: Set main scene**

Modify `project.godot` under `[application]`:

```ini
config/name="project-rest"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.6", "Mobile")
config/icon="res://icon.svg"
```

- [ ] **Step 4: Run project parse check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --quit
```

Expected: exits with code 0 and no script parse errors.

- [ ] **Step 5: Run self-check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add scripts/main_view.gd scenes/Main.tscn project.godot
git commit -m "feat: add main dessert shop UI shell"
```

## Task 7: Complete End-to-End Self-Check

**Files:**
- Modify: `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`

- [ ] **Step 1: Add full MVP flow check**

Add and call this function:

```gdscript
func _run_full_mvp_flow() -> void:
	var state := GameState.new()
	state.new_game()
	for item in ["flour", "egg", "sugar", "butter", "strawberry", "milk"]:
		state.add_ingredient(item, 20)
	var research := RecipeBook.research(state, "oven", ["flour", "egg", "sugar"])
	_assert_true(research.success, "full flow should research sponge cake")
	var made := RecipeBook.make_product(state, "sponge_cake", 1)
	_assert_true(made.success, "full flow should make sponge cake")
	_assert_true(state.set_display_slot(0, "sponge_cake"), "full flow should place display item")
	var business := ShopSimulation.run_business(state)
	_assert_true(business.sold_count > 0, "full flow should sell product")
	state.coins = 200
	state.reputation = 10
	_assert_true(state.upgrade(), "full flow should upgrade to level 2")
	state.shop_level = 3
	var pond := ProductionSite.start_slot(state, "pond", "sea_salt")
	_assert_true(pond.success, "full flow should start pond")
	for i in 3:
		ProductionSite.advance_after_business(state)
	var harvest := ProductionSite.harvest_slot(state, 0)
	_assert_true(harvest.success, "full flow should harvest pond")
```

- [ ] **Step 2: Run self-check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: PASS with `MVP_SELF_CHECK_PASS`.

- [ ] **Step 3: Commit**

```powershell
git add tests/mvp_self_check.gd
git commit -m "test: add full mvp flow self check"
```

## Task 8: UI Completion Pass

**Files:**
- Modify: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`

- [ ] **Step 1: Replace research placeholder with selectors**

Modify `_show_research()` to provide one-click MVP recipe buttons. Use exact known combinations for prototype usability:

```gdscript
func _show_research() -> void:
	_clear_content()
	content.add_child(_label("研发"))
	for recipe_id in Catalog.RECIPES.keys():
		var recipe: Dictionary = Catalog.RECIPES[recipe_id]
		if int(recipe.unlock_level) > state.shop_level or state.is_recipe_unlocked(recipe_id):
			continue
		var button := Button.new()
		button.text = "试做%s：%s" % [recipe.name, ", ".join(recipe.materials)]
		button.pressed.connect(func(): _research_recipe(recipe_id))
		content.add_child(button)
	_refresh_common()

func _research_recipe(recipe_id: String) -> void:
	var recipe: Dictionary = Catalog.RECIPES[recipe_id]
	status_bar.text = RecipeBook.research(state, recipe.device, recipe.materials).message
	SaveSystem.save_game(state)
	_show_research()
```

- [ ] **Step 2: Add display slot assignment buttons**

Modify `_show_display()` to list unlocked recipes per slot:

```gdscript
func _show_display() -> void:
	_clear_content()
	content.add_child(_label("橱窗"))
	for i in state.display_slots.size():
		content.add_child(_label("槽位%d：%s" % [i + 1, state.display_slots[i]]))
		for recipe_id in state.unlocked_recipes:
			var button := Button.new()
			button.text = "槽位%d 上架 %s 库存%d" % [i + 1, Catalog.RECIPES[recipe_id].name, state.product_inventory.get(recipe_id, 0)]
			button.pressed.connect(func(): _set_display(i, recipe_id))
			content.add_child(button)
	var run := Button.new()
	run.text = "开始营业"
	run.pressed.connect(func(): _run_business())
	content.add_child(run)
	_refresh_common()

func _set_display(index: int, recipe_id: String) -> void:
	state.set_display_slot(index, recipe_id)
	SaveSystem.save_game(state)
	_show_display()
```

- [ ] **Step 3: Run parse and self-check**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --quit
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: both commands exit 0; self-check prints `MVP_SELF_CHECK_PASS`.

- [ ] **Step 4: Commit**

```powershell
git add scripts/main_view.gd
git commit -m "feat: complete mvp ui interactions"
```

## Task 9: Final Verification and Documentation Sync

**Files:**
- Modify if needed: `D:\Project\ProjectRest\project-rest\doc\v3.md`
- Modify if needed: `D:\Project\ProjectRest\project-rest\docs\superpowers\plans\2026-07-03-neighbor-dessert-mvp.md`

- [ ] **Step 1: Run final automated checks**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --quit
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

Expected: both commands exit 0; self-check prints `MVP_SELF_CHECK_PASS`.

- [ ] **Step 2: Inspect git status**

Run:

```powershell
git status --short
```

Expected: only intentional files are modified or untracked.

- [ ] **Step 3: Verify spec coverage manually**

Check these requirements against the implementation:

- Purchase can add unlocked ingredients.
- Farm, ranch, and pond can each complete one production loop.
- Correct research unlocks at least `sponge_cake`.
- Product making consumes materials and adds products.
- Display slot can hold an unlocked product.
- Business run sells product, adds coins and reputation, and advances production slots.
- Upgrade to level 2 changes display slot count to 4.
- Save/load preserves inventory, products, production slots, display slots, unlocked recipes, logs, and business run count.

- [ ] **Step 4: Commit final verification updates**

If documentation or tests changed:

```powershell
git add doc/v3.md docs/superpowers/plans/2026-07-03-neighbor-dessert-mvp.md tests/mvp_self_check.gd
git commit -m "docs: align mvp implementation plan"
```

If no files changed, do not create an empty commit.

## Self-Review Notes

Spec coverage:

- `doc/v3.md` sections 3-8 are covered by Tasks 1-3.
- Recipe research and production are covered by Task 4.
- Display, business, customers, reputation, and business-run progression are covered by Task 5.
- Main UI and tabs are covered by Tasks 6 and 8.
- Save/load is covered by Task 2 and Task 7.
- Automated verification is covered by Tasks 1, 7, and 9.

Known scope choices:

- The first UI pass uses code-created controls instead of hand-authored complex scenes. This keeps the MVP small and testable.
- The research UI exposes known recipe attempts as one-click buttons. This is acceptable for MVP implementation because the rule layer still supports arbitrary `device + materials`; a freeform selector can replace the convenience buttons later.
- Fishpond produces `sea_salt` but the 18 MVP recipes do not require it. This matches `doc/v3.md`: pond exists as a production structure and expansion hook.
