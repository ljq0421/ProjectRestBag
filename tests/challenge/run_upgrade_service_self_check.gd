extends SceneTree

const SERVICE_PATH := "res://scripts/challenge/run_upgrade_service.gd"
const UPGRADE_CONFIG_PATH := "res://doc/challenge/run_upgrades.json"
const RECIPE_CONFIG_PATH := "res://doc/challenge/challenge_recipes.json"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in [SERVICE_PATH, UPGRADE_CONFIG_PATH, RECIPE_CONFIG_PATH]:
		_expect(FileAccess.file_exists(path), "required file should exist: %s" % path)
	if not _failures.is_empty():
		_finish()
		return
	var service_script = load(SERVICE_PATH)
	_expect(service_script != null, "run upgrade service should load")
	_expect(service_script != null and service_script.can_instantiate(), "run upgrade service should compile")
	if service_script == null or not service_script.can_instantiate():
		_finish()
		return
	var service = service_script.new()
	var upgrade_config := _load_json(UPGRADE_CONFIG_PATH)
	var recipe_config := _load_json(RECIPE_CONFIG_PATH)
	var upgrade_defs: Dictionary = upgrade_config.get("upgrades", {})
	var recipe_defs: Dictionary = recipe_config.get("recipes", {})
	var starter_ids: Array = recipe_config.get("starter_recipe_ids", [])
	var all_ids: Array = starter_ids.duplicate()
	all_ids.append_array(recipe_config.get("research_recipe_ids", []))

	var validation: Dictionary = service.validate_definitions(upgrade_defs, recipe_defs)
	for error in validation.get("errors", []):
		_fail("committed upgrade definitions should validate: %s" % String(error))
	_expect(bool(validation.get("valid", false)), "committed upgrade pool should be valid")
	_expect(upgrade_defs.size() >= 12, "upgrade pool should contain at least 12 definitions")
	var structural_count := 0
	var universal_count := 0
	for definition in upgrade_defs.values():
		if String(definition.get("category", "")) == "universal":
			universal_count += 1
		if String((definition.get("effect", {}) as Dictionary).get("type", "")) in [
			"copy_limit_add", "cycle_pct", "relation_bonus_add", "tag_add", "shape_variant"
		]:
			structural_count += 1
	_expect(structural_count >= 6, "at least six upgrades should change layout, limits, cycles, tags, or relations")
	_expect(universal_count >= 3, "at least three universal fallbacks should exist")

	var analysis := {
		"instances": [
			{"recipe_id": "butter_cookie", "tags": ["fast", "bake"]},
			{"recipe_id": "strawberry_jelly", "tags": ["fast", "fruit"]}
		]
	}
	var run_state := _run_state()
	var generated: Dictionary = service.generate_offer(run_state, analysis, all_ids, upgrade_defs)
	_expect(bool(generated.get("ok", false)), "compatible draft should generate an offer")
	var offer: Dictionary = generated.get("offer", {})
	_assert_offer_contract(offer)
	var categories := _offer_categories(offer)
	_expect(categories.has("compatible"), "offer should contain a direct compatible candidate")
	_expect(categories.has("universal"), "offer should contain a universal candidate")
	_expect(categories.count("pivot") <= 1, "offer should contain at most one pivot")
	_expect(
		JSON.stringify(offer) ==
		JSON.stringify(service.generate_offer(run_state, analysis, all_ids, upgrade_defs).get("offer", {})),
		"same immutable inputs should produce the same candidate order"
	)
	var reversed_defs := {}
	var reverse_ids: Array = upgrade_defs.keys()
	reverse_ids.reverse()
	for upgrade_id in reverse_ids:
		reversed_defs[upgrade_id] = upgrade_defs[upgrade_id]
	_expect(
		JSON.stringify(offer) ==
		JSON.stringify(service.generate_offer(run_state, analysis, all_ids, reversed_defs).get("offer", {})),
		"offer order should not depend on dictionary insertion order"
	)

	var empty_analysis := {"instances": []}
	var fallback_result: Dictionary = service.generate_offer(run_state, empty_analysis, starter_ids, upgrade_defs)
	_expect(bool(fallback_result.get("ok", false)), "empty compatible pool should use universal fallbacks")
	var fallback_offer: Dictionary = fallback_result.get("offer", {})
	_assert_offer_contract(fallback_offer)
	_expect(
		_offer_categories(fallback_offer).count("universal") == 3,
		"empty draft should receive three validated universal candidates"
	)

	var pivot_run := _run_state()
	var pivot_offer_result: Dictionary = service.generate_offer(
		pivot_run,
		analysis,
		["butter_cookie", "strawberry_jelly", "vanilla_scone", "chocolate_cookie"],
		upgrade_defs
	)
	_expect(bool(pivot_offer_result.get("ok", false)), "unlocked unused recipes should not dead-card an offer")
	_expect(
		_offer_categories(pivot_offer_result.get("offer", {})).count("pivot") <= 1,
		"transformation candidates should remain capped at one"
	)
	var locked_pivot_defs := {
		"aromatic_expansion": upgrade_defs["aromatic_expansion"],
		"bigger_pantry": upgrade_defs["bigger_pantry"],
		"opening_buffer": upgrade_defs["opening_buffer"],
		"service_rhythm": upgrade_defs["service_rhythm"]
	}
	var no_unlock_offer: Dictionary = service.generate_offer(
		pivot_run,
		empty_analysis,
		starter_ids,
		locked_pivot_defs
	).get("offer", {})
	_expect(
		not _offer_ids(no_unlock_offer).has("aromatic_expansion"),
		"pivot targeting a locked recipe should be filtered"
	)

	var selected_id := String((offer.get("candidate_ids", []) as Array)[0])
	var applied: Dictionary = service.apply_choice(run_state, offer, selected_id)
	_expect(bool(applied.get("applied", false)), "offered upgrade should apply")
	var upgraded_run: Dictionary = applied.get("run", {})
	_expect((upgraded_run.get("run_upgrades", []) as Array).size() == 1, "first choice should persist one structured upgrade")
	_expect(
		(upgraded_run.get("applied_run_reward_transaction_ids", []) as Array).size() == 1,
		"first choice should persist its reward transaction"
	)
	var duplicate: Dictionary = service.apply_choice(upgraded_run, offer, selected_id)
	_expect(not bool(duplicate.get("applied", true)), "same reward transaction should be idempotent")
	_expect(
		JSON.stringify(duplicate.get("run", {})) == JSON.stringify(upgraded_run),
		"duplicate transaction should not mutate run state"
	)

	var stack_run := _run_state()
	var stack_offer_one := _manual_offer("stack:upgrade:0", upgrade_defs["bigger_pantry"])
	var first_stack: Dictionary = service.apply_choice(stack_run, stack_offer_one, "bigger_pantry")
	var stack_offer_two := _manual_offer("stack:upgrade:1", upgrade_defs["bigger_pantry"])
	var second_stack: Dictionary = service.apply_choice(first_stack.get("run", {}), stack_offer_two, "bigger_pantry")
	_expect(bool(second_stack.get("applied", false)), "upgrade should stack up to configured maximum")
	_expect(int(second_stack.get("stack_count", 0)) == 2, "stack count should increment")
	var stack_offer_three := _manual_offer("stack:upgrade:2", upgrade_defs["bigger_pantry"])
	var over_cap: Dictionary = service.apply_choice(second_stack.get("run", {}), stack_offer_three, "bigger_pantry")
	_expect(not bool(over_cap.get("applied", true)), "upgrade should reject a stack above configured maximum")

	var base_rules := {"supply_budget": 16, "first_window_guard": 0, "relation_bonus_add": {}}
	var context_before: Dictionary = service.resolve_context(recipe_defs, base_rules, [])
	var context_after: Dictionary = service.resolve_context(
		recipe_defs,
		base_rules,
		[
			_upgrade_entry(upgrade_defs["bigger_pantry"], 2),
			_upgrade_entry(upgrade_defs["muffin_fold"], 1),
			_upgrade_entry(upgrade_defs["bakers_badge"], 1),
			_upgrade_entry(upgrade_defs["service_rhythm"], 1)
		]
	)
	_expect(
		int((context_after.get("rules", {}) as Dictionary).get("supply_budget", 0)) == 20,
		"budget effect should apply configured stacks"
	)
	var resolved_recipes: Dictionary = context_after.get("recipe_defs", {})
	_expect(
		(resolved_recipes["blueberry_muffin"]["shape_cells"] as Array).size() == 1,
		"shape variant should replace the recipe shape"
	)
	_expect(
		(resolved_recipes["butter_cookie"]["tags"] as Array).has("set"),
		"tag upgrade should affect recipes selected by target tag"
	)
	_expect(
		int(resolved_recipes["butter_cookie"]["cycle_ms"]) == 3680,
		"cycle modifier should resolve deterministically"
	)
	_expect(
		int(recipe_defs["butter_cookie"]["cycle_ms"]) == 4000,
		"effect resolution should not mutate base recipe definitions"
	)
	var summary: Dictionary = service.describe_effect(context_before, context_after, "combined_test")
	_expect(not (summary.get("changes", []) as Array).is_empty(), "effect summary should list before and after changes")
	_expect(
		(summary.get("affected_recipe_ids", []) as Array).has("blueberry_muffin"),
		"effect summary should name affected recipes"
	)
	_expect(bool(summary.get("recommends_rearrange", false)), "structural effect summary should recommend rearranging")
	for change in summary.get("changes", []):
		_expect(change.has("field"), "effect change should name its field")
		_expect(change.has("before"), "effect change should include before")
		_expect(change.has("after"), "effect change should include after")

	var broken_defs: Dictionary = upgrade_defs.duplicate(true)
	broken_defs["cookie_tin"]["effect"]["target_recipe_ids"] = ["missing_recipe"]
	_expect(
		not bool(service.validate_definitions(broken_defs, recipe_defs).get("valid", true)),
		"definition validation should reject unknown target recipes"
	)
	_finish()


func _run_state() -> Dictionary:
	return {
		"run_id": "standard:test:upgrade",
		"seed": 8842,
		"stage_index": 1,
		"encounter_instances": [
			{},
			{"reward_seed": 73177}
		],
		"run_upgrades": [],
		"applied_run_reward_transaction_ids": []
	}


func _manual_offer(offer_id: String, definition: Dictionary) -> Dictionary:
	var candidate := definition.duplicate(true)
	var upgrade_id := String(definition.get("id", ""))
	candidate["upgrade_id"] = upgrade_id
	candidate["reward_transaction_id"] = "%s:%s" % [offer_id, upgrade_id]
	return {
		"offer_id": offer_id,
		"candidate_ids": [upgrade_id],
		"candidates": [candidate]
	}


func _upgrade_entry(definition: Dictionary, stack_count: int) -> Dictionary:
	return {
		"upgrade_id": String(definition.get("id", "")),
		"stack_count": stack_count,
		"definition": definition.duplicate(true),
		"reward_transaction_ids": []
	}


func _assert_offer_contract(offer: Dictionary) -> void:
	var candidate_ids: Array = offer.get("candidate_ids", [])
	var candidates: Array = offer.get("candidates", [])
	_expect(candidate_ids.size() == 3, "offer should persist exactly three candidate IDs")
	_expect(candidates.size() == 3, "offer should persist exactly three candidate snapshots")
	var unique_ids := {}
	for candidate_id in candidate_ids:
		unique_ids[String(candidate_id)] = true
	_expect(unique_ids.size() == 3, "offer candidates should be unique")
	for candidate in candidates:
		_expect(not String(candidate.get("reward_transaction_id", "")).is_empty(), "candidate should persist reward transaction ID")
		_expect(candidate.get("effect") is Dictionary, "candidate should persist its effect definition")


func _offer_categories(offer: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for candidate in offer.get("candidates", []):
		result.append(String(candidate.get("category", "")))
	return result


func _offer_ids(offer: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for candidate_id in offer.get("candidate_ids", []):
		result.append(String(candidate_id))
	return result


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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RUN_UPGRADE_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
