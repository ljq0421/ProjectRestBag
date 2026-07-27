class_name ShowcaseHotspotService
extends RefCounted

const ShowcaseRegionService = preload("res://scripts/showcase_region_service.gd")

static func generate(seed: int, round_id: int, bounds: Dictionary) -> Dictionary:
	return generate_for_cells(seed, round_id, ShowcaseRegionService.cells_for_bounds(bounds))


static func generate_for_cells(seed: int, round_id: int, unlocked_cells: Array) -> Dictionary:
	var normalized := ShowcaseRegionService.normalize_cells(unlocked_cells)
	if normalized.is_empty():
		return {"round_id": round_id, "id": "none", "type": "none", "label": "", "price_pct": 0.0, "speed_pct": 0.0, "cells": []}
	var selector := absi(seed * 31 + round_id * 17) % 3
	var anchor: Vector2i = normalized[absi(seed + round_id * 7) % normalized.size()]
	var cells: Array[Vector2i] = []
	var result := {"round_id": round_id, "price_pct": 0.0, "speed_pct": 0.0}
	match selector:
		0:
			for cell in normalized:
				if cell.x == anchor.x: cells.append(cell)
			result.merge({"id": "traffic_row", "type": "traffic", "label": "客流热排", "price_pct": 0.0, "speed_pct": 10.0})
		1:
			for current_row in range(anchor.x, mini(12, anchor.x + 1) + 1):
				for current_column in range(anchor.y, mini(14, anchor.y + 1) + 1):
					var cell := Vector2i(current_row, current_column)
					if normalized.has(cell): cells.append(cell)
			result.merge({"id": "quality_corner", "type": "quality", "label": "品质聚光", "price_pct": 8.0, "speed_pct": 0.0})
		_:
			for cell in normalized:
				if cell.x == anchor.x: cells.append(cell)
			result.merge({"id": "congestion_row", "type": "congestion", "label": "拥挤客流", "price_pct": 3.0, "speed_pct": -6.0})
	result["cells"] = cells
	return result

static func apply_to_terms(terms: Dictionary, display_items: Dictionary, hotspot: Dictionary) -> Dictionary:
	var result := terms.duplicate(true)
	var hotspot_cells: Array = hotspot.get("cells", [])
	for recipe_id_value in result.keys():
		var item: Dictionary = display_items.get(recipe_id_value, {})
		if not _overlaps(item.get("cells", []), hotspot_cells): continue
		var term: Dictionary = result.get(recipe_id_value, {})
		var price_pct := float(hotspot.get("price_pct", 0.0))
		var speed_pct := float(hotspot.get("speed_pct", 0.0))
		term["unit_price"] = maxi(0, int(round(float(term.get("unit_price", 0)) * (1.0 + price_pct / 100.0))))
		term["duration_seconds"] = maxi(1, int(round(float(term.get("duration_seconds", 1)) / maxf(0.2, 1.0 + speed_pct / 100.0))))
		var reason := "%s：售价 %+.0f%%，售速 %+.0f%%" % [String(hotspot.get("label", "动态热点")), price_pct, speed_pct]
		var hotspot_reasons: Array = term.get("hotspot_reasons", [])
		hotspot_reasons.append(reason)
		term["hotspot_reasons"] = hotspot_reasons
		var environment_reasons: Array = term.get("environment_reasons", [])
		environment_reasons.append(reason)
		term["environment_reasons"] = environment_reasons
		result[recipe_id_value] = term
	return result

static func _overlaps(left: Variant, right: Array) -> bool:
	if not left is Array: return false
	for cell in left:
		if right.has(cell): return true
	return false
