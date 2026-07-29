extends SceneTree

const SaveService = preload("res://scripts/challenge/challenge_save_service.gd")

var _failures: Array[String] = []
var _path := OS.get_temp_dir().path_join("project_rest_two_menu_save_self_check.json")


func _init() -> void:
	for suffix in ["", ".tmp", ".previous", ".broken"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)
	var save := SaveService.empty_save()
	var meta: Dictionary = save.get("meta", {})
	_expect(meta.has("active_menu_recipe_ids"), "save meta should include active menu")
	_expect(meta.has("saved_menus"), "save meta should reserve saved menu presets")
	_expect(meta.has("unlocked_route_ids"), "save meta should reserve route progression")
	meta["active_menu_recipe_ids"] = ["a", "b", "c", "d"]
	meta["saved_menus"] = [{"name": "测试", "recipe_ids": ["a", "b", "c", "d"]}]
	save["meta"] = meta
	var saved := SaveService.save_to_path(_path, save)
	_expect(bool(saved.get("ok", false)), "extended development save should persist")
	var loaded := SaveService.load_from_path(_path)
	var loaded_meta: Dictionary = (loaded.get("data", {}) as Dictionary).get("meta", {})
	_expect(loaded_meta.get("active_menu_recipe_ids", []) == ["a", "b", "c", "d"], "active menu should round trip")
	_expect((loaded_meta.get("saved_menus", []) as Array).size() == 1, "saved menu preset should round trip")
	for suffix in ["", ".tmp", ".previous", ".broken"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_MENU_SAVE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
