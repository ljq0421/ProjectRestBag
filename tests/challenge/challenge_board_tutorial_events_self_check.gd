extends SceneTree

const BOARD_PATH := "res://scenes/challenge/challenge_board.tscn"
const LOADOUT_SERVICE := preload("res://scripts/challenge/challenge_loadout_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var board_scene = load(BOARD_PATH)
	_expect(board_scene != null, "challenge board scene should load")
	if board_scene == null:
		_finish()
		return
	var board = board_scene.instantiate()
	root.add_child(board)
	await process_frame

	var recipe_config := _load_json("res://doc/challenge/challenge_recipes.json")
	var encounter_config := _load_json("res://doc/challenge/boss_encounters.json")
	var defs: Dictionary = recipe_config.get("recipes", {})
	var encounter: Dictionary = (encounter_config.get("encounters", {}) as Dictionary).get("picky_food_critic", {})
	board.bind(defs, LOADOUT_SERVICE.new(), encounter, 16)

	var events: Array[String] = []
	board.recipe_placed.connect(func(instance_id: String, recipe_id: String) -> void:
		events.append("placed:%s:%s" % [instance_id, recipe_id])
	)
	board.instance_rotated.connect(func(
		instance_id: String,
		recipe_id: String,
		rotation: int,
		shape_changed: bool
	) -> void:
		events.append("rotated:%s:%s:%d:%s" % [instance_id, recipe_id, rotation, shape_changed])
	)

	_expect(board.place_recipe("milk_pudding", [1, 1], 0, "pudding_1"), "pudding placement succeeds")
	_expect(events == ["placed:pudding_1:milk_pudding"], "successful placement emits once")
	_expect(board.rotate_instance("pudding_1"), "pudding rotation succeeds")
	_expect(events[1] == "rotated:pudding_1:milk_pudding:90:true", "shape-changing rotation emits")

	var event_count := events.size()
	_expect(not board.place_recipe("sponge_cake", [7, 5]), "out-of-bounds placement fails")
	_expect(events.size() == event_count, "rejected placement emits no success event")
	_expect(board.is_current_draft_valid(), "committed draft remains valid")
	_expect(not board.get_tutorial_target_rects("board").is_empty(), "board target resolves")
	var risk_targets: Array[Rect2] = board.get_tutorial_target_rects("risk")
	_expect(not risk_targets.is_empty(), "risk target resolves")
	_expect(
		risk_targets[0].size.x < board.size.x,
		"risk highlight should hug the visible header chips instead of the full row"
	)
	_expect(not board.get_tutorial_target_rects("instance", "pudding_1").is_empty(), "instance cells resolve")

	board.queue_free()
	await process_frame
	_finish()


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
		print("CHALLENGE_BOARD_TUTORIAL_EVENTS_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
