extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var manifest := _load_json("res://doc/challenge/recipe_progression_manifest.json")
	var entries: Dictionary = manifest.get("recipes", {})
	var ids := {}
	var batches := {}
	var statuses := {}
	for recipe_key in entries:
		var entry_value: Variant = entries[recipe_key]
		if not entry_value is Dictionary:
			_failures.append("manifest entry must be a dictionary")
			continue
		var recipe_id := String(entry_value.get("recipe_id", ""))
		_expect(not recipe_id.is_empty(), "manifest id must not be empty")
		_expect(not ids.has(recipe_id), "manifest id must be unique: %s" % recipe_id)
		ids[recipe_id] = true
		var batch := String(entry_value.get("migration_batch", ""))
		batches[batch] = int(batches.get(batch, 0)) + 1
		var status := String(entry_value.get("content_status", ""))
		statuses[status] = int(statuses.get(status, 0)) + 1
	_expect(entries.size() == 166, "manifest should cover all 166 catalog recipes")
	_expect(batches == {"baseline": 12, "A": 18, "B": 34, "C": 48, "D": 54}, "migration batch counts should remain frozen")
	_expect(int(statuses.get("released", 0)) == 166, "all 166 recipes should be released after batch D")
	_expect(int(statuses.get("draft", 0)) == 0, "no migration draft should remain after stage 10")
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
		print("CHALLENGE_RECIPE_MANIFEST_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
