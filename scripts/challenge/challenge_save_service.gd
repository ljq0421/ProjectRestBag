class_name ChallengeSaveService
extends RefCounted

const SAVE_PATH := "user://project_rest_two_save_v1.json"
const BROKEN_SAVE_PATH := "user://project_rest_two_save_v1.broken.json"
const SCHEMA_VERSION := 1
const INCOMPATIBLE_ERROR := "incompatible_development_save"


static func empty_save() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"meta": {
			"research_points": 0,
			"unlocked_recipe_ids": [],
			"unlocked_variant_ids": [],
			"unlocked_upgrade_ids": [],
			"revealed_research_node_ids": [],
			"boss_first_clear_ids": [],
			"applied_reward_transaction_ids": [],
			"endless_records": {},
			"onboarding": {
				"version": 2,
				"status": "active",
				"step_id": "boss_brief",
				"completed_step_ids": [],
				"pre_battle_draft_fingerprint": "",
				"seen_stage_two_hint_ids": []
			}
		},
		"active_run": null,
		"active_battle": null
	}


static func validate_current(raw: Dictionary) -> Dictionary:
	var json_error := _validate_json_value(raw, "save")
	if not json_error.is_empty():
		return _incompatible(json_error)
	if raw.has("active_draft"):
		return _incompatible("deprecated top-level active_draft is not supported")
	for field in ["schema_version", "meta", "active_run", "active_battle"]:
		if not raw.has(field):
			return _incompatible("missing required field: %s" % field)
	if not _is_integer_number(raw["schema_version"]) or int(raw["schema_version"]) != SCHEMA_VERSION:
		return _incompatible("schema_version must equal %d" % SCHEMA_VERSION)

	var meta_value: Variant = raw["meta"]
	if not meta_value is Dictionary:
		return _incompatible("meta must be a dictionary")
	var meta_error := _validate_meta(meta_value)
	if not meta_error.is_empty():
		return _incompatible(meta_error)

	var active_run_value: Variant = raw["active_run"]
	if active_run_value != null:
		if not active_run_value is Dictionary:
			return _incompatible("active_run must be null or a dictionary")
		var run_error := _validate_active_run(active_run_value)
		if not run_error.is_empty():
			return _incompatible(run_error)

	var active_battle_value: Variant = raw["active_battle"]
	if active_battle_value != null:
		if not active_battle_value is Dictionary:
			return _incompatible("active_battle must be null or a dictionary")
		var battle_error := _validate_active_battle(active_battle_value)
		if not battle_error.is_empty():
			return _incompatible(battle_error)
	return {"ok": true}


static func save(data: Dictionary) -> Dictionary:
	return save_to_path(SAVE_PATH, data)


static func load_save() -> Dictionary:
	return load_from_path(SAVE_PATH)


static func save_to_path(path: String, data: Dictionary) -> Dictionary:
	if path.is_empty():
		return _failure("save path is empty")
	var validation := validate_current(data)
	if not bool(validation.get("ok", false)):
		return validation

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

	var current := _read_current(path)
	if bool(current.get("ok", false)):
		return {"ok": true, "data": current.get("data", {}), "source": "current"}

	_preserve_broken(path)
	var previous_path := path + ".previous"
	var previous := _read_current(previous_path)
	if bool(previous.get("ok", false)):
		var copy_error := DirAccess.copy_absolute(_absolute(previous_path), _absolute(path))
		if copy_error != OK:
			return _failure("previous save is valid but cannot be restored: %s" % error_string(copy_error))
		return {
			"ok": true,
			"data": previous.get("data", {}),
			"source": "previous",
			"recovered_error": current.get("error", ""),
			"recovered_reason": current.get("reason", "")
		}
	if String(current.get("error", "")) == INCOMPATIBLE_ERROR:
		var incompatible := current.duplicate(true)
		incompatible["previous_error"] = previous.get("error", "")
		return incompatible
	return {
		"ok": false,
		"error": "current_and_previous_saves_are_invalid",
		"current_error": current.get("error", ""),
		"previous_error": previous.get("error", "")
	}


static func _read_current(path: String) -> Dictionary:
	var read_result := _read_dictionary(path)
	if not bool(read_result.get("ok", false)):
		return read_result
	var data: Dictionary = read_result.get("data", {})
	var validation := validate_current(data)
	if not bool(validation.get("ok", false)):
		return validation
	return {"ok": true, "data": data}


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


static func _validate_meta(meta: Dictionary) -> String:
	var required_types := {
		"research_points": "integer",
		"unlocked_recipe_ids": "string_array",
		"unlocked_variant_ids": "string_array",
		"unlocked_upgrade_ids": "string_array",
		"revealed_research_node_ids": "string_array",
		"boss_first_clear_ids": "string_array",
		"applied_reward_transaction_ids": "string_array",
		"endless_records": "dictionary",
		"onboarding": "dictionary"
	}
	for field in required_types:
		if not meta.has(field):
			return "meta missing required field: %s" % field
		var type_error := _validate_named_type(meta[field], required_types[field])
		if not type_error.is_empty():
			return "meta.%s %s" % [field, type_error]
	if int(meta["research_points"]) < 0:
		return "meta.research_points must not be negative"
	var onboarding_error := _validate_onboarding(meta["onboarding"])
	if not onboarding_error.is_empty():
		return onboarding_error
	return ""


static func _validate_onboarding(onboarding: Dictionary) -> String:
	var fields := {
		"version": "integer",
		"status": "string",
		"step_id": "string",
		"completed_step_ids": "string_array",
		"pre_battle_draft_fingerprint": "string",
		"seen_stage_two_hint_ids": "string_array"
	}
	for field in fields:
		if not onboarding.has(field):
			return "meta.onboarding missing required field: %s" % field
		var type_error := _validate_named_type(onboarding[field], fields[field])
		if not type_error.is_empty():
			return "meta.onboarding.%s %s" % [field, type_error]
	return ""


static func _validate_active_run(run: Dictionary) -> String:
	if String(run.get("mode", "")) == "vertical_slice":
		return "legacy vertical_slice active_run is not supported"
	var fields := {
		"run_id": "string",
		"mode": "string",
		"seed": "integer",
		"phase": "string",
		"route_id": "string",
		"stage_index": "integer",
		"confidence": "integer",
		"permanent_pool_snapshot": "dictionary",
		"run_upgrades": "array",
		"encounter_instances": "array",
		"loadout_draft": "dictionary",
		"pending_upgrade_offer": "nullable_dictionary",
		"stage_history": "array",
		"settled_settlement_ids": "string_array",
		"applied_run_reward_transaction_ids": "string_array",
		"next_attempt_index": "integer"
	}
	for field in fields:
		if not run.has(field):
			return "active_run missing required field: %s" % field
		var type_error := _validate_named_type(run[field], fields[field])
		if not type_error.is_empty():
			return "active_run.%s %s" % [field, type_error]
	return ""


static func _validate_active_battle(battle: Dictionary) -> String:
	var fields := {
		"battle_attempt_id": "string",
		"encounter_instance_id": "string",
		"stage_index": "integer",
		"snapshot": "dictionary",
		"elapsed_ms": "integer",
		"item_states": "dictionary",
		"pickiness": "integer",
		"reputation": "integer",
		"resolved_windows": "dictionary",
		"events": "array",
		"next_event_seq": "integer"
	}
	for field in fields:
		if not battle.has(field):
			return "active_battle missing required field: %s" % field
		var type_error := _validate_named_type(battle[field], fields[field])
		if not type_error.is_empty():
			return "active_battle.%s %s" % [field, type_error]
	return ""


static func _validate_named_type(value: Variant, expected: String) -> String:
	match expected:
		"integer":
			if _is_integer_number(value):
				return ""
		"string":
			if value is String:
				return ""
		"array":
			if value is Array:
				return ""
		"string_array":
			if value is Array and _all_strings(value):
				return ""
		"dictionary":
			if value is Dictionary:
				return ""
		"nullable_dictionary":
			if value == null or value is Dictionary:
				return ""
	return "must be %s" % expected


static func _all_strings(values: Array) -> bool:
	for value in values:
		if not value is String:
			return false
	return true


static func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value) and value == floor(value)
	return false


static func _validate_json_value(value: Variant, path: String) -> String:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return ""
		TYPE_FLOAT:
			return "" if is_finite(value) else "%s contains a non-finite number" % path
		TYPE_ARRAY:
			for index in range(value.size()):
				var item_error := _validate_json_value(value[index], "%s[%d]" % [path, index])
				if not item_error.is_empty():
					return item_error
			return ""
		TYPE_DICTIONARY:
			for key in value:
				if not key is String:
					return "%s contains a non-string dictionary key" % path
				var field_error := _validate_json_value(value[key], "%s.%s" % [path, key])
				if not field_error.is_empty():
					return field_error
			return ""
	return "%s contains a non-JSON value" % path


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


static func _incompatible(reason: String) -> Dictionary:
	return {
		"ok": false,
		"error": INCOMPATIBLE_ERROR,
		"reason": reason
	}


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
