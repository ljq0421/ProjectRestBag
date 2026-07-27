extends SceneTree

const ShowcaseRoundReportService = preload("res://scripts/showcase_round_report_service.gd")
const GameState = preload("res://scripts/game_state.gd")
const RecipeGrowthService = preload("res://scripts/recipe_growth_service.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_growth_flags_are_per_recipe_and_capped_per_round()
	_test_report_exposes_growth_flags()
	_test_settlement_records_growth_once()
	_finish()


func _test_growth_flags_are_per_recipe_and_capped_per_round() -> void:
	var service := ShowcaseRoundReportService.new()
	_expect(service.has_method("growth_round_flags"), "ShowcaseRoundReportService should expose growth_round_flags")
	if not service.has_method("growth_round_flags"):
		return
	var flags: Dictionary = service.call("growth_round_flags", [
		{"recipe_id": "rice_milk_drink", "quantity": 1, "positive_adjacency": false},
		{"recipe_id": "rice_milk_drink", "quantity": 1, "positive_adjacency": true},
		{"recipe_id": "rice_milk_drink", "quantity": 4, "positive_adjacency": true},
		{"recipe_id": "butter_cookie", "quantity": 1, "positive_adjacency": false},
		{"recipe_id": "clearance_only", "quantity": 3, "positive_adjacency": true, "clearance": true},
		{"recipe_id": "bonus_only", "quantity": 0, "positive_adjacency": true, "bonus_only": true}
	])
	_expect_equal("rice effective flag", bool(flags.get("rice_milk_drink", {}).get("growth_effective_round", false)), true)
	_expect_equal("rice synergy flag", bool(flags.get("rice_milk_drink", {}).get("growth_synergy_round", false)), true)
	_expect_equal("rice real sale count remains informational", int(flags.get("rice_milk_drink", {}).get("real_sale_count", 0)), 6)
	_expect_equal("butter effective flag", bool(flags.get("butter_cookie", {}).get("growth_effective_round", false)), true)
	_expect_equal("butter synergy flag", bool(flags.get("butter_cookie", {}).get("growth_synergy_round", false)), false)
	_expect(not flags.has("clearance_only"), "clearance-only events should not count as growth rounds")
	_expect(not flags.has("bonus_only"), "bonus-only events should not count as growth rounds")


func _test_report_exposes_growth_flags() -> void:
	var round_state := {
		"round_id": 7,
		"kind": "challenge",
		"duration_ms": 30000,
		"sale_events": [
			{"recipe_id": "rice_milk_drink", "quantity": 1, "earned_coins": 10, "base_price": 10, "positive_adjacency": true}
		],
		"refill_events": [],
		"item_states": {"rice_milk_drink": {"fresh_stock": 0, "carried_stock": 0}},
		"layout_snapshot": {},
		"environment": {}
	}
	var report := ShowcaseRoundReportService.build_report(round_state, {"settlement_id": "growth-report-7"})
	var product: Dictionary = report.get("products", {}).get("rice_milk_drink", {})
	_expect_equal("report effective flag", bool(product.get("growth_effective_round", false)), true)
	_expect_equal("report synergy flag", bool(product.get("growth_synergy_round", false)), true)


func _test_settlement_records_growth_once() -> void:
	var state = GameState.new_game()
	state.level = 5
	state.unlock_device("round_pot")
	state.add_recipe("rice_milk_drink")
	state.device_growth["round_pot"] = {"level": 3, "research_count": 30, "production_batch_count": 0}
	var growth := RecipeGrowthService.default_growth("rice_milk_drink")
	growth["stage_made_batches"] = 30
	growth["stage_effective_rounds"] = 9
	growth["stage_synergy_rounds"] = 2
	state.recipe_growth["rice_milk_drink"] = growth
	var settlement := {
		"ok": true,
		"settlement_id": "growth-settlement-1",
		"earned_coins": 0,
		"item_states": {},
		"round_report": {
			"round_id": 1,
			"is_complete": true,
			"missing_fields": [],
			"products": {
				"rice_milk_drink": {
					"growth_effective_round": true,
					"growth_synergy_round": true
				}
			}
		}
	}
	_expect(state.apply_showcase_round_settlement(settlement), "first completed settlement should apply")
	var after_first: Dictionary = state.get_recipe_growth("rice_milk_drink")
	_expect_equal("settlement can promote one stage", int(after_first.get("mastery_level", -1)), RecipeGrowthService.MASTERY_POPULAR)
	_expect_equal("promotion resets effective round", int(after_first.get("stage_effective_rounds", -1)), 0)
	_expect_equal("promotion resets synergy round", int(after_first.get("stage_synergy_rounds", -1)), 0)
	var applied_product: Dictionary = state.recent_showcase_round_reports.back().get("products", {}).get("rice_milk_drink", {})
	_expect_equal("applied report keeps effective contribution", bool(applied_product.get("growth_effective_round", false)), true)
	_expect_equal("applied report records stage before promotion", int(applied_product.get("growth_before_mastery", -1)), RecipeGrowthService.MASTERY_TRIAL)
	_expect_equal("applied report records stage after promotion", int(applied_product.get("growth_after_mastery", -1)), RecipeGrowthService.MASTERY_POPULAR)
	_expect(not state.apply_showcase_round_settlement(settlement), "duplicate settlement should be rejected")
	_expect_equal("duplicate settlement does not add another round", int(state.get_recipe_growth("rice_milk_drink").get("stage_effective_rounds", -1)), 0)

	var incomplete := settlement.duplicate(true)
	incomplete["settlement_id"] = "growth-settlement-incomplete"
	incomplete["round_report"]["is_complete"] = false
	_expect(state.apply_showcase_round_settlement(incomplete), "incomplete report settlement may still close the round")
	_expect_equal("incomplete report does not add growth", int(state.get_recipe_growth("rice_milk_drink").get("stage_effective_rounds", -1)), 0)

	var signature_state = GameState.new_game()
	signature_state.level = 5
	signature_state.unlock_device("round_pot")
	signature_state.add_recipe("rice_milk_drink")
	var signature_growth := RecipeGrowthService.default_growth("rice_milk_drink")
	signature_growth["mastery_level"] = RecipeGrowthService.MASTERY_SIGNATURE
	signature_state.recipe_growth["rice_milk_drink"] = signature_growth
	var signature_settlement := settlement.duplicate(true)
	signature_settlement["settlement_id"] = "growth-settlement-signature"
	_expect(signature_state.apply_showcase_round_settlement(signature_settlement), "signature settlement should still apply normally")
	var signature_product: Dictionary = signature_state.recent_showcase_round_reports.back().get("products", {}).get("rice_milk_drink", {})
	_expect_equal("signature report suppresses ineffective growth", bool(signature_product.get("growth_effective_round", true)), false)
	_expect_equal("signature report suppresses ineffective synergy", bool(signature_product.get("growth_synergy_round", true)), false)
	_expect_equal("signature report stage remains signature", int(signature_product.get("growth_after_mastery", -1)), RecipeGrowthService.MASTERY_SIGNATURE)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("RECIPE_GROWTH_ROUND_PROGRESS_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
