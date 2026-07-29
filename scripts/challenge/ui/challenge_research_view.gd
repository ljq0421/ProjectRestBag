class_name ChallengeResearchView
extends PanelContainer

const Catalog = preload("res://scripts/catalog.gd")
const UiStyle = preload("res://scripts/challenge/ui/challenge_ui_style.gd")

signal unlock_requested(node_id: String)
signal back_requested

var _catalog_recipes: Dictionary = Catalog.new().get_recipes()
var _tree_def: Dictionary = {}
var _node_states: Dictionary = {}
var _selected_branch_id := ""


func _ready() -> void:
	UiStyle.apply_secondary($Content/BackButton)
	$Content/BackButton.pressed.connect(func() -> void: back_requested.emit())


func bind(tree_def: Dictionary, meta: Dictionary, node_states: Dictionary) -> void:
	_tree_def = tree_def.duplicate(true)
	_node_states = node_states.duplicate(true)
	$Content/ResearchPoints.text = "可用研究点 %d" % int(meta.get("research_points", 0))
	var branch_ids := _branch_ids()
	if not branch_ids.has(_selected_branch_id):
		_selected_branch_id = branch_ids[0] if not branch_ids.is_empty() else ""
	_rebuild_branch_buttons()
	_rebuild_selected_branch()


func selected_branch_id() -> String:
	return _selected_branch_id


func _rebuild_branch_buttons() -> void:
	var container: VBoxContainer = (
		$Content/Branches/BranchRail/Content/BranchScroll/BranchButtons
	)
	for child in container.get_children():
		child.queue_free()
	for branch_value in _tree_def.get("branches", []):
		if not branch_value is Dictionary:
			continue
		var branch: Dictionary = branch_value
		var branch_id := String(branch.get("id", ""))
		var node_ids: Array = branch.get("node_ids", [])
		var unlocked_count := 0
		for node_id in node_ids:
			var state: Dictionary = _node_states.get(String(node_id), {})
			if bool(state.get("unlocked", false)):
				unlocked_count += 1
		var button := Button.new()
		button.custom_minimum_size = Vector2(270, 62)
		button.text = "%s\n%d / %d 已解锁" % [
			String(branch.get("display_name", branch_id)),
			unlocked_count,
			node_ids.size()
		]
		if branch_id == _selected_branch_id:
			UiStyle.apply_primary(button, Color("#2D9A6A"))
		else:
			UiStyle.apply_secondary(button)
		button.pressed.connect(_select_branch.bind(branch_id))
		container.add_child(button)


func _rebuild_selected_branch() -> void:
	var node_list: VBoxContainer = $Content/Branches/NodePanel/Content/NodeScroll/NodeList
	for child in node_list.get_children():
		child.queue_free()
	var branch := _branch_definition(_selected_branch_id)
	$Content/Branches/NodePanel/Content/BranchTitle.text = String(
		branch.get("display_name", "选择研究方向")
	)
	$Content/Branches/NodePanel/Content/BranchDescription.text = String(
		branch.get("description", "")
	)
	var nodes: Dictionary = _tree_def.get("nodes", {})
	var first_node_id := ""
	for node_id_value in branch.get("node_ids", []):
		var node_id := String(node_id_value)
		if first_node_id.is_empty():
			first_node_id = node_id
		var state: Dictionary = _node_states.get(node_id, {})
		var node_def: Dictionary = nodes.get(node_id, {})
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 112)
		button.text = _node_copy(node_id, node_def, state)
		button.disabled = not bool(state.get("unlockable", false))
		button.tooltip_text = _node_tooltip(state)
		if bool(state.get("unlockable", false)):
			UiStyle.apply_primary(button, Color("#2D9A6A"))
		else:
			UiStyle.apply_secondary(button)
		button.pressed.connect(func() -> void: unlock_requested.emit(node_id))
		button.mouse_entered.connect(_show_node_detail.bind(node_id))
		button.focus_entered.connect(_show_node_detail.bind(node_id))
		node_list.add_child(button)
	if not first_node_id.is_empty():
		_show_node_detail(first_node_id)


func _select_branch(branch_id: String) -> void:
	_selected_branch_id = branch_id
	_rebuild_branch_buttons()
	_rebuild_selected_branch()


func _show_node_detail(node_id: String) -> void:
	var node_def: Dictionary = (_tree_def.get("nodes", {}) as Dictionary).get(node_id, {})
	var state: Dictionary = _node_states.get(node_id, {})
	$Content/Branches/DetailPanel/Content/NodeTitle.text = _node_display_name(node_id, node_def)
	$Content/Branches/DetailPanel/Content/NodeStatus.text = "%s · %d 点" % [
		_status_text(String(state.get("status", ""))),
		int(state.get("cost", node_def.get("cost", 0)))
	]
	$Content/Branches/DetailPanel/Content/Purpose.text = String(
		state.get("build_purpose", node_def.get("build_purpose", ""))
	)
	var rewards: Array[String] = []
	for unlock_value in node_def.get("unlocks", []):
		if not unlock_value is Dictionary:
			continue
		var unlock_type := String(unlock_value.get("type", ""))
		var unlock_id := String(unlock_value.get("id", ""))
		rewards.append(
			_recipe_name(unlock_id) if unlock_type == "recipe" else "%s：%s" % [unlock_type, unlock_id]
		)
	$Content/Branches/DetailPanel/Content/Rewards.text = (
		"\n".join(rewards) if not rewards.is_empty() else "暂无奖励"
	)
	var prerequisites: Array[String] = []
	var nodes: Dictionary = _tree_def.get("nodes", {})
	for prerequisite_id in node_def.get("prerequisite_ids", []):
		prerequisites.append(
			_node_display_name(String(prerequisite_id), nodes.get(String(prerequisite_id), {}))
		)
	$Content/Branches/DetailPanel/Content/Prerequisites.text = (
		"前置：无" if prerequisites.is_empty() else "前置：" + "、".join(prerequisites)
	)


func _node_copy(node_id: String, node_def: Dictionary, state: Dictionary) -> String:
	if not bool(state.get("revealed", false)) and not bool(state.get("unlocked", false)):
		return "尚未揭示\n击败对应客潮后显示"
	var tier := int(node_def.get("tier", 1))
	return "%s · 第 %d 层 · %d 点\n%s\n%s" % [
		_node_display_name(node_id, node_def),
		tier,
		int(state.get("cost", node_def.get("cost", 0))),
		_status_text(String(state.get("status", ""))),
		String(state.get("build_purpose", node_def.get("build_purpose", "")))
	]


func _node_tooltip(state: Dictionary) -> String:
	var prerequisites: Array = state.get("missing_prerequisite_ids", [])
	if not prerequisites.is_empty():
		var names: Array[String] = []
		var nodes: Dictionary = _tree_def.get("nodes", {})
		for node_id in prerequisites:
			names.append(_node_display_name(String(node_id), nodes.get(String(node_id), {})))
		return "需要先解锁：" + "、".join(names)
	if not bool(state.get("enough_points", false)):
		return "研究点不足"
	return "解锁后进入永久收藏；加入本局菜单后才会在下局使用"


func _node_display_name(node_id: String, node_def: Dictionary) -> String:
	var display_name := String(node_def.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		return display_name
	var names: Array[String] = []
	for unlock_value in node_def.get("unlocks", []):
		if unlock_value is Dictionary and String(unlock_value.get("type", "")) == "recipe":
			names.append(_recipe_name(String(unlock_value.get("id", ""))))
	return " + ".join(names) if not names.is_empty() else _recipe_name(node_id)


func _recipe_name(recipe_id: String) -> String:
	return String((_catalog_recipes.get(recipe_id, {}) as Dictionary).get("name", recipe_id))


func _branch_ids() -> Array[String]:
	var result: Array[String] = []
	for branch_value in _tree_def.get("branches", []):
		if branch_value is Dictionary:
			var branch_id := String(branch_value.get("id", "")).strip_edges()
			if not branch_id.is_empty():
				result.append(branch_id)
	return result


func _branch_definition(branch_id: String) -> Dictionary:
	for branch_value in _tree_def.get("branches", []):
		if branch_value is Dictionary and String(branch_value.get("id", "")) == branch_id:
			return (branch_value as Dictionary).duplicate(true)
	return {}


func _status_text(status: String) -> String:
	match status:
		"available":
			return "现在可以解锁"
		"unlocked":
			return "已进入永久收藏"
		"prerequisite_locked":
			return "需要先解锁上一层"
		"insufficient_points":
			return "研究点不足"
		"unrevealed":
			return "尚未揭示"
	return "等待解锁条件"
