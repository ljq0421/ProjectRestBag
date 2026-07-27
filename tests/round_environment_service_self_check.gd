extends SceneTree

const CATALOG := preload("res://scripts/catalog.gd")
const BUSINESS_ROUND := preload("res://scripts/business_round_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	var service_path := "res://scripts/round_environment_service.gd"
	if not ResourceLoader.exists(service_path):
		_fail("RoundEnvironmentService should exist")
		_finish()
		return
	var service = load(service_path)
	var rules := CATALOG.new().get_showcase_round_rules()
	var first: Dictionary = service.generate(314159, 7, ["甜", "烘焙"], rules)
	var repeated: Dictionary = service.generate(314159, 7, ["甜", "烘焙"], rules)
	_expect_equal("same seed and round reproduce environment", first, repeated)
	_expect_equal("environment keeps standard round at thirty seconds", int(BUSINESS_ROUND.create_standard(7).get("duration_ms", 0)), 30000)
	_expect_equal("environment snapshot records round id", int(first.get("round_id", 0)), 7)
	_expect_equal("environment has one market slot", first.has("market"), true)
	_expect_equal("environment has one weather slot", first.has("weather"), true)
	_expect_equal("environment has one wave slot", first.has("wave"), true)
	_expect_equal("positive modifier is capped", float(first.get("total_price_pct", 0.0)) <= 25.0, true)
	_expect_equal("negative modifier is capped", float(first.get("total_price_pct", 0.0)) >= -10.0, true)
	_expect_equal("speed modifier cannot make sales impossible", float(first.get("total_speed_pct", 0.0)) >= -10.0, true)

	var terms := {
		"sponge_cake": {
			"base_price": 100,
			"unit_price": 100,
			"duration_seconds": 10,
			"tags": ["甜", "烘焙"],
			"environment_reasons": []
		}
	}
	var applied: Dictionary = service.apply_to_terms(terms, first)
	var item: Dictionary = applied.get("sponge_cake", {})
	_expect_equal("environment keeps positive sale duration", int(item.get("duration_seconds", 0)) >= 1, true)
	_expect_equal("environment records item reasons", (item.get("environment_reasons", []) as Array).size() > 0, true)
	_expect_equal("environment never mutates source terms", int((terms.get("sponge_cake", {}) as Dictionary).get("unit_price", 0)), 100)

	var fallback: Dictionary = service.generate(314159, 8, ["__no_matching_tag__"], rules)
	_expect_equal("unmatched environment still returns safe snapshot", String(fallback.get("label", "")).is_empty(), false)
	_finish()


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ROUND_ENVIRONMENT_SERVICE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("ROUND_ENVIRONMENT_SERVICE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
