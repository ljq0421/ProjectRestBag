extends SceneTree

const VIEW_PATH := "res://scenes/challenge/challenge_battle_view.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var packed_scene = load(VIEW_PATH)
	_expect(packed_scene != null, "battle view scene should load")
	if packed_scene == null:
		_finish()
		return
	var view = packed_scene.instantiate()
	root.add_child(view)
	await process_frame

	var timeline := view.get_node("BossPanel/DemandTimeline") as VBoxContainer
	_expect(timeline != null, "dynamic demand timeline should exist")
	_expect(timeline.get_child_count() == 0, "scene should not contain fixed demand rows")

	var encounter := {
		"display_name": "标签品鉴",
		"duration_ms": 31000,
		"initial_pickiness": 999,
		"initial_reputation": 100,
		"relation_bonus_pct": 0,
		"relation": {},
		"windows": [
			{
				"id": "fruit_open",
				"at_ms": 7000,
				"metric": "tag_sales_count",
				"tag": "fruit",
				"target": 1,
				"reputation_damage": 10
			},
			{
				"id": "variety_finale",
				"at_ms": 19000,
				"metric": "distinct_tag_count",
				"target_tags": ["fruit", "bake"],
				"target": 2,
				"reputation_damage": 10
			}
		]
	}
	view.call("bind_encounter", encounter)
	_expect(timeline.get_child_count() == 3, "two encounter windows should create two rows plus the deadline")
	var first := timeline.get_child(0) as Label
	var second := timeline.get_child(1) as Label
	var deadline := timeline.get_child(2) as Label
	_expect(first.get_meta("window_id", "") == "fruit_open", "first row should preserve encounter order and id")
	_expect(first.text == "07s｜标签出餐（水果） ≥ 1", "single-tag metric should show its translated tag context")
	_expect(second.text == "19s｜售出标签种类（水果 / 烘焙） ≥ 2", "multi-tag metric should show translated targets")
	_expect(deadline.get_meta("timeline_kind", "") == "deadline", "final row should be a dedicated deadline")
	_expect(deadline.text.begins_with("31s｜"), "final deadline should remain visible at the encounter duration")

	var snapshot := {
		"grid_rows": 6,
		"grid_columns": 8,
		"instances": [
			{
				"instance_id": "jelly",
				"recipe_id": "strawberry_jelly",
				"cycle_ms": 7000,
				"virtual_stock": 2,
				"base_satisfaction": 5,
				"tags": ["fruit", "fast"],
				"cells": [[0, 0]]
			},
			{
				"instance_id": "cookie",
				"recipe_id": "butter_cookie",
				"cycle_ms": 19000,
				"virtual_stock": 1,
				"base_satisfaction": 4,
				"tags": ["bake", "fast"],
				"cells": [[0, 1]]
			}
		],
		"relations": []
	}
	view.call("start_battle", snapshot, 77)
	view.call("advance_for_test", 7000)
	_expect(first.text == "✓ 07s｜标签出餐（水果） ≥ 1｜实际 1", "resolved UI should display translated context, target, and actual without the internal ID")
	view.call("advance_for_test", 19000)
	_expect(second.text == "✓ 19s｜售出标签种类（水果 / 烘焙） ≥ 2｜实际 2", "later dynamic row should resolve without exposing its internal ID")

	var shorter_encounter := encounter.duplicate(true)
	shorter_encounter["duration_ms"] = 15000
	shorter_encounter["windows"] = [
		{
			"id": "single",
			"at_ms": 9000,
			"metric": "tag_satisfaction",
			"tag": "bake",
			"target": 4,
			"reputation_damage": 10
		}
	]
	view.call("bind_encounter", shorter_encounter)
	_expect(timeline.get_child_count() == 2, "rebinding should replace old rows instead of retaining them")
	_expect((timeline.get_child(0) as Label).get_meta("window_id", "") == "single", "rebuilt row should use the new encounter")
	_expect((timeline.get_child(1) as Label).text.begins_with("15s｜"), "rebuilt timeline should use the new deadline")

	view.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_DYNAMIC_TIMELINE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
