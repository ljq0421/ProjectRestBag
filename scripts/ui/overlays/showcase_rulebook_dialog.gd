class_name ShowcaseRulebookDialog
extends AcceptDialog

const ShowcaseRegionService = preload("res://scripts/showcase_region_service.gd")
const ShowcaseRuleService = preload("res://scripts/showcase_rule_service.gd")
const ShowcaseExpansionService = preload("res://scripts/showcase_expansion_service.gd")

const CATEGORIES := [
	{"id": "regions", "label": "区域"},
	{"id": "expansion", "label": "橱窗扩建"},
	{"id": "adjacency", "label": "四方向相邻"},
	{"id": "sets", "label": "连通套装"},
	{"id": "conflicts", "label": "冲突减损"},
	{"id": "variants", "label": "上架变体"},
	{"id": "growth", "label": "配方成长"},
	{"id": "roles", "label": "角色与热度连锁"},
	{"id": "props", "label": "陈列道具"},
	{"id": "themes", "label": "橱窗主题"}
]

@onready var bounds_label: Label = $RulebookBody/RulebookLayout/CategoryPanel/BoundsLabel
@onready var category_list: ItemList = $RulebookBody/RulebookLayout/CategoryPanel/CategoryList
@onready var rule_text: RichTextLabel = $RulebookBody/RulebookLayout/RuleScroll/RuleText

var _state = null
var _catalog = null


func _ready() -> void:
	get_ok_button().hide()
	$DialogChrome/CloseButton.pressed.connect(_on_close_requested)
	_populate_categories()
	var handler := Callable(self, "_on_category_selected")
	if not category_list.item_selected.is_connected(handler):
		category_list.item_selected.connect(handler)
	if not close_requested.is_connected(_on_close_requested):
		close_requested.connect(_on_close_requested)


func _on_close_requested() -> void:
	hide()


func show_rules(state, catalog) -> void:
	if not is_node_ready():
		await ready
	_state = state
	_catalog = catalog
	var cells := _current_cells()
	var layout := ShowcaseRegionService.resolve_regions_for_cells(cells)
	bounds_label.text = "已开放 %d/168\n有效 %d 行｜%d 列" % [
		int(layout.get("unlocked_count", 0)),
		int(layout.get("row_count", 0)),
		int(layout.get("column_count", 0))
	]
	category_list.select(0)
	_show_category("regions")
	popup_centered(Vector2i(980, 720))


func select_category(category_id: String) -> void:
	for index in range(CATEGORIES.size()):
		if String(CATEGORIES[index].id) == category_id:
			category_list.select(index)
			_show_category(category_id)
			return


func _populate_categories() -> void:
	category_list.clear()
	for category in CATEGORIES:
		category_list.add_item(String(category.label))
		category_list.set_item_metadata(category_list.item_count - 1, String(category.id))


func _on_category_selected(index: int) -> void:
	_show_category(String(category_list.get_item_metadata(index)))


func _show_category(category_id: String) -> void:
	match category_id:
		"regions": rule_text.text = _region_text()
		"expansion": rule_text.text = _expansion_text()
		"adjacency": rule_text.text = _configured_rule_text("四方向相邻", "base_tag_bonuses")
		"sets": rule_text.text = _configured_rule_text("连通套装", "set_bonuses")
		"conflicts": rule_text.text = _configured_rule_text("冲突减损", "conflict_penalties")
		"variants": rule_text.text = _variant_text()
		"growth": rule_text.text = _growth_text()
		"roles": rule_text.text = _role_text()
		"props": rule_text.text = _prop_text()
		"themes": rule_text.text = _theme_text()


func _region_text() -> String:
	var layout := ShowcaseRegionService.resolve_regions_for_cells(_current_cells())
	var zones: Dictionary = _display_rules().get("zone_bonuses", {})
	var front: Dictionary = zones.get("zone_001", {})
	var golden: Dictionary = zones.get("zone_002", {})
	var back: Dictionary = zones.get("zone_003", {})
	return "[font_size=24]区域[/font_size]\n[font_size=14]区域从当前实际已解锁格的有效行列推导；不规则形状中的锁定空洞不属于任何功能区。商品全部占格位于同一功能区才生效。[/font_size]\n\n" \
		+ "[b]引流前排位｜第%s行[/b]\n触发：已解锁区域前 30%%（最少 1 行）\n效果：售价 %s，售速 %s\n适合：走量与引流商品\n\n" % [
			_axis_values(layout.get("front_rows", [])),
			_signed_pct(front.get("price_bonus_pct", 0)),
			_signed_pct(front.get("speed_bonus_pct", 0))
		] \
		+ "[b]黄金 C 位｜第%s行 × 第%s列[/b]\n触发：中间 40%% 行与中间 40%% 列的交集（各最少 1）\n效果：售价 %s；相邻/套装/冲突效果 ×%.1f\n适合：核心构筑商品\n\n" % [
			_axis_values(layout.get("golden_rows", [])),
			_axis_values(layout.get("golden_columns", [])),
			_signed_pct(golden.get("price_bonus_pct", 0)),
			float(golden.get("adjacency_multiplier", 1.0))
		] \
		+ "[b]宝藏深处位｜第%s行[/b]\n触发：已解锁区域后 30%%（最少 1 行）\n效果：售价 %s，售速 %s\n适合：高价招牌款\n\n" % [
			_axis_values(layout.get("back_rows", [])),
			_signed_pct(back.get("price_bonus_pct", 0)),
			_signed_pct(back.get("speed_bonus_pct", 0))
		] \
		+ "[color=#9b3f32][b]跨区[/b]：商品横跨两个功能区时，不获得固定区域效果。[/color]"


func _expansion_text() -> String:
	var level := int(_state.level) if _state != null else 0
	var count := _current_cells().size()
	var max_count := ShowcaseExpansionService.max_unlocked_cells_for_level(level)
	var next_price := ShowcaseExpansionService.cell_price(maxi(1, count - 16 + 1))
	return "[font_size=24]橱窗扩建[/font_size]\n\n[b]开放等级[/b]：Lv.2 起可购买；等级只开放购买额度，不赠送格子。\n" \
		+ "[b]当前[/b]：Lv.%d｜%d/%d 格｜下一格 %d 金币\n\n" % [level, count, max_count, next_price] \
		+ "[b]价格[/b]：第一格 300 金币，之后每购买一格 +10；批量购买按格逐一累加。\n" \
		+ "[b]单格/N格[/b]：所选格可彼此连接，只要整批购买后与旧区域四方向连通，就能一次向外延伸多层。\n" \
		+ "[b]购买行/列[/b]：购买所点行或列中，所有与购买前旧区域四方向相邻的未解锁格。\n" \
		+ "[b]等级额度[/b]：Lv.2 36格｜Lv.3 64格｜Lv.4 100格｜Lv.5 144格｜Lv.6+ 168格。"


func _configured_rule_text(title: String, key: String) -> String:
	var groups: Dictionary = _display_rules().get(key, {})
	var lines: Array[String] = ["[font_size=24]%s[/font_size]" % title]
	var ids := groups.keys()
	ids.sort()
	for rule_id in ids:
		var rule: Dictionary = groups[rule_id]
		var name := String(rule.get("rule_name", rule.get("set_name", rule.get("penalty_name", rule_id))))
		var condition := String(rule.get("trigger_condition", "上下左右相邻触发；斜角不计"))
		var scope := String(rule.get("effect_scope", "触发规则的参与商品"))
		lines.append("\n[b]%s[/b]｜已开放" % name)
		lines.append("触发：%s" % condition)
		if rule.has("required_tags"):
			lines.append("标签：%s" % "、".join(rule.get("required_tags", [])))
		elif rule.has("trigger_tag_a"):
			lines.append("标签：%s + %s" % [rule.get("trigger_tag_a", ""), rule.get("trigger_tag_b", "")])
		lines.append("对象：%s" % scope)
		lines.append("效果：售价 %s｜售速 %s" % [
			_signed_pct(rule.get("price_bonus_pct", rule.get("price_penalty_pct", 0))),
			_signed_pct(rule.get("speed_bonus_pct", rule.get("speed_penalty_pct", 0)))
		])
		lines.append("说明：%s" % String(rule.get("description", "")))
	if key == "base_tag_bonuses":
		lines.append("\n同一商品对可同时命中多条不同规则；同一规则不会因多格接触重复结算。")
	elif key == "set_bonuses":
		lines.append("\n必须覆盖全部 required_tags；只奖励满足条件的最小连通成员组。")
	elif key == "conflict_penalties":
		lines.append("\n同类扎堆按相同标签的四方向连通分量分别计算，前两件安全。")
	return "\n".join(lines)


func _variant_text() -> String:
	var lines: Array[String] = ["[font_size=24]上架变体[/font_size]", "调整阶段在库存商品上右键选择；营业中不可改。"]
	for variant_id in ["standard", "small", "gift_box", "large", "sample"]:
		var definition := ShowcaseRuleService.variant_definition("", variant_id, {})
		var reputation := int(definition.get("reputation_delta", 0))
		var reputation_text := "" if reputation == 0 else "｜真实成交额外口碑 %+d" % reputation
		lines.append("\n[b]%s[/b]｜已开放\n占格：%d｜售价 %s｜售速 %s%s" % [
			definition.get("label", variant_id),
			int(definition.get("cell_count", 1)),
			_signed_pct(definition.get("price_pct", 0)),
			_signed_pct(definition.get("speed_pct", 0)),
			reputation_text
		])
	return "\n".join(lines)


func _growth_text() -> String:
	return "[font_size=24]配方成长[/font_size]\n\n[b]试作品 → 人气款 → 招牌款[/b]\n制作、真实售卖和橱窗搭配共同推进成长。\n\n当前开放：成长阶段、已选特性与候选特性可在商品详情查看。\n计划接入：达到阈值时打开真实选择弹窗，对比 30 秒预计成交、金币、占格、角色和热度影响。"


func _role_text() -> String:
	var rules := _round_rules()
	var lines: Array[String] = [
		"[font_size=24]角色与热度连锁[/font_size]",
		"单次连锁最多 %d 层；只消耗真实库存。" % int(rules.get("chain_max_depth", 4)),
		"\n[b]没有后续目标时[/b]",
		"推进角色只会连接四方向相邻且仍可售卖的商品；如果没有这样的目标，本次销售会静默终止，不会产生后续连锁，也不显示标记。斜角接触不算相邻。",
		"调整摆位，让推进商品与目标商品上下左右接触即可建立连锁。"
	]
	var templates: Dictionary = rules.get("shape_templates", {})
	var names := templates.keys()
	names.sort()
	for name in names:
		var item: Dictionary = templates[name]
		lines.append("\n[b]%s｜%s[/b]\n基础周期 %d 秒｜占格/角色成本由当前配方形状决定" % [name, item.get("role", "lure"), int(item.get("base_sale_seconds", 10))])
	lines.append("\n橱窗上的箭头表示当前首个连锁目标；没有可用目标时不绘制箭头或文字。")
	return "\n".join(lines)


func _prop_text() -> String:
	return "[font_size=24]陈列道具[/font_size]\n阶段奖励永久解锁；占真实格，只能在调整阶段操作。\n\n[b]蛋糕架｜1 格[/b]\n四方向相邻商品：售价 +4%，售速 +4%\n\n[b]冷藏展示柜｜2 格[/b]\n相邻清爽/果香/清凉商品：售速 +8%\n\n[b]复古托盘｜1 格[/b]\n相邻经典/茶香/浓郁商品：售价 +5%\n\n[b]试吃牌｜1 格[/b]\n相邻小份/试吃变体：售速 +10%\n\n[b]礼盒角｜1 格[/b]\n相邻礼盒变体：售价 +10%\n\n当前入口：经营中心的“橱窗策略”页签；拖入真实橱窗格放置。"


func _theme_text() -> String:
	var lines: Array[String] = ["[font_size=24]橱窗主题[/font_size]", "同轮只能启用一个主题或选择无主题；营业开始后锁定。"]
	for theme_id in ["summer", "retro", "tea"]:
		var theme: Dictionary = ShowcaseRuleService.THEME_RULES[theme_id]
		lines.append("\n[b]%s｜当前效果已存在[/b]\n标签：%s\n效果：售价 %s｜售速 %s" % [
			theme.get("label", theme_id),
			"、".join(theme.get("tags", [])),
			_signed_pct(theme.get("price_pct", 0)),
			_signed_pct(theme.get("speed_pct", 0))
		])
	lines.append("\n当前入口：经营中心的“橱窗策略”页签；选择后立即刷新构筑预览。")
	return "\n".join(lines)


func _current_cells() -> Array[Vector2i]:
	if _state != null and _state.has_method("get_showcase_unlocked_cells"):
		return _state.get_showcase_unlocked_cells()
	return ShowcaseRegionService.cells_for_bounds(ShowcaseRegionService.default_bounds())


func _display_rules() -> Dictionary:
	return _catalog.get_display_rules() if _catalog != null and _catalog.has_method("get_display_rules") else {}


func _round_rules() -> Dictionary:
	return _catalog.get_showcase_round_rules() if _catalog != null and _catalog.has_method("get_showcase_round_rules") else {}


func _axis_values(values_value: Variant) -> String:
	var values: Array = values_value if values_value is Array else []
	if values.is_empty():
		return "—"
	return str(int(values[0])) if values.size() == 1 else "%d-%d" % [int(values.front()), int(values.back())]


func _signed_pct(value: Variant) -> String:
	return "%+.0f%%" % float(value)
