extends VBoxContainer

signal close_requested()
signal catalog_make_requested(recipe_id: String)
signal catalog_reward_claim_requested(recipe_id: String)
signal catalog_reward_claim_all_requested()
signal catalog_milestone_claim_requested(percent: int)

var _selected_recipe_id := ""

@onready var action_popup: PopupPanel = $CatalogCardActionPopup


func _ready() -> void:
	action_popup.connect("make_requested", Callable(self, "_on_make_pressed"))
	action_popup.connect("reward_claim_requested", Callable(self, "_on_reward_claim_pressed"))
	var claim_all_button := get_node_or_null("CatalogRewardActions/CatalogClaimAllRewardsButton") as Button
	if claim_all_button == null:
		claim_all_button = get_node_or_null("CatalogSummaryRow/CatalogClaimAllRewardsButton") as Button
	if claim_all_button != null:
		claim_all_button.pressed.connect(_on_reward_claim_all_pressed)
	for percent in [25, 50, 75, 100]:
		var milestone_button := get_node_or_null("CatalogMilestoneTrack/CatalogMilestone%dButton" % percent) as Button
		if milestone_button != null:
			milestone_button.pressed.connect(_on_milestone_pressed.bind(percent))


func _on_make_pressed(recipe_id: String = "") -> void:
	_selected_recipe_id = recipe_id if not recipe_id.is_empty() else _selected_recipe_id
	catalog_make_requested.emit(_selected_recipe_id)


func _on_reward_claim_pressed(recipe_id: String = "") -> void:
	_selected_recipe_id = recipe_id if not recipe_id.is_empty() else _selected_recipe_id
	catalog_reward_claim_requested.emit(_selected_recipe_id)


func _on_reward_claim_all_pressed() -> void:
	catalog_reward_claim_all_requested.emit()


func _on_milestone_pressed(percent: int) -> void:
	catalog_milestone_claim_requested.emit(percent)


func refresh(_state, _catalog) -> void:
	pass


func show_mode(_mode: String) -> void:
	visible = true


func hide_mode() -> void:
	close_action_popup()
	visible = false


func open_action_popup(recipe_id: String, content: String, claimable_amount: int, anchor_rect: Rect2) -> void:
	_selected_recipe_id = recipe_id
	action_popup.call("show_recipe", recipe_id, content, claimable_amount, anchor_rect)


func refresh_action_popup(recipe_id: String, content: String, claimable_amount: int) -> void:
	action_popup.call("refresh_recipe", recipe_id, content, claimable_amount)


func close_action_popup() -> void:
	if is_instance_valid(action_popup):
		action_popup.call("close_menu")


func is_action_popup_open() -> bool:
	return is_instance_valid(action_popup) and action_popup.visible


func refresh_milestones(unlocked: int, total: int, claimed_rewards: Array = []) -> void:
	for percent in [25, 50, 75, 100]:
		var target := int(ceil(float(total) * float(percent) / 100.0))
		var button := get_node_or_null("CatalogMilestoneTrack/CatalogMilestone%dButton" % percent) as Button
		if button == null:
			continue
		var reward_key := "catalog_milestone:%d" % percent
		if claimed_rewards.has(reward_key):
			button.text = "%d%%\n已领取" % percent
			button.disabled = true
			button.tooltip_text = "该图鉴里程碑星辉已领取。"
		elif unlocked >= target:
			button.text = "%d%%\n可领取" % percent
			button.disabled = false
			button.tooltip_text = "领取 %d%% 图鉴里程碑星辉。" % percent
		else:
			button.text = "%d%%\n进度 %d/%d" % [percent, unlocked, target]
			button.disabled = true
			button.tooltip_text = "还需解锁 %d 个配方。" % maxi(0, target - unlocked)


func refresh_claim_actions(claimable_count: int) -> void:
	var button := get_node_or_null("CatalogRewardActions/CatalogClaimAllRewardsButton") as Button
	if button == null:
		return
	button.disabled = claimable_count <= 0
	button.text = "一键领取星辉（%d 项）" % claimable_count if claimable_count > 0 else "暂无可领取星辉"
	button.tooltip_text = "领取所有已达成的配方、阶段与图鉴星辉。" if claimable_count > 0 else "继续解锁配方或提升熟练度可获得星辉。"


func refresh_panel(view, preserve_action_popup: bool = false) -> void:
	if not preserve_action_popup:
		close_action_popup()
	_selected_recipe_id = String(view.selected_catalog_recipe_id)
	view.call("_fill_catalog_filter_tabs")
	view.call("_clear_children", view.catalog_grid)
	view.call("_refresh_catalog_summary")
	view.catalog_grid.columns = view.CATALOG_GRID_COLUMNS
	var recipes: Dictionary = view.catalog.get_recipes()
	var recipe_ids: Array = view.call("_catalog_recipe_ids")
	var page_count := int(view.call("_catalog_page_count", recipe_ids))
	view.selected_catalog_page = clampi(view.selected_catalog_page, 0, page_count - 1)
	var start_index: int = view.selected_catalog_page * view.CATALOG_CELLS_PER_PAGE
	for cell_index in range(view.CATALOG_CELLS_PER_PAGE):
		var entry_index := start_index + cell_index
		if entry_index >= recipe_ids.size():
			view.catalog_grid.add_child(view.call("_make_catalog_cell", "", {}))
			continue
		var recipe_id := String(recipe_ids[entry_index])
		var recipe: Dictionary = recipes[recipe_id]
		view.catalog_grid.add_child(view.call("_make_catalog_cell", recipe_id, recipe))
	view.catalog_page_label.text = "%d/%d" % [view.selected_catalog_page + 1, page_count]
	view.catalog_prev_button.disabled = view.selected_catalog_page <= 0
	view.catalog_next_button.disabled = view.selected_catalog_page >= page_count - 1
