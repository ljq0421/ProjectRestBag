class_name ChallengeBoardExpansionService
extends RefCounted

const ChallengeLoadoutService = preload("res://scripts/challenge/challenge_loadout_service.gd")

const MAX_ROWS := 8
const MAX_COLUMNS := 14
const INITIAL_TOP := 2
const INITIAL_LEFT := 5
const INITIAL_ROWS := 4
const INITIAL_COLUMNS := 4

const PRODUCTS := {
	"single_1": {
		"id": "single_1",
		"display_name": "单格",
		"price": 1,
		"shape_cells": [[0, 0]]
	},
	"bar_2": {
		"id": "bar_2",
		"display_name": "长条 2 格",
		"price": 2,
		"shape_cells": [[0, 0], [1, 0]]
	},
	"bar_3": {
		"id": "bar_3",
		"display_name": "长条 3 格",
		"price": 3,
		"shape_cells": [[0, 0], [1, 0], [2, 0]]
	},
	"l_3": {
		"id": "l_3",
		"display_name": "L 形 3 格",
		"price": 3,
		"shape_cells": [[0, 0], [0, 1], [1, 1]]
	},
	"l_4": {
		"id": "l_4",
		"display_name": "L 形 4 格",
		"price": 4,
		"shape_cells": [[0, 0], [0, 1], [0, 2], [1, 2]]
	},
	"square_4": {
		"id": "square_4",
		"display_name": "方形 2×2",
		"price": 4,
		"shape_cells": [[0, 0], [1, 0], [0, 1], [1, 1]]
	}
}

const PRODUCT_ORDER := ["single_1", "bar_2", "bar_3", "l_3", "l_4", "square_4"]


func default_state() -> Dictionary:
	var cells: Array = []
	for row in range(INITIAL_TOP, INITIAL_TOP + INITIAL_ROWS):
		for column in range(INITIAL_LEFT, INITIAL_LEFT + INITIAL_COLUMNS):
			cells.append([row, column])
	return {
		"max_rows": MAX_ROWS,
		"max_columns": MAX_COLUMNS,
		"unlocked_cells": cells
	}


func bootstrap_meta(meta: Dictionary) -> Dictionary:
	var result := meta.duplicate(true)
	if not _valid_state(result.get("board_expansion")):
		result["board_expansion"] = default_state()
	if not _is_non_negative_integer(result.get("expansion_tickets")):
		result["expansion_tickets"] = 0
	if not result.get("expansion_ticket_reward_ids") is Array:
		result["expansion_ticket_reward_ids"] = []
	return result


func products() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for product_id in PRODUCT_ORDER:
		result.append((PRODUCTS[product_id] as Dictionary).duplicate(true))
	return result


func unlocked_cells(meta: Dictionary) -> Array:
	var state: Dictionary = bootstrap_meta(meta).get("board_expansion", {})
	return (state.get("unlocked_cells", []) as Array).duplicate(true)


func rotated_shape(product_id: String, rotation: int) -> Array[Vector2i]:
	if not PRODUCTS.has(product_id):
		return []
	var product: Dictionary = PRODUCTS[product_id]
	var turns := int(posmod(rotation, 360) / 90)
	var cells: Array[Vector2i] = []
	for value in product.get("shape_cells", []):
		if not value is Array or value.size() < 2:
			continue
		var cell := Vector2i(int(value[1]), int(value[0]))
		for _turn in range(turns):
			cell = Vector2i(cell.y, -cell.x)
		cells.append(cell)
	return _normalize(cells)


func preview(meta: Dictionary, product_id: String, rotation: int, anchor: Vector2i) -> Dictionary:
	if not PRODUCTS.has(product_id):
		return {"valid": false, "error": "未知扩建形状", "cells": []}
	var shape := rotated_shape(product_id, rotation)
	var existing := _cell_keys(unlocked_cells(meta))
	var candidate: Array = []
	var touches_board := false
	for offset in shape:
		var cell := anchor + offset
		candidate.append([cell.x, cell.y])
		if cell.x < 0 or cell.x >= MAX_ROWS or cell.y < 0 or cell.y >= MAX_COLUMNS:
			return {"valid": false, "error": "扩建范围超出预留区域", "cells": candidate}
		var key := _key(cell.x, cell.y)
		if existing.has(key):
			return {"valid": false, "error": "扩建格与已解锁区域重叠", "cells": candidate}
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor: Vector2i = cell + direction
			if existing.has(_key(neighbor.x, neighbor.y)):
				touches_board = true
	if not touches_board:
		return {"valid": false, "error": "扩建区域必须与现有棋盘上下左右相连", "cells": candidate}
	return {"valid": true, "cells": candidate}


func purchase(meta: Dictionary, product_id: String, rotation: int, anchor: Vector2i) -> Dictionary:
	var result_meta := bootstrap_meta(meta)
	if not PRODUCTS.has(product_id):
		return {"applied": false, "meta": result_meta, "error": "未知扩建形状"}
	var price := int((PRODUCTS[product_id] as Dictionary).get("price", 0))
	if int(result_meta.get("expansion_tickets", 0)) < price:
		return {"applied": false, "meta": result_meta, "error": "扩建券不足"}
	var checked := preview(result_meta, product_id, rotation, anchor)
	if not bool(checked.get("valid", false)):
		return {
			"applied": false,
			"meta": result_meta,
			"error": String(checked.get("error", "扩建位置无效"))
		}
	var state: Dictionary = result_meta.get("board_expansion", {}).duplicate(true)
	var next_cells: Array = (state.get("unlocked_cells", []) as Array).duplicate(true)
	next_cells.append_array((checked.get("cells", []) as Array).duplicate(true))
	next_cells.sort_custom(_sort_cell)
	state["unlocked_cells"] = next_cells
	result_meta["board_expansion"] = state
	result_meta["expansion_tickets"] = int(result_meta.get("expansion_tickets", 0)) - price
	return {
		"applied": true,
		"meta": result_meta,
		"cells": (checked.get("cells", []) as Array).duplicate(true),
		"price": price,
		"product_id": product_id
	}


func grant_ticket(meta: Dictionary, reward_id: String) -> Dictionary:
	var result_meta := bootstrap_meta(meta)
	var ids: Array = (result_meta.get("expansion_ticket_reward_ids", []) as Array).duplicate()
	if reward_id.is_empty() or ids.has(reward_id):
		return {"applied": false, "meta": result_meta, "tickets_granted": 0}
	ids.append(reward_id)
	result_meta["expansion_ticket_reward_ids"] = ids
	result_meta["expansion_tickets"] = int(result_meta.get("expansion_tickets", 0)) + 1
	return {"applied": true, "meta": result_meta, "tickets_granted": 1}


func pack_draft(draft: Dictionary, recipe_defs: Dictionary, meta: Dictionary) -> Dictionary:
	var unlocked := unlocked_cells(meta)
	var available := _cell_keys(unlocked)
	var occupied := {}
	var source: Array = draft.get("placements", [])
	var packed: Array = []
	if _try_pack(source, 0, recipe_defs, unlocked, available, occupied, packed):
		return {"placements": packed}
	return draft.duplicate(true)


func _try_pack(
	placements: Array,
	index: int,
	recipe_defs: Dictionary,
	unlocked: Array,
	available: Dictionary,
	occupied: Dictionary,
	packed: Array
) -> bool:
	if index >= placements.size():
		return true
	if not placements[index] is Dictionary:
		return _try_pack(
			placements,
			index + 1,
			recipe_defs,
			unlocked,
			available,
			occupied,
			packed
		)
	var placement: Dictionary = placements[index]
	var recipe_id := String(placement.get("recipe_id", ""))
	var definition: Dictionary = recipe_defs.get(recipe_id, {})
	var shape: Array = definition.get("shape_cells", [])
	var rotations := [int(placement.get("rotation", 0))]
	if bool(definition.get("rotatable", false)):
		for rotation in [0, 90, 180, 270]:
			if not rotations.has(rotation):
				rotations.append(rotation)
	for rotation in rotations:
		var offsets := ChallengeLoadoutService.rotated_cells(shape, rotation)
		for anchor_value in unlocked:
			var anchor := Vector2i(int(anchor_value[0]), int(anchor_value[1]))
			if not _recipe_fits(anchor, offsets, available, occupied):
				continue
			var occupied_keys: Array[String] = []
			for offset in offsets:
				var cell := anchor + Vector2i(offset.y, offset.x)
				var key := _key(cell.x, cell.y)
				occupied[key] = true
				occupied_keys.append(key)
			var next := placement.duplicate(true)
			next["origin"] = [anchor.x, anchor.y]
			next["rotation"] = rotation
			packed.append(next)
			if _try_pack(
				placements,
				index + 1,
				recipe_defs,
				unlocked,
				available,
				occupied,
				packed
			):
				return true
			packed.pop_back()
			for key in occupied_keys:
				occupied.erase(key)
	return false


func _recipe_fits(
	anchor: Vector2i,
	offsets: Array[Vector2i],
	available: Dictionary,
	occupied: Dictionary
) -> bool:
	for offset in offsets:
		var cell := anchor + Vector2i(offset.y, offset.x)
		var key := _key(cell.x, cell.y)
		if not available.has(key) or occupied.has(key):
			return false
	return true


func _valid_state(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var state: Dictionary = value
	if int(state.get("max_rows", 0)) != MAX_ROWS or int(state.get("max_columns", 0)) != MAX_COLUMNS:
		return false
	var cells: Variant = state.get("unlocked_cells")
	if not cells is Array or cells.is_empty():
		return false
	var seen := {}
	for cell in cells:
		if not cell is Array or cell.size() < 2:
			return false
		var row := int(cell[0])
		var column := int(cell[1])
		if row < 0 or row >= MAX_ROWS or column < 0 or column >= MAX_COLUMNS:
			return false
		if seen.has(_key(row, column)):
			return false
		seen[_key(row, column)] = true
	return true


func _cell_keys(cells: Array) -> Dictionary:
	var result := {}
	for value in cells:
		if value is Array and value.size() >= 2:
			result[_key(int(value[0]), int(value[1]))] = true
	return result


func _normalize(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.is_empty():
		return cells
	var min_row := cells[0].x
	var min_column := cells[0].y
	for cell in cells:
		min_row = mini(min_row, cell.x)
		min_column = mini(min_column, cell.y)
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(cell - Vector2i(min_row, min_column))
	return result


func _key(row: int, column: int) -> String:
	return "%d:%d" % [row, column]


func _sort_cell(a: Array, b: Array) -> bool:
	return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1]))


func _is_non_negative_integer(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and int(value) == value and int(value) >= 0
