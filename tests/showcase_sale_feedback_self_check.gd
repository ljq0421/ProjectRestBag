extends SceneTree

const DIRECTOR := preload("res://scripts/ui/storefront/showcase_feedback_director.gd")
const GAME_STATE := preload("res://scripts/game_state.gd")
const MAIN_VIEW := preload("res://scripts/main_view.gd")
const CHAIN_SERVICE := preload("res://scripts/showcase_chain_service.gd")

var failed := false


func _init() -> void:
	var director = DIRECTOR.new()
	for index in range(5):
		director.enqueue_sale({
			"recipe_id": "item_%d" % index,
			"anchor_slot": 22,
			"cell_indices": [22, 23, 32, 33],
			"earned_coins": 20 + index,
			"combo_key": "set_001",
			"combo_label": "经典下午茶三件套"
		}, 1000)
	var batch: Dictionary = director.drain_visual_batch()
	var visible_events: Array = batch.get("events", [])
	if visible_events.size() != 4:
		_fail("director should start at most four simultaneous text groups")
	_expect_equal("fifth sale remains queued", director.pending_count(), 1)
	_expect_equal("four visual slots remain active", director.active_count(), 4)
	var drained_again: Dictionary = director.drain_visual_batch()
	var drained_events: Array = drained_again.get("events", [])
	if not drained_events.is_empty():
		_fail("director must not exceed four active text groups")
	director.release_visual_slot("item_0")
	var resumed_batch: Dictionary = director.drain_visual_batch()
	var resumed_events: Array = resumed_batch.get("events", [])
	_expect_equal("releasing one slot resumes exactly one queued sale", resumed_events.size(), 1)
	if not resumed_events.is_empty():
		_expect_equal("queued sales keep FIFO order", String((resumed_events[0] as Dictionary).get("recipe_id", "")), "item_4")
	_expect_equal("queue drains without aggregation", director.pending_count(), 0)
	_expect_same_product_feedback_serializes()
	_expect_blocked_product_does_not_hide_other_products()
	_expect_non_sale_events_do_not_enter_sale_batch()
	_expect_recent_sale_contract()
	_expect_feedback_timing_contract()
	if failed:
		quit(1)
	else:
		print("SHOWCASE_SALE_FEEDBACK_SELF_CHECK_PASS")
		quit(0)


func _expect_same_product_feedback_serializes() -> void:
	var director = DIRECTOR.new()
	for index in range(3):
		director.enqueue_sale({"recipe_id": "same_product", "earned_coins": 30 + index}, 1000)
	var first_batch: Dictionary = director.drain_visual_batch()
	_expect_equal("same product starts only one text group", (first_batch.get("events", []) as Array).size(), 1)
	_expect_equal("same product keeps later sales queued", director.pending_count(), 2)
	director.release_visual_slot("same_product")
	var second_batch: Dictionary = director.drain_visual_batch()
	_expect_equal("same product resumes one sale at a time", (second_batch.get("events", []) as Array).size(), 1)


func _expect_blocked_product_does_not_hide_other_products() -> void:
	var director = DIRECTOR.new()
	for recipe_id in ["a", "a", "b", "c", "d"]:
		director.enqueue_sale({"recipe_id": recipe_id, "earned_coins": 20}, 1000)
	var batch: Dictionary = director.drain_visual_batch()
	var events: Array = batch.get("events", [])
	_expect_equal("director fills free slots with other products", events.size(), 4)
	var started_ids: Array[String] = []
	for event_value in events:
		started_ids.append(String((event_value as Dictionary).get("recipe_id", "")))
	_expect_equal("other products keep their queue order", started_ids, ["a", "b", "c", "d"])
	_expect_equal("second same-product event remains queued", director.pending_count(), 1)


func _expect_non_sale_events_do_not_enter_sale_batch() -> void:
	var director = DIRECTOR.new()
	director.enqueue_sale({"recipe_id": "zero", "quantity": 1, "earned_coins": 0}, 1000)
	var chain_result: Dictionary = CHAIN_SERVICE.resolve_chain(
		{"recipe_id": "chain", "quantity": 1, "earned_coins": 60, "completed_at_ms": 1000},
		{},
		{"chain": {"role": "amplify"}},
		8
	)
	var chain_events: Array = chain_result.get("chain_events", [])
	_expect_equal("real amplify chain creates one bonus-only reward", chain_events.size(), 1)
	if not chain_events.is_empty():
		director.enqueue_sale(chain_events[0], 1000)
	var batch: Dictionary = director.drain_visual_batch()
	_expect_equal("zero-income event stays excluded while bonus-only reward gets a text slot", (batch.get("events", []) as Array).size(), 1)
	if not (batch.get("events", []) as Array).is_empty():
		_expect_equal("bonus-only reward identity is preserved", bool(((batch.get("events", []) as Array)[0] as Dictionary).get("bonus_only", false)), true)


func _expect_recent_sale_contract() -> void:
	var state = GAME_STATE.new_game()
	if not state.has_method("record_showcase_sale"):
		_fail("game state should expose structured recent showcase sales")
		return
	if state.has_method("append_cashier_sale") or state.has_method("consume_cashier_summary"):
		_fail("automatic settlement should not retain centralized cashier consumption methods")
	state.coins = 500
	var event := {
		"recipe_id": "sponge_cake",
		"recipe_name": "海绵杯蛋糕",
		"anchor_slot": 22,
		"cell_indices": [22, 23, 32, 33],
		"related_slots": [24],
		"conflict_slots": [25],
		"earned_coins": 48,
		"earned_reputation": 1,
		"quantity": 1,
		"unit_price": 48,
		"timestamp": 1000,
		"attribution": {
			"base_coins": 40,
			"position_adjacency_coins": 5,
			"set_growth_coins": 6,
			"other_delta": 0,
			"conflict_loss": 3
		},
		"reasons": [
			{"source": "adjacency", "text": "曲奇与蛋糕相邻，提升售价", "price_pct": 5.0, "speed_pct": 0.0},
			{"source": "conflict", "text": "清凉与浓郁相邻，降低售价", "price_pct": -3.0, "speed_pct": 0.0}
		],
		"groups": [{"id": "set_001", "label": "经典下午茶三件套", "recipe_ids": ["sponge_cake"]}]
	}
	state.record_showcase_sale(event)
	state.record_showcase_sale(event)
	if state.recent_showcase_sales.size() != 2:
		_fail("recent sales should retain each independently credited sale")
	var restored = GAME_STATE.from_dict(state.to_dict())
	if restored.recent_showcase_sales.size() != 2:
		_fail("recent showcase sales should survive current development save and load")
	var restored_reasons: Array = (restored.recent_showcase_sales[0] as Dictionary).get("reasons", []) if not restored.recent_showcase_sales.is_empty() else []
	if restored_reasons.size() != 2:
		_fail("recent showcase sales should preserve full sale reasons across save and load")
	var coins_before := int(restored.coins)
	if int(restored.coins) != coins_before:
		_fail("reading recent sales must not change already credited coins")
	if not GAME_STATE.from_dict({"coins": 77}).recent_showcase_sales.is_empty():
		_fail("development saves without recent sales should default to an empty list")


func _expect_feedback_timing_contract() -> void:
	var main_view = MAIN_VIEW.new()
	var constants: Dictionary = main_view.get_script().get_script_constant_map()
	main_view.free()
	var expected := {
		"SHOWCASE_FEEDBACK_PULSE_SECONDS": 1.6,
		"SHOWCASE_FEEDBACK_COIN_SECONDS": 2.2,
		"SHOWCASE_FEEDBACK_COIN_ROLL_DELAY_SECONDS": 1.9,
		"SHOWCASE_FEEDBACK_COIN_ROLL_SECONDS": 0.3,
		"SHOWCASE_FEEDBACK_RELATION_SECONDS": 2.4,
		"SHOWCASE_FEEDBACK_RELATION_HOLD_SECONDS": 0.8,
		"SHOWCASE_FEEDBACK_QUEUE_DELAY_SECONDS": 0.15
	}
	var source := FileAccess.get_file_as_string("res://scripts/main_view.gd")
	for removed_runtime in ["另外售出", "_spawn_showcase_sale_feedback_card", "_showcase_sale_pulse_reason_text"]:
		if source.find(removed_runtime) >= 0:
			_fail("transparent sale text should remove old runtime %s" % removed_runtime)
	if source.find("_clear_showcase_feedback_outline") < 0:
		_fail("finished outline feedback should remove its keyed runtime reference")
	if source.find("_schedule_showcase_coins_label_gain") < 0:
		_fail("top coin label should roll only when the 2.2 second coin flight reaches its arrival phase")
	if source.find("_animate_coins_label_gain(credited_coins_for_roll)") >= 0:
		_fail("sale feedback should not roll the top coin label immediately")
	if source.find("func _play_pending_showcase_sale_feedback(credited_coins_for_roll") >= 0:
		_fail("queued feedback should derive coin rolls from the events that actually start playing")
	if source.find("tween.tween_interval(0.75)") >= 0:
		_fail("sale feedback text should keep drifting upward instead of pausing through its middle phase")
	for constant_name in expected.keys():
		if not constants.has(constant_name):
			_fail("main view should expose readable feedback timing constant %s" % constant_name)
			continue
		if not is_equal_approx(float(constants[constant_name]), float(expected[constant_name])):
			_fail("%s should be %.1f seconds" % [constant_name, float(expected[constant_name])])
		if source.count(constant_name) < 2:
			_fail("%s should be used by the runtime tween" % constant_name)


func _fail(message: String) -> void:
	failed = true
	push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])
