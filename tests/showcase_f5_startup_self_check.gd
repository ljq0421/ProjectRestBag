extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const EXPECTED_SLOT_COUNT := 168
const EXPECTED_MINIMUM_VISIBLE_SLOT_COUNT := 16


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("Main scene is missing")
		return

	var main := packed_scene.instantiate() as Control
	root.add_child(main)
	await process_frame
	await process_frame

	var showcase_grid := main.get_node_or_null(
		"Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid"
	) as GridContainer
	if showcase_grid == null:
		_fail("F5 startup should provide the showcase grid")
		return
	if showcase_grid.get_child_count() != EXPECTED_SLOT_COUNT:
		_fail(
			"F5 startup should render %d showcase cells, got %d"
			% [EXPECTED_SLOT_COUNT, showcase_grid.get_child_count()]
		)
		return

	var visible_slot_count := 0
	for child_value in showcase_grid.get_children():
		var slot := child_value as Control
		if slot != null and slot.visible and slot.modulate.a > 0.0:
			visible_slot_count += 1
	if visible_slot_count < EXPECTED_MINIMUM_VISIBLE_SLOT_COUNT:
		_fail(
			"F5 startup should show at least %d default showcase cells, got %d"
			% [EXPECTED_MINIMUM_VISIBLE_SLOT_COUNT, visible_slot_count]
		)
		return

	main.queue_free()
	print("SHOWCASE_F5_STARTUP_SELF_CHECK_PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	printerr("SHOWCASE_F5_STARTUP_SELF_CHECK_FAIL: %s" % message)
	quit(1)
