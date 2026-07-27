class_name ShowcaseRegionService
extends RefCounted

const DEFAULT_GRID_ROWS := 12
const DEFAULT_GRID_COLUMNS := 14
const FRONT_RATIO := 0.30
const BACK_RATIO_START := 0.70


static func default_bounds() -> Dictionary:
	return {
		"min_row": 5,
		"max_row": 8,
		"min_column": 6,
		"max_column": 9
	}


static func normalize_bounds(
		bounds: Dictionary,
		grid_rows: int = DEFAULT_GRID_ROWS,
		grid_columns: int = DEFAULT_GRID_COLUMNS
) -> Dictionary:
	var safe_rows := maxi(1, grid_rows)
	var safe_columns := maxi(1, grid_columns)
	var fallback := default_bounds()
	var min_row := clampi(int(bounds.get("min_row", fallback.min_row)), 1, safe_rows)
	var max_row := clampi(int(bounds.get("max_row", fallback.max_row)), 1, safe_rows)
	var min_column := clampi(int(bounds.get("min_column", fallback.min_column)), 1, safe_columns)
	var max_column := clampi(int(bounds.get("max_column", fallback.max_column)), 1, safe_columns)
	if min_row > max_row:
		var row_swap := min_row
		min_row = max_row
		max_row = row_swap
	if min_column > max_column:
		var column_swap := min_column
		min_column = max_column
		max_column = column_swap
	return {
		"min_row": min_row,
		"max_row": max_row,
		"min_column": min_column,
		"max_column": max_column
	}


static func resolve_regions(
		bounds: Dictionary,
		grid_rows: int = DEFAULT_GRID_ROWS,
		grid_columns: int = DEFAULT_GRID_COLUMNS
) -> Dictionary:
	var normalized := normalize_bounds(bounds, grid_rows, grid_columns)
	var row_segments := _axis_segments(int(normalized.min_row), int(normalized.max_row))
	var column_segments := _axis_segments(int(normalized.min_column), int(normalized.max_column))
	var row_count := int(normalized.max_row) - int(normalized.min_row) + 1
	var column_count := int(normalized.max_column) - int(normalized.min_column) + 1
	return {
		"bounds": normalized,
		"row_count": row_count,
		"column_count": column_count,
		"unlocked_count": row_count * column_count,
		"front_rows": row_segments.front,
		"middle_rows": row_segments.middle,
		"back_rows": row_segments.back,
		"golden_rows": (row_segments.middle as Array).duplicate(),
		"golden_columns": (column_segments.middle as Array).duplicate()
	}


static func resolve_regions_for_cells(
		unlocked_cells: Array,
		grid_rows: int = DEFAULT_GRID_ROWS,
		grid_columns: int = DEFAULT_GRID_COLUMNS
) -> Dictionary:
	var cells := normalize_cells(unlocked_cells, grid_rows, grid_columns)
	var effective_rows: Array[int] = []
	var effective_columns: Array[int] = []
	for cell in cells:
		if not effective_rows.has(cell.x): effective_rows.append(cell.x)
		if not effective_columns.has(cell.y): effective_columns.append(cell.y)
	effective_rows.sort()
	effective_columns.sort()
	var row_segments := _axis_segments_for_values(effective_rows)
	var column_segments := _axis_segments_for_values(effective_columns)
	return {
		"bounds": bounds_for_cells(cells),
		"row_count": effective_rows.size(),
		"column_count": effective_columns.size(),
		"unlocked_count": cells.size(),
		"effective_rows": effective_rows,
		"effective_columns": effective_columns,
		"front_rows": row_segments.front,
		"middle_rows": row_segments.middle,
		"back_rows": row_segments.back,
		"golden_rows": (row_segments.middle as Array).duplicate(),
		"golden_columns": (column_segments.middle as Array).duplicate()
	}


static func normalize_cells(unlocked_cells: Array, grid_rows: int = DEFAULT_GRID_ROWS, grid_columns: int = DEFAULT_GRID_COLUMNS) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_value in unlocked_cells:
		if not cell_value is Vector2i: continue
		var cell: Vector2i = cell_value
		if cell.x < 1 or cell.x > grid_rows or cell.y < 1 or cell.y > grid_columns or result.has(cell): continue
		result.append(cell)
	result.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		return left.x < right.x or left.x == right.x and left.y < right.y
	)
	return result


static func cells_for_bounds(bounds: Dictionary, grid_rows: int = DEFAULT_GRID_ROWS, grid_columns: int = DEFAULT_GRID_COLUMNS) -> Array[Vector2i]:
	var normalized := normalize_bounds(bounds, grid_rows, grid_columns)
	var result: Array[Vector2i] = []
	for row in range(int(normalized.min_row), int(normalized.max_row) + 1):
		for column in range(int(normalized.min_column), int(normalized.max_column) + 1): result.append(Vector2i(row, column))
	return result


static func bounds_for_cells(unlocked_cells: Array) -> Dictionary:
	var cells := normalize_cells(unlocked_cells)
	if cells.is_empty(): return default_bounds()
	var min_row := DEFAULT_GRID_ROWS
	var max_row := 1
	var min_column := DEFAULT_GRID_COLUMNS
	var max_column := 1
	for cell in cells:
		min_row = mini(min_row, cell.x)
		max_row = maxi(max_row, cell.x)
		min_column = mini(min_column, cell.y)
		max_column = maxi(max_column, cell.y)
	return {"min_row": min_row, "max_row": max_row, "min_column": min_column, "max_column": max_column}


static func is_cell_unlocked(
		cell: Vector2i,
		bounds: Dictionary,
		grid_rows: int = DEFAULT_GRID_ROWS,
		grid_columns: int = DEFAULT_GRID_COLUMNS
) -> bool:
	var normalized := normalize_bounds(bounds, grid_rows, grid_columns)
	return cell.x >= int(normalized.min_row) \
		and cell.x <= int(normalized.max_row) \
		and cell.y >= int(normalized.min_column) \
		and cell.y <= int(normalized.max_column)


static func zone_for_cell(
		cell: Vector2i,
		bounds: Dictionary,
		grid_rows: int = DEFAULT_GRID_ROWS,
		grid_columns: int = DEFAULT_GRID_COLUMNS
) -> String:
	if not is_cell_unlocked(cell, bounds, grid_rows, grid_columns):
		return "locked"
	var layout := resolve_regions(bounds, grid_rows, grid_columns)
	if (layout.front_rows as Array).has(cell.x):
		return "front"
	if (layout.back_rows as Array).has(cell.x):
		return "back"
	if (layout.golden_rows as Array).has(cell.x) and (layout.golden_columns as Array).has(cell.y):
		return "golden"
	return "middle"


static func zone_for_cells(
		cells: Array,
		bounds: Dictionary,
		grid_rows: int = DEFAULT_GRID_ROWS,
		grid_columns: int = DEFAULT_GRID_COLUMNS
) -> String:
	if cells.is_empty():
		return ""
	var shared_zone := ""
	for cell_value in cells:
		if not cell_value is Vector2i:
			return ""
		var cell_zone := zone_for_cell(cell_value as Vector2i, bounds, grid_rows, grid_columns)
		if cell_zone == "locked":
			return ""
		if shared_zone.is_empty():
			shared_zone = cell_zone
		elif cell_zone != shared_zone:
			return ""
	return shared_zone


static func zone_for_cell_in_cells(cell: Vector2i, unlocked_cells: Array) -> String:
	var cells := normalize_cells(unlocked_cells)
	if not cells.has(cell): return "locked"
	var layout := resolve_regions_for_cells(cells)
	if (layout.front_rows as Array).has(cell.x): return "front"
	if (layout.back_rows as Array).has(cell.x): return "back"
	if (layout.golden_rows as Array).has(cell.x) and (layout.golden_columns as Array).has(cell.y): return "golden"
	return "middle"


static func zone_for_cells_in_cells(cells_value: Array, unlocked_cells: Array) -> String:
	if cells_value.is_empty(): return ""
	var shared_zone := ""
	for cell_value in cells_value:
		if not cell_value is Vector2i: return ""
		var zone := zone_for_cell_in_cells(cell_value, unlocked_cells)
		if zone == "locked": return ""
		if shared_zone.is_empty(): shared_zone = zone
		elif shared_zone != zone: return ""
	return shared_zone


static func _axis_segments(axis_min: int, axis_max: int) -> Dictionary:
	var front: Array[int] = []
	var middle: Array[int] = []
	var back: Array[int] = []
	var count := maxi(1, axis_max - axis_min + 1)
	for local_index in range(count):
		var value := axis_min + local_index
		var ratio := (float(local_index) + 0.5) / float(count)
		if ratio < FRONT_RATIO:
			front.append(value)
		elif ratio > BACK_RATIO_START:
			back.append(value)
		else:
			middle.append(value)

	# Very small rectangles cannot have three disjoint bands. Keep every
	# advertised band addressable while functional-zone precedence remains
	# front -> back -> golden/middle in zone_for_cell().
	if front.is_empty():
		front.append(axis_min)
	if back.is_empty():
		back.append(axis_max)
	if middle.is_empty():
		middle.append(axis_min + int((count - 1) / 2))
	return {"front": front, "middle": middle, "back": back}


static func _axis_segments_for_values(values: Array[int]) -> Dictionary:
	if values.is_empty(): return {"front": [], "middle": [], "back": []}
	var front: Array[int] = []
	var middle: Array[int] = []
	var back: Array[int] = []
	for index in range(values.size()):
		var ratio := (float(index) + 0.5) / float(values.size())
		if ratio < FRONT_RATIO: front.append(values[index])
		elif ratio > BACK_RATIO_START: back.append(values[index])
		else: middle.append(values[index])
	if front.is_empty(): front.append(values.front())
	if back.is_empty(): back.append(values.back())
	if middle.is_empty(): middle.append(values[int((values.size() - 1) / 2)])
	return {"front": front, "middle": middle, "back": back}
