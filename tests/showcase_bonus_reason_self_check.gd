extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")
const SHOP_SIMULATION := preload("res://scripts/shop_simulation.gd")
const SHOWCASE_RULE_SERVICE := preload("res://scripts/showcase_rule_service.gd")

var failed := false


func _init() -> void:
	var root := MAIN_SCENE.instantiate()
	get_root().add_child(root)
	await root.ready

	var state = GAME_STATE.new_game()
	state.level = 2
	state.add_recipe("sponge_cake")
	state.add_recipe("butter_cookie")
	state.add_product("sponge_cake", 2)
	state.add_product("butter_cookie", 1)
	if not state.list_display_item("sponge_cake", [Vector2i(6, 7), Vector2i(6, 8), Vector2i(7, 7), Vector2i(7, 8)], 1):
		_fail("should list sponge_cake in golden zone")
	if not state.list_display_item("butter_cookie", [Vector2i(6, 6)], 1):
		_fail("should list butter_cookie adjacent to sponge_cake")

	root.set("state", state)
	root.call("_sync_showcase_slot_from_display_item", 76, "sponge_cake")
	root.call("_sync_showcase_slot_from_display_item", 75, "butter_cookie")
	root.call("_refresh_storefront_showcase")
	var showcase_grid: GridContainer = root.get_node("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid")
	var sponge_tooltip := _grid_tooltip_for_recipe(showcase_grid, "sponge_cake")
	if sponge_tooltip.find("原因") == -1:
		_fail("showcase tooltip should explain bonus reasons, got: %s" % sponge_tooltip)
	if sponge_tooltip.find("受") == -1 and sponge_tooltip.find("触发") == -1:
		_fail("showcase tooltip should say what affected the bonus, got: %s" % sponge_tooltip)

	var bonus: Dictionary = root.call("_showcase_bonus_for_recipe", "sponge_cake")
	var relation_cells := {
		"tea_item": [Vector2i(1, 1)],
		"crisp_item": [Vector2i(1, 2)],
		"rich_item": [Vector2i(2, 1)]
	}
	var relation_recipes := {
		"tea_item": {"name": "茶饮", "tags": ["茶香", "清凉"]},
		"crisp_item": {"name": "脆点", "tags": ["香脆"]},
		"rich_item": {"name": "浓点", "tags": ["浓郁"]}
	}
	var set_parts: Dictionary = SHOP_SIMULATION._calc_set_bonuses(relation_cells, relation_recipes, {
		"set_test": {"set_name": "测试下午茶", "required_tags": ["茶香", "香脆", "浓郁"], "min_item_count": 3, "price_bonus_pct": 10, "speed_bonus_pct": 5}
	})
	var tea_set_part: Dictionary = set_parts.get("tea_item", {})
	var actual_groups: Array = tea_set_part.get("groups", [])
	if actual_groups.size() != 1 or String((actual_groups[0] as Dictionary).get("id", "")) != "set_test":
		_fail("real set calculation should expose stable group metadata")
	var actual_related_ids: Array = tea_set_part.get("related_recipe_ids", [])
	if not actual_related_ids.has("crisp_item"):
		_fail("real set calculation should expose related members")
	var conflict_parts: Dictionary = SHOP_SIMULATION._calc_conflict_penalties(relation_cells, relation_recipes, {
		"penalty_002": {"penalty_name": "测试口感冲突", "conflict_tags": ["清凉", "浓郁"], "price_penalty_pct": -5}
	})
	var tea_conflict_part: Dictionary = conflict_parts.get("tea_item", {})
	var actual_conflict_ids: Array = tea_conflict_part.get("related_recipe_ids", [])
	if not actual_conflict_ids.has("rich_item"):
		_fail("real conflict calculation should expose conflicting recipes")

	var synthetic_bonus := {
		"price_multiplier": 1.2,
		"breakdown": {
			"zone": {"price_pct": 10.0},
			"adjacency_tag": {"price_pct": 5.0, "related_recipe_ids": ["butter_cookie"]},
			"set": {
				"price_pct": 12.0,
				"groups": [{"id": "set_001", "label": "经典下午茶三件套", "recipe_ids": ["sponge_cake", "butter_cookie"]}],
				"related_recipe_ids": ["butter_cookie"]
			},
			"growth": {"price_pct": 3.0},
			"conflict": {"price_pct": -5.0, "related_recipe_ids": ["mint_mousse"]}
		}
	}
	var attribution: Dictionary = SHOWCASE_RULE_SERVICE.sale_attribution(100, 120, synthetic_bonus)
	var rebuilt := int(attribution.get("base_coins", 0)) \
			+ int(attribution.get("position_adjacency_coins", 0)) \
			+ int(attribution.get("set_growth_coins", 0)) \
			+ int(attribution.get("other_delta", 0)) \
			- int(attribution.get("conflict_loss", 0))
	if rebuilt != 120:
		_fail("sale attribution should exactly reconstruct final price")
	if int(attribution.get("conflict_loss", 0)) <= 0:
		_fail("negative conflict price pct should expose a visible loss")
	var context: Dictionary = SHOWCASE_RULE_SERVICE.sale_context(synthetic_bonus)
	var groups: Array = context.get("groups", [])
	if groups.size() != 1 or String((groups[0] as Dictionary).get("id", "")) != "set_001":
		_fail("sale context should preserve stable set ids")
	var related_recipe_ids: Array = context.get("related_recipe_ids", [])
	if not related_recipe_ids.has("butter_cookie"):
		_fail("sale context should expose positive related recipes")
	var conflict_recipe_ids: Array = context.get("conflict_recipe_ids", [])
	if not conflict_recipe_ids.has("mint_mousse"):
		_fail("sale context should expose conflicting recipes")

	root.call("_record_business_feedback", "sponge_cake", {
		"ok": true,
		"sold_count": 1,
		"earned_coins": 20,
		"earned_reputation": 2,
		"sales": [{
			"recipe_id": "sponge_cake",
			"quantity": 1,
			"base_price": 18,
			"final_price": 20,
			"price": 20,
			"bonus": bonus
		}]
	})
	root.call("_refresh_feedback_log")
	var feedback_text := String(root.get("cashier_feedback_text"))
	if feedback_text.find("最近售出") == -1:
		_fail("cashier feedback should show recent sales, got: %s" % feedback_text)
	if feedback_text.find("原因") == -1:
		_fail("cashier feedback should explain bonus reasons, got: %s" % feedback_text)

	if failed:
		quit(1)
	else:
		print("SHOWCASE_BONUS_REASON_SELF_CHECK_PASS")
		quit(0)


func _grid_tooltip_for_recipe(grid: GridContainer, recipe_id: String) -> String:
	for child in grid.get_children():
		if child is Control:
			var control := child as Control
			if control.has_meta("recipe_id") and String(control.get_meta("recipe_id")) == recipe_id:
				return control.tooltip_text
	return ""


func _fail(message: String) -> void:
	failed = true
	push_error(message)
