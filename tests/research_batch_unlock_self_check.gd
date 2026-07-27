extends SceneTree

const GAME_STATE_PATH := "res://scripts/game_state.gd"
const TASK_SERVICE_PATH := "res://scripts/task_service.gd"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"

const RESTOCK_TASK_ID := "feature_restock_all"
const MAKE_ALL_TASK_ID := "feature_make_all"
const LIST_ALL_TASK_ID := "feature_list_all"

const RESTOCK_FEATURE_ID := "research_bulk_restock"
const MAKE_ALL_FEATURE_ID := "research_make_all"
const LIST_ALL_FEATURE_ID := "research_list_all"

var _save_path := OS.get_temp_dir().path_join("project_rest_research_batch_unlock_self_check.json")
var _broken_save_path := OS.get_temp_dir().path_join("project_rest_research_batch_unlock_self_check.broken.json")
var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state_script = load(GAME_STATE_PATH)
	var task_service_script = load(TASK_SERVICE_PATH)
	_expect(game_state_script != null, "GameState should load")
	_expect(task_service_script != null, "TaskService should load")
	if game_state_script == null or task_service_script == null:
		_finish()
		return

	_expect_task_definitions(task_service_script)
	var unlocked_state = _expect_parallel_progression(game_state_script, task_service_script)
	if unlocked_state != null:
		_expect_save_behavior(game_state_script, unlocked_state)
	await _expect_runtime_boundaries(game_state_script)
	_finish()


func _expect_task_definitions(task_service_script) -> void:
	var definitions: Dictionary = task_service_script.get_task_definitions()
	_expect_task_definition(definitions, RESTOCK_TASK_ID, "manual_restock_success", 10, RESTOCK_FEATURE_ID)
	_expect_task_definition(definitions, MAKE_ALL_TASK_ID, "manual_craft_success", 30, MAKE_ALL_FEATURE_ID)
	_expect_task_definition(definitions, LIST_ALL_TASK_ID, "manual_list_success", 60, LIST_ALL_FEATURE_ID)

	var restock_ids: Array = task_service_script.task_ids_for_event("manual_restock_success")
	_expect(restock_ids.has(RESTOCK_TASK_ID), "manual restock index should include the restock task")
	var craft_ids: Array = task_service_script.task_ids_for_event("manual_craft_success")
	_expect(not craft_ids.has(RESTOCK_TASK_ID), "manual craft index should exclude the restock task")
	_expect(craft_ids.has(MAKE_ALL_TASK_ID), "manual craft index should include the make-all task")
	var list_ids: Array = task_service_script.task_ids_for_event("manual_list_success")
	_expect(list_ids.has(LIST_ALL_TASK_ID), "manual list index should include the list-all task")


func _expect_task_definition(definitions: Dictionary, task_id: String, event_name: String, goal: int, feature_id: String) -> void:
	var task_value: Variant = definitions.get(task_id, {})
	_expect(task_value is Dictionary and not (task_value as Dictionary).is_empty(), "task catalog should define %s" % task_id)
	if not task_value is Dictionary or (task_value as Dictionary).is_empty():
		return
	var task: Dictionary = task_value
	_expect(String(task.get("event", "")) == event_name, "%s should subscribe to %s" % [task_id, event_name])
	_expect(int(task.get("goal", 0)) == goal, "%s should use goal %d" % [task_id, goal])
	var reward_value: Variant = task.get("reward", {})
	var unlocks: Array = (reward_value as Dictionary).get("unlock_features", []) if reward_value is Dictionary else []
	_expect(unlocks.has(feature_id), "%s should unlock %s" % [task_id, feature_id])


func _expect_parallel_progression(game_state_script, task_service_script):
	var state = game_state_script.new_game()
	_unlock_task_tracking(state)
	_expect(not state.is_feature_unlocked(RESTOCK_FEATURE_ID), "new games should lock one-click restock")
	_expect(not state.is_feature_unlocked(MAKE_ALL_FEATURE_ID), "new games should lock make all")
	_expect(not state.is_feature_unlocked(LIST_ALL_FEATURE_ID), "new games should lock list all")

	for index in range(9):
		state.record_task_event("manual_restock_success", {"action_kind": "recipe", "recipe_id": "synthetic:%d" % index})
	_expect(_progress_count(state, RESTOCK_TASK_ID) == 9, "nine successful manual restocks should produce 9/10 restock progress")
	_expect(_progress_count(state, MAKE_ALL_TASK_ID) == 0, "manual restock should not advance make-all progress")

	state.record_task_event("manual_restock_success", {"action_kind": "recipe", "recipe_id": "synthetic:9"})
	_expect(state.is_task_completed(RESTOCK_TASK_ID), "the tenth successful manual restock should complete the restock task")
	_expect(state.is_feature_unlocked(RESTOCK_FEATURE_ID), "the tenth successful manual restock should unlock one-click restock")
	_expect(not state.is_task_completed(MAKE_ALL_TASK_ID), "manual restock should not complete make all")
	_expect(_progress_count(state, MAKE_ALL_TASK_ID) == 0, "make-all progress should remain independent from restock")

	for index in range(30):
		state.record_task_event("manual_craft_success", {"action_kind": "recipe", "recipe_id": "synthetic:%d" % index})
	_expect(state.is_task_completed(MAKE_ALL_TASK_ID), "the thirtieth manual craft action should complete make all")
	_expect(state.is_feature_unlocked(MAKE_ALL_FEATURE_ID), "the thirtieth manual craft action should unlock make all")

	for index in range(60):
		state.record_task_event("manual_list_success", {"action_kind": "button" if index % 2 == 0 else "drag", "recipe_id": "synthetic"})
	_expect(state.is_task_completed(LIST_ALL_TASK_ID), "the sixtieth manual list action should complete list all")
	_expect(state.is_feature_unlocked(LIST_ALL_FEATURE_ID), "the sixtieth manual list action should unlock list all")

	for task_id in [RESTOCK_TASK_ID, MAKE_ALL_TASK_ID, LIST_ALL_TASK_ID]:
		_expect(state.is_task_reward_claimed(task_id), "%s should be marked applied automatically" % task_id)
		_expect(not _task_ids(state.get_claimable_tasks()).has(task_id), "%s should not enter the claimable list" % task_id)

	_expect(_notifications_contain(state, "一键补货已开放"), "restock completion should announce the unlock")
	_expect(_notifications_contain(state, "制作全部已开放"), "make-all completion should announce the unlock")
	_expect(_notifications_contain(state, "上架全部已开放"), "list-all completion should announce the unlock")

	var notification_count: int = state.pending_notifications.size()
	state.record_task_event("manual_restock_success", {"action_kind": "recipe", "recipe_id": "after_complete"})
	state.record_task_event("manual_craft_success", {"action_kind": "recipe", "recipe_id": "after_complete"})
	state.record_task_event("manual_list_success", {"action_kind": "button", "recipe_id": "after_complete"})
	_expect(_progress_count(state, RESTOCK_TASK_ID) == 10, "completed restock progress should remain 10/10")
	_expect(_progress_count(state, MAKE_ALL_TASK_ID) == 30, "completed make-all progress should remain 30/30")
	_expect(_progress_count(state, LIST_ALL_TASK_ID) == 60, "completed list-all progress should remain 60/60")
	_expect(state.pending_notifications.size() == notification_count, "completed tasks should not repeat unlock notifications")

	var visible_ids := _task_ids(task_service_script.get_visible_tasks(state)) if task_service_script.has_method("get_visible_tasks") else _task_ids(task_service_script.get_side_tasks(state))
	_expect(not visible_ids.has(RESTOCK_TASK_ID) and not visible_ids.has(MAKE_ALL_TASK_ID) and not visible_ids.has(LIST_ALL_TASK_ID), "completed feature tasks should leave the active task list")
	return state


func _expect_save_behavior(game_state_script, unlocked_state) -> void:
	var restored = game_state_script.from_dict(unlocked_state.to_dict())
	_expect(restored.is_feature_unlocked(RESTOCK_FEATURE_ID), "one-click restock unlock should survive save roundtrip")
	_expect(restored.is_feature_unlocked(MAKE_ALL_FEATURE_ID), "make-all unlock should survive save roundtrip")
	_expect(restored.is_feature_unlocked(LIST_ALL_FEATURE_ID), "list-all unlock should survive save roundtrip")

	var partial = game_state_script.new_game()
	_unlock_task_tracking(partial)
	for index in range(9):
		partial.record_task_event("manual_restock_success", {"action_kind": "recipe", "recipe_id": "partial:%d" % index})
	var partial_restored = game_state_script.from_dict(partial.to_dict())
	_expect(_progress_count(partial_restored, RESTOCK_TASK_ID) == 9, "partial restock progress should survive save roundtrip")
	_expect(_progress_count(partial_restored, MAKE_ALL_TASK_ID) == 0, "restock save progress should not leak into make-all")
	partial_restored.record_task_event("manual_restock_success", {"action_kind": "recipe", "recipe_id": "partial:9"})
	var ten_restored = game_state_script.from_dict(partial_restored.to_dict())
	_expect(ten_restored.is_feature_unlocked(RESTOCK_FEATURE_ID), "tenth saved restock should preserve the restock unlock")
	_expect(_progress_count(ten_restored, MAKE_ALL_TASK_ID) == 0, "restock unlock should not alter make-all progress")

	var legacy = game_state_script.from_dict(game_state_script.new_game().to_dict())
	_expect(_progress_count(legacy, RESTOCK_TASK_ID) == 0, "legacy saves should start restock progress at zero")
	_expect(_progress_count(legacy, MAKE_ALL_TASK_ID) == 0, "legacy saves should start make-all progress at zero")
	_expect(_progress_count(legacy, LIST_ALL_TASK_ID) == 0, "legacy saves should start list-all progress at zero")
	_expect(not legacy.is_feature_unlocked(RESTOCK_FEATURE_ID), "legacy saves should not auto-unlock one-click restock")
	_expect(not legacy.is_feature_unlocked(MAKE_ALL_FEATURE_ID), "legacy saves should not auto-unlock make all")
	_expect(not legacy.is_feature_unlocked(LIST_ALL_FEATURE_ID), "legacy saves should not auto-unlock list all")

	var repair_data: Dictionary = unlocked_state.to_dict()
	repair_data.erase("feature_unlocks")
	var repaired = game_state_script.from_dict(repair_data)
	_expect(repaired.is_feature_unlocked(RESTOCK_FEATURE_ID), "completed restock task should repair a missing feature unlock")
	_expect(repaired.is_feature_unlocked(MAKE_ALL_FEATURE_ID), "completed make-all task should repair a missing feature unlock")
	_expect(repaired.is_feature_unlocked(LIST_ALL_FEATURE_ID), "completed list-all task should repair a missing feature unlock")


func _expect_runtime_boundaries(game_state_script) -> void:
	var packed_scene = load(MAIN_SCENE_PATH)
	_expect(packed_scene is PackedScene, "Main scene should load")
	if not packed_scene is PackedScene:
		return
	var main: Control = (packed_scene as PackedScene).instantiate()
	main.set("save_path", _save_path)
	main.set("broken_save_path", _broken_save_path)
	root.add_child(main)
	await process_frame
	await process_frame

	await _expect_hidden_buttons(main, game_state_script)
	await _expect_direct_guards(main, game_state_script)
	await _expect_manual_restock_boundaries(main, game_state_script)
	await _expect_manual_craft_boundaries(main, game_state_script)
	await _expect_manual_list_boundaries(main, game_state_script)
	await _expect_unlock_visibility(main, game_state_script)

	main.queue_free()
	await process_frame


func _expect_hidden_buttons(main: Control, game_state_script) -> void:
	var state = game_state_script.new_game()
	_set_main_state(main, state)
	await process_frame
	var bulk_menu: PopupMenu = (main.get("production_workbench").get_node("ProductionQueueHeader/BulkActionButton") as MenuButton).get_popup()
	_expect(bulk_menu.is_item_disabled(bulk_menu.get_item_index(0)), "make all should stay disabled until unlocked")
	_expect(bulk_menu.is_item_disabled(bulk_menu.get_item_index(2)), "list all should stay disabled until unlocked")
	_expect(bulk_menu.is_item_disabled(bulk_menu.get_item_index(1)), "one-click restock should stay disabled until unlocked")
	main.call("_show_inventory_global_popup")
	var inventory_batch_list: Button = main.get("inventory_batch_list_button")
	_expect(not inventory_batch_list.visible, "inventory batch listing should stay hidden until list-all is unlocked")
	main.call("_close_global_popup")


func _expect_direct_guards(main: Control, game_state_script) -> void:
	var make_state = _craft_ready_state(game_state_script)
	_set_main_state(main, make_state)
	var queue_before: int = make_state.recipe_production_queue.size()
	main.call("_make_all_available_products")
	_expect(make_state.recipe_production_queue.size() == queue_before, "locked direct make-all should not start production")
	_expect(_status_contains(main, "制作熟手") and _status_contains(main, "0/30"), "locked make-all should explain its task and progress")

	var list_state = game_state_script.new_game()
	list_state.add_recipe("rice_milk_drink")
	list_state.add_product("rice_milk_drink", 3)
	_set_main_state(main, list_state)
	var product_before: int = list_state.get_product_count("rice_milk_drink")
	main.call("_list_all_available_products")
	_expect(list_state.get_product_count("rice_milk_drink") == product_before, "locked direct list-all should not move product stock")
	_expect(list_state.display_items.is_empty(), "locked direct list-all should not change the showcase")
	_expect(_status_contains(main, "上架熟手") and _status_contains(main, "0/60"), "locked list-all should explain its task and progress")

	var restock_state = game_state_script.new_game()
	restock_state.add_recipe("rice_milk_drink")
	restock_state.coins = 999
	restock_state.ingredient_inventory = {}
	_set_main_state(main, restock_state)
	main.set("pending_research_bulk_restock", false)
	main.call("_on_research_bulk_restock_pressed")
	_expect(not bool(main.get("pending_research_bulk_restock")), "locked direct one-click restock should not open a bulk quote")
	_expect(_status_contains(main, "备货熟手") and _status_contains(main, "0/10"), "locked one-click restock should explain its task and progress")


func _expect_manual_craft_boundaries(main: Control, game_state_script) -> void:
	var recipe_state = _craft_ready_state(game_state_script)
	_set_main_state(main, recipe_state)
	main.call("_on_recipe_make_pressed", "rice_milk_drink")
	_expect(_progress_count(recipe_state, RESTOCK_TASK_ID) == 0, "successful recipe-button craft should not count as restock")
	_expect(_progress_count(recipe_state, MAKE_ALL_TASK_ID) == 1, "successful recipe-button craft should advance make-all mastery")
	var count_before_completion := _progress_count(recipe_state, MAKE_ALL_TASK_ID)
	if not recipe_state.recipe_production_queue.is_empty():
		recipe_state.complete_recipe_production(0, 2147483647)
	_expect(_progress_count(recipe_state, MAKE_ALL_TASK_ID) == count_before_completion, "recipe completion should not count a second manual craft")

	var process_state = _process_ready_state(game_state_script)
	_set_main_state(main, process_state)
	main.call("_on_process_make_pressed", "rice_flour_process")
	_expect(_progress_count(process_state, RESTOCK_TASK_ID) == 0, "successful processing-button action should not count as restock")
	_expect(_progress_count(process_state, MAKE_ALL_TASK_ID) == 1, "successful processing should advance make-all mastery")

	var failed_state = game_state_script.new_game()
	failed_state.add_recipe("rice_milk_drink")
	_set_main_state(main, failed_state)
	main.call("_on_recipe_make_pressed", "rice_milk_drink")
	_expect(_progress_count(failed_state, RESTOCK_TASK_ID) == 0, "failed recipe craft should not count")

	var bulk_state = _craft_ready_state(game_state_script)
	bulk_state.unlock_feature(MAKE_ALL_FEATURE_ID)
	_set_main_state(main, bulk_state)
	main.call("_make_all_available_products")
	_expect(_progress_count(bulk_state, RESTOCK_TASK_ID) == 0, "make all should not count as manual craft")
	_expect(_progress_count(bulk_state, MAKE_ALL_TASK_ID) == 0, "make all should not advance its own unlock task")
	bulk_state.record_task_event("make_product", {"recipe_id": "rice_milk_drink", "quantity": 3})
	_expect(_progress_count(bulk_state, RESTOCK_TASK_ID) == 0, "production completion events should not count as manual craft")


func _expect_manual_restock_boundaries(main: Control, game_state_script) -> void:
	var success_state = game_state_script.new_game()
	success_state.level = 2
	success_state.coins = 100
	success_state.ingredient_inventory.clear()
	success_state.add_recipe("butter_cookie")
	_unlock_task_tracking(success_state)
	for index in range(9):
		success_state.record_task_event("manual_restock_success", {"action_kind": "recipe", "recipe_id": "runtime:%d" % index})
	_set_main_state(main, success_state)
	main.call("_on_recipe_restock_pressed", "butter_cookie")
	_expect(_progress_count(success_state, RESTOCK_TASK_ID) == 9, "opening a single restock quote should not count")
	var restock_dialog: ConfirmationDialog = main.get("recipe_restock_dialog")
	restock_dialog.canceled.emit()
	restock_dialog.hide()
	_expect(_progress_count(success_state, RESTOCK_TASK_ID) == 9, "canceling a single restock quote should not count")
	main.call("_on_recipe_restock_pressed", "butter_cookie")
	restock_dialog.hide()
	main.call("_on_recipe_restock_confirmed")
	_expect(_progress_count(success_state, RESTOCK_TASK_ID) == 10, "the tenth successful confirmed single restock should count once")
	_expect(success_state.is_feature_unlocked(RESTOCK_FEATURE_ID), "the tenth real restock purchase should unlock one-click restock")
	main.call("_refresh_current_page")
	await process_frame
	var bulk_menu: PopupMenu = (main.get("production_workbench").get_node("ProductionQueueHeader/BulkActionButton") as MenuButton).get_popup()
	_expect(not bulk_menu.is_item_disabled(bulk_menu.get_item_index(1)), "the tenth real restock purchase should enable one-click restock immediately")
	var task_popup: AcceptDialog = main.get("task_popup")
	_expect(task_popup.visible and task_popup.title.find("一键补货已开放") != -1, "the tenth real restock purchase should present the unlock notification")
	task_popup.hide()

	var failed_state = game_state_script.new_game()
	failed_state.level = 2
	failed_state.coins = 0
	failed_state.ingredient_inventory.clear()
	failed_state.add_recipe("butter_cookie")
	_set_main_state(main, failed_state)
	main.call("_on_recipe_restock_pressed", "butter_cookie")
	main.call("_on_recipe_restock_confirmed")
	_expect(_progress_count(failed_state, RESTOCK_TASK_ID) == 0, "failed confirmed single restock should not count")

	var bulk_state = game_state_script.new_game()
	bulk_state.level = 2
	bulk_state.coins = 9999
	bulk_state.ingredient_inventory.clear()
	bulk_state.add_recipe("butter_cookie")
	bulk_state.unlock_feature(RESTOCK_FEATURE_ID)
	_set_main_state(main, bulk_state)
	main.call("_on_research_bulk_restock_pressed")
	main.call("_on_recipe_restock_confirmed")
	_expect(_progress_count(bulk_state, RESTOCK_TASK_ID) == 0, "successful bulk restock should not advance its own unlock task")


func _expect_manual_list_boundaries(main: Control, game_state_script) -> void:
	var button_state = game_state_script.new_game()
	button_state.add_recipe("rice_milk_drink")
	button_state.add_product("rice_milk_drink", 2)
	_set_main_state(main, button_state)
	main.call("_on_recipe_list_pressed", "rice_milk_drink")
	_expect(_progress_count(button_state, LIST_ALL_TASK_ID) == 1, "successful list button should count once")

	var drag_state = game_state_script.new_game()
	drag_state.add_recipe("rice_milk_drink")
	drag_state.add_product("rice_milk_drink", 2)
	_set_main_state(main, drag_state)
	var drag_data := {
		"kind": "inventory_product",
		"recipe_id": "rice_milk_drink",
		"target_slot_index": -1
	}
	for slot_index in range(200):
		drag_data["target_slot_index"] = slot_index
		if bool(main.call("_can_drop_showcase_data", "showcase", drag_data)):
			break
	var drag_ok := bool(main.call("_drop_showcase_data", "showcase", drag_data))
	_expect(drag_ok, "drag fixture should successfully list one product")
	_expect(_progress_count(drag_state, LIST_ALL_TASK_ID) == 1, "successful drag listing should count once")

	var failed_state = game_state_script.new_game()
	failed_state.add_recipe("rice_milk_drink")
	_set_main_state(main, failed_state)
	main.call("_on_recipe_list_pressed", "rice_milk_drink")
	_expect(_progress_count(failed_state, LIST_ALL_TASK_ID) == 0, "failed list button should not count")
	var failed_drag_ok := bool(main.call("_drop_showcase_data", "showcase", {
		"kind": "inventory_product",
		"recipe_id": "rice_milk_drink",
		"target_slot_index": 0
	}))
	_expect(not failed_drag_ok, "drag listing without product stock should fail")
	_expect(_progress_count(failed_state, LIST_ALL_TASK_ID) == 0, "failed drag listing should not count")

	var move_state = game_state_script.new_game()
	move_state.add_recipe("rice_milk_drink")
	move_state.add_product("rice_milk_drink", 2)
	_set_main_state(main, move_state)
	main.call("_on_recipe_list_pressed", "rice_milk_drink")
	move_state.task_progress.erase(LIST_ALL_TASK_ID)
	var source_slot: int = int(main.call("_display_anchor_slot_index_for_recipe", "rice_milk_drink"))
	var move_data := {
		"kind": "showcase_product",
		"recipe_id": "rice_milk_drink",
		"source_anchor_slot_index": source_slot,
		"source_grab_slot_index": source_slot,
		"target_slot_index": source_slot
	}
	for slot_index in range(200):
		if slot_index == source_slot:
			continue
		move_data["target_slot_index"] = slot_index
		if bool(main.call("_can_drop_showcase_data", "showcase", move_data)):
			break
	var move_ok := bool(main.call("_drop_showcase_data", "showcase", move_data))
	_expect(move_ok, "moving an existing showcase product fixture should succeed")
	_expect(_progress_count(move_state, LIST_ALL_TASK_ID) == 0, "moving an existing showcase product should not count as manual listing")

	var bulk_state = game_state_script.new_game()
	bulk_state.add_recipe("rice_milk_drink")
	bulk_state.add_product("rice_milk_drink", 3)
	bulk_state.unlock_feature(LIST_ALL_FEATURE_ID)
	_set_main_state(main, bulk_state)
	main.call("_list_all_available_products")
	_expect(_progress_count(bulk_state, LIST_ALL_TASK_ID) == 0, "list all should not count as manual listing")


func _expect_unlock_visibility(main: Control, game_state_script) -> void:
	var state = game_state_script.new_game()
	_set_main_state(main, state)
	for index in range(10):
		state.record_task_event("manual_restock_success", {"action_kind": "recipe", "recipe_id": "visibility:%d" % index})
	main.call("_refresh_current_page")
	await process_frame
	var bulk_menu: PopupMenu = (main.get("production_workbench").get_node("ProductionQueueHeader/BulkActionButton") as MenuButton).get_popup()
	_expect(not bulk_menu.is_item_disabled(bulk_menu.get_item_index(1)), "one-click restock should be enabled after ten successful manual restocks")
	_expect(bulk_menu.is_item_disabled(bulk_menu.get_item_index(0)), "make all should remain disabled before manual craft progress")
	_expect(bulk_menu.is_item_disabled(bulk_menu.get_item_index(2)), "list all should remain disabled before manual listing mastery")

	for index in range(30):
		state.record_task_event("manual_craft_success", {"action_kind": "processing", "process_id": "visibility:%d" % index})
	main.call("_refresh_current_page")
	await process_frame
	_expect(not bulk_menu.is_item_disabled(bulk_menu.get_item_index(0)), "make all should be enabled after thirty manual craft actions")

	for index in range(60):
		state.record_task_event("manual_list_success", {"action_kind": "button", "recipe_id": "visibility"})
	main.call("_refresh_current_page")
	await process_frame
	_expect(not bulk_menu.is_item_disabled(bulk_menu.get_item_index(2)), "list all should be enabled after sixty manual list actions")
	main.call("_show_inventory_global_popup")
	var inventory_batch_list: Button = main.get("inventory_batch_list_button")
	_expect(inventory_batch_list.visible, "inventory batch listing should appear with the list-all unlock")
	main.call("_close_global_popup")


func _craft_ready_state(game_state_script):
	var state = game_state_script.new_game()
	state.add_recipe("rice_milk_drink")
	state.unlock_device("round_pot")
	state.ingredient_inventory = {
		"rice": 20,
		"spring_water": 20,
		"sugar": 20
	}
	return state


func _process_ready_state(game_state_script):
	var state = game_state_script.new_game()
	state.level = 1
	state.unlock_device("grinder")
	state.unlock_ingredient_process("rice_flour")
	state.ingredient_inventory = {"rice": 5}
	return state


func _set_main_state(main: Control, state) -> void:
	state.tutorial_guide_skipped = true
	_unlock_task_tracking(state)
	main.set("state", state)
	main.set("selected_task_id", "")
	main.call("_show_page", "research")


func _unlock_task_tracking(state) -> void:
	for feature_id in ["purchase", "output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage", "task"]:
		state.unlock_core_feature(feature_id)


func _progress_count(state, task_id: String) -> int:
	var progress_value: Variant = state.task_progress.get(task_id, {})
	return int((progress_value as Dictionary).get("count", 0)) if progress_value is Dictionary else 0


func _task_ids(tasks: Array) -> Array[String]:
	var ids: Array[String] = []
	for task_value: Variant in tasks:
		if task_value is Dictionary:
			ids.append(String((task_value as Dictionary).get("id", "")))
	return ids


func _notifications_contain(state, expected: String) -> bool:
	for notification_value: Variant in state.pending_notifications:
		if not notification_value is Dictionary:
			continue
		var notification: Dictionary = notification_value
		if String(notification.get("title", "")).find(expected) != -1 or String(notification.get("body", "")).find(expected) != -1:
			return true
	return false


func _status_contains(main: Control, expected: String) -> bool:
	var status: Label = main.get("status_label")
	return status != null and status.text.find(expected) != -1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RESEARCH_BATCH_UNLOCK_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)
