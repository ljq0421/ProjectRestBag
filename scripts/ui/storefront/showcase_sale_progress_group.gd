extends Control

@export var fill_color := Color(0.941176, 0.392157, 0.0, 0.45)
@export var edge_color := Color(1.0, 0.878431, 0.541176, 1.0)
@export var edge_width := 2.0

var recipe_id := ""
var cell_rects: Array[Rect2] = []
var fill_rects: Array[Rect2] = []
var edge_segments: Array[Vector2] = []
var completion_edge_segments: Array[Vector2] = []
var liquid_y := 0.0
var completion_liquid_y := 0.0

var _progress := 0.0
var _active := false
var _completion_active := false
var _completion_alpha := 0.0
var _completion_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func configure(product_recipe_id: String, source_cell_rects: Array, progress: float, active: bool) -> void:
	recipe_id = product_recipe_id
	_progress = clampf(progress, 0.0, 1.0)
	_active = active
	_set_cell_rects(source_cell_rects)
	_rebuild_draw_geometry()
	visible = (active and not cell_rects.is_empty()) or _completion_active
	queue_redraw()


func play_sale_complete_feedback() -> void:
	if cell_rects.is_empty():
		return
	if _completion_tween != null and _completion_tween.is_valid():
		_completion_tween.kill()
	_completion_active = true
	_completion_alpha = 1.0
	completion_edge_segments.clear()
	completion_edge_segments.append_array(edge_segments)
	completion_liquid_y = liquid_y
	visible = true
	queue_redraw()
	_completion_tween = create_tween()
	_completion_tween.tween_method(_set_completion_alpha, 1.0, 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_completion_tween.tween_callback(_finish_sale_complete_feedback)


func clear_feedback() -> void:
	if _completion_tween != null and _completion_tween.is_valid():
		_completion_tween.kill()
	_completion_tween = null
	_completion_active = false
	_completion_alpha = 0.0
	completion_edge_segments.clear()
	_active = false
	visible = false
	queue_redraw()


func _set_cell_rects(source_cell_rects: Array) -> void:
	cell_rects.clear()
	var valid_rects: Array[Rect2] = []
	for source_rect_value in source_cell_rects:
		if source_rect_value is Rect2 and (source_rect_value as Rect2).size.x > 0.0 and (source_rect_value as Rect2).size.y > 0.0:
			valid_rects.append(source_rect_value as Rect2)
	if valid_rects.is_empty():
		position = Vector2.ZERO
		size = Vector2.ZERO
		return
	var bounds := valid_rects[0]
	for source_rect in valid_rects:
		bounds = bounds.merge(source_rect)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		position = Vector2.ZERO
		size = Vector2.ZERO
		return
	position = bounds.position
	size = bounds.size
	for source_rect in valid_rects:
		cell_rects.append(Rect2(source_rect.position - bounds.position, source_rect.size))


func _rebuild_draw_geometry() -> void:
	fill_rects.clear()
	edge_segments.clear()
	if cell_rects.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		liquid_y = 0.0
		return
	liquid_y = size.y * (1.0 - _progress)
	if _active and _progress > 0.0:
		var liquid_rect := Rect2(0.0, liquid_y, size.x, size.y - liquid_y)
		for cell_rect in cell_rects:
			var fill_rect := cell_rect.intersection(liquid_rect)
			if fill_rect.size.x > 0.0 and fill_rect.size.y > 0.0:
				fill_rects.append(fill_rect)
		_build_edge_segments()


func _build_edge_segments() -> void:
	var segments: Array[Vector2] = []
	for cell_rect in cell_rects:
		var cell_bottom := cell_rect.position.y + cell_rect.size.y
		if liquid_y < cell_rect.position.y - 0.01 or liquid_y >= cell_bottom - 0.01:
			continue
		segments.append(Vector2(cell_rect.position.x, cell_rect.position.x + cell_rect.size.x))
	segments.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for segment in segments:
		if edge_segments.is_empty() or segment.x > edge_segments[-1].y + 0.01:
			edge_segments.append(segment)
		else:
			edge_segments[-1].y = maxf(edge_segments[-1].y, segment.y)


func _draw() -> void:
	if _active:
		for fill_rect in fill_rects:
			draw_rect(fill_rect, fill_color)
		for segment in edge_segments:
			draw_line(Vector2(segment.x, liquid_y), Vector2(segment.y, liquid_y), edge_color, edge_width)
	if _completion_active and _completion_alpha > 0.0:
		var pulse_color := edge_color
		pulse_color.a *= _completion_alpha
		for segment in completion_edge_segments:
			draw_line(Vector2(segment.x, completion_liquid_y), Vector2(segment.y, completion_liquid_y), pulse_color, edge_width * 2.0)


func _set_completion_alpha(value: float) -> void:
	_completion_alpha = value
	queue_redraw()


func _finish_sale_complete_feedback() -> void:
	_completion_active = false
	_completion_alpha = 0.0
	completion_edge_segments.clear()
	_completion_tween = null
	visible = _active and not cell_rects.is_empty()
	queue_redraw()
