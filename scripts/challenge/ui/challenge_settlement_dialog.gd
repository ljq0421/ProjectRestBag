class_name ChallengeSettlementDialog
extends PopupPanel

signal retry_requested
signal back_requested
signal report_action_requested(action: String)
signal tutorial_help_requested


func _ready() -> void:
	$Margin/Content/ActionRow/RetryButton.pressed.connect(func() -> void:
		report_action_requested.emit("retry")
		retry_requested.emit()
	)
	$Margin/Content/ActionRow/BackButton.pressed.connect(func() -> void:
		report_action_requested.emit("back")
		back_requested.emit()
	)
	$Margin/Content/ActionRow/TutorialHelpButton.pressed.connect(func() -> void:
		tutorial_help_requested.emit()
	)


func resolve_tutorial_targets(outcome: String, retryable: bool = true) -> Array[Rect2]:
	if outcome == "victory":
		return [
			$Margin/Content/WindowRows.get_global_rect(),
			$Margin/Content/ContributionRows.get_global_rect()
		]
	var action_target: Control = (
		$Margin/Content/ActionRow/RetryButton
		if retryable
		else $Margin/Content/ActionRow/BackButton
	)
	return [
		$Margin/Content/PrimaryFailure.get_global_rect(),
		$Margin/Content/SuggestionList.get_global_rect(),
		action_target.get_global_rect()
	]


func show_tutorial_report(outcome: String, replay_mode: bool = false, retryable: bool = true) -> void:
	var victory := outcome == "victory"
	var terminal_loss := not victory and not retryable
	$TutorialReportOverlay.show_step(
		7,
		9,
		"读懂胜利来自哪里" if victory else ("本场挑战已结束" if terminal_loss else "先找出本场主要缺口"),
		"查看需求窗口和配方贡献。" if victory else ("查看失败原因，然后返回备战。" if terminal_loss else "查看失败窗口，再按建议重排展示柜。"),
		resolve_tutorial_targets(outcome, retryable),
		"",
		replay_mode
	)


func hide_tutorial_report() -> void:
	$TutorialReportOverlay.hide_step()


func bind_report(report: Dictionary) -> void:
	var victory := String(report.get("outcome", "")) == "victory"
	$Margin/Content/ResultTitle.text = "挑战成功｜评论家认可了你的展示柜" if victory else "挑战失利｜调整备货后再战"
	$Margin/Content/ResultTitle.add_theme_color_override(
		"font_color",
		Color("#2d8a60") if victory else Color("#ef476f")
	)
	$Margin/Content/PressureSummary.text = "口碑防线 %d｜Boss 剩余挑剔值 %d｜总出餐 %d｜总满足力 %d" % [
		int(report.get("reputation_remaining", 0)),
		int(report.get("pickiness_remaining", 0)),
		int(report.get("total_sales", 0)),
		int(report.get("total_satisfaction", 0))
	]
	$Margin/Content/WindowRows.text = _window_rows(report.get("windows", []))
	$Margin/Content/ContributionRows.text = _contribution_rows(report.get("recipe_contributions", []))

	var failure: Dictionary = report.get("primary_failure", {})
	if failure.is_empty():
		$Margin/Content/PrimaryFailure.text = "关键结论：所有已触发需求均已覆盖。"
	else:
		$Margin/Content/PrimaryFailure.text = "主要缺口：%s 实际 %s / 目标 %s" % [
			String(failure.get("window_id", "")),
			_display_value(failure.get("actual")),
			_display_value(failure.get("target"))
		]
	$Margin/Content/SuggestionList.text = _suggestion_rows(report.get("suggestions", []))


func set_retry_enabled(enabled: bool) -> void:
	$Margin/Content/ActionRow/RetryButton.disabled = not enabled
	$Margin/Content/ActionRow/RetryButton.text = "调整备货，再战同一 Boss" if enabled else "本局已结束"


func _window_rows(windows: Array) -> String:
	var lines: Array[String] = ["[b]需求窗口[/b]"]
	for row_value in windows:
		var row: Dictionary = row_value
		if not bool(row.get("resolved", false)):
			lines.append("— %02ds｜战斗提前结束，未触发" % int(row.get("at_ms", 0) / 1000))
			continue
		var passed := bool(row.get("passed", false))
		lines.append("%s %02ds｜%s｜%s / %s%s" % [
			"[color=#72d6a0]✓[/color]" if passed else "[color=#ef476f]✕[/color]",
			int(row.get("at_ms", 0) / 1000),
			String(row.get("window_id", "")),
			_display_value(row.get("actual")),
			_display_value(row.get("target")),
			"" if passed else "｜口碑 -%d" % int(row.get("reputation_damage", 0))
		])
	return "\n".join(lines)


func _display_value(value: Variant) -> String:
	return "—" if value == null else str(value)


func _contribution_rows(rows: Array) -> String:
	var lines: Array[String] = ["[b]配方贡献[/b]"]
	for row_value in rows:
		var row: Dictionary = row_value
		lines.append("%s｜%d 次｜基础 %d + 联动 %d = %d" % [
			String(row.get("recipe_id", "")),
			int(row.get("sales_count", 0)),
			int(row.get("base_satisfaction", 0)),
			int(row.get("relation_bonus", 0)),
			int(row.get("total_satisfaction", 0))
		])
	if rows.is_empty():
		lines.append("本场没有完成出餐。")
	return "\n".join(lines)


func _suggestion_rows(suggestions: Array) -> String:
	var lines: Array[String] = ["[b]下次调整[/b]"]
	for suggestion_value in suggestions:
		var suggestion: Dictionary = suggestion_value
		lines.append("• %s" % String(suggestion.get("text", "")))
	if suggestions.is_empty():
		lines.append("当前没有额外调整建议。")
	return "\n".join(lines)
