extends ConfirmationDialog

@onready var recipe_label: Label = $Body/RecipeLabel
@onready var restock_list: RichTextLabel = $Body/RestockList
@onready var total_label: Label = $Body/TotalLabel
@onready var hint_label: Label = $Body/HintLabel


func configure(quote: Dictionary) -> void:
	_ensure_node_references()
	var quote_kind := String(quote.get("quote_kind", "recipe"))
	recipe_label.text = (
		"补货范围：%s" % String(quote.get("quote_name", "全部配方与加工"))
		if quote_kind == "research_bulk"
		else "当前配方：%s" % String(quote.get("recipe_name", quote.get("quote_name", "")))
	)
	var lines: Array[String] = []
	for entry_value: Variant in quote.get("entries", []):
		var entry: Dictionary = entry_value
		if bool(entry.get("purchasable", false)):
			lines.append("%s ×%d｜单价 %d｜小计 %d 金币" % [
				String(entry.get("name", "")),
				int(entry.get("missing", 0)),
				int(entry.get("unit_price", 0)),
				int(entry.get("subtotal", 0))
			])
		else:
			lines.append("%s ×%d｜不可直接采购（需通过%s获得）" % [
				String(entry.get("name", "")),
				int(entry.get("missing", 0)),
				String(entry.get("source", "对应产地"))
			])
	restock_list.text = "\n".join(lines)
	var total_cost := int(quote.get("total_cost", 0))
	var available_coins := int(quote.get("available_coins", 0))
	total_label.text = "本次可采购：%d 件｜合计：%d 金币" % [
		int(quote.get("purchasable_units", 0)),
		total_cost
	]
	var has_purchasable: bool = not quote.get("purchasable_entries", []).is_empty()
	var can_afford: bool = available_coins >= total_cost
	get_ok_button().disabled = not has_purchasable or not can_afford
	if not has_purchasable:
		hint_label.text = "请先通过对应生产来源获得缺少的食材。"
	elif not can_afford:
		hint_label.text = "金币不足：需要 %d，当前 %d。整单不会购买。" % [total_cost, available_coins]
	else:
		hint_label.text = "不可直购食材不会计价或加入库存。"


func _ensure_node_references() -> void:
	if is_instance_valid(recipe_label):
		return
	recipe_label = get_node("Body/RecipeLabel") as Label
	restock_list = get_node("Body/RestockList") as RichTextLabel
	total_label = get_node("Body/TotalLabel") as Label
	hint_label = get_node("Body/HintLabel") as Label
