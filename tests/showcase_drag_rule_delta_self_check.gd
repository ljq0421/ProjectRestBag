extends SceneTree

const SHOWCASE_RULE_SERVICE := preload("res://scripts/showcase_rule_service.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var before := {
		"reasons": [
			{"source": "adjacency", "text": "果香清爽相邻", "price_pct": 8.0, "speed_pct": 5.0},
			{"source": "set", "text": "经典下午茶套装", "price_pct": 15.0, "speed_pct": 10.0}
		]
	}
	var after := {
		"reasons": [
			{"source": "adjacency", "text": "果香清爽相邻", "price_pct": 8.0, "speed_pct": 5.0},
			{"source": "variant", "text": "试吃变体", "price_pct": -35.0, "speed_pct": 40.0},
			{"source": "conflict", "text": "口感冲突", "price_pct": -8.0, "speed_pct": 0.0},
			{"source": "position", "text": "跨区：无区域效果", "price_pct": 0.0, "speed_pct": 0.0}
		]
	}
	var delta: Dictionary = SHOWCASE_RULE_SERVICE.rule_difference(before, after)
	if not _joined(delta.get("added", [])).contains("试吃变体"):
		_fail("rule difference should report newly gained rules")
	if not _joined(delta.get("lost", [])).contains("经典下午茶套装"):
		_fail("rule difference should report lost rules")
	var risks := _joined(delta.get("risks", []))
	if not risks.contains("口感冲突") or not risks.contains("跨区"):
		_fail("rule difference should report negative and structural risks")

	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var state = GAME_STATE.new_game()
	state.level = 2
	state.add_recipe("butter_cookie")
	state.add_product("butter_cookie", 1)
	state.list_display_item("butter_cookie", [Vector2i(6, 6)], 1)
	main.set("state", state)
	main.call("_invalidate_showcase_bonus_cache")
	var preview_text := String(main.call("_showcase_preview_bonus_text", "butter_cookie", [Vector2i(5, 6)], "move", "standard"))
	for heading in ["新增：", "失去：", "风险："]:
		if preview_text.find(heading) == -1:
			_fail("drag preview should always expose line: %s" % heading)
	main.queue_free()
	_finish()


func _joined(values_value: Variant) -> String:
	var values: Array = values_value if values_value is Array else []
	var texts: Array[String] = []
	for value in values:
		texts.append(String(value))
	return "\n".join(texts)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_DRAG_RULE_DELTA_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHOWCASE_DRAG_RULE_DELTA_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
