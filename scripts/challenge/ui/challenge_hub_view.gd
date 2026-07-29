class_name ChallengeHubView
extends PanelContainer

const UiStyle = preload("res://scripts/challenge/ui/challenge_ui_style.gd")

signal start_requested
signal endless_requested
signal continue_requested
signal menu_requested
signal research_requested
signal route_selected(route_id: String)

var _route_states: Array[Dictionary] = []
var _binding_routes := false


func _ready() -> void:
	UiStyle.apply_primary($Content/Actions/StartButton)
	UiStyle.apply_primary($Content/Actions/EndlessButton, Color("#6B63C7"))
	UiStyle.apply_primary($Content/Actions/ContinueButton)
	UiStyle.apply_secondary($Content/Actions/MenuButton)
	UiStyle.apply_secondary($Content/Actions/ResearchButton)
	$Content/Actions/StartButton.pressed.connect(func() -> void: start_requested.emit())
	$Content/Actions/EndlessButton.pressed.connect(func() -> void: endless_requested.emit())
	$Content/Actions/ContinueButton.pressed.connect(func() -> void: continue_requested.emit())
	$Content/Actions/MenuButton.pressed.connect(func() -> void: menu_requested.emit())
	$Content/Actions/ResearchButton.pressed.connect(func() -> void: research_requested.emit())
	$Content/RouteRow/RouteSelector.item_selected.connect(_on_route_selected)


func bind(
	meta: Dictionary,
	active_run: Variant,
	route_states: Array[Dictionary] = [],
	mastery_states: Array[Dictionary] = []
) -> void:
	var has_run := active_run is Dictionary
	var records: Dictionary = meta.get("endless_records", {})
	var endless_unlocked := bool(records.get("unlocked", false))
	$Content/ResearchPoints.text = "研究点 %d" % int(meta.get("research_points", 0))
	$Content/PoolSummary.text = "永久收藏 %d 种 · 本局菜单 %d / 8" % [
		(meta.get("unlocked_recipe_ids", []) as Array).size(),
		(meta.get("active_menu_recipe_ids", []) as Array).size()
	]
	$Content/EndlessRecord.text = (
		"无尽纪录：最高 %d 层 · 分段研究收益单局最多 3 点" % int(records.get("best_floor", 0))
		if endless_unlocked
		else "无尽爬升：完成第一条五场短链后解锁"
	)
	$Content/Actions/StartButton.visible = not has_run
	$Content/Actions/EndlessButton.visible = not has_run
	$Content/Actions/EndlessButton.disabled = not endless_unlocked
	$Content/Actions/EndlessButton.text = "开始无尽爬升" if endless_unlocked else "无尽爬升（未解锁）"
	$Content/Actions/ContinueButton.visible = has_run
	$Content/Actions/ContinueButton.disabled = not has_run
	$Content/Actions/MenuButton.visible = not has_run
	_bind_routes(route_states, active_run)
	var completed_masteries := 0
	for state in mastery_states:
		if bool(state.get("completed", false)):
			completed_masteries += 1
	$Content/LongGoals.text = "长期目标：%d / %d · 路线首胜 %d / %d" % [
		completed_masteries,
		mastery_states.size(),
		(meta.get("route_first_clear_ids", []) as Array).size(),
		route_states.size()
	]
	if has_run:
		var run: Dictionary = active_run
		if String(run.get("mode", "")) == "endless":
			$Content/ActiveRun.text = "无尽进行中：第 %d 层 · 信心 %d / 2" % [
				int(run.get("stage_index", 0)) + 1,
				int(run.get("confidence", 0))
			]
		else:
			$Content/ActiveRun.text = "短链进行中：第 %d / 5 场 · 信心 %d / 2" % [
				int(run.get("stage_index", 0)) + 1,
				int(run.get("confidence", 0))
			]
	else:
		$Content/ActiveRun.text = "五场短链构筑成长 · 无尽爬升纪录挑战"


func _bind_routes(route_states: Array[Dictionary], active_run: Variant) -> void:
	_route_states = route_states.duplicate(true)
	var selector: OptionButton = $Content/RouteRow/RouteSelector
	_binding_routes = true
	selector.clear()
	var selected_index := 0
	var active_route_id := (
		String((active_run as Dictionary).get("route_id", ""))
		if active_run is Dictionary
		else ""
	)
	for index in range(_route_states.size()):
		var state := _route_states[index]
		var label := String(state.get("display_name", state.get("route_id", "")))
		if not bool(state.get("unlocked", false)):
			label += "（未解锁）"
		elif bool(state.get("first_cleared", false)):
			label += " ✓"
		selector.add_item(label)
		selector.set_item_metadata(index, String(state.get("route_id", "")))
		if not active_route_id.is_empty() and String(state.get("route_id", "")) == active_route_id:
			selected_index = index
	if selector.item_count > 0:
		selector.select(selected_index)
	_binding_routes = false
	_refresh_route_status(selected_index)


func _on_route_selected(index: int) -> void:
	if _binding_routes:
		return
	_refresh_route_status(index)
	if index >= 0 and index < _route_states.size():
		var state := _route_states[index]
		if bool(state.get("unlocked", false)):
			route_selected.emit(String(state.get("route_id", "")))


func _refresh_route_status(index: int) -> void:
	if index < 0 or index >= _route_states.size():
		$Content/RouteStatus.text = "暂无标准路线"
		$Content/Actions/StartButton.disabled = true
		return
	var state := _route_states[index]
	var unlocked := bool(state.get("unlocked", false))
	$Content/RouteStatus.text = (
		String(state.get("description", ""))
		if unlocked
		else String(state.get("lock_reason", "路线尚未解锁"))
	)
	$Content/Actions/StartButton.disabled = not unlocked
