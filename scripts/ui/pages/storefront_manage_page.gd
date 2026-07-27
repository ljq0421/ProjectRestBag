extends VBoxContainer

signal settle_showcase_requested()
signal expand_showcase_requested()

const TAB_OVERVIEW := "overview"
const TAB_STRATEGY := "strategy"
const TAB_DEVICE_GROWTH := "device_growth"

@onready var overview_tab: Button = $StorefrontManagePanel/ManagementCenterTabs/OverviewTab
@onready var strategy_tab: Button = $StorefrontManagePanel/ManagementCenterTabs/StrategyTab
@onready var device_growth_tab: Button = $StorefrontManagePanel/ManagementCenterTabs/DeviceGrowthTab
@onready var overview_page: VBoxContainer = $StorefrontManagePanel/ManagementCenterPages/OverviewPage
@onready var strategy_page: VBoxContainer = $StorefrontManagePanel/ManagementCenterPages/StrategyPage
@onready var device_growth_page: DeviceGrowthCenterPage = $StorefrontManagePanel/ManagementCenterPages/DeviceGrowthPage

var _device_upgrade_ready_count := 0


func _ready() -> void:
	overview_tab.pressed.connect(show_tab.bind(TAB_OVERVIEW))
	strategy_tab.pressed.connect(show_tab.bind(TAB_STRATEGY))
	device_growth_tab.pressed.connect(show_tab.bind(TAB_DEVICE_GROWTH))
	reset_to_default_tab()


func refresh(_state, _catalog, _receipt_text: String, _feedback_text: String) -> void:
	pass


func reset_to_default_tab() -> void:
	show_tab(TAB_OVERVIEW)


func show_tab(tab_id: String) -> void:
	var resolved_tab := tab_id if tab_id in [TAB_OVERVIEW, TAB_STRATEGY, TAB_DEVICE_GROWTH] else TAB_OVERVIEW
	overview_page.visible = resolved_tab == TAB_OVERVIEW
	strategy_page.visible = resolved_tab == TAB_STRATEGY
	device_growth_page.visible = resolved_tab == TAB_DEVICE_GROWTH
	overview_tab.button_pressed = resolved_tab == TAB_OVERVIEW
	strategy_tab.button_pressed = resolved_tab == TAB_STRATEGY
	device_growth_tab.button_pressed = resolved_tab == TAB_DEVICE_GROWTH


func set_device_upgrade_badge(ready_count: int) -> void:
	_device_upgrade_ready_count = maxi(0, ready_count)
	device_growth_tab.text = "设备培养　%d 可升级" % _device_upgrade_ready_count if _device_upgrade_ready_count > 0 else "设备培养"
	device_growth_tab.tooltip_text = "%d 台设备可升级" % _device_upgrade_ready_count if _device_upgrade_ready_count > 0 else "查看全部设备的培养进度"
