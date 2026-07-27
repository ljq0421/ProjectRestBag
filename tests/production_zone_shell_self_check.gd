extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const EXPECTED_SHELL_SCRIPT := "res://scripts/ui/pages/production_zone_shell.gd"

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var main := MainScene.instantiate() as Control
	_expect(main != null, "Main scene must instantiate")
	if main == null:
		_finish()
		return
	main.set_script(null)
	root.add_child(main)
	await process_frame
	await process_frame

	var panel := main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel") as Control
	_expect(panel != null, "WorkbenchPanel path must remain stable")
	if panel == null:
		main.queue_free()
		await process_frame
		_finish()
		return

	_expect(not panel is VBoxContainer, "WorkbenchPanel must be a free-layout Control")
	_expect_equal("shell width", int(panel.size.x), 820)
	_expect(
		panel.get_script() != null
		and String((panel.get_script() as Script).resource_path) == EXPECTED_SHELL_SCRIPT,
		"WorkbenchPanel must use the visual-only production zone shell script"
	)
	_expect(
		panel.theme_type_variation != &"DessertWorkbenchPanel",
		"WorkbenchPanel must not use the full dessert panel skin"
	)

	for node_name in [
		"TileFade",
		"WarmLight",
		"CounterSurface",
		"SteamEffect"
	]:
		var visual := panel.get_node_or_null(node_name) as Control
		_expect(visual != null, "%s must be scene-authored" % node_name)
		if visual != null:
			_expect_equal(
				"%s ignores mouse" % node_name,
				visual.mouse_filter,
				Control.MOUSE_FILTER_IGNORE
			)

	var tile_fade := panel.get_node_or_null("TileFade") as TextureRect
	var counter_surface := panel.get_node_or_null("CounterSurface") as TextureRect
	_expect(tile_fade != null, "tile wall must use the hand-painted texture overlay")
	_expect(counter_surface != null, "counter must use the hand-painted texture overlay")
	if tile_fade != null:
		_expect(
			tile_fade.texture != null
			and tile_fade.texture.resource_path.ends_with(
				"production_tile_wall_overlay.png"
			),
			"tile wall must reference the generated hand-painted asset"
		)
	if counter_surface != null:
		_expect(
			counter_surface.texture != null
			and counter_surface.texture.resource_path.ends_with(
				"production_counter_overlay.png"
			),
			"counter must reference the generated hand-painted asset"
		)
	var workbench := panel.get_node_or_null("ProductionWorkbench") as Control
	var launcher := panel.get_node_or_null("WorkbenchLauncher") as Control
	_expect(workbench != null, "ProductionWorkbench must remain a direct child")
	_expect(launcher != null, "WorkbenchLauncher must remain a direct child")
	if workbench != null:
		var shelf_frame := workbench.get_node_or_null(
			"ProductionColumns/CompletedColumn/ShelfFrame"
		) as TextureRect
		_expect(shelf_frame != null, "completed stock shelf must replace the standalone post")
		if shelf_frame != null:
			_expect_equal(
				"completed shelf ignores mouse",
				shelf_frame.mouse_filter,
				Control.MOUSE_FILTER_IGNORE
			)
			_expect(
				shelf_frame.texture != null
				and shelf_frame.texture.resource_path.ends_with(
					"production_completed_shelf_v2.png"
				),
				"completed shelf must reference the hand-painted shelf asset"
			)
		_expect(
			workbench.get_global_rect().position.y >= 172.0
			and workbench.get_global_rect().position.y <= 180.0,
			"production workbench must clear the curtain"
		)
	if launcher != null:
		_expect_equal(
			"launcher bottom aligns with shell",
			int(round(launcher.position.y + launcher.size.y)),
			int(round(panel.size.y))
		)

	_expect(panel.has_method("set_activity_state"), "shell must expose set_activity_state")
	_expect(panel.has_method("pulse_completion"), "shell must expose pulse_completion")
	_expect(
		panel.has_method("activity_transition_count"),
		"shell must expose transition count for deterministic verification"
	)
	_expect(
		panel.has_method("completion_pulse_count"),
		"shell must expose completion pulse count for deterministic verification"
	)

	if panel.has_method("set_activity_state") and panel.has_method("activity_transition_count"):
		var child_ids_before := _child_instance_ids(panel)
		var transitions_before := int(panel.call("activity_transition_count"))
		panel.call("set_activity_state", true)
		var transitions_after_start := int(panel.call("activity_transition_count"))
		panel.call("set_activity_state", true)
		var transitions_after_repeat := int(panel.call("activity_transition_count"))
		_expect_equal(
			"activity transition increments once",
			transitions_after_start,
			transitions_before + 1
		)
		_expect_equal(
			"repeated activity state does not restart",
			transitions_after_repeat,
			transitions_after_start
		)
		_expect_equal(
			"activity updates do not recreate shell nodes",
			_child_instance_ids(panel),
			child_ids_before
		)
		panel.call("set_activity_state", false)
		_expect_equal(
			"idle transition increments once",
			int(panel.call("activity_transition_count")),
			transitions_after_repeat + 1
		)

	if panel.has_method("pulse_completion") and panel.has_method("completion_pulse_count"):
		var pulses_before := int(panel.call("completion_pulse_count"))
		panel.call("pulse_completion")
		_expect_equal(
			"completion pulse increments once",
			int(panel.call("completion_pulse_count")),
			pulses_before + 1
		)

	main.queue_free()
	await process_frame
	_finish()


func _child_instance_ids(node: Node) -> Array[int]:
	var result: Array[int] = []
	for child: Node in node.get_children():
		result.append(child.get_instance_id())
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_expect(false, "%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCTION_ZONE_SHELL_SELF_CHECK_PASS")
		quit(0)
		return
	for failure: String in failures:
		printerr("PRODUCTION_ZONE_SHELL_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
