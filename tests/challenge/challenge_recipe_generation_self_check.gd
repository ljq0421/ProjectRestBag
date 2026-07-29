extends SceneTree

const RUNTIME_PATH := "res://doc/challenge/challenge_recipes.json"
const MANIFEST_PATH := "res://doc/challenge/recipe_progression_manifest.json"

var _failures: Array[String] = []


func _init() -> void:
	var runtime := _load_json(RUNTIME_PATH)
	var manifest := _load_json(MANIFEST_PATH)
	var recipes: Dictionary = runtime.get("recipes", {})
	var entries: Dictionary = manifest.get("recipes", {})
	var released := {}
	for recipe_id in entries:
		var entry_value: Variant = entries[recipe_id]
		if entry_value is Dictionary and String(entry_value.get("content_status", "")) == "released":
			released[String(recipe_id)] = entry_value
	_expect(recipes.size() == 166, "runtime generation should expose all 166 released recipes")
	_expect(released.size() == 166, "manifest should expose all 166 released recipes")
	for recipe_id in recipes:
		_expect(released.has(recipe_id), "runtime recipe should have a released manifest entry: %s" % recipe_id)
		if released.has(recipe_id):
			_expect(
				recipes[recipe_id].get("build_roles", []) == released[recipe_id].get("build_roles", []),
				"generated runtime roles should match manifest: %s" % recipe_id
			)
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
		print("CHALLENGE_RECIPE_GENERATION_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
