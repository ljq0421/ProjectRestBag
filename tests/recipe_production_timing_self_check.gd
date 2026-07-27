extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")
const GameState = preload("res://scripts/game_state.gd")
const RecipeBook = preload("res://scripts/recipe_book.gd")
const SaveSystem = preload("res://scripts/save_system.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_catalog_durations()
	_test_same_device_allows_parallel_tasks()
	_test_single_recipe_batch_limit()
	_test_queue_summary_counts_batches()
	_test_batch_progress_sequence_is_stable()
	_test_recipe_book_starts_timed_manual_task()
	_test_recipe_book_explains_locked_device()
	_test_ready_completion_is_atomic()
	_test_offline_manual_completion()
	_finish()


func _test_catalog_durations() -> void:
	var recipes: Dictionary = Catalog.new().get_recipes()
	_expect_equal("rice milk duration", int(recipes["rice_milk_drink"].get("production_duration_seconds", 0)), 2)
	_expect_equal("rich rice duration", int(recipes["rich_rice_drink"].get("production_duration_seconds", 0)), 4)
	_expect_equal("compound duration", int(recipes["cream_shortcake"].get("production_duration_seconds", 0)), 8)


func _test_same_device_allows_parallel_tasks() -> void:
	var state = _ready_state()
	_expect(state.queue_recipe_production("rice_milk_drink", 1, 1000, "manual"), "first round-pot task should start")
	_expect(not state.queue_recipe_production("rice_milk_drink", 1, 1000, "manual"), "same recipe should not start twice")
	_expect(state.queue_recipe_production("rich_rice_drink", 1, 1000, "manual"), "different recipe should also start on the same round pot")
	_expect_equal("parallel queue count", state.recipe_production_queue.size(), 2)
	_expect(not state.queue_recipe_production("rice_milk_drink", 5, 1000, "manual"), "manual five-batch task should be rejected")


func _test_single_recipe_batch_limit() -> void:
	var manual_state = _ready_state()
	_expect(manual_state.queue_recipe_production("rice_milk_drink", 1, 1000, "manual"), "first manual batch should fit")
	_expect_equal("one manual batch queued", manual_state.recipe_production_queue.size(), 1)
	var rice_before_second: int = manual_state.get_ingredient_count("rice")
	var water_before_second: int = manual_state.get_ingredient_count("spring_water")
	_expect(not manual_state.queue_recipe_production("rice_milk_drink", 1, 1001, "manual"), "second manual batch should be rejected")
	_expect_equal("second rejection keeps rice", manual_state.get_ingredient_count("rice"), rice_before_second)
	_expect_equal("second rejection keeps water", manual_state.get_ingredient_count("spring_water"), water_before_second)
	_expect(manual_state.queue_recipe_production("rich_rice_drink", 1, 1001, "manual"), "a different recipe should keep independent capacity")

	var shared_state = _ready_state()
	_expect(shared_state.queue_recipe_production("rice_milk_drink", 1, 1000, "manual"), "manual batch should reserve a shared recipe slot")
	var rice_before_blocked_automation: int = shared_state.get_ingredient_count("rice")
	var water_before_blocked_automation: int = shared_state.get_ingredient_count("spring_water")
	_expect(not shared_state.queue_recipe_production("rice_milk_drink", 3, 1001, "automation", "rule_batch_three"), "automation should reject legacy three-batch starts")
	_expect_equal("blocked automation keeps queue size", shared_state.recipe_production_queue.size(), 1)
	_expect_equal("blocked automation keeps rice", shared_state.get_ingredient_count("rice"), rice_before_blocked_automation)
	_expect_equal("blocked automation keeps water", shared_state.get_ingredient_count("spring_water"), water_before_blocked_automation)

	var automatic_state = _ready_state()
	_expect(not automatic_state.queue_recipe_production("rice_milk_drink", 3, 1000, "automation", "rule_batch_three"), "automation should never start three batches")
	_expect(automatic_state.queue_recipe_production("rice_milk_drink", 1, 1000, "automation", "rule_batch_one"), "automation should start one batch")
	_expect(not automatic_state.queue_recipe_production("rice_milk_drink", 1, 1001, "manual"), "manual and automation should share the one-batch limit")

	var legacy_data: Dictionary = _ready_state().to_dict()
	legacy_data["recipe_production_queue"] = [{
		"queue_sequence": 7,
		"recipe_id": "rice_milk_drink",
		"device_id": "round_pot",
		"batches": 3,
		"output_count": 9,
		"started_at_unix": 1000,
		"duration_seconds": 6,
		"ready_at_unix": 1006,
		"source": "automation",
		"automation_rule_id": "legacy_three"
	}]
	var legacy_state = GameState.from_dict(legacy_data)
	_expect_equal("legacy three-batch record survives load", int(legacy_state.recipe_production_queue[0].get("batches", 0)), 3)
	_expect(not legacy_state.queue_recipe_production("rice_milk_drink", 1, 1001, "manual"), "legacy active work blocks a new start")
	_expect(legacy_state.complete_recipe_production(0, 1006), "legacy three-batch record should settle")
	_expect_equal("legacy output settles in full", legacy_state.get_product_count("rice_milk_drink"), 9)


func _test_recipe_book_starts_timed_manual_task() -> void:
	var state = _ready_state()
	var recipe_book = RecipeBook.new()
	var argument_count := _method_argument_count(recipe_book, "make_product")
	_expect(argument_count >= 4, "RecipeBook.make_product should accept an injected timestamp")
	if argument_count < 4:
		return
	var rice_before: int = int(state.get_ingredient_count("rice"))
	var water_before: int = int(state.get_ingredient_count("spring_water"))
	var result: Dictionary = recipe_book.call("make_product", state, "rice_milk_drink", 1, 1000)
	_expect(bool(result.get("ok", false)), "manual production should start")
	_expect_equal("started message kind", String(result.get("status", "")), "started")
	_expect_equal("rice consumed at start", state.get_ingredient_count("rice"), rice_before - 1)
	_expect_equal("water consumed at start", state.get_ingredient_count("spring_water"), water_before - 1)
	_expect_equal("no product before ready", state.get_product_count("rice_milk_drink"), 0)
	_expect_equal("one queued task", state.recipe_production_queue.size(), 1)
	if state.recipe_production_queue.size() == 1:
		var queued: Dictionary = state.recipe_production_queue[0]
		_expect_equal("manual batch count", int(queued.get("batches", 0)), 1)
		_expect_equal("configured duration", int(queued.get("duration_seconds", 0)), 2)
		_expect_equal("configured ready time", int(queued.get("ready_at_unix", 0)), 1002)
	_expect_equal("growth waits for completion", int(state.get_recipe_growth("rice_milk_drink").get("made_count", 0)), 0)
	_expect_equal("device use waits for completion", int(state.get_device_growth("round_pot").get("production_batch_count", 0)), 0)


func _test_queue_summary_counts_batches() -> void:
	var state = _ready_state()
	_expect(state.queue_recipe_production("rice_milk_drink", 1, 1000, "manual"), "summary manual task should start")
	_expect(state.queue_recipe_production("rich_rice_drink", 1, 1000, "automation", "rule_batch_one"), "summary one-batch automation task should start")
	var summary: Dictionary = state.recipe_production_queue_summary(1000)
	_expect_equal("manual active batch count", int(summary.get("rice_milk_drink", {}).get("active_count", 0)), 1)
	_expect_equal("automation active batch count", int(summary.get("rich_rice_drink", {}).get("active_count", 0)), 1)
	_expect_equal("automation active task count", int(summary.get("rich_rice_drink", {}).get("active_task_count", 0)), 1)
	var manual_progress: Array = summary.get("rice_milk_drink", {}).get("batch_progress", [])
	var automation_progress: Array = summary.get("rich_rice_drink", {}).get("batch_progress", [])
	_expect_equal("manual progress item count", manual_progress.size(), 1)
	_expect_equal("automation progress item count", automation_progress.size(), 1)
	if manual_progress.size() == 1:
		var batch: Dictionary = manual_progress[0]
		_expect(int(batch.get("queue_sequence", 0)) > 0, "manual progress should expose a persistent queue sequence")
		_expect_equal("manual progress batch index", int(batch.get("batch_index", -1)), 0)
		_expect_equal("manual progress duration", int(batch.get("duration_seconds", 0)), 2)
		_expect_equal("manual progress remaining", int(batch.get("remaining_seconds", -1)), 2)
		_expect(is_equal_approx(float(batch.get("progress", -1.0)), 0.0), "manual progress should begin at zero")
		_expect_equal("manual progress source", String(batch.get("source", "")), "manual")
	if automation_progress.size() == 1:
		for batch_index in range(automation_progress.size()):
			var batch: Dictionary = automation_progress[batch_index]
			_expect(int(batch.get("queue_sequence", 0)) > 0, "automation progress should expose a persistent queue sequence")
			_expect_equal("automation progress batch index", int(batch.get("batch_index", -1)), batch_index)
			_expect_equal("automation progress duration", int(batch.get("duration_seconds", 0)), 4)
			_expect(is_equal_approx(float(batch.get("progress", -1.0)), 0.0), "automation progress should begin at zero")
			_expect_equal("automation progress source", String(batch.get("source", "")), "automation")
			_expect_equal("automation progress rule", String(batch.get("automation_rule_id", "")), "rule_batch_one")
	var halfway_summary: Dictionary = state.recipe_production_queue_summary(1001)
	var halfway_manual: Array = halfway_summary.get("rice_milk_drink", {}).get("batch_progress", [])
	if halfway_manual.size() == 1:
		_expect(is_equal_approx(float((halfway_manual[0] as Dictionary).get("progress", -1.0)), 0.5), "manual progress should use elapsed over duration")


func _test_batch_progress_sequence_is_stable() -> void:
	var state = _ready_state()
	_expect(state.queue_recipe_production("rice_milk_drink", 1, 1000, "manual"), "first sequence fixture should queue")
	_expect(state.queue_recipe_production("rich_rice_drink", 1, 1000, "manual"), "different recipe sequence fixture should queue")
	var before_summary: Dictionary = state.recipe_production_queue_summary(1000)
	var first_progress: Array = before_summary.get("rice_milk_drink", {}).get("batch_progress", [])
	var surviving_progress: Array = before_summary.get("rich_rice_drink", {}).get("batch_progress", [])
	_expect_equal("first sequence fixture count", first_progress.size(), 1)
	_expect_equal("surviving sequence fixture count", surviving_progress.size(), 1)
	if first_progress.size() != 1 or surviving_progress.size() != 1:
		return
	var first_sequence := int((first_progress[0] as Dictionary).get("queue_sequence", 0))
	var surviving_sequence := int((surviving_progress[0] as Dictionary).get("queue_sequence", 0))
	_expect(first_sequence > 0, "first task should have a positive queue sequence")
	_expect(surviving_sequence > first_sequence, "later task should have a larger queue sequence")
	_expect(state.complete_recipe_production(0, 1002), "earlier task should complete independently")
	var after_progress: Array = state.recipe_production_queue_summary(1002).get("rich_rice_drink", {}).get("batch_progress", [])
	_expect_equal("surviving sequence fixture count", after_progress.size(), 1)
	if after_progress.size() == 1:
		_expect_equal("surviving task keeps queue sequence", int((after_progress[0] as Dictionary).get("queue_sequence", 0)), surviving_sequence)
	var restored = GameState.from_dict(state.to_dict())
	var restored_progress: Array = restored.recipe_production_queue_summary(1002).get("rich_rice_drink", {}).get("batch_progress", [])
	_expect_equal("restored sequence fixture count", restored_progress.size(), 1)
	if restored_progress.size() == 1:
		_expect_equal("save roundtrip keeps queue sequence", int((restored_progress[0] as Dictionary).get("queue_sequence", 0)), surviving_sequence)


func _test_recipe_book_explains_locked_device() -> void:
	var state = _ready_state()
	state.level = 0
	state.unlocked_devices.erase("round_pot")
	var result: Dictionary = RecipeBook.make_product(state, "rice_milk_drink", 1, 1000)
	_expect(not bool(result.get("ok", false)), "locked device should reject manual production")
	_expect(String(result.get("message", "")).find("设备") >= 0 and String(result.get("message", "")).find("未解锁") >= 0, "locked device rejection should be explicit")


func _test_ready_completion_is_atomic() -> void:
	var state = _ready_state()
	state.tutorial_guide_step = "craft"
	_expect(state.queue_recipe_production("rice_milk_drink", 1, 1000, "manual"), "completion fixture should queue")
	var completed_sequence := int(state.recipe_production_queue[0].get("queue_sequence", 0))
	_expect(state.has_method("complete_ready_manual_recipe_productions"), "GameState should complete all ready manual tasks")
	_expect(state.has_method("recipe_production_queue_summary"), "GameState should summarize production queues")
	if not state.has_method("complete_ready_manual_recipe_productions") or not state.has_method("recipe_production_queue_summary"):
		return
	var summary: Dictionary = state.recipe_production_queue_summary(1001)
	var rice_summary: Dictionary = summary.get("rice_milk_drink", {})
	_expect_equal("active summary count", int(rice_summary.get("active_count", 0)), 1)
	_expect_equal("active summary remaining", int(rice_summary.get("remaining_seconds", 0)), 1)
	var early: Dictionary = state.complete_ready_manual_recipe_productions(1001)
	_expect_equal("early completion count", int(early.get("completed_batches", -1)), 0)
	_expect_equal("early product stock", state.get_product_count("rice_milk_drink"), 0)
	_expect_equal("guide waits before ready", String(state.tutorial_guide_step), "craft")
	var completed: Dictionary = state.complete_ready_manual_recipe_productions(1002)
	_expect_equal("completed batches", int(completed.get("completed_batches", 0)), 1)
	_expect_equal("completed output", int((completed.get("product_outputs", {}) as Dictionary).get("rice_milk_drink", 0)), 3)
	_expect_equal("product enters inventory", state.get_product_count("rice_milk_drink"), 3)
	_expect_equal("recipe growth records output", int(state.get_recipe_growth("rice_milk_drink").get("made_count", 0)), 3)
	_expect_equal("device growth records batch", int(state.get_device_growth("round_pot").get("production_batch_count", 0)), 1)
	_expect_equal("guide advances after completion", String(state.tutorial_guide_step), "list")
	_expect_equal("queue removed after completion", state.recipe_production_queue.size(), 0)
	var ready_record: Dictionary = state.production_ready_recipe_record("rice_milk_drink")
	_expect(not ready_record.is_empty(), "completed recipe should create a persistent row record")
	_expect_equal("completed row preserves queue sequence", int(ready_record.get("display_sequence", 0)), completed_sequence)
	var restored = GameState.from_dict(state.to_dict())
	_expect(not restored.production_ready_recipe_record("rice_milk_drink").is_empty(), "completed row record should survive save roundtrip")
	var next_sequence_state = GameState.from_dict(state.to_dict())
	_expect(next_sequence_state.queue_recipe_production("rich_rice_drink", 1, 1003, "manual"), "fixture should queue a different recipe after completion")
	_expect(int(next_sequence_state.recipe_production_queue[0].get("queue_sequence", 0)) > completed_sequence, "new active work should sort after retained completed rows")
	restored.remove_product("rice_milk_drink", restored.get_product_count("rice_milk_drink"))
	_expect(restored.production_ready_recipe_record("rice_milk_drink").is_empty(), "zero stock without active work should prune the row record")
	var retained = GameState.from_dict(state.to_dict())
	_expect(retained.queue_recipe_production("rice_milk_drink", 1, 1003, "manual"), "fixture should start a later active batch")
	retained.remove_product("rice_milk_drink", retained.get_product_count("rice_milk_drink"))
	_expect(not retained.production_ready_recipe_record("rice_milk_drink").is_empty(), "active work should keep the row after finished stock reaches zero")
	var repeated: Dictionary = state.complete_ready_manual_recipe_productions(1002)
	_expect_equal("repeated completion count", int(repeated.get("completed_batches", -1)), 0)
	_expect_equal("repeated completion stock", state.get_product_count("rice_milk_drink"), 3)


func _test_offline_manual_completion() -> void:
	var state = _ready_state()
	var save_system = SaveSystem.new()
	_expect(state.queue_recipe_production("rice_milk_drink", 1, 1000, "manual"), "offline fixture should queue")
	_expect(save_system.has_method("apply_offline_recipe_production"), "SaveSystem should settle existing manual production offline")
	if not save_system.has_method("apply_offline_recipe_production"):
		return
	var early: Dictionary = save_system.call("apply_offline_recipe_production", state, 1001)
	_expect_equal("offline early completion", int(early.get("completed_batches", -1)), 0)
	_expect_equal("offline early queue count", state.recipe_production_queue.size(), 1)
	if state.recipe_production_queue.size() == 1:
		_expect_equal("offline keeps original ready time", int(state.recipe_production_queue[0].get("ready_at_unix", 0)), 1002)
	var completed: Dictionary = save_system.call("apply_offline_recipe_production", state, 1005)
	_expect_equal("offline completed batches", int(completed.get("completed_batches", 0)), 1)
	_expect_equal("offline product stock", state.get_product_count("rice_milk_drink"), 3)
	_expect_equal("offline queue removed", state.recipe_production_queue.size(), 0)
	var report_notifications := 0
	var report_body := ""
	for notification_value: Variant in state.pending_notifications:
		if notification_value is Dictionary:
			var metadata: Dictionary = (notification_value as Dictionary).get("metadata", {})
			if String(metadata.get("kind", "")) == "recipe_production_report":
				report_notifications += 1
				report_body = String((notification_value as Dictionary).get("body", ""))
	_expect_equal("offline summary notification count", report_notifications, 1)
	_expect(report_body.find("米浆饮 x3") >= 0, "offline summary should name the completed product and quantity")
	save_system.call("apply_offline_recipe_production", state, 1005)
	_expect_equal("offline completion is idempotent", state.get_product_count("rice_milk_drink"), 3)


func _ready_state():
	var state = GameState.new_game()
	state.level = 5
	state.unlock_device("round_pot")
	state.add_recipe("rice_milk_drink")
	state.add_recipe("rich_rice_drink")
	state.add_ingredient("rice", 30)
	state.add_ingredient("spring_water", 30)
	state.add_ingredient("milk", 30)
	state.add_ingredient("sugar", 30)
	return state


func _method_argument_count(target, method_name: String) -> int:
	for method_value in target.get_method_list():
		var method: Dictionary = method_value
		if String(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("RECIPE_PRODUCTION_TIMING_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
