extends SceneTree

const GAME_STATE_PATH := "res://scripts/game_state.gd"
const RECIPE_BOOK_PATH := "res://scripts/recipe_book.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state_script := load(GAME_STATE_PATH)
	var recipe_book_script := load(RECIPE_BOOK_PATH)
	if game_state_script == null:
		_fail("GameState script is missing")
		_finish()
		return
	if recipe_book_script == null:
		_fail("RecipeBook script is missing")
		_finish()
		return

	var state = game_state_script.new_game()
	state.add_ingredient("rice", 1)
	state.add_ingredient("spring_water", 1)
	state.unlock_device("round_pot")

	var result: Dictionary = recipe_book_script.research(state, "round_pot", ["rice", "spring_water"])
	if not bool(result.get("ok", false)):
		_fail("rice_milk_drink research should succeed: %s" % str(result))
		_finish()
		return

	var notifications: Array = state.to_dict().get("pending_notifications", [])
	if notifications.size() != 1:
		_fail("rice-milk research should enqueue one recipe notification, got %d" % notifications.size())
	else:
		_expect_notification_contains("recipe unlock notification title", notifications[0], "解锁新配方")
		_expect_notification_contains("recipe unlock notification recipe", notifications[0], "米浆饮")
		_expect_notification_contains("recipe unlock notification device", notifications[0], "圆锅")

	var notification_count := notifications.size()
	state.add_ingredient("rice", 1)
	state.add_ingredient("spring_water", 1)
	var duplicate_result: Dictionary = recipe_book_script.research(state, "round_pot", ["rice", "spring_water"])
	if bool(duplicate_result.get("ok", false)):
		_fail("duplicate rice_milk_drink research should fail")
	_expect_array_size("duplicate research should not enqueue notifications", state.to_dict().get("pending_notifications", []), notification_count)

	_finish()


func _expect_notification_contains(label: String, notification: Dictionary, expected: String) -> void:
	var combined := "%s\n%s" % [
		String(notification.get("title", "")),
		String(notification.get("body", ""))
	]
	if combined.find(expected) == -1:
		_fail("%s should contain %s, got %s" % [label, expected, combined])


func _expect_array_size(label: String, value: Variant, expected: int) -> void:
	if not value is Array:
		_fail("%s should be an Array" % label)
		return

	var values: Array = value as Array
	if values.size() != expected:
		_fail("%s expected size %d, got %d" % [label, expected, values.size()])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RECIPE_UNLOCK_NOTIFICATION_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("RECIPE_UNLOCK_NOTIFICATION_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
