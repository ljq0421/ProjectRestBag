extends SceneTree

const COMPONENTS := [
	{
		"name": "ShowcaseBoard",
		"scene": "res://scenes/ui/storefront/showcase_board.tscn",
		"signals": [
			"product_list_requested",
			"product_move_requested",
			"product_rotate_requested",
			"listing_status_changed"
		],
		"methods": [
			"refresh",
			"clear_drag_preview",
			"cells_for_slot"
		]
	},
	{
		"name": "OutputPage",
		"scene": "res://scenes/ui/pages/output_page.tscn",
		"signals": [
			"start_output_requested",
			"harvest_requested",
			"harvest_all_requested",
			"accelerator_menu_requested",
			"output_context_action_requested"
		],
		"methods": [
			"refresh",
			"clear_context_menu",
			"selected_site_id"
		]
	},
	{
		"name": "ProductionWorkbench",
		"scene": "res://scenes/ui/pages/production_workbench.tscn",
		"signals": [
			"search_changed",
			"bulk_action_requested",
			"kitchen_schedule_requested",
			"make_requested",
			"process_requested",
			"restock_requested"
		],
		"methods": [
			"refresh_queue",
			"refresh_queue_runtime",
			"refresh_bulk_action_unlocks",
			"row_tutorial_target",
			"tutorial_target"
		]
	},
	{
		"name": "ProductionQueueRecipeRow",
		"scene": "res://scenes/ui/pages/production_queue_recipe_row.tscn",
		"signals": [
			"make_requested",
			"process_requested",
			"restock_requested"
		],
		"methods": [
			"configure",
			"refresh_runtime",
			"tutorial_target"
		]
	},
	{
		"name": "ProductionCompletedStockCell",
		"scene": "res://scenes/ui/pages/production_completed_stock_cell.tscn",
		"signals": [],
		"methods": [
			"configure",
			"recipe_id"
		]
	},
	{
		"name": "KitchenScheduleOverlay",
		"scene": "res://scenes/ui/overlays/kitchen_schedule_overlay.tscn",
		"signals": [],
		"methods": [
			"panel",
			"refresh"
		]
	},
	{
		"name": "PurchasePage",
		"scene": "res://scenes/ui/pages/purchase_page.tscn",
		"signals": [
			"purchase_requested"
		],
		"methods": [
			"refresh",
			"selected_metadata"
		]
	},
	{
		"name": "StorefrontManagePage",
		"scene": "res://scenes/ui/pages/storefront_manage_page.tscn",
		"signals": [
			"settle_showcase_requested",
			"expand_showcase_requested"
		],
		"methods": [
			"refresh"
		]
	},
	{
		"name": "TaskOverlay",
		"scene": "res://scenes/ui/overlays/task_overlay.tscn",
		"signals": [
			"close_requested"
		],
		"methods": [
			"refresh",
			"show_mode",
			"hide_mode"
		]
	},
	{
		"name": "InventoryOverlay",
		"scene": "res://scenes/ui/overlays/inventory_overlay.tscn",
		"signals": [
			"close_requested",
			"inventory_restock_requested",
			"inventory_batch_list_requested",
			"inventory_item_selected"
		],
		"methods": [
			"refresh",
			"show_mode",
			"hide_mode"
		]
	},
	{
		"name": "CatalogOverlay",
		"scene": "res://scenes/ui/overlays/catalog_overlay.tscn",
		"signals": [
			"close_requested",
			"catalog_make_requested",
			"catalog_reward_claim_requested",
			"catalog_reward_claim_all_requested",
			"catalog_milestone_claim_requested"
		],
		"methods": [
			"refresh",
			"show_mode",
			"hide_mode"
		]
	},
	{
		"name": "AutomationOverlay",
		"scene": "res://scenes/ui/overlays/automation_overlay.tscn",
		"signals": [
			"close_requested",
			"upgrade_requested",
			"pause_all_requested"
		],
		"methods": [
			"refresh",
			"show_mode",
			"hide_mode"
		]
	},
	{
		"name": "KitchenAutomationPanel",
		"scene": "res://scenes/ui/pages/kitchen_automation_panel.tscn",
		"signals": [
			"rule_save_requested",
			"rule_remove_requested",
			"pause_toggled"
		],
		"methods": [
			"refresh",
			"focus_rule"
		]
	},
	{
		"name": "AutomationReportDialog",
		"scene": "res://scenes/ui/overlays/automation_report_dialog.tscn",
		"signals": [
			"navigate_requested"
		],
		"methods": [
			"configure"
		]
	},
	{
		"name": "DeviceGrowthCenterPage",
		"scene": "res://scenes/ui/pages/device_growth_center_page.tscn",
		"signals": [
			"upgrade_requested",
			"catalog_filter_requested"
		],
		"methods": [
			"refresh",
			"upgrade_ready_count",
			"selected_device_id"
		]
	},
	{
		"name": "RecipeGrowthDetailPanel",
		"scene": "res://scenes/ui/overlays/recipe_growth_detail_panel.tscn",
		"signals": [
			"trait_choice_requested"
		],
		"methods": [
			"refresh"
		]
	}
]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for component in COMPONENTS:
		_check_component(component)
	_check_scene_mounts()
	await process_frame
	_finish()


func _check_scene_mounts() -> void:
	var workbench_scene := load("res://scenes/ui/pages/workbench_pages.tscn") as PackedScene
	if workbench_scene == null:
		_fail("Workbench pages scene could not be loaded")
	else:
		var workbench := workbench_scene.instantiate()
		root.add_child(workbench)
		if workbench.get_node_or_null("PrimaryList/ResearchHintPanel") != null:
			_fail("Workbench pages should not retain the migrated ResearchHintPanel")
		if workbench.get_node_or_null("PrimaryList/DeviceGrowthBar") != null:
			_fail("Workbench PrimaryList should not retain the migrated DeviceGrowthBar")
		if workbench.get_node_or_null("SecondaryList/KitchenAutomationPanel") == null:
			_fail("Workbench SecondaryList should mount KitchenAutomationPanel before RecipeScroll")
		else:
			var panel_index := workbench.get_node("SecondaryList/KitchenAutomationPanel").get_index()
			var recipe_index := workbench.get_node("SecondaryList/RecipeScroll").get_index()
			if panel_index >= recipe_index:
				_fail("KitchenAutomationPanel should appear before RecipeScroll")
		workbench.queue_free()
	var research_dialog_scene := load("res://scenes/ui/overlays/research_progress_dialog.tscn") as PackedScene
	if research_dialog_scene == null:
		_fail("Research progress dialog scene could not be loaded")
	else:
		var research_dialog := research_dialog_scene.instantiate()
		root.add_child(research_dialog)
		var default_result_center = research_dialog.get_node_or_null("DialogMargin/DialogContent/StateContent/DefaultResultCenter")
		var dialog_failure_content = research_dialog.get_node_or_null("DialogMargin/DialogContent/StateContent/ResearchFailureContent")
		var dialog_failure_message = research_dialog.get_node_or_null("DialogMargin/DialogContent/StateContent/ResearchFailureContent/FailureMessageLabel")
		var dialog_hint_title = research_dialog.get_node_or_null("DialogMargin/DialogContent/StateContent/ResearchFailureContent/ResearchHintTitle")
		var dialog_hint_body = research_dialog.get_node_or_null("DialogMargin/DialogContent/StateContent/ResearchFailureContent/ResearchHintBody")
		if not default_result_center is CenterContainer:
			_fail("Research progress dialog should preserve a dedicated centered default result layout")
		if not dialog_failure_content is VBoxContainer:
			_fail("Research progress dialog should declare a frameless dedicated failure layout")
		if not dialog_failure_message is RichTextLabel:
			_fail("ResearchFailureContent should declare FailureMessageLabel")
		if not dialog_hint_title is Label:
			_fail("ResearchFailureContent should declare ResearchHintTitle")
		if not dialog_hint_body is RichTextLabel:
			_fail("ResearchFailureContent should declare ResearchHintBody")
		research_dialog.queue_free()
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene could not be loaded")
	else:
		var main := main_scene.instantiate()
		root.add_child(main)
		if main.get_node_or_null("AutomationReportDialog") == null:
			_fail("Main should mount AutomationReportDialog")
		if main.get_node_or_null("ShowcaseFeedbackLayer") == null:
			_fail("Main should mount ShowcaseFeedbackLayer outside MainArea")
		if main.get_node_or_null("Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcasePulseSummary") == null:
			_fail("ShowcaseBoard should mount ShowcasePulseSummary")
		var search_field = main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/ProductionQueueHeader/SearchField")
		var bulk_button = main.get_node_or_null("Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench/ProductionQueueHeader/BulkActionButton")
		if not search_field is LineEdit or not bulk_button is MenuButton:
			_fail("Main should declare production search and bulk actions in the workbench header")
		if main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ProductionRecipePickerOverlay") != null:
			_fail("Main should not mount the removed ProductionRecipePickerOverlay")
		if main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/KitchenScheduleOverlay/KitchenAutomationPanel") == null:
			_fail("Main should mount KitchenAutomationPanel inside KitchenScheduleOverlay")
		if not ResourceLoader.exists("res://scripts/ui/storefront/showcase_feedback_director.gd"):
			_fail("ShowcaseFeedbackDirector script is missing")
		if main.get_node_or_null("DeviceGrowthDrawer") != null:
			_fail("Main should not retain the migrated DeviceGrowthDrawer")
		if main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/DeviceGrowthPage") == null:
			_fail("Management center should mount DeviceGrowthCenterPage")
		if main.get_node_or_null("RecipeGrowthChoiceDialog") == null:
			_fail("Main should mount the existing RecipeGrowthChoiceDialog")
		if main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogDeviceFilterRow/CatalogDeviceFilter") == null:
			_fail("CatalogOverlay should expose a visible device filter")
		if main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogContent/CatalogDetailPanel") != null:
			_fail("CatalogOverlay should not retain the crowded CatalogDetailPanel")
		var catalog_action_popup = main.get_node_or_null("GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogCardActionPopup")
		if catalog_action_popup == null:
			_fail("CatalogOverlay should mount CatalogCardActionPopup")
		else:
			_check_required_nodes(catalog_action_popup, [
				"PopupMargin/PopupContent/DetailScroll/DetailText",
				"PopupMargin/PopupContent/ActionRow/ClaimRewardButton",
				"PopupMargin/PopupContent/ActionRow/MakeButton"
			], "CatalogCardActionPopup")
		main.queue_free()


func _check_component(component: Dictionary) -> void:
	var scene_path := String(component.get("scene", ""))
	if not ResourceLoader.exists(scene_path):
		_fail("%s scene is missing: %s" % [component.get("name", ""), scene_path])
		return

	var packed_scene := load(scene_path)
	if packed_scene == null:
		_fail("%s scene could not be loaded" % component.get("name", ""))
		return

	var instance := (packed_scene as PackedScene).instantiate()
	root.add_child(instance)
	for signal_name in component.get("signals", []):
		if not instance.has_signal(String(signal_name)):
			_fail("%s missing signal: %s" % [component.get("name", ""), signal_name])
	for method_name in component.get("methods", []):
		if not instance.has_method(String(method_name)):
			_fail("%s missing method: %s" % [component.get("name", ""), method_name])
	if String(component.get("name", "")) == "CatalogOverlay":
		_check_catalog_reward_states(instance)
	elif String(component.get("name", "")) == "AutomationOverlay":
		_check_automation_upgrade_metadata(instance)
	elif String(component.get("name", "")) == "KitchenAutomationPanel":
		_check_required_nodes(instance, [
			"Header/TitleLabel",
			"Header/PauseToggle",
			"LockedMessage",
			"RuleList",
			"Editor/RecipeOption",
			"Editor/BatchOption",
			"Editor/TargetStockSpin",
			"Editor/PriorityOption",
			"Editor/MaterialReserveList",
			"Editor/SaveRuleButton",
			"Editor/RemoveRuleButton"
		], "KitchenAutomationPanel")
	elif String(component.get("name", "")) == "AutomationReportDialog":
		if not instance is AcceptDialog:
			_fail("AutomationReportDialog should inherit AcceptDialog")
		if int((instance as AcceptDialog).size.y) > 600 or int((instance as AcceptDialog).min_size.y) > 500:
			_fail("AutomationReportDialog should fit within the standard page height without expanding past its dialog frame")
		var report_body := instance.get_node("ReportBody") as ScrollContainer
		if report_body == null:
			_fail("AutomationReportDialog report body should scroll instead of expanding its dialog frame")
		elif int(report_body.custom_minimum_size.y) > 480 or int(report_body.get_combined_minimum_size().y) > 480:
			_fail("AutomationReportDialog report body should fit its allocated content height")
		_check_required_nodes(instance, [
			"ReportBody/Content/SummaryLabel",
			"ReportBody/Content/OutputList",
			"ReportBody/Content/ProductList",
			"ReportBody/Content/GrowthList",
			"ReportBody/Content/PauseList",
			"ReportBody/Content/NavigateButton"
		], "AutomationReportDialog")
		instance.call("configure", {
			"from_unix": 1200,
			"to_unix": 1100,
			"pauses": [{"reason": {"code": "clock_rollback"}}]
		})
		var pause_list := instance.get_node("ReportBody/Content/PauseList") as ItemList
		var clock_metadata: Dictionary = pause_list.get_item_metadata(0) if pause_list.item_count > 0 and pause_list.get_item_metadata(0) is Dictionary else {}
		if String(clock_metadata.get("kind", "")) != "system" or String(clock_metadata.get("key", "")) != "clock_rollback":
			_fail("clock rollback report item should navigate as system, not an empty kitchen rule")
		instance.call("configure", {
			"from_unix": 1000,
			"to_unix": 1030,
			"kitchen_cycle_count": 1,
			"growth": {
				"milk_pudding": {
					"made_count": 3,
					"before_mastery": 0,
					"after_mastery": 1,
					"before_stage": "试作品",
					"after_stage": "人气款"
				}
			}
		})
		var growth_list := instance.get_node("ReportBody/Content/GrowthList") as ItemList
		var growth_text := growth_list.get_item_text(0) if growth_list.item_count > 0 else ""
		if growth_text.find("牛奶布丁") == -1 or growth_text.find("试作品 → 人气款") == -1 or growth_text.find("3") == -1:
			_fail("automation report should show the concrete recipe mastery transition and made amount")
	elif String(component.get("name", "")) == "DeviceGrowthCenterPage":
		_check_required_nodes(instance, [
			"DeviceSelectorPanel/DeviceButtons/round_pot",
			"DeviceSelectorPanel/DeviceButtons/oven",
			"DeviceSelectorPanel/DeviceButtons/chiller",
			"DeviceSelectorPanel/DeviceButtons/griddle",
			"DeviceSelectorPanel/DeviceButtons/mixer",
			"DeviceDetailColumns/DetailPanel/DetailContent/Header/CatalogButton",
			"DeviceDetailColumns/UpgradePanel/UpgradeContent/UpgradeButton"
		], "DeviceGrowthCenterPage")
	elif String(component.get("name", "")) == "RecipeGrowthDetailPanel":
		_check_required_nodes(instance, [
			"StageLabel",
			"NextStageLabel",
			"StageMadeRow",
			"StageEffectiveRoundRow",
			"StageSynergyRoundRow",
			"StageDeviceRow",
			"AllConditionsHintLabel",
			"CountLabel",
			"DeviceStatusLabel",
			"MasterworkLabel",
			"MasterworkProgress",
			"TraitLabel",
			"ChooseTraitButton"
		], "RecipeGrowthDetailPanel")
	instance.queue_free()


func _check_required_nodes(instance: Node, paths: Array, component_name: String) -> void:
	for path_value: Variant in paths:
		var node_path := String(path_value)
		if instance.get_node_or_null(node_path) == null:
			_fail("%s missing required node: %s" % [component_name, node_path])


func _check_catalog_reward_states(instance: Node) -> void:
	instance.call("refresh_milestones", 38, 149, [])
	var quarter_button := instance.get_node_or_null("CatalogMilestoneTrack/CatalogMilestone25Button") as Button
	var half_button := instance.get_node_or_null("CatalogMilestoneTrack/CatalogMilestone50Button") as Button
	if quarter_button == null or quarter_button.disabled or quarter_button.text.find("可领取") == -1:
		_fail("CatalogOverlay 25% milestone should become claimable at 38/149")
	if half_button == null or not half_button.disabled or half_button.text.find("进度") == -1:
		_fail("CatalogOverlay 50% milestone should remain disabled before its target")
	instance.call("refresh_milestones", 38, 149, ["catalog_milestone:25"])
	if quarter_button == null or not quarter_button.disabled or quarter_button.text.find("已领取") == -1:
		_fail("CatalogOverlay claimed milestone should stay disabled and marked claimed")


func _check_automation_upgrade_metadata(instance: Node) -> void:
	var button := instance.get_node_or_null("OutputSection/OutputUpgradeGrid/OutputCapacity1Button") as Button
	if button == null or String(button.get_meta("upgrade_id", "")) != "output_capacity_1":
		_fail("AutomationOverlay upgrade buttons should expose configured upgrade_id metadata")


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("COMPONENT_CONTRACT_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("COMPONENT_CONTRACT_SELF_CHECK_FAIL: %s" % failure)
		quit(1)
