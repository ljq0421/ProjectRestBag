extends SceneTree

const CATALOG_PATH := "res://scripts/catalog.gd"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const CHALLENGE_SERVICE_PATH := "res://scripts/showcase_challenge_service.gd"
const ROUND_RULES_PATH := "res://doc/showcase_round_rules.json"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var catalog_script := load(CATALOG_PATH)
	if catalog_script == null:
		_fail("Catalog script should load")
		_finish()
		return
	var catalog = catalog_script.new()
	if not catalog.has_method("get_showcase_round_rules"):
		_fail("Catalog should expose get_showcase_round_rules")
		_finish()
		return
	if not FileAccess.file_exists(ROUND_RULES_PATH):
		_fail("showcase round rules should exist")
		_finish()
		return

	var rules: Dictionary = catalog.get_showcase_round_rules()
	_expect_equal("standard duration", int(rules.get("standard_duration_seconds", 0)), 30)
	_expect_equal("grid rows", int(rules.get("grid_rows", 0)), 12)
	_expect_equal("grid columns", int(rules.get("grid_columns", 0)), 14)
	_expect_equal("heat maximum", int(rules.get("heat_max", 0)), 100)
	_expect_equal("chain depth maximum", int(rules.get("chain_max_depth", 0)), 4)

	var tiers: Dictionary = rules.get("sale_tiers", {})
	_expect_tier(tiers, "fast", 4, 7)
	_expect_tier(tiers, "medium", 8, 12)
	_expect_tier(tiers, "slow", 15, 25)

	var shape_templates: Dictionary = rules.get("shape_templates", {})
	for shape_name in ["迷你款", "竖杯款", "横盘款", "中块款", "招牌款"]:
		var template: Dictionary = shape_templates.get(shape_name, {})
		if template.is_empty():
			_fail("shape template should exist: %s" % shape_name)
			continue
		var duration := int(template.get("base_sale_seconds", 0))
		if duration < 4 or duration > 25:
			_fail("shape template duration should be 4-25 seconds: %s=%d" % [shape_name, duration])
		var role := String(template.get("role", ""))
		if not ["lure", "advance", "amplify", "harvest"].has(role):
			_fail("shape template should use a supported role: %s=%s" % [shape_name, role])

	var environment_limits: Dictionary = rules.get("environment_limits", {})
	_expect_equal("environment positive cap", int(environment_limits.get("positive_pct", 0)), 25)
	_expect_equal("environment negative cap", int(environment_limits.get("negative_pct", 0)), -10)

	var display_rules: Dictionary = catalog.get_display_rules()
	var meta: Dictionary = display_rules.get("meta", {})
	_expect_equal("display rules grid rows", int(meta.get("grid_rows", 0)), 12)
	_expect_equal("display rules grid columns", int(meta.get("grid_columns", 0)), 14)
	_expect_equal("display rules grid cells", int(meta.get("grid_cells", 0)), 168)
	var description := String(meta.get("description", ""))
	if description.find("5x10") >= 0 or description.find("5 x 10") >= 0:
		_fail("display rules description should not use legacy 5x10 wording")

	var zones: Dictionary = display_rules.get("zone_bonuses", {})
	if zones.is_empty():
		_fail("display rules should include zone bonuses")
	var region_policy: Dictionary = display_rules.get("region_policy", {})
	_expect_equal("region policy source", String(region_policy.get("source", "")), "showcase_unlocked_bounds")
	_expect_equal("front row ratio", float(region_policy.get("front_row_ratio", 0.0)), 0.3)
	_expect_equal("middle row ratio", float(region_policy.get("middle_row_ratio", 0.0)), 0.4)
	_expect_equal("back row ratio", float(region_policy.get("back_row_ratio", 0.0)), 0.3)
	_expect_equal("golden column ratio", float(region_policy.get("golden_column_ratio", 0.0)), 0.4)
	_expect_equal("minimum region size", int(region_policy.get("minimum_band_size", 0)), 1)
	for zone_id in ["zone_001", "zone_002", "zone_003"]:
		var zone: Dictionary = zones.get(zone_id, {})
		if zone.has("row_range") or zone.has("col_range"):
			_fail("%s should not duplicate dynamic region coordinates" % zone_id)
	var expected_region_ids := {"zone_001": "front", "zone_002": "golden", "zone_003": "back"}
	for zone_id in expected_region_ids.keys():
		_expect_equal(zone_id + " region id", String((zones.get(zone_id, {}) as Dictionary).get("region_id", "")), expected_region_ids[zone_id])

	var center_cells := _center_cells()
	_expect_equal("initial center cell count", center_cells.size(), 16)
	var center_keys := {}
	for cell in center_cells:
		if cell.x < 5 or cell.x > 8 or cell.y < 6 or cell.y > 9:
			_fail("initial center cell should remain inside the configured 4x4 center: %s" % cell)
		center_keys["%d:%d" % [cell.x, cell.y]] = true
	_expect_equal("initial center cells stay unique", center_keys.size(), 16)

	_finish()


func _center_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in range(5, 9):
		for column in range(6, 10):
			cells.append(Vector2i(row, column))
	return cells


func _expect_tier(tiers: Dictionary, tier_id: String, expected_min: int, expected_max: int) -> void:
	var tier: Dictionary = tiers.get(tier_id, {})
	_expect_equal(tier_id + " minimum", int(tier.get("min_seconds", 0)), expected_min)
	_expect_equal(tier_id + " maximum", int(tier.get("max_seconds", 0)), expected_max)


func _expect_range(label: String, value: Variant, minimum: int, maximum: int) -> void:
	if not value is Array or (value as Array).size() != 2:
		_fail("%s should contain two bounds" % label)
		return
	var bounds: Array = value
	var lower := int(bounds[0])
	var upper := int(bounds[1])
	if lower < minimum or upper > maximum or lower > upper:
		_fail("%s should stay within %d-%d, got %s" % [label, minimum, maximum, bounds])


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_ROUND_CONFIG_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_ROUND_CONFIG_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
