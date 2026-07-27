extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const BACKGROUND_TEXTURE_PATH := "res://resources/ui/skin_v1/background.png"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "Main scene should load")
	if packed_scene == null:
		_finish()
		return

	var main := packed_scene.instantiate() as Control
	_expect(main != null, "Main scene should instantiate as Control")
	if main == null:
		_finish()
		return
	main.set_script(null)
	root.add_child(main)
	await process_frame
	await process_frame

	var background := main.get_node_or_null("PageBackground") as TextureRect
	_expect(background != null, "Main scene should contain a PageBackground TextureRect")
	if background != null:
		_expect(main.get_child(0) == background, "PageBackground should render below every existing main-page child")
		_expect(background.texture != null, "PageBackground should have a texture")
		if background.texture != null:
			_expect(background.texture.resource_path == BACKGROUND_TEXTURE_PATH, "PageBackground should use the assigned full-screen background texture")
		_expect(background.anchor_left == 0.0 and background.anchor_top == 0.0, "PageBackground should start at the viewport origin")
		_expect(background.anchor_right == 1.0 and background.anchor_bottom == 1.0, "PageBackground should fill the viewport")
		_expect(background.mouse_filter == Control.MOUSE_FILTER_IGNORE, "PageBackground should not intercept input")
		_expect(background.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "PageBackground should ignore the source texture size")
		_expect(background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "PageBackground should cover the viewport without distorting the image")

	var panel := main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel") as Control
	var workbench := main.get_node_or_null(
		"Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench"
	) as Control
	_expect(panel != null, "Main scene should preserve the WorkbenchPanel path")
	_expect(workbench != null, "Main scene should preserve the ProductionWorkbench path")
	if panel != null:
		_expect_equal("workbench shell width", int(panel.size.x), 820)
	if workbench != null:
		var workbench_top := workbench.get_global_rect().position.y
		_expect(
			workbench_top >= 172.0 and workbench_top <= 180.0,
			"production content should start below the curtain near y=176, got %.1f" % workbench_top
		)

	main.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_expect(false, "%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
	if _failures.is_empty():
		print("MAIN_PAGE_BACKGROUND_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("MAIN_PAGE_BACKGROUND_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
