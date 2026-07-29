extends SceneTree

const RunUpgradeService = preload("res://scripts/challenge/run_upgrade_service.gd")
const ChallengeLoadoutService = preload("res://scripts/challenge/challenge_loadout_service.gd")
const BossBattleService = preload("res://scripts/challenge/boss_battle_service.gd")
const BossBattleReportService = preload("res://scripts/challenge/boss_battle_report_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var upgrades := RunUpgradeService.new()
	var loadouts := ChallengeLoadoutService.new()
	var battles := BossBattleService.new()
	var reports := BossBattleReportService.new()
	var base_defs := {"test_recipe": _recipe()}
	var base_rules := {"supply_budget": 2}
	var encounter := _encounter()

	var base_context := upgrades.resolve_context(base_defs, base_rules, [])
	var base_draft := _draft([["one", 0, 0]])
	var base_snapshot_result := loadouts.build_snapshot_from_context(
		base_draft,
		base_context,
		encounter,
		6,
		8
	)
	_expect(bool(base_snapshot_result.get("ok", false)), "base context should build a snapshot")

	var shape_context := upgrades.resolve_context(
		base_defs,
		base_rules,
		[_entry("wide_display", {
			"type": "shape_variant",
			"target_recipe_ids": ["test_recipe"],
			"shape_cells": [[0, 0], [0, 1]],
			"rotatable": false
		})]
	)
	var edge_draft := _draft([["edge", 0, 7]])
	_expect(
		bool(loadouts.build_snapshot_from_context(
			edge_draft,
			base_context,
			encounter,
			6,
			8
		).get("ok", false)),
		"one-cell base shape should fit at the board edge"
	)
	var invalid_after_shape := loadouts.build_snapshot_from_context(
		edge_draft,
		shape_context,
		encounter,
		6,
		8
	)
	_expect(
		not bool(invalid_after_shape.get("ok", true))
		and bool(invalid_after_shape.get("requires_rearrange", false)),
		"shape change should explicitly require rearranging an invalid existing draft"
	)

	var two_copy_draft := _draft([["one", 0, 0], ["two", 1, 0]])
	_expect(
		not bool(loadouts.build_snapshot_from_context(
			two_copy_draft,
			base_context,
			encounter,
			6,
			8
		).get("ok", true)),
		"base copy limit should reject the second copy"
	)
	var copies_context := upgrades.resolve_context(
		base_defs,
		base_rules,
		[_entry("extra_copy", {
			"type": "copy_limit_add",
			"target_recipe_ids": ["test_recipe"],
			"value": 1
		})]
	)
	_expect(
		bool(loadouts.build_snapshot_from_context(
			two_copy_draft,
			copies_context,
			encounter,
			6,
			8
		).get("ok", false)),
		"copy limit upgrade should immediately allow a second copy"
	)

	var cycle_context := upgrades.resolve_context(
		base_defs,
		base_rules,
		[_entry("quick_service", {
			"type": "cycle_pct",
			"target_recipe_ids": ["test_recipe"],
			"value": -50,
			"min_cycle_ms": 1000
		})]
	)
	var cycle_snapshot := (
		loadouts.build_snapshot_from_context(
			base_draft,
			cycle_context,
			encounter,
			6,
			8
		).get("snapshot", {}) as Dictionary
	)
	var base_battle := battles.advance(
		battles.create_state(base_snapshot_result.get("snapshot", {}), encounter, 91),
		8000
	)
	var cycle_battle := battles.advance(
		battles.create_state(cycle_snapshot, encounter, 91),
		8000
	)
	_expect(
		int(base_battle.get("sales_count", 0)) == 2
		and int(cycle_battle.get("sales_count", 0)) == 4,
		"cycle upgrade should change demand-window coverage"
	)

	var guard_context := upgrades.resolve_context(
		base_defs,
		base_rules,
		[_entry("opening_guard", {"type": "first_window_guard", "value": 6})]
	)
	var guard_snapshot: Dictionary = loadouts.build_snapshot_from_context(
		base_draft,
		guard_context,
		encounter,
		6,
		8
	).get("snapshot", {})
	var guarded := battles.advance(battles.create_state(guard_snapshot, encounter, 91), 8000)
	var guarded_window: Dictionary = guarded.get("resolved_windows", {}).get("rush", {})
	_expect(int(guarded_window.get("guard_absorbed", 0)) == 6, "universal guard should absorb first-window damage")
	_expect(int(guarded.get("reputation", 0)) == 16, "guard should leave sixteen reputation after ten base damage")
	_expect(
		(guarded_window.get("upgrade_source_ids", []) as Array).has("opening_guard"),
		"demand event should trace the guard upgrade source"
	)

	var satisfaction_context := upgrades.resolve_context(
		base_defs,
		base_rules,
		[_entry("better_recipe", {
			"type": "satisfaction_add",
			"target_recipe_ids": ["test_recipe"],
			"value": 3
		})]
	)
	var satisfaction_snapshot: Dictionary = loadouts.build_snapshot_from_context(
		base_draft,
		satisfaction_context,
		encounter,
		6,
		8
	).get("snapshot", {})
	var restored_a := battles.simulate(satisfaction_snapshot, encounter, 91)
	var restored_b := battles.simulate(satisfaction_snapshot.duplicate(true), encounter.duplicate(true), 91)
	_expect(restored_a == restored_b, "frozen upgraded snapshot should restore deterministically")
	var report := reports.build(restored_a, encounter)
	var contributions: Array = report.get("recipe_contributions", [])
	_expect(not contributions.is_empty(), "upgraded battle report should contain recipe contribution")
	if not contributions.is_empty():
		_expect(
			(contributions[0].get("upgrade_source_ids", []) as Array).has("better_recipe"),
			"battle report should trace recipe effect to its upgrade"
		)
	_expect(
		(report.get("applied_upgrades", []) as Array).size() == 1,
		"battle report should expose the frozen applied upgrade summary"
	)

	_finish()


func _recipe() -> Dictionary:
	return {
		"shape_cells": [[0, 0]],
		"supply_cost": 1,
		"copy_limit": 1,
		"virtual_stock": 6,
		"cycle_ms": 4000,
		"satisfaction": 5,
		"tags": ["fast"],
		"rotatable": false
	}


func _encounter() -> Dictionary:
	return {
		"id": "upgrade_test",
		"duration_ms": 12000,
		"initial_pickiness": 999,
		"initial_reputation": 20,
		"relation_bonus_pct": 0,
		"relation": {},
		"windows": [{
			"id": "rush",
			"at_ms": 8000,
			"metric": "sales_count",
			"target": 99,
			"reputation_damage": 10
		}]
	}


func _draft(rows: Array) -> Dictionary:
	var placements: Array[Dictionary] = []
	for row in rows:
		placements.append({
			"instance_id": String(row[0]),
			"recipe_id": "test_recipe",
			"origin": [int(row[1]), int(row[2])],
			"rotation": 0
		})
	return {"placements": placements}


func _entry(upgrade_id: String, effect: Dictionary) -> Dictionary:
	return {
		"upgrade_id": upgrade_id,
		"stack_count": 1,
		"definition": {
			"id": upgrade_id,
			"effect": effect.duplicate(true)
		}
	}


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_UPGRADE_EFFECTS_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
