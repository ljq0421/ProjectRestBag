extends SceneTree

const ResearchService = preload("res://scripts/challenge/recipe_research_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	var tree := {
		"id": "bundle_tree",
		"display_name": "组合研究",
		"completion_reward_points": 3,
		"starter_recipe_ids": ["butter_cookie"],
		"branches": [{
			"id": "bundle_branch",
			"display_name": "组合方向",
			"node_ids": ["bundle_node", "successor_node"]
		}],
		"boss_reveals": {"boss": ["bundle_node"]},
		"nodes": {
			"bundle_node": {
				"id": "bundle_node",
				"branch_id": "bundle_branch",
				"tier": 1,
				"cost": 3,
				"prerequisite_ids": [],
				"tags": ["fast"],
				"build_purpose": "一次解锁两个配方",
				"unlocks": [
					{"type": "recipe", "id": "strawberry_jelly"},
					{"type": "recipe", "id": "milk_pudding"}
				]
			},
			"successor_node": {
				"id": "successor_node",
				"branch_id": "bundle_branch",
				"tier": 2,
				"cost": 5,
				"prerequisite_ids": ["bundle_node"],
				"tags": ["fast"],
				"build_purpose": "验证直接后继揭示",
				"unlocks": [{"type": "recipe", "id": "blueberry_muffin"}]
			}
		}
	}
	var defs := {
		"butter_cookie": {},
		"strawberry_jelly": {},
		"milk_pudding": {},
		"blueberry_muffin": {}
	}
	var service = ResearchService.new()
	var validation := service.validate_tree(tree, defs, {})
	_expect(bool(validation.get("valid", false)), "research tree should allow one node to unlock multiple recipes")
	var meta := service.bootstrap_meta({
		"research_points": 3,
		"revealed_research_node_ids": ["bundle_node"]
	}, tree)
	var unlocked := service.unlock_node(meta, "bundle_node", tree, "bundle:unlock")
	_expect(bool(unlocked.get("applied", false)), "bundle node should unlock")
	var unlocked_ids: Array = (unlocked.get("meta", {}) as Dictionary).get("unlocked_recipe_ids", [])
	_expect(unlocked_ids.has("strawberry_jelly"), "bundle should grant first recipe")
	_expect(unlocked_ids.has("milk_pudding"), "bundle should grant second recipe")
	_expect((unlocked.get("granted_unlocks", []) as Array).size() == 2, "bundle should report both grants")
	_expect(
		(unlocked.get("revealed_node_ids", []) as Array).has("successor_node"),
		"unlocking a node should reveal its direct successor in the same branch"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_RESEARCH_BUNDLE_UNLOCK_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
