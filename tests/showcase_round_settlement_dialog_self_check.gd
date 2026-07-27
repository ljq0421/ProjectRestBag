extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_round_settlement_dialog_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	var main := packed.instantiate()
	main.set("save_path", _save_path)
	main.set("broken_save_path", _save_path + ".broken")
	root.add_child(main)
	await process_frame

	var dialog := main.get_node_or_null("ShowcaseRoundSettlementDialog")
	_expect(dialog != null, "Main should instance a centered showcase settlement dialog")
	if dialog != null:
		var runtime_summary: Dictionary = main.call("_build_showcase_round_summary", [
			{"recipe_id": "sponge_cake", "quantity": 1, "earned_coins": 10, "positive_adjacency": true}
		], {"sponge_cake": {"base_price": 10}}, {})
		var runtime_growth: Dictionary = runtime_summary.get("products", {}).get("sponge_cake", {})
		_expect(bool(runtime_growth.get("growth_effective_round", false)), "runtime settlement summary should expose the effective growth increment")
		_expect(bool(runtime_growth.get("growth_synergy_round", false)), "runtime settlement summary should expose the synergy growth increment")
		_expect(dialog is ConfirmationDialog, "settlement dialog should be a real ConfirmationDialog")
		_expect(dialog.get_node_or_null("SettlementBody/SettlementContent/SettlementTabs") == null, "settlement should merge summary and detail without tabs")
		_expect(dialog.get_node_or_null("SettlementBody/SettlementContent/SettlementGrid") is GridContainer, "leftover rows should use a real GridContainer")
		_expect(dialog.get_node_or_null("SettlementBody/SettlementContent/RoundDetailGrid") is GridContainer, "round detail should follow the summary in the same page")
		_expect(dialog.has_signal("settlement_confirmed"), "dialog should expose settlement_confirmed")
		_expect(dialog.has_method("show_settlement"), "dialog should expose show_settlement")
		dialog.call("show_settlement", {
			"settlement_id": "round:3",
			"forced_entries": [{"recipe_id": "old_cake", "quantity": 2, "unit_price": 4, "earned_coins": 8}],
			"forced_clearance_coins": 8,
			"round_summary": {
				"sold_count": 4,
				"total_coins": 120,
				"base_income": 100,
				"layout_extra_income": 20,
				"top_recipe_id": "sponge_cake",
				"top_contribution_coins": 80,
				"triggered_reasons": ["黄金区售价 +10%", "下午茶组合售速 +15%"],
				"next_sale_gap_ms": 2000,
				"products": {
					"sponge_cake": {"sold_count": 3, "fresh_sale_count": 2, "carried_sale_count": 1, "earned_coins": 80, "refill_count": 2, "role": "harvest", "chain_count": 1, "next_sale_gap_ms": 2000, "triggered_rules": ["黄金区售价 +10%，同时触发下午茶组合售速加成与招牌商品额外收益"], "growth_effective_round": true, "growth_synergy_round": true},
					"cookie": {"sold_count": 1, "fresh_sale_count": 1, "carried_sale_count": 0, "earned_coins": 40, "refill_count": 0, "role": "lure", "chain_count": 0, "next_sale_gap_ms": 3000, "triggered_rules": [], "growth_effective_round": true, "growth_synergy_round": false}
				}
			},
			"fresh_options": [
				{"recipe_id": "sponge_cake", "quantity": 3, "clear_unit_price": 22, "carry_multiplier": 0.8},
				{"recipe_id": "cookie", "quantity": 1, "clear_unit_price": 5, "carry_multiplier": 0.8}
			]
		}, {"old_cake": "隔夜蛋糕", "sponge_cake": "海绵蛋糕", "cookie": "曲奇"})
		await process_frame
		var default_decisions: Dictionary = dialog.call("get_decisions")
		_expect_equal("every fresh product defaults to next-round 8-discount", default_decisions, {
			"sponge_cake": "carry_80",
			"cookie": "carry_80"
		})
		_expect_equal("confirmation is immediately available with safe defaults", dialog.get_ok_button().disabled, false)
		_expect_equal("second explicit decision is accepted", bool(dialog.call("select_decision", "cookie", "clear_50")), true)
		_expect_equal("one decision per fresh product", dialog.call("get_decisions").size(), 2)
		_expect_equal("confirmation enables after all explicit choices", dialog.get_ok_button().disabled, false)
		var grid := dialog.get_node("SettlementBody/SettlementContent/SettlementGrid") as GridContainer
		_expect_equal("four fixed headers plus two product rows", grid.get_child_count(), 12)
		var content := dialog.get_node("SettlementBody/SettlementContent") as VBoxContainer
		var summary := dialog.get_node("SettlementBody/SettlementContent/SettlementSummary") as Label
		var detail_grid := dialog.get_node("SettlementBody/SettlementContent/RoundDetailGrid") as GridContainer
		var leftover_title := dialog.get_node("SettlementBody/SettlementContent/LeftoverTitleLabel") as Label
		var leftover_income := dialog.get_node("SettlementBody/SettlementContent/SettlementIncomeLabel") as Label
		_expect(content.get_children().find(detail_grid) > content.get_children().find(summary), "round detail should appear immediately after the summary section")
		_expect(content.get_children().find(grid) > content.get_children().find(detail_grid), "leftover decisions should appear after round detail")
		_expect_equal("nine detail headers plus two complete product rows", detail_grid.get_child_count(), 27)
		var detail_text := ""
		for child in detail_grid.get_children():
			if child is Label:
				detail_text += (child as Label).text + "\n"
		_expect(detail_text.find("2/1") >= 0, "product detail should separate full-price and 8-discount sales")
		_expect(detail_text.find("harvest") >= 0, "product detail should show role")
		_expect(detail_text.find("连锁 1") >= 0, "product detail should show chain count")
		_expect(detail_text.find("2.0 秒") >= 0, "product detail should show next threshold gap")
		_expect(detail_text.find("有效营业 +1｜协同营业 +1") >= 0, "synergy product should show both growth increments")
		_expect(detail_text.find("有效营业 +1") >= 0, "real-sale product should show its effective growth increment")
		var total_column_width := 0.0
		if detail_grid.get_child_count() == 27:
			for column_index in range(9):
				var header := detail_grid.get_child(column_index) as Label
				var first_row_cell := detail_grid.get_child(9 + column_index) as Label
				var second_row_cell := detail_grid.get_child(18 + column_index) as Label
				_expect_equal("detail column %d header and row width align" % column_index, header.custom_minimum_size.x, first_row_cell.custom_minimum_size.x)
				_expect_equal("detail column %d rows share one width" % column_index, first_row_cell.custom_minimum_size.x, second_row_cell.custom_minimum_size.x)
				_expect_equal("detail column %d header alignment" % column_index, header.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
				_expect_equal("detail column %d row alignment" % column_index, first_row_cell.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
				_expect(header.autowrap_mode != TextServer.AUTOWRAP_OFF, "detail column %d header should wrap long text" % column_index)
				_expect(first_row_cell.autowrap_mode != TextServer.AUTOWRAP_OFF, "detail column %d first row should wrap long text" % column_index)
				_expect(second_row_cell.autowrap_mode != TextServer.AUTOWRAP_OFF, "detail column %d second row should wrap long text" % column_index)
				_expect_equal("detail column %d first row should not trim with ellipsis" % column_index, first_row_cell.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
				_expect_equal("detail column %d second row should not trim with ellipsis" % column_index, second_row_cell.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
				total_column_width += header.custom_minimum_size.x
			total_column_width += 8.0 * float(detail_grid.get_theme_constant("h_separation"))
			_expect(total_column_width <= content.size.x, "detail columns should fit inside the settlement content width")
			var wrapped_cell := detail_grid.get_child(26) as Label
			var wrapped_row_height := wrapped_cell.size.y
			_expect(wrapped_row_height > 32.0, "long detail text should expand the row height instead of being truncated")
			for column_index in range(9):
				var row_cell := detail_grid.get_child(18 + column_index) as Label
				var expected_y := wrapped_cell.position.y + (wrapped_row_height - row_cell.size.y) / 2.0
				_expect(is_equal_approx(row_cell.position.y, expected_y), "wrapped detail row should vertically center column %d" % column_index)
		_expect(summary.text.find("总金币 120") >= 0, "dialog should show total round coins")
		_expect(summary.text.find("布局额外 +20") >= 0, "dialog should separate layout extra income")
		_expect(summary.text.find("海绵蛋糕") >= 0, "dialog should name the highest contributor")
		_expect(summary.text.find("布局加成：\n1. 黄金区售价 +10%\n2. 下午茶组合售速 +15%") >= 0, "dialog should number each layout bonus on its own line")
		_expect_equal("summary omits per-product listing", summary.text.find("各商品："), -1)
		_expect_equal("summary omits next-sale gap", summary.text.find("还差 2.0 秒"), -1)
		_expect_equal("summary omits leftover decision instructions", summary.text.find("新鲜余货"), -1)
		_expect(leftover_income.text.find("当前选择 5 折 5") >= 0, "leftover section should show selected clearance income")
		_expect(leftover_title.visible and grid.visible and leftover_income.visible, "leftover section should show when decisions exist")
		_expect(dialog.visible, "show_settlement should open the centered dialog")

		dialog.call("show_settlement", {
			"settlement_id": "round:4",
			"forced_entries": [{"recipe_id": "old_cake", "quantity": 1}],
			"forced_clearance_coins": 4,
			"round_summary": {"sold_count": 0, "total_coins": 0, "base_income": 0, "layout_extra_income": 0, "products": {}},
			"fresh_options": []
		}, {"old_cake": "隔夜蛋糕"})
		await process_frame
		var forced_clearance := dialog.get_node("SettlementBody/SettlementContent/ForcedClearanceLabel") as Label
		_expect_equal("leftover title hides without decisions", leftover_title.visible, false)
		_expect_equal("leftover table hides without decisions", grid.visible, false)
		_expect_equal("leftover income hides without decisions", leftover_income.visible, false)
		_expect_equal("completed forced clearance remains visible in summary", forced_clearance.visible, true)

	_expect(main.has_method("_confirm_showcase_round_settlement"), "Main should expose atomic settlement confirmation")
	main.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHOWCASE_ROUND_SETTLEMENT_DIALOG_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_ROUND_SETTLEMENT_DIALOG_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
