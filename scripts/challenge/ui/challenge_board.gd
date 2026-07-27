class_name ChallengeBoard
extends VBoxContainer

signal draft_changed(draft: Dictionary)
signal placement_rejected(reasons: Array[String])
signal recipe_placed(instance_id: String, recipe_id: String)
signal instance_moved(instance_id: String)
signal instance_rotated(
	instance_id: String,
	recipe_id: String,
	rotation: int,
	shape_changed: bool
)
signal instance_removed(instance_id: String)

const ROWS := 6
const COLUMNS := 8
const CELL_SIZE := 80
const RecipeIconService = preload("res://scripts/recipe_icon_service.gd")
const ShowcaseIconService = preload("res://scripts/ui/storefront/showcase_icon_service.gd")
const ChallengeLoadoutServiceClass = preload("res://scripts/challenge/challenge_loadout_service.gd")

var _recipe_defs: Dictionary = {}
var _loadout_service: RefCounted
var _encounter: Dictionary = {}
var _budget := 16
var _draft := {"placements": []}
var _analysis: Dictionary = {}
var _locked := false
var _instance_serial := 0
var _risk_summary := "稳定覆盖：待评估"
var _showcase_icons = ShowcaseIconService.new()
var _dragged_instance_id := ""


func _ready() -> void:
	_showcase_icons.load_manifest()
	_build_cells()
	_refresh()


func bind(
	recipe_defs: Dictionary,
	loadout_service: RefCounted,
	encounter: Dictionary,
	budget: int
) -> void:
	_recipe_defs = recipe_defs.duplicate(true)
	_loadout_service = loadout_service
	_encounter = encounter.duplicate(true)
	_budget = budget
	_refresh()


func set_draft(draft: Dictionary) -> void:
	_draft = draft.duplicate(true)
	_refresh()
	draft_changed.emit(get_draft())


func get_draft() -> Dictionary:
	return _draft.duplicate(true)


func place_recipe(
	recipe_id: String,
	origin: Variant,
	rotation: int = 0,
	instance_id: String = ""
) -> bool:
	if _locked:
		return false
	var resolved_instance_id := instance_id.strip_edges()
	if resolved_instance_id.is_empty():
		_instance_serial += 1
		resolved_instance_id = "%s_%d" % [recipe_id, _instance_serial]
	var candidate := get_draft()
	var placements: Array = candidate.get("placements", [])
	placements.append({
		"instance_id": resolved_instance_id,
		"recipe_id": recipe_id,
		"origin": _origin_array(origin),
		"rotation": rotation
	})
	candidate["placements"] = placements
	if not _commit_candidate(candidate):
		return false
	recipe_placed.emit(resolved_instance_id, recipe_id)
	return true


func move_instance(instance_id: String, origin: Variant) -> bool:
	if _locked:
		return false
	var candidate := get_draft()
	var found := false
	for placement in candidate.get("placements", []):
		if placement.get("instance_id") == instance_id:
			placement["origin"] = _origin_array(origin)
			found = true
			break
	if not found or not _commit_candidate(candidate):
		return false
	instance_moved.emit(instance_id)
	return true


func rotate_instance(instance_id: String) -> bool:
	if _locked:
		return false
	var candidate := get_draft()
	var recipe_id := ""
	var previous_rotation := 0
	var next_rotation := 0
	var found := false
	for placement in candidate.get("placements", []):
		if placement.get("instance_id") == instance_id:
			recipe_id = String(placement.get("recipe_id", ""))
			previous_rotation = posmod(int(placement.get("rotation", 0)), 360)
			next_rotation = posmod(previous_rotation + 90, 360)
			placement["rotation"] = next_rotation
			found = true
			break
	if not found or not _commit_candidate(candidate):
		return false
	var shape: Array = (_recipe_defs.get(recipe_id, {}) as Dictionary).get("shape_cells", [])
	var before := ChallengeLoadoutServiceClass.rotated_cells(shape, previous_rotation)
	var after := ChallengeLoadoutServiceClass.rotated_cells(shape, next_rotation)
	instance_rotated.emit(instance_id, recipe_id, next_rotation, before != after)
	return true


func remove_instance(instance_id: String) -> bool:
	if _locked:
		return false
	var candidate := get_draft()
	var placements: Array = candidate.get("placements", [])
	for index in placements.size():
		if placements[index].get("instance_id") == instance_id:
			placements.remove_at(index)
			candidate["placements"] = placements
			if not _commit_candidate(candidate):
				return false
			instance_removed.emit(instance_id)
			return true
	return false


func set_locked(locked: bool) -> void:
	_locked = locked
	$RiskLabel.modulate = Color(1, 1, 1, 0.7) if locked else Color.WHITE


func is_locked() -> bool:
	return _locked


func set_risk_summary(summary: String) -> void:
	_risk_summary = summary
	_refresh_header()


func get_occupied_cell_count() -> int:
	return (_analysis.get("occupied_cells", {}) as Dictionary).size()


func is_current_draft_valid() -> bool:
	return bool(_analysis.get("valid", false))


func get_tutorial_target_rects(kind: String, instance_id: String = "") -> Array[Rect2]:
	match kind:
		"board":
			return [ChallengeTutorialOverlay.control_screen_rect($BoardFrame)]
		"risk":
			return [
				ChallengeTutorialOverlay.control_screen_rect($Header),
				ChallengeTutorialOverlay.control_screen_rect($RiskLabel),
				ChallengeTutorialOverlay.control_screen_rect($RelationSummary)
			]
		"instance":
			var rects: Array[Rect2] = []
			for cell in $BoardFrame/BoardGrid.get_children():
				if String(cell.get_meta("instance_id", "")) == instance_id:
					rects.append(ChallengeTutorialOverlay.control_screen_rect(cell))
			return rects
	return []


func _commit_candidate(candidate: Dictionary) -> bool:
	if _loadout_service == null:
		_reject(["board: loadout service is not bound"])
		return false
	var analyzed: Dictionary = _loadout_service.call(
		"analyze",
		candidate,
		_recipe_defs,
		ROWS,
		COLUMNS,
		_budget,
		_encounter
	)
	if not bool(analyzed.get("valid", false)):
		_reject(_string_array(analyzed.get("errors", [])))
		return false
	_draft = candidate.duplicate(true)
	_analysis = analyzed.duplicate(true)
	_refresh()
	draft_changed.emit(get_draft())
	return true


func _reject(reasons: Array[String]) -> void:
	placement_rejected.emit(reasons)
	if not reasons.is_empty():
		$RiskLabel.text = reasons[0]


func _refresh() -> void:
	if _loadout_service != null:
		_analysis = _loadout_service.call(
			"analyze",
			_draft,
			_recipe_defs,
			ROWS,
			COLUMNS,
			_budget,
			_encounter
		)
	else:
		_analysis = {
			"valid": true,
			"errors": [],
			"spent_budget": 0,
			"occupied_cells": {},
			"relations": [],
			"instances": []
		}
	_refresh_header()
	_refresh_cells()
	_refresh_relations()


func _refresh_header() -> void:
	$Header/BudgetLabel.text = "挑战备货 %d / %d" % [int(_analysis.get("spent_budget", 0)), _budget]
	$Header/CoverageLabel.text = "展示柜占格 %d / %d" % [get_occupied_cell_count(), ROWS * COLUMNS]
	var errors: Array = _analysis.get("errors", [])
	$RiskLabel.text = String(errors[0]) if not errors.is_empty() else _risk_summary


func _refresh_relations() -> void:
	var relations: Array = _analysis.get("relations", [])
	if relations.is_empty():
		$RelationSummary.text = "[color=#9e94b6]组合联动：尚未激活｜让饮品与烘焙配方上下左右相邻[/color]"
	else:
		$RelationSummary.text = "[color=#72d6a0][b]组合联动：饮品 × 烘焙 × %d[/b][/color]  每个参与配方获得一次 25%% 满意度加成" % relations.size()


func _build_cells() -> void:
	if $BoardFrame/BoardGrid.get_child_count() > 0:
		return
	for row in ROWS:
		for column in COLUMNS:
			var cell := PanelContainer.new()
			cell.name = "Cell_%d_%d" % [row, column]
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.set_meta("row", row)
			cell.set_meta("column", column)
			cell.set_meta("instance_id", "")
			var icon := TextureRect.new()
			icon.name = "Icon"
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(icon)
			$BoardFrame/BoardGrid.add_child(cell)


func _refresh_cells() -> void:
	var grid: GridContainer = $BoardFrame/BoardGrid
	for child in grid.get_children():
		var row := int(child.get_meta("row", 0))
		var column := int(child.get_meta("column", 0))
		child.set_meta("instance_id", "")
		child.get_node("Icon").texture = null
		child.add_theme_stylebox_override("panel", _cell_style(row, column, false, false))

	var relation_instances := {}
	for relation in _analysis.get("relations", []):
		relation_instances[String(relation.get("left_instance_id", ""))] = true
		relation_instances[String(relation.get("right_instance_id", ""))] = true
	for instance_value in _analysis.get("instances", []):
		var instance: Dictionary = instance_value
		var instance_id := String(instance.get("instance_id", ""))
		var origin_value: Array = instance.get("origin", [0, 0])
		var origin := Vector2i(int(origin_value[0]), int(origin_value[1]))
		var rotation := int(instance.get("rotation", 0))
		for cell_value in instance.get("cells", []):
			var row := int(cell_value[0])
			var column := int(cell_value[1])
			var cell_index := row * COLUMNS + column
			if cell_index < 0 or cell_index >= grid.get_child_count():
				continue
			var cell: PanelContainer = grid.get_child(cell_index)
			cell.set_meta("instance_id", instance_id)
			var local_cell := Vector2i(row, column) - origin
			var texture: Texture2D = _showcase_icons.fragment(
				String(instance.get("recipe_id", "")),
				"standard",
				rotation,
				local_cell,
				0
			)
			if texture == null:
				texture = RecipeIconService.texture(String(instance.get("recipe_id", "")), 0, "base")
			cell.get_node("Icon").texture = texture
			cell.add_theme_stylebox_override("panel", _cell_style(row, column, true, relation_instances.has(instance_id)))


func _cell_style(row: int, column: int, occupied: bool, related: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#5367d5") if occupied else (Color("#342b4b") if (row + column) % 2 == 0 else Color("#2c2540"))
	style.border_color = Color("#ffc857") if related else (Color("#756b91") if not occupied else Color("#8ea0ff"))
	style.set_border_width_all(3 if related else 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 5
	style.content_margin_top = 5
	style.content_margin_right = 5
	style.content_margin_bottom = 5
	return style


func _gui_input(event: InputEvent) -> void:
	if _locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var instance_id := _instance_at_global(get_global_mouse_position())
		if not instance_id.is_empty():
			rotate_instance(instance_id)
			accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _locked:
		return null
	var instance_id := _instance_at_global(get_global_mouse_position())
	if instance_id.is_empty():
		return null
	_dragged_instance_id = instance_id
	var preview := Label.new()
	preview.text = "移动 %s" % instance_id
	set_drag_preview(preview)
	return {
		"kind": "challenge_instance",
		"instance_id": instance_id
	}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if _locked or not data is Dictionary:
		return false
	if not ["challenge_recipe", "challenge_instance"].has(String(data.get("kind", ""))):
		return false
	return _cell_at_global(global_position + at_position) != Vector2i(-1, -1)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var cell := _cell_at_global(global_position + at_position)
	if cell == Vector2i(-1, -1):
		return
	match String(data.get("kind", "")):
		"challenge_recipe":
			place_recipe(String(data.get("recipe_id", "")), [cell.x, cell.y])
		"challenge_instance":
			move_instance(String(data.get("instance_id", "")), [cell.x, cell.y])
	_dragged_instance_id = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and not _dragged_instance_id.is_empty():
		if not is_drag_successful() and not _locked:
			remove_instance(_dragged_instance_id)
		_dragged_instance_id = ""


func _instance_at_global(global_mouse: Vector2) -> String:
	var cell := _cell_at_global(global_mouse)
	if cell == Vector2i(-1, -1):
		return ""
	var index := cell.x * COLUMNS + cell.y
	return String($BoardFrame/BoardGrid.get_child(index).get_meta("instance_id", ""))


func _cell_at_global(global_mouse: Vector2) -> Vector2i:
	for child in $BoardFrame/BoardGrid.get_children():
		if child.get_global_rect().has_point(global_mouse):
			return Vector2i(int(child.get_meta("row", -1)), int(child.get_meta("column", -1)))
	return Vector2i(-1, -1)


func _origin_array(origin: Variant) -> Array:
	if origin is Vector2i:
		return [origin.x, origin.y]
	if origin is Array and origin.size() == 2:
		return [int(origin[0]), int(origin[1])]
	return [-1, -1]


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
