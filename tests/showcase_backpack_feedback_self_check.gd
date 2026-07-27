extends SceneTree

const DIRECTOR := preload("res://scripts/ui/storefront/showcase_feedback_director.gd")
const MAIN_VIEW := preload("res://scripts/main_view.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect_four_full_events_before_queue()
	_expect_feedback_constants()
	_expect_whole_item_progress_contract()
	_expect_coin_arc_targets_top_bar()
	_expect_storefront_page_is_read_only_realtime_board()
	_finish()


func _expect_four_full_events_before_queue() -> void:
	var director = DIRECTOR.new()
	for index in range(5):
		director.enqueue_sale({"recipe_id": "item_%d" % index, "earned_coins": 10 + index}, 1000)
	var batch: Dictionary = director.drain_visual_batch()
	if (batch.get("events", []) as Array).size() != 4:
		_fail("feedback director should keep four complete sale effects")
	if director.pending_count() != 1:
		_fail("the fifth simultaneous sale should wait for a visual slot")
	director.release_visual_slot("item_0")
	var resumed: Dictionary = director.drain_visual_batch()
	if (resumed.get("events", []) as Array).size() != 1:
		_fail("queued sale should resume individually after a slot releases")


func _expect_feedback_constants() -> void:
	if MAIN_VIEW == null:
		_fail("main view script should compile and instantiate")
		return
	var view = MAIN_VIEW.new()
	var constants: Dictionary = view.get_script().get_script_constant_map()
	view.free()
	var expected := {
		"SHOWCASE_FEEDBACK_QUEUE_DELAY_SECONDS": 0.15,
		"SHOWCASE_FEEDBACK_COIN_SECONDS": 2.2,
		"SHOWCASE_COIN_MIN_COUNT": 3,
		"SHOWCASE_COIN_MAX_COUNT": 6
	}
	for constant_name in expected.keys():
		if not constants.has(constant_name):
			_fail("main view should define %s" % constant_name)
		elif not is_equal_approx(float(constants[constant_name]), float(expected[constant_name])):
			_fail("%s should equal %s" % [constant_name, expected[constant_name]])


func _expect_whole_item_progress_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main_view.gd")
	for required in ["showcase_progress_bars", "_refresh_showcase_group_progress_bars", "_showcase_group_rect", "_showcase_round_item_view"]:
		if source.find(required) == -1:
			_fail("whole-item progress implementation should include %s" % required)
	if source.find("待补货") == -1:
		_fail("sold-out placements should expose a visible refill state")


func _expect_coin_arc_targets_top_bar() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main_view.gd")
	for required in ["_spawn_showcase_coin_burst", "_set_showcase_coin_arc_position", "_coins_label_center", "_animate_coins_label_gain"]:
		if source.find(required) == -1:
			_fail("coin feedback should include %s" % required)
	if source.find("coins_label.get_global_rect().get_center()") == -1:
		_fail("flying coins should target the top-bar CoinsLabel")


func _expect_storefront_page_is_read_only_realtime_board() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main_view.gd")
	for required_text in ["本轮成交", "本轮环境", "最近成交", "待补货", "特殊挑战", "最近营业报告"]:
		if source.find(required_text) == -1:
			_fail("storefront management page should contain %s" % required_text)
	if source.find("action_row.visible = false") == -1:
		_fail("storefront management page should remove centralized cashier actions")


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_BACKPACK_FEEDBACK_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	print("SHOWCASE_BACKPACK_FEEDBACK_SELF_CHECK_FAIL: %s" % " | ".join(_failures))
	quit(1)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)
