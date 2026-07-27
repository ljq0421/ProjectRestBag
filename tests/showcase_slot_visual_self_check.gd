extends SceneTree

const SLOT_SCENE_PATH := "res://scenes/ui/storefront/showcase_slot.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("SHOWCASE_SLOT_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _run() -> void:
	var packed := load(SLOT_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("showcase slot scene should load")
		return
	var slot := packed.instantiate() as Button
	root.add_child(slot)
	var icon := slot.get_node_or_null("RecipeIcon") as TextureRect
	var tint := slot.get_node_or_null("PreviewTint") as Control
	var outline := slot.get_node_or_null("GroupOutline") as Panel
	var badge := slot.get_node_or_null("StatusBadge") as Label
	_expect(slot.custom_minimum_size == Vector2(72, 72), "slot should be 72x72")
	_expect(icon != null, "slot should contain RecipeIcon")
	_expect(tint != null, "slot should contain PreviewTint")
	_expect(outline != null, "slot should contain GroupOutline")
	_expect(badge != null, "slot should contain StatusBadge")
	if icon == null or tint == null or outline == null or badge == null:
		slot.free()
		return
	_expect(icon.anchors_preset == Control.PRESET_FULL_RECT, "fragment should follow the 72x72 runtime slot size")
	_expect(icon.offset_left == 0.0 and icon.offset_top == 0.0 and icon.offset_right == 0.0 and icon.offset_bottom == 0.0, "fragment should have no inset")
	_expect(icon.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "80x80 source fragment should scale inside the 72x72 slot")
	_expect(icon.stretch_mode == TextureRect.STRETCH_SCALE, "fragment should fill expanded showcase cells")
	_expect(icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "icon should not intercept drag")
	_expect(tint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "preview tint should not intercept drag")
	_expect(outline.mouse_filter == Control.MOUSE_FILTER_IGNORE, "group outline should not intercept drag")
	_expect(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "badge should not intercept drag")
	_expect(slot.has_method("configure_drag"), "slot should preserve inherited drag behavior")
	_expect(not slot.has_method("configure_product_drag_preview"), "showcase slot should not couple status text to the engine drag preview")

	slot.call("set_status_badge", "12s")
	_expect(badge.visible and badge.text == "12s", "non-empty badge should be visible")
	var image := Image.create(80, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var drag_preview := slot.call("_make_drag_preview") as Control
	_expect(drag_preview != null, "showcase drag should create a transparent engine preview")
	if drag_preview != null:
		root.add_child(drag_preview)
		_expect(drag_preview.get_node_or_null("RecipeIcon") == null, "showcase drag preview should not contain a recipe icon")
		_expect(drag_preview.get_node_or_null("FallbackLabel") == null, "showcase drag preview should not contain fallback text")
		_expect(drag_preview.get_node_or_null("UnlistLabel") == null, "showcase drag preview should not contain status text")
		_expect(drag_preview.theme_type_variation.is_empty(), "transparent drag state should not draw a preview panel")
		drag_preview.free()
	slot.call("set_icon_fragment", texture, true)
	_expect(icon.texture == texture, "slot should display the supplied fragment")
	_expect(is_equal_approx(icon.modulate.a, 0.55), "preview fragment should be translucent")
	slot.call("set_preview_state", true, true)
	_expect(tint.visible, "active preview should show tint")
	slot.call("set_outline_edges", true, false, true, false, Color.ORANGE, false)
	_expect(not slot.has_theme_stylebox_override("normal"), "outline should preserve the slot Button skin")
	_expect(outline.visible and outline.has_theme_stylebox_override("panel"), "outline should render on the overlay panel")

	slot.call("clear_product_visual")
	_expect(icon.texture == null, "clear should remove fragment")
	_expect(not badge.visible, "clear should hide badge")
	_expect(not tint.visible, "clear should hide preview tint")
	_expect(not outline.visible, "clear should hide group outline")
	slot.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
