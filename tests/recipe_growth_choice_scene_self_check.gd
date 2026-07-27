extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")
const RecipeGrowthService := preload("res://scripts/recipe_growth_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var state = GAME_STATE.new_game()
	state.level = 2
	state.add_recipe("butter_cookie")
	state.device_growth["oven"] = {
		"level": 3,
		"use_count": 30,
		"research_count": 30,
		"production_batch_count": 0
	}
	state.recipe_growth["butter_cookie"] = {
		"mastery_level": RecipeGrowthService.MASTERY_POPULAR,
		"stage_made_batches": 0,
		"stage_effective_rounds": 0,
		"stage_synergy_rounds": 0,
		"made_count": 15,
		"sold_count": 9,
		"adjacency_trigger_count": 0,
		"selected_traits": []
	}
	state.record_recipe_sold("butter_cookie", 1, false)
	var growth: Dictionary = state.get_recipe_growth("butter_cookie")
	if not bool(growth.get("pending_trait_choice", false)) or (growth.get("available_traits", []) as Array).size() < 2:
		_fail("popular recipe should expose a pending choice with candidates")

	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.set("state", state)
	main.call("_maybe_show_pending_recipe_growth_choice")
	await process_frame
	await process_frame
	var dialog: ConfirmationDialog = main.get_node_or_null("RecipeGrowthChoiceDialog")
	if dialog == null:
		_fail("main scene should declare a real growth choice dialog")
		main.queue_free()
		_finish()
		return
	var candidate_list: ItemList = dialog.get_node_or_null("ChoiceBody/ChoiceContent/CandidateList")
	var impact_label: RichTextLabel = dialog.get_node_or_null("ChoiceBody/ChoiceContent/ImpactLabel")
	if candidate_list == null or impact_label == null:
		_fail("growth dialog should declare candidates and a comparison area")
	else:
		_assert_equal(candidate_list.item_count, 2, "popular growth choice should show two candidates")
		for expected in ["30 秒", "预计成交", "预计金币", "占格", "角色", "热度"]:
			if impact_label.text.find(expected) == -1:
				_fail("growth candidate preview should explain: %s" % expected)
		candidate_list.select(0)
		dialog.call("_on_candidate_selected", 0)
		dialog.call("_on_confirmed")
		await process_frame
		var selected: Array = state.get_recipe_growth("butter_cookie").get("selected_traits", [])
		_assert_equal(selected.size(), 1, "confirming should select exactly one growth trait")
		main.call("_maybe_show_pending_recipe_growth_choice")
		await process_frame
		_assert_equal((state.get_recipe_growth("butter_cookie").get("selected_traits", []) as Array).size(), 1, "re-checking should not select the same trait twice")

	main.queue_free()
	_finish()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s; expected=%s actual=%s" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RECIPE_GROWTH_CHOICE_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("RECIPE_GROWTH_CHOICE_SCENE_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
