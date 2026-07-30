class_name ChallengeMainView
extends Control

const Catalog = preload("res://scripts/catalog.gd")
const ChallengeSessionService = preload("res://scripts/challenge/challenge_session_service.gd")
const ChallengeLoadoutService = preload("res://scripts/challenge/challenge_loadout_service.gd")
const BossBattleReportService = preload("res://scripts/challenge/boss_battle_report_service.gd")
const ChallengeTutorialProgress = preload("res://scripts/challenge/challenge_tutorial_progress.gd")
const ChallengeTutorialOverlay = preload("res://scripts/challenge/ui/challenge_tutorial_overlay.gd")

const ROUTE_ID := "standard_short_chain"

@export var save_path := "user://project_rest_two_save_v1.json"

var run_state: Dictionary = {}
var battle_state: Dictionary = {}

var _save_data: Dictionary = {}
var _session = ChallengeSessionService.new()
var _loadout_service = ChallengeLoadoutService.new()
var _report_service = BossBattleReportService.new()
var _tutorial_progress = ChallengeTutorialProgress.new()
var _tutorial_state: Dictionary = {}
var _tutorial_replay_mode := false
var _tutorial_replay_step_index := 0
var _stage_two_hint_id := ""
var _binding_preparation := false
var _tutorial_refresh_queued := false
var _last_saved_second := -1
var _page := "hub"
var _selected_route_id := ROUTE_ID


func _ready() -> void:
	_connect_signals()
	_session.save_path = save_path
	var loaded := _session.load_or_create()
	_adopt(loaded)
	var recovered := _session.recover(_save_data)
	if bool(recovered.get("applied", false)):
		_adopt(recovered)
		_set_status("已恢复挑战进度")
	else:
		_set_status("挑战进度已保存")
	_initialize_tutorial()
	_route_from_state()
	call_deferred("_refresh_tutorial_after_layout")


func _process(_delta: float) -> void:
	if _page != "battle":
		return
	var battle_view = $Root/PageHost/BattleView
	if String(battle_view.battle_state.get("phase", "")) != "running":
		return
	var elapsed_ms := int(battle_view.battle_state.get("elapsed_ms", 0))
	if elapsed_ms / 1000 == _last_saved_second:
		return
	_last_saved_second = elapsed_ms / 1000
	battle_state = battle_view.battle_state.duplicate(true)
	var saved := _session.save_battle_progress(_save_data, battle_state)
	if bool(saved.get("applied", false)):
		_adopt(saved)


func start_new_run(seed: int = 0) -> void:
	var resolved_seed := seed if seed != 0 else int(Time.get_unix_time_from_system())
	var result := _session.create_standard_run(_save_data, _selected_route_id, resolved_seed)
	if not bool(result.get("applied", false)):
		_set_status(_error_text(result))
		return
	_adopt(result)
	_show_preparation()
	_offer_stage_two_hint(
		"next_run_recipe"
		if _has_researched_recipe()
		else "five_stage_route"
	)
	_refresh_tutorial()


func start_endless_run(seed: int = 0) -> void:
	var resolved_seed := seed if seed != 0 else int(Time.get_unix_time_from_system())
	var result := _session.create_endless_run(_save_data, resolved_seed)
	if not bool(result.get("applied", false)):
		_set_status(_error_text(result))
		return
	_adopt(result)
	_set_status("无尽爬升已开始：每 5 层恢复节点，每 10 层最终 Boss")
	_show_preparation()
	_refresh_tutorial()


func continue_run() -> void:
	_route_from_state()


func start_battle() -> void:
	_start_battle_with_draft($Root/PageHost/PreparationHost/PreparationView.get_draft())


func retry_same_encounter() -> void:
	$SettlementDialog.hide_tutorial_report()
	$SettlementDialog.close_after_report_action()
	var acknowledged := _session.acknowledge_battle_result(_save_data)
	if not bool(acknowledged.get("applied", false)):
		_set_status(_error_text(acknowledged))
		return
	_adopt(acknowledged)
	_show_preparation()
	_apply_tutorial_event("report_exited", {
		"outcome": String(battle_state.get("outcome", "")),
		"confidence": int(run_state.get("confidence", 0))
	})


func set_draft_for_test(draft: Dictionary) -> void:
	if _page == "hub" and not _save_data.get("active_run") is Dictionary:
		start_new_run(42)
	$Root/PageHost/PreparationHost/PreparationView.set_draft(draft)


func advance_battle_for_test(target_elapsed_ms: int) -> void:
	var battle_view = $Root/PageHost/BattleView
	battle_view.set_paused(false)
	battle_view.advance_for_test(target_elapsed_ms)
	battle_state = battle_view.battle_state.duplicate(true)


func start_new_run_for_test(seed: int = 42) -> void:
	start_new_run(seed)


func _connect_signals() -> void:
	get_viewport().size_changed.connect(
		func() -> void: call_deferred("_refresh_tutorial_after_layout")
	)
	var hub = $Root/PageHost/HubHost/HubView
	hub.start_requested.connect(func() -> void: start_new_run())
	hub.endless_requested.connect(func() -> void: start_endless_run())
	hub.continue_requested.connect(continue_run)
	hub.menu_requested.connect(_show_menu)
	hub.research_requested.connect(_show_research)
	hub.route_selected.connect(func(route_id: String) -> void: _selected_route_id = route_id)
	var preparation = $Root/PageHost/PreparationHost/PreparationView
	preparation.battle_requested.connect(_start_battle_with_draft)
	preparation.draft_changed.connect(_on_draft_changed)
	preparation.placement_rejected.connect(
		func(reasons: Array[String]) -> void:
			if not reasons.is_empty():
				_set_status(reasons[0])
	)
	var board = preparation.board()
	board.recipe_placed.connect(
		func(_instance_id: String, recipe_id: String) -> void:
			_apply_tutorial_event("recipe_placed", {"recipe_id": recipe_id})
	)
	board.instance_rotated.connect(
		func(_instance_id: String, recipe_id: String, _rotation: int, shape_changed: bool) -> void:
			_apply_tutorial_event("instance_rotated", {
				"recipe_id": recipe_id,
				"shape_changed": shape_changed
			})
	)
	$Root/PageHost/BattleView.battle_finished.connect(_on_battle_finished)
	$Root/PageHost/UpgradeHost/UpgradeSelectView.upgrade_requested.connect(_on_upgrade_requested)
	$Root/PageHost/ResearchHost/ResearchView.unlock_requested.connect(_on_research_unlock_requested)
	$Root/PageHost/ResearchHost/ResearchView.back_requested.connect(_show_hub)
	$Root/PageHost/MenuHost/MenuView.back_requested.connect(_show_hub)
	$Root/PageHost/MenuHost/MenuView.save_requested.connect(_on_menu_save_requested)
	$Root/PageHost/MenuHost/MenuView.preset_save_requested.connect(_on_menu_preset_save_requested)
	$Root/PageHost/MenuHost/MenuView.preset_load_requested.connect(_on_menu_preset_load_requested)
	$Root/PageHost/SummaryHost/RunSummaryView.reward_requested.connect(_on_reward_requested)
	$Root/PageHost/SummaryHost/RunSummaryView.return_requested.connect(_on_return_requested)
	$SettlementDialog.report_action_requested.connect(_on_report_action_requested)
	$SettlementDialog.retry_requested.connect(retry_same_encounter)
	$SettlementDialog.back_requested.connect(_on_report_back)
	$SettlementDialog.tutorial_help_requested.connect(open_tutorial_help)
	$SettlementDialog.tutorial_dismiss_requested.connect(dismiss_tutorial)
	$SettlementDialog.tutorial_next_requested.connect(advance_tutorial_replay)
	$TutorialLayer/TutorialOverlay.confirm_requested.connect(_on_tutorial_confirm_requested)
	$TutorialLayer/TutorialOverlay.dismiss_requested.connect(dismiss_tutorial)
	$TutorialLayer/TutorialOverlay.next_requested.connect(advance_tutorial_replay)
	$Root/GlobalTopBar/TutorialHelpButton.pressed.connect(open_tutorial_help)


func _route_from_state() -> void:
	var active_run: Variant = _save_data.get("active_run")
	if not active_run is Dictionary:
		_show_hub()
		return
	run_state = (active_run as Dictionary).duplicate(true)
	var phase := String(run_state.get("phase", ""))
	match phase:
		"preparation", "battle_result_loss":
			_show_preparation()
		"battle":
			_show_saved_battle()
		"battle_result_win":
			if _save_data.get("active_battle") is Dictionary:
				_show_saved_report()
			else:
				_prepare_upgrade_offer()
		"upgrade_select":
			_show_upgrade()
		"run_complete", "run_failed":
			if _save_data.get("active_battle") is Dictionary:
				_show_saved_report()
			else:
				_show_summary()
		_:
			_show_hub()


func _show_hub() -> void:
	_set_page("hub")
	$Root/PageHost/HubHost/HubView.bind(
		_save_data.get("meta", {}),
		_save_data.get("active_run"),
		_session.route_states(_save_data),
		_session.mastery_states(_save_data)
	)
	_refresh_top_bar()
	_refresh_tutorial()


func _show_preparation() -> void:
	run_state = (_save_data.get("active_run", {}) as Dictionary).duplicate(true)
	var encounter := _session.current_encounter(_save_data)
	var effective := _session.effective_context_for_run(run_state)
	_binding_preparation = true
	$Root/PageHost/PreparationHost/PreparationView.bind(
		run_state,
		encounter,
		effective,
		_loadout_service,
		Catalog.new().get_recipes()
	)
	_binding_preparation = false
	_set_page("preparation")
	_refresh_top_bar()
	_refresh_tutorial()


func _show_saved_battle() -> void:
	var value: Variant = _save_data.get("active_battle")
	if not value is Dictionary:
		_set_status("战斗记录缺失，已回到本场备战")
		_show_preparation()
		return
	battle_state = (value as Dictionary).duplicate(true)
	var encounter := _session.current_encounter(_save_data)
	$Root/PageHost/BattleView.restore_battle(battle_state, encounter)
	$Root/PageHost/BattleView.set_confidence(int(run_state.get("confidence", 0)))
	_set_page("battle")
	_refresh_top_bar()
	_refresh_tutorial()


func _show_saved_report() -> void:
	var value: Variant = _save_data.get("active_battle")
	if not value is Dictionary:
		_route_from_state()
		return
	battle_state = (value as Dictionary).duplicate(true)
	var encounter := _session.current_encounter(_save_data)
	var report := _report_service.build(battle_state, encounter)
	$SettlementDialog.bind_report(report)
	$SettlementDialog.set_retry_enabled(
		String(run_state.get("phase", "")) == "battle_result_loss"
		and int(run_state.get("confidence", 0)) > 0,
		String(run_state.get("phase", "")) in ["run_complete", "run_failed"]
	)
	$SettlementDialog.open_report()
	_apply_tutorial_event("battle_finished")
	_refresh_tutorial()


func _show_upgrade() -> void:
	run_state = (_save_data.get("active_run", {}) as Dictionary).duplicate(true)
	$Root/PageHost/UpgradeHost/UpgradeSelectView.bind(
		run_state.get("pending_upgrade_offer", {})
	)
	_set_page("upgrade")
	_refresh_top_bar()
	_offer_stage_two_hint("upgrade_choice")


func _show_research() -> void:
	var tree := _session.research_tree()
	var states := {}
	for node_id in (tree.get("nodes", {}) as Dictionary).keys():
		states[String(node_id)] = _session.research_node_state(_save_data, String(node_id))
	$Root/PageHost/ResearchHost/ResearchView.bind(
		tree,
		_save_data.get("meta", {}),
		states
	)
	_set_page("research")
	_refresh_top_bar()
	_offer_stage_two_hint("research_unlock")


func _show_menu() -> void:
	var default_ids: Array[String] = []
	for value in _session.research_tree().get("starter_recipe_ids", []):
		if value is String:
			default_ids.append(String(value))
	$Root/PageHost/MenuHost/MenuView.bind(
		_session.available_recipe_ids(_save_data),
		_session.active_menu(_save_data),
		_session.recipe_definitions(),
		Catalog.new().get_recipes(),
		default_ids,
		(_save_data.get("meta", {}) as Dictionary).get("saved_menus", [])
	)
	_set_page("menu")
	_refresh_top_bar()


func _on_menu_save_requested(recipe_ids: Array[String]) -> void:
	var saved := _session.set_active_menu(_save_data, recipe_ids)
	if not bool(saved.get("applied", false)):
		_set_status(_error_text(saved))
		return
	_adopt(saved)
	_set_status("本局菜单已保存；开局后将冻结这份清单")
	_show_hub()


func _on_menu_preset_save_requested(
	preset_id: String,
	display_name: String,
	recipe_ids: Array[String]
) -> void:
	var saved := _session.save_menu_preset(_save_data, preset_id, display_name, recipe_ids)
	if bool(saved.get("applied", false)):
		_adopt(saved)
		_set_status("菜单预设已保存（最多 3 套）")
	else:
		_set_status(_error_text(saved))
	_show_menu()


func _on_menu_preset_load_requested(preset_id: String) -> void:
	var loaded := _session.load_menu_preset(_save_data, preset_id)
	if bool(loaded.get("applied", false)):
		_adopt(loaded)
		_set_status("菜单预设已载入")
	else:
		_set_status(_error_text(loaded))
	_show_menu()


func _show_summary() -> void:
	run_state = (_save_data.get("active_run", {}) as Dictionary).duplicate(true)
	$Root/PageHost/SummaryHost/RunSummaryView.bind(run_state, _save_data.get("meta", {}))
	_set_page("summary")
	_refresh_top_bar()
	if String(run_state.get("phase", "")) == "run_complete":
		_offer_stage_two_hint("completion_reward")


func _start_battle_with_draft(draft: Dictionary) -> void:
	var result := _session.start_battle(_save_data, draft)
	if not bool(result.get("applied", false)):
		_set_status(_error_text(result))
		return
	_adopt(result)
	battle_state = (_save_data.get("active_battle", {}) as Dictionary).duplicate(true)
	var encounter := _session.current_encounter(_save_data)
	$Root/PageHost/BattleView.restore_battle(battle_state, encounter)
	$Root/PageHost/BattleView.set_confidence(int(run_state.get("confidence", 0)))
	$Root/PageHost/BattleView.set_paused(false)
	_last_saved_second = 0
	_set_page("battle")
	_apply_tutorial_event("battle_started", {"draft": draft})
	_refresh_top_bar()


func _on_battle_finished(final_state: Dictionary) -> void:
	battle_state = final_state.duplicate(true)
	var settled := _session.settle_battle(_save_data, battle_state)
	if not bool(settled.get("applied", false)):
		_set_status(_error_text(settled))
		return
	_adopt(settled)
	_show_saved_report()


func _on_report_action_requested(_action: String) -> void:
	$SettlementDialog.hide_tutorial_report()


func _on_report_back() -> void:
	$SettlementDialog.hide_tutorial_report()
	$SettlementDialog.close_after_report_action()
	var outcome := String(battle_state.get("outcome", ""))
	var acknowledged := _session.acknowledge_battle_result(_save_data)
	if bool(acknowledged.get("applied", false)):
		_adopt(acknowledged)
	_apply_tutorial_event("report_exited", {
		"outcome": outcome,
		"confidence": int(run_state.get("confidence", 0))
	})
	run_state = (_save_data.get("active_run", {}) as Dictionary).duplicate(true)
	match String(run_state.get("phase", "")):
		"battle_result_win":
			_prepare_upgrade_offer()
		"run_complete", "run_failed":
			_show_summary()
		_:
			_show_preparation()


func _prepare_upgrade_offer() -> void:
	run_state = (_save_data.get("active_run", {}) as Dictionary).duplicate(true)
	var snapshot: Dictionary = run_state.get("last_battle_snapshot", {})
	var offered := _session.prepare_upgrade_offer(_save_data, snapshot)
	if not bool(offered.get("applied", false)):
		if offered.has("offer"):
			_show_upgrade()
			return
		_set_status(_error_text(offered))
		return
	_adopt(offered)
	_show_upgrade()


func _on_upgrade_requested(offer_id: String, upgrade_id: String) -> void:
	var chosen := _session.choose_upgrade(_save_data, offer_id, upgrade_id)
	if not bool(chosen.get("applied", false)):
		_set_status(_error_text(chosen))
		_show_upgrade()
		return
	_adopt(chosen)
	var summary: Dictionary = chosen.get("effect_summary", {})
	_set_status(
		"强化已应用，需要重排"
		if bool(summary.get("recommends_rearrange", false))
		else "强化已应用"
	)
	_show_preparation()
	_offer_stage_two_hint("upgrade_prediction")


func _on_reward_requested() -> void:
	var rewarded := _session.grant_completion_reward(_save_data)
	if bool(rewarded.get("applied", false)):
		_adopt(rewarded)
		_set_status("获得 %d 点研究点" % int(rewarded.get("points_granted", 0)))
	_show_summary()


func _on_research_unlock_requested(node_id: String) -> void:
	var unlocked := _session.unlock_research(_save_data, node_id)
	if bool(unlocked.get("applied", false)):
		_adopt(unlocked)
		_set_status("研究成果已进入永久收藏；加入本局菜单后，下局生效")
	else:
		_set_status(_error_text(unlocked))
	_show_research()


func _on_return_requested() -> void:
	var returned := _session.return_to_hub(_save_data)
	if not bool(returned.get("applied", false)):
		_set_status(_error_text(returned))
		return
	_adopt(returned)
	_show_hub()


func _on_draft_changed(draft: Dictionary) -> void:
	if _binding_preparation:
		return
	var saved := _session.update_draft(_save_data, draft)
	if bool(saved.get("applied", false)):
		_adopt(saved)
	if String(_tutorial_state.get("step_id", "")) == "rearrange":
		var board = $Root/PageHost/PreparationHost/PreparationView.board()
		_apply_tutorial_event("draft_changed", {
			"draft": draft,
			"draft_valid": board.is_current_draft_valid()
		})
	call_deferred("_refresh_tutorial_after_layout")


func _set_page(page: String) -> void:
	_page = page
	$Root/PageHost/HubHost.visible = page == "hub"
	$Root/PageHost/PreparationHost.visible = page == "preparation"
	$Root/PageHost/BattleView.visible = page == "battle"
	$Root/PageHost/UpgradeHost.visible = page == "upgrade"
	$Root/PageHost/ResearchHost.visible = page == "research"
	$Root/PageHost/MenuHost.visible = page == "menu"
	$Root/PageHost/SummaryHost.visible = page == "summary"


func _adopt(result: Dictionary) -> void:
	if result.get("save_data") is Dictionary:
		_save_data = (result.get("save_data", {}) as Dictionary).duplicate(true)
	var active_run: Variant = _save_data.get("active_run")
	run_state = (active_run as Dictionary).duplicate(true) if active_run is Dictionary else {}
	var active_battle: Variant = _save_data.get("active_battle")
	battle_state = (active_battle as Dictionary).duplicate(true) if active_battle is Dictionary else {}
	_refresh_top_bar()


func _refresh_top_bar() -> void:
	var meta: Dictionary = _save_data.get("meta", {})
	$Root/GlobalTopBar/ResearchLabel.text = "研究点 %d" % int(meta.get("research_points", 0))
	if run_state.is_empty():
		$Root/GlobalTopBar/StageLabel.text = "五场客潮挑战"
		$Root/GlobalTopBar/ConfidenceLabel.text = "信心待开局"
	else:
		var encounter := _session.current_encounter(_save_data)
		if String(run_state.get("mode", "")) == "endless":
			$Root/GlobalTopBar/StageLabel.text = "无尽第 %d 层 · %s" % [
				int(run_state.get("stage_index", 0)) + 1,
				String(encounter.get("base_display_name", encounter.get("display_name", "客潮")))
			]
		else:
			$Root/GlobalTopBar/StageLabel.text = "第 %d / 5 场 · %s" % [
				int(run_state.get("stage_index", 0)) + 1,
				String(encounter.get("display_name", "客潮"))
			]
		$Root/GlobalTopBar/ConfidenceLabel.text = "信心 %d / 2" % int(
			run_state.get("confidence", 0)
		)


func _set_status(text: String) -> void:
	$Root/GlobalTopBar/SaveStatusLabel.text = text


func _error_text(result: Dictionary) -> String:
	var error := String(result.get("error", "操作未完成"))
	var errors: Array = result.get("errors", [])
	return String(errors[0]) if not errors.is_empty() else error


func _initialize_tutorial() -> void:
	var meta: Dictionary = _save_data.get("meta", {})
	_tutorial_state = _tutorial_progress.normalize(
		meta.get("onboarding"),
		_current_tutorial_surface()
	)
	if bool(_tutorial_state.get("unsupported_newer_version", false)):
		$TutorialLayer/TutorialOverlay.hide_step()


func _apply_tutorial_event(event_id: String, context: Dictionary = {}) -> void:
	if _tutorial_replay_mode or bool(_tutorial_state.get("unsupported_newer_version", false)):
		return
	var next := _tutorial_progress.apply_event(_tutorial_state, event_id, context)
	if next == _tutorial_state:
		return
	_tutorial_state = next
	var saved := _session.update_onboarding(_save_data, _tutorial_state)
	if bool(saved.get("applied", false)):
		_adopt(saved)
	_refresh_tutorial()
	if event_id == "tutorial_completed":
		_offer_stage_two_hint("five_stage_route")


func _refresh_tutorial_after_layout() -> void:
	if _tutorial_refresh_queued:
		return
	_tutorial_refresh_queued = true
	await get_tree().process_frame
	await get_tree().process_frame
	_tutorial_refresh_queued = false
	if is_inside_tree():
		_refresh_tutorial()


func _refresh_tutorial() -> void:
	var overlay = $TutorialLayer/TutorialOverlay
	if not _stage_two_hint_id.is_empty():
		var context_copy := _stage_two_tutorial_copy(_stage_two_hint_id)
		var hint_index := ChallengeTutorialProgress.STAGE_TWO_HINTS.find(_stage_two_hint_id)
		overlay.show_step(
			hint_index + 1,
			ChallengeTutorialProgress.STAGE_TWO_HINTS.size(),
			String(context_copy.get("title", "")),
			String(context_copy.get("body", "")),
			resolve_stage_two_tutorial_targets(_stage_two_hint_id),
			String(context_copy.get("confirm", "知道了")),
			false
		)
		return
	if (
		bool(_tutorial_state.get("unsupported_newer_version", false))
		or (not _tutorial_replay_mode and String(_tutorial_state.get("status", "")) != "active")
		or (
			not _tutorial_replay_mode
			and
			_page in ["hub", "menu", "upgrade", "research", "summary"]
			and _active_tutorial_step_id() != "complete"
		)
	):
		overlay.hide_step()
		return
	var step_id := _active_tutorial_step_id()
	var copy := _tutorial_copy(step_id)
	var step_index := ChallengeTutorialProgress.STEPS.find(step_id)
	overlay.show_step(
		maxi(1, step_index + 1),
		ChallengeTutorialProgress.STEPS.size(),
		String(copy.get("title", "")),
		String(copy.get("body", "")),
		resolve_tutorial_targets(step_id),
		String(copy.get("confirm", "")),
		_tutorial_replay_mode
	)


func _on_tutorial_confirm_requested() -> void:
	if _tutorial_replay_mode:
		return
	if not _stage_two_hint_id.is_empty():
		_complete_stage_two_hint()
		return
	match _active_tutorial_step_id():
		"boss_brief":
			_apply_tutorial_event("boss_acknowledged")
		"read_risk":
			var board = $Root/PageHost/PreparationHost/PreparationView.board()
			_apply_tutorial_event("risk_acknowledged", {
				"draft_valid": board.is_current_draft_valid()
			})
		"complete":
			_apply_tutorial_event("tutorial_completed")


func dismiss_tutorial() -> void:
	if not _stage_two_hint_id.is_empty():
		_complete_stage_two_hint()
		return
	if _tutorial_replay_mode:
		_tutorial_replay_mode = false
		$TutorialLayer/TutorialOverlay.hide_step()
		return
	_tutorial_state = _tutorial_progress.dismiss(_tutorial_state)
	var saved := _session.update_onboarding(_save_data, _tutorial_state)
	if bool(saved.get("applied", false)):
		_adopt(saved)
	_refresh_tutorial()


func open_tutorial_help() -> void:
	if bool(_tutorial_state.get("unsupported_newer_version", false)):
		return
	if String(_tutorial_state.get("status", "")) == "completed":
		_tutorial_replay_mode = true
		_tutorial_replay_step_index = 0
	else:
		_tutorial_state = _tutorial_progress.resume(_tutorial_state, _current_tutorial_surface())
		var saved := _session.update_onboarding(_save_data, _tutorial_state)
		if bool(saved.get("applied", false)):
			_adopt(saved)
	_refresh_tutorial()


func advance_tutorial_replay() -> void:
	if not _tutorial_replay_mode:
		return
	_tutorial_replay_step_index += 1
	if _tutorial_replay_step_index >= ChallengeTutorialProgress.STEPS.size():
		_tutorial_replay_mode = false
		$TutorialLayer/TutorialOverlay.hide_step()
		return
	_refresh_tutorial()


func get_tutorial_state_for_test() -> Dictionary:
	return _tutorial_state.duplicate(true)


func is_tutorial_replay_for_test() -> bool:
	return _tutorial_replay_mode


func acknowledge_tutorial_for_test() -> void:
	_on_tutorial_confirm_requested()


func _active_tutorial_step_id() -> String:
	if _tutorial_replay_mode:
		return ChallengeTutorialProgress.STEPS[_tutorial_replay_step_index]
	return String(_tutorial_state.get("step_id", "boss_brief"))


func _current_tutorial_surface() -> String:
	if $SettlementDialog.visible:
		return "settlement"
	if _page == "battle":
		return "battle"
	if _page == "summary":
		return "finished"
	return "preparation"


func resolve_tutorial_targets(step_id: String) -> Array[Rect2]:
	var preparation = $Root/PageHost/PreparationHost/PreparationView
	var board = preparation.board()
	match step_id:
		"boss_brief":
			return _visible_target_rects([preparation.get_node("MainColumns/BossBrief")])
		"place_recipe":
			var result: Array[Rect2] = [
				ChallengeTutorialOverlay.control_screen_rect(preparation.get_node("SupplyScroll"))
			]
			result.append_array(board.get_tutorial_target_rects("board"))
			return result
		"rotate_recipe", "rearrange":
			return board.get_tutorial_target_rects("board")
		"read_risk":
			var result: Array[Rect2] = board.get_tutorial_target_rects("relation")
			result.append_array(_visible_target_rects([
				preparation.get_node("MainColumns/BossBrief/Content/BuildGuide")
			]))
			return result
		"start_battle":
			return _visible_target_rects([preparation.get_node("BattleButton")])
		"observe_battle":
			return _visible_target_rects([
				$Root/PageHost/BattleView/TopStatus,
				$Root/PageHost/BattleView/BossPanel/DemandTimeline
			])
		"complete":
			return _visible_target_rects([$Root/GlobalTopBar/TutorialHelpButton])
	return []


func _visible_target_rects(controls: Array) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for control in controls:
		if control is Control and control.is_visible_in_tree():
			result.append(ChallengeTutorialOverlay.control_screen_rect(control))
	return result


func _offer_stage_two_hint(hint_id: String) -> void:
	if _tutorial_replay_mode or not _stage_two_hint_id.is_empty():
		return
	if not _tutorial_progress.can_offer_stage_two_hint(_tutorial_state, hint_id):
		return
	_stage_two_hint_id = hint_id
	call_deferred("_refresh_tutorial_after_layout")


func _complete_stage_two_hint() -> void:
	var hint_id := _stage_two_hint_id
	_stage_two_hint_id = ""
	_tutorial_state = _tutorial_progress.mark_stage_two_hint_seen(_tutorial_state, hint_id)
	var saved := _session.update_onboarding(_save_data, _tutorial_state)
	if bool(saved.get("applied", false)):
		_adopt(saved)
	_refresh_tutorial()
	_offer_stage_two_hint(_stage_two_hint_for_page())


func _stage_two_hint_for_page() -> String:
	match _page:
		"upgrade":
			return "upgrade_choice"
		"research":
			return "research_unlock"
		"summary":
			return "completion_reward"
		"preparation":
			if not (run_state.get("run_upgrades", []) as Array).is_empty():
				return "upgrade_prediction"
	return ""


func _has_researched_recipe() -> bool:
	var tree := _session.research_tree()
	var starter_ids: Array = tree.get("starter_recipe_ids", [])
	var meta: Dictionary = _save_data.get("meta", {})
	return (meta.get("unlocked_recipe_ids", []) as Array).size() > starter_ids.size()


func resolve_stage_two_tutorial_targets(hint_id: String) -> Array[Rect2]:
	match hint_id:
		"five_stage_route":
			return _visible_target_rects([$Root/GlobalTopBar/StageLabel])
		"upgrade_choice":
			return _visible_target_rects([
				$Root/PageHost/UpgradeHost/UpgradeSelectView/Content/Candidates
			])
		"upgrade_prediction":
			return _visible_target_rects([
				$Root/PageHost/PreparationHost/PreparationView/MainColumns/ChallengeBoard
			])
		"completion_reward":
			return _visible_target_rects([
				$Root/PageHost/SummaryHost/RunSummaryView/Content/Actions/RewardButton
			])
		"research_unlock":
			return _visible_target_rects([
				$Root/PageHost/ResearchHost/ResearchView/Content/Branches
			])
		"next_run_recipe":
			return _visible_target_rects([
				$Root/PageHost/PreparationHost/PreparationView/SupplyScroll
			])
	return []


func _stage_two_tutorial_copy(hint_id: String) -> Dictionary:
	match hint_id:
		"five_stage_route":
			return {
				"title": "这是一条 5 场短链",
				"body": "顶部票据会标记当前客潮。连胜推进到第 5 场；失败消耗 1 点信心，同场可重排后再战。"
			}
		"upgrade_choice":
			return {
				"title": "场间三选一强化",
				"body": "强化只在本局生效。它会改变备货、窗口或结算规则，选择后进入下一场。"
			}
		"upgrade_prediction":
			return {
				"title": "强化已经进入预测",
				"body": "供应卡和覆盖预测会显示强化来源。若收益依赖位置或标签，请先重排再开战。"
			}
		"completion_reward":
			return {
				"title": "通关奖励是研究点",
				"body": "奖励只结算一次。研究点用于局外研发，不会直接把 166 个配方快速送完。"
			}
		"research_unlock":
			return {
				"title": "永久解锁走研发树",
				"body": "节点有前置与研究点成本。新配方进入永久收藏；回大厅加入本局菜单后，才会在下一局使用。"
			}
		"next_run_recipe":
			return {
				"title": "菜单已冻结为本局配方池",
				"body": "永久收藏不会改写活动局；只有开局前加入菜单的 4～8 个配方会进入这局快照。"
			}
	return {"title": "", "body": ""}


func _tutorial_copy(step_id: String) -> Dictionary:
	match step_id:
		"boss_brief":
			return {"title": "先读懂本场客潮", "body": "每场都有完整时间轴；开战后橱窗会全自动售卖。", "confirm": "看懂了"}
		"place_recipe":
			return {
				"title": "先读卡面，再拖进橱窗",
				"body": "卡面直接显示售卖周期、每次满足力、库存和标签。先挑一对符合本场联动标签的配方。"
			}
		"rotate_recipe":
			return {
				"title": "让联动标签上下左右贴边",
				"body": "右键旋转、拖动重排；斜角不算相邻。贴边成功后，棋盘下方会立即显示加成组数。"
			}
		"read_risk":
			return {
				"title": "确认当前构筑真的获得加成",
				"body": "右侧“当前构筑”会汇总周期和生效配方；棋盘下方会写明本场标签配对、组数与加成百分比。",
				"confirm": "继续"
			}
		"start_battle":
			return {"title": "锁定后自动战斗", "body": "开战后不能移动配方，直到本场战报确认。"}
		"observe_battle":
			return {"title": "双向压力条", "body": "满足力压低 Boss 挑剔值；需求失败会损伤口碑防线。"}
		"read_report":
			return {"title": "从战报找到缺口", "body": "确认失败窗口、配方贡献和强化来源。"}
		"rearrange":
			return {"title": "根据战报重排", "body": "改变布局后再重试同一客潮。"}
		"complete":
			return {"title": "核心循环已掌握", "body": "后续会在场间选择强化，并用研究点规划永久配方。", "confirm": "完成"}
	return {"title": "", "body": ""}
