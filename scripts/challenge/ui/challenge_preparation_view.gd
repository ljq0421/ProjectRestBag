class_name ChallengePreparationView
extends VBoxContainer

signal battle_requested(draft: Dictionary)
signal draft_changed(draft: Dictionary)
signal placement_rejected(reasons: Array[String])
signal expansion_purchase_requested(product_id: String, rotation: int, anchor: Vector2i)

const SupplyCardScene = preload("res://scenes/challenge/challenge_supply_card.tscn")
const UiStyle = preload("res://scripts/challenge/ui/challenge_ui_style.gd")
const ROLE_ORDER := ["tempo", "pairing", "signature", "softness", "flavor", "shape", "sustain", "space", "other"]
const ROLE_NAMES := {
	"tempo": "快速周转",
	"pairing": "搭配联动",
	"signature": "招牌输出",
	"softness": "柔软质感",
	"flavor": "风味覆盖",
	"shape": "形状构筑",
	"sustain": "持续供给",
	"space": "空间组合",
	"other": "其他"
}

var _catalog_recipes: Dictionary = {}
var _effective_recipe_defs: Dictionary = {}
var _pool_recipe_ids: Array[String] = []
var _expansion_open := false


func _ready() -> void:
	UiStyle.apply_primary($MainColumns/RightSidebar/BattleButton)
	UiStyle.apply_secondary($MainColumns/RightSidebar/ExpansionButton)
	$MainColumns/ChallengeBoard.draft_changed.connect(_on_draft_changed)
	$MainColumns/ChallengeBoard.placement_rejected.connect(
		func(reasons: Array[String]) -> void: placement_rejected.emit(reasons)
	)
	$MainColumns/RightSidebar/BattleButton.pressed.connect(
		func() -> void: battle_requested.emit($MainColumns/ChallengeBoard.get_draft())
	)
	$MainColumns/RightSidebar/ExpansionButton.pressed.connect(_open_expansion)
	$MainColumns/RightSidebar/ExpansionPanel.product_selected.connect(
		_on_expansion_product_selected
	)
	$MainColumns/RightSidebar/ExpansionPanel.rotate_requested.connect(
		_on_expansion_rotate_requested
	)
	$MainColumns/RightSidebar/ExpansionPanel.close_requested.connect(_close_expansion)
	$MainColumns/ChallengeBoard.expansion_placement_requested.connect(
		func(product_id: String, rotation: int, anchor: Vector2i) -> void:
			expansion_purchase_requested.emit(product_id, rotation, anchor)
	)


func bind(
	run: Dictionary,
	encounter: Dictionary,
	effective_context: Dictionary,
	loadout_service: RefCounted,
	catalog_recipes: Dictionary,
	meta: Dictionary = {},
	expansion_products: Array = []
) -> void:
	_catalog_recipes = catalog_recipes.duplicate(true)
	_effective_recipe_defs = (
		effective_context.get("recipe_defs", {}) as Dictionary
	).duplicate(true)
	var pool: Dictionary = run.get("permanent_pool_snapshot", {})
	_pool_recipe_ids = _sorted_recipe_ids(pool.get("recipe_ids", []))
	$MainColumns/ChallengeBoard.bind_effective_context(
		effective_context,
		loadout_service,
		encounter
	)
	_bind_stage_rail(run)
	_bind_boss(encounter)
	_rebuild_supply_cards()
	$MainColumns/RightSidebar/ExpansionPanel.bind(
		expansion_products,
		int(meta.get("expansion_tickets", 0))
	)
	$MainColumns/RightSidebar/ExpansionButton.text = "扩建展示柜 · 扩建券 %d" % int(
		meta.get("expansion_tickets", 0)
	)
	_close_expansion()
	set_draft(run.get("loadout_draft", {"placements": []}))


func board() -> Control:
	return $MainColumns/ChallengeBoard


func get_draft() -> Dictionary:
	return $MainColumns/ChallengeBoard.get_draft()


func set_draft(draft: Dictionary) -> void:
	$MainColumns/ChallengeBoard.set_draft(draft)


func set_locked(locked: bool) -> void:
	$MainColumns/ChallengeBoard.set_locked(locked)
	$MainColumns/RightSidebar/BattleButton.disabled = (
		locked or not $MainColumns/ChallengeBoard.is_current_draft_valid()
	)


func _open_expansion() -> void:
	_expansion_open = true
	_set_normal_sidebar_visible(false)
	$MainColumns/RightSidebar/ExpansionPanel.show()
	var product_id := String(
		$MainColumns/RightSidebar/ExpansionPanel.selected_product_id()
	)
	if not product_id.is_empty():
		$MainColumns/ChallengeBoard.begin_expansion_preview(
			product_id,
			int($MainColumns/RightSidebar/ExpansionPanel.rotation())
		)


func _close_expansion() -> void:
	_expansion_open = false
	$MainColumns/RightSidebar/ExpansionPanel.hide()
	_set_normal_sidebar_visible(true)
	$MainColumns/ChallengeBoard.cancel_expansion_preview()


func _on_expansion_product_selected(product_id: String) -> void:
	if not _expansion_open:
		return
	$MainColumns/ChallengeBoard.begin_expansion_preview(product_id, 0)


func _on_expansion_rotate_requested() -> void:
	if not _expansion_open:
		return
	$MainColumns/ChallengeBoard.set_expansion_rotation(
		int($MainColumns/RightSidebar/ExpansionPanel.rotation())
	)


func _set_normal_sidebar_visible(value: bool) -> void:
	$MainColumns/RecipeLibrary.visible = value
	$MainColumns/RightSidebar/BossBrief.visible = value
	$MainColumns/RightSidebar/ExpansionButton.visible = value
	$MainColumns/RightSidebar/BattleButton.visible = value


func _bind_stage_rail(run: Dictionary) -> void:
	var stage_index := int(run.get("stage_index", 0))
	if String(run.get("mode", "")) == "endless":
		var floor_number := stage_index + 1
		var next_elite := int(ceil(float(floor_number) / 5.0)) * 5
		var next_boss := int(ceil(float(floor_number) / 10.0)) * 10
		$StageRail.text = "无尽爬升  ◆ 当前 %d 层  ─  精英 %d 层  ─  Boss %d 层" % [
			floor_number,
			next_elite,
			next_boss
		]
		$StageMeta.text = "已通关 %d 层 · 信心 %d / 2 · 本局强化 %d" % [
			int(run.get("highest_cleared_floor", 0)),
			int(run.get("confidence", 0)),
			_count_upgrade_stacks(run.get("run_upgrades", []))
		]
		return
	var labels: Array[String] = []
	for index in range(5):
		var marker := "●" if index < stage_index else ("◆" if index == stage_index else "○")
		labels.append("%s %d" % [marker, index + 1])
	$StageRail.text = "订单票据  " + "  ─  ".join(labels)
	$StageMeta.text = "第 %d / 5 场 · 信心 %d / 2 · 本局强化 %d" % [
		stage_index + 1,
		int(run.get("confidence", 0)),
		_count_upgrade_stacks(run.get("run_upgrades", []))
	]


func _bind_boss(encounter: Dictionary) -> void:
	$MainColumns/RightSidebar/BossBrief/Content/BossName.text = String(
		encounter.get("display_name", encounter.get("encounter_id", "客潮"))
	)
	$MainColumns/RightSidebar/BossBrief/Content/BossStats.text = "挑剔 %d · 口碑 %d · 自动战斗 %d 秒" % [
		int(encounter.get("initial_pickiness", 0)),
		int(encounter.get("initial_reputation", 0)),
		int(encounter.get("duration_ms", 0)) / 1000
	]
	var lines: Array[String] = []
	for value in encounter.get("windows", []):
		if value is Dictionary:
			var metric_text := _metric_name(String(value.get("metric", "")))
			var tag_context := _window_tag_context(value)
			if not tag_context.is_empty():
				metric_text = "%s（%s）" % [metric_text, tag_context]
			lines.append("%02d 秒  %s ≥ %d  ·  失败口碑 -%d" % [
				int(value.get("at_ms", 0)) / 1000,
				metric_text,
				int(value.get("target", 0)),
				int(value.get("reputation_damage", 0))
			])
	lines.append("%02d 秒  清空挑剔值" % (int(encounter.get("duration_ms", 0)) / 1000))
	$MainColumns/RightSidebar/BossBrief/Content/TimelineBlock/Timeline.text = "\n".join(lines)
	var relation: Dictionary = encounter.get("relation", {})
	var left_tag := _tag_name(String(relation.get("left_tag", "")))
	var right_tag := _tag_name(String(relation.get("right_tag", "")))
	var bonus_pct := int(encounter.get("relation_bonus_pct", 0))
	$MainColumns/RightSidebar/BossBrief/Content/BuildGuide/RelationRule.text = (
		"本场联动：%s × %s，上下左右贴边后，两边每次售卖 +%d%% 满足力" % [
			left_tag,
			right_tag,
			bonus_pct
		]
		if not left_tag.is_empty() and not right_tag.is_empty()
		else "本场没有相邻联动，优先按需求选择周期、满足力和标签。"
	)


func _rebuild_supply_cards() -> void:
	var supply_grid: GridContainer = (
		$MainColumns/RecipeLibrary/Content/SupplyScroll/SupplyGrid
	)
	for child in supply_grid.get_children():
		child.queue_free()
	$MainColumns/RecipeLibrary/Content/Header/CountLabel.text = (
		"%d 个" % _pool_recipe_ids.size()
	)
	for recipe_id in _pool_recipe_ids:
		var card = SupplyCardScene.instantiate()
		card.set_meta("recipe_id", recipe_id)
		supply_grid.add_child(card)
		var catalog_entry: Dictionary = _catalog_recipes.get(recipe_id, {})
		card.bind(
			recipe_id,
			_effective_recipe_defs.get(recipe_id, {}),
			String(catalog_entry.get("name", recipe_id))
		)
	_update_counts(get_draft())


func _on_draft_changed(draft: Dictionary) -> void:
	_update_counts(draft)
	_refresh_build_guide()
	$MainColumns/RightSidebar/BattleButton.disabled = (
		(draft.get("placements", []) as Array).is_empty()
		or not $MainColumns/ChallengeBoard.is_current_draft_valid()
	)
	$MainColumns/RightSidebar/BattleButton.text = (
		"重新摆放后开始自动战斗"
		if $MainColumns/ChallengeBoard.needs_rearrange()
		else "锁定橱窗，开始自动战斗"
	)
	draft_changed.emit(draft.duplicate(true))


func _refresh_build_guide() -> void:
	var summary: Dictionary = $MainColumns/ChallengeBoard.get_build_summary()
	var instance_count := int(summary.get("instance_count", 0))
	if instance_count <= 0:
		$MainColumns/RightSidebar/BossBrief/Content/BuildGuide/LiveBuild.text = (
			"当前构筑：尚未摆放配方。先从卡面比较“秒/次、满足、标签”。"
		)
		return
	var cycle_min_ms := int(summary.get("cycle_min_ms", 0))
	var cycle_max_ms := int(summary.get("cycle_max_ms", 0))
	var relation_count := int(summary.get("relation_count", 0))
	var boosted_count := int(summary.get("boosted_instance_count", 0))
	var relation_bonus_pct := int(summary.get("relation_bonus_pct", 0))
	var cycle_text := (
		"%s 秒" % _seconds_text(cycle_min_ms)
		if cycle_min_ms == cycle_max_ms
		else "%s～%s 秒" % [
			_seconds_text(cycle_min_ms),
			_seconds_text(cycle_max_ms)
		]
	)
	$MainColumns/RightSidebar/BossBrief/Content/BuildGuide/LiveBuild.text = (
		"当前构筑：%d 份 · 售卖周期 %s · 联动 %d 组（%d 份获得 +%d%%）" % [
			instance_count,
			cycle_text,
			relation_count,
			boosted_count,
			relation_bonus_pct if relation_count > 0 else 0
		]
	)


func _seconds_text(milliseconds: int) -> String:
	var seconds := float(milliseconds) / 1000.0
	return (
		"%d" % int(seconds)
		if is_equal_approx(seconds, float(int(seconds)))
		else "%.1f" % seconds
	)


func _update_counts(draft: Dictionary) -> void:
	var counts := {}
	for placement in draft.get("placements", []):
		var recipe_id := String(placement.get("recipe_id", ""))
		counts[recipe_id] = int(counts.get(recipe_id, 0)) + 1
	for card in supply_cards():
		var recipe_id := String(card.get_meta("recipe_id", ""))
		card.set_selected_count(int(counts.get(recipe_id, 0)))


func supply_cards() -> Array[Control]:
	var result: Array[Control] = []
	_collect_supply_cards(
		$MainColumns/RecipeLibrary/Content/SupplyScroll/SupplyGrid,
		result
	)
	return result


func _collect_supply_cards(node: Node, result: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control and not String(child.get_meta("recipe_id", "")).is_empty():
			result.append(child)
		_collect_supply_cards(child, result)


func _count_upgrade_stacks(upgrades: Array) -> int:
	var count := 0
	for value in upgrades:
		count += maxi(1, int(value.get("stack_count", 1))) if value is Dictionary else 1
	return count


func _sorted_recipe_ids(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			var text := String(value)
			if not text.is_empty() and not result.has(text):
				result.append(text)
	result.sort_custom(
		func(a: String, b: String) -> bool:
			var a_role := _primary_role(_effective_recipe_defs.get(a, {}))
			var b_role := _primary_role(_effective_recipe_defs.get(b, {}))
			var a_index := ROLE_ORDER.find(a_role)
			var b_index := ROLE_ORDER.find(b_role)
			if a_index == b_index:
				return a < b
			return a_index < b_index
	)
	return result


func _primary_role(recipe_def: Dictionary) -> String:
	var roles: Array = recipe_def.get("build_roles", [])
	return String(roles[0]) if not roles.is_empty() else "other"


func _metric_name(metric: String) -> String:
	match metric:
		"sales_count":
			return "累计售卖"
		"active_relation_count":
			return "相邻联动"
		"window_satisfaction":
			return "区间满足力"
		"tag_sales_count":
			return "标签售卖"
		"tag_satisfaction":
			return "标签满足力"
		"distinct_tag_count":
			return "标签覆盖"
	return metric


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
