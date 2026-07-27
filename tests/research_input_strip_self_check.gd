extends SceneTree

const Catalog := preload("res://scripts/catalog.gd")
const GameState := preload("res://scripts/game_state.gd")
const MainScene := preload("res://scenes/Main.tscn")
const TEST_SAVE_PATH := "res://tests/research_input_strip_self_check.save.json"
const INPUT_BAR_PATH := "GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ResearchInputBar"
const DEVICE_IDS := ["round_pot", "grinder", "oven", "chiller", "griddle", "mixer"]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_recipe_contract()
	_test_device_icon_contract()
	await _test_input_strip_ui()
	_cleanup_test_save()
	_finish()


func _test_recipe_contract() -> void:
	var recipes := Catalog.new().get_recipes()
	_expect(_materials(recipes, "vanilla_cream_puff") == ["flour", "butter", "egg", "cream", "vanilla", "sugar"], "vanilla cream puff should use the approved six materials")
	_expect(_materials(recipes, "black_tea_nut_brownie") == ["chocolate", "egg", "butter", "nuts", "black_tea", "flour"], "black tea nut brownie should use the approved six materials")
	_expect(_materials(recipes, "blueberry_muffin") == ["flour", "butter", "egg", "milk", "blueberry", "sugar"], "blueberry muffin should remain unchanged")
	_expect(_materials(recipes, "matcha_redbean_mousse") == ["matcha", "red_bean", "cream", "gelatin", "milk", "sugar"], "matcha red bean mousse should remain unchanged")
	_expect(_materials(recipes, "nuts_cocoa_brownie") == ["cocoa", "chocolate", "butter", "nuts", "egg", "flour"], "nuts cocoa brownie should remain unchanged")
	for recipe_id_value in recipes:
		var recipe: Dictionary = recipes[recipe_id_value]
		_expect(Array(recipe.get("materials", [])).size() <= 6, "recipe %s should not exceed six materials" % String(recipe_id_value))


func _test_device_icon_contract() -> void:
	for device_id in DEVICE_IDS:
		var path := "res://resources/ui/device_v1/%s.png" % device_id
		_expect(FileAccess.file_exists(ProjectSettings.globalize_path(path)), "device v1 icon should exist for %s" % device_id)


func _test_input_strip_ui() -> void:
	var view = MainScene.instantiate()
	view.set("save_path", TEST_SAVE_PATH)
	root.add_child(view)
	await process_frame
	for device_id in DEVICE_IDS:
		var expected_path := "res://resources/ui/device_v1/%s.png" % device_id
		var device_texture := view.call("_device_icon_texture", device_id) as Texture2D
		_expect(device_texture != null, "runtime device icon should load for %s" % device_id)
		if device_texture != null:
			_expect(device_texture.resource_path == expected_path, "runtime device icon for %s should load from device_v1, got %s" % [device_id, device_texture.resource_path])

	var state = GameState.new_game()
	state.level = 5
	state.shop_level = 5
	for device_id in DEVICE_IDS:
		state.unlock_device(device_id)
	for item_id in ["flour", "butter", "egg", "milk", "cream", "vanilla", "sugar"]:
		state.add_ingredient(item_id, 3)
	view.set("state", state)
	view.set("selected_research_tool_id", "oven")
	var initial_materials: Array[String] = ["flour", "egg"]
	view.set("selected_research_material_ids", initial_materials)
	_expect(Array(view.get("selected_research_material_ids")).size() == 2, "fixture should assign two selected materials before opening research")
	_expect(state.get_ingredient_count("flour") == 3, "fixture should stock flour before opening research")
	view.call("_show_page", "research")
	await process_frame
	_expect(Array(view.get("selected_research_material_ids")).size() == 2, "opening research should preserve selected materials")

	var input_bar := view.get_node_or_null(INPUT_BAR_PATH) as HBoxContainer
	_expect(input_bar != null, "research page should declare ResearchInputBar")
	if input_bar == null:
		view.queue_free()
		await process_frame
		return

	var tool_slot := input_bar.get_node_or_null("ToolSlot") as Button
	var material_grid := input_bar.get_node_or_null("InventoryGrid") as GridContainer
	_expect(input_bar.get_theme_constant("separation") == 16, "tool and material regions should have a 16px gap")
	_expect(tool_slot != null, "ResearchInputBar should declare one ToolSlot")
	_expect(material_grid != null, "ResearchInputBar should declare InventoryGrid")
	if tool_slot == null or material_grid == null:
		view.queue_free()
		await process_frame
		return

	_expect(tool_slot.custom_minimum_size == Vector2(104, 104), "tool slot should be a 104x104 square")
	_expect(material_grid.columns == 6, "material grid should use six columns")
	_expect(material_grid.get_theme_constant("h_separation") == 8, "material slots should have 8px gaps")
	_expect(material_grid.get_child_count() == 6, "research input strip should expose six material slots")
	for child_value in material_grid.get_children():
		var slot := child_value as Button
		_expect(slot != null and slot.custom_minimum_size == Vector2(88, 88), "every material slot should be an 88x88 square")

	var tool_icon := tool_slot.get_node_or_null("Icon") as TextureRect
	var tool_name_backdrop := tool_slot.get_node_or_null("NameBackdrop") as ColorRect
	var tool_name := tool_slot.get_node_or_null("NameLabel") as Label
	_expect(tool_icon != null and tool_icon.texture != null, "selected tool should show its device image")
	_expect(tool_icon != null and _fills_parent(tool_icon), "selected tool image should fill the 104x104 slot")
	_expect(tool_icon != null and tool_icon.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "selected tool image should scale with the slot")
	_expect(tool_icon != null and tool_icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "selected tool image should preserve aspect ratio without cropping")
	_expect(tool_name_backdrop != null and tool_name_backdrop.visible and tool_name_backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "main tool slot should show a non-blocking bottom name backdrop")
	_expect(tool_name != null and tool_name.visible and tool_name.text == "烤箱" and tool_name.mouse_filter == Control.MOUSE_FILTER_IGNORE, "main tool slot should overlay a non-blocking name below the full-size icon")

	var first_slot := material_grid.get_child(0) as Button
	var third_slot := material_grid.get_child(2) as Button
	var first_material_icon := first_slot.get_node_or_null("Icon") as TextureRect
	var first_material_backdrop := first_slot.get_node_or_null("NameBackdrop") as ColorRect
	var first_material_name := first_slot.get_node_or_null("NameLabel") as Label
	_expect(first_material_icon != null and first_material_icon.texture != null, "selected material should show its icon")
	_expect(first_material_icon != null and _fills_parent(first_material_icon), "selected material image should fill the 88x88 slot")
	_expect(first_material_icon != null and first_material_icon.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "selected material image should scale with the slot")
	_expect(first_material_icon != null and first_material_icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "selected material image should preserve aspect ratio without cropping")
	_expect(first_material_backdrop != null and first_material_backdrop.visible and first_material_backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "main material slot should show a non-blocking bottom name backdrop")
	_expect(first_material_name != null and first_material_name.visible and first_material_name.text == "面粉" and first_material_name.mouse_filter == Control.MOUSE_FILTER_IGNORE, "main material slot should overlay a non-blocking name below the full-size icon")
	_expect(first_slot.tooltip_text.find("面粉") != -1, "icon-only material slot should keep its name in the tooltip")
	var empty_icon := third_slot.get_node_or_null("Icon") as TextureRect
	var empty_backdrop := third_slot.get_node_or_null("NameBackdrop") as ColorRect
	var empty_name := third_slot.get_node_or_null("NameLabel") as Label
	var empty_plus := third_slot.get_node_or_null("PlusLabel") as Label
	_expect(empty_plus != null and empty_plus.visible and empty_icon != null and not empty_icon.visible and empty_backdrop != null and not empty_backdrop.visible and empty_name != null and not empty_name.visible, "empty material slot should show only a plus")

	tool_slot.pressed.emit()
	await process_frame
	var picker := input_bar.get_node_or_null("ResearchToolPickerPopup") as PopupPanel
	_expect(picker != null and picker.visible, "pressing ToolSlot should open the enlarged tool picker")
	if picker != null:
		_expect(picker.size == Vector2i(720, 504), "tool picker should open at 720x504, got %s" % str(picker.size))
		var expected_picker_position := (Vector2i(view.get_viewport().get_visible_rect().size) - picker.size) / 2
		_expect(picker.position == expected_picker_position, "tool picker should remain centered after enforcing its exact size")
		var picker_style := picker.get_theme_stylebox("panel") as StyleBoxTexture
		_expect(picker_style != null, "tool picker should use a StyleBoxTexture panel")
		if picker_style != null:
			_expect(picker_style.texture != null and picker_style.texture.resource_path == "res://resources/ui/skin/neighborhood_dessert/runtime/panel_v1.png", "tool picker should use the runtime panel_v1 texture")
			_expect(picker_style.texture_margin_left == 52.0 and picker_style.texture_margin_top == 52.0 and picker_style.texture_margin_right == 52.0 and picker_style.texture_margin_bottom == 52.0, "tool picker panel should preserve 52px texture margins")
		var picker_margin := picker.get_node_or_null("ToolPickerMargin") as MarginContainer
		var picker_title := picker.get_node_or_null("ToolPickerMargin/ToolPickerBox/ToolPickerTitle") as Label
		var picker_box := picker.get_node_or_null("ToolPickerMargin/ToolPickerBox") as VBoxContainer
		var picker_grid := picker.get_node_or_null("ToolPickerMargin/ToolPickerBox/ToolPickerGrid") as GridContainer
		_expect(picker_margin != null, "tool picker should keep its scene-declared content margin")
		if picker_margin != null:
			_expect(picker_margin.get_theme_constant("margin_left") == 64 and picker_margin.get_theme_constant("margin_right") == 64, "tool picker should keep 64px horizontal content margins")
			_expect(picker_margin.get_theme_constant("margin_top") == 48 and picker_margin.get_theme_constant("margin_bottom") == 48, "tool picker should keep 48px vertical content margins")
		_expect(picker_title != null and picker_title.get_theme_font_size("font_size") == 24, "tool picker title should use a 24px font")
		_expect(picker_box != null and picker_box.get_theme_constant("separation") == 16, "tool picker title and grid should keep a 16px gap")
		_expect(picker_grid != null and picker_grid.columns == 3, "tool picker should keep a three-column grid")
		if picker_grid != null:
			_expect(picker_grid.get_theme_constant("h_separation") == 16 and picker_grid.get_theme_constant("v_separation") == 16, "tool picker cards should keep 16px gaps")
			_expect(picker_grid.get_child_count() == 6, "six unlocked devices should produce six tool cards")
			for child_value in picker_grid.get_children():
				var tool_button := child_value as Button
				_expect(tool_button != null and tool_button.custom_minimum_size == Vector2(168, 168) and tool_button.size == Vector2(168, 168), "every tool picker card should render at 168x168")
				if tool_button == null:
					continue
				var picker_tool_icon := tool_button.get_node_or_null("Icon") as TextureRect
				var picker_tool_backdrop := tool_button.get_node_or_null("NameBackdrop") as ColorRect
				var picker_tool_name := tool_button.get_node_or_null("NameLabel") as Label
				_expect(picker_tool_icon != null and _fills_parent(picker_tool_icon), "every picker device image should fill its 168x168 card")
				_expect(picker_tool_icon != null and picker_tool_icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "picker device images should preserve aspect ratio without cropping")
				_expect(picker_tool_backdrop != null and not picker_tool_backdrop.visible, "picker cards should hide their bottom name backdrop")
				_expect(picker_tool_name != null and not picker_tool_name.visible, "picker cards should hide their visible device name")
				if picker_tool_name != null:
					_expect(tool_button.tooltip_text == picker_tool_name.text, "picker card Tooltip should equal its device name")
		var mixer_button := _find_button_by_meta(picker, "tool_id", "mixer")
		_expect(mixer_button != null, "tool picker should list unlocked devices")
		if mixer_button != null:
			var mixer_name := mixer_button.get_node_or_null("NameLabel") as Label
			_expect(mixer_name != null and not mixer_name.visible and mixer_name.text == "搅拌机", "tool picker should hide the visible mixer name while retaining its exact text for the Tooltip")
			mixer_button.pressed.emit()
			await process_frame
			_expect(String(view.get("selected_research_tool_id")) == "mixer", "choosing a tool should replace the current tool")
			_expect(not picker.visible, "choosing a tool should close the picker")
			_expect(Array(view.get("selected_research_material_ids")) == initial_materials, "choosing a tool should preserve selected research materials")
			view.call("_show_page", "purchase")
			view.call("_show_page", "research")
			await process_frame
			_expect(String(view.get("selected_research_tool_id")) == "mixer", "leaving and returning to research should retain the selected tool")
			_expect((tool_slot.get_node("NameLabel") as Label).visible and (tool_slot.get_node("NameLabel") as Label).text == "搅拌机", "retained main tool slot should keep its bottom name after returning")
			_expect(tool_slot.tooltip_text.find("搅拌机") != -1, "retained tool name should remain available in the tooltip")

	var empty_materials: Array[String] = []
	view.set("selected_research_material_ids", empty_materials)
	for item_id in ["flour", "butter", "egg", "milk", "cream", "vanilla", "sugar"]:
		view.call("_on_research_material_cell_pressed", item_id)
	var selected: Array = view.call("_selected_research_material_ids")
	_expect(selected.size() == 6, "research material selection should reject a seventh item")
	var status_label := view.get_node("Root/StatusBar/StatusLabel") as Label
	_expect(status_label.text.find("最多选择 6 种食材") != -1, "rejecting a seventh material should explain the six-item limit")

	view.queue_free()
	await process_frame


func _find_button_by_meta(node: Node, key: String, value: String) -> Button:
	if node is Button and String(node.get_meta(key, "")) == value:
		return node as Button
	for child in node.get_children():
		var found := _find_button_by_meta(child, key, value)
		if found != null:
			return found
	return null


func _fills_parent(control: Control) -> bool:
	return is_equal_approx(control.anchor_left, 0.0) \
		and is_equal_approx(control.anchor_top, 0.0) \
		and is_equal_approx(control.anchor_right, 1.0) \
		and is_equal_approx(control.anchor_bottom, 1.0) \
		and control.offset_left == 0.0 \
		and control.offset_top == 0.0 \
		and control.offset_right == 0.0 \
		and control.offset_bottom == 0.0


func _materials(recipes: Dictionary, recipe_id: String) -> Array:
	return Array((recipes.get(recipe_id, {}) as Dictionary).get("materials", []))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _cleanup_test_save() -> void:
	for path in [TEST_SAVE_PATH, "%s.tmp" % TEST_SAVE_PATH]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)


func _finish() -> void:
	if failures.is_empty():
		print("RESEARCH_INPUT_STRIP_SELF_CHECK: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
