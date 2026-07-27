extends SceneTree

const SERVICE_PATH := "res://scripts/business_round_service.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ResourceLoader.exists(SERVICE_PATH):
		_fail("BusinessRoundService should exist")
		_finish()
		return
	var service := load(SERVICE_PATH)
	if service == null or not service.has_method("create_standard"):
		_fail("BusinessRoundService should expose create_standard")
		_finish()
		return

	var round: Dictionary = service.create_standard(7)
	_expect_equal("round id", int(round.get("round_id", 0)), 7)
	_expect_equal("round kind", String(round.get("kind", "")), "standard")
	_expect_equal("initial phase", String(round.get("phase", "")), "adjusting")
	_expect_equal("standard duration", int(round.get("duration_ms", 0)), 30000)
	_expect_equal("initial elapsed", int(round.get("elapsed_ms", -1)), 0)
	_expect_equal("initial remaining", int(round.get("remaining_ms", 0)), 30000)
	_expect_equal("initial heat", int(round.get("heat", -1)), 0)

	if not service.has_method("start_round") or not service.has_method("advance"):
		_fail("BusinessRoundService should expose start_round and advance")
		_finish()
		return
	var started: Dictionary = service.start_round(round, {"layout": "locked"}, {"item": {"stock": 2}})
	_expect_equal("started phase", String(started.get("phase", "")), "running")
	_expect_equal("layout snapshot", String((started.get("layout_snapshot", {}) as Dictionary).get("layout", "")), "locked")
	_expect_equal("item snapshot stock", int(((started.get("item_states", {}) as Dictionary).get("item", {}) as Dictionary).get("stock", 0)), 2)

	var almost_done: Dictionary = service.advance(started, 29999)
	_expect_equal("almost done phase", String(almost_done.get("phase", "")), "running")
	_expect_equal("almost done elapsed", int(almost_done.get("elapsed_ms", 0)), 29999)
	_expect_equal("almost done remaining", int(almost_done.get("remaining_ms", 0)), 1)

	var ended: Dictionary = service.advance(almost_done, 1)
	_expect_equal("end phase", String(ended.get("phase", "")), "settlement")
	_expect_equal("end elapsed", int(ended.get("elapsed_ms", 0)), 30000)
	_expect_equal("end remaining", int(ended.get("remaining_ms", -1)), 0)

	var repeated_end: Dictionary = service.advance(ended, 5000)
	_expect_equal("ended round does not advance", int(repeated_end.get("elapsed_ms", 0)), 30000)

	if not service.has_method("pause") or not service.has_method("resume"):
		_fail("BusinessRoundService should expose pause and resume")
	else:
		var running_again: Dictionary = service.start_round(service.create_standard(8), {}, {})
		var paused: Dictionary = service.pause(service.advance(running_again, 5000))
		_expect_equal("paused marker", bool(paused.get("paused", false)), true)
		var paused_advanced: Dictionary = service.advance(paused, 7000)
		_expect_equal("paused elapsed stays fixed", int(paused_advanced.get("elapsed_ms", 0)), 5000)
		var resumed: Dictionary = service.resume(paused_advanced)
		_expect_equal("resumed marker", bool(resumed.get("paused", true)), false)
		_expect_equal("resumed round advances", int(service.advance(resumed, 1000).get("elapsed_ms", 0)), 6000)

	if not service.has_method("create_challenge"):
		_fail("BusinessRoundService should expose create_challenge")
	else:
		var challenge: Dictionary = service.create_challenge(9, 20, {"id": "short_shift"})
		_expect_equal("challenge kind", String(challenge.get("kind", "")), "challenge")
		_expect_equal("challenge duration", int(challenge.get("duration_ms", 0)), 20000)
		_expect_equal("challenge id", String((challenge.get("challenge", {}) as Dictionary).get("id", "")), "short_shift")
		_expect_equal("standard remains thirty seconds", int(service.create_standard(10).get("duration_ms", 0)), 30000)

	if not service.has_method("complete_settlement"):
		_fail("BusinessRoundService should expose complete_settlement")
	else:
		var next_round: Dictionary = service.complete_settlement(ended)
		_expect_equal("next round id", int(next_round.get("round_id", 0)), 8)
		_expect_equal("next round phase", String(next_round.get("phase", "")), "adjusting")
		_expect_equal("completed round id", int(next_round.get("previous_round_id", 0)), 7)
		var duplicate_completion: Dictionary = service.complete_settlement(next_round)
		_expect_equal("duplicate completion does not advance id", int(duplicate_completion.get("round_id", 0)), 8)
	_finish()


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BUSINESS_ROUND_SERVICE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("BUSINESS_ROUND_SERVICE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
