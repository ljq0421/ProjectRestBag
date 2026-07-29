extends SceneTree

const VIEW_PATH := "res://scenes/challenge/challenge_research_view.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var view = load(VIEW_PATH).instantiate()
	root.add_child(view)
	await process_frame
	var tree := {"branches": [], "nodes": {}}
	var states := {}
	for index in range(8):
		var branch_id := "branch_%d" % index
		var node_id := "node_%d" % index
		tree["branches"].append({
			"id": branch_id,
			"display_name": "方向 %d" % (index + 1),
			"description": "可扩展研究方向",
			"node_ids": [node_id]
		})
		tree["nodes"][node_id] = {
			"id": node_id,
			"display_name": "组合节点 %d" % (index + 1),
			"tier": 1,
			"cost": 3,
			"build_purpose": "一次解锁多个成果",
			"unlocks": [{"type": "recipe", "id": "butter_cookie"}]
		}
		states[node_id] = {
			"revealed": true,
			"unlocked": false,
			"unlockable": true,
			"cost": 3,
			"status": "available",
			"build_purpose": "一次解锁多个成果"
		}
	view.bind(tree, {"research_points": 99}, states)
	await process_frame
	var branch_buttons = view.get_node("Content/Branches/BranchRail/Content/BranchScroll/BranchButtons")
	var node_list = view.get_node("Content/Branches/NodePanel/Content/NodeScroll/NodeList")
	_expect(branch_buttons.get_child_count() == 8, "research view should render all eight branches")
	_expect(node_list.get_child_count() == 1, "research view should render selected branch nodes")
	if branch_buttons.get_child_count() == 8:
		branch_buttons.get_child(7).emit_signal("pressed")
		await process_frame
		_expect(view.selected_branch_id() == "branch_7", "eighth branch should be selectable")
	view.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_RESEARCH_TREE_SCALING_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
