class_name ChallengeResearchView
extends PanelContainer

const Catalog = preload("res://scripts/catalog.gd")
const UiStyle = preload("res://scripts/challenge/ui/challenge_ui_style.gd")

signal unlock_requested(node_id: String)
signal back_requested

var _catalog_recipes: Dictionary = Catalog.new().get_recipes()


func _ready() -> void:
	UiStyle.apply_secondary($Content/BackButton)
	$Content/BackButton.pressed.connect(func() -> void: back_requested.emit())


func bind(tree_def: Dictionary, meta: Dictionary, node_states: Dictionary) -> void:
	$Content/ResearchPoints.text = "可用研究点 %d" % int(meta.get("research_points", 0))
	for branch_box in $Content/Branches.get_children():
		for child in branch_box.get_children():
			child.queue_free()
	var branches: Array = tree_def.get("branches", [])
	for branch_index in range(mini(3, branches.size())):
		if not branches[branch_index] is Dictionary:
			continue
		var branch: Dictionary = branches[branch_index]
		var box: VBoxContainer = $Content/Branches.get_child(branch_index)
		var title := Label.new()
		title.text = String(branch.get("display_name", branch.get("id", "")))
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", Color("#29213D"))
		box.add_child(title)
		var description := Label.new()
		description.text = String(branch.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_color_override("font_color", Color("#665A82"))
		box.add_child(description)
		for node_id_value in branch.get("node_ids", []):
			var node_id := String(node_id_value)
			var state: Dictionary = node_states.get(node_id, {})
			var node_def: Dictionary = (tree_def.get("nodes", {}) as Dictionary).get(node_id, {})
			var button := Button.new()
			button.custom_minimum_size = Vector2(0, 116)
			button.text = _node_copy(node_id, node_def, state)
			button.disabled = not bool(state.get("unlockable", false))
			button.tooltip_text = _node_tooltip(state)
			if bool(state.get("unlockable", false)):
				UiStyle.apply_primary(button, Color("#2D9A6A"))
			else:
				UiStyle.apply_secondary(button)
			button.pressed.connect(func() -> void: unlock_requested.emit(node_id))
			box.add_child(button)


func _node_copy(node_id: String, node_def: Dictionary, state: Dictionary) -> String:
	if not bool(state.get("revealed", false)) and not bool(state.get("unlocked", false)):
		return "尚未揭示\n击败对应客潮后显示"
	var tier := int(node_def.get("tier", 1))
	return "%s · 第 %d 层 · %d 点\n%s\n%s" % [
		_recipe_name(node_id),
		tier,
		int(state.get("cost", node_def.get("cost", 0))),
		_status_text(String(state.get("status", ""))),
		String(state.get("build_purpose", node_def.get("build_purpose", "")))
	]


func _node_tooltip(state: Dictionary) -> String:
	var prerequisites: Array = state.get("missing_prerequisite_ids", [])
	if not prerequisites.is_empty():
		var names: Array[String] = []
		for recipe_id in prerequisites:
			names.append(_recipe_name(String(recipe_id)))
		return "需要先解锁：" + "、".join(names)
	if not bool(state.get("enough_points", false)):
		return "研究点不足"
	return "解锁后从下一条短链起加入挑战备货池"


func _recipe_name(recipe_id: String) -> String:
	return String((_catalog_recipes.get(recipe_id, {}) as Dictionary).get("name", recipe_id))


func _status_text(status: String) -> String:
	match status:
		"available":
			return "现在可以解锁"
		"unlocked":
			return "已永久解锁"
		"prerequisite_locked":
			return "需要先解锁上一层"
		"insufficient_points":
			return "研究点不足"
		"unrevealed":
			return "尚未揭示"
	return "等待解锁条件"
