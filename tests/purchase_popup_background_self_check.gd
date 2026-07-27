extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const DEFAULT_BACKGROUND_PATH := "res://resources/ui/skin/neighborhood_dessert/runtime/panel_v1.png"
const UNIFIED_POPUP_SIZE := Vector2(1176.883, 800.0)
const PURCHASE_CONTENT_MARGINS := Vector4(32, 8, 32, 24)
const TOLERANCE := 1.0

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("purchase_popup_background_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = VIEWPORT_SIZE
	var view := MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var popup := view.get_node("GlobalOverlayLayer") as Control
	var default_surface := view.get_node("GlobalOverlayLayer/DefaultModalSurface") as PanelContainer
	var frame := view.get_node("GlobalOverlayLayer/OverlayFrame") as Control
	var header := view.get_node("GlobalOverlayLayer/OverlayFrame/OverlayHeader") as Control
	var mode_stack := view.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack") as MarginContainer
	var purchase_page := view.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay") as Control
	_expect(view.get_node_or_null("GlobalOverlayLayer/PurchasePopupBackground") == null, "purchase background node should be removed")
	_expect(view.get_node_or_null("GlobalOverlayLayer/CatalogPopupBackground") == null, "catalog background node should be removed")
	_check_default_surface(default_surface)

	view.call("_show_purchase_global_popup")
	await process_frame
	_expect(default_surface.visible, "purchase mode should use the default modal surface")
	_expect_near("purchase popup size", popup.size, UNIFIED_POPUP_SIZE)
	_expect(is_equal_approx(popup.size.x / popup.size.y, 840.0 / 571.0), "purchase popup should use the catalog baseline ratio")
	_expect_near("default surface fills purchase popup", default_surface.size, popup.size)
	_expect(default_surface.position.distance_to(Vector2.ZERO) <= TOLERANCE, "default surface should start at the popup origin")
	_expect(popup.get_global_rect().encloses(header.get_global_rect()), "default surface should extend behind the complete title bar")
	_expect(popup.get_global_rect().encloses(purchase_page.get_global_rect()), "purchase page should stay inside the default modal surface")
	_expect(mode_stack.get_theme_constant("margin_left") == roundi(PURCHASE_CONTENT_MARGINS.x), "purchase should preserve its left content margin")
	_expect(mode_stack.get_theme_constant("margin_top") == roundi(PURCHASE_CONTENT_MARGINS.y), "purchase should preserve its top content margin")
	_expect(mode_stack.get_theme_constant("margin_right") == roundi(PURCHASE_CONTENT_MARGINS.z), "purchase should preserve its right content margin")
	_expect(mode_stack.get_theme_constant("margin_bottom") == roundi(PURCHASE_CONTENT_MARGINS.w), "purchase should preserve its bottom content margin")
	var regions_grid := view.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PurchaseRegionsGrid") as GridContainer
	_expect(regions_grid.get_child_count() == 6, "purchase page should preserve all six source regions")

	view.call("_show_inventory_global_popup")
	await process_frame
	_expect(default_surface.visible, "inventory mode should keep the same default modal surface")
	_expect_near("inventory keeps unified popup size", popup.size, UNIFIED_POPUP_SIZE)
	for margin_name in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_expect(mode_stack.get_theme_constant(margin_name) == 0, "leaving purchase should reset %s" % margin_name)
	var inventory_page := view.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay") as Control
	_expect_near("non-purchase content restores zero margins", inventory_page.size, mode_stack.size)

	view.call("_close_global_popup")
	await process_frame
	_expect(default_surface.visible, "closing the popup should preserve the default surface for the next mode")
	_expect(frame != null, "shared overlay frame should remain present")

	view.queue_free()
	_cleanup_save()
	_finish()


func _check_default_surface(surface: PanelContainer) -> void:
	var style := surface.get_theme_stylebox("panel") as StyleBoxTexture
	_expect(style != null, "default modal surface should use a textured panel style")
	if style == null:
		return
	_expect(style.texture != null and style.texture.resource_path == DEFAULT_BACKGROUND_PATH, "default modal surface should use panel_v1")


func _expect_near(label: String, actual: Vector2, expected: Vector2) -> void:
	if actual.distance_to(expected) > TOLERANCE:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _cleanup_save() -> void:
	for path in [_save_path, _save_path + ".broken"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PURCHASE_POPUP_BACKGROUND_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("PURCHASE_POPUP_BACKGROUND_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
