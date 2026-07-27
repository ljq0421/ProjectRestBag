extends SceneTree

const CATALOG_PATH := "res://scripts/catalog.gd"
const RECIPE_FIXTURE_PATH := "res://tests/fixtures/existing_recipe_contract_v1.json"

const DEVICE_LEVELS := {
	"grinder": 1,
	"oven": 2,
	"chiller": 3,
	"griddle": 4,
	"mixer": 5
}
const GROWING_DEVICE_IDS := ["round_pot", "oven", "chiller", "griddle", "mixer"]
const CORE_INGREDIENTS_BY_LEVEL := {
	0: ["rice", "spring_water", "sugar"],
	1: ["wheat", "rice_flour", "flour", "egg", "chicken", "butter"],
	2: ["banana", "strawberry", "blueberry", "milk", "beef", "chocolate", "vanilla", "caramel", "cream", "cheese"],
	3: ["gelatin", "peach", "apple", "lemon", "orange", "mango", "honey", "sea_salt", "red_bean", "black_sesame"],
	4: ["pumpkin", "glutinous_rice", "glutinous_rice_flour", "coffee", "cocoa", "yogurt", "mint", "yeast", "duck_egg", "duck_meat"],
	5: ["chestnut", "oats", "nuts", "cinnamon", "matcha", "almond", "black_tea", "green_tea", "goat_milk", "mutton"]
}
const RECIPE_COUNTS_BY_LEVEL := {0: 1, 1: 8, 2: 17, 3: 23, 4: 35, 5: 44}
const RANCH_INPUTS := {
	"chick": {"level": 1, "outputs": ["egg", "chicken"]},
	"calf": {"level": 2, "outputs": ["milk", "beef"]},
	"bee_colony": {"level": 3, "outputs": ["honey"]},
	"duckling": {"level": 4, "outputs": ["duck_egg", "duck_meat"]},
	"lamb": {"level": 5, "outputs": ["goat_milk", "mutton"]}
}
const PROCESSING_LEVELS := {
	"rice_flour_process": 1,
	"wheat_flour_process": 1,
	"glutinous_rice_flour_process": 4,
	"cocoa_process": 4,
	"yogurt_process": 4,
	"matcha_process": 5
}
const NEW_RECIPES := {
	"egg_rice_flour_custard": {"level": 1, "name": "蛋香米粉羹", "device": "round_pot", "materials": ["rice_flour", "egg", "spring_water", "sugar"]},
	"butter_chicken_steamed_cake": {"level": 1, "name": "黄油鸡肉蒸糕", "device": "round_pot", "materials": ["flour", "chicken", "butter"]},
	"chicken_wheat_porridge": {"level": 1, "name": "鸡肉麦仁粥", "device": "round_pot", "materials": ["wheat", "chicken", "spring_water"]},
	"honey_peach_jelly": {"level": 3, "name": "蜂蜜桃子冻", "device": "chiller", "materials": ["honey", "peach", "gelatin"]},
	"honey_redbean_steamed_cake": {"level": 3, "name": "蜂蜜红豆蒸糕", "device": "round_pot", "materials": ["honey", "red_bean", "rice_flour"]},
	"duck_egg_pumpkin_pudding": {"level": 4, "name": "鸭蛋南瓜布丁", "device": "chiller", "materials": ["duck_egg", "pumpkin", "milk", "sugar"]},
	"coffee_duck_egg_cake": {"level": 4, "name": "咖啡鸭蛋糕", "device": "oven", "materials": ["duck_egg", "coffee", "flour", "sugar"]},
	"duck_egg_banana_griddle_cake": {"level": 4, "name": "鸭蛋香蕉煎糕", "device": "griddle", "materials": ["duck_egg", "banana", "flour", "milk"]},
	"cheese_duck_baked_rice": {"level": 4, "name": "芝士鸭肉焗饭", "device": "oven", "materials": ["duck_meat", "rice", "cheese", "butter"]},
	"sea_salt_duck_rice_cup": {"level": 4, "name": "海盐鸭肉米盏", "device": "round_pot", "materials": ["duck_meat", "rice_flour", "sea_salt"]},
	"pumpkin_duck_pancake": {"level": 4, "name": "南瓜鸭肉煎饼", "device": "griddle", "materials": ["duck_meat", "pumpkin", "flour"]},
	"goat_milk_black_tea_jelly": {"level": 5, "name": "羊奶红茶冻", "device": "chiller", "materials": ["goat_milk", "black_tea", "gelatin", "sugar"]},
	"matcha_goat_milk_mousse": {"level": 5, "name": "抹茶羊奶慕斯", "device": "mixer", "materials": ["goat_milk", "matcha", "cream", "gelatin"]},
	"goat_milk_oats_porridge": {"level": 5, "name": "羊奶燕麦粥", "device": "round_pot", "materials": ["goat_milk", "oats", "sugar"]},
	"chestnut_mutton_baked_rice": {"level": 5, "name": "栗子羊肉焗饭", "device": "oven", "materials": ["mutton", "rice", "chestnut", "butter"]},
	"black_tea_mutton_pastry": {"level": 5, "name": "红茶羊肉酥饼", "device": "oven", "materials": ["mutton", "black_tea", "flour", "butter"]},
	"mutton_glutinous_shumai": {"level": 5, "name": "羊肉糯米烧卖", "device": "round_pot", "materials": ["mutton", "glutinous_rice_flour", "sea_salt"]}
}

var _failures: Array[String] = []


func _init() -> void:
	_run()
	_finish()


func _run() -> void:
	var catalog_script := load(CATALOG_PATH)
	_expect(catalog_script != null, "Catalog script should load")
	if catalog_script == null:
		return
	var catalog = catalog_script.new()
	var ingredients: Dictionary = catalog.get_ingredients()
	var devices: Dictionary = catalog.get_devices()
	var recipes: Dictionary = catalog.get_recipes()
	var processing_recipes: Dictionary = catalog.get_processing_recipes()
	var production_sites: Dictionary = catalog.get_production_sites()

	_expect_device_route(devices)
	_expect_core_ingredients(ingredients)
	_expect_ranch_route(ingredients, production_sites)
	_expect_processing_route(processing_recipes)
	_expect_recipe_progression(recipes, ingredients, devices)
	_expect_new_recipes(recipes)
	_expect_existing_recipe_contract(recipes)


func _expect_device_route(devices: Dictionary) -> void:
	_expect(devices.has("round_pot"), "round_pot should remain in the device catalog")
	if devices.has("round_pot"):
		_expect(int(devices.round_pot.get("unlock_level", 0)) > 5, "round_pot should remain a Lv.0 tutorial unlock, not an automatic level unlock")
	for device_id: String in DEVICE_LEVELS:
		_expect(devices.has(device_id), "device catalog should contain %s" % device_id)
		if devices.has(device_id):
			_expect(int(devices[device_id].get("unlock_level", -1)) == int(DEVICE_LEVELS[device_id]), "%s should unlock at Lv.%d" % [device_id, int(DEVICE_LEVELS[device_id])])
	var growth_enabled_count := 0
	for device_id_value in devices:
		var device_id := String(device_id_value)
		if bool(devices[device_id].get("recipe_growth_enabled", false)):
			growth_enabled_count += 1
	for device_id in GROWING_DEVICE_IDS:
		_expect(bool(devices.get(device_id, {}).get("recipe_growth_enabled", false)), "%s should explicitly enable recipe device growth" % device_id)
	_expect(not bool(devices.get("grinder", {}).get("recipe_growth_enabled", true)), "grinder should explicitly opt out of recipe device growth")
	_expect(growth_enabled_count == 5, "exactly five product devices should enable recipe device growth")


func _expect_core_ingredients(ingredients: Dictionary) -> void:
	for level: int in CORE_INGREDIENTS_BY_LEVEL:
		var expected_ids: Array = CORE_INGREDIENTS_BY_LEVEL[level]
		_expect(expected_ids.size() == int([3, 6, 10, 10, 10, 10][level]), "core ingredient fixture count should match Lv.%d design" % level)
		for item_id_value: Variant in expected_ids:
			var item_id := String(item_id_value)
			_expect(ingredients.has(item_id), "ingredient catalog should contain %s" % item_id)
			if ingredients.has(item_id):
				_expect(int(ingredients[item_id].get("unlock_level", -1)) == level, "%s should unlock at Lv.%d" % [item_id, level])


func _expect_ranch_route(ingredients: Dictionary, production_sites: Dictionary) -> void:
	var ranch_items: Array = production_sites.get("ranch", {}).get("items", [])
	for input_id: String in RANCH_INPUTS:
		var expected: Dictionary = RANCH_INPUTS[input_id]
		_expect(ingredients.has(input_id), "ranch input %s should exist" % input_id)
		_expect(ranch_items.has(input_id), "ranch production site should offer %s" % input_id)
		if not ingredients.has(input_id):
			continue
		var input: Dictionary = ingredients[input_id]
		_expect(int(input.get("unlock_level", -1)) == int(expected.level), "%s should unlock at Lv.%d" % [input_id, int(expected.level)])
		var outputs: Dictionary = input.get("harvest_outputs", {})
		for output_id_value: Variant in expected.outputs:
			var output_id := String(output_id_value)
			_expect(outputs.has(output_id), "%s should produce %s" % [input_id, output_id])
			_expect(ingredients.has(output_id), "ranch output %s should exist" % output_id)
			if ingredients.has(output_id):
				_expect(String(ingredients[output_id].get("source", "")) == "养殖场", "%s source should be ranch" % output_id)
				_expect(not bool(ingredients[output_id].get("purchasable", true)), "%s should not be directly purchasable" % output_id)
	for site_id in ["farm", "forest"]:
		_expect(not production_sites.get(site_id, {}).get("items", []).has("honey"), "%s should no longer produce honey" % site_id)


func _expect_processing_route(processing_recipes: Dictionary) -> void:
	for recipe_id: String in PROCESSING_LEVELS:
		_expect(processing_recipes.has(recipe_id), "processing catalog should contain %s" % recipe_id)
		if processing_recipes.has(recipe_id):
			_expect(int(processing_recipes[recipe_id].get("unlock_level", -1)) == int(PROCESSING_LEVELS[recipe_id]), "%s should unlock at Lv.%d" % [recipe_id, int(PROCESSING_LEVELS[recipe_id])])


func _expect_recipe_progression(recipes: Dictionary, ingredients: Dictionary, devices: Dictionary) -> void:
	_expect(recipes.size() == 166, "selling recipe catalog should contain 166 recipes")
	var actual_counts := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	var reserve_count := 0
	for recipe_id_value: Variant in recipes:
		var recipe_id := String(recipe_id_value)
		var recipe: Dictionary = recipes[recipe_id]
		var level := int(recipe.get("unlock_level", -1))
		if actual_counts.has(level):
			actual_counts[level] += 1
		elif level >= 6:
			reserve_count += 1
		else:
			_expect(false, "%s should have a non-negative unlock level" % recipe_id)

		var device_id := String(recipe.get("device", ""))
		_expect(devices.has(device_id), "%s should reference a known device %s" % [recipe_id, device_id])
		if devices.has(device_id):
			var device_level := 0 if device_id == "round_pot" else int(devices[device_id].get("unlock_level", 999))
			_expect(level >= device_level, "%s should not unlock before device %s" % [recipe_id, device_id])
		for material_id_value: Variant in recipe.get("materials", []):
			var material_id := String(material_id_value)
			_expect(ingredients.has(material_id) or recipes.has(material_id), "%s should reference known material or component recipe %s" % [recipe_id, material_id])
			if ingredients.has(material_id):
				_expect(level >= int(ingredients[material_id].get("unlock_level", 999)), "%s should not unlock before material %s" % [recipe_id, material_id])
			elif recipes.has(material_id):
				_expect(level >= int(recipes[material_id].get("unlock_level", 999)), "%s should not unlock before component recipe %s" % [recipe_id, material_id])

	for level: int in RECIPE_COUNTS_BY_LEVEL:
		_expect(int(actual_counts[level]) == int(RECIPE_COUNTS_BY_LEVEL[level]), "Lv.%d should unlock exactly %d selling recipes" % [level, int(RECIPE_COUNTS_BY_LEVEL[level])])
	_expect(actual_counts.values().reduce(func(total, count): return int(total) + int(count), 0) == 128, "Lv.0–Lv.5 should contain 128 selling recipes")
	_expect(reserve_count == 38, "Lv.6+ reserve pool should contain 38 selling recipes")


func _expect_new_recipes(recipes: Dictionary) -> void:
	for recipe_id: String in NEW_RECIPES:
		var expected: Dictionary = NEW_RECIPES[recipe_id]
		_expect(recipes.has(recipe_id), "new recipe %s should exist" % recipe_id)
		if not recipes.has(recipe_id):
			continue
		var recipe: Dictionary = recipes[recipe_id]
		_expect(int(recipe.get("unlock_level", -1)) == int(expected.level), "%s should unlock at Lv.%d" % [recipe_id, int(expected.level)])
		_expect(String(recipe.get("name", "")) == String(expected.name), "%s should keep its approved name" % recipe_id)
		_expect(String(recipe.get("device", "")) == String(expected.device), "%s should use its approved device" % recipe_id)
		_expect(recipe.get("materials", []) == expected.materials, "%s should use its approved materials in order" % recipe_id)


func _expect_existing_recipe_contract(recipes: Dictionary) -> void:
	var fixture := _load_json_dictionary(RECIPE_FIXTURE_PATH)
	_expect(not fixture.is_empty(), "existing recipe contract fixture should load")
	if fixture.is_empty():
		return
	var frozen_recipes: Dictionary = fixture.get("recipes", {})
	var fields: Array = fixture.get("meta", {}).get("immutable_fields", [])
	_expect(int(fixture.get("meta", {}).get("recipe_count", 0)) == 149, "fixture should freeze exactly 149 pre-existing recipes")
	_expect(frozen_recipes.size() == 149, "fixture recipe dictionary should contain 149 entries")
	for recipe_id_value: Variant in frozen_recipes:
		var recipe_id := String(recipe_id_value)
		_expect(recipes.has(recipe_id), "pre-existing recipe %s should not be removed" % recipe_id)
		if not recipes.has(recipe_id):
			continue
		for field_value: Variant in fields:
			var field := String(field_value)
			_expect(recipes[recipe_id].get(field) == frozen_recipes[recipe_id].get(field), "%s immutable field %s should not change" % [recipe_id, field])


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PROGRESSION_CATALOG_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
