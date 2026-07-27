extends SceneTree

const SERVICE_PATH := "res://scripts/challenge/challenge_save_service.gd"
const TUTORIAL_PROGRESS_PATH := "res://scripts/challenge/challenge_tutorial_progress.gd"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("project_rest_two_challenge_save_test.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ResourceLoader.exists(SERVICE_PATH):
		_fail("challenge save service should exist")
		_finish()
		return
	var service = load(SERVICE_PATH)
	_expect(service != null, "challenge save service should load")
	if service == null:
		_finish()
		return
	_expect(service.SAVE_PATH == "user://project_rest_two_save_v1.json", "save path should use project-rest-two namespace")
	_expect(service.BROKEN_SAVE_PATH == "user://project_rest_two_save_v1.broken.json", "broken path should use project-rest-two namespace")
	_expect(service.SAVE_PATH.find("project_rest_new") == -1, "save path must not mention project-rest-new")

	_cleanup()
	var source: Dictionary = service.empty_save()
	var default_onboarding: Dictionary = source.get("onboarding", {})
	_expect(int(default_onboarding.get("version", 0)) == 1, "empty save should start onboarding at version 1")
	_expect(String(default_onboarding.get("status", "")) == "active", "empty save should activate onboarding")
	_expect(String(default_onboarding.get("step_id", "")) == "boss_brief", "empty save should start onboarding at boss brief")
	_expect(default_onboarding.get("completed_step_ids", []) == [], "empty save should start with no completed onboarding steps")
	_expect(String(default_onboarding.get("pre_battle_draft_fingerprint", "")) == "", "empty save should start without a draft fingerprint")
	source["meta"]["unlocked_recipe_ids"] = ["butter_cookie"]
	source["onboarding"] = {
		"version": 1,
		"status": "dismissed",
		"step_id": "read_report",
		"completed_step_ids": ["boss_brief", "place_recipe"],
		"pre_battle_draft_fingerprint": "draft-fingerprint"
	}
	var saved: Dictionary = service.save_to_path(_save_path, source)
	_expect(bool(saved.get("ok", false)), "save should succeed")
	var loaded: Dictionary = service.load_from_path(_save_path)
	_expect(bool(loaded.get("ok", false)), "load should succeed")
	var loaded_data: Dictionary = loaded.get("data", {})
	var loaded_meta: Dictionary = loaded_data.get("meta", {})
	_expect(loaded_meta.get("unlocked_recipe_ids", []) == ["butter_cookie"], "loaded recipes should match saved data")
	_expect_onboarding(loaded_data, source["onboarding"], "loaded")
	_expect(loaded_data.get("active_run", "missing") == null, "loaded active run should keep empty-save contract")
	_expect(loaded_data.get("active_draft", {}) == {"placements": []}, "loaded active draft should keep empty-save contract")
	_expect(loaded_data.get("active_battle", "missing") == null, "loaded active battle should keep empty-save contract")

	var replacement: Dictionary = service.empty_save()
	replacement["meta"]["research_points"] = 7
	var replaced: Dictionary = service.save_to_path(_save_path, replacement)
	_expect(bool(replaced.get("ok", false)), "replacement save should succeed")
	_expect(FileAccess.file_exists(_save_path + ".previous"), "replacement should retain previous save")
	var loaded_replacement: Dictionary = service.load_from_path(_save_path)
	var replacement_meta: Dictionary = (loaded_replacement.get("data", {}) as Dictionary).get("meta", {})
	_expect(int(replacement_meta.get("research_points", 0)) == 7, "replacement data should become current")

	var corrupt := FileAccess.open(_save_path, FileAccess.WRITE)
	if corrupt == null:
		_fail("test should open save for corruption")
	else:
		corrupt.store_string("{broken")
		corrupt.close()
	var recovered: Dictionary = service.load_from_path(_save_path)
	_expect(bool(recovered.get("ok", false)), "malformed current save should recover")
	_expect(String(recovered.get("source", "")) == "previous", "recovery should report previous source")
	var recovered_meta: Dictionary = (recovered.get("data", {}) as Dictionary).get("meta", {})
	_expect(recovered_meta.get("unlocked_recipe_ids", []) == ["butter_cookie"], "recovery should load previous data")
	var recovered_data: Dictionary = recovered.get("data", {})
	_expect_onboarding(recovered_data, source["onboarding"], "recovery")
	_expect(recovered_data.get("active_run", "missing") == null, "recovery should keep active run contract")
	_expect(recovered_data.get("active_draft", {}) == {"placements": []}, "recovery should keep active draft contract")
	_expect(recovered_data.get("active_battle", "missing") == null, "recovery should keep active battle contract")
	_expect(FileAccess.file_exists(_save_path + ".broken"), "malformed save should be preserved as broken")

	var future_source: Dictionary = service.empty_save()
	future_source["onboarding"] = {
		"version": 2,
		"status": "future-status",
		"step_id": "future-step",
		"unknown_nested": {"keep": [1, {"value": true}]}
	}
	_expect(bool(service.save_to_path(_save_path, future_source).get("ok", false)), "future onboarding save should succeed")
	var future_loaded: Dictionary = service.load_from_path(_save_path)
	var future_onboarding: Dictionary = (future_loaded.get("data", {}) as Dictionary).get("onboarding", {})
	_expect(int(future_onboarding.get("version", 0)) == 2, "save service should not downgrade a future onboarding version")
	_expect(future_onboarding.get("unknown_nested", {}) == {"keep": [1.0, {"value": true}]}, "save service should preserve unknown future onboarding fields")

	var malformed_source: Dictionary = service.empty_save()
	malformed_source["meta"] = {"research_points": 13, "custom_meta": {"keep": true}}
	malformed_source["active_run"] = {"run_id": "keep-run", "phase": "battle", "custom": [1, 2]}
	malformed_source["active_draft"] = {"placements": [{"instance_id": "keep-draft"}], "custom": "draft"}
	malformed_source["active_battle"] = {"phase": "running", "elapsed_ms": 1234, "custom": "battle"}
	malformed_source["unrelated_business"] = {"ledger": [{"id": "keep-ledger"}]}
	malformed_source["onboarding"] = {
		"version": {},
		"status": null,
		"step_id": 42,
		"completed_step_ids": {"not": "an array"},
		"pre_battle_draft_fingerprint": false,
		"unknown_nested": {"keep": ["unknown", {"field": true}]}
	}
	var tutorial = load(TUTORIAL_PROGRESS_PATH).new()
	malformed_source["onboarding"] = tutorial.normalize(malformed_source["onboarding"], "battle")
	var expected_business := malformed_source.duplicate(true)
	expected_business.erase("onboarding")
	expected_business = JSON.parse_string(JSON.stringify(expected_business))
	_expect(bool(service.save_to_path(_save_path, malformed_source).get("ok", false)), "sanitized malformed onboarding save should succeed")
	var malformed_loaded: Dictionary = (service.load_from_path(_save_path).get("data", {}) as Dictionary)
	var loaded_business := malformed_loaded.duplicate(true)
	loaded_business.erase("onboarding")
	_expect(loaded_business == expected_business, "onboarding sanitization preserves all unrelated save business data")
	_expect(
		(malformed_loaded.get("onboarding", {}) as Dictionary).get("unknown_nested", {})
			== {"keep": ["unknown", {"field": true}]},
		"onboarding sanitization preserves unknown nested onboarding fields"
	)

	_cleanup()
	_finish()


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken", ".broken.previous"]:
		var path: String = _save_path + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _expect_onboarding(data: Dictionary, expected: Dictionary, context: String) -> void:
	var onboarding: Dictionary = data.get("onboarding", {})
	_expect(int(onboarding.get("version", 0)) == int(expected.get("version", 0)), context + " onboarding version should survive")
	_expect(String(onboarding.get("status", "")) == String(expected.get("status", "")), context + " onboarding status should survive")
	_expect(String(onboarding.get("step_id", "")) == String(expected.get("step_id", "")), context + " onboarding step should survive")
	_expect(onboarding.get("completed_step_ids", []) == expected.get("completed_step_ids", []), context + " onboarding completed steps should survive")
	_expect(
		String(onboarding.get("pre_battle_draft_fingerprint", ""))
			== String(expected.get("pre_battle_draft_fingerprint", "")),
		context + " onboarding draft fingerprint should survive"
	)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_SAVE_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
