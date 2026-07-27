extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("workbench_purchase_overlay_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var view := MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var purchase_button := view.get_node("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/PurchaseButton") as Button
	purchase_button.emit_signal("pressed")
	await process_frame

	var base := "GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/"
	var description := view.get_node_or_null(base + "PageDescription") as RichTextLabel
	var regions_grid := view.get_node_or_null(base + "PurchaseRegionsGrid") as GridContainer
	var cart := view.get_node_or_null(base + "PurchaseFooter/PurchaseCartLabel") as Label
	var confirm := view.get_node_or_null(base + "PurchaseFooter/PurchaseConfirmButton") as Button
	_expect_equal("purchase description exists", description != null, true)
	_expect_equal("purchase region grid exists", regions_grid != null, true)
	_expect_equal("purchase cart summary exists", cart != null, true)
	_expect_equal("purchase confirm button exists", confirm != null, true)
	if description != null:
		_expect_equal("purchase description explains the six-source workflow", description.text.find("六个来源") >= 0, true)
	if regions_grid != null:
		_expect_equal("purchase region grid uses three columns", regions_grid.columns, 3)
		_expect_equal("purchase exposes six sources", regions_grid.get_child_count(), 6)
		var farm_region := regions_grid.get_child(0)
		_expect_equal("purchase renders available farm rows", not (farm_region.call("item_rows") as Array).is_empty(), true)
	if cart != null:
		_expect_equal("purchase cart starts empty", cart.text.find("0 件") >= 0, true)
	if confirm != null:
		_expect_equal("empty cart disables purchase", confirm.disabled, true)

	view.queue_free()
	_cleanup_save()
	_finish()


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _cleanup_save() -> void:
	for path in [_save_path, _save_path + ".broken"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("WORKBENCH_PURCHASE_OVERLAY_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("WORKBENCH_PURCHASE_OVERLAY_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
