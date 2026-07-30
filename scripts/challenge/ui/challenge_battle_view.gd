class_name ChallengeBattleView
extends Control

signal battle_finished(final_state: Dictionary)

const BossBattleService = preload("res://scripts/challenge/boss_battle_service.gd")
const Catalog = preload("res://scripts/catalog.gd")
const RecipeIconService = preload("res://scripts/recipe_icon_service.gd")
const ShowcaseIconService = preload("res://scripts/ui/storefront/showcase_icon_service.gd")
const UPGRADE_CONFIG_PATH := "res://doc/challenge/run_upgrades.json"
const ROWS := 8
const COLUMNS := 14
const MIN_CELL_SIZE := 90
const MAX_CELL_SIZE := 132
const GRID_AVAILABLE_SIZE := Vector2i(1066, 550)

var battle_locked := false
var battle_paused := false
var battle_state: Dictionary = {}
var _encounter: Dictionary = {}
var _snapshot: Dictionary = {}
var _display_origin := Vector2i.ZERO
var _display_rows := 4
var _display_columns := 4
var _cell_size := MIN_CELL_SIZE
var _service = BossBattleService.new()
var _event_cursor := 0
var _finished_emitted := false
var _window_labels_by_id: Dictionary = {}
var _catalog_recipes: Dictionary = Catalog.new().get_recipes()
var _upgrade_definitions: Dictionary = {}
var _origin_cell_by_instance: Dictionary = {}
var _showcase_icons = ShowcaseIconService.new()


func _ready() -> void:
	_upgrade_definitions = _load_upgrade_definitions()
	_showcase_icons.load_manifest()
	$TopStatus/PickinessBar.fill_mode = 1
	$TopStatus/ReputationBar.tooltip_text = "口碑防线受需求失败影响，从左侧向中央退缩"
	$TopStatus/PickinessBar.tooltip_text = "Boss 挑剔值从右侧向中央施压；售卖会把它向右推回"
	$BattleFooter/PauseButton.pressed.connect(_toggle_pause)
	_build_boss_pressure_visual()
	_build_snapshot_grid()
	set_process(false)


func _build_boss_pressure_visual() -> void:
	var portrait: ColorRect = $BossPanel/BossPortrait
	portrait.color = Color("#E34B72").lightened(0.72)
	var copy := Label.new()
	copy.name = "PressureCopy"
	copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	copy.text = "◆ 客潮压力演算中 ◆\n需求窗口将按时间自动触发"
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	copy.add_theme_color_override("font_color", Color("#8F294C"))
	copy.add_theme_font_size_override("font_size", 22)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(copy)


func bind_encounter(encounter: Dictionary) -> void:
	_encounter = encounter.duplicate(true)
	var duration_seconds := int(ceil(float(_encounter.get("duration_ms", 30000)) / 1000.0))
	var encounter_name := String(_encounter.get("display_name", "挑剔的美食评论家"))
	$BossPanel/BossName.text = encounter_name
	$BossPanel/BossPortrait/PressureCopy.text = "◆ %s正在施压 ◆\n需求窗口将按时间自动触发" % encounter_name
	$BossPanel/BossRule.text = "%d 秒内清空挑剔值。售卖全自动；需求窗口失败会削减口碑防线。" % duration_seconds
	var windows: Array = _encounter.get("windows", [])
	_rebuild_demand_timeline(windows, duration_seconds)
	_refresh_status()


func start_battle(snapshot: Dictionary, seed: int) -> void:
	_snapshot = snapshot.duplicate(true)
	battle_state = _service.create_state(_snapshot, _encounter, seed)
	battle_locked = true
	battle_paused = false
	_event_cursor = 0
	_finished_emitted = false
	$BattleFooter/CurrentDemandLabel.text = "自动战斗中｜详细结算显示在左侧配方格"
	_render_snapshot()
	var opening_guard := int(
		(_snapshot.get("effective_rules", {}) as Dictionary).get("first_window_guard", 0)
	)
	_set_board_event(
		"等待出售：每张配方周期到点自动卖 1 份；库存为 0 后停止。%s" % (
			"首个需求另有 %d 点开场缓冲。" % opening_guard
			if opening_guard > 0
			else ""
		),
		Color("#F7F4FF")
	)
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
	_set_board_event("正在还原战斗记录……", Color("#F7F4FF"))
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
			var recipe_name := _recipe_name(String(event.get("recipe_id", "")))
			var base_satisfaction := int(event.get("base_satisfaction", 0))
			var relation_bonus := int(event.get("relation_bonus", 0))
			var final_satisfaction := int(event.get("final_satisfaction", 0))
			var pickiness_reduction := int(
				event.get("pickiness_reduction", final_satisfaction)
			)
			$BattleFooter/CurrentDemandLabel.text = "%s 已售出｜Boss 挑剔 -%d" % [
				recipe_name,
				pickiness_reduction
			]
			_set_board_event(
				_sale_event_text(
					event,
					recipe_name,
					base_satisfaction,
					relation_bonus,
					final_satisfaction,
					pickiness_reduction
				),
				Color("#FFC857") if relation_bonus == 0 else Color("#72D6A0")
			)
			_show_sale_on_grid(event)
			_pulse_instance(String(event.get("source_id", "")), Color("#ffc857"), animate)
		"relation_trigger":
			_show_relation_on_grid(event)
			_highlight_relation(String(event.get("source_id", "")), animate)
		"demand_window":
			_resolve_window_visual(event)
			_show_window_on_grid(event)
		"battle_end":
			var victory := String(event.get("outcome", "")) == "victory"
			var outcome_text := _battle_outcome_text(event)
			_set_board_event(
				outcome_text,
				Color("#72D6A0") if victory else Color("#EF476F")
			)
			$BattleFooter/CurrentDemandLabel.text = outcome_text
			battle_paused = false
			set_process(false)
			$BattleFooter/PauseButton.disabled = true
			if not _finished_emitted:
				_finished_emitted = true
				battle_finished.emit(battle_state.duplicate(true))


func _resolve_window_visual(event: Dictionary) -> void:
	var window_id := String(event.get("window_id", ""))
	var label := _window_labels_by_id.get(window_id) as Label
	if label == null:
		return
	var passed := bool(event.get("passed", false))
	label.add_theme_color_override("font_color", Color("#72d6a0") if passed else Color("#ef476f"))
	label.text = "%s %s｜实际 %d" % [
		"✓" if passed else "✕",
		String(label.get_meta("display_text", "需求窗口")),
		int(event.get("actual", 0))
	]


func _refresh_status() -> void:
	var initial_reputation := int(_encounter.get("initial_reputation", 100))
	var reputation := int(battle_state.get("reputation", initial_reputation))
	$TopStatus/ReputationBar.max_value = initial_reputation
	$TopStatus/ReputationBar.value = reputation
	$TopStatus/ReputationLabel.text = "口碑防线 %d →" % reputation

	var initial_pickiness := int(_encounter.get("initial_pickiness", 0))
	var pickiness := int(battle_state.get("pickiness", initial_pickiness))
	$TopStatus/PickinessBar.max_value = maxi(1, initial_pickiness)
	$TopStatus/PickinessBar.value = pickiness
	$TopStatus/PickinessLabel.text = "← Boss 挑剔 %d" % pickiness
	_refresh_next_window()
	_refresh_grid_runtime()


func _refresh_next_window() -> void:
	if battle_state.is_empty():
		$BossPanel/CurrentWindowProgress.text = "需求进度：开战后实时显示"
		return
	if String(battle_state.get("phase", "")) == "finished":
		if String(battle_state.get("outcome", "")) == "victory":
			$BossPanel/CurrentWindowProgress.text = "已清空 Boss 挑剔值：立即胜利，未到的需求不再检查"
		else:
			$BossPanel/CurrentWindowProgress.text = "战斗已结束"
		return
	var progress: Dictionary = _service.next_window_progress(battle_state)
	if not progress.is_empty():
		var metric_text := _metric_name(String(progress.get("metric", "")))
		var tag_context := _window_tag_context(progress)
		if not tag_context.is_empty():
			metric_text = "%s（%s）" % [metric_text, tag_context]
		var actual := int(progress.get("actual", 0))
		var target := int(progress.get("target", 0))
		var result_text := (
			"已达标，等待到点检查"
			if actual >= target
			else "还差 %d" % int(progress.get("remaining", 0))
		)
		$BossPanel/CurrentWindowProgress.text = "当前检查 %02ds｜%s %d / %d｜%s" % [
			int(progress.get("at_ms", 0)) / 1000,
			metric_text,
			actual,
			target,
			result_text
		]
		$BattleFooter/NextDemandLabel.text = "到 %02ds 自动检查｜未达标才扣口碑" % (
			int(progress.get("at_ms", 0)) / 1000
		)
		return
	var duration_ms := int(_encounter.get("duration_ms", 30000))
	$BossPanel/CurrentWindowProgress.text = "所有需求已检查｜继续自动出售，清空 Boss 挑剔值"
	$BattleFooter/NextDemandLabel.text = "终局 %02ds｜清空挑剔值" % int(duration_ms / 1000)


func _build_snapshot_grid(force_rebuild := false) -> void:
	var grid: GridContainer = $BoardPresentation/BoardContent/SnapshotGrid
	if grid.get_child_count() > 0 and not force_rebuild:
		return
	for child in grid.get_children():
		child.free()
	_resolve_display_bounds()
	_cell_size = _resolved_cell_size()
	grid.columns = _display_columns
	grid.custom_minimum_size = Vector2(
		_display_columns * _cell_size + maxi(0, _display_columns - 1) * 2,
		_display_rows * _cell_size + maxi(0, _display_rows - 1) * 2
	)
	var top_badge_width := (_cell_size - 2) / 2
	var roomy_badges := _cell_size >= 104
	for local_row in _display_rows:
		for local_column in _display_columns:
			var row := _display_origin.x + local_row
			var column := _display_origin.y + local_column
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(_cell_size, _cell_size)
			cell.set_meta("row", row)
			cell.set_meta("column", column)
			cell.set_meta("instance_id", "")
			cell.set_meta("is_origin", false)
			cell.set_meta("related", false)
			cell.set_meta("upgraded", false)
			cell.add_theme_stylebox_override("panel", _cell_style(false, false, false))
			var icon_host := Control.new()
			icon_host.name = "IconHost"
			icon_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_host.clip_contents = false
			cell.add_child(icon_host)
			var icon := TextureRect.new()
			icon.name = "Icon"
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.z_index = 5
			icon_host.add_child(icon)
			var overlay := Control.new()
			overlay.name = "CellOverlay"
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.z_index = 10
			cell.add_child(overlay)
			overlay.add_child(_cell_badge(
				"CycleBadge",
				Rect2(0, 0, top_badge_width, 22),
				15 if roomy_badges else 14,
				Color("#F7F4FF"),
				Color("#171126E8")
			))
			overlay.add_child(_cell_badge(
				"StockBadge",
				Rect2(top_badge_width + 2, 0, _cell_size - top_badge_width - 2, 22),
				14 if roomy_badges else 13,
				Color("#F7F4FF"),
				Color("#171126E8")
			))
			overlay.add_child(_cell_badge(
				"EventBadge",
				Rect2(4, 28, _cell_size - 8, 32),
				19 if roomy_badges else 18,
				Color("#FFF4CF"),
				Color("#5D4315F2")
			))
			overlay.add_child(_cell_badge(
				"RelationBadge",
				Rect2(4, _cell_size - 24, _cell_size - 8, 20),
				13 if roomy_badges else 12,
				Color("#D8FFEA"),
				Color("#17382EF2")
			))
			grid.add_child(cell)


func _render_snapshot() -> void:
	var grid: GridContainer = $BoardPresentation/BoardContent/SnapshotGrid
	_build_snapshot_grid(true)
	_origin_cell_by_instance.clear()
	var unlocked_keys := {}
	for value in _snapshot.get("unlocked_cells", []):
		if value is Array and value.size() >= 2:
			unlocked_keys["%d:%d" % [int(value[0]), int(value[1])]] = true
	for cell in grid.get_children():
		cell.set_meta("instance_id", "")
		cell.set_meta("is_origin", false)
		cell.set_meta("related", false)
		cell.set_meta("upgraded", false)
		var icon: TextureRect = cell.get_node("IconHost/Icon")
		icon.texture = null
		icon.position = Vector2.ZERO
		icon.size = Vector2.ZERO
		for label_name in ["CycleBadge", "StockBadge", "EventBadge", "RelationBadge"]:
			var badge: Label = cell.get_node("CellOverlay/%s" % label_name)
			badge.text = ""
			badge.visible = false
		cell.tooltip_text = ""
		cell.modulate = Color.WHITE
		var key := "%d:%d" % [
			int(cell.get_meta("row", 0)),
			int(cell.get_meta("column", 0))
		]
		cell.add_theme_stylebox_override(
			"panel",
			_cell_style(false, false, false)
			if unlocked_keys.is_empty() or unlocked_keys.has(key)
			else _hidden_cell_style()
		)
	var related_instances := {}
	var relation_bonus_by_instance := {}
	var relation_sources_by_instance := {}
	for relation in _snapshot.get("relations", []):
		var bonus_pct := int(relation.get("bonus_pct", _encounter.get("relation_bonus_pct", 0)))
		for side in ["left_instance_id", "right_instance_id"]:
			var related_id := String(relation.get(side, ""))
			related_instances[related_id] = true
			relation_bonus_by_instance[related_id] = maxi(
				int(relation_bonus_by_instance.get(related_id, 0)),
				bonus_pct
			)
			relation_sources_by_instance[related_id] = _merge_source_ids(
				relation_sources_by_instance.get(related_id, []),
				relation.get("upgrade_source_ids", [])
			)
	for instance_value in _snapshot.get("instances", []):
		var instance: Dictionary = instance_value
		var instance_id := String(instance.get("instance_id", ""))
		var source_ids := _merge_source_ids(
			instance.get("upgrade_source_ids", []),
			relation_sources_by_instance.get(instance_id, [])
		)
		var related := related_instances.has(instance_id)
		var upgraded := not source_ids.is_empty()
		var base_satisfaction := int(instance.get("base_satisfaction", 0))
		var relation_pct := int(relation_bonus_by_instance.get(instance_id, 0))
		var relation_bonus := base_satisfaction * relation_pct / 100
		var instance_tooltip := _instance_tooltip(
			instance,
			relation_pct,
			relation_bonus,
			source_ids
		)
		var recipe_id := String(instance.get("recipe_id", ""))
		var origin_value: Array = instance.get("origin", [0, 0])
		var origin := Vector2i(int(origin_value[0]), int(origin_value[1]))
		var local_cells: Array[Vector2i] = []
		for cell_value in instance.get("cells", []):
			local_cells.append(
				Vector2i(int(cell_value[0]), int(cell_value[1])) - origin
			)
		var icon_layout := _showcase_icons.layout_for_shape(
			recipe_id,
			"standard",
			local_cells,
			0
		)
		var full_texture: Texture2D = _showcase_icons.layout_texture(icon_layout)
		if full_texture == null:
			full_texture = RecipeIconService.texture(recipe_id, 0, "base")
		for cell_value in instance.get("cells", []):
			var row := int(cell_value[0])
			var column := int(cell_value[1])
			var index := _display_index(row, column)
			if index < 0 or index >= grid.get_child_count():
				continue
			var cell: PanelContainer = grid.get_child(index)
			cell.set_meta("instance_id", instance_id)
			cell.set_meta("related", related)
			cell.set_meta("upgraded", upgraded)
			cell.add_theme_stylebox_override("panel", _cell_style(true, related, upgraded))
			cell.tooltip_text = instance_tooltip
		var origin_cell := _origin_cell(instance, grid)
		if origin_cell == null:
			continue
		var icon_host: Control = origin_cell.get_node("IconHost")
		var full_icon: TextureRect = icon_host.get_node("Icon")
		full_icon.texture = full_texture
		full_icon.position = Vector2.ZERO
		full_icon.size = _full_icon_size(icon_host, local_cells, _cell_size)
		origin_cell.set_meta("is_origin", true)
		_origin_cell_by_instance[instance_id] = origin_cell
		var cycle_badge: Label = origin_cell.get_node("CellOverlay/CycleBadge")
		cycle_badge.text = _seconds_badge_text(int(instance.get("cycle_ms", 0)))
		cycle_badge.visible = true
		var stock_badge: Label = origin_cell.get_node("CellOverlay/StockBadge")
		stock_badge.text = "余%d" % int(instance.get("virtual_stock", 0))
		stock_badge.visible = true
		if relation_pct > 0:
			var relation_badge: Label = origin_cell.get_node("CellOverlay/RelationBadge")
			relation_badge.text = "联动率%d%%" % relation_pct
			relation_badge.visible = true


func _cell_style(occupied: bool, related: bool, upgraded: bool, alert := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#5367d5") if occupied else Color("#29213d")
	style.border_color = (
		Color("#EF476F") if alert
		else Color("#FFC857") if related
		else Color("#5ED3C6") if upgraded
		else Color("#655A82")
	)
	style.set_border_width_all(4 if alert else 3 if related or upgraded else 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 5
	style.content_margin_top = 5
	style.content_margin_right = 5
	style.content_margin_bottom = 5
	return style


func _hidden_cell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	return style


func _full_icon_size(
	icon_host: Control,
	local_cells: Array[Vector2i],
	cell_size: int
) -> Vector2:
	var max_row := 0
	var max_column := 0
	for cell in local_cells:
		max_row = maxi(max_row, cell.x)
		max_column = maxi(max_column, cell.y)
	var base_size := icon_host.size
	if base_size.x <= 0.0 or base_size.y <= 0.0:
		base_size = Vector2(cell_size - 12, cell_size - 12)
	return base_size + Vector2(
		max_column * (cell_size + 2),
		max_row * (cell_size + 2)
	)


func _cell_badge(
	label_name: String,
	rect: Rect2,
	font_size: int,
	font_color: Color,
	background_color: Color
) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_stylebox_override("normal", _badge_style(background_color))
	label.visible = false
	return label


func _badge_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _set_badge_palette(label: Label, font_color: Color, background_color: Color) -> void:
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_stylebox_override("normal", _badge_style(background_color))


func _origin_cell(instance: Dictionary, grid: GridContainer) -> PanelContainer:
	var cells: Array = instance.get("cells", [])
	var origin_value: Variant = instance.get("origin")
	var coordinates: Array = []
	if origin_value is Array and origin_value.size() >= 2:
		coordinates = origin_value
	elif not cells.is_empty() and cells[0] is Array:
		coordinates = cells[0]
	if coordinates.size() < 2:
		return null
	var index := _display_index(int(coordinates[0]), int(coordinates[1]))
	if index < 0 or index >= grid.get_child_count():
		return null
	return grid.get_child(index) as PanelContainer


func _resolve_display_bounds() -> void:
	var cells: Array = _snapshot.get("unlocked_cells", [])
	if cells.is_empty():
		_display_origin = Vector2i.ZERO
		_display_rows = int(_snapshot.get("grid_rows", 6))
		_display_columns = int(_snapshot.get("grid_columns", 8))
		return
	var min_row := ROWS - 1
	var max_row := 0
	var min_column := COLUMNS - 1
	var max_column := 0
	for value in cells:
		if not value is Array or value.size() < 2:
			continue
		min_row = mini(min_row, int(value[0]))
		max_row = maxi(max_row, int(value[0]))
		min_column = mini(min_column, int(value[1]))
		max_column = maxi(max_column, int(value[1]))
	_display_origin = Vector2i(min_row, min_column)
	_display_rows = max_row - min_row + 1
	_display_columns = max_column - min_column + 1


func _resolved_cell_size() -> int:
	var horizontal_gaps := maxi(0, _display_columns - 1) * 2
	var vertical_gaps := maxi(0, _display_rows - 1) * 2
	var width_limited := (
		GRID_AVAILABLE_SIZE.x - horizontal_gaps
	) / maxi(1, _display_columns)
	var height_limited := (
		GRID_AVAILABLE_SIZE.y - vertical_gaps
	) / maxi(1, _display_rows)
	return clampi(mini(width_limited, height_limited), MIN_CELL_SIZE, MAX_CELL_SIZE)


func _display_index(row: int, column: int) -> int:
	var local_row := row - _display_origin.x
	var local_column := column - _display_origin.y
	if (
		local_row < 0
		or local_row >= _display_rows
		or local_column < 0
		or local_column >= _display_columns
	):
		return -1
	return local_row * _display_columns + local_column


func _seconds_badge_text(milliseconds: int) -> String:
	var seconds := float(maxi(0, milliseconds)) / 1000.0
	if is_equal_approx(seconds, float(roundi(seconds))):
		return "%d秒" % roundi(seconds)
	return "%.1f秒" % seconds


func _refresh_grid_runtime() -> void:
	if battle_state.is_empty():
		return
	var elapsed_ms := int(battle_state.get("elapsed_ms", 0))
	var item_states: Dictionary = battle_state.get("item_states", {})
	for instance_id_value in _origin_cell_by_instance.keys():
		var instance_id := String(instance_id_value)
		var cell := _origin_cell_by_instance.get(instance_id) as PanelContainer
		var item: Dictionary = item_states.get(instance_id, {})
		if cell == null or item.is_empty():
			continue
		var cycle_badge: Label = cell.get_node("CellOverlay/CycleBadge")
		var stock_badge: Label = cell.get_node("CellOverlay/StockBadge")
		var remaining_stock := int(item.get("remaining_stock", 0))
		stock_badge.text = "余%d" % remaining_stock
		stock_badge.visible = true
		if remaining_stock <= 0:
			cycle_badge.text = "售罄"
			_set_badge_palette(cycle_badge, Color("#D5CDDF"), Color("#393044F2"))
		else:
			var remaining_ms := maxi(
				0,
				int(item.get("next_sale_ms", elapsed_ms)) - elapsed_ms
			)
			cycle_badge.text = _seconds_badge_text(remaining_ms)
			_set_badge_palette(
				cycle_badge,
				Color("#FFF4CF") if remaining_ms <= 1000 else Color("#F7F4FF"),
				Color("#5D4315F2") if remaining_ms <= 1000 else Color("#171126E8")
			)
		cycle_badge.visible = true


func _show_sale_on_grid(event: Dictionary) -> void:
	var instance_id := String(event.get("source_id", ""))
	var cell := _origin_cell_by_instance.get(instance_id) as PanelContainer
	if cell == null:
		return
	_restore_instance_style(instance_id)
	var relation_bonus := int(event.get("relation_bonus", 0))
	var final_satisfaction := int(event.get("final_satisfaction", 0))
	var pickiness_reduction := int(event.get("pickiness_reduction", final_satisfaction))
	var event_badge: Label = cell.get_node("CellOverlay/EventBadge")
	event_badge.text = "挑剔-%d" % pickiness_reduction
	event_badge.visible = true
	_set_badge_palette(
		event_badge,
		Color("#D8FFEA") if relation_bonus > 0 else Color("#FFF4CF"),
		Color("#17382EF2") if relation_bonus > 0 else Color("#5D4315F2")
	)
	var item_states: Dictionary = battle_state.get("item_states", {})
	var item: Dictionary = item_states.get(instance_id, {})
	if not item.is_empty():
		var cycle_badge: Label = cell.get_node("CellOverlay/CycleBadge")
		var elapsed_ms := int(battle_state.get("elapsed_ms", 0))
		cycle_badge.text = _seconds_badge_text(
			maxi(0, int(item.get("next_sale_ms", elapsed_ms)) - elapsed_ms)
		)
		cycle_badge.visible = true
		var stock_badge: Label = cell.get_node("CellOverlay/StockBadge")
		stock_badge.text = "余%d" % int(item.get("remaining_stock", 0))
		stock_badge.visible = true


func _show_relation_on_grid(event: Dictionary) -> void:
	var instance_id := String(event.get("source_id", ""))
	var cell := _origin_cell_by_instance.get(instance_id) as PanelContainer
	if cell == null:
		return
	var relation_badge: Label = cell.get_node("CellOverlay/RelationBadge")
	relation_badge.text = "联动值+%d" % int(event.get("bonus_satisfaction", 0))
	relation_badge.visible = true
	_set_badge_palette(relation_badge, Color("#D8FFEA"), Color("#17382EF2"))


func _show_window_on_grid(event: Dictionary) -> void:
	var window := _window_definition(String(event.get("window_id", "")))
	var passed := bool(event.get("passed", false))
	var actual := int(event.get("actual", 0))
	var target := int(event.get("target", 0))
	var gap := maxi(0, target - actual)
	var metric_text := _metric_name(String(event.get("metric", "")))
	var tag_context := _window_tag_context(window)
	if not tag_context.is_empty():
		metric_text = "%s（%s）" % [metric_text, tag_context]
	var board_text := "%02ds 全局需求通过｜%s %d / %d｜不扣口碑" % [
		int(event.get("at_ms", 0)) / 1000,
		metric_text,
		actual,
		target
	] if passed else "%02ds 全局需求失败｜%s %d / %d｜整体还差 %d｜口碑 -%d" % [
		int(event.get("at_ms", 0)) / 1000,
		metric_text,
		actual,
		target,
		gap,
		int(event.get("reputation_damage", 0))
	]
	var guard_absorbed := int(event.get("guard_absorbed", 0))
	if guard_absorbed > 0:
		board_text += "｜开场缓冲吸收 %d" % guard_absorbed
	_set_board_event(
		board_text,
		Color("#72D6A0") if passed else Color("#EF476F")
	)
	for instance_id in _window_instance_ids(window):
		var cell := _origin_cell_by_instance.get(instance_id) as PanelContainer
		if cell == null:
			continue
		var event_badge: Label = cell.get_node("CellOverlay/EventBadge")
		event_badge.text = "需求达标" if passed else "需求缺%d" % gap
		event_badge.visible = true
		_set_badge_palette(
			event_badge,
			Color("#D8FFEA") if passed else Color("#FFE5EB"),
			Color("#17382EF2") if passed else Color("#7A1934F2")
		)
		_restore_instance_style(instance_id, not passed)


func _window_definition(window_id: String) -> Dictionary:
	for value in _encounter.get("windows", []):
		if value is Dictionary and String((value as Dictionary).get("id", "")) == window_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _window_instance_ids(window: Dictionary) -> Array[String]:
	var metric := String(window.get("metric", ""))
	var result: Array[String] = []
	if metric == "active_relation_count":
		for relation_value in _snapshot.get("relations", []):
			if not relation_value is Dictionary:
				continue
			for side in ["left_instance_id", "right_instance_id"]:
				var relation_instance_id := String((relation_value as Dictionary).get(side, ""))
				if not relation_instance_id.is_empty() and not result.has(relation_instance_id):
					result.append(relation_instance_id)
		return result
	var target_tags: Array[String] = []
	var single_tag := String(window.get("tag", ""))
	if not single_tag.is_empty():
		target_tags.append(single_tag)
	var raw_target_tags: Variant = window.get("target_tags", window.get("tags", []))
	if raw_target_tags is Array:
		for tag_value in raw_target_tags:
			var tag := String(tag_value)
			if not tag.is_empty() and not target_tags.has(tag):
				target_tags.append(tag)
	for instance_value in _snapshot.get("instances", []):
		if not instance_value is Dictionary:
			continue
		var instance: Dictionary = instance_value
		if metric in ["tag_sales_count", "tag_satisfaction", "distinct_tag_count"]:
			var matches := false
			for tag in instance.get("tags", []):
				if target_tags.has(String(tag)):
					matches = true
					break
			if not matches:
				continue
		var instance_id := String(instance.get("instance_id", ""))
		if not instance_id.is_empty() and not result.has(instance_id):
			result.append(instance_id)
	return result


func _restore_instance_style(instance_id: String, alert := false) -> void:
	for cell in $BoardPresentation/BoardContent/SnapshotGrid.get_children():
		if String(cell.get_meta("instance_id", "")) != instance_id:
			continue
		cell.add_theme_stylebox_override(
			"panel",
			_cell_style(
				true,
				bool(cell.get_meta("related", false)),
				bool(cell.get_meta("upgraded", false)),
				alert
			)
		)


func _set_board_event(text: String, color: Color) -> void:
	$BoardPresentation/BoardContent/BoardEvent/BoardEventLabel.text = text
	$BoardPresentation/BoardContent/BoardEvent/BoardEventLabel.add_theme_color_override(
		"font_color",
		color
	)


func _sale_event_text(
	event: Dictionary,
	recipe_name: String,
	base_satisfaction: int,
	relation_bonus: int,
	final_satisfaction: int,
	pickiness_reduction: int
) -> String:
	var result := (
		"%04.1fs｜%s 自动售出：%d 基础 + %d 联动 = %d 满足力｜实际挑剔 -%d"
		% [
			float(event.get("at_ms", 0)) / 1000.0,
			recipe_name,
			base_satisfaction,
			relation_bonus,
			final_satisfaction,
			pickiness_reduction
		]
	)
	var overflow := maxi(0, final_satisfaction - pickiness_reduction)
	if overflow > 0:
		result += "（%d 满足力溢出）" % overflow
	return result


func _battle_outcome_text(event: Dictionary) -> String:
	match String(event.get("outcome", "")):
		"victory":
			return "挑战通过：Boss 挑剔值已清空；未到时间的需求不再检查。"
		"loss_reputation":
			return "挑战失败：需求未达标使口碑归零；红色格标标出同一全局需求缺口，数字不要相加。"
		"loss_timeout":
			return "挑战失败：时间到时 Boss 仍有 %d 挑剔值；总满足力不足。" % int(
				event.get("pickiness_after", 0)
			)
	return "战斗结束：%s" % String(event.get("outcome", "未知结果"))


func _instance_tooltip(
	instance: Dictionary,
	relation_pct: int,
	relation_bonus: int,
	source_ids: Array[String]
) -> String:
	var base_satisfaction := int(instance.get("base_satisfaction", 0))
	var lines: Array[String] = [
		_recipe_name(String(instance.get("recipe_id", ""))),
		"自动出售：每 %.1f 秒 1 份，本场初始备货 %d 份" % [
			float(instance.get("cycle_ms", 0)) / 1000.0,
			int(instance.get("virtual_stock", 0))
		],
		"单次效果：%d 基础 + %d 联动 = %d 满足力" % [
			base_satisfaction,
			relation_bonus,
			base_satisfaction + relation_bonus
		]
	]
	if relation_pct > 0:
		lines.append("相邻联动：每次售卖 +%d%% 基础满足力" % relation_pct)
	for source_id in source_ids:
		var definition: Dictionary = _upgrade_definitions.get(source_id, {})
		lines.append("◆ %s：%s" % [
			String(definition.get("display_name", source_id)),
			String(definition.get("description", "本局强化已生效"))
		])
	return "\n".join(lines)


func _merge_source_ids(left_value: Variant, right_value: Variant) -> Array[String]:
	var result: Array[String] = []
	for values in [left_value, right_value]:
		if not values is Array:
			continue
		for value in values:
			var source_id := String(value)
			if not source_id.is_empty() and not result.has(source_id):
				result.append(source_id)
	result.sort()
	return result


func _load_upgrade_definitions() -> Dictionary:
	if not FileAccess.file_exists(UPGRADE_CONFIG_PATH):
		return {}
	var file := FileAccess.open(UPGRADE_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var upgrades: Variant = (parsed as Dictionary).get("upgrades", {})
	return (upgrades as Dictionary).duplicate(true) if upgrades is Dictionary else {}


func _pulse_instance(instance_id: String, color: Color, animate: bool) -> void:
	for cell in $BoardPresentation/BoardContent/SnapshotGrid.get_children():
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


func _recipe_name(recipe_id: String) -> String:
	return String((_catalog_recipes.get(recipe_id, {}) as Dictionary).get("name", recipe_id))


func _toggle_pause() -> void:
	set_paused(not battle_paused)


func _window_text(window: Dictionary) -> String:
	var metric := String(window.get("metric", ""))
	var metric_text := _metric_name(metric)
	var tag_context := _window_tag_context(window)
	if not tag_context.is_empty():
		metric_text = "%s（%s）" % [metric_text, tag_context]
	return "%02ds｜%s ≥ %d" % [
		int(ceil(float(window.get("at_ms", 0)) / 1000.0)),
		metric_text,
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
		"tag_sales_count":
			return "标签出餐"
		"tag_satisfaction":
			return "标签满足力"
		"distinct_tag_count":
			return "售出标签种类"
	return metric


func _rebuild_demand_timeline(windows: Array, duration_seconds: int) -> void:
	var timeline: VBoxContainer = $BossPanel/DemandTimeline
	for child in timeline.get_children():
		timeline.remove_child(child)
		child.queue_free()
	_window_labels_by_id.clear()

	for index in windows.size():
		if not windows[index] is Dictionary:
			continue
		var window: Dictionary = windows[index]
		var label := _new_timeline_label()
		var window_id := String(window.get("id", ""))
		label.name = "DemandWindow%d" % index
		label.text = _window_text(window)
		label.set_meta("display_text", label.text)
		label.set_meta("timeline_kind", "demand_window")
		label.set_meta("window_id", window_id)
		label.set_meta("at_ms", int(window.get("at_ms", 0)))
		label.set_meta("metric", String(window.get("metric", "")))
		timeline.add_child(label)
		if not window_id.is_empty():
			_window_labels_by_id[window_id] = label

	var deadline := _new_timeline_label()
	deadline.name = "FinalDeadline"
	deadline.text = "%02ds｜清空挑剔值，否则挑战超时" % duration_seconds
	deadline.set_meta("timeline_kind", "deadline")
	deadline.set_meta("at_ms", int(_encounter.get("duration_ms", 30000)))
	timeline.add_child(deadline)


func _new_timeline_label() -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color("#655a82"))
	label.add_theme_font_size_override("font_size", 21)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _window_tag_context(window: Dictionary) -> String:
	var tag := String(window.get("tag", ""))
	if not tag.is_empty():
		return _tag_name(tag)
	var tags_value: Variant = window.get("target_tags", window.get("tags", []))
	if not tags_value is Array:
		return ""
	var tags: Array[String] = []
	for value in tags_value:
		var candidate := _tag_name(String(value))
		if not candidate.is_empty() and not tags.has(candidate):
			tags.append(candidate)
	tags.sort()
	return " / ".join(tags)


func _tag_name(tag: String) -> String:
	match tag:
		"fast":
			return "快速"
		"bake":
			return "烘焙"
		"fruit":
			return "水果"
		"drink":
			return "饮品"
		"set":
			return "套装"
		"signature":
			return "招牌"
		"chocolate":
			return "巧克力"
		"cold":
			return "冷饮"
		"milk":
			return "奶香"
		"aromatic":
			return "香气"
		"cake":
			return "蛋糕"
		"soft":
			return "软糯"
		"tea":
			return "茶香"
		"crisp":
			return "香脆"
		"savory":
			return "咸香"
		"hearty":
			return "饱腹"
		"refreshing":
			return "清爽"
		"rich":
			return "浓郁"
		"spatial":
			return "空间"
	return tag
