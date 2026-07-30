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
signal expansion_placement_requested(product_id: String, rotation: int, anchor: Vector2i)

const ROWS := 8
const COLUMNS := 14
const CELL_SIZE := 64
const RecipeIconService = preload("res://scripts/recipe_icon_service.gd")
const ShowcaseIconService = preload("res://scripts/ui/storefront/showcase_icon_service.gd")
const ChallengeLoadoutServiceClass = preload("res://scripts/challenge/challenge_loadout_service.gd")
const ChallengeTutorialOverlay = preload("res://scripts/challenge/ui/challenge_tutorial_overlay.gd")
const ChallengeBoardExpansionService = preload(
	"res://scripts/challenge/challenge_board_expansion_service.gd"
)
const TAG_NAMES := {
	"fast": "快速",
	"bake": "烘焙",
	"fruit": "水果",
	"drink": "饮品",
	"set": "搭配",
	"signature": "招牌",
	"chocolate": "巧克力",
	"aromatic": "香气",
	"soft": "软糯",
	"tea": "茶香",
	"crisp": "香脆",
	"savory": "咸香",
	"hearty": "饱腹",
	"refreshing": "清爽",
	"rich": "浓郁",
	"spatial": "空间"
}

var _recipe_defs: Dictionary = {}
var _effective_context: Dictionary = {}
var _loadout_service: RefCounted
var _encounter: Dictionary = {}
var _budget := 16
var _draft := {"placements": []}
var _analysis: Dictionary = {}
var _locked := false
var _requires_rearrange := false
var _instance_serial := 0
var _risk_summary := "稳定覆盖：待评估"
var _showcase_icons = ShowcaseIconService.new()
var _dragged_instance_id := ""
var _layout_refresh_queued := false
var _unlocked_cells: Array = []
var _unlocked_keys := {}
var _expansion_service = ChallengeBoardExpansionService.new()
var _expansion_meta: Dictionary = {}
var _expansion_product_id := ""
var _expansion_rotation := 0
var _expansion_anchor := Vector2i(-1, -1)
var _expansion_preview: Dictionary = {}


func _ready() -> void:
	_showcase_icons.load_manifest()
	var default_meta := _expansion_service.bootstrap_meta({})
	_unlocked_cells = _expansion_service.unlocked_cells(default_meta)
	_unlocked_keys = _cell_keys(_unlocked_cells)
	_expansion_meta = default_meta
	$BoardFrame/BoardGrid.resized.connect(_queue_layout_refresh)
	_build_cells()
	_refresh()


func bind(
	recipe_defs: Dictionary,
	loadout_service: RefCounted,
	encounter: Dictionary,
	budget: int
) -> void:
	_recipe_defs = recipe_defs.duplicate(true)
	_effective_context = {}
	_loadout_service = loadout_service
	_encounter = encounter.duplicate(true)
	_budget = budget
	_requires_rearrange = false
	_refresh()


func bind_effective_context(
	effective_context: Dictionary,
	loadout_service: RefCounted,
	encounter: Dictionary
) -> void:
	_recipe_defs = (
		effective_context.get("recipe_defs", {}) as Dictionary
	).duplicate(true)
	_effective_context = effective_context.duplicate(true)
	_unlocked_cells = (
		effective_context.get("unlocked_cells", []) as Array
	).duplicate(true)
	_unlocked_keys = _cell_keys(_unlocked_cells)
	_expansion_meta = {
		"board_expansion": {
			"max_rows": ROWS,
			"max_columns": COLUMNS,
			"unlocked_cells": _unlocked_cells.duplicate(true)
		},
		"expansion_tickets": 0,
		"expansion_ticket_reward_ids": []
	}
	_loadout_service = loadout_service
	_encounter = encounter.duplicate(true)
	var rules: Dictionary = effective_context.get("rules", {})
	_budget = int(rules.get("supply_budget", 0))
	_refresh()
	_requires_rearrange = not bool(_analysis.get("valid", false))
	if _requires_rearrange:
		_risk_summary = "强化改变了当前构筑，请重新摆放后再战斗"
		_refresh_header()


func set_draft(draft: Dictionary) -> void:
	_draft = draft.duplicate(true)
	_refresh()
	draft_changed.emit(get_draft())


func begin_expansion_preview(product_id: String, rotation: int = 0) -> void:
	_expansion_product_id = product_id
	_expansion_rotation = posmod(rotation, 360)
	_expansion_anchor = Vector2i(-1, -1)
	_expansion_preview = {}
	_refresh_cells()


func set_expansion_rotation(rotation: int) -> void:
	_expansion_rotation = posmod(rotation, 360)
	_update_expansion_preview(_expansion_anchor)


func cancel_expansion_preview() -> void:
	_expansion_product_id = ""
	_expansion_anchor = Vector2i(-1, -1)
	_expansion_preview = {}
	_refresh_cells()


func is_expansion_preview_active() -> bool:
	return not _expansion_product_id.is_empty()


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


func needs_rearrange() -> bool:
	return _requires_rearrange


func effective_recipe_defs() -> Dictionary:
	return _recipe_defs.duplicate(true)


func get_build_summary() -> Dictionary:
	var cycle_min_ms := 0
	var cycle_max_ms := 0
	var boosted_instances := {}
	var relation_bonus_pct := 0
	for value in _analysis.get("instances", []):
		if not value is Dictionary:
			continue
		var cycle_ms := int(value.get("cycle_ms", 0))
		if cycle_ms > 0:
			cycle_min_ms = cycle_ms if cycle_min_ms == 0 else mini(cycle_min_ms, cycle_ms)
			cycle_max_ms = maxi(cycle_max_ms, cycle_ms)
	for value in _analysis.get("relations", []):
		if not value is Dictionary:
			continue
		boosted_instances[String(value.get("left_instance_id", ""))] = true
		boosted_instances[String(value.get("right_instance_id", ""))] = true
		relation_bonus_pct = maxi(relation_bonus_pct, int(value.get("bonus_pct", 0)))
	return {
		"instance_count": (_analysis.get("instances", []) as Array).size(),
		"cycle_min_ms": cycle_min_ms,
		"cycle_max_ms": cycle_max_ms,
		"relation_count": (_analysis.get("relations", []) as Array).size(),
		"boosted_instance_count": boosted_instances.size(),
		"relation_bonus_pct": relation_bonus_pct
	}


func get_tutorial_target_rects(kind: String, instance_id: String = "") -> Array[Rect2]:
	match kind:
		"board":
			return [ChallengeTutorialOverlay.control_screen_rect($BoardFrame)]
		"risk":
			var header_rect := ChallengeTutorialOverlay.control_screen_rect(
				$Header/BudgetLabel
			).merge(
				ChallengeTutorialOverlay.control_screen_rect($Header/CoverageLabel)
			)
			return [
				header_rect,
				ChallengeTutorialOverlay.control_content_screen_rect($RiskLabel),
				ChallengeTutorialOverlay.control_content_screen_rect($RelationSummary)
			]
		"relation":
			return [
				ChallengeTutorialOverlay.control_content_screen_rect($RelationSummary)
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
	var analyzed := _analyze_draft(candidate)
	if not bool(analyzed.get("valid", false)):
		_reject(_string_array(analyzed.get("errors", [])))
		return false
	_draft = candidate.duplicate(true)
	_analysis = analyzed.duplicate(true)
	_requires_rearrange = false
	_refresh()
	draft_changed.emit(get_draft())
	return true


func _reject(reasons: Array[String]) -> void:
	placement_rejected.emit(reasons)
	if not reasons.is_empty():
		$RiskLabel.text = reasons[0]


func _refresh() -> void:
	if _loadout_service != null:
		_analysis = _analyze_draft(_draft)
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


func _analyze_draft(draft: Dictionary) -> Dictionary:
	if not _effective_context.is_empty():
		return _loadout_service.call(
			"analyze_context",
			draft,
			_effective_context,
			ROWS,
			COLUMNS,
			_encounter
		)
	return _loadout_service.call(
		"analyze",
		draft,
		_recipe_defs,
		ROWS,
		COLUMNS,
		_budget,
		_encounter
	)


func _refresh_header() -> void:
	$Header/BudgetLabel.text = "挑战备货 %d / %d" % [int(_analysis.get("spent_budget", 0)), _budget]
	$Header/CoverageLabel.text = "展示柜占格 %d / %d" % [
		get_occupied_cell_count(),
		_unlocked_cells.size()
	]
	var errors: Array = _analysis.get("errors", [])
	$RiskLabel.text = String(errors[0]) if not errors.is_empty() else _risk_summary


func _refresh_relations() -> void:
	var relations: Array = _analysis.get("relations", [])
	var relation: Dictionary = _encounter.get("relation", {})
	var left_tag := _tag_name(String(relation.get("left_tag", "")))
	var right_tag := _tag_name(String(relation.get("right_tag", "")))
	var pair_text := "%s × %s" % [left_tag, right_tag]
	if relations.is_empty():
		$RelationSummary.text = (
			"[color=#9e94b6]相邻加成：未触发｜把「%s」和「%s」上下左右贴边[/color]" % [
				left_tag,
				right_tag
			]
			if not left_tag.is_empty() and not right_tag.is_empty()
			else "[color=#9e94b6]相邻加成：本场无标签配对规则[/color]"
		)
	else:
		var bonus_pct := int(relations[0].get("bonus_pct", 0))
		$RelationSummary.text = (
			"[color=#72d6a0][b]相邻加成：%s 已触发 %d 组[/b][/color]  两边配方每次售卖 +%d%% 满足力" % [
				pair_text,
				relations.size(),
				bonus_pct
			]
		)


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
			var icon_host := Control.new()
			icon_host.name = "IconHost"
			icon_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_host.clip_contents = false
			cell.add_child(icon_host)
			var icon := TextureRect.new()
			icon.name = "Icon"
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.z_index = 5
			icon_host.add_child(icon)
			$BoardFrame/BoardGrid.add_child(cell)


func _refresh_cells() -> void:
	_layout_refresh_queued = false
	var grid: GridContainer = $BoardFrame/BoardGrid
	for child in grid.get_children():
		var row := int(child.get_meta("row", 0))
		var column := int(child.get_meta("column", 0))
		child.set_meta("instance_id", "")
		var icon: TextureRect = child.get_node("IconHost/Icon")
		icon.texture = null
		icon.position = Vector2.ZERO
		icon.size = Vector2.ZERO
		var unlocked := _unlocked_keys.has(_cell_key(row, column))
		child.add_theme_stylebox_override(
			"panel",
			_cell_style(row, column, false, false) if unlocked else _hidden_cell_style()
		)

	var preview_cells := _cell_keys(_expansion_preview.get("cells", []))
	if not preview_cells.is_empty():
		for child in grid.get_children():
			var row := int(child.get_meta("row", 0))
			var column := int(child.get_meta("column", 0))
			if preview_cells.has(_cell_key(row, column)):
				child.add_theme_stylebox_override(
					"panel",
					_expansion_preview_style(bool(_expansion_preview.get("valid", false)))
				)

	var relation_instances := {}
	for relation in _analysis.get("relations", []):
		relation_instances[String(relation.get("left_instance_id", ""))] = true
		relation_instances[String(relation.get("right_instance_id", ""))] = true
	for instance_value in _analysis.get("instances", []):
		var instance: Dictionary = instance_value
		var instance_id := String(instance.get("instance_id", ""))
		var absolute_cells: Array[Vector2i] = []
		var icon_origin := Vector2i(ROWS, COLUMNS)
		for cell_value in instance.get("cells", []):
			var absolute_cell := Vector2i(int(cell_value[0]), int(cell_value[1]))
			absolute_cells.append(absolute_cell)
			icon_origin.x = mini(icon_origin.x, absolute_cell.x)
			icon_origin.y = mini(icon_origin.y, absolute_cell.y)
		var local_cells: Array[Vector2i] = []
		for absolute_cell in absolute_cells:
			local_cells.append(absolute_cell - icon_origin)
		var icon_layout := _showcase_icons.layout_for_shape(
			String(instance.get("recipe_id", "")),
			"standard",
			local_cells,
			0
		)
		var full_texture: Texture2D = _showcase_icons.layout_texture(icon_layout)
		if full_texture == null:
			full_texture = RecipeIconService.texture(
			String(instance.get("recipe_id", "")),
			0,
			"base"
		)
		for absolute_cell in absolute_cells:
			var row := absolute_cell.x
			var column := absolute_cell.y
			var cell_index := row * COLUMNS + column
			if cell_index < 0 or cell_index >= grid.get_child_count():
				continue
			var cell: PanelContainer = grid.get_child(cell_index)
			cell.set_meta("instance_id", instance_id)
			cell.add_theme_stylebox_override("panel", _cell_style(row, column, true, relation_instances.has(instance_id)))
		var origin_index := icon_origin.x * COLUMNS + icon_origin.y
		if origin_index < 0 or origin_index >= grid.get_child_count():
			continue
		var origin_cell: PanelContainer = grid.get_child(origin_index)
		var icon_host: Control = origin_cell.get_node("IconHost")
		var full_icon: TextureRect = icon_host.get_node("Icon")
		full_icon.texture = full_texture
		full_icon.position = Vector2.ZERO
		full_icon.size = _full_icon_size(icon_origin, local_cells)


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


func _hidden_cell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	style.set_border_width_all(0)
	return style


func _expansion_preview_style(valid: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3EB48988") if valid else Color("#EF476F88")
	style.border_color = Color("#72D6A0") if valid else Color("#EF476F")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _full_icon_size(
	icon_origin: Vector2i,
	local_cells: Array[Vector2i]
) -> Vector2:
	var max_row := 0
	var max_column := 0
	for cell in local_cells:
		max_row = maxi(max_row, cell.x)
		max_column = maxi(max_column, cell.y)
	var grid: GridContainer = $BoardFrame/BoardGrid
	var origin_index := icon_origin.x * COLUMNS + icon_origin.y
	var far_index := (
		(icon_origin.x + max_row) * COLUMNS
		+ icon_origin.y
		+ max_column
	)
	if (
		origin_index < 0
		or far_index < 0
		or origin_index >= grid.get_child_count()
		or far_index >= grid.get_child_count()
	):
		return Vector2(CELL_SIZE - 10, CELL_SIZE - 10)
	var origin_cell := grid.get_child(origin_index) as Control
	var far_cell := grid.get_child(far_index) as Control
	if origin_cell == null or far_cell == null:
		return Vector2(CELL_SIZE - 10, CELL_SIZE - 10)
	return (
		far_cell.position
		+ far_cell.size
		- origin_cell.position
		- Vector2(10, 10)
	)


func _queue_layout_refresh() -> void:
	if _layout_refresh_queued or not is_node_ready():
		return
	_layout_refresh_queued = true
	_refresh_cells.call_deferred()


func _gui_input(event: InputEvent) -> void:
	if _locked:
		return
	if not _expansion_product_id.is_empty():
		if event is InputEventMouseMotion:
			_update_expansion_preview(_cell_at_global(get_global_mouse_position()))
		elif (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):
			_update_expansion_preview(_cell_at_global(get_global_mouse_position()))
			if bool(_expansion_preview.get("valid", false)):
				expansion_placement_requested.emit(
					_expansion_product_id,
					_expansion_rotation,
					_expansion_anchor
				)
			accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var instance_id := _instance_at_global(get_global_mouse_position())
		if not instance_id.is_empty():
			rotate_instance(instance_id)
			accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _locked or not _expansion_product_id.is_empty():
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
	if _locked or not _expansion_product_id.is_empty() or not data is Dictionary:
		return false
	if not ["challenge_recipe", "challenge_instance"].has(String(data.get("kind", ""))):
		return false
	var cell := _cell_at_global(global_position + at_position)
	return cell != Vector2i(-1, -1) and _unlocked_keys.has(_cell_key(cell.x, cell.y))


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


func _update_expansion_preview(anchor: Vector2i) -> void:
	_expansion_anchor = anchor
	if anchor == Vector2i(-1, -1) or _expansion_product_id.is_empty():
		_expansion_preview = {}
	else:
		_expansion_preview = _expansion_service.preview(
			_expansion_meta,
			_expansion_product_id,
			_expansion_rotation,
			anchor
		)
	_refresh_cells()


func _cell_keys(cells: Array) -> Dictionary:
	var result := {}
	for value in cells:
		if value is Array and value.size() >= 2:
			result[_cell_key(int(value[0]), int(value[1]))] = true
	return result


func _cell_key(row: int, column: int) -> String:
	return "%d:%d" % [row, column]


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


func _tag_name(tag: String) -> String:
	return String(TAG_NAMES.get(tag, tag))
