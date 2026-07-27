class_name ShowcaseRoundSettlementDialog
extends ConfirmationDialog

signal settlement_confirmed(decisions: Dictionary)

const HEADER_CELL_COUNT := 4
const DETAIL_HEADER_CELL_COUNT := 9
const DETAIL_COLUMN_WIDTHS := [96.0, 40.0, 60.0, 60.0, 40.0, 52.0, 52.0, 116.0, 100.0]

@onready var settlement_grid: GridContainer = $SettlementBody/SettlementContent/SettlementGrid
@onready var round_detail_grid: GridContainer = $SettlementBody/SettlementContent/RoundDetailGrid
@onready var forced_clearance_label: Label = $SettlementBody/SettlementContent/ForcedClearanceLabel
@onready var settlement_summary: Label = $SettlementBody/SettlementContent/SettlementSummary
@onready var rating_title_label: Label = $SettlementBody/SettlementContent/RatingTitleLabel
@onready var rating_summary_label: Label = $SettlementBody/SettlementContent/RatingSummaryLabel
@onready var leftover_title_label: Label = $SettlementBody/SettlementContent/LeftoverTitleLabel
@onready var settlement_income_label: Label = $SettlementBody/SettlementContent/SettlementIncomeLabel

var _settlement_id := ""
var _decisions: Dictionary = {}
var _choice_buttons: Dictionary = {}
var _required_decision_count := 0
var _fresh_options_by_recipe: Dictionary = {}
var _forced_clearance_coins := 0
var _summary_base_text := ""
var _rating_only := false


func _ready() -> void:
	var handler := Callable(self, "_on_confirmed")
	if not confirmed.is_connected(handler):
		confirmed.connect(handler)
	$DialogChrome/CloseButton.pressed.connect(_on_image_close_pressed)
	get_cancel_button().hide()
	for column_index in range(DETAIL_HEADER_CELL_COUNT):
		var header := round_detail_grid.get_child(column_index) as Label
		_configure_detail_cell(header, header.text, float(DETAIL_COLUMN_WIDTHS[column_index]))


func _on_image_close_pressed() -> void:
	hide()
	close_requested.emit()


func show_settlement(quote: Dictionary, recipe_names: Dictionary = {}) -> void:
	if not is_node_ready():
		await ready
	_settlement_id = String(quote.get("settlement_id", ""))
	_rating_only = false
	get_ok_button().text = "确认处理并继续"
	$SettlementBody/SettlementContent/SummaryTitleLabel.visible = true
	settlement_summary.visible = true
	$SettlementBody/SettlementContent/DetailTitleLabel.visible = true
	round_detail_grid.visible = true
	_decisions.clear()
	_choice_buttons.clear()
	_fresh_options_by_recipe.clear()
	_forced_clearance_coins = maxi(0, int(quote.get("forced_clearance_coins", 0)))
	_clear_rows()
	_clear_detail_rows()
	var fresh_options: Array = quote.get("fresh_options", [])
	_required_decision_count = 0
	for option_value in fresh_options:
		if not option_value is Dictionary:
			continue
		_required_decision_count += 1
		var option: Dictionary = option_value
		var recipe_id := String(option.get("recipe_id", ""))
		var quantity := maxi(0, int(option.get("quantity", 0)))
		_fresh_options_by_recipe[recipe_id] = option.duplicate(true)
		_add_cell(String(recipe_names.get(recipe_id, recipe_id)), false)
		_add_cell(str(quantity), true)
		_add_cell("本轮新鲜剩余", false)
		var choice := OptionButton.new()
		choice.custom_minimum_size = Vector2(210.0, 36.0)
		choice.add_item("下轮 8 折继续出售")
		choice.set_item_metadata(0, "carry_80")
		choice.add_item("立即 5 折清仓（%d 金币/份）" % int(option.get("clear_unit_price", 0)))
		choice.set_item_metadata(1, "clear_50")
		choice.select(0)
		choice.item_selected.connect(_on_choice_selected.bind(recipe_id, choice))
		settlement_grid.add_child(choice)
		_choice_buttons[recipe_id] = choice
		_decisions[recipe_id] = "carry_80"
	var has_leftover_options := _required_decision_count > 0
	leftover_title_label.visible = has_leftover_options
	settlement_grid.visible = has_leftover_options
	settlement_income_label.visible = has_leftover_options
	var forced_count := 0
	for entry_value in quote.get("forced_entries", []):
		if entry_value is Dictionary:
			forced_count += maxi(0, int((entry_value as Dictionary).get("quantity", 0)))
	forced_clearance_label.text = "上轮 8 折留售品未售出：%d 份已按 1 折强制清仓，获得 %d 金币。" % [
		forced_count,
		maxi(0, int(quote.get("forced_clearance_coins", 0)))
	]
	forced_clearance_label.visible = forced_count > 0
	var summary: Dictionary = quote.get("round_summary", {})
	var challenge_snapshot: Dictionary = quote.get("challenge_snapshot", {})
	rating_title_label.visible = not challenge_snapshot.is_empty()
	rating_summary_label.visible = not challenge_snapshot.is_empty()
	if not challenge_snapshot.is_empty():
		rating_summary_label.text = "%s｜确认余货处理后，按 %s 评级。" % [
			String(challenge_snapshot.get("title", "经营合同")),
			_tier_id_text(challenge_snapshot.get("tiers", []))
		]
	var summary_lines: Array[String] = [
		"本轮总金币 %d｜成交 %d 次" % [
			int(summary.get("total_coins", 0)),
			int(summary.get("sold_count", 0))
		],
		"基础收入 %d｜布局额外 %+d" % [
			int(summary.get("base_income", 0)),
			int(summary.get("layout_extra_income", 0))
		]
	]
	var products: Dictionary = summary.get("products", {})
	var product_ids: Array[String] = []
	for recipe_id_value in products.keys():
		product_ids.append(String(recipe_id_value))
	product_ids.sort()
	for recipe_id in product_ids:
		var product: Dictionary = products.get(recipe_id, {})
		var product_name := String(recipe_names.get(recipe_id, product.get("recipe_name", recipe_id)))
		_add_detail_cell(product_name, false)
		_add_detail_cell(str(int(product.get("sold_count", 0))), true)
		_add_detail_cell("%d/%d" % [int(product.get("fresh_sale_count", 0)), int(product.get("carried_sale_count", 0))], true)
		_add_detail_cell("%d 金币" % int(product.get("earned_coins", 0)), true)
		_add_detail_cell(str(int(product.get("refill_count", 0))), true)
		_add_detail_cell(String(product.get("role", "—")), false)
		_add_detail_cell("连锁 %d" % int(product.get("chain_count", 0)), true)
		var triggered_rules: Array = product.get("triggered_rules", [])
		var gap_ms := int(product.get("next_sale_gap_ms", -1))
		var gap_text := "" if gap_ms < 0 else "%.1f 秒" % (float(gap_ms) / 1000.0)
		var rule_text := "—" if triggered_rules.is_empty() else String(triggered_rules[0])
		_add_detail_cell(rule_text if gap_text.is_empty() else "%s｜%s" % [gap_text, rule_text], false)
		_add_detail_cell(_growth_increment_text(product), false)
	var top_recipe_id := String(summary.get("top_recipe_id", ""))
	if not top_recipe_id.is_empty():
		summary_lines.append("贡献最高：%s（%d 金币）" % [
			String(recipe_names.get(top_recipe_id, top_recipe_id)),
			int(summary.get("top_contribution_coins", 0))
		])
	var reasons: Array = summary.get("triggered_reasons", [])
	if not reasons.is_empty():
		summary_lines.append("布局加成：")
		for reason_index in range(reasons.size()):
			summary_lines.append("%d. %s" % [reason_index + 1, String(reasons[reason_index])])
	_summary_base_text = "\n".join(summary_lines)
	_update_confirmation_state()
	popup_centered(Vector2i(840, 660))


func show_rating_result(result: Dictionary) -> void:
	if not is_node_ready():
		await ready
	_rating_only = true
	get_ok_button().text = "关闭"
	$SettlementBody/SettlementContent/SummaryTitleLabel.visible = false
	settlement_summary.visible = false
	forced_clearance_label.visible = false
	$SettlementBody/SettlementContent/DetailTitleLabel.visible = false
	round_detail_grid.visible = false
	leftover_title_label.visible = false
	settlement_grid.visible = false
	settlement_income_label.visible = false
	rating_title_label.visible = true
	rating_summary_label.visible = true
	var evaluation: Dictionary = result.get("evaluation", {})
	var highest := String(result.get("highest_tier", ""))
	var lines: Array[String] = ["本轮最高评价：%s" % (highest.capitalize() if not highest.is_empty() else "未达铜级")]
	var next_tier := String(evaluation.get("next_tier", ""))
	if not next_tier.is_empty():
		lines.append("下一评价：%s" % next_tier.capitalize())
	for failure_value in evaluation.get("next_failures", []):
		if failure_value is Dictionary:
			lines.append("未达成：%s" % String((failure_value as Dictionary).get("reason", "")))
	if String(result.get("status", "")) == "invalid":
		lines = ["本轮报告不完整，合同未判定。", String(evaluation.get("reason", "请重新完成营业结算。"))]
	rating_summary_label.text = "\n".join(lines)
	popup_centered(Vector2i(760, 420))


func get_decisions() -> Dictionary:
	return _decisions.duplicate(true)


func select_decision(recipe_id: String, decision: String) -> bool:
	if not ["carry_80", "clear_50"].has(decision):
		return false
	var choice := _choice_buttons.get(recipe_id) as OptionButton
	if choice == null:
		return false
	for index in range(choice.item_count):
		if String(choice.get_item_metadata(index)) == decision:
			choice.select(index)
			_on_choice_selected(index, recipe_id, choice)
			return true
	return false


func _clear_rows() -> void:
	while settlement_grid.get_child_count() > HEADER_CELL_COUNT:
		var cell := settlement_grid.get_child(HEADER_CELL_COUNT)
		settlement_grid.remove_child(cell)
		cell.queue_free()


func _clear_detail_rows() -> void:
	while round_detail_grid.get_child_count() > DETAIL_HEADER_CELL_COUNT:
		var cell := round_detail_grid.get_child(DETAIL_HEADER_CELL_COUNT)
		round_detail_grid.remove_child(cell)
		cell.queue_free()


func _add_cell(value: String, numeric: bool) -> void:
	var cell := Label.new()
	cell.text = value
	cell.custom_minimum_size = Vector2(110.0 if numeric else 170.0, 36.0)
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if numeric else HORIZONTAL_ALIGNMENT_LEFT
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settlement_grid.add_child(cell)


func _add_detail_cell(value: String, _numeric: bool) -> void:
	var cell := Label.new()
	cell.text = value
	var column_index := (round_detail_grid.get_child_count() - DETAIL_HEADER_CELL_COUNT) % DETAIL_HEADER_CELL_COUNT
	round_detail_grid.add_child(cell)
	_configure_detail_cell(cell, value, float(DETAIL_COLUMN_WIDTHS[column_index]))


func _configure_detail_cell(cell: Label, value: String, column_width: float) -> void:
	cell.text = value
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	cell.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	cell.tooltip_text = value
	cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var font := cell.get_theme_font("font")
	var font_size := cell.get_theme_font_size("font_size")
	var break_flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_GRAPHEME_BOUND
	var measured_size := font.get_multiline_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, column_width, font_size, -1, break_flags)
	cell.custom_minimum_size = Vector2(column_width, maxf(32.0, ceilf(measured_size.y) + 4.0))


func _growth_increment_text(product: Dictionary) -> String:
	if not bool(product.get("growth_effective_round", false)):
		return "—"
	return "有效营业 +1｜协同营业 +1" if bool(product.get("growth_synergy_round", false)) else "有效营业 +1"


func _on_choice_selected(index: int, recipe_id: String, choice: OptionButton) -> void:
	var decision := String(choice.get_item_metadata(index))
	if decision.is_empty():
		_decisions.erase(recipe_id)
	else:
		_decisions[recipe_id] = decision
	_update_confirmation_state()


func _update_confirmation_state() -> void:
	get_ok_button().disabled = _decisions.size() < _required_decision_count
	var selected_clearance_coins := 0
	for recipe_id_value in _decisions.keys():
		var recipe_id := String(recipe_id_value)
		if String(_decisions.get(recipe_id, "")) != "clear_50":
			continue
		var option: Dictionary = _fresh_options_by_recipe.get(recipe_id, {})
		selected_clearance_coins += maxi(0, int(option.get("quantity", 0))) * maxi(0, int(option.get("clear_unit_price", 0)))
	settlement_summary.text = _summary_base_text
	settlement_income_label.text = "余货清仓收入：强制 1 折 %d｜当前选择 5 折 %d" % [
		_forced_clearance_coins,
		selected_clearance_coins
	]


func _on_confirmed() -> void:
	if not _rating_only:
		settlement_confirmed.emit(get_decisions())


func _tier_id_text(tiers_value: Variant) -> String:
	var ids: Array[String] = []
	if tiers_value is Array:
		for tier_value in tiers_value as Array:
			if tier_value is Dictionary:
				ids.append(String((tier_value as Dictionary).get("id", "")).capitalize())
	return " / ".join(ids)
