extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const EXPECTED_ENTRIES := [
	["StarlightButton", "starlight"],
	["TaskButton", "task"],
	["InventoryButton", "inventory"],
	["CatalogButton", "catalog"],
	["ResearchButton", "research"],
	["PurchaseButton", "purchase"],
	["OutputButton", "output"],
	["StorefrontManageButton", "storefront"],
]

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("workbench_bottom_launcher_self_check.json")


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

	for old_path in [
		"Root/TopBar/StarlightButton",
		"Root/TopBar/TaskButton",
		"Root/TopBar/InventoryButton",
		"Root/TopBar/CatalogButton",
		"Root/Body/MainArea/WorkbenchPanel/ConsoleTabs",
	]:
		_expect_equal("old navigation removed: %s" % old_path, view.get_node_or_null(old_path), null)

	var storefront := view.get_node_or_null("Root/Body/MainArea/StorefrontPanel") as Control
	_expect_equal("left storefront remains at the stable path", storefront != null, true)
	if storefront != null:
		_expect_equal("left storefront keeps its 63 share", storefront.size_flags_stretch_ratio, 63.0)

	var production := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench") as Control
	var launcher := view.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher") as Control
	_expect_equal("production workbench exists", production != null, true)
	_expect_equal("bottom launcher exists", launcher != null, true)
	if production != null and launcher != null:
		_expect_equal("production keeps the larger vertical share", production.size_flags_stretch_ratio > launcher.size_flags_stretch_ratio, true)
		_expect_equal("launcher keeps a readable minimum height", launcher.custom_minimum_size.y >= 72.0, true)
		_expect_equal("launcher stays below production", production.get_global_rect().end.y <= launcher.get_global_rect().position.y + 1.0, true)

	if launcher != null:
		_expect_equal("launcher exposes eight entries", launcher.get_child_count(), EXPECTED_ENTRIES.size())
		for index in range(mini(launcher.get_child_count(), EXPECTED_ENTRIES.size())):
			var expected: Array = EXPECTED_ENTRIES[index]
			var button := launcher.get_child(index) as Button
			_expect_equal("entry %d is a button" % index, button != null, true)
			if button == null:
				continue
			_expect_equal("entry %d node name" % index, button.name, StringName(expected[0]))
			var icon_slug := String(expected[1])
			_expect_equal("entry %d hides its text label" % index, button.text, "")
			_expect_equal("entry %d has an icon" % index, button.icon != null, true)
			if button.icon != null:
				_expect_equal("entry %d uses the generated PNG icon" % index, String(button.icon.resource_path), "res://resources/ui/icons/workbench/generated/%s.png" % String(expected[1]))
				_expect_equal("entry %d uses the 64px icon size" % index, button.get_theme_constant("icon_max_width"), 64)
			_expect_equal("entry %d has a 64px-wide frame" % index, button.size.x, 64.0)
			_expect_equal("entry %d has a 64px-tall frame" % index, button.size.y, 64.0)
			_expect_equal("entry %d uses the zero-padding launcher skin" % index, button.theme_type_variation, &"DessertLauncherIconButton")
			var normal_style := button.get_theme_stylebox("normal")
			_expect_equal("entry %d has no horizontal icon padding" % index, normal_style.get_content_margin(SIDE_LEFT), 0.0)
			_expect_equal("entry %d has no vertical icon padding" % index, normal_style.get_content_margin(SIDE_TOP), 0.0)
			_expect_equal("entry %d has a tooltip" % index, not button.tooltip_text.is_empty(), true)

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
		print("WORKBENCH_BOTTOM_LAUNCHER_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("WORKBENCH_BOTTOM_LAUNCHER_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
