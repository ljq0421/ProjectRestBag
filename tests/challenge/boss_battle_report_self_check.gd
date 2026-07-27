extends SceneTree

const SERVICE_PATH := "res://scripts/challenge/boss_battle_report_service.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not FileAccess.file_exists(SERVICE_PATH):
		_fail("boss battle report service should exist")
		_finish()
		return
	var service_script = load(SERVICE_PATH)
	_expect(service_script != null and service_script.can_instantiate(), "boss battle report service should compile")
	if service_script == null or not service_script.can_instantiate():
		_finish()
		return
	var service = service_script.new()
	var encounter := {
		"windows": [
			{"id": "early_tempo", "at_ms": 8000, "metric": "sales_count", "target": 3, "reputation_damage": 25},
			{"id": "linked_display", "at_ms": 16000, "metric": "active_relation_count", "target": 1, "reputation_damage": 30},
			{"id": "sustained_service", "at_ms": 24000, "from_ms": 16000, "metric": "window_satisfaction", "target": 30, "reputation_damage": 45}
		]
	}
	var failed_battle := {
		"outcome": "loss_timeout",
		"elapsed_ms": 30000,
		"pickiness": 17,
		"reputation": 55,
		"resolved_windows": {
			"early_tempo": _window_result("early_tempo", "sales_count", 3, 3, true, 0, 100),
			"linked_display": _window_result("linked_display", "active_relation_count", 1, 1, true, 0, 100),
			"sustained_service": _window_result("sustained_service", "window_satisfaction", 22, 30, false, 45, 55)
		},
		"events": [
			_sale("milk_pudding", 7, 1, 8),
			_sale("butter_cookie", 4, 0, 4),
			_sale("milk_pudding", 7, 1, 8),
			_sale("butter_cookie", 4, 0, 4)
		]
	}
	var report: Dictionary = service.build(failed_battle, encounter)
	_expect(report.get("outcome") == "loss_timeout", "report should preserve outcome")
	_expect((report.get("windows", []) as Array).size() == 3, "report should include all demand windows")
	var primary_failure: Dictionary = report.get("primary_failure", {})
	_expect(primary_failure.get("window_id") == "sustained_service", "report should identify the final failed window")
	_expect(int(primary_failure.get("actual", -1)) == 22, "report should expose actual value")
	_expect(int(primary_failure.get("target", -1)) == 30, "report should expose target value")
	var suggestions: Array = report.get("suggestions", [])
	_expect(not suggestions.is_empty() and suggestions[0].get("code") == "increase_window_satisfaction", "suggestion should come from a fixed rule")

	var contributions: Array = report.get("recipe_contributions", [])
	_expect(contributions.size() == 2, "report should aggregate recipe contributions")
	if contributions.size() == 2:
		_expect(contributions[0].get("recipe_id") == "milk_pudding", "contributions should sort by total descending")
		_expect(int(contributions[0].get("sales_count", 0)) == 2, "contribution should count sales")
		_expect(int(contributions[0].get("base_satisfaction", 0)) == 14, "contribution should total base satisfaction")
		_expect(int(contributions[0].get("relation_bonus", 0)) == 2, "contribution should total relation bonus")
		_expect(int(contributions[0].get("total_satisfaction", 0)) == 16, "contribution should total final satisfaction")

	_finish()


func _window_result(
	window_id: String,
	metric: String,
	actual: int,
	target: int,
	passed: bool,
	damage: int,
	reputation_after: int
) -> Dictionary:
	return {
		"type": "demand_window",
		"window_id": window_id,
		"metric": metric,
		"actual": actual,
		"target": target,
		"passed": passed,
		"reputation_damage": damage,
		"reputation_after": reputation_after
	}


func _sale(recipe_id: String, base: int, bonus: int, total: int) -> Dictionary:
	return {
		"type": "sale",
		"recipe_id": recipe_id,
		"base_satisfaction": base,
		"relation_bonus": bonus,
		"final_satisfaction": total
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BOSS_BATTLE_REPORT_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
