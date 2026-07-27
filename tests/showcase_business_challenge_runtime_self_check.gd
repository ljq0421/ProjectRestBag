extends SceneTree

const MAIN := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_business_challenge_runtime_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var view = MAIN.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	var state = GAME_STATE.new_game()
	state.level = 6
	state.shop_level = 6
	state.coins = 100
	state.add_recipe("sponge_cake")
	state.display_items = {
		"sponge_cake": {"cells": [Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(6, 6)], "fresh_stock": 5, "carried_stock": 0, "stock": 5, "variant_id": "standard"}
	}
	view.set("state", state)
	_expect_equal("runtime exposes challenge acceptance", view.has_method("_accept_showcase_business_challenge"), true)
	if not view.has_method("_accept_showcase_business_challenge"):
		_finish(view)
		return
	_expect_equal("runtime accepts generated contract", bool(view.call("_accept_showcase_business_challenge", "contract_fast_turnover")), true)
	_expect_equal("normal contract has no deposit", int(state.coins), 100)
	_expect_equal("challenge round starts", bool(view.call("_start_showcase_business_round")), true)
	_expect_equal("active round is challenge", String(state.active_business_round.get("kind", "")), "challenge")
	_expect_equal("contract preserves configured duration", int(state.active_business_round.get("duration_ms", 0)), 30000)
	var environment_reasons: Array = ((state.active_business_round.get("sale_terms", {}) as Dictionary).get("sponge_cake", {}) as Dictionary).get("environment_reasons", [])
	_expect_equal("challenge sale terms retain environment reasons", environment_reasons.is_empty(), false)
	state.active_business_round["heat"] = 15
	view.call("_advance_showcase_business_round", 30000)
	_expect_equal("challenge enters settlement at its own boundary", String(state.active_business_round.get("phase", "")), "settlement")
	var preview_summary: Dictionary = state.pending_showcase_settlement.get("round_summary", {})
	_expect_equal("contract round records real product sales", int(preview_summary.get("sold_count", 0)) > 0, true)
	_expect_equal("challenge settlement applies", bool(view.call("_confirm_showcase_round_settlement", {"sponge_cake": "carry_80"})), true)
	_expect_equal("challenge result clears pending snapshot", state.pending_showcase_challenge, {})
	_expect_equal("challenge instance is marked completed", state.completed_showcase_challenge_ids.size(), 1)
	_expect_equal("challenge report keeps challenge kind", String((state.recent_showcase_round_reports.back() as Dictionary).get("kind", "")), "challenge")
	if not environment_reasons.is_empty():
		var product_report: Dictionary = (((state.recent_showcase_round_reports.back() as Dictionary).get("products", {}) as Dictionary).get("sponge_cake", {}) as Dictionary)
		_expect_equal("round report retains locked environment reason", (product_report.get("triggered_rules", []) as Array).has(String(environment_reasons[0])), true)
	_finish(view)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish(view) -> void:
	view.queue_free()
	if _failures.is_empty():
		print("SHOWCASE_BUSINESS_CHALLENGE_RUNTIME_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_BUSINESS_CHALLENGE_RUNTIME_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
