extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var tutorial_state = GAME_STATE.new_game()
	tutorial_state.record_task_event("harvest", {"item_id": "rice", "site_id": "farm", "amount": 1})
	_expect(tutorial_state.task_progress.is_empty(), "NPC tutorial actions must not create task progress")
	_expect(not tutorial_state.unlocked_devices.has("round_pot"), "Task events must not bypass the NPC unlock route")

	var state = GAME_STATE.new_game()
	_open_task_system(state)
	state.record_task_event("business_round_completed", _sales_report(30000, 1, 1))
	_expect(_objective_completed(state, "growth_l1_sales_rhythm", "standard_round"), "A standard round should complete its objective")
	_expect(not _objective_completed(state, "growth_l1_sales_rhythm", "repeat_sale"), "One same-product sale should not pass the repeat objective")
	_expect(_objective_completed(state, "growth_l1_sales_rhythm", "refill"), "One refill should complete its objective")
	_expect(not state.is_task_completed("growth_l1_sales_rhythm"), "Growth card should wait for every objective")

	var restored = GAME_STATE.from_dict(state.to_dict())
	_expect(_objective_completed(restored, "growth_l1_sales_rhythm", "standard_round"), "Completed objectives should survive save roundtrip")
	_expect(not _objective_completed(restored, "growth_l1_sales_rhythm", "repeat_sale"), "Incomplete objectives should survive save roundtrip")
	restored.record_task_event("business_round_completed", _sales_report(20000, 2, 0))
	_expect(_objective_completed(restored, "growth_l1_sales_rhythm", "repeat_sale"), "A later round may complete the remaining objective")
	_expect(restored.is_task_completed("growth_l1_sales_rhythm"), "Objectives may complete across different reports")

	var compact = GAME_STATE.new_game()
	_open_task_system(compact)
	compact.level = 2
	for task_id in ["growth_l1_sales_rhythm", "growth_l1_leftover_decision", "growth_l2_basic_combo"]:
		compact.completed_tasks.append(task_id)
	compact.record_task_event("business_round_completed", _compact_report(6, 79, 2, 10))
	_expect(not _objective_completed(compact, "growth_l2_compact_build", "compact_income"), "Split compact metrics across reports should not pass")
	compact.record_task_event("business_round_completed", _compact_report(7, 80, 1, 0))
	_expect(not _objective_completed(compact, "growth_l2_compact_build", "compact_income"), "A report over the cell limit should not pass")
	compact.record_task_event("business_round_completed", _compact_report(6, 80, 1, 0))
	_expect(_objective_completed(compact, "growth_l2_compact_build", "compact_income"), "Both compact metrics in one report should pass")
	_expect(compact.is_task_completed("growth_l2_compact_build"), "Different objectives may complete across different reports")

	_finish()


func _open_task_system(state) -> void:
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage", "task"]:
		state.unlock_core_feature(feature_id)
	state.level = maxi(1, int(state.level))


func _sales_report(duration_ms: int, max_product_sold: int, refill_actions: int) -> Dictionary:
	return {
		"is_complete": true,
		"report_id": "objective:sales:%d:%d:%d" % [duration_ms, max_product_sold, refill_actions],
		"round_id": duration_ms + max_product_sold + refill_actions,
		"duration_ms": duration_ms,
		"counts": {"sold": max_product_sold, "refill_actions": refill_actions},
		"max_product_sold": max_product_sold
	}


func _compact_report(occupied_cells: int, total_coins: int, distinct_roles: int, layout_extra_income: int) -> Dictionary:
	return {
		"is_complete": true,
		"report_id": "objective:%d:%d:%d:%d" % [occupied_cells, total_coins, distinct_roles, layout_extra_income],
		"round_id": total_coins + occupied_cells,
		"duration_ms": 30000,
		"counts": {"sold": 3, "refill_actions": 0, "forced_clearance": 0},
		"layout": {"occupied_cells": occupied_cells, "distinct_roles": distinct_roles, "max_shared_tag": 1},
		"total_coins": total_coins,
		"layout_extra_income": layout_extra_income,
		"max_product_sold": 1,
		"sold_distinct_recipes": 1
	}


func _objective_completed(state, task_id: String, objective_id: String) -> bool:
	var task_progress: Dictionary = state.task_progress.get(task_id, {})
	var objectives: Dictionary = task_progress.get("objectives", {})
	var objective: Dictionary = objectives.get(objective_id, {})
	return bool(objective.get("completed", false))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TASK_OBJECTIVE_PROGRESS_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("TASK_OBJECTIVE_PROGRESS_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
