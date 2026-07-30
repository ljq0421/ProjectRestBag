extends SceneTree

const SERVICE_PATH := "res://scripts/challenge/boss_battle_service.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not FileAccess.file_exists(SERVICE_PATH):
		_fail("boss battle service should exist")
		_finish()
		return
	var service_script = load(SERVICE_PATH)
	_expect(service_script != null and service_script.can_instantiate(), "boss battle service should compile")
	if service_script == null or not service_script.can_instantiate():
		_finish()
		return
	var service = service_script.new()

	var snapshot := _snapshot([
		_instance("cookie", "butter_cookie", 2500, 4, 8)
	])
	var encounter := _encounter(10000, 999)
	var first: Dictionary = service.simulate(snapshot, encounter, 42)
	var second: Dictionary = service.simulate(snapshot, encounter, 42)
	_expect(first.get("events", []) == second.get("events", []), "same snapshot and seed should replay identically")
	_expect(first.get("outcome", "") == second.get("outcome", ""), "same snapshot and seed should keep outcome")

	var boundary_snapshot := _snapshot([
		_instance("cookie", "butter_cookie", 4000, 4, 3)
	])
	var boundary_encounter := _encounter(12000, 100)
	boundary_encounter["windows"] = [
		{"id": "at_eight", "at_ms": 8000, "metric": "sales_count", "target": 2, "reputation_damage": 25}
	]
	var boundary: Dictionary = service.advance(service.create_state(boundary_snapshot, boundary_encounter, 42), 8000)
	var sale_index := _event_index(boundary.get("events", []), "sale", 8000)
	var window_index := _event_index(boundary.get("events", []), "demand_window", 8000)
	_expect(sale_index >= 0 and sale_index < window_index, "sale due exactly at the window should resolve first")

	var simultaneous := _snapshot([
		_instance("z_item", "butter_cookie", 4000, 4, 1),
		_instance("a_item", "strawberry_jelly", 4000, 5, 1)
	])
	var simultaneous_state: Dictionary = service.advance(service.create_state(simultaneous, _encounter(10000, 100), 9), 4000)
	var sale_sources: Array[String] = []
	for event in simultaneous_state.get("events", []):
		if event.get("type") == "sale":
			sale_sources.append(String(event.get("source_id", "")))
	_expect(sale_sources == ["a_item", "z_item"], "simultaneous sales should be sorted by instance_id")

	var limited := _snapshot([
		_instance("limited", "butter_cookie", 1000, 4, 2)
	])
	var limited_result: Dictionary = service.simulate(limited, _encounter(5000, 999), 1)
	_expect(_event_count(limited_result.get("events", []), "sale") == 2, "virtual stock should stop further sales")

	var related := _snapshot([
		_instance("pudding", "milk_pudding", 1000, 7, 1, ["drink"]),
		_instance("muffin", "blueberry_muffin", 1000, 8, 1, ["bake"])
	], [
		{
			"relation_id": "drink_bake_pair",
			"left_instance_id": "pudding",
			"right_instance_id": "muffin",
			"bonus_pct": 25
		}
	])
	var related_state: Dictionary = service.advance(service.create_state(related, _encounter(5000, 999), 3), 1000)
	var pudding_sale := _first_sale(related_state.get("events", []), "pudding")
	_expect(int(pudding_sale.get("relation_bonus", -1)) == 1, "25 percent relation bonus should floor the bonus value")
	_expect(int(pudding_sale.get("final_satisfaction", -1)) == 8, "relation sale should use floor(base * 125 / 100)")
	_expect(pudding_sale.get("tags", []) == ["drink"], "sale events should carry frozen sorted tags")

	var tagged_snapshot := _snapshot([
		_instance("mixed", "fruit_bake", 2000, 7, 3, ["fruit", "bake", "fruit"]),
		_instance("drink", "iced_drink", 4000, 11, 1, ["drink", "fast"])
	])
	var tagged_encounter := _encounter(8000, 999)
	tagged_encounter["windows"] = [
		{
			"id": "bake_sales",
			"at_ms": 4000,
			"metric": "tag_sales_count",
			"tag": "bake",
			"target": 2,
			"reputation_damage": 10
		},
		{
			"id": "fruit_power",
			"at_ms": 6000,
			"from_ms": 2000,
			"metric": "tag_satisfaction",
			"tag": "fruit",
			"target": 14,
			"reputation_damage": 10
		},
		{
			"id": "served_variety",
			"at_ms": 8000,
			"metric": "distinct_tag_count",
			"target_tags": ["fruit", "drink", "signature"],
			"target": 2,
			"reputation_damage": 10
		}
	]
	var tagged_created: Dictionary = service.create_state(tagged_snapshot, tagged_encounter, 17)
	var frozen_instances: Array = (tagged_created.get("_snapshot", {}) as Dictionary).get("instances", [])
	_expect(frozen_instances[0].get("tags", []) == ["bake", "fruit"], "battle snapshot should freeze sorted unique tags")
	_expect(
		((tagged_created.get("item_states", {}) as Dictionary).get("drink", {}) as Dictionary).get("tags", [])
			== ["drink", "fast"],
		"item state should freeze sorted tags"
	)
	var tagged_result: Dictionary = service.simulate(tagged_snapshot, tagged_encounter, 17)
	var tagged_windows: Dictionary = tagged_result.get("resolved_windows", {})
	_expect(
		int((tagged_windows.get("bake_sales", {}) as Dictionary).get("actual", -1)) == 2,
		"tag_sales_count should include matching sales at the deadline"
	)
	_expect(
		int((tagged_windows.get("fruit_power", {}) as Dictionary).get("actual", -1)) == 14,
		"tag_satisfaction should use final satisfaction in the open-closed interval"
	)
	_expect(
		int((tagged_windows.get("served_variety", {}) as Dictionary).get("actual", -1)) == 2,
		"distinct_tag_count should count sold target tags once each"
	)

	var damage_encounter := _encounter(3000, 999)
	damage_encounter["windows"] = [
		{"id": "miss_once", "at_ms": 1000, "metric": "sales_count", "target": 1, "reputation_damage": 25}
	]
	var no_sales := _snapshot([
		_instance("slow", "butter_cookie", 100000, 4, 1)
	])
	var damaged_once: Dictionary = service.advance(service.create_state(no_sales, damage_encounter, 5), 2000)
	var damaged_twice: Dictionary = service.advance(damaged_once, 2500)
	_expect(int(damaged_twice.get("reputation", 0)) == 75, "failed demand window should damage reputation only once")
	_expect((damaged_twice.get("resolved_windows", {}) as Dictionary).size() == 1, "demand window should resolve only once")

	var lethal := _snapshot([
		_instance("finisher", "butter_cookie", 1000, 10, 1)
	])
	var victory: Dictionary = service.simulate(lethal, _encounter(5000, 3), 7)
	_expect(victory.get("outcome") == "victory", "battle should end in immediate victory when pickiness reaches zero")
	_expect(int(victory.get("elapsed_ms", 0)) == 1000, "immediate victory should stop at the lethal sale timestamp")
	var lethal_sale := _first_sale(victory.get("events", []), "finisher")
	_expect(
		int(lethal_sale.get("final_satisfaction", 0)) == 10
			and int(lethal_sale.get("pickiness_before", -1)) == 3
			and int(lethal_sale.get("pickiness_reduction", -1)) == 3
			and int(lethal_sale.get("pickiness_after", -1)) == 0,
		"lethal sale should preserve satisfaction while reporting only the actual pickiness reduction"
	)
	var simultaneous_finishers := _snapshot([
		_instance("finisher_a", "butter_cookie", 1000, 4, 1),
		_instance("finisher_b", "strawberry_jelly", 1000, 4, 1)
	])
	var simultaneous_victory: Dictionary = service.simulate(
		simultaneous_finishers,
		_encounter(5000, 6),
		8
	)
	var first_finisher := _first_sale(
		simultaneous_victory.get("events", []),
		"finisher_a"
	)
	var second_finisher := _first_sale(
		simultaneous_victory.get("events", []),
		"finisher_b"
	)
	_expect(
		int(first_finisher.get("pickiness_reduction", -1)) == 4
			and int(second_finisher.get("pickiness_reduction", -1)) == 2
			and int(simultaneous_victory.get("total_satisfaction", 0)) == 8,
		"same-timestamp sales should allocate actual reductions without losing total satisfaction"
	)

	var timeout_result: Dictionary = service.simulate(no_sales, _encounter(30000, 10), 8)
	_expect(timeout_result.get("outcome") == "loss_timeout", "battle should lose by timeout at 30 seconds")
	_expect(int(timeout_result.get("elapsed_ms", 0)) == 30000, "timeout should resolve at the encounter duration")

	var recipe_config := _load_json("res://doc/challenge/challenge_recipes.json")
	var encounter_config := _load_json("res://doc/challenge/boss_encounters.json")
	var defs: Dictionary = recipe_config.get("recipes", {})
	var configured_snapshot := _snapshot([
		_configured_instance("pudding_1", "milk_pudding", defs),
		_configured_instance("pudding_2", "milk_pudding", defs),
		_configured_instance("muffin_1", "blueberry_muffin", defs),
		_configured_instance("muffin_2", "blueberry_muffin", defs),
		_configured_instance("cookie_1", "butter_cookie", defs),
		_configured_instance("cookie_2", "butter_cookie", defs)
	], [
		{"relation_id": "drink_bake_pair", "left_instance_id": "pudding_1", "right_instance_id": "muffin_1", "bonus_pct": 25},
		{"relation_id": "drink_bake_pair", "left_instance_id": "pudding_2", "right_instance_id": "muffin_2", "bonus_pct": 25}
	])
	var critic: Dictionary = (encounter_config.get("encounters", {}) as Dictionary).get("picky_food_critic", {})
	var configured_result: Dictionary = service.simulate(configured_snapshot, critic, 42)
	_expect(configured_result.get("outcome") == "victory", "committed six-recipe data should retain its proven winning loadout")
	_expect(int(configured_result.get("elapsed_ms", 0)) == 30000, "sale at the final deadline should resolve before timeout")
	_expect(int(configured_result.get("total_satisfaction", 0)) == 212, "proven winning loadout should produce 212 satisfaction")

	var legacy_windows: Dictionary = configured_result.get("resolved_windows", {})
	_expect(
		int((legacy_windows.get("early_tempo", {}) as Dictionary).get("actual", -1)) == 8,
		"stage 1 sales_count result should remain unchanged"
	)
	_expect(
		int((legacy_windows.get("linked_display", {}) as Dictionary).get("actual", -1)) == 2,
		"stage 1 active_relation_count result should remain unchanged"
	)
	_expect(
		int((legacy_windows.get("sustained_service", {}) as Dictionary).get("actual", -1)) == 72,
		"stage 1 window_satisfaction result should remain unchanged"
	)

	var forward: Dictionary = service.advance(service.create_state(no_sales, _encounter(5000, 10), 11), 2000)
	var backward: Dictionary = service.advance(forward, 1000)
	_expect(backward.get("error") == "cannot_move_backward", "advance should refuse to move backward")
	_expect(int(backward.get("elapsed_ms", 0)) == 2000, "backward advance should preserve elapsed time")
	_expect(backward.get("events", []) == forward.get("events", []), "backward advance should not mutate prior events")

	_finish()


func _snapshot(instances: Array, relations: Array = []) -> Dictionary:
	return {
		"grid_rows": 6,
		"grid_columns": 8,
		"spent_budget": 1,
		"instances": instances,
		"relations": relations,
		"encounter_id": "test_encounter"
	}


func _instance(
	instance_id: String,
	recipe_id: String,
	cycle_ms: int,
	satisfaction: int,
	stock: int,
	tags: Array = []
) -> Dictionary:
	return {
		"instance_id": instance_id,
		"recipe_id": recipe_id,
		"cycle_ms": cycle_ms,
		"virtual_stock": stock,
		"base_satisfaction": satisfaction,
		"tags": tags,
		"cells": [[0, 0]]
	}


func _configured_instance(instance_id: String, recipe_id: String, defs: Dictionary) -> Dictionary:
	var definition: Dictionary = defs.get(recipe_id, {})
	return {
		"instance_id": instance_id,
		"recipe_id": recipe_id,
		"cycle_ms": int(definition.get("cycle_ms", 0)),
		"virtual_stock": int(definition.get("virtual_stock", 0)),
		"base_satisfaction": int(definition.get("satisfaction", 0)),
		"tags": (definition.get("tags", []) as Array).duplicate(),
		"cells": [[0, 0]]
	}


func _encounter(duration_ms: int, pickiness: int) -> Dictionary:
	return {
		"duration_ms": duration_ms,
		"initial_pickiness": pickiness,
		"initial_reputation": 100,
		"relation_bonus_pct": 25,
		"relation": {
			"id": "drink_bake_pair",
			"left_tag": "drink",
			"right_tag": "bake"
		},
		"windows": []
	}


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("could not open JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_fail("JSON root should be a dictionary: %s" % path)
		return {}
	return parsed


func _event_index(events: Array, type: String, at_ms: int) -> int:
	for index in events.size():
		var event: Dictionary = events[index]
		if event.get("type") == type and int(event.get("at_ms", -1)) == at_ms:
			return index
	return -1


func _event_count(events: Array, type: String) -> int:
	var count := 0
	for event in events:
		if event.get("type") == type:
			count += 1
	return count


func _first_sale(events: Array, source_id: String) -> Dictionary:
	for event in events:
		if event.get("type") == "sale" and event.get("source_id") == source_id:
			return event
	_fail("sale event should exist for %s" % source_id)
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BOSS_BATTLE_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
