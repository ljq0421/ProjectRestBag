extends SceneTree

const SERVICE_PATH := "res://scripts/challenge/recipe_research_service.gd"
const TREE_PATH := "res://doc/challenge/research_tree.json"
const RECIPES_PATH := "res://doc/challenge/challenge_recipes.json"

const STARTER_IDS := [
	"butter_cookie",
	"strawberry_jelly",
	"milk_pudding",
	"blueberry_muffin",
	"sponge_cake",
	"chocolate_lava_cake"
]
const RESEARCH_IDS := [
	"vanilla_scone",
	"chocolate_cookie",
	"blueberry_mousse",
	"strawberry_mousse",
	"cream_shortcake",
	"caramel_mousse"
]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in [SERVICE_PATH, TREE_PATH, RECIPES_PATH]:
		if not FileAccess.file_exists(path):
			_fail("required file should exist: %s" % path)
	if not _failures.is_empty():
		_finish()
		return
	var service_script = load(SERVICE_PATH)
	_expect(service_script != null, "research service should load")
	_expect(service_script != null and service_script.can_instantiate(), "research service should compile")
	if service_script == null or not service_script.can_instantiate():
		_finish()
		return
	var service = service_script.new()
	var tree := _load_json(TREE_PATH)
	var recipe_config := _load_json(RECIPES_PATH)
	var recipe_defs: Dictionary = recipe_config.get("recipes", {})

	_test_tree_validation(service, tree, recipe_defs)
	_test_bootstrap_and_reveals(service, tree)
	_test_completion_and_purchases(service, tree)
	_finish()


func _test_tree_validation(service, tree: Dictionary, recipe_defs: Dictionary) -> void:
	var validation: Dictionary = service.validate_tree(tree, recipe_defs, {})
	for error in validation.get("errors", []):
		_fail("committed research tree should validate: %s" % String(error))
	_expect(bool(validation.get("valid", false)), "committed research tree should be a valid DAG")

	var missing_prerequisite := tree.duplicate(true)
	missing_prerequisite["nodes"]["chocolate_cookie"]["prerequisite_ids"] = ["missing_node"]
	_expect(
		not bool(service.validate_tree(missing_prerequisite, recipe_defs, {}).get("valid", true)),
		"tree should reject a broken prerequisite link"
	)

	var cycle := tree.duplicate(true)
	cycle["nodes"]["vanilla_scone"]["prerequisite_ids"] = ["chocolate_cookie"]
	_expect(
		not bool(service.validate_tree(cycle, recipe_defs, {}).get("valid", true)),
		"tree should reject prerequisite cycles"
	)

	var duplicate_unlock := tree.duplicate(true)
	duplicate_unlock["nodes"]["strawberry_mousse"]["unlocks"][0]["id"] = "blueberry_mousse"
	_expect(
		not bool(service.validate_tree(duplicate_unlock, recipe_defs, {}).get("valid", true)),
		"tree should reject duplicate unlock ownership"
	)

	var disconnected := tree.duplicate(true)
	disconnected["branches"][0]["node_ids"].erase("chocolate_cookie")
	_expect(
		not bool(service.validate_tree(disconnected, recipe_defs, {}).get("valid", true)),
		"tree should reject a node disconnected from its branch"
	)


func _test_bootstrap_and_reveals(service, tree: Dictionary) -> void:
	var meta: Dictionary = service.bootstrap_meta({}, tree)
	_expect(int(meta.get("research_points", -1)) == 0, "new development profile should start with zero research points")
	_expect(meta.get("unlocked_recipe_ids", []) == STARTER_IDS, "new profile should receive exactly six starter recipes")
	for recipe_id in RESEARCH_IDS:
		_expect(
			not (meta.get("unlocked_recipe_ids", []) as Array).has(recipe_id),
			"new profile should not receive research recipe %s" % recipe_id
		)

	var reveal_ids: Array = tree.get("boss_reveals", {}).get("morning_rush", [])
	var revealed: Dictionary = service.reveal_for_boss_clear(
		meta,
		"morning_rush",
		reveal_ids,
		"boss-first-clear:morning_rush"
	)
	_expect(bool(revealed.get("applied", false)), "first boss clear should reveal its branch")
	meta = revealed.get("meta", {})
	_expect(
		meta.get("revealed_research_node_ids", []) == ["vanilla_scone", "chocolate_cookie"],
		"boss clear should reveal configured branch nodes"
	)
	var revealed_state: Dictionary = service.node_state(meta, "vanilla_scone", tree)
	_expect(revealed_state.get("status") == "insufficient_points", "revealed base node should expose point gating")
	for field in ["cost", "prerequisite_ids", "tags", "build_purpose"]:
		_expect(revealed_state.has(field), "revealed node should expose %s" % field)
	var hidden_state: Dictionary = service.node_state(meta, "blueberry_mousse", tree)
	_expect(hidden_state.get("status") == "hidden", "unrevealed node should remain hidden")
	_expect(not hidden_state.has("build_purpose"), "hidden node should not expose build details")

	var first_clear_meta := meta.duplicate(true)
	var duplicate: Dictionary = service.reveal_for_boss_clear(
		meta,
		"morning_rush",
		reveal_ids,
		"boss-first-clear:morning_rush:duplicate"
	)
	_expect(not bool(duplicate.get("applied", true)), "same boss should not reveal twice with a different transaction")
	_expect(duplicate.get("meta", {}) == first_clear_meta, "duplicate boss clear should not change meta")


func _test_completion_and_purchases(service, tree: Dictionary) -> void:
	var meta: Dictionary = service.bootstrap_meta({}, tree)
	meta = service.reveal_for_boss_clear(
		meta,
		"morning_rush",
		tree.get("boss_reveals", {}).get("morning_rush", []),
		"boss-first-clear:morning_rush"
	).get("meta", {})

	var hidden_purchase: Dictionary = service.unlock_node(
		meta,
		"blueberry_mousse",
		tree,
		"research-purchase:hidden"
	)
	_expect(hidden_purchase.get("error") == "research_node_not_revealed", "hidden node purchase should be rejected")

	var prerequisite_purchase: Dictionary = service.unlock_node(
		meta,
		"chocolate_cookie",
		tree,
		"research-purchase:prerequisite"
	)
	_expect(
		prerequisite_purchase.get("error") == "research_prerequisites_not_met",
		"missing prerequisite purchase should be rejected before point spending"
	)

	var no_points_purchase: Dictionary = service.unlock_node(
		meta,
		"vanilla_scone",
		tree,
		"research-purchase:no-points"
	)
	_expect(no_points_purchase.get("error") == "insufficient_research_points", "insufficient points should reject purchase")

	var completion_tx := "standard:test:research-complete"
	var completed: Dictionary = service.grant_run_completion(meta, 3, completion_tx)
	_expect(bool(completed.get("applied", false)), "standard completion should grant research points")
	meta = completed.get("meta", {})
	_expect(int(meta.get("research_points", -1)) == 3, "one standard completion should grant exactly three points")
	var completed_meta := meta.duplicate(true)
	var duplicate_completion: Dictionary = service.grant_run_completion(meta, 3, completion_tx)
	_expect(not bool(duplicate_completion.get("applied", true)), "completion reward transaction should be idempotent")
	_expect(duplicate_completion.get("meta", {}) == completed_meta, "duplicate completion should not add points")

	var bought: Dictionary = service.unlock_node(
		meta,
		"vanilla_scone",
		tree,
		"research-purchase:vanilla_scone"
	)
	_expect(bool(bought.get("applied", false)), "revealed affordable base node should be purchasable")
	meta = bought.get("meta", {})
	_expect(int(meta.get("research_points", -1)) == 0, "base node should cost three points")
	_expect((meta.get("unlocked_recipe_ids", []) as Array).has("vanilla_scone"), "purchase should permanently unlock its recipe")
	_expect(service.node_state(meta, "vanilla_scone", tree).get("status") == "unlocked", "unlocked node should report unlocked")

	var bought_meta := meta.duplicate(true)
	var duplicate_purchase: Dictionary = service.unlock_node(
		meta,
		"vanilla_scone",
		tree,
		"research-purchase:vanilla_scone:duplicate"
	)
	_expect(not bool(duplicate_purchase.get("applied", true)), "duplicate node purchase should be ignored")
	_expect(duplicate_purchase.get("meta", {}) == bought_meta, "duplicate purchase should not deduct points or unlock twice")

	var second_completion: Dictionary = service.grant_run_completion(
		meta,
		7,
		"standard:test:second-research-complete"
	)
	meta = second_completion.get("meta", {})
	_expect(
		service.node_state(meta, "chocolate_cookie", tree).get("status") == "available",
		"purchased prerequisite and enough points should make tier two available"
	)
	var second_bought: Dictionary = service.unlock_node(
		meta,
		"chocolate_cookie",
		tree,
		"research-purchase:chocolate_cookie"
	)
	_expect(bool(second_bought.get("applied", false)), "tier two node should be purchasable after prerequisite")
	meta = second_bought.get("meta", {})
	_expect(int(meta.get("research_points", -1)) == 0, "tier two node should cost seven points")
	var available: Array[String] = service.available_recipe_ids(meta, tree)
	_expect(available.size() == 8, "permanent pool should include six starter and two purchased recipes")
	_expect(available.slice(0, 6) == STARTER_IDS, "permanent pool should preserve starter recipe order")
	_expect(available.slice(6, 8) == ["vanilla_scone", "chocolate_cookie"], "permanent pool should append research branch order")


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("could not open JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_fail("JSON root should be a dictionary: %s" % path)
		return {}
	return parsed


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RECIPE_RESEARCH_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
