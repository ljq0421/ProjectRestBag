extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const UNIFIED_POPUP_SIZE := Vector2(1176.883, 800)
const UNIFIED_POPUP_POSITION := Vector2(371.5585, 140)
const INVENTORY_CELL_SIZE := Vector2(80, 80)
const CATALOG_CELL_SIZE := Vector2(112, 112)
const TOLERANCE := 1.0

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("compact_global_overlay_self_check.json")


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
	var frame := view.get_node("GlobalOverlayLayer/OverlayFrame") as Control
	for open_method in [
		"_show_automation_global_popup",
		"_show_task_global_popup",
		"_show_inventory_global_popup",
		"_show_catalog_global_popup",
		"_show_purchase_global_popup",
		"_show_output_global_popup",
		"_show_storefront_manage_global_popup",
	]:
		view.call(open_method)
		await process_frame
		_expect_near("%s unified size" % open_method, popup.size, UNIFIED_POPUP_SIZE)
		_expect_near("%s centered position" % open_method, popup.position, UNIFIED_POPUP_POSITION)
		if open_method in [
			"_show_automation_global_popup",
			"_show_task_global_popup",
			"_show_inventory_global_popup",
			"_show_catalog_global_popup",
		]:
			_expect_visible_descendants_inside(open_method, frame, popup.get_global_rect())

	var catalog_grid := view.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogContent/CatalogGridPanel/CatalogGrid") as GridContainer
	_expect_equal("catalog uses five compact columns", catalog_grid.columns, 5)
	_expect_equal("catalog uses 15 cells per page", catalog_grid.get_child_count(), 15)
	if catalog_grid.get_child_count() > 0:
		var first_cell := catalog_grid.get_child(0) as Control
		_expect_equal("catalog cell uses compact size", first_cell.custom_minimum_size, CATALOG_CELL_SIZE)

	var inventory_grid := view.get_node("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryGrid") as GridContainer
	_expect_equal("inventory uses eight compact columns", inventory_grid.columns, 8)
	_expect_equal("inventory uses 48 cells per page", inventory_grid.get_child_count(), 48)
	if inventory_grid.get_child_count() > 0:
		var first_inventory_cell := inventory_grid.get_child(0) as Control
		_expect_equal("inventory keeps readable cell size", first_inventory_cell.custom_minimum_size, INVENTORY_CELL_SIZE)

	if view.has_method("_show_handbook_global_popup"):
		view.call("_show_handbook_global_popup")
		await process_frame
		_expect_equal("business handbook remains larger than workbench popup modes", popup.size.x > UNIFIED_POPUP_SIZE.x and popup.size.y > UNIFIED_POPUP_SIZE.y, true)

	view.queue_free()
	_cleanup_save()
	_finish()


func _expect_near(label: String, actual: Vector2, expected: Vector2) -> void:
	if actual.distance_to(expected) > TOLERANCE:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _expect_visible_descendants_inside(context: String, node: Node, outer_rect: Rect2) -> void:
	for child in node.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			var control := child as Control
			var rect := control.get_global_rect()
			var inside := rect.position.x >= outer_rect.position.x - TOLERANCE \
				and rect.position.y >= outer_rect.position.y - TOLERANCE \
				and rect.end.x <= outer_rect.end.x + TOLERANCE \
				and rect.end.y <= outer_rect.end.y + TOLERANCE
			if not inside:
				_fail("%s keeps %s inside unified popup: %s" % [context, String(control.get_path()), rect])
		_expect_visible_descendants_inside(context, child, outer_rect)


func _cleanup_save() -> void:
	for path in [_save_path, _save_path + ".broken"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("COMPACT_GLOBAL_OVERLAY_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("COMPACT_GLOBAL_OVERLAY_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
