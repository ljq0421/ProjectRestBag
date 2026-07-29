class_name ChallengeHubView
extends PanelContainer

const UiStyle = preload("res://scripts/challenge/ui/challenge_ui_style.gd")

signal start_requested
signal endless_requested
signal continue_requested
signal menu_requested
signal research_requested


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


func bind(meta: Dictionary, active_run: Variant) -> void:
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
