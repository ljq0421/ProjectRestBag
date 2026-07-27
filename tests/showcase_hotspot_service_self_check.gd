extends SceneTree

const Service = preload("res://scripts/showcase_hotspot_service.gd")

func _init() -> void:
	var bounds := {"min_row": 5, "max_row": 8, "min_column": 6, "max_column": 9}
	var first: Dictionary = Service.generate(77, 3, bounds)
	var again: Dictionary = Service.generate(77, 3, bounds)
	if first != again or (first.get("cells", []) as Array).is_empty():
		push_error("hotspot should be deterministic and affect unlocked cells")
		quit(1)
		return
	var irregular_cells := [Vector2i(5, 6), Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8)]
	var irregular: Dictionary = Service.generate_for_cells(77, 3, irregular_cells)
	for cell_value in irregular.get("cells", []):
		if not irregular_cells.has(cell_value):
			push_error("hotspot should never include a locked hole from an irregular layout")
			quit(1)
			return
	var display_items := {"cake": {"cells": [(first.get("cells", []) as Array)[0]]}, "other": {"cells": [Vector2i(99, 99)]}}
	var terms := {"cake": {"unit_price": 100, "duration_seconds": 10}, "other": {"unit_price": 100, "duration_seconds": 10}}
	var applied: Dictionary = Service.apply_to_terms(terms, display_items, first)
	var cake: Dictionary = applied.get("cake", {})
	var other: Dictionary = applied.get("other", {})
	if (cake.get("hotspot_reasons", []) as Array).is_empty() or cake == terms.get("cake", {}):
		push_error("overlapping product should receive an attributed hotspot effect")
		quit(1)
		return
	if other != terms.get("other", {}):
		push_error("non-overlapping product should not receive hotspot effect")
		quit(1)
		return
	print("SHOWCASE_HOTSPOT_SERVICE_SELF_CHECK_PASS")
	quit(0)
