extends SceneTree

const VIEW_PATH := "res://scenes/challenge/challenge_battle_view.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	if not ResourceLoader.exists(VIEW_PATH):
		_fail("challenge battle view scene should exist")
		_finish()
		return
	var view_scene = load(VIEW_PATH)
	_expect(view_scene != null, "challenge battle view scene should load")
	if view_scene == null:
		_finish()
		return
	var view = view_scene.instantiate()
	root.add_child(view)
	await process_frame

	_expect(view.get_node("TopStatus/ReputationBar") is ProgressBar, "reputation bar should exist")
	_expect(view.get_node("TopStatus/PickinessBar") is ProgressBar, "pickiness bar should exist")
	_expect(view.get_node("BossPanel/DemandTimeline").get_child_count() == 4, "timeline should show 8/16/24/30")

	var encounter := _encounter()
	var snapshot := _snapshot()
	view.call("bind_encounter", encounter)
	var finished_count := {"value": 0}
	view.connect("battle_finished", func(_final_state: Dictionary) -> void:
		finished_count["value"] = int(finished_count["value"]) + 1
	)
	view.call("start_battle", snapshot, 42)
	_expect(bool(view.get("battle_locked")), "battle should lock immediately")
	view.call("advance_for_test", 16000)
	_expect(view.get_node("BossPanel/DemandTimeline/Window16").has_theme_color_override("font_color"), "current window should be visually resolved")

	var saved_state: Dictionary = (view.get("battle_state") as Dictionary).duplicate(true)
	view.call("restore_battle", saved_state, encounter)
	_expect(bool(view.get("battle_paused")), "restored battle should start paused")
	view.call("advance_for_test", 24000)
	_expect(int((view.get("battle_state") as Dictionary).get("elapsed_ms", 0)) == 16000, "paused restored battle should not advance")
	view.call("set_paused", false)
	view.call("advance_for_test", 24000)
	_expect(int((view.get("battle_state") as Dictionary).get("elapsed_ms", 0)) == 24000, "continued battle should resume from saved time")

	view.call("advance_for_test", 30000)
	_expect(int(finished_count["value"]) == 1, "battle_finished should fire once at completion")
	view.call("advance_for_test", 30000)
	_expect(int(finished_count["value"]) == 1, "completed battle should not emit battle_finished twice")
	_expect(not bool(view.get("battle_paused")), "completed battle should not masquerade as paused")

	view.queue_free()
	await process_frame
	_finish()


func _snapshot() -> Dictionary:
	return {
		"grid_rows": 6,
		"grid_columns": 8,
		"spent_budget": 2,
		"encounter_id": "test_boss",
		"relations": [],
		"instances": [
			{
				"instance_id": "cookie",
				"recipe_id": "butter_cookie",
				"cycle_ms": 4000,
				"virtual_stock": 6,
				"base_satisfaction": 4,
				"tags": ["fast", "bake"],
				"cells": [[2, 3]]
			}
		]
	}


func _encounter() -> Dictionary:
	return {
		"duration_ms": 30000,
		"initial_pickiness": 999,
		"initial_reputation": 100,
		"relation_bonus_pct": 25,
		"relation": {"id": "drink_bake_pair", "left_tag": "drink", "right_tag": "bake"},
		"windows": [
			{"id": "early_tempo", "at_ms": 8000, "metric": "sales_count", "target": 0, "reputation_damage": 25},
			{"id": "linked_display", "at_ms": 16000, "metric": "active_relation_count", "target": 0, "reputation_damage": 30},
			{"id": "sustained_service", "at_ms": 24000, "from_ms": 16000, "metric": "window_satisfaction", "target": 0, "reputation_damage": 45}
		]
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_BATTLE_VIEW_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
