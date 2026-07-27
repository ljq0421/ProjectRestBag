extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const TASK_SERVICE := preload("res://scripts/task_service.gd")

const GROWTH_IDS := [
	"growth_l1_sales_rhythm",
	"growth_l1_leftover_decision",
	"growth_l2_basic_combo",
	"growth_l2_compact_build",
	"growth_l3_inventory_pressure",
	"growth_l4_chain_efficiency",
	"growth_l5_signature_build"
]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var definitions := TASK_SERVICE.get_task_definitions()
	for growth_id in GROWTH_IDS:
		var task: Dictionary = definitions.get(growth_id, {})
		_expect(not task.is_empty(), "Growth task should exist: %s" % growth_id)
		_expect(not task.has("tiers") and not task.has("required_tier"), "Growth task should have one completion standard: %s" % growth_id)

	var l1 = _route_state(1, 0)
	l1.record_task_event("business_round_completed", _report(1, {"sold": 1, "refill_actions": 0}, 0, 4, 1, 1, 0, 30_000))
	_expect(not l1.is_task_completed(GROWTH_IDS[0]), "Sales rhythm should wait for all three objectives")
	l1.record_task_event("business_round_completed", _report(2, {"sold": 2, "refill_actions": 0}, 0, 4, 1, 1, 0, 30_000))
	l1.record_task_event("business_round_completed", _report(3, {"sold": 2, "refill_actions": 1}, 0, 4, 1, 1, 0, 30_000))
	_expect(l1.is_task_completed(GROWTH_IDS[0]), "Sales rhythm should complete after standard round, repeat sale and refill")

	var leftovers = _route_state(1, 1)
	leftovers.record_task_event("business_round_completed", _report(4, {"sold": 2, "carried_leftovers": 1, "direct_clearance": 0, "forced_clearance": 1}, 0, 4, 1, 1, 0))
	leftovers.record_task_event("business_round_completed", _report(5, {"sold": 2, "carried_leftovers": 0, "direct_clearance": 1, "forced_clearance": 1}, 0, 4, 1, 1, 0))
	leftovers.record_task_event("business_round_completed", _report(6, {"sold": 3, "carried_leftovers": 0, "direct_clearance": 0, "forced_clearance": 0}, 0, 4, 1, 1, 0))
	_expect(leftovers.is_task_completed(GROWTH_IDS[1]), "Leftover decision should complete after all three decisions")

	var combo = _route_state(2, 2)
	combo.record_task_event("business_round_completed", _report(7, {"sold": 3}, 100, 6, 2, 2, 1))
	_expect(combo.is_task_completed(GROWTH_IDS[2]), "Basic combo should complete from roles and layout income")

	var compact = _route_state(2, 3)
	compact.record_task_event("business_round_completed", _report(8, {"sold": 3}, 80, 6, 2, 2, 10))
	_expect(compact.is_task_completed(GROWTH_IDS[3]), "Compact build should complete both compound objectives")

	var inventory = _route_state(3, 4)
	inventory.record_task_event("business_round_completed", _report(9, {"sold": 7, "refill_actions": 1, "forced_clearance": 1}, 120, 8, 3, 2, 20))
	_expect(not inventory.is_task_completed(GROWTH_IDS[4]), "Inventory challenge should fail below two refills")
	inventory.record_task_event("business_round_completed", _report(10, {"sold": 7, "refill_actions": 2, "forced_clearance": 1}, 120, 8, 3, 2, 20))
	_expect(inventory.is_task_completed(GROWTH_IDS[4]), "Inventory challenge should use its single approved standard")

	var chain = _route_state(4, 5)
	chain.record_task_event("business_round_completed", _report(11, {"sold": 7, "chain_triggers": 1}, 240, 8, 3, 3, 60))
	_expect(not chain.is_task_completed(GROWTH_IDS[5]), "Chain challenge should fail below two triggers")
	chain.record_task_event("business_round_completed", _report(12, {"sold": 7, "chain_triggers": 2}, 240, 8, 3, 3, 60))
	_expect(chain.is_task_completed(GROWTH_IDS[5]), "Chain challenge should use its single approved standard")

	var signature = _route_state(5, 6)
	signature.record_task_event("business_round_completed", _report(13, {"sold": 8, "chain_triggers": 2}, 300, 9, 3, 3, 80, 30_000, 2))
	_expect(not signature.is_task_completed(GROWTH_IDS[6]), "Signature challenge should fail below three shared-theme products")
	signature.record_task_event("business_round_completed", _report(14, {"sold": 8, "chain_triggers": 2}, 300, 9, 3, 3, 80, 30_000, 3))
	_expect(signature.is_task_completed(GROWTH_IDS[6]), "Signature challenge should use its single approved standard")

	var level_six = _route_state(6, 6)
	var before_contracts: Dictionary = TASK_SERVICE.build_task_snapshot(level_six, [])
	var before_ids := _task_ids(before_contracts.get("current_entries", []))
	_expect(before_ids.has("shop_upgrade_7"), "Lv.6 should keep the next shop upgrade visible")
	_expect(before_ids.has(GROWTH_IDS[6]), "Lv.6 unfinished route should keep its growth task beside shop upgrade")
	level_six.completed_tasks.append(GROWTH_IDS[6])
	var candidates := [
		{"task_id": "contract_fast_turnover", "title": "A"},
		{"task_id": "contract_compact_value", "title": "B"},
		{"task_id": "contract_chain_stage", "title": "C"}
	]
	var contract_snapshot: Dictionary = TASK_SERVICE.build_task_snapshot(level_six, candidates)
	var contract_ids := _task_ids(contract_snapshot.get("current_entries", []))
	_expect(contract_ids.has("shop_upgrade_7"), "Contract selector should not hide the shop upgrade task")
	for candidate: Dictionary in candidates:
		_expect(contract_ids.has(String(candidate.get("task_id", ""))), "Contract selector should expose %s" % String(candidate.get("task_id", "")))
	_expect_equal("Parallel current count includes upgrade and choices", int(contract_snapshot.get("current_slot_count", 0)), 4)

	_finish()


func _route_state(level: int, completed_growth_count: int):
	var state = GAME_STATE.new_game()
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage", "task"]:
		state.unlock_core_feature(feature_id)
	state.level = level
	for index in range(completed_growth_count):
		state.completed_tasks.append(GROWTH_IDS[index])
	return state


func _report(id: int, counts: Dictionary, total_coins: int, occupied: int, distinct_recipes: int, distinct_roles: int, layout_extra: int, duration_ms: int = 30_000, max_shared_tag: int = 2) -> Dictionary:
	return {
		"is_complete": true,
		"report_id": "growth:%d" % id,
		"round_id": id,
		"duration_ms": duration_ms,
		"counts": counts,
		"total_coins": total_coins,
		"layout_extra_income": layout_extra,
		"max_product_sold": maxi(1, int(counts.get("sold", 1))),
		"sold_distinct_recipes": distinct_recipes,
		"layout": {"occupied_cells": occupied, "distinct_recipes": distinct_recipes, "distinct_roles": distinct_roles, "max_shared_tag": max_shared_tag}
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_TASK_GROWTH_ROUTE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_TASK_GROWTH_ROUTE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)


func _task_ids(tasks: Array) -> Array[String]:
	var ids: Array[String] = []
	for task_value: Variant in tasks:
		if task_value is Dictionary:
			ids.append(String((task_value as Dictionary).get("id", (task_value as Dictionary).get("task_id", ""))))
	return ids
