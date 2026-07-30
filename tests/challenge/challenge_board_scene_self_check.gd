extends SceneTree

const BOARD_PATH := "res://scenes/challenge/challenge_board.tscn"
const SUPPLY_CARD_PATH := "res://scenes/challenge/challenge_supply_card.tscn"
const LOADOUT_SERVICE := preload("res://scripts/challenge/challenge_loadout_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	for path in [BOARD_PATH, SUPPLY_CARD_PATH]:
		if not ResourceLoader.exists(path):
			_fail("required challenge scene should exist: %s" % path)
	if not _failures.is_empty():
		_finish()
		return

	var board_scene = load(BOARD_PATH)
	var supply_scene = load(SUPPLY_CARD_PATH)
	_expect(board_scene != null, "challenge board scene should load")
	_expect(supply_scene != null, "challenge supply card scene should load")
	if board_scene == null or supply_scene == null:
		_finish()
		return
	var board = board_scene.instantiate()
	root.add_child(board)
	await process_frame

	var board_grid: GridContainer = board.get_node("BoardFrame/BoardGrid")
	_expect(board_grid.columns == 14, "board should reserve fourteen columns")
	_expect(board_grid.get_child_count() == 112, "board should reserve 8x14 fixed cells")
	_expect(board.has_method("place_recipe"), "board should expose placement intent")
	_expect(board.has_method("set_locked"), "board should expose battle lock")

	var recipe_config := _load_json("res://doc/challenge/challenge_recipes.json")
	var encounter_config := _load_json("res://doc/challenge/boss_encounters.json")
	var defs: Dictionary = recipe_config.get("recipes", {})
	var encounter: Dictionary = (encounter_config.get("encounters", {}) as Dictionary).get("picky_food_critic", {})
	board.call("bind", defs, LOADOUT_SERVICE.new(), encounter, 16)
	_expect(bool(board.call("place_recipe", "milk_pudding", [1, 1], 0, "pudding_1")), "board should place milk pudding")
	_expect(int(board.call("get_occupied_cell_count")) == 2, "milk pudding should occupy two cells")
	var pudding_top_icon: TextureRect = board_grid.get_child(1 * 14 + 1).get_node("IconHost/Icon")
	var pudding_bottom_icon: TextureRect = board_grid.get_child(2 * 14 + 1).get_node("IconHost/Icon")
	_expect(
		pudding_top_icon.texture != null
			and not pudding_top_icon.texture is AtlasTexture
			and pudding_bottom_icon.texture == null
			and pudding_top_icon.size.y > (
				(board_grid.get_child(1 * 14 + 1) as Control).size.y * 1.5
			),
		"default milk pudding should be one complete vertical image spanning two cells"
	)
	_expect(bool(board.call("rotate_instance", "pudding_1")), "board should rotate a rotatable recipe")
	var rotated_draft: Dictionary = board.call("get_draft")
	_expect(rotated_draft["placements"][0]["rotation"] == 90, "rotation intent should advance by 90 degrees")
	_expect(int(board.call("get_occupied_cell_count")) == 2, "rotated milk pudding should still occupy two cells")
	var pudding_left_icon: TextureRect = board_grid.get_child(1 * 14 + 1).get_node("IconHost/Icon")
	var pudding_right_icon: TextureRect = board_grid.get_child(1 * 14 + 2).get_node("IconHost/Icon")
	_expect(
		pudding_left_icon.texture != null
			and not pudding_left_icon.texture is AtlasTexture
			and pudding_right_icon.texture == null
			and pudding_left_icon.size.x > (
				(board_grid.get_child(1 * 14 + 1) as Control).size.x * 1.5
			),
		"rotated milk pudding should be one complete horizontal image spanning two cells"
	)
	var single_summary: Dictionary = board.call("get_build_summary")
	_expect(int(single_summary.get("instance_count", 0)) == 1, "board should expose live build count")
	_expect(int(single_summary.get("cycle_min_ms", 0)) == 5000, "board should expose build cycle range")

	board.call("set_locked", true)
	var locked_before := JSON.stringify(board.call("get_draft"))
	_expect(not bool(board.call("place_recipe", "butter_cookie", [0, 0], 0, "cookie_1")), "locked board should reject placement")
	_expect(not bool(board.call("rotate_instance", "pudding_1")), "locked board should reject rotation")
	_expect(not bool(board.call("remove_instance", "pudding_1")), "locked board should reject removal")
	_expect(JSON.stringify(board.call("get_draft")) == locked_before, "locked board operations should preserve draft")

	var supply = supply_scene.instantiate()
	root.add_child(supply)
	await process_frame
	_expect(supply.has_signal("recipe_drag_started"), "supply card should expose recipe drag signal")
	_expect(supply.has_method("bind"), "supply card should expose bind")
	supply.call("bind", "butter_cookie", defs.get("butter_cookie", {}), "黄油曲奇")
	supply.call("set_selected_count", 2)
	_expect((supply.get_node("CountBadge") as Label).text.find("2") >= 0, "supply card should show selected count")
	_expect((supply.get_node("CostBadge") as Label).text.find("2") >= 0, "supply card should show challenge cost")
	_expect((supply.get_node("StatsLabel") as Label).text.find("4 秒/次") >= 0, "supply card should show sale cycle")
	_expect((supply.get_node("StatsLabel") as Label).text.find("满足 4") >= 0, "supply card should show satisfaction")
	_expect((supply.get_node("TagsLabel") as Label).text.find("快速") >= 0, "supply card should show localized tags")
	_expect(supply.tooltip_text.find("上下左右贴边") >= 0, "supply tooltip should explain adjacency")

	supply.queue_free()
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
		print("CHALLENGE_BOARD_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
