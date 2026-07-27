extends Control

const Catalog = preload("res://scripts/catalog.gd")
const AutomationService = preload("res://scripts/automation_service.gd")
const BusinessRoundService = preload("res://scripts/business_round_service.gd")
const ShowcaseHotspotService = preload("res://scripts/showcase_hotspot_service.gd")
const GameState = preload("res://scripts/game_state.gd")
const ProductionSite = preload("res://scripts/production_site.gd")
const RecipeBook = preload("res://scripts/recipe_book.gd")
const RecipeGrowthService = preload("res://scripts/recipe_growth_service.gd")
const RecipeIconService = preload("res://scripts/recipe_icon_service.gd")
const RoundEnvironmentService = preload("res://scripts/round_environment_service.gd")
const BasicButtonScene = preload("res://scenes/ui/common/basic_button.tscn")
const BasicLabelScene = preload("res://scenes/ui/common/basic_label.tscn")
const ResearchInputSlotScene = preload("res://scenes/ui/pages/research_input_slot.tscn")
const InventoryProductCellScene = preload("res://scenes/ui/overlays/inventory_product_cell.tscn")
const OutputCellScene = preload("res://scenes/ui/pages/output_cell.tscn")
const ProductionWorkbenchComponent = preload("res://scripts/ui/pages/production_workbench.gd")
const KitchenScheduleOverlayComponent = preload("res://scripts/ui/overlays/kitchen_schedule_overlay.gd")
const SaveSystem = preload("res://scripts/save_system.gd")
const StarProgressionService = preload("res://scripts/star_progression_service.gd")
const ShowcaseFeedbackDirector = preload("res://scripts/ui/storefront/showcase_feedback_director.gd")
const ShowcaseSaleFeedbackScene = preload("res://scenes/ui/storefront/showcase_sale_feedback.tscn")
const ShowcaseFreshnessService = preload("res://scripts/showcase_freshness_service.gd")
const ShowcaseChainService = preload("res://scripts/showcase_chain_service.gd")
const ShowcaseChallengeService = preload("res://scripts/showcase_challenge_service.gd")
const ShowcaseRoleService = preload("res://scripts/showcase_role_service.gd")
const ShowcaseRoundReportService = preload("res://scripts/showcase_round_report_service.gd")
const ShowcaseRoundSaleService = preload("res://scripts/showcase_round_sale_service.gd")
const ShowcaseRuleService = preload("res://scripts/showcase_rule_service.gd")
const ShowcaseRegionService = preload("res://scripts/showcase_region_service.gd")
const ShowcaseExpansionService = preload("res://scripts/showcase_expansion_service.gd")
const TaskService = preload("res://scripts/task_service.gd")
const TutorialProgress = preload("res://scripts/tutorial_progress.gd")
const TutorialDialogueCatalog = preload("res://scripts/tutorial_dialogue_catalog.gd")
const ProgressionAccessService = preload("res://scripts/progression_access_service.gd")
const CoreFeatureUnlockService = preload("res://scripts/core_feature_unlock_service.gd")
const DevRecipeUnlockImporter = preload("res://scripts/dev_recipe_unlock_importer.gd")
const SHOWCASE_WEATHER_CLEAR_ICON = preload("res://resources/ui/icons/storefront/weather_clear.svg")
const SHOWCASE_WEATHER_RAIN_ICON = preload("res://resources/ui/icons/storefront/weather_rain.svg")
const SHOWCASE_WEATHER_WARM_ICON = preload("res://resources/ui/icons/storefront/weather_warm.svg")
const SHOWCASE_WEATHER_GENERIC_ICON = preload("res://resources/ui/icons/storefront/weather_generic.svg")

const INGREDIENT_ICON_DIRECTORY := "res://resources/ui/ingredient_v1"
const DEVICE_ICON_DIRECTORY := "res://resources/ui/device_v1"

const PAGE_PURCHASE := "purchase"
const PAGE_OUTPUT := "output"
const PAGE_PRODUCTION := "production"
const PAGE_RESEARCH := "research"
const PAGE_STOREFRONT_MANAGE := "storefront_manage"
const MODE_KITCHEN_SCHEDULE := "kitchen_schedule"
const PICKER_FILTER_CRAFTABLE := "craftable"
const PICKER_FILTER_MISSING := "missing"
const HARVEST_ALL_FEATURE_ID := "harvest_all"
const HARVEST_ALL_TASK_ID := "feature_harvest_all"
const HARVEST_ALL_TASK_GOAL := 30
const RESEARCH_BULK_RESTOCK_FEATURE_ID := "research_bulk_restock"
const RESEARCH_MAKE_ALL_FEATURE_ID := "research_make_all"
const RECIPE_BATCH_LIMIT_STATUS := "该配方已有 1 批正在制作"
const RESEARCH_LIST_ALL_FEATURE_ID := "research_list_all"
const RESEARCH_BULK_RESTOCK_TASK_ID := "feature_restock_all"
const RESEARCH_MAKE_ALL_TASK_ID := "feature_make_all"
const RESEARCH_LIST_ALL_TASK_ID := "feature_list_all"
const TOOL_METADATA_PREFIX := "tool:"
const OUTPUT_SITE_ORDER := ["farm", "ranch", "forest", "pond"]
const OUTPUT_SLOT_COUNT := 8
const OUTPUT_SITE_CELLS_PER_PAGE := 4
const OUTPUT_SITE_PAGE_COUNT := 2
const OUTPUT_BAG_PAGE_COUNT := 5
const OUTPUT_BAG_CELLS_PER_PAGE := 12
const OUTPUT_CELL_SIZE := Vector2(112, 112)
const OUTPUT_REGION_GRID_COLUMNS := 1
const RESEARCH_INVENTORY_CELL_COUNT := 6
const RESEARCH_INVENTORY_GRID_COLUMNS := 6
const RESEARCH_TOOL_SLOT_SIZE := Vector2(104, 104)
const RESEARCH_MATERIAL_SLOT_SIZE := Vector2(88, 88)
const RESEARCH_TOOL_PICKER_CELL_SIZE := Vector2(168, 168)
const RESEARCH_TOOL_PICKER_POPUP_SIZE := Vector2i(720, 504)
const SHOWCASE_SLOT_COUNT := 168
const SHOWCASE_GRID_ROWS := 12
const SHOWCASE_GRID_COLUMNS := 14
const SHOWCASE_CELL_SIZE := Vector2(72, 72)
const SHOWCASE_EXPANSION_CELL_SIZE := Vector2(65, 65)
const SHOWCASE_UNLIST_DRAG_LABEL_SIZE := Vector2(112, 56)
const SHOWCASE_UNLIST_DRAG_LABEL_GAP := 18.0
const SHOWCASE_UNLIST_DRAG_LABEL_MARGIN := 8.0
const SHOWCASE_SALE_MIN_SECONDS := 10
const SHOWCASE_SALE_MAX_SECONDS := 30
const SHOWCASE_FEEDBACK_PULSE_SECONDS := 1.6
const SHOWCASE_FEEDBACK_COIN_SECONDS := 2.2
const SHOWCASE_FEEDBACK_COIN_ROLL_DELAY_SECONDS := 1.9
const SHOWCASE_FEEDBACK_COIN_ROLL_SECONDS := 0.3
const SHOWCASE_FEEDBACK_RELATION_SECONDS := 2.4
const PRODUCTION_COMPLETION_FEEDBACK_MSEC := 1000
const SHOWCASE_FEEDBACK_RELATION_HOLD_SECONDS := 0.8
const SHOWCASE_FEEDBACK_QUEUE_DELAY_SECONDS := 0.15
const SHOWCASE_COIN_MIN_COUNT := 3
const SHOWCASE_COIN_MAX_COUNT := 6
const SHOWCASE_GROUP_HIGHLIGHT_BORDER_WIDTH := 3
const INVENTORY_GRID_COLUMNS := 8
const INVENTORY_CELLS_PER_PAGE := 48
const INVENTORY_CELL_SIZE := Vector2(80, 80)
const INVENTORY_TAB_ORDER := ["all", "products", "ingredients", "seeds", "tools"]
const INVENTORY_SORT_DEFAULT := "default"
const INVENTORY_SORT_COUNT := "count"
const INVENTORY_SORT_NAME := "name"
const SHOWCASE_VARIANT_ORDER := ["standard", "small", "gift_box", "large", "sample"]
const PURCHASE_REGION_ORDER := ["农场", "养殖场", "林场", "水塘", "辅料", "工具"]
const CATALOG_GRID_COLUMNS := 5
const CATALOG_CELLS_PER_PAGE := 15
const CATALOG_CELL_SIZE := Vector2(112, 112)
const CATALOG_FILTER_ORDER := ["all", "sweet", "drink", "fruit", "bake", "new"]
const TASK_POPUP_MIN_SIZE := Vector2i(420, 180)
const GLOBAL_OVERLAY_FALLBACK_ANCHORS := Vector4(0.19352083, 0.12962963, 0.80647917, 0.87037037)
const GLOBAL_OVERLAY_ASPECT_RATIO := 840.0 / 571.0
const GLOBAL_OVERLAY_MAX_VIEWPORT_FRACTION := Vector2((840.0 / 571.0) * (800.0 / 1920.0), 800.0 / 1080.0)
const PURCHASE_OVERLAY_CONTENT_MARGINS := Vector4(32, 8, 32, 24)
const DEFAULT_OVERLAY_FRAME_OFFSETS := Vector4(22.0, 20.0, -22.0, -20.0)
const CATALOG_OVERLAY_FRAME_OFFSETS := Vector4(92.0, 34.0, -92.0, -86.0)

@onready var coins_label: Label = $Root/TopBar/CoinsLabel
@onready var reputation_label: Label = $Root/TopBar/ReputationLabel
@onready var level_label: Label = $Root/TopBar/LevelLabel
@onready var coins_upgrade_skin: TextureRect = $Root/TopBar/CoinsLabel/SkinTexture
@onready var reputation_upgrade_skin: TextureRect = $Root/TopBar/ReputationLabel/SkinTexture
@onready var coins_upgrade_progress: ProgressBar = $Root/TopBar/CoinsLabel/UpgradeProgress
@onready var reputation_upgrade_progress: ProgressBar = $Root/TopBar/ReputationLabel/UpgradeProgress
@onready var production_zone_shell: Control = $Root/Body/MainArea/WorkbenchPanel
@onready var workbench_launcher: HBoxContainer = $Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher
@onready var starlight_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/StarlightButton
@onready var task_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/TaskButton
@onready var inventory_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/InventoryButton
@onready var catalog_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/CatalogButton
@onready var research_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/ResearchButton
@onready var purchase_receipt_dialog: Control = $PurchaseReceiptDialog
@onready var tutorial_guide_overlay: Control = $TutorialGuideOverlay
@onready var showcase_round_settlement_dialog: ConfirmationDialog = $ShowcaseRoundSettlementDialog
@onready var showcase_rulebook_dialog: AcceptDialog = $ShowcaseRulebookDialog
@onready var recipe_growth_choice_dialog: ConfirmationDialog = $RecipeGrowthChoiceDialog
@onready var purchase_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/PurchaseButton
@onready var output_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/OutputButton
@onready var storefront_manage_button: Button = $Root/Body/MainArea/WorkbenchPanel/WorkbenchLauncher/StorefrontManageButton
@onready var showcase_grid: GridContainer = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcaseGrid
@onready var showcase_panel: Control = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel
@onready var showcase_feedback_layer: Control = $ShowcaseFeedbackLayer
@onready var showcase_unlist_drag_label: Label = $ShowcaseUnlistDragLabel
@onready var showcase_set_progress_label: Label = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/SetProgressLabel
@onready var showcase_pulse_summary: Label = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/ShowcasePulseSummary
@onready var showcase_task_progress_panel: PanelContainer = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/TaskProgressPanel
@onready var showcase_task_progress_label: Label = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/TaskProgressPanel/TaskProgressLabel
@onready var showcase_round_state_label: Label = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/RoundStateLabel
@onready var showcase_weather_forecast_icon: TextureRect = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/WeatherForecastIcon
@onready var showcase_round_countdown_icon: Control = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/CountdownIcon
@onready var showcase_round_countdown_hand: TextureRect = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/CountdownIcon/SecondHand
@onready var showcase_heat_bar: ProgressBar = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/HeatBar
@onready var showcase_rulebook_button: Button = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/RulebookButton
@onready var showcase_start_round_button: Button = $Root/Body/MainArea/StorefrontPanel/ShowcasePanel/RoundControlBar/StartRoundButton
@onready var production_workbench: VBoxContainer = $Root/Body/MainArea/WorkbenchPanel/ProductionWorkbench
@onready var page_description: RichTextLabel = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/PageDescription
@onready var purchase_page_description: RichTextLabel = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PageDescription
@onready var purchase_regions_grid: GridContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PurchaseRegionsGrid
@onready var research_input_bar: HBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ResearchInputBar
@onready var research_tool_slot: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ResearchInputBar/ToolSlot
@onready var research_inventory_grid: GridContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ResearchInputBar/InventoryGrid
@onready var research_tool_picker_popup: PopupPanel = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ResearchInputBar/ResearchToolPickerPopup
@onready var research_tool_picker_grid: GridContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ResearchInputBar/ResearchToolPickerPopup/ToolPickerMargin/ToolPickerBox/ToolPickerGrid
@onready var kitchen_schedule_overlay: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/KitchenScheduleOverlay
@onready var kitchen_automation_panel: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/KitchenScheduleOverlay/KitchenAutomationPanel
@onready var output_page_description: RichTextLabel = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/PageDescription
@onready var output_scroll: ScrollContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputScroll
@onready var output_grid_row: GridContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputScroll/OutputGridRow
@onready var output_primary_action_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputActions/OutputPrimaryActionButton
@onready var output_refresh_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputActions/OutputRefreshButton
@onready var storefront_manage_panel: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel
@onready var storefront_open_slots_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/OpenSlotsMetric/OpenSlotsValue
@onready var storefront_placed_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/PlacedMetric/PlacedValue
@onready var storefront_listed_stock_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/CurrentBuildPanel/CurrentBuildContent/CurrentBuildMetrics/ListedStockMetric/ListedStockValue
@onready var storefront_recent_report_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/CurrentBuildPanel/CurrentBuildContent/CurrentBuildHeader/RecentReportButton
@onready var storefront_view_rules_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/CombinationBonusPanel/CombinationBonusContent/CombinationBonusHeader/ViewAllRulesButton
@onready var storefront_bonus_region_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/CombinationBonusPanel/CombinationBonusContent/BonusGrid/RegionBonusCell/Content/Value
@onready var storefront_bonus_flavor_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/CombinationBonusPanel/CombinationBonusContent/BonusGrid/FlavorBonusCell/Content/Value
@onready var storefront_bonus_set_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/CombinationBonusPanel/CombinationBonusContent/BonusGrid/SetBonusCell/Content/Value
@onready var storefront_bonus_conflict_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/CombinationBonusPanel/CombinationBonusContent/BonusGrid/ConflictBonusCell/Content/Value
@onready var storefront_bonus_prop_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/CombinationBonusPanel/CombinationBonusContent/BonusGrid/PropBonusCell/Content/Value
@onready var storefront_bonus_theme_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/CombinationBonusPanel/CombinationBonusContent/BonusGrid/ThemeBonusCell/Content/Value
@onready var storefront_forecast_income_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/IncomeMetric/IncomeValue
@onready var storefront_forecast_reputation_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/ReputationMetric/ReputationValue
@onready var storefront_forecast_sold_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/SoldMetric/SoldValue
@onready var storefront_forecast_low_stock_value: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/RoundForecastPanel/RoundForecastContent/ForecastMetricGrid/LowStockMetric/LowStockValue
@onready var storefront_product_rate_grid: GridContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/OverviewPage/RoundForecastPanel/RoundForecastContent/ProductRateGrid
@onready var showcase_prop_buttons: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/PropsThemePanel/PropsThemeContent/PropsThemeColumns/PropsColumn/PropScroll/PropButtons
@onready var showcase_theme_buttons: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/PropsThemePanel/PropsThemeContent/PropsThemeColumns/ThemeColumn/ThemeScroll/ThemeButtons
@onready var storefront_special_challenge_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/StrategyActionRow/SpecialChallengeButton
@onready var storefront_expansion_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/StrategyPage/StrategyColumns/StrategyLeft/StrategyActionRow/StorefrontExpansionButton
@onready var management_device_growth_page: DeviceGrowthCenterPage = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay/StorefrontManagePanel/ManagementCenterPages/DeviceGrowthPage
@onready var storefront_challenge_dialog: AcceptDialog = $StorefrontChallengeDialog
@onready var storefront_challenge_summary: RichTextLabel = $StorefrontChallengeDialog/ChallengeContent/ChallengeSummary
@onready var sprint_challenge_button: Button = $StorefrontChallengeDialog/ChallengeContent/ChallengeButtons/SprintChallengeButton
@onready var value_challenge_button: Button = $StorefrontChallengeDialog/ChallengeContent/ChallengeButtons/ValueChallengeButton
@onready var chain_challenge_button: Button = $StorefrontChallengeDialog/ChallengeContent/ChallengeButtons/ChainChallengeButton
@onready var storefront_recent_report_dialog: AcceptDialog = $StorefrontRecentReportDialog
@onready var storefront_recent_round_report_label: RichTextLabel = $StorefrontRecentReportDialog/ReportLabel
@onready var output_context_menu: PopupMenu = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay/OutputContextMenu
@onready var purchase_cart_label: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PurchaseFooter/PurchaseCartLabel
@onready var purchase_confirm_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay/PurchaseFooter/PurchaseConfirmButton
@onready var primary_action_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay/ActionRow/ResearchActionButton
@onready var status_label: Label = $Root/StatusBar/StatusLabel
@onready var task_popup: AcceptDialog = $TaskPopup
@onready var task_popup_title_label: Label = $TaskPopup/TaskPopupContent/TitleLabel
@onready var task_popup_body_label: Label = $TaskPopup/TaskPopupContent/BodyLabel
@onready var research_progress_dialog: ResearchProgressDialog = $ResearchProgressDialog
@onready var automation_report_dialog: AcceptDialog = $AutomationReportDialog
@onready var recipe_restock_dialog: ConfirmationDialog = $RecipeRestockDialog
@onready var global_popup_backdrop: Button = $GlobalPopupBackdrop
@onready var global_overlay_layer: Control = $GlobalOverlayLayer
@onready var default_modal_surface: PanelContainer = $GlobalOverlayLayer/DefaultModalSurface
@onready var overlay_frame: VBoxContainer = $GlobalOverlayLayer/OverlayFrame
@onready var overlay_mode_stack: MarginContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack
@onready var overlay_title: Label = $GlobalOverlayLayer/OverlayFrame/OverlayHeader/OverlayTitle
@onready var overlay_summary: Label = $GlobalOverlayLayer/OverlayFrame/OverlayHeader/OverlaySummary
@onready var overlay_close_button: Button = $GlobalOverlayLayer/OverlayCloseButton
@onready var task_overlay: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay
@onready var overlay_header: HBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayHeader
@onready var task_tabs: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskTabs
@onready var task_list_panel: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskListScroll/TaskListPanel
@onready var task_detail_panel: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/TaskOverlay/TaskBody/TaskDetailPanel
@onready var inventory_overlay: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay
@onready var research_overlay: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/ResearchOverlay
@onready var inventory_capacity_label: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventorySummaryRow/InventoryCapacityLabel
@onready var inventory_search_input: LineEdit = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventorySummaryRow/InventorySearchInput
@onready var inventory_sort_button: OptionButton = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventorySummaryRow/InventorySortButton
@onready var inventory_tabs: TabBar = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryTabs
@onready var inventory_grid: GridContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryGrid
@onready var inventory_prev_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryPager/InventoryPrevButton
@onready var inventory_page_label: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryPager/InventoryPageLabel
@onready var inventory_next_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventoryMainPanel/InventoryPager/InventoryNextButton
@onready var inventory_low_stock_list: RichTextLabel = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventorySidePanel/InventoryLowStockList
@onready var inventory_capacity_warning: RichTextLabel = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventorySidePanel/InventoryCapacityWarning
@onready var inventory_restock_recommendations: RichTextLabel = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryBody/InventorySidePanel/InventoryRestockRecommendations
@onready var inventory_restock_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryActionRow/InventoryRestockButton
@onready var inventory_batch_list_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryActionRow/InventoryBatchListButton
@onready var inventory_sell_extra_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryActionRow/InventorySellExtraButton
@onready var inventory_organize_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/InventoryOverlay/InventoryActionRow/InventoryOrganizeButton
@onready var catalog_overlay: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay
@onready var catalog_collection_label: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogSummaryRow/CatalogCollectionLabel
@onready var catalog_star_label: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogSummaryRow/CatalogStarLabel
@onready var catalog_starlight_label: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogSummaryRow/CatalogStarlightLabel
@onready var catalog_reward_label: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogSummaryRow/CatalogRewardLabel
@onready var catalog_filter_tabs: TabBar = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogFilterTabs
@onready var catalog_device_filter: OptionButton = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogDeviceFilterRow/CatalogDeviceFilter
@onready var catalog_grid: GridContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogContent/CatalogGridPanel/CatalogGrid
@onready var catalog_prev_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogContent/CatalogGridPanel/CatalogPager/CatalogPrevButton
@onready var catalog_page_label: Label = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogContent/CatalogGridPanel/CatalogPager/CatalogPageLabel
@onready var catalog_next_button: Button = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogContent/CatalogGridPanel/CatalogPager/CatalogNextButton
@onready var catalog_milestone_track: HBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/CatalogOverlay/CatalogMilestoneTrack
@onready var automation_overlay: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/AutomationOverlay
@onready var purchase_overlay: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/PurchaseOverlay
@onready var output_overlay: Control = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/OutputOverlay
@onready var storefront_manage_overlay: VBoxContainer = $GlobalOverlayLayer/OverlayFrame/OverlayModeStack/StorefrontManageOverlay

var state = GameState.new_game()
var catalog := Catalog.new()
var save_path := SaveSystem.SAVE_PATH
var broken_save_path := SaveSystem.BROKEN_SAVE_PATH
var recipe_qa_manifest_path := "res://doc/recipe_icon_preview_manifest.md"
var tutorial_last_auto_routed_step := ""
var tutorial_last_auto_routed_state_id := 0
var purchase_regions_by_category := {}
var purchase_cart_quantities := {}
var tutorial_popup_was_blocking := false
var purchase_receipt_suspended_task_popup := false
var purchase_page_refresh_pending := false
var selected_output_site_id := ""
var selected_output_kind := ""
var selected_output_item_id := ""
var selected_output_slot_index := -1
var selected_output_slot_array_index := -1
var selected_output_bag_page := 0
var output_context_item_id := ""
var output_context_actions := {}
var output_countdown_tick_unix := -1
var output_site_grids := {}
var output_site_title_labels := {}
var output_site_pages := {}
var active_output_grid: GridContainer = null
var output_bag_tabs: TabBar = null
var unlocked_output_grid: GridContainer = null
var selected_inventory_tab := "all"
var selected_inventory_page := 0
var inventory_search_text := ""
var selected_inventory_sort := INVENTORY_SORT_DEFAULT
var selected_inventory_item_keys: Array[String] = []
var selected_showcase_variants := {}
var inventory_variant_menu: PopupMenu = null
var inventory_variant_menu_recipe_id := ""
var selected_catalog_page := 0
var selected_catalog_filter := "all"
var selected_catalog_device_filter := "all"
var selected_catalog_recipe_id := ""
var selected_task_filter := "current"
var selected_task_id := ""
var showcase_drag_preview_recipe_id := ""
var showcase_drag_preview_variant_id := ""
var showcase_drag_preview_cells: Array[Vector2i] = []
var showcase_drag_preview_mode := ""
var showcase_unlist_drag_recipe_id := ""
var showcase_unlist_drag_debug_recipe_id := ""
var showcase_unlist_drag_debug_signature := ""
var showcase_expansion_active := false
var showcase_expansion_tool := "cells"
var showcase_expansion_selected_cells: Array[Vector2i] = []
var showcase_bonus_cache := {}
var showcase_bonus_cache_valid := false
var showcase_preview_bonus_cache_key := ""
var showcase_preview_bonus_cache := {}
var showcase_icon_service := ShowcaseIconService.new()
var selected_research_material_ids: Array[String] = []
var selected_research_tool_id := ""
var pending_research_material_slot_index := -1
var pending_recipe_restock_id := ""
var pending_research_bulk_restock := false
var production_completion_feedback: Array[Dictionary] = []
var production_queue_snapshot: Dictionary = {}
var production_queue_search_query := ""
var research_request_busy := false
var global_popup_mode := ""
var global_popup_return_mode := ""
var global_overlay_dragging := false
var global_overlay_drag_offset := Vector2.ZERO
var inventory_overlay_dragging := false
var inventory_drag_start_mouse_position := Vector2.ZERO
var inventory_drag_start_overlay_position := Vector2.ZERO
var inventory_overlay_hidden_for_product_drag := false
var last_business_feedback := {
	"recipe_name": "",
	"sold_by_recipe_name": {},
	"sold_count": 0,
	"earned_coins": 0,
	"earned_reputation": 0,
	"triggered": false
}
var cashier_receipt_text := "待营业"
var cashier_feedback_text := "暂无反馈"
var showcase_feedback_director := ShowcaseFeedbackDirector.new()
var showcase_sale_progress_groups := {}
var showcase_feedback_outlines := {}
var showcase_stock_feedback_badges := {}
var showcase_stock_feedback_sequence := 0
var showcase_feedback_visual_coin_target := -1
var showcase_feedback_pending_coin_rolls := 0
var showcase_feedback_coin_roll_tween: Tween
var showcase_round_delta_carry_ms := 0.0
var showcase_round_persist_carry_ms := 0


func _ready() -> void:
	state = SaveSystem.load_game(save_path, broken_save_path)
	_refresh_showcase_layout_projection()
	showcase_feedback_visual_coin_target = int(state.coins)
	showcase_icon_service.load_manifest()
	var start_round_handler := Callable(self, "_start_showcase_business_round")
	if showcase_panel.has_signal("start_round_requested") and not showcase_panel.is_connected("start_round_requested", start_round_handler):
		showcase_panel.connect("start_round_requested", start_round_handler)
	var guided_rulebook_handler := Callable(self, "_on_showcase_rulebook_requested")
	if showcase_panel.has_signal("rulebook_requested") and not showcase_panel.is_connected("rulebook_requested", guided_rulebook_handler):
		showcase_panel.connect("rulebook_requested", guided_rulebook_handler)
	var rulebook_handler := Callable(self, "_open_showcase_rulebook")
	if not storefront_view_rules_button.pressed.is_connected(rulebook_handler):
		storefront_view_rules_button.pressed.connect(rulebook_handler)
	if not storefront_expansion_button.pressed.is_connected(_enter_showcase_expansion_mode):
		storefront_expansion_button.pressed.connect(_enter_showcase_expansion_mode)
	var expansion_tool_handler := Callable(self, "_set_showcase_expansion_tool")
	if showcase_panel.has_signal("expansion_tool_requested") and not showcase_panel.is_connected("expansion_tool_requested", expansion_tool_handler):
		showcase_panel.connect("expansion_tool_requested", expansion_tool_handler)
	var expansion_confirm_handler := Callable(self, "_confirm_showcase_expansion_purchase")
	if showcase_panel.has_signal("expansion_confirm_requested") and not showcase_panel.is_connected("expansion_confirm_requested", expansion_confirm_handler):
		showcase_panel.connect("expansion_confirm_requested", expansion_confirm_handler)
	var expansion_cancel_handler := Callable(self, "_cancel_showcase_expansion_mode")
	if showcase_panel.has_signal("expansion_cancel_requested") and not showcase_panel.is_connected("expansion_cancel_requested", expansion_cancel_handler):
		showcase_panel.connect("expansion_cancel_requested", expansion_cancel_handler)
	if not storefront_special_challenge_button.pressed.is_connected(_open_storefront_challenge_dialog):
		storefront_special_challenge_button.pressed.connect(_open_storefront_challenge_dialog)
	if not storefront_recent_report_button.pressed.is_connected(_open_storefront_recent_report_dialog):
		storefront_recent_report_button.pressed.connect(_open_storefront_recent_report_dialog)
	for theme_button_value in showcase_theme_buttons.get_children():
		var theme_button := theme_button_value as Button
		if theme_button == null:
			continue
		var theme_id := "" if theme_button.name == &"none" else String(theme_button.name)
		var theme_handler := Callable(self, "_on_showcase_theme_button_pressed").bind(theme_id)
		if not theme_button.pressed.is_connected(theme_handler):
			theme_button.pressed.connect(theme_handler)
	workbench_launcher.connect("purchase_requested", _on_purchase_global_button_pressed)
	workbench_launcher.connect("output_requested", _on_output_global_button_pressed)
	workbench_launcher.connect("storefront_manage_requested", _on_storefront_manage_pressed)
	if not tutorial_guide_overlay.is_connected("skip_requested", _on_tutorial_skip_requested):
		tutorial_guide_overlay.connect("skip_requested", _on_tutorial_skip_requested)
	if not tutorial_guide_overlay.is_connected("dialogue_acknowledged", _on_tutorial_dialogue_acknowledged):
		tutorial_guide_overlay.connect("dialogue_acknowledged", _on_tutorial_dialogue_acknowledged)
	if not tutorial_guide_overlay.is_connected("close_requested", _on_tutorial_close_requested):
		tutorial_guide_overlay.connect("close_requested", _on_tutorial_close_requested)
	if not tutorial_guide_overlay.is_connected("restart_requested", _on_tutorial_restart_requested):
		tutorial_guide_overlay.connect("restart_requested", _on_tutorial_restart_requested)
	workbench_launcher.connect("task_requested", Callable(self, "_on_task_global_button_pressed"))
	workbench_launcher.connect("inventory_requested", Callable(self, "_on_inventory_global_button_pressed"))
	workbench_launcher.connect("catalog_requested", Callable(self, "_on_catalog_global_button_pressed"))
	workbench_launcher.connect("research_requested", Callable(self, "_on_research_global_button_pressed"))
	workbench_launcher.connect("starlight_requested", Callable(self, "_on_starlight_global_button_pressed"))
	_bind_purchase_regions()
	purchase_confirm_button.pressed.connect(_on_purchase_confirm_pressed)
	var research_tool_slot_handler := Callable(self, "_on_research_tool_slot_pressed")
	if not research_tool_slot.pressed.is_connected(research_tool_slot_handler):
		research_tool_slot.pressed.connect(research_tool_slot_handler)
	if is_instance_valid(output_bag_tabs):
		output_bag_tabs.tab_changed.connect(_on_output_bag_tab_changed)
	var output_context_handler := Callable(self, "_on_output_context_menu_id_pressed")
	if not output_context_menu.id_pressed.is_connected(output_context_handler):
		output_context_menu.id_pressed.connect(output_context_handler)
	output_primary_action_button.pressed.connect(_on_output_primary_action_pressed)
	output_refresh_button.pressed.connect(_on_output_refresh_pressed)
	_ensure_inventory_variant_menu()
	var task_popup_handler := Callable(self, "_on_task_popup_confirmed")
	if not task_popup.confirmed.is_connected(task_popup_handler):
		task_popup.confirmed.connect(task_popup_handler)
	var task_popup_native_label := task_popup.get_label()
	if task_popup_native_label != null:
		task_popup_native_label.hide()
	var receipt_visibility_handler := Callable(self, "_on_purchase_receipt_visibility_changed")
	if not purchase_receipt_dialog.visibility_changed.is_connected(receipt_visibility_handler):
		purchase_receipt_dialog.visibility_changed.connect(receipt_visibility_handler)
	var showcase_settlement_handler := Callable(self, "_confirm_showcase_round_settlement")
	if showcase_round_settlement_dialog.has_signal("settlement_confirmed") and not showcase_round_settlement_dialog.is_connected("settlement_confirmed", showcase_settlement_handler):
		showcase_round_settlement_dialog.connect("settlement_confirmed", showcase_settlement_handler)
	var growth_choice_handler := Callable(self, "_on_recipe_growth_trait_selected")
	if recipe_growth_choice_dialog.has_signal("trait_selected") and not recipe_growth_choice_dialog.is_connected("trait_selected", growth_choice_handler):
		recipe_growth_choice_dialog.connect("trait_selected", growth_choice_handler)
	var report_closed_handler := Callable(self, "_on_automation_report_closed")
	if not automation_report_dialog.confirmed.is_connected(report_closed_handler):
		automation_report_dialog.confirmed.connect(report_closed_handler)
	var recipe_restock_handler := Callable(self, "_on_recipe_restock_confirmed")
	if not recipe_restock_dialog.confirmed.is_connected(recipe_restock_handler):
		recipe_restock_dialog.confirmed.connect(recipe_restock_handler)
	production_workbench.search_changed.connect(_on_production_queue_search_changed)
	production_workbench.bulk_action_requested.connect(_on_production_queue_bulk_action_requested)
	production_workbench.kitchen_schedule_requested.connect(_show_kitchen_schedule)
	production_workbench.make_requested.connect(_on_recipe_make_pressed)
	production_workbench.process_requested.connect(_on_process_make_pressed)
	production_workbench.restock_requested.connect(_on_recipe_restock_pressed)
	if automation_report_dialog.has_signal("canceled") and not automation_report_dialog.canceled.is_connected(report_closed_handler):
		automation_report_dialog.canceled.connect(report_closed_handler)
	if not automation_report_dialog.close_requested.is_connected(report_closed_handler):
		automation_report_dialog.close_requested.connect(report_closed_handler)
	for storefront_entry_dialog in [storefront_challenge_dialog, storefront_recent_report_dialog, showcase_rulebook_dialog]:
		var storefront_close_handler := Callable(self, "_on_storefront_entry_dialog_close_requested").bind(storefront_entry_dialog)
		if not storefront_entry_dialog.close_requested.is_connected(storefront_close_handler):
			storefront_entry_dialog.close_requested.connect(storefront_close_handler)
		var storefront_visibility_handler := Callable(self, "_refresh_storefront_entry_dialog_backdrop")
		if not storefront_entry_dialog.visibility_changed.is_connected(storefront_visibility_handler):
			storefront_entry_dialog.visibility_changed.connect(storefront_visibility_handler)
	var report_navigate_handler := Callable(self, "_on_automation_report_navigate_requested")
	if not automation_report_dialog.is_connected("navigate_requested", report_navigate_handler):
		automation_report_dialog.connect("navigate_requested", report_navigate_handler)
	var kitchen_save_handler := Callable(self, "_on_kitchen_rule_save_requested")
	if not kitchen_automation_panel.is_connected("rule_save_requested", kitchen_save_handler):
		kitchen_automation_panel.connect("rule_save_requested", kitchen_save_handler)
	var kitchen_remove_handler := Callable(self, "_on_kitchen_rule_remove_requested")
	if not kitchen_automation_panel.is_connected("rule_remove_requested", kitchen_remove_handler):
		kitchen_automation_panel.connect("rule_remove_requested", kitchen_remove_handler)
	var kitchen_pause_handler := Callable(self, "_on_kitchen_pause_toggled")
	if not kitchen_automation_panel.is_connected("pause_toggled", kitchen_pause_handler):
		kitchen_automation_panel.connect("pause_toggled", kitchen_pause_handler)
	var global_popup_backdrop_handler := Callable(self, "_on_global_popup_backdrop_pressed")
	if not global_popup_backdrop.pressed.is_connected(global_popup_backdrop_handler):
		global_popup_backdrop.pressed.connect(global_popup_backdrop_handler)
	var overlay_close_handler := Callable(self, "_on_overlay_close_button_pressed")
	if not overlay_close_button.pressed.is_connected(overlay_close_handler):
		overlay_close_button.pressed.connect(overlay_close_handler)
	var overlay_header_drag_handler := Callable(self, "_on_overlay_header_gui_input")
	if not overlay_header.gui_input.is_connected(overlay_header_drag_handler):
		overlay_header.gui_input.connect(overlay_header_drag_handler)
	_fill_inventory_sort_options()
	var inventory_sort_handler := Callable(self, "_on_inventory_sort_changed")
	if not inventory_sort_button.item_selected.is_connected(inventory_sort_handler):
		inventory_sort_button.item_selected.connect(inventory_sort_handler)
	var inventory_search_handler := Callable(self, "_on_inventory_search_changed")
	if not inventory_search_input.text_changed.is_connected(inventory_search_handler):
		inventory_search_input.text_changed.connect(inventory_search_handler)
	inventory_tabs.tab_changed.connect(_on_inventory_tab_changed)
	inventory_prev_button.pressed.connect(_on_inventory_prev_pressed)
	inventory_next_button.pressed.connect(_on_inventory_next_pressed)
	inventory_restock_button.pressed.connect(_on_inventory_restock_pressed)
	inventory_batch_list_button.pressed.connect(_on_inventory_batch_list_pressed)
	inventory_sell_extra_button.pressed.connect(_on_inventory_sell_extra_pressed)
	inventory_organize_button.pressed.connect(_on_inventory_organize_pressed)
	_fill_catalog_filter_tabs()
	_fill_catalog_device_filter()
	var catalog_filter_handler := Callable(self, "_on_catalog_filter_changed")
	if not catalog_filter_tabs.tab_changed.is_connected(catalog_filter_handler):
		catalog_filter_tabs.tab_changed.connect(catalog_filter_handler)
	var catalog_device_filter_handler := Callable(self, "_on_catalog_device_filter_changed")
	if not catalog_device_filter.item_selected.is_connected(catalog_device_filter_handler):
		catalog_device_filter.item_selected.connect(catalog_device_filter_handler)
	var device_growth_upgrade_handler := Callable(self, "_on_device_growth_upgrade_requested")
	if not management_device_growth_page.is_connected("upgrade_requested", device_growth_upgrade_handler):
		management_device_growth_page.connect("upgrade_requested", device_growth_upgrade_handler)
	var device_growth_catalog_handler := Callable(self, "_on_device_growth_catalog_filter_requested")
	if not management_device_growth_page.is_connected("catalog_filter_requested", device_growth_catalog_handler):
		management_device_growth_page.connect("catalog_filter_requested", device_growth_catalog_handler)
	catalog_prev_button.pressed.connect(_on_catalog_prev_pressed)
	catalog_next_button.pressed.connect(_on_catalog_next_pressed)
	task_overlay.connect("task_rewards_claim_all_requested", Callable(self, "_on_task_claim_all_rewards_pressed"))
	catalog_overlay.connect("catalog_make_requested", Callable(self, "_on_catalog_make_pressed"))
	catalog_overlay.connect("catalog_reward_claim_requested", Callable(self, "_on_catalog_claim_reward_pressed"))
	catalog_overlay.connect("catalog_reward_claim_all_requested", Callable(self, "_on_catalog_claim_all_rewards_pressed"))
	catalog_overlay.connect("catalog_milestone_claim_requested", Callable(self, "_on_catalog_milestone_claim_pressed"))
	automation_overlay.connect("close_requested", Callable(self, "_close_global_popup"))
	automation_overlay.connect("upgrade_requested", Callable(self, "_on_automation_upgrade_requested"))
	automation_overlay.connect("pause_all_requested", Callable(self, "_on_automation_pause_all_requested"))
	_setup_output_drag_forwarding()
	primary_action_button.pressed.connect(_on_primary_action)
	research_progress_dialog.result_confirmed.connect(_on_research_result_confirmed)
	for challenge_binding in [
		[sprint_challenge_button, 0],
		[value_challenge_button, 1],
		[chain_challenge_button, 2]
	]:
		var challenge_button: Button = challenge_binding[0]
		var challenge_index: int = challenge_binding[1]
		var challenge_handler := Callable(self, "_accept_showcase_business_challenge_index").bind(challenge_index)
		if not challenge_button.pressed.is_connected(challenge_handler):
			challenge_button.pressed.connect(challenge_handler)
	_show_page(PAGE_PRODUCTION)
	_apply_initial_status()
	_refresh_showcase_round_controls()
	if not state.pending_showcase_settlement.is_empty():
		call_deferred("_present_showcase_round_settlement")
	_show_next_notification()
	_log_showcase_unlist_drag("ready", "", "scene=%s label_path=%s" % [scene_file_path, showcase_unlist_drag_label.get_path()])
	call_deferred("_refresh_tutorial_guide")


func _process(delta: float) -> void:
	_restore_inventory_overlay_after_product_drag_if_needed()
	_refresh_showcase_unlist_drag_label()
	if is_instance_valid(tutorial_guide_overlay) and TutorialProgress.is_guide_active(state):
		var tutorial_popup_blocking := _is_tutorial_popup_blocking()
		tutorial_guide_overlay.call("set_popup_paused", tutorial_popup_blocking)
		if tutorial_popup_was_blocking and not tutorial_popup_blocking:
			call_deferred("_refresh_tutorial_guide")
		tutorial_popup_was_blocking = tutorial_popup_blocking
	_process_showcase_business_round_delta(delta)
	var now_unix := int(Time.get_unix_time_from_system())
	if now_unix == output_countdown_tick_unix:
		return

	output_countdown_tick_unix = now_unix
	var manual_result := _process_online_recipe_production(now_unix)
	var manual_completed := _capture_recipe_completion_feedback(manual_result)
	var automation_result := _process_online_automation(now_unix)
	var automation_completed := _capture_recipe_completion_feedback(automation_result)
	if manual_completed or automation_completed:
		production_zone_shell.call("pulse_completion")
	_prune_recipe_completion_feedback()
	_refresh_production_queue_tick(now_unix)
	if global_popup_mode == "output":
		_refresh_output_countdown_texts(now_unix)
		if TutorialProgress.is_guide_active(state) and String(state.tutorial_guide_step) == TutorialProgress.STEP_OUTPUT:
			call_deferred("_refresh_tutorial_guide")
	_refresh_showcase_round_controls()
	_refresh_showcase_countdown_texts(now_unix)


func _process_online_recipe_production(now_unix: int) -> Dictionary:
	if state == null or now_unix < 0:
		return {}
	var result: Dictionary = state.complete_ready_manual_recipe_productions(now_unix)
	var processing_result: Dictionary = state.complete_ready_ingredient_processes(now_unix)
	result["completed_processes"] = int(processing_result.get("completed_processes", 0))
	result["ingredient_outputs"] = processing_result.get("ingredient_outputs", {})
	result["completed_process_slots"] = processing_result.get("completed_process_slots", [])
	if int(result.get("completed_batches", 0)) <= 0 \
			and int(result.get("completed_processes", 0)) <= 0:
		return result
	_set_status(_recipe_production_completion_feedback_text(result))
	_save_game()
	_refresh_current_page()
	_show_next_notification()
	return result


func _recipe_production_completion_feedback_text(result: Dictionary) -> String:
	var total_output := 0
	var product_outputs: Dictionary = result.get("product_outputs", {}) if result.get("product_outputs", {}) is Dictionary else {}
	for output_value: Variant in product_outputs.values():
		total_output += maxi(0, int(output_value))
	var total_ingredients := 0
	var ingredient_outputs: Dictionary = result.get("ingredient_outputs", {}) if result.get("ingredient_outputs", {}) is Dictionary else {}
	for output_value: Variant in ingredient_outputs.values():
		total_ingredients += maxi(0, int(output_value))
	var completed_batches := int(result.get("completed_batches", 0))
	var completed_processes := int(result.get("completed_processes", 0))
	if completed_batches > 0 and completed_processes > 0:
		return "制作完成：%d 批成品、%d 项加工，共获得 %d 份成品和 %d 份食材。" % [
			completed_batches,
			completed_processes,
			total_output,
			total_ingredients
		]
	if completed_processes > 0:
		return "加工完成：%d 项，共获得 %d 份食材。" % [completed_processes, total_ingredients]
	return "制作完成：%d 个队列，共获得 %d 份成品。" % [completed_batches, total_output]


func _process_online_automation(now_unix: int) -> Dictionary:
	if state == null or now_unix < 0:
		return {}
	var previous_unix := int(state.automation_last_settled_unix)
	if previous_unix <= 0:
		state.automation_last_settled_unix = now_unix
		return _empty_online_automation_report(now_unix, now_unix)
	if now_unix <= previous_unix:
		return _empty_online_automation_report(previous_unix, now_unix)
	var report: Dictionary = AutomationService.settle(state, previous_unix, now_unix, -1)
	state.automation_last_settled_unix = now_unix
	var has_changed_pause := not (report.get("pauses", []) as Array).is_empty() or not (report.get("paused_slots", []) as Array).is_empty()
	if int(report.get("event_count", 0)) <= 0 and not has_changed_pause:
		return report
	_set_status(_online_automation_feedback_text(report))
	_save_game()
	_refresh_current_page()
	return report


func _empty_online_automation_report(from_unix: int, to_unix: int) -> Dictionary:
	return {
		"from_unix": from_unix,
		"to_unix": to_unix,
		"event_count": 0,
		"output_cycle_count": 0,
		"kitchen_cycle_count": 0,
		"outputs": {},
		"product_outputs": {},
		"completed_recipe_slots": [],
		"growth": {},
		"pauses": [],
		"paused_slots": []
	}


func _online_automation_feedback_text(report: Dictionary) -> String:
	var parts: Array[String] = []
	var outputs: Dictionary = report.get("outputs", {}) if report.get("outputs", {}) is Dictionary else {}
	var output_ids: Array = outputs.keys()
	output_ids.sort()
	for item_value: Variant in output_ids:
		var item_id := String(item_value)
		parts.append("%s x%d" % [_ingredient_name(item_id), int(outputs.get(item_value, 0))])
	var product_outputs: Dictionary = report.get("product_outputs", {}) if report.get("product_outputs", {}) is Dictionary else {}
	var product_ids: Array = product_outputs.keys()
	product_ids.sort()
	for recipe_value: Variant in product_ids:
		var recipe_id := String(recipe_value)
		parts.append("%s x%d" % [_recipe_name(recipe_id), int(product_outputs.get(recipe_value, 0))])
	var pause_count := (report.get("pauses", []) as Array).size() + (report.get("paused_slots", []) as Array).size()
	if parts.is_empty() and pause_count > 0:
		return "自动化暂停：新增 %d 个需处理项目。" % pause_count
	if parts.is_empty():
		return "自动化完成 %d 轮生产。" % int(report.get("event_count", 0))
	return "自动化已收获：%s。" % "、".join(parts)


func _input(event: InputEvent) -> void:
	if _handle_recipe_qa_unlock_shortcut(event):
		return
	if purchase_receipt_dialog.visible \
			and purchase_receipt_dialog.has_method("handle_pointer_input") \
			and bool(purchase_receipt_dialog.call("handle_pointer_input", event)):
		get_viewport().set_input_as_handled()
		return
	if _handle_global_overlay_drag_input(event):
		return
	if global_popup_mode.is_empty() or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _is_position_inside_control(workbench_launcher, mouse_event.position):
		get_viewport().set_input_as_handled()
		if not mouse_event.pressed:
			workbench_launcher.call("press_entry_at_global_position", mouse_event.position)
		return
	if not mouse_event.pressed:
		return
	if _is_position_inside_control(global_overlay_layer, mouse_event.position):
		return
	var top_bar := task_button.get_parent() as Control
	if _is_position_inside_control(top_bar, mouse_event.position):
		if global_popup_mode != "inventory":
			get_viewport().set_input_as_handled()
		return
	_close_global_popup()
	get_viewport().set_input_as_handled()


func _handle_recipe_qa_unlock_shortcut(event: InputEvent) -> bool:
	if not OS.is_debug_build() or not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	var is_unlock_key := key_event.keycode == KEY_U or key_event.physical_keycode == KEY_U
	if not is_unlock_key \
			or not key_event.ctrl_pressed \
			or not key_event.alt_pressed \
			or key_event.shift_pressed \
			or key_event.meta_pressed:
		return false
	_run_recipe_qa_unlock_import(recipe_qa_manifest_path)
	get_viewport().set_input_as_handled()
	return true


func _run_recipe_qa_unlock_import(path: String = "") -> Dictionary:
	var actual_path := recipe_qa_manifest_path if path.is_empty() else path
	var parsed: Dictionary = DevRecipeUnlockImporter.parse_manifest(actual_path, catalog.get_recipes())
	if not bool(parsed.get("ok", false)):
		var parse_errors: Array = parsed.get("errors", [])
		status_label.text = String(parse_errors[0]) if not parse_errors.is_empty() else "Markdown 中没有可解锁的配方。"
		return {"ok": false, "stage": "parse", "parsed": parsed}
	var plan: Dictionary = DevRecipeUnlockImporter.build_plan(parsed, catalog)
	if not bool(plan.get("ok", false)):
		var plan_errors: Array = plan.get("errors", [])
		status_label.text = String(plan_errors[0]) if not plan_errors.is_empty() else "配方依赖计划无效。"
		return {"ok": false, "stage": "plan", "parsed": parsed, "plan": plan}

	var snapshot: Dictionary = DevRecipeUnlockImporter.snapshot_state(state)
	var applied: Dictionary = DevRecipeUnlockImporter.apply_plan(state, plan)
	if not bool(applied.get("ok", false)):
		DevRecipeUnlockImporter.restore_snapshot(state, snapshot)
		_refresh_after_recipe_qa_unlock()
		status_label.text = "配方验收解锁失败，未修改当前存档。"
		return {"ok": false, "stage": "apply", "parsed": parsed, "plan": plan, "applied": applied}

	var mutation_count := _recipe_qa_mutation_count(applied)
	if mutation_count > 0 and state.has_method("add_log"):
		state.add_log("dev_recipe_qa_unlock:%d" % mutation_count)
	if not _save_game():
		DevRecipeUnlockImporter.restore_snapshot(state, snapshot)
		_refresh_after_recipe_qa_unlock()
		status_label.text = "配方验收解锁保存失败，已恢复执行前状态。"
		return {"ok": false, "stage": "save", "parsed": parsed, "plan": plan, "applied": applied}

	_refresh_after_recipe_qa_unlock()
	var summary := _recipe_qa_unlock_summary(plan, applied)
	status_label.text = summary
	return {
		"ok": true,
		"stage": "complete",
		"parsed": parsed,
		"plan": plan,
		"applied": applied,
		"summary": summary,
	}


func _refresh_after_recipe_qa_unlock() -> void:
	_refresh_core_feature_access()
	_refresh_current_page()
	if global_popup_mode == "catalog" and is_instance_valid(catalog_overlay):
		catalog_overlay.call("refresh_panel", self)
	elif global_popup_mode == "inventory" and is_instance_valid(inventory_overlay):
		inventory_overlay.call("refresh_grid", self)


func _recipe_qa_mutation_count(applied: Dictionary) -> int:
	var count := 0
	for key in [
		"added_core_count",
		"added_device_count",
		"added_process_count",
		"added_purchase_count",
		"added_recipe_count",
	]:
		count += maxi(0, int(applied.get(key, 0)))
	if int(applied.get("after_level", 0)) > int(applied.get("before_level", 0)):
		count += 1
	return count


func _recipe_qa_unlock_summary(plan: Dictionary, applied: Dictionary) -> String:
	var ignored_count := (plan.get("ignored_ids", []) as Array).size() + (plan.get("invalid_targets", []) as Array).size()
	return "配方验收导入完成｜目标 %d｜新增 %d｜已有 %d｜前置 %d｜设备/原料权限 %d｜等级 %d→%d｜忽略 %d｜缺图 %d｜已保存" % [
		(plan.get("target_recipe_ids", []) as Array).size(),
		int(applied.get("added_recipe_count", 0)),
		int(applied.get("existing_recipe_count", 0)),
		int(applied.get("added_prerequisite_count", 0)),
		int(applied.get("added_device_count", 0)) + int(applied.get("added_process_count", 0)) + int(applied.get("added_purchase_count", 0)),
		int(applied.get("before_level", 0)),
		int(applied.get("after_level", 0)),
		ignored_count,
		(plan.get("missing_assets", []) as Array).size(),
	]



func _on_overlay_header_gui_input(event: InputEvent) -> void:
	if global_popup_mode.is_empty() or not global_overlay_layer.visible:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		var mouse_global := overlay_header.get_global_rect().position + mouse_event.position
		global_overlay_dragging = true
		global_overlay_drag_offset = global_overlay_layer.global_position - mouse_global
		get_viewport().set_input_as_handled()


func _handle_global_overlay_drag_input(event: InputEvent) -> bool:
	if not global_overlay_dragging:
		return false
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_move_global_overlay_to(motion.position + global_overlay_drag_offset)
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if not mouse_event.pressed:
				global_overlay_dragging = false
				get_viewport().set_input_as_handled()
			return true
	return false


func _move_global_overlay_to(target_global_position: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var overlay_size := global_overlay_layer.size
	var max_position := Vector2(
		maxf(0.0, viewport_size.x - overlay_size.x),
		maxf(0.0, viewport_size.y - overlay_size.y)
	)
	global_overlay_layer.global_position = Vector2(
		clampf(target_global_position.x, 0.0, max_position.x),
		clampf(target_global_position.y, 0.0, max_position.y)
	)


func _show_page(page: String) -> void:
	_open_workbench_destination(page)


func _open_workbench_destination(destination: String) -> void:
	match destination:
		PAGE_PURCHASE:
			_show_purchase_global_popup()
		PAGE_OUTPUT:
			_show_output_global_popup()
		PAGE_STOREFRONT_MANAGE:
			_show_storefront_manage_global_popup()
		PAGE_RESEARCH:
			_show_research_global_popup()
		PAGE_PRODUCTION:
			_close_global_popup()
			_refresh_current_page()


func _is_workbench_destination_active(destination: String) -> bool:
	if destination == PAGE_PRODUCTION:
		return global_popup_mode.is_empty()
	return global_popup_mode == destination


func _refresh_tutorial_guide() -> void:
	if not is_instance_valid(tutorial_guide_overlay):
		return
	if not TutorialProgress.is_guide_active(state):
		tutorial_guide_overlay.call("hide_guide")
		return
	if TutorialProgress.is_current_guidance_dismissed(state):
		tutorial_guide_overlay.call("hide_guide")
		return
	if _is_tutorial_popup_blocking():
		tutorial_guide_overlay.call("set_popup_paused", true)
		return
	var current_state_id := int(state.get_instance_id())
	if tutorial_last_auto_routed_state_id != current_state_id:
		tutorial_last_auto_routed_state_id = current_state_id
		tutorial_last_auto_routed_step = ""
	var step := String(state.tutorial_guide_step)
	var step_changed := tutorial_last_auto_routed_step != step
	var dialogue_entry := _tutorial_dialogue_entry(step, null)
	var showcase_rect := showcase_panel.get_global_rect() if is_instance_valid(showcase_panel) else Rect2(global_position, size)
	if step == TutorialProgress.STEP_COMPLETE:
		tutorial_last_auto_routed_step = step
		tutorial_guide_overlay.call("present_completion", dialogue_entry, showcase_rect)
		tutorial_guide_overlay.call("set_popup_paused", false)
		return
	var required_page := _tutorial_required_page(step)
	if step_changed:
		tutorial_last_auto_routed_step = step
		if not _tutorial_page_opens_from_dialogue_action(step) \
				and not required_page.is_empty() \
				and not _is_workbench_destination_active(required_page):
			_open_workbench_destination(required_page)
	var target := _tutorial_target_for_step(step)
	dialogue_entry = _tutorial_dialogue_entry(step, target)
	var should_expand := step_changed and String(state.tutorial_guide_dialogue_acknowledged_step) != step
	if not step_changed and tutorial_guide_overlay.has_method("is_dialogue_expanded"):
		should_expand = bool(tutorial_guide_overlay.call("is_dialogue_expanded"))
	tutorial_guide_overlay.call("present_step", dialogue_entry, target, showcase_rect, should_expand)
	tutorial_guide_overlay.call("set_popup_paused", _is_tutorial_popup_blocking())


func _tutorial_required_page(step: String) -> String:
	match step:
		TutorialProgress.STEP_PURCHASE:
			return PAGE_PURCHASE
		TutorialProgress.STEP_OUTPUT:
			return PAGE_OUTPUT
		TutorialProgress.STEP_RESEARCH:
			return PAGE_RESEARCH
		TutorialProgress.STEP_CRAFT, TutorialProgress.STEP_LIST:
			return PAGE_PRODUCTION
		TutorialProgress.STEP_SETTLEMENT:
			return PAGE_STOREFRONT_MANAGE
	return ""


func _tutorial_page_opens_from_dialogue_action(step: String) -> bool:
	return step in [TutorialProgress.STEP_PURCHASE, TutorialProgress.STEP_OUTPUT]


func _tutorial_dialogue_entry(step: String, target: Control) -> Dictionary:
	var entry := TutorialDialogueCatalog.dialogue_for_step(step)
	match step:
		TutorialProgress.STEP_PURCHASE:
			entry["action_hint"] = "确认购买水稻种子。" if target == primary_action_button else "购买 1 份水稻种子。"
		TutorialProgress.STEP_OUTPUT:
			if target != null and String(target.get_meta("output_kind", "")) == "active":
				entry["action_hint"] = "点击成熟槽，手动收获大米。"
			elif target != null:
				entry["action_hint"] = "点击农场空位，用刚买的水稻种子开始产出。"
			else:
				entry["action_hint"] = "等待大米成熟后手动收获。"
		TutorialProgress.STEP_RESEARCH:
			if target == primary_action_button:
				entry["action_hint"] = "点击研发，解锁米浆饮。"
			elif target == research_tool_slot:
				entry["action_hint"] = "选择蒸煮一体的圆锅。"
			elif global_popup_mode == "inventory" and global_overlay_layer.visible:
				entry["action_hint"] = "选择箭头指向的研发材料。"
			else:
				entry["action_hint"] = "依次放入大米和泉水。"
		TutorialProgress.STEP_CRAFT:
			entry["action_hint"] = "米浆饮制作中，等待完成。" if _tutorial_recipe_is_producing("rice_milk_drink") else "制作 1 次米浆饮。"
		TutorialProgress.STEP_LIST:
			entry["action_hint"] = "把米浆饮上架到橱窗。"
		TutorialProgress.STEP_RULEBOOK:
			entry["action_hint"] = "点击查看构筑规则。"
		TutorialProgress.STEP_ARRANGE:
			if _is_showcase_round_layout_locked():
				entry["action_hint"] = "等待当前经营结束后再调整橱窗。"
			else:
				var move_status := "已拖动" if bool(state.tutorial_guide_showcase_moved) else "拖动一次"
				var rotate_status := "已旋转" if bool(state.tutorial_guide_showcase_rotated) else "右键旋转一次"
				entry["action_hint"] = "%s｜%s" % [move_status, rotate_status]
		TutorialProgress.STEP_BUSINESS:
			if target == null and String(state.active_business_round.get("phase", "")) in ["running", "settlement"]:
				entry["action_hint"] = "等待当前经营结束后再开始营业。"
			else:
				entry["action_hint"] = "点击开始营业。"
		TutorialProgress.STEP_STOREFRONT:
			entry["action_hint"] = "点击经营中心，查看经营状态。"
		TutorialProgress.STEP_SETTLEMENT:
			entry["action_hint"] = "等待本轮营业结束并完成结算；至少售出 1 件商品。"
	return entry


func _is_tutorial_popup_blocking() -> bool:
	if global_overlay_layer.visible:
		var tutorial_step := String(state.tutorial_guide_step)
		var required_destination := _tutorial_required_page(tutorial_step)
		var is_new_unrouted_step := tutorial_last_auto_routed_step != tutorial_step
		var is_required_workbench_overlay := not required_destination.is_empty() \
			and global_popup_mode == required_destination
		var is_completion_storefront_overlay := tutorial_step == TutorialProgress.STEP_COMPLETE \
			and global_popup_mode == PAGE_STOREFRONT_MANAGE
		var is_research_picker := tutorial_step == TutorialProgress.STEP_RESEARCH \
			and global_popup_mode == "inventory" \
			and pending_research_material_slot_index >= 0
		if not is_new_unrouted_step \
				and not is_research_picker \
				and not is_required_workbench_overlay \
				and not is_completion_storefront_overlay:
			return true
	for popup in [
		task_popup,
		automation_report_dialog,
		purchase_receipt_dialog,
		recipe_restock_dialog,
		showcase_round_settlement_dialog,
		recipe_growth_choice_dialog,
		storefront_challenge_dialog,
		storefront_recent_report_dialog,
		showcase_rulebook_dialog,
		research_progress_dialog,
		research_tool_picker_popup
	]:
		if is_instance_valid(popup) and popup.visible:
			return true
	return false


func _on_tutorial_skip_requested() -> void:
	if not TutorialProgress.skip_current_step(state):
		return
	_save_game()
	_set_status("已隐藏本步提示；真正完成本步操作后才会开放下一项。")
	_refresh_tutorial_guide()


func _on_tutorial_dialogue_acknowledged() -> void:
	if not TutorialProgress.is_guide_active(state):
		return
	var step := String(state.tutorial_guide_step)
	if step == TutorialProgress.STEP_COMPLETE:
		return
	state.tutorial_guide_dialogue_acknowledged_step = step
	_save_game()
	if _tutorial_page_opens_from_dialogue_action(step):
		var destination := _tutorial_required_page(step)
		if not destination.is_empty() and not _is_workbench_destination_active(destination):
			_open_workbench_destination(destination)
			call_deferred("_refresh_tutorial_guide")


func _on_tutorial_close_requested() -> void:
	if not TutorialProgress.close_guide(state):
		return
	_save_game()
	tutorial_guide_overlay.call("hide_guide")
	_set_status("新手引导已关闭，可以继续自由经营。")


func _on_tutorial_restart_requested() -> void:
	if not TutorialProgress.restart_guide(state):
		return
	_save_game()
	_set_status("新手引导已重新开始，游戏进度保持不变。")
	_refresh_tutorial_guide()


func _on_storefront_manage_pressed() -> void:
	if not _require_core_feature(CoreFeatureUnlockService.STOREFRONT_MANAGE):
		return
	if _close_if_global_popup_mode("storefront_manage"):
		return
	var guide_advanced := TutorialProgress.on_storefront_viewed(state)
	_show_storefront_manage_global_popup()
	if guide_advanced:
		_save_game()
		if String(state.tutorial_guide_step) == TutorialProgress.STEP_COMPLETE:
			_set_status("第一轮真实经营已完成，听听外婆最后的叮嘱吧。")
		else:
			_set_status("请完成本轮真实结算；至少售出 1 件商品后，外婆会进行最后说明。")
	_refresh_tutorial_guide()


func _show_storefront_manage_global_popup() -> void:
	_open_global_popup_mode("storefront_manage")
	storefront_manage_overlay.call("reset_to_default_tab")
	_refresh_storefront_manage_page()


func _apply_initial_status() -> void:
	var ready_count := _offline_ready_count()
	if ready_count > 0:
		_set_status("离线期间有 %d 个产出已成熟，请到产出页手动收获。" % ready_count)
	else:
		_set_status("选择采购食材开始第一轮研发。")


func _refresh_current_page() -> void:
	_refresh_resource_bar()
	_refresh_production_workbench()
	_refresh_research_overlay()
	match global_popup_mode:
		"purchase":
			_refresh_purchase_page()
		"output":
			_refresh_output_page()
		"storefront_manage":
			_refresh_storefront_manage_page()
	_refresh_feedback_log()
	_refresh_storefront()
	call_deferred("_refresh_tutorial_guide")


func _offline_ready_count() -> int:
	if state == null:
		return 0
	return maxi(0, int(state.offline_ready_count))


func _evaluate_output_ready_state() -> void:
	if state == null:
		return

	ProductionSite.evaluate_slots(state)
	if _offline_ready_count() > 0:
		state.offline_ready_count = _ready_output_slot_count()


func _ready_output_slot_count(now_unix: int = -1) -> int:
	if state == null:
		return 0

	var ready_count := 0
	for index in range(state.production_slots.size()):
		if ProductionSite.is_slot_ready(state, index, now_unix):
			ready_count += 1
	return ready_count


func _active_output_total_count(now_unix: int = -1) -> int:
	if state == null:
		return 0
	var active_count := 0
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if slot_value is Dictionary and not ProductionSite.is_slot_ready(state, index, now_unix):
			active_count += 1
	return active_count


func _idle_output_total_count() -> int:
	var idle_count := 0
	for site_id in OUTPUT_SITE_ORDER:
		idle_count += _output_site_idle_count(site_id)
	return idle_count


func _refresh_purchase_page(_preferred_metadata: String = "") -> void:
	purchase_page_description.text = "采购｜六个来源同时补货，底部统一结算。"
	var snapshot := _refresh_purchase_regions()
	_update_purchase_cart_summary(snapshot)
	purchase_page_refresh_pending = false


func _bind_purchase_regions() -> void:
	purchase_regions_by_category.clear()
	for region_value in purchase_regions_grid.get_children():
		var region := region_value as Control
		if region == null:
			continue
		var category := String(region.get("category_id"))
		if category.is_empty():
			continue
		purchase_regions_by_category[category] = region
		var handler := Callable(self, "_on_purchase_cart_quantity_pressed")
		if region.has_signal("quantity_delta_requested") and not region.is_connected("quantity_delta_requested", handler):
			region.connect("quantity_delta_requested", handler)


func _refresh_purchase_regions() -> Dictionary:
	var snapshot := _purchase_cart_snapshot()
	for category_value in PURCHASE_REGION_ORDER:
		var category := String(category_value)
		var region := purchase_regions_by_category.get(category) as Control
		if region != null:
			var region_open := _is_purchase_region_open(category)
			region.call(
				"populate",
				_purchase_region_entries(category, snapshot),
				not region_open,
				ProgressionAccessService.level_lock_text(ProgressionAccessService.purchase_region_level(category))
			)
	return snapshot


func _purchase_region_entries(category: String, snapshot: Dictionary = {}) -> Array[Dictionary]:
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	var entries: Array[Dictionary] = []
	if not _is_purchase_region_open(category):
		return entries
	for item_key in _purchase_region_item_keys(category):
		if not _is_purchase_cart_item_available(item_key, actual_snapshot):
			continue
		_ensure_purchase_cart_quantity(item_key)
		entries.append({
			"item_key": item_key,
			"name": _purchase_cart_item_name(item_key, actual_snapshot),
			"price": _purchase_cart_item_price(item_key, actual_snapshot),
			"stock": _purchase_cart_item_stock(item_key),
			"quantity": _purchase_cart_quantity(item_key),
			"can_increase": _can_increase_purchase_cart_item(item_key, actual_snapshot)
		})
	return entries


func _purchase_region_item_keys(category: String) -> Array[String]:
	if category == "工具":
		var tool_keys: Array[String] = []
		var tools := catalog.get_tools()
		for tool_id in _sorted_keys(tools):
			var tool: Dictionary = tools[tool_id]
			if String(tool.get("tool_kind", "")) == "accelerator":
				tool_keys.append("%s%s" % [TOOL_METADATA_PREFIX, tool_id])
		return tool_keys
	return _purchase_candidate_item_ids(category)


func _purchase_candidate_item_ids(category: String) -> Array[String]:
	match category:
		"辅料":
			return _purchase_supply_item_ids()
		"农场":
			return _purchase_site_item_ids("farm")
		"养殖场":
			return _purchase_ranch_item_ids()
		"林场":
			return _purchase_site_item_ids("forest")
		"水塘":
			return _purchase_site_item_ids("pond")
		_:
			return []


func _purchase_supply_item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	var ingredients := catalog.get_ingredients()
	for item_id in _sorted_keys(ingredients):
		var ingredient: Dictionary = ingredients[item_id]
		if String(ingredient.get("purchase_category", "")) != "配料":
			continue
		if _is_ingredient_purchase_candidate(item_id, ingredient):
			item_ids.append(item_id)
	return item_ids


func _purchase_ranch_item_ids() -> Array[String]:
	var item_ids := _purchase_site_item_ids("ranch")
	var ingredients := catalog.get_ingredients()
	for item_id in _sorted_keys(ingredients):
		var ingredient: Dictionary = ingredients[item_id]
		if String(ingredient.get("purchase_category", "")) != "畜牧":
			continue
		if _is_ingredient_purchase_candidate(item_id, ingredient) and not item_ids.has(item_id):
			item_ids.append(item_id)
	return item_ids


func _purchase_site_item_ids(site_id: String) -> Array[String]:
	var item_ids: Array[String] = []
	var ingredients := catalog.get_ingredients()
	var sites := catalog.get_production_sites()
	var site: Dictionary = sites.get(site_id, {})
	for item_id_value: Variant in site.get("items", []):
		var item_id := String(item_id_value)
		var ingredient: Dictionary = ingredients.get(item_id, {})
		if ingredient.is_empty():
			continue
		if _is_ingredient_purchase_candidate(item_id, ingredient):
			item_ids.append(item_id)
	return item_ids


func _is_ingredient_purchase_candidate(item_id: String, ingredient: Dictionary) -> bool:
	if ingredient.is_empty():
		return false
	if bool(ingredient.get("purchasable", true)):
		return true
	return state.has_method("is_ingredient_purchase_unlocked") and state.is_ingredient_purchase_unlocked(item_id)


func _is_purchase_region_open(category: String) -> bool:
	return ProgressionAccessService.is_purchase_region_open(category, int(state.level))


func _purchase_shortage_item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	var seen := {}
	for item_id in _recipe_material_purchase_shortage_ids():
		if not seen.has(item_id):
			item_ids.append(item_id)
			seen[item_id] = true
	for item_id in _showcase_restock_purchase_ids():
		if not seen.has(item_id):
			item_ids.append(item_id)
			seen[item_id] = true
	if item_ids.is_empty():
		for item_id in _purchase_supply_item_ids():
			if not seen.has(item_id):
				item_ids.append(item_id)
				seen[item_id] = true
			if item_ids.size() >= 6:
				break
	return item_ids


func _purchase_locked_shortage_item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	var ingredients := catalog.get_ingredients()
	for item_id in _recipe_material_purchase_shortage_ids(false):
		var ingredient: Dictionary = ingredients.get(item_id, {})
		if ingredient.is_empty() or _is_ingredient_available_for_purchase(item_id, ingredient):
			continue
		if int(ingredient.get("unlock_level", 1)) == state.level + 1:
			item_ids.append(item_id)
	return item_ids


func _recipe_material_purchase_shortage_ids(available_only: bool = true) -> Array[String]:
	var item_ids: Array[String] = []
	var seen := {}
	for recipe_id in _unlocked_recipe_ids():
		var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
		for material_value: Variant in recipe.get("materials", []):
			var material_id := String(material_value)
			if state.get_ingredient_count(material_id) >= 2:
				continue
			var purchase_id := _purchase_source_item_id_for_material(material_id, available_only)
			if purchase_id.is_empty() or seen.has(purchase_id):
				continue
			item_ids.append(purchase_id)
			seen[purchase_id] = true
	return item_ids


func _showcase_restock_purchase_ids() -> Array[String]:
	var item_ids: Array[String] = []
	var seen := {}
	for recipe_id in _showcase_bonus_recipe_ids(_current_showcase_bonuses()):
		if state.get_product_count(recipe_id) > 2:
			continue
		var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
		for material_value: Variant in recipe.get("materials", []):
			var purchase_id := _purchase_source_item_id_for_material(String(material_value))
			if purchase_id.is_empty() or seen.has(purchase_id):
				continue
			item_ids.append(purchase_id)
			seen[purchase_id] = true
	return item_ids


func _purchase_source_item_id_for_material(material_id: String, available_only: bool = true) -> String:
	var ingredients := catalog.get_ingredients()
	var direct: Dictionary = ingredients.get(material_id, {})
	if not direct.is_empty() and bool(direct.get("purchasable", true)):
		if not available_only or _is_ingredient_available_for_purchase(material_id, direct):
			return material_id
	for candidate_id in _sorted_keys(ingredients):
		var candidate: Dictionary = ingredients[candidate_id]
		if not bool(candidate.get("purchasable", true)):
			continue
		if String(candidate.get("harvest_item_id", "")) == material_id:
			if not available_only or _is_ingredient_available_for_purchase(candidate_id, candidate):
				return candidate_id
		var harvest_outputs: Dictionary = candidate.get("harvest_outputs", {})
		if harvest_outputs.has(material_id):
			if not available_only or _is_ingredient_available_for_purchase(candidate_id, candidate):
				return candidate_id
	return ""


func _is_ingredient_available_for_purchase(item_id: String, ingredient: Dictionary) -> bool:
	if ingredient.is_empty() or int(ingredient.get("unlock_level", 1)) > state.level:
		return false
	var region_id := _purchase_region_for_ingredient(ingredient)
	if not region_id.is_empty() and not _is_purchase_region_open(region_id):
		return false
	if bool(ingredient.get("purchasable", true)):
		return true
	return state.has_method("is_ingredient_purchase_unlocked") and state.is_ingredient_purchase_unlocked(item_id)


func _purchase_region_for_ingredient(ingredient: Dictionary) -> String:
	match String(ingredient.get("purchase_category", "")):
		"农作":
			return "农场"
		"水果":
			return "林场"
		"畜牧":
			return "养殖场"
		"水塘":
			return "水塘"
		"配料":
			return "辅料"
	return ""


func _ensure_purchase_cart_quantity(item_key: String) -> void:
	if purchase_cart_quantities.has(item_key):
		return
	purchase_cart_quantities[item_key] = 0


func _on_purchase_cart_quantity_pressed(item_key: String, delta: int) -> void:
	var snapshot := _purchase_cart_snapshot()
	if delta > 0 and not _can_increase_purchase_cart_item(item_key, snapshot):
		var category := _purchase_region_for_item_key(item_key, snapshot)
		if not _is_purchase_cart_item_available(item_key, snapshot):
			_set_status(_purchase_cart_item_locked_text(item_key, category))
		else:
			_set_status("金币不足，购物车总额已达上限。")
		_refresh_purchase_region_item_states(snapshot)
		call_deferred("_refresh_tutorial_guide")
		return
	var next_quantity := maxi(0, _purchase_cart_quantity(item_key) + delta)
	purchase_cart_quantities[item_key] = next_quantity
	var refreshed_snapshot := _purchase_cart_snapshot(
		snapshot["ingredients"] as Dictionary,
		snapshot["tools"] as Dictionary
	)
	_refresh_purchase_region_item_states(refreshed_snapshot)
	call_deferred("_refresh_tutorial_guide")


func _refresh_purchase_region_item_states(snapshot: Dictionary = {}) -> void:
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	for region_value in purchase_regions_by_category.values():
		var region := region_value as Control
		if region == null:
			continue
		for row_value: Variant in region.call("item_rows"):
			var row := row_value as Control
			if row == null:
				continue
			var item_key := String(row.get_meta("purchase_cart_item_key", ""))
			if item_key.is_empty():
				continue
			row.call(
				"update_state",
				_purchase_cart_item_stock(item_key),
				_purchase_cart_quantity(item_key),
				_can_increase_purchase_cart_item(item_key, actual_snapshot)
			)
	_update_purchase_cart_summary(actual_snapshot)


func _purchase_region_for_item_key(item_key: String, snapshot: Dictionary = {}) -> String:
	if item_key.begins_with(TOOL_METADATA_PREFIX):
		return "工具"
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	var ingredients: Dictionary = actual_snapshot["ingredients"]
	var ingredient: Dictionary = ingredients.get(item_key, {})
	return _purchase_region_for_ingredient(ingredient)


func _purchase_cart_quantity(item_key: String) -> int:
	return maxi(0, int(purchase_cart_quantities.get(item_key, 0)))


func _can_increase_purchase_cart_item(item_key: String, snapshot: Dictionary = {}) -> bool:
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	if not _is_purchase_cart_item_available(item_key, actual_snapshot):
		return false
	var price := _purchase_cart_item_price(item_key, actual_snapshot)
	if price <= 0:
		return true
	return int(actual_snapshot.get("total_cost", 0)) + price <= int(state.coins)


func _update_purchase_cart_summary(snapshot: Dictionary = {}) -> void:
	if purchase_cart_label == null:
		return
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	var total_units := int(actual_snapshot.get("total_units", 0))
	var total_cost := int(actual_snapshot.get("total_cost", 0))
	purchase_cart_label.text = "购物车：%d 件｜合计:%d 金币" % [total_units, total_cost]
	purchase_confirm_button.disabled = total_units <= 0 or total_cost > int(state.coins)


func _purchase_cart_total_units(snapshot: Dictionary = {}) -> int:
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	return int(actual_snapshot.get("total_units", 0))


func _purchase_cart_total_cost(snapshot: Dictionary = {}) -> int:
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	return int(actual_snapshot.get("total_cost", 0))


func _purchase_cart_entries(snapshot: Dictionary = {}) -> Array[String]:
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	var entries: Array[String] = []
	for item_key_value: Variant in actual_snapshot.get("entries", []):
		entries.append(String(item_key_value))
	return entries


func _purchase_cart_snapshot(
	ingredients: Dictionary = {},
	tools: Dictionary = {}
) -> Dictionary:
	var actual_ingredients := ingredients if not ingredients.is_empty() else catalog.get_ingredients()
	var actual_tools := tools if not tools.is_empty() else catalog.get_tools()
	var entries: Array[String] = []
	var total_units := 0
	var total_cost := 0
	for item_key_value: Variant in purchase_cart_quantities.keys():
		var item_key := String(item_key_value)
		if not _is_purchase_cart_item_available_with_catalog(item_key, actual_ingredients, actual_tools):
			continue
		var quantity := _purchase_cart_quantity(item_key)
		total_units += quantity
		total_cost += quantity * _purchase_cart_item_price_with_catalog(item_key, actual_ingredients, actual_tools)
		if quantity > 0:
			entries.append(item_key)
	entries.sort()
	return {
		"ingredients": actual_ingredients,
		"tools": actual_tools,
		"entries": entries,
		"total_units": total_units,
		"total_cost": total_cost
	}


func _is_purchase_cart_item_available(item_key: String, snapshot: Dictionary = {}) -> bool:
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	return _is_purchase_cart_item_available_with_catalog(
		item_key,
		actual_snapshot["ingredients"] as Dictionary,
		actual_snapshot["tools"] as Dictionary
	)


func _is_purchase_cart_item_available_with_catalog(
	item_key: String,
	ingredients: Dictionary,
	tools: Dictionary
) -> bool:
	if item_key.begins_with(TOOL_METADATA_PREFIX):
		var tool_id := item_key.substr(TOOL_METADATA_PREFIX.length())
		var tool: Dictionary = tools.get(tool_id, {})
		return _is_purchase_region_open("工具") \
			and _is_tool_available_for_display(tool_id, tool) \
			and String(tool.get("tool_kind", "")) == "accelerator"
	var ingredient: Dictionary = ingredients.get(item_key, {})
	return _is_ingredient_available_for_purchase(item_key, ingredient)


func _purchase_cart_item_price(item_key: String, snapshot: Dictionary = {}) -> int:
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	return _purchase_cart_item_price_with_catalog(
		item_key,
		actual_snapshot["ingredients"] as Dictionary,
		actual_snapshot["tools"] as Dictionary
	)


func _purchase_cart_item_price_with_catalog(
	item_key: String,
	ingredients: Dictionary,
	tools: Dictionary
) -> int:
	if item_key.begins_with(TOOL_METADATA_PREFIX):
		var tool_id := item_key.substr(TOOL_METADATA_PREFIX.length())
		var tool: Dictionary = tools.get(tool_id, {})
		return maxi(0, int(tool.get("price", 0)))
	var ingredient: Dictionary = ingredients.get(item_key, {})
	return maxi(0, int(ingredient.get("price", 0)))


func _purchase_cart_item_name(item_key: String, snapshot: Dictionary = {}) -> String:
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	var ingredients: Dictionary = actual_snapshot["ingredients"]
	var tools: Dictionary = actual_snapshot["tools"]
	if item_key.begins_with(TOOL_METADATA_PREFIX):
		var tool_id := item_key.substr(TOOL_METADATA_PREFIX.length())
		var tool: Dictionary = tools.get(tool_id, {})
		return String(tool.get("name", tool_id))
	var ingredient: Dictionary = ingredients.get(item_key, {})
	return String(ingredient.get("name", item_key))


func _purchase_cart_item_locked_text(item_key: String, category: String) -> String:
	var region_level := ProgressionAccessService.purchase_region_level(category)
	if int(state.level) < region_level:
		return ProgressionAccessService.level_lock_text(region_level)
	var unlock_level := 0
	if item_key.begins_with(TOOL_METADATA_PREFIX):
		var tool_id := item_key.substr(TOOL_METADATA_PREFIX.length())
		unlock_level = int((catalog.get_tools().get(tool_id, {}) as Dictionary).get("unlock_level", 1))
	else:
		unlock_level = int((catalog.get_ingredients().get(item_key, {}) as Dictionary).get("unlock_level", 1))
	if int(state.level) < unlock_level:
		return ProgressionAccessService.level_lock_text(unlock_level)
	return "🔒 完成对应经营进度后开放"


func _purchase_cart_item_stock(item_key: String) -> int:
	if item_key.begins_with(TOOL_METADATA_PREFIX):
		return state.get_tool_count(item_key.substr(TOOL_METADATA_PREFIX.length()))
	return state.get_ingredient_count(item_key)


func _refresh_output_page() -> void:
	_evaluate_output_ready_state()
	_refresh_output_page_description()
	var ready_count := _ready_output_slot_count()
	output_scroll.visible = true
	output_grid_row.visible = true
	if is_instance_valid(active_output_grid):
		active_output_grid.visible = false
	if is_instance_valid(output_bag_tabs):
		output_bag_tabs.visible = false
	if is_instance_valid(unlocked_output_grid):
		unlocked_output_grid.visible = false
	output_primary_action_button.visible = _is_harvest_all_unlocked()
	output_primary_action_button.text = "一键收获"
	output_primary_action_button.disabled = ready_count <= 0
	output_primary_action_button.tooltip_text = ""

	_refresh_output_grids()


func _fill_output_bag_tabs() -> void:
	if not is_instance_valid(output_bag_tabs):
		return
	output_bag_tabs.set_block_signals(true)
	output_bag_tabs.clear_tabs()
	for page_index in range(OUTPUT_BAG_PAGE_COUNT):
		output_bag_tabs.add_tab("背包%d" % (page_index + 1))
		output_bag_tabs.set_tab_metadata(page_index, page_index)
	selected_output_bag_page = clampi(selected_output_bag_page, 0, OUTPUT_BAG_PAGE_COUNT - 1)
	output_bag_tabs.current_tab = selected_output_bag_page
	output_bag_tabs.set_block_signals(false)


func _setup_output_drag_forwarding() -> void:
	if is_instance_valid(active_output_grid):
		active_output_grid.set_drag_forwarding(
			Callable(self, "_get_output_grid_drag_data"),
			Callable(self, "_can_drop_output_on_active_grid"),
			Callable(self, "_drop_output_on_active_grid")
		)
	if is_instance_valid(unlocked_output_grid):
		unlocked_output_grid.set_drag_forwarding(
			Callable(self, "_get_output_grid_drag_data"),
			Callable(self, "_can_drop_output_on_unlocked_grid"),
			Callable(self, "_drop_output_on_unlocked_grid")
		)


func _get_output_grid_drag_data(_at_position: Vector2, _from_control: Control = null) -> Variant:
	return null


func _can_drop_output_on_active_grid(_at_position: Vector2, data: Variant, _from_control: Control = null) -> bool:
	return _can_drop_output_data("active", data)


func _drop_output_on_active_grid(_at_position: Vector2, data: Variant, _from_control: Control = null) -> void:
	_drop_output_data("active", data)


func _can_drop_output_on_unlocked_grid(_at_position: Vector2, data: Variant, _from_control: Control = null) -> bool:
	return _can_drop_output_data("unlocked", data)


func _drop_output_on_unlocked_grid(_at_position: Vector2, data: Variant, _from_control: Control = null) -> void:
	_drop_output_data("unlocked", data)


func _can_drop_output_data(target_kind: String, data: Variant) -> bool:
	if global_popup_mode != "output":
		return false
	if selected_output_site_id.is_empty() or not data is Dictionary:
		return false

	var drag_data: Dictionary = data
	var kind := String(drag_data.get("kind", ""))
	if target_kind == "active":
		if kind != "unlocked" or String(drag_data.get("site_id", "")) != selected_output_site_id:
			return false
		var item_id := String(drag_data.get("item_id", ""))
		var target_slot_index := int(drag_data.get("target_slot_index", -1))
		if target_slot_index < 0:
			target_slot_index = _first_idle_output_slot_index(selected_output_site_id)
		return _output_item_belongs_to_site(item_id, selected_output_site_id) \
				and target_slot_index >= 0 \
				and target_slot_index < _unlocked_output_slot_count(selected_output_site_id) \
				and _slot_array_index_for_site_slot(selected_output_site_id, target_slot_index) == -1

	if target_kind == "unlocked":
		if kind != "active" or String(drag_data.get("site_id", "")) != selected_output_site_id:
			return false
		var slot_index := int(drag_data.get("slot_index", -1))
		if slot_index < 0 or slot_index >= state.production_slots.size():
			return false
		var slot_value: Variant = state.production_slots[slot_index]
		if not slot_value is Dictionary:
			return false
		var slot: Dictionary = slot_value
		return _is_output_slot_for_site(slot, selected_output_site_id) \
				and String(slot.get("item_id", "")) == String(drag_data.get("item_id", "")) \
				and int(slot.get("started_at_unix", -1)) == int(drag_data.get("started_at_unix", -2))

	return false


func _drop_output_data(target_kind: String, data: Variant) -> bool:
	if not _can_drop_output_data(target_kind, data):
		return false

	var drag_data: Dictionary = data
	if target_kind == "active":
		return _drop_output_item_to_active(String(drag_data.get("item_id", "")), int(drag_data.get("target_slot_index", -1)))
	if target_kind == "unlocked":
		return _drop_output_slot_to_unlocked(int(drag_data.get("slot_index", -1)))
	return false


func _refresh_output_grids() -> void:
	_evaluate_output_ready_state()
	output_site_grids.clear()
	output_site_title_labels.clear()
	active_output_grid = null
	output_grid_row.columns = OUTPUT_REGION_GRID_COLUMNS
	var sites := catalog.get_production_sites()
	for child in output_grid_row.get_children():
		output_grid_row.remove_child(child)
		child.queue_free()
	for site_id in OUTPUT_SITE_ORDER:
		if not sites.has(site_id):
			continue
		output_grid_row.add_child(output_overlay.call("create_site_region", self, site_id))
	_update_output_action_buttons()


func _populate_output_site_grid(site_id: String, grid: GridContainer) -> void:
	output_site_grids[site_id] = grid
	if not _is_output_site_available(site_id):
		for slot_index in range(OUTPUT_SITE_CELLS_PER_PAGE):
			grid.add_child(_make_locked_output_site_cell(site_id, slot_index))
		return
	var unlocked_slots := _unlocked_output_slot_count(site_id)
	var page_index := _output_site_page_index(site_id)
	var first_slot_index := page_index * OUTPUT_SITE_CELLS_PER_PAGE
	var last_slot_index := mini(OUTPUT_SLOT_COUNT, first_slot_index + OUTPUT_SITE_CELLS_PER_PAGE)
	for slot_index in range(first_slot_index, last_slot_index):
		if slot_index >= unlocked_slots:
			grid.add_child(_make_locked_output_slot_cell(site_id, slot_index))
			continue
		var slot_array_index := _slot_array_index_for_site_slot(site_id, slot_index)
		if slot_array_index == -1:
			grid.add_child(_make_idle_output_slot_cell(site_id, slot_index))
			continue
		var slot_value: Variant = state.production_slots[slot_array_index]
		if slot_value is Dictionary:
			var slot: Dictionary = slot_value
			grid.add_child(_make_active_output_cell(slot_array_index, slot))
		else:
			grid.add_child(_make_idle_output_slot_cell(site_id, slot_index))


func _output_site_production_summary(site_id: String, now_unix: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state == null or not OUTPUT_SITE_ORDER.has(site_id):
		return result
	var current_time := int(Time.get_unix_time_from_system()) if now_unix < 0 else now_unix
	var summary_by_item := {}
	var item_order: Array[String] = []
	for slot_array_index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[slot_array_index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		if String(slot.get("site_id", "")) != site_id:
			continue
		if bool(slot.get("automation_paused", false)) \
				and int(slot.get("started_at_unix", 0)) <= 0 \
				and int(slot.get("ready_at_unix", 0)) <= 0:
			continue
		var site_slot_index := int(slot.get("slot_index", -1))
		if site_slot_index < 0 or site_slot_index >= OUTPUT_SLOT_COUNT:
			continue
		var item_id := String(slot.get("item_id", ""))
		var harvest_outputs := ProductionSite.harvest_outputs_for(site_id, item_id)
		var is_ready := ProductionSite.is_slot_ready(state, slot_array_index, current_time)
		for output_id_value: Variant in harvest_outputs.keys():
			var output_id := String(output_id_value)
			var amount := maxi(0, int(harvest_outputs.get(output_id_value, 0)))
			if output_id.is_empty() or amount <= 0:
				continue
			if not summary_by_item.has(output_id):
				summary_by_item[output_id] = {
					"item_id": output_id,
					"name": _ingredient_name(output_id),
					"ready_amount": 0,
					"producing_amount": 0
				}
				item_order.append(output_id)
			var entry: Dictionary = summary_by_item[output_id]
			var amount_key := "ready_amount" if is_ready else "producing_amount"
			entry[amount_key] = int(entry.get(amount_key, 0)) + amount
			summary_by_item[output_id] = entry
	for output_id in item_order:
		result.append(summary_by_item[output_id])
	return result


func _site_region_title(site_id: String, now_unix: int = -1) -> String:
	if not _is_output_site_available(site_id):
		return "🔒 %s · Lv.%d 开放" % [_site_name(site_id), ProgressionAccessService.output_site_level(site_id)]
	return "%s  可收:%d  进行:%d  空闲:%d" % [
		_site_name(site_id),
		_output_site_ready_count(site_id, now_unix),
		_output_site_active_count(site_id, now_unix),
		_output_site_idle_count(site_id)
	]


func _refresh_output_page_description(now_unix: int = -1) -> void:
	output_page_description.text = "挂机产出｜可收 %d｜进行 %d｜空闲 %d" % [
		_ready_output_slot_count(now_unix),
		_active_output_total_count(now_unix),
		_idle_output_total_count()
	]


func _refresh_output_site_titles(now_unix: int = -1) -> void:
	for site_id_value: Variant in output_site_title_labels.keys():
		var site_id := String(site_id_value)
		var label_value: Variant = output_site_title_labels.get(site_id)
		if label_value is Label:
			var refreshed_title := _site_region_title(site_id, now_unix)
			(label_value as Label).text = refreshed_title
			(label_value as Label).tooltip_text = refreshed_title


func _refresh_output_site_summaries(now_unix: int = -1) -> void:
	for region_value: Variant in output_grid_row.get_children():
		if region_value is Control and (region_value as Control).has_method("refresh_production_summary"):
			(region_value as Control).call("refresh_production_summary", now_unix)


func _output_site_page_label(site_id: String) -> String:
	return "%d/%d" % [_output_site_page_index(site_id) + 1, OUTPUT_SITE_PAGE_COUNT]


func _is_output_site_prev_page_available(site_id: String) -> bool:
	return _output_site_page_index(site_id) > 0


func _is_output_site_next_page_available(site_id: String) -> bool:
	return _output_site_page_index(site_id) < OUTPUT_SITE_PAGE_COUNT - 1


func _change_output_site_page(site_id: String, delta: int) -> void:
	if not OUTPUT_SITE_ORDER.has(site_id):
		return
	output_site_pages[site_id] = clampi(_output_site_page_index(site_id) + delta, 0, OUTPUT_SITE_PAGE_COUNT - 1)
	_refresh_output_grids()


func _output_site_page_index(site_id: String) -> int:
	return clampi(int(output_site_pages.get(site_id, 0)), 0, OUTPUT_SITE_PAGE_COUNT - 1)


func _output_site_item_ids(site_id: String) -> Array[String]:
	var item_ids: Array[String] = []
	if not _is_output_site_available(site_id):
		return item_ids
	var sites := catalog.get_production_sites()
	var ingredients := catalog.get_ingredients()
	var site: Dictionary = sites.get(site_id, {})
	for item_id_value in site.get("items", []):
		var item_id := String(item_id_value)
		var ingredient: Dictionary = ingredients.get(item_id, {})
		if ingredient.is_empty() or int(ingredient.get("unlock_level", 1)) > state.level:
			continue
		item_ids.append(item_id)
	return item_ids


func _is_output_site_available(site_id: String) -> bool:
	return ProgressionAccessService.is_output_site_open(site_id, int(state.level))


func _output_site_locked_text(site_id: String) -> String:
	return ProgressionAccessService.level_lock_text(ProgressionAccessService.output_site_level(site_id))


func _make_active_output_cell(slot_array_index: int, slot: Dictionary) -> Button:
	var item_id := String(slot.get("item_id", ""))
	var site_id := String(slot.get("site_id", ""))
	var slot_index := int(slot.get("slot_index", slot_array_index))
	var button := _make_output_cell_button("")
	_update_output_progress_bar(button, _output_slot_progress_fraction(slot, int(Time.get_unix_time_from_system())))
	button.set_meta("output_kind", "active")
	button.set_meta("site_id", site_id)
	button.set_meta("slot_index", slot_index)
	button.set_meta("slot_array_index", slot_array_index)
	button.set_meta("item_id", item_id)
	_configure_active_output_products(button, site_id, item_id)
	_configure_active_output_automation(button, slot)
	button.configure_drag({
		"kind": "active",
		"slot_index": slot_array_index,
		"site_slot_index": slot_index,
		"site_id": site_id,
		"item_id": item_id,
		"started_at_unix": int(slot.get("started_at_unix", -1))
	}, _ingredient_name(item_id))
	button.pressed.connect(_on_output_slot_pressed.bind(site_id, slot_index, slot_array_index, button))
	button.gui_input.connect(_on_output_cell_gui_input.bind("active", {"site_id": site_id, "slot_index": slot_index, "slot_array_index": slot_array_index}))
	return button


func _configure_active_output_products(button: Button, site_id: String, item_id: String) -> void:
	if not button.has_method("configure_products"):
		return
	button.configure_products(_active_output_products(site_id, item_id))


func _active_output_products(site_id: String, item_id: String) -> Array[Dictionary]:
	var output_amounts := ProductionSite.harvest_outputs_for(site_id, item_id)
	if output_amounts.is_empty() and not item_id.is_empty():
		var site: Dictionary = catalog.get_production_sites().get(site_id, {})
		output_amounts[item_id] = maxi(1, int(site.get("yield_amount", 1)))
	var products: Array[Dictionary] = []
	for output_id_value: Variant in output_amounts.keys():
		var output_id := String(output_id_value)
		var amount := int(output_amounts.get(output_id_value, 0))
		if output_id.is_empty() or amount <= 0:
			continue
		products.append(_output_product_entry(output_id, amount))
	return products


func _output_product_entry(output_id: String, amount: int) -> Dictionary:
	return {
		"id": output_id,
		"name": _ingredient_name(output_id),
		"amount": amount,
		"texture": _ingredient_icon_texture(output_id)
	}


func _make_idle_output_slot_cell(site_id: String, slot_index: int) -> Button:
	var button := _make_output_cell_button("闲置中\n左键选择产出\n右键加速器")
	button.set_meta("output_kind", "idle")
	button.set_meta("site_id", site_id)
	button.set_meta("slot_index", slot_index)
	button.pressed.connect(_on_output_slot_pressed.bind(site_id, slot_index, -1, button))
	button.gui_input.connect(_on_output_cell_gui_input.bind("idle", {"site_id": site_id, "slot_index": slot_index, "slot_array_index": -1}))
	return button


func _make_locked_output_slot_cell(site_id: String, slot_index: int) -> Button:
	var cost := _output_slot_unlock_cost(slot_index)
	var button := _make_output_cell_button("待解锁\n金币:%d" % cost)
	button.set_meta("output_kind", "locked_slot")
	button.set_meta("site_id", site_id)
	button.set_meta("slot_index", slot_index)
	button.pressed.connect(_unlock_output_slot.bind(site_id, slot_index))
	return button


func _make_locked_output_site_cell(site_id: String, slot_index: int) -> Button:
	var locked_text := _output_site_locked_text(site_id)
	var button := _make_output_cell_button("🔒\n%s" % locked_text)
	button.set_meta("output_kind", "locked_site")
	button.set_meta("site_id", site_id)
	button.set_meta("slot_index", slot_index)
	button.tooltip_text = locked_text
	button.pressed.connect(_set_status.bind(locked_text))
	return button


func _make_locked_output_bag_page_cell(page_index: int) -> Button:
	var cost := _output_bag_page_unlock_cost(page_index)
	var button := _make_output_cell_button("背包页待解锁\n金币:%d" % cost)
	button.set_meta("output_kind", "locked_bag_page")
	button.set_meta("bag_page", page_index)
	_configure_output_drop_target(button, "unlocked")
	button.pressed.connect(_unlock_output_bag_page.bind(page_index))
	return button


func _refresh_output_countdown_texts(now_unix: int = -1) -> void:
	if global_popup_mode != "output":
		return

	var current_time := int(Time.get_unix_time_from_system()) if now_unix < 0 else now_unix
	ProductionSite.evaluate_slots(state, current_time)
	_refresh_output_page_description(current_time)
	_refresh_output_site_titles(current_time)
	_refresh_output_site_summaries(current_time)
	for grid_value: Variant in output_site_grids.values():
		if not grid_value is GridContainer:
			continue
		var grid: GridContainer = grid_value
		for child in grid.get_children():
			if not child is Button:
				continue
			var button: Button = child
			if not button.has_meta("slot_array_index"):
				continue

			var slot_array_index := int(button.get_meta("slot_array_index"))
			if slot_array_index < 0 or slot_array_index >= state.production_slots.size():
				continue
			var slot_value: Variant = state.production_slots[slot_array_index]
			if not slot_value is Dictionary:
				continue

			var slot: Dictionary = slot_value
			_update_output_progress_bar(button, _output_slot_progress_fraction(slot, current_time))

	_update_output_action_buttons(current_time)


func _make_unlocked_output_cell(item_id: String, ingredient: Dictionary) -> Button:
	var usage := _research_usage_names(item_id)
	if usage.is_empty():
		usage = "暂无"
	var text := "%s\n耗时:%d秒\n可用于研发:%s\n库存:%d\n%s" % [
		String(ingredient.get("name", item_id)),
		ProductionSite.production_duration_seconds(state, selected_output_site_id, item_id),
		usage,
		state.get_ingredient_count(item_id),
		_accelerator_summary(item_id)
	]
	var button := _make_output_cell_button(text)
	button.set_meta("output_kind", "unlocked")
	button.set_meta("item_id", item_id)
	button.configure_drag({
		"kind": "unlocked",
		"item_id": item_id,
		"site_id": selected_output_site_id
	}, String(ingredient.get("name", item_id)))
	_configure_output_drop_target(button, "unlocked")
	button.pressed.connect(_select_output_item.bind(item_id))
	button.gui_input.connect(_on_output_cell_gui_input.bind("unlocked", item_id))
	return button


func _make_output_cell_button(text: String) -> Button:
	var button := OutputCellScene.instantiate() as Button
	button.text = text
	button.custom_minimum_size = OUTPUT_CELL_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 11)
	return button


func _configure_active_output_automation(button: Button, slot: Dictionary) -> void:
	if not button.has_method("configure_automation"):
		return
	var site_id := String(slot.get("site_id", ""))
	var managed: bool = state.is_output_site_managed(site_id)
	var available: bool = state.is_automation_unlocked("output") and managed
	var display := _output_automation_status(slot, managed)
	button.call("configure_automation", managed, available, String(display.get("text", "")), display.get("reason", {}))


func _output_automation_status(slot: Dictionary, managed: bool) -> Dictionary:
	if not managed:
		return {"text": "未托管", "reason": {}}
	if bool(state.automation_paused):
		return {
			"text": "已全局暂停",
			"reason": {
				"code": "global_paused",
				"next_step": "打开自动化中枢恢复全部自动化。"
			}
		}
	var reason: Dictionary = slot.get("pause_reason", {}) if slot.get("pause_reason", {}) is Dictionary else {}
	if not bool(slot.get("automation_paused", false)) and reason.is_empty():
		return {"text": "托管中", "reason": {}}
	var code := String(reason.get("code", ""))
	var item_id := String(reason.get("item_id", ""))
	var item_name := _ingredient_name(item_id) if not item_id.is_empty() else "所需原料"
	var status_text := "托管已暂停"
	var next_step := "检查该生产槽的启动条件后将自动继续。"
	match code:
		"missing_input":
			status_text = "缺少%s" % item_name
			next_step = "补充%s后将自动继续。" % item_name
		"insufficient_coins":
			var required := maxi(0, int(reason.get("required", 0)))
			var available := maxi(0, int(reason.get("available", 0)))
			var missing := maxi(0, required - available)
			status_text = "金币不足 %d" % missing
			next_step = "补足 %d 金币后将自动继续。" % missing
		"limit_reached":
			status_text = "托管产地已达上限"
			next_step = "关闭其他产地托管或在自动化中枢购买扩容。"
	var display_reason := reason.duplicate(true)
	display_reason["next_step"] = next_step
	return {"text": status_text, "reason": display_reason}


func _is_output_site_automation_available() -> bool:
	return state != null and state.is_automation_unlocked("output")


func _is_output_site_managed(site_id: String) -> bool:
	return state != null and state.is_output_site_managed(site_id)


func _output_site_automation_tooltip(site_id: String) -> String:
	if not _is_output_site_automation_available():
		return "完成“产地轮转”后解锁板块托管。"
	if _is_output_site_managed(site_id):
		return "已托管%s：自动收获并按各格的下一轮产物续产。" % _site_name(site_id)
	return "托管%s的所有已开工格子；空闲格不会自动开工。" % _site_name(site_id)


func _on_output_site_automation_toggled(site_id: String, managed: bool) -> void:
	if site_id.is_empty():
		_set_status("无法识别该产地，托管状态未改变。")
		_refresh_output_grids()
		return
	var result := AutomationService.set_output_site_managed(state, site_id, managed)
	if not bool(result.get("ok", false)):
		_set_status("托管切换失败：%s。" % String(result.get("reason", "未知原因")))
		_refresh_output_grids()
		return
	_save_game()
	_set_status("已开启%s板块托管。" % _site_name(site_id) if managed else "已关闭%s板块托管。" % _site_name(site_id))
	_refresh_output_grids()


func _update_output_progress_bar(button: Button, fraction: float) -> void:
	var clamped_fraction := clampf(fraction, 0.0, 1.0)
	button.set_meta("production_progress_fraction", clamped_fraction)
	var progress_bar := button.get_node_or_null("ProductionProgressBar")
	if progress_bar is ProgressBar:
		(progress_bar as ProgressBar).value = clamped_fraction


func _output_slot_progress_fraction(slot: Dictionary, now_unix: int) -> float:
	var duration := maxf(1.0, float(slot.get("duration_seconds", 1)))
	var started_at := float(slot.get("started_at_unix", now_unix))
	return clampf((float(now_unix) - started_at) / duration, 0.0, 1.0)


func _add_output_empty_cell(grid: GridContainer, text: String) -> void:
	var button := _make_output_cell_button(text)
	button.focus_mode = Control.FOCUS_NONE
	if grid == active_output_grid:
		_configure_output_drop_target(button, "active")
	elif grid == unlocked_output_grid:
		_configure_output_drop_target(button, "unlocked")
	grid.add_child(button)


func _configure_output_drop_target(button: Button, target_kind: String, target_data: Dictionary = {}) -> void:
	if button.has_method("configure_drop"):
		button.configure_drop(target_kind, Callable(self, "_can_drop_output_data"), Callable(self, "_drop_output_data"), target_data)


func _unlocked_output_slot_count(site_id: String) -> int:
	return clampi(int(state.production_slot_unlocks.get(site_id, 1)), 1, OUTPUT_SLOT_COUNT)


func _unlocked_output_bag_page_count(site_id: String) -> int:
	return clampi(int(state.production_bag_page_unlocks.get(site_id, 1)), 1, OUTPUT_BAG_PAGE_COUNT)


func _slot_array_index_for_site_slot(site_id: String, slot_index: int) -> int:
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		if String(slot.get("site_id", "")) == site_id and int(slot.get("slot_index", index)) == slot_index:
			return index
	return -1


func _first_idle_output_slot_index(site_id: String) -> int:
	for slot_index in range(_unlocked_output_slot_count(site_id)):
		if _slot_array_index_for_site_slot(site_id, slot_index) == -1:
			return slot_index
	return -1


func _output_slot_unlock_cost(slot_index: int) -> int:
	var costs := catalog.get_production_slot_unlock_costs()
	var cost_index := slot_index - 1
	if cost_index < 0:
		return 0
	if cost_index >= costs.size():
		return int(costs.back()) if not costs.is_empty() else 0
	return int(costs[cost_index])


func _output_bag_page_unlock_cost(page_index: int) -> int:
	var costs := catalog.get_production_bag_page_unlock_costs()
	var cost_index := page_index - 1
	if cost_index < 0 or cost_index >= costs.size():
		return 0
	return int(costs[cost_index])


func _unlock_output_slot(site_id: String, slot_index: int) -> void:
	selected_output_site_id = site_id
	if ProductionSite.unlock_site_slot(state, site_id, slot_index):
		_save_game()
		_set_status("已解锁 %s 第 %d 个生产格。" % [_site_name(site_id), slot_index + 1])
		_refresh_current_page()
	else:
		_set_status("无法解锁生产格：金币不足或前置格未解锁。")


func _unlock_output_bag_page(page_index: int) -> void:
	if ProductionSite.unlock_bag_page(state, selected_output_site_id, page_index):
		_save_game()
		_set_status("已解锁 %s 背包第 %d 页。" % [_site_name(selected_output_site_id), page_index + 1])
		_refresh_current_page()
	else:
		_set_status("无法解锁背包页：金币不足或前置页未解锁。")


func _select_output_item(item_id: String) -> void:
	selected_output_kind = "unlocked"
	selected_output_item_id = item_id
	selected_output_slot_index = -1
	selected_output_slot_array_index = -1
	_update_output_action_buttons()
	_set_status("已选择 %s，点击开始产出。" % _ingredient_name(item_id))


func _select_idle_output_slot(slot_index: int) -> void:
	selected_output_kind = "idle"
	selected_output_item_id = ""
	selected_output_slot_index = slot_index
	selected_output_slot_array_index = -1
	_update_output_action_buttons()
	_set_status("已选择闲置生产格，可从右侧拖入产物。")


func _select_output_slot(slot_index: int, slot_array_index: int) -> void:
	selected_output_kind = "active"
	selected_output_item_id = ""
	selected_output_slot_index = slot_index
	selected_output_slot_array_index = slot_array_index
	_update_output_action_buttons()
	if ProductionSite.is_slot_ready(state, slot_array_index):
		_set_status("产出已成熟，可手动收获。")
	else:
		_set_status("已选择产出槽位，成熟后可收获；拖回右侧可暂停。")


func _update_output_action_buttons(now_unix: int = -1) -> void:
	if global_popup_mode != "output":
		return
	output_primary_action_button.disabled = false
	output_primary_action_button.tooltip_text = ""
	if selected_output_kind == "unlocked":
		output_primary_action_button.visible = true
		output_primary_action_button.text = "开始产出"
	elif selected_output_kind == "active" and selected_output_slot_array_index >= 0:
		output_primary_action_button.visible = true
		output_primary_action_button.text = "收获产出" if ProductionSite.is_slot_ready(state, selected_output_slot_array_index, now_unix) else "检查成熟"
	else:
		output_primary_action_button.visible = _is_harvest_all_unlocked()
		output_primary_action_button.text = "一键收获"
		output_primary_action_button.disabled = _ready_output_slot_count(now_unix) <= 0


func _is_harvest_all_unlocked() -> bool:
	return state != null and state.is_feature_unlocked(HARVEST_ALL_FEATURE_ID)


func _harvest_all_progress_count() -> int:
	if state == null:
		return 0
	var progress_value: Variant = state.task_progress.get(HARVEST_ALL_TASK_ID, {})
	if not progress_value is Dictionary:
		return 0
	return clampi(int((progress_value as Dictionary).get("count", 0)), 0, HARVEST_ALL_TASK_GOAL)


func _apply_primary_output_action() -> void:
	if selected_output_kind == "unlocked":
		_start_output_item(selected_output_item_id)
	elif selected_output_kind == "active":
		_harvest_output_slot(selected_output_slot_array_index)
	else:
		_harvest_all_ready_outputs()


func _apply_secondary_output_action() -> void:
	_evaluate_output_ready_state()
	_set_status("产出状态已刷新。")


func _start_output_item(item_id: String, slot_index: int = -1) -> bool:
	return _start_output_item_in_site(selected_output_site_id, item_id, slot_index)


func _start_output_item_in_site(site_id: String, item_id: String, slot_index: int = -1) -> bool:
	if site_id.is_empty() or item_id.is_empty():
		_set_status("请选择产出地点和产出食材。")
		return false
	if slot_index < 0 and selected_output_kind == "idle":
		slot_index = selected_output_slot_index
	if ProductionSite.start_slot(state, site_id, item_id, slot_index):
		_set_status("已安排 %s 产出 %s。" % [_site_name(site_id), _ingredient_name(item_id)])
		return true

	var ingredient: Dictionary = catalog.get_ingredients().get(item_id, {})
	if String(ingredient.get("type", "")) == "种子" and state.get_ingredient_count(item_id) <= 0:
		_set_status("%s库存不足，请先采购种子。" % _ingredient_name(item_id))
		return false
	_set_status("无法安排产出：等级、槽位或金币可能不足。")
	return false


func _queue_output_item_in_slot(site_id: String, slot_index: int, item_id: String) -> bool:
	if site_id.is_empty() or item_id.is_empty():
		_set_status("请选择产出地点和下轮食材。")
		return false
	var slot_array_index := _slot_array_index_for_site_slot(site_id, slot_index)
	if slot_array_index < 0:
		_set_status("该格当前空闲，请直接开始产出。")
		return false
	if ProductionSite.set_next_item(state, slot_array_index, item_id):
		_set_status("已设置 %s 第 %d 格下轮产出 %s。" % [
			_site_name(site_id),
			slot_index + 1,
			_ingredient_name(item_id)
		])
		return true
	_set_status("无法设置下轮产出：等级或产地不匹配。")
	return false


func _harvest_output_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= state.production_slots.size():
		_set_status("请选择左侧产出格子。")
		return false
	if not ProductionSite.is_slot_ready(state, slot_index):
		_set_status("尚未成熟，稍后再来收获。")
		return false
	var harvested_slot: Dictionary = (state.production_slots[slot_index] as Dictionary).duplicate(true)
	if ProductionSite.harvest_slot(state, slot_index, -1, true):
		var site_id := String(harvested_slot.get("site_id", ""))
		var site_slot_index := int(harvested_slot.get("slot_index", slot_index))
		state.record_task_event("manual_harvest", {
			"site_id": site_id,
			"item_id": String(harvested_slot.get("item_id", "")),
			"harvest_batch_id": "%s:%d:%d" % [site_id, site_slot_index, int(harvested_slot.get("started_at_unix", 0))]
		})
		_evaluate_output_ready_state()
		_set_status("已收获产出槽位。")
		_show_next_notification()
		return true

	_set_status("槽位无法收获，请重新选择。")
	return false


func _harvest_all_ready_outputs() -> bool:
	if not _is_harvest_all_unlocked():
		_set_status("完成“熟练收获”任务后解锁：手动收获 %d/%d 次。" % [_harvest_all_progress_count(), HARVEST_ALL_TASK_GOAL])
		return false
	_evaluate_output_ready_state()
	var before_inventory: Dictionary = state.ingredient_inventory.duplicate(true)
	var harvested_count := 0
	for index in range(state.production_slots.size() - 1, -1, -1):
		if not ProductionSite.is_slot_ready(state, index):
			continue
		if ProductionSite.harvest_slot(state, index):
			harvested_count += 1

	if harvested_count <= 0:
		_set_status("暂无可收获产出。")
		return false

	_evaluate_output_ready_state()
	var delta_text := _ingredient_delta_summary(before_inventory)
	if delta_text.is_empty():
		delta_text = "成熟槽位 x%d" % harvested_count
	_set_status("一键收获：%s" % delta_text)
	_show_next_notification()
	return true


func _ingredient_delta_summary(before_inventory: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id_value: Variant in state.ingredient_inventory.keys():
		var item_id := String(item_id_value)
		var before_count := int(before_inventory.get(item_id, 0))
		var after_count: int = int(state.get_ingredient_count(item_id))
		var delta: int = after_count - before_count
		if delta > 0:
			parts.append("%s +%d" % [_ingredient_name(item_id), delta])
	parts.sort()
	return "，".join(parts)


func _cancel_output_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= state.production_slots.size():
		_set_status("请选择左侧产出格子。")
		return false
	if ProductionSite.cancel_slot(state, slot_index):
		_evaluate_output_ready_state()
		_set_status("已暂停该产出。")
		return true

	_set_status("无法暂停该产出。")
	return false


func _drop_output_item_to_active(item_id: String, slot_index: int = -1) -> bool:
	if global_popup_mode != "output":
		return false
	if _start_output_item(item_id, slot_index):
		_save_game()
		_refresh_current_page()
		return true
	return false


func _drop_output_slot_to_unlocked(slot_index: int) -> bool:
	if global_popup_mode != "output":
		return false
	if _cancel_output_slot(slot_index):
		_save_game()
		_refresh_current_page()
		return true
	return false


func _on_output_slot_pressed(site_id: String, slot_index: int, slot_array_index: int, button: Button) -> void:
	selected_output_site_id = site_id
	if slot_array_index >= 0:
		_select_output_slot(slot_index, slot_array_index)
		if ProductionSite.is_slot_ready(state, slot_array_index):
			if _harvest_output_slot(slot_array_index):
				_save_game()
				_refresh_current_page()
		else:
			_set_status("%s 第 %d 格正在生产，可设置下轮产出。" % [_site_name(site_id), slot_index + 1])
			_show_output_plant_menu(site_id, slot_index, button.get_global_rect().end)
		return

	_select_idle_output_slot(slot_index)
	var tutorial_item_id := _tutorial_output_start_item_for_site(site_id)
	if not tutorial_item_id.is_empty() and _start_output_item_in_site(site_id, tutorial_item_id, slot_index):
		_save_game()
		_refresh_current_page()
		return
	_show_output_plant_menu(site_id, slot_index, button.get_global_rect().end)


func _tutorial_output_start_item_for_site(site_id: String) -> String:
	if not TutorialProgress.is_guide_active(state) or String(state.tutorial_guide_step) != TutorialProgress.STEP_OUTPUT:
		return ""
	var requirement_by_site := {
		"farm": {"output_id": "rice", "item_id": "rice_seed"}
	}
	var requirement_value: Variant = requirement_by_site.get(site_id)
	if not requirement_value is Dictionary:
		return ""
	var requirement := requirement_value as Dictionary
	if state.tutorial_guide_harvested_ids.has(String(requirement.get("output_id", ""))):
		return ""
	var item_id := String(requirement.get("item_id", ""))
	if _tutorial_output_slot_array_index(site_id, item_id) >= 0 or not state.has_ingredient(item_id, 1):
		return ""
	return item_id


func _on_output_cell_gui_input(event: InputEvent, kind: String, value: Variant) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return
	if not value is Dictionary:
		return
	var data: Dictionary = value
	var site_id := String(data.get("site_id", ""))
	var slot_index := int(data.get("slot_index", -1))
	if site_id.is_empty() or slot_index < 0:
		return
	selected_output_site_id = site_id
	_show_output_accelerator_menu(site_id, slot_index, mouse_event.global_position)
	accept_event()


func _show_output_plant_menu(site_id: String, slot_index: int, global_position: Vector2) -> void:
	_clear_output_context_menu()
	output_context_item_id = "%s:%d" % [site_id, slot_index]
	selected_output_site_id = site_id

	var next_id := 1
	var added_action := false
	var slot_array_index := _slot_array_index_for_site_slot(site_id, slot_index)
	var action_name := "queue" if slot_array_index >= 0 else "start"
	var action_prefix := "下轮：" if slot_array_index >= 0 else ""
	for item_id in _output_site_item_ids(site_id):
		var ingredient: Dictionary = catalog.get_ingredients().get(item_id, {})
		var duration := ProductionSite.production_duration_seconds(state, site_id, item_id, slot_index)
		output_context_menu.add_item("%s%s（%s，收获:%s，耗时:%d秒）" % [
			action_prefix,
			String(ingredient.get("name", item_id)),
			_output_start_stock_text(item_id, ingredient),
			_harvest_output_text(item_id, ingredient),
			duration
		], next_id)
		output_context_actions[next_id] = {
			"action": action_name,
			"site_id": site_id,
			"slot_index": slot_index,
			"item_id": item_id
		}
		next_id += 1
		added_action = true

	if not added_action:
		output_context_menu.add_item("暂无可产出项目", next_id)
		output_context_menu.set_item_disabled(output_context_menu.get_item_index(next_id), true)

	var popup_position := Vector2i(int(global_position.x), int(global_position.y))
	output_context_menu.position = popup_position
	if output_context_menu.is_inside_tree():
		output_context_menu.popup(Rect2i(popup_position, Vector2i(1, 1)))


func _output_start_stock_text(item_id: String, ingredient: Dictionary) -> String:
	var input_type := String(ingredient.get("type", ""))
	if _uses_inventory_output_input(ingredient):
		if input_type == "幼畜":
			return "幼畜库存:%d" % state.get_ingredient_count(item_id)
		return "种子库存:%d" % state.get_ingredient_count(item_id)
	return "库存:%d" % state.get_ingredient_count(item_id)


func _uses_inventory_output_input(ingredient: Dictionary) -> bool:
	var input_type := String(ingredient.get("type", ""))
	if input_type != "种子" and input_type != "幼畜":
		return false
	var harvest_outputs_value: Variant = ingredient.get("harvest_outputs", {})
	if harvest_outputs_value is Dictionary and not (harvest_outputs_value as Dictionary).is_empty():
		return true
	return not String(ingredient.get("harvest_item_id", "")).is_empty()


func _harvest_output_text(item_id: String, ingredient: Dictionary) -> String:
	var harvest_outputs_value: Variant = ingredient.get("harvest_outputs", {})
	if harvest_outputs_value is Dictionary:
		var harvest_outputs: Dictionary = harvest_outputs_value
		var parts: Array[String] = []
		for output_id_value: Variant in harvest_outputs.keys():
			var output_id := String(output_id_value)
			var amount := int(harvest_outputs[output_id_value])
			if not output_id.is_empty() and amount > 0:
				parts.append("%sx%d" % [_ingredient_name(output_id), amount])
		if not parts.is_empty():
			return "、".join(parts)

	return _ingredient_name(String(ingredient.get("harvest_item_id", item_id)))


func _show_output_context_menu(item_id: String, global_position: Vector2) -> void:
	var site_id := selected_output_site_id
	var slot_index := _first_idle_output_slot_index(site_id)
	if slot_index < 0:
		slot_index = 0
	_show_output_accelerator_menu(site_id, slot_index, global_position)


func _show_output_accelerator_menu(site_id: String, slot_index: int, global_position: Vector2) -> void:
	_clear_output_context_menu()
	output_context_item_id = "%s:%d" % [site_id, slot_index]
	selected_output_site_id = site_id

	var target_id := output_context_item_id
	var next_id := 1
	var added_action := false
	var current_tool_id := String(state.get_equipped_accelerator(target_id))
	if not current_tool_id.is_empty():
		var current_tool: Dictionary = catalog.get_tools().get(current_tool_id, {})
		output_context_menu.add_item("卸下：%s" % String(current_tool.get("name", current_tool_id)), next_id)
		output_context_actions[next_id] = {
			"action": "unequip",
			"tool_id": current_tool_id,
			"site_id": site_id,
			"slot_index": slot_index
		}
		next_id += 1
		added_action = true

	var tools := catalog.get_tools()
	for tool_id in _sorted_keys(tools):
		if tool_id == current_tool_id:
			continue
		var tool: Dictionary = tools.get(tool_id, {})
		if String(tool.get("compatible_site", "")) != site_id:
			continue
		var stock: int = state.get_tool_count(tool_id)
		if stock <= 0:
			continue

		var item_id := _item_id_for_site_slot(site_id, slot_index)
		var duration_text := "按原料变化"
		if not item_id.is_empty():
			duration_text = "%d秒" % _duration_with_tool(site_id, item_id, slot_index, tool)
		output_context_menu.add_item("装备：%s（库存 %d，耗时 %s）" % [
			String(tool.get("name", tool_id)),
			stock,
			duration_text
		], next_id)
		output_context_actions[next_id] = {
			"action": "equip",
			"tool_id": tool_id,
			"site_id": site_id,
			"slot_index": slot_index
		}
		next_id += 1
		added_action = true

	if not added_action:
		output_context_menu.add_item("暂无可用加速器", next_id)
		output_context_menu.set_item_disabled(output_context_menu.get_item_index(next_id), true)

	var popup_position := Vector2i(int(global_position.x), int(global_position.y))
	output_context_menu.position = popup_position
	if output_context_menu.is_inside_tree():
		output_context_menu.popup(Rect2i(popup_position, Vector2i(1, 1)))


func _on_output_context_menu_id_pressed(id: int) -> void:
	var action: Dictionary = output_context_actions.get(id, {})
	if action.is_empty():
		return
	if not _is_output_context_action_valid(action):
		_clear_output_context_menu()
		_set_status("菜单已失效，请重新选择")
		return

	var tool_id := String(action.get("tool_id", ""))
	var tool: Dictionary = catalog.get_tools().get(tool_id, {})
	var tool_name := String(tool.get("name", tool_id))
	var site_id := String(action.get("site_id", ""))
	var slot_index := int(action.get("slot_index", -1))
	var target_id := "%s:%d" % [site_id, slot_index]
	match String(action.get("action", "")):
		"start":
			var item_id := String(action.get("item_id", ""))
			if _start_output_item_in_site(site_id, item_id, slot_index):
				_save_game()
				_refresh_current_page()
		"queue":
			var item_id := String(action.get("item_id", ""))
			if _queue_output_item_in_slot(site_id, slot_index, item_id):
				_save_game()
				_refresh_current_page()
		"equip":
			if state.equip_accelerator(target_id, tool_id):
				_apply_output_slot_accelerator(site_id, slot_index)
				_set_status("已为 %s 第 %d 格装备 %s。" % [_site_name(site_id), slot_index + 1, tool_name])
				_save_game()
				_refresh_current_page()
			else:
				_set_status("无法为该格装备 %s：库存或兼容性可能不足。" % tool_name)
		"unequip":
			if state.unequip_accelerator(target_id):
				_apply_output_slot_accelerator(site_id, slot_index)
				_set_status("已卸下 %s 第 %d 格的 %s。" % [_site_name(site_id), slot_index + 1, tool_name])
				_save_game()
				_refresh_current_page()
			else:
				_set_status("无法卸下该格的加速器。")


func _is_output_context_action_valid(action: Dictionary) -> bool:
	if global_popup_mode != "output":
		return false
	var site_id := String(action.get("site_id", ""))
	var slot_index := int(action.get("slot_index", -1))
	if site_id.is_empty() or slot_index < 0:
		return false
	if not catalog.get_production_sites().has(site_id):
		return false
	if slot_index >= OUTPUT_SLOT_COUNT:
		return false
	match String(action.get("action", "")):
		"start":
			var item_id := String(action.get("item_id", ""))
			return _output_item_belongs_to_site(item_id, site_id) \
					and slot_index < _unlocked_output_slot_count(site_id) \
					and _slot_array_index_for_site_slot(site_id, slot_index) == -1
		"queue":
			var item_id := String(action.get("item_id", ""))
			return _output_item_belongs_to_site(item_id, site_id) \
					and slot_index < _unlocked_output_slot_count(site_id) \
					and _slot_array_index_for_site_slot(site_id, slot_index) != -1
		"equip", "unequip":
			return slot_index < _unlocked_output_slot_count(site_id)
	return false


func _clear_output_context_menu() -> void:
	output_context_item_id = ""
	output_context_actions.clear()
	output_context_menu.clear()
	output_context_menu.hide()


func _duration_with_tool(site_id: String, item_id: String, _slot_index: int, tool: Dictionary) -> int:
	var base_duration := ProductionSite.production_duration_seconds(state, site_id, item_id, -1)
	var multiplier := float(tool.get("duration_multiplier", 1.0))
	return maxi(1, int(ceil(float(base_duration) * multiplier)))


func _item_id_for_site_slot(site_id: String, slot_index: int) -> String:
	var slot_array_index := _slot_array_index_for_site_slot(site_id, slot_index)
	if slot_array_index < 0 or slot_array_index >= state.production_slots.size():
		return ""
	var slot_value: Variant = state.production_slots[slot_array_index]
	if not slot_value is Dictionary:
		return ""
	var slot: Dictionary = slot_value
	return String(slot.get("item_id", ""))


func _is_output_slot_for_site(slot: Dictionary, site_id: String) -> bool:
	if String(slot.get("site_id", "")) != site_id:
		return false
	var item_id := String(slot.get("item_id", ""))
	if not _output_item_belongs_to_site(item_id, site_id):
		return false
	if not slot.has("started_at_unix") or not slot.has("duration_seconds") or not slot.has("ready_at_unix"):
		return false
	var duration_value: Variant = slot.get("duration_seconds")
	return duration_value is int or duration_value is float


func _output_item_belongs_to_site(item_id: String, site_id: String) -> bool:
	var sites := catalog.get_production_sites()
	var ingredients := catalog.get_ingredients()
	if not sites.has(site_id) or not ingredients.has(item_id):
		return false
	var site: Dictionary = sites[site_id]
	var site_items: Array = site.get("items", [])
	return site_items.has(item_id)


func _is_output_item_active(site_id: String, item_id: String) -> bool:
	for slot_value: Variant in state.production_slots:
		if not slot_value is Dictionary:
			continue

		var slot: Dictionary = slot_value
		if _is_output_slot_for_site(slot, site_id) and String(slot.get("item_id", "")) == item_id:
			return true
	return false


func _active_output_slot_count(site_id: String) -> int:
	var count := 0
	for slot_value: Variant in state.production_slots:
		if not slot_value is Dictionary:
			continue

		var slot: Dictionary = slot_value
		if _is_output_slot_for_site(slot, site_id):
			count += 1
	return count


func _output_site_active_count(site_id: String, now_unix: int = -1) -> int:
	var count := 0
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		if _is_output_slot_for_site(slot, site_id) and not ProductionSite.is_slot_ready(state, index, now_unix):
			count += 1
	return count


func _output_site_ready_count(site_id: String, now_unix: int = -1) -> int:
	var count := 0
	for index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		if _is_output_slot_for_site(slot, site_id) and ProductionSite.is_slot_ready(state, index, now_unix):
			count += 1
	return count


func _output_site_idle_count(site_id: String) -> int:
	return maxi(0, _unlocked_output_slot_count(site_id) - _active_output_slot_count(site_id))


func _slot_accelerator_key(site_id: String, slot_index: int) -> String:
	return "%s:%d" % [site_id, slot_index]


func _accelerator_summary_for_slot(site_id: String, slot_index: int) -> String:
	var accelerator_id := String(state.get_equipped_accelerator(_slot_accelerator_key(site_id, slot_index)))
	if accelerator_id.is_empty():
		return "加速:无"
	var tool: Dictionary = catalog.get_tools().get(accelerator_id, {})
	if tool.is_empty():
		return "加速:无"
	return "加速:%s" % String(tool.get("name", accelerator_id))


func _apply_output_slot_accelerator(site_id: String, slot_index: int) -> void:
	var slot_array_index := _slot_array_index_for_site_slot(site_id, slot_index)
	if slot_array_index < 0 or slot_array_index >= state.production_slots.size():
		return
	var slot_value: Variant = state.production_slots[slot_array_index]
	if not slot_value is Dictionary:
		return

	var slot: Dictionary = slot_value
	var item_id := String(slot.get("item_id", ""))
	var started_at := int(slot.get("started_at_unix", int(Time.get_unix_time_from_system())))
	var duration := ProductionSite.production_duration_seconds(state, site_id, item_id, slot_index)
	slot["duration_seconds"] = duration
	slot["ready_at_unix"] = started_at + duration
	slot["accelerator_id"] = String(state.get_equipped_accelerator(_slot_accelerator_key(site_id, slot_index)))
	slot["ready"] = ProductionSite.is_slot_ready(state, slot_array_index)
	state.production_slots[slot_array_index] = slot


func _accelerator_summary(item_id: String) -> String:
	var accelerator_id := String(state.get_equipped_accelerator(item_id))
	if accelerator_id.is_empty():
		return "加速:无"
	var tool: Dictionary = catalog.get_tools().get(accelerator_id, {})
	if tool.is_empty():
		return "加速:无"
	return "加速:%s" % String(tool.get("name", accelerator_id))


func _refresh_research_overlay() -> void:
	_prune_empty_research_material_slots(true)
	var research_unlocked: bool = state.is_core_feature_unlocked(CoreFeatureUnlockService.RESEARCH)
	primary_action_button.set_meta("access_locked", not research_unlocked)
	primary_action_button.text = "研发" if research_unlocked else "🔒 研发"
	primary_action_button.disabled = research_request_busy
	primary_action_button.tooltip_text = "" if research_unlocked else state.core_feature_locked_reason(CoreFeatureUnlockService.RESEARCH)
	if not research_unlocked:
		page_description.text = "🔒 研发尚未开放｜%s" % state.core_feature_locked_reason(CoreFeatureUnlockService.RESEARCH)
	else:
		_refresh_research_summary()

	research_input_bar.visible = true
	_fill_research_inventory_grid()
	_fill_research_tool_grid()


func _refresh_production_workbench() -> void:
	if state == null:
		return
	production_queue_snapshot = _build_unified_production_queue_snapshot(
		int(Time.get_unix_time_from_system())
	)
	_render_unified_production_queue()
	production_workbench.refresh_bulk_action_unlocks(
		state.is_feature_unlocked(RESEARCH_MAKE_ALL_FEATURE_ID),
		state.is_feature_unlocked(RESEARCH_BULK_RESTOCK_FEATURE_ID),
		state.is_feature_unlocked(RESEARCH_LIST_ALL_FEATURE_ID)
	)


func _refresh_production_queue_tick(now_unix: int) -> void:
	if state == null:
		return
	var queue_entries := _production_queue_runtime_entries(now_unix)
	var active_count := _production_active_batch_count(queue_entries)
	production_workbench.refresh_queue_runtime(
		queue_entries,
		active_count,
		bool(state.automation_paused)
	)
	production_zone_shell.call("set_activity_state", active_count > 0)


func _production_active_batch_count(entries: Array) -> int:
	var count := 0
	for entry_value: Variant in entries:
		if entry_value is Dictionary and bool((entry_value as Dictionary).get("is_active", false)):
			count += 1
	return count


func _render_unified_production_queue() -> void:
	var filtered := _filtered_production_queue_snapshot(production_queue_search_query)
	var completed_entries: Array = filtered.get("completed_entries", [])
	var queue_entries: Array = filtered.get("queue_entries", [])
	var active_count := _production_active_batch_count(queue_entries)
	production_workbench.refresh_queue(
		completed_entries,
		queue_entries,
		active_count,
		bool(state.automation_paused)
	)
	production_zone_shell.call("set_activity_state", active_count > 0)


func _filtered_production_queue_snapshot(query: String) -> Dictionary:
	var normalized_query := query.strip_edges().to_lower()
	var result := {
		"completed_entries": [],
		"queue_entries": []
	}
	for key in ["completed_entries", "queue_entries"]:
		var filtered_entries: Array = result[key]
		for entry_value: Variant in production_queue_snapshot.get(key, []):
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value
			if normalized_query.is_empty() \
					or String(entry.get("search_haystack", "")).to_lower().find(normalized_query) >= 0:
				filtered_entries.append(entry)
	return result


func _on_production_queue_search_changed(query: String) -> void:
	production_queue_search_query = query
	_render_unified_production_queue()


func _on_production_queue_bulk_action_requested(action: String) -> void:
	match action:
		"make_all":
			_on_secondary_action()
		"restock_all":
			_on_research_bulk_restock_pressed()
		"list_all":
			_on_tertiary_action()


func _refresh_storefront_manage_page() -> void:
	_refresh_showcase_round_controls()
	storefront_manage_panel.visible = true
	_refresh_cashier_feedback()
	_refresh_feedback_log()
	_refresh_storefront_manage_sections()


func _refresh_storefront_manage_sections() -> void:
	if state.has_method("sync_showcase_collection_unlocks"):
		state.sync_showcase_collection_unlocks()
	_refresh_storefront_live_metrics()
	_refresh_storefront_combination_bonus_grid()
	_refresh_showcase_props_theme_panel()
	_refresh_storefront_challenge_section()
	storefront_recent_round_report_label.text = _storefront_recent_round_report_text()
	_refresh_storefront_expansion_button()
	storefront_special_challenge_button.text = "特殊挑战%s" % ("（已选择）" if not state.pending_showcase_challenge.is_empty() else "")
	storefront_recent_report_button.text = "最近营业报告%s" % ("" if state.recent_showcase_round_reports.is_empty() else "（第%d轮）" % int((state.recent_showcase_round_reports.back() as Dictionary).get("round_id", 0)))
	management_device_growth_page.refresh(state, catalog)
	storefront_manage_overlay.call("set_device_upgrade_badge", management_device_growth_page.upgrade_ready_count(state, catalog))
	call_deferred("_maybe_show_pending_recipe_growth_choice")


func _refresh_storefront_live_metrics() -> void:
	var unlocked_count := _unlocked_showcase_slot_count()
	var snapshot := _showcase_business_snapshot()
	storefront_open_slots_value.text = "开放格位 %d/%d" % [unlocked_count, SHOWCASE_SLOT_COUNT]
	storefront_placed_value.text = "已摆放 %d 件" % int(snapshot.get("placed_count", 0))
	storefront_listed_stock_value.text = "可售库存 %d 份" % int(snapshot.get("listed_stock", 0))
	_refresh_storefront_round_forecast()


func _refresh_storefront_combination_bonus_grid() -> void:
	var values := _storefront_combination_bonus_values()
	for entry in [
		[storefront_bonus_region_value, "zone"],
		[storefront_bonus_flavor_value, "adjacency_tag"],
		[storefront_bonus_set_value, "set"],
		[storefront_bonus_conflict_value, "conflict"],
		[storefront_bonus_prop_value, "prop"],
		[storefront_bonus_theme_value, "theme"]
	]:
		var value_label: Label = entry[0]
		var value := float(values.get(String(entry[1]), 0.0))
		value_label.text = _storefront_signed_percent(value)
		value_label.add_theme_color_override("font_color", Color("b55046") if value < -0.01 else Color("3f7f54"))
		value_label.tooltip_text = "当前上架商品中，该来源对单品收益率的最大影响（售价倍率 × 售速倍率）。"


func _storefront_combination_bonus_values() -> Dictionary:
	var values := {
		"zone": 0.0,
		"adjacency_tag": 0.0,
		"set": 0.0,
		"conflict": 0.0,
		"prop": 0.0,
		"theme": 0.0
	}
	var result := ShowcaseRuleService.calculate(state, catalog.get_recipes(), catalog.get_display_rules())
	for item_value in (result.get("items", {}) as Dictionary).values():
		if not item_value is Dictionary:
			continue
		var breakdown: Dictionary = (item_value as Dictionary).get("breakdown", {})
		for source in values.keys():
			var part: Dictionary = breakdown.get(source, {})
			var rate_impact := _storefront_rate_impact_percent(
				float(part.get("price_pct", 0.0)),
				float(part.get("speed_pct", 0.0))
			)
			if absf(rate_impact) > absf(float(values[source])):
				values[source] = rate_impact
	return values


func _storefront_rate_impact_percent(price_pct: float, speed_pct: float) -> float:
	return ((1.0 + price_pct / 100.0) * (1.0 + speed_pct / 100.0) - 1.0) * 100.0


func _refresh_storefront_round_forecast() -> void:
	var forecast := _storefront_round_forecast()
	storefront_forecast_income_value.text = "预估收益\n+%d 金币" % int(forecast.get("income", 0))
	storefront_forecast_reputation_value.text = "预估口碑\n+%d" % int(forecast.get("reputation", 0))
	storefront_forecast_sold_value.text = "预计售出\n%d 件" % int(forecast.get("sold_count", 0))
	storefront_forecast_low_stock_value.text = "低库存提示\n%s" % String(forecast.get("low_stock_text", "库存充足"))
	storefront_forecast_low_stock_value.add_theme_color_override(
		"font_color",
		Color("b55046") if bool(forecast.get("has_low_stock", false)) else Color("3f7f54")
	)
	var rates: Array = forecast.get("product_rates", [])
	for index in range(storefront_product_rate_grid.get_child_count()):
		var rate_label := storefront_product_rate_grid.get_child(index) as RichTextLabel
		if rate_label == null:
			continue
		if index >= rates.size():
			rate_label.text = "[center]%d  暂无\n0 金币/s[/center]" % (index + 1)
			rate_label.tooltip_text = "当前橱窗不足 %d 种有库存商品。" % (index + 1)
			continue
		var rate: Dictionary = rates[index]
		rate_label.text = "[center][b]%d  %s[/b]\n%s 金币/s[/center]" % [
			index + 1,
			String(rate.get("name", rate.get("recipe_id", "商品"))),
			_storefront_rate_text(float(rate.get("coins_per_second", 0.0)))
		]
		rate_label.tooltip_text = "%s｜当前售价 %d 金币｜成交周期 %d 秒\n收益率 = 当前售价 ÷ 成交周期" % [
			String(rate.get("name", "商品")),
			int(rate.get("unit_price", 0)),
			int(rate.get("duration_seconds", 1))
		]


func _storefront_round_forecast() -> Dictionary:
	var round_state: Dictionary = state.active_business_round if state.active_business_round is Dictionary else {}
	var phase := String(round_state.get("phase", "adjusting"))
	var sale_terms: Dictionary = {}
	var item_states: Dictionary = {}
	var role_snapshot: Dictionary = {}
	var duration_ms := 30000
	var chain_max_depth := int(catalog.get_showcase_round_rules().get("chain_max_depth", 4))
	if phase == "running" and not (round_state.get("item_states", {}) as Dictionary).is_empty():
		sale_terms = (round_state.get("sale_terms", {}) as Dictionary).duplicate(true)
		item_states = (round_state.get("item_states", {}) as Dictionary).duplicate(true)
		role_snapshot = (round_state.get("role_snapshot", {}) as Dictionary).duplicate(true)
		duration_ms = maxi(0, int(round_state.get("remaining_ms", 0)))
		chain_max_depth = int(round_state.get("chain_max_depth", chain_max_depth))
	else:
		var preview_environment := _ensure_showcase_round_environment()
		var preview_hotspot := _ensure_showcase_hotspot()
		sale_terms = _showcase_round_terms_for_environment(preview_environment, preview_hotspot)
		item_states = ShowcaseRoundSaleService.build_item_states(state.display_items, sale_terms)
		role_snapshot = ShowcaseRoleService.build_configured_snapshot(
			state.display_items,
			sale_terms,
			catalog.get_showcase_round_rules().get("role_rules", {})
		)
		if not state.pending_showcase_challenge.is_empty():
			duration_ms = maxi(1, int(state.pending_showcase_challenge.get("duration_seconds", 30))) * 1000
		elif int(round_state.get("duration_ms", 0)) > 0:
			duration_ms = int(round_state.get("duration_ms", 30000))
	var preview := ShowcaseRoundSaleService.replay_round(
		item_states,
		duration_ms,
		[],
		"full",
		role_snapshot,
		chain_max_depth
	)
	var reputation := 0
	for event_value in preview.get("events", []):
		if not event_value is Dictionary or bool((event_value as Dictionary).get("bonus_only", false)):
			continue
		var event: Dictionary = event_value
		var term: Dictionary = sale_terms.get(String(event.get("recipe_id", "")), {})
		reputation += maxi(0, int(term.get("reputation_gain", 1)))
	var rates: Array[Dictionary] = []
	for recipe_id_value in sale_terms.keys():
		var recipe_id := String(recipe_id_value)
		var item_state: Dictionary = item_states.get(recipe_id, {})
		var stock := maxi(0, int(item_state.get("fresh_stock", 0))) + maxi(0, int(item_state.get("carried_stock", 0)))
		if stock <= 0:
			continue
		var term: Dictionary = sale_terms.get(recipe_id, {})
		var unit_price := maxi(0, int(term.get("unit_price", 0)))
		var duration_seconds := maxi(1, int(term.get("duration_seconds", 1)))
		rates.append({
			"recipe_id": recipe_id,
			"name": _recipe_name(recipe_id),
			"unit_price": unit_price,
			"duration_seconds": duration_seconds,
			"coins_per_second": float(unit_price) / float(duration_seconds)
		})
	rates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_rate := float(left.get("coins_per_second", 0.0))
		var right_rate := float(right.get("coins_per_second", 0.0))
		if not is_equal_approx(left_rate, right_rate):
			return left_rate > right_rate
		return String(left.get("recipe_id", "")) < String(right.get("recipe_id", ""))
	)
	if rates.size() > 4:
		rates.resize(4)
	var low_stock := _storefront_low_stock_summary()
	return {
		"income": int(preview.get("income", 0)),
		"reputation": reputation,
		"sold_count": int(preview.get("sold_count", 0)),
		"low_stock_text": String(low_stock.get("text", "库存充足")),
		"has_low_stock": bool(low_stock.get("has_low_stock", false)),
		"product_rates": rates
	}


func _storefront_low_stock_summary() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for recipe_id_value in state.display_items.keys():
		var recipe_id := String(recipe_id_value)
		var listed_stock := _storefront_listed_stock_for_recipe(recipe_id)
		var inventory_stock := maxi(0, int(state.get_product_count(recipe_id)))
		if listed_stock <= 1 or inventory_stock <= 2:
			candidates.append({"recipe_id": recipe_id, "name": _recipe_name(recipe_id), "listed_stock": listed_stock})
	if candidates.is_empty():
		return {"has_low_stock": false, "text": "库存充足"}
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_stock := int(left.get("listed_stock", 0))
		var right_stock := int(right.get("listed_stock", 0))
		if left_stock != right_stock:
			return left_stock < right_stock
		return String(left.get("recipe_id", "")) < String(right.get("recipe_id", ""))
	)
	var first: Dictionary = candidates[0]
	var suffix := "" if candidates.size() == 1 else " 等%d种" % candidates.size()
	return {
		"has_low_stock": true,
		"text": "%s %d份%s" % [String(first.get("name", "商品")), int(first.get("listed_stock", 0)), suffix]
	}


func _storefront_listed_stock_for_recipe(recipe_id: String) -> int:
	var round_state: Dictionary = state.active_business_round if state.active_business_round is Dictionary else {}
	if String(round_state.get("phase", "")) == "running":
		var item_states: Dictionary = round_state.get("item_states", {})
		if item_states.has(recipe_id):
			var item_state: Dictionary = item_states.get(recipe_id, {})
			return maxi(0, int(item_state.get("fresh_stock", 0))) + maxi(0, int(item_state.get("carried_stock", 0)))
	return maxi(0, int(state.get_display_item_stock(recipe_id)))


func _storefront_price_speed_text(data: Dictionary) -> String:
	var parts: Array[String] = []
	var price_pct := int(round(float(data.get("price_pct", 0.0))))
	var speed_pct := int(round(float(data.get("speed_pct", 0.0))))
	if price_pct != 0:
		parts.append("售价 %+d%%" % price_pct)
	if speed_pct != 0:
		parts.append("售速 %+d%%" % speed_pct)
	return "无加成" if parts.is_empty() else "·".join(parts)


func _storefront_signed_percent(value: float) -> String:
	var rounded := int(round(value))
	return "0%" if rounded == 0 else "%+d%%" % rounded


func _storefront_rate_text(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return "%d" % int(round(value))
	return "%.1f" % value


func _refresh_showcase_props_theme_panel() -> void:
	var phase := String(state.active_business_round.get("phase", "adjusting"))
	var unlocked_themes: Array[String] = state.get_unlocked_showcase_theme_ids() if state.has_method("get_unlocked_showcase_theme_ids") else []
	var selected_theme_id := String(state.showcase_theme_id)
	for theme_button_value in showcase_theme_buttons.get_children():
		var theme_button := theme_button_value as Button
		if theme_button == null:
			continue
		var theme_id := "" if theme_button.name == &"none" else String(theme_button.name)
		var unlocked := theme_id.is_empty() or unlocked_themes.has(theme_id)
		var theme: Dictionary = ShowcaseRuleService.THEME_RULES.get(theme_id, {})
		var label := "无主题" if theme_id.is_empty() else String(theme.get("label", theme_id))
		var effect_text := "无加成" if theme_id.is_empty() else _storefront_price_speed_text(theme)
		theme_button.text = "%s｜%s%s" % [label, effect_text, "｜已选择" if selected_theme_id == theme_id else ""]
		theme_button.button_pressed = selected_theme_id == theme_id
		theme_button.disabled = showcase_expansion_active or not unlocked or phase != "adjusting"
		theme_button.tooltip_text = "%s%s" % [
			"同轮只能选择一个主题；不占橱窗格。" if unlocked else "Lv.%d 阶段奖励解锁。" % int(GameState.SHOWCASE_THEME_UNLOCK_LEVELS.get(theme_id, 0)),
			" 营业开始后主题锁定。" if phase != "adjusting" else ""
		]
	var unlocked_props: Array[String] = state.get_unlocked_showcase_prop_ids() if state.has_method("get_unlocked_showcase_prop_ids") else []
	for prop_id in GameState.SHOWCASE_PROP_ORDER:
		var button: Button = showcase_prop_buttons.get_node_or_null(prop_id)
		if button == null:
			continue
		var definition: Dictionary = ShowcaseRuleService.PROP_RULES.get(prop_id, {})
		var unlocked: bool = unlocked_props.has(prop_id)
		var placed: bool = bool((state.get("display_props") as Dictionary).has(prop_id))
		var status: String = "Lv.%d" % int(definition.get("unlock_level", 0))
		if unlocked:
			status = "已放置" if placed else ("可放置" if phase == "adjusting" else "营业中锁定")
		if showcase_expansion_active and unlocked:
			status = "扩建中锁定"
		button.call("configure_available", unlocked and phase == "adjusting" and not showcase_expansion_active, int(definition.get("unlock_level", 0)), String(definition.get("effect_text", "")), status)


func _on_showcase_theme_button_pressed(theme_id: String) -> void:
	if showcase_expansion_active:
		_set_status("请先退出扩建模式，再切换橱窗主题。")
		return
	if not state.set_showcase_theme(theme_id):
		_set_status("主题切换失败：尚未解锁，或营业中布局已锁定。")
		_refresh_showcase_props_theme_panel()
		return
	_invalidate_showcase_bonus_cache()
	_save_game()
	_set_status("橱窗主题已切换为：%s" % ("无主题" if theme_id.is_empty() else String((ShowcaseRuleService.THEME_RULES[theme_id] as Dictionary).get("label", theme_id))))
	_refresh_storefront_showcase()
	_refresh_storefront_manage_sections()


func _open_storefront_challenge_dialog() -> void:
	_refresh_storefront_challenge_section()
	storefront_challenge_dialog.popup_centered(Vector2i(560, 330))


func _open_storefront_recent_report_dialog() -> void:
	storefront_recent_round_report_label.text = _storefront_recent_round_report_text()
	storefront_recent_report_dialog.popup_centered(Vector2i(600, 300))


func _on_storefront_entry_dialog_close_requested(dialog: AcceptDialog) -> void:
	dialog.hide()
	_refresh_storefront_entry_dialog_backdrop()


func _refresh_storefront_entry_dialog_backdrop() -> void:
	if not global_popup_mode.is_empty():
		return
	for dialog in [storefront_challenge_dialog, storefront_recent_report_dialog, showcase_rulebook_dialog]:
		if is_instance_valid(dialog) and dialog.visible:
			global_popup_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
			global_popup_backdrop.visible = true
			return
	call_deferred("_hide_storefront_entry_dialog_backdrop_if_idle")


func _hide_storefront_entry_dialog_backdrop_if_idle() -> void:
	if not global_popup_mode.is_empty():
		return
	for dialog in [storefront_challenge_dialog, storefront_recent_report_dialog, showcase_rulebook_dialog]:
		if is_instance_valid(dialog) and dialog.visible:
			return
	global_popup_backdrop.visible = false


func _maybe_show_pending_recipe_growth_choice(preferred_recipe_id: String = "") -> void:
	if state == null or not is_instance_valid(recipe_growth_choice_dialog) or recipe_growth_choice_dialog.visible:
		return
	var recipe_ids: Array[String] = []
	for recipe_id_value in state.unlocked_recipes:
		recipe_ids.append(String(recipe_id_value))
	recipe_ids.sort()
	if not preferred_recipe_id.is_empty() and recipe_ids.has(preferred_recipe_id):
		recipe_ids.erase(preferred_recipe_id)
		recipe_ids.push_front(preferred_recipe_id)
	var recipes: Dictionary = catalog.get_recipes()
	var display_config: Dictionary = catalog.get_recipe_display_config()
	var display_recipes: Dictionary = display_config.get("recipes", {})
	var round_rules: Dictionary = catalog.get_showcase_round_rules()
	var templates: Dictionary = round_rules.get("shape_templates", {})
	for recipe_id in recipe_ids:
		var growth: Dictionary = state.get_recipe_growth(recipe_id)
		if not bool(growth.get("pending_trait_choice", false)):
			continue
		var recipe: Dictionary = recipes.get(recipe_id, {})
		var recipe_display: Dictionary = display_recipes.get(recipe_id, {})
		var shape_category := String(recipe_display.get("shape_category", "横盘款"))
		var template: Dictionary = templates.get(shape_category, {})
		var base_seconds := maxi(1, int(template.get("base_sale_seconds", 10)))
		var base_price := maxi(0, int(recipe.get("price", 0)))
		var cell_count := maxi(1, int(recipe_display.get("cell_count", 1)))
		var role := String(template.get("role", "lure"))
		var candidates: Array[Dictionary] = []
		for trait_id_value in growth.get("available_traits", []):
			var trait_id := String(trait_id_value)
			if (growth.get("selected_traits", []) as Array).has(trait_id):
				continue
			var definition := RecipeGrowthService.trait_definition(recipe_id, trait_id, recipe, display_config)
			var price_pct := float(definition.get("price_pct", 0.0))
			var speed_pct := float(definition.get("speed_pct", 0.0))
			var duration := float(base_seconds) / maxf(0.2, 1.0 + speed_pct / 100.0)
			var estimated_sales := maxi(0, int(floor(30.0 / duration)))
			var estimated_unit_price := maxi(0, int(round(float(base_price) * (1.0 + price_pct / 100.0))))
			definition["impact_text"] = "[font_size=20]%s[/font_size]\n售价 %+.0f%%｜售速 %+.0f%%\n\n30 秒预计成交：%d 次\n预计金币：%d（%d × %d）\n占格：%d 格｜角色：%s\n热度：沿用角色连锁成本，本特性不额外增加" % [
				definition.get("label", trait_id),
				price_pct,
				speed_pct,
				estimated_sales,
				estimated_sales * estimated_unit_price,
				estimated_sales,
				estimated_unit_price,
				cell_count,
				role
			]
			candidates.append(definition)
		if candidates.is_empty():
			continue
		recipe_growth_choice_dialog.call(
			"show_choice",
			recipe_id,
			String(recipe.get("name", recipe_id)),
			RecipeGrowthService.mastery_name(int(growth.get("mastery_level", 0))),
			candidates
		)
		return


func _on_recipe_growth_trait_selected(recipe_id: String, trait_id: String) -> void:
	if not state.select_recipe_trait(recipe_id, trait_id):
		_set_status("成长特性选择失败：候选已变化，请重新查看。")
		return
	_invalidate_showcase_bonus_cache()
	_save_game()
	_set_status("已选择成长特性：%s" % RecipeGrowthService.trait_definition(recipe_id, trait_id, catalog.get_recipes().get(recipe_id, {}), catalog.get_recipe_display_config()).get("label", trait_id))
	_refresh_current_page()
	if catalog_overlay.visible:
		catalog_overlay.call("refresh_panel", self)
	call_deferred("_maybe_show_pending_recipe_growth_choice")


func _open_showcase_rulebook() -> bool:
	if not _require_core_feature(CoreFeatureUnlockService.RULEBOOK):
		return false
	if is_instance_valid(showcase_rulebook_dialog) and showcase_rulebook_dialog.has_method("show_rules"):
		showcase_rulebook_dialog.call("show_rules", state, catalog)
		return showcase_rulebook_dialog.visible
	return false


func _on_showcase_rulebook_requested() -> void:
	if not _open_showcase_rulebook():
		return
	if TutorialProgress.on_showcase_rulebook_opened(state):
		_save_game()
		call_deferred("_refresh_tutorial_guide")


func _storefront_current_build_text() -> String:
	var result := ShowcaseRuleService.calculate(state, catalog.get_recipes(), catalog.get_display_rules())
	var summary: Dictionary = result.get("summary", {})
	var regions: Dictionary = summary.get("region_cell_counts", {})
	var theme_id := String(summary.get("theme_id", ""))
	var theme_label := "无"
	if ShowcaseRuleService.THEME_RULES.has(theme_id):
		theme_label = String((ShowcaseRuleService.THEME_RULES[theme_id] as Dictionary).get("label", theme_id))
	var strongest: Array = summary.get("strongest_effects", [])
	var strongest_text := "暂无，先查看规则再开始摆放" if strongest.is_empty() else "；".join(strongest)
	return "当前构筑｜已开放 %d/%d｜引流 %d｜黄金 %d｜宝藏 %d\n正向规则 %d｜冲突 %d｜套装 %d｜主题 %s｜道具 %d\n最强影响：%s" % [
		int(summary.get("unlocked_count", _unlocked_showcase_slot_count())),
		SHOWCASE_SLOT_COUNT,
		int(regions.get("front", 0)),
		int(regions.get("golden", 0)),
		int(regions.get("back", 0)),
		int(summary.get("positive_rule_count", 0)),
		int(summary.get("conflict_count", 0)),
		int(summary.get("set_count", 0)),
		theme_label,
		int(summary.get("prop_count", 0)),
		strongest_text
	]


func _storefront_overview_text(unlocked_count: int, snapshot: Dictionary) -> String:
	var phase := String(state.active_business_round.get("phase", "adjusting"))
	var phase_label := "布局调整" if phase == "adjusting" else ("营业中" if phase == "running" else "待结算")
	return "经营概览｜%s｜已开放 %d/%d｜摆放 %d 件｜橱窗库存 %d" % [
		phase_label,
		unlocked_count,
		SHOWCASE_SLOT_COUNT,
		int(snapshot.get("placed_count", 0)),
		int(snapshot.get("listed_stock", 0))
	]


func _refresh_storefront_challenge_section() -> void:
	var choices := _showcase_contract_choices()
	var buttons: Array[Button] = [sprint_challenge_button, value_challenge_button, chain_challenge_button]
	var phase := String(state.active_business_round.get("phase", "adjusting"))
	var has_pending: bool = not state.pending_showcase_challenge.is_empty()
	var lines: Array[String] = ["特殊挑战｜Lv.6 起每轮三选一，普通营业无需选择"]
	if has_pending:
		var pending: Dictionary = state.pending_showcase_challenge
		lines.append("已锁定：%s｜%d 秒｜保证金 %d" % [
			String(pending.get("title", pending.get("id", "挑战"))),
			int(pending.get("duration_seconds", 30)),
			int(pending.get("deposit", 0))
		])
		lines.append("环境：%s｜%s" % [_showcase_challenge_environment_text(pending.get("environment", {})), _showcase_contract_tier_text(pending)])
	else:
		lines.append("未选择挑战：左侧“开始营业”将开始标准 30 秒营业。")
		lines.append("选择后条件与环境锁定；普通合同失败不会扣除长期评级。")
	for index in range(buttons.size()):
		var button: Button = buttons[index]
		var challenge: Dictionary = choices[index] if index < choices.size() else {}
		var unlocked := not challenge.is_empty()
		var deposit := maxi(0, int(challenge.get("deposit", 0)))
		button.visible = unlocked
		button.disabled = not unlocked or phase != "adjusting" or has_pending or state.coins < deposit
		if not unlocked:
			continue
		button.text = String(challenge.get("title", "经营合同"))
		var disabled_reason := ""
		if phase != "adjusting":
			disabled_reason = "；营业中或待结算时不可接受"
		elif has_pending:
			disabled_reason = "；已有待开始挑战"
		elif state.coins < deposit:
			disabled_reason = "；金币不足"
		button.tooltip_text = "%s\n时长 %d 秒｜保证金 %d｜%s\n环境：%s%s" % [
			String(challenge.get("description", "")),
			int(challenge.get("duration_seconds", 30)),
			deposit,
			_showcase_contract_tier_text(challenge),
			_showcase_challenge_environment_text(challenge.get("environment", {})),
			disabled_reason
		]
	storefront_challenge_summary.text = "\n".join(lines)


func _showcase_contract_choices() -> Array[Dictionary]:
	if state == null or int(state.level) < 6:
		return []
	if not state.showcase_contract_choices.is_empty() and int(state.showcase_contract_choices[0].get("round_id", 0)) == int(state.business_round_id):
		return state.showcase_contract_choices.duplicate(true)
	var contracts: Array = []
	for task_value in TaskService.get_task_definitions().values():
		if task_value is Dictionary and String((task_value as Dictionary).get("type", "")) == "contract":
			contracts.append((task_value as Dictionary).duplicate(true))
	state.showcase_contract_choices = ShowcaseChallengeService.generate_contract_choices(
		int(state.level),
		int(state.business_round_id),
		contracts,
		catalog.get_showcase_round_rules(),
		_showcase_challenge_unlock_context()
	)
	return state.showcase_contract_choices.duplicate(true)


func _showcase_contract_tier_text(snapshot: Dictionary) -> String:
	var tier_names: Array[String] = []
	for tier_value in snapshot.get("tiers", []):
		if tier_value is Dictionary:
			tier_names.append(String((tier_value as Dictionary).get("id", "")).capitalize())
	return "评价 %s" % "/".join(tier_names)


func _showcase_challenge_restriction_text(restrictions_value: Variant) -> String:
	var restrictions: Dictionary = restrictions_value if restrictions_value is Dictionary else {}
	var parts: Array[String] = []
	var required_tags: Array[String] = []
	for tag_value in restrictions.get("required_tags", []):
		required_tags.append(String(tag_value))
	if not required_tags.is_empty():
		parts.append("需标签 %s" % "/".join(required_tags))
	var allowed_recipe_ids: Array = restrictions.get("allowed_recipe_ids", [])
	if not allowed_recipe_ids.is_empty():
		parts.append("限定 %d 个已解锁配方" % allowed_recipe_ids.size())
	return "不限商品" if parts.is_empty() else "；".join(parts)


func _showcase_challenge_environment_text(environment_value: Variant) -> String:
	var environment: Dictionary = environment_value if environment_value is Dictionary else {}
	if environment.is_empty():
		return "普通街区"
	return "%s（售价 %+d%%，售速 %+d%%）" % [
		String(environment.get("label", "普通街区")),
		int(round(float(environment.get("total_price_pct", 0.0)))),
		int(round(float(environment.get("total_speed_pct", 0.0))))
	]


func _storefront_recent_round_report_text() -> String:
	if state.recent_showcase_round_reports.is_empty():
		return "最近营业报告\n完成一轮营业并处理余货后，这里会拆分基础、市场、布局与清仓收入。"
	var report_value: Variant = state.recent_showcase_round_reports.back()
	if not report_value is Dictionary:
		return "最近营业报告\n暂无可显示的营业数据。"
	var report: Dictionary = report_value
	var top_recipe_id := String(report.get("top_recipe_id", ""))
	var top_text := "无" if top_recipe_id.is_empty() else _recipe_name(top_recipe_id)
	var kind_text := "特殊挑战" if String(report.get("kind", "standard")) == "challenge" else "标准营业"
	return "最近营业报告｜第 %d 轮·%s\n总金币 %d｜成交 %d 次｜贡献最高 %s\n基础 %d｜市场 %+d｜布局/连锁 %+d｜清仓 %d" % [
		int(report.get("round_id", 0)),
		kind_text,
		int(report.get("total_coins", 0)),
		int(report.get("sold_count", 0)),
		top_text,
		int(report.get("base_income", 0)),
		int(report.get("market_income", 0)),
		int(report.get("layout_extra_income", 0)),
		int(report.get("clearance_income", 0))
	]


func _storefront_expansion_text(unlocked_count: int) -> String:
	var max_unlocked := ShowcaseExpansionService.max_unlocked_cells_for_level(state.level if state != null else 0)
	var next_price := ShowcaseExpansionService.cell_price(maxi(1, unlocked_count - 16 + 1))
	return "橱窗扩张\n已开放 %d/%d 格｜本级上限 %d 格｜下一格 %d 金币\n可购买单格、连通的 N 格，或整行/整列中与旧区域四方向相邻的格子；扩建后功能区域按实际已开放行列重算。" % [
		unlocked_count,
		SHOWCASE_SLOT_COUNT,
		max_unlocked,
		next_price
	]


func _refresh_storefront_expansion_button() -> void:
	if state == null:
		return
	var unlocked_count: int = state.get_showcase_unlocked_cells().size()
	var max_unlocked: int = ShowcaseExpansionService.max_unlocked_cells_for_level(state.level)
	if unlocked_count >= SHOWCASE_SLOT_COUNT:
		storefront_expansion_button.text = "橱窗已全部开放"
		storefront_expansion_button.disabled = true
		return
	if state.level < 2:
		storefront_expansion_button.text = "Lv.2 开放扩建"
		storefront_expansion_button.disabled = true
		storefront_expansion_button.tooltip_text = "升级到 Lv.2 后，可按格、行或列扩建橱窗。"
		return
	if unlocked_count >= max_unlocked:
		storefront_expansion_button.text = "本级已达 %d 格上限" % max_unlocked
		storefront_expansion_button.disabled = true
		storefront_expansion_button.tooltip_text = "提升店铺等级可开放更多橱窗格购买额度。"
		return
	storefront_expansion_button.text = "进入扩建｜下一格 %d 金币" % ShowcaseExpansionService.cell_price(unlocked_count - 16 + 1)
	storefront_expansion_button.disabled = _is_showcase_round_layout_locked()
	storefront_expansion_button.tooltip_text = "在真实橱窗网格内选择单格/N格、整行或整列；新区必须与旧区域连通。"


func _enter_showcase_expansion_mode() -> void:
	if state == null or state.level < 2:
		_set_status("扩建在 Lv.2 开放。")
		return
	if _is_showcase_round_layout_locked():
		_set_status("营业中布局已锁定，请在本轮结算后扩建。")
		return
	showcase_expansion_active = true
	showcase_expansion_tool = "cells"
	showcase_expansion_selected_cells.clear()
	_clear_showcase_drag_preview()
	_refresh_showcase_expansion_mode_ui()
	_refresh_storefront_showcase()
	_set_status("已进入扩建模式：绿色格可选，金色格已选。")


func _cancel_showcase_expansion_mode() -> void:
	showcase_expansion_active = false
	showcase_expansion_selected_cells.clear()
	_refresh_showcase_expansion_mode_ui()
	_refresh_storefront_showcase()
	_set_status("已退出橱窗扩建模式。")


func _set_showcase_expansion_tool(tool: String) -> void:
	if not showcase_expansion_active or not ["cells", "row", "column"].has(tool):
		return
	showcase_expansion_tool = tool
	showcase_expansion_selected_cells.clear()
	_refresh_showcase_expansion_mode_ui()
	_refresh_storefront_showcase()


func _refresh_showcase_expansion_mode_ui() -> void:
	if not is_instance_valid(showcase_panel) or not showcase_panel.has_method("set_expansion_mode"):
		return
	_refresh_showcase_round_controls()
	_refresh_showcase_props_theme_panel()
	if not showcase_expansion_active:
		showcase_panel.call("set_expansion_mode", false, showcase_expansion_tool, "", false)
		return
	var selected_count := showcase_expansion_selected_cells.size()
	var quote: Dictionary = state.quote_showcase_cell_purchase(showcase_expansion_selected_cells) if selected_count > 0 else {}
	var unlocked_count: int = state.get_showcase_unlocked_cells().size()
	var max_unlocked: int = ShowcaseExpansionService.max_unlocked_cells_for_level(state.level)
	var summary := "已开放 %d/%d｜剩余额度 %d｜下一格 %d 金币｜余额 %d" % [
		unlocked_count, max_unlocked, maxi(0, max_unlocked - unlocked_count),
		ShowcaseExpansionService.cell_price(unlocked_count - 16 + 1), state.coins
	]
	var confirm_enabled := false
	if selected_count > 0:
		summary = _showcase_expansion_quote_text(quote)
		confirm_enabled = bool(quote.get("ok", false))
	showcase_panel.call("set_expansion_mode", true, showcase_expansion_tool, summary, confirm_enabled)


func _showcase_expansion_quote_text(quote: Dictionary) -> String:
	var reason := String(quote.get("reason", ""))
	if reason == "level_cap":
		return "已选 %d 格｜本级还可买 %d 格（上限 %d）｜Lv.%d 可到 %d 格" % [
			int(quote.get("count", 0)), int(quote.get("remaining_quota", 0)), int(quote.get("max_unlocked_cells", 0)),
			state.level + 1, ShowcaseExpansionService.max_unlocked_cells_for_level(state.level + 1)
		]
	if reason == "insufficient_coins":
		return "已选 %d 格｜合计 %d 金币｜余额 %d｜还差 %d" % [int(quote.get("count", 0)), int(quote.get("total_cost", 0)), state.coins, int(quote.get("coin_shortfall", 0))]
	if not reason.is_empty() and not bool(quote.get("ok", false)):
		return "当前选择不可购买：%s" % _showcase_expansion_reason_text(reason)
	return "已选 %d 格｜单价 %d→%d｜合计 %d｜余额 %d｜购买后 %d/%d｜剩余 %d" % [
		int(quote.get("count", 0)), int(quote.get("first_price", 0)), int(quote.get("last_price", 0)),
		int(quote.get("total_cost", 0)), state.coins, int(quote.get("unlocked_count", 0)) + int(quote.get("count", 0)),
		int(quote.get("max_unlocked_cells", 0)), int(quote.get("remaining_quota", 0)) - int(quote.get("count", 0))
	]


func _showcase_expansion_reason_text(reason: String) -> String:
	return {
		"layout_locked": "营业中布局已锁定",
		"level_required": "需达到 Lv.2",
		"empty_selection": "尚未选择格子",
		"invalid_selection": "包含越界、重复或已开放格",
		"disconnected": "整批购买后必须与旧区域四方向连通",
		"level_cap": "超过当前等级上限",
		"insufficient_coins": "金币不足"
	}.get(reason, reason)


func _confirm_showcase_expansion_purchase() -> void:
	if not showcase_expansion_active or showcase_expansion_selected_cells.is_empty():
		return
	var result: Dictionary = state.purchase_showcase_cells(showcase_expansion_selected_cells)
	if not bool(result.get("ok", false)):
		_set_status("扩建失败：%s。" % _showcase_expansion_reason_text(String(result.get("reason", ""))))
		_refresh_showcase_expansion_mode_ui()
		return
	var purchased_count := int(result.get("count", 0))
	var total_cost := int(result.get("total_cost", 0))
	showcase_expansion_selected_cells.clear()
	if int(result.get("unlocked_count", 0)) >= SHOWCASE_SLOT_COUNT:
		showcase_expansion_active = false
	_invalidate_showcase_bonus_cache()
	_save_game()
	_refresh_showcase_layout_projection()
	_refresh_current_page()
	_refresh_showcase_expansion_mode_ui()
	_set_status("橱窗扩建完成：开放 %d 格，支付 %d 金币，现共 %d 格；区域加成已重算。" % [purchased_count, total_cost, int(result.get("unlocked_count", 0))])


func _on_primary_action() -> void:
	if not _require_core_feature(CoreFeatureUnlockService.RESEARCH):
		return
	_research_selected_recipe()


func _on_secondary_action() -> void:
	_make_all_available_products()
	_save_game()
	_refresh_current_page()
	_show_next_notification()


func _on_tertiary_action() -> void:
	_list_all_available_products()
	_save_game()
	_refresh_current_page()
	_show_next_notification()


func _purchase_tool_item(
	tool_id: String,
	update_status: bool = true,
	tools: Dictionary = {}
) -> bool:
	var actual_tools := tools if not tools.is_empty() else catalog.get_tools()
	var tool: Dictionary = actual_tools.get(tool_id, {})
	if tool.is_empty() or not _is_tool_available_for_display(tool_id, tool):
		if update_status:
			_set_status("该工具尚未解锁，无法购买。")
		return false
	if String(tool.get("tool_kind", "")) != "accelerator":
		if update_status:
			_set_status("%s 已解锁，可在研发页使用。" % String(tool.get("name", tool_id)))
		return false

	var price := int(tool.get("price", 0))
	if state.coins < price:
		if update_status:
			_set_status("金币不足，无法购买 %s。" % String(tool.get("name", tool_id)))
		return false

	state.coins -= price
	state.add_tool(tool_id, 1)
	state.add_log("purchase_tool:%s:%d" % [tool_id, price])
	if update_status:
		_set_status("已购买工具 %s。" % String(tool.get("name", tool_id)))
	return true


func _purchase_cart_items() -> bool:
	var snapshot := _purchase_cart_snapshot()
	var entries := _purchase_cart_entries(snapshot)
	if entries.is_empty():
		_set_status("购物车为空，请先调整采购数量。")
		_update_purchase_cart_summary(snapshot)
		return false

	var receipt := _purchase_cart_receipt(entries, snapshot)
	var purchased_quantities: Dictionary = {}
	for receipt_entry_value: Variant in receipt.get("entries", []):
		if not receipt_entry_value is Dictionary:
			continue
		var receipt_entry := receipt_entry_value as Dictionary
		purchased_quantities[String(receipt_entry.get("item_key", ""))] = int(receipt_entry.get("quantity", 0))
	var total_cost := int(receipt.get("total_cost", 0))
	if total_cost > int(state.coins):
		_set_status("金币不足，无法结算当前购物车。")
		_update_purchase_cart_summary(snapshot)
		return false

	var ingredients: Dictionary = snapshot["ingredients"]
	var tools: Dictionary = snapshot["tools"]
	var bought_units := 0
	for item_key in entries:
		var quantity := _purchase_cart_quantity(item_key)
		for _unit_index in range(quantity):
			var bought := false
			if item_key.begins_with(TOOL_METADATA_PREFIX):
				bought = _purchase_tool_item(
					item_key.substr(TOOL_METADATA_PREFIX.length()),
					false,
					tools
				)
			else:
				bought = _purchase_inventory_item(item_key, false, ingredients)
			if bought:
				bought_units += 1
	var expected_units := int(receipt.get("total_units", 0))
	if bought_units != expected_units:
		_set_status("购物车结算未完整完成，未展示小票。")
		var failed_snapshot := _refresh_purchase_regions()
		_update_purchase_cart_summary(failed_snapshot)
		return false
	TutorialProgress.on_purchase_completed(state, purchased_quantities)
	for item_key in entries:
		purchase_cart_quantities[item_key] = 0

	_set_status("已购买 %d 件商品，花费 %d 金币。" % [bought_units, total_cost])
	var cleared_snapshot := _purchase_cart_snapshot(ingredients, tools)
	_update_purchase_cart_summary(cleared_snapshot)
	purchase_page_refresh_pending = true
	receipt["remaining_coins"] = int(state.coins)
	purchase_receipt_suspended_task_popup = task_popup.visible
	if purchase_receipt_suspended_task_popup:
		task_popup.hide()
	purchase_receipt_dialog.call("show_receipt", receipt)
	return true


func _purchase_cart_receipt(entries: Array[String], snapshot: Dictionary = {}) -> Dictionary:
	var actual_snapshot := snapshot if not snapshot.is_empty() else _purchase_cart_snapshot()
	var receipt_entries: Array[Dictionary] = []
	var total_units := 0
	var total_cost := 0
	for item_key in entries:
		var quantity := _purchase_cart_quantity(item_key)
		var unit_price := _purchase_cart_item_price(item_key, actual_snapshot)
		var subtotal := quantity * unit_price
		receipt_entries.append({
			"item_key": item_key,
			"name": _purchase_cart_item_name(item_key, actual_snapshot),
			"quantity": quantity,
			"unit_price": unit_price,
			"subtotal": subtotal
		})
		total_units += quantity
		total_cost += subtotal
	return {
		"entries": receipt_entries,
		"total_units": total_units,
		"total_cost": total_cost
	}


func _research_selected_recipe() -> void:
	if research_request_busy:
		return

	var material_ids: Array[String] = []
	material_ids.assign(_selected_research_material_ids())
	if material_ids.is_empty():
		_set_status("请选择材料进行研发或加工。")
		return

	var tool_id := selected_research_tool_id
	if tool_id.is_empty():
		_set_status("请选择一个研发或加工工具。")
		return

	research_request_busy = true
	primary_action_button.disabled = true
	research_progress_dialog.show_waiting()
	var wait_seconds := _research_wait_duration_seconds(material_ids.size())
	get_tree().create_timer(wait_seconds).timeout.connect(
		_complete_research_request.bind(tool_id, material_ids.duplicate())
	)


func _research_wait_duration_seconds(material_count: int) -> float:
	if material_count <= 0:
		return 0.0
	if material_count == 1:
		return 0.5
	if material_count == 2:
		return 1.0
	return 1.5


func _complete_research_request(tool_id: String, material_ids: Array[String]) -> void:
	if not research_request_busy or not is_instance_valid(research_progress_dialog):
		return

	var result: Dictionary
	var action_name := "研发"
	if material_ids.size() == 1:
		action_name = "加工"
		result = RecipeBook.process_ingredient(state, tool_id, material_ids)
	elif TutorialProgress.on_research_attempted(state, tool_id, material_ids):
		state.record_task_event("research_attempt", {
			"device_id": tool_id,
			"material_count": material_ids.size()
		})
		result = {
			"ok": true,
			"message": "米浆饮已研发过，本次正确操作已完成引导步骤。"
		}
		call_deferred("_refresh_tutorial_guide")
	else:
		result = RecipeBook.research(state, tool_id, material_ids, false)

	var fallback_message := "加工完成。" if action_name == "加工" else "研发完成。"
	var result_message := String(result.get("message", fallback_message))
	_set_status(result_message)
	_prune_empty_research_material_slots(true)
	_save_game()
	_refresh_current_page()
	var result_ok := bool(result.get("ok", false))
	var ingredient_id := String(result.get("ingredient_id", ""))
	var recipe_id := String(result.get("recipe_id", ""))
	if result_ok and action_name == "加工" and not ingredient_id.is_empty():
		var ingredient: Dictionary = catalog.get_ingredients().get(ingredient_id, {})
		var ingredient_name := String(ingredient.get("name", ingredient_id))
		research_progress_dialog.show_item_success(
			_ingredient_icon_texture(ingredient_id),
			ingredient_name,
			result_message,
			action_name
		)
	elif result_ok and action_name == "研发" and not recipe_id.is_empty():
		var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
		var recipe_name := String(recipe.get("name", recipe_id))
		research_progress_dialog.show_item_success(
			_research_result_recipe_icon_texture(recipe_id),
			recipe_name,
			result_message,
			action_name
		)
	else:
		if not result_ok and action_name == "研发":
			var hint := RecipeBook.research_hint_view(state, tool_id, material_ids)
			research_progress_dialog.show_result(
				result_ok,
				result_message,
				action_name,
				_research_hint_title_text(hint),
				_research_hint_body_text(hint)
			)
		else:
			research_progress_dialog.show_result(result_ok, result_message, action_name)


func _on_research_result_confirmed() -> void:
	research_request_busy = false
	_refresh_current_page()
	_show_next_notification()


func _on_recipe_make_pressed(recipe_id: String) -> void:
	if not _require_core_feature(CoreFeatureUnlockService.CRAFT):
		return
	var unavailable_reason := _recipe_unavailable_status(recipe_id)
	if not unavailable_reason.is_empty():
		_set_status(unavailable_reason)
		return
	if _make_recipe_product(recipe_id, 1):
		state.record_task_event("manual_craft_success", {"action_kind": "recipe", "recipe_id": recipe_id})
	_prune_empty_research_material_slots(true)
	_save_game()
	_refresh_current_page()
	_show_next_notification()


func _on_recipe_restock_pressed(recipe_id: String) -> void:
	var quote := _recipe_restock_quote(recipe_id)
	if not bool(quote.get("ok", false)):
		_set_status("该配方当前不可补货。")
		return
	if quote.get("entries", []).is_empty():
		_set_status("当前配方材料充足。")
		return
	pending_research_bulk_restock = false
	pending_recipe_restock_id = recipe_id
	recipe_restock_dialog.call("configure", quote)
	recipe_restock_dialog.popup_centered(Vector2i(600, 460))


func _on_research_bulk_restock_pressed() -> void:
	if not state.is_feature_unlocked(RESEARCH_BULK_RESTOCK_FEATURE_ID):
		_set_status(_research_batch_locked_status("一键补货", RESEARCH_BULK_RESTOCK_TASK_ID))
		return
	var quote := _research_bulk_restock_quote()
	if not bool(quote.get("ok", false)):
		_set_status(String(quote.get("reason", "当前不可补货")))
		return
	if quote.get("entries", []).is_empty():
		_set_status("所有配方与加工的食材均已充足。")
		return
	pending_recipe_restock_id = ""
	pending_research_bulk_restock = true
	recipe_restock_dialog.call("configure", quote)
	recipe_restock_dialog.popup_centered(Vector2i(600, 460))


func _on_recipe_restock_confirmed() -> void:
	var is_bulk := pending_research_bulk_restock
	pending_research_bulk_restock = false
	var recipe_id := pending_recipe_restock_id
	pending_recipe_restock_id = ""
	var result: Dictionary = _purchase_research_bulk_restock() if is_bulk else _purchase_recipe_restock(recipe_id)
	var quote: Dictionary = result.get("quote", {})
	if not bool(result.get("ok", false)):
		if String(result.get("reason", "")) == "金币不足":
			_set_status("金币不足，无法补货：需要 %d，当前 %d。" % [
				int(quote.get("total_cost", 0)),
				int(state.coins)
			])
		else:
			_set_status(String(result.get("reason", "补货失败")))
		return

	if not is_bulk:
		state.record_task_event("manual_restock_success", {"action_kind": "recipe", "recipe_id": recipe_id})
	_save_game()
	_refresh_resource_bar()
	_refresh_current_page()
	var unavailable_names: Array[String] = []
	for entry_value: Variant in quote.get("unavailable_entries", []):
		var entry: Dictionary = entry_value
		unavailable_names.append(String(entry.get("name", "")))
	var status_prefix := "全部配方一键补货完成" if is_bulk else "一键补货完成"
	var status := "%s：购买 %d 件，花费 %d 金币。" % [
		status_prefix,
		int(quote.get("purchasable_units", 0)),
		int(quote.get("total_cost", 0))
	]
	if not unavailable_names.is_empty():
		status += " 仍需自产：%s。" % "、".join(unavailable_names)
	_set_status(status)
	if not is_bulk:
		_show_next_notification()


func _on_recipe_list_pressed(recipe_id: String) -> void:
	if not _require_core_feature(CoreFeatureUnlockService.LIST):
		return
	if not state.has_product(recipe_id):
		_set_status("库存不足，无法上架")
		return
	_display_recipe_product(recipe_id)
	_save_game()
	_refresh_current_page()
	_show_next_notification()


func _on_process_make_pressed(process_id: String) -> void:
	var unavailable_reason := _process_unavailable_status(process_id)
	if not unavailable_reason.is_empty():
		_set_status(unavailable_reason)
		return
	if _make_process_ingredient(process_id):
		state.record_task_event("manual_craft_success", {"action_kind": "processing", "process_id": process_id})
	_prune_empty_research_material_slots(true)
	_save_game()
	_refresh_current_page()
	_show_next_notification()


func _on_process_list_pressed(_process_id: String) -> void:
	_set_status("中间产品不可上架")


func _make_recipe_product(recipe_id: String, batches: int) -> bool:
	var result: Dictionary = RecipeBook.make_product(state, recipe_id, batches)
	_set_status(String(result.get("message", "已开始制作。")))
	return bool(result.get("ok", false))


func _make_process_ingredient(process_id: String) -> bool:
	var process: Dictionary = catalog.get_processing_recipes().get(process_id, {})
	if process.is_empty():
		_set_status("未知加工配方，无法制作。")
		return false
	var result: Dictionary = RecipeBook.process_ingredient(
		state,
		String(process.get("device", "")),
		process.get("materials", [])
	)
	_set_status(String(result.get("message", "加工完成。")))
	return bool(result.get("ok", false))


func _display_recipe_product(recipe_id: String) -> bool:
	if not _require_core_feature(CoreFeatureUnlockService.LIST):
		return false
	if recipe_id.is_empty():
		_set_status("请选择要上架的甜品。")
		return false
	if not state.has_product(recipe_id):
		_set_status("库存不足，无法上架")
		return false

	for slot_index in range(SHOWCASE_SLOT_COUNT):
		var drag_data := {
			"kind": "inventory_product",
			"recipe_id": recipe_id,
			"target_slot_index": slot_index,
			"manual_list_source": "button"
		}
		if _can_drop_showcase_data("showcase", drag_data):
			return _drop_showcase_data("showcase", drag_data)

	_set_status("暂无可上架的橱窗空位。")
	return false


func _make_all_available_products() -> void:
	if not state.is_feature_unlocked(RESEARCH_MAKE_ALL_FEATURE_ID):
		_set_status(_research_batch_locked_status("制作全部", RESEARCH_MAKE_ALL_TASK_ID))
		return
	var processed_count := 0
	var started_count := 0
	var capped_recipe_count := 0
	for process_id in _available_process_ids():
		if not _process_unavailable_status(process_id).is_empty():
			continue
		if _make_process_ingredient(process_id):
			processed_count += 1
	for recipe_id in _unlocked_recipe_ids():
		if not state.production_ready_recipe_record(recipe_id).is_empty() \
				and state.get_product_count(recipe_id) > 0:
			continue
		var unavailable_reason := _recipe_unavailable_status(recipe_id)
		if unavailable_reason == RECIPE_BATCH_LIMIT_STATUS:
			capped_recipe_count += 1
		if not unavailable_reason.is_empty():
			continue
		if _make_recipe_product(recipe_id, 1):
			started_count += 1
	if processed_count > 0 and started_count > 0:
		_set_status("已开始 %d 项中间加工和 %d 项成品制作。" % [processed_count, started_count])
	elif started_count > 0:
		_set_status("已开始制作 %d 项。" % started_count)
	elif processed_count > 0:
		_set_status("已开始 %d 项中间加工。" % processed_count)
	elif capped_recipe_count > 0:
		_set_status("没有可开始制作的项目；%d 种配方已有任务进行中。" % capped_recipe_count)
	else:
		_set_status("没有原料足够的项目。")
	_prune_empty_research_material_slots(true)


func _listed_showcase_stock_total() -> int:
	var total := 0
	for recipe_id_value: Variant in state.display_items.keys():
		total += int(state.get_display_item_stock(String(recipe_id_value)))
	return total


func _list_all_available_products() -> void:
	if not state.is_feature_unlocked(RESEARCH_LIST_ALL_FEATURE_ID):
		_set_status(_research_batch_locked_status("上架全部", RESEARCH_LIST_ALL_TASK_ID))
		return
	var listed_count := 0
	var now_unix := int(Time.get_unix_time_from_system())
	_invalidate_showcase_preview_bonus_cache()
	for recipe_id in _unlocked_recipe_ids():
		listed_count += _list_recipe_stock_batch(recipe_id, now_unix)
	if listed_count > 0:
		_set_status("已上架 %d 份成品。" % listed_count)
	else:
		_set_status("没有可上架的成品库存。")


func _research_batch_locked_status(feature_name: String, task_id: String) -> String:
	var task: Dictionary = TaskService.get_task_definitions().get(task_id, {})
	var title := String(task.get("title", task_id))
	var goal := maxi(1, int(task.get("goal", 1)))
	var progress_value: Variant = state.task_progress.get(task_id, {})
	var count := int((progress_value as Dictionary).get("count", 0)) if progress_value is Dictionary else 0
	return "%s尚未解锁：完成任务「%s」%d/%d。" % [feature_name, title, mini(count, goal), goal]


func _list_recipe_stock_batch(recipe_id: String, now_unix: int) -> int:
	var stock_count: int = state.get_product_count(recipe_id)
	if stock_count <= 0:
		return 0

	var variant_id := "standard"
	var base_sale_seconds: int = _random_showcase_sale_seconds()
	var round_phase := String(state.active_business_round.get("phase", "adjusting"))
	if state.has_method("is_display_item_placed") and state.is_display_item_placed(recipe_id):
		if _display_item_variant_id(recipe_id) != variant_id:
			return 0
		var anchor_slot_index: int = _display_anchor_slot_index_for_recipe(recipe_id)
		if anchor_slot_index < 0:
			return 0
		var inventory_before: int = state.get_product_count(recipe_id)
		if round_phase == "running":
			return inventory_before - state.get_product_count(recipe_id) if _refill_showcase_round_item(recipe_id, stock_count) else 0
		if not _refill_showcase_item(recipe_id, stock_count):
			return 0
		var accepted: int = inventory_before - state.get_product_count(recipe_id)
		_sync_showcase_slot_from_display_item(anchor_slot_index, recipe_id, accepted)
		return accepted

	var placement: Dictionary = _first_available_showcase_placement(recipe_id, variant_id)
	if placement.is_empty():
		return 0
	var slot_index: int = int(placement.get("slot_index", -1))
	var cells: Array[Vector2i] = []
	cells.assign(placement.get("cells", []))
	if round_phase == "running":
		return stock_count if _list_showcase_round_item(recipe_id, cells, variant_id, base_sale_seconds, stock_count) else 0
	if not state.list_display_item(recipe_id, cells, stock_count, variant_id, base_sale_seconds):
		return 0
	_sync_showcase_slot_from_display_item(slot_index, recipe_id, stock_count)
	_invalidate_showcase_bonus_cache()
	_invalidate_showcase_preview_bonus_cache()
	return stock_count


func _first_available_showcase_placement(recipe_id: String, variant_id: String) -> Dictionary:
	var round_phase := String(state.active_business_round.get("phase", "adjusting"))
	for slot_index in range(SHOWCASE_SLOT_COUNT):
		var cells := _showcase_cells_for_slot(recipe_id, slot_index, variant_id)
		if cells.is_empty() or not _are_showcase_cells_unlocked(cells):
			continue
		var can_place: bool = state.has_method("can_list_display_item_during_round") \
			and state.can_list_display_item_during_round(recipe_id, cells, 1, variant_id) \
			if round_phase == "running" \
			else state.has_method("can_place_display_item") and state.can_place_display_item(recipe_id, cells, variant_id)
		if can_place:
			return {
				"slot_index": slot_index,
				"cells": cells
			}
	return {}


func _refresh_research_material_list() -> void:
	_fill_research_inventory_grid()
	_refresh_research_tool_slot()


func _prune_empty_research_material_slots(show_status: bool) -> void:
	if selected_research_material_ids.size() > RESEARCH_INVENTORY_CELL_COUNT:
		selected_research_material_ids.resize(RESEARCH_INVENTORY_CELL_COUNT)
		_set_status("研发最多选择 6 种食材，已移除超出槽位的选择。")
	if state == null or selected_research_material_ids.is_empty():
		return
	var removed_names: Array[String] = []
	for index in range(selected_research_material_ids.size()):
		var material_id := String(selected_research_material_ids[index])
		if material_id.is_empty():
			continue
		if _material_stock(material_id) > 0:
			continue
		selected_research_material_ids[index] = ""
		removed_names.append(_material_name(material_id))
	while not selected_research_material_ids.is_empty() and String(selected_research_material_ids[selected_research_material_ids.size() - 1]).is_empty():
		selected_research_material_ids.pop_back()
	if show_status and not removed_names.is_empty():
		_set_status("已移除库存为 0 的研发食材：%s。" % "、".join(removed_names))


func _fill_research_inventory_grid() -> void:
	_prune_empty_research_material_slots(false)
	_clear_children(research_inventory_grid)
	for cell_index in range(RESEARCH_INVENTORY_CELL_COUNT):
		research_inventory_grid.add_child(_make_research_material_slot_cell(cell_index))


func _make_research_material_slot_cell(slot_index: int) -> Button:
	var material_id := String(selected_research_material_ids[slot_index]) if slot_index < selected_research_material_ids.size() else ""
	var button := ResearchInputSlotScene.instantiate() as Button
	button.set_meta("tutorial_research_slot_index", slot_index)
	button.custom_minimum_size = RESEARCH_MATERIAL_SLOT_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.clip_text = true
	if material_id.is_empty():
		_set_research_input_slot_visual(button, null, "", true, true)
		button.tooltip_text = "左键打开库存选择食材或成品。"
	else:
		_set_research_input_slot_visual(button, _material_icon_texture(material_id), _material_name(material_id), false, true)
		button.tooltip_text = "%s。左键重新选择，右键取消该研发材料。" % _material_name(material_id)
		button.set_meta("material_id", material_id)
	button.set_meta("slot_index", slot_index)
	button.pressed.connect(_on_research_material_slot_pressed.bind(slot_index))
	button.gui_input.connect(_on_research_material_slot_gui_input.bind(slot_index))
	return button


func _tutorial_target_for_step(step: String) -> Control:
	if state == null:
		return null
	match step:
		"purchase":
			if _purchase_cart_quantity("rice_seed") > 0:
				return purchase_confirm_button
			var farm_region := purchase_regions_by_category.get("农场") as Control
			if farm_region != null:
				return farm_region.call("tutorial_target_for_item", "rice_seed", "increase") as Control
		"output":
			return _tutorial_output_target()
		"research":
			return _tutorial_research_target()
		"craft":
			if _tutorial_recipe_is_producing("rice_milk_drink"):
				return null
			return _tutorial_recipe_action_target("make")
		"list":
			return _tutorial_recipe_action_target("list")
		"rulebook":
			return showcase_rulebook_button
		"arrange":
			if _is_showcase_round_layout_locked():
				return null
			return _tutorial_showcase_product_target("rice_milk_drink")
		"business":
			return null if showcase_start_round_button.disabled else showcase_start_round_button
		"storefront":
			return storefront_manage_button
	return null


func _tutorial_recipe_is_producing(recipe_id: String) -> bool:
	if state == null:
		return false
	for queued_value: Variant in state.recipe_production_queue:
		if queued_value is Dictionary and String((queued_value as Dictionary).get("recipe_id", "")) == recipe_id:
			return true
	return false


func _tutorial_output_target() -> Control:
	var requirements := [
		{"output_id": "rice", "site_id": "farm", "item_id": "rice_seed"}
	]
	for requirement: Dictionary in requirements:
		if state.tutorial_guide_harvested_ids.has(String(requirement.get("output_id", ""))):
			continue
		var slot_array_index := _tutorial_output_slot_array_index(String(requirement.get("site_id", "")), String(requirement.get("item_id", "")))
		if slot_array_index >= 0 and ProductionSite.is_slot_ready(state, slot_array_index):
			return _tutorial_output_active_cell(String(requirement.get("site_id", "")), slot_array_index)
	for requirement: Dictionary in requirements:
		if state.tutorial_guide_harvested_ids.has(String(requirement.get("output_id", ""))):
			continue
		if _tutorial_output_slot_array_index(String(requirement.get("site_id", "")), String(requirement.get("item_id", ""))) < 0:
			return _tutorial_output_idle_cell(String(requirement.get("site_id", "")))
	return null


func _tutorial_output_slot_array_index(site_id: String, item_id: String) -> int:
	for slot_array_index in range(state.production_slots.size()):
		var slot_value: Variant = state.production_slots[slot_array_index]
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		if String(slot.get("site_id", "")) == site_id and String(slot.get("item_id", "")) == item_id:
			return slot_array_index
	return -1


func _tutorial_output_idle_cell(site_id: String) -> Control:
	var grid_value: Variant = output_site_grids.get(site_id)
	if not grid_value is GridContainer:
		return null
	for child_value: Variant in (grid_value as GridContainer).get_children():
		if child_value is Control and String((child_value as Control).get_meta("output_kind", "")) == "idle":
			return child_value as Control
	return null


func _tutorial_output_active_cell(site_id: String, slot_array_index: int) -> Control:
	var grid_value: Variant = output_site_grids.get(site_id)
	if not grid_value is GridContainer:
		return null
	for child_value: Variant in (grid_value as GridContainer).get_children():
		if not child_value is Control:
			continue
		var child := child_value as Control
		if String(child.get_meta("output_kind", "")) == "active" and int(child.get_meta("slot_array_index", -1)) == slot_array_index:
			return child
	return null


func _tutorial_research_target() -> Control:
	var missing_material_id := ""
	for material_id in ["rice", "spring_water"]:
		if not selected_research_material_ids.has(material_id):
			missing_material_id = material_id
			break
	if not missing_material_id.is_empty():
		if global_popup_mode == "inventory" and global_overlay_layer.visible:
			return _tutorial_inventory_target("ingredient:%s" % missing_material_id)
		for child_value: Variant in research_inventory_grid.get_children():
			if child_value is Control:
				var slot_index := int((child_value as Control).get_meta("tutorial_research_slot_index", -1))
				var selected_id := String(selected_research_material_ids[slot_index]) if slot_index >= 0 and slot_index < selected_research_material_ids.size() else ""
				if selected_id.is_empty():
					return child_value as Control
	if selected_research_tool_id != "round_pot":
		return research_tool_slot
	return primary_action_button


func _tutorial_inventory_target(inventory_key: String) -> Control:
	for child_value: Variant in inventory_grid.get_children():
		if child_value is Control and String((child_value as Control).get_meta("inventory_key", "")) == inventory_key:
			return child_value as Control
	return null


func _tutorial_recipe_action_target(action: String) -> Control:
	var row_target: Control = production_workbench.row_tutorial_target(
		"finished",
		"rice_milk_drink",
		action
	) as Control
	return row_target if row_target != null else production_workbench.tutorial_target("search")


func _tutorial_showcase_product_target(recipe_id: String) -> Control:
	for child_value: Variant in showcase_grid.get_children():
		if child_value is Control and String((child_value as Control).get_meta("recipe_id", "")) == recipe_id:
			return child_value as Control
	return null


func _research_inventory_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var ingredients := catalog.get_ingredients()
	for item_id in _sorted_keys(state.ingredient_inventory):
		var stock: int = state.get_ingredient_count(item_id)
		if stock <= 0 or not ingredients.has(item_id):
			continue

		entries.append({
			"kind": "ingredient",
			"id": item_id,
			"name": _ingredient_name(item_id),
			"count": stock
		})

	var recipes := catalog.get_recipes()
	for recipe_id in _sorted_keys(state.product_inventory):
		var stock: int = state.get_product_count(recipe_id)
		if stock <= 0 or not recipes.has(recipe_id):
			continue

		entries.append({
			"kind": "product",
			"id": recipe_id,
			"name": _recipe_name(recipe_id),
			"count": stock
		})
	return entries


func _make_research_inventory_cell(entry: Dictionary) -> Button:
	var material_id := String(entry.get("id", ""))
	var button := BasicButtonScene.instantiate() as Button
	button.text = "\n%s\nx%d" % [
		String(entry.get("name", material_id)),
		int(entry.get("count", 0))
	]
	button.toggle_mode = true
	button.button_pressed = selected_research_material_ids.has(material_id)
	button.custom_minimum_size = RESEARCH_MATERIAL_SLOT_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.tooltip_text = "点击选择/取消选择研发或加工材料。"
	button.set_meta("material_id", material_id)
	button.set_meta("kind", String(entry.get("kind", "")))
	_add_ingredient_icon_to_button(button, material_id, Vector2(28, 28), Vector2(6, 4))
	button.pressed.connect(_on_research_material_cell_pressed.bind(material_id))
	return button


func _make_research_empty_cell(size: Vector2) -> Button:
	var button := BasicButtonScene.instantiate() as Button
	button.custom_minimum_size = size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = true
	button.clip_text = true
	return button


func _set_research_input_slot_visual(button: Button, texture: Texture2D, display_name: String, empty: bool, fill_slot: bool = false, show_name: bool = true) -> void:
	button.text = ""
	var icon := button.get_node("Icon") as TextureRect
	var plus_label := button.get_node("PlusLabel") as Label
	var name_backdrop := button.get_node("NameBackdrop") as ColorRect
	var name_label := button.get_node("NameLabel") as Label
	if fill_slot:
		icon.anchor_left = 0.0
		icon.anchor_top = 0.0
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = 0.0
		icon.offset_top = 0.0
		icon.offset_right = 0.0
		icon.offset_bottom = 0.0
	icon.texture = texture
	icon.visible = not empty and texture != null
	plus_label.visible = empty
	name_backdrop.visible = not empty and show_name
	name_label.text = display_name
	name_label.visible = not empty and show_name


func _device_icon_texture(device_id: String) -> Texture2D:
	var path := "%s/%s.png" % [DEVICE_ICON_DIRECTORY, device_id]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var image := Image.new()
	if image.load_png_from_buffer(file.get_buffer(file.get_length())) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _refresh_research_tool_slot() -> void:
	var entries := _research_tool_entries()
	if selected_research_tool_id.is_empty() or not _research_tool_entries_have(entries, selected_research_tool_id):
		selected_research_tool_id = String(entries[0].get("id", "")) if not entries.is_empty() else ""
	research_tool_slot.custom_minimum_size = RESEARCH_TOOL_SLOT_SIZE
	if selected_research_tool_id.is_empty():
		research_tool_slot.remove_meta("tool_id")
		_set_research_input_slot_visual(research_tool_slot, null, "", true, true)
		research_tool_slot.tooltip_text = "点击选择研发工具。"
		return
	research_tool_slot.set_meta("tool_id", selected_research_tool_id)
	_set_research_input_slot_visual(research_tool_slot, _device_icon_texture(selected_research_tool_id), _device_name(selected_research_tool_id), false, true)
	research_tool_slot.tooltip_text = "当前工具：%s。点击更换。" % _device_name(selected_research_tool_id)


func _fill_research_tool_grid() -> void:
	_refresh_research_tool_slot()


func _fill_research_tool_picker() -> void:
	_clear_children(research_tool_picker_grid)
	for entry in _research_tool_entries():
		research_tool_picker_grid.add_child(_make_research_tool_cell(entry))


func _research_tool_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var devices := catalog.get_devices()
	for device_id in _sorted_keys(devices):
		var device: Dictionary = devices[device_id]
		if not state.is_device_unlocked(device_id):
			continue

		entries.append({
			"id": device_id,
			"name": String(device.get("name", device_id))
		})
	return entries


func _research_tool_entries_have(entries: Array[Dictionary], tool_id: String) -> bool:
	for entry in entries:
		if String(entry.get("id", "")) == tool_id:
			return true
	return false


func _research_summary_text() -> String:
	var material_count := _selected_research_material_ids().size()
	if material_count <= 0:
		return "至少选择 2 个食材开始研发"
	if material_count == 1:
		return "已选择 1 个材料｜点击研发将进行加工"
	if selected_research_tool_id.is_empty():
		return "已选择 %d 个材料｜请选择研发工具" % material_count
	return "已选择 %d 个材料｜设备：%s｜点击研发开始" % [material_count, _device_name(selected_research_tool_id)]


func _research_hint_body_text(hint: Dictionary) -> String:
	if hint.is_empty() or int(hint.get("level", 0)) <= 0:
		return "选择至少 2 个食材并进行研发，接近失败会留下永久线索。"
	var level := int(hint.get("level", 0))
	var matched := int(hint.get("matched_count", 0))
	var required := int(hint.get("required_count", 0))
	if level == 1:
		return "方向：%s\n已确认：%d/%d 种材料\n再次接近失败将揭示目标配方。" % [
			String(hint.get("direction", "研发")),
			matched,
			required
		]
	if level == 2:
		var category_names: Array[String] = []
		for category_value: Variant in hint.get("missing_categories", []):
			category_names.append(String(category_value))
		var material_summary := "材料已齐" if category_names.is_empty() else "缺少类别：%s" % "、".join(category_names)
		return "正确设备：%s\n已确认：%d/%d 种材料\n%s\n再次接近失败将揭示完整材料。" % [
			_device_name(String(hint.get("correct_device_id", ""))),
			matched,
			required,
			material_summary
		]
	var lines: Array[String] = ["设备：%s" % _device_name(String(hint.get("correct_device_id", "")))]
	for status_value: Variant in hint.get("material_statuses", []):
		if not status_value is Dictionary:
			continue
		var status: Dictionary = status_value
		lines.append("%s：%s" % [
			_material_name(String(status.get("item_id", ""))),
			String(status.get("status", ""))
		])
	return "\n".join(lines)


func _research_hint_title_text(hint: Dictionary) -> String:
	var level := int(hint.get("level", 0))
	if level <= 0:
		return "研发笔记｜暂无有效线索"
	var label := "完整线索" if level >= 3 else "线索等级 %d" % level
	var recipe_name := String(hint.get("recipe_name", ""))
	return "研发笔记｜%s%s" % [
		label,
		"｜%s" % recipe_name if not recipe_name.is_empty() else ""
	]


func _refresh_research_summary() -> void:
	page_description.text = "研发制作｜%s" % _research_summary_text()


func _make_research_tool_cell(entry: Dictionary) -> Button:
	var tool_id := String(entry.get("id", ""))
	var tool_name := String(entry.get("name", tool_id))
	var button := ResearchInputSlotScene.instantiate() as Button
	button.custom_minimum_size = RESEARCH_TOOL_PICKER_CELL_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_set_research_input_slot_visual(button, _device_icon_texture(tool_id), tool_name, false, true, false)
	button.tooltip_text = tool_name
	button.set_meta("tool_id", tool_id)
	button.pressed.connect(_on_research_tool_cell_pressed.bind(tool_id))
	return button


func _on_research_material_cell_pressed(material_id: String) -> void:
	if material_id.is_empty():
		return
	if selected_research_material_ids.has(material_id):
		selected_research_material_ids.erase(material_id)
	else:
		if _selected_research_material_ids().size() >= RESEARCH_INVENTORY_CELL_COUNT:
			_set_status("研发最多选择 6 种食材。")
			return
		selected_research_material_ids.append(material_id)
	_fill_research_inventory_grid()
	_refresh_research_summary()


func _on_research_material_slot_pressed(slot_index: int) -> void:
	pending_research_material_slot_index = clampi(slot_index, 0, RESEARCH_INVENTORY_CELL_COUNT - 1)
	selected_inventory_tab = "all"
	selected_inventory_page = 0
	_show_inventory_global_popup(PAGE_RESEARCH)
	_set_status("选择一个库存食材或成品填入研发坑位 %d。" % (pending_research_material_slot_index + 1))
	call_deferred("_refresh_tutorial_guide")


func _on_research_material_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	_clear_research_material_slot(slot_index)


func _clear_research_material_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= selected_research_material_ids.size():
		return
	var material_id := String(selected_research_material_ids[slot_index])
	if material_id.is_empty():
		return
	selected_research_material_ids[slot_index] = ""
	while not selected_research_material_ids.is_empty() and String(selected_research_material_ids[selected_research_material_ids.size() - 1]).is_empty():
		selected_research_material_ids.pop_back()
	pending_research_material_slot_index = -1
	_fill_research_inventory_grid()
	_refresh_research_summary()
	_set_status("已取消研发材料：%s。" % _material_name(material_id))


func _on_research_tool_cell_pressed(tool_id: String) -> void:
	selected_research_tool_id = tool_id
	research_tool_picker_popup.hide()
	_refresh_research_tool_slot()
	_refresh_research_summary()
	_set_status("已选择研发工具：%s。" % _device_name(tool_id))
	call_deferred("_refresh_tutorial_guide")


func _on_research_tool_slot_pressed() -> void:
	_fill_research_tool_picker()
	research_tool_picker_popup.popup_centered()
	# PopupPanel shrinks to its content minimum when shown, so enforce the approved size afterwards.
	research_tool_picker_popup.size = RESEARCH_TOOL_PICKER_POPUP_SIZE
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	research_tool_picker_popup.position = (viewport_size - RESEARCH_TOOL_PICKER_POPUP_SIZE) / 2


func _prune_research_material_selection_from_entries(entries: Array[Dictionary]) -> void:
	var available := {}
	for entry in entries:
		available[String(entry.get("id", ""))] = true

	var next_selection: Array[String] = []
	for id in selected_research_material_ids:
		if available.has(id):
			next_selection.append(id)
	selected_research_material_ids = next_selection


func _production_queue_entries(now_unix: int = -1) -> Array:
	return _build_unified_production_queue_snapshot(now_unix).get("queue_entries", [])


func _build_unified_production_queue_snapshot(now_unix: int = -1) -> Dictionary:
	var current_time := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var recipe_summary: Dictionary = state.recipe_production_queue_summary(current_time)
	var processing_summary: Dictionary = state.ingredient_processing_queue_summary(current_time)
	var recipes: Dictionary = catalog.get_recipes()
	var processes: Dictionary = catalog.get_processing_recipes()
	var ingredients: Dictionary = catalog.get_ingredients()
	var devices: Dictionary = catalog.get_devices()
	var completed_entries: Array = []
	var queue_entries: Array = []
	var stable_order := 0

	for process_id_value: Variant in processes.keys():
		var process_id := String(process_id_value)
		var process: Dictionary = processes.get(process_id, {})
		if process.is_empty() or int(process.get("unlock_level", 1)) > state.level:
			stable_order += 1
			continue
		var output_item_id := String(process.get("output_item_id", ""))
		if not state.has_method("is_ingredient_process_unlocked") \
				or not state.is_ingredient_process_unlocked(output_item_id):
			stable_order += 1
			continue
		var material_entries := _production_material_entries(
			process.get("materials", []),
			ingredients,
			recipes
		)
		var active: Dictionary = processing_summary.get(process_id, {})
		var is_active: bool = not active.is_empty()
		var device_id := String(process.get("device", ""))
		var device_available: bool = devices.has(device_id) and state.is_device_unlocked(device_id)
		var has_missing: bool = _production_material_entries_have_missing(material_entries)
		var can_craft: bool = not has_missing and device_available
		var disabled_reason: String = ""
		if has_missing:
			disabled_reason = _production_material_missing_reason(material_entries)
		elif not device_available:
			disabled_reason = "工具%s未解锁" % _device_name(device_id)
		var duration_seconds := maxi(1, int(process.get("production_duration_seconds", 1)))
		var search_parts: Array[String] = [process_id, _ingredient_name(output_item_id)]
		for material_entry_value: Variant in material_entries:
			if material_entry_value is Dictionary:
				search_parts.append(String((material_entry_value as Dictionary).get("name", "")))
		queue_entries.append({
			"entry_kind": "processing",
			"kind": "processing",
			"id": process_id,
			"recipe_id": process_id,
			"name": _ingredient_name(output_item_id),
			"icon": _material_icon_texture(output_item_id),
			"materials": material_entries,
			"duration_seconds": duration_seconds,
			"remaining_seconds": int(active.get("remaining_seconds", duration_seconds)),
			"price": 0,
			"is_active": is_active,
			"is_craftable": can_craft,
			"progress": float(active.get("progress", 0.0)),
			"action_kind": "active" if is_active else "make",
			"action_enabled": not is_active and can_craft,
			"disabled_reason": disabled_reason,
			"inventory_count": state.get_ingredient_count(output_item_id),
			"completed_stock_count": 0,
			"sort_band": 0 if is_active or can_craft else 2,
			"stable_order": stable_order,
			"search_haystack": " ".join(search_parts)
		})
		stable_order += 1

	stable_order = 0
	for recipe_id_value: Variant in recipes.keys():
		var recipe_id := String(recipe_id_value)
		if not state.is_recipe_unlocked(recipe_id):
			stable_order += 1
			continue
		var recipe: Dictionary = recipes.get(recipe_id, {})
		var device_id := String(recipe.get("device", ""))
		if recipe.is_empty() or not devices.has(device_id) or not state.is_device_unlocked(device_id):
			stable_order += 1
			continue
		var material_entries := _production_material_entries(
			recipe.get("materials", []),
			ingredients,
			recipes
		)
		var summary_entry: Dictionary = recipe_summary.get(recipe_id, {})
		var batch_progress: Array = summary_entry.get("batch_progress", [])
		var active: Dictionary = batch_progress[0] as Dictionary if not batch_progress.is_empty() and batch_progress[0] is Dictionary else {}
		var is_active := int(summary_entry.get("active_count", 0)) > 0
		var has_missing := _production_material_entries_have_missing(material_entries)
		var can_craft := not has_missing
		var restock_quote := _recipe_restock_quote(recipe_id) if has_missing else {}
		var restockable := has_missing and not (restock_quote.get("purchasable_entries", []) as Array).is_empty()
		var disabled_reason := _production_material_missing_reason(material_entries) if has_missing else ""
		var action_kind := "active" if is_active else ("restock" if has_missing else "make")
		state.prune_recipe_production_ready_record(recipe_id)
		var ready_record: Dictionary = state.production_ready_recipe_record(recipe_id)
		var completed_stock_count: int = state.get_product_count(recipe_id) if not ready_record.is_empty() else 0
		var duration_seconds := maxi(1, int(recipe.get("production_duration_seconds", 1)))
		var search_parts: Array[String] = [recipe_id, String(recipe.get("name", recipe_id))]
		for material_entry_value: Variant in material_entries:
			if material_entry_value is Dictionary:
				search_parts.append(String((material_entry_value as Dictionary).get("name", "")))
		for tag_value: Variant in recipe.get("tags", []):
			search_parts.append(String(tag_value))
		var entry := {
			"entry_kind": "finished",
			"kind": "recipe",
			"id": recipe_id,
			"recipe_id": recipe_id,
			"name": String(recipe.get("name", recipe_id)),
			"icon": _recipe_icon_texture(recipe_id, "base"),
			"tags": (recipe.get("tags", []) as Array).duplicate(),
			"materials": material_entries,
			"duration_seconds": duration_seconds,
			"remaining_seconds": int(active.get("remaining_seconds", duration_seconds)),
			"price": maxi(0, int(recipe.get("price", 0))),
			"is_active": is_active,
			"is_craftable": can_craft,
			"progress": float(active.get("progress", 0.0)),
			"action_kind": action_kind,
			"action_enabled": not is_active and (can_craft or restockable),
			"disabled_reason": disabled_reason,
			"inventory_count": state.get_product_count(recipe_id),
			"completed_stock_count": completed_stock_count,
			"sort_band": 1 if is_active or can_craft else 3,
			"stable_order": stable_order,
			"search_haystack": " ".join(search_parts)
		}
		if completed_stock_count > 0:
			var drag_details := _production_queue_completed_stock_drag_details(recipe_id)
			entry["completed_stock_drag_enabled"] = bool(drag_details.get("enabled", false))
			entry["completed_stock_tooltip"] = String(drag_details.get("tooltip", ""))
			entry["drag_data"] = drag_details.get("drag_data", {})
			entry["drag_preview_text"] = String(drag_details.get("preview_text", ""))
			entry["drag_preview_data"] = drag_details.get("preview_data", {})
			entry["drag_end_callable"] = drag_details.get("end_callable", Callable())
			completed_entries.append(entry)
			stable_order += 1
			continue
		queue_entries.append(entry)
		stable_order += 1

	completed_entries.sort_custom(_completed_production_entry_less)
	queue_entries.sort_custom(_unified_production_entry_less)
	return {
		"completed_entries": completed_entries,
		"queue_entries": queue_entries,
		"active_count": _production_active_batch_count(queue_entries)
	}


func _production_queue_runtime_entries(now_unix: int) -> Array:
	var recipe_summary: Dictionary = state.recipe_production_queue_summary(now_unix)
	var processing_summary: Dictionary = state.ingredient_processing_queue_summary(now_unix)
	var runtime_entries: Array = []
	for entry_value: Variant in production_queue_snapshot.get("queue_entries", []):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var entry_kind := String(entry.get("entry_kind", "finished"))
		var entry_id := String(entry.get("recipe_id", ""))
		var active := {}
		var is_active := false
		if entry_kind == "processing":
			active = processing_summary.get(entry_id, {})
			is_active = not (active as Dictionary).is_empty()
		else:
			var summary_entry: Dictionary = recipe_summary.get(entry_id, {})
			var batch_progress: Array = summary_entry.get("batch_progress", [])
			active = batch_progress[0] as Dictionary if not batch_progress.is_empty() and batch_progress[0] is Dictionary else {}
			is_active = int(summary_entry.get("active_count", 0)) > 0
		runtime_entries.append({
			"entry_kind": entry_kind,
			"recipe_id": entry_id,
			"is_active": is_active,
			"progress": float((active as Dictionary).get("progress", 0.0)),
			"remaining_seconds": int((active as Dictionary).get(
				"remaining_seconds",
				entry.get("duration_seconds", 0)
			)),
			"duration_seconds": int(entry.get("duration_seconds", 0)),
			"action_kind": "active" if is_active else String(entry.get("action_kind", "make")),
			"disabled_reason": String(entry.get("disabled_reason", ""))
		})
	return runtime_entries


func _production_material_entries(
	materials_value: Variant,
	ingredients: Dictionary,
	recipes: Dictionary
) -> Array:
	var result: Array = []
	if not materials_value is Array:
		return result
	var required_by_id: Dictionary = {}
	var ordered_ids: Array[String] = []
	for material_value: Variant in materials_value:
		var material_id := String(material_value)
		if material_id.is_empty():
			continue
		if not required_by_id.has(material_id):
			required_by_id[material_id] = 0
			ordered_ids.append(material_id)
		required_by_id[material_id] = int(required_by_id[material_id]) + 1
	for material_id in ordered_ids:
		var required: int = int(required_by_id[material_id])
		var owned: int = (
			state.get_ingredient_count(material_id)
			if ingredients.has(material_id)
			else state.get_product_count(material_id)
		)
		var missing: bool = owned < required
		var material_name: String = _material_name_from_catalog(material_id, ingredients, recipes)
		result.append({
			"id": material_id,
			"name": material_name,
			"icon": _material_icon_texture(material_id),
			"required_count": required,
			"owned_count": owned,
			"missing": missing,
			"display_text": "%s %d/%d" % [material_name, owned, required] if missing else "%s ×%d" % [material_name, required],
			"tooltip": "%s｜库存 %d，需要 %d" % [material_name, owned, required]
		})
	return result


func _production_material_entries_have_missing(materials: Array) -> bool:
	for material_value: Variant in materials:
		if material_value is Dictionary and bool((material_value as Dictionary).get("missing", false)):
			return true
	return false


func _production_material_missing_reason(materials: Array) -> String:
	var missing_names: Array[String] = []
	for material_value: Variant in materials:
		if material_value is Dictionary and bool((material_value as Dictionary).get("missing", false)):
			missing_names.append(String((material_value as Dictionary).get("name", "")))
	return "原料%s不足" % "、".join(missing_names) if not missing_names.is_empty() else ""


func _unified_production_entry_less(first: Dictionary, second: Dictionary) -> bool:
	var first_band := int(first.get("sort_band", 0))
	var second_band := int(second.get("sort_band", 0))
	if first_band != second_band:
		return first_band < second_band
	var entry_kind := String(first.get("entry_kind", "finished"))
	if entry_kind == "processing":
		var first_duration := int(first.get("duration_seconds", 0))
		var second_duration := int(second.get("duration_seconds", 0))
		if first_duration != second_duration:
			return first_duration < second_duration
	else:
		var first_price := int(first.get("price", 0))
		var second_price := int(second.get("price", 0))
		if first_price != second_price:
			return first_price > second_price
	return int(first.get("stable_order", 0)) < int(second.get("stable_order", 0))


func _completed_production_entry_less(first: Dictionary, second: Dictionary) -> bool:
	var first_price := int(first.get("price", 0))
	var second_price := int(second.get("price", 0))
	if first_price != second_price:
		return first_price > second_price
	return int(first.get("stable_order", 0)) < int(second.get("stable_order", 0))


func _production_queue_completed_stock_drag_details(recipe_id: String) -> Dictionary:
	var variant_id := _selected_showcase_variant(recipe_id)
	var shape_info := _showcase_drag_shape_info(recipe_id, variant_id)
	var can_drag: bool = state.is_core_feature_unlocked(CoreFeatureUnlockService.LIST) and state.has_product(recipe_id)
	var shape_text := "%s / %d格" % [
		String(shape_info.get("default_shape", "1x1")),
		int(shape_info.get("cell_count", 1))
	]
	var tooltip := "拖到橱窗上架；每次上架 1 件。"
	if not can_drag:
		tooltip = state.core_feature_locked_reason(CoreFeatureUnlockService.LIST)
	return {
		"enabled": can_drag,
		"tooltip": tooltip,
		"drag_data": {
			"kind": "inventory_product",
			"recipe_id": recipe_id,
			"variant_id": variant_id,
			"manual_list_source": "drag",
			"default_shape": String(shape_info.get("default_shape", "1x1")),
			"shape_rows": int(shape_info.get("shape_rows", 1)),
			"shape_cols": int(shape_info.get("shape_cols", 1)),
			"cell_count": int(shape_info.get("cell_count", 1)),
			"shape_cells": shape_info.get("shape_cells", [])
		},
		"preview_text": "%s\n%s\n%s" % [
			_recipe_name(recipe_id),
			_showcase_variant_label(variant_id),
			shape_text
		],
		"preview_data": shape_info,
		"end_callable": Callable(self, "_on_production_queue_completed_stock_drag_ended")
	}


func _on_production_queue_completed_stock_drag_ended() -> void:
	_clear_showcase_drag_preview()


func _build_production_picker_snapshot() -> Dictionary:
	var craftable: Array = []
	var missing: Array = []
	var recipes: Dictionary = catalog.get_recipes()
	var ingredients: Dictionary = catalog.get_ingredients()
	var devices: Dictionary = catalog.get_devices()
	var processes: Dictionary = catalog.get_processing_recipes()
	var stable_order := 0

	for recipe_id in _sorted_keys(recipes):
		if not state.is_recipe_unlocked(recipe_id):
			continue
		var recipe: Dictionary = recipes.get(recipe_id, {})
		var device_id := String(recipe.get("device", ""))
		var device: Dictionary = devices.get(device_id, {})
		if recipe.is_empty() or device.is_empty() or not state.is_device_unlocked(device_id):
			stable_order += 1
			continue
		var active_count: int = state.active_recipe_production_batch_count(recipe_id)
		if active_count >= GameState.MAX_CONCURRENT_RECIPE_BATCHES:
			stable_order += 1
			continue
		var entry := _production_picker_recipe_entry(
			recipe_id,
			recipe,
			recipes,
			ingredients,
			active_count,
			stable_order
		)
		if String(entry.get("filter", "")) == PICKER_FILTER_CRAFTABLE:
			craftable.append(entry)
		else:
			missing.append(entry)
		stable_order += 1

	for process_id in _sorted_keys(processes):
		var process_entry := _production_picker_process_entry(
			process_id,
			processes.get(process_id, {}),
			recipes,
			ingredients,
			devices,
			stable_order
		)
		if process_entry.is_empty():
			continue
		if String(process_entry.get("filter", "")) == PICKER_FILTER_CRAFTABLE:
			craftable.append(process_entry)
		else:
			missing.append(process_entry)
		stable_order += 1

	_sort_production_picker_entries(craftable, missing)
	return {
		"craftable": craftable,
		"missing": missing,
		"craftable_count": craftable.size(),
		"missing_count": missing.size()
	}


func _production_picker_recipe_entry(
	recipe_id: String,
	recipe: Dictionary,
	recipes: Dictionary,
	ingredients: Dictionary,
	active_count: int,
	stable_order: int
) -> Dictionary:
	var missing_ids := _missing_recipe_material_ids_from_catalog(recipe, ingredients, recipes)
	var entry_filter := PICKER_FILTER_CRAFTABLE if missing_ids.is_empty() else PICKER_FILTER_MISSING
	var missing_names: Array[String] = []
	for material_id in missing_ids:
		missing_names.append(_material_name_from_catalog(material_id, ingredients, recipes))
	var restockable := false
	for material_id in missing_ids:
		var ingredient: Dictionary = ingredients.get(material_id, {})
		if not ingredient.is_empty() and _is_ingredient_available_for_purchase(material_id, ingredient):
			restockable = true
			break
	var search_parts: Array[String] = [recipe_id, String(recipe.get("name", recipe_id))]
	for material_value: Variant in recipe.get("materials", []):
		search_parts.append(_material_name_from_catalog(String(material_value), ingredients, recipes))
	for tag_value: Variant in recipe.get("tags", []):
		search_parts.append(String(tag_value))
	return {
		"id": recipe_id,
		"kind": "recipe",
		"filter": entry_filter,
		"name": String(recipe.get("name", recipe_id)),
		"icon": _material_icon_texture(recipe_id),
		"stock_count": state.get_product_count(recipe_id),
		"active_count": active_count,
		"remaining_capacity": GameState.MAX_CONCURRENT_RECIPE_BATCHES - active_count,
		"materials_text": "材料：%s" % _material_stock_requirements_from_catalog(
			recipe.get("materials", []),
			ingredients,
			recipes
		),
		"reason": "" if missing_names.is_empty() else "原料%s不足" % "、".join(missing_names),
		"missing_count": missing_ids.size(),
		"restockable": restockable,
		"action_enabled": true if entry_filter == PICKER_FILTER_CRAFTABLE else restockable,
		"can_list": state.has_product(recipe_id) and state.is_core_feature_unlocked(CoreFeatureUnlockService.LIST),
		"stable_order": stable_order,
		"search_haystack": " ".join(search_parts)
	}


func _production_picker_process_entry(
	process_id: String,
	process: Dictionary,
	recipes: Dictionary,
	ingredients: Dictionary,
	devices: Dictionary,
	stable_order: int
) -> Dictionary:
	if process.is_empty() or int(process.get("unlock_level", 1)) > state.level:
		return {}
	var output_item_id := String(process.get("output_item_id", ""))
	if not state.has_method("is_ingredient_process_unlocked") or not state.is_ingredient_process_unlocked(output_item_id):
		return {}
	var missing_ids: Array[String] = []
	for material_value: Variant in process.get("materials", []):
		var material_id := String(material_value)
		if not ingredients.has(material_id) or not state.has_ingredient(material_id):
			missing_ids.append(material_id)
	var entry_filter := PICKER_FILTER_CRAFTABLE if missing_ids.is_empty() else PICKER_FILTER_MISSING
	var missing_names: Array[String] = []
	for material_id in missing_ids:
		missing_names.append(_material_name_from_catalog(material_id, ingredients, recipes))
	var device_id := String(process.get("device", ""))
	var reason := "" if missing_names.is_empty() else "原料%s不足" % "、".join(missing_names)
	var device: Dictionary = devices.get(device_id, {})
	if reason.is_empty() and (device.is_empty() or not state.is_device_unlocked(device_id)):
		reason = "工具%s未解锁" % String(device.get("name", device_id))
	var search_parts: Array[String] = [
		process_id,
		_material_name_from_catalog(output_item_id, ingredients, recipes)
	]
	for material_value: Variant in process.get("materials", []):
		search_parts.append(_material_name_from_catalog(String(material_value), ingredients, recipes))
	return {
		"id": process_id,
		"kind": "processing",
		"filter": entry_filter,
		"name": _material_name_from_catalog(output_item_id, ingredients, recipes),
		"icon": _material_icon_texture(output_item_id),
		"stock_count": state.get_ingredient_count(output_item_id),
		"materials_text": "材料：%s" % _material_stock_requirements_from_catalog(
			process.get("materials", []),
			ingredients,
			recipes
		),
		"reason": reason,
		"missing_count": missing_ids.size(),
		"restockable": false,
		"action_enabled": entry_filter == PICKER_FILTER_CRAFTABLE,
		"can_list": false,
		"stable_order": stable_order,
		"search_haystack": " ".join(search_parts)
	}


func _missing_recipe_material_ids_from_catalog(
	recipe: Dictionary,
	ingredients: Dictionary,
	recipes: Dictionary
) -> Array[String]:
	var missing: Array[String] = []
	for material_value: Variant in recipe.get("materials", []):
		var material_id := String(material_value)
		if ingredients.has(material_id):
			if not state.has_ingredient(material_id):
				missing.append(material_id)
		elif recipes.has(material_id):
			if not state.has_product(material_id):
				missing.append(material_id)
		else:
			missing.append(material_id)
	return missing


func _material_name_from_catalog(
	material_id: String,
	ingredients: Dictionary,
	recipes: Dictionary
) -> String:
	if ingredients.has(material_id):
		var ingredient: Dictionary = ingredients.get(material_id, {})
		return String(ingredient.get("name", material_id))
	var recipe: Dictionary = recipes.get(material_id, {})
	return String(recipe.get("name", material_id))


func _material_stock_requirements_from_catalog(
	materials_value: Variant,
	ingredients: Dictionary,
	recipes: Dictionary
) -> String:
	if not materials_value is Array:
		return ""
	var required_by_id: Dictionary = {}
	var ordered_ids: Array[String] = []
	for material_value: Variant in materials_value:
		var material_id := String(material_value)
		if material_id.is_empty():
			continue
		if not required_by_id.has(material_id):
			required_by_id[material_id] = 0
			ordered_ids.append(material_id)
		required_by_id[material_id] = int(required_by_id[material_id]) + 1
	var parts: Array[String] = []
	for material_id in ordered_ids:
		var stock: int = (
			state.get_ingredient_count(material_id)
			if ingredients.has(material_id)
			else state.get_product_count(material_id)
		)
		parts.append("%s %d/%d" % [
			_material_name_from_catalog(material_id, ingredients, recipes),
			stock,
			int(required_by_id[material_id])
		])
	return ", ".join(parts)


func _sort_production_picker_entries(craftable: Array, missing: Array) -> void:
	craftable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var capacity_a := int(a.get("remaining_capacity", 0 if String(a.get("kind", "")) == "recipe" else 4))
		var capacity_b := int(b.get("remaining_capacity", 0 if String(b.get("kind", "")) == "recipe" else 4))
		if capacity_a != capacity_b:
			return capacity_a > capacity_b
		return int(a.get("stable_order", 0)) < int(b.get("stable_order", 0))
	)
	missing.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("restockable", false)) != bool(b.get("restockable", false)):
			return bool(a.get("restockable", false))
		if int(a.get("missing_count", 0)) != int(b.get("missing_count", 0)):
			return int(a.get("missing_count", 0)) < int(b.get("missing_count", 0))
		return int(a.get("stable_order", 0)) < int(b.get("stable_order", 0))
	)


func _production_picker_entries(filter_id: String) -> Array:
	var snapshot := _build_production_picker_snapshot()
	return (
		snapshot.get("missing", [])
		if filter_id == PICKER_FILTER_MISSING
		else snapshot.get("craftable", [])
	)


func _legacy_production_picker_entries(filter_id: String) -> Array:
	var entries: Array = []
	var recipes: Dictionary = catalog.get_recipes()
	var stable_order := 0
	for recipe_id in _unlocked_recipe_ids():
		var recipe: Dictionary = recipes.get(recipe_id, {})
		var device_id := String(recipe.get("device", ""))
		if recipe.is_empty() or not _research_device_available(device_id):
			stable_order += 1
			continue
		var active_count: int = state.active_recipe_production_batch_count(recipe_id)
		if active_count >= GameState.MAX_CONCURRENT_RECIPE_BATCHES:
			stable_order += 1
			continue
		var missing_ids := _missing_recipe_material_ids(recipe_id)
		var entry_filter := PICKER_FILTER_CRAFTABLE if missing_ids.is_empty() else PICKER_FILTER_MISSING
		if entry_filter != filter_id:
			stable_order += 1
			continue
		var restock_quote := _recipe_restock_quote(recipe_id)
		var restockable := not (restock_quote.get("purchasable_entries", []) as Array).is_empty()
		entries.append({
			"id": recipe_id,
			"kind": "recipe",
			"filter": entry_filter,
			"name": String(recipe.get("name", recipe_id)),
			"icon": _material_icon_texture(recipe_id),
			"stock_count": state.get_product_count(recipe_id),
			"active_count": active_count,
			"remaining_capacity": GameState.MAX_CONCURRENT_RECIPE_BATCHES - active_count,
			"materials_text": "材料：%s" % _material_stock_requirements(recipe.get("materials", [])),
			"reason": _recipe_missing_material_status(recipe_id),
			"missing_count": missing_ids.size(),
			"restockable": restockable,
			"action_enabled": true if entry_filter == PICKER_FILTER_CRAFTABLE else restockable,
			"can_list": state.has_product(recipe_id) and state.is_core_feature_unlocked(CoreFeatureUnlockService.LIST),
			"stable_order": stable_order,
			"search_haystack": _production_picker_search_haystack(recipe_id, recipe)
		})
		stable_order += 1

	var processes: Dictionary = catalog.get_processing_recipes()
	for process_id in _available_process_ids():
		var process: Dictionary = processes.get(process_id, {})
		var missing_ids := _missing_process_material_ids(process_id)
		var entry_filter := PICKER_FILTER_CRAFTABLE if missing_ids.is_empty() else PICKER_FILTER_MISSING
		if entry_filter != filter_id:
			stable_order += 1
			continue
		var output_item_id := String(process.get("output_item_id", ""))
		entries.append({
			"id": process_id,
			"kind": "processing",
			"filter": entry_filter,
			"name": _ingredient_name(output_item_id),
			"icon": _material_icon_texture(output_item_id),
			"stock_count": state.get_ingredient_count(output_item_id),
			"materials_text": "材料：%s" % _material_stock_requirements(process.get("materials", [])),
			"reason": _process_unavailable_status(process_id),
			"missing_count": missing_ids.size(),
			"restockable": false,
			"action_enabled": entry_filter == PICKER_FILTER_CRAFTABLE,
			"can_list": false,
			"stable_order": stable_order,
			"search_haystack": _processing_picker_search_haystack(process_id, process)
		})
		stable_order += 1

	if filter_id == PICKER_FILTER_CRAFTABLE:
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var capacity_a := int(a.get("remaining_capacity", 0 if String(a.get("kind", "")) == "recipe" else 4))
			var capacity_b := int(b.get("remaining_capacity", 0 if String(b.get("kind", "")) == "recipe" else 4))
			if capacity_a != capacity_b:
				return capacity_a > capacity_b
			return int(a.get("stable_order", 0)) < int(b.get("stable_order", 0))
		)
	else:
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if bool(a.get("restockable", false)) != bool(b.get("restockable", false)):
				return bool(a.get("restockable", false))
			if int(a.get("missing_count", 0)) != int(b.get("missing_count", 0)):
				return int(a.get("missing_count", 0)) < int(b.get("missing_count", 0))
			return int(a.get("stable_order", 0)) < int(b.get("stable_order", 0))
		)
	return entries


func _production_picker_search_haystack(recipe_id: String, recipe: Dictionary) -> String:
	var parts: Array[String] = [recipe_id, String(recipe.get("name", recipe_id))]
	for material_value: Variant in recipe.get("materials", []):
		parts.append(_material_name(String(material_value)))
	for tag_value: Variant in recipe.get("tags", []):
		parts.append(String(tag_value))
	return " ".join(parts)


func _processing_picker_search_haystack(process_id: String, process: Dictionary) -> String:
	var parts: Array[String] = [process_id, _ingredient_name(String(process.get("output_item_id", "")))]
	for material_value: Variant in process.get("materials", []):
		parts.append(_material_name(String(material_value)))
	return " ".join(parts)


func _capture_recipe_completion_feedback(result: Dictionary, now_msec: int = -1) -> bool:
	var captured_at := now_msec if now_msec >= 0 else Time.get_ticks_msec()
	for slot_value: Variant in result.get("completed_recipe_slots", []):
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = (slot_value as Dictionary).duplicate(true)
		slot["expires_at_msec"] = captured_at + PRODUCTION_COMPLETION_FEEDBACK_MSEC
		production_completion_feedback.append(slot)
	return int(result.get("completed_batches", 0)) > 0 \
		or int(result.get("completed_processes", 0)) > 0


func _prune_recipe_completion_feedback(now_msec: int = -1) -> void:
	var current := now_msec if now_msec >= 0 else Time.get_ticks_msec()
	var retained: Array[Dictionary] = []
	for entry: Dictionary in production_completion_feedback:
		if int(entry.get("expires_at_msec", 0)) > current:
			retained.append(entry)
	production_completion_feedback = retained


func _completion_feedback_for_recipe(recipe_id: String) -> Array:
	var result: Array = []
	for feedback: Dictionary in production_completion_feedback:
		if String(feedback.get("recipe_id", "")) != recipe_id:
			continue
		var batches := maxi(1, int(feedback.get("batches", 1)))
		var total_output := maxi(1, int(feedback.get("output_count", 1)))
		var output_per_batch := maxi(1, total_output / batches)
		for batch_index in range(batches):
			var expanded := feedback.duplicate(true)
			expanded["batch_index"] = batch_index
			expanded["output_count"] = output_per_batch
			result.append(expanded)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("queue_sequence", 0)) != int(b.get("queue_sequence", 0)):
			return int(a.get("queue_sequence", 0)) < int(b.get("queue_sequence", 0))
		return int(a.get("batch_index", 0)) < int(b.get("batch_index", 0))
	)
	return result


func _apply_recipe_action_availability(button: Button, unavailable_reason: String) -> void:
	button.disabled = not unavailable_reason.is_empty()
	button.modulate = Color(1, 1, 1, 1)
	if button.has_meta("unavailable_reason"):
		button.remove_meta("unavailable_reason")
	button.tooltip_text = ""
	if unavailable_reason.is_empty():
		return
	button.set_meta("unavailable_reason", unavailable_reason)
	button.modulate = Color(1, 1, 1, 0.45)
	button.tooltip_text = unavailable_reason


func _unlocked_recipe_ids() -> Array[String]:
	var recipe_ids: Array[String] = []
	var recipes := catalog.get_recipes()
	for recipe_id in _sorted_keys(recipes):
		if state.is_recipe_unlocked(recipe_id):
			recipe_ids.append(recipe_id)
	return recipe_ids


func _available_process_ids() -> Array[String]:
	var process_ids: Array[String] = []
	var processes := catalog.get_processing_recipes()
	for process_id in _sorted_keys(processes):
		var process: Dictionary = processes[process_id]
		if int(process.get("unlock_level", 1)) > state.level:
			continue
		var output_item_id := String(process.get("output_item_id", ""))
		if not state.has_method("is_ingredient_process_unlocked") or not state.is_ingredient_process_unlocked(output_item_id):
			continue
		process_ids.append(process_id)
	return process_ids


func _process_unavailable_status(process_id: String) -> String:
	if state != null and state.active_ingredient_processing_count(process_id) > 0:
		return "该配方已有 1 批正在加工"
	var missing_materials := _missing_process_material_ids(process_id)
	if not missing_materials.is_empty():
		var names: Array[String] = []
		for material_id in missing_materials:
			names.append(_material_name(material_id))
		return "原料%s不足" % "、".join(names)
	var process: Dictionary = catalog.get_processing_recipes().get(process_id, {})
	var device_id := String(process.get("device", ""))
	if not _research_device_available(device_id):
		return "工具%s未解锁" % _device_name(device_id)
	return ""


func _research_device_available(device_id: String) -> bool:
	if device_id.is_empty():
		return false
	var device: Dictionary = catalog.get_devices().get(device_id, {})
	return not device.is_empty() and state.is_device_unlocked(device_id)


func _missing_process_material_ids(process_id: String) -> Array[String]:
	var missing: Array[String] = []
	var process: Dictionary = catalog.get_processing_recipes().get(process_id, {})
	var ingredients := catalog.get_ingredients()
	for material_value in process.get("materials", []):
		var material_id := String(material_value)
		if not ingredients.has(material_id) or not state.has_ingredient(material_id, 1):
			missing.append(material_id)
	return missing


func _can_make_recipe(recipe_id: String) -> bool:
	return _recipe_unavailable_status(recipe_id).is_empty()


func _material_requirements(materials_value: Variant) -> Dictionary:
	var requirements := {}
	_merge_material_requirements(requirements, materials_value)
	return requirements


func _merge_material_requirements(target: Dictionary, materials_value: Variant) -> void:
	if not materials_value is Array:
		return
	for material_value: Variant in materials_value:
		var material_id := String(material_value)
		if material_id.is_empty():
			continue
		target[material_id] = int(target.get(material_id, 0)) + 1


func _research_bulk_restock_requirements() -> Dictionary:
	var requirements := {}
	var recipes := catalog.get_recipes()
	for recipe_id in _unlocked_recipe_ids():
		_merge_material_requirements(requirements, recipes.get(recipe_id, {}).get("materials", []))
	var processes := catalog.get_processing_recipes()
	for process_id in _available_process_ids():
		_merge_material_requirements(requirements, processes.get(process_id, {}).get("materials", []))
	return requirements


func _recipe_restock_quote(recipe_id: String) -> Dictionary:
	var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
	if recipe.is_empty() or state == null or not state.is_recipe_unlocked(recipe_id):
		return {"ok": false, "reason": "配方不可用", "entries": []}
	var quote := _restock_quote_for_requirements(
		_material_requirements(recipe.get("materials", [])),
		String(recipe.get("name", recipe_id)),
		"recipe"
	)
	quote["recipe_id"] = recipe_id
	quote["recipe_name"] = String(recipe.get("name", recipe_id))
	return quote


func _research_bulk_restock_quote() -> Dictionary:
	if state == null:
		return {"ok": false, "reason": "当前状态不可用", "entries": []}
	return _restock_quote_for_requirements(
		_research_bulk_restock_requirements(),
		"全部配方与加工",
		"research_bulk"
	)


func _restock_quote_for_requirements(requirements: Dictionary, quote_name: String, quote_kind: String) -> Dictionary:
	var entries: Array[Dictionary] = []
	var purchasable_entries: Array[Dictionary] = []
	var unavailable_entries: Array[Dictionary] = []
	var total_cost := 0
	var purchasable_units := 0
	var ingredients := catalog.get_ingredients()
	var recipes := catalog.get_recipes()
	for material_id_value: Variant in requirements.keys():
		var material_id := String(material_id_value)
		var required := int(requirements.get(material_id, 0))
		var available: int = (
			state.get_ingredient_count(material_id)
			if ingredients.has(material_id)
			else state.get_product_count(material_id)
		)
		var missing := maxi(required - available, 0)
		if missing == 0:
			continue
		var ingredient: Dictionary = ingredients.get(material_id, {})
		var material_recipe: Dictionary = recipes.get(material_id, {})
		var purchasable := not ingredient.is_empty() and _is_ingredient_available_for_purchase(material_id, ingredient)
		var unit_price := int(ingredient.get("price", 0))
		var entry := {
			"item_id": material_id,
			"name": String(material_recipe.get("name", material_id)) if ingredient.is_empty() else _ingredient_name(material_id),
			"missing": missing,
			"purchasable": purchasable,
			"unit_price": unit_price,
			"subtotal": unit_price * missing if purchasable else 0,
			"source": "制作" if not material_recipe.is_empty() else String(ingredient.get("source", "对应产地"))
		}
		entries.append(entry)
		if purchasable:
			purchasable_entries.append(entry)
			total_cost += int(entry.get("subtotal", 0))
			purchasable_units += missing
		else:
			unavailable_entries.append(entry)
	return {
		"ok": true,
		"quote_name": quote_name,
		"quote_kind": quote_kind,
		"entries": entries,
		"purchasable_entries": purchasable_entries,
		"unavailable_entries": unavailable_entries,
		"total_cost": total_cost,
		"purchasable_units": purchasable_units,
		"available_coins": int(state.coins)
	}


func _purchase_recipe_restock(recipe_id: String) -> Dictionary:
	return _purchase_restock_quote(_recipe_restock_quote(recipe_id))


func _purchase_research_bulk_restock() -> Dictionary:
	return _purchase_restock_quote(_research_bulk_restock_quote())


func _purchase_restock_quote(quote: Dictionary) -> Dictionary:
	if not bool(quote.get("ok", false)):
		return {"ok": false, "reason": String(quote.get("reason", "补货不可用")), "quote": quote}
	if quote.get("entries", []).is_empty():
		return {"ok": false, "reason": "材料充足", "quote": quote}
	if quote.get("purchasable_entries", []).is_empty():
		return {"ok": false, "reason": "没有可直接采购的缺口", "quote": quote}
	var total_cost := int(quote.get("total_cost", 0))
	if int(state.coins) < total_cost:
		return {"ok": false, "reason": "金币不足", "quote": quote}

	for entry_value: Variant in quote.get("purchasable_entries", []):
		var entry: Dictionary = entry_value
		var item_id := String(entry.get("item_id", ""))
		for _unit_index in range(int(entry.get("missing", 0))):
			_purchase_inventory_item(item_id, false)
	return {"ok": true, "reason": "", "quote": quote}


func _missing_recipe_material_ids(recipe_id: String, batches: int = 1) -> Array[String]:
	var missing: Array[String] = []
	var recipes := catalog.get_recipes()
	var ingredients := catalog.get_ingredients()
	var recipe: Dictionary = recipes.get(recipe_id, {})
	for material_value in recipe.get("materials", []):
		var material_id := String(material_value)
		if ingredients.has(material_id):
			if not state.has_ingredient(material_id, batches):
				missing.append(material_id)
		elif recipes.has(material_id):
			if not state.has_product(material_id, batches):
				missing.append(material_id)
		else:
			missing.append(material_id)
	return missing


func _recipe_missing_material_status(recipe_id: String) -> String:
	var names: Array[String] = []
	for material_id in _missing_recipe_material_ids(recipe_id):
		names.append(_material_name(material_id))
	if names.is_empty():
		return ""
	return "原料%s不足" % "、".join(names)


func _recipe_unavailable_status(recipe_id: String, active_count_override: int = -1) -> String:
	var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
	if recipe.is_empty() or state == null or not state.is_recipe_unlocked(recipe_id):
		return "配方尚未解锁"
	var device_id := String(recipe.get("device", ""))
	if not _research_device_available(device_id):
		return "设备%s未解锁" % _device_name(device_id)
	var active_count: int = active_count_override if active_count_override >= 0 else int(state.active_recipe_production_batch_count(recipe_id))
	if active_count >= GameState.MAX_CONCURRENT_RECIPE_BATCHES:
		return RECIPE_BATCH_LIMIT_STATUS
	return _recipe_missing_material_status(recipe_id)


func _refresh_resource_bar() -> void:
	var upgrade_target := _topbar_shop_upgrade_target()
	if upgrade_target.is_empty():
		coins_label.text = "金币: %d" % state.coins
		reputation_label.text = "口碑: %d" % state.reputation
		coins_label.tooltip_text = "当前持有金币"
		reputation_label.tooltip_text = "当前累计口碑"
		_set_topbar_upgrade_visuals_visible(false)
	else:
		var target_level := int(upgrade_target.get("target_level", int(state.level) + 1))
		var required_coins := maxi(0, int(upgrade_target.get("cost", 0)))
		var required_reputation := maxi(0, int(upgrade_target.get("required_reputation", 0)))
		coins_label.text = _topbar_coins_text(int(state.coins), upgrade_target)
		reputation_label.text = "口碑 %d / %d" % [int(state.reputation), required_reputation]
		coins_label.tooltip_text = "升至 Lv.%d 需要 %d 金币；升级时扣除金币。" % [target_level, required_coins]
		reputation_label.tooltip_text = "升至 Lv.%d 需要累计口碑 %d；升级时不扣除口碑。" % [target_level, required_reputation]
		coins_upgrade_progress.max_value = maxi(1, required_coins)
		coins_upgrade_progress.value = clampi(int(state.coins), 0, required_coins) if required_coins > 0 else coins_upgrade_progress.max_value
		reputation_upgrade_progress.max_value = maxi(1, required_reputation)
		reputation_upgrade_progress.value = clampi(int(state.reputation), 0, required_reputation) if required_reputation > 0 else reputation_upgrade_progress.max_value
		coins_upgrade_progress.tooltip_text = coins_label.tooltip_text
		reputation_upgrade_progress.tooltip_text = reputation_label.tooltip_text
		_set_topbar_upgrade_visuals_visible(true)
	level_label.text = "店铺等级: %d" % state.level
	workbench_launcher.call("set_badge", "StarlightButton", str(state.recipe_starlight_available) if state.recipe_starlight_available > 0 else "")
	starlight_button.tooltip_text = "可用 %d｜累计 %d｜打开自动化中枢" % [state.recipe_starlight_available, state.recipe_starlight_total]
	_refresh_task_button_badge()
	workbench_launcher.call("set_badge", "InventoryButton", "!" if not _inventory_low_stock_lines().is_empty() else "")
	_refresh_core_feature_access()


func _set_topbar_upgrade_visuals_visible(visible: bool) -> void:
	coins_upgrade_skin.visible = visible
	reputation_upgrade_skin.visible = visible
	coins_upgrade_progress.visible = visible
	reputation_upgrade_progress.visible = visible


func _topbar_shop_upgrade_target() -> Dictionary:
	if state == null or int(state.level) < 1 or not state.has_method("upgrade_eligibility"):
		return {}
	var eligibility: Dictionary = state.upgrade_eligibility()
	if String(eligibility.get("reason", "")) == "definition_missing":
		return {}
	return eligibility


func _topbar_coins_text(coins: int, upgrade_target: Dictionary = {}) -> String:
	var target := upgrade_target if not upgrade_target.is_empty() else _topbar_shop_upgrade_target()
	if target.is_empty():
		return "金币: %d" % coins
	return "金币 %d / %d" % [coins, maxi(0, int(target.get("cost", 0)))]


func _refresh_core_feature_access() -> void:
	if state == null or not is_instance_valid(workbench_launcher):
		return
	for binding in [
		["PurchaseButton", CoreFeatureUnlockService.PURCHASE],
		["OutputButton", CoreFeatureUnlockService.OUTPUT],
		["InventoryButton", CoreFeatureUnlockService.INVENTORY],
		["CatalogButton", CoreFeatureUnlockService.CATALOG],
		["ResearchButton", CoreFeatureUnlockService.RESEARCH],
		["StorefrontManageButton", CoreFeatureUnlockService.STOREFRONT_MANAGE],
		["TaskButton", CoreFeatureUnlockService.TASK],
		["StarlightButton", CoreFeatureUnlockService.STARLIGHT],
	]:
		var button_name := String(binding[0])
		var feature_id := String(binding[1])
		var unlocked: bool = state.is_core_feature_unlocked(feature_id)
		var tooltip: String = "" if unlocked else state.core_feature_locked_reason(feature_id)
		workbench_launcher.call("set_entry_enabled", button_name, unlocked, tooltip)


func _require_core_feature(feature_id: String) -> bool:
	if state != null and state.is_core_feature_unlocked(feature_id):
		return true
	if state != null:
		_set_status("🔒 %s" % state.core_feature_locked_reason(feature_id))
	return false


func _refresh_task_button_badge() -> void:
	var claimable_count := 0
	if state != null and state.has_method("get_claimable_tasks"):
		claimable_count = state.get_claimable_tasks().size()
	if claimable_count > 0:
		workbench_launcher.call("set_badge", "TaskButton", str(claimable_count))
		task_button.tooltip_text = "有 %d 个任务奖励待领取" % claimable_count
	else:
		workbench_launcher.call("set_badge", "TaskButton", "")
		task_button.tooltip_text = "查看任务"


func _refresh_feedback_log() -> void:
	var lines: Array[String] = []
	var sale_lines := _recent_sale_bonus_lines()
	if not sale_lines.is_empty():
		lines.append("最近售出")
		lines.append_array(sale_lines)
	for message in state.feedback_log:
		lines.append(String(message))
	if lines.is_empty():
		cashier_feedback_text = "暂无反馈"
	else:
		cashier_feedback_text = "最近反馈\n%s" % "\n".join(lines)


func _refresh_storefront() -> void:
	_refresh_storefront_showcase()
	_refresh_cashier_feedback()


func _refresh_storefront_showcase() -> void:
	_invalidate_showcase_bonus_cache()
	_clear_children(showcase_grid)
	showcase_grid.columns = SHOWCASE_GRID_COLUMNS
	var cell_size := SHOWCASE_EXPANSION_CELL_SIZE if showcase_expansion_active else SHOWCASE_CELL_SIZE
	showcase_grid.custom_minimum_size = Vector2(cell_size.x * SHOWCASE_GRID_COLUMNS, cell_size.y * SHOWCASE_GRID_ROWS)
	_ensure_showcase_slot_count()
	var now_unix := int(Time.get_unix_time_from_system())
	for index in range(SHOWCASE_SLOT_COUNT):
		var button := _make_storefront_slot_button(index)
		_apply_showcase_slot_button_state(button, index, now_unix)
		showcase_grid.add_child(button)
	_refresh_all_showcase_product_visuals(now_unix)
	_hide_showcase_sale_progress_groups()
	call_deferred("_refresh_showcase_sale_progress_groups")
	_refresh_showcase_set_progress()
	_refresh_showcase_pulse_summary()
	call_deferred("_refresh_showcase_chain_preview")


func _make_storefront_slot_button(slot_index: int) -> Button:
	var button := preload("res://scenes/ui/storefront/showcase_slot.tscn").instantiate() as Button
	button.set_meta("slot_index", slot_index)
	button.configure_drop("showcase", Callable(self, "_can_drop_showcase_data"), Callable(self, "_drop_showcase_data"), {
		"target_slot_index": slot_index
	})
	button.gui_input.connect(_on_showcase_slot_gui_input.bind(slot_index))
	button.mouse_entered.connect(_on_showcase_slot_hovered.bind(slot_index, true))
	button.mouse_exited.connect(_on_showcase_slot_hovered.bind(slot_index, false))
	button.custom_minimum_size = SHOWCASE_EXPANSION_CELL_SIZE if showcase_expansion_active else SHOWCASE_CELL_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	return button


func _apply_showcase_slot_button_state(button: Button, slot_index: int, now_unix: int) -> void:
	button.set_meta("showcase_preview", false)
	button.modulate = Color(1, 1, 1, 1)
	if button.has_method("set_skin_state"):
		button.call("set_skin_state", &"normal")
	button.remove_meta("recipe_id")
	button.remove_meta("showcase_region_id")
	button.remove_meta("showcase_hotspot_id")
	if button.has_method("clear_drag"):
		button.call("clear_drag")
	if button.has_method("clear_product_visual"):
		button.call("clear_product_visual")
	_clear_showcase_group_highlight(button)
	if _is_showcase_slot_unlocked(slot_index):
		_apply_showcase_region_tint(button, slot_index)
		_apply_showcase_hotspot_tint(button, slot_index)
	if _is_showcase_preview_slot(slot_index):
		button.set_meta("showcase_preview", true)
		button.set_meta("recipe_id", showcase_drag_preview_recipe_id)
		button.text = ""
		button.tooltip_text = _showcase_preview_slot_tooltip(slot_index)
		if button.has_method("set_preview_state"):
			button.call("set_preview_state", true, true)
		return
	var slot := _showcase_slot(slot_index)
	if slot.is_empty() and not _is_showcase_slot_unlocked(slot_index):
		button.remove_meta("recipe_id")
		var cell := _showcase_cell_for_slot_index(slot_index)
		var unlocked: Array = state.get_showcase_unlocked_cells()
		var selected := showcase_expansion_selected_cells.has(cell)
		var frontier := ShowcaseExpansionService.can_add_cell(unlocked, showcase_expansion_selected_cells if showcase_expansion_tool == "cells" else [], cell)
		var reveal_for_expansion := showcase_expansion_active and (selected or frontier)
		if not reveal_for_expansion:
			button.text = ""
			button.tooltip_text = ""
			button.modulate = Color(1.0, 1.0, 1.0, 0.0)
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.focus_mode = Control.FOCUS_NONE
			return
		button.text = ("已选\n%d,%d" if selected else "可扩建\n%d,%d") % [cell.x, cell.y]
		button.tooltip_text = "点击取消选择" if selected else "点击选择该格；新区须与旧区域四方向连通"
		if button.has_method("set_skin_state"):
			button.call("set_skin_state", &"locked")
		if selected:
			button.modulate = Color(1.0, 0.78, 0.28, 1.0)
		elif frontier:
			button.modulate = Color(0.68, 0.94, 0.76, 1.0)
		return
	var prop_id := _showcase_prop_id_for_cell(_showcase_cell_for_slot_index(slot_index))
	if not prop_id.is_empty():
		var definition: Dictionary = ShowcaseRuleService.PROP_RULES.get(prop_id, {})
		button.set_meta("showcase_prop_id", prop_id)
		button.text = String(definition.get("label", prop_id))
		button.tooltip_text = "%s\n%s\n右键收回；重新从右侧拖放可移动" % [
			definition.get("label", prop_id),
			definition.get("effect_text", "")
		]
		return
	var recipe_id := String(slot.get("recipe_id", ""))
	if recipe_id.is_empty():
		button.text = _showcase_slot_text(slot_index, now_unix)
		button.tooltip_text = _showcase_slot_tooltip(slot_index, now_unix)
	else:
		button.set_meta("recipe_id", recipe_id)
		var phase := String(state.active_business_round.get("phase", "adjusting"))
		var can_drag: bool = not showcase_expansion_active and (phase == "adjusting" \
			or phase == "running" and state.has_method("is_display_item_sold_out_during_round") \
			and state.is_display_item_sold_out_during_round(recipe_id))
		if can_drag:
			var drag_end := Callable(self, "_on_showcase_product_drag_cancelled")
			var can_unlist_outside := _can_unlist_showcase_item(recipe_id)
			var drag_start := Callable(self, "_on_showcase_product_drag_started").bind(recipe_id)
			if can_unlist_outside:
				drag_end = Callable(self, "_on_showcase_product_drag_ended").bind(recipe_id)
			button.call("configure_drag", {
				"kind": "showcase_product",
				"recipe_id": recipe_id,
				"variant_id": _display_item_variant_id(recipe_id),
				"source_anchor_slot_index": _showcase_anchor_slot_index_for_slot(slot_index),
				"source_grab_slot_index": slot_index
			}, "", {}, drag_end, drag_start)
		button.text = ""
		button.tooltip_text = _showcase_slot_tooltip(slot_index, now_unix)


func _apply_showcase_region_tint(button: Button, slot_index: int) -> void:
	var unlocked_cells: Array = ShowcaseRegionService.cells_for_bounds(ShowcaseRegionService.default_bounds())
	if state != null and state.has_method("get_showcase_unlocked_cells"):
		unlocked_cells = state.get_showcase_unlocked_cells()
	var region_id := ShowcaseRegionService.zone_for_cell_in_cells(_showcase_cell_for_slot_index(slot_index), unlocked_cells)
	button.set_meta("showcase_region_id", region_id)
	match region_id:
		"front": button.modulate = Color(0.90, 1.0, 0.95, 1.0)
		"golden": button.modulate = Color(1.0, 0.94, 0.76, 1.0)
		"back": button.modulate = Color(0.94, 0.88, 0.98, 1.0)
		_: button.modulate = Color(1.0, 0.98, 0.94, 1.0)


func _apply_showcase_hotspot_tint(button: Button, slot_index: int) -> void:
	if state == null: return
	var hotspot := _ensure_showcase_hotspot()
	if not (hotspot.get("cells", []) as Array).has(_showcase_cell_for_slot_index(slot_index)): return
	button.set_meta("showcase_hotspot_id", String(hotspot.get("id", "")))
	match String(hotspot.get("type", "")):
		"traffic": button.modulate = button.modulate.lerp(Color(0.72, 1.0, 0.88, 1.0), 0.32)
		"quality": button.modulate = button.modulate.lerp(Color(1.0, 0.82, 0.45, 1.0), 0.35)
		"congestion": button.modulate = button.modulate.lerp(Color(1.0, 0.68, 0.56, 1.0), 0.30)


func _clear_showcase_group_highlight(button: Button) -> void:
	button.set_meta("showcase_group_highlight", false)
	if button.has_method("clear_outline"):
		button.call("clear_outline")
	else:
		for state_name in ["normal", "hover", "pressed", "focus"]:
			button.remove_theme_stylebox_override(state_name)


func _refresh_all_showcase_product_visuals(now_unix: int) -> void:
	if state == null:
		return
	var display_items: Dictionary = state.get("display_items") if state.get("display_items") is Dictionary else {}
	var recipe_ids := display_items.keys()
	recipe_ids.sort()
	for recipe_id_value in recipe_ids:
		var recipe_id := String(recipe_id_value)
		var cells: Array = state.get_display_item_cells(recipe_id)
		_apply_showcase_group_visual(recipe_id, cells, _display_item_variant_id(recipe_id), false, now_unix)
	for slot_index in range(state.display_slots.size()):
		var raw_slot: Variant = state.display_slots[slot_index]
		if raw_slot == null or raw_slot is Dictionary and (raw_slot as Dictionary).has("covered_by"):
			continue
		var legacy_slot := _showcase_slot(slot_index)
		var legacy_recipe_id := String(legacy_slot.get("recipe_id", ""))
		if legacy_recipe_id.is_empty() or state.has_method("is_display_item_placed") and state.is_display_item_placed(legacy_recipe_id):
			continue
		_apply_showcase_group_visual(
			legacy_recipe_id,
			[_showcase_cell_for_slot_index(slot_index)],
			"standard",
			false,
			now_unix
		)
	if not showcase_drag_preview_recipe_id.is_empty() and not showcase_drag_preview_cells.is_empty():
		_apply_showcase_group_visual(
			showcase_drag_preview_recipe_id,
			showcase_drag_preview_cells,
			showcase_drag_preview_variant_id,
			true,
			now_unix
		)


func _apply_showcase_group_visual(recipe_id: String, cells: Array, variant_id: String, preview: bool, now_unix: int, hovered: bool = false) -> void:
	var typed_cells: Array[Vector2i] = []
	for cell_value in cells:
		if cell_value is Vector2i:
			typed_cells.append(cell_value)
	if recipe_id.is_empty() or typed_cells.is_empty():
		return
	var local_cells := _local_showcase_shape_cells(typed_cells)
	var recipe_growth: Dictionary = state.get_recipe_growth(recipe_id)
	var mastery_level := int(recipe_growth.get("mastery_level", 0))
	var layout := showcase_icon_service.layout_for_shape(recipe_id, variant_id, local_cells, mastery_level)
	var rotation := int(layout.get("rotation", -1))
	var min_row := SHOWCASE_GRID_ROWS
	var min_col := SHOWCASE_GRID_COLUMNS
	for cell in typed_cells:
		min_row = mini(min_row, cell.x)
		min_col = mini(min_col, cell.y)
	var occupied := {}
	for local_cell in local_cells:
		occupied["%d:%d" % [local_cell.x, local_cell.y]] = true
	var anchor_index := _showcase_anchor_slot_index_for_cells(typed_cells)
	var anchor_slot := _showcase_slot(anchor_index)
	var item_view := _showcase_round_item_view(recipe_id)
	var sold_out: bool = not preview and int(item_view.get("quantity", 0)) <= 0
	var reward_ready := false
	var border_color := _showcase_preview_outline_color() if preview else _showcase_bonus_border_color(recipe_id)
	var shared_tooltip := _showcase_preview_slot_tooltip(_showcase_slot_index_for_cell(typed_cells[0])) if preview else _showcase_slot_tooltip(anchor_index, now_unix)
	var masterwork_level := int(recipe_growth.get("masterwork_level", 0)) if not preview else 0
	var masterwork_title := RecipeGrowthService.masterwork_title(_recipe_name(recipe_id), masterwork_level)
	if not masterwork_title.is_empty():
		shared_tooltip += "\n名作称号：%s" % masterwork_title
	for cell in typed_cells:
		var slot_index := _showcase_slot_index_for_cell(cell)
		if slot_index < 0 or slot_index >= showcase_grid.get_child_count():
			continue
		var button := showcase_grid.get_child(slot_index) as Button
		if button == null:
			continue
		var local_cell := Vector2i(cell.x - min_row + 1, cell.y - min_col + 1)
		var fragment: AtlasTexture = null
		if rotation >= 0:
			fragment = showcase_icon_service.fragment(recipe_id, variant_id, rotation, local_cell, mastery_level)
		button.set_meta("recipe_id", recipe_id)
		button.set_meta("showcase_group_highlight", true)
		button.modulate = Color(0.48, 0.48, 0.48, 0.82) if sold_out else Color.WHITE
		if button.has_method("set_skin_state"):
			button.call("set_skin_state", &"reward" if reward_ready else &"normal")
		button.text = ""
		button.tooltip_text = shared_tooltip
		if button.has_method("set_icon_fragment"):
			button.call("set_icon_fragment", fragment, preview)
		if button.has_method("set_preview_state"):
			button.call("set_preview_state", preview, true)
		if button.has_method("set_masterwork_visual"):
			button.call("set_masterwork_visual", masterwork_level, slot_index == anchor_index)
		if button.has_method("set_status_badge"):
			var badge_text := ""
			if not preview and slot_index == anchor_index:
				badge_text = _showcase_status_badge_text(_showcase_slot(anchor_index), now_unix)
			button.call("set_status_badge", badge_text)
		if button.has_method("set_outline_edges"):
			button.call(
				"set_outline_edges",
				not occupied.has("%d:%d" % [local_cell.x - 1, local_cell.y]),
				not occupied.has("%d:%d" % [local_cell.x, local_cell.y + 1]),
				not occupied.has("%d:%d" % [local_cell.x + 1, local_cell.y]),
				not occupied.has("%d:%d" % [local_cell.x, local_cell.y - 1]),
				border_color,
				hovered
			)


func _showcase_preview_outline_color() -> Color:
	var preview_color := _showcase_preview_color()
	return Color(preview_color.r, preview_color.g, preview_color.b, 1.0)


func _on_showcase_slot_hovered(slot_index: int, hovered: bool) -> void:
	if slot_index < 0 or slot_index >= showcase_grid.get_child_count() or _is_showcase_preview_slot(slot_index):
		return
	var slot := _showcase_slot(slot_index)
	var recipe_id := String(slot.get("recipe_id", ""))
	if recipe_id.is_empty() or not state.has_method("get_display_item_cells"):
		return
	var cells: Array = state.get_display_item_cells(recipe_id)
	var variant_id := _display_item_variant_id(recipe_id)
	if cells.is_empty():
		cells = [_showcase_cell_for_slot_index(slot_index)]
		variant_id = "standard"
	_apply_showcase_group_visual(
		recipe_id,
		cells,
		variant_id,
		false,
		int(Time.get_unix_time_from_system()),
		hovered
	)


func _showcase_preview_color() -> Color:
	var bonus := _preview_showcase_bonus(showcase_drag_preview_recipe_id, showcase_drag_preview_cells, showcase_drag_preview_mode, showcase_drag_preview_variant_id)
	var price_delta := float(bonus.get("price_multiplier", 1.0)) - 1.0
	var speed_delta := float(bonus.get("speed_multiplier", 1.0)) - 1.0
	if price_delta < -0.01 or speed_delta < -0.01:
		return Color(1.0, 0.78, 0.74, 1.0)
	if price_delta > 0.01 or speed_delta > 0.01:
		return Color(0.78, 1.0, 0.84, 1.0)
	return Color(1.0, 0.93, 0.72, 1.0)


func _showcase_bonus_border_color(recipe_id: String) -> Color:
	var bonus := _showcase_bonus_for_recipe(recipe_id)
	var price_delta := float(bonus.get("price_multiplier", 1.0)) - 1.0
	var speed_delta := float(bonus.get("speed_multiplier", 1.0)) - 1.0
	if price_delta < -0.01 or speed_delta < -0.01:
		return Color(0.92, 0.25, 0.18, 1.0)
	if price_delta > 0.01 or speed_delta > 0.01:
		return Color(0.15, 0.62, 0.28, 1.0)
	return Color(1.0, 0.68, 0.08, 1.0)


func _refresh_showcase_countdown_texts(now_unix: int) -> void:
	_refresh_showcase_anchor_badges(now_unix)
	_refresh_showcase_sale_progress_groups()


func _refresh_showcase_sale_progress_groups() -> void:
	if state == null or not is_instance_valid(showcase_grid) or not is_instance_valid(showcase_feedback_layer):
		return
	var active_recipe_ids := {}
	for recipe_id_value: Variant in state.display_items.keys():
		var recipe_id := String(recipe_id_value)
		var item_view := _showcase_round_item_view(recipe_id)
		var progress := clampf(float(item_view.get("progress", 0.0)), 0.0, 1.0)
		var active := String(item_view.get("phase", "adjusting")) == "running" \
			and int(item_view.get("quantity", 0)) > 0
		var cell_rects: Array = []
		var preview_intersects := false
		for cell_value: Variant in state.get_display_item_cells(recipe_id):
			if not cell_value is Vector2i:
				continue
			var slot_index := _showcase_slot_index_for_cell(cell_value as Vector2i)
			if slot_index < 0 or slot_index >= showcase_grid.get_child_count():
				continue
			var button := showcase_grid.get_child(slot_index) as Control
			if button == null or button.is_queued_for_deletion():
				continue
			preview_intersects = preview_intersects or bool(button.get_meta("showcase_preview", false))
			var cell_rect := button.get_global_rect()
			cell_rect.position -= showcase_feedback_layer.global_position
			cell_rects.append(cell_rect)
		if cell_rects.is_empty():
			continue
		active_recipe_ids[recipe_id] = true
		var group := showcase_sale_progress_groups.get(recipe_id) as Control
		if group == null or not is_instance_valid(group):
			group = preload("res://scenes/ui/storefront/showcase_sale_progress_group.tscn").instantiate() as Control
			group.name = "ShowcaseSaleProgressGroup_%s" % recipe_id
			showcase_feedback_layer.add_child(group)
			showcase_sale_progress_groups[recipe_id] = group
		group.call("configure", recipe_id, cell_rects, progress, active and not preview_intersects)
	for recipe_id_value: Variant in showcase_sale_progress_groups.keys():
		var recipe_id := String(recipe_id_value)
		if active_recipe_ids.has(recipe_id):
			continue
		var stale_group := showcase_sale_progress_groups.get(recipe_id) as Control
		if is_instance_valid(stale_group):
			stale_group.queue_free()
		showcase_sale_progress_groups.erase(recipe_id)


func _hide_showcase_sale_progress_groups() -> void:
	for group_value: Variant in showcase_sale_progress_groups.values():
		if is_instance_valid(group_value):
			(group_value as Control).visible = false


func _showcase_group_rect(cells: Array) -> Rect2:
	var result := Rect2(Vector2.ZERO, Vector2(-1.0, -1.0))
	var found := false
	for cell_value: Variant in cells:
		if not cell_value is Vector2i:
			continue
		var slot_index := _showcase_slot_index_for_cell(cell_value)
		if slot_index < 0 or slot_index >= showcase_grid.get_child_count():
			continue
		var cell_control := showcase_grid.get_child(slot_index) as Control
		if cell_control == null:
			continue
		var cell_rect := cell_control.get_global_rect()
		result = cell_rect if not found else result.merge(cell_rect)
		found = true
	if found:
		result.position -= showcase_feedback_layer.global_position
	return result


func _refresh_showcase_chain_preview(role_snapshot: Dictionary = {}) -> void:
	if not is_instance_valid(showcase_feedback_layer) or state == null:
		return
	for child in showcase_feedback_layer.get_children():
		if String(child.name).begins_with("ShowcaseChainArrow_"):
			showcase_feedback_layer.remove_child(child)
			child.queue_free()
	var roles := role_snapshot
	if roles.is_empty() and not state.display_items.is_empty():
		roles = ShowcaseRoleService.build_configured_snapshot(
			state.display_items,
			_showcase_round_sale_terms(),
			catalog.get_showcase_round_rules().get("role_rules", {})
		)
	var source_ids := roles.keys()
	source_ids.sort()
	for source_id_value in source_ids:
		var source_id := String(source_id_value)
		var role: Dictionary = roles.get(source_id_value, {})
		if String(role.get("role", "")) != "advance":
			continue
		var source_cells: Array = (state.display_items.get(source_id, {}) as Dictionary).get("cells", [])
		var source_rect := _showcase_group_rect(source_cells)
		if source_rect.size.x <= 0.0:
			continue
		var targets: Array = role.get("targets", [])
		if targets.is_empty():
			continue
		var target_id := String(targets[0])
		var target_cells: Array = (state.display_items.get(target_id, {}) as Dictionary).get("cells", [])
		var target_rect := _showcase_group_rect(target_cells)
		if target_rect.size.x <= 0.0:
			continue
		var source_center := source_rect.get_center()
		var target_center := target_rect.get_center()
		var arrow := Label.new()
		arrow.name = "ShowcaseChainArrow_%s_%s" % [source_id, target_id]
		arrow.text = "→"
		arrow.tooltip_text = "%s 推进到 %s" % [_recipe_name(source_id), _recipe_name(target_id)]
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow.add_theme_font_size_override("font_size", 24)
		arrow.add_theme_color_override("font_color", Color(0.94, 0.54, 0.12, 1.0))
		arrow.position = (source_center + target_center) * 0.5 - Vector2(18.0, 18.0)
		arrow.size = Vector2(36.0, 36.0)
		arrow.pivot_offset = arrow.size * 0.5
		arrow.rotation = (target_center - source_center).angle()
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.z_index = 4
		showcase_feedback_layer.add_child(arrow)


func _refresh_showcase_anchor_badges(now_unix: int) -> void:
	if state == null:
		return
	var display_items: Dictionary = state.get("display_items") if state.get("display_items") is Dictionary else {}
	for recipe_id_value in display_items.keys():
		var recipe_id := String(recipe_id_value)
		var anchor_index := _display_anchor_slot_index_for_recipe(recipe_id)
		if anchor_index < 0 or anchor_index >= showcase_grid.get_child_count():
			continue
		var anchor_slot := _showcase_slot(anchor_index)
		var badge_text := _showcase_status_badge_text(anchor_slot, now_unix)
		var skin_state: StringName = &"reward" if badge_text == "可售" else &"normal"
		for cell_value in state.get_display_item_cells(recipe_id):
			if not cell_value is Vector2i:
				continue
			var cell_index := _showcase_slot_index_for_cell(cell_value)
			if cell_index < 0 or cell_index >= showcase_grid.get_child_count():
				continue
			var cell_button := showcase_grid.get_child(cell_index) as Button
			if cell_button != null and cell_button.has_method("set_skin_state"):
				cell_button.call("set_skin_state", skin_state)
		var button := showcase_grid.get_child(anchor_index) as Button
		if button != null and button.has_method("set_status_badge"):
			button.call("set_status_badge", badge_text)
	for slot_index in range(state.display_slots.size()):
		var raw_slot: Variant = state.display_slots[slot_index]
		if raw_slot == null or raw_slot is Dictionary and (raw_slot as Dictionary).has("covered_by"):
			continue
		var slot := _showcase_slot(slot_index)
		var recipe_id := String(slot.get("recipe_id", ""))
		if recipe_id.is_empty() or state.has_method("is_display_item_placed") and state.is_display_item_placed(recipe_id):
			continue
		if slot_index < showcase_grid.get_child_count():
			var button := showcase_grid.get_child(slot_index) as Button
			if button != null:
				var badge_text := _showcase_status_badge_text(slot, now_unix)
				if button.has_method("set_skin_state"):
					button.call("set_skin_state", &"reward" if badge_text == "可售" else &"normal")
				if button.has_method("set_status_badge"):
					button.call("set_status_badge", badge_text)


func _refresh_showcase_slot_indices(slot_indices: Array, now_unix: int) -> void:
	var refreshed := {}
	for index_value in slot_indices:
		var slot_index := int(index_value)
		if refreshed.has(slot_index) or slot_index < 0 or slot_index >= showcase_grid.get_child_count():
			continue
		refreshed[slot_index] = true
		var child := showcase_grid.get_child(slot_index)
		if child is Button and child.has_meta("slot_index"):
			_apply_showcase_slot_button_state(child as Button, int(child.get_meta("slot_index")), now_unix)
	_refresh_showcase_visuals_for_slot_indices(refreshed, now_unix)


func _refresh_showcase_visuals_for_slot_indices(refreshed: Dictionary, now_unix: int) -> void:
	if refreshed.is_empty() or state == null:
		return
	var display_items: Dictionary = state.get("display_items") if state.get("display_items") is Dictionary else {}
	var recipe_ids := []
	for recipe_id_value in display_items.keys():
		var recipe_id := String(recipe_id_value)
		var touches_refresh := false
		for cell_value in state.get_display_item_cells(recipe_id):
			if cell_value is Vector2i and refreshed.has(_showcase_slot_index_for_cell(cell_value)):
				touches_refresh = true
				break
		if touches_refresh:
			recipe_ids.append(recipe_id)
	recipe_ids.sort()
	for recipe_id in recipe_ids:
		_apply_showcase_group_visual(
			recipe_id,
			state.get_display_item_cells(recipe_id),
			_display_item_variant_id(recipe_id),
			false,
			now_unix
		)
	for slot_index_value in refreshed.keys():
		var slot_index := int(slot_index_value)
		if slot_index < 0 or slot_index >= state.display_slots.size():
			continue
		var raw_slot: Variant = state.display_slots[slot_index]
		if raw_slot == null or raw_slot is Dictionary and (raw_slot as Dictionary).has("covered_by"):
			continue
		var legacy_slot := _showcase_slot(slot_index)
		var legacy_recipe_id := String(legacy_slot.get("recipe_id", ""))
		if legacy_recipe_id.is_empty() or state.has_method("is_display_item_placed") and state.is_display_item_placed(legacy_recipe_id):
			continue
		_apply_showcase_group_visual(
			legacy_recipe_id,
			[_showcase_cell_for_slot_index(slot_index)],
			"standard",
			false,
			now_unix
		)
	if not showcase_drag_preview_recipe_id.is_empty() and not showcase_drag_preview_cells.is_empty():
		for preview_cell in showcase_drag_preview_cells:
			if refreshed.has(_showcase_slot_index_for_cell(preview_cell)):
				_apply_showcase_group_visual(
					showcase_drag_preview_recipe_id,
					showcase_drag_preview_cells,
					showcase_drag_preview_variant_id,
					true,
					now_unix
				)
				break


func _set_showcase_drag_preview(recipe_id: String, cells: Array, mode: String, variant_id: String = "") -> void:
	var normalized: Array[Vector2i] = []
	for cell_value in cells:
		if cell_value is Vector2i:
			normalized.append(cell_value)
	var clean_variant_id := _normalized_showcase_variant_id(variant_id)
	if variant_id.is_empty() and state.has_method("is_display_item_placed") and state.is_display_item_placed(recipe_id):
		clean_variant_id = _display_item_variant_id(recipe_id)
	if showcase_drag_preview_recipe_id == recipe_id and showcase_drag_preview_variant_id == clean_variant_id and showcase_drag_preview_mode == mode and _same_showcase_cells(showcase_drag_preview_cells, normalized):
		return
	var previous_cells := showcase_drag_preview_cells.duplicate()
	showcase_drag_preview_recipe_id = recipe_id
	showcase_drag_preview_variant_id = clean_variant_id
	showcase_drag_preview_cells = normalized
	showcase_drag_preview_mode = mode
	_invalidate_showcase_preview_bonus_cache()
	_refresh_showcase_slot_indices(_showcase_preview_slot_indices_for_cells(previous_cells, normalized), int(Time.get_unix_time_from_system()))


func _clear_showcase_drag_preview() -> void:
	if showcase_drag_preview_recipe_id.is_empty() and showcase_drag_preview_variant_id.is_empty() and showcase_drag_preview_cells.is_empty() and showcase_drag_preview_mode.is_empty():
		return
	var previous_cells := showcase_drag_preview_cells.duplicate()
	showcase_drag_preview_recipe_id = ""
	showcase_drag_preview_variant_id = ""
	showcase_drag_preview_cells = []
	showcase_drag_preview_mode = ""
	_invalidate_showcase_preview_bonus_cache()
	_refresh_showcase_slot_indices(_showcase_preview_slot_indices_for_cells(previous_cells, []), int(Time.get_unix_time_from_system()))


func _showcase_preview_slot_indices_for_cells(previous_cells: Array, current_cells: Array) -> Array:
	var indices := []
	var seen := {}
	for cells in [previous_cells, current_cells]:
		for cell_value in cells:
			if not cell_value is Vector2i:
				continue
			var slot_index := _showcase_slot_index_for_cell(cell_value as Vector2i)
			if slot_index < 0 or seen.has(slot_index):
				continue
			seen[slot_index] = true
			indices.append(slot_index)
	indices.sort()
	return indices


func _is_showcase_preview_slot(slot_index: int) -> bool:
	for cell in showcase_drag_preview_cells:
		if _showcase_slot_index_for_cell(cell) == slot_index:
			return true
	return false


func _showcase_preview_slot_text(slot_index: int) -> String:
	var shape_info := _showcase_drag_shape_info(showcase_drag_preview_recipe_id, showcase_drag_preview_variant_id)
	var anchor_index := _showcase_anchor_slot_index_for_cells(showcase_drag_preview_cells)
	if showcase_drag_preview_mode == "stack":
		if slot_index == anchor_index:
			var current_quantity := maxi(0, state.get_display_item_stock(showcase_drag_preview_recipe_id))
			return "追加\nx%d+1" % current_quantity
		return "追加"
	if showcase_drag_preview_mode == "move":
		if slot_index == anchor_index:
			return "移动\n%s" % _recipe_name(showcase_drag_preview_recipe_id)
		return "移动"
	if showcase_drag_preview_mode == "replace":
		if slot_index == anchor_index:
			return "替换\n%s" % _recipe_name(showcase_drag_preview_recipe_id)
		return "替换"
	if slot_index == anchor_index:
		return "预占\n%s\n%s\n%d格" % [
			_showcase_variant_label(showcase_drag_preview_variant_id),
			String(shape_info.get("default_shape", "1x1")),
			int(shape_info.get("cell_count", showcase_drag_preview_cells.size()))
		]
	return "预占"


func _showcase_preview_slot_tooltip(_slot_index: int) -> String:
	var shape_info := _showcase_drag_shape_info(showcase_drag_preview_recipe_id, showcase_drag_preview_variant_id)
	var action := "释放后移动到这些格子"
	if showcase_drag_preview_mode == "stack":
		action = "追加到已上架区域"
	elif showcase_drag_preview_mode == "replace":
		action = "释放后替换该售完商品"
	elif showcase_drag_preview_mode != "move":
		action = "释放后占用这些格子"
	return "%s\n变体：%s\n形状：%s\n占格：%d\n%s\n%s" % [
		_recipe_name(showcase_drag_preview_recipe_id),
		_showcase_variant_label(showcase_drag_preview_variant_id),
		String(shape_info.get("default_shape", "1x1")),
		int(shape_info.get("cell_count", showcase_drag_preview_cells.size())),
		action,
		_showcase_preview_bonus_text(showcase_drag_preview_recipe_id, showcase_drag_preview_cells, showcase_drag_preview_mode, showcase_drag_preview_variant_id)
	]


func _showcase_slot_text(slot_index: int, now_unix: int) -> String:
	var slot := _showcase_slot(slot_index)
	if slot.is_empty():
		return "%02d\n空" % (slot_index + 1)
	var recipe_id := String(slot.get("recipe_id", ""))
	var display_name := _recipe_name(recipe_id)
	var variant_id := _display_item_variant_id(recipe_id)
	if variant_id != "standard":
		display_name = "%s·%s" % [display_name, _showcase_variant_label(variant_id)]
	var growth_label := _recipe_growth_label(recipe_id)
	if not growth_label.is_empty():
		display_name = "%s·%s" % [display_name, growth_label]
	var item_view := _showcase_round_item_view(recipe_id)
	var quantity := maxi(0, int(item_view.get("quantity", slot.get("quantity", 0))))
	if quantity <= 0:
		return "%s\n待补货" % display_name
	var phase := String(item_view.get("phase", "adjusting"))
	if phase == "running":
		return "%s\nx%d｜%s\n%.1f秒" % [display_name, quantity, String(item_view.get("batch_label", "")), float(item_view.get("remaining_ms", 0)) / 1000.0]
	if phase == "settlement":
		return "%s\nx%d\n待结算" % [display_name, quantity]
	return "%s\nx%d｜%s" % [display_name, quantity, String(item_view.get("batch_label", ""))]


func _showcase_status_badge_text(slot: Dictionary, now_unix: int) -> String:
	var recipe_id := String(slot.get("recipe_id", ""))
	if showcase_stock_feedback_badges.has(recipe_id):
		var feedback_entry: Dictionary = showcase_stock_feedback_badges.get(recipe_id, {})
		return String(feedback_entry.get("text", ""))
	var item_view := _showcase_round_item_view(recipe_id)
	var phase := String(item_view.get("phase", "adjusting"))
	if phase == "settlement":
		return "待结算"
	var quantity := maxi(0, int(item_view.get("quantity", slot.get("quantity", 0))))
	if quantity <= 0:
		return "待补货"
	if phase == "running":
		var seconds := int(ceil(float(item_view.get("remaining_ms", 0)) / 1000.0))
		return "%s %ds" % [String(item_view.get("batch_label", "")), seconds]
	return "%s ×%d" % [String(item_view.get("batch_label", "")), quantity]


func _showcase_slot_tooltip(slot_index: int, now_unix: int) -> String:
	var slot := _showcase_slot(slot_index)
	if slot.is_empty():
		return "把库存中的成品拖到这里上架。"
	var recipe_id := String(slot.get("recipe_id", ""))
	var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
	var tags_value: Variant = recipe.get("tags", [])
	var tag_names: Array[String] = []
	if tags_value is Array:
		for tag in tags_value:
			tag_names.append(String(tag))
	var item_view := _showcase_round_item_view(recipe_id)
	var listed_stock := int(item_view.get("quantity", state.get_display_item_stock(recipe_id)))
	var phase := String(item_view.get("phase", "adjusting"))
	var sale_text := ("待补货：拖入同款成品后即可开始营业。" if listed_stock <= 0 else "调整布局并补货后，点击开始营业。") \
		+ "\n" + _showcase_adjusting_sale_preview_text(recipe_id)
	if phase == "running":
		if listed_stock <= 0:
			sale_text = "待补货：当前没有可售批次；不会倒扣成交次数，拖入同款即可重新开始完整销售周期。"
		else:
			sale_text = "%s批次｜本次成交还需 %.1f 秒｜本轮剩余 %.1f 秒" % [
				String(item_view.get("batch_label", "")),
				float(item_view.get("remaining_ms", 0)) / 1000.0,
				float(state.active_business_round.get("remaining_ms", 0)) / 1000.0
			]
	elif phase == "settlement":
		sale_text = "营业结束：未完成的销售周期不结算，请先处理本轮余货。"
	return "名称：%s\n变体：%s\n售价：%d\n上架数量：%d\n库存剩余：%d\n标签：%s\n%s\n%s\n%s\n最近售卖：%s" % [
		_recipe_name(recipe_id),
		_showcase_variant_label(_display_item_variant_id(recipe_id)),
		int(recipe.get("price", 0)),
		listed_stock,
		state.get_product_count(recipe_id),
		"、".join(tag_names),
		sale_text,
		_recipe_growth_detail_text(recipe_id),
		_showcase_bonus_detail_text(recipe_id),
		_recent_sale_text(_recipe_name(recipe_id))
	]


func _showcase_adjusting_sale_preview_text(recipe_id: String, compact: bool = false) -> String:
	var source_terms := _showcase_round_sale_terms()
	var environment: Dictionary = state.active_business_round.get("environment", {})
	var terms := RoundEnvironmentService.apply_to_terms(source_terms, environment)
	var term: Dictionary = terms.get(recipe_id, {})
	var duration_ms := maxi(1000, int(term.get("duration_seconds", 1)) * 1000)
	var round_duration_ms := 30000
	if not state.pending_showcase_challenge.is_empty():
		round_duration_ms = maxi(1000, int(state.pending_showcase_challenge.get("duration_seconds", 30)) * 1000)
	var expected_sales := round_duration_ms / duration_ms
	var next_duration_ms := maxi(1, int(floor(float(round_duration_ms) / float(expected_sales + 1))))
	var gap_ms := maxi(0, duration_ms - next_duration_ms)
	var item: Dictionary = state.display_items.get(recipe_id, {})
	var fresh_stock := maxi(0, int(item.get("fresh_stock", item.get("stock", 0))))
	var carried_stock := maxi(0, int(item.get("carried_stock", 0)))
	if compact:
		return "周期 %.1f 秒｜预计完整成交 %d 次｜距离下一档需缩短 %.1f 秒" % [
			float(duration_ms) / 1000.0,
			expected_sales,
			float(gap_ms) / 1000.0
		]
	return "周期 %.1f 秒｜预计完整成交 %d 次｜距离下一档还需缩短 %.1f 秒\n全价库存 %d｜8 折留售库存 %d｜预计以库存持续充足为前提" % [
		float(duration_ms) / 1000.0,
		expected_sales,
		float(gap_ms) / 1000.0,
		fresh_stock,
		carried_stock
	]


func _showcase_bonus_for_recipe(recipe_id: String) -> Dictionary:
	var bonuses := _current_showcase_bonuses()
	return bonuses.get(recipe_id, {})


func _current_showcase_bonuses() -> Dictionary:
	if state == null:
		return {}
	if showcase_bonus_cache_valid:
		return showcase_bonus_cache
	var rule_result: Dictionary = ShowcaseRuleService.calculate(state, catalog.get_recipes(), catalog.get_display_rules())
	showcase_bonus_cache = rule_result.get("items", {})
	showcase_bonus_cache_valid = true
	return showcase_bonus_cache


func _invalidate_showcase_bonus_cache() -> void:
	showcase_bonus_cache = {}
	showcase_bonus_cache_valid = false


func _preview_showcase_bonus(recipe_id: String, cells: Array, mode: String, variant_id: String = "") -> Dictionary:
	if recipe_id.is_empty() or state == null:
		return {}
	var clean_variant_id := _normalized_showcase_variant_id(variant_id)
	var cache_key := _showcase_preview_bonus_key(recipe_id, cells, mode, clean_variant_id)
	if cache_key == showcase_preview_bonus_cache_key:
		return showcase_preview_bonus_cache.duplicate(true)
	var preview_state = GameState.from_dict(state.to_dict())
	if preview_state == null:
		return {}
	if mode != "stack" and preview_state.has_method("place_display_item"):
		preview_state.place_display_item(recipe_id, cells, clean_variant_id)
	var rule_result: Dictionary = ShowcaseRuleService.calculate(preview_state, catalog.get_recipes(), catalog.get_display_rules())
	var bonuses: Dictionary = rule_result.get("items", {})
	var bonus: Dictionary = bonuses.get(recipe_id, {})
	showcase_preview_bonus_cache_key = cache_key
	showcase_preview_bonus_cache = bonus.duplicate(true)
	return bonus


func _showcase_preview_bonus_key(recipe_id: String, cells: Array, mode: String, variant_id: String = "") -> String:
	var slot_indices: Array[String] = []
	for cell_value in cells:
		if not cell_value is Vector2i:
			continue
		var slot_index := _showcase_slot_index_for_cell(cell_value as Vector2i)
		if slot_index >= 0:
			slot_indices.append(str(slot_index))
	return "%s|%s|%s|%s" % [recipe_id, _normalized_showcase_variant_id(variant_id), mode, ",".join(slot_indices)]


func _invalidate_showcase_preview_bonus_cache() -> void:
	showcase_preview_bonus_cache_key = ""
	showcase_preview_bonus_cache = {}


func _showcase_preview_bonus_text(recipe_id: String, cells: Array, mode: String, variant_id: String = "") -> String:
	var bonus := _preview_showcase_bonus(recipe_id, cells, mode, variant_id)
	var lines: Array[String] = [_showcase_bonus_summary_line(recipe_id, bonus, "预计变化")]
	var before_bonus: Dictionary = {}
	if state != null and state.display_items.has(recipe_id):
		before_bonus = _showcase_bonus_for_recipe(recipe_id)
	var delta := ShowcaseRuleService.rule_difference(before_bonus, bonus)
	lines.append("新增：%s" % _showcase_rule_delta_text(delta.get("added", []), "无"))
	lines.append("失去：%s" % _showcase_rule_delta_text(delta.get("lost", []), "无"))
	lines.append("风险：%s" % _showcase_rule_delta_text(delta.get("risks", []), "无"))
	return "\n".join(lines)


func _showcase_rule_delta_text(values_value: Variant, empty_text: String) -> String:
	var values: Array = values_value if values_value is Array else []
	if values.is_empty():
		return empty_text
	var texts: Array[String] = []
	for value in values.slice(0, mini(2, values.size())):
		texts.append(String(value))
	return "；".join(texts)


func _showcase_bonus_detail_text(recipe_id: String) -> String:
	var bonus := _showcase_bonus_for_recipe(recipe_id)
	var lines: Array[String] = [_showcase_bonus_summary_line(recipe_id, bonus, "当前加成")]
	var breakdown_lines := _showcase_bonus_breakdown_lines(bonus)
	if breakdown_lines.is_empty():
		lines.append("加成来源：暂无")
	else:
		lines.append("加成来源：")
		for line in breakdown_lines:
			lines.append("- %s" % line)
	return "\n".join(lines)


func _showcase_bonus_panel_text() -> String:
	var bonuses := _current_showcase_bonuses()
	var recipe_ids := _showcase_bonus_recipe_ids(bonuses)
	var lines: Array[String] = ["橱窗加成"]
	if recipe_ids.is_empty():
		lines.append("暂无上架商品")
		return "\n".join(lines)
	var rule_result := ShowcaseRuleService.calculate(state, catalog.get_recipes(), catalog.get_display_rules())
	var summary: Dictionary = rule_result.get("summary", {})
	lines.append("布局摘要：正向 %d｜冲突 %d｜道具 %d｜主题 %s" % [
		int(summary.get("positive_rule_count", 0)),
		int(summary.get("conflict_count", 0)),
		int(summary.get("prop_count", 0)),
		"无" if String(summary.get("theme_id", "")).is_empty() else String(summary.get("theme_id", ""))
	])
	for recipe_id in recipe_ids:
		lines.append(_showcase_bonus_summary_line(recipe_id, bonuses.get(recipe_id, {}), _recipe_name(recipe_id)))
	return "\n".join(lines)


func _showcase_business_preview_text() -> String:
	var snapshot := _showcase_business_snapshot()
	return "本轮预估：到期 %d 件｜上架库存 %d｜预计金币 +%d｜预计口碑 +%d" % [
		int(snapshot.get("ready_count", 0)),
		int(snapshot.get("listed_stock", 0)),
		int(snapshot.get("estimated_coins", 0)),
		int(snapshot.get("estimated_reputation", 0))
	]


func _showcase_business_snapshot() -> Dictionary:
	var bonuses := _current_showcase_bonuses()
	var ready_count := 0
	var listed_count := 0
	var placed_count := 0
	var shortage_count := 0
	var estimated_coins := 0
	var ready_estimated_coins := 0
	var coins_per_minute := 0.0
	for recipe_id_value: Variant in state.display_items.keys():
		var recipe_id := String(recipe_id_value)
		if recipe_id.is_empty():
			continue
		var item: Dictionary = state.display_items.get(recipe_id_value, {})
		var stock := _storefront_listed_stock_for_recipe(recipe_id)
		placed_count += 1
		listed_count += stock
		if stock <= 0:
			shortage_count += 1
		var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
		var base_price := int(recipe.get("price", 0))
		var bonus: Dictionary = bonuses.get(recipe_id, {})
		var estimated_price := int(round(float(base_price) * float(bonus.get("price_multiplier", 1.0))))
		if stock > 0:
			estimated_coins += estimated_price
			var base_seconds := maxi(1, int(item.get("base_sale_seconds", item.get("cycle_duration_seconds", SHOWCASE_SALE_MIN_SECONDS))))
			var duration := _showcase_sale_seconds_for_bonus(base_seconds, float(bonus.get("speed_multiplier", 1.0)))
			coins_per_minute += float(estimated_price) * 60.0 / float(duration)
		if stock > 0:
			ready_count += 1
			ready_estimated_coins += estimated_price
	return {
		"ready_count": ready_count,
		"listed_stock": listed_count,
		"placed_count": placed_count,
		"shortage_count": shortage_count,
		"coins_per_minute": coins_per_minute,
		"estimated_coins": estimated_coins,
		"ready_estimated_coins": ready_estimated_coins,
		"estimated_reputation": ready_count
	}


func _showcase_low_stock_lines() -> Array[String]:
	var lines: Array[String] = []
	var recipe_ids := _showcase_bonus_recipe_ids(_current_showcase_bonuses())
	for recipe_id in recipe_ids:
		var listed_stock: int = int(state.get_display_item_stock(recipe_id)) if state.has_method("get_display_item_stock") else 0
		var inventory_stock: int = int(state.get_product_count(recipe_id))
		if listed_stock <= 1 or inventory_stock <= 2:
			lines.append("补货提醒：%s 上架 x%d，库存 x%d" % [_recipe_name(recipe_id), listed_stock, inventory_stock])
	return lines


func _unlocked_showcase_slot_count() -> int:
	var count := 0
	for slot_index in range(SHOWCASE_SLOT_COUNT):
		if _is_showcase_slot_unlocked(slot_index):
			count += 1
	return count


func _is_showcase_slot_unlocked(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SHOWCASE_SLOT_COUNT:
		return false
	if state != null and state.has_method("is_showcase_cell_unlocked"):
		return state.is_showcase_cell_unlocked(_showcase_cell_for_slot_index(slot_index))
	var row := int(slot_index / SHOWCASE_GRID_COLUMNS) + 1
	var col := int(slot_index % SHOWCASE_GRID_COLUMNS) + 1
	return row >= 5 and row <= 8 and col >= 6 and col <= 9


func _are_showcase_cells_unlocked(cells: Array) -> bool:
	if cells.is_empty():
		return false
	for cell_value in cells:
		if not cell_value is Vector2i:
			return false
		var slot_index := _showcase_slot_index_for_cell(cell_value as Vector2i)
		if not _is_showcase_slot_unlocked(slot_index):
			return false
	return true


func _showcase_bonus_recipe_ids(bonuses: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	if state != null and state.has_method("get") and state.get("display_items") is Dictionary:
		for recipe_id_value in (state.get("display_items") as Dictionary).keys():
			var recipe_id := String(recipe_id_value)
			if bonuses.has(recipe_id) and not ids.has(recipe_id):
				ids.append(recipe_id)
	if ids.is_empty() and state != null:
		for slot_index in range(state.display_slots.size()):
			var slot := _showcase_slot(slot_index)
			var recipe_id := String(slot.get("recipe_id", ""))
			if not recipe_id.is_empty() and bonuses.has(recipe_id) and not ids.has(recipe_id):
				ids.append(recipe_id)
	ids.sort()
	return ids


func _showcase_bonus_summary_line(recipe_id: String, bonus: Dictionary, prefix: String) -> String:
	var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
	var base_price := int(recipe.get("price", 0))
	var price_multiplier := float(bonus.get("price_multiplier", 1.0))
	var speed_multiplier := float(bonus.get("speed_multiplier", 1.0))
	var final_price := int(round(float(base_price) * price_multiplier))
	var base_seconds := 20
	var adjusted_seconds := _showcase_sale_seconds_for_bonus(base_seconds, speed_multiplier)
	return "%s：售价 %s（%d→%d），售速 %s（%d秒→%d秒）" % [
		prefix,
		_bonus_pct_text((price_multiplier - 1.0) * 100.0),
		base_price,
		final_price,
		_bonus_pct_text((speed_multiplier - 1.0) * 100.0),
		base_seconds,
		adjusted_seconds
	]


func _showcase_bonus_breakdown_lines(bonus: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var breakdown: Dictionary = bonus.get("breakdown", {})
	var order := ["zone", "adjacency_tag", "set", "conflict", "spacing", "growth", "variant", "theme", "prop"]
	var labels := {
		"zone": "区域",
		"adjacency_tag": "相邻标签",
		"set": "套装",
		"conflict": "冲突",
		"spacing": "留白/拥挤",
		"growth": "成长",
		"variant": "变体",
		"theme": "主题",
		"prop": "道具"
	}
	for key in order:
		var value: Dictionary = breakdown.get(key, {})
		var price_pct := float(value.get("price_pct", 0.0))
		var speed_pct := float(value.get("speed_pct", 0.0))
		if absf(price_pct) < 0.01 and absf(speed_pct) < 0.01:
			continue
		var extra := ""
		if key == "growth":
			var mastery_name := String(value.get("mastery_name", ""))
			if not mastery_name.is_empty():
				extra = "（%s）" % mastery_name
		var line := "%s%s：售价 %s，售速 %s" % [
			String(labels.get(key, key)),
			extra,
			_bonus_pct_text(price_pct),
			_bonus_pct_text(speed_pct)
		]
		var reason_text := _showcase_bonus_part_reason_text(value, 2)
		if not reason_text.is_empty():
			line += "；原因：%s" % reason_text
		result.append(line)
	return result


func _showcase_bonus_part_reason_text(part: Dictionary, limit: int = 2) -> String:
	var raw_reasons: Array = part.get("reasons", [])
	var reasons: Array[String] = []
	for reason_value in raw_reasons:
		var reason := String(reason_value).strip_edges()
		if reason.is_empty() or reasons.has(reason):
			continue
		reasons.append(reason)
		if reasons.size() >= limit:
			break
	return "；".join(reasons)


func _showcase_bonus_reason_text(bonus: Dictionary, limit: int = 2) -> String:
	var breakdown: Dictionary = bonus.get("breakdown", {})
	var order := ["zone", "adjacency_tag", "set", "conflict", "spacing", "growth", "variant", "theme", "prop"]
	var reasons: Array[String] = []
	for key in order:
		var value: Dictionary = breakdown.get(key, {})
		var raw_reasons: Array = value.get("reasons", [])
		for reason_value in raw_reasons:
			var reason := String(reason_value).strip_edges()
			if reason.is_empty() or reasons.has(reason):
				continue
			reasons.append(reason)
			if reasons.size() >= limit:
				return "；".join(reasons)
	return "；".join(reasons)


func _bonus_pct_text(value: float) -> String:
	if absf(value) < 0.01:
		return "0%"
	if value > 0.0:
		return "+%.0f%%" % value
	return "%.0f%%" % value


func _showcase_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= state.display_slots.size():
		return {}
	var slot_value: Variant = state.display_slots[slot_index]
	if slot_value is Dictionary:
		var slot: Dictionary = slot_value
		if slot.has("covered_by"):
			var anchor_index := int(slot.get("covered_by", -1))
			if anchor_index == slot_index:
				return {}
			var anchor_slot := _showcase_slot(anchor_index)
			if anchor_slot.is_empty():
				return {}
			var covered_slot := anchor_slot.duplicate(true)
			covered_slot["covered_by"] = anchor_index
			return covered_slot
		var recipe_id := String(slot.get("recipe_id", ""))
		if recipe_id.is_empty():
			return {}
		return slot
	if slot_value != null:
		var recipe_id := String(slot_value)
		if not recipe_id.is_empty():
			return {
				"recipe_id": recipe_id,
				"quantity": maxi(1, state.get_product_count(recipe_id))
			}
	return {}


func _has_legacy_display_product() -> bool:
	for slot_value: Variant in state.display_slots:
		if slot_value == null or slot_value is Dictionary:
			continue
		var recipe_id := String(slot_value)
		if not recipe_id.is_empty() and state.get_product_count(recipe_id) > 0:
			return true
	return false


func _process_showcase_business_round_delta(delta: float) -> void:
	if state == null or String(state.active_business_round.get("phase", "")) != "running":
		showcase_round_delta_carry_ms = 0.0
		return
	if bool(state.active_business_round.get("paused", false)):
		return
	showcase_round_delta_carry_ms += maxf(0.0, delta) * 1000.0
	var delta_ms := int(floor(showcase_round_delta_carry_ms))
	if delta_ms <= 0:
		return
	showcase_round_delta_carry_ms -= float(delta_ms)
	var remaining_ms := delta_ms
	while remaining_ms > 0 and String(state.active_business_round.get("phase", "")) == "running":
		var step_ms := mini(1000, remaining_ms)
		_advance_showcase_business_round(step_ms)
		remaining_ms -= step_ms
	if global_popup_mode == "storefront_manage":
		_refresh_showcase_sale_progress_groups()
	showcase_round_persist_carry_ms += delta_ms
	if showcase_round_persist_carry_ms >= 1000:
		showcase_round_persist_carry_ms %= 1000
		_save_game()
		if global_popup_mode == "storefront_manage":
			_refresh_storefront_live_metrics()


func _start_showcase_business_round() -> bool:
	if state == null:
		return false
	var current_phase := String(state.active_business_round.get("phase", ""))
	if current_phase == "settlement":
		if state.pending_showcase_settlement.is_empty():
			_set_status("本轮结算数据缺失，请重新加载存档后重试。")
			_refresh_showcase_round_controls()
			return false
		_present_showcase_round_settlement()
		_set_status("已重新打开本轮营业结算。")
		return true
	if not _require_core_feature(CoreFeatureUnlockService.BUSINESS):
		return false
	if showcase_expansion_active:
		_set_status("请先确认或退出扩建模式，再开始营业。")
		return false
	if not state.pending_showcase_settlement.is_empty():
		_set_status("请先处理上一轮余货。")
		return false
	if current_phase == "running" or current_phase == "settlement":
		_set_status("当前营业轮尚未结束。")
		return false
	_ensure_showcase_batch_fields()
	var preview_environment := _ensure_showcase_round_environment()
	var preview_hotspot := _ensure_showcase_hotspot()
	var sale_terms := _showcase_round_terms_for_environment(preview_environment, preview_hotspot)
	var item_states := ShowcaseRoundSaleService.build_item_states(state.display_items, sale_terms)
	if item_states.is_empty():
		_set_status("请先在橱窗摆放并补入商品。")
		return false
	var has_stock := false
	for item_value in item_states.values():
		if item_value is Dictionary and int((item_value as Dictionary).get("fresh_stock", 0)) + int((item_value as Dictionary).get("carried_stock", 0)) > 0:
			has_stock = true
			break
	if not has_stock:
		_set_status("橱窗商品均待补货。")
		return false
	var round_state: Dictionary
	if not state.pending_showcase_challenge.is_empty():
		round_state = BusinessRoundService.create_challenge(
			state.business_round_id,
			int(state.pending_showcase_challenge.get("duration_seconds", 30)),
			state.pending_showcase_challenge
		)
	else:
		round_state = state.active_business_round.duplicate(true)
		if String(round_state.get("phase", "")) != "adjusting" or int(round_state.get("round_id", 0)) != state.business_round_id:
			round_state = BusinessRoundService.create_standard(state.business_round_id)
	round_state["environment"] = preview_environment.duplicate(true)
	round_state["hotspot"] = preview_hotspot.duplicate(true)
	round_state["sale_terms"] = sale_terms.duplicate(true)
	round_state["role_snapshot"] = ShowcaseRoleService.build_configured_snapshot(
		state.display_items,
		sale_terms,
		catalog.get_showcase_round_rules().get("role_rules", {})
	)
	round_state["tag_snapshot"] = _showcase_tag_snapshot(state.display_items)
	round_state["chain_max_depth"] = int(catalog.get_showcase_round_rules().get("chain_max_depth", 4))
	round_state["initial_item_states"] = item_states.duplicate(true)
	round_state["applied_sale_event_ids"] = []
	round_state["refill_events"] = []
	round_state["sale_events"] = []
	round_state["live_layout_changed"] = false
	round_state["live_listing_events"] = []
	state.active_business_round = BusinessRoundService.start_round(
		round_state,
		state.display_items,
		item_states
	)
	var completed_task_ids: Array = state.record_task_event("business_round_started", {
		"round_id": int(state.active_business_round.get("round_id", 0)),
		"kind": String(state.active_business_round.get("kind", "standard"))
	})
	TutorialProgress.on_business_round_started(state)
	_refresh_core_feature_access()
	showcase_round_delta_carry_ms = 0.0
	showcase_round_persist_carry_ms = 0
	_save_game()
	_refresh_showcase_round_controls()
	_refresh_storefront_showcase()
	call_deferred("_refresh_tutorial_guide")
	if global_popup_mode == "storefront_manage":
		_refresh_storefront_manage_sections()
	_set_status("开始营业：本轮固定 30 秒，营业中可补入同款商品。")
	return true


func _advance_showcase_business_round(delta_ms: int) -> Dictionary:
	if state == null or delta_ms <= 0:
		return {}
	var current: Dictionary = state.active_business_round.duplicate(true)
	if String(current.get("phase", "")) != "running" or bool(current.get("paused", false)):
		return current
	if showcase_feedback_director.pending_count() == 0 \
			and showcase_feedback_director.active_count() == 0 \
			and showcase_feedback_pending_coin_rolls == 0:
		showcase_feedback_visual_coin_target = int(state.coins)
	var from_elapsed_ms := maxi(0, int(current.get("elapsed_ms", 0)))
	var clock_result := BusinessRoundService.advance(current, delta_ms)
	var to_elapsed_ms := maxi(from_elapsed_ms, int(clock_result.get("elapsed_ms", from_elapsed_ms)))
	var final_phase := String(clock_result.get("phase", "running"))
	var sale_result := ShowcaseRoundSaleService.advance(
		current.get("item_states", {}),
		from_elapsed_ms,
		to_elapsed_ms
	)
	clock_result["phase"] = "running"
	clock_result["item_states"] = (sale_result.get("item_states", {}) as Dictionary).duplicate(true)
	state.active_business_round = clock_result
	var recorded_events: Array = state.active_business_round.get("sale_events", [])
	var sale_terms: Dictionary = state.active_business_round.get("sale_terms", {})
	var resolved_item_states: Dictionary = (sale_result.get("item_states", {}) as Dictionary).duplicate(true)
	var event_index := recorded_events.size()
	var feedback_enqueued := false
	var completed_sale_feedback_events: Array[Dictionary] = []
	for event_value in sale_result.get("events", []):
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var recipe_id := String(event.get("recipe_id", ""))
		var term: Dictionary = sale_terms.get(recipe_id, {})
		var completed_at_ms := int(event.get("completed_at_ms", to_elapsed_ms))
		var full_event := event.duplicate(true)
		full_event["event_id"] = "%d:%s:%d:%d" % [
			int(state.active_business_round.get("round_id", state.business_round_id)),
			recipe_id,
			completed_at_ms,
			event_index
		]
		full_event["quantity"] = 1
		full_event["recipe_name"] = _recipe_name(recipe_id)
		full_event["earned_reputation"] = maxi(0, int(term.get("reputation_gain", 1)))
		full_event["base_price"] = maxi(0, int(term.get("base_price", 0)))
		full_event["environment_price_pct"] = float(term.get("environment_price_pct", 0.0))
		full_event["timestamp"] = completed_at_ms
		full_event["anchor_slot"] = _showcase_slot_index_for_cell(event.get("anchor_cell", Vector2i(-1, -1)))
		full_event["cell_indices"] = _showcase_slot_indices_for_recipe(recipe_id)
		var event_reasons: Array = []
		if term.get("bonus", {}) is Dictionary:
			for reason_value in (term.get("bonus", {}) as Dictionary).get("reasons", []):
				event_reasons.append(reason_value)
		for environment_reason in term.get("environment_reasons", []):
			event_reasons.append(environment_reason)
		full_event["reasons"] = event_reasons
		full_event = _enrich_showcase_sale_feedback_event(full_event, term)
		if state.apply_showcase_round_sale(full_event):
			recorded_events.append(full_event)
			state.record_task_event("showcase_sale", full_event)
			completed_sale_feedback_events.append(full_event)
			event_index += 1
			if showcase_feedback_director.enqueue_sale(full_event, Time.get_ticks_msec()):
				feedback_enqueued = true
			var chain_result := ShowcaseChainService.resolve_chain(
				full_event,
				resolved_item_states,
				state.active_business_round.get("role_snapshot", {}),
				int(state.active_business_round.get("heat", 0)),
				int(catalog.get_showcase_round_rules().get("chain_max_depth", 4))
			)
			resolved_item_states = (chain_result.get("item_states", resolved_item_states) as Dictionary).duplicate(true)
			state.active_business_round["heat"] = int(chain_result.get("heat", state.active_business_round.get("heat", 0)))
			for chain_event_value in chain_result.get("chain_events", []):
				if not chain_event_value is Dictionary:
					continue
				var chain_event: Dictionary = (chain_event_value as Dictionary).duplicate(true)
				var chain_recipe_id := String(chain_event.get("recipe_id", ""))
				chain_event["event_id"] = "%d:chain:%s:%d:%d" % [
					int(state.active_business_round.get("round_id", state.business_round_id)),
					chain_recipe_id,
					completed_at_ms,
					event_index
				]
				chain_event["recipe_name"] = _recipe_name(chain_recipe_id)
				chain_event["earned_reputation"] = 0 if bool(chain_event.get("bonus_only", false)) else int((sale_terms.get(chain_recipe_id, {}) as Dictionary).get("reputation_gain", 1))
				var chain_term: Dictionary = sale_terms.get(chain_recipe_id, {})
				chain_event["base_price"] = 0 if bool(chain_event.get("bonus_only", false)) else maxi(0, int(chain_term.get("base_price", 0)))
				chain_event["environment_price_pct"] = float(chain_term.get("environment_price_pct", 0.0))
				chain_event["timestamp"] = completed_at_ms
				chain_event["cell_indices"] = _showcase_slot_indices_for_recipe(chain_recipe_id)
				chain_event["reasons"] = ["热度连锁：%s" % String(chain_event.get("chain_source", "advance"))]
				chain_event = _enrich_showcase_sale_feedback_event(chain_event, chain_term)
				if state.apply_showcase_round_sale(chain_event):
					recorded_events.append(chain_event)
					state.record_task_event("showcase_sale", chain_event)
					completed_sale_feedback_events.append(chain_event)
					event_index += 1
					if showcase_feedback_director.enqueue_sale(chain_event, Time.get_ticks_msec()):
						feedback_enqueued = true
	if feedback_enqueued:
		_play_pending_showcase_sale_feedback()
	state.active_business_round["sale_events"] = recorded_events
	state.active_business_round["item_states"] = resolved_item_states
	state.active_business_round["phase"] = final_phase
	_refresh_newly_sold_out_showcase_drag_sources(current.get("item_states", {}), resolved_item_states)
	for completed_event in completed_sale_feedback_events:
		_play_showcase_sale_progress_completion(completed_event)
	if final_phase == "settlement":
		var base_prices := {}
		for recipe_id_value in sale_terms.keys():
			var recipe_id := String(recipe_id_value)
			base_prices[recipe_id] = int((sale_terms.get(recipe_id_value, {}) as Dictionary).get("base_price", 0))
		var settlement_id := "round:%d" % int(state.active_business_round.get("round_id", state.business_round_id))
		var quote := ShowcaseFreshnessService.prepare_settlement(
			state.active_business_round.get("item_states", {}),
			base_prices,
			settlement_id
		)
		quote["item_states"] = (state.active_business_round.get("item_states", {}) as Dictionary).duplicate(true)
		quote["round_summary"] = _build_showcase_round_summary(recorded_events, sale_terms, quote["item_states"])
		quote["challenge_snapshot"] = state.pending_showcase_challenge.duplicate(true)
		state.pending_showcase_settlement = quote
		_present_showcase_round_settlement()
	if not (sale_result.get("events", []) as Array).is_empty() or final_phase == "settlement":
		_save_game()
	_refresh_showcase_round_controls()
	return state.active_business_round.duplicate(true)


func _refresh_newly_sold_out_showcase_drag_sources(previous_states: Dictionary, current_states: Dictionary) -> void:
	var slot_indices: Array = []
	for recipe_id_value in current_states.keys():
		var recipe_id := String(recipe_id_value)
		var previous: Dictionary = previous_states.get(recipe_id_value, {})
		var current_item: Dictionary = current_states.get(recipe_id_value, {})
		var previous_stock := maxi(0, int(previous.get("fresh_stock", 0))) + maxi(0, int(previous.get("carried_stock", 0)))
		var current_stock := maxi(0, int(current_item.get("fresh_stock", 0))) + maxi(0, int(current_item.get("carried_stock", 0)))
		if previous_stock <= 0 or current_stock > 0 or not bool(current_item.get("waiting_for_refill", false)):
			continue
		for slot_index in _showcase_slot_indices_for_recipe(recipe_id):
			if not slot_indices.has(slot_index):
				slot_indices.append(slot_index)
	if not slot_indices.is_empty():
		_refresh_showcase_slot_indices(slot_indices, int(Time.get_unix_time_from_system()))


func _showcase_sale_feedback_breakdown(event: Dictionary, term: Dictionary) -> Dictionary:
	var report_event := event.duplicate(true)
	report_event["base_price"] = maxi(0, int(term.get("base_price", event.get("base_price", 0))))
	report_event["environment_price_pct"] = float(term.get("environment_price_pct", event.get("environment_price_pct", 0.0)))
	return ShowcaseRoundReportService.event_income_breakdown(report_event)


func _showcase_layout_boost_percent(breakdown: Dictionary) -> int:
	var market_baseline := int(breakdown.get("base_income", 0)) + int(breakdown.get("market_income", 0))
	var layout_extra := int(breakdown.get("layout_extra_income", 0))
	if market_baseline <= 0 or layout_extra == 0:
		return 0
	return int(round(float(layout_extra) * 100.0 / float(market_baseline)))


func _showcase_sale_feedback_boost_percent(event: Dictionary) -> int:
	if bool(event.get("bonus_only", false)):
		match String(event.get("chain_source", "")):
			"amplify":
				return 20
			"harvest":
				return 30
	var breakdown: Dictionary = event.get("feedback_breakdown", {})
	var income_boost := _showcase_layout_boost_percent(breakdown)
	return income_boost if income_boost != 0 else int(event.get("speed_boost_percent", 0))


func _showcase_sale_feedback_text_position(product_rect: Rect2, feedback_size: Vector2, layer_size: Vector2) -> Vector2:
	const GAP := 8.0
	const RISE_DISTANCE := 28.0
	var candidates := [
		Vector2(product_rect.get_center().x - feedback_size.x * 0.5, product_rect.position.y - feedback_size.y - GAP),
		Vector2(product_rect.end.x + GAP, product_rect.get_center().y - feedback_size.y * 0.5),
		Vector2(product_rect.position.x - feedback_size.x - GAP, product_rect.get_center().y - feedback_size.y * 0.5),
		Vector2(product_rect.get_center().x - feedback_size.x * 0.5, product_rect.end.y + GAP + RISE_DISTANCE)
	]
	var bounds := Rect2(Vector2.ZERO, layer_size)
	for candidate_value in candidates:
		var candidate: Vector2 = candidate_value
		var candidate_rect := Rect2(candidate, feedback_size)
		if bounds.encloses(candidate_rect) and not candidate_rect.intersects(product_rect):
			return candidate
	for candidate_value in candidates:
		var candidate: Vector2 = candidate_value
		var clamped := Vector2(
			clampf(candidate.x, 0.0, maxf(0.0, layer_size.x - feedback_size.x)),
			clampf(candidate.y, 0.0, maxf(0.0, layer_size.y - feedback_size.y))
		)
		if not Rect2(clamped, feedback_size).intersects(product_rect):
			return clamped
	return Vector2(
		clampf(candidates[0].x, 0.0, maxf(0.0, layer_size.x - feedback_size.x)),
		clampf(candidates[0].y, 0.0, maxf(0.0, layer_size.y - feedback_size.y))
	)


func _enrich_showcase_sale_feedback_event(event: Dictionary, term: Dictionary) -> Dictionary:
	var enriched := event.duplicate(true)
	var recipe_id := String(enriched.get("recipe_id", ""))
	if int(enriched.get("anchor_slot", -1)) < 0:
		enriched["anchor_slot"] = _display_anchor_slot_index_for_recipe(recipe_id)
	if (enriched.get("cell_indices", []) as Array).is_empty():
		enriched["cell_indices"] = _showcase_slot_indices_for_recipe(recipe_id)
	var breakdown := _showcase_sale_feedback_breakdown(enriched, term)
	enriched["feedback_breakdown"] = breakdown
	var bonus: Dictionary = term.get("bonus", {}) if term.get("bonus", {}) is Dictionary else {}
	enriched["speed_boost_percent"] = int(round((float(bonus.get("speed_multiplier", 1.0)) - 1.0) * 100.0))
	var context := ShowcaseRuleService.sale_context(bonus)
	var related_recipe_ids: Array = context.get("related_recipe_ids", [])
	var conflict_recipe_ids: Array = context.get("conflict_recipe_ids", [])
	enriched["groups"] = (context.get("groups", []) as Array).duplicate(true)
	enriched["related_recipe_ids"] = related_recipe_ids.duplicate()
	enriched["conflict_recipe_ids"] = conflict_recipe_ids.duplicate()
	enriched["related_slots"] = _showcase_anchor_slots_for_recipe_ids(related_recipe_ids)
	enriched["conflict_slots"] = _showcase_anchor_slots_for_recipe_ids(conflict_recipe_ids)
	enriched["positive_adjacency"] = not related_recipe_ids.is_empty()
	var market_total := int(breakdown.get("base_income", 0)) + int(breakdown.get("market_income", 0))
	enriched["attribution"] = ShowcaseRuleService.sale_attribution(
		market_total,
		int(breakdown.get("total_coins", 0)),
		bonus
	)
	var groups: Array = enriched.get("groups", [])
	if not groups.is_empty() and groups[0] is Dictionary:
		var first_group: Dictionary = groups[0]
		enriched["combo_key"] = String(first_group.get("id", ""))
		enriched["combo_label"] = String(first_group.get("label", "套装连售"))
	return enriched


func _play_showcase_sale_progress_completion(event: Dictionary) -> void:
	if bool(event.get("bonus_only", false)) or not is_instance_valid(showcase_grid):
		return
	var recipe_id := String(event.get("recipe_id", ""))
	var cell_indices_value: Variant = event.get("cell_indices", null)
	if recipe_id.is_empty() or not cell_indices_value is Array:
		return
	var cell_indices: Array = cell_indices_value
	var feedback_buttons: Array[Button] = []
	for slot_index_value: Variant in cell_indices:
		var slot_index := int(slot_index_value)
		if slot_index < 0 or slot_index >= showcase_grid.get_child_count():
			continue
		var slot_node := showcase_grid.get_child(slot_index)
		if not slot_node is Button or slot_node.is_queued_for_deletion():
			continue
		var button := slot_node as Button
		if String(button.get_meta("recipe_id", "")) != recipe_id:
			continue
		feedback_buttons.append(button)
	if feedback_buttons.is_empty():
		return
	var group := showcase_sale_progress_groups.get(recipe_id) as Control
	if is_instance_valid(group) and group.has_method("play_sale_complete_feedback"):
		group.call("play_sale_complete_feedback")
	for button in feedback_buttons:
		if button.has_method("play_sale_complete_feedback"):
			button.call("play_sale_complete_feedback")


func _build_showcase_round_summary(sale_events: Array, sale_terms: Dictionary, item_states: Dictionary) -> Dictionary:
	var products := {}
	var total_coins := 0
	var base_income := 0
	var sold_count := 0
	var triggered_reasons: Array[String] = []
	for event_value in sale_events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var recipe_id := String(event.get("recipe_id", ""))
		var earned_coins := maxi(0, int(event.get("earned_coins", 0)))
		var quantity := maxi(0, int(event.get("quantity", 0)))
		var term: Dictionary = sale_terms.get(recipe_id, {})
		var event_base := maxi(0, int(term.get("base_price", event.get("unit_price", 0))))
		if String(event.get("batch", "fresh")) == "carried":
			event_base = int(floor(float(event_base) * 0.8))
		total_coins += earned_coins
		sold_count += quantity
		base_income += event_base
		var product: Dictionary = products.get(recipe_id, {
			"recipe_id": recipe_id,
			"recipe_name": _recipe_name(recipe_id),
			"sold_count": 0,
			"fresh_sale_count": 0,
			"carried_sale_count": 0,
			"earned_coins": 0,
			"refill_count": 0,
			"chain_count": 0,
			"role": "—",
			"next_sale_gap_ms": -1,
			"triggered_rules": []
		})
		product["sold_count"] = int(product.get("sold_count", 0)) + quantity
		var batch := String(event.get("batch", "fresh"))
		product["fresh_sale_count"] = int(product.get("fresh_sale_count", 0)) + (quantity if batch == "fresh" else 0)
		product["carried_sale_count"] = int(product.get("carried_sale_count", 0)) + (quantity if batch == "carried" else 0)
		product["earned_coins"] = int(product.get("earned_coins", 0)) + earned_coins
		if not String(event.get("chain_source", "")).is_empty():
			product["chain_count"] = int(product.get("chain_count", 0)) + 1
		products[recipe_id] = product
		for reason_value in event.get("reasons", []):
			var reason := String((reason_value as Dictionary).get("text", "")) if reason_value is Dictionary else String(reason_value)
			if not reason.is_empty() and not triggered_reasons.has(reason):
				triggered_reasons.append(reason)
			var product_rules: Array = product.get("triggered_rules", [])
			if not reason.is_empty() and not product_rules.has(reason):
				product_rules.append(reason)
			product["triggered_rules"] = product_rules
		products[recipe_id] = product
	for refill_value in state.active_business_round.get("refill_events", []):
		if not refill_value is Dictionary:
			continue
		var refill: Dictionary = refill_value
		var refill_recipe_id := String(refill.get("recipe_id", ""))
		if refill_recipe_id.is_empty():
			continue
		var refill_product: Dictionary = products.get(refill_recipe_id, {
			"recipe_id": refill_recipe_id,
			"recipe_name": _recipe_name(refill_recipe_id),
			"sold_count": 0,
			"fresh_sale_count": 0,
			"carried_sale_count": 0,
			"earned_coins": 0,
			"refill_count": 0,
			"chain_count": 0,
			"role": "—",
			"next_sale_gap_ms": -1,
			"triggered_rules": []
		})
		refill_product["refill_count"] = int(refill_product.get("refill_count", 0)) + maxi(0, int(refill.get("amount", 0)))
		products[refill_recipe_id] = refill_product
	var role_snapshot: Dictionary = state.active_business_round.get("role_snapshot", {})
	for recipe_id_value in products.keys():
		var recipe_id := String(recipe_id_value)
		var product: Dictionary = products.get(recipe_id, {})
		var role_data: Dictionary = role_snapshot.get(recipe_id, {})
		product["role"] = String(role_data.get("role", "—"))
		var role_reason := String(role_data.get("role_reason", ""))
		if not role_reason.is_empty():
			var product_rules: Array = product.get("triggered_rules", [])
			if not product_rules.has(role_reason):
				product_rules.append(role_reason)
			product["triggered_rules"] = product_rules
		var item: Dictionary = item_states.get(recipe_id, {})
		if int(item.get("fresh_stock", 0)) + int(item.get("carried_stock", 0)) > 0:
			product["next_sale_gap_ms"] = maxi(0, int(item.get("duration_ms", 0)) - int(item.get("cycle_elapsed_ms", 0)))
		products[recipe_id] = product
	var growth_flags := ShowcaseRoundReportService.growth_round_flags(sale_events)
	for recipe_id_value in products.keys():
		var recipe_id := String(recipe_id_value)
		var product: Dictionary = products.get(recipe_id_value, {})
		var flags: Dictionary = growth_flags.get(recipe_id, {})
		var growth_complete := int(state.get_recipe_growth(recipe_id).get("mastery_level", 0)) >= RecipeGrowthService.MASTERY_SIGNATURE
		product["growth_effective_round"] = not growth_complete and bool(flags.get("growth_effective_round", false))
		product["growth_synergy_round"] = not growth_complete and bool(flags.get("growth_synergy_round", false))
		products[recipe_id_value] = product
	var top_recipe_id := ""
	var top_contribution := -1
	for recipe_id_value in products.keys():
		var recipe_id := String(recipe_id_value)
		var contribution := int((products.get(recipe_id_value, {}) as Dictionary).get("earned_coins", 0))
		if contribution > top_contribution or contribution == top_contribution and recipe_id < top_recipe_id:
			top_recipe_id = recipe_id
			top_contribution = contribution
	var nearest_gap_ms := -1
	for item_value in item_states.values():
		if not item_value is Dictionary:
			continue
		var item: Dictionary = item_value
		if int(item.get("fresh_stock", 0)) + int(item.get("carried_stock", 0)) <= 0:
			continue
		var gap_ms := maxi(0, int(item.get("duration_ms", 0)) - int(item.get("cycle_elapsed_ms", 0)))
		if nearest_gap_ms < 0 or gap_ms < nearest_gap_ms:
			nearest_gap_ms = gap_ms
	return {
		"sold_count": sold_count,
		"total_coins": total_coins,
		"base_income": base_income,
		"layout_extra_income": total_coins - base_income,
		"products": products,
		"top_recipe_id": top_recipe_id,
		"top_contribution_coins": maxi(0, top_contribution),
		"triggered_reasons": triggered_reasons,
		"next_sale_gap_ms": nearest_gap_ms
	}


func _present_showcase_round_settlement() -> void:
	if state == null or state.pending_showcase_settlement.is_empty() or not is_instance_valid(showcase_round_settlement_dialog):
		return
	var recipe_names := {}
	for recipe_id_value in state.display_items.keys():
		var recipe_id := String(recipe_id_value)
		recipe_names[recipe_id] = _recipe_name(recipe_id)
	showcase_round_settlement_dialog.call("show_settlement", state.pending_showcase_settlement, recipe_names)


func _accept_showcase_business_challenge_index(challenge_index: int) -> bool:
	var choices := _showcase_contract_choices()
	if challenge_index < 0 or challenge_index >= choices.size():
		_set_status("当前没有可选择的经营合同。")
		return false
	return _accept_showcase_business_challenge(String(choices[challenge_index].get("task_id", "")))


func _accept_showcase_business_challenge(challenge_id: String) -> bool:
	if state == null:
		return false
	var snapshot := {}
	for challenge_value in _showcase_contract_choices():
		if String((challenge_value as Dictionary).get("task_id", "")) == challenge_id:
			snapshot = (challenge_value as Dictionary).duplicate(true)
			break
	if snapshot.is_empty():
		_set_status("该特殊挑战尚未解锁。")
		return false
	if state.is_task_completed(challenge_id) and not state.is_task_reward_claimed(challenge_id):
		_set_status("请先领取该合同上一轮的任务奖励，再次挑战。")
		return false
	if not state.accept_showcase_challenge(snapshot):
		_set_status("无法接受挑战：请确认当前处于调整阶段且金币足够支付保证金。")
		return false
	_save_game()
	_refresh_showcase_round_controls()
	if global_popup_mode == "storefront_manage":
		_refresh_storefront_manage_sections()
	_set_status("已接受特殊挑战：%s（%d 秒）" % [String(snapshot.get("title", challenge_id)), int(snapshot.get("duration_seconds", 30))])
	return true


func _showcase_challenge_unlock_context() -> Dictionary:
	var recipe_ids: Array[String] = []
	var tags: Array[String] = []
	var recipes := catalog.get_recipes()
	for recipe_id in _unlocked_recipe_ids():
		recipe_ids.append(recipe_id)
		for tag_value in (recipes.get(recipe_id, {}) as Dictionary).get("tags", []):
			var tag := String(tag_value)
			if not tags.has(tag):
				tags.append(tag)
	recipe_ids.sort()
	tags.sort()
	return {"unlocked_recipe_ids": recipe_ids, "unlocked_tags": tags}


func _showcase_tag_snapshot(display_items: Dictionary) -> Dictionary:
	var result := {}
	var recipes := catalog.get_recipes()
	for recipe_id_value in display_items.keys():
		var recipe_id := String(recipe_id_value)
		var recipe: Dictionary = recipes.get(recipe_id, {})
		var tags: Array = []
		for tag_value in recipe.get("tags", []):
			var tag := String(tag_value)
			if not tag.is_empty() and not tags.has(tag):
				tags.append(tag)
		result[recipe_id] = tags
	return result


func _confirm_showcase_round_settlement(decisions: Dictionary) -> bool:
	if state == null or state.pending_showcase_settlement.is_empty():
		return false
	var quote: Dictionary = state.pending_showcase_settlement.duplicate(true)
	var item_states: Dictionary = quote.get("item_states", state.active_business_round.get("item_states", {}))
	var settlement_result := ShowcaseFreshnessService.apply_decisions(
		item_states,
		quote,
		decisions,
		state.applied_showcase_settlement_ids
	)
	var round_report := ShowcaseRoundReportService.build_report(state.active_business_round, settlement_result)
	var challenge_result := {}
	if String(state.active_business_round.get("kind", "standard")) == "challenge" and not state.pending_showcase_challenge.is_empty():
		challenge_result = ShowcaseChallengeService.evaluate_business_challenge(state.pending_showcase_challenge, round_report)
		round_report["challenge_result"] = challenge_result.duplicate(true)
	settlement_result["round_report"] = round_report
	if not bool(settlement_result.get("ok", false)) or not state.apply_showcase_round_settlement(settlement_result):
		_set_status("结算未完成，请为每件剩余商品选择处理方式。")
		return false
	if bool(round_report.get("is_complete", false)):
		state.record_task_event("business_round_completed", round_report)
	var tutorial_reached_final_dialogue := TutorialProgress.on_business_round_settled(state, round_report)
	if not challenge_result.is_empty() and bool(challenge_result.get("valid", true)):
		state.apply_showcase_challenge_result(challenge_result)
	if not challenge_result.is_empty() and is_instance_valid(showcase_round_settlement_dialog):
		showcase_round_settlement_dialog.call_deferred("show_rating_result", challenge_result)
	state.active_business_round = BusinessRoundService.complete_settlement(state.active_business_round)
	state.business_round_id = int(state.active_business_round.get("round_id", state.business_round_id + 1))
	showcase_round_delta_carry_ms = 0.0
	_save_game()
	_refresh_showcase_round_controls()
	_refresh_storefront_showcase()
	_refresh_current_page()
	if tutorial_reached_final_dialogue:
		_set_status("第一轮真实经营已完成，听听外婆最后的叮嘱吧。")
		call_deferred("_refresh_tutorial_guide")
	else:
		_set_status("本轮营业已结算，可以继续调整布局与补货。")
	return true


func _refill_showcase_round_item(recipe_id: String, amount: int = 1) -> bool:
	if state == null or amount <= 0 or String(state.active_business_round.get("phase", "")) != "running":
		return false
	if not state.has_product(recipe_id, amount):
		_set_status("补货失败：成品库存不足。")
		return false
	var refill_result := ShowcaseRoundSaleService.refill_item(
		state.active_business_round.get("item_states", {}),
		recipe_id,
		amount,
		int(state.active_business_round.get("elapsed_ms", 0))
	)
	var accepted_amount := int(refill_result.get("accepted_amount", 0))
	if not bool(refill_result.get("ok", false)) or accepted_amount <= 0:
		_set_status("补货失败：无法更新营业库存。")
		return false
	if not state.remove_product(recipe_id, accepted_amount):
		return false
	state.active_business_round["item_states"] = (refill_result.get("item_states", {}) as Dictionary).duplicate(true)
	var refill_events: Array = state.active_business_round.get("refill_events", [])
	refill_events.append((refill_result.get("refill_event", {}) as Dictionary).duplicate(true))
	state.active_business_round["refill_events"] = refill_events
	TutorialProgress.on_guide_product_displayed(state, recipe_id)
	_save_game()
	_refresh_showcase_round_controls()
	_refresh_showcase_after_live_stock_change(recipe_id, "补货 +%d" % accepted_amount)
	call_deferred("_refresh_tutorial_guide")
	_set_status("营业中补货：%s +%d" % [_recipe_name(recipe_id), accepted_amount])
	return true


func _list_showcase_round_item(recipe_id: String, cells: Array[Vector2i], variant_id: String, base_sale_seconds: int, amount: int = 1) -> bool:
	if state == null or amount <= 0 or String(state.active_business_round.get("phase", "")) != "running":
		return false
	if not state.has_method("list_display_item_during_round") \
			or not state.list_display_item_during_round(recipe_id, cells, amount, variant_id, base_sale_seconds):
		_set_status("上新失败：成品库存不足或目标区域不可用。")
		return false
	_refresh_showcase_layout_projection()
	if not _apply_showcase_live_layout_change(recipe_id, cells, variant_id, amount):
		_clear_showcase_slots_for_recipe(recipe_id)
		state.display_items.erase(recipe_id)
		state.add_product(recipe_id, amount)
		_refresh_showcase_layout_projection()
		_set_status("上新失败：无法建立本轮销售参数。")
		return false
	_save_game()
	_refresh_showcase_round_controls()
	_refresh_showcase_after_live_stock_change(recipe_id, "上新成功")
	_set_status("营业中上新：%s 已立即加入本轮售卖，布局加成已重算。" % _recipe_name(recipe_id))
	return true


func _replace_showcase_round_item(
	replaced_recipe_id: String,
	recipe_id: String,
	cells: Array[Vector2i],
	variant_id: String,
	base_sale_seconds: int,
	amount: int = 1
) -> bool:
	if state == null \
			or amount <= 0 \
			or String(state.active_business_round.get("phase", "")) != "running" \
			or not state.has_method("replace_sold_out_display_item_during_round"):
		return false
	var previous_display_items: Dictionary = state.display_items.duplicate(true)
	var previous_product_inventory: Dictionary = state.product_inventory.duplicate(true)
	var previous_round: Dictionary = state.active_business_round.duplicate(true)
	var previous_slots: Array = state.display_slots.duplicate(true)
	if not state.replace_sold_out_display_item_during_round(
		replaced_recipe_id,
		recipe_id,
		cells,
		amount,
		variant_id,
		base_sale_seconds
	):
		_set_status("替换失败：成品库存不足或目标区域不可用。")
		return false
	_clear_showcase_slots_for_recipe(replaced_recipe_id)
	_refresh_showcase_layout_projection()
	var event := _showcase_live_layout_event("replace", recipe_id, cells, variant_id, amount)
	event["replaced_recipe_id"] = replaced_recipe_id
	if not _rebuild_showcase_live_layout(event):
		state.display_items = previous_display_items
		state.product_inventory = previous_product_inventory
		state.active_business_round = previous_round
		state.display_slots = previous_slots
		_set_status("替换失败：无法建立本轮销售参数。")
		return false
	_clear_showcase_drag_preview()
	state.add_log("display_item_live_replaced:%s:%s:%d" % [replaced_recipe_id, recipe_id, amount])
	state.record_task_event("display_product", {"recipe_id": recipe_id, "quantity": amount})
	_save_game()
	_refresh_showcase_round_controls()
	_refresh_showcase_after_live_stock_change(recipe_id, "替换上架")
	_set_status("营业中替换：%s → %s" % [_recipe_name(replaced_recipe_id), _recipe_name(recipe_id)])
	return true


func _on_showcase_product_drag_ended(recipe_id: String) -> void:
	_log_showcase_unlist_drag(
		"end_unlist",
		recipe_id,
		"drag_successful=%s" % str(get_viewport().gui_is_drag_successful())
	)
	_end_showcase_unlist_drag_status()
	_finish_showcase_product_drag(recipe_id, get_viewport().gui_is_drag_successful(), get_viewport().get_mouse_position())


func _on_showcase_product_drag_cancelled() -> void:
	_log_showcase_unlist_drag("end_without_unlist", showcase_unlist_drag_debug_recipe_id)
	_end_showcase_unlist_drag_status()
	_clear_showcase_drag_preview()


func _on_showcase_product_drag_started(recipe_id: String) -> void:
	var eligible := _can_unlist_showcase_item(recipe_id)
	showcase_unlist_drag_debug_recipe_id = recipe_id
	showcase_unlist_drag_debug_signature = ""
	showcase_unlist_drag_recipe_id = recipe_id if eligible else ""
	_log_showcase_unlist_drag("start", recipe_id, "eligible=%s" % str(eligible))
	_refresh_showcase_unlist_drag_label()


func _end_showcase_unlist_drag_status() -> void:
	showcase_unlist_drag_recipe_id = ""
	showcase_unlist_drag_debug_recipe_id = ""
	showcase_unlist_drag_debug_signature = ""
	if is_instance_valid(showcase_unlist_drag_label):
		showcase_unlist_drag_label.visible = false


func _refresh_showcase_unlist_drag_label() -> void:
	if not is_instance_valid(showcase_unlist_drag_label):
		return
	var viewport := get_viewport()
	var pointer_position := viewport.get_mouse_position() if viewport != null else Vector2.ZERO
	var dragging := viewport != null and viewport.gui_is_dragging()
	var grid_valid := is_instance_valid(showcase_grid)
	var outside_showcase := grid_valid and not _is_pointer_inside_showcase_unlocked_area(pointer_position)
	var eligible := not showcase_unlist_drag_recipe_id.is_empty() \
		and _can_unlist_showcase_item(showcase_unlist_drag_recipe_id)
	var should_show := dragging and outside_showcase and eligible
	showcase_unlist_drag_label.visible = should_show
	if should_show:
		var viewport_rect := viewport.get_visible_rect()
		var target_position := pointer_position + Vector2.ONE * SHOWCASE_UNLIST_DRAG_LABEL_GAP
		if target_position.x + SHOWCASE_UNLIST_DRAG_LABEL_SIZE.x > viewport_rect.end.x - SHOWCASE_UNLIST_DRAG_LABEL_MARGIN:
			target_position.x = pointer_position.x - SHOWCASE_UNLIST_DRAG_LABEL_GAP - SHOWCASE_UNLIST_DRAG_LABEL_SIZE.x
		if target_position.y + SHOWCASE_UNLIST_DRAG_LABEL_SIZE.y > viewport_rect.end.y - SHOWCASE_UNLIST_DRAG_LABEL_MARGIN:
			target_position.y = pointer_position.y - SHOWCASE_UNLIST_DRAG_LABEL_GAP - SHOWCASE_UNLIST_DRAG_LABEL_SIZE.y
		var minimum_position := viewport_rect.position + Vector2.ONE * SHOWCASE_UNLIST_DRAG_LABEL_MARGIN
		var maximum_position := viewport_rect.end - SHOWCASE_UNLIST_DRAG_LABEL_SIZE - Vector2.ONE * SHOWCASE_UNLIST_DRAG_LABEL_MARGIN
		maximum_position.x = maxf(maximum_position.x, minimum_position.x)
		maximum_position.y = maxf(maximum_position.y, minimum_position.y)
		showcase_unlist_drag_label.global_position = Vector2(
			clampf(target_position.x, minimum_position.x, maximum_position.x),
			clampf(target_position.y, minimum_position.y, maximum_position.y)
		)
	if not showcase_unlist_drag_debug_recipe_id.is_empty():
		var signature := "%s|%s|%s|%s|%s" % [
			str(dragging),
			str(outside_showcase),
			str(eligible),
			str(should_show),
			str(showcase_unlist_drag_label.get_global_rect())
		]
		if signature != showcase_unlist_drag_debug_signature:
			showcase_unlist_drag_debug_signature = signature
			_log_showcase_unlist_drag(
				"visibility",
				showcase_unlist_drag_debug_recipe_id,
				"outside_unlocked_cells=%s eligible=%s should_show=%s" % [str(outside_showcase), str(eligible), str(should_show)]
			)


func _log_showcase_unlist_drag(event_name: String, recipe_id: String, details: String = "") -> void:
	var viewport := get_viewport()
	var pointer_position := viewport.get_mouse_position() if viewport != null else Vector2.ZERO
	var dragging := viewport != null and viewport.gui_is_dragging()
	var grid_rect := showcase_grid.get_global_rect() if is_instance_valid(showcase_grid) else Rect2()
	var label_visible := is_instance_valid(showcase_unlist_drag_label) and showcase_unlist_drag_label.visible
	var label_rect := showcase_unlist_drag_label.get_global_rect() if is_instance_valid(showcase_unlist_drag_label) else Rect2()
	var phase := String(state.active_business_round.get("phase", "missing")) if state != null else "missing"
	var stock: int = int(state.get_display_item_stock(recipe_id)) if state != null and not recipe_id.is_empty() else -1
	print(
		"[showcase_unlist_drag] event=%s recipe=%s phase=%s stock=%d dragging=%s pointer=%s grid_rect=%s label_visible=%s label_rect=%s %s" % [
			event_name,
			recipe_id,
			phase,
			stock,
			str(dragging),
			str(pointer_position),
			str(grid_rect),
			str(label_visible),
			str(label_rect),
			details
		]
	)


func _finish_showcase_product_drag(recipe_id: String, drag_succeeded: bool, pointer_global_position: Vector2) -> bool:
	_clear_showcase_drag_preview()
	if drag_succeeded \
			or state == null \
			or not is_instance_valid(showcase_grid) \
			or _is_pointer_inside_showcase_unlocked_area(pointer_global_position) \
			or not _can_unlist_showcase_item(recipe_id):
		return false
	if String(state.active_business_round.get("phase", "adjusting")) == "adjusting":
		return _unlist_adjusting_showcase_item(recipe_id)
	return _unlist_showcase_round_item(recipe_id)


func _can_unlist_showcase_item(recipe_id: String) -> bool:
	if state == null or recipe_id.is_empty() or not state.display_items.has(recipe_id):
		return false
	var phase := String(state.active_business_round.get("phase", "adjusting"))
	if phase == "adjusting":
		return true
	return phase == "running" \
		and state.has_method("is_display_item_sold_out_during_round") \
		and state.is_display_item_sold_out_during_round(recipe_id)


func _is_showcase_item_waiting_for_unlist(recipe_id: String) -> bool:
	return _can_unlist_showcase_item(recipe_id)


func _is_pointer_inside_showcase_unlocked_area(pointer_global_position: Vector2) -> bool:
	if state == null \
			or not state.has_method("get_showcase_unlocked_cells") \
			or not is_instance_valid(showcase_grid):
		return false
	for cell_value in state.get_showcase_unlocked_cells():
		if not (cell_value is Vector2i):
			continue
		var slot_index := _showcase_slot_index_for_cell(cell_value)
		if slot_index < 0 or slot_index >= showcase_grid.get_child_count():
			continue
		var slot_control := showcase_grid.get_child(slot_index) as Control
		if is_instance_valid(slot_control) and slot_control.get_global_rect().has_point(pointer_global_position):
			return true
	return false


func _unlist_adjusting_showcase_item(recipe_id: String) -> bool:
	if state == null \
			or String(state.active_business_round.get("phase", "adjusting")) != "adjusting" \
			or not state.remove_display_item(recipe_id):
		return false
	_clear_showcase_slots_for_recipe(recipe_id)
	_refresh_showcase_layout_projection()
	_save_game()
	if is_instance_valid(inventory_overlay) and inventory_overlay.has_method("refresh_grid"):
		inventory_overlay.call("refresh_grid", self)
	_refresh_storefront_showcase()
	_set_status("已下架商品：%s" % _recipe_name(recipe_id))
	return true


func _unlist_showcase_round_item(recipe_id: String) -> bool:
	if state == null or not state.has_method("unlist_sold_out_display_item_during_round"):
		return false
	var previous_display_items: Dictionary = state.display_items.duplicate(true)
	var previous_round: Dictionary = state.active_business_round.duplicate(true)
	var previous_slots: Array = state.display_slots.duplicate(true)
	var cells: Array[Vector2i] = []
	for cell_value in state.get_display_item_cells(recipe_id):
		if cell_value is Vector2i:
			cells.append(cell_value)
	var variant_id := _display_item_variant_id(recipe_id)
	if not state.unlist_sold_out_display_item_during_round(recipe_id):
		return false
	_clear_showcase_slots_for_recipe(recipe_id)
	_refresh_showcase_layout_projection()
	if not _rebuild_showcase_live_layout(_showcase_live_layout_event("unlist", recipe_id, cells, variant_id, 0)):
		state.display_items = previous_display_items
		state.active_business_round = previous_round
		state.display_slots = previous_slots
		return false
	state.add_log("display_item_live_unlisted:%s" % recipe_id)
	_save_game()
	_refresh_showcase_round_controls()
	if is_instance_valid(inventory_overlay) and inventory_overlay.has_method("refresh_grid"):
		inventory_overlay.call("refresh_grid", self)
	_refresh_storefront_showcase()
	_set_status("营业中下架：%s" % _recipe_name(recipe_id))
	return true


func _apply_showcase_live_layout_change(recipe_id: String, cells: Array[Vector2i], variant_id: String, amount: int = 1) -> bool:
	var event := _showcase_live_layout_event("list", recipe_id, cells, variant_id, amount)
	if not _rebuild_showcase_live_layout(event):
		return false
	return (state.active_business_round.get("item_states", {}) as Dictionary).has(recipe_id)


func _showcase_live_layout_event(
	kind: String,
	recipe_id: String,
	cells: Array[Vector2i],
	variant_id: String,
	amount: int
) -> Dictionary:
	var serialized_cells: Array = []
	for cell in cells:
		serialized_cells.append([cell.x, cell.y])
	return {
		"kind": kind,
		"recipe_id": recipe_id,
		"variant_id": variant_id,
		"cells": serialized_cells,
		"elapsed_ms": maxi(0, int(state.active_business_round.get("elapsed_ms", 0))),
		"amount": maxi(0, amount)
	}


func _rebuild_showcase_live_layout(event: Dictionary) -> bool:
	if state == null or String(state.active_business_round.get("phase", "")) != "running":
		return false
	var round_state: Dictionary = state.active_business_round.duplicate(true)
	var sale_terms := _showcase_round_terms_for_environment(round_state.get("environment", {}))
	var rebuilt_states := ShowcaseRoundSaleService.build_item_states(state.display_items, sale_terms)
	var merged_states := ShowcaseRoundSaleService.merge_live_layout_states(
		round_state.get("item_states", {}),
		rebuilt_states
	)
	var event_kind := String(event.get("kind", "list"))
	var event_recipe_id := String(event.get("recipe_id", ""))
	if event_kind == "unlist":
		if merged_states.has(event_recipe_id):
			return false
	elif event_recipe_id.is_empty() or not merged_states.has(event_recipe_id):
		return false
	round_state["sale_terms"] = sale_terms.duplicate(true)
	round_state["item_states"] = merged_states.duplicate(true)
	round_state["role_snapshot"] = ShowcaseRoleService.build_configured_snapshot(
		state.display_items,
		sale_terms,
		catalog.get_showcase_round_rules().get("role_rules", {})
	)
	round_state["tag_snapshot"] = _showcase_tag_snapshot(state.display_items)
	round_state["live_layout_changed"] = true
	var listing_events: Array = round_state.get("live_listing_events", [])
	listing_events.append(event.duplicate(true))
	round_state["live_listing_events"] = listing_events
	state.active_business_round = round_state
	return true


func _refresh_showcase_after_live_stock_change(recipe_id: String, badge_text: String) -> void:
	if is_instance_valid(inventory_overlay) and inventory_overlay.has_method("refresh_grid"):
		inventory_overlay.call("refresh_grid", self)
	showcase_stock_feedback_sequence += 1
	var feedback_token := showcase_stock_feedback_sequence
	showcase_stock_feedback_badges[recipe_id] = {
		"text": badge_text,
		"token": feedback_token
	}
	_refresh_storefront_showcase()
	call_deferred("_play_showcase_stock_change_feedback", recipe_id, badge_text, feedback_token)


func _play_showcase_stock_change_feedback(recipe_id: String, badge_text: String, feedback_token: int) -> void:
	var feedback_entry: Dictionary = showcase_stock_feedback_badges.get(recipe_id, {})
	if state == null \
			or not state.display_items.has(recipe_id) \
			or int(feedback_entry.get("token", -1)) != feedback_token:
		return
	var slot_indices := _showcase_slot_indices_for_recipe(recipe_id)
	_spawn_showcase_product_pulse(slot_indices, Color(0.26, 0.92, 0.38), "restock", 0.55)
	get_tree().create_timer(1.2).timeout.connect(
		_restore_showcase_stock_badge.bind(recipe_id, feedback_token),
		CONNECT_ONE_SHOT
	)
	var anchor_slot := _display_anchor_slot_index_for_recipe(recipe_id)
	if anchor_slot < 0 or anchor_slot >= showcase_grid.get_child_count():
		return
	var button := showcase_grid.get_child(anchor_slot) as Button
	if button == null or not button.has_method("set_status_badge"):
		return
	button.call("set_status_badge", badge_text)


func _restore_showcase_stock_badge(recipe_id: String, feedback_token: int) -> void:
	var feedback_entry: Dictionary = showcase_stock_feedback_badges.get(recipe_id, {})
	if int(feedback_entry.get("token", -1)) != feedback_token:
		return
	showcase_stock_feedback_badges.erase(recipe_id)
	var anchor_slot := _display_anchor_slot_index_for_recipe(recipe_id)
	if not is_instance_valid(showcase_grid) or anchor_slot < 0 or anchor_slot >= showcase_grid.get_child_count():
		return
	var button := showcase_grid.get_child(anchor_slot) as Button
	if button == null or not button.has_method("set_status_badge"):
		return
	button.call(
		"set_status_badge",
		_showcase_status_badge_text(_showcase_slot(anchor_slot), int(Time.get_unix_time_from_system()))
	)


func _refresh_showcase_round_controls() -> void:
	if not is_instance_valid(showcase_start_round_button):
		return
	var round_state: Dictionary = state.active_business_round if state != null else {}
	if state != null and (round_state.is_empty() or String(round_state.get("phase", "adjusting")) == "adjusting"):
		_ensure_showcase_round_environment()
		round_state = state.active_business_round
	var phase := String(round_state.get("phase", "adjusting"))
	if phase.is_empty():
		phase = "adjusting"
	var state_text := "调整中"
	match phase:
		"running":
			state_text = "营业中"
		"settlement":
			state_text = "待结算"
	showcase_round_state_label.text = state_text
	var environment: Dictionary = round_state.get("environment", {})
	var hotspot: Dictionary = round_state.get("hotspot", {})
	var environment_status := "%s｜售价 %+d%%｜售速 %+d%%｜热点：%s" % [
		String(environment.get("label", "普通街区")),
		int(round(float(environment.get("total_price_pct", 0.0)))),
		int(round(float(environment.get("total_speed_pct", 0.0)))),
		String(hotspot.get("label", "生成中"))
	]
	var weather_value: Variant = environment.get("weather", {})
	var weather: Dictionary = weather_value if weather_value is Dictionary else {}
	var weather_id := String(weather.get("id", environment.get("id", "")))
	showcase_weather_forecast_icon.texture = _showcase_weather_icon_texture(weather_id)
	showcase_weather_forecast_icon.tooltip_text = environment_status
	var remaining_ms := int(round_state.get("remaining_ms", 30000))
	var duration_ms := maxi(1, int(round_state.get("duration_ms", 30000)))
	var clamped_remaining_ms := clampi(remaining_ms, 0, duration_ms)
	showcase_round_countdown_icon.call("set_remaining_seconds", float(clamped_remaining_ms) / 1000.0)
	showcase_round_countdown_hand.rotation = TAU * (1.0 - float(clamped_remaining_ms) / float(duration_ms))
	showcase_heat_bar.value = clampi(int(round_state.get("heat", 0)), 0, 100)
	var rulebook_unlocked: bool = state != null and state.is_core_feature_unlocked(CoreFeatureUnlockService.RULEBOOK)
	showcase_rulebook_button.set_meta("access_locked", not rulebook_unlocked)
	showcase_rulebook_button.text = "构筑规则" if rulebook_unlocked else "🔒 规则"
	showcase_rulebook_button.tooltip_text = "查看构筑规则" if rulebook_unlocked else state.core_feature_locked_reason(CoreFeatureUnlockService.RULEBOOK)
	var business_unlocked: bool = state != null and state.is_core_feature_unlocked(CoreFeatureUnlockService.BUSINESS)
	showcase_start_round_button.set_meta("access_locked", not business_unlocked)
	if phase == "settlement":
		var has_pending_settlement: bool = state != null and not state.pending_showcase_settlement.is_empty()
		showcase_start_round_button.disabled = not has_pending_settlement
		showcase_start_round_button.text = "待结算" if has_pending_settlement else "结算异常"
		showcase_start_round_button.tooltip_text = "重新打开本轮营业结算" if has_pending_settlement else "本轮结算数据缺失，请重新加载存档后重试。"
		return
	showcase_start_round_button.disabled = showcase_expansion_active or phase != "adjusting" or state == null or (business_unlocked and state.display_items.is_empty()) or not state.pending_showcase_settlement.is_empty()
	if not business_unlocked and phase == "adjusting":
		showcase_start_round_button.disabled = false
		showcase_start_round_button.text = "🔒 营业"
		showcase_start_round_button.tooltip_text = state.core_feature_locked_reason(CoreFeatureUnlockService.BUSINESS)
	else:
		showcase_start_round_button.text = "营业中" if phase == "running" else ("待结算" if phase == "settlement" else "开始营业")
		showcase_start_round_button.tooltip_text = ""


func _showcase_weather_icon_texture(weather_id: String) -> Texture2D:
	match weather_id:
		"clear_day":
			return SHOWCASE_WEATHER_CLEAR_ICON
		"light_rain":
			return SHOWCASE_WEATHER_RAIN_ICON
		"warm_day":
			return SHOWCASE_WEATHER_WARM_ICON
		_:
			return SHOWCASE_WEATHER_GENERIC_ICON


func _ensure_showcase_round_environment() -> Dictionary:
	if state == null:
		return {}
	if not state.pending_showcase_challenge.is_empty():
		var challenge_environment: Dictionary = state.pending_showcase_challenge.get("environment", {})
		if not challenge_environment.is_empty():
			return challenge_environment.duplicate(true)
	var current: Dictionary = state.active_business_round
	if int(current.get("round_id", 0)) == state.business_round_id and current.get("environment", {}) is Dictionary and not (current.get("environment", {}) as Dictionary).is_empty():
		return (current.get("environment", {}) as Dictionary).duplicate(true)
	var unlocked_tags: Array = []
	var recipes: Dictionary = catalog.get_recipes()
	for recipe_id_value in state.display_items.keys():
		var recipe: Dictionary = recipes.get(recipe_id_value, {})
		for tag_value in recipe.get("tags", []):
			if not unlocked_tags.has(tag_value):
				unlocked_tags.append(tag_value)
	var environment := RoundEnvironmentService.generate(state.showcase_seed, state.business_round_id, unlocked_tags, catalog.get_showcase_round_rules())
	var round_state := BusinessRoundService.create_standard(state.business_round_id)
	round_state["environment"] = environment.duplicate(true)
	state.active_business_round = round_state
	return environment


func _ensure_showcase_hotspot() -> Dictionary:
	if state == null: return {}
	var current: Dictionary = state.active_business_round
	if int(current.get("round_id", 0)) == state.business_round_id and current.get("hotspot", {}) is Dictionary and not (current.get("hotspot", {}) as Dictionary).is_empty():
		return (current.get("hotspot", {}) as Dictionary).duplicate(true)
	var hotspot := ShowcaseHotspotService.generate_for_cells(state.showcase_seed, state.business_round_id, state.get_showcase_unlocked_cells())
	current["hotspot"] = hotspot.duplicate(true)
	state.active_business_round = current
	return hotspot


func _is_showcase_round_layout_locked() -> bool:
	if state == null:
		return false
	return String(state.active_business_round.get("phase", "adjusting")) in ["running", "settlement"]


func _showcase_round_item_view(recipe_id: String) -> Dictionary:
	if state == null or recipe_id.is_empty():
		return {}
	var phase := String(state.active_business_round.get("phase", "adjusting"))
	if phase == "running" or phase == "settlement":
		var round_item: Dictionary = (state.active_business_round.get("item_states", {}) as Dictionary).get(recipe_id, {})
		if round_item.is_empty():
			return {"phase": phase, "quantity": 0, "batch_label": "待补货", "remaining_ms": 0, "progress": 0.0}
		var carried_stock := maxi(0, int(round_item.get("carried_stock", 0)))
		var fresh_stock := maxi(0, int(round_item.get("fresh_stock", 0)))
		var quantity := carried_stock + fresh_stock
		var duration_ms := maxi(1, int(round_item.get("duration_ms", 1)))
		var cycle_elapsed_ms := clampi(int(round_item.get("cycle_elapsed_ms", 0)), 0, duration_ms)
		return {
			"phase": phase,
			"quantity": quantity,
			"carried_stock": carried_stock,
			"fresh_stock": fresh_stock,
			"batch_label": "8折留售" if carried_stock > 0 else ("新鲜" if fresh_stock > 0 else "待补货"),
			"remaining_ms": 0 if quantity <= 0 else duration_ms - cycle_elapsed_ms,
			"progress": 0.0 if quantity <= 0 else float(cycle_elapsed_ms) / float(duration_ms),
			"waiting_for_refill": quantity <= 0
		}
	var display_item: Dictionary = state.display_items.get(recipe_id, {})
	var carried_stock := maxi(0, int(display_item.get("carried_stock", 0)))
	var fresh_stock := maxi(0, int(display_item.get("fresh_stock", display_item.get("stock", 0))))
	return {
		"phase": "adjusting",
		"quantity": carried_stock + fresh_stock,
		"carried_stock": carried_stock,
		"fresh_stock": fresh_stock,
		"batch_label": "8折留售" if carried_stock > 0 else ("新鲜" if fresh_stock > 0 else "待补货"),
		"remaining_ms": 0,
		"progress": 0.0,
		"waiting_for_refill": carried_stock + fresh_stock <= 0
	}


func _showcase_round_sale_terms() -> Dictionary:
	var recipes: Dictionary = catalog.get_recipes()
	var display_config: Dictionary = catalog.get_recipe_display_config().get("recipes", {})
	var round_rules: Dictionary = catalog.get_showcase_round_rules()
	var shape_templates: Dictionary = round_rules.get("shape_templates", {})
	var rule_result: Dictionary = ShowcaseRuleService.calculate(state, recipes, catalog.get_display_rules())
	var rule_items: Dictionary = rule_result.get("items", {})
	var result := {}
	for recipe_id_value in state.display_items.keys():
		var recipe_id := String(recipe_id_value)
		var recipe: Dictionary = recipes.get(recipe_id, {})
		if recipe.is_empty():
			continue
		var recipe_display: Dictionary = display_config.get(recipe_id, {})
		var shape_category := String(recipe_display.get("shape_category", "横盘款"))
		var template: Dictionary = shape_templates.get(shape_category, {})
		var base_seconds := maxi(1, int(template.get("base_sale_seconds", 10)))
		var bonus: Dictionary = rule_items.get(recipe_id, {})
		var speed_multiplier := maxf(0.2, float(bonus.get("speed_multiplier", 1.0)))
		var duration_seconds := maxi(1, int(round(float(base_seconds) / speed_multiplier)))
		var base_price := maxi(0, int(recipe.get("price", 0)))
		result[recipe_id] = {
			"base_price": base_price,
			"base_duration_seconds": base_seconds,
			"unit_price": maxi(0, int(round(float(base_price) * float(bonus.get("price_multiplier", 1.0))))),
			"duration_seconds": duration_seconds,
			"reputation_gain": maxi(0, 1 + int(bonus.get("reputation_delta", 0))),
			"tags": (recipe.get("tags", []) as Array).duplicate(),
			"variant_id": String((state.display_items.get(recipe_id, {}) as Dictionary).get("variant_id", "standard")),
			"growth_level": int(state.get_recipe_growth(recipe_id).get("mastery_level", 0)),
			"role": String(template.get("role", "lure")),
			"bonus": bonus.duplicate(true)
		}
	return result


func _showcase_round_terms_for_environment(environment: Dictionary, hotspot: Dictionary = {}) -> Dictionary:
	var source_terms := _showcase_round_sale_terms()
	var market_source_terms := source_terms.duplicate(true)
	for recipe_id_value in market_source_terms.keys():
		var market_source: Dictionary = market_source_terms.get(recipe_id_value, {})
		market_source["unit_price"] = int(market_source.get("base_price", market_source.get("unit_price", 0)))
		market_source["duration_seconds"] = int(market_source.get("base_duration_seconds", market_source.get("duration_seconds", 1)))
		market_source_terms[recipe_id_value] = market_source
	var market_terms := RoundEnvironmentService.apply_to_terms(market_source_terms, environment)
	var sale_terms := RoundEnvironmentService.apply_to_terms(source_terms, environment)
	for recipe_id_value in sale_terms.keys():
		var term: Dictionary = sale_terms.get(recipe_id_value, {})
		var source_term: Dictionary = source_terms.get(recipe_id_value, {})
		var market_term: Dictionary = market_terms.get(recipe_id_value, {})
		term["base_unit_price"] = int(source_term.get("base_price", 0))
		term["base_duration_seconds"] = int(source_term.get("base_duration_seconds", source_term.get("duration_seconds", 1)))
		term["market_unit_price"] = int(market_term.get("unit_price", term.get("unit_price", 0)))
		term["market_duration_seconds"] = int(market_term.get("duration_seconds", term.get("duration_seconds", 1)))
		sale_terms[recipe_id_value] = term
	var active_hotspot := hotspot if not hotspot.is_empty() else _ensure_showcase_hotspot()
	return ShowcaseHotspotService.apply_to_terms(sale_terms, state.display_items, active_hotspot)


func _ensure_showcase_batch_fields() -> void:
	if state == null:
		return
	for recipe_id_value in state.display_items.keys():
		var item: Dictionary = state.display_items.get(recipe_id_value, {})
		var fresh_stock := maxi(0, int(item.get("fresh_stock", item.get("stock", 0))))
		var carried_stock := maxi(0, int(item.get("carried_stock", 0)))
		item["fresh_stock"] = fresh_stock
		item["carried_stock"] = carried_stock
		item["stock"] = fresh_stock + carried_stock
		state.display_items[recipe_id_value] = item


func _showcase_sale_seconds_for_bonus(base_seconds: int, speed_multiplier: float) -> int:
	var safe_base := maxi(1, base_seconds)
	var safe_multiplier := maxf(0.2, speed_multiplier)
	return clampi(int(round(float(safe_base) / safe_multiplier)), 3, 90)


func _showcase_sale_seconds_for_recipe(recipe_id: String, base_seconds: int = -1) -> int:
	var raw_seconds := base_seconds
	if raw_seconds <= 0:
		raw_seconds = _random_showcase_sale_seconds()
	var bonus := _showcase_bonus_for_recipe(recipe_id)
	return _showcase_sale_seconds_for_bonus(raw_seconds, float(bonus.get("speed_multiplier", 1.0)))


func _refill_showcase_item(recipe_id: String, amount: int = 1) -> bool:
	if state == null or recipe_id.is_empty() or amount <= 0 or not state.display_items.has(recipe_id):
		return false
	var item: Dictionary = state.display_items[recipe_id]
	var base_seconds := maxi(1, int(item.get("base_sale_seconds", SHOWCASE_SALE_MIN_SECONDS)))
	return state.add_display_item_stock(recipe_id, amount, base_seconds)


func _refresh_showcase_layout_projection() -> void:
	if state == null:
		return
	_invalidate_showcase_bonus_cache()
	_invalidate_showcase_preview_bonus_cache()
	var recipe_ids: Array = state.display_items.keys()
	recipe_ids.sort()
	for recipe_id_value: Variant in recipe_ids:
		var recipe_id := String(recipe_id_value)
		_sync_showcase_slot_projection(recipe_id)


func _ensure_showcase_slot_count() -> void:
	while state.display_slots.size() < SHOWCASE_SLOT_COUNT:
		state.display_slots.append(null)
	while state.display_slots.size() > SHOWCASE_SLOT_COUNT:
		state.display_slots.pop_back()


func _showcase_prop_cells_for_slot(prop_id: String, slot_index: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if slot_index < 0 or slot_index >= SHOWCASE_SLOT_COUNT or not GameState.DISPLAY_PROP_SHAPES.has(prop_id):
		return cells
	var anchor := _showcase_cell_for_slot_index(slot_index)
	for offset_value in (GameState.DISPLAY_PROP_SHAPES[prop_id] as Dictionary).get("cells", []):
		if offset_value is Vector2i:
			cells.append(anchor + (offset_value as Vector2i))
	return cells


func _showcase_prop_id_for_cell(cell: Vector2i) -> String:
	if state == null or not state.display_props is Dictionary:
		return ""
	for prop_id_value in state.display_props.keys():
		var prop_id := String(prop_id_value)
		var prop: Dictionary = state.display_props[prop_id_value]
		if (prop.get("cells", []) as Array).has(cell):
			return prop_id
	return ""


func _can_drop_showcase_data(target_kind: String, data: Variant) -> bool:
	if showcase_expansion_active or target_kind != "showcase" or not data is Dictionary:
		return false
	var drag_data: Dictionary = data
	var drag_kind := String(drag_data.get("kind", ""))
	if drag_kind == "inventory_product" and not state.is_core_feature_unlocked(CoreFeatureUnlockService.LIST):
		return false
	if drag_kind in ["showcase_product", "showcase_prop"] and not state.is_core_feature_unlocked(CoreFeatureUnlockService.ARRANGE):
		return false
	var round_phase := String(state.active_business_round.get("phase", "adjusting"))
	if round_phase == "settlement" or (round_phase == "running" and drag_kind != "inventory_product"):
		_clear_showcase_drag_preview()
		return false
	if drag_kind == "showcase_prop":
		var prop_id := String(drag_data.get("prop_id", ""))
		var target_slot_index := int(drag_data.get("target_slot_index", -1))
		var prop_cells := _showcase_prop_cells_for_slot(prop_id, target_slot_index)
		var can_place_prop: bool = not prop_cells.is_empty() \
			and state.has_method("can_place_display_prop") \
			and state.can_place_display_prop(prop_id, prop_cells)
		_clear_showcase_drag_preview()
		return can_place_prop
	if drag_kind == "showcase_product":
		var move_recipe_id := String(drag_data.get("recipe_id", ""))
		var move_slot_index := _showcase_move_anchor_slot_index(drag_data)
		if move_recipe_id.is_empty() or move_slot_index < 0 or move_slot_index >= SHOWCASE_SLOT_COUNT:
			_clear_showcase_drag_preview()
			return false
		if not state.has_method("is_display_item_placed") or not state.is_display_item_placed(move_recipe_id):
			_clear_showcase_drag_preview()
			return false
		var move_cells := _showcase_cells_for_slot_using_current_shape(move_recipe_id, move_slot_index)
		var can_move: bool = not move_cells.is_empty() and _are_showcase_cells_unlocked(move_cells) and state.has_method("can_place_display_item") and state.can_place_display_item(move_recipe_id, move_cells)
		if can_move:
			_set_showcase_drag_preview(move_recipe_id, move_cells, "move")
		else:
			_clear_showcase_drag_preview()
		return can_move
	if drag_kind != "inventory_product":
		_clear_showcase_drag_preview()
		return false
	var recipe_id := String(drag_data.get("recipe_id", ""))
	var variant_id := _showcase_variant_from_drag(recipe_id, drag_data)
	var slot_index := int(drag_data.get("target_slot_index", -1))
	if recipe_id.is_empty() or slot_index < 0 or slot_index >= SHOWCASE_SLOT_COUNT:
		_clear_showcase_drag_preview()
		return false
	if not state.is_recipe_unlocked(recipe_id) or not state.has_product(recipe_id):
		_clear_showcase_drag_preview()
		return false
	if state.has_method("is_display_item_placed") and state.is_display_item_placed(recipe_id):
		if _display_item_variant_id(recipe_id) != variant_id:
			_clear_showcase_drag_preview()
			return false
		var existing_cells: Array = state.get_display_item_cells(recipe_id)
		if existing_cells.is_empty():
			_clear_showcase_drag_preview()
			return false
		_set_showcase_drag_preview(recipe_id, existing_cells, "stack", variant_id)
		return true
	if round_phase == "running":
		var replacement := _showcase_replacement_placement_for_target(recipe_id, slot_index, variant_id)
		if not replacement.is_empty():
			_set_showcase_drag_preview(recipe_id, replacement.get("cells", []), "replace", variant_id)
			return true
		var target_cell := _showcase_cell_for_slot_index(slot_index)
		if not _showcase_blocking_recipes_for_cells(recipe_id, [target_cell]).is_empty():
			_clear_showcase_drag_preview()
			return false
	var cells := _showcase_cells_for_slot(recipe_id, slot_index, variant_id)
	if cells.is_empty():
		_clear_showcase_drag_preview()
		return false
	if not _are_showcase_cells_unlocked(cells):
		_clear_showcase_drag_preview()
		return false
	var blocking_recipes := _showcase_blocking_recipes_for_cells(recipe_id, cells)
	if not blocking_recipes.is_empty():
		var replaced_recipe_id := String(blocking_recipes[0]) if blocking_recipes.size() == 1 else ""
		var can_replace: bool = not replaced_recipe_id.is_empty() \
			and round_phase == "running" \
			and state.has_method("can_replace_display_item_during_round") \
			and state.can_replace_display_item_during_round(replaced_recipe_id, recipe_id, cells, 1, variant_id)
		if can_replace:
			_set_showcase_drag_preview(recipe_id, cells, "replace", variant_id)
		else:
			_clear_showcase_drag_preview()
		return can_replace
	var raw_slot: Variant = state.display_slots[slot_index]
	if raw_slot is Dictionary and (raw_slot as Dictionary).has("covered_by"):
		_clear_showcase_drag_preview()
		return false
	var slot := _showcase_slot(slot_index)
	if not slot.is_empty():
		var can_stack_here := String(slot.get("recipe_id", "")) == recipe_id and _display_item_variant_id(recipe_id) == variant_id
		if can_stack_here:
			_set_showcase_drag_preview(recipe_id, cells, "stack", variant_id)
		else:
			_clear_showcase_drag_preview()
		return can_stack_here
	var can_place: bool
	if round_phase == "running":
		can_place = state.has_method("can_list_display_item_during_round") \
			and state.can_list_display_item_during_round(recipe_id, cells, 1, variant_id)
	else:
		can_place = state.has_method("can_place_display_item") and state.can_place_display_item(recipe_id, cells, variant_id)
	if can_place:
		_set_showcase_drag_preview(recipe_id, cells, "place", variant_id)
	else:
		_clear_showcase_drag_preview()
	return can_place


func _drop_showcase_data(target_kind: String, data: Variant) -> bool:
	if not _can_drop_showcase_data(target_kind, data):
		_set_status(_showcase_drop_failure_status(data))
		return false
	var drag_data: Dictionary = data
	if String(drag_data.get("kind", "")) == "showcase_prop":
		var prop_id := String(drag_data.get("prop_id", ""))
		var prop_cells := _showcase_prop_cells_for_slot(prop_id, int(drag_data.get("target_slot_index", -1)))
		if not state.place_display_prop(prop_id, prop_cells):
			_set_status("道具放置失败：目标格被占用或营业中布局已锁定。")
			return false
		_invalidate_showcase_bonus_cache()
		_save_game()
		_set_status("已放置陈列道具：%s" % String((ShowcaseRuleService.PROP_RULES.get(prop_id, {}) as Dictionary).get("label", prop_id)))
		_refresh_storefront_showcase()
		_refresh_storefront_manage_sections()
		return true
	var recipe_id := String(drag_data.get("recipe_id", ""))
	var variant_id := _showcase_variant_from_drag(recipe_id, drag_data)
	var slot_index := int(drag_data.get("target_slot_index", -1))
	if String(drag_data.get("kind", "")) == "showcase_product":
		return _move_showcase_product(recipe_id, _showcase_move_anchor_slot_index(drag_data))
	var base_sale_seconds := _random_showcase_sale_seconds()
	if state.has_method("is_display_item_placed") and state.is_display_item_placed(recipe_id):
		var anchor_slot_index := _display_anchor_slot_index_for_recipe(recipe_id)
		if anchor_slot_index < 0:
			_set_status("无法上架：找不到已上架商品的位置。")
			_clear_showcase_drag_preview()
			return false
		if String(state.active_business_round.get("phase", "adjusting")) == "running":
			var refilled := _refill_showcase_round_item(recipe_id, 1)
			_clear_showcase_drag_preview()
			if refilled:
				_record_manual_list_success(recipe_id, drag_data)
				_save_game()
				_show_next_notification()
			return refilled
		if not _refill_showcase_item(recipe_id):
			_set_status("无法上架：成品库存不足。")
			_clear_showcase_drag_preview()
			return false
		_sync_showcase_slot_from_display_item(anchor_slot_index, recipe_id)
		_clear_showcase_drag_preview()
		_record_manual_list_success(recipe_id, drag_data)
		_save_game()
		_set_status("已追加上架 %s；开始营业后按本轮周期售卖。" % _recipe_name(recipe_id))
		inventory_overlay.call("refresh_grid", self)
		_refresh_storefront_showcase()
		_show_next_notification()
		return true
	var cells := _showcase_cells_for_slot(recipe_id, slot_index, variant_id)
	if String(state.active_business_round.get("phase", "adjusting")) == "running":
		var replacement := _showcase_replacement_placement_for_target(recipe_id, slot_index, variant_id)
		if not replacement.is_empty():
			var replaced_target := _replace_showcase_round_item(
				String(replacement.get("replaced_recipe_id", "")),
				recipe_id,
				replacement.get("cells", []),
				variant_id,
				base_sale_seconds
			)
			if replaced_target:
				_record_manual_list_success(recipe_id, drag_data)
				_save_game()
				_show_next_notification()
			return replaced_target
		var blocking_recipes := _showcase_blocking_recipes_for_cells(recipe_id, cells)
		if blocking_recipes.size() == 1:
			var replaced_blocker := _replace_showcase_round_item(
				String(blocking_recipes[0]),
				recipe_id,
				cells,
				variant_id,
				base_sale_seconds
			)
			if replaced_blocker:
				_record_manual_list_success(recipe_id, drag_data)
				_save_game()
				_show_next_notification()
			return replaced_blocker
		_clear_showcase_drag_preview()
		var listed_during_round := _list_showcase_round_item(recipe_id, cells, variant_id, base_sale_seconds)
		if listed_during_round:
			_record_manual_list_success(recipe_id, drag_data)
			_save_game()
			_show_next_notification()
		return listed_during_round
	if not state.list_display_item(recipe_id, cells, 1, variant_id, base_sale_seconds):
		_set_status("无法上架：成品库存不足。")
		_clear_showcase_drag_preview()
		return false
	_sync_showcase_slot_from_display_item(slot_index, recipe_id)
	_clear_showcase_drag_preview()
	_record_manual_list_success(recipe_id, drag_data)
	_save_game()
	_set_status("已上架 %s；开始营业后按本轮周期售卖。" % _recipe_name(recipe_id))
	inventory_overlay.call("refresh_grid", self)
	_refresh_storefront_showcase()
	_refresh_showcase_round_controls()
	_show_next_notification()
	return true


func _record_manual_list_success(recipe_id: String, drag_data: Dictionary) -> void:
	state.record_task_event("manual_list_success", {
		"action_kind": String(drag_data.get("manual_list_source", "drag")),
		"recipe_id": recipe_id
	})
	call_deferred("_refresh_production_workbench")


func _showcase_drop_failure_status(data: Variant) -> String:
	var phase := String(state.active_business_round.get("phase", "adjusting")) if state != null else "adjusting"
	if phase == "settlement":
		return "营业已经结束，请先处理本轮余货。"
	if not data is Dictionary:
		return "无法上架：拖入内容不是可售成品。"
	var drag_data: Dictionary = data
	var drag_kind := String(drag_data.get("kind", ""))
	if drag_kind == "inventory_product" and not state.is_core_feature_unlocked(CoreFeatureUnlockService.LIST):
		return "🔒 %s" % state.core_feature_locked_reason(CoreFeatureUnlockService.LIST)
	if drag_kind in ["showcase_product", "showcase_prop"] and not state.is_core_feature_unlocked(CoreFeatureUnlockService.ARRANGE):
		return "🔒 %s" % state.core_feature_locked_reason(CoreFeatureUnlockService.ARRANGE)
	if drag_kind == "showcase_prop":
		return "道具放置失败：请使用已解锁道具，并拖到调整阶段的已解锁空格。"
	if phase == "running" and String(drag_data.get("kind", "")) == "showcase_product":
		return "营业中只能补货或放入空格，不能移动已有商品。"
	var recipe_id := String(drag_data.get("recipe_id", ""))
	if recipe_id.is_empty() or not state.has_product(recipe_id):
		return "上新失败：成品库存不足。"
	var variant_id := _showcase_variant_from_drag(recipe_id, drag_data)
	var cells := _showcase_cells_for_slot(recipe_id, int(drag_data.get("target_slot_index", -1)), variant_id)
	var blocking_recipes := _showcase_blocking_recipes_for_cells(recipe_id, cells)
	if phase == "running" and blocking_recipes.size() > 1:
		return "替换失败：一次只能替换一个售完商品。"
	if phase == "running" and blocking_recipes.size() == 1:
		var blocker := String(blocking_recipes[0])
		if not state.has_method("is_display_item_sold_out_during_round") \
				or not state.is_display_item_sold_out_during_round(blocker):
			return "替换失败：目标区域仍有在售商品。"
	if cells.is_empty():
		return "上新失败：商品形状超出橱窗范围。"
	if not _are_showcase_cells_unlocked(cells):
		return "上新失败：目标格未全部解锁。"
	return "上新失败：目标区域已被占用。"


func _move_showcase_product(recipe_id: String, slot_index: int) -> bool:
	if not _require_core_feature(CoreFeatureUnlockService.ARRANGE):
		_clear_showcase_drag_preview()
		return false
	if _is_showcase_round_layout_locked():
		_set_status("营业中布局已锁定，请在本轮结算后调整。")
		_clear_showcase_drag_preview()
		return false
	var cells := _showcase_cells_for_slot_using_current_shape(recipe_id, slot_index)
	if cells.is_empty():
		_set_status("无法移动：目标格子放不下该商品。")
		_clear_showcase_drag_preview()
		return false
	var current_cells: Array = state.get_display_item_cells(recipe_id) if state.has_method("get_display_item_cells") else []
	if _same_showcase_cells(current_cells, cells):
		_set_status("请把商品拖到另一个位置。")
		_clear_showcase_drag_preview()
		return false
	if not state.has_method("place_display_item") or not state.place_display_item(recipe_id, cells):
		_set_status("无法移动：目标格子被占用。")
		_clear_showcase_drag_preview()
		return false
	_refresh_showcase_layout_projection()
	_clear_showcase_drag_preview()
	TutorialProgress.on_showcase_product_moved(state, recipe_id)
	_save_game()
	_set_status("已移动橱窗商品：%s" % _recipe_name(recipe_id))
	_refresh_storefront_showcase()
	call_deferred("_refresh_tutorial_guide")
	return true


func _on_showcase_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if showcase_expansion_active:
		if mouse_event.pressed:
			accept_event()
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				_select_showcase_expansion_from_slot(slot_index)
			else:
				_set_status("扩建模式只用于选择锁定格；退出后可旋转商品或收回道具。")
		return
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var prop_id := _showcase_prop_id_for_cell(_showcase_cell_for_slot_index(slot_index))
	if not prop_id.is_empty():
		accept_event()
		if state.remove_display_prop(prop_id):
			_invalidate_showcase_bonus_cache()
			_save_game()
			_set_status("已收回陈列道具：%s" % String((ShowcaseRuleService.PROP_RULES.get(prop_id, {}) as Dictionary).get("label", prop_id)))
			_refresh_storefront_showcase()
			_refresh_storefront_manage_sections()
		else:
			_set_status("营业中道具布局已锁定，请在结算后调整。")
		return
	var slot := _showcase_slot(slot_index)
	var recipe_id := String(slot.get("recipe_id", ""))
	if recipe_id.is_empty():
		return
	accept_event()
	if _rotate_showcase_product(recipe_id):
		TutorialProgress.on_showcase_product_rotated(state, recipe_id)
		_save_game()
		call_deferred("_refresh_tutorial_guide")


func _select_showcase_expansion_from_slot(slot_index: int) -> void:
	if state == null or slot_index < 0 or slot_index >= SHOWCASE_SLOT_COUNT:
		return
	var cell := _showcase_cell_for_slot_index(slot_index)
	var unlocked: Array = state.get_showcase_unlocked_cells()
	if unlocked.has(cell):
		_set_status("该格已开放；请选择外围锁定格。")
		return
	if showcase_expansion_tool == "row":
		showcase_expansion_selected_cells = ShowcaseExpansionService.row_candidates(unlocked, cell.x)
	elif showcase_expansion_tool == "column":
		showcase_expansion_selected_cells = ShowcaseExpansionService.column_candidates(unlocked, cell.y)
	elif showcase_expansion_selected_cells.has(cell):
		var remaining := showcase_expansion_selected_cells.duplicate()
		remaining.erase(cell)
		if remaining.is_empty() or ShowcaseExpansionService.is_connected_purchase(unlocked, remaining):
			showcase_expansion_selected_cells = remaining
		else:
			_set_status("不能取消这个格：剩余选择会与旧区域断开。")
			return
	elif ShowcaseExpansionService.can_add_cell(unlocked, showcase_expansion_selected_cells, cell):
		showcase_expansion_selected_cells.append(cell)
	else:
		_set_status("该格暂不可选：请从绿色相邻格连续向外扩建。")
		return
	if showcase_expansion_selected_cells.is_empty():
		_set_status("该行/列没有与旧区域四方向相邻的未开放格。")
	_refresh_showcase_expansion_mode_ui()
	_refresh_storefront_showcase()


func _rotate_showcase_product(recipe_id: String) -> bool:
	if not _require_core_feature(CoreFeatureUnlockService.ARRANGE):
		return false
	if _is_showcase_round_layout_locked():
		_set_status("营业中布局已锁定，请在本轮结算后调整。")
		return false
	if not state.has_method("get_display_item_cells") or not state.has_method("place_display_item"):
		return false
	var current_cells: Array = state.get_display_item_cells(recipe_id)
	if current_cells.is_empty():
		return false
	var anchor_slot_index := _showcase_anchor_slot_index_for_cells(current_cells)
	if anchor_slot_index < 0:
		return false
	var local_cells := _local_showcase_shape_cells(current_cells)
	if local_cells.size() <= 1:
		_set_status("该商品只有一个格子，方向不变。")
		return false
	var rows := _showcase_shape_rows(local_cells)
	var rotated_local: Array[Vector2i] = []
	for cell in local_cells:
		rotated_local.append(Vector2i(cell.y, rows - cell.x + 1))
	var rotated_cells := _showcase_cells_for_local_shape(rotated_local, anchor_slot_index)
	if rotated_cells.is_empty():
		_set_status("无法旋转：目标方向超出橱窗。")
		return false
	if not _are_showcase_cells_unlocked(rotated_cells):
		_set_status("无法旋转：目标方向包含未解锁格。")
		return false
	if _same_showcase_cells(current_cells, rotated_cells):
		_set_status("该商品旋转后位置不变。")
		return false
	if not state.place_display_item(recipe_id, rotated_cells):
		_set_status("无法旋转：目标方向被其他商品占用。")
		return false
	_refresh_showcase_layout_projection()
	_clear_showcase_drag_preview()
	_save_game()
	_set_status("已旋转橱窗商品：%s" % _recipe_name(recipe_id))
	_refresh_storefront_showcase()
	return true


func _showcase_cells_for_slot(recipe_id: String, slot_index: int, variant_id: String = "standard") -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if slot_index < 0 or slot_index >= SHOWCASE_SLOT_COUNT:
		return cells
	var shape_info := _showcase_drag_shape_info(recipe_id, variant_id)
	var shape_rows := maxi(1, int(shape_info.get("shape_rows", 1)))
	var shape_cols := maxi(1, int(shape_info.get("shape_cols", 1)))
	var start_row := int(slot_index / SHOWCASE_GRID_COLUMNS) + 1
	var start_col := int(slot_index % SHOWCASE_GRID_COLUMNS) + 1
	if start_row + shape_rows - 1 > SHOWCASE_GRID_ROWS or start_col + shape_cols - 1 > SHOWCASE_GRID_COLUMNS:
		return []
	var shape_cells: Array = shape_info.get("shape_cells", [])
	if not shape_cells.is_empty():
		for shape_cell in shape_cells:
			if not shape_cell is Vector2i:
				return []
			var offset: Vector2i = shape_cell
			cells.append(Vector2i(start_row + offset.x - 1, start_col + offset.y - 1))
		return cells
	for row_offset in range(shape_rows):
		for col_offset in range(shape_cols):
			cells.append(Vector2i(start_row + row_offset, start_col + col_offset))
	return cells


func _showcase_cells_for_slot_using_current_shape(recipe_id: String, slot_index: int) -> Array[Vector2i]:
	if state.has_method("get_display_item_cells"):
		var current_cells: Array = state.get_display_item_cells(recipe_id)
		if not current_cells.is_empty():
			return _showcase_cells_for_local_shape(_local_showcase_shape_cells(current_cells), slot_index)
	return _showcase_cells_for_slot(recipe_id, slot_index)


func _showcase_move_anchor_slot_index(drag_data: Dictionary) -> int:
	var target_slot_index := int(drag_data.get("target_slot_index", -1))
	if target_slot_index < 0 or target_slot_index >= SHOWCASE_SLOT_COUNT:
		return -1
	var source_anchor_slot_index := int(drag_data.get("source_anchor_slot_index", -1))
	var source_grab_slot_index := int(drag_data.get("source_grab_slot_index", -1))
	if source_anchor_slot_index < 0 \
			or source_anchor_slot_index >= SHOWCASE_SLOT_COUNT \
			or source_grab_slot_index < 0 \
			or source_grab_slot_index >= SHOWCASE_SLOT_COUNT:
		return target_slot_index
	var grab_offset := _showcase_cell_for_slot_index(source_grab_slot_index) \
		- _showcase_cell_for_slot_index(source_anchor_slot_index)
	var anchor_cell := _showcase_cell_for_slot_index(target_slot_index) - grab_offset
	return _showcase_slot_index_for_cell(anchor_cell)


func _showcase_cells_for_local_shape(local_cells: Array[Vector2i], slot_index: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if local_cells.is_empty() or slot_index < 0 or slot_index >= SHOWCASE_SLOT_COUNT:
		return cells
	var start_row := int(slot_index / SHOWCASE_GRID_COLUMNS) + 1
	var start_col := int(slot_index % SHOWCASE_GRID_COLUMNS) + 1
	var max_row := _showcase_shape_rows(local_cells)
	var max_col := _showcase_shape_cols(local_cells)
	if start_row + max_row - 1 > SHOWCASE_GRID_ROWS or start_col + max_col - 1 > SHOWCASE_GRID_COLUMNS:
		return []
	for local_cell in local_cells:
		cells.append(Vector2i(start_row + local_cell.x - 1, start_col + local_cell.y - 1))
	return cells


func _local_showcase_shape_cells(cells: Array) -> Array[Vector2i]:
	var local_cells: Array[Vector2i] = []
	var min_row := SHOWCASE_GRID_ROWS
	var min_col := SHOWCASE_GRID_COLUMNS
	var found_cell := false
	for cell_value in cells:
		if not cell_value is Vector2i:
			continue
		var cell := cell_value as Vector2i
		found_cell = true
		min_row = mini(min_row, cell.x)
		min_col = mini(min_col, cell.y)
	if not found_cell:
		return local_cells
	for cell_value in cells:
		if not cell_value is Vector2i:
			continue
		var cell := cell_value as Vector2i
		local_cells.append(Vector2i(cell.x - min_row + 1, cell.y - min_col + 1))
	return local_cells


func _showcase_shape_rows(cells: Array[Vector2i]) -> int:
	var rows := 0
	for cell in cells:
		rows = maxi(rows, cell.x)
	return rows


func _showcase_shape_cols(cells: Array[Vector2i]) -> int:
	var cols := 0
	for cell in cells:
		cols = maxi(cols, cell.y)
	return cols


func _showcase_drag_shape_info(recipe_id: String, variant_id: String = "") -> Dictionary:
	var local_cells: Array[Vector2i] = []
	var clean_variant_id := _normalized_showcase_variant_id(variant_id)
	if variant_id.is_empty() and not recipe_id.is_empty() and state.has_method("is_display_item_placed") and state.is_display_item_placed(recipe_id) and state.has_method("get_display_item_cells"):
		local_cells = _local_showcase_shape_cells(state.get_display_item_cells(recipe_id))
		clean_variant_id = _display_item_variant_id(recipe_id)
	if local_cells.is_empty():
		if variant_id.is_empty():
			clean_variant_id = _selected_showcase_variant(recipe_id)
		local_cells = _variant_showcase_shape_cells(recipe_id, clean_variant_id)
	var variant: Dictionary = ShowcaseRuleService.variant_definition(recipe_id, clean_variant_id, catalog.get_recipe_display_config())
	return {
		"variant_id": clean_variant_id,
		"variant_label": _showcase_variant_label(clean_variant_id),
		"default_shape": "%dx%d" % [maxi(1, _showcase_shape_rows(local_cells)), maxi(1, _showcase_shape_cols(local_cells))],
		"shape_rows": maxi(1, _showcase_shape_rows(local_cells)),
		"shape_cols": maxi(1, _showcase_shape_cols(local_cells)),
		"cell_count": int(variant.get("cell_count", local_cells.size())),
		"shape_cells": local_cells
	}


func _variant_showcase_shape_cells(recipe_id: String, variant_id: String) -> Array[Vector2i]:
	var base_info := _recipe_display_shape_info(recipe_id)
	var base_cells := _base_showcase_shape_cells(base_info)
	var clean_variant_id := _normalized_showcase_variant_id(variant_id)
	var variant: Dictionary = ShowcaseRuleService.variant_definition(recipe_id, clean_variant_id, catalog.get_recipe_display_config())
	var target_count := maxi(1, int(variant.get("cell_count", base_cells.size())))
	if target_count <= base_cells.size():
		return _first_showcase_shape_cells(base_cells, target_count)
	return _expanded_showcase_shape_cells(base_cells, target_count)


func _base_showcase_shape_cells(shape_info: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var configured_cells: Array = shape_info.get("shape_cells", [])
	if configured_cells.is_empty():
		for row_index in range(int(shape_info.get("shape_rows", 1))):
			for col_index in range(int(shape_info.get("shape_cols", 1))):
				cells.append(Vector2i(row_index + 1, col_index + 1))
	else:
		for configured_cell in configured_cells:
			if configured_cell is Vector2i:
				cells.append(configured_cell)
	if cells.is_empty():
		cells.append(Vector2i(1, 1))
	return cells


func _first_showcase_shape_cells(cells: Array[Vector2i], count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if result.size() >= count:
			break
		result.append(cell)
	if result.is_empty():
		result.append(Vector2i(1, 1))
	return result


func _expanded_showcase_shape_cells(cells: Array[Vector2i], target_count: int) -> Array[Vector2i]:
	var result := _first_showcase_shape_cells(cells, cells.size())
	var used := {}
	for cell in result:
		used["%d:%d" % [cell.x, cell.y]] = true
	var max_rows := maxi(1, _showcase_shape_rows(result))
	var max_cols := maxi(1, _showcase_shape_cols(result))
	while result.size() < target_count:
		var added := false
		for row_index in range(1, max_rows + 1):
			for col_index in range(1, max_cols + 2):
				var key := "%d:%d" % [row_index, col_index]
				if used.has(key):
					continue
				result.append(Vector2i(row_index, col_index))
				used[key] = true
				added = true
				break
			if added:
				break
		if not added:
			max_rows += 1
			result.append(Vector2i(max_rows, 1))
			used["%d:%d" % [max_rows, 1]] = true
		max_rows = maxi(max_rows, _showcase_shape_rows(result))
		max_cols = maxi(max_cols, _showcase_shape_cols(result))
	return result


func _recipe_display_shape_info(recipe_id: String) -> Dictionary:
	var config: Dictionary = catalog.get_recipe_display_config()
	var recipe_display: Dictionary = config.get("recipes", {}).get(recipe_id, {})
	var default_shape := String(recipe_display.get("default_shape", "1x1"))
	var shape := default_shape.split("x")
	if shape.size() != 2:
		default_shape = "1x1"
		shape = ["1", "1"]
	var shape_rows := maxi(1, int(shape[0]))
	var shape_cols := maxi(1, int(shape[1]))
	var shape_cells := _display_shape_cells_from_value(recipe_display.get("shape_cells", []))
	for cell in shape_cells:
		shape_rows = maxi(shape_rows, cell.x)
		shape_cols = maxi(shape_cols, cell.y)
	var cell_count := maxi(1, int(recipe_display.get("cell_count", shape_rows * shape_cols)))
	if not shape_cells.is_empty():
		cell_count = shape_cells.size()
	return {
		"default_shape": default_shape,
		"shape_rows": shape_rows,
		"shape_cols": shape_cols,
		"cell_count": cell_count,
		"shape_cells": shape_cells
	}


func _display_shape_cells_from_value(value: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not value is Array:
		return cells
	for cell_value in value:
		if cell_value is Vector2i:
			cells.append(cell_value)
		elif cell_value is Array and cell_value.size() == 2:
			cells.append(Vector2i(int(cell_value[0]), int(cell_value[1])))
	return cells


func _showcase_slot_index_for_cell(cell: Vector2i) -> int:
	if cell.x < 1 or cell.x > SHOWCASE_GRID_ROWS or cell.y < 1 or cell.y > SHOWCASE_GRID_COLUMNS:
		return -1
	return (cell.x - 1) * SHOWCASE_GRID_COLUMNS + (cell.y - 1)


func _showcase_cell_for_slot_index(slot_index: int) -> Vector2i:
	return Vector2i(int(slot_index / SHOWCASE_GRID_COLUMNS) + 1, slot_index % SHOWCASE_GRID_COLUMNS + 1)


func _showcase_anchor_slot_index_for_cells(cells: Array) -> int:
	var anchor_index := SHOWCASE_SLOT_COUNT
	for cell in cells:
		if not cell is Vector2i:
			continue
		var slot_index := _showcase_slot_index_for_cell(cell)
		if slot_index < 0:
			continue
		anchor_index = mini(anchor_index, slot_index)
	return anchor_index if anchor_index < SHOWCASE_SLOT_COUNT else -1


func _showcase_anchor_slot_index_for_slot(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= state.display_slots.size():
		return -1
	var slot_value: Variant = state.display_slots[slot_index]
	if slot_value is Dictionary and (slot_value as Dictionary).has("covered_by"):
		return int((slot_value as Dictionary).get("covered_by", -1))
	return slot_index


func _display_anchor_slot_index_for_recipe(recipe_id: String) -> int:
	if not state.has_method("get_display_item_cells"):
		return -1
	return _showcase_anchor_slot_index_for_cells(state.get_display_item_cells(recipe_id))


func _showcase_blocking_recipes_for_cells(recipe_id: String, cells: Array) -> Array[String]:
	var result: Array[String] = []
	if state == null or cells.is_empty():
		return result
	for other_recipe_id_value in state.display_items.keys():
		var other_recipe_id := String(other_recipe_id_value)
		if other_recipe_id == recipe_id:
			continue
		var other_cells: Array = (state.display_items.get(other_recipe_id_value, {}) as Dictionary).get("cells", [])
		for cell_value in cells:
			if other_cells.has(cell_value):
				result.append(other_recipe_id)
				break
	result.sort()
	return result


func _showcase_replacement_placement_for_target(recipe_id: String, target_slot_index: int, variant_id: String) -> Dictionary:
	if state == null \
			or target_slot_index < 0 \
			or target_slot_index >= SHOWCASE_SLOT_COUNT \
			or not state.has_method("is_display_item_sold_out_during_round") \
			or not state.has_method("can_replace_display_item_during_round"):
		return {}
	var target_cell := _showcase_cell_for_slot_index(target_slot_index)
	var target_blockers := _showcase_blocking_recipes_for_cells(recipe_id, [target_cell])
	if target_blockers.size() != 1:
		return {}
	var replaced_recipe_id := String(target_blockers[0])
	if not state.is_display_item_sold_out_during_round(replaced_recipe_id):
		return {}
	var anchor_candidates: Array[int] = []
	var replaced_anchor := _display_anchor_slot_index_for_recipe(replaced_recipe_id)
	if replaced_anchor >= 0:
		anchor_candidates.append(replaced_anchor)
	var shape_info := _showcase_drag_shape_info(recipe_id, variant_id)
	var local_cells: Array[Vector2i] = []
	for local_value in shape_info.get("shape_cells", []):
		if local_value is Vector2i:
			local_cells.append(local_value)
	if local_cells.is_empty():
		for row in range(1, maxi(1, int(shape_info.get("shape_rows", 1))) + 1):
			for column in range(1, maxi(1, int(shape_info.get("shape_cols", 1))) + 1):
				local_cells.append(Vector2i(row, column))
	for local_cell in local_cells:
		var anchor_cell := target_cell - local_cell + Vector2i.ONE
		var anchor_slot_index := _showcase_slot_index_for_cell(anchor_cell)
		if anchor_slot_index >= 0 and not anchor_candidates.has(anchor_slot_index):
			anchor_candidates.append(anchor_slot_index)
	for anchor_slot_index in anchor_candidates:
		var cells := _showcase_cells_for_slot(recipe_id, anchor_slot_index, variant_id)
		if cells.is_empty() \
				or not cells.has(target_cell) \
				or not state.can_replace_display_item_during_round(replaced_recipe_id, recipe_id, cells, 1, variant_id):
			continue
		return {
			"replaced_recipe_id": replaced_recipe_id,
			"anchor_slot_index": anchor_slot_index,
			"cells": cells
		}
	return {}


func _same_showcase_cells(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	var left_keys := {}
	for cell in left:
		if not cell is Vector2i:
			return false
		left_keys["%d:%d" % [cell.x, cell.y]] = true
	for cell in right:
		if not cell is Vector2i:
			return false
		if not left_keys.has("%d:%d" % [cell.x, cell.y]):
			return false
	return true


func _sync_showcase_slot_from_display_item(slot_index: int, recipe_id: String, amount: int = 1) -> void:
	_ensure_showcase_slot_count()
	_clear_showcase_covered_slots(slot_index)
	var current_quantity := 0
	if slot_index < state.display_slots.size() and state.display_slots[slot_index] is Dictionary:
		var existing: Dictionary = state.display_slots[slot_index]
		if String(existing.get("recipe_id", "")) == recipe_id:
			current_quantity = maxi(0, int(existing.get("quantity", 0)))
	state.display_slots[slot_index] = {
		"recipe_id": recipe_id,
		"quantity": current_quantity + maxi(1, amount)
	}
	for cell in state.get_display_item_cells(recipe_id):
		var cell_slot_index := _showcase_slot_index_for_cell(cell)
		if cell_slot_index == -1 or cell_slot_index == slot_index or cell_slot_index >= state.display_slots.size():
			continue
		state.display_slots[cell_slot_index] = {"covered_by": slot_index}


func _sync_showcase_slot_projection(recipe_id: String) -> void:
	if state == null or recipe_id.is_empty() or not state.display_items.has(recipe_id):
		return
	_ensure_showcase_slot_count()
	_clear_showcase_slots_for_recipe(recipe_id)
	var slot_index := _display_anchor_slot_index_for_recipe(recipe_id)
	if slot_index < 0 or slot_index >= state.display_slots.size():
		return
	var item: Dictionary = state.display_items[recipe_id]
	state.display_slots[slot_index] = {
		"recipe_id": recipe_id,
		"quantity": maxi(0, int(item.get("stock", 0)))
	}
	for cell in state.get_display_item_cells(recipe_id):
		var cell_slot_index := _showcase_slot_index_for_cell(cell)
		if cell_slot_index == -1 or cell_slot_index == slot_index or cell_slot_index >= state.display_slots.size():
			continue
		state.display_slots[cell_slot_index] = {"covered_by": slot_index}
func _clear_showcase_slots_for_recipe(recipe_id: String) -> void:
	var anchor_indices := {}
	var indices_to_clear := {}
	for index in range(state.display_slots.size()):
		var slot_value: Variant = state.display_slots[index]
		if slot_value == null:
			continue
		if slot_value is Dictionary:
			var slot: Dictionary = slot_value
			if slot.has("covered_by"):
				continue
			if String(slot.get("recipe_id", "")) == recipe_id:
				anchor_indices[index] = true
				indices_to_clear[index] = true
		elif String(slot_value) == recipe_id:
			anchor_indices[index] = true
			indices_to_clear[index] = true
	for index in range(state.display_slots.size()):
		var slot_value: Variant = state.display_slots[index]
		if slot_value is Dictionary and anchor_indices.has(int((slot_value as Dictionary).get("covered_by", -1))):
			indices_to_clear[index] = true
	for index in indices_to_clear.keys():
		state.display_slots[int(index)] = null


func _clear_showcase_covered_slots(anchor_slot_index: int) -> void:
	for index in range(state.display_slots.size()):
		var slot_value: Variant = state.display_slots[index]
		if slot_value is Dictionary and int((slot_value as Dictionary).get("covered_by", -1)) == anchor_slot_index:
			state.display_slots[index] = null


func _random_showcase_sale_seconds() -> int:
	return randi_range(SHOWCASE_SALE_MIN_SECONDS, SHOWCASE_SALE_MAX_SECONDS)


func _showcase_slot_indices_for_recipe(recipe_id: String) -> Array[int]:
	var result: Array[int] = []
	for cell_value in state.get_display_item_cells(recipe_id):
		if cell_value is Vector2i:
			var cell_slot_index := _showcase_slot_index_for_cell(cell_value)
			if cell_slot_index >= 0 and not result.has(cell_slot_index):
				result.append(cell_slot_index)
	return result


func _showcase_anchor_slots_for_recipe_ids(recipe_ids: Variant) -> Array[int]:
	var result: Array[int] = []
	if recipe_ids is Array:
		for recipe_id_value in recipe_ids as Array:
			var anchor_slot_index := _display_anchor_slot_index_for_recipe(String(recipe_id_value))
			if anchor_slot_index >= 0 and not result.has(anchor_slot_index):
				result.append(anchor_slot_index)
	return result


func _play_pending_showcase_sale_feedback() -> void:
	var batch: Dictionary = showcase_feedback_director.drain_visual_batch()
	var events: Array = batch.get("events", [])
	if events.is_empty():
		_refresh_showcase_pulse_summary()
		return
	var started_coins := 0
	for started_event_value: Variant in events:
		if started_event_value is Dictionary:
			started_coins += maxi(0, int((started_event_value as Dictionary).get("earned_coins", 0)))
	if started_coins > 0:
		if showcase_feedback_visual_coin_target < 0:
			showcase_feedback_visual_coin_target = int(state.coins) - started_coins
		var visual_start := showcase_feedback_visual_coin_target
		showcase_feedback_visual_coin_target += started_coins
		_schedule_showcase_coins_label_gain(started_coins, visual_start, showcase_feedback_visual_coin_target)
	for event_value: Variant in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		if bool(event.get("bonus_only", false)):
			_play_showcase_chain_reward_feedback(event)
		else:
			_play_showcase_sale_pulse(event)
	_refresh_showcase_pulse_summary()


func _play_showcase_sale_pulse(event: Dictionary) -> void:
	var anchor_slot := int(event.get("anchor_slot", -1))
	var source_center := _showcase_slot_center(anchor_slot)
	if source_center == Vector2.INF:
		source_center = _showcase_summary_center()
	var breakdown: Dictionary = event.get("feedback_breakdown", {})
	if breakdown.is_empty():
		breakdown = {
			"total_coins": maxi(0, int(event.get("earned_coins", 0))),
			"base_income": maxi(0, int(event.get("earned_coins", 0))),
			"market_income": 0,
			"layout_extra_income": 0
		}
	var layout_extra := int(breakdown.get("layout_extra_income", 0))
	var total_coins := maxi(1, int(breakdown.get("total_coins", event.get("earned_coins", 0))))
	var layout_strength := clampf(float(maxi(0, layout_extra)) / float(total_coins), 0.0, 1.0)
	var pulse_color := Color(1.0, 0.77 + layout_strength * 0.12, 0.18)
	var pulse_slots: Array = event.get("cell_indices", [])
	if pulse_slots.is_empty():
		pulse_slots = [anchor_slot]
	_spawn_showcase_product_pulse(pulse_slots, pulse_color, "sold", layout_strength)
	_spawn_showcase_sale_feedback_text(event, pulse_slots)
	_spawn_showcase_coin_burst(source_center, _coins_label_center(), total_coins, layout_extra)
	_play_showcase_related_feedback(event, source_center, "related_recipe_ids", "related_slots", "contributor", Color(1.0, 0.62, 0.18))
	_play_showcase_related_feedback(event, source_center, "conflict_recipe_ids", "conflict_slots", "conflict", Color(0.92, 0.24, 0.20))


func _play_showcase_chain_reward_feedback(event: Dictionary) -> void:
	var earned_coins := maxi(0, int(event.get("earned_coins", 0)))
	if earned_coins <= 0:
		return
	var source_center := _showcase_slot_center(int(event.get("anchor_slot", -1)))
	if source_center == Vector2.INF:
		source_center = _showcase_summary_center()
	_spawn_showcase_sale_feedback_text(event, [int(event.get("anchor_slot", -1))])
	_spawn_showcase_coin_burst(source_center, _coins_label_center(), earned_coins, earned_coins)


func _play_showcase_related_feedback(
	event: Dictionary,
	source_center: Vector2,
	recipe_ids_key: String,
	slots_key: String,
	role: String,
	color: Color
) -> void:
	var recipe_ids: Array = event.get(recipe_ids_key, [])
	if not recipe_ids.is_empty():
		for recipe_id_value: Variant in recipe_ids:
			var recipe_id := String(recipe_id_value)
			var related_indices: Array[int] = _showcase_slot_indices_for_recipe(recipe_id)
			if related_indices.is_empty():
				continue
			_spawn_showcase_product_pulse(related_indices, color, role, 0.35)
			var related_anchor := _display_anchor_slot_index_for_recipe(recipe_id)
			var related_center := _showcase_slot_center(related_anchor)
			if related_center != Vector2.INF:
				_spawn_showcase_relation_line(source_center, related_center, color)
		return
	for target_value: Variant in event.get(slots_key, []):
		var target_slot := int(target_value)
		_spawn_showcase_product_pulse([target_slot], color, role, 0.35)
		var target := _showcase_slot_center(target_slot)
		if target != Vector2.INF:
			_spawn_showcase_relation_line(source_center, target, color)


func _showcase_slot_center(slot_index: int) -> Vector2:
	if slot_index < 0 or slot_index >= showcase_grid.get_child_count():
		return Vector2.INF
	var control := showcase_grid.get_child(slot_index) as Control
	if control == null:
		return Vector2.INF
	return control.get_global_rect().get_center() - showcase_feedback_layer.global_position


func _showcase_summary_center() -> Vector2:
	return showcase_pulse_summary.get_global_rect().get_center() - showcase_feedback_layer.global_position


func _coins_label_center() -> Vector2:
	return coins_label.get_global_rect().get_center() - showcase_feedback_layer.global_position


func _spawn_showcase_sale_feedback_text(event: Dictionary, slot_indices: Array) -> void:
	var feedback_key := String(event.get("feedback_key", event.get("recipe_id", "")))
	var feedback := ShowcaseSaleFeedbackScene.instantiate() as VBoxContainer
	if feedback == null:
		showcase_feedback_director.release_visual_slot(feedback_key)
		return
	var breakdown: Dictionary = event.get("feedback_breakdown", {})
	var total_coins := maxi(0, int(breakdown.get("total_coins", event.get("earned_coins", 0))))
	var earned_reputation := maxi(0, int(event.get("earned_reputation", 0)))
	var boost_percent := _showcase_sale_feedback_boost_percent(event)
	var coin_label := feedback.get_node("CoinLabel") as Label
	var reputation_label := feedback.get_node("ReputationLabel") as Label
	var boost_label := feedback.get_node("BoostLabel") as Label
	coin_label.visible = total_coins > 0
	coin_label.text = "金币 +%d" % total_coins
	reputation_label.visible = earned_reputation > 0
	reputation_label.text = "口碑 +%d" % earned_reputation
	boost_label.visible = boost_percent != 0
	if boost_percent > 0:
		boost_label.text = "收益加成 +%d%%" % boost_percent
		boost_label.add_theme_color_override("font_color", Color(0.42, 1.0, 0.32))
	else:
		boost_label.text = "收益减损 %d%%" % boost_percent
		boost_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.26))
	feedback.z_index = 8
	feedback.size = feedback.custom_minimum_size
	var cells: Array[Vector2i] = []
	for slot_value in slot_indices:
		var slot_index := int(slot_value)
		if slot_index >= 0:
			cells.append(_showcase_cell_for_slot_index(slot_index))
	var product_rect := _showcase_group_rect(cells)
	if product_rect.size.x <= 0.0 or product_rect.size.y <= 0.0:
		product_rect = Rect2(_showcase_summary_center(), Vector2.ONE)
	feedback.position = _showcase_sale_feedback_text_position(
		product_rect,
		feedback.custom_minimum_size,
		showcase_feedback_layer.size
	)
	feedback.pivot_offset = feedback.custom_minimum_size * 0.5
	feedback.scale = Vector2(0.9, 0.9)
	showcase_feedback_layer.add_child(feedback)
	var tween := create_tween()
	tween.tween_property(feedback, "scale", Vector2(1.10, 1.10), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(feedback, "position:y", feedback.position.y - 4.0, 0.15)
	tween.tween_property(feedback, "scale", Vector2.ONE, 0.10)
	tween.parallel().tween_property(feedback, "position:y", feedback.position.y - 8.0, 0.10)
	tween.tween_property(feedback, "position:y", feedback.position.y - 16.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(feedback, "position:y", feedback.position.y - 28.0, 0.50)
	tween.parallel().tween_property(feedback, "modulate:a", 0.0, 0.50)
	tween.tween_callback(_finish_showcase_sale_feedback_text.bind(feedback, feedback_key))


func _finish_showcase_sale_feedback_text(feedback: Variant, feedback_key: String) -> void:
	if is_instance_valid(feedback):
		feedback.call("queue_free")
	showcase_feedback_director.release_visual_slot(feedback_key)
	if showcase_feedback_director.pending_count() > 0:
		get_tree().create_timer(SHOWCASE_FEEDBACK_QUEUE_DELAY_SECONDS).timeout.connect(
			_play_pending_showcase_sale_feedback,
			CONNECT_ONE_SHOT
		)


func _spawn_showcase_relation_line(from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 3.0
	line.default_color = color
	showcase_feedback_layer.add_child(line)
	var tween := create_tween()
	tween.tween_interval(SHOWCASE_FEEDBACK_RELATION_HOLD_SECONDS)
	tween.tween_property(
		line,
		"modulate:a",
		0.0,
		SHOWCASE_FEEDBACK_RELATION_SECONDS - SHOWCASE_FEEDBACK_RELATION_HOLD_SECONDS
	)
	tween.tween_callback(line.queue_free)


func _spawn_showcase_pulse_rect(slot_index: int, color: Color) -> void:
	if slot_index < 0 or slot_index >= showcase_grid.get_child_count():
		return
	var source := showcase_grid.get_child(slot_index) as Control
	if source == null:
		return
	var source_rect := source.get_global_rect()
	var pulse := ColorRect.new()
	pulse.color = Color(color.r, color.g, color.b, 0.35)
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.position = source_rect.position - showcase_feedback_layer.global_position
	pulse.size = source_rect.size
	pulse.pivot_offset = pulse.size * 0.5
	showcase_feedback_layer.add_child(pulse)
	var tween := create_tween()
	tween.tween_property(pulse, "scale", Vector2(1.08, 1.08), SHOWCASE_FEEDBACK_PULSE_SECONDS * 0.15)
	tween.tween_interval(SHOWCASE_FEEDBACK_PULSE_SECONDS * 0.45)
	tween.tween_property(pulse, "scale", Vector2.ONE, SHOWCASE_FEEDBACK_PULSE_SECONDS * 0.20)
	tween.parallel().tween_property(pulse, "modulate:a", 0.0, SHOWCASE_FEEDBACK_PULSE_SECONDS * 0.40)
	tween.tween_callback(pulse.queue_free)


func _spawn_showcase_product_pulse(slot_indices: Array, color: Color, role: String = "sold", strength: float = 0.0) -> void:
	var cells: Array[Vector2i] = []
	var normalized_indices: Array[int] = []
	for slot_value: Variant in slot_indices:
		var slot_index := int(slot_value)
		if slot_index >= 0 and not normalized_indices.has(slot_index):
			normalized_indices.append(slot_index)
			cells.append(_showcase_cell_for_slot_index(slot_index))
	var product_rect := _showcase_group_rect(cells)
	if product_rect.size.x <= 0.0 or product_rect.size.y <= 0.0:
		return
	normalized_indices.sort()
	var key_parts: Array[String] = []
	for slot_index: int in normalized_indices:
		key_parts.append(str(slot_index))
	var outline_key := "%s:%s" % [role, ",".join(key_parts)]
	var previous: Variant = showcase_feedback_outlines.get(outline_key)
	if is_instance_valid(previous):
		(previous as Control).queue_free()
	var pulse := Panel.new()
	var outline_style := StyleBoxFlat.new()
	var safe_strength := clampf(strength, 0.0, 1.0)
	outline_style.bg_color = Color(color.r, color.g, color.b, 0.14 + safe_strength * 0.14)
	outline_style.border_color = Color(color.r, color.g, color.b, 0.94)
	var border_width := clampi(4 + int(round(safe_strength * 4.0)), 4, 8)
	outline_style.border_width_left = border_width
	outline_style.border_width_top = border_width
	outline_style.border_width_right = border_width
	outline_style.border_width_bottom = border_width
	outline_style.corner_radius_top_left = 8
	outline_style.corner_radius_top_right = 8
	outline_style.corner_radius_bottom_left = 8
	outline_style.corner_radius_bottom_right = 8
	pulse.add_theme_stylebox_override("panel", outline_style)
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.position = product_rect.position
	pulse.size = product_rect.size
	pulse.pivot_offset = pulse.size * 0.5
	pulse.z_index = 6 if role == "sold" else 5
	pulse.set_meta("showcase_feedback_role", role)
	pulse.set_meta("showcase_feedback_slots", normalized_indices.duplicate())
	showcase_feedback_layer.add_child(pulse)
	showcase_feedback_outlines[outline_key] = pulse
	var tween := create_tween()
	var peak_scale := 1.06 + safe_strength * 0.06
	tween.tween_property(pulse, "scale", Vector2(peak_scale, peak_scale), SHOWCASE_FEEDBACK_PULSE_SECONDS * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse, "scale", Vector2(0.99, 0.99), SHOWCASE_FEEDBACK_PULSE_SECONDS * 0.10)
	tween.tween_property(pulse, "scale", Vector2(1.04, 1.04), SHOWCASE_FEEDBACK_PULSE_SECONDS * 0.10)
	tween.tween_property(pulse, "scale", Vector2.ONE, SHOWCASE_FEEDBACK_PULSE_SECONDS * 0.10)
	tween.tween_interval(SHOWCASE_FEEDBACK_PULSE_SECONDS * 0.18)
	tween.tween_property(pulse, "modulate:a", 0.0, SHOWCASE_FEEDBACK_PULSE_SECONDS * 0.40)
	tween.tween_callback(_clear_showcase_feedback_outline.bind(outline_key, pulse))


func _clear_showcase_feedback_outline(outline_key: String, outline: Variant) -> void:
	if showcase_feedback_outlines.get(outline_key) == outline:
		showcase_feedback_outlines.erase(outline_key)
	if is_instance_valid(outline):
		outline.call("queue_free")


func _spawn_showcase_coin_burst(from: Vector2, to: Vector2, earned_coins: int, layout_extra_coins: int = 0) -> void:
	var coin_count := clampi(
		SHOWCASE_COIN_MIN_COUNT + int(maxi(0, earned_coins) / 40) + int(maxi(0, layout_extra_coins) / 18),
		SHOWCASE_COIN_MIN_COUNT,
		SHOWCASE_COIN_MAX_COUNT
	)
	var layout_strength := clampf(float(maxi(0, layout_extra_coins)) / float(maxi(1, earned_coins)), 0.0, 1.0)
	for coin_index in range(coin_count):
		var coin := Label.new()
		coin.text = "●"
		coin.modulate = Color(1.0, 0.78 + float(coin_index % 2) * 0.08, 0.22)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.position = from - Vector2(6, 8)
		coin.scale = Vector2.ONE * (0.8 + layout_strength * 0.25)
		coin.z_index = 5
		showcase_feedback_layer.add_child(coin)
		var side_offset := (float(coin_index) - float(coin_count - 1) * 0.5) * 13.0
		var scatter_center := from + Vector2(side_offset * 0.45, -18.0 - float(coin_index % 3) * 5.0)
		var arc_control := (scatter_center + to) * 0.5 + Vector2(side_offset, -70.0 - float(coin_index % 3) * 12.0)
		var tween := create_tween()
		tween.tween_interval(float(coin_index) * 0.04)
		tween.tween_property(coin, "position", scatter_center - Vector2(6, 8), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_method(
			Callable(self, "_set_showcase_coin_arc_position").bind(coin, scatter_center, arc_control, to),
			0.0,
			1.0,
			1.70
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(coin, "scale", Vector2(0.62, 0.62), 1.70)
		tween.tween_property(coin, "scale", Vector2(0.30, 0.30), SHOWCASE_FEEDBACK_COIN_SECONDS - 1.90)
		tween.parallel().tween_property(coin, "modulate:a", 0.0, SHOWCASE_FEEDBACK_COIN_SECONDS - 1.90)
		tween.tween_callback(coin.queue_free)


func _set_showcase_coin_arc_position(progress: float, coin: Control, from: Vector2, arc_control: Vector2, to: Vector2) -> void:
	if not is_instance_valid(coin):
		return
	var inverse := 1.0 - progress
	coin.position = inverse * inverse * from + 2.0 * inverse * progress * arc_control + progress * progress * to - Vector2(6, 8)


func _schedule_showcase_coins_label_gain(earned_coins: int, start_coins: int, target_coins: int) -> void:
	if earned_coins <= 0:
		return
	showcase_feedback_pending_coin_rolls += 1
	get_tree().create_timer(SHOWCASE_FEEDBACK_COIN_ROLL_DELAY_SECONDS).timeout.connect(
		_begin_showcase_coins_label_gain.bind(earned_coins, start_coins, target_coins),
		CONNECT_ONE_SHOT
	)


func _begin_showcase_coins_label_gain(earned_coins: int, start_coins: int, target_coins: int) -> void:
	showcase_feedback_pending_coin_rolls = maxi(0, showcase_feedback_pending_coin_rolls - 1)
	_animate_coins_label_gain(earned_coins, start_coins, target_coins)


func _animate_coins_label_gain(earned_coins: int, start_coins: int, target_coins: int) -> void:
	if earned_coins <= 0 or not is_instance_valid(coins_label):
		return
	if showcase_feedback_coin_roll_tween != null and showcase_feedback_coin_roll_tween.is_running():
		showcase_feedback_coin_roll_tween.kill()
	coins_label.pivot_offset = coins_label.size * 0.5
	showcase_feedback_coin_roll_tween = create_tween()
	showcase_feedback_coin_roll_tween.tween_method(
		Callable(self, "_set_coins_label_roll_value").bind(start_coins, target_coins),
		0.0,
		1.0,
		SHOWCASE_FEEDBACK_COIN_ROLL_SECONDS
	)
	showcase_feedback_coin_roll_tween.parallel().tween_property(coins_label, "scale", Vector2(1.16, 1.16), SHOWCASE_FEEDBACK_COIN_ROLL_SECONDS * 0.55).set_trans(Tween.TRANS_BACK)
	showcase_feedback_coin_roll_tween.tween_property(coins_label, "scale", Vector2.ONE, SHOWCASE_FEEDBACK_COIN_ROLL_SECONDS * 0.45).set_trans(Tween.TRANS_BACK)


func _set_coins_label_roll_value(progress: float, start_coins: int, target_coins: int) -> void:
	var displayed_coins := int(round(lerpf(float(start_coins), float(target_coins), progress)))
	var upgrade_target := _topbar_shop_upgrade_target()
	coins_label.text = _topbar_coins_text(displayed_coins, upgrade_target)
	if not upgrade_target.is_empty() and is_instance_valid(coins_upgrade_progress):
		var required_coins := maxi(0, int(upgrade_target.get("cost", 0)))
		coins_upgrade_progress.value = clampi(displayed_coins, 0, required_coins) if required_coins > 0 else coins_upgrade_progress.max_value


func _refresh_showcase_pulse_summary() -> void:
	var listed_stock := 0
	for recipe_id_value: Variant in state.display_items.keys():
		var item_view := _showcase_round_item_view(String(recipe_id_value))
		var stock := maxi(0, int(item_view.get("quantity", 0)))
		listed_stock += stock
	var phase := String(state.active_business_round.get("phase", "adjusting"))
	var phase_text := "布局调整"
	if phase == "running":
		phase_text = "营业中"
	elif phase == "settlement":
		phase_text = "待处理余货"
	showcase_pulse_summary.text = "%s｜热度 %d｜可售库存 %d" % [
		phase_text,
		clampi(int(state.active_business_round.get("heat", 0)), 0, 100),
		listed_stock
	]
	_refresh_showcase_task_progress()


func _refresh_showcase_set_progress() -> void:
	var progress: Array[Dictionary] = []
	if state != null:
		progress = ShowcaseRuleService.set_progress(
			state.display_items,
			catalog.get_recipes(),
			catalog.get_display_rules().get("set_bonuses", {})
		)
	var lines: Array[String] = []
	for entry in progress:
		var set_name := String(entry.get("set_name", entry.get("set_id", "套装")))
		match String(entry.get("status", "missing_items")):
			"active":
				lines.append("套装「%s」生效" % set_name)
			"needs_connection":
				lines.append("套装「%s」还差连通摆放" % set_name)
			_:
				lines.append("套装「%s」还差 %d 件" % [set_name, maxi(0, int(entry.get("missing_count", 0)))])
	var progress_text := "\n".join(lines)
	showcase_set_progress_label.text = progress_text
	showcase_set_progress_label.tooltip_text = progress_text
	showcase_set_progress_label.visible = not lines.is_empty()


func _refresh_showcase_task_progress() -> void:
	var snapshot: Dictionary = state.pending_showcase_challenge
	if snapshot.is_empty() and state.active_business_round.get("challenge", {}) is Dictionary:
		snapshot = state.active_business_round.get("challenge", {})
	if snapshot.is_empty():
		showcase_task_progress_panel.visible = false
		return
	var preview_state: Dictionary = state.active_business_round.duplicate(true)
	if preview_state.is_empty():
		preview_state = BusinessRoundService.create_challenge(state.business_round_id, int(snapshot.get("duration_seconds", 30)), snapshot)
	preview_state["live_layout_changed"] = true
	preview_state["layout_snapshot"] = state.display_items.duplicate(true)
	preview_state["role_snapshot"] = ShowcaseRoleService.build_configured_snapshot(state.display_items, _showcase_round_sale_terms(), catalog.get_showcase_round_rules().get("role_rules", {}))
	preview_state["tag_snapshot"] = _showcase_tag_snapshot(state.display_items)
	preview_state["item_states"] = preview_state.get("item_states", {}) if preview_state.get("item_states", {}) is Dictionary else {}
	preview_state["environment"] = snapshot.get("environment", preview_state.get("environment", {}))
	var preview_report := ShowcaseRoundReportService.build_report(preview_state, {"settlement_id": "preview"})
	var tiers: Array = snapshot.get("tiers", [])
	var conditions: Array = []
	if not tiers.is_empty() and tiers[0] is Dictionary:
		_collect_showcase_leaf_conditions((tiers[0] as Dictionary).get("condition", {}), conditions)
	var lines: Array[String] = ["合同目标｜%s" % String(snapshot.get("title", snapshot.get("task_id", "经营合同")))]
	for condition_value in conditions.slice(0, 3):
		if not condition_value is Dictionary:
			continue
		var condition: Dictionary = condition_value
		var field := String(condition.get("field", ""))
		var current: Variant = _showcase_report_value(preview_report, field)
		var operator := String(condition.get("operator", ""))
		var symbol := "≥" if operator == "gte" else "≤" if operator == "lte" else "="
		lines.append("%s：%s %s %s" % [_showcase_metric_label(field), current, symbol, condition.get("value")])
	showcase_task_progress_panel.visible = true
	showcase_task_progress_label.text = "\n".join(lines)


func _collect_showcase_leaf_conditions(condition_value: Variant, output: Array) -> void:
	if not condition_value is Dictionary:
		return
	var condition: Dictionary = condition_value
	if condition.get("conditions", []) is Array and not (condition.get("conditions", []) as Array).is_empty():
		for child in condition.get("conditions", []):
			_collect_showcase_leaf_conditions(child, output)
	else:
		output.append(condition)


func _showcase_report_value(report: Dictionary, field: String) -> Variant:
	var current: Variant = report
	for segment in field.split("."):
		if not current is Dictionary or not (current as Dictionary).has(segment):
			return 0
		current = (current as Dictionary).get(segment)
	return current


func _showcase_metric_label(field: String) -> String:
	return {
		"counts.sold": "成交",
		"counts.chain_triggers": "连锁",
		"counts.forced_clearance": "强制清仓",
		"layout.occupied_cells": "占用格数",
		"total_coins": "本轮金币",
		"layout_extra_income": "构筑收益"
	}.get(field, field)


func _recent_sale_text(recipe_name: String) -> String:
	if not bool(last_business_feedback.get("triggered", false)):
		return "暂无营业"
	var sold_by_recipe_name: Dictionary = last_business_feedback.get("sold_by_recipe_name", {})
	var sold_count := int(sold_by_recipe_name.get(recipe_name, 0))
	if sold_count <= 0:
		return "本轮未售出"
	return "本轮售出 %d 份" % sold_count


func _refresh_cashier_feedback() -> void:
	if not bool(last_business_feedback.get("triggered", false)):
		cashier_receipt_text = "待营业\n\n%s" % _showcase_bonus_panel_text()
		return
	var sold_count := int(last_business_feedback.get("sold_count", 0))
	var earned_coins := int(last_business_feedback.get("earned_coins", 0))
	var earned_reputation := int(last_business_feedback.get("earned_reputation", 0))
	var sale_lines := _recent_sale_bonus_lines()
	var sale_text := ""
	if not sale_lines.is_empty():
		sale_text = "\n最近售出\n%s" % "\n".join(sale_lines)
	cashier_receipt_text = "本轮营业\n售出 %d 份\n金币 +%d\n口碑 +%d%s\n\n%s" % [
		sold_count,
		earned_coins,
		earned_reputation,
		sale_text,
		_showcase_bonus_panel_text()
	]


func _record_business_feedback(recipe_id: String, sale_result: Dictionary) -> void:
	var sold_by_recipe_name := {}
	var sale_bonus_lines: Array[String] = []
	var sales_value: Variant = sale_result.get("sales", [])
	if sales_value is Array:
		for sale in sales_value:
			if not (sale is Dictionary):
				continue
			var sold_recipe_id := String(sale.get("recipe_id", recipe_id))
			var sold_recipe_name := _recipe_name(sold_recipe_id)
			var sold_quantity := int(sale.get("quantity", 1))
			if sold_quantity <= 0:
				continue
			sold_by_recipe_name[sold_recipe_name] = int(sold_by_recipe_name.get(sold_recipe_name, 0)) + sold_quantity
			var sale_bonus: Dictionary = sale.get("bonus", {})
			var base_price := int(sale.get("base_price", 0))
			var final_price := int(sale.get("final_price", sale.get("price", base_price)))
			var speed_multiplier := float(sale_bonus.get("speed_multiplier", 1.0))
			var reason_text := _showcase_bonus_reason_text(sale_bonus, 2)
			var reason_suffix := ""
			if not reason_text.is_empty():
				reason_suffix = "；原因：%s" % reason_text
			sale_bonus_lines.append("%s：售价 %d→%d，售速 %s%s" % [
				sold_recipe_name,
				base_price,
				final_price,
				_bonus_pct_text((speed_multiplier - 1.0) * 100.0),
				reason_suffix
			])
	last_business_feedback = {
		"recipe_name": _recipe_name(recipe_id),
		"sold_by_recipe_name": sold_by_recipe_name,
		"sold_count": int(sale_result.get("sold_count", 0)),
		"earned_coins": int(sale_result.get("earned_coins", 0)),
		"earned_reputation": int(sale_result.get("earned_reputation", 0)),
		"sale_bonus_lines": sale_bonus_lines,
		"triggered": true
	}
	_refresh_storefront()


func _recent_sale_bonus_lines() -> Array[String]:
	var result: Array[String] = []
	if not bool(last_business_feedback.get("triggered", false)):
		return result
	var sale_lines: Array = last_business_feedback.get("sale_bonus_lines", [])
	for line in sale_lines:
		var text := String(line)
		if not text.is_empty():
			result.append(text)
	return result


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _on_output_bag_tab_changed(index: int) -> void:
	if global_popup_mode != "output":
		return
	if index < 0 or index >= OUTPUT_BAG_PAGE_COUNT:
		return
	selected_output_bag_page = index
	_refresh_output_grids()


func _save_game() -> bool:
	if SaveSystem.save_game(state, save_path):
		return true
	var prefix := status_label.text.strip_edges()
	status_label.text = "%s｜存档失败，请检查用户目录权限。" % prefix if not prefix.is_empty() else "存档失败，请检查用户目录权限。"
	return false


func _selected_research_material_ids() -> Array:
	var ids: Array[String] = []
	for material_id in selected_research_material_ids:
		if not material_id.is_empty():
			ids.append(material_id)
	return ids


func _set_status(message: String) -> void:
	status_label.text = message
	if state != null and state.has_method("add_log"):
		state.add_log("ui:%s" % message)
		_refresh_feedback_log()


func _is_tool_available_for_display(tool_id: String, tool: Dictionary) -> bool:
	return int(tool.get("unlock_level", 1)) <= state.level


func _show_task_global_popup() -> void:
	_open_global_popup_mode("task")
	_refresh_task_overlay()


func _show_inventory_global_popup(return_mode: String = "") -> void:
	global_popup_return_mode = return_mode
	_open_global_popup_mode("inventory")
	_fill_inventory_tabs()
	inventory_batch_list_button.visible = state.is_feature_unlocked(RESEARCH_LIST_ALL_FEATURE_ID)
	inventory_overlay.call("refresh_grid", self)


func _show_research_global_popup() -> void:
	_open_global_popup_mode(PAGE_RESEARCH)
	_refresh_production_workbench()
	_refresh_research_overlay()


func _show_catalog_global_popup() -> void:
	_open_global_popup_mode("catalog")
	selected_catalog_page = 0
	catalog_overlay.call("refresh_panel", self)


func _show_automation_global_popup() -> void:
	_open_global_popup_mode("automation")
	_refresh_automation_overlay()


func _show_purchase_global_popup() -> void:
	_open_global_popup_mode("purchase")
	_refresh_purchase_page()


func _show_output_global_popup() -> void:
	_open_global_popup_mode("output")
	_refresh_output_page()


func _show_kitchen_schedule() -> void:
	_open_global_popup_mode(MODE_KITCHEN_SCHEDULE)
	kitchen_schedule_overlay.refresh(state)


func _open_global_popup_mode(mode: String) -> bool:
	if mode != "inventory":
		global_popup_return_mode = ""
		pending_research_material_slot_index = -1
	_apply_global_overlay_layout(mode)
	global_popup_mode = mode
	inventory_overlay_hidden_for_product_drag = false
	showcase_feedback_layer.visible = mode.is_empty()
	global_overlay_layer.visible = not mode.is_empty()
	global_popup_backdrop.visible = not mode.is_empty()
	global_popup_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_global_popup_mode(mode)
	return true


func _apply_global_overlay_layout(mode: String = "") -> void:
	var is_purchase := mode == PAGE_PURCHASE
	var is_catalog := mode == "catalog"
	default_modal_surface.visible = true
	_apply_overlay_content_margins(is_purchase)
	_apply_unified_overlay_layout(is_catalog)


func _apply_overlay_content_margins(is_purchase: bool) -> void:
	var margins := PURCHASE_OVERLAY_CONTENT_MARGINS if is_purchase else Vector4.ZERO
	overlay_mode_stack.add_theme_constant_override("margin_left", roundi(margins.x))
	overlay_mode_stack.add_theme_constant_override("margin_top", roundi(margins.y))
	overlay_mode_stack.add_theme_constant_override("margin_right", roundi(margins.z))
	overlay_mode_stack.add_theme_constant_override("margin_bottom", roundi(margins.w))


func _apply_unified_overlay_layout(is_catalog: bool) -> void:
	global_overlay_layer.custom_minimum_size = Vector2.ZERO
	overlay_frame.custom_minimum_size = Vector2.ZERO
	_set_overlay_frame_offsets(CATALOG_OVERLAY_FRAME_OFFSETS if is_catalog else DEFAULT_OVERLAY_FRAME_OFFSETS)
	var anchors := _global_overlay_anchors(size)
	global_overlay_layer.anchor_left = anchors.x
	global_overlay_layer.anchor_top = anchors.y
	global_overlay_layer.anchor_right = anchors.z
	global_overlay_layer.anchor_bottom = anchors.w
	global_overlay_layer.offset_left = 0.0
	global_overlay_layer.offset_top = 0.0
	global_overlay_layer.offset_right = 0.0
	global_overlay_layer.offset_bottom = 0.0


func _set_overlay_frame_offsets(offsets: Vector4) -> void:
	overlay_frame.offset_left = offsets.x
	overlay_frame.offset_top = offsets.y
	overlay_frame.offset_right = offsets.z
	overlay_frame.offset_bottom = offsets.w


func _global_overlay_anchors(viewport_size: Vector2) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return GLOBAL_OVERLAY_FALLBACK_ANCHORS
	var available_size := viewport_size * GLOBAL_OVERLAY_MAX_VIEWPORT_FRACTION
	var target_size := available_size
	if target_size.x / target_size.y > GLOBAL_OVERLAY_ASPECT_RATIO:
		target_size.x = target_size.y * GLOBAL_OVERLAY_ASPECT_RATIO
	else:
		target_size.y = target_size.x / GLOBAL_OVERLAY_ASPECT_RATIO
	var anchor_size := target_size / viewport_size
	var anchor_origin := (Vector2.ONE - anchor_size) * 0.5
	return Vector4(
		anchor_origin.x,
		anchor_origin.y,
		anchor_origin.x + anchor_size.x,
		anchor_origin.y + anchor_size.y
	)


func _on_task_global_button_pressed() -> void:
	if not _require_core_feature(CoreFeatureUnlockService.TASK):
		return
	if _close_if_global_popup_mode("task"):
		return
	_show_task_global_popup()


func _on_inventory_global_button_pressed() -> void:
	if not _require_core_feature(CoreFeatureUnlockService.INVENTORY):
		return
	if _close_if_global_popup_mode("inventory"):
		return
	_show_inventory_global_popup()


func _on_catalog_global_button_pressed() -> void:
	if not _require_core_feature(CoreFeatureUnlockService.CATALOG):
		return
	if _close_if_global_popup_mode("catalog"):
		return
	_show_catalog_global_popup()


func _on_research_global_button_pressed() -> void:
	if _close_if_global_popup_mode(PAGE_RESEARCH):
		return
	_show_research_global_popup()


func _on_starlight_global_button_pressed() -> void:
	if not _require_core_feature(CoreFeatureUnlockService.STARLIGHT):
		return
	if _close_if_global_popup_mode("automation"):
		return
	_show_automation_global_popup()


func _on_purchase_global_button_pressed() -> void:
	if not _require_core_feature(CoreFeatureUnlockService.PURCHASE):
		return
	if _close_if_global_popup_mode("purchase"):
		return
	_show_purchase_global_popup()


func _on_purchase_confirm_pressed() -> void:
	if global_popup_mode != "purchase":
		return
	_purchase_cart_items()
	_save_game()
	_refresh_resource_bar()
	_show_next_notification()


func _on_output_global_button_pressed() -> void:
	if not _require_core_feature(CoreFeatureUnlockService.OUTPUT):
		return
	if _close_if_global_popup_mode("output"):
		return
	_show_output_global_popup()


func _on_output_primary_action_pressed() -> void:
	if global_popup_mode != "output":
		return
	_apply_primary_output_action()
	_save_game()
	_refresh_output_page()
	_refresh_resource_bar()
	_show_next_notification()


func _on_output_refresh_pressed() -> void:
	if global_popup_mode != "output":
		return
	_apply_secondary_output_action()
	_refresh_output_page()


func _on_overlay_close_button_pressed() -> void:
	_return_or_close_global_popup()


func _close_if_global_popup_mode(mode: String) -> bool:
	if global_popup_mode != mode:
		return false
	_close_global_popup()
	return true


func _close_global_popup() -> void:
	global_popup_mode = ""
	global_popup_return_mode = ""
	purchase_page_refresh_pending = false
	catalog_overlay.call("close_action_popup")
	pending_research_material_slot_index = -1
	global_overlay_dragging = false
	inventory_overlay_dragging = false
	inventory_overlay_hidden_for_product_drag = false
	showcase_feedback_layer.visible = true
	_apply_global_overlay_layout()
	_show_global_popup_mode("")
	global_popup_backdrop.visible = false
	global_popup_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	global_overlay_layer.visible = false


func _return_or_close_global_popup() -> void:
	if global_popup_mode == "inventory" and not global_popup_return_mode.is_empty():
		var return_mode := global_popup_return_mode
		global_popup_return_mode = ""
		pending_research_material_slot_index = -1
		_open_global_popup_mode(return_mode)
		if return_mode == PAGE_RESEARCH:
			_refresh_research_overlay()
		return
	_close_global_popup()


func _on_global_popup_backdrop_pressed() -> void:
	var closed_storefront_dialog := false
	for dialog in [storefront_challenge_dialog, storefront_recent_report_dialog, showcase_rulebook_dialog]:
		if is_instance_valid(dialog) and dialog.visible:
			dialog.hide()
			closed_storefront_dialog = true
	if closed_storefront_dialog:
		_refresh_storefront_entry_dialog_backdrop()
		return
	_return_or_close_global_popup()


func _on_global_popup_closed() -> void:
	_return_or_close_global_popup()


func _show_global_popup_mode(mode: String) -> void:
	inventory_overlay.visible = mode == "inventory"
	research_overlay.visible = mode == PAGE_RESEARCH
	task_overlay.visible = mode == "task"
	catalog_overlay.visible = mode == "catalog"
	automation_overlay.visible = mode == "automation"
	kitchen_schedule_overlay.visible = mode == MODE_KITCHEN_SCHEDULE
	purchase_overlay.visible = mode == "purchase"
	output_overlay.visible = mode == "output"
	storefront_manage_overlay.visible = mode == "storefront_manage"
	match mode:
		"task":
			overlay_title.text = "当前任务"
		"inventory":
			overlay_title.text = "库存"
		"catalog":
			overlay_title.text = "甜品图鉴"
		PAGE_RESEARCH:
			overlay_title.text = "研发"
			overlay_summary.text = "选择食材与设备，研发新配方或加工中间产物"
		"automation":
			overlay_title.text = "自动化中枢"
		MODE_KITCHEN_SCHEDULE:
			overlay_title.text = "厨房自动排程"
			overlay_summary.text = "设置单批制作、目标库存与原料保留"
		"purchase":
			overlay_title.text = "采购"
			overlay_summary.text = "按来源补充原料、种苗与工具"
		"output":
			overlay_title.text = "产出"
			overlay_summary.text = "安排原料产地并收获成熟产出"
		"storefront_manage":
			overlay_title.text = "经营中心"
			overlay_summary.text = "总览经营、调整橱窗策略并培养设备"
		_:
			overlay_title.text = "经营总览"
			overlay_summary.text = "查看对应经营详情"


func _refresh_automation_overlay() -> void:
	if state == null:
		return
	automation_overlay.call("refresh", state)
	var output_text := "已解锁" if state.is_automation_unlocked("output") else "待解锁"
	var kitchen_text := "已解锁" if state.is_automation_unlocked("kitchen") else "待解锁"
	overlay_summary.text = "可用星辉 %d｜原料产地 %s｜厨房甜品 %s" % [state.recipe_starlight_available, output_text, kitchen_text]


func _on_task_filter_button_pressed(filter_id: String) -> void:
	selected_task_filter = filter_id
	selected_task_id = ""
	_refresh_task_overlay()


func _refresh_task_overlay() -> void:
	var contract_choices: Array = []
	if state != null and int(state.level) >= 6 and state.pending_showcase_challenge.is_empty():
		contract_choices = _showcase_contract_choices()
	var snapshot: Dictionary = TaskService.build_task_snapshot(state, contract_choices) if state != null else {
		"current_entries": [], "side_entries": [], "claimable": [], "completed": [], "active": [],
		"current_slot_count": 0, "side_slot_count": 0, "current_empty_text": "当前没有可处理的任务。", "side_empty_text": "今日支线已全部完成。"
	}
	if not ["current", "side"].has(selected_task_filter):
		selected_task_filter = "current"
	var side_entries: Array = snapshot.get("side_entries", [])
	var claimable_tasks: Array = snapshot.get("claimable", [])
	overlay_summary.text = "成长任务 %d｜支线 %d｜待领取 %d" % [
		int(snapshot.get("current_slot_count", 0)),
		int(snapshot.get("side_slot_count", side_entries.size())),
		claimable_tasks.size()
	]
	selected_task_id = String(task_overlay.call("refresh_panel", self, snapshot, selected_task_filter, selected_task_id))


func _on_task_overlay_button_pressed(task_id: String) -> void:
	selected_task_id = task_id
	_refresh_task_overlay()


func _on_task_contract_select_requested(task_id: String) -> void:
	if not _accept_showcase_business_challenge(task_id):
		return
	selected_task_id = task_id
	_refresh_task_overlay()


func _task_progress_text(task: Dictionary) -> String:
	var progress: Dictionary = task.get("progress", {})
	var detail := TaskService.format_task_progress_detail(task, progress)
	if not detail.is_empty():
		return "已完成｜%s" % detail if String(task.get("status", "")) == "completed" else detail
	var goal := maxi(1, int(task.get("goal", progress.get("goal", 1))))
	var count := maxi(0, int(progress.get("count", 0)))
	if String(task.get("status", "")) == "completed":
		return "已完成"
	return "%d/%d" % [count, goal]


func _task_claim_status_text(task: Dictionary) -> String:
	if String(task.get("status", "")) == "candidate":
		return "可选择"
	if String(task.get("status", "")) != "completed":
		return "进行中"
	if String(task.get("claim_status", "")) == "claimable":
		return "待领取"
	return "已生效" if TaskService.format_claimable_reward(task.get("reward", {})).is_empty() else "已领取"


func _task_reward_text(reward_value: Variant) -> String:
	var reward_text := TaskService.format_claimable_reward(reward_value)
	return reward_text if not reward_text.is_empty() else "暂无"


func _task_unlock_text(reward_value: Variant) -> String:
	var unlock_text := TaskService.format_progression_effects(reward_value)
	return unlock_text if not unlock_text.is_empty() else "暂无"


func _on_task_claim_reward_pressed(task_id: String) -> void:
	if state == null or task_id.is_empty():
		return
	if not state.claim_task_reward(task_id):
		_set_status("该任务奖励暂时无法领取。")
		return
	_refresh_resource_bar()
	_refresh_current_page()
	_refresh_task_overlay()
	_save_game()
	_set_status("已领取任务奖励。")
	_show_next_notification()


func _on_task_shop_upgrade_requested(task_id: String) -> void:
	if state == null:
		return
	var expected_task_id := "shop_upgrade_%d" % (int(state.level) + 1)
	if task_id != expected_task_id:
		_set_status("升级任务已更新，请重新确认当前等级目标。")
		_refresh_task_overlay()
		return
	var eligibility: Dictionary = state.upgrade_eligibility()
	if not bool(eligibility.get("ok", false)):
		var missing: Array[String] = []
		var missing_coins := maxi(0, int(eligibility.get("missing_coins", 0)))
		var missing_reputation := maxi(0, int(eligibility.get("missing_reputation", 0)))
		if missing_coins > 0:
			missing.append("金币 %d" % missing_coins)
		if missing_reputation > 0:
			missing.append("累计口碑 %d" % missing_reputation)
		_set_status("升级条件不足：还需%s。" % "、".join(missing))
		_refresh_task_overlay()
		return
	var target_level := int(eligibility.get("target_level", int(state.level) + 1))
	var cost := int(eligibility.get("cost", 0))
	if not state.upgrade():
		_set_status("店铺升级未完成，请重新检查升级条件。")
		_refresh_task_overlay()
		return
	_save_game()
	_refresh_resource_bar()
	_refresh_current_page()
	_refresh_task_overlay()
	_set_status("店铺已升至 Lv.%d，扣除 %d 金币；累计口碑不扣除。" % [target_level, cost])
	_show_next_notification()


func _on_task_claim_all_rewards_pressed() -> void:
	if state == null:
		return
	var result: Dictionary = state.claim_all_task_rewards()
	if not bool(result.get("ok", false)):
		_set_status("当前没有可一键领取的任务奖励。")
		_refresh_task_overlay()
		return
	var task_ids: Array = result.get("task_ids", [])
	state.enqueue_notification("任务奖励已汇总", "本次共领取 %d 项任务奖励。" % task_ids.size())
	_refresh_resource_bar()
	_refresh_current_page()
	_refresh_task_overlay()
	_save_game()
	_set_status("已一键领取 %d 项任务奖励。" % task_ids.size())
	_show_next_notification()


func _on_task_go_button_pressed(task_id: String) -> void:
	_close_global_popup()
	var destination := _task_destination_page(task_id)
	_show_page(destination)
	var destination_label := "产地" if destination == PAGE_OUTPUT else "研发" if destination == PAGE_RESEARCH else "制作" if destination == PAGE_PRODUCTION else "经营中心"
	_set_status("已切换到%s，可继续完成当前任务。" % destination_label)


func _task_destination_page(task_id: String) -> String:
	var task: Dictionary = TaskService.get_task_definitions().get(task_id, {})
	if task.is_empty():
		return PAGE_STOREFRONT_MANAGE
	var event_name := _next_task_event(task_id, task)
	if ["harvest", "output_next_set"].has(event_name):
		return PAGE_OUTPUT
	if event_name == "research_attempt":
		return PAGE_RESEARCH
	if ["make_product", "recipe_queue_complete"].has(event_name):
		return PAGE_PRODUCTION
	return PAGE_STOREFRONT_MANAGE


func _next_task_event(task_id: String, task: Dictionary) -> String:
	var objectives_value: Variant = task.get("objectives", [])
	if objectives_value is Array and not (objectives_value as Array).is_empty():
		var progress_value: Variant = state.task_progress.get(task_id, {}) if state != null else {}
		var progress: Dictionary = progress_value if progress_value is Dictionary else {}
		var saved_value: Variant = progress.get("objectives", {})
		var saved: Dictionary = saved_value if saved_value is Dictionary else {}
		for objective_value: Variant in objectives_value:
			if not objective_value is Dictionary:
				continue
			var objective: Dictionary = objective_value
			var objective_progress_value: Variant = saved.get(String(objective.get("id", "")), {})
			if not objective_progress_value is Dictionary or not bool((objective_progress_value as Dictionary).get("completed", false)):
				return String(objective.get("event", ""))
	var events_value: Variant = task.get("events", [])
	if events_value is Array and not (events_value as Array).is_empty():
		return String((events_value as Array)[0])
	return String(task.get("event", ""))


func _is_position_inside_control(control: Control, position: Vector2) -> bool:
	return is_instance_valid(control) and control.visible and control.get_global_rect().has_point(position)


func _event_mouse_position(event: InputEventMouse) -> Vector2:
	if event.global_position != Vector2.ZERO:
		return event.global_position
	return event.position


func _fill_inventory_tabs() -> void:
	if inventory_tabs.tab_count == INVENTORY_TAB_ORDER.size():
		return
	inventory_tabs.set_block_signals(true)
	inventory_tabs.clear_tabs()
	var labels := {
		"all": "全部",
		"products": "成品",
		"ingredients": "食材",
		"seeds": "种养",
		"tools": "工具"
	}
	for tab_id in INVENTORY_TAB_ORDER:
		inventory_tabs.add_tab(String(labels.get(tab_id, tab_id)))
		var index := inventory_tabs.tab_count - 1
		inventory_tabs.set_tab_metadata(index, tab_id)
	inventory_tabs.current_tab = maxi(0, INVENTORY_TAB_ORDER.find(selected_inventory_tab))
	inventory_tabs.set_block_signals(false)


func _fill_inventory_sort_options() -> void:
	if inventory_sort_button.item_count > 0:
		return
	var options := [
		{"label": "默认排序", "id": INVENTORY_SORT_DEFAULT},
		{"label": "数量优先", "id": INVENTORY_SORT_COUNT},
		{"label": "名称排序", "id": INVENTORY_SORT_NAME}
	]
	for option in options:
		inventory_sort_button.add_item(String(option.get("label", "")))
		var index := inventory_sort_button.item_count - 1
		inventory_sort_button.set_item_metadata(index, String(option.get("id", "")))


func _on_inventory_sort_changed(index: int) -> void:
	var value: Variant = inventory_sort_button.get_item_metadata(index)
	if value == null:
		return
	selected_inventory_sort = String(value)
	selected_inventory_page = 0
	inventory_overlay.call("refresh_grid", self)


func _on_inventory_search_changed(text: String) -> void:
	inventory_search_text = text.strip_edges()
	selected_inventory_page = 0
	inventory_overlay.call("refresh_grid", self)


func _on_inventory_tab_changed(index: int) -> void:
	if index < 0 or index >= inventory_tabs.tab_count:
		return
	var metadata: Variant = inventory_tabs.get_tab_metadata(index)
	if metadata == null:
		return
	selected_inventory_tab = String(metadata)
	selected_inventory_page = 0
	inventory_overlay.call("refresh_grid", self)


func _on_inventory_prev_pressed() -> void:
	if selected_inventory_page <= 0:
		return
	selected_inventory_page -= 1
	inventory_overlay.call("refresh_grid", self)


func _on_inventory_next_pressed() -> void:
	var page_count := _inventory_page_count()
	if selected_inventory_page >= page_count - 1:
		return
	selected_inventory_page += 1
	inventory_overlay.call("refresh_grid", self)


func _refresh_inventory_summary() -> void:
	var used := _inventory_used_count()
	var capacity := 260
	inventory_capacity_label.text = "仓库容量：%d/%d" % [used, capacity]
	overlay_summary.text = "仓库容量 %d/%d｜分类 %s｜可拖拽成品到橱窗上架" % [
		used,
		capacity,
		_inventory_tab_label(selected_inventory_tab)
	]
	var low_stock_lines := _inventory_low_stock_lines()
	if low_stock_lines.is_empty():
		inventory_low_stock_list.text = "低库存：暂无"
	else:
		inventory_low_stock_list.text = "低库存提醒\n%s" % "\n".join(low_stock_lines.slice(0, mini(6, low_stock_lines.size())))
	var fill_percent := int(round(float(used) / float(capacity) * 100.0))
	inventory_capacity_warning.text = "即将满仓\n%d/%d（%d%%）" % [used, capacity, fill_percent]
	var recommendations := _inventory_restock_recommendation_lines()
	inventory_restock_recommendations.text = "可补货推荐\n%s" % ("暂无" if recommendations.is_empty() else "\n".join(recommendations.slice(0, mini(4, recommendations.size()))))


func _inventory_tab_label(tab_id: String) -> String:
	var labels := {
		"all": "全部",
		"products": "成品",
		"ingredients": "食材",
		"seeds": "种养",
		"tools": "工具",
		"low_stock": "低库存"
	}
	return String(labels.get(tab_id, tab_id))


func _ensure_inventory_variant_menu() -> void:
	if is_instance_valid(inventory_variant_menu):
		return
	inventory_variant_menu = PopupMenu.new()
	inventory_variant_menu.name = "InventoryVariantMenu"
	inventory_variant_menu.theme_type_variation = &"DessertPopupMenu"
	add_child(inventory_variant_menu)
	var handler := Callable(self, "_on_inventory_variant_menu_id_pressed")
	if not inventory_variant_menu.id_pressed.is_connected(handler):
		inventory_variant_menu.id_pressed.connect(handler)


func _on_inventory_product_cell_gui_input(event: InputEvent, recipe_id: String) -> void:
	if recipe_id.is_empty() or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	accept_event()
	_show_inventory_variant_menu(recipe_id, mouse_event.global_position)


func _show_inventory_variant_menu(recipe_id: String, global_position: Vector2) -> void:
	if recipe_id.is_empty():
		return
	_ensure_inventory_variant_menu()
	inventory_variant_menu_recipe_id = recipe_id
	inventory_variant_menu.clear()
	var selected_variant := _selected_showcase_variant(recipe_id)
	var display_config := catalog.get_recipe_display_config()
	for index in range(SHOWCASE_VARIANT_ORDER.size()):
		var variant_id := String(SHOWCASE_VARIANT_ORDER[index])
		var variant: Dictionary = ShowcaseRuleService.variant_definition(recipe_id, variant_id, display_config)
		var price_pct := float(variant.get("price_pct", 0.0))
		var speed_pct := float(variant.get("speed_pct", 0.0))
		var label := "%s｜%d格｜售价 %s｜售速 %s" % [
			_showcase_variant_label(variant_id),
			int(variant.get("cell_count", 1)),
			_bonus_pct_text(price_pct),
			_bonus_pct_text(speed_pct)
		]
		inventory_variant_menu.add_check_item(label, index)
		inventory_variant_menu.set_item_metadata(index, variant_id)
		inventory_variant_menu.set_item_checked(index, variant_id == selected_variant)
	inventory_variant_menu.position = Vector2i(int(global_position.x), int(global_position.y))
	if inventory_variant_menu.is_inside_tree():
		inventory_variant_menu.popup(Rect2i(inventory_variant_menu.position, Vector2i(1, 1)))


func _on_inventory_variant_menu_id_pressed(id: int) -> void:
	if not is_instance_valid(inventory_variant_menu):
		return
	var item_index := inventory_variant_menu.get_item_index(id)
	if item_index < 0:
		return
	var variant_id := String(inventory_variant_menu.get_item_metadata(item_index))
	_set_selected_showcase_variant(inventory_variant_menu_recipe_id, variant_id)


func _set_selected_showcase_variant(recipe_id: String, variant_id: String) -> void:
	if recipe_id.is_empty():
		return
	var clean_variant_id := _normalized_showcase_variant_id(variant_id)
	if clean_variant_id == "standard":
		selected_showcase_variants.erase(recipe_id)
	else:
		selected_showcase_variants[recipe_id] = clean_variant_id
	_set_status("已选择上架变体：%s｜%s" % [_recipe_name(recipe_id), _showcase_variant_label(clean_variant_id)])
	if global_popup_mode == "inventory" and is_instance_valid(inventory_overlay):
		inventory_overlay.call("refresh_grid", self)


func _selected_showcase_variant(recipe_id: String) -> String:
	if recipe_id.is_empty():
		return "standard"
	return _normalized_showcase_variant_id(String(selected_showcase_variants.get(recipe_id, "standard")))


func _normalized_showcase_variant_id(variant_id: String) -> String:
	var clean_variant_id := "standard" if variant_id.is_empty() else variant_id
	if SHOWCASE_VARIANT_ORDER.has(clean_variant_id):
		return clean_variant_id
	return "standard"


func _showcase_variant_label(variant_id: String) -> String:
	var variant: Dictionary = ShowcaseRuleService.variant_definition("", _normalized_showcase_variant_id(variant_id), catalog.get_recipe_display_config())
	return String(variant.get("label", variant_id))


func _display_item_variant_id(recipe_id: String) -> String:
	if recipe_id.is_empty() or state == null:
		return "standard"
	var display_items: Dictionary = state.get("display_items") if state.get("display_items") is Dictionary else {}
	var item: Dictionary = display_items.get(recipe_id, {})
	return _normalized_showcase_variant_id(String(item.get("variant_id", "standard")))


func _showcase_variant_from_drag(recipe_id: String, drag_data: Dictionary) -> String:
	if drag_data.has("variant_id"):
		return _normalized_showcase_variant_id(String(drag_data.get("variant_id", "standard")))
	return "standard"


func _make_inventory_cell(text: String, entry: Dictionary = {}) -> Button:
	var button: Button
	var uses_ingredient_icon := false
	if String(entry.get("kind", "")) == "product" and int(entry.get("count", 0)) > 0:
		var drag_button := InventoryProductCellScene.instantiate() as Button
		var recipe_id := String(entry.get("id", ""))
		var variant_id := _selected_showcase_variant(recipe_id)
		var shape_info := _showcase_drag_shape_info(recipe_id, variant_id)
		var shape_text := "%s / %d格" % [
			String(shape_info.get("default_shape", "1x1")),
			int(shape_info.get("cell_count", 1))
		]
		drag_button.call("configure_drag", {
			"kind": "inventory_product",
			"recipe_id": recipe_id,
			"variant_id": variant_id,
			"default_shape": String(shape_info.get("default_shape", "1x1")),
			"shape_rows": int(shape_info.get("shape_rows", 1)),
			"shape_cols": int(shape_info.get("shape_cols", 1)),
			"cell_count": int(shape_info.get("cell_count", 1)),
			"shape_cells": shape_info.get("shape_cells", [])
		}, "%s\n%s\n%s" % [String(entry.get("name", recipe_id)), _showcase_variant_label(variant_id), shape_text], shape_info, Callable(self, "_on_inventory_product_drag_ended"), Callable(self, "_on_inventory_product_drag_started"))
		var recipe_icon := drag_button.get_node("RecipeIcon") as TextureRect
		var name_label := drag_button.get_node("NameLabel") as Label
		var quantity_badge := drag_button.get_node("QuantityBadge") as Label
		recipe_icon.texture = _recipe_icon_texture(recipe_id, "inventory")
		name_label.text = String(entry.get("name", recipe_id))
		quantity_badge.text = str(int(entry.get("count", 0)))
		drag_button.tooltip_text = "拖到橱窗上架。\n右键选择上架变体。\n当前变体：%s\n形状：%s" % [_showcase_variant_label(variant_id), shape_text]
		drag_button.gui_input.connect(_on_inventory_product_cell_gui_input.bind(recipe_id))
		button = drag_button
	elif String(entry.get("kind", "")) == "ingredient" and int(entry.get("count", 0)) > 0:
		var ingredient_id := String(entry.get("id", ""))
		var ingredient_icon := _ingredient_icon_texture(ingredient_id)
		if ingredient_icon != null:
			var icon_button := InventoryProductCellScene.instantiate() as Button
			var icon_rect := icon_button.get_node("RecipeIcon") as TextureRect
			var name_label := icon_button.get_node("NameLabel") as Label
			var quantity_badge := icon_button.get_node("QuantityBadge") as Label
			icon_rect.texture = ingredient_icon
			name_label.text = String(entry.get("name", ingredient_id))
			quantity_badge.text = str(int(entry.get("count", 0)))
			icon_button.tooltip_text = _inventory_entry_tooltip(entry)
			button = icon_button
			uses_ingredient_icon = true
		else:
			button = BasicButtonScene.instantiate() as Button
	else:
		button = BasicButtonScene.instantiate() as Button
	button.theme_type_variation = &"DessertItemSlot"
	var entry_key := _inventory_entry_key(entry)
	if not entry_key.is_empty():
		button.set_meta("inventory_key", entry_key)
	button.text = "" if String(entry.get("kind", "")) == "product" or uses_ingredient_icon else (_inventory_cell_text(entry) if not entry.is_empty() else text)
	button.custom_minimum_size = INVENTORY_CELL_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var entry_kind := String(entry.get("kind", ""))
	var is_research_picker_active := pending_research_material_slot_index >= 0
	var is_research_picker := is_research_picker_active and (entry_kind == "ingredient" or entry_kind == "product")
	button.disabled = entry.is_empty() or (is_research_picker_active and not is_research_picker) or (not is_research_picker_active and entry_kind != "product" and entry_kind.is_empty())
	button.toggle_mode = not entry.is_empty()
	button.button_pressed = selected_inventory_item_keys.has(entry_key)
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_research_picker:
		button.pressed.connect(_select_research_material_from_inventory.bind(String(entry.get("id", ""))))
	elif not entry.is_empty():
		button.pressed.connect(_on_inventory_cell_pressed.bind(entry_key))
	if entry.has("source"):
		button.tooltip_text = _inventory_entry_tooltip(entry)
	return button


func _on_inventory_product_drag_started() -> void:
	if global_popup_mode != "inventory" or not is_instance_valid(global_overlay_layer):
		return
	inventory_overlay_hidden_for_product_drag = true
	global_overlay_layer.visible = false


func _on_inventory_product_drag_ended() -> void:
	_clear_showcase_drag_preview()
	_restore_inventory_overlay_after_product_drag_if_needed(true)


func _restore_inventory_overlay_after_product_drag_if_needed(force: bool = false) -> void:
	if not inventory_overlay_hidden_for_product_drag:
		return
	if not force and is_instance_valid(get_viewport()) and get_viewport().gui_is_dragging():
		return
	inventory_overlay_hidden_for_product_drag = false
	if global_popup_mode == "inventory" and is_instance_valid(global_overlay_layer):
		global_overlay_layer.visible = true


func _ingredient_icon_texture(item_id: String) -> Texture2D:
	if item_id.is_empty():
		return null
	var icon_path := "%s/%s.png" % [INGREDIENT_ICON_DIRECTORY, item_id]
	if not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


func _material_icon_texture(item_id: String) -> Texture2D:
	var ingredient_icon := _ingredient_icon_texture(item_id)
	if ingredient_icon != null:
		return ingredient_icon
	return _recipe_icon_texture(item_id, "action")


func _research_result_recipe_icon_texture(recipe_id: String) -> Texture2D:
	return _recipe_icon_texture(recipe_id, "base")


func _recipe_icon_texture(recipe_id: String, surface: String) -> Texture2D:
	if recipe_id.is_empty():
		return null
	var mastery_level := 0
	if state != null and state.has_method("recipe_mastery_level"):
		mastery_level = int(state.recipe_mastery_level(recipe_id))
	return RecipeIconService.texture(recipe_id, mastery_level, surface)


func _add_ingredient_icon_to_button(button: Button, item_id: String, icon_size: Vector2, offset: Vector2) -> void:
	var icon_texture := _material_icon_texture(item_id)
	if icon_texture == null:
		return
	var icon := TextureRect.new()
	icon.name = "IngredientIcon"
	icon.texture = icon_texture
	icon.position = offset
	icon.size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)


func _inventory_cell_text(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	return "%s\nx%d" % [
		String(entry.get("name", "")),
		int(entry.get("count", 0))
	]


func _inventory_entry_key(entry: Dictionary) -> String:
	var kind := String(entry.get("kind", ""))
	var id := String(entry.get("id", ""))
	if kind.is_empty() or id.is_empty():
		return ""
	return "%s:%s" % [kind, id]


func _on_inventory_cell_pressed(entry_key: String) -> void:
	if entry_key.is_empty():
		return
	if selected_inventory_item_keys.has(entry_key):
		selected_inventory_item_keys.erase(entry_key)
	else:
		selected_inventory_item_keys.append(entry_key)
	inventory_overlay.call("refresh_grid", self)


func _inventory_source_label(entry: Dictionary) -> String:
	var source := String(entry.get("source", ""))
	return source


func _inventory_entry_tooltip(entry: Dictionary) -> String:
	var lines: Array[String] = [
		String(entry.get("name", "")),
		"来源：%s" % _inventory_source_label(entry),
		"类型：%s" % String(entry.get("kind_label", ""))
	]
	if String(entry.get("kind", "")) == "product":
		var recipe_id := String(entry.get("id", ""))
		var variant_id := _selected_showcase_variant(recipe_id)
		var shape_info := _showcase_drag_shape_info(recipe_id, variant_id)
		lines.append("右键选择上架变体")
		lines.append("当前变体：%s｜%s｜%d格" % [
			_showcase_variant_label(variant_id),
			String(shape_info.get("default_shape", "1x1")),
			int(shape_info.get("cell_count", 1))
		])
	var restock_id := _restock_purchase_id_for_entry(entry)
	if not restock_id.is_empty():
		var ingredient: Dictionary = catalog.get_ingredients().get(restock_id, {})
		lines.append("补货：%s 库存 %d 价格 %d" % [
			_ingredient_name(restock_id),
			state.get_ingredient_count(restock_id),
			int(ingredient.get("price", 0))
		])
	return "\n".join(lines)


func _select_research_material_from_inventory(item_id: String) -> void:
	if pending_research_material_slot_index < 0 or item_id.is_empty():
		return
	while selected_research_material_ids.size() <= pending_research_material_slot_index:
		selected_research_material_ids.append("")
	for index in range(selected_research_material_ids.size()):
		if index != pending_research_material_slot_index and selected_research_material_ids[index] == item_id:
			selected_research_material_ids[index] = ""
	selected_research_material_ids[pending_research_material_slot_index] = item_id
	pending_research_material_slot_index = -1
	global_popup_return_mode = ""
	_show_research_global_popup()
	_refresh_current_page()
	_set_status("已选择研发材料：%s。" % _material_name(item_id))


func _inventory_page_count(entries: Array = []) -> int:
	if entries.is_empty():
		entries = _inventory_entries(selected_inventory_tab)
	return maxi(1, int(ceil(float(entries.size()) / float(INVENTORY_CELLS_PER_PAGE))))


func _inventory_entries(tab_id: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var ingredients := catalog.get_ingredients()
	if tab_id == "all" or tab_id == "ingredients" or tab_id == "seeds" or tab_id == "low_stock":
		for item_id in _sorted_keys(state.ingredient_inventory):
			var count: int = state.get_ingredient_count(item_id)
			if count > 0:
				var ingredient: Dictionary = ingredients.get(item_id, {})
				var ingredient_type := String(ingredient.get("type", "食材"))
				var is_seed := ingredient_type == "种子" or item_id.ends_with("_seed")
				var is_cultivation_input := is_seed or ingredient_type == "幼畜"
				var low_stock := count <= _low_stock_threshold_for_entry("ingredient", item_id)
				if tab_id == "ingredients" and is_cultivation_input:
					continue
				if tab_id == "seeds" and not is_cultivation_input:
					continue
				if tab_id == "low_stock" and not low_stock:
					continue
				entries.append({
					"kind": "ingredient",
					"kind_label": ingredient_type,
					"id": item_id,
					"name": _ingredient_name(item_id),
					"count": count,
					"source": String(ingredient.get("source", "库存"))
				})
	if tab_id == "all" or tab_id == "products" or tab_id == "low_stock":
		for recipe_id in _sorted_keys(state.product_inventory):
			var count: int = state.get_product_count(recipe_id)
			if count > 0:
				var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
				var low_stock := count <= _low_stock_threshold_for_entry("product", recipe_id)
				if tab_id == "low_stock" and not low_stock:
					continue
				entries.append({
					"kind": "product",
					"kind_label": "成品",
					"id": recipe_id,
					"name": _recipe_name(recipe_id),
					"count": count,
					"source": _device_name(String(recipe.get("device", "")))
				})
	if tab_id == "all" or tab_id == "tools":
		var tools := catalog.get_tools()
		for tool_id in _sorted_keys(state.tool_inventory):
			var count: int = state.get_tool_count(tool_id)
			if count <= 0:
				continue
			var tool: Dictionary = tools.get(tool_id, {})
			entries.append({"kind": "tool", "kind_label": "工具", "id": tool_id, "name": String(tool.get("name", tool_id)), "count": count, "source": "工具箱"})
	return _sorted_inventory_entries(_filtered_inventory_entries(entries))


func _filtered_inventory_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	if inventory_search_text.is_empty():
		return entries
	var result: Array[Dictionary] = []
	var needle := inventory_search_text.to_lower()
	for entry in entries:
		var haystack := "%s %s %s" % [
			String(entry.get("name", "")),
			String(entry.get("id", "")),
			String(entry.get("source", ""))
		]
		if haystack.to_lower().find(needle) != -1:
			result.append(entry)
	return result


func _sorted_inventory_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = entries.duplicate(true)
	match selected_inventory_sort:
		INVENTORY_SORT_COUNT:
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var left_count := int(a.get("count", 0))
				var right_count := int(b.get("count", 0))
				if left_count == right_count:
					return String(a.get("name", "")) < String(b.get("name", ""))
				return left_count > right_count
			)
		INVENTORY_SORT_NAME:
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var left_name := String(a.get("name", ""))
				var right_name := String(b.get("name", ""))
				if left_name == right_name:
					return _inventory_entry_key(a) < _inventory_entry_key(b)
				return left_name < right_name
			)
	return sorted


func _inventory_used_count() -> int:
	var total := 0
	for value: Variant in state.ingredient_inventory.values():
		total += maxi(0, int(value))
	for value: Variant in state.product_inventory.values():
		total += maxi(0, int(value))
	for value: Variant in state.tool_inventory.values():
		total += maxi(0, int(value))
	return total


func _inventory_low_stock_lines() -> Array[String]:
	var lines: Array[String] = []
	for line in _showcase_low_stock_lines():
		lines.append(line)
	for entry in _inventory_entries("low_stock"):
		lines.append("%s  %d/%d" % [
			String(entry.get("name", "")),
			int(entry.get("count", 0)),
			_low_stock_threshold_for_entry(String(entry.get("kind", "")), String(entry.get("id", "")))
		])
	return lines


func _inventory_restock_recommendation_lines() -> Array[String]:
	var result: Array[String] = []
	var ingredients := catalog.get_ingredients()
	for item_id in _sorted_keys(ingredients):
		var ingredient: Dictionary = ingredients.get(item_id, {})
		if int(ingredient.get("unlock_level", 0)) > state.level:
			continue
		var price := int(ingredient.get("price", 0))
		if price <= 0:
			continue
		var count: int = state.get_ingredient_count(item_id)
		if count >= 10:
			continue
		result.append("%s x%d  金币 %d" % [_ingredient_name(item_id), 10 - count, price * maxi(1, 10 - count)])
		if result.size() >= 6:
			break
	return result


func _low_stock_threshold_for_entry(kind: String, _id: String) -> int:
	match kind:
		"product":
			return 3
		"ingredient":
			return 10
	return 2


func _on_inventory_restock_pressed() -> void:
	if selected_inventory_item_keys.is_empty():
		_set_status("请先点击库存格子选择要补货的项目。")
		return

	var purchase_ids: Array[String] = []
	var missing_names: Array[String] = []
	for key in selected_inventory_item_keys:
		var entry := _inventory_entry_for_key(key)
		if entry.is_empty():
			continue
		var purchase_id := _restock_purchase_id_for_entry(entry)
		if purchase_id.is_empty():
			missing_names.append(String(entry.get("name", key)))
			continue
		purchase_ids.append(purchase_id)
	if purchase_ids.is_empty():
		_set_status("选中的库存没有可直接采购的补货项。")
		return

	var total_cost := _purchase_ids_total_cost(purchase_ids)
	if int(state.coins) < total_cost:
		_set_status("金币不足，无法一键补货：需要 %d，当前 %d。" % [total_cost, int(state.coins)])
		return

	var bought_names: Array[String] = []
	for purchase_id in purchase_ids:
		if _purchase_inventory_item(purchase_id, false):
			bought_names.append(_ingredient_name(purchase_id))
	_save_game()
	_refresh_resource_bar()
	inventory_overlay.call("refresh_grid", self)
	var status := "一键补货：%s。" % "、".join(bought_names)
	if not missing_names.is_empty():
		status += " 无法直接补货：%s。" % "、".join(missing_names)
	_set_status(status)


func _on_inventory_batch_list_pressed() -> void:
	_list_all_available_products()
	_save_game()
	inventory_overlay.call("refresh_grid", self)
	_refresh_storefront_showcase()


func _on_inventory_sell_extra_pressed() -> void:
	_set_status("出售多余功能已预留，本版先保留库存规则不变。")


func _on_inventory_organize_pressed() -> void:
	var sort_index := inventory_sort_button.selected
	if sort_index >= 0 and sort_index < inventory_sort_button.item_count:
		var sort_value: Variant = inventory_sort_button.get_item_metadata(sort_index)
		if sort_value != null:
			selected_inventory_sort = String(sort_value)
	selected_inventory_tab = "all"
	selected_inventory_page = 0
	inventory_search_input.text = ""
	inventory_search_text = ""
	_fill_inventory_tabs()
	inventory_overlay.call("refresh_grid", self)
	_set_status("库存已按%s整理显示。" % _inventory_sort_label(selected_inventory_sort))


func _inventory_sort_label(sort_id: String) -> String:
	match sort_id:
		INVENTORY_SORT_COUNT:
			return "数量"
		INVENTORY_SORT_NAME:
			return "名称"
	return "默认顺序"


func _inventory_entry_for_key(entry_key: String) -> Dictionary:
	for tab_id in INVENTORY_TAB_ORDER:
		for entry in _inventory_entries(tab_id):
			if _inventory_entry_key(entry) == entry_key:
				return entry
	return {}


func _restock_purchase_id_for_entry(entry: Dictionary) -> String:
	if String(entry.get("kind", "")) != "ingredient":
		return ""
	var item_id := String(entry.get("id", ""))
	var ingredient: Dictionary = catalog.get_ingredients().get(item_id, {})
	if ingredient.is_empty():
		return ""
	if _is_ingredient_available_for_purchase(item_id, ingredient):
		return item_id
	return _purchase_source_item_id_for_material(item_id, true)


func _purchase_ids_total_cost(item_ids: Array[String]) -> int:
	var total := 0
	var ingredients := catalog.get_ingredients()
	for item_id in item_ids:
		var ingredient: Dictionary = ingredients.get(item_id, {})
		total += int(ingredient.get("price", 0))
	return total


func _purchase_inventory_item(
	item_id: String,
	update_status: bool = true,
	ingredients: Dictionary = {}
) -> bool:
	var actual_ingredients := ingredients if not ingredients.is_empty() else catalog.get_ingredients()
	var ingredient: Dictionary = actual_ingredients.get(item_id, {})
	if not _is_ingredient_available_for_purchase(item_id, ingredient):
		if update_status:
			_set_status("该商品尚未解锁，无法采购。")
		return false
	var price := int(ingredient.get("price", 0))
	if int(state.coins) < price:
		if update_status:
			_set_status("金币不足，无法购买 %s。" % String(ingredient.get("name", item_id)))
		return false
	state.coins = int(state.coins) - price
	state.add_ingredient(item_id, 1)
	state.add_log("purchase:%s:%d" % [item_id, price])
	if update_status:
		_set_status("已购买 %s。" % String(ingredient.get("name", item_id)))
	return true


func _on_device_growth_upgrade_requested(device_id: String) -> void:
	var result: Dictionary = state.upgrade_device_growth(device_id)
	if not bool(result.get("ok", false)):
		_set_status("设备升级条件不足：还需有效使用 %d 次、金币 %d。" % [int(result.get("missing_uses", 0)), int(result.get("missing_coins", 0))])
		management_device_growth_page.refresh(state, catalog, device_id)
		storefront_manage_overlay.call("set_device_upgrade_badge", management_device_growth_page.upgrade_ready_count(state, catalog))
		return
	_save_game()
	_set_status("%s 已升至 L%d；%d 道配方已立即晋级，%d 道仍等待更高设备等级。" % [_device_name(device_id), int(result.get("upgraded_level", 1)), int(result.get("promoted_recipe_count", 0)), int(result.get("waiting_recipe_count", 0))])
	management_device_growth_page.refresh(state, catalog, device_id)
	storefront_manage_overlay.call("set_device_upgrade_badge", management_device_growth_page.upgrade_ready_count(state, catalog))
	_refresh_production_workbench()
	_refresh_resource_bar()


func _on_device_growth_catalog_filter_requested(device_id: String) -> void:
	selected_catalog_device_filter = device_id
	selected_catalog_filter = "all"
	selected_catalog_page = 0
	selected_catalog_recipe_id = ""
	_fill_catalog_filter_tabs()
	_fill_catalog_device_filter()
	_show_catalog_global_popup()


func _on_growth_detail_trait_requested(recipe_id: String) -> void:
	selected_catalog_recipe_id = recipe_id
	_maybe_show_pending_recipe_growth_choice(recipe_id)


func _fill_catalog_device_filter() -> void:
	catalog_device_filter.set_block_signals(true)
	catalog_device_filter.clear()
	var entries := [
		["all", "全部成品设备"],
		["round_pot", "蒸煮一体的圆锅"],
		["oven", "烤箱"],
		["chiller", "冷藏柜"],
		["griddle", "煎烤盘"],
		["mixer", "搅拌机"]
	]
	var selected_index := 0
	for entry in entries:
		var index := catalog_device_filter.item_count
		catalog_device_filter.add_item(String(entry[1]))
		catalog_device_filter.set_item_metadata(index, String(entry[0]))
		if String(entry[0]) == selected_catalog_device_filter:
			selected_index = index
	catalog_device_filter.select(selected_index)
	catalog_device_filter.set_block_signals(false)


func _on_catalog_device_filter_changed(index: int) -> void:
	if index < 0 or index >= catalog_device_filter.item_count:
		return
	selected_catalog_device_filter = String(catalog_device_filter.get_item_metadata(index))
	selected_catalog_page = 0
	selected_catalog_recipe_id = ""
	catalog_overlay.call("refresh_panel", self)


func _catalog_page_count(recipe_ids: Array[String] = []) -> int:
	if recipe_ids.is_empty():
		recipe_ids = _catalog_recipe_ids()
	return maxi(1, int(ceil(float(recipe_ids.size()) / float(CATALOG_CELLS_PER_PAGE))))


func _catalog_recipe_ids() -> Array[String]:
	var recipes := catalog.get_recipes()
	var by_level := {}
	for recipe_id in _sorted_keys(recipes):
		var recipe: Dictionary = recipes[recipe_id]
		if not _catalog_recipe_matches_filter(recipe_id, recipe):
			continue
		var unlock_level := int(recipe.get("unlock_level", 1))
		if not by_level.has(unlock_level):
			by_level[unlock_level] = []
		(by_level[unlock_level] as Array).append(recipe_id)
	var result: Array[String] = []
	for unlock_level in _sorted_int_keys(by_level):
		var ids: Array = by_level[unlock_level]
		ids.sort()
		for recipe_id in ids:
			result.append(String(recipe_id))
	return result


func _fill_catalog_filter_tabs() -> void:
	if catalog_filter_tabs.tab_count == CATALOG_FILTER_ORDER.size():
		catalog_filter_tabs.current_tab = maxi(0, CATALOG_FILTER_ORDER.find(selected_catalog_filter))
		return
	catalog_filter_tabs.set_block_signals(true)
	catalog_filter_tabs.clear_tabs()
	var labels := {
		"all": "全部",
		"sweet": "甜点",
		"drink": "饮品",
		"fruit": "水果",
		"bake": "烘焙",
		"new": "新品"
	}
	for filter_id in CATALOG_FILTER_ORDER:
		catalog_filter_tabs.add_tab(String(labels.get(filter_id, filter_id)))
		catalog_filter_tabs.set_tab_metadata(catalog_filter_tabs.tab_count - 1, filter_id)
	catalog_filter_tabs.current_tab = maxi(0, CATALOG_FILTER_ORDER.find(selected_catalog_filter))
	catalog_filter_tabs.set_block_signals(false)


func _on_catalog_filter_changed(index: int) -> void:
	if index < 0 or index >= catalog_filter_tabs.tab_count:
		return
	var metadata: Variant = catalog_filter_tabs.get_tab_metadata(index)
	if metadata == null:
		return
	selected_catalog_filter = String(metadata)
	selected_catalog_page = 0
	selected_catalog_recipe_id = ""
	catalog_overlay.call("refresh_panel", self)


func _catalog_recipe_matches_filter(recipe_id: String, recipe: Dictionary) -> bool:
	if selected_catalog_device_filter != "all" and String(recipe.get("device", "")) != selected_catalog_device_filter:
		return false
	match selected_catalog_filter:
		"sweet":
			return _recipe_tags(recipe).has("甜")
		"drink":
			return String(recipe.get("name", recipe_id)).find("饮") != -1 or String(recipe.get("name", recipe_id)).find("露") != -1
		"fruit":
			return _recipe_tags(recipe).has("果香") or _unlocked_recipe_material_text(recipe).find("草莓") != -1 or _unlocked_recipe_material_text(recipe).find("蓝莓") != -1
		"bake":
			var device_id := String(recipe.get("device", ""))
			return device_id == "oven" or device_id == "griddle"
		"new":
			return int(recipe.get("unlock_level", 1)) >= maxi(1, state.level)
	return true


func _recipe_tags(recipe: Dictionary) -> Array[String]:
	return _string_array_from_variant(recipe.get("tags", []))


func _make_catalog_cell(recipe_id: String, recipe: Dictionary) -> Button:
	var button := preload("res://scenes/ui/overlays/catalog_recipe_card.tscn").instantiate() as Button
	var recipe_icon := button.get_node("RecipeIcon") as TextureRect
	var stage_badge := button.get_node("StageBadge") as Label
	var masterwork_badge := button.get_node("MasterworkBadge") as Label
	var masterwork_glow := button.get_node("MasterworkGlow") as ColorRect
	var masterwork_frame := button.get_node("MasterworkFrame") as Panel
	var masterwork_seal := button.get_node("MasterworkSeal") as Label
	button.custom_minimum_size = CATALOG_CELL_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if recipe_id.is_empty() or recipe.is_empty():
		button.disabled = true
		button.text = ""
		recipe_icon.texture = null
		stage_badge.visible = false
		return button
	button.set_meta("recipe_id", recipe_id)
	var unlocked: bool = state != null and state.is_recipe_unlocked(recipe_id)
	button.disabled = not unlocked
	if unlocked:
		var growth: Dictionary = state.get_recipe_growth(recipe_id)
		var stage_level := int(growth.get("mastery_level", 0))
		stage_badge.text = ["试作", "人气", "招牌"][clampi(stage_level, 0, 2)]
		stage_badge.visible = true
		var masterwork_level := int(growth.get("masterwork_level", 0))
		masterwork_badge.visible = masterwork_level > 0
		masterwork_badge.text = "名作 L%d" % masterwork_level
		var milestone := RecipeGrowthService.masterwork_milestone(masterwork_level)
		masterwork_glow.visible = bool(milestone.get("glow", false))
		masterwork_frame.visible = not String(milestone.get("frame", "")).is_empty()
		if masterwork_frame.visible:
			masterwork_frame.add_theme_stylebox_override("panel", _masterwork_frame_style(String(milestone.get("frame", ""))))
		masterwork_seal.visible = bool(milestone.get("seal", false))
		var unlocked_text := "%s\n食材：%s\n工具：%s\n%s" % [
			String(recipe.get("name", recipe_id)),
			_unlocked_recipe_material_text(recipe),
			_device_name(String(recipe.get("device", ""))),
			_recipe_growth_detail_text(recipe_id)
		]
		button.text = ""
		button.tooltip_text = unlocked_text
		recipe_icon.texture = _recipe_icon_texture(recipe_id, "catalog")
	else:
		button.theme_type_variation = &"DessertItemSlotLocked"
		stage_badge.visible = false
		masterwork_badge.visible = false
		masterwork_glow.visible = false
		masterwork_frame.visible = false
		masterwork_seal.visible = false
		button.text = "待解锁 Lv.%d\n未解锁线索\n原料：%s\n工具：%s" % [
			int(recipe.get("unlock_level", 1)),
			_locked_recipe_material_text(recipe),
			_locked_device_hint(String(recipe.get("device", "")))
		]
		button.tooltip_text = button.text
		recipe_icon.texture = null
		button.add_theme_color_override("font_disabled_color", Color(0.42, 0.46, 0.52))
	button.toggle_mode = false
	if unlocked:
		button.pressed.connect(_on_catalog_recipe_cell_pressed.bind(recipe_id, button))
	return button


func _masterwork_frame_style(frame: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("f3c85b") if frame == "gold" else Color("b9c8d8")
	var width := 3 if frame == "gold" else 2
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style


func _on_catalog_recipe_cell_pressed(recipe_id: String, card: Button) -> void:
	selected_catalog_recipe_id = recipe_id
	catalog_overlay.call(
		"open_action_popup",
		recipe_id,
		_catalog_action_detail_text(recipe_id),
		_catalog_claimable_reward_amount(recipe_id),
		card.get_global_rect()
	)


func _on_catalog_prev_pressed() -> void:
	if selected_catalog_page <= 0:
		return
	selected_catalog_page -= 1
	catalog_overlay.call("refresh_panel", self)


func _on_catalog_next_pressed() -> void:
	var page_count := _catalog_page_count()
	if selected_catalog_page >= page_count - 1:
		return
	selected_catalog_page += 1
	catalog_overlay.call("refresh_panel", self)


func _refresh_catalog_summary() -> void:
	var recipes := catalog.get_recipes()
	var unlocked := 0
	for recipe_id in recipes.keys():
		if state != null and state.is_recipe_unlocked(String(recipe_id)):
			unlocked += 1
	var total := recipes.size()
	var percent := int(round(float(unlocked) / float(maxi(1, total)) * 100.0))
	catalog_collection_label.text = "收集进度 %d/%d" % [unlocked, total]
	catalog_star_label.text = "星级完成度 %d%%" % percent
	catalog_starlight_label.text = "食谱星辉 可用 %d｜累计 %d" % [state.recipe_starlight_available, state.recipe_starlight_total]
	catalog_reward_label.text = "收集奖励 %d/%d" % [unlocked, total]
	overlay_summary.text = "收集进度 %d/%d｜分类 %s｜设备 %s｜点击卡片查看详情" % [
		unlocked,
		total,
		_catalog_filter_label(selected_catalog_filter),
		"全部" if selected_catalog_device_filter == "all" else _device_name(selected_catalog_device_filter)
	]
	catalog_overlay.call("refresh_milestones", unlocked, total, state.claimed_starlight_rewards)
	catalog_overlay.call("refresh_claim_actions", StarProgressionService.claimable_recipe_rewards(state).size())


func _catalog_filter_label(filter_id: String) -> String:
	var labels := {
		"all": "全部",
		"sweet": "甜点",
		"drink": "饮品",
		"fruit": "水果",
		"bake": "烘焙",
		"new": "新品"
	}
	return String(labels.get(filter_id, filter_id))


func _catalog_action_detail_text(recipe_id: String) -> String:
	var recipes := catalog.get_recipes()
	if recipe_id.is_empty() or not recipes.has(recipe_id):
		return ""
	var recipe: Dictionary = recipes.get(recipe_id, {})
	var tags := _recipe_tags(recipe)
	var tag_text := "、".join(tags) if not tags.is_empty() else "暂无"
	return "名称：%s\n售价：金币 %d\n标签：%s\n食材：%s\n工具：%s\n解锁来源：Lv.%d 或研发解锁\n首次售卖加成：+30%%\n顾客偏好：学生、上班族、探店客\n组合关联：\n%s\n成长状态：%s" % [
		String(recipe.get("name", recipe_id)),
		int(recipe.get("price", 0)),
		tag_text,
		_unlocked_recipe_material_text(recipe),
		_device_name(String(recipe.get("device", ""))),
		int(recipe.get("unlock_level", 1)),
		_catalog_combo_text(recipe_id, recipe),
		_recipe_growth_detail_text(recipe_id)
	]


func _catalog_claimable_reward_amount(recipe_id: String) -> int:
	var claimable_rewards := StarProgressionService.claimable_recipe_rewards(state, recipe_id)
	var claimable_amount := 0
	for reward_value: Variant in claimable_rewards:
		if reward_value is Dictionary:
			claimable_amount += maxi(0, int((reward_value as Dictionary).get("amount", 0)))
	return claimable_amount


func _refresh_catalog_action_popup(recipe_id: String) -> void:
	catalog_overlay.call(
		"refresh_action_popup",
		recipe_id,
		_catalog_action_detail_text(recipe_id),
		_catalog_claimable_reward_amount(recipe_id)
	)


func _catalog_combo_text(recipe_id: String, recipe: Dictionary) -> String:
	var parts: Array[String] = []
	var materials_value: Variant = recipe.get("materials", [])
	if materials_value is Array:
		for material_id_value in materials_value:
			var material_id := String(material_id_value)
			if catalog.get_recipes().has(material_id):
				parts.append("%s → %s" % [_recipe_name(material_id), _recipe_name(recipe_id)])
	if parts.is_empty():
		parts.append("%s → %s" % [_device_name(String(recipe.get("device", ""))), _recipe_name(recipe_id)])
	return "\n".join(parts)


func _on_catalog_make_pressed(recipe_id: String = "") -> void:
	if not recipe_id.is_empty():
		selected_catalog_recipe_id = recipe_id
	if selected_catalog_recipe_id.is_empty():
		return
	_close_global_popup()
	_show_page(PAGE_PRODUCTION)
	_set_status("已切换到制作区域，准备制作 %s。" % _recipe_name(selected_catalog_recipe_id))


func _on_catalog_claim_reward_pressed(recipe_id: String) -> void:
	if state == null or recipe_id.is_empty():
		return
	var result: Dictionary = state.claim_recipe_starlight(recipe_id)
	if not bool(result.get("ok", false)):
		_set_status("该配方暂无可领取的食谱星辉。")
		catalog_overlay.call("refresh_panel", self, true)
		_refresh_catalog_action_popup(recipe_id)
		return
	var amount := int(result.get("amount", 0))
	state.enqueue_notification("食谱星辉已入账", "%s 的已达成奖励：+%d 星辉。" % [_recipe_name(recipe_id), amount])
	_save_game()
	_refresh_resource_bar()
	catalog_overlay.call("refresh_panel", self, true)
	_refresh_catalog_action_popup(recipe_id)
	_set_status("已领取 %d 食谱星辉。" % amount)
	_show_next_notification()


func _on_catalog_claim_all_rewards_pressed() -> void:
	if state == null:
		return
	var result: Dictionary = state.claim_recipe_starlight()
	if not bool(result.get("ok", false)):
		_set_status("当前没有可领取的食谱星辉。")
		catalog_overlay.call("refresh_panel", self)
		return
	var amount := int(result.get("amount", 0))
	state.enqueue_notification("星辉奖励已汇总", "本次共领取 %d 食谱星辉。" % amount)
	_save_game()
	_refresh_resource_bar()
	catalog_overlay.call("refresh_panel", self)
	_set_status("已一键领取 %d 食谱星辉。" % amount)
	_show_next_notification()


func _on_catalog_milestone_claim_pressed(percent: int) -> void:
	if state == null:
		return
	var result: Dictionary = state.claim_catalog_milestone(percent)
	if not bool(result.get("ok", false)):
		_set_status("该图鉴里程碑尚未达成或已经领取。")
		catalog_overlay.call("refresh_panel", self)
		return
	var amount := int(result.get("amount", 0))
	state.enqueue_notification("图鉴里程碑达成", "%d%% 图鉴里程碑：+%d 星辉。" % [percent, amount])
	_save_game()
	_refresh_resource_bar()
	catalog_overlay.call("refresh_panel", self)
	_set_status("已领取 %d%% 图鉴里程碑。" % percent)
	_show_next_notification()


func _on_automation_upgrade_requested(upgrade_id: String) -> void:
	if state == null or upgrade_id.is_empty():
		return
	var result: Dictionary = state.purchase_automation_upgrade(upgrade_id)
	if not bool(result.get("ok", false)):
		_set_status(_automation_upgrade_failure_text(result))
		_refresh_automation_overlay()
		return
	var cost := int(result.get("cost", 0))
	var upgrade_name := _automation_upgrade_name(upgrade_id)
	state.enqueue_notification("自动化升级完成", "%s 已生效，消耗 %d 星辉。" % [upgrade_name, cost])
	_save_game()
	_refresh_resource_bar()
	_refresh_automation_overlay()
	_set_status("已购买%s。" % upgrade_name)
	_show_next_notification()


func _on_automation_pause_all_requested() -> void:
	if state == null:
		return
	var paused := not bool(state.automation_paused)
	AutomationService.set_global_paused(state, paused)
	state.enqueue_notification("自动化已暂停" if paused else "自动化已恢复", "产地与厨房自动化已全部暂停。" if paused else "产地与厨房自动化将从当前时间继续。")
	_save_game()
	_refresh_current_page()
	_refresh_automation_overlay()
	_set_status("已暂停全部自动化。" if paused else "已恢复全部自动化。")
	_show_next_notification()


func _on_kitchen_rule_save_requested(rule: Dictionary) -> void:
	if state == null:
		return
	var result: Dictionary = AutomationService.save_kitchen_rule(state, rule)
	if not bool(result.get("ok", false)):
		kitchen_automation_panel.call("show_service_result", result, "save")
		_set_status("厨房排程未保存：%s" % String(result.get("reason", "unknown")))
		return
	var saved_rule: Dictionary = result.get("rule", {}) if result.get("rule", {}) is Dictionary else {}
	var rule_id := String(saved_rule.get("id", ""))
	_save_game()
	_refresh_current_page()
	kitchen_automation_panel.call("focus_rule", rule_id)
	kitchen_automation_panel.call("show_service_result", result, "save")
	_set_status("厨房排程已保存，配方列表与规则状态已刷新。")


func _on_kitchen_rule_remove_requested(rule_id: String) -> void:
	if state == null or rule_id.is_empty():
		return
	var removed := AutomationService.remove_kitchen_rule(state, rule_id)
	var result := {"ok": removed, "reason": "" if removed else "not_found"}
	if removed:
		_save_game()
		_refresh_current_page()
		kitchen_automation_panel.call("focus_rule", "")
	kitchen_automation_panel.call("show_service_result", result, "remove")
	_set_status("厨房排程已移除。" if removed else "厨房排程未移除：规则已不存在。")


func _on_kitchen_pause_toggled(paused: bool) -> void:
	if state == null:
		return
	AutomationService.set_global_paused(state, paused)
	_save_game()
	_refresh_current_page()
	_set_status("已暂停产地与厨房自动化。" if paused else "已恢复全部自动化，将从当前时间继续。")


func _automation_upgrade_name(upgrade_id: String) -> String:
	var names := {
		"output_capacity_1": "托管扩容 I",
		"offline_duration_1": "离线延长 I",
		"output_capacity_2": "托管扩容 II",
		"offline_duration_2": "离线延长 II",
		"output_capacity_all": "全产地托管",
		"kitchen_devices_2": "双设备排程",
		"kitchen_rules_3": "规则扩容",
		"kitchen_priority": "优先级排程",
		"kitchen_inventory_policy": "库存策略",
		"kitchen_all": "全厨房托管"
	}
	return String(names.get(upgrade_id, upgrade_id))


func _automation_upgrade_failure_text(result: Dictionary) -> String:
	match String(result.get("reason", "")):
		"already_purchased":
			return "该自动化升级已购买。"
		"feature_locked":
			return "请先完成对应功能任务，解锁自动化。"
		"missing_prerequisite":
			return "请先购买前置自动化升级。"
		"insufficient_starlight":
			return "食谱星辉不足，还差 %d。" % maxi(0, int(result.get("missing", 0)))
		_:
			return "该自动化升级暂时无法购买。"


func _unlocked_recipe_material_text(recipe: Dictionary) -> String:
	var counts := {}
	var materials_value: Variant = recipe.get("materials", [])
	if materials_value is Array:
		for material_id_value in materials_value:
			var material_id := String(material_id_value)
			counts[material_id] = int(counts.get(material_id, 0)) + 1
	var parts: Array[String] = []
	for material_id in _sorted_keys(counts):
		parts.append("%s x%d" % [_material_name(material_id), int(counts[material_id])])
	return "、".join(parts)


func _locked_recipe_material_text(recipe: Dictionary) -> String:
	var parts: Array[String] = []
	var materials_value: Variant = recipe.get("materials", [])
	if materials_value is Array:
		for material_id_value in materials_value:
			parts.append(_mystery_material_description(String(material_id_value)))
	return "、".join(parts)


func _mystery_material_description(material_id: String) -> String:
	var descriptions := {
		"apple": "一种红色果子",
		"banana": "一种黄色果子",
		"blueberry": "一种蓝色果子",
		"strawberry": "一种红色浆果",
		"lemon": "一种酸香果子",
		"rice": "一种朴素谷物",
		"rice_seed": "一种农作种子",
		"spring_water": "一种清澈水源",
		"sea_salt": "一种海边调味",
		"flour": "一种白色基底",
		"egg": "一枚养殖场食材",
		"milk": "一种白色乳饮",
		"butter": "一种金色乳制品",
		"cream": "一种白色乳制品",
		"sugar": "一种甜味调料",
		"chocolate": "一种苦甜风味",
		"matcha": "一种绿色风味",
		"coffee": "一种深色风味",
		"red_bean": "一种红色农作",
		"cheese": "一种浓郁乳制品",
		"honey": "一种金色农作",
		"nuts": "一种香脆配料",
		"yogurt": "一种清爽乳制品",
		"cocoa": "一种可可风味"
	}
	if descriptions.has(material_id):
		return String(descriptions[material_id])
	if catalog.get_recipes().has(material_id):
		return "一种已制作甜品"
	return "一种未知材料"


func _locked_device_hint(device_id: String) -> String:
	var device: Dictionary = catalog.get_devices().get(device_id, {})
	var meaning := String(device.get("research_meaning", ""))
	if not meaning.is_empty():
		return "%s类工具" % meaning
	var usage := String(device.get("usage", ""))
	if not usage.is_empty():
		return usage
	return "未知工具线索"


func _task_global_text() -> String:
	if state != null and state.has_method("get_task_snapshot"):
		return TaskService.format_task_panel(state)

	var lines: Array[String] = ["任务"]
	if state.completed_tasks.is_empty():
		lines.append("已完成：暂无")
	else:
		lines.append("已完成：%s" % "、".join(state.completed_tasks))
	if state.pending_notifications.is_empty():
		lines.append("待领取提示：暂无")
	else:
		lines.append("待领取提示：%d 条" % state.pending_notifications.size())
	return "\n".join(lines)


func _show_next_notification() -> void:
	if task_popup.visible \
			or research_progress_dialog.visible \
			or automation_report_dialog.visible \
			or purchase_receipt_dialog.visible \
			or state == null:
		return
	if bool(state.pending_automation_report.get("ui_displaying", false)):
		_show_automation_report(state.pending_automation_report)
		return
	if state.pending_notifications.is_empty():
		return

	var notification: Dictionary = state.pop_notification()
	var metadata: Dictionary = notification.get("metadata", {}) if notification.get("metadata", {}) is Dictionary else {}
	if String(metadata.get("kind", "")) == "automation_report" and metadata.get("report", {}) is Dictionary:
		state.pending_automation_report = (metadata.get("report", {}) as Dictionary).duplicate(true)
		state.pending_automation_report["ui_displaying"] = true
		_save_game()
		_show_automation_report(state.pending_automation_report)
		return
	var notification_title := String(notification.get("title", "任务完成"))
	var notification_body := String(notification.get("body", ""))
	task_popup.title = notification_title
	task_popup.dialog_text = notification_body
	task_popup_title_label.text = notification_title
	task_popup_body_label.text = notification_body
	task_popup.min_size = TASK_POPUP_MIN_SIZE
	if task_popup.is_inside_tree():
		task_popup.popup_centered(TASK_POPUP_MIN_SIZE)
	else:
		task_popup.size = TASK_POPUP_MIN_SIZE
		task_popup.visible = true
	_save_game()


func _on_purchase_receipt_visibility_changed() -> void:
	if purchase_receipt_dialog.visible:
		return
	if purchase_page_refresh_pending:
		purchase_page_refresh_pending = false
		if global_popup_mode == "purchase":
			_refresh_purchase_page()
	if purchase_receipt_suspended_task_popup:
		purchase_receipt_suspended_task_popup = false
		if task_popup.is_inside_tree():
			task_popup.popup_centered(TASK_POPUP_MIN_SIZE)
		else:
			task_popup.visible = true
		return
	call_deferred("_show_next_notification")


func _on_task_popup_confirmed() -> void:
	_show_next_notification()


func _show_automation_report(report: Dictionary) -> void:
	task_popup.hide()
	automation_report_dialog.call("configure", report)
	if automation_report_dialog.is_inside_tree():
		automation_report_dialog.popup_centered()
	else:
		automation_report_dialog.visible = true


func _on_automation_report_closed() -> void:
	_finish_automation_report()


func _on_automation_report_navigate_requested(kind: String, key: String) -> void:
	match kind:
		"output":
			var parts := key.split(":")
			var target_site_id := String(parts[0]) if not parts.is_empty() else ""
			var target_slot_index := int(parts[1]) if parts.size() > 1 and String(parts[1]).is_valid_int() else -1
			if OUTPUT_SITE_ORDER.has(target_site_id):
				selected_output_site_id = target_site_id
			if target_slot_index >= 0:
				output_site_pages[selected_output_site_id] = clampi(
					target_slot_index / OUTPUT_SITE_CELLS_PER_PAGE,
					0,
					OUTPUT_SITE_PAGE_COUNT - 1
				)
			_show_page(PAGE_OUTPUT)
			var slot_array_index := _slot_array_index_for_site_slot(selected_output_site_id, target_slot_index)
			if slot_array_index >= 0:
				_select_output_slot(target_slot_index, slot_array_index)
			elif target_slot_index >= 0:
				_select_idle_output_slot(target_slot_index)
			_set_status("已前往%s %d 号槽处理暂停原因。" % [_site_name(selected_output_site_id), target_slot_index + 1])
		"kitchen":
			_show_page(PAGE_PRODUCTION)
			kitchen_automation_panel.call("focus_rule", key)
			_set_status("已展开厨房排程，请补充原料或调整规则。")
		"system":
			_set_status("本次离线结算已到时间或事件上限；关闭简报后，自动化将从当前进度继续。")
		_:
			_set_status("简报已读。")
	_finish_automation_report()


func _finish_automation_report() -> void:
	automation_report_dialog.hide()
	if state != null:
		state.pending_automation_report = {}
		_save_game()
	_show_next_notification()


func _sorted_keys(value: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key in value.keys():
		keys.append(String(key))
	keys.sort()
	return keys


func _sorted_int_keys(value: Dictionary) -> Array[int]:
	var keys: Array[int] = []
	for key in value.keys():
		keys.append(int(key))
	keys.sort()
	return keys


func _ingredient_name(item_id: String) -> String:
	var ingredient: Dictionary = catalog.get_ingredients().get(item_id, {})
	return String(ingredient.get("name", item_id))


func _recipe_name(recipe_id: String) -> String:
	var recipe: Dictionary = catalog.get_recipes().get(recipe_id, {})
	return String(recipe.get("name", recipe_id))


func _tool_name(tool_id: String) -> String:
	var tool: Dictionary = catalog.get_tools().get(tool_id, {})
	return String(tool.get("name", tool_id))


func _recipe_growth_label(recipe_id: String) -> String:
	if state == null or not state.has_method("recipe_growth_stage_name"):
		return ""
	var label: String = state.recipe_growth_stage_name(recipe_id)
	if label == "试作品":
		return ""
	return label


func _recipe_growth_detail_text(recipe_id: String) -> String:
	if state == null or not state.has_method("get_recipe_growth"):
		return "成长阶段：试作品"
	var growth: Dictionary = state.get_recipe_growth(recipe_id)
	var stage: String = state.recipe_growth_stage_name(recipe_id) if state.has_method("recipe_growth_stage_name") else RecipeGrowthService.mastery_name(int(growth.get("mastery_level", 0)))
	var available_trait_labels := RecipeGrowthService.trait_labels(growth.get("available_traits", growth.get("display_traits", [])))
	var selected_trait_labels := RecipeGrowthService.trait_labels(growth.get("selected_traits", growth.get("selected_display_traits", [])))
	var available_trait_text := "无" if available_trait_labels.is_empty() else "、".join(available_trait_labels)
	var selected_trait_text := "无" if selected_trait_labels.is_empty() else "、".join(selected_trait_labels)
	var pending_text := "\n待选择特性：是" if bool(growth.get("pending_trait_choice", false)) else ""
	var status: Dictionary = state.recipe_growth_status(recipe_id) if state.has_method("recipe_growth_status") else {}
	var waiting_text := "\n设备状态：条件已达成，等待下一次成功制作" if bool(status.get("waiting_for_device", false)) else ""
	var masterwork_level := int(growth.get("masterwork_level", 0))
	var masterwork_text := "未开启" if masterwork_level <= 0 else "Lv.%d（经验 %.1f）" % [masterwork_level, int(growth.get("masterwork_xp_tenths", 0)) / 10.0]
	return "成长阶段：%s\n制作：%d 售卖：%d 相邻：%d\n名作：%s\n候选特性：%s\n已选特性：%s%s%s" % [
		stage,
		int(growth.get("made_count", 0)),
		int(growth.get("sold_count", 0)),
		int(growth.get("adjacency_trigger_count", 0)),
		masterwork_text,
		available_trait_text,
		selected_trait_text,
		pending_text,
		waiting_text
	]


func _site_name(site_id: String) -> String:
	var site: Dictionary = catalog.get_production_sites().get(site_id, {})
	return String(site.get("name", site_id))


func _device_name(device_id: String) -> String:
	var device: Dictionary = catalog.get_devices().get(device_id, {})
	return String(device.get("name", device_id))


func _material_name(material_id: String) -> String:
	if catalog.get_ingredients().has(material_id):
		return _ingredient_name(material_id)
	return _recipe_name(material_id)


func _string_array_from_variant(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value:
		result.append(String(item))
	return result


func _material_names(materials_value: Variant) -> String:
	if not materials_value is Array:
		return ""
	var names: Array[String] = []
	for material_id in materials_value:
		names.append(_material_name(String(material_id)))
	return ", ".join(names)


func _material_stock_requirements(materials_value: Variant, amount_per_material: int = 1) -> String:
	if not materials_value is Array:
		return ""
	var required_by_id := {}
	var ordered_ids: Array[String] = []
	for material_value in materials_value:
		var material_id := String(material_value)
		if material_id.is_empty():
			continue
		if not required_by_id.has(material_id):
			required_by_id[material_id] = 0
			ordered_ids.append(material_id)
		required_by_id[material_id] = int(required_by_id[material_id]) + maxi(1, amount_per_material)

	var parts: Array[String] = []
	for material_id in ordered_ids:
		parts.append("%s %d/%d" % [
			_material_name(material_id),
			_material_stock(material_id),
			int(required_by_id.get(material_id, amount_per_material))
		])
	return ", ".join(parts)


func _purchase_tooltip(item_id: String, ingredient: Dictionary) -> String:
	var usage := _research_usage_names(item_id)
	if usage.is_empty():
		usage = "暂无已知配方"
	return "来源：%s\n可用于研发：%s" % [
		String(ingredient.get("source", "")),
		usage
	]


func _research_usage_names(item_id: String) -> String:
	var names: Array[String] = []
	var recipes := catalog.get_recipes()
	for recipe_id in _sorted_keys(recipes):
		var recipe: Dictionary = recipes[recipe_id]
		if int(recipe.get("unlock_level", 1)) > state.level:
			continue
		var materials_value: Variant = recipe.get("materials", [])
		if not materials_value is Array:
			continue
		var materials: Array = materials_value as Array
		if materials.has(item_id):
			names.append(String(recipe.get("name", recipe_id)))
	return "、".join(names)


func _material_stock(material_id: String) -> int:
	if catalog.get_ingredients().has(material_id):
		return state.get_ingredient_count(material_id)
	return state.get_product_count(material_id)


func _first_display_slot_index() -> int:
	_ensure_showcase_slot_count()
	for index in range(state.display_slots.size()):
		if _is_showcase_slot_unlocked(index) and state.display_slots[index] == null:
			return index
	return -1
