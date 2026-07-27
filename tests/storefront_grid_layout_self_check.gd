extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const GAME_STATE_PATH := "res://scripts/game_state.gd"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = VIEWPORT_SIZE
	var packed_scene := load(MAIN_SCENE_PATH)
	if packed_scene == null:
		_fail("Main scene is missing")
		_finish()
		return

	var main: Control = (packed_scene as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var initial_showcase_grid := main.get_node_or_null(
		"Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid"
	) as GridContainer
	if initial_showcase_grid == null:
		_fail("F5 startup should provide the showcase grid")
		_finish()
		return
	if initial_showcase_grid.get_child_count() != 168:
		_fail("F5 startup should render 168 showcase cells")
		_finish()
		return

	var game_state_script := load(GAME_STATE_PATH)
	var state = game_state_script.new_game()
	state.level = 2
	state.shop_level = 2
	state.add_recipe("sponge_cake")
	state.add_product("sponge_cake", 2)
	main.set("state", state)
	main.call("_show_page", "storefront_manage")
	await process_frame

	var main_area: HBoxContainer = main.get_node("Root/Body/MainArea")
	var storefront: Control = main.get_node("Root/Body/MainArea/StorefrontPanel")
	var workbench: Control = main.get_node("Root/Body/MainArea/WorkbenchPanel")
	var manage_button: Button = main.get_node("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/StorefrontManageButton")
	var showcase_grid: GridContainer = main.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid")
	var open_slots_value: Label = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/OpenSlotsMetric/OpenSlotsValue")
	var expansion_button: Button = main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/StrategyActionRow/StorefrontExpansionButton")
	var feedback_layer: Control = main.get_node_or_null("ShowcaseFeedbackLayer")
	if feedback_layer == null:
		_fail("main scene should provide root showcase feedback layer")
	elif feedback_layer.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("showcase feedback layer must not intercept drag input")
	var pulse_summary: Label = main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcasePulseSummary")
	if pulse_summary == null:
		_fail("showcase board should expose credited round summary")
	elif pulse_summary.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("showcase pulse summary must not intercept drag input")
	if main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") != showcase_grid:
		_fail("showcase board should preserve the direct ShowcaseGrid path")

	if main_area == null:
		_fail("MainArea should be an HBoxContainer")
	if storefront.size_flags_stretch_ratio != 63.0:
		_fail("StorefrontPanel stretch ratio should be 63")
	if workbench.size_flags_stretch_ratio != 37.0:
		_fail("WorkbenchPanel stretch ratio should be 37")
	if String(main.get("global_popup_mode")) != "storefront_manage":
		_fail("storefront manage launcher should open the storefront overlay")
	if state.display_slots.size() != 168:
		_fail("new game should reserve 168 showcase slots")
	if showcase_grid.columns != 14:
		_fail("showcase grid should use fourteen columns")
	if showcase_grid.get_child_count() != 168:
		_fail("showcase grid should render 168 cells")
	if open_slots_value.text.find("16/168") == -1:
		_fail("current build should report the initial sixteen unlocked slots")
	if expansion_button.text.find("进入扩建") == -1 or expansion_button.text.find("300") == -1:
		_fail("storefront expansion entry should expose the grid mode and next-cell price")

	var locked_drag := {
		"kind": "inventory_product",
		"recipe_id": "sponge_cake",
		"target_slot_index": 0
	}
	if bool(main.call("_can_drop_showcase_data", "showcase", locked_drag)):
		_fail("outer locked showcase cell should reject a new product")
	var locked_button: Button = showcase_grid.get_child(0)
	if not is_zero_approx(locked_button.modulate.a):
		_fail("locked showcase cell should be visually hidden outside expansion mode")
	if locked_button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("hidden locked showcase cell should not receive pointer input")
	if locked_button.focus_mode != Control.FOCUS_NONE:
		_fail("hidden locked showcase cell should not receive keyboard focus")

	var center_drag := {
		"kind": "inventory_product",
		"recipe_id": "sponge_cake",
		"target_slot_index": 76
	}
	if not bool(main.call("_can_drop_showcase_data", "showcase", center_drag)):
		_fail("center unlocked showcase cell should accept a product")
	for slot_index in [76, 77, 90, 91]:
		var preview_button: Button = showcase_grid.get_child(slot_index)
		if not bool(preview_button.get_meta("showcase_preview", false)):
			_fail("center 2x2 product should preview occupied slot %d" % slot_index)

	main.queue_free()
	_finish()


func _joined_list_text(list: ItemList) -> String:
	var parts: Array[String] = []
	for index in range(list.item_count):
		parts.append(list.get_item_text(index))
	return "\n".join(parts)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("STOREFRONT_GRID_LAYOUT_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("STOREFRONT_GRID_LAYOUT_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
