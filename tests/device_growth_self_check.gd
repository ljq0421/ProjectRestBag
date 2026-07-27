extends SceneTree

const SERVICE_PATH := "res://scripts/device_growth_service.gd"
const CATALOG_PATH := "res://scripts/catalog.gd"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const RECIPE_BOOK_PATH := "res://scripts/recipe_book.gd"
const RECIPE_GROWTH_SERVICE_PATH := "res://scripts/recipe_growth_service.gd"
const GROWING_DEVICE_IDS := ["round_pot", "oven", "chiller", "griddle", "mixer"]

var _failures: Array[String] = []


func _init() -> void:
	_run()
	_finish()


func _run() -> void:
	_expect(ResourceLoader.exists(SERVICE_PATH), "DeviceGrowthService should exist")
	if not ResourceLoader.exists(SERVICE_PATH):
		return
	var service = load(SERVICE_PATH)
	var catalog = load(CATALOG_PATH).new()
	var devices: Dictionary = catalog.get_devices()

	_expect(service.default_state() == {
		"level": 1,
		"use_count": 0,
		"research_count": 0,
		"production_batch_count": 0
	}, "default state should start at L1 with no effective uses")

	var expected_uses := [0, 10, 30, 70, 150]
	var expected_costs := [0, 120, 360, 900, 2200]
	var expected_caps := [0, 0, 1, 1, 2]
	var total_cost := 0
	for level in range(1, 6):
		var definition: Dictionary = service.level_definition(level)
		_expect(int(definition.get("required_uses", -1)) == expected_uses[level - 1], "L%d required uses should match design" % level)
		_expect(int(definition.get("coin_cost", -1)) == expected_costs[level - 1], "L%d coin cost should match design" % level)
		_expect(int(service.stage_cap(level)) == expected_caps[level - 1], "L%d stage cap should match design" % level)
		total_cost += int(definition.get("coin_cost", 0))

	_expect(total_cost * GROWING_DEVICE_IDS.size() == 17900, "five devices should cost 17,900 coins in total")
	_expect(expected_uses.back() * GROWING_DEVICE_IDS.size() == 750, "five devices should require 750 cumulative uses")
	_expect(int(service.research_hint_increment(1)) == 1, "L1 research hint increment should be 1")
	_expect(int(service.research_hint_increment(2)) == 2, "L2 research hint increment should be 2")
	_expect(is_equal_approx(float(service.production_growth_multiplier(3)), 1.0), "L3 production growth multiplier should be 1.0")
	_expect(is_equal_approx(float(service.production_growth_multiplier(4)), 1.2), "L4 production growth multiplier should be 1.2")
	_expect(String(service.level_definition(4).get("effect", "")).find("名作制作经验 +20%") >= 0, "L4 effect should describe the multiplier as masterwork XP only")

	for device_id in GROWING_DEVICE_IDS:
		_expect(service.supports_growth(device_id, devices), "%s should support device growth" % device_id)
	_expect(not service.supports_growth("grinder", devices), "grinder should not support device growth")
	_expect_recipe_stage_caps()
	_expect(service.has_method("upgrade_quote"), "DeviceGrowthService should provide upgrade_quote")
	if service.has_method("upgrade_quote"):
		_expect_upgrade_transaction()


func _expect_recipe_stage_caps() -> void:
	var service = load(RECIPE_GROWTH_SERVICE_PATH)
	var required_methods := [
		"stage_requirement",
		"stage_progress_status",
		"can_advance_stage",
		"effective_signature_made_count",
		"growth_status"
	]
	for method_name in required_methods:
		_expect(service.has_method(method_name), "RecipeGrowthService should provide %s" % method_name)
	if required_methods.any(func(method_name): return not service.has_method(method_name)):
		return

	var signature_progress := {
		"mastery_level": service.MASTERY_POPULAR,
		"stage_made_batches": 40,
		"stage_effective_rounds": 14,
		"stage_synergy_rounds": 8
	}
	_expect(bool(service.can_advance_stage(signature_progress, 5)), "popular progress should require 40 real batches, 14 rounds, 8 synergy rounds, and L5")
	_expect(not bool(service.can_advance_stage(signature_progress, 4)), "popular progress should wait below L5")
	_expect(int(service.effective_signature_made_count(33, 4)) == 33, "L4 multiplier should not inflate stage batches")
	_expect(int(service.effective_signature_made_count(40, 4)) == 40, "signature should still require 40 real batches")

	var game_state_script = load(GAME_STATE_PATH)
	var waiting = game_state_script.new_game()
	waiting.unlock_device("round_pot")
	waiting.add_recipe("rice_milk_drink")
	waiting.recipe_growth["rice_milk_drink"] = {
		"mastery_level": service.MASTERY_TRIAL,
		"stage_made_batches": 30,
		"stage_effective_rounds": 10,
		"stage_synergy_rounds": 3,
		"made_count": 40,
		"sold_count": 25,
		"adjacency_trigger_count": 10,
		"display_traits": [],
		"available_traits": [],
		"selected_traits": [],
		"selected_display_traits": [],
		"pending_trait_choice": false
	}
	_expect(waiting.has_method("recipe_growth_status"), "GameState should provide a read-only recipe growth status")
	if not waiting.has_method("recipe_growth_status"):
		return
	_expect(int(waiting.get_recipe_growth("rice_milk_drink").get("mastery_level", -1)) == service.MASTERY_TRIAL, "reading growth should not bypass the L1 cap")
	var blocked_status: Dictionary = waiting.recipe_growth_status("rice_milk_drink")
	_expect(bool(blocked_status.get("waiting_for_device", false)), "eligible recipe should report waiting for its device")
	_expect(int(blocked_status.get("device_target_level", 0)) == 3, "waiting status should expose its L3 target")

	waiting.device_growth["round_pot"]["level"] = 5
	_expect(int(waiting.get_recipe_growth("rice_milk_drink").get("mastery_level", -1)) == service.MASTERY_TRIAL, "device upgrade followed by a read should not mass-promote")
	waiting.record_recipe_sold("rice_milk_drink", 1, false)
	_expect(int(waiting.get_recipe_growth("rice_milk_drink").get("mastery_level", -1)) == service.MASTERY_TRIAL, "sale should not release pre-existing device wait")
	waiting.record_recipe_made("rice_milk_drink", 1, 1, "manual")
	var released: Dictionary = waiting.get_recipe_growth("rice_milk_drink")
	_expect(int(released.get("mastery_level", 0)) == service.MASTERY_POPULAR, "one production event should release at most one waiting stage")
	_expect(bool(released.get("pending_trait_choice", false)), "released popular recipe should retain its trait choice flow")

	var sale_crosses_while_waiting = game_state_script.new_game()
	sale_crosses_while_waiting.unlock_device("round_pot")
	sale_crosses_while_waiting.add_recipe("rice_milk_drink")
	sale_crosses_while_waiting.device_growth["round_pot"]["level"] = 5
	sale_crosses_while_waiting.recipe_growth["rice_milk_drink"] = {
		"mastery_level": service.MASTERY_TRIAL,
		"stage_made_batches": 30,
		"stage_effective_rounds": 10,
		"stage_synergy_rounds": 3,
		"made_count": 40,
		"sold_count": 24,
		"adjacency_trigger_count": 10,
		"selected_traits": []
	}
	sale_crosses_while_waiting.record_recipe_sold("rice_milk_drink", 1, false)
	_expect(int(sale_crosses_while_waiting.get_recipe_growth("rice_milk_drink").get("mastery_level", -1)) == service.MASTERY_TRIAL, "sale should not release an existing wait even when it completes a later natural stage")

	var sale_cross = game_state_script.new_game()
	sale_cross.unlock_device("round_pot")
	sale_cross.add_recipe("rice_milk_drink")
	sale_cross.device_growth["round_pot"]["level"] = 3
	sale_cross.recipe_growth["rice_milk_drink"] = {
		"mastery_level": service.MASTERY_TRIAL,
		"stage_made_batches": 30,
		"stage_effective_rounds": 10,
		"stage_synergy_rounds": 3,
		"made_count": 15,
		"sold_count": 9,
		"adjacency_trigger_count": 0,
		"selected_traits": []
	}
	sale_cross.record_recipe_sold("rice_milk_drink", 1, false)
	_expect(int(sale_cross.get_recipe_growth("rice_milk_drink").get("mastery_level", -1)) == service.MASTERY_TRIAL, "lifetime sales should never be a stage promotion event")


func _expect_upgrade_transaction() -> void:
	var game_state_script = load(GAME_STATE_PATH)
	var state = game_state_script.new_game()
	_expect(state.has_method("get_device_growth"), "GameState should provide get_device_growth")
	_expect(state.has_method("device_growth_quote"), "GameState should provide device_growth_quote")
	_expect(state.has_method("upgrade_device_growth"), "GameState should provide upgrade_device_growth")
	if not state.has_method("upgrade_device_growth"):
		return

	_expect(String(state.get_device_growth("grinder").get("status", "")) == "unsupported", "grinder should return unsupported status")
	_expect(String(state.get_device_growth("oven").get("status", "")) == "locked", "locked product device should return locked status")
	_expect(state.unlock_device("round_pot"), "round pot should be explicitly unlockable")
	_expect(int(state.get_device_growth("round_pot").get("level", 0)) == 1, "unlocked round pot should initialize at L1")

	state.coins = 200
	var blocked: Dictionary = state.upgrade_device_growth("round_pot")
	_expect(not bool(blocked.get("ok", false)), "upgrade should fail without enough uses")
	_expect(int(blocked.get("missing_uses", -1)) == 10, "blocked upgrade should report ten missing uses")
	_expect(state.coins == 200, "blocked upgrade should not spend coins")

	state.device_growth["round_pot"] = {
		"level": 1,
		"use_count": 10,
		"research_count": 10,
		"production_batch_count": 0
	}
	var upgraded: Dictionary = state.upgrade_device_growth("round_pot")
	_expect(bool(upgraded.get("ok", false)), "qualified upgrade should succeed")
	_expect(int(state.get_device_growth("round_pot").get("level", 0)) == 2, "qualified upgrade should reach L2")
	_expect(state.coins == 80, "L2 upgrade should spend 120 coins")

	var saved: Dictionary = state.to_dict()
	_expect(saved.has("device_growth"), "save data should include device growth")
	var loaded = game_state_script.from_dict(saved)
	var loaded_growth: Dictionary = loaded.get_device_growth("round_pot")
	_expect(int(loaded_growth.get("level", 0)) == 2, "device level should survive save round-trip")
	_expect(int(loaded_growth.get("use_count", 0)) == 10, "device uses should survive save round-trip")

	var pure_read_state = game_state_script.new_game()
	pure_read_state.level = 99
	_expect(not pure_read_state.device_growth.has("oven"), "level-unlocked device should begin without stored growth when it has not been used")
	pure_read_state.get_device_growth("oven")
	_expect(not pure_read_state.device_growth.has("oven"), "reading device growth should not create persisted state")

	var unchanged_cap_state = game_state_script.new_game()
	unchanged_cap_state.unlock_device("round_pot")
	unchanged_cap_state.add_recipe("rice_milk_drink")
	unchanged_cap_state.coins = 200
	unchanged_cap_state.device_growth["round_pot"] = {
		"level": 1,
		"use_count": 10,
		"research_count": 10,
		"production_batch_count": 0
	}
	unchanged_cap_state.recipe_growth["rice_milk_drink"] = {
		"mastery_level": 0,
		"stage_made_batches": 30,
		"stage_effective_rounds": 10,
		"stage_synergy_rounds": 3,
		"selected_traits": []
	}
	var unchanged_cap_result: Dictionary = unchanged_cap_state.upgrade_device_growth("round_pot")
	_expect(bool(unchanged_cap_result.get("ok", false)), "L1 to L2 upgrade should succeed when qualified")
	_expect(int(unchanged_cap_result.get("promoted_recipe_count", -1)) == 0, "L1 to L2 should not release an L3 recipe requirement")
	_expect(int(unchanged_cap_result.get("waiting_recipe_count", -1)) == 1, "L1 to L2 should keep the recipe visibly waiting for L3")
	if not unchanged_cap_state.pending_notifications.is_empty():
		_expect(String(unchanged_cap_state.pending_notifications.back().get("body", "")).find("等待更高设备等级") >= 0, "upgrade summary should accurately describe recipes that still wait for a higher device level")

	var summary_state = game_state_script.new_game()
	summary_state.unlock_device("round_pot")
	summary_state.add_recipe("rice_milk_drink")
	summary_state.coins = 500
	summary_state.device_growth["round_pot"] = {
		"level": 2,
		"use_count": 30,
		"research_count": 30,
		"production_batch_count": 0
	}
	summary_state.recipe_growth["rice_milk_drink"] = {
		"mastery_level": 0,
		"stage_made_batches": 30,
		"stage_effective_rounds": 10,
		"stage_synergy_rounds": 3,
		"selected_traits": []
	}
	var summary_result: Dictionary = summary_state.upgrade_device_growth("round_pot")
	_expect(bool(summary_result.get("ok", false)), "L2 to L3 upgrade should succeed when qualified")
	_expect(int(summary_result.get("promoted_recipe_count", -1)) == 1, "L2 to L3 should immediately promote a fully ready recipe")
	_expect(int(summary_result.get("waiting_recipe_count", -1)) == 0, "promoted recipe should no longer be reported as waiting")
	_expect(summary_state.pending_notifications.size() == 2, "device upgrade should enqueue one recipe promotion plus one device summary")
	var notification_kinds: Array[String] = []
	for notification_value in summary_state.pending_notifications:
		if notification_value is Dictionary:
			notification_kinds.append(String((notification_value as Dictionary).get("metadata", {}).get("kind", "")))
	_expect(notification_kinds.has("recipe_growth_promoted"), "device-triggered promotion should keep the structured recipe notification")
	_expect(notification_kinds.has("device_growth_upgrade"), "device upgrade should keep its aggregate summary notification")
	_expect(summary_state.feedback_log.any(func(entry): return String(entry).begins_with("recipe_growth:rice_milk_drink:1")), "device-triggered promotion should keep the per-recipe growth log")
	_expect(int(summary_state.get_recipe_growth("rice_milk_drink").get("mastery_level", 0)) == 1, "device upgrade should release exactly one ready stage")
	_expect_event_counting(game_state_script)


func _expect_event_counting(game_state_script) -> void:
	var state = game_state_script.new_game()
	state.unlock_device("round_pot")
	_expect(state.has_method("record_device_research_success"), "GameState should record successful research uses")
	_expect(state.has_method("record_device_production_batches"), "GameState should record successful production batches")
	_expect(_method_argument_count(state, "record_recipe_made") >= 4, "record_recipe_made should distinguish output, batches, and source")
	if not state.has_method("record_device_research_success") or not state.has_method("record_device_production_batches") or _method_argument_count(state, "record_recipe_made") < 4:
		return

	state.record_device_research_success("round_pot")
	state.record_device_production_batches("round_pot", 5)
	var direct_growth: Dictionary = state.get_device_growth("round_pot")
	_expect(int(direct_growth.get("research_count", 0)) == 1, "successful research should add one research use")
	_expect(int(direct_growth.get("production_batch_count", 0)) == 5, "five completed batches should add five production uses")
	_expect(int(direct_growth.get("use_count", 0)) == 6, "effective use should equal research plus completed batches")
	var before_grinder: Dictionary = state.device_growth.duplicate(true)
	state.record_device_production_batches("grinder", 5)
	_expect(state.device_growth == before_grinder, "grinder processing should not change device growth")

	var recipe_book = load(RECIPE_BOOK_PATH)
	var manual = game_state_script.new_game()
	manual.unlock_device("round_pot")
	manual.add_recipe("rice_milk_drink")
	for item_id in ["rice", "spring_water", "sugar"]:
		manual.add_ingredient(item_id, 5)
	var made: Dictionary = recipe_book.make_product(manual, "rice_milk_drink", 1, 1000)
	_expect(bool(made.get("ok", false)), "one-batch manual production should start")
	_expect(int(manual.get_recipe_growth("rice_milk_drink").get("made_count", 0)) == 0, "starting production should not advance recipe growth")
	_expect(int(manual.get_device_growth("round_pot").get("production_batch_count", 0)) == 0, "starting production should not advance device growth")
	_expect(manual.complete_recipe_production(0, 1002), "ready manual production should complete")
	_expect(int(manual.get_recipe_growth("rice_milk_drink").get("made_count", 0)) == 3, "recipe made count should use completed product output")
	_expect(int(manual.get_device_growth("round_pot").get("production_batch_count", 0)) == 1, "manual device growth should use completed batches instead of output count")

	var automation = game_state_script.new_game()
	automation.unlock_device("round_pot")
	automation.add_recipe("rice_milk_drink")
	automation.recipe_production_queue.append({
		"recipe_id": "rice_milk_drink",
		"device_id": "round_pot",
		"batches": 5,
		"output_count": 15,
		"ready_at_unix": 1,
		"source": "automation",
		"automation_rule_id": "test"
	})
	_expect(automation.complete_recipe_production(0, 1), "ready automation production should complete")
	_expect(int(automation.get_device_growth("round_pot").get("production_batch_count", 0)) == 5, "automation should count actual completed batches once")


func _method_argument_count(target, method_name: String) -> int:
	for method_value in target.get_method_list():
		var method: Dictionary = method_value
		if String(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DEVICE_GROWTH_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
