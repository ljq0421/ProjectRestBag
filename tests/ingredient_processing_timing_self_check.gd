extends SceneTree

const Catalog := preload("res://scripts/catalog.gd")
const GameState := preload("res://scripts/game_state.gd")
const RecipeBook := preload("res://scripts/recipe_book.gd")
const SaveSystem := preload("res://scripts/save_system.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_catalog_durations()
	_test_parallel_single_batch_rule()
	_test_recipe_book_starts_timed_work()
	_test_completion_and_save_roundtrip()
	_test_offline_completion()
	_finish()


func _test_catalog_durations() -> void:
	_expect_equal("rice flour duration", Catalog.processing_recipe_duration("rice_flour_process"), 2)
	_expect_equal("wheat flour duration", Catalog.processing_recipe_duration("wheat_flour_process"), 2)
	_expect_equal("glutinous rice flour duration", Catalog.processing_recipe_duration("glutinous_rice_flour_process"), 4)
	_expect_equal("cocoa duration", Catalog.processing_recipe_duration("cocoa_process"), 4)
	_expect_equal("matcha duration", Catalog.processing_recipe_duration("matcha_process"), 4)
	_expect_equal("yogurt duration", Catalog.processing_recipe_duration("yogurt_process"), 8)


func _test_parallel_single_batch_rule() -> void:
	var state = _ready_state()
	var rice_before: int = state.get_ingredient_count("rice")
	_expect(state.queue_ingredient_processing("rice_flour_process", 1000), "rice flour process should start")
	_expect_equal("rice consumed at start", state.get_ingredient_count("rice"), rice_before - 1)
	_expect_equal("rice flour waits for completion", state.get_ingredient_count("rice_flour"), 0)
	var rice_after_start: int = state.get_ingredient_count("rice")
	_expect(not state.queue_ingredient_processing("rice_flour_process", 1001), "same process should not start twice")
	_expect_equal("blocked duplicate keeps input", state.get_ingredient_count("rice"), rice_after_start)
	_expect(state.queue_ingredient_processing("wheat_flour_process", 1000), "different process should run concurrently")
	_expect_equal("parallel processing task count", state.ingredient_processing_queue.size(), 2)
	var summary: Dictionary = state.ingredient_processing_queue_summary(1001)
	_expect_equal("rice processing active count", int(summary.get("rice_flour_process", {}).get("active_count", 0)), 1)
	_expect_equal("rice processing remaining", int(summary.get("rice_flour_process", {}).get("remaining_seconds", -1)), 1)
	_expect(is_equal_approx(float(summary.get("rice_flour_process", {}).get("progress", -1.0)), 0.5), "rice processing should be halfway")


func _test_recipe_book_starts_timed_work() -> void:
	var state = _ready_state()
	var rice_before: int = state.get_ingredient_count("rice")
	var result: Dictionary = RecipeBook.process_ingredient(state, "grinder", ["rice"], 1000)
	_expect(bool(result.get("ok", false)), "RecipeBook processing should start")
	_expect_equal("processing result status", String(result.get("status", "")), "started")
	_expect_equal("processing result duration", int(result.get("duration_seconds", 0)), 2)
	_expect_equal("RecipeBook consumes input", state.get_ingredient_count("rice"), rice_before - 1)
	_expect_equal("RecipeBook defers output", state.get_ingredient_count("rice_flour"), 0)
	_expect_equal("RecipeBook creates one timed task", state.ingredient_processing_queue.size(), 1)
	var duplicate: Dictionary = RecipeBook.process_ingredient(state, "grinder", ["rice"], 1001)
	_expect(not bool(duplicate.get("ok", false)), "RecipeBook should reject duplicate active processing")
	_expect(String(duplicate.get("message", "")).find("只能制作 1 批") >= 0, "duplicate rejection should explain the one-batch rule")


func _test_completion_and_save_roundtrip() -> void:
	var state = _ready_state()
	_expect(state.queue_ingredient_processing("yogurt_process", 2000), "yogurt should start")
	var restored = GameState.from_dict(state.to_dict())
	_expect_equal("processing queue survives save", restored.ingredient_processing_queue.size(), 1)
	_expect_equal("saved process id", String(restored.ingredient_processing_queue[0].get("process_id", "")), "yogurt_process")
	_expect(not restored.complete_ingredient_processing(0, 2007), "processing should not complete early")
	_expect_equal("early completion has no yogurt", restored.get_ingredient_count("yogurt"), 0)
	_expect(restored.complete_ingredient_processing(0, 2008), "processing should complete at ready time")
	_expect_equal("yogurt output enters inventory", restored.get_ingredient_count("yogurt"), 1)
	_expect_equal("completed processing leaves queue", restored.ingredient_processing_queue.size(), 0)
	_expect(restored.is_ingredient_process_unlocked("yogurt"), "completion should retain the process unlock")


func _test_offline_completion() -> void:
	var state = _ready_state()
	_expect(state.queue_ingredient_processing("rice_flour_process", 3000), "offline fixture should start")
	var early: Dictionary = SaveSystem.apply_offline_recipe_production(state, 3001)
	_expect_equal("offline early processing count", int(early.get("completed_processes", -1)), 0)
	_expect_equal("offline early queue remains", state.ingredient_processing_queue.size(), 1)
	var completed: Dictionary = SaveSystem.apply_offline_recipe_production(state, 3005)
	_expect_equal("offline processing count", int(completed.get("completed_processes", 0)), 1)
	_expect_equal("offline ingredient output", int((completed.get("ingredient_outputs", {}) as Dictionary).get("rice_flour", 0)), 2)
	_expect_equal("offline output enters inventory", state.get_ingredient_count("rice_flour"), 2)
	_expect_equal("offline queue clears", state.ingredient_processing_queue.size(), 0)
	SaveSystem.apply_offline_recipe_production(state, 3005)
	_expect_equal("offline processing is idempotent", state.get_ingredient_count("rice_flour"), 2)


func _ready_state():
	var state = GameState.new_game()
	state.level = 5
	state.unlock_device("grinder")
	state.unlock_device("round_pot")
	for item_id in ["rice", "wheat", "glutinous_rice", "coffee", "green_tea", "milk", "yeast"]:
		state.add_ingredient(item_id, 10)
	return state


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("INGREDIENT_PROCESSING_TIMING_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
