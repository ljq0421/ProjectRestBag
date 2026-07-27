extends SceneTree

const SAVE_SYSTEM_PATH := "res://scripts/save_system.gd"

var _failures: Array[String] = []


func _init() -> void:
	_run()
	_finish()


func _run() -> void:
	_expect(
		String(ProjectSettings.get_setting("application/config/name", "")) == "project-rest-new",
		"project config name should isolate project-rest-new user data"
	)
	var save_system = load(SAVE_SYSTEM_PATH)
	_expect(save_system != null, "SaveSystem should load")
	if save_system == null:
		return
	var save_path := String(save_system.SAVE_PATH)
	var broken_save_path := String(save_system.BROKEN_SAVE_PATH)
	_expect(save_path == "user://project_rest_new_save.json", "default save path should use project_rest_new")
	_expect(
		broken_save_path == "user://project_rest_new_save.broken.json",
		"broken save path should use project_rest_new"
	)
	_expect(save_path.begins_with("user://"), "default save path should remain in user data")
	_expect(broken_save_path.begins_with("user://"), "broken save path should remain in user data")
	_expect(not save_path.contains("neighbor_dessert"), "default save path must not reuse the old project")
	_expect(not broken_save_path.contains("neighbor_dessert"), "broken save path must not reuse the old project")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PROJECT_IDENTITY_SELF_CHECK_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
