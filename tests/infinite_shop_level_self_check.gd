extends SceneTree

const CATALOG_PATH := "res://scripts/catalog.gd"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const GAME_DATA_PATH := "res://game_data.json"

const UPGRADE_ANCHORS := {
	2: {"rounds": 5.0, "cost": 900, "reputation": 30},
	3: {"rounds": 6.0, "cost": 2200, "reputation": 80},
	4: {"rounds": 7.0, "cost": 4500, "reputation": 170},
	5: {"rounds": 8.0, "cost": 8000, "reputation": 300},
	6: {"rounds": 9.0, "cost": 13000, "reputation": 500},
	7: {"rounds": 10.0, "cost": 15000, "reputation": 720},
	8: {"rounds": 10.0, "cost": 17500, "reputation": 960},
	9: {"rounds": 10.0, "cost": 20000, "reputation": 1220},
	10: {"rounds": 10.0, "cost": 23000, "reputation": 1500},
	11: {"rounds": 10.0, "cost": 26000, "reputation": 1800},
	12: {"rounds": 11.0, "cost": 33000, "reputation": 2150}
}

var _failures: Array[String] = []


func _init() -> void:
	_run()
	_finish()


func _run() -> void:
	var catalog_script := load(CATALOG_PATH)
	var game_state_script := load(GAME_STATE_PATH)
	_expect(catalog_script != null, "Catalog script should load")
	_expect(game_state_script != null, "GameState script should load")
	if catalog_script == null or game_state_script == null:
		return

	var catalog = catalog_script.new()
	_expect(catalog.has_method("get_upgrade_definition"), "Catalog should expose get_upgrade_definition(target_level)")
	_expect(catalog.has_method("get_next_level_milestone"), "Catalog should expose get_next_level_milestone(current_level)")
	if catalog.has_method("get_upgrade_definition"):
		_expect_upgrade_anchors(catalog)
		_expect_long_term_monotonicity(catalog)
		_expect_numeric_boundary(catalog, game_state_script)
	_expect_game_data_matches_upgrade_anchors()

	var level_zero = game_state_script.new_game()
	level_zero.coins = 999999
	level_zero.reputation = 999999
	_expect(not level_zero.can_upgrade(), "Lv.0 should not bypass the first-listing tutorial with manual upgrade")

	var level_one = game_state_script.new_game()
	level_one.level = 1
	level_one.coins = 900
	level_one.reputation = 30
	_expect(level_one.has_method("upgrade_eligibility"), "GameState should expose upgrade_eligibility()")
	if level_one.has_method("upgrade_eligibility"):
		var eligibility: Dictionary = level_one.call("upgrade_eligibility")
		_expect(bool(eligibility.get("ok", false)), "Lv.1 with 900 coins and 30 reputation should be eligible for Lv.2")
		_expect(int(eligibility.get("target_level", -1)) == 2, "eligibility should describe only the next level")
		_expect(int(eligibility.get("missing_coins", -1)) == 0, "eligible upgrade should have no missing coins")
		_expect(int(eligibility.get("missing_reputation", -1)) == 0, "eligible upgrade should have no missing reputation")
	var reputation_before := int(level_one.reputation)
	_expect(level_one.upgrade(), "Lv.1 should upgrade with exact Lv.2 resources")
	_expect(int(level_one.level) == 2, "one upgrade call should increase the level by exactly one")
	_expect(int(level_one.coins) == 0, "Lv.2 upgrade should deduct exactly 900 coins")
	_expect(int(level_one.reputation) == reputation_before, "upgrade should never deduct cumulative reputation")

	var level_five = game_state_script.new_game()
	level_five.level = 5
	level_five.coins = 999999
	level_five.reputation = 999999
	_expect(level_five.upgrade(), "Lv.5 should be able to continue to Lv.6")
	_expect(int(level_five.level) == 6, "Lv.5 upgrade should stop at Lv.6 even with abundant resources")
	_expect(int(level_five.coins) == 999999 - 13000, "Lv.6 upgrade should deduct the explicit rebalance cost")
	_expect(int(level_five.reputation) == 999999, "Lv.6 upgrade should preserve reputation")

	var high_level = game_state_script.new_game()
	high_level.level = 100
	var restored = game_state_script.from_dict(high_level.to_dict())
	_expect(int(restored.level) == 100, "Lv.100 should survive to_dict/from_dict without finite-table clamping")


func _expect_upgrade_anchors(catalog) -> void:
	for target_level: int in UPGRADE_ANCHORS:
		var expected: Dictionary = UPGRADE_ANCHORS[target_level]
		var definition: Dictionary = catalog.call("get_upgrade_definition", target_level)
		_expect(not definition.is_empty(), "Lv.%d upgrade definition should exist" % target_level)
		_expect(int(definition.get("level", -1)) == target_level, "Lv.%d definition should report its target level" % target_level)
		_expect(int(definition.get("cost", -1)) == int(expected.cost), "Lv.%d cost should be %d" % [target_level, int(expected.cost)])
		_expect(
			int(definition.get("required_reputation", -1)) == int(expected.reputation),
			"Lv.%d cumulative reputation should be %d" % [target_level, int(expected.reputation)]
		)
		_expect(
			is_equal_approx(float(definition.get("target_business_days", -1.0)), float(expected.rounds)),
			"Lv.%d target business rounds should be %.1f" % [target_level, float(expected.rounds)]
		)


func _expect_long_term_monotonicity(catalog) -> void:
	var previous_cost := 13000
	var previous_reputation := 500
	var previous_rounds := 9.0
	for target_level in range(7, 101):
		var definition: Dictionary = catalog.call("get_upgrade_definition", target_level)
		var cost := int(definition.get("cost", -1))
		var required_reputation := int(definition.get("required_reputation", -1))
		var target_rounds := float(definition.get("target_business_days", -1.0))
		_expect(cost > previous_cost, "upgrade cost should increase at Lv.%d" % target_level)
		_expect(required_reputation > previous_reputation, "cumulative reputation should increase at Lv.%d" % target_level)
		_expect(target_rounds >= previous_rounds, "Lv.%d target rounds should never decrease" % target_level)
		_expect(target_rounds >= 10.0 and target_rounds <= 16.0, "Lv.%d target rounds should stay within 10–16" % target_level)
		previous_cost = cost
		previous_reputation = required_reputation
		previous_rounds = target_rounds
	_expect(is_equal_approx(float(catalog.call("get_upgrade_definition", 37).get("target_business_days", 0.0)), 16.0), "Lv.37 target rounds should reach the 16-round cap")
	_expect(is_equal_approx(float(catalog.call("get_upgrade_definition", 100).get("target_business_days", 0.0)), 16.0), "Late levels should preserve the 16-round cap")


func _expect_numeric_boundary(catalog, game_state_script) -> void:
	var highest_definition: Dictionary = catalog.call("get_upgrade_definition", 247)
	_expect(not highest_definition.is_empty(), "Lv.247 should remain a valid upgrade target")
	_expect(int(highest_definition.get("cost", 0)) > 0, "Lv.247 cost should stay positive within int64")
	_expect(catalog.call("get_upgrade_definition", 248).is_empty(), "Lv.248 should stop before the exponential cost exceeds int64")

	var capped_state = game_state_script.new_game()
	capped_state.level = 247
	capped_state.coins = 123
	capped_state.reputation = 456
	var before := [int(capped_state.level), int(capped_state.coins), int(capped_state.reputation)]
	var eligibility: Dictionary = capped_state.upgrade_eligibility()
	_expect(String(eligibility.get("reason", "")) == "definition_missing", "Lv.247 should report the explicit progression boundary")
	_expect(not bool(eligibility.get("ok", true)), "Lv.247 must not become eligible for an unrepresentable cost")
	_expect(not capped_state.upgrade(), "Lv.247 upgrade should fail safely instead of overflowing currency")
	_expect([int(capped_state.level), int(capped_state.coins), int(capped_state.reputation)] == before, "Boundary upgrade failure should preserve level and resources")


func _expect_game_data_matches_upgrade_anchors() -> void:
	var game_data_file := FileAccess.open(GAME_DATA_PATH, FileAccess.READ)
	_expect(game_data_file != null, "game_data.json should be readable")
	if game_data_file == null:
		return
	var parsed: Variant = JSON.parse_string(game_data_file.get_as_text())
	_expect(parsed is Dictionary, "game_data.json should parse as a dictionary")
	if not parsed is Dictionary:
		return
	var game_data := parsed as Dictionary
	var progression: Dictionary = game_data.get("level_progression", {})
	var fixed_requirements: Dictionary = progression.get("base_upgrade_requirements", {})
	for target_level in range(2, 7):
		var expected: Dictionary = UPGRADE_ANCHORS[target_level]
		var requirement: Dictionary = fixed_requirements.get(str(target_level), {})
		_expect(int(requirement.get("cost", -1)) == int(expected.cost), "game_data Lv.%d cost should match Catalog" % target_level)
		_expect(int(requirement.get("required_reputation", -1)) == int(expected.reputation), "game_data Lv.%d reputation should match Catalog" % target_level)
		_expect(is_equal_approx(float(requirement.get("target_business_rounds", -1.0)), float(expected.rounds)), "game_data Lv.%d target rounds should match Catalog" % target_level)

	var formula: Dictionary = progression.get("infinite_formula", {})
	_expect(int(formula.get("starts_at_level", -1)) == 7, "game_data infinite formula should start at Lv.7")
	_expect(int(formula.get("max_supported_level", -1)) == 247, "game_data should document the int64-safe progression boundary")
	_expect(String(formula.get("target_business_rounds", "")).contains("min(16"), "game_data should document the 16-round cap")

	var routes_by_level := {}
	for route_value: Variant in game_data.get("unlock_route", []):
		if route_value is Dictionary:
			var route := route_value as Dictionary
			routes_by_level[int(route.get("level", -1))] = route
	for current_level in range(1, 6):
		var target_level := current_level + 1
		var expected: Dictionary = UPGRADE_ANCHORS[target_level]
		var route: Dictionary = routes_by_level.get(current_level, {})
		var condition_text := "｜".join(PackedStringArray(route.get("upgrade_condition", [])))
		_expect(condition_text.contains("升级资金 %d 金币" % int(expected.cost)), "Lv.%d route should show the rebalance cost" % current_level)
		_expect(condition_text.contains("累计口碑 %d" % int(expected.reputation)), "Lv.%d route should show the rebalance reputation" % current_level)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("INFINITE_SHOP_LEVEL_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
