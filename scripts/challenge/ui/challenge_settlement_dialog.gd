class_name ChallengeSettlementDialog
extends PopupPanel

signal retry_requested
signal back_requested
signal report_action_requested(action: String)
signal tutorial_help_requested
signal tutorial_dismiss_requested
signal tutorial_next_requested

const Catalog = preload("res://scripts/catalog.gd")
const ChallengeTutorialOverlay = preload("res://scripts/challenge/ui/challenge_tutorial_overlay.gd")
const UiStyle = preload("res://scripts/challenge/ui/challenge_ui_style.gd")

var _report_open := false
var _report_action_committed := false
var _unexpected_hide_restore_pending := false
var _report_victory := false
var _catalog_recipes: Dictionary = Catalog.new().get_recipes()


func _ready() -> void:
	UiStyle.apply_primary($Margin/Content/ActionRow/RetryButton, Color("#E34B72"))
	UiStyle.apply_secondary($Margin/Content/ActionRow/BackButton)
	$Margin/Content/ActionRow/RetryButton.pressed.connect(func() -> void:
		_request_report_action("retry")
	)
	$Margin/Content/ActionRow/BackButton.pressed.connect(func() -> void:
		_request_report_action("back")
	)
	$Margin/Content/ActionRow/TutorialHelpButton.pressed.connect(func() -> void:
		tutorial_help_requested.emit()
	)
	$TutorialOverlayHost/TutorialReportOverlay.dismiss_requested.connect(func() -> void:
		tutorial_dismiss_requested.emit()
	)
	$TutorialOverlayHost/TutorialReportOverlay.next_requested.connect(func() -> void:
		tutorial_next_requested.emit()
	)
	close_requested.connect(_on_close_requested)
	popup_hide.connect(_on_popup_hide)


func open_report() -> void:
	_report_open = true
	_report_action_committed = false
	_unexpected_hide_restore_pending = false
	popup_centered(Vector2i(1080, 820))


func close_after_report_action() -> bool:
	if not _report_open or not _report_action_committed:
		return false
	_report_open = false
	hide()
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		set_input_as_handled()


func _request_report_action(action: String) -> void:
	if not _report_open or _report_action_committed:
		return
	_report_action_committed = true
	report_action_requested.emit(action)
	if action == "retry":
		retry_requested.emit()
	else:
		back_requested.emit()


func _on_close_requested() -> void:
	if _report_open and not _report_action_committed:
		grab_focus()


func _on_popup_hide() -> void:
	if not _report_open or _report_action_committed or _unexpected_hide_restore_pending:
		return
	_unexpected_hide_restore_pending = true
	call_deferred("_restore_after_unexpected_hide")


func _restore_after_unexpected_hide() -> void:
	_unexpected_hide_restore_pending = false
	if not is_inside_tree() or not _report_open or _report_action_committed or visible:
		return
	popup_centered(Vector2i(1080, 820))


func resolve_tutorial_targets(outcome: String, retryable: bool = true) -> Array[Rect2]:
	if outcome == "victory":
		return [
			ChallengeTutorialOverlay.control_screen_rect($Margin/Content/WindowRows),
			ChallengeTutorialOverlay.control_screen_rect($Margin/Content/ContributionRows),
			ChallengeTutorialOverlay.control_screen_rect($Margin/Content/ActionRow/BackButton)
		]
	var action_target: Control = (
		$Margin/Content/ActionRow/RetryButton
		if retryable
		else $Margin/Content/ActionRow/BackButton
	)
	return [
		ChallengeTutorialOverlay.control_screen_rect($Margin/Content/PrimaryFailure),
		ChallengeTutorialOverlay.control_screen_rect($Margin/Content/SuggestionList),
		ChallengeTutorialOverlay.control_screen_rect(action_target)
	]


func show_tutorial_report(outcome: String, replay_mode: bool = false, retryable: bool = true) -> void:
	var victory := outcome == "victory"
	var terminal_loss := not victory and not retryable
	$TutorialOverlayHost/TutorialReportOverlay.show_step(
		7,
		9,
		"读懂胜利来自哪里" if victory else ("本场挑战已结束" if terminal_loss else "先找出本场主要缺口"),
		"查看需求窗口和配方贡献，然后点击“返回备战”离开战报。" if victory else ("查看失败原因，然后返回备战。" if terminal_loss else "查看失败窗口，再按建议重排展示柜。"),
		resolve_tutorial_targets(outcome, retryable),
		"",
		replay_mode
	)


func show_tutorial_step(
	step_number: int,
	total_steps: int,
	title: String,
	body: String,
	targets: Array[Rect2],
	confirm_text: String = "",
	replay_mode: bool = false
) -> void:
	$TutorialOverlayHost/TutorialReportOverlay.show_step(
		step_number,
		total_steps,
		title,
		body,
		targets,
		confirm_text,
		replay_mode
	)


func hide_tutorial_report() -> void:
	$TutorialOverlayHost/TutorialReportOverlay.hide_step()


func bind_report(report: Dictionary) -> void:
	var victory := String(report.get("outcome", "")) == "victory"
	_report_victory = victory
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
		match String(report.get("outcome", "")):
			"victory":
				$Margin/Content/PrimaryFailure.text = "通过原因：Boss 挑剔值已清空；所有已触发需求均已覆盖。"
			"loss_timeout":
				$Margin/Content/PrimaryFailure.text = (
					"失败原因：时间到时 Boss 仍有 %d 挑剔值；需求虽已覆盖，但总满足力不足。"
					% int(report.get("pickiness_remaining", 0))
				)
			"loss_reputation":
				$Margin/Content/PrimaryFailure.text = "失败原因：需求失败累计扣光了口碑防线。"
			_:
				$Margin/Content/PrimaryFailure.text = "关键结论：所有已触发需求均已覆盖。"
	else:
		var actual := int(failure.get("actual", 0))
		var target := int(failure.get("target", 0))
		$Margin/Content/PrimaryFailure.text = "失败原因：%s 实际 %d / 目标 %d，差 %d；本次口碑 -%d。" % [
			_metric_name(String(failure.get("metric", ""))),
			actual,
			target,
			maxi(0, target - actual),
			int(failure.get("reputation_damage", 0))
		]
	$Margin/Content/SuggestionList.text = _suggestion_rows(report.get("suggestions", []))


func set_retry_enabled(enabled: bool, final_stage: bool = false) -> void:
	$Margin/Content/ActionRow/RetryButton.visible = enabled
	$Margin/Content/ActionRow/RetryButton.disabled = not enabled
	$Margin/Content/ActionRow/RetryButton.text = "调整备货，再战同一 Boss"
	if enabled:
		UiStyle.apply_secondary($Margin/Content/ActionRow/BackButton)
		$Margin/Content/ActionRow/BackButton.text = "返回备战"
	else:
		UiStyle.apply_primary($Margin/Content/ActionRow/BackButton, Color("#546BDD"))
		$Margin/Content/ActionRow/BackButton.text = (
			"查看短链总结" if final_stage or not _report_victory else "选择本局强化"
		)


func _window_rows(windows: Array) -> String:
	var lines: Array[String] = ["[color=#29213d]需求窗口[/color]"]
	for row_value in windows:
		var row: Dictionary = row_value
		if not bool(row.get("resolved", false)):
			lines.append("— %02ds｜战斗提前结束，未触发" % int(row.get("at_ms", 0) / 1000))
			continue
		var passed := bool(row.get("passed", false))
		var metric_text := _metric_name(String(row.get("metric", "")))
		var tag_context := _window_tag_context(row)
		var guard_absorbed := int(row.get("guard_absorbed", 0))
		if not tag_context.is_empty():
			metric_text = "%s（%s）" % [metric_text, tag_context]
		lines.append("%s %02ds｜%s｜%s / %s%s" % [
			"[color=#72d6a0]✓[/color]" if passed else "[color=#ef476f]✕[/color]",
			int(row.get("at_ms", 0) / 1000),
			metric_text,
			_display_value(row.get("actual")),
			_display_value(row.get("target")),
			"" if passed else "｜口碑 -%d%s" % [
				int(row.get("reputation_damage", 0)),
				"｜开场缓冲吸收 %d" % guard_absorbed if guard_absorbed > 0 else ""
			]
		])
	return "\n".join(lines)


func _display_value(value: Variant) -> String:
	return "—" if value == null else str(value)


func _contribution_rows(rows: Array) -> String:
	var lines: Array[String] = ["[color=#29213d]配方贡献[/color]"]
	for row_value in rows:
		var row: Dictionary = row_value
		lines.append("%s｜%d 次｜基础 %d + 联动 %d = %d" % [
			_recipe_name(String(row.get("recipe_id", ""))),
			int(row.get("sales_count", 0)),
			int(row.get("base_satisfaction", 0)),
			int(row.get("relation_bonus", 0)),
			int(row.get("total_satisfaction", 0))
		])
	if rows.is_empty():
		lines.append("本场没有完成出餐。")
	return "\n".join(lines)


func _metric_name(metric: String) -> String:
	match metric:
		"sales_count":
			return "累计出餐"
		"active_relation_count":
			return "有效联动"
		"window_satisfaction":
			return "区间满足力"
		"tag_sales_count":
			return "标签出餐"
		"tag_satisfaction":
			return "标签满足力"
		"distinct_tag_count":
			return "售出标签种类"
	return "需求目标"


func _window_tag_context(window: Dictionary) -> String:
	var values: Variant = window.get("target_tags", [])
	if not values is Array:
		return ""
	var names: Array[String] = []
	for value in values:
		var name := _tag_name(String(value))
		if not name.is_empty() and not names.has(name):
			names.append(name)
	return " / ".join(names)


func _tag_name(tag: String) -> String:
	var names := {
		"fast": "快速", "bake": "烘焙", "fruit": "水果", "drink": "饮品",
		"set": "搭配", "signature": "招牌", "chocolate": "巧克力",
		"aromatic": "香气", "soft": "软糯", "tea": "茶香", "crisp": "香脆",
		"savory": "咸香", "hearty": "饱腹", "refreshing": "清爽",
		"rich": "浓郁", "spatial": "空间"
	}
	return String(names.get(tag, tag))


func _recipe_name(recipe_id: String) -> String:
	return String((_catalog_recipes.get(recipe_id, {}) as Dictionary).get("name", recipe_id))


func _suggestion_rows(suggestions: Array) -> String:
	var lines: Array[String] = ["[color=#29213d]下次调整[/color]"]
	for suggestion_value in suggestions:
		var suggestion: Dictionary = suggestion_value
		lines.append("• %s" % String(suggestion.get("text", "")))
	if suggestions.is_empty():
		lines.append("当前没有额外调整建议。")
	return "\n".join(lines)
