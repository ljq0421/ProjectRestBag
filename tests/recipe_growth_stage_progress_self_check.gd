extends SceneTree

const RecipeGrowthService = preload("res://scripts/recipe_growth_service.gd")
const GameState = preload("res://scripts/game_state.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_three_stage_contract()
	_test_default_stage_counters()
	_test_stage_requirements()
	_test_all_requirements_are_required()
	_test_advance_is_single_stage_and_resets_stage_counters()
	_test_game_state_records_real_batches_and_promotes_once()
	_test_player_feedback_is_structured_and_device_wait_is_not_repeated()
	_test_signature_events_do_not_accumulate_stage_progress()
	_test_legacy_growth_does_not_backfill_or_auto_promote()
	_finish()


func _test_three_stage_contract() -> void:
	var constants: Dictionary = RecipeGrowthService.new().get_script().get_script_constant_map()
	_expect(not constants.has("MASTERY_STABLE"), "stable mastery constant should be removed")
	_expect_equal("trial stage id", RecipeGrowthService.MASTERY_TRIAL, 0)
	_expect_equal("popular stage id", RecipeGrowthService.MASTERY_POPULAR, 1)
	_expect_equal("signature stage id", RecipeGrowthService.MASTERY_SIGNATURE, 2)
	_expect_equal("trial stage name", RecipeGrowthService.mastery_name(0), "试作品")
	_expect_equal("popular stage name", RecipeGrowthService.mastery_name(1), "人气款")
	_expect_equal("signature stage name", RecipeGrowthService.mastery_name(2), "招牌款")


func _test_default_stage_counters() -> void:
	var growth := RecipeGrowthService.default_growth("rice_milk_drink")
	_expect_equal("default made batches", int(growth.get("stage_made_batches", -1)), 0)
	_expect_equal("default effective rounds", int(growth.get("stage_effective_rounds", -1)), 0)
	_expect_equal("default synergy rounds", int(growth.get("stage_synergy_rounds", -1)), 0)


func _test_stage_requirements() -> void:
	var service := RecipeGrowthService.new()
	_expect(service.has_method("stage_requirement"), "RecipeGrowthService should expose stage_requirement")
	if not service.has_method("stage_requirement"):
		return
	var trial: Dictionary = service.call("stage_requirement", RecipeGrowthService.MASTERY_TRIAL)
	var popular: Dictionary = service.call("stage_requirement", RecipeGrowthService.MASTERY_POPULAR)
	var signature: Dictionary = service.call("stage_requirement", RecipeGrowthService.MASTERY_SIGNATURE)
	_expect_requirement("trial", trial, 1, 30, 10, 3, 3)
	_expect_requirement("popular", popular, 2, 40, 14, 8, 5)
	_expect(signature.is_empty(), "signature recipes should not expose another stage requirement")


func _test_all_requirements_are_required() -> void:
	var service := RecipeGrowthService.new()
	_expect(service.has_method("can_advance_stage"), "RecipeGrowthService should expose can_advance_stage")
	_expect(service.has_method("stage_progress_status"), "RecipeGrowthService should expose stage_progress_status")
	if not service.has_method("can_advance_stage") or not service.has_method("stage_progress_status"):
		return
	var trial := RecipeGrowthService.default_growth("rice_milk_drink")
	trial["stage_made_batches"] = 30
	trial["stage_effective_rounds"] = 10
	trial["stage_synergy_rounds"] = 2
	_expect(not bool(service.call("can_advance_stage", trial, 3)), "trial should wait until the third synergy round")
	trial["stage_synergy_rounds"] = 3
	_expect(not bool(service.call("can_advance_stage", trial, 2)), "trial should wait for device L3")
	var status: Dictionary = service.call("stage_progress_status", trial, 2)
	_expect(bool(status.get("waiting_for_device", false)), "completed trial progress should report a device wait")
	_expect(not bool(status.get("ready_to_advance", true)), "device wait should not be ready to advance")
	_expect_equal("trial target device", int(status.get("device_target_level", 0)), 3)
	_expect(bool(service.call("can_advance_stage", trial, 3)), "trial should advance when device reaches L3")

	var popular := RecipeGrowthService.default_growth("rice_milk_drink")
	popular["mastery_level"] = RecipeGrowthService.MASTERY_POPULAR
	popular["stage_made_batches"] = 40
	popular["stage_effective_rounds"] = 14
	popular["stage_synergy_rounds"] = 7
	_expect(not bool(service.call("can_advance_stage", popular, 5)), "popular should wait until the eighth synergy round")
	popular["stage_synergy_rounds"] = 8
	_expect(not bool(service.call("can_advance_stage", popular, 4)), "popular should still require device L5")
	_expect(bool(service.call("can_advance_stage", popular, 5)), "popular should advance at 40 batches, 14 rounds, 8 synergy rounds, and L5")


func _test_advance_is_single_stage_and_resets_stage_counters() -> void:
	var service := RecipeGrowthService.new()
	_expect(service.has_method("advance_one_stage"), "RecipeGrowthService should expose advance_one_stage")
	if not service.has_method("advance_one_stage"):
		return
	var growth := RecipeGrowthService.default_growth("rice_milk_drink")
	growth["stage_made_batches"] = 70
	growth["stage_effective_rounds"] = 24
	growth["stage_synergy_rounds"] = 12
	growth["made_count"] = 210
	growth["sold_count"] = 130
	growth["adjacency_trigger_count"] = 45
	var recipe := {"tags": ["经典"], "device": "round_pot"}
	var updated: Dictionary = service.call("advance_one_stage", "rice_milk_drink", growth, recipe, {"recipes": {}}, 5)
	_expect_equal("single event advances one stage", int(updated.get("mastery_level", -1)), RecipeGrowthService.MASTERY_POPULAR)
	_expect_equal("promotion clears made batches", int(updated.get("stage_made_batches", -1)), 0)
	_expect_equal("promotion clears effective rounds", int(updated.get("stage_effective_rounds", -1)), 0)
	_expect_equal("promotion clears synergy rounds", int(updated.get("stage_synergy_rounds", -1)), 0)
	_expect_equal("promotion preserves lifetime made", int(updated.get("made_count", -1)), 210)
	_expect_equal("promotion preserves lifetime sold", int(updated.get("sold_count", -1)), 130)
	_expect_equal("promotion preserves lifetime adjacency", int(updated.get("adjacency_trigger_count", -1)), 45)


func _test_game_state_records_real_batches_and_promotes_once() -> void:
	var state = GameState.new_game()
	state.level = 5
	state.unlock_device("round_pot")
	state.add_recipe("rice_milk_drink")
	state.device_growth["round_pot"] = {"level": 3, "research_count": 30, "production_batch_count": 0}
	var growth := RecipeGrowthService.default_growth("rice_milk_drink")
	growth["stage_made_batches"] = 29
	growth["stage_effective_rounds"] = 10
	growth["stage_synergy_rounds"] = 3
	state.recipe_growth["rice_milk_drink"] = growth
	state.record_recipe_made("rice_milk_drink", 3, 1, "manual")
	var popular: Dictionary = state.get_recipe_growth("rice_milk_drink")
	_expect_equal("one real batch completes trial", int(popular.get("mastery_level", -1)), RecipeGrowthService.MASTERY_POPULAR)
	_expect_equal("promotion clears stage batches in state", int(popular.get("stage_made_batches", -1)), 0)
	_expect_equal("output remains a lifetime item count", int(popular.get("made_count", -1)), 3)

	popular["stage_made_batches"] = 39
	popular["stage_effective_rounds"] = 14
	popular["stage_synergy_rounds"] = 8
	state.recipe_growth["rice_milk_drink"] = popular
	state.device_growth["round_pot"] = {"level": 5, "research_count": 150, "production_batch_count": 0}
	state.record_recipe_made("rice_milk_drink", 15, 5, "automation")
	var after_five_batches: Dictionary = state.get_recipe_growth("rice_milk_drink")
	_expect_equal("multi-batch event advances at most one stage", int(after_five_batches.get("mastery_level", -1)), RecipeGrowthService.MASTERY_SIGNATURE)
	_expect_equal("multi-batch overflow does not carry", int(after_five_batches.get("stage_made_batches", -1)), 0)
	_expect_equal("five batches are not multiplied by output", int(after_five_batches.get("made_count", -1)), 18)


func _test_player_feedback_is_structured_and_device_wait_is_not_repeated() -> void:
	var promoted_state = GameState.new_game()
	promoted_state.level = 5
	promoted_state.unlock_device("round_pot")
	promoted_state.add_recipe("rice_milk_drink")
	var ready_trial := RecipeGrowthService.default_growth("rice_milk_drink")
	ready_trial["stage_made_batches"] = 29
	ready_trial["stage_effective_rounds"] = 10
	ready_trial["stage_synergy_rounds"] = 3
	promoted_state.device_growth["round_pot"] = {"level": 3, "research_count": 30, "production_batch_count": 0}
	promoted_state.recipe_growth["rice_milk_drink"] = ready_trial
	promoted_state.record_recipe_made("rice_milk_drink", 3, 1, "manual")
	_expect_equal("promotion queues one player notification", promoted_state.pending_notifications.size(), 1)
	if promoted_state.pending_notifications.size() == 1:
		var metadata: Dictionary = promoted_state.pending_notifications[0].get("metadata", {})
		_expect_equal("promotion notification kind", String(metadata.get("kind", "")), "recipe_growth_promoted")
		_expect_equal("promotion notification previous stage", int(metadata.get("before_level", -1)), 0)
		_expect_equal("promotion notification new stage", int(metadata.get("after_level", -1)), RecipeGrowthService.MASTERY_POPULAR)

	var waiting_state = GameState.new_game()
	waiting_state.level = 5
	waiting_state.unlock_device("round_pot")
	waiting_state.add_recipe("rice_milk_drink")
	var waiting_growth := RecipeGrowthService.default_growth("rice_milk_drink")
	waiting_growth["mastery_level"] = RecipeGrowthService.MASTERY_TRIAL
	waiting_growth["stage_made_batches"] = 30
	waiting_growth["stage_effective_rounds"] = 9
	waiting_growth["stage_synergy_rounds"] = 3
	waiting_state.recipe_growth["rice_milk_drink"] = waiting_growth
	waiting_state.record_recipe_growth_round("rice_milk_drink", true, false)
	waiting_state.record_recipe_growth_round("rice_milk_drink", true, false)
	_expect_equal("device wait notification is one-time", waiting_state.pending_notifications.size(), 1)
	if waiting_state.pending_notifications.size() == 1:
		var metadata: Dictionary = waiting_state.pending_notifications[0].get("metadata", {})
		_expect_equal("device wait notification kind", String(metadata.get("kind", "")), "recipe_growth_device_wait")


func _test_signature_events_do_not_accumulate_stage_progress() -> void:
	var state = GameState.new_game()
	state.level = 5
	state.unlock_device("round_pot")
	state.add_recipe("rice_milk_drink")
	var signature := RecipeGrowthService.default_growth("rice_milk_drink")
	signature["mastery_level"] = RecipeGrowthService.MASTERY_SIGNATURE
	state.recipe_growth["rice_milk_drink"] = signature
	state.record_recipe_made("rice_milk_drink", 3, 1, "manual")
	state.record_recipe_growth_round("rice_milk_drink", true, true)
	var updated: Dictionary = state.get_recipe_growth("rice_milk_drink")
	_expect_equal("signature made stage counter stays zero", int(updated.get("stage_made_batches", -1)), 0)
	_expect_equal("signature effective stage counter stays zero", int(updated.get("stage_effective_rounds", -1)), 0)
	_expect_equal("signature synergy stage counter stays zero", int(updated.get("stage_synergy_rounds", -1)), 0)


func _test_legacy_growth_does_not_backfill_or_auto_promote() -> void:
	var legacy := {
		"mastery_level": RecipeGrowthService.MASTERY_TRIAL,
		"made_count": 500,
		"sold_count": 500,
		"adjacency_trigger_count": 500
	}
	var sanitized := RecipeGrowthService.sanitize_growth(
		"rice_milk_drink",
		legacy,
		{"tags": ["经典"], "device": "round_pot"},
		{"recipes": {}},
		5
	)
	_expect_equal("legacy stage remains unchanged", int(sanitized.get("mastery_level", -1)), RecipeGrowthService.MASTERY_TRIAL)
	_expect_equal("legacy made batches start at zero", int(sanitized.get("stage_made_batches", -1)), 0)
	_expect_equal("legacy effective rounds start at zero", int(sanitized.get("stage_effective_rounds", -1)), 0)
	_expect_equal("legacy synergy rounds start at zero", int(sanitized.get("stage_synergy_rounds", -1)), 0)
	_expect_equal("legacy lifetime made is preserved", int(sanitized.get("made_count", -1)), 500)


func _expect_requirement(label: String, requirement: Dictionary, next_level: int, batches: int, rounds: int, synergy: int, device_level: int) -> void:
	_expect_equal("%s next level" % label, int(requirement.get("next_level", -1)), next_level)
	_expect_equal("%s batches" % label, int(requirement.get("made_batches", -1)), batches)
	_expect_equal("%s effective rounds" % label, int(requirement.get("effective_rounds", -1)), rounds)
	_expect_equal("%s synergy rounds" % label, int(requirement.get("synergy_rounds", -1)), synergy)
	_expect_equal("%s device level" % label, int(requirement.get("device_level", -1)), device_level)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("RECIPE_GROWTH_STAGE_PROGRESS_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
