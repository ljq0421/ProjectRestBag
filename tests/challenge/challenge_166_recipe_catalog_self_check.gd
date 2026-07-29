extends SceneTree
func _init() -> void:
	var f:=FileAccess.open("res://doc/challenge/challenge_recipes.json",FileAccess.READ);var d:Dictionary=JSON.parse_string(f.get_as_text());f.close()
	var recipes:Dictionary=d.get("recipes",{});var starters:Array=d.get("starter_recipe_ids",[]);var research:Array=d.get("research_recipe_ids",[])
	if recipes.size()==166 and starters.size()==6 and research.size()==160 and not _overlap(starters,research):
		print("CHALLENGE_166_RECIPE_CATALOG_SELF_CHECK_PASS");quit(0);return
	push_error("complete challenge catalog should be 166 = 6 starters + 160 research");quit(1)
func _overlap(a:Array,b:Array)->bool:
	for value in a:
		if b.has(value): return true
	return false
