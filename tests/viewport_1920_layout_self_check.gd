extends SceneTree

const MAIN := preload("res://scenes/Main.tscn")

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("viewport_1920_layout_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var view = MAIN.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	for path in ["Root", "Root/TopBar", "Root/Body", "Root/StatusBar"]:
		var control := view.get_node_or_null(path) as Control
		_expect_equal("%s exists" % path, control != null, true)
		if control != null:
			_expect_inside(path, control.get_global_rect(), viewport_rect)
	var left := view.get_node("Root/Body/MainArea/StorefrontPanel") as Control
	var right := view.get_node("Root/Body/MainArea/WorkbenchPanel") as Control
	_expect_equal("left and right panels do not overlap", left.get_global_rect().end.x <= right.get_global_rect().position.x, true)
	var showcase := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel") as Control
	_expect_equal("showcase content fills StorefrontPanel", showcase.get_global_rect(), left.get_global_rect())
	_expect_equal("storefront has no separate background node", left.get_node_or_null("StorefrontBackground"), null)
	var grid := view.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid") as GridContainer
	_expect_equal("grid uses 1008 by 864", grid.custom_minimum_size, Vector2(1008, 864))
	_expect_equal("showcase has 168 slots", grid.get_child_count(), 168)
	if grid.get_child_count() == 168:
		var last := grid.get_child(167) as Control
		_expect_equal("slot uses 72 by 72", last.custom_minimum_size, Vector2(72, 72))
		_expect_inside("last showcase slot", last.get_global_rect(), viewport_rect)
	var overlay := view.get_node("GlobalOverlayLayer") as Control
	overlay.show()
	await process_frame
	_expect_inside("global overlay", overlay.get_global_rect(), viewport_rect)
	for dialog_path in ["ShowcaseRoundSettlementDialog", "AutomationReportDialog", "RecipeRestockDialog"]:
		var dialog := view.get_node_or_null(dialog_path) as Window
		_expect_equal("%s exists" % dialog_path, dialog != null, true)
		if dialog != null:
			_expect_equal("%s width fits" % dialog_path, dialog.size.x <= 1920, true)
			_expect_equal("%s height fits" % dialog_path, dialog.size.y <= 1080, true)
	var receipt := view.get_node_or_null("PurchaseReceiptDialog") as Control
	var receipt_frame := receipt.get_node_or_null("ReceiptFrame") as Control if receipt != null else null
	_expect_equal("purchase receipt overlay exists", receipt != null, true)
	_expect_equal("purchase receipt frame exists", receipt_frame != null, true)
	if receipt_frame != null:
		_expect_equal("purchase receipt frame size", receipt_frame.size, Vector2(600, 800))
		_expect_inside("purchase receipt frame", receipt_frame.get_global_rect(), viewport_rect)
	view.queue_free()
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	if FileAccess.file_exists(_save_path + ".broken"):
		DirAccess.remove_absolute(_save_path + ".broken")
	_finish()


func _expect_inside(label: String, inner: Rect2, outer: Rect2) -> void:
	var inside := inner.position.x >= outer.position.x - 0.5 \
		and inner.position.y >= outer.position.y - 0.5 \
		and inner.end.x <= outer.end.x + 0.5 \
		and inner.end.y <= outer.end.y + 0.5
	_expect_equal("%s stays inside 1920x1080 (%s)" % [label, inner], inside, true)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("VIEWPORT_1920_LAYOUT_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("VIEWPORT_1920_LAYOUT_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
