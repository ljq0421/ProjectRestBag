extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var taxonomy := _load_json("res://doc/challenge/challenge_tag_taxonomy.json")
	var manifest := _load_json("res://doc/challenge/recipe_progression_manifest.json")
	var tags: Dictionary = taxonomy.get("tags", {})
	var roles: Dictionary = taxonomy.get("build_roles", {})
	_expect(tags.size() == 16, "taxonomy should define 16 planned combat tags")
	_expect(roles.size() == 8, "taxonomy should define eight build roles")
	var entries: Dictionary = manifest.get("recipes", {})
	for recipe_id_value in entries:
		var entry_value: Variant = entries[recipe_id_value]
		if not entry_value is Dictionary:
			continue
		var recipe_id := String(entry_value.get("recipe_id", ""))
		for tag in entry_value.get("combat_tags", []):
			_expect(tags.has(String(tag)), "manifest recipe %s uses unknown tag %s" % [recipe_id, tag])
		for role in entry_value.get("build_roles", []):
			_expect(roles.has(String(role)), "manifest recipe %s uses unknown role %s" % [recipe_id, role])
	_finish()


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_TAG_TAXONOMY_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
