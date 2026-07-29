extends SceneTree

const MenuService = preload("res://scripts/challenge/challenge_menu_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	var service = MenuService.new()
	var ids: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h", "i"]
	var starters: Array[String] = ["a", "b", "c", "d", "e", "f"]
	var defs := {}
	for recipe_id in ids:
		defs[recipe_id] = {
			"build_roles": ["tempo"],
			"tags": ["fast"],
			"shape_cells": [[0, 0]],
			"cycle_seconds": 5
		}
	var meta := service.bootstrap_meta({}, ids, starters)
	_expect(meta.get("active_menu_recipe_ids", []) == starters, "new profile should default to six starter recipes")
	_expect(bool(service.validate_menu(["a", "b", "c", "d"], ids, defs).get("valid", false)), "four recipes should be valid")
	_expect(bool(service.validate_menu(ids.slice(0, 8), ids, defs).get("valid", false)), "eight recipes should be valid")
	_expect(not bool(service.validate_menu(["a", "b", "c"], ids, defs).get("valid", true)), "three recipes should be rejected")
	_expect(not bool(service.validate_menu(ids, ids, defs).get("valid", true)), "nine recipes should be rejected")
	_expect(not bool(service.validate_menu(["a", "a", "b", "c"], ids, defs).get("valid", true)), "duplicates should be rejected")
	_expect(not bool(service.validate_menu(["a", "b", "c", "locked"], ids, defs).get("valid", true)), "locked recipes should be rejected")
	var changed := service.set_active_menu(meta, ["a", "b", "c", "d", "g"], ids, defs)
	_expect(bool(changed.get("applied", false)), "valid menu should apply")
	_expect(changed.get("recipe_ids", []) == ["a", "b", "c", "d", "g"], "menu order should be stable")
	var large_ids: Array[String] = []
	var large_defs := {}
	for index in range(166):
		var recipe_id := "recipe_%03d" % index
		large_ids.append(recipe_id)
		large_defs[recipe_id] = {
			"build_roles": ["tempo"],
			"tags": ["fast"],
			"shape_cells": [[0, 0]],
			"cycle_seconds": 5
		}
	_expect(
		bool(service.validate_menu(large_ids.slice(0, 8), large_ids, large_defs).get("valid", false)),
		"166-recipe permanent collection should still accept an eight-recipe active menu"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_MENU_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
