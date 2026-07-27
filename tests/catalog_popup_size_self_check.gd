extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const VIEWPORT_SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const POPUP_ASPECT_RATIO := 840.0 / 571.0
const SIZE_TOLERANCE := 1.0
const CENTER_TOLERANCE := 1.0
const MODES := [
	["_show_automation_global_popup", "automation"],
	["_show_task_global_popup", "task"],
	["_show_inventory_global_popup", "inventory"],
	["_show_catalog_global_popup", "catalog"],
	["_show_purchase_global_popup", "purchase"],
	["_show_output_global_popup", "output"],
	["_show_storefront_manage_global_popup", "storefront_manage"],
]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for viewport_size_value in VIEWPORT_SIZES:
		await _check_viewport(viewport_size_value)
	_finish()


func _check_viewport(viewport_size: Vector2i) -> void:
	root.content_scale_size = viewport_size
	root.size = viewport_size
	var packed_scene := load(MAIN_SCENE_PATH)
	if packed_scene == null:
		_fail("Main scene is missing")
		return

	var save_path := OS.get_temp_dir().path_join("catalog_popup_size_self_check_%dx%d.json" % [viewport_size.x, viewport_size.y])
	var main: Control = (packed_scene as PackedScene).instantiate()
	main.set("save_path", save_path)
	main.set("broken_save_path", save_path + ".broken")
	root.add_child(main)
	await process_frame
	await process_frame

	var popup := main.get_node("GlobalOverlayLayer") as Control
	var default_surface := main.get_node("GlobalOverlayLayer/DefaultModalSurface") as PanelContainer
	var tabs := main.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogFilterTabs") as TabBar
	_expect(main.get_node_or_null("GlobalOverlayLayer/PurchasePopupBackground") == null, "purchase background node should be removed")
	_expect(main.get_node_or_null("GlobalOverlayLayer/CatalogPopupBackground") == null, "catalog background node should be removed")

	main.call("_show_catalog_global_popup")
	await process_frame
	var expected_rect := popup.get_global_rect()
	_expect_near("%s catalog ratio" % viewport_size, expected_rect.size.x / expected_rect.size.y, POPUP_ASPECT_RATIO)
	_expect_vector_near("%s popup center" % viewport_size, expected_rect.get_center(), Vector2(viewport_size.x, viewport_size.y) * 0.5)
	_expect(_rect_inside_viewport(expected_rect, viewport_size), "%s catalog popup should stay inside the viewport: %s" % [viewport_size, expected_rect])
	_expect(default_surface.visible, "%s catalog should use the default modal surface" % viewport_size)
	_expect(tabs.tab_count == 6, "%s catalog should expose six stable filter tabs" % viewport_size)
	for index in range(tabs.tab_count):
		tabs.current_tab = index
		await process_frame
		_expect_rect("%s catalog filter %d" % [viewport_size, index], popup.get_global_rect(), expected_rect)

	for mode_entry in MODES:
		var open_method := String(mode_entry[0])
		var mode := String(mode_entry[1])
		main.call(open_method)
		await process_frame
		_expect(String(main.get("global_popup_mode")) == mode, "%s should open %s" % [open_method, mode])
		_expect_rect("%s %s outer rect" % [viewport_size, mode], popup.get_global_rect(), expected_rect)
		_expect(default_surface.visible, "%s %s should keep the default modal surface visible" % [viewport_size, mode])

	main.queue_free()
	await process_frame
	for path in [save_path, save_path + ".broken"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _rect_inside_viewport(rect: Rect2, viewport_size: Vector2i) -> bool:
	return rect.position.x >= -SIZE_TOLERANCE \
		and rect.position.y >= -SIZE_TOLERANCE \
		and rect.end.x <= float(viewport_size.x) + SIZE_TOLERANCE \
		and rect.end.y <= float(viewport_size.y) + SIZE_TOLERANCE


func _expect_rect(context: String, actual: Rect2, expected: Rect2) -> void:
	_expect_vector_near("%s position" % context, actual.position, expected.position)
	_expect_vector_near("%s size" % context, actual.size, expected.size)


func _expect_vector_near(context: String, actual: Vector2, expected: Vector2) -> void:
	if actual.distance_to(expected) > CENTER_TOLERANCE:
		_fail("%s expected %s, got %s" % [context, expected, actual])


func _expect_near(context: String, actual: float, expected: float) -> void:
	if absf(actual - expected) > 0.001:
		_fail("%s expected %s, got %s" % [context, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CATALOG_POPUP_SIZE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("CATALOG_POPUP_SIZE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
