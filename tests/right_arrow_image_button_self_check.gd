extends SceneTree

const BUTTON_SCENES := {
	"right": "res://scenes/ui/common/right_arrow_image_button.tscn",
	"left": "res://scenes/ui/common/left_arrow_image_button.tscn"
}
const INVENTORY_SCENE := "res://scenes/ui/overlays/inventory_overlay.tscn"
const CATALOG_SCENE := "res://scenes/ui/overlays/catalog_overlay.tscn"
const OUTPUT_SITE_SCENE := "res://scenes/ui/pages/output_site_region.tscn"
const COMPONENT_SCRIPT := "res://scripts/ui/common/right_arrow_image_button.gd"
const TEXTURE_PATHS := {
	"right": {
		"normal": "res://resources/ui/skin_v1/arrow_right_normal.png",
		"hover": "res://resources/ui/skin_v1/arrow_right_hover.png",
		"pressed": "res://resources/ui/skin_v1/arrow_right_pressed.png",
		"selected": "res://resources/ui/skin_v1/arrow_right_selected.png"
	},
	"left": {
		"normal": "res://resources/ui/skin_v1/arrow_left_normal.png",
		"hover": "res://resources/ui/skin_v1/arrow_left_hover.png",
		"pressed": "res://resources/ui/skin_v1/arrow_left_pressed.png",
		"selected": "res://resources/ui/skin_v1/arrow_left_selected.png"
	}
}

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(640, 360)
	_check_texture_files()
	_check_horizontal_mirrors()
	await _check_real_input_states("right")
	await _check_real_input_states("left")
	await _check_disabled_state()
	_check_scene_contracts()
	_finish()


func _check_texture_files() -> void:
	for direction: String in TEXTURE_PATHS:
		var paths: Dictionary = TEXTURE_PATHS[direction]
		for state: String in paths:
			var path: String = paths[state]
			var texture := load(path) as Texture2D
			if texture == null:
				_fail("%s %s texture should load: %s" % [direction, state, path])
				continue
			_expect_equal(texture.get_size(), Vector2(112, 116), "%s %s texture keeps the approved canvas" % [direction, state])
			var image := texture.get_image()
			if image == null:
				_fail("%s %s texture should expose image data" % [direction, state])
			else:
				_expect_close(image.get_pixel(0, 0).a, 0.0, 0.001, "%s %s texture keeps a transparent corner" % [direction, state])


func _check_horizontal_mirrors() -> void:
	for state: String in TEXTURE_PATHS["right"]:
		var right := (load(TEXTURE_PATHS["right"][state]) as Texture2D).get_image()
		var left := (load(TEXTURE_PATHS["left"][state]) as Texture2D).get_image()
		if right == null or left == null:
			_fail("%s mirror images should load" % state)
			continue
		var expected_left := right.duplicate()
		expected_left.flip_x()
		_expect_equal(left.get_data(), expected_left.get_data(), "%s left texture is the exact horizontal mirror" % state)


func _check_real_input_states(direction: String) -> void:
	var button := _instantiate_button(direction)
	if button == null:
		return
	button.position = Vector2(120, 90)
	button.size = Vector2(48, 48)
	await process_frame

	_expect_texture(button, direction, "normal")
	_parse_mouse_motion(button.get_global_rect().get_center())
	await process_frame
	_expect_texture(button, direction, "hover")

	_parse_mouse_button(button.get_global_rect().get_center(), true)
	await process_frame
	_expect_texture(button, direction, "pressed")

	_parse_mouse_button(button.get_global_rect().get_center(), false)
	await process_frame
	_expect_texture(button, direction, "selected")

	_parse_mouse_motion(Vector2(8, 8))
	button.release_focus()
	await process_frame
	_expect_texture(button, direction, "normal")
	_expect_equal(button.text, "", "%s arrow button should not render text" % direction)
	_expect_equal(button.tooltip_text, "上一页" if direction == "left" else "下一页", "%s arrow keeps its accessible tooltip" % direction)
	button.queue_free()
	await process_frame


func _check_disabled_state() -> void:
	var button := _instantiate_button("right")
	if button == null:
		return
	button.position = Vector2(120, 90)
	button.size = Vector2(48, 48)
	button.disabled = true
	await process_frame
	_expect_texture(button, "right", "normal")
	_expect_close(button.self_modulate.a, 0.58, 0.001, "disabled button uses the approved opacity")
	button.pressed.connect(func() -> void: _fail("disabled pagination arrow should not emit pressed"))
	_parse_mouse_button(button.get_global_rect().get_center(), true)
	_parse_mouse_button(button.get_global_rect().get_center(), false)
	await process_frame
	button.queue_free()
	await process_frame


func _instantiate_button(direction: String) -> Button:
	var packed := load(BUTTON_SCENES[direction]) as PackedScene
	if packed == null:
		_fail("%s arrow image button scene should load" % direction)
		return null
	var button := packed.instantiate() as Button
	if button == null:
		_fail("%s arrow image button root should remain a Button" % direction)
		return null
	root.add_child(button)
	return button


func _check_scene_contracts() -> void:
	var inventory := (load(INVENTORY_SCENE) as PackedScene).instantiate()
	_check_scene_button(
		inventory.get_node_or_null("InventoryBody/InventoryMainPanel/InventoryPager/InventoryPrevButton") as Button,
		Vector2(48, 48), "left", "inventory previous"
	)
	_check_scene_button(
		inventory.get_node_or_null("InventoryBody/InventoryMainPanel/InventoryPager/InventoryNextButton") as Button,
		Vector2(48, 48), "right", "inventory next"
	)
	inventory.free()

	var catalog := (load(CATALOG_SCENE) as PackedScene).instantiate()
	_check_scene_button(
		catalog.get_node_or_null("CatalogContent/CatalogGridPanel/CatalogPager/CatalogPrevButton") as Button,
		Vector2(48, 48), "left", "catalog previous"
	)
	_check_scene_button(
		catalog.get_node_or_null("CatalogContent/CatalogGridPanel/CatalogPager/CatalogNextButton") as Button,
		Vector2(48, 48), "right", "catalog next"
	)
	catalog.free()

	var output_site := (load(OUTPUT_SITE_SCENE) as PackedScene).instantiate()
	_check_scene_button(
		output_site.get_node_or_null("OutputSiteBox/OutputSiteBody/PlotColumn/OutputSitePager/OutputPrevPageButton") as Button,
		Vector2(36, 36), "left", "output site previous"
	)
	_check_scene_button(
		output_site.get_node_or_null("OutputSiteBox/OutputSiteBody/PlotColumn/OutputSitePager/OutputNextPageButton") as Button,
		Vector2(36, 36), "right", "output site next"
	)
	var pager := output_site.get_node_or_null("OutputSiteBox/OutputSiteBody/PlotColumn/OutputSitePager") as Control
	if pager == null:
		_fail("output site pager should remain available")
	else:
		_expect_equal(pager.custom_minimum_size.y, 36.0, "output site pager keeps its approved compact height")
	output_site.free()


func _check_scene_button(button: Button, expected_size: Vector2, direction: String, label: String) -> void:
	if button == null:
		_fail("%s button should remain at its existing node path" % label)
		return
	var script := button.get_script() as Script
	if script == null:
		_fail("%s button should use the four-state component script" % label)
	else:
		_expect_equal(script.resource_path, COMPONENT_SCRIPT, "%s uses the pagination-arrow component" % label)
	_expect_equal(button.custom_minimum_size, expected_size, "%s keeps the approved hit area" % label)
	_expect_equal(button.text, "", "%s removes the old text glyph" % label)
	_expect_equal(bool(button.get("points_left")), direction == "left", "%s keeps the approved direction" % label)


func _parse_mouse_motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	root.push_input(event, true)


func _parse_mouse_button(position: Vector2, is_pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = is_pressed
	root.push_input(event, true)


func _expect_texture(button: Button, direction: String, state: String) -> void:
	if button.icon == null:
		_fail("%s %s state should provide an icon" % [direction, state])
		return
	_expect_equal(button.icon.resource_path, TEXTURE_PATHS[direction][state], "%s %s state uses the approved texture" % [direction, state])


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s; expected=%s actual=%s" % [message, expected, actual])


func _expect_close(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		_fail("%s; expected=%.3f actual=%.3f" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RIGHT_ARROW_IMAGE_BUTTON_SELF_CHECK_PASS")
		quit(0)
		return
	for failure: String in _failures:
		printerr("RIGHT_ARROW_IMAGE_BUTTON_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
