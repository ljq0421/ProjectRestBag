class_name ChallengeMainView
extends Control

const Catalog = preload("res://scripts/catalog.gd")
const ChallengeSaveService = preload("res://scripts/challenge/challenge_save_service.gd")
const ChallengeConfigValidator = preload("res://scripts/challenge/challenge_config_validator.gd")
const ChallengeLoadoutService = preload("res://scripts/challenge/challenge_loadout_service.gd")
const BossBattleService = preload("res://scripts/challenge/boss_battle_service.gd")
const BossBattleReportService = preload("res://scripts/challenge/boss_battle_report_service.gd")
const ChallengeRunService = preload("res://scripts/challenge/challenge_run_service.gd")
const ChallengeTutorialProgress = preload("res://scripts/challenge/challenge_tutorial_progress.gd")

const RECIPE_CONFIG_PATH := "res://doc/challenge/challenge_recipes.json"
const ENCOUNTER_CONFIG_PATH := "res://doc/challenge/boss_encounters.json"
const ENCOUNTER_ID := "picky_food_critic"

@export var save_path := ChallengeSaveService.SAVE_PATH

var run_state: Dictionary = {}
var battle_state: Dictionary = {}

var _save_data: Dictionary = {}
var _recipe_config: Dictionary = {}
var _encounter_config: Dictionary = {}
var _recipe_defs: Dictionary = {}
var _encounter: Dictionary = {}
var _config_valid := false
var _loadout_service = ChallengeLoadoutService.new()
var _battle_service = BossBattleService.new()
var _report_service = BossBattleReportService.new()
var _run_service = ChallengeRunService.new()
var _last_saved_elapsed := -1
var _tutorial_progress = ChallengeTutorialProgress.new()
var _tutorial_state: Dictionary = {}
var _tutorial_replay_mode := false
var _tutorial_persistence_blocked := false
var _battle_tutorial_hint_shown := false


func _ready() -> void:
	$Root/Body/PreparationPanel/StartButton.pressed.connect(start_battle)
	$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.draft_changed.connect(_on_draft_changed)
	$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.placement_rejected.connect(_on_placement_rejected)
	$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.recipe_placed.connect(
		func(_instance_id: String, recipe_id: String) -> void:
			_apply_tutorial_event("recipe_placed", {"recipe_id": recipe_id})
			_on_board_mutated()
	)
	$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.instance_moved.connect(
		func(_instance_id: String) -> void: _on_board_mutated()
	)
	$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.instance_rotated.connect(
		func(_instance_id: String, recipe_id: String, _rotation: int, shape_changed: bool) -> void:
			_apply_tutorial_event("instance_rotated", {
				"recipe_id": recipe_id,
				"shape_changed": shape_changed
			})
			_on_board_mutated()
	)
	$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.instance_removed.connect(
		func(_instance_id: String) -> void: _on_board_mutated()
	)
	$Root/Body/BattlePanel/ChallengeBattleView.battle_finished.connect(_on_battle_finished)
	$SettlementDialog.report_action_requested.connect(_on_report_action_requested)
	$SettlementDialog.retry_requested.connect(retry_same_encounter)
	$SettlementDialog.back_requested.connect(_return_to_preparation)
	$SettlementDialog.tutorial_help_requested.connect(_on_settlement_tutorial_help_requested)
	$TutorialCanvasLayer/TutorialOverlay.confirm_requested.connect(_on_tutorial_confirm_requested)
	start_vertical_slice()


func _process(_delta: float) -> void:
	if not $Root/Body/BattlePanel.visible:
		return
	var current_state: Dictionary = $Root/Body/BattlePanel/ChallengeBattleView.battle_state
	if String(current_state.get("phase", "")) != "running":
		return
	var elapsed_ms := int(current_state.get("elapsed_ms", 0))
	if elapsed_ms / 1000 != _last_saved_elapsed / 1000:
		battle_state = current_state.duplicate(true)
		_last_saved_elapsed = elapsed_ms
		_save_now(true)


func start_vertical_slice() -> void:
	_load_configuration()
	_bind_preparation()
	_load_or_create_run()
	_refresh_top_bar()
	if _restore_active_battle():
		_initialize_tutorial()
		_schedule_battle_tutorial_fade()
		return
	_show_preparation()
	var saved_draft = _save_data.get("active_draft")
	if saved_draft is Dictionary:
		$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.set_draft(saved_draft)
	else:
		$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.set_draft({"placements": []})
	_initialize_tutorial()
	_save_now(false)


func start_battle() -> void:
	if not _config_valid:
		return
	var board = $Root/Body/PreparationPanel/MainColumns/ChallengeBoard
	var draft: Dictionary = board.get_draft()
	if (draft.get("placements", []) as Array).is_empty():
		$Root/Body/PreparationPanel/StartButton.tooltip_text = "至少放入一个挑战配方。"
		return
	var built: Dictionary = _loadout_service.build_snapshot(
		draft,
		_recipe_defs,
		_encounter,
		int(_recipe_config.get("grid_rows", 6)),
		int(_recipe_config.get("grid_columns", 8)),
		int(_recipe_config.get("supply_budget", 16))
	)
	if not bool(built.get("ok", false)):
		var errors: Array = built.get("errors", [])
		$Root/Body/PreparationPanel/StartButton.tooltip_text = String(errors[0]) if not errors.is_empty() else "挑战备货无效。"
		return

	var snapshot: Dictionary = built.get("snapshot", {})
	run_state["phase"] = "battle"
	$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.set_locked(true)
	$Root/Body/BattlePanel/ChallengeBattleView.bind_encounter(_encounter)
	$Root/Body/BattlePanel/ChallengeBattleView.set_confidence(int(run_state.get("confidence", 2)))
	$Root/Body/BattlePanel/ChallengeBattleView.start_battle(snapshot, int(run_state.get("encounter_seed", 42)))
	battle_state = $Root/Body/BattlePanel/ChallengeBattleView.battle_state.duplicate(true)
	$Root/Body/PreparationPanel.visible = false
	$Root/Body/BattlePanel.visible = true
	_last_saved_elapsed = 0
	_apply_tutorial_event("battle_started", {"draft": draft})
	_schedule_battle_tutorial_fade()
	_save_now(true)
	_refresh_top_bar()


func retry_same_encounter() -> void:
	if String(run_state.get("phase", "")) != "preparation" or int(run_state.get("confidence", 0)) <= 0:
		return
	$SettlementDialog.hide_tutorial_report()
	$SettlementDialog.hide()
	battle_state = {}
	$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.set_locked(false)
	_show_preparation()
	_save_now(false)
	_refresh_top_bar()


func set_draft_for_test(draft: Dictionary) -> void:
	$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.set_draft(draft)


func advance_battle_for_test(target_elapsed_ms: int) -> void:
	$Root/Body/BattlePanel/ChallengeBattleView.advance_for_test(target_elapsed_ms)
	battle_state = $Root/Body/BattlePanel/ChallengeBattleView.battle_state.duplicate(true)


func _initialize_tutorial() -> void:
	var surface := _current_tutorial_surface()
	var raw_onboarding = _save_data.get("onboarding")
	_tutorial_state = _tutorial_progress.normalize(raw_onboarding, surface)
	_tutorial_persistence_blocked = bool(_tutorial_state.get("unsupported_newer_version", false))
	if _tutorial_persistence_blocked:
		_hide_all_tutorial_surfaces()
		push_warning("Challenge onboarding was created by a newer client; leaving it unchanged.")
		return
	_save_data["onboarding"] = _tutorial_state.duplicate(true)
	if not raw_onboarding is Dictionary or raw_onboarding != _tutorial_state:
		_save_now(not battle_state.is_empty())
	_refresh_tutorial()


func _apply_tutorial_event(event_id: String, context: Dictionary = {}) -> void:
	if _tutorial_replay_mode or _tutorial_persistence_blocked:
		return
	var next := _tutorial_progress.apply_event(_tutorial_state, event_id, context)
	if next == _tutorial_state:
		return
	_tutorial_state = next
	_save_data["onboarding"] = next.duplicate(true)
	_save_now($Root/Body/BattlePanel.visible)
	_refresh_tutorial()


func _refresh_tutorial() -> void:
	if _tutorial_persistence_blocked or String(_tutorial_state.get("status", "")) != "active":
		_hide_all_tutorial_surfaces()
		return
	if $SettlementDialog.visible or _current_tutorial_surface() == "finished":
		$TutorialCanvasLayer/TutorialOverlay.hide_step()
		return
	var step_id := String(_tutorial_state.get("step_id", "boss_brief"))
	var copy := _tutorial_copy(step_id)
	$TutorialCanvasLayer/TutorialOverlay.show_step(
		ChallengeTutorialProgress.STEPS.find(step_id) + 1,
		ChallengeTutorialProgress.STEPS.size(),
		String(copy.get("title", "")),
		String(copy.get("body", "")),
		resolve_tutorial_targets(step_id),
		String(copy.get("confirm", "")),
		false
	)


func _hide_all_tutorial_surfaces() -> void:
	$TutorialCanvasLayer/TutorialOverlay.hide_step()
	$SettlementDialog.hide_tutorial_report()


func _current_tutorial_surface() -> String:
	if $SettlementDialog.visible:
		return "settlement"
	if $Root/Body/BattlePanel.visible:
		return "battle"
	return "preparation"


func _on_tutorial_confirm_requested() -> void:
	match String(_tutorial_state.get("step_id", "")):
		"boss_brief":
			_apply_tutorial_event("boss_acknowledged")
		"read_risk":
			var board = $Root/Body/PreparationPanel/MainColumns/ChallengeBoard
			_apply_tutorial_event("risk_acknowledged", {
				"draft_valid": board.is_current_draft_valid()
			})
		"complete":
			_apply_tutorial_event("tutorial_completed")


func get_tutorial_state_for_test() -> Dictionary:
	return _tutorial_state.duplicate(true)


func acknowledge_tutorial_for_test() -> void:
	_on_tutorial_confirm_requested()


func exit_report_for_test(action: String) -> void:
	_on_report_action_requested(action)
	if action == "retry":
		retry_same_encounter()
	else:
		_return_to_preparation()


func resolve_tutorial_targets(step_id: String) -> Array[Rect2]:
	var board = $Root/Body/PreparationPanel/MainColumns/ChallengeBoard
	match step_id:
		"boss_brief":
			return [$Root/Body/PreparationPanel/MainColumns/BossPreview.get_global_rect()]
		"place_recipe":
			var placement_targets: Array[Rect2] = [$Root/Body/PreparationPanel/SupplyStrip.get_global_rect()]
			placement_targets.append_array(board.get_tutorial_target_rects("board"))
			return placement_targets
		"rotate_recipe":
			for placement_value in board.get_draft().get("placements", []):
				var placement: Dictionary = placement_value
				if ChallengeTutorialProgress.ROTATABLE_RECIPE_IDS.has(String(placement.get("recipe_id", ""))):
					var instance_targets: Array[Rect2] = board.get_tutorial_target_rects("instance", String(placement.get("instance_id", "")))
					if not instance_targets.is_empty():
						return instance_targets
			var supply_targets: Array[Rect2] = []
			for card in $Root/Body/PreparationPanel/SupplyStrip.get_children():
				if ChallengeTutorialProgress.ROTATABLE_RECIPE_IDS.has(String(card.get_meta("recipe_id", ""))):
					supply_targets.append(card.get_global_rect())
			return supply_targets
		"read_risk":
			return board.get_tutorial_target_rects("risk")
		"start_battle":
			return [$Root/Body/PreparationPanel/StartButton.get_global_rect()]
		"observe_battle":
			return [
				$Root/Body/BattlePanel/ChallengeBattleView/TopStatus.get_global_rect(),
				$Root/Body/BattlePanel/ChallengeBattleView/BossPanel/DemandTimeline.get_global_rect()
			]
		"rearrange":
			return board.get_tutorial_target_rects("board")
		"complete":
			return [$Root/TopBar/TutorialHelpButton.get_global_rect()]
	return []


func _tutorial_copy(step_id: String) -> Dictionary:
	match step_id:
		"boss_brief":
			return {"title": "了解 Boss 的完整要求", "body": "8、16、24 秒会检查需求；30 秒前要清空挑剔值。", "confirm": "开始准备"}
		"place_recipe":
			return {"title": "挑一份挑战备货", "body": "把任意配方拖进展示柜。本模式不会消耗经营库存。"}
		"rotate_recipe":
			return {"title": "试试右键旋转", "body": "牛奶布丁和蓝莓松饼可以改变占格方向。"}
		"read_risk":
			return {"title": "先看覆盖，再决定开战", "body": "预算、联动和失败窗口预测会随布局变化。", "confirm": "看懂风险了"}
		"start_battle":
			return {"title": "锁定陈列，开始挑战", "body": "开战后展示柜锁定，战斗会自动进行。"}
		"observe_battle":
			return {"title": "同时看住两条压力", "body": "满意度会降低 Boss 挑剔值；需求失败会损伤口碑防线。"}
		"read_report":
			return {"title": "从战报找出下一步", "body": "先看失败窗口，再看各配方贡献与调整建议。"}
		"rearrange":
			return {"title": "根据战报重排一次", "body": "移动、旋转、增加或移除配方；合法布局发生变化才算完成。"}
		"complete":
			return {"title": "核心循环已经掌握", "body": "以后可通过顶部问号重播引导。", "confirm": "完成引导"}
	return {"title": "", "body": ""}


func _schedule_battle_tutorial_fade() -> void:
	if (
		_battle_tutorial_hint_shown
		or String(_tutorial_state.get("step_id", "")) != "observe_battle"
	):
		return
	_battle_tutorial_hint_shown = true
	_refresh_tutorial()
	await get_tree().create_timer(3.0).timeout
	if (
		String(_tutorial_state.get("step_id", "")) == "observe_battle"
		and not _tutorial_replay_mode
	):
		$TutorialCanvasLayer/TutorialOverlay.hide_step()


func _load_configuration() -> void:
	_recipe_config = _load_json(RECIPE_CONFIG_PATH)
	_encounter_config = _load_json(ENCOUNTER_CONFIG_PATH)
	var catalog_recipes: Dictionary = Catalog.new().get_recipes()
	var result: Dictionary = ChallengeConfigValidator.new().validate(
		_recipe_config,
		_encounter_config,
		catalog_recipes
	)
	_config_valid = bool(result.get("valid", false))
	_recipe_defs = result.get("recipe_defs", {})
	_encounter = (result.get("encounters", {}) as Dictionary).get(ENCOUNTER_ID, {})
	if not _config_valid:
		var errors: Array = result.get("errors", [])
		var first_error := String(errors[0]) if not errors.is_empty() else "未知错误"
		$Root/TopBar/SaveStatusLabel.text = "挑战配置无效：%s" % first_error
		$Root/Body/PreparationPanel/StartButton.disabled = true


func _bind_preparation() -> void:
	var board = $Root/Body/PreparationPanel/MainColumns/ChallengeBoard
	board.bind(
		_recipe_defs,
		_loadout_service,
		_encounter,
		int(_recipe_config.get("supply_budget", 16))
	)
	var catalog_recipes: Dictionary = Catalog.new().get_recipes()
	for card in $Root/Body/PreparationPanel/SupplyStrip.get_children():
		var recipe_id := String(card.get_meta("recipe_id", ""))
		var catalog_entry: Dictionary = catalog_recipes.get(recipe_id, {})
		card.bind(recipe_id, _recipe_defs.get(recipe_id, {}), String(catalog_entry.get("name", recipe_id)))
	_bind_boss_preview()


func _bind_boss_preview() -> void:
	var preview = $Root/Body/PreparationPanel/MainColumns/BossPreview/Margin/Content
	preview.get_node("BossName").text = "挑剔的美食评论家"
	preview.get_node("BossStats").text = "挑剔值 %d｜口碑防线 %d｜全自动 %d 秒" % [
		int(_encounter.get("initial_pickiness", 0)),
		int(_encounter.get("initial_reputation", 0)),
		int(_encounter.get("duration_ms", 0) / 1000)
	]
	var timeline_lines: Array[String] = ["[b]本场完整需求时间轴[/b]"]
	for window_value in _encounter.get("windows", []):
		var window: Dictionary = window_value
		timeline_lines.append("%02ds｜%s ≥ %d｜失败口碑 -%d" % [
			int(window.get("at_ms", 0) / 1000),
			_metric_name(String(window.get("metric", ""))),
			int(window.get("target", 0)),
			int(window.get("reputation_damage", 0))
		])
	timeline_lines.append("30s｜清空挑剔值，否则超时失败")
	preview.get_node("DemandTimeline").text = "\n".join(timeline_lines)
	preview.get_node("RelationRule").text = "联动规则：饮品与烘焙配方上下左右相邻，参与配方每次售卖获得一次 25% 加成。"


func _load_or_create_run() -> void:
	var loaded: Dictionary = ChallengeSaveService.load_from_path(save_path)
	if bool(loaded.get("ok", false)):
		_save_data = (loaded.get("data", {}) as Dictionary).duplicate(true)
	else:
		_save_data = ChallengeSaveService.empty_save()
		$Root/TopBar/SaveStatusLabel.text = "存档读取失败，已开启新的挑战局。"
	var saved_run = _save_data.get("active_run")
	if saved_run is Dictionary and String(saved_run.get("encounter_id", "")) == ENCOUNTER_ID:
		run_state = saved_run.duplicate(true)
	else:
		run_state = _run_service.create_single_encounter("vertical-slice-1", 42, ENCOUNTER_ID)


func _restore_active_battle() -> bool:
	var saved_battle = _save_data.get("active_battle")
	if saved_battle == null:
		return false
	if not saved_battle is Dictionary or not _battle_state_is_restorable(saved_battle):
		_save_data["active_battle"] = null
		run_state["phase"] = "preparation"
		$Root/TopBar/SaveStatusLabel.text = "战斗进度损坏，已回到本场战前准备。"
		return false
	battle_state = saved_battle.duplicate(true)
	$Root/Body/BattlePanel/ChallengeBattleView.restore_battle(battle_state, _encounter)
	$Root/Body/BattlePanel/ChallengeBattleView.set_confidence(int(run_state.get("confidence", 2)))
	$Root/Body/PreparationPanel.visible = false
	$Root/Body/BattlePanel.visible = true
	$Root/TopBar/SaveStatusLabel.text = "战斗已恢复并暂停，点击“继续挑战”后才会推进。"
	return true


func _battle_state_is_restorable(value: Dictionary) -> bool:
	return (
		String(value.get("phase", "")) == "running"
		and value.get("item_states") is Dictionary
		and value.get("events") is Array
		and value.get("_snapshot") is Dictionary
		and value.get("_encounter") is Dictionary
	)


func _on_draft_changed(draft: Dictionary) -> void:
	_save_data["active_draft"] = draft.duplicate(true)
	var counts := {}
	for placement in draft.get("placements", []):
		var recipe_id := String(placement.get("recipe_id", ""))
		counts[recipe_id] = int(counts.get(recipe_id, 0)) + 1
	for card in $Root/Body/PreparationPanel/SupplyStrip.get_children():
		var recipe_id := String(card.get_meta("recipe_id", ""))
		card.set_selected_count(int(counts.get(recipe_id, 0)))
	_refresh_start_readiness(draft)


func _on_board_mutated() -> void:
	if String(_tutorial_state.get("step_id", "")) != "rearrange":
		return
	var board = $Root/Body/PreparationPanel/MainColumns/ChallengeBoard
	_apply_tutorial_event("draft_changed", {
		"draft": board.get_draft(),
		"draft_valid": board.is_current_draft_valid()
	})


func _refresh_start_readiness(draft: Dictionary) -> void:
	var start_button: Button = $Root/Body/PreparationPanel/StartButton
	if not _config_valid:
		start_button.disabled = true
		return
	var placements: Array = draft.get("placements", [])
	if placements.is_empty():
		start_button.disabled = true
		start_button.text = "先把配方放进挑战展示柜"
		start_button.tooltip_text = "本模式使用独立挑战备货，不消耗经营库存。"
		$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.set_risk_summary("稳定覆盖：待放入配方")
		return
	var built: Dictionary = _loadout_service.build_snapshot(
		draft,
		_recipe_defs,
		_encounter,
		int(_recipe_config.get("grid_rows", 6)),
		int(_recipe_config.get("grid_columns", 8)),
		int(_recipe_config.get("supply_budget", 16))
	)
	if not bool(built.get("ok", false)):
		var errors: Array = built.get("errors", [])
		start_button.disabled = true
		start_button.text = "挑战备货需要调整"
		start_button.tooltip_text = String(errors[0]) if not errors.is_empty() else "挑战备货无效。"
		return
	start_button.disabled = false
	start_button.text = "锁定展示柜，开始 30 秒全自动挑战"
	start_button.tooltip_text = "开战后不能移动配方；本场不消耗经营库存。"
	var preview_state: Dictionary = _battle_service.simulate(
		built.get("snapshot", {}),
		_encounter,
		int(run_state.get("encounter_seed", 42))
	)
	var failed_windows := 0
	for resolved in (preview_state.get("resolved_windows", {}) as Dictionary).values():
		if resolved is Dictionary and not bool(resolved.get("passed", false)):
			failed_windows += 1
	var risk_text := ""
	if failed_windows > 0:
		risk_text = "缺口：预计 %d 个需求窗失败" % failed_windows
	elif String(preview_state.get("outcome", "")) == "victory":
		risk_text = "稳定覆盖：预计可击败 Boss"
	else:
		risk_text = "边缘：需求窗可过，但总满足力不足"
	$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.set_risk_summary(risk_text)


func _on_placement_rejected(reasons: Array[String]) -> void:
	if not reasons.is_empty():
		$Root/Body/PreparationPanel/StartButton.tooltip_text = reasons[0]


func _on_battle_finished(final_state: Dictionary) -> void:
	battle_state = final_state.duplicate(true)
	var settlement_id := "%s:settlement:%d" % [
		String(run_state.get("run_id", "run")),
		(run_state.get("settled_ids", []) as Array).size() + 1
	]
	var registered: Dictionary = _run_service.register_result(run_state, {
		"settlement_id": settlement_id,
		"outcome": String(battle_state.get("outcome", "")),
		"encounter_id": String(run_state.get("encounter_id", ""))
	})
	run_state = (registered.get("run", run_state) as Dictionary).duplicate(true)
	_apply_tutorial_event("battle_finished")
	var report: Dictionary = _report_service.build(battle_state, _encounter)
	$SettlementDialog.bind_report(report)
	$SettlementDialog.set_retry_enabled(
		String(run_state.get("phase", "")) == "preparation"
		and int(run_state.get("confidence", 0)) > 0
	)
	$SettlementDialog.popup_centered(Vector2i(1080, 820))
	$TutorialCanvasLayer/TutorialOverlay.hide_step()
	if String(_tutorial_state.get("step_id", "")) == "read_report":
		$SettlementDialog.show_tutorial_report(String(battle_state.get("outcome", "")))
	_save_now(false)
	_refresh_top_bar()


func _on_report_action_requested(_action: String) -> void:
	_apply_tutorial_event("report_exited", {
		"outcome": String(battle_state.get("outcome", "")),
		"confidence": int(run_state.get("confidence", 0))
	})
	$SettlementDialog.hide_tutorial_report()


func _on_settlement_tutorial_help_requested() -> void:
	$SettlementDialog.show_tutorial_report(String(battle_state.get("outcome", "")), true)


func _return_to_preparation() -> void:
	$SettlementDialog.hide_tutorial_report()
	$SettlementDialog.hide()
	if String(run_state.get("phase", "")) == "preparation":
		retry_same_encounter()


func _show_preparation() -> void:
	$Root/Body/PreparationPanel.visible = true
	$Root/Body/BattlePanel.visible = false
	$Root/Body/PreparationPanel/MainColumns/ChallengeBoard.set_locked(false)


func _refresh_top_bar() -> void:
	$Root/TopBar/StageLabel.text = "垂直切片｜第 1 场：挑剔评论家"
	$Root/TopBar/ConfidenceLabel.text = "信心 %d / 2" % int(run_state.get("confidence", 2))


func _save_now(include_battle: bool) -> void:
	if _save_data.is_empty():
		_save_data = ChallengeSaveService.empty_save()
	_save_data["active_run"] = run_state.duplicate(true)
	_save_data["active_draft"] = $Root/Body/PreparationPanel/MainColumns/ChallengeBoard.get_draft()
	_save_data["active_battle"] = battle_state.duplicate(true) if include_battle else null
	var saved: Dictionary = ChallengeSaveService.save_to_path(save_path, _save_data)
	if bool(saved.get("ok", false)):
		$Root/TopBar/SaveStatusLabel.text = "挑战进度已保存"
	else:
		$Root/TopBar/SaveStatusLabel.text = "保存失败：%s" % String(saved.get("error", ""))


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _metric_name(metric: String) -> String:
	match metric:
		"sales_count":
			return "累计出餐"
		"active_relation_count":
			return "有效联动"
		"window_satisfaction":
			return "区间满足力"
	return metric
