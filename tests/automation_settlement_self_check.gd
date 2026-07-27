extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const ProductionSite = preload("res://scripts/production_site.gd")
const AutomationService = preload("res://scripts/automation_service.gd")
const SaveSystem = preload("res://scripts/save_system.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_multiple_output_cycles()
	_test_unmanaged_slot_only_matures()
	_test_missing_input_preserves_paused_slot()
	_test_queued_item_switches_then_repeats()
	_test_base_managed_site_limit()
	_test_accelerator_applies_to_each_new_cycle()
	_test_structured_slot_settlement()
	_test_management_persistence()
	_test_limits_and_global_pause()
	_test_global_pause_resume_does_not_backfill()
	_test_explicit_offline_limit_caps_settlement()
	_test_overdue_slot_uses_ready_timestamp()
	_test_malformed_managed_slot_terminates()
	_test_event_limit_only_reports_remaining_events()
	_test_kitchen_rule_fixture()
	_test_kitchen_three_batch_capacity_is_atomic()
	_test_kitchen_generated_rule_id_skips_explicit_sequence()
	_test_output_to_kitchen_chain()
	_test_kitchen_growth_report()
	_test_kitchen_manual_queue_has_priority()
	_test_kitchen_priority_target_and_reserve_gates()
	_test_kitchen_offline_rule_and_save_sanitation()
	_test_kitchen_pause_resume_uses_resume_floor()
	_test_started_online_only_queue_blocks_offline_then_resumes_online()
	_test_eligible_kitchen_queue_keeps_normal_overdue_catch_up()
	_test_coin_funded_output_restart_reports_insufficient_coins()
	_test_notification_metadata_roundtrip()
	_test_unread_displaying_report_survives_empty_later_load()
	_test_first_offline_load_only_records_baseline()
	_test_offline_load_settles_and_is_idempotent()
	_test_clock_rollback_yields_nothing()
	_test_offline_duration_cap_discards_backlog()
	_test_offline_event_cap_discards_backlog()
	_test_truncation_reanchors_only_automatic_kitchen_queue()
	_test_offline_save_failure_rolls_back()

	if failures.is_empty():
		print("Automation settlement self-check passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_multiple_output_cycles() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 4}
	if not ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000):
		_fail("wheat slot should start")
	if not bool(AutomationService.set_output_managed(state, "farm", 0, true).get("ok", false)):
		_fail("farm:0 should become managed")
	var report := AutomationService.settle(state, 1000, 1080, 7200)
	_expect_equal("wheat harvested", state.get_ingredient_count("wheat"), 12)
	_expect_equal("output cycles", int(report.get("output_cycle_count", 0)), 4)
	_expect_equal("remaining seed", state.get_ingredient_count("wheat_seed"), 0)


func _test_unmanaged_slot_only_matures() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 1}
	if not ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000):
		_fail("unmanaged wheat slot should start")
	var report := AutomationService.settle(state, 1000, 1080, 7200)
	_expect_equal("unmanaged slot harvest", state.get_ingredient_count("wheat"), 0)
	_expect_equal("unmanaged output cycles", int(report.get("output_cycle_count", 0)), 0)
	_expect_equal("unmanaged slot should mature", ProductionSite.is_slot_ready(state, 0, 1080), true)


func _test_missing_input_preserves_paused_slot() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 1}
	ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000)
	AutomationService.set_output_managed(state, "farm", 0, true)
	var report := AutomationService.settle(state, 1000, 1020, 7200)
	_expect_equal("exhausted managed slot count", state.production_slots.size(), 1)
	if state.production_slots.size() == 1:
		var slot: Dictionary = state.production_slots[0]
		_expect_equal("exhausted slot paused", bool(slot.get("automation_paused", false)), true)
		_expect_equal("exhausted slot started_at", int(slot.get("started_at_unix", -1)), 0)
		_expect_equal("exhausted slot ready_at", int(slot.get("ready_at_unix", -1)), 0)
		_expect_equal("exhausted slot pause code", String(slot.get("pause_reason", {}).get("code", "")), "missing_input")
		_expect_equal("exhausted slot pause item", String(slot.get("pause_reason", {}).get("item_id", "")), "wheat_seed")
		_expect_equal("exhausted slot first stopped", int(slot.get("pause_reason", {}).get("first_stopped_at_unix", 0)), 1020)
		_expect_equal("paused slot cannot harvest twice", ProductionSite.is_slot_ready(state, 0, 2000), false)
	_expect_equal("paused report entries", (report.get("paused_slots", []) as Array).size(), 1)


func _test_queued_item_switches_then_repeats() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 1, "rice_seed": 2}
	if not ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000):
		_fail("queued switch slot should start")
	if not ProductionSite.set_next_item(state, 0, "rice_seed"):
		_fail("queued rice should be accepted")
	AutomationService.set_output_managed(state, "farm", 0, true)
	var report := AutomationService.settle(state, 1000, 1024, 7200)
	_expect_equal("queued switch output cycles", int(report.get("output_cycle_count", 0)), 3)
	_expect_equal("queued switch wheat output", state.get_ingredient_count("wheat"), 3)
	_expect_equal("queued switch repeated rice output", state.get_ingredient_count("rice"), 6)
	if state.production_slots.size() == 1:
		var slot: Dictionary = state.production_slots[0]
		_expect_equal("queued switch current item", String(slot.get("item_id", "")), "rice_seed")
		_expect_equal("queued item consumed after switch", slot.has("queued_item_id"), false)
	else:
		_fail("queued switch should preserve one paused slot")


func _test_base_managed_site_limit() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	_expect_equal("base farm site accepted", bool(AutomationService.set_output_site_managed(state, "farm", true).get("ok", false)), true)
	_expect_equal("second managed site rejected", bool(AutomationService.set_output_site_managed(state, "ranch", true).get("ok", false)), false)
	_expect_equal("base managed site count", state.managed_production_sites.size(), 1)
	state.automation_upgrades["output_capacity_1"] = true
	_expect_equal("second managed site accepted after upgrade", bool(AutomationService.set_output_site_managed(state, "ranch", true).get("ok", false)), true)
	_expect_equal("upgraded managed site count", state.managed_production_sites.size(), 2)


func _test_accelerator_applies_to_each_new_cycle() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 5}
	ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000)
	state.add_tool("farm_accelerator", 1)
	if not state.equip_accelerator("farm:0", "farm_accelerator"):
		_fail("farm accelerator should equip after initial cycle starts")
	AutomationService.set_output_managed(state, "farm", 0, true)
	var report := AutomationService.settle(state, 1000, 1065, 7200)
	_expect_equal("accelerated output cycles", int(report.get("output_cycle_count", 0)), 4)
	_expect_equal("accelerated wheat output", state.get_ingredient_count("wheat"), 12)
	if state.production_slots.size() == 1:
		var slot: Dictionary = state.production_slots[0]
		_expect_equal("accelerated restart duration", int(slot.get("duration_seconds", 0)), 15)
		_expect_equal("accelerated repeated next ready", int(slot.get("ready_at_unix", 0)), 1080)


func _test_structured_slot_settlement() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.ingredient_inventory = {"wheat_seed": 2}
	ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000)
	var result := ProductionSite.settle_ready_slot(state, 0, 1020, true)
	_expect_equal("structured settlement ok", bool(result.get("ok", false)), true)
	_expect_equal("structured settlement key", String(result.get("slot_key", "")), "farm:0")
	_expect_equal("structured settlement outputs", int(result.get("outputs", {}).get("wheat", 0)), 3)
	_expect_equal("structured settlement restarted", bool(result.get("restarted", false)), true)
	_expect_equal("structured settlement next ready", int(result.get("next_ready_at_unix", 0)), 1040)


func _test_management_persistence() -> void:
	var state = GameState.new_game()
	state.managed_production_sites.append("farm")
	state.automation_paused = true
	state.automation_resume_floor_unix = 1050
	var saved: Dictionary = state.to_dict()
	(saved.get("managed_production_sites", []) as Array).append("ranch")
	_expect_equal("managed sites save uses copy", state.managed_production_sites, ["farm"])
	var loaded = GameState.from_dict({
		"production_slot_unlocks": {"farm": 2},
		"managed_production_slots": [
			"farm:00",
			"farm:+0",
			"farm:0",
			"farm:01",
			"farm:1",
			"farm:-1",
			"unknown:0",
			"farm:x",
			"farm:0:1",
			":0",
			"farm:99",
			"farm:999"
		],
		"automation_paused": true,
		"automation_resume_floor_unix": 1050
	})
	_expect_equal("managed slots canonicalize and filter locked indices", loaded.managed_production_slots, ["farm:0", "farm:1"])
	_expect_equal("legacy managed slots migrate to one site", loaded.managed_production_sites, ["farm"])
	_expect_equal("global pause roundtrip", loaded.automation_paused, true)
	_expect_equal("resume floor saved", int(saved.get("automation_resume_floor_unix", 0)), 1050)
	_expect_equal("resume floor roundtrip", loaded.automation_resume_floor_unix, 1050)
	var invalid_resume_floor_state = GameState.from_dict({"automation_resume_floor_unix": -1})
	_expect_equal("negative resume floor sanitized", invalid_resume_floor_state.automation_resume_floor_unix, 0)


func _test_limits_and_global_pause() -> void:
	var state = GameState.new_game()
	_expect_equal("base output site limit", AutomationService.output_site_limit(state), 1)
	_expect_equal("base offline seconds", AutomationService.offline_seconds_limit(state), 7200)
	_expect_equal("base kitchen rule limit", AutomationService.kitchen_rule_limit(state), 1)
	_expect_equal("base kitchen device limit", AutomationService.kitchen_device_limit(state), 1)
	_expect_equal("base kitchen priority locked", AutomationService.priority_enabled(state), false)
	_expect_equal("base kitchen reserve policy locked", AutomationService.inventory_policy_enabled(state), false)
	state.automation_upgrades["output_capacity_1"] = true
	state.automation_upgrades["offline_duration_1"] = true
	_expect_equal("first output site upgrade", AutomationService.output_site_limit(state), 2)
	_expect_equal("first offline upgrade", AutomationService.offline_seconds_limit(state), 14400)
	state.automation_upgrades["output_capacity_2"] = true
	state.automation_upgrades["offline_duration_2"] = true
	_expect_equal("second output site upgrade", AutomationService.output_site_limit(state), 3)
	_expect_equal("second offline upgrade", AutomationService.offline_seconds_limit(state), 28800)
	state.automation_upgrades["output_capacity_all"] = true
	state.automation_upgrades["kitchen_rules_3"] = true
	state.automation_upgrades["kitchen_devices_2"] = true
	state.automation_upgrades["kitchen_priority"] = true
	state.automation_upgrades["kitchen_inventory_policy"] = true
	_expect_equal("all output sites upgrade", AutomationService.output_site_limit(state), -1)
	_expect_equal("first kitchen rule upgrade", AutomationService.kitchen_rule_limit(state), 3)
	_expect_equal("first kitchen device upgrade", AutomationService.kitchen_device_limit(state), 2)
	_expect_equal("kitchen priority upgrade", AutomationService.priority_enabled(state), true)
	_expect_equal("kitchen reserve policy upgrade", AutomationService.inventory_policy_enabled(state), true)
	state.automation_upgrades["kitchen_all"] = true
	_expect_equal("all kitchen rule upgrade", AutomationService.kitchen_rule_limit(state), 8)
	_expect_equal("all kitchen device upgrade", AutomationService.kitchen_device_limit(state), -1)

	var paused_state = GameState.new_game()
	paused_state.level = 3
	paused_state.unlock_automation("output")
	paused_state.ingredient_inventory = {"wheat_seed": 1}
	ProductionSite.start_slot(paused_state, "farm", "wheat_seed", 0, 1000)
	AutomationService.set_output_managed(paused_state, "farm", 0, true)
	AutomationService.set_global_paused(paused_state, true, 1000)
	var paused_report := AutomationService.settle(paused_state, 1000, 1040, 7200)
	_expect_equal("global pause blocks harvest", int(paused_report.get("output_cycle_count", 0)), 0)
	_expect_equal("global pause keeps timer mature", ProductionSite.is_slot_ready(paused_state, 0, 1040), true)
	AutomationService.set_global_paused(paused_state, false, 1040)
	var resumed_report := AutomationService.settle(paused_state, 1040, 1040, 7200)
	_expect_equal("resume processes mature harvest", int(resumed_report.get("output_cycle_count", 0)), 1)


func _test_global_pause_resume_does_not_backfill() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 4}
	ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000)
	AutomationService.set_output_managed(state, "farm", 0, true)
	AutomationService.set_global_paused(state, true, 1000)
	var paused_report := AutomationService.settle(state, 1000, 1050, 7200)
	_expect_equal("pause boundary blocks settlement", int(paused_report.get("output_cycle_count", 0)), 0)
	AutomationService.set_global_paused(state, false, 1050)
	var resumed_report := AutomationService.settle(state, 1050, 1050, 7200)
	_expect_equal("resume boundary harvests one matured result", int(resumed_report.get("output_cycle_count", 0)), 1)
	_expect_equal("resume boundary harvest output", state.get_ingredient_count("wheat"), 3)
	_expect_equal("resume boundary preserves later inputs", state.get_ingredient_count("wheat_seed"), 2)
	if state.production_slots.size() == 1:
		var slot: Dictionary = state.production_slots[0]
		_expect_equal("resume boundary restart timestamp", int(slot.get("started_at_unix", 0)), 1050)
		_expect_equal("resume boundary next ready timestamp", int(slot.get("ready_at_unix", 0)), 1070)


func _test_explicit_offline_limit_caps_settlement() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 6}
	ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000)
	AutomationService.set_output_managed(state, "farm", 0, true)
	var report := AutomationService.settle(state, 1000, 1100, 40)
	_expect_equal("explicit offline limit cycles", int(report.get("output_cycle_count", 0)), 2)
	_expect_equal("explicit offline limit report end", int(report.get("to_unix", 0)), 1040)


func _test_overdue_slot_uses_ready_timestamp() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 4}
	ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000)
	AutomationService.set_output_managed(state, "farm", 0, true)
	var report := AutomationService.settle(state, 1060, 1080, 7200)
	_expect_equal("overdue slot catches up from ready timestamp", int(report.get("output_cycle_count", 0)), 4)
	_expect_equal("overdue slot catch-up output", state.get_ingredient_count("wheat"), 12)


func _test_malformed_managed_slot_terminates() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.managed_production_sites.append("farm")
	state.production_slots = [{
		"site_id": "farm",
		"slot_index": 0,
		"item_id": "missing_catalog_item",
		"started_at_unix": 1000,
		"duration_seconds": 20,
		"ready_at_unix": 1020
	}]
	var report := AutomationService.settle(state, 1000, 1020, 7200)
	_expect_equal("malformed managed slot has no cycles", int(report.get("output_cycle_count", 0)), 0)


func _test_event_limit_only_reports_remaining_events() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"rice_seed": 101}
	ProductionSite.start_slot(state, "farm", "rice_seed", 0, 0)
	AutomationService.set_output_managed(state, "farm", 0, true)
	var report := AutomationService.settle(state, 0, 200, 200, 100)
	_expect_equal("event limit exact cycle count", int(report.get("output_cycle_count", 0)), 100)
	_expect_equal("event limit with no remaining event", bool(report.get("event_limit_reached", true)), false)

	var capped_state = GameState.new_game()
	capped_state.level = 3
	capped_state.unlock_automation("output")
	capped_state.ingredient_inventory = {"rice_seed": 102}
	ProductionSite.start_slot(capped_state, "farm", "rice_seed", 0, 0)
	AutomationService.set_output_managed(capped_state, "farm", 0, true)
	var capped_report := AutomationService.settle(capped_state, 0, 202, 202, 100)
	_expect_equal("event limit with remaining event", bool(capped_report.get("event_limit_reached", false)), true)


func _test_kitchen_rule_fixture() -> void:
	var state = GameState.new_game()
	state.level = 1
	state.unlock_automation("kitchen")
	state.add_recipe("butter_cookie")
	var rule := {
		"id": "rule_cookie",
		"recipe_id": "butter_cookie",
		"device_id": "oven",
		"batches": 1,
		"target_stock": 3,
		"material_reserves": {},
		"priority": 0,
		"sort_order": 0,
		"enabled": true
	}
	var saved := AutomationService.save_kitchen_rule(state, rule)
	_expect_equal("kitchen fixture saves", bool(saved.get("ok", false)), true)
	_expect_equal("kitchen fixture id", String(saved.get("rule", {}).get("id", "")), "rule_cookie")
	var generated := AutomationService.save_kitchen_rule(state, {
		"recipe_id": "butter_cookie",
		"device_id": "oven",
		"batches": 1,
		"target_stock": 0
	})
	_expect_equal("generated id needs capacity upgrade", bool(generated.get("ok", false)), false)
	state.automation_upgrades["kitchen_rules_3"] = true
	var generated_after_upgrade := AutomationService.save_kitchen_rule(state, {
		"recipe_id": "butter_cookie",
		"device_id": "oven",
		"batches": 1,
		"target_stock": 0
	})
	_expect_equal("generated id saves after capacity upgrade", bool(generated_after_upgrade.get("ok", false)), true)
	_expect_equal("generated id is persistent sequence", String(generated_after_upgrade.get("rule", {}).get("id", "")), "rule_1")


func _test_kitchen_three_batch_capacity_is_atomic() -> void:
	var normalization_state = GameState.new_game()
	normalization_state.level = 3
	normalization_state.unlock_automation("kitchen")
	normalization_state.add_recipe("milk_pudding")
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("kitchen")
	state.add_recipe("milk_pudding")
	state.ingredient_inventory = {"milk": 20, "egg": 20, "sugar": 20}
	var invalid_five := _milk_pudding_rule("rule_five", true)
	invalid_five["batches"] = 5
	var normalized_five: Dictionary = AutomationService.save_kitchen_rule(normalization_state, invalid_five)
	_expect_equal("legacy five-batch kitchen rule is accepted", bool(normalized_five.get("ok", false)), true)
	_expect_equal("legacy five-batch kitchen rule normalizes to one", int(normalized_five.get("rule", {}).get("batches", 0)), 1)
	var rule := _milk_pudding_rule("rule_three", true)
	rule["batches"] = 3
	rule["target_stock"] = 30
	var normalized_three: Dictionary = AutomationService.save_kitchen_rule(state, rule)
	_expect_equal("legacy three-batch kitchen rule saves", bool(normalized_three.get("ok", false)), true)
	_expect_equal("legacy three-batch kitchen rule normalizes to one", int(normalized_three.get("rule", {}).get("batches", 0)), 1)
	_expect_equal("manual capacity fixture starts", state.queue_recipe_production("milk_pudding", 1, 1000), true)
	var milk_before: int = state.get_ingredient_count("milk")
	var egg_before: int = state.get_ingredient_count("egg")
	var sugar_before: int = state.get_ingredient_count("sugar")
	AutomationService.settle(state, 1000, 1000, -1)
	_expect_equal("single-batch rule does not start beside the same recipe", state.recipe_production_queue.size(), 1)
	_expect_equal("capacity rejection keeps milk", state.get_ingredient_count("milk"), milk_before)
	_expect_equal("capacity rejection keeps egg", state.get_ingredient_count("egg"), egg_before)
	_expect_equal("capacity rejection keeps sugar", state.get_ingredient_count("sugar"), sugar_before)
	_expect_equal(
		"capacity pause reason",
		String(AutomationService.kitchen_rule_status(state, "rule_three").get("reason", {}).get("code", "")),
		"capacity_reached"
	)


func _test_kitchen_generated_rule_id_skips_explicit_sequence() -> void:
	var state = GameState.new_game()
	state.level = 1
	state.unlock_automation("kitchen")
	state.automation_upgrades["kitchen_rules_3"] = true
	state.add_recipe("butter_cookie")
	var explicit_rule := {
		"id": "rule_1",
		"recipe_id": "butter_cookie",
		"device_id": "oven",
		"batches": 1,
		"target_stock": 0
	}
	var explicit_saved := AutomationService.save_kitchen_rule(state, explicit_rule)
	_expect_equal("explicit sequence rule saves", bool(explicit_saved.get("ok", false)), true)
	_expect_equal("explicit sequence advances next id", int(state.kitchen_rule_next_id), 2)
	var generated := AutomationService.save_kitchen_rule(state, {
		"recipe_id": "butter_cookie",
		"device_id": "oven",
		"batches": 1,
		"target_stock": 0
	})
	_expect_equal("generated rule after explicit sequence saves", bool(generated.get("ok", false)), true)
	_expect_equal("generated rule after explicit sequence is created", bool(generated.get("created", false)), true)
	_expect_equal("generated rule skips explicit sequence id", String(generated.get("rule", {}).get("id", "")), "rule_2")
	_expect_equal("explicit and generated rules both remain", state.kitchen_automation_rules.size(), 2)


func _test_output_to_kitchen_chain() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.unlock_automation("kitchen")
	state.add_recipe("milk_pudding")
	state.ingredient_inventory = {"calf": 1, "egg": 1, "sugar": 1}
	if not ProductionSite.start_slot(state, "ranch", "calf", 0, 1000):
		_fail("chain ranch slot should start")
	if not bool(AutomationService.set_output_managed(state, "ranch", 0, true).get("ok", false)):
		_fail("chain ranch slot should become managed")
	var saved := AutomationService.save_kitchen_rule(state, {
		"id": "rule_milk_pudding",
		"recipe_id": "milk_pudding",
		"device_id": "chiller",
		"batches": 1,
		"target_stock": 3,
		"material_reserves": {},
		"priority": 0,
		"sort_order": 0,
		"enabled": true
	})
	_expect_equal("chain kitchen rule saves", bool(saved.get("ok", false)), true)
	_expect_equal("chain starts without preloaded milk", state.get_ingredient_count("milk"), 0)
	var report := AutomationService.settle(state, 1000, 1050, 7200)
	_expect_equal("chain keeps all harvested milk for online kitchen", state.get_ingredient_count("milk"), 2)
	_expect_equal("offline does not consume kitchen egg", state.get_ingredient_count("egg"), 1)
	_expect_equal("offline does not consume kitchen sugar", state.get_ingredient_count("sugar"), 1)
	_expect_equal("offline does not complete pudding", state.get_product_count("milk_pudding"), 0)
	_expect_equal("offline does not advance kitchen made count", int(state.get_recipe_growth("milk_pudding").get("made_count", 0)), 0)
	_expect_equal("offline report has no pudding output", int(report.get("product_outputs", {}).get("milk_pudding", 0)), 0)
	_expect_equal("chain does not auto-list product", state.display_items.is_empty(), true)


func _test_kitchen_growth_report() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("kitchen")
	state.add_recipe("milk_pudding")
	state.device_growth["chiller"] = {"level": 3, "research_count": 30, "production_batch_count": 0}
	state.recipe_growth["milk_pudding"] = {
		"mastery_level": 0,
		"stage_made_batches": 29,
		"stage_effective_rounds": 10,
		"stage_synergy_rounds": 3,
		"made_count": 2,
		"sold_count": 3,
		"adjacency_trigger_count": 0
	}
	state.ingredient_inventory = {"milk": 1, "egg": 1, "sugar": 1}
	var saved := AutomationService.save_kitchen_rule(state, _milk_pudding_rule("rule_growth", true))
	_expect_equal("growth report rule saves", bool(saved.get("ok", false)), true)
	var report := AutomationService.settle(state, 1000, 1030)
	var growth: Dictionary = report.get("growth", {}).get("milk_pudding", {}) if report.get("growth", {}) is Dictionary else {}
	var completed_slots: Array = report.get("completed_recipe_slots", [])
	_expect_equal("growth report exposes completed slot identity", completed_slots.size(), 1)
	if completed_slots.size() == 1:
		_expect_equal("completed slot source", String((completed_slots[0] as Dictionary).get("source", "")), "automation")
	_expect_equal("growth report made amount", int(growth.get("made_count", 0)), 3)
	_expect_equal("growth report real batch amount", int(growth.get("made_batches", 0)), 1)
	_expect_equal("growth report earliest mastery", int(growth.get("before_mastery", -1)), 0)
	_expect_equal("growth report latest mastery", int(growth.get("after_mastery", -1)), 1)
	var automated_ready_record: Dictionary = state.production_ready_recipe_record("milk_pudding")
	_expect_equal("automated completion registers persistent row identity", automated_ready_record.is_empty(), false)
	_expect_equal("growth report before stage", String(growth.get("before_stage", "")), "试作品")
	_expect_equal("growth report after stage", String(growth.get("after_stage", "")), "人气款")


func _test_kitchen_manual_queue_has_priority() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("kitchen")
	state.add_recipe("milk_pudding")
	state.ingredient_inventory = {"milk": 2, "egg": 2, "sugar": 2}
	_expect_equal("manual queue starts", state.queue_recipe_production("milk_pudding", 1, 1000), true)
	var saved := AutomationService.save_kitchen_rule(state, _milk_pudding_rule("rule_manual", true))
	_expect_equal("manual priority rule saves", bool(saved.get("ok", false)), true)
	AutomationService.settle(state, 1000, 1000)
	_expect_equal("manual queue blocks same-recipe automation", state.recipe_production_queue.size(), 1)
	_expect_equal("manual queue retains source", String(state.recipe_production_queue[0].get("source", "")), "manual")
	_expect_equal(
		"manual queue pauses same-recipe rule at capacity",
		String(AutomationService.kitchen_rule_status(state, "rule_manual").get("reason", {}).get("code", "")),
		"capacity_reached"
	)


func _test_kitchen_priority_target_and_reserve_gates() -> void:
	var priority_state = GameState.new_game()
	priority_state.level = 3
	priority_state.unlock_automation("kitchen")
	priority_state.automation_upgrades["kitchen_all"] = true
	priority_state.automation_upgrades["kitchen_priority"] = true
	priority_state.add_recipe("milk_pudding")
	priority_state.ingredient_inventory = {"milk": 2, "egg": 2, "sugar": 2}
	var low := _milk_pudding_rule("rule_low", true)
	low["priority"] = 1
	low["sort_order"] = 0
	var high := _milk_pudding_rule("rule_high", true)
	high["priority"] = 5
	high["sort_order"] = 9
	_expect_equal("low priority rule saves", bool(AutomationService.save_kitchen_rule(priority_state, low).get("ok", false)), true)
	_expect_equal("high priority rule saves", bool(AutomationService.save_kitchen_rule(priority_state, high).get("ok", false)), true)
	AutomationService.settle(priority_state, 1000, 1000)
	_expect_equal("higher priority rule starts first", String(priority_state.recipe_production_queue[0].get("automation_rule_id", "")), "rule_high")
	_expect_equal("same-recipe automation rules start only one batch", priority_state.recipe_production_queue.size(), 1)
	_expect_equal(
		"lower priority same-recipe rule pauses",
		String(AutomationService.kitchen_rule_status(priority_state, "rule_low").get("reason", {}).get("code", "")),
		"capacity_reached"
	)

	var target_state = GameState.new_game()
	target_state.level = 3
	target_state.unlock_automation("kitchen")
	target_state.add_recipe("milk_pudding")
	target_state.add_product("milk_pudding", 3)
	target_state.ingredient_inventory = {"milk": 1, "egg": 1, "sugar": 1}
	_expect_equal("target rule saves", bool(AutomationService.save_kitchen_rule(target_state, _milk_pudding_rule("rule_target", true)).get("ok", false)), true)
	AutomationService.settle(target_state, 1000, 1000)
	_expect_equal("target stock pauses rule", String(AutomationService.kitchen_rule_status(target_state, "rule_target").get("reason", {}).get("code", "")), "target_reached")

	var reserve_state = GameState.new_game()
	reserve_state.level = 3
	reserve_state.unlock_automation("kitchen")
	reserve_state.automation_upgrades["kitchen_inventory_policy"] = true
	reserve_state.add_recipe("milk_pudding")
	reserve_state.ingredient_inventory = {"milk": 1, "egg": 1, "sugar": 1}
	var reserve_rule := _milk_pudding_rule("rule_reserve", true)
	reserve_rule["material_reserves"] = {"sugar": 1}
	_expect_equal("reserve rule saves", bool(AutomationService.save_kitchen_rule(reserve_state, reserve_rule).get("ok", false)), true)
	AutomationService.settle(reserve_state, 1000, 1000)
	var reserve_reason: Dictionary = AutomationService.kitchen_rule_status(reserve_state, "rule_reserve").get("reason", {})
	_expect_equal("reserve blocks automatic start", String(reserve_reason.get("code", "")), "material_reserve")
	_expect_equal("reserve reports blocked material", String(reserve_reason.get("item_id", "")), "sugar")


func _test_kitchen_offline_rule_and_save_sanitation() -> void:
	var offline_state = GameState.new_game()
	offline_state.level = 3
	offline_state.unlock_automation("kitchen")
	offline_state.add_recipe("milk_pudding")
	offline_state.ingredient_inventory = {"milk": 1, "egg": 1, "sugar": 1}
	_expect_equal("kitchen rule saves", bool(AutomationService.save_kitchen_rule(offline_state, _milk_pudding_rule("rule_online", false)).get("ok", false)), true)
	AutomationService.settle(offline_state, 1000, 1050, 7200)
	_expect_equal("kitchen rule does not start offline", offline_state.recipe_production_queue.size(), 0)
	AutomationService.settle(offline_state, 1050, 1050)
	_expect_equal("kitchen rule starts online", offline_state.recipe_production_queue.size(), 1)
	AutomationService.settle(offline_state, 1080, 1080)
	_expect_equal("kitchen rule completes online", offline_state.get_product_count("milk_pudding"), 3)

	var saved_rule := _milk_pudding_rule("rule_saved", true)
	saved_rule["material_reserves"] = {"sugar": 2}
	var loaded = GameState.from_dict({
		"automation_upgrades": {},
		"kitchen_automation_rules": [
			{"id": "bad", "recipe_id": "missing_recipe", "device_id": "oven"},
			saved_rule,
			_milk_pudding_rule("rule_saved_2", true)
		],
		"recipe_production_queue": [{"recipe_id": "milk_pudding", "device_id": "chiller", "batches": 1, "output_count": 3, "started_at_unix": 1, "duration_seconds": 30, "ready_at_unix": 31}]
	})
	_expect_equal("legacy queue defaults to manual source", String(loaded.recipe_production_queue[0].get("source", "")), "manual")
	_expect_equal("invalid saved kitchen rule removed", loaded.kitchen_automation_rules.size(), 2)
	_expect_equal("legacy reserve is cleared without upgrade", (loaded.kitchen_automation_rules[0].get("material_reserves", {}) as Dictionary).is_empty(), true)
	_expect_equal("over-limit saved rule is retained disabled", bool(loaded.kitchen_automation_rules[1].get("enabled", true)), false)
	_expect_equal("invalid save warning is recorded", String((loaded.pending_automation_report.get("pauses", []) as Array)[0].get("reason", {}).get("code", "")), "invalid_recipe")


func _test_kitchen_pause_resume_uses_resume_floor() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("kitchen")
	state.add_recipe("milk_pudding")
	state.ingredient_inventory = {"milk": 2, "egg": 2, "sugar": 2}
	var rule := _milk_pudding_rule("rule_resume_floor", true)
	rule["target_stock"] = 6
	_expect_equal("resume-floor rule saves", bool(AutomationService.save_kitchen_rule(state, rule).get("ok", false)), true)
	AutomationService.settle(state, 1000, 1000)
	_expect_equal("resume-floor queue starts", state.recipe_production_queue.size(), 1)
	AutomationService.set_global_paused(state, true, 1000)
	AutomationService.settle(state, 1000, 1050)
	AutomationService.set_global_paused(state, false, 1050)
	var report := AutomationService.settle(state, 1050, 1050)
	_expect_equal("resume-floor completes automatic queue", int(report.get("product_outputs", {}).get("milk_pudding", 0)), 3)
	_expect_equal("resume-floor starts next queue at resume boundary", int(state.recipe_production_queue[0].get("started_at_unix", 0)), 1050)


func _test_started_online_only_queue_blocks_offline_then_resumes_online() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("kitchen")
	state.add_recipe("milk_pudding")
	state.ingredient_inventory = {"milk": 2, "egg": 2, "sugar": 2}
	var rule := _milk_pudding_rule("rule_crosses_offline", false)
	rule["target_stock"] = 6
	_expect_equal("cross-offline rule saves", bool(AutomationService.save_kitchen_rule(state, rule).get("ok", false)), true)
	AutomationService.settle(state, 1000, 1000)
	_expect_equal("cross-offline queue starts online", state.recipe_production_queue.size(), 1)
	var duration_seconds := int(state.recipe_production_queue[0].get("duration_seconds", 0))
	var offline_report := AutomationService.settle(state, 1000, 1100, 7200)
	_expect_equal("cross-offline queue does not complete offline", state.get_product_count("milk_pudding"), 0)
	if state.recipe_production_queue.is_empty():
		_fail("cross-offline queue should remain pending")
	else:
		_expect_equal("cross-offline queue keeps remaining duration", int(state.recipe_production_queue[0].get("ready_at_unix", 0)), 1100 + duration_seconds)
	_expect_equal("cross-offline report has no product", int(offline_report.get("product_outputs", {}).get("milk_pudding", 0)), 0)
	var online_ready_unix := 1100 + duration_seconds
	var online_report := AutomationService.settle(state, online_ready_unix, online_ready_unix)
	_expect_equal("cross-offline queue completes online", int(online_report.get("product_outputs", {}).get("milk_pudding", 0)), 3)
	if state.recipe_production_queue.is_empty():
		_fail("cross-offline completion should start the next queue")
	else:
		_expect_equal("cross-offline restart uses online boundary", int(state.recipe_production_queue[0].get("started_at_unix", 0)), online_ready_unix)


func _test_eligible_kitchen_queue_keeps_normal_overdue_catch_up() -> void:
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("kitchen")
	state.add_recipe("milk_pudding")
	state.ingredient_inventory = {"milk": 2, "egg": 2, "sugar": 2}
	var rule := _milk_pudding_rule("rule_overdue_online", true)
	rule["target_stock"] = 6
	_expect_equal("overdue-online rule saves", bool(AutomationService.save_kitchen_rule(state, rule).get("ok", false)), true)
	AutomationService.settle(state, 1000, 1000)
	var report := AutomationService.settle(state, 1060, 1060)
	_expect_equal("overdue-online queue catches up both completed cycles", int(report.get("product_outputs", {}).get("milk_pudding", 0)), 6)
	_expect_equal("overdue-online queue stops only after target stock", state.recipe_production_queue.is_empty(), true)


func _test_coin_funded_output_restart_reports_insufficient_coins() -> void:
	var state = GameState.new_game()
	state.level = 4
	state.unlock_automation("output")
	_expect_equal("coin-funded coffee slot starts", ProductionSite.start_slot(state, "forest", "coffee", 0, 1000), true)
	state.coins = 0
	_expect_equal("coin-funded coffee slot becomes managed", bool(AutomationService.set_output_managed(state, "forest", 0, true).get("ok", false)), true)
	AutomationService.settle(state, 1000, 1028, 7200)
	var slot: Dictionary = state.production_slots[0]
	var reason: Dictionary = slot.get("pause_reason", {})
	_expect_equal("coin-funded restart reports insufficient coins", String(reason.get("code", "")), "insufficient_coins")
	_expect_equal("coin-funded restart reports cost", int(reason.get("required", 0)), 4)
	_expect_equal("coin-funded restart reports available coins", int(reason.get("available", -1)), 0)


func _test_notification_metadata_roundtrip() -> void:
	var state = GameState.new_game()
	state.enqueue_notification("旧通知", "两参数仍可使用")
	state.enqueue_notification("自动化交班简报", "处理离线自动化结果。", {
		"kind": "automation_report",
		"report_id": "1000:1080",
		"report": {"from_unix": 1000, "to_unix": 1080, "outputs": {"wheat": 3}}
	})
	var loaded = GameState.from_dict(state.to_dict())
	_expect_equal("legacy notification keeps empty metadata", (loaded.pending_notifications[0].get("metadata", {}) as Dictionary).is_empty(), true)
	_expect_equal("notification metadata kind roundtrip", String(loaded.pending_notifications[1].get("metadata", {}).get("kind", "")), "automation_report")
	_expect_equal("notification metadata report roundtrip", int(loaded.pending_notifications[1].get("metadata", {}).get("report", {}).get("outputs", {}).get("wheat", 0)), 3)
	var sanitized = GameState.from_dict({"pending_notifications": [
		{"title": "保留", "body": "正文", "metadata": {"kind": "automation_report"}},
		{"title": "旧档", "body": "没有 metadata"},
		{"title": "忽略", "body": "非法 metadata", "metadata": "bad"}
	]})
	_expect_equal("dictionary metadata survives sanitation", String(sanitized.pending_notifications[0].get("metadata", {}).get("kind", "")), "automation_report")
	_expect_equal("legacy missing metadata sanitizes empty", (sanitized.pending_notifications[1].get("metadata", {}) as Dictionary).is_empty(), true)
	_expect_equal("invalid metadata sanitizes empty", (sanitized.pending_notifications[2].get("metadata", {}) as Dictionary).is_empty(), true)


func _test_unread_displaying_report_survives_empty_later_load() -> void:
	var path := OS.get_temp_dir().path_join("automation_unread_report_restart.json")
	_cleanup_save_path(path)
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.automation_last_settled_unix = 1000
	state.pending_automation_report = {
		"from_unix": 900,
		"to_unix": 1000,
		"event_count": 1,
		"outputs": {"wheat": 3},
		"ui_displaying": true
	}
	_expect_equal("unread-report fixture saves", SaveSystem.save_game(state, path, 1000), true)
	var loaded = SaveSystem.load_game(path, path + ".broken.json", 1001)
	_expect_equal("later empty settlement preserves displaying report", int(loaded.pending_automation_report.get("from_unix", 0)), 900)
	_expect_equal("later empty settlement keeps report display marker", bool(loaded.pending_automation_report.get("ui_displaying", false)), true)
	_expect_equal("later empty settlement does not enqueue empty report", loaded.pending_notifications.size(), 0)
	_cleanup_save_path(path)


func _test_offline_load_settles_and_is_idempotent() -> void:
	var path := OS.get_temp_dir().path_join("automation_offline_settlement.json")
	_cleanup_save_path(path)
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 4, "strawberry_seed": 1}
	ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000)
	ProductionSite.start_slot(state, "forest", "strawberry_seed", 0, 1000)
	AutomationService.set_output_managed(state, "farm", 0, true)
	state.automation_last_settled_unix = 1000
	_expect_equal("offline fixture saves at injected time", SaveSystem.save_game(state, path, 1000), true)
	var loaded = SaveSystem.load_game(path, path + ".broken.json", 1080)
	_expect_equal("offline load harvests managed cycles", loaded.get_ingredient_count("wheat"), 12)
	_expect_equal("offline load advances settlement baseline", loaded.automation_last_settled_unix, 1080)
	_expect_equal("offline load persists report cycles", int(loaded.pending_automation_report.get("output_cycle_count", 0)), 4)
	_expect_equal("offline load keeps unmanaged ready prompt", loaded.offline_ready_count, 1)
	_expect_equal("offline load marks unmanaged slot ready", bool(loaded.production_slots[1].get("ready", false)), true)
	_expect_equal("eventful offline load enqueues one report notification", loaded.pending_notifications.size(), 1)
	if not loaded.pending_notifications.is_empty():
		var metadata: Dictionary = loaded.pending_notifications[0].get("metadata", {})
		_expect_equal("offline report notification kind", String(metadata.get("kind", "")), "automation_report")
		_expect_equal("offline report notification carries result", int(metadata.get("report", {}).get("output_cycle_count", 0)), 4)
	var reloaded = SaveSystem.load_game(path, path + ".broken.json", 1080)
	_expect_equal("same-time reload does not duplicate harvest", reloaded.get_ingredient_count("wheat"), 12)
	_expect_equal("same-time reload keeps unmanaged ready prompt", reloaded.offline_ready_count, 1)
	_expect_equal("same-time reload does not duplicate report notification", reloaded.pending_notifications.size(), 1)
	var later_reload = SaveSystem.load_game(path, path + ".broken.json", 1090)
	_expect_equal("later reload keeps unharvested manual prompt", later_reload.offline_ready_count, 1)
	_expect_equal("no-event later reload keeps only original report notification", later_reload.pending_notifications.size(), 1)
	_cleanup_save_path(path)


func _test_first_offline_load_only_records_baseline() -> void:
	var path := OS.get_temp_dir().path_join("automation_offline_first_baseline.json")
	_cleanup_save_path(path)
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 2}
	ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000)
	AutomationService.set_output_managed(state, "farm", 0, true)
	_expect_equal("first-baseline fixture saves", SaveSystem.save_game(state, path, 1000), true)
	var loaded = SaveSystem.load_game(path, path + ".broken.json", 1080)
	_expect_equal("first load without baseline produces nothing", loaded.get_ingredient_count("wheat"), 0)
	_expect_equal("first load records settlement baseline", loaded.automation_last_settled_unix, 1080)
	_expect_equal("first load report has no cycles", int(loaded.pending_automation_report.get("event_count", 0)), 0)
	_expect_equal("first baseline does not enqueue empty report", loaded.pending_notifications.size(), 0)
	_cleanup_save_path(path)


func _test_clock_rollback_yields_nothing() -> void:
	var path := OS.get_temp_dir().path_join("automation_offline_clock_rollback.json")
	_cleanup_save_path(path)
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 2}
	ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000)
	AutomationService.set_output_managed(state, "farm", 0, true)
	state.automation_last_settled_unix = 1200
	_expect_equal("rollback fixture saves", SaveSystem.save_game(state, path, 1200), true)
	var loaded = SaveSystem.load_game(path, path + ".broken.json", 1100)
	_expect_equal("clock rollback produces nothing", loaded.get_ingredient_count("wheat"), 0)
	_expect_equal("clock rollback preserves high-water baseline", loaded.automation_last_settled_unix, 1200)
	var pauses: Array = loaded.pending_automation_report.get("pauses", [])
	_expect_equal("clock rollback emits one pause", pauses.size(), 1)
	if not pauses.is_empty():
		_expect_equal("clock rollback pause code", String(pauses[0].get("reason", {}).get("code", "")), "clock_rollback")
	_expect_equal("clock rollback enqueues one actionable report", loaded.pending_notifications.size(), 1)
	_cleanup_save_path(path)


func _test_offline_duration_cap_discards_backlog() -> void:
	var path := OS.get_temp_dir().path_join("automation_offline_duration_cap.json")
	_cleanup_save_path(path)
	var state = GameState.new_game()
	state.level = 4
	state.unlock_automation("output")
	state.coins = 5000
	ProductionSite.start_slot(state, "forest", "coffee", 0, 1000)
	AutomationService.set_output_managed(state, "forest", 0, true)
	state.automation_last_settled_unix = 1000
	_expect_equal("duration-cap fixture saves", SaveSystem.save_game(state, path, 1000), true)
	var loaded = SaveSystem.load_game(path, path + ".broken.json", 10000)
	_expect_equal("base offline duration settles only two hours", int(loaded.pending_automation_report.get("output_cycle_count", 0)), 257)
	_expect_equal("duration cap still advances load baseline", loaded.automation_last_settled_unix, 10000)
	var harvested: int = loaded.get_ingredient_count("coffee")
	var reloaded = SaveSystem.load_game(path, path + ".broken.json", 10000)
	_expect_equal("same-time reload cannot reclaim duration backlog", reloaded.get_ingredient_count("coffee"), harvested)
	var later_reload = SaveSystem.load_game(path, path + ".broken.json", 10001)
	_expect_equal("later reload cannot reclaim duration backlog", later_reload.get_ingredient_count("coffee"), harvested)
	_cleanup_save_path(path)

	var quiet_path := OS.get_temp_dir().path_join("automation_offline_quiet_duration_cap.json")
	_cleanup_save_path(quiet_path)
	var quiet_state = GameState.new_game()
	quiet_state.level = 3
	quiet_state.unlock_automation("output")
	quiet_state.automation_last_settled_unix = 1000
	_expect_equal("quiet duration-cap fixture saves", SaveSystem.save_game(quiet_state, quiet_path, 1000), true)
	var quiet_loaded = SaveSystem.load_game(quiet_path, quiet_path + ".broken.json", 10000)
	_expect_equal("quiet duration truncation still enqueues report", quiet_loaded.pending_notifications.size(), 1)
	if not quiet_loaded.pending_notifications.is_empty():
		_expect_equal("quiet duration report marks truncation", bool(quiet_loaded.pending_notifications[0].get("metadata", {}).get("report", {}).get("truncated", false)), true)
	_cleanup_save_path(quiet_path)


func _test_offline_event_cap_discards_backlog() -> void:
	var path := OS.get_temp_dir().path_join("automation_offline_event_cap.json")
	_cleanup_save_path(path)
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.automation_upgrades["offline_duration_2"] = true
	state.ingredient_inventory = {"rice_seed": 102}
	ProductionSite.start_slot(state, "farm", "rice_seed", 0, 1000)
	AutomationService.set_output_managed(state, "farm", 0, true)
	state.automation_last_settled_unix = 1000
	_expect_equal("event-cap fixture saves", SaveSystem.save_game(state, path, 1000), true)
	var loaded = SaveSystem.load_game(path, path + ".broken.json", 1204, 100)
	_expect_equal("offline event safety cap", int(loaded.pending_automation_report.get("output_cycle_count", 0)), 100)
	_expect_equal("offline event cap is reported", bool(loaded.pending_automation_report.get("event_limit_reached", false)), true)
	_expect_equal("event cap still advances load baseline", loaded.automation_last_settled_unix, 1204)
	var harvested: int = loaded.get_ingredient_count("rice")
	var reloaded = SaveSystem.load_game(path, path + ".broken.json", 1204, 100)
	_expect_equal("same-time reload cannot reclaim event backlog", reloaded.get_ingredient_count("rice"), harvested)
	var later_reload = SaveSystem.load_game(path, path + ".broken.json", 1205, 100)
	_expect_equal("later reload cannot reclaim event backlog", later_reload.get_ingredient_count("rice"), harvested)
	_cleanup_save_path(path)


func _test_truncation_reanchors_only_automatic_kitchen_queue() -> void:
	var automatic_state = GameState.new_game()
	automatic_state.level = 3
	automatic_state.unlock_automation("kitchen")
	automatic_state.add_recipe("milk_pudding")
	automatic_state.ingredient_inventory = {"milk": 1, "egg": 1, "sugar": 1}
	_expect_equal("automatic reanchor fixture queues", automatic_state.queue_recipe_production("milk_pudding", 1, 8190, "automation", "rule_reanchor"), true)
	automatic_state.automation_last_settled_unix = 1000
	var automatic_duration := int(automatic_state.recipe_production_queue[0].get("duration_seconds", 0))
	SaveSystem.apply_offline_automation(automatic_state, 10000)
	_expect_equal("offline shifts automatic kitchen start", int(automatic_state.recipe_production_queue[0].get("started_at_unix", 0)), 17190)
	_expect_equal("offline preserves automatic kitchen duration", int(automatic_state.recipe_production_queue[0].get("ready_at_unix", 0)), 17190 + automatic_duration)

	var manual_state = GameState.new_game()
	manual_state.level = 3
	manual_state.add_recipe("milk_pudding")
	manual_state.ingredient_inventory = {"milk": 1, "egg": 1, "sugar": 1}
	_expect_equal("manual control fixture queues", manual_state.queue_recipe_production("milk_pudding", 1, 8190), true)
	manual_state.automation_last_settled_unix = 1000
	SaveSystem.apply_offline_automation(manual_state, 10000)
	_expect_equal("offline automation does not shift manual kitchen start", int(manual_state.recipe_production_queue[0].get("started_at_unix", 0)), 8190)
	_expect_equal("offline automation keeps manual ready timestamp", int(manual_state.recipe_production_queue[0].get("ready_at_unix", 0)), 8192)


func _test_offline_save_failure_rolls_back() -> void:
	var path := OS.get_temp_dir().path_join("automation_offline_save_failure.json")
	_cleanup_save_path(path)
	var state = GameState.new_game()
	state.level = 3
	state.unlock_automation("output")
	state.ingredient_inventory = {"wheat_seed": 2}
	ProductionSite.start_slot(state, "farm", "wheat_seed", 0, 1000)
	AutomationService.set_output_managed(state, "farm", 0, true)
	state.automation_last_settled_unix = 1000
	_expect_equal("save-failure fixture saves", SaveSystem.save_game(state, path, 1000), true)
	var temp_abs := ProjectSettings.globalize_path(path + ".tmp")
	_expect_equal("save-failure temp blocker is created", DirAccess.make_dir_absolute(temp_abs), OK)
	var loaded = SaveSystem.load_game(path, path + ".broken.json", 1080)
	_expect_equal("failed atomic save rolls inventory back", loaded.get_ingredient_count("wheat"), 0)
	_expect_equal("failed atomic save rolls baseline back", loaded.automation_last_settled_unix, 1000)
	_expect_equal("failed atomic save hides unsaved report", loaded.pending_automation_report.is_empty(), true)
	_expect_equal("failed atomic save records diagnostic", loaded.feedback_log.has("offline_automation_save_failed"), true)
	DirAccess.remove_absolute(temp_abs)
	_cleanup_save_path(path)


func _cleanup_save_path(path: String) -> void:
	for suffix: String in ["", ".broken.json", ".tmp", ".previous"]:
		var target := path + suffix
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
		elif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))


func _milk_pudding_rule(rule_id: String, _unused_legacy_mode: bool) -> Dictionary:
	return {
		"id": rule_id,
		"recipe_id": "milk_pudding",
		"device_id": "chiller",
		"batches": 1,
		"target_stock": 3,
		"material_reserves": {},
		"priority": 0,
		"sort_order": 0,
		"enabled": true
	}


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _fail(message: String) -> void:
	failures.append(message)
