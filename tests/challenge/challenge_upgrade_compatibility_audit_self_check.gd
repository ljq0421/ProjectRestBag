extends SceneTree

func _init() -> void:
	var recipes: Dictionary = _load("res://doc/challenge/challenge_recipes.json").get("recipes", {})
	var upgrades: Dictionary = _load("res://doc/challenge/run_upgrades.json").get("upgrades", {})
	var targeted_tags := {}
	for upgrade in upgrades.values():
		if String(upgrade.get("category", "")) == "compatible":
			for tag in (upgrade.get("effect", {}) as Dictionary).get("target_tags", []):
				targeted_tags[String(tag)] = true
	var missing: Array[String] = []
	for role in ["tempo","pairing","signature","softness","flavor","shape","sustain","space"]:
		var covered := false
		for recipe in recipes.values():
			if (recipe.get("build_roles", []) as Array).has(role):
				for tag in recipe.get("tags", []):
					if targeted_tags.has(String(tag)): covered = true
		if not covered: missing.append(role)
	if missing.is_empty(): print("CHALLENGE_UPGRADE_COMPATIBILITY_AUDIT_SELF_CHECK_PASS");quit(0);return
	push_error("roles without compatible upgrade: %s" % [missing]);quit(1)

func _load(path:String)->Dictionary:
	var f:=FileAccess.open(path,FileAccess.READ);var value:Variant=JSON.parse_string(f.get_as_text());f.close();return value if value is Dictionary else {}
