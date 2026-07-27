extends SceneTree

const SERVICE_PATH := "res://scripts/challenge/challenge_save_service.gd"

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
	source["meta"]["unlocked_recipe_ids"] = ["butter_cookie"]
	var saved: Dictionary = service.save_to_path(_save_path, source)
	_expect(bool(saved.get("ok", false)), "save should succeed")
	var loaded: Dictionary = service.load_from_path(_save_path)
	_expect(bool(loaded.get("ok", false)), "load should succeed")
	var loaded_data: Dictionary = loaded.get("data", {})
	var loaded_meta: Dictionary = loaded_data.get("meta", {})
	_expect(loaded_meta.get("unlocked_recipe_ids", []) == ["butter_cookie"], "loaded recipes should match saved data")

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
	_expect(FileAccess.file_exists(_save_path + ".broken"), "malformed save should be preserved as broken")

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
