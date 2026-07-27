extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const GAME_STATE := preload("res://scripts/game_state.gd")
const TUTORIAL_PROGRESS := preload("res://scripts/tutorial_progress.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	main.set("save_path", OS.get_temp_dir().path_join("tutorial_guide_route_self_check.json"))
	root.add_child(main)
	await process_frame
	await process_frame
	var state = GAME_STATE.new_game()
	main.set("state", state)
	main.set("tutorial_last_auto_routed_step", "")
	main.call("_close_global_popup")
	main.call("_refresh_tutorial_guide")
	await process_frame
	await process_frame
	_expect_equal("purchase dialogue preserves current background", String(main.get("global_popup_mode")), "")
	main.call("_on_tutorial_dialogue_acknowledged")
	await process_frame
	_expect_equal("purchase action opens purchase", String(main.get("global_popup_mode")), "purchase")
	_expect_equal("purchase action does not advance step", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_PURCHASE)

	TUTORIAL_PROGRESS.on_purchase_completed(state, {"rice_seed": 1})
	main.call("_refresh_tutorial_guide")
	await process_frame
	await process_frame
	_expect_equal("real purchase advances to output", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_OUTPUT)
	_expect_equal("output dialogue preserves purchase background", String(main.get("global_popup_mode")), "purchase")
	main.call("_on_tutorial_dialogue_acknowledged")
	await process_frame
	_expect_equal("output action opens output", String(main.get("global_popup_mode")), "output")
	_expect_equal("output action does not advance step", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_OUTPUT)

	main.call("_on_tutorial_skip_requested")
	await process_frame
	_expect_equal("I will do it myself keeps output step", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_OUTPUT)
	var overlay := main.get_node("TutorialGuideOverlay") as Control
	_expect(not overlay.visible, "dismissed guidance should hide overlay")

	main.call("_show_page", "purchase")
	await process_frame
	_expect_equal("manual navigation keeps guide progress", state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_OUTPUT)
	main.call("_refresh_tutorial_guide")
	await process_frame
	_expect_equal("same step does not force route again", String(main.get("global_popup_mode")), "purchase")

	var settled_state = GAME_STATE.new_game()
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage"]:
		settled_state.unlock_core_feature(feature_id)
	settled_state.tutorial_guide_step = TUTORIAL_PROGRESS.STEP_STOREFRONT
	settled_state.record_core_unlock_progress("first_sale_settlement_completed", true)
	main.set("state", settled_state)
	main.call("_refresh_current_page")
	main.call("_on_storefront_manage_pressed")
	await process_frame
	_expect_equal("settlement-first storefront click reaches final dialogue", settled_state.tutorial_guide_step, TUTORIAL_PROGRESS.STEP_COMPLETE)
	_expect_equal("settlement-first click opens storefront management", String(main.get("global_popup_mode")), "storefront_manage")

	main.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	_expect(actual == expected, "%s expected %s, got %s" % [label, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("TUTORIAL_GUIDE_ROUTE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("TUTORIAL_GUIDE_ROUTE_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
