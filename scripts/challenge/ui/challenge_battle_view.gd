class_name ChallengeBattleView
extends Control

signal battle_finished(final_state: Dictionary)

const BossBattleService = preload("res://scripts/challenge/boss_battle_service.gd")
const RecipeIconService = preload("res://scripts/recipe_icon_service.gd")
const ROWS := 6
const COLUMNS := 8

var battle_locked := false
var battle_paused := false
var battle_state: Dictionary = {}
var _encounter: Dictionary = {}
var _snapshot: Dictionary = {}
var _service = BossBattleService.new()
var _event_cursor := 0
var _finished_emitted := false


func _ready() -> void:
	$BattleFooter/PauseButton.pressed.connect(_toggle_pause)
	_build_snapshot_grid()
	set_process(false)


func bind_encounter(encounter: Dictionary) -> void:
	_encounter = encounter.duplicate(true)
	$BossPanel/BossName.text = "挑剔的美食评论家"
	$BossPanel/BossRule.text = "30 秒内清空挑剔值。售卖全自动；需求窗口失败会削减口碑防线。"
	var windows: Array = _encounter.get("windows", [])
	for index in 3:
		var label: Label = $BossPanel/DemandTimeline.get_child(index)
		label.add_theme_color_override("font_color", Color("#655a82"))
		label.text = _window_text(windows[index]) if index < windows.size() else "%02ds｜等待需求" % ((index + 1) * 8)
	var deadline: Label = $BossPanel/DemandTimeline/Window30
	deadline.add_theme_color_override("font_color", Color("#655a82"))
	deadline.text = "%02ds｜清空挑剔值，否则挑战超时" % int(_encounter.get("duration_ms", 30000) / 1000)
	_refresh_status()


func start_battle(snapshot: Dictionary, seed: int) -> void:
	_snapshot = snapshot.duplicate(true)
	battle_state = _service.create_state(_snapshot, _encounter, seed)
	battle_locked = true
	battle_paused = false
	_event_cursor = 0
	_finished_emitted = false
	_render_snapshot()
	_refresh_status()
	$BattleFooter/PauseButton.disabled = false
	$BattleFooter/PauseButton.text = "暂停"
	set_process(true)


func restore_battle(saved_state: Dictionary, encounter: Dictionary) -> void:
	bind_encounter(encounter)
	battle_state = saved_state.duplicate(true)
	_snapshot = (battle_state.get("_snapshot", {}) as Dictionary).duplicate(true)
	battle_locked = true
	battle_paused = true
	_finished_emitted = String(battle_state.get("phase", "")) == "finished"
	_event_cursor = 0
	_render_snapshot()
	_consume_new_events(false)
	_refresh_status()
	$BattleFooter/PauseButton.text = "继续挑战"
	set_process(false)


func advance_for_test(target_elapsed_ms: int) -> void:
	if battle_paused or String(battle_state.get("phase", "")) != "running":
		return
	_advance_to(target_elapsed_ms)


func set_paused(paused: bool) -> void:
	if String(battle_state.get("phase", "")) != "running":
		battle_paused = false
		set_process(false)
		return
	battle_paused = paused
	$BattleFooter/PauseButton.text = "继续挑战" if battle_paused else "暂停"
	set_process(not battle_paused)


func set_confidence(confidence: int) -> void:
	$TopStatus/ConfidenceLabel.text = "信心 %d / 2" % confidence


func _process(delta: float) -> void:
	if not battle_locked or battle_paused or String(battle_state.get("phase", "")) != "running":
		return
	var elapsed_ms := int(battle_state.get("elapsed_ms", 0))
	var duration_ms := int(_encounter.get("duration_ms", 0))
	_advance_to(mini(duration_ms, elapsed_ms + maxi(1, int(round(delta * 1000.0)))))


func _advance_to(target_elapsed_ms: int) -> void:
	battle_state = _service.advance(battle_state, target_elapsed_ms)
	_consume_new_events(true)
	_refresh_status()


func _consume_new_events(animate: bool) -> void:
	var events: Array = battle_state.get("events", [])
	while _event_cursor < events.size():
		var event: Dictionary = events[_event_cursor]
		_apply_event(event, animate)
		_event_cursor += 1


func _apply_event(event: Dictionary, animate: bool) -> void:
	match String(event.get("type", "")):
		"sale":
			$BattleFooter/CurrentDemandLabel.text = "%s 售出｜满足力 +%d" % [
				String(event.get("recipe_id", "")),
				int(event.get("final_satisfaction", 0))
			]
			_pulse_instance(String(event.get("source_id", "")), Color("#ffc857"), animate)
		"relation_trigger":
			_highlight_relation(String(event.get("source_id", "")), animate)
		"demand_window":
			_resolve_window_visual(event)
		"battle_end":
			battle_paused = false
			set_process(false)
			$BattleFooter/PauseButton.disabled = true
			if not _finished_emitted:
				_finished_emitted = true
				battle_finished.emit(battle_state.duplicate(true))


func _resolve_window_visual(event: Dictionary) -> void:
	var at_ms := int(event.get("at_ms", 0))
	var label_name := "Window%02d" % int(at_ms / 1000)
	var label := $BossPanel/DemandTimeline.get_node_or_null(label_name) as Label
	if label == null:
		return
	var passed := bool(event.get("passed", false))
	label.add_theme_color_override("font_color", Color("#72d6a0") if passed else Color("#ef476f"))
	label.text = "%s %s｜%d / %d" % [
		"✓" if passed else "✕",
		String(event.get("window_id", "")),
		int(event.get("actual", 0)),
		int(event.get("target", 0))
	]


func _refresh_status() -> void:
	var initial_reputation := int(_encounter.get("initial_reputation", 100))
	var reputation := int(battle_state.get("reputation", initial_reputation))
	$TopStatus/ReputationBar.max_value = initial_reputation
	$TopStatus/ReputationBar.value = reputation
	$TopStatus/ReputationLabel.text = "口碑防线 %d" % reputation

	var initial_pickiness := int(_encounter.get("initial_pickiness", 0))
	var pickiness := int(battle_state.get("pickiness", initial_pickiness))
	$TopStatus/PickinessBar.max_value = maxi(1, initial_pickiness)
	$TopStatus/PickinessBar.value = initial_pickiness - pickiness
	$TopStatus/PickinessLabel.text = "Boss 挑剔值 %d" % pickiness
	_refresh_next_window()


func _refresh_next_window() -> void:
	var elapsed_ms := int(battle_state.get("elapsed_ms", 0))
	for window_value in _encounter.get("windows", []):
		var window: Dictionary = window_value
		if int(window.get("at_ms", 0)) > elapsed_ms:
			$BattleFooter/NextDemandLabel.text = "下一需求 %02ds｜%s" % [
				int(window.get("at_ms", 0) / 1000),
				_metric_name(String(window.get("metric", "")))
			]
			return
	var duration_ms := int(_encounter.get("duration_ms", 30000))
	$BattleFooter/NextDemandLabel.text = "终局 %02ds｜清空挑剔值" % int(duration_ms / 1000)


func _build_snapshot_grid() -> void:
	var grid: GridContainer = $BoardPresentation/SnapshotGrid
	if grid.get_child_count() > 0:
		return
	for row in ROWS:
		for column in COLUMNS:
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(72, 72)
			cell.set_meta("row", row)
			cell.set_meta("column", column)
			cell.set_meta("instance_id", "")
			cell.add_theme_stylebox_override("panel", _cell_style(false, false))
			var icon := TextureRect.new()
			icon.name = "Icon"
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(icon)
			grid.add_child(cell)


func _render_snapshot() -> void:
	var grid: GridContainer = $BoardPresentation/SnapshotGrid
	for cell in grid.get_children():
		cell.set_meta("instance_id", "")
		cell.get_node("Icon").texture = null
		cell.modulate = Color.WHITE
		cell.add_theme_stylebox_override("panel", _cell_style(false, false))
	var related_instances := {}
	for relation in _snapshot.get("relations", []):
		related_instances[String(relation.get("left_instance_id", ""))] = true
		related_instances[String(relation.get("right_instance_id", ""))] = true
	for instance_value in _snapshot.get("instances", []):
		var instance: Dictionary = instance_value
		var instance_id := String(instance.get("instance_id", ""))
		var texture := RecipeIconService.texture(String(instance.get("recipe_id", "")), 0, "base")
		for cell_value in instance.get("cells", []):
			var row := int(cell_value[0])
			var column := int(cell_value[1])
			var index := row * COLUMNS + column
			if index < 0 or index >= grid.get_child_count():
				continue
			var cell: PanelContainer = grid.get_child(index)
			cell.set_meta("instance_id", instance_id)
			cell.get_node("Icon").texture = texture
			cell.add_theme_stylebox_override("panel", _cell_style(true, related_instances.has(instance_id)))


func _cell_style(occupied: bool, related: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#5367d5") if occupied else Color("#29213d")
	style.border_color = Color("#ffc857") if related else Color("#655a82")
	style.set_border_width_all(3 if related else 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 5
	style.content_margin_top = 5
	style.content_margin_right = 5
	style.content_margin_bottom = 5
	return style


func _pulse_instance(instance_id: String, color: Color, animate: bool) -> void:
	for cell in $BoardPresentation/SnapshotGrid.get_children():
		if String(cell.get_meta("instance_id", "")) != instance_id:
			continue
		cell.modulate = color
		if animate:
			var tween := cell.create_tween()
			tween.tween_property(cell, "modulate", Color.WHITE, 0.24)
		else:
			cell.modulate = Color.WHITE


func _highlight_relation(source_id: String, animate: bool) -> void:
	var related_ids := {source_id: true}
	for relation in _snapshot.get("relations", []):
		if relation.get("left_instance_id") == source_id or relation.get("right_instance_id") == source_id:
			related_ids[String(relation.get("left_instance_id", ""))] = true
			related_ids[String(relation.get("right_instance_id", ""))] = true
	for instance_id in related_ids:
		_pulse_instance(String(instance_id), Color("#72d6a0"), animate)


func _toggle_pause() -> void:
	set_paused(not battle_paused)


func _window_text(window: Dictionary) -> String:
	return "%02ds｜%s ≥ %d" % [
		int(window.get("at_ms", 0) / 1000),
		_metric_name(String(window.get("metric", ""))),
		int(window.get("target", 0))
	]


func _metric_name(metric: String) -> String:
	match metric:
		"sales_count":
			return "累计出餐"
		"active_relation_count":
			return "有效联动"
		"window_satisfaction":
			return "区间满足力"
	return metric
