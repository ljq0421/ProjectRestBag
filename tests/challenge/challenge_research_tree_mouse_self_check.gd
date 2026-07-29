extends SceneTree

const VIEW_PATH := "res://scenes/challenge/challenge_research_view.tscn"

var _failures: Array[String] = []
var _requested_node_id := ""
var _clicks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var view = load(VIEW_PATH).instantiate()
	root.add_child(view)
	view.unlock_requested.connect(func(node_id: String) -> void: _requested_node_id = node_id)
	await process_frame
	var tree := {"branches": [], "nodes": {}}
	var states := {}
	for index in range(8):
		var branch_id := "branch_%d" % index
		var node_id := "node_%d" % index
		tree["branches"].append({
			"id": branch_id,
			"display_name": "方向 %d" % (index + 1),
			"description": "第 %d 个可扩展方向" % (index + 1),
			"node_ids": [node_id]
		})
		tree["nodes"][node_id] = {
			"id": node_id,
			"display_name": "节点 %d" % (index + 1),
			"tier": 1,
			"cost": 3,
			"prerequisite_ids": [],
			"build_purpose": "鼠标路径验证",
			"unlocks": [{"type": "recipe", "id": "butter_cookie"}]
		}
		states[node_id] = {
			"revealed": true,
			"unlocked": false,
			"unlockable": true,
			"cost": 3,
			"status": "available",
			"build_purpose": "鼠标路径验证"
		}
	view.bind(tree, {"research_points": 99}, states)
	await process_frame
	var branch_buttons = view.get_node(
		"Content/Branches/BranchRail/Content/BranchScroll/BranchButtons"
	)
	var eighth_button: Button = branch_buttons.get_child(7)
	var branch_scroll: ScrollContainer = view.get_node(
		"Content/Branches/BranchRail/Content/BranchScroll"
	)
	branch_scroll.ensure_control_visible(eighth_button)
	await process_frame
	await process_frame
	await _click(_center(eighth_button))
	await process_frame
	_expect(view.selected_branch_id() == "branch_7", "real click should select the eighth research branch")
	var detail_title: Label = view.get_node("Content/Branches/DetailPanel/Content/NodeTitle")
	_expect(detail_title.text == "节点 8", "right detail panel should follow selected branch")
	var node_list = view.get_node("Content/Branches/NodePanel/Content/NodeScroll/NodeList")
	var unlock_button: Button = node_list.get_child(0)
	await _click(_center(unlock_button))
	await process_frame
	_expect(_requested_node_id == "node_7", "real click should emit the selected node unlock request")
	view.queue_free()
	_finish()


func _click(position: Vector2) -> void:
	var hover := InputEventMouseMotion.new()
	hover.position = position
	hover.global_position = position
	Input.parse_input_event(hover)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = position
		event.global_position = position
		Input.parse_input_event(event)
		await process_frame
	_clicks += 1


func _center(control: Control) -> Vector2:
	return control.get_screen_transform() * (control.size * 0.5)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_RESEARCH_TREE_MOUSE_SELF_CHECK_PASS clicks=%d" % _clicks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
