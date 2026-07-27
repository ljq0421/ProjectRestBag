class_name ChallengeSaveService
extends RefCounted

const SAVE_PATH := "user://project_rest_two_save_v1.json"
const BROKEN_SAVE_PATH := "user://project_rest_two_save_v1.broken.json"


static func empty_save() -> Dictionary:
	return {
		"schema_version": 1,
		"meta": {
			"research_points": 0,
			"unlocked_recipe_ids": [],
			"revealed_research_node_ids": [],
			"boss_first_clear_ids": [],
			"endless_records": {}
		},
		"onboarding": {
			"version": 1,
			"status": "active",
			"step_id": "boss_brief",
			"completed_step_ids": [],
			"pre_battle_draft_fingerprint": ""
		},
		"active_run": null,
		"active_draft": {"placements": []},
		"active_battle": null
	}


static func save(data: Dictionary) -> Dictionary:
	return save_to_path(SAVE_PATH, data)


static func load_save() -> Dictionary:
	return load_from_path(SAVE_PATH)


static func save_to_path(path: String, data: Dictionary) -> Dictionary:
	if path.is_empty():
		return _failure("save path is empty")
	var temporary_path := path + ".tmp"
	var previous_path := path + ".previous"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _failure("cannot open temporary save: %s" % FileAccess.get_open_error())
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	if FileAccess.file_exists(previous_path):
		var remove_previous_error := DirAccess.remove_absolute(_absolute(previous_path))
		if remove_previous_error != OK:
			_remove_if_exists(temporary_path)
			return _failure("cannot replace previous save: %s" % error_string(remove_previous_error))
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(_absolute(path), _absolute(previous_path))
		if backup_error != OK:
			_remove_if_exists(temporary_path)
			return _failure("cannot back up current save: %s" % error_string(backup_error))

	var promote_error := DirAccess.rename_absolute(_absolute(temporary_path), _absolute(path))
	if promote_error != OK:
		if FileAccess.file_exists(previous_path) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(_absolute(previous_path), _absolute(path))
		_remove_if_exists(temporary_path)
		return _failure("cannot promote temporary save: %s" % error_string(promote_error))
	return {"ok": true, "path": path}


static func load_from_path(path: String) -> Dictionary:
	if path.is_empty():
		return _failure("save path is empty")
	if not FileAccess.file_exists(path):
		return {"ok": true, "data": empty_save(), "source": "new"}

	var current := _read_dictionary(path)
	if bool(current.get("ok", false)):
		return {"ok": true, "data": current.get("data", {}), "source": "current"}

	_preserve_broken(path)
	var previous_path := path + ".previous"
	var previous := _read_dictionary(previous_path)
	if bool(previous.get("ok", false)):
		var copy_error := DirAccess.copy_absolute(_absolute(previous_path), _absolute(path))
		if copy_error != OK:
			return _failure("previous save is valid but cannot be restored: %s" % error_string(copy_error))
		return {
			"ok": true,
			"data": previous.get("data", {}),
			"source": "previous",
			"recovered_error": current.get("error", "")
		}
	return _failure("current and previous saves are invalid")


static func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("file does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("cannot open save: %s" % FileAccess.get_open_error())
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		return _failure("invalid JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
	var value: Variant = parser.data
	if typeof(value) != TYPE_DICTIONARY:
		return _failure("save root is not a dictionary: %s" % path)
	return {"ok": true, "data": value}


static func _preserve_broken(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var broken_path := path + ".broken"
	var older_broken_path := broken_path + ".previous"
	_remove_if_exists(older_broken_path)
	if FileAccess.file_exists(broken_path):
		DirAccess.rename_absolute(_absolute(broken_path), _absolute(older_broken_path))
	DirAccess.rename_absolute(_absolute(path), _absolute(broken_path))


static func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_absolute(path))


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
