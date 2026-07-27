class_name RecipeIconService
extends RefCounted

const SURFACE_DIRECTORIES := {
	"base": "res://resources/recipe_icons",
	"catalog": "res://resources/recipe_icons_catalog",
	"inventory": "res://resources/recipe_icons_inventory",
	"action": "res://resources/recipe_icons_action",
}
const STAGE_SUFFIXES := ["", "_popular", "_signature"]


static func stage_suffix(mastery_level: int) -> String:
	return STAGE_SUFFIXES[clampi(mastery_level, 0, STAGE_SUFFIXES.size() - 1)]


static func candidate_paths(recipe_id: String, mastery_level: int, surface: String = "base") -> Array[String]:
	var paths: Array[String] = []
	if recipe_id.is_empty() or not SURFACE_DIRECTORIES.has(surface):
		return paths
	var stage_name := stage_suffix(mastery_level)
	var surface_directory := String(SURFACE_DIRECTORIES[surface])
	_append_unique(paths, "%s/%s%s.png" % [surface_directory, recipe_id, stage_name])
	_append_unique(paths, "%s/%s.png" % [surface_directory, recipe_id])
	var base_directory := String(SURFACE_DIRECTORIES["base"])
	_append_unique(paths, "%s/%s%s.png" % [base_directory, recipe_id, stage_name])
	_append_unique(paths, "%s/%s.png" % [base_directory, recipe_id])
	return paths


static func texture(recipe_id: String, mastery_level: int, surface: String = "base") -> Texture2D:
	for path in candidate_paths(recipe_id, mastery_level, surface):
		if not ResourceLoader.exists(path):
			continue
		var loaded := load(path) as Texture2D
		if loaded != null:
			return loaded
	return null


static func _append_unique(paths: Array[String], path: String) -> void:
	if not paths.has(path):
		paths.append(path)
