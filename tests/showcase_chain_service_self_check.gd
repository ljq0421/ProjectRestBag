extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var role_path := "res://scripts/showcase_role_service.gd"
	var chain_path := "res://scripts/showcase_chain_service.gd"
	if not ResourceLoader.exists(role_path) or not ResourceLoader.exists(chain_path):
		_fail("role and chain services should exist")
		_finish()
		return
	var role_service = load(role_path)
	var chain_service = load(chain_path)
	var display_items := {
		"a": {"cells": [Vector2i(1, 1)]},
		"b": {"cells": [Vector2i(1, 2)]},
		"c": {"cells": [Vector2i(1, 3)]},
		"d": {"cells": [Vector2i(4, 4)]}
	}
	var roles: Dictionary = role_service.build_snapshot(display_items, {
		"a": {"role": "advance"},
		"b": {"role": "advance"},
		"c": {"role": "harvest"},
		"d": {"role": "advance"}
	})
	_expect_equal("role snapshot preserves configured role", String((roles.get("a", {}) as Dictionary).get("role", "")), "advance")
	_expect_equal("nearest deterministic target comes first", String(((roles.get("a", {}) as Dictionary).get("targets", []) as Array)[0]), "b")
	_expect_equal("advance targets only include orthogonally touching products", ((roles.get("a", {}) as Dictionary).get("targets", []) as Array).size(), 1)
	_expect_equal("isolated product has no directional target", ((roles.get("d", {}) as Dictionary).get("targets", []) as Array).size(), 0)

	var item_states := {
		"a": {"fresh_stock": 2, "carried_stock": 0, "unit_price": 10, "duration_ms": 5000, "cycle_elapsed_ms": 0},
		"b": {"fresh_stock": 1, "carried_stock": 1, "unit_price": 20, "duration_ms": 8000, "cycle_elapsed_ms": 1000},
		"c": {"fresh_stock": 1, "carried_stock": 0, "unit_price": 30, "duration_ms": 10000, "cycle_elapsed_ms": 0}
	}
	var resolved: Dictionary = chain_service.resolve_chain({
		"recipe_id": "a", "earned_coins": 10, "batch": "fresh", "completed_at_ms": 5000
	}, item_states, roles, 10, 4)
	var chain_events: Array = resolved.get("chain_events", [])
	_expect_equal("advance spends heat and creates one real target sale", chain_events.size() >= 1, true)
	if not chain_events.is_empty():
		_expect_equal("carried batch sells before fresh batch", String((chain_events[0] as Dictionary).get("batch", "")), "carried")
		_expect_equal("carried chain sale uses eighty percent", int((chain_events[0] as Dictionary).get("earned_coins", 0)), 16)
	var next_b: Dictionary = (resolved.get("item_states", {}) as Dictionary).get("b", {})
	_expect_equal("chain sale consumes carried stock", int(next_b.get("carried_stock", -1)), 0)
	_expect_equal("new heat is added only after chain spending", int(resolved.get("heat", -1)), 8)

	var waiting_states := item_states.duplicate(true)
	waiting_states["b"]["fresh_stock"] = 0
	waiting_states["b"]["carried_stock"] = 0
	waiting_states["c"]["fresh_stock"] = 0
	var skipped: Dictionary = chain_service.resolve_chain({"recipe_id": "a", "earned_coins": 10}, waiting_states, roles, 10, 4)
	_expect_equal("waiting targets produce no forced sale", (skipped.get("chain_events", []) as Array).size(), 0)
	_expect_equal("invalid target does not spend heat", int(skipped.get("heat", -1)), 14)
	var broken: Dictionary = chain_service.resolve_chain({"recipe_id": "d", "earned_coins": 10}, item_states, roles, 10, 4)
	var broken_effects: Array = broken.get("effects", [])
	_expect_equal("isolated advance emits one visible broken-chain effect", broken_effects.size(), 1)
	if not broken_effects.is_empty():
		_expect_equal("broken-chain effect uses stable kind", String((broken_effects[0] as Dictionary).get("kind", "")), "broken")

	var loop_roles := {
		"a": {"role": "advance", "targets": ["b"]},
		"b": {"role": "advance", "targets": ["c"]},
		"c": {"role": "advance", "targets": ["a"]}
	}
	var bounded: Dictionary = chain_service.resolve_chain({"recipe_id": "a", "earned_coins": 10}, item_states, loop_roles, 100, 4)
	_expect_equal("same layout instance triggers at most once per chain", (bounded.get("triggered_recipe_ids", []) as Array).size(), 3)
	_expect_equal("chain depth is capped", (bounded.get("chain_events", []) as Array).size() <= 4, true)
	_expect_equal("heat remains within zero to one hundred", int(bounded.get("heat", -1)) in range(0, 101), true)
	_finish()


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_CHAIN_SERVICE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_CHAIN_SERVICE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
