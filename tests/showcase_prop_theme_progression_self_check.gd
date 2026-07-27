extends SceneTree

const GAME_STATE := preload("res://scripts/game_state.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var state = GAME_STATE.new_game()
	state.level = 2
	state.sync_showcase_collection_unlocks()
	_assert_equal(state.get_unlocked_showcase_prop_ids(), ["cake_stand"], "level two should permanently unlock the basic cake stand")
	_assert_equal(state.get_unlocked_showcase_theme_ids(), ["summer"], "level two should permanently unlock the summer theme")
	if state.place_display_prop("chilled_case", [Vector2i(5, 6), Vector2i(5, 7)]):
		_fail("locked props should not be placeable")
	if state.set_showcase_theme("retro"):
		_fail("locked themes should not be selectable")
	if not state.set_showcase_theme("summer"):
		_fail("an unlocked theme should be selectable during adjustment")

	state.level = 5
	state.sync_showcase_collection_unlocks()
	_assert_equal(state.get_unlocked_showcase_prop_ids(), ["cake_stand", "chilled_case", "retro_tray", "sample_sign", "gift_corner"], "level five should own all first-wave props")
	_assert_equal(state.get_unlocked_showcase_theme_ids(), ["summer", "retro", "tea"], "level five should own all first-wave themes")
	var restored = GAME_STATE.from_dict(state.to_dict())
	_assert_equal(restored.get_unlocked_showcase_prop_ids(), state.get_unlocked_showcase_prop_ids(), "prop collection should survive save/load")
	_assert_equal(restored.get_unlocked_showcase_theme_ids(), state.get_unlocked_showcase_theme_ids(), "theme collection should survive save/load")

	restored.active_business_round = {"phase": "running"}
	if restored.set_showcase_theme("tea"):
		_fail("theme selection should lock during business")
	if restored.place_display_prop("cake_stand", [Vector2i(5, 6)]):
		_fail("prop placement should lock during business")
	restored.active_business_round = {}

	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui_state = GAME_STATE.new_game()
	ui_state.level = 2
	ui_state.sync_showcase_collection_unlocks()
	ui_state.set_showcase_theme("summer")
	main.set("state", ui_state)
	main.call("_show_page", "storefront_manage")
	await process_frame
	var base := "GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/PropsThemePanel/PropsThemeContent/PropsThemeColumns"
	var theme_buttons: VBoxContainer = main.get_node_or_null(base + "/ThemeColumn/ThemeScroll/ThemeButtons")
	var prop_buttons: VBoxContainer = main.get_node_or_null(base + "/PropsColumn/PropScroll/PropButtons")
	if theme_buttons == null or prop_buttons == null:
		_fail("storefront management should declare the props and themes player entry")
	else:
		if theme_buttons.get_child_count() != 4:
			_fail("theme selector should show none plus three themes as a full list")
		var summer_button := theme_buttons.get_node_or_null("summer") as Button
		var retro_button := theme_buttons.get_node_or_null("retro") as Button
		if summer_button == null or not summer_button.button_pressed:
			_fail("selected theme should be visibly selected in the full list")
		if retro_button == null or not retro_button.disabled:
			_fail("locked themes should remain visible but disabled")
		for prop_id in ["cake_stand", "chilled_case", "retro_tray", "sample_sign", "gift_corner"]:
			var button: Button = prop_buttons.get_node_or_null(prop_id)
			if button == null:
				_fail("prop panel should declare button: %s" % prop_id)
			elif prop_id == "cake_stand" and button.disabled:
				_fail("owned cake stand should be draggable")
			elif prop_id != "cake_stand" and not button.disabled:
				_fail("unowned prop should remain visible but disabled: %s" % prop_id)
			elif button.text.find("｜") == -1:
				_fail("prop rows should visibly include effect and status: %s" % prop_id)

	var prop_drag := {"kind": "showcase_prop", "prop_id": "cake_stand", "target_slot_index": 61}
	if not bool(main.call("_can_drop_showcase_data", "showcase", prop_drag)):
		_fail("an owned prop should be droppable on an unlocked empty cell")
	elif not bool(main.call("_drop_showcase_data", "showcase", prop_drag)):
		_fail("dropping an owned prop should place it")
	elif not ui_state.display_props.has("cake_stand"):
		_fail("prop drop should update GameState")
	var prop_cell: Button = main.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid").get_child(61)
	if prop_cell.text.find("蛋糕架") == -1:
		_fail("placed prop should be visible on the showcase grid")

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
		print("SHOWCASE_PROP_THEME_PROGRESSION_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHOWCASE_PROP_THEME_PROGRESSION_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
