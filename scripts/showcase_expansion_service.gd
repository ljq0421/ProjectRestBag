class_name ShowcaseExpansionService
extends RefCounted

const GRID_ROWS := 12
const GRID_COLUMNS := 14
const INITIAL_UNLOCKED_COUNT := 16

static func max_unlocked_cells_for_level(level: int) -> int:
	if level < 2: return 16
	if level == 2: return 36
	if level == 3: return 64
	if level == 4: return 100
	if level == 5: return 144
	return 168

static func cell_price(purchase_index: int) -> int:
	return 300 + maxi(0, purchase_index - 1) * 10

static func quote(unlocked_count: int, purchase_count: int) -> Dictionary:
	var count := maxi(0, purchase_count)
	var first_index := maxi(1, unlocked_count - INITIAL_UNLOCKED_COUNT + 1)
	var total := 0
	for offset in range(count): total += cell_price(first_index + offset)
	return {
		"count": count,
		"first_price": cell_price(first_index) if count > 0 else 0,
		"last_price": cell_price(first_index + count - 1) if count > 0 else 0,
		"total_cost": total
	}

static func can_add_cell(unlocked: Array, selected: Array, cell: Vector2i) -> bool:
	if not _in_grid(cell) or unlocked.has(cell) or selected.has(cell): return false
	for neighbor in _neighbors(cell):
		if unlocked.has(neighbor) or selected.has(neighbor): return true
	return false

static func is_connected_purchase(unlocked: Array, selected: Array) -> bool:
	if unlocked.is_empty() or selected.is_empty(): return false
	var allowed := {}
	for cell_value in unlocked:
		if cell_value is Vector2i and _in_grid(cell_value): allowed[cell_value] = true
	for cell_value in selected:
		if not cell_value is Vector2i or not _in_grid(cell_value) or allowed.has(cell_value): return false
		allowed[cell_value] = true
	var pending: Array[Vector2i] = [allowed.keys()[0]]
	var visited := {pending[0]: true}
	while not pending.is_empty():
		var current: Vector2i = pending.pop_front()
		for neighbor in _neighbors(current):
			if allowed.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	return visited.size() == allowed.size()

static func row_candidates(unlocked: Array, row: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if row < 1 or row > GRID_ROWS: return result
	for column in range(1, GRID_COLUMNS + 1):
		var cell := Vector2i(row, column)
		if not unlocked.has(cell) and _touches_unlocked(cell, unlocked): result.append(cell)
	return result

static func column_candidates(unlocked: Array, column: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if column < 1 or column > GRID_COLUMNS: return result
	for row in range(1, GRID_ROWS + 1):
		var cell := Vector2i(row, column)
		if not unlocked.has(cell) and _touches_unlocked(cell, unlocked): result.append(cell)
	return result

static func _touches_unlocked(cell: Vector2i, unlocked: Array) -> bool:
	for neighbor in _neighbors(cell):
		if unlocked.has(neighbor): return true
	return false

static func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [cell + Vector2i.UP, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.LEFT]

static func _in_grid(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= GRID_ROWS and cell.y >= 1 and cell.y <= GRID_COLUMNS
