extends SceneTree

const AutomationService = preload("res://scripts/automation_service.gd")
const GameState = preload("res://scripts/game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect_legacy_showcase_paths_removed()
	_expect_offline_settlement_skips_kitchen_and_business_round()
	_finish()


func _expect_legacy_showcase_paths_removed() -> void:
	for path in [
		"res://scripts/showcase_auto_sale_service.gd",
		"res://scripts/showcase_auto_sale_service.gd.uid",
		"res://tests/showcase_auto_sale_service_self_check.gd",
		"res://tests/showcase_auto_sale_service_self_check.gd.uid"
	]:
		_expect_equal("legacy file removed: %s" % path, FileAccess.file_exists(path), false)
	var forbidden := [
		"ShowcaseAuto" + "SaleService",
		"plan_" + "offline",
		"offline_showcase_" + "batch",
		"_play_offline_showcase_" + "sale_summary",
		"sale_ready_at_" + "unix",
		"cycle_started_at_" + "unix",
		"run_" + "business(",
		"_run_" + "business("
	]
	for path in [
		"res://scripts/main_view.gd",
		"res://scripts/game_state.gd",
		"res://scripts/shop_simulation.gd"
	]:
		var source := FileAccess.get_file_as_string(path)
		for token in forbidden:
			_expect_equal("%s removes %s" % [path, token], source.find(token), -1)
	var kitchen_scene := FileAccess.get_file_as_string("res://scenes/ui/pages/kitchen_automation_panel.tscn")
	var kitchen_script := FileAccess.get_file_as_string("res://scripts/ui/pages/kitchen_automation_panel.gd")
	_expect_equal("kitchen scene removes offline toggle", kitchen_scene.find("Offline" + "Toggle"), -1)
	_expect_equal("kitchen script removes offline rule field", kitchen_script.find("allow_" + "offline"), -1)


func _expect_offline_settlement_skips_kitchen_and_business_round() -> void:
	var state = GameState.new_game()
	state.level = 4
	state.shop_level = 4
	state.unlock_automation("kitchen")
	state.add_recipe("milk_pudding")
	state.ingredient_inventory = {"milk": 2, "egg": 2, "sugar": 2}
	var saved := AutomationService.save_kitchen_rule(state, {
		"id": "rule_1",
		"recipe_id": "milk_pudding",
		"device_id": "chiller",
		"batches": 1,
		"target_stock": 10,
		"priority": 0,
		"material_reserves": {},
		"enabled": true
	})
	_expect_equal("kitchen rule fixture saves", bool(saved.get("ok", false)), true)
	AutomationService.settle(state, 1000, 1000)
	var queue_before: Array = state.recipe_production_queue.duplicate(true)
	var ingredients_before: Dictionary = state.ingredient_inventory.duplicate(true)
	var products_before: Dictionary = state.product_inventory.duplicate(true)
	state.active_business_round = {
		"round_id": 7,
		"phase": "running",
		"elapsed_ms": 12000,
		"remaining_ms": 18000,
		"environment": {"id": "locked"},
		"sale_events": []
	}
	state.pending_showcase_challenge = {"instance_id": "challenge:7"}
	state.pending_showcase_settlement = {"settlement_id": "pending"}
	var round_before: Dictionary = state.active_business_round.duplicate(true)
	var challenge_before: Dictionary = state.pending_showcase_challenge.duplicate(true)
	var settlement_before: Dictionary = state.pending_showcase_settlement.duplicate(true)
	var report := AutomationService.settle(state, 1000, 1200, 7200)
	_expect_equal("offline report has no kitchen cycles", int(report.get("kitchen_cycle_count", -1)), 0)
	_expect_equal("offline keeps kitchen queue count", state.recipe_production_queue.size(), queue_before.size())
	if not state.recipe_production_queue.is_empty() and not queue_before.is_empty():
		_expect_equal("offline shifts kitchen start without consuming progress", int(state.recipe_production_queue[0].get("started_at_unix", 0)), int(queue_before[0].get("started_at_unix", 0)) + 200)
		_expect_equal("offline shifts kitchen ready without consuming progress", int(state.recipe_production_queue[0].get("ready_at_unix", 0)), int(queue_before[0].get("ready_at_unix", 0)) + 200)
	_expect_equal("offline does not consume kitchen ingredients", state.ingredient_inventory, ingredients_before)
	_expect_equal("offline does not create kitchen products", state.product_inventory, products_before)
	_expect_equal("offline does not advance active business round", state.active_business_round, round_before)
	_expect_equal("offline keeps challenge snapshot", state.pending_showcase_challenge, challenge_before)
	_expect_equal("offline keeps settlement snapshot", state.pending_showcase_settlement, settlement_before)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_LEGACY_CLEANUP_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_LEGACY_CLEANUP_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
