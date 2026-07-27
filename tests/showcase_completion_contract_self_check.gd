extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	_expect_role_precedence_and_reasons()
	_expect_business_challenge_is_the_only_challenge_path()
	_expect_scene_contracts_are_current()
	_finish()


func _expect_role_precedence_and_reasons() -> void:
	var role_service = load("res://scripts/showcase_role_service.gd")
	var display_items := {
		"recipe_override": {"cells": [Vector2i(0, 0)], "variant_id": "gift_box"},
		"variant_override": {"cells": [Vector2i(0, 1)], "variant_id": "gift_box"},
		"tag_override": {"cells": [Vector2i(0, 2)], "variant_id": "standard"},
		"growth_override": {"cells": [Vector2i(0, 3)], "variant_id": "standard"}
	}
	var sale_terms := {
		"recipe_override": {"role": "lure", "tags": ["清爽"], "growth_level": 4},
		"variant_override": {"role": "lure", "tags": [], "growth_level": 0},
		"tag_override": {"role": "lure", "tags": ["清爽", "果香"], "growth_level": 0},
		"growth_override": {"role": "lure", "tags": [], "growth_level": 3}
	}
	var rules := {
		"recipe_overrides": {"recipe_override": {"role": "harvest", "reason": "招牌覆盖"}},
		"variant_overrides": {"gift_box": {"role": "amplify", "reason": "礼盒展示"}},
		"tag_overrides": [{"all_tags": ["清爽", "果香"], "role": "advance", "reason": "清爽果香"}],
		"growth_overrides": [{"min_level": 3, "role": "advance", "reason": "成熟配方"}]
	}
	_expect_equal("role service exposes configured snapshot", role_service.has_method("build_configured_snapshot"), true)
	if not role_service.has_method("build_configured_snapshot"):
		return
	var snapshot: Dictionary = role_service.call("build_configured_snapshot", display_items, sale_terms, rules)
	_expect_equal("recipe override wins", _role(snapshot, "recipe_override"), "harvest")
	_expect_equal("variant override wins before growth", _role(snapshot, "variant_override"), "amplify")
	_expect_equal("tag combination resolves role", _role(snapshot, "tag_override"), "advance")
	_expect_equal("growth threshold resolves role", _role(snapshot, "growth_override"), "advance")
	for recipe_id in snapshot.keys():
		var role_data: Dictionary = snapshot.get(recipe_id, {})
		_expect_equal("%s has role source" % recipe_id, String(role_data.get("role_source", "")).is_empty(), false)
		_expect_equal("%s has role reason" % recipe_id, String(role_data.get("role_reason", "")).is_empty(), false)


func _expect_business_challenge_is_the_only_challenge_path() -> void:
	var challenge_service = load("res://scripts/showcase_challenge_service.gd")
	_expect_equal("legacy static score entry removed", challenge_service.has_method("score_showcase"), false)
	_expect_equal("legacy static challenge entry removed", challenge_service.has_method("evaluate_challenges"), false)
	_expect_equal("challenge service exposes task snapshot", challenge_service.has_method("create_task_challenge"), true)
	if not challenge_service.has_method("create_task_challenge"):
		return
	var snapshot: Dictionary = challenge_service.call("create_task_challenge", {
		"id": "strict", "type": "contract", "version": 2, "title": "限定营业", "description": "使用当前开放商品完成合同。",
		"level": 6, "availability": {"min_level": 6}, "duration_seconds": 30, "environment_id": "steady_demand",
		"tiers": [{"id": "bronze", "condition": {"field": "counts.sold", "operator": "gte", "value": 4}}]
	}, 4, {
		"environment": {"markets": [{"id": "steady_demand", "label": "平稳需求", "price_pct": 3, "speed_pct": 0}]}
	}, {"level": 6, "unlocked_recipe_ids": ["tea"], "unlocked_tags": ["清爽"]})
	_expect_equal("challenge locks task id", String(snapshot.get("task_id", "")), "strict")
	_expect_equal("challenge locks environment", snapshot.get("environment", {}).is_empty(), false)
	_expect_equal("challenge records resolved recipes", snapshot.get("resolved_recipe_ids", []), ["tea"])
	var rejected: Dictionary = challenge_service.call("create_task_challenge", {"id": "early", "type": "contract", "version": 1, "level": 6, "availability": {"min_level": 6}}, 4, {}, {"level": 5})
	_expect_equal("challenge rejects unavailable level", rejected.is_empty(), true)


func _expect_scene_contracts_are_current() -> void:
	var board := FileAccess.get_file_as_string("res://scenes/ui/storefront/showcase_board.tscn")
	var slot := FileAccess.get_file_as_string("res://scenes/ui/storefront/showcase_slot.tscn")
	var dialog := FileAccess.get_file_as_string("res://scenes/ui/overlays/showcase_round_settlement_dialog.tscn")
	_expect_equal("board is 1008 by 864", board.find("custom_minimum_size = Vector2(1008, 864)") >= 0, true)
	_expect_equal("slot is 72 by 72", slot.find("custom_minimum_size = Vector2(72, 72)") >= 0, true)
	_expect_equal("board removes automatic business copy", board.find("自动经营中"), -1)
	_expect_equal("board removes shortage copy", board.find("缺货"), -1)
	_expect_equal("settlement removes summary and detail tabs", dialog.find("SettlementTabs"), -1)
	_expect_equal("settlement declares a compact summary", dialog.find("SettlementSummary") >= 0, true)
	_expect_equal("settlement declares round detail after summary", dialog.find("RoundDetailGrid") >= 0, true)
	_expect_equal("settlement declares leftover processing after detail", dialog.find("SettlementGrid") >= 0, true)
	_expect_equal("board declares live task progress", board.find("TaskProgressPanel") >= 0, true)
	_expect_equal("settlement declares rating summary", dialog.find("RatingSummaryLabel") >= 0, true)


func _role(snapshot: Dictionary, recipe_id: String) -> String:
	return String((snapshot.get(recipe_id, {}) as Dictionary).get("role", ""))


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_COMPLETION_CONTRACT_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_COMPLETION_CONTRACT_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
