extends SceneTree
func _init() -> void:
	var d := _load(); var count := 0
	for entry in d.values():
		if String(entry.get("migration_batch", "")) in ["baseline", "A"]: count += 1
	if count == 30: print("CHALLENGE_30_RECIPE_CATALOG_SELF_CHECK_PASS"); quit(0); return
	push_error("baseline + batch A should contain 30 recipes"); quit(1)
func _load() -> Dictionary:
	var f:=FileAccess.open("res://doc/challenge/recipe_progression_manifest.json",FileAccess.READ);var v:Dictionary=JSON.parse_string(f.get_as_text());f.close();return v.get("recipes",{})
