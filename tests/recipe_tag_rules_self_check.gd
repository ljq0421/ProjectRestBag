extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")
const ShopSimulation = preload("res://scripts/shop_simulation.gd")

var failed := false


func _init() -> void:
	var cells := {
		"left": [Vector2i(0, 0)],
		"right": [Vector2i(1, 0)],
	}
	var recipes := {
		"left": {"name": "左侧", "tags": ["果香", "甜"]},
		"right": {"name": "右侧", "tags": ["清爽", "咸香"]},
	}
	var rules := {
		"low": {
			"priority": 10,
			"rule_name": "低优先",
			"trigger_tag_a": "果香",
			"trigger_tag_b": "清爽",
			"price_bonus_pct": 5,
		},
		"high": {
			"priority": 20,
			"rule_name": "高优先",
			"trigger_tag_a": "甜",
			"trigger_tag_b": "咸香",
			"price_bonus_pct": 12,
		},
	}
	var result: Dictionary = ShopSimulation._calc_adjacency_tag_bonuses(
		cells,
		recipes,
		rules
	)
	var left: Dictionary = result.get("left", {})
	if int(left.get("price_pct", 0)) != 12:
		_fail("only the highest-priority base rule should apply")
	if (left.get("reasons", []) as Array).size() != 1:
		_fail("one adjacent pair should expose one base-rule reason")

	var loaded := Catalog.new().get_display_rules()
	if (loaded.get("base_tag_bonuses", {}) as Dictionary).is_empty():
		_fail("display rules should load from JSON")

	var student := {
		"preference_tags": ["甜"],
		"low_price_threshold": 20,
		"budget": 100,
	}
	var cheap_sweet := {"tags": ["甜"], "price": 18}
	var expensive_sweet := {"tags": ["甜"], "price": 28}
	var cheap_score := ShopSimulation._score_product(student, cheap_sweet, 1)
	var expensive_score := ShopSimulation._score_product(student, expensive_sweet, 1)
	if cheap_score <= expensive_score:
		_fail("typed low-price preference should favor the affordable recipe")
	var blogger := {
		"id": "blogger",
		"preference_tags": ["招牌"],
		"budget": 50,
	}
	if ShopSimulation._score_product(
		blogger,
		{"tags": ["招牌"], "price": 40},
		1
	) <= 10:
		_fail("blogger should retain the signature bonus")

	if failed:
		quit(1)
	else:
		print("RECIPE_TAG_RULES_SELF_CHECK_PASS")
		quit(0)


func _fail(message: String) -> void:
	failed = true
	push_error(message)
