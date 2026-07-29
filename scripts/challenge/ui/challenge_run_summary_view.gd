class_name ChallengeRunSummaryView
extends PanelContainer

const UiStyle = preload("res://scripts/challenge/ui/challenge_ui_style.gd")

signal return_requested
signal reward_requested


func _ready() -> void:
	UiStyle.apply_primary($Content/Actions/RewardButton, Color("#2D9A6A"))
	UiStyle.apply_secondary($Content/Actions/ReturnButton)
	$Content/Actions/RewardButton.pressed.connect(func() -> void: reward_requested.emit())
	$Content/Actions/ReturnButton.pressed.connect(func() -> void: return_requested.emit())


func bind(run: Dictionary, meta: Dictionary) -> void:
	var mode := String(run.get("mode", ""))
	var completed := String(run.get("phase", "")) == "run_complete"
	if mode == "endless":
		var cleared := int(run.get("highest_cleared_floor", 0))
		var records: Dictionary = meta.get("endless_records", {})
		var staged_points := mini(3, int(cleared / 5))
		$Content/Eyebrow.text = "ENDLESS CLIMB · 本局纪录已保存"
		$Content/Outcome.text = "无尽爬升止步第 %d 层" % (cleared + 1)
		$Content/History.text = "已通关 %d 层 · 获得强化 %d 层 · 历史最高 %d 层" % [
			cleared,
			_count_upgrade_stacks(run.get("run_upgrades", [])),
			int(records.get("best_floor", 0))
		]
		$Content/ResearchSummary.text = "最终构筑：%s\n阶段研究收益 %d 点 · 当前研究点 %d" % [
			_upgrade_summary(run.get("run_upgrades", [])),
			staged_points,
			int(meta.get("research_points", 0))
		]
		$Content/Actions/RewardButton.text = "确认结算并领取 %d 点" % staged_points
		$Content/Actions/RewardButton.visible = not bool(run.get("endless_rewarded", false))
		$Content/Actions/ReturnButton.disabled = not bool(run.get("endless_rewarded", false))
		return
	$Content/Eyebrow.text = "五张订单票据已结算"
	$Content/Outcome.text = "短链完成" if completed else "短链结束"
	$Content/History.text = "完成战斗 %d 次 · 获得强化 %d 个 · 剩余信心 %d / 2" % [
		_count_history(run.get("stage_history", []), "battle"),
		_count_upgrade_stacks(run.get("run_upgrades", [])),
		int(run.get("confidence", 0))
	]
	$Content/ResearchSummary.text = "本局构筑：%s\n当前研究点 %d" % [
		_upgrade_summary(run.get("run_upgrades", [])),
		int(meta.get("research_points", 0))
	]
	$Content/Actions/RewardButton.text = "领取 3 点研究收益"
	$Content/Actions/RewardButton.visible = completed and not bool(run.get("research_rewarded", false))
	$Content/Actions/ReturnButton.disabled = completed and not bool(run.get("research_rewarded", false))


func _upgrade_summary(upgrades: Array) -> String:
	var labels: Array[String] = []
	for value in upgrades:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		var definition: Dictionary = entry.get("definition", {})
		var label := String(definition.get("display_name", entry.get("upgrade_id", "强化")))
		var stacks := maxi(1, int(entry.get("stack_count", 1)))
		labels.append("%s%s" % [label, " ×%d" % stacks if stacks > 1 else ""])
	return "、".join(labels) if not labels.is_empty() else "尚未获得强化"


func _count_upgrade_stacks(upgrades: Array) -> int:
	var count := 0
	for value in upgrades:
		if value is Dictionary:
			count += maxi(1, int(value.get("stack_count", 1)))
		else:
			count += 1
	return count


func _count_history(history: Array, kind: String) -> int:
	var count := 0
	for value in history:
		if value is Dictionary and String(value.get("kind", "")) == kind:
			count += 1
	return count
