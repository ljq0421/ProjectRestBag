extends SceneTree

const VIEW_PATH := "res://scenes/challenge/challenge_battle_view.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	if not ResourceLoader.exists(VIEW_PATH):
		_fail("challenge battle view scene should exist")
		_finish()
		return
	var view_scene = load(VIEW_PATH)
	_expect(view_scene != null, "challenge battle view scene should load")
	if view_scene == null:
		_finish()
		return
	var view = view_scene.instantiate()
	root.add_child(view)
	await process_frame

	_expect(view.get_node("TopStatus/ReputationBar") is ProgressBar, "reputation bar should exist")
	_expect(view.get_node("TopStatus/PickinessBar") is ProgressBar, "pickiness bar should exist")
	_expect(view.get_node("TopStatus/PickinessBar").fill_mode == 1, "boss pressure should fill from the opposite direction")
	_expect(not view.get_node("BossPanel/BossPortrait/PressureCopy").text.is_empty(), "boss panel should explain the active pressure instead of showing an empty placeholder")
	_expect(
		view.has_node("BoardPresentation/BoardContent/BoardEvent/BoardEventLabel")
			and "周期到点自动卖 1 份" in view.get_node(
				"BoardPresentation/BoardContent/BoardEvent/BoardEventLabel"
			).text,
		"automatic-sale explanation should live beside the source grid"
	)
	var board_title: Label = view.get_node(
		"BoardPresentation/BoardContent/BoardHeader/BoardTitle"
	)
	var board_legend: Label = view.get_node(
		"BoardPresentation/BoardContent/BoardHeader/BoardLegend"
	)
	_expect(
		"格内标记见右侧速查" in board_title.text,
		"board header should direct players to the permanent explanation"
	)
	_expect(
		"中央=实际挑剔扣除 / 全局需求结果" in board_legend.text,
		"board header should name both central result types instead of saying only result"
	)
	var guide_body: Label = view.get_node("BossPanel/MechanicGuide/GuideContent/GuideBody")
	_expect(
		board_title.tooltip_text.is_empty()
			and board_legend.tooltip_text.is_empty(),
		"battle mark explanations should not depend on header hover tooltips"
	)
	_expect(
		view.has_node("BossPanel/MechanicGuide")
			and view.get_node("BossPanel/MechanicGuide").visible
			and "挑剔-X  本次实际扣除 X" in guide_body.text
			and "溢出满足力不计入" in guide_body.text
			and "需求达标 / 需求缺X" in guide_body.text
			and "多格重复不相加" in guide_body.text
			and "联动值+X" in guide_body.text
			and "金边 联动" in guide_body.text
			and "青边 强化" in guide_body.text
			and "红边 失败需求相关" in guide_body.text,
		"boss side should permanently explain every battle mark and overflow rule"
	)
	_expect(view.get_node("BossPanel/DemandTimeline").get_child_count() == 0, "timeline should not ship fixed window rows")

	var encounter := _encounter()
	var snapshot := _snapshot()
	view.call("bind_encounter", encounter)
	await process_frame
	var timeline: Node = view.get_node("BossPanel/DemandTimeline")
	_expect(timeline.get_child_count() == 4, "timeline should build three encounter windows plus the deadline")
	var grid: GridContainer = view.get_node("BoardPresentation/BoardContent/SnapshotGrid")
	var board_panel: Control = view.get_node("BoardPresentation")
	var boss_panel_background: Control = view.get_node("BossPanelBackground")
	_expect(
		board_panel.size.x >= 1090.0
			and grid.get_child(0).custom_minimum_size.x == 90.0,
		"left battle board and cells should be large enough for readable in-cell badges"
	)
	_expect(
		board_panel.size.x >= boss_panel_background.size.x * 1.9,
		"battle layout should reserve about two thirds of the content width for the grid"
	)
	var boss_panel_rect: Rect2 = view.get_node("BossPanel").get_global_rect()
	var deadline_rect: Rect2 = timeline.get_child(timeline.get_child_count() - 1).get_global_rect()
	_expect(
		boss_panel_rect.encloses(deadline_rect),
		"mechanic guide and activity log should leave the full demand timeline inside the boss panel: boss=%s deadline=%s"
			% [boss_panel_rect, deadline_rect]
	)
	var finished_count := {"value": 0}
	view.connect("battle_finished", func(_final_state: Dictionary) -> void:
		finished_count["value"] = int(finished_count["value"]) + 1
	)
	view.call("start_battle", snapshot, 42)
	_expect(bool(view.get("battle_locked")), "battle should lock immediately")
	var cookie_cell: PanelContainer = grid.get_child(2 * 8 + 3)
	var cycle_badge: Label = cookie_cell.get_node("CellOverlay/CycleBadge")
	var stock_badge: Label = cookie_cell.get_node("CellOverlay/StockBadge")
	var event_badge: Label = cookie_cell.get_node("CellOverlay/EventBadge")
	var relation_badge: Label = cookie_cell.get_node("CellOverlay/RelationBadge")
	_expect(cycle_badge.text == "4秒", "sale badge should start from the authoritative next-sale countdown")
	view.call("advance_for_test", 1000)
	_expect(cycle_badge.text == "3秒", "sale badge should visibly count down during battle")
	view.call("advance_for_test", 4000)
	_expect(
		"黄油曲奇 自动售出｜4 基础 + 0 联动 = 4 满足力"
			not in view.get_node("BattleFooter/CurrentDemandLabel").text,
		"footer should keep a compact outcome instead of duplicating the full calculation"
	)
	_expect(
		"黄油曲奇 自动售出：4 基础 + 1 联动 = 5 满足力"
			in view.get_node(
				"BoardPresentation/BoardContent/BoardEvent/BoardEventLabel"
			).text,
		"full sale calculation should appear beside the source grid"
	)
	_expect(cycle_badge.text == "4秒", "sale countdown should reset to the next cycle after a sale")
	_expect(stock_badge.text == "余5", "source cell should name its current remaining stock")
	_expect(event_badge.text == "挑剔-5", "source cell should name the final boss reduction")
	_expect(relation_badge.text == "联动值+1", "source cell should name the relation bonus as a value")
	view.call("_apply_event", {
		"type": "sale",
		"at_ms": 5500,
		"source_id": "cookie",
		"recipe_id": "butter_cookie",
		"base_satisfaction": 8,
		"relation_bonus": 2,
		"final_satisfaction": 10,
		"pickiness_reduction": 3
	}, false)
	_expect(
		event_badge.text == "挑剔-3"
			and "实际挑剔 -3" in view.get_node(
				"BoardPresentation/BoardContent/BoardEvent/BoardEventLabel"
			).text
			and "7 满足力溢出" in view.get_node(
				"BoardPresentation/BoardContent/BoardEvent/BoardEventLabel"
			).text
			and "Boss 挑剔 -3" in view.get_node("BattleFooter/CurrentDemandLabel").text,
		"lethal sale UI should show the actual reduction and name overflow separately"
	)
	_expect(
		cycle_badge.get_theme_font_size("font_size") >= 14
			and event_badge.get_theme_font_size("font_size") >= 18,
		"cell badges should remain legible instead of relying on tiny outlined text"
	)
	_expect(
		not cycle_badge.get_rect().intersects(stock_badge.get_rect())
			and not cycle_badge.get_rect().intersects(event_badge.get_rect())
			and not stock_badge.get_rect().intersects(event_badge.get_rect())
			and not event_badge.get_rect().intersects(relation_badge.get_rect()),
		"cell badge rectangles should never overlap"
	)
	var cell_rect := Rect2(Vector2.ZERO, cookie_cell.custom_minimum_size)
	_expect(
		cell_rect.encloses(cycle_badge.get_rect())
			and cell_rect.encloses(stock_badge.get_rect())
			and cell_rect.encloses(event_badge.get_rect())
			and cell_rect.encloses(relation_badge.get_rect()),
		"all real-time badges should stay fully inside the enlarged battle cell"
	)
	_expect(
		(event_badge.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.a > 0.9,
		"dynamic result should use an opaque high-contrast badge instead of outlined text over the icon"
	)
	_expect(
		not cookie_cell.has_node("TimingBadge")
			and not cookie_cell.has_node("EffectBadge"),
		"legacy full-cell labels should be removed so they cannot overlap"
	)
	var pudding_origin: PanelContainer = grid.get_child(2 * 8 + 4)
	var pudding_covered: PanelContainer = grid.get_child(3 * 8 + 4)
	var pudding_origin_icon: TextureRect = pudding_origin.get_node("IconHost/Icon")
	var pudding_covered_icon: TextureRect = pudding_covered.get_node("IconHost/Icon")
	_expect(
		pudding_origin_icon.texture != null
			and not pudding_origin_icon.texture is AtlasTexture
			and pudding_covered_icon.texture == null
			and pudding_origin_icon.size.y > 140.0,
		"multi-cell milk pudding should use one complete vertical image across two cells"
	)
	_expect(
		String(pudding_origin.get_meta("instance_id", ""))
			== String(pudding_covered.get_meta("instance_id", ""))
			and not pudding_covered.get_node("CellOverlay/CycleBadge").visible
			and not pudding_covered.get_node("CellOverlay/StockBadge").visible,
		"multi-cell recipe should be one instance with badges only on its origin cell"
	)
	_expect(
		"服务节奏" in cookie_cell.tooltip_text
			and "单次效果" in cookie_cell.tooltip_text
			and not "格内左上" in cookie_cell.tooltip_text,
		"occupied cell tooltip should keep recipe-specific details without hiding mark rules"
	)
	_expect(
		pudding_covered.tooltip_text == pudding_origin.tooltip_text
			and not "多个格子的数字不要相加" in pudding_covered.tooltip_text,
		"multi-cell parts should share recipe details while global mark rules remain permanently visible"
	)
	view.call("_show_window_on_grid", {
		"window_id": "early_tempo",
		"metric": "sales_count",
		"at_ms": 8000,
		"actual": 1,
		"target": 2,
		"passed": false,
		"reputation_damage": 25
	})
	_expect(
		"全局需求失败" in view.get_node(
			"BoardPresentation/BoardContent/BoardEvent/BoardEventLabel"
		).text
			and "整体还差 1" in view.get_node(
				"BoardPresentation/BoardContent/BoardEvent/BoardEventLabel"
			).text,
		"failed demand should explain its exact gap beside the grid"
	)
	_expect(event_badge.text == "需求缺1", "affected source cell should name the global demand gap")
	_expect(
		"累计出餐 1 / 2" in view.get_node("BossPanel/CurrentWindowProgress").text
			and "还差 1" in view.get_node("BossPanel/CurrentWindowProgress").text,
		"battle view should show live progress toward the next demand"
	)
	view.call("advance_for_test", 16000)
	var current_window := _timeline_window(timeline, "linked_display")
	_expect(current_window != null and current_window.text.begins_with("✓"), "current dynamic window should show event resolution")
	_expect(current_window != null and not "linked_display" in current_window.text, "resolved windows should not expose internal IDs")
	_expect(not "butter_cookie" in view.get_node("BattleFooter/CurrentDemandLabel").text, "sale feedback should use the player-facing recipe name")

	var saved_state: Dictionary = (view.get("battle_state") as Dictionary).duplicate(true)
	view.call("restore_battle", saved_state, encounter)
	_expect(bool(view.get("battle_paused")), "restored battle should start paused")
	view.call("advance_for_test", 24000)
	_expect(int((view.get("battle_state") as Dictionary).get("elapsed_ms", 0)) == 16000, "paused restored battle should not advance")
	view.call("set_paused", false)
	view.call("advance_for_test", 24000)
	_expect(int((view.get("battle_state") as Dictionary).get("elapsed_ms", 0)) == 24000, "continued battle should resume from saved time")

	view.call("advance_for_test", 30000)
	_expect(int(finished_count["value"]) == 1, "battle_finished should fire once at completion")
	view.call("advance_for_test", 30000)
	_expect(int(finished_count["value"]) == 1, "completed battle should not emit battle_finished twice")
	_expect(not bool(view.get("battle_paused")), "completed battle should not masquerade as paused")

	var compact_snapshot := snapshot.duplicate(true)
	var compact_unlocked_cells: Array = []
	for row in range(1, 5):
		for column in range(2, 6):
			compact_unlocked_cells.append([row, column])
	compact_snapshot["unlocked_cells"] = compact_unlocked_cells
	view.set("_snapshot", compact_snapshot)
	view.call("_render_snapshot")
	await process_frame
	_expect(
		grid.get_child_count() == 16
			and grid.get_child(0).custom_minimum_size == Vector2(132, 132),
		"compact 4x4 battles should expand their cells to use the available board area"
	)
	_expect(
		view.get_node("BoardPresentation").get_global_rect().encloses(grid.get_global_rect()),
		"expanded compact grid should remain inside the battle board"
	)

	view.queue_free()
	await process_frame
	_finish()


func _snapshot() -> Dictionary:
	return {
		"grid_rows": 6,
		"grid_columns": 8,
		"spent_budget": 2,
		"encounter_id": "test_boss",
		"applied_upgrades": [{"upgrade_id": "service_rhythm", "stack_count": 1}],
		"relations": [
			{
				"relation_id": "drink_bake_pair",
				"left_instance_id": "pudding",
				"right_instance_id": "cookie",
				"bonus_pct": 25,
				"upgrade_source_ids": []
			}
		],
		"instances": [
			{
				"instance_id": "cookie",
				"recipe_id": "butter_cookie",
				"origin": [2, 3],
				"cycle_ms": 4000,
				"virtual_stock": 6,
				"base_satisfaction": 4,
				"tags": ["fast", "bake"],
				"upgrade_source_ids": ["service_rhythm"],
				"cells": [[2, 3]]
			},
			{
				"instance_id": "pudding",
				"recipe_id": "milk_pudding",
				"origin": [2, 4],
				"cycle_ms": 5000,
				"virtual_stock": 4,
				"base_satisfaction": 7,
				"tags": ["drink", "milk"],
				"upgrade_source_ids": [],
				"cells": [[2, 4], [3, 4]]
			}
		]
	}


func _encounter() -> Dictionary:
	return {
		"duration_ms": 30000,
		"initial_pickiness": 999,
		"initial_reputation": 100,
		"relation_bonus_pct": 25,
		"relation": {"id": "drink_bake_pair", "left_tag": "drink", "right_tag": "bake"},
		"windows": [
			{"id": "early_tempo", "at_ms": 8000, "metric": "sales_count", "target": 2, "reputation_damage": 25},
			{"id": "linked_display", "at_ms": 16000, "metric": "active_relation_count", "target": 0, "reputation_damage": 30},
			{"id": "sustained_service", "at_ms": 24000, "from_ms": 16000, "metric": "window_satisfaction", "target": 0, "reputation_damage": 45}
		]
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _timeline_window(timeline: Node, window_id: String) -> Label:
	for child in timeline.get_children():
		if String(child.get_meta("window_id", "")) == window_id:
			return child as Label
	return null


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_BATTLE_VIEW_SELF_CHECK_PASS")
		quit(0)
		return
	for message in _failures:
		push_error(message)
	quit(1)
