extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TASK_SERVICE := preload("res://scripts/task_service.gd")
const CATALOG := preload("res://scripts/catalog.gd")
const MAIN := preload("res://scenes/Main.tscn")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var level_zero = GAME_STATE.new_game()
	_expect(not _task_ids(TASK_SERVICE.build_task_snapshot(level_zero).get("current_entries", [])).has("shop_upgrade_1"), "Lv.0 must not expose a shop upgrade task")

	var level_one = _level_one_state(899, 30)
	var snapshot: Dictionary = TASK_SERVICE.build_task_snapshot(level_one)
	var current_entries: Array = snapshot.get("current_entries", [])
	var current_ids := _task_ids(current_entries)
	_expect(current_ids.has("shop_upgrade_2"), "Lv.1 should immediately expose the Lv.2 shop upgrade task")
	_expect(current_ids.has("growth_l1_sales_rhythm"), "Lv.1 shop upgrade and sales course should be visible in parallel")
	_expect_equal("Parallel current task count", int(snapshot.get("current_slot_count", -1)), current_entries.size())

	var upgrade_task := _task_by_id(current_entries, "shop_upgrade_2")
	if not upgrade_task.is_empty():
		_expect_equal("Upgrade action kind", String(upgrade_task.get("action_kind", "")), "shop_upgrade")
		_expect_equal("Upgrade progress before funds", String(upgrade_task.get("progress_detail", "")), "升级资金 899/900｜累计口碑 30/30")
		_expect(not bool(upgrade_task.get("can_upgrade", true)), "Upgrade should be disabled while one coin short")
		_expect_equal("Missing upgrade coins", int(upgrade_task.get("missing_coins", -1)), 1)
		_expect_equal("Missing upgrade reputation", int(upgrade_task.get("missing_reputation", -1)), 0)
	_expect(not _task_ids(snapshot.get("claimable", [])).has("shop_upgrade_2"), "Shop upgrade must not enter claimable rewards")

	var reputation_short = _level_one_state(900, 29)
	var reputation_task := TASK_SERVICE.build_shop_upgrade_task(reputation_short)
	_expect_equal("Reputation-only shortage progress", String(reputation_task.get("progress_detail", "")), "升级资金 900/900｜累计口碑 29/30")
	_expect_equal("Reputation-only shortage", int(reputation_task.get("missing_reputation", -1)), 1)
	var failure_snapshot := [int(reputation_short.level), int(reputation_short.coins), int(reputation_short.reputation)]
	_expect(not reputation_short.upgrade(), "Upgrade should fail when cumulative reputation is insufficient")
	_expect_equal("Failed upgrade preserves level and resources", [int(reputation_short.level), int(reputation_short.coins), int(reputation_short.reputation)], failure_snapshot)

	var level_six = GAME_STATE.new_game()
	level_six.level = 6
	level_six.coins = 0
	level_six.reputation = 0
	var level_seven_definition: Dictionary = CATALOG.new().get_upgrade_definition(7)
	var level_seven_task := TASK_SERVICE.build_shop_upgrade_task(level_six)
	_expect_equal("Lv.6 dynamic upgrade id", String(level_seven_task.get("id", "")), "shop_upgrade_7")
	_expect_equal("Lv.7 dynamic upgrade cost", int(level_seven_task.get("cost", -1)), 15000)
	_expect_equal("Lv.7 dynamic reputation requirement", int(level_seven_task.get("required_reputation", -1)), 720)
	_expect_equal("Lv.7 task mirrors catalog cost", int(level_seven_task.get("cost", -1)), int(level_seven_definition.get("cost", -2)))
	_expect_equal("Lv.7 task mirrors catalog reputation", int(level_seven_task.get("required_reputation", -1)), int(level_seven_definition.get("required_reputation", -2)))

	var capped_state = GAME_STATE.new_game()
	capped_state.level = 247
	capped_state.coins = 123
	capped_state.reputation = 456
	_expect(TASK_SERVICE.build_shop_upgrade_task(capped_state).is_empty(), "The numeric progression boundary should not expose a broken upgrade task")

	var parallel_definitions := {
		"parallel_growth_a": {"id": "parallel_growth_a", "type": "growth", "level": 1, "sort_order": 1, "prerequisites": []},
		"parallel_growth_b": {"id": "parallel_growth_b", "type": "growth", "level": 1, "sort_order": 2, "prerequisites": []}
	}
	var task_service_script = load("res://scripts/task_service.gd")
	_expect(task_service_script.has_method("available_progression_task_ids"), "TaskService should expose every available progression task in deterministic order")
	if task_service_script.has_method("available_progression_task_ids"):
		var parallel_ids: Array = task_service_script.call("available_progression_task_ids", level_one, parallel_definitions)
		_expect_equal("Two ordinary progression tasks can run in parallel", parallel_ids, ["parallel_growth_a", "parallel_growth_b"])

	var main = MAIN.instantiate()
	var save_path := OS.get_temp_dir().path_join("task_shop_upgrade_self_check.json")
	main.set("save_path", save_path)
	main.set("broken_save_path", OS.get_temp_dir().path_join("task_shop_upgrade_self_check.broken.json"))
	root.add_child(main)
	await process_frame
	await process_frame
	main.set("state", level_one)
	main.set("selected_task_filter", "current")
	main.set("selected_task_id", "shop_upgrade_2")
	main.call("_show_task_global_popup")
	await process_frame

	var action_button := main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskDetailPanel/TaskDetailContent/TaskActionButton") as Button
	var detail_text := main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskDetailPanel/TaskDetailContent/TaskDetailText") as RichTextLabel
	_expect_equal("Upgrade detail action", action_button.text, "升级店铺")
	_expect(action_button.disabled, "Upgrade detail action should be disabled while funds are insufficient")
	_expect(detail_text.text.contains("还需金币 1"), "Visible upgrade detail should state the exact missing coin amount")
	main.call("_on_task_shop_upgrade_requested", "shop_upgrade_2")
	_expect_equal("Failed task action preserves level and resources", [int(level_one.level), int(level_one.coins), int(level_one.reputation)], [1, 899, 30])
	var status_text := String((main.get_node("Root/StatusBar/StatusLabel") as Label).text)
	_expect_equal("Failure message lists only positive gaps", status_text, "升级条件不足：还需金币 1。")

	level_one.coins = 900
	main.call("_refresh_task_overlay")
	await process_frame
	action_button = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskDetailPanel/TaskDetailContent/TaskActionButton") as Button
	_expect_equal("Ready upgrade detail action", action_button.text, "升级店铺")
	_expect(not action_button.disabled, "Upgrade detail action should enable when both thresholds are met")
	_expect(main.has_method("_on_task_shop_upgrade_requested"), "Main view should handle shop upgrade requests from the task card")
	if action_button.text == "升级店铺" and not action_button.disabled and main.has_method("_on_task_shop_upgrade_requested"):
		action_button.emit_signal("pressed")
		await process_frame
		_expect_equal("Level after task upgrade", int(level_one.level), 2)
		_expect_equal("Coins after task upgrade", int(level_one.coins), 0)
		_expect_equal("Reputation after task upgrade", int(level_one.reputation), 30)
		level_one.coins = 2200
		level_one.reputation = 80
		main.call("_on_task_shop_upgrade_requested", "shop_upgrade_2")
		_expect_equal("Stale card cannot upgrade twice even with Lv.3 resources", [int(level_one.level), int(level_one.coins), int(level_one.reputation)], [2, 2200, 80])
		var after_upgrade: Dictionary = TASK_SERVICE.build_task_snapshot(level_one)
		var after_ids := _task_ids(after_upgrade.get("current_entries", []))
		_expect(not after_ids.has("shop_upgrade_2"), "Completed level upgrade card should disappear")
		_expect(after_ids.has("shop_upgrade_3"), "Next level upgrade card should appear immediately")
		_expect(not _task_ids(after_upgrade.get("completed", [])).has("shop_upgrade_2"), "Shop upgrade must not be stored as a completed task")

	main.queue_free()
	_finish()


func _level_one_state(coins: int, reputation: int):
	var state = GAME_STATE.new_game()
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage", "task"]:
		state.unlock_core_feature(feature_id)
	state.level = 1
	state.coins = coins
	state.reputation = reputation
	return state


func _task_ids(tasks: Array) -> Array[String]:
	var ids: Array[String] = []
	for task_value: Variant in tasks:
		if task_value is Dictionary:
			ids.append(String((task_value as Dictionary).get("id", "")))
	return ids


func _task_by_id(tasks: Array, task_id: String) -> Dictionary:
	for task_value: Variant in tasks:
		if task_value is Dictionary and String((task_value as Dictionary).get("id", "")) == task_id:
			return (task_value as Dictionary).duplicate(true)
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TASK_SHOP_UPGRADE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("TASK_SHOP_UPGRADE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
