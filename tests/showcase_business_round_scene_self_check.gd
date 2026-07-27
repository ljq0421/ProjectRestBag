extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GAME_STATE := preload("res://scripts/game_state.gd")
const ROUND_REPORT_SERVICE := preload("res://scripts/showcase_round_report_service.gd")
const SALE_FEEDBACK_SCENE_PATH := "res://scenes/ui/storefront/showcase_sale_feedback.tscn"

var _failures: Array[String] = []
var _save_path := OS.get_temp_dir().path_join("showcase_business_round_scene_self_check.json")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var view = MAIN_SCENE.instantiate()
	view.set("save_path", _save_path)
	view.set("broken_save_path", _save_path + ".broken")
	root.add_child(view)
	await process_frame
	await process_frame

	var round_bar := view.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar")
	var round_state_label := view.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/RoundStateLabel") as Label
	var weather_icon := view.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/WeatherForecastIcon") as TextureRect
	var countdown_icon := view.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/CountdownIcon") as Control
	var heat_bar := view.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/HeatBar") as ProgressBar
	var start_button := view.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/StartRoundButton") as Button
	for required in [round_bar, round_state_label, weather_icon, countdown_icon, heat_bar, start_button]:
		if required == null:
			_fail("showcase board should declare the complete round control bar")
			break
	if not view.has_method("_start_showcase_business_round") \
			or not view.has_method("_advance_showcase_business_round") \
			or not view.has_method("_refill_showcase_round_item"):
		_fail("main view should expose showcase business round runtime entrypoints")
		_finish(view)
		return
	_expect_sale_feedback_scene_contract()
	_expect_equal("runtime exposes shared event income breakdown", view.has_method("_showcase_sale_feedback_breakdown"), true)
	if view.has_method("_showcase_sale_feedback_breakdown"):
		var feedback_breakdown: Dictionary = view.call("_showcase_sale_feedback_breakdown", {
			"earned_coins": 86,
			"quantity": 1,
			"batch": "fresh"
		}, {
			"base_price": 50,
			"environment_price_pct": 16.0
		})
		_expect_equal("feedback base uses shared event attribution", int(feedback_breakdown.get("base_income", -1)), 50)
		_expect_equal("feedback market uses shared event attribution", int(feedback_breakdown.get("market_income", -1)), 8)
		_expect_equal("feedback layout uses shared event attribution", int(feedback_breakdown.get("layout_extra_income", -1)), 28)
		_expect_equal("feedback parts rebuild credited coins", int(feedback_breakdown.get("total_coins", -1)), 86)
	_expect_equal("runtime exposes layout boost percent", view.has_method("_showcase_layout_boost_percent"), true)
	if view.has_method("_showcase_layout_boost_percent"):
		_expect_equal("positive layout extra becomes integer percent", int(view.call("_showcase_layout_boost_percent", {
			"base_income": 50,
			"market_income": 0,
			"layout_extra_income": 10
		})), 20)
		_expect_equal("negative layout extra becomes loss percent", int(view.call("_showcase_layout_boost_percent", {
			"base_income": 50,
			"market_income": 0,
			"layout_extra_income": -5
		})), -10)
	_expect_equal("runtime exposes event boost percent", view.has_method("_showcase_sale_feedback_boost_percent"), true)
	if view.has_method("_showcase_sale_feedback_boost_percent"):
		_expect_equal("amplify reward preserves its explicit percent", int(view.call("_showcase_sale_feedback_boost_percent", {
			"bonus_only": true,
			"chain_source": "amplify",
			"feedback_breakdown": {"base_income": 0, "market_income": 0, "layout_extra_income": 12}
		})), 20)
		_expect_equal("harvest reward preserves its explicit percent", int(view.call("_showcase_sale_feedback_boost_percent", {
			"bonus_only": true,
			"chain_source": "harvest",
			"feedback_breakdown": {"base_income": 0, "market_income": 0, "layout_extra_income": 18}
		})), 30)
	_expect_equal("runtime exposes non-overlapping text placement", view.has_method("_showcase_sale_feedback_text_position"), true)
	if view.has_method("_showcase_sale_feedback_text_position"):
		var product_rect := Rect2(300, 260, 144, 144)
		var feedback_size := Vector2(180, 90)
		var feedback_position: Vector2 = view.call("_showcase_sale_feedback_text_position", product_rect, feedback_size, Vector2(1000, 700))
		var feedback_rect := Rect2(feedback_position, feedback_size)
		_expect_equal("feedback text stays off the sold product", feedback_rect.intersects(product_rect), false)
		_expect_equal("feedback text stays inside feedback layer", Rect2(Vector2.ZERO, Vector2(1000, 700)).encloses(feedback_rect), true)
		var wide_top_product := Rect2(100, 0, 800, 200)
		var bottom_position: Vector2 = view.call("_showcase_sale_feedback_text_position", wide_top_product, feedback_size, Vector2(1000, 700))
		var bottom_final_rect := Rect2(bottom_position - Vector2(0, 28), feedback_size)
		_expect_equal("bottom feedback remains off product through its upward animation", bottom_final_rect.intersects(wide_top_product), false)

	var state = GAME_STATE.new_game()
	for feature_id in ["output", "inventory", "research", "craft", "catalog", "list", "rulebook", "arrange", "business", "storefront_manage", "task"]:
		state.unlock_core_feature(feature_id)
	state.level = 2
	state.shop_level = 2
	state.record_task_event("display_product", {"recipe_id": "sponge_cake", "quantity": 1})
	state.add_recipe("sponge_cake")
	state.add_product("sponge_cake", 1)
	state.display_items = {
		"sponge_cake": {
			"cells": [Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(6, 6)],
			"fresh_stock": 3,
			"carried_stock": 0,
			"stock": 3,
			"variant_id": "standard"
		}
	}
	view.set("state", state)
	state.active_business_round["hotspot"] = {}
	view.call("_show_page", "storefront_manage")
	await process_frame
	var main_area := view.get_node_or_null("Root/Body/MainArea") as Control
	var main_area_minimum_width := main_area.get_combined_minimum_size().x if main_area != null else 0.0
	_expect_equal("runtime prepares environment before opening", view.has_method("_ensure_showcase_round_environment"), true)
	var preview_environment: Dictionary = view.call("_ensure_showcase_round_environment") if view.has_method("_ensure_showcase_round_environment") else {}
	_expect_equal("adjustment phase exposes environment preview", String(preview_environment.get("label", "")).is_empty(), false)

	var coins_before := int(state.coins)
	var task_popup := view.get_node_or_null("TaskPopup") as AcceptDialog
	if task_popup != null:
		task_popup.hide()
	_expect_equal("round starts", bool(view.call("_start_showcase_business_round")), true)
	_expect_equal("running phase", String(state.active_business_round.get("phase", "")), "running")
	_expect_equal("standard duration", int(state.active_business_round.get("duration_ms", 0)), 30000)
	_expect_equal("opening locks the previewed environment", state.active_business_round.get("environment", {}), preview_environment)
	_expect_equal("opening locks product roles", (state.active_business_round.get("role_snapshot", {}) as Dictionary).has("sponge_cake"), true)
	_expect_equal("runtime exposes item view state", view.has_method("_showcase_round_item_view"), true)
	if view.has_method("_showcase_round_item_view"):
		var initial_item_view: Dictionary = view.call("_showcase_round_item_view", "sponge_cake")
		_expect_equal("item view starts with fresh batch", String(initial_item_view.get("batch_label", "")), "新鲜")
		_expect_equal("item view exposes its independent sixteen-second cycle", int(initial_item_view.get("remaining_ms", 0)), 16000)
	await process_frame
	_expect_equal("starting an ordinary round does not fabricate a tutorial task notification", task_popup != null and task_popup.visible, false)
	if false and task_popup != null:
		_expect_equal("first-round notification title", task_popup.title, "第一轮营业开始")
		task_popup.hide()
	await process_frame
	_expect_equal("layout is locked during running", bool(view.call("_move_showcase_product", "sponge_cake", 62)), false)
	var runtime_roles: Dictionary = state.active_business_round.get("role_snapshot", {}).duplicate(true)
	runtime_roles["sponge_cake"] = {"role": "amplify"}
	state.active_business_round["role_snapshot"] = runtime_roles
	var controlled_items: Dictionary = state.active_business_round.get("item_states", {}).duplicate(true)
	var controlled_item: Dictionary = controlled_items.get("sponge_cake", {}).duplicate(true)
	controlled_item["duration_ms"] = 5000
	controlled_item["base_duration_ms"] = 5000
	controlled_item["market_duration_ms"] = 5000
	controlled_item["fresh_stock"] = 6
	controlled_item["carried_stock"] = 0
	controlled_item["waiting_for_refill"] = false
	controlled_items["sponge_cake"] = controlled_item
	state.active_business_round["item_states"] = controlled_items.duplicate(true)
	state.active_business_round["initial_item_states"] = controlled_items.duplicate(true)

	view.call("_advance_showcase_business_round", 25000)
	state.active_business_round["paused"] = true
	_expect_equal("controlled five-sale batch credits coins", int(state.coins) > coins_before, true)
	var feedback_layer := view.get_node_or_null("ShowcaseFeedbackLayer")
	var real_sale_feedback := _find_descendant_with_meta(feedback_layer, "showcase_sale_feedback_text", true)
	_expect_equal("real round sale creates visible transparent sale text", real_sale_feedback != null, true)
	if real_sale_feedback != null:
		var coin_label := real_sale_feedback.get_node_or_null("CoinLabel") as Label
		var reputation_label := real_sale_feedback.get_node_or_null("ReputationLabel") as Label
		var boost_label := real_sale_feedback.get_node_or_null("BoostLabel") as Label
		_expect_equal("sale text exposes credited coins", coin_label != null and coin_label.text.find("金币 +") >= 0, true)
		_expect_equal("sale text exposes credited reputation", reputation_label != null and reputation_label.visible and reputation_label.text.find("口碑 +") >= 0, true)
		_expect_equal("neutral cross-region sale does not invent layout percentage", boost_label != null and not boost_label.visible, true)
	_expect_equal("old sale card marker is absent", _find_descendant_with_meta(feedback_layer, "showcase_sale_feedback", true) == null, true)
	_expect_equal("same product starts only one text group", _count_descendants_with_meta(feedback_layer, "showcase_sale_feedback_text", true), 1)
	_expect_equal("real round sale outlines the whole sold product", _has_feedback_role(feedback_layer, "sold"), true)
	var routed_events: Array = state.active_business_round.get("sale_events", [])
	var bonus_event_count := 0
	for routed_event_value in routed_events:
		if routed_event_value is Dictionary and bool((routed_event_value as Dictionary).get("bonus_only", false)):
			bonus_event_count += 1
	_expect_equal("real amplify batch records five natural sales plus two bonus rewards", routed_events.size(), 7)
	_expect_equal("real amplify rewards remain bonus-only", bonus_event_count, 2)
	var feedback_director = view.get("showcase_feedback_director")
	_expect_equal("later same-product feedback waits instead of overlapping", feedback_director.pending_count(), 6)
	_expect_equal("director tracks one active group for the same product", feedback_director.active_count(), 1)
	var first_visual_target := coins_before + int((routed_events[0] as Dictionary).get("earned_coins", 0))
	_expect_equal("top coin roll initially targets only the feedback event that started", int(view.get("showcase_feedback_visual_coin_target")), first_visual_target)
	_expect_equal("overflow aggregate text is removed", _find_label_containing(feedback_layer, "另外售出") == null, true)
	_expect_equal("single sale does not count day", int(state.business_runs), 0)
	_expect_equal("real sale generates four heat", int(state.active_business_round.get("heat", 0)), 4)
	var active_items: Dictionary = state.active_business_round.get("item_states", {})
	var active_item: Dictionary = active_items.get("sponge_cake", {})
	_expect_equal("five sales consume five fresh items", int(active_item.get("fresh_stock", 0)), 1)

	view.call("_play_showcase_sale_pulse", {
		"anchor_slot": 60,
		"cell_indices": [60, 61, 74, 75],
		"related_slots": [62],
		"conflict_slots": [63],
		"earned_coins": 86,
		"attribution": {"conflict_loss": 6},
		"feedback_breakdown": {"base_income": 50, "market_income": 8, "layout_extra_income": 28, "total_coins": 86}
	})
	await process_frame
	_expect_equal("positive layout contributor receives an orange outline", _has_feedback_role(feedback_layer, "contributor"), true)
	_expect_equal("conflicting neighbor receives a red outline", _has_feedback_role(feedback_layer, "conflict"), true)
	var conflict_label := _find_visible_label(feedback_layer, "ConflictLabel")
	_expect_equal("old conflict amount card is removed", conflict_label, null)
	var sold_outline := _find_descendant_with_meta(feedback_layer, "showcase_feedback_role", "sold") as Panel
	if sold_outline != null:
		var sold_style := sold_outline.get_theme_stylebox("panel") as StyleBoxFlat
		_expect_equal("sold product keeps a gold success outline even with conflict", sold_style != null and sold_style.border_color.g > sold_style.border_color.r * 0.65, true)
	await create_timer(2.10).timeout
	_expect_equal("queued same-product feedback resumes after a visual slot releases", feedback_director.pending_count(), 5)
	_expect_equal("queued feedback continues one group at a time", feedback_director.active_count(), 1)
	var second_visual_target := first_visual_target + int((routed_events[1] as Dictionary).get("earned_coins", 0))
	_expect_equal("next queued event advances the top coin roll target by its own coins", int(view.get("showcase_feedback_visual_coin_target")), second_visual_target)
	var queue_timeout_seconds := 12.0
	while (feedback_director.pending_count() > 0 or feedback_director.active_count() > 0) and queue_timeout_seconds > 0.0:
		await create_timer(0.25).timeout
		queue_timeout_seconds -= 0.25
	await create_timer(2.25).timeout
	_expect_equal("same-product feedback queue fully drains", feedback_director.pending_count(), 0)
	_expect_equal("all feedback slots release after the queue drains", feedback_director.active_count(), 0)
	_expect_equal("all transparent feedback text clears after playback", _count_descendants_with_meta(feedback_layer, "showcase_sale_feedback_text", true), 0)
	_expect_equal("queued coin arrivals finish at the credited state balance", int(view.get("showcase_feedback_visual_coin_target")), int(state.coins))
	var top_coins_label := view.get_node_or_null("Root/TopBar/CoinsLabel") as Label
	var expected_coin_prefix := "金币 %d /" % int(state.coins)
	var coin_label_timeout := 3.0
	while top_coins_label != null and not top_coins_label.text.contains(expected_coin_prefix) and coin_label_timeout > 0.0:
		await create_timer(0.1).timeout
		coin_label_timeout -= 0.1
	if top_coins_label == null or not top_coins_label.text.contains(expected_coin_prefix):
		_fail("top coin label should finish at %d, got %s" % [int(state.coins), top_coins_label.text if top_coins_label != null else "<missing>"])

	_expect_equal("inventory drag refills during the running round", bool(view.call("_drop_showcase_data", "showcase", {
		"kind": "inventory_product",
		"recipe_id": "sponge_cake",
		"variant_id": "standard",
		"target_slot_index": 60
	})), true)
	_expect_equal("round refill consumes inventory", int(state.get_product_count("sponge_cake")), 0)
	active_items = state.active_business_round.get("item_states", {})
	active_item = active_items.get("sponge_cake", {})
	_expect_equal("round refill adds one fresh item", int(active_item.get("fresh_stock", 0)), 2)

	state.display_items["butter_cookie"] = {"cells": [Vector2i(5, 7)], "stock": 1}
	state.display_items["mint_mousse"] = {"cells": [Vector2i(5, 8)], "stock": 1}
	var enriched_feedback: Dictionary = view.call("_enrich_showcase_sale_feedback_event", {
		"recipe_id": "sponge_cake",
		"earned_coins": 86,
		"quantity": 1,
		"batch": "fresh"
	}, {
		"base_price": 50,
		"environment_price_pct": 16.0,
		"bonus": {"breakdown": {
			"adjacency_tag": {"price_pct": 5.0, "related_recipe_ids": ["butter_cookie"]},
			"conflict": {"price_pct": -5.0, "related_recipe_ids": ["mint_mousse"]}
		}}
	})
	_expect_equal("runtime enrichment maps contributor recipe to its live showcase anchor", (enriched_feedback.get("related_slots", []) as Array).has(62), true)
	_expect_equal("runtime enrichment maps conflict recipe to its live showcase anchor", (enriched_feedback.get("conflict_slots", []) as Array).has(63), true)

	state.active_business_round["paused"] = false
	view.call("_advance_showcase_business_round", 5000)
	_expect_equal("round reaches settlement", String(state.active_business_round.get("phase", "")), "settlement")
	_expect_equal("round creates pending settlement", String(state.pending_showcase_settlement.get("settlement_id", "")), "round:1")
	_expect_equal("unconfirmed settlement does not count day", int(state.business_runs), 0)
	var round_summary: Dictionary = state.pending_showcase_settlement.get("round_summary", {})
	_expect_equal("settlement summarizes six completed sales", int(round_summary.get("sold_count", 0)), 6)
	_expect_equal("settlement exposes total sale coins", int(round_summary.get("total_coins", 0)) > 0, true)
	_expect_equal("settlement exposes per-product sale count", int((round_summary.get("products", {}).get("sponge_cake", {}) as Dictionary).get("sold_count", 0)), 6)
	_expect_equal("settlement names the highest contributor", String(round_summary.get("top_recipe_id", "")), "sponge_cake")
	var immediate_total := 0
	for recorded_event_value in state.active_business_round.get("sale_events", []):
		if recorded_event_value is Dictionary:
			immediate_total += int(ROUND_REPORT_SERVICE.event_income_breakdown(recorded_event_value as Dictionary).get("total_coins", 0))
	var settlement_dialog := view.get_node_or_null("ShowcaseRoundSettlementDialog") as ConfirmationDialog
	_expect_equal("settlement dialog exists for pending recovery", settlement_dialog != null, true)
	if start_button != null:
		_expect_equal("pending settlement button is enabled", start_button.disabled, false)
		_expect_equal("pending settlement button keeps its action label", start_button.text, "待结算")
		_expect_equal("pending settlement button explains reopen action", start_button.tooltip_text.find("重新打开") >= 0, true)
	if settlement_dialog != null:
		settlement_dialog.hide()
	var reopen_coins_before := int(state.coins)
	var reopen_business_runs_before := int(state.business_runs)
	var reopen_round_id_before := int(state.active_business_round.get("round_id", 0))
	var reopen_quote_before: Dictionary = state.pending_showcase_settlement.duplicate(true)
	var reopen_applied_ids_before: Array[String] = state.applied_showcase_settlement_ids.duplicate()
	if start_button != null:
		start_button.pressed.emit()
	await process_frame
	if settlement_dialog != null:
		_expect_equal("pending settlement button reopens the dialog", settlement_dialog.visible, true)
	_expect_equal("reopening settlement does not credit coins", int(state.coins), reopen_coins_before)
	_expect_equal("reopening settlement does not count a business day", int(state.business_runs), reopen_business_runs_before)
	_expect_equal("reopening settlement preserves the round id", int(state.active_business_round.get("round_id", 0)), reopen_round_id_before)
	_expect_equal("reopening settlement preserves its quote", state.pending_showcase_settlement, reopen_quote_before)
	_expect_equal("reopening settlement does not apply an id", state.applied_showcase_settlement_ids, reopen_applied_ids_before)
	if countdown_icon != null:
		_expect_equal("countdown tooltip reaches zero", countdown_icon.tooltip_text.find("0.0") >= 0, true)
	_expect_equal("settlement confirmation succeeds", bool(view.call("_confirm_showcase_round_settlement", {"sponge_cake": "carry_80"})), true)
	_expect_equal("confirmed settlement counts one business day", int(state.business_runs), 1)
	_expect_equal("confirmed settlement stores one round report", state.recent_showcase_round_reports.size(), 1)
	if not state.recent_showcase_round_reports.is_empty():
		var stored_report: Dictionary = state.recent_showcase_round_reports.back()
		_expect_equal("stored replay report reconciles all immediate credited events", int(stored_report.get("normal_income", 0)), immediate_total)
		_expect_equal("stored replay categories rebuild normal income", int(stored_report.get("base_income", 0)) + int(stored_report.get("market_income", 0)) + int(stored_report.get("layout_extra_income", 0)), int(stored_report.get("normal_income", 0)))
		_expect_equal("completed round uses replay attribution", bool(stored_report.get("replay_verified", false)), true)
	_expect_equal("next round returns to adjustment", String(state.active_business_round.get("phase", "")), "adjusting")
	_expect_equal("next round id increments", int(state.active_business_round.get("round_id", 0)), 2)
	_expect_equal("pending settlement clears", state.pending_showcase_settlement, {})
	await process_frame
	if main_area != null:
		_expect_equal("settlement should not widen the main page minimum width", main_area.get_combined_minimum_size().x, main_area_minimum_width)
	var settled_weather_icon := view.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/WeatherForecastIcon") as TextureRect
	if settled_weather_icon != null:
		_expect_equal("environment tooltip should preserve price details", settled_weather_icon.tooltip_text.find("售价") >= 0, true)
		_expect_equal("environment tooltip should preserve speed details", settled_weather_icon.tooltip_text.find("售速") >= 0, true)
	var settled_item: Dictionary = state.display_items.get("sponge_cake", {})
	_expect_equal("fresh leftover becomes 80 percent carried batch", int(settled_item.get("carried_stock", 0)), 1)
	if start_button != null:
		_expect_equal("start button reenabled for adjustment", start_button.disabled, false)
		_expect_equal("adjustment button restores its action label", start_button.text, "开始营业")
	if countdown_icon != null:
		_expect_equal("next standard round tooltip resets to thirty seconds", countdown_icon.tooltip_text.find("30.0") >= 0, true)
	state.active_business_round["phase"] = "settlement"
	state.pending_showcase_settlement = {}
	view.call("_refresh_showcase_round_controls")
	if start_button != null:
		_expect_equal("missing settlement data disables the round button", start_button.disabled, true)
		_expect_equal("missing settlement data exposes an error label", start_button.text, "结算异常")
		_expect_equal("missing settlement data explains recovery", start_button.tooltip_text.find("重新加载") >= 0, true)
	var abnormal_round_id := int(state.active_business_round.get("round_id", 0))
	_expect_equal("missing settlement data cannot start another round", bool(view.call("_start_showcase_business_round")), false)
	_expect_equal("missing settlement data preserves settlement phase", String(state.active_business_round.get("phase", "")), "settlement")
	_expect_equal("missing settlement data preserves the round id", int(state.active_business_round.get("round_id", 0)), abnormal_round_id)

	_finish(view)


func _expect_sale_feedback_scene_contract() -> void:
	if not FileAccess.file_exists(SALE_FEEDBACK_SCENE_PATH):
		_fail("showcase sale feedback should use a stable scene template")
		return
	var packed := load(SALE_FEEDBACK_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("showcase sale feedback scene should load")
		return
	var feedback := packed.instantiate() as Control
	if feedback is PanelContainer:
		_fail("showcase sale feedback should be transparent text, not a panel card")
	if not feedback.has_meta("showcase_sale_feedback_text"):
		_fail("showcase sale feedback text should expose a stable runtime marker")
	for path in ["CoinLabel", "ReputationLabel", "BoostLabel"]:
		var label := feedback.get_node_or_null(path) as Label
		if label == null:
			_fail("showcase sale feedback text should declare %s" % path)
		elif label.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_fail("%s should not intercept showcase refills" % path)
	for removed_path in ["FeedbackContent/AmountLabel", "FeedbackContent/BreakdownRow/BaseLabel", "FeedbackContent/MarketLabel", "FeedbackContent/ConflictLabel"]:
		if feedback.get_node_or_null(removed_path) != null:
			_fail("transparent sale text should remove old card node %s" % removed_path)
	feedback.free()


func _find_visible_label(node: Node, node_name: String) -> Label:
	if node == null:
		return null
	if node is Label and node.name == node_name and (node as Label).visible:
		return node as Label
	for child in node.get_children():
		var found := _find_visible_label(child, node_name)
		if found != null:
			return found
	return null


func _find_label_containing(node: Node, needle: String) -> Label:
	if node == null:
		return null
	if node is Label and (node as Label).text.find(needle) >= 0:
		return node as Label
	for child in node.get_children():
		var found := _find_label_containing(child, needle)
		if found != null:
			return found
	return null


func _find_descendant_with_meta(node: Node, key: String, expected: Variant) -> Node:
	if node == null:
		return null
	if node.has_meta(key) and node.get_meta(key) == expected:
		return node
	for child in node.get_children():
		var found := _find_descendant_with_meta(child, key, expected)
		if found != null:
			return found
	return null


func _count_descendants_with_meta(node: Node, key: String, expected: Variant) -> int:
	if node == null:
		return 0
	var result := 1 if node.has_meta(key) and node.get_meta(key) == expected else 0
	for child in node.get_children():
		result += _count_descendants_with_meta(child, key, expected)
	return result


func _has_feedback_role(feedback_layer: Node, role: String) -> bool:
	return _find_descendant_with_meta(feedback_layer, "showcase_feedback_role", role) != null


func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish(view) -> void:
	if is_instance_valid(view):
		view.queue_free()
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	if FileAccess.file_exists(_save_path + ".tmp"):
		DirAccess.remove_absolute(_save_path + ".tmp")
	if _failures.is_empty():
		print("SHOWCASE_BUSINESS_ROUND_SCENE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("SHOWCASE_BUSINESS_ROUND_SCENE_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
