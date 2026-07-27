extends SceneTree

const SHOWCASE_SLOT_SCENE := preload("res://scenes/ui/storefront/showcase_slot.tscn")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(800, 600)
	var boundary := Control.new()
	boundary.position = Vector2(40, 40)
	boundary.size = Vector2(320, 320)
	root.add_child(boundary)

	var slot := SHOWCASE_SLOT_SCENE.instantiate() as Button
	slot.position = Vector2(100, 100)
	slot.size = Vector2(72, 72)
	boundary.add_child(slot)
	slot.call("configure_drag", {"kind": "showcase_product", "recipe_id": "butter_cookie"}, "")
	await process_frame

	var preview := slot.call("_make_drag_preview") as Control
	slot.force_drag((slot.get("drag_data") as Dictionary).duplicate(true), preview)
	await process_frame
	await process_frame
	_expect(root.gui_is_dragging(), "isolated showcase slot should start a real engine drag")
	_expect(preview != null, "engine drag should attach the specialized showcase preview")

	var outside_position := Vector2(620, 500)
	await _move_drag(outside_position)
	if preview != null:
		_expect(preview.get_child_count() == 0, "engine drag preview should stay completely empty outside showcase")
	await _release_drag(outside_position)
	boundary.queue_free()
	if _failures.is_empty():
		print("SHOWCASE_DRAG_PREVIEW_ENGINE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_DRAG_PREVIEW_ENGINE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)


func _move_drag(to: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = to
	motion.global_position = to
	motion.relative = Vector2(400, 300)
	Input.parse_input_event(motion)
	await process_frame
	await process_frame


func _release_drag(at: Vector2) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at
	release.global_position = at
	Input.parse_input_event(release)
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
