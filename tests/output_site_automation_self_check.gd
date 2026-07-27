extends SceneTree

const GAME_STATE_PATH := "res://scripts/game_state.gd"
const AUTOMATION_SERVICE_PATH := "res://scripts/automation_service.gd"
const PRODUCTION_SITE_PATH := "res://scripts/production_site.gd"
const OUTPUT_SITE_REGION_SCENE_PATH := "res://scenes/ui/pages/output_site_region.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state_script := load(GAME_STATE_PATH)
	var automation_service_script := load(AUTOMATION_SERVICE_PATH)
	var production_site_script := load(PRODUCTION_SITE_PATH)
	_expect(game_state_script != null, "GameState should load")
	_expect(automation_service_script != null, "AutomationService should load")
	_expect(production_site_script != null, "ProductionSite should load")
	if game_state_script == null or automation_service_script == null or production_site_script == null:
		_finish()
		return

	var state = game_state_script.new_game()
	_expect(_has_property(state, "managed_production_sites"), "GameState should store managed production sites")
	_expect(automation_service_script.has_method("set_output_site_managed"), "AutomationService should toggle a whole output site")
	_expect(automation_service_script.has_method("output_site_limit"), "AutomationService should expose a managed-site limit")
	if not _has_property(state, "managed_production_sites") or not automation_service_script.has_method("set_output_site_managed") or not automation_service_script.has_method("output_site_limit"):
		_finish()
		return

	state.level = 3
	state.unlock_automation("output")
	_expect(automation_service_script.output_site_limit(state) == 1, "base automation should manage one output site")
	_expect(bool(automation_service_script.set_output_site_managed(state, "farm", true).get("ok", false)), "farm site should become managed")
	_expect(state.managed_production_sites == ["farm"], "managed output state should contain one site id")
	_expect(not bool(automation_service_script.set_output_site_managed(state, "ranch", true).get("ok", true)), "second site should be rejected before capacity upgrade")
	state.automation_upgrades["output_capacity_1"] = true
	_expect(automation_service_script.output_site_limit(state) == 2, "first capacity upgrade should manage two sites")
	_expect(bool(automation_service_script.set_output_site_managed(state, "ranch", true).get("ok", false)), "second site should unlock after capacity upgrade")

	var settlement_state = game_state_script.new_game()
	settlement_state.level = 3
	settlement_state.unlock_automation("output")
	settlement_state.production_slot_unlocks["farm"] = 2
	settlement_state.ingredient_inventory = {"wheat_seed": 2, "rice_seed": 2, "calf": 1}
	_expect(production_site_script.start_slot(settlement_state, "farm", "wheat_seed", 0, 1000), "farm slot 0 should start")
	_expect(production_site_script.start_slot(settlement_state, "farm", "rice_seed", 1, 1000), "farm slot 1 should start")
	_expect(production_site_script.start_slot(settlement_state, "ranch", "calf", 0, 1000), "ranch slot should start")
	automation_service_script.set_output_site_managed(settlement_state, "farm", true)
	var report: Dictionary = automation_service_script.settle(settlement_state, 1000, 1080, 7200)
	_expect(int(report.get("output_cycle_count", 0)) >= 4, "managed farm should settle all active farm slots")
	_expect(settlement_state.get_ingredient_count("wheat") > 0, "managed farm should harvest wheat")
	_expect(settlement_state.get_ingredient_count("rice") > 0, "managed farm should harvest rice")
	_expect(settlement_state.get_ingredient_count("milk") == 0, "unmanaged ranch should not be harvested")

	var loaded = game_state_script.from_dict({
		"production_slot_unlocks": {"farm": 2, "ranch": 1},
		"managed_production_slots": ["farm:0", "farm:1", "ranch:0"]
	})
	_expect(loaded.managed_production_sites == ["farm", "ranch"], "legacy managed slots should migrate to unique managed sites")
	var saved: Dictionary = loaded.to_dict()
	_expect(saved.get("managed_production_sites", []) == ["farm", "ranch"], "managed sites should persist under the site-level save field")
	loaded.unlock_automation("output")
	_expect(bool(automation_service_script.set_output_site_managed(loaded, "farm", false).get("ok", false)), "migrated farm site should be removable")
	_expect(not loaded.is_output_site_managed("farm"), "disabling a migrated site should not be overridden by legacy slot data")

	var release_state = game_state_script.new_game()
	release_state.level = 3
	release_state.unlock_automation("output")
	release_state.ingredient_inventory = {"wheat_seed": 1, "rice_seed": 1}
	_expect(production_site_script.start_slot(release_state, "farm", "wheat_seed", 0, 1000), "release fixture should start wheat")
	automation_service_script.set_output_site_managed(release_state, "farm", true)
	automation_service_script.settle(release_state, 1000, 1020, 7200)
	_expect(release_state.production_slots.size() == 1 and bool((release_state.production_slots[0] as Dictionary).get("automation_paused", false)), "failed automatic restart should retain one paused placeholder")
	automation_service_script.set_output_site_managed(release_state, "farm", false)
	_expect(release_state.production_slots.is_empty(), "disabling site management should release paused restart placeholders")
	_expect(production_site_script.start_slot(release_state, "farm", "rice_seed", 0, 1030), "released slot should accept manual planting immediately")

	var retarget_state = game_state_script.new_game()
	retarget_state.level = 3
	retarget_state.unlock_automation("output")
	retarget_state.ingredient_inventory = {"wheat_seed": 1, "rice_seed": 1}
	_expect(production_site_script.start_slot(retarget_state, "farm", "wheat_seed", 0, 1000), "retarget fixture should start wheat")
	automation_service_script.set_output_site_managed(retarget_state, "farm", true)
	automation_service_script.settle(retarget_state, 1000, 1020, 7200)
	_expect(bool((retarget_state.production_slots[0] as Dictionary).get("automation_paused", false)), "exhausted wheat should pause automatic restart")
	_expect(production_site_script.set_next_item(retarget_state, 0, "rice_seed"), "paused slot should accept a different next target")
	var retargeted_slot: Dictionary = retarget_state.production_slots[0]
	_expect(String(retargeted_slot.get("item_id", "")) == "rice_seed", "available next target should become the active item")
	_expect(not bool(retargeted_slot.get("automation_paused", false)), "available next target should resume the paused slot")
	_expect(not retargeted_slot.has("queued_item_id"), "resumed next target should clear the queued marker")
	_expect(retarget_state.get_ingredient_count("rice_seed") == 0, "resuming the paused slot should consume the selected seed")
	var retarget_ready_at := int(retargeted_slot.get("ready_at_unix", 0))
	_expect(retarget_ready_at > 0, "resumed next target should receive a new completion time")
	automation_service_script.settle(retarget_state, retarget_ready_at - 1, retarget_ready_at, 7200)
	_expect(retarget_state.get_ingredient_count("rice") > 0, "resumed next target should complete under site management")

	var restock_state = game_state_script.new_game()
	restock_state.level = 3
	restock_state.unlock_automation("output")
	restock_state.ingredient_inventory = {"wheat_seed": 1}
	production_site_script.start_slot(restock_state, "farm", "wheat_seed", 0, 1000)
	automation_service_script.set_output_site_managed(restock_state, "farm", true)
	automation_service_script.settle(restock_state, 1000, 1020, 7200)
	_expect(production_site_script.set_next_item(restock_state, 0, "rice_seed"), "paused slot should remember an unavailable next target")
	var waiting_slot: Dictionary = restock_state.production_slots[0]
	_expect(String(waiting_slot.get("queued_item_id", "")) == "rice_seed", "unavailable next target should remain queued")
	_expect(String(waiting_slot.get("pause_reason", {}).get("item_id", "")) == "rice_seed", "pause reason should point to the selected next seed")
	restock_state.add_ingredient("rice_seed", 1)
	automation_service_script.settle(restock_state, 1030, 1100, 7200)
	_expect(restock_state.get_ingredient_count("rice") > 0, "replenishing the queued seed should resume site automation")

	var region_scene := load(OUTPUT_SITE_REGION_SCENE_PATH) as PackedScene
	var region = region_scene.instantiate() if region_scene != null else null
	_expect(region != null, "output site region should instantiate")
	if region != null:
		_expect(region.get_node_or_null("OutputSiteBox/OutputSiteBody/ProductionSummaryPanel/ProductionSummaryBox/ProductionSummaryHeader/OutputSiteAutomationToggle") != null, "output site summary header should expose one board-level automation toggle")
		region.free()

	_finish()


func _has_property(value, property_name: String) -> bool:
	for property: Dictionary in value.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Output site automation self-check passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)
