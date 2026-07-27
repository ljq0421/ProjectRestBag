extends SceneTree

const GAME_STATE_PATH := "res://scripts/game_state.gd"
const TASK_SERVICE_PATH := "res://scripts/task_service.gd"
const RECIPE_BOOK_PATH := "res://scripts/recipe_book.gd"
const TASK_OVERLAY_SCENE_PATH := "res://scenes/ui/overlays/task_overlay.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state_script = load(GAME_STATE_PATH)
	var task_service_script = load(TASK_SERVICE_PATH)
	var recipe_book_script = load(RECIPE_BOOK_PATH)
	var task_overlay_scene = load(TASK_OVERLAY_SCENE_PATH)
	if game_state_script == null or task_service_script == null or recipe_book_script == null or not task_overlay_scene is PackedScene:
		_fail("Daily task self-check could not load runtime dependencies")
		_finish()
		return

	var definitions: Dictionary = task_service_script.get_task_definitions()
	for daily_id in [
		"daily_farm_harvest",
		"daily_forest_harvest",
		"daily_product_sales",
		"daily_research_attempts",
		"daily_customer_orders",
		"daily_ranch_harvest",
		"daily_neighbor_gift"
	]:
		_expect(definitions.has(daily_id), "Daily task definition should include %s" % daily_id)

	var state = game_state_script.new_game()
	_open_task_system(state)
	_expect(state.has_method("sync_daily_tasks"), "GameState should expose deterministic daily task synchronization")
	if not state.has_method("sync_daily_tasks"):
		_finish()
		return
	var current_day := Time.get_date_string_from_system(false)
	state.sync_daily_tasks(current_day)
	var selected_once: Array[String] = state.daily_task_selected_ids.duplicate()
	state.sync_daily_tasks(current_day)
	_expect(state.daily_task_selected_ids == selected_once, "Daily selection should stay stable within the same day")
	var active_tasks: Array = task_service_script.get_visible_tasks(state)
	var daily_tasks := _tasks_of_type(active_tasks, "daily")
	_expect(daily_tasks.size() == 2, "Exactly two daily tasks should be selected and visible")
	_expect(not _task_ids(daily_tasks).has("daily_neighbor_gift"), "NPC gift daily task should stay hidden until gifting exists")

	state.daily_task_selected_ids.assign(["daily_farm_harvest", "daily_product_sales"])
	var ranch_state = game_state_script.new_game()
	_open_task_system(ranch_state)
	ranch_state.sync_daily_tasks(current_day)
	ranch_state.daily_task_selected_ids.assign(["daily_ranch_harvest", "daily_product_sales"])
	ranch_state.record_task_event("harvest", {"site_id": "ranch", "item_id": "egg", "amount": 2, "harvest_batch_id": "ranch:0:100"})
	ranch_state.record_task_event("harvest", {"site_id": "ranch", "item_id": "chicken", "amount": 1, "harvest_batch_id": "ranch:0:100"})
	var ranch_progress: Dictionary = ranch_state.task_progress.get("daily_ranch_harvest", {})
	_expect(int(ranch_progress.get("count", 0)) == 1, "Multiple products from one ranch harvest batch should count as one action")
	var overlay = (task_overlay_scene as PackedScene).instantiate()
	var snapshot: Dictionary = task_service_script.build_task_snapshot(state)
	var daily_entries: Array = _tasks_of_type(overlay.call("_task_entries", snapshot, "side"), "daily")
	_expect(daily_entries.size() == 2, "Side tab should show the two selected daily tasks")
	for entry_value: Variant in daily_entries:
		if entry_value is Dictionary:
			_expect(String((entry_value as Dictionary).get("type", "")) == "daily", "Daily filter should not include mainline tasks")
	overlay.free()

	for _index in range(9):
		state.record_task_event("harvest", {"site_id": "farm", "item_id": "rice", "amount": 3})
	_expect(not state.is_task_completed("daily_farm_harvest"), "Farm daily should count harvest actions rather than yielded amount")
	state.record_task_event("harvest", {"site_id": "farm", "item_id": "rice", "amount": 3})
	_expect(state.is_task_completed("daily_farm_harvest"), "Ten farm harvest actions should complete the farm daily")

	state.record_task_event("showcase_sale", {"recipe_id": "rice_milk_drink", "quantity": 1})
	_expect(int(state.task_progress.get("daily_product_sales", {}).get("count", 0)) == 1, "A real showcase sale should advance the sales daily immediately")
	state.record_task_event("showcase_sale", {"recipe_id": "rice_milk_drink", "quantity": 0, "bonus_only": true})
	_expect(int(state.task_progress.get("daily_product_sales", {}).get("count", 0)) == 1, "A bonus-only showcase event should not count as a sold dessert")
	for _index in range(19):
		state.record_task_event("showcase_sale", {"recipe_id": "sponge_cake", "quantity": 1})
	_expect(state.is_task_completed("daily_product_sales"), "Selling twenty products should complete the sales daily")
	_expect(not state.is_task_completed("daily_customer_orders"), "Unselected daily tasks should not receive progress")
	_expect(not state.task_progress.has("daily_customer_orders"), "Unselected daily tasks should not create progress records")

	var coins_before_claim := int(state.coins)
	var rice_seed_before_claim := int(state.get_ingredient_count("rice_seed"))
	_expect(state.claim_task_reward("daily_farm_harvest"), "Completed farm daily reward should be claimable")
	_expect(int(state.coins) == coins_before_claim + 50, "Farm daily claim should add 50 coins")
	_expect(int(state.get_ingredient_count("rice_seed")) > rice_seed_before_claim, "Farm daily claim should grant a usable seed bundle")

	var restored = game_state_script.from_dict(state.to_dict())
	_expect(String(restored.get("daily_task_day_key")) == current_day, "Daily task day key should survive save roundtrip")
	_expect(restored.daily_task_selected_ids == state.daily_task_selected_ids, "Selected daily task ids should survive save roundtrip")
	restored.completed_tasks.append("growth_l1_sales_rhythm")
	restored.sync_daily_tasks("2099-12-31")
	_expect(not restored.is_task_completed("daily_farm_harvest"), "A new day should clear completed daily tasks")
	_expect(not restored.is_task_reward_claimed("daily_farm_harvest"), "A new day should clear claimed daily tasks")
	_expect(not restored.task_progress.has("daily_farm_harvest"), "A new day should clear daily task progress")
	_expect(restored.is_task_completed("growth_l1_sales_rhythm"), "A new day should not clear completed growth tasks")

	_finish()


func _open_task_system(state) -> void:
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage", "task"]:
		state.unlock_core_feature(feature_id)


func _tasks_of_type(tasks: Array, task_type: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for value: Variant in tasks:
		if value is Dictionary and String((value as Dictionary).get("type", "")) == task_type:
			matches.append(value)
	return matches


func _task_ids(tasks: Array) -> Array[String]:
	var ids: Array[String] = []
	for value: Variant in tasks:
		if value is Dictionary:
			ids.append(String((value as Dictionary).get("id", "")))
	return ids


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Daily task self-check passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)
