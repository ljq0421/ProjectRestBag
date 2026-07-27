extends PanelContainer

const SITE_IMAGE_DIRECTORY := "res://resources/ui/output_v1"

var title: Label
var site_image: TextureRect
var automation_toggle: CheckButton
var prev_button: Button
var page_label: Label
var next_button: Button
var summary_list: VBoxContainer
var grid: GridContainer

var _view
var _site_id := ""
var _summary_signature := ""


func configure(view, site_id: String) -> void:
	_bind_nodes()
	_view = view
	_site_id = site_id
	_summary_signature = ""
	set_meta("site_id", site_id)
	var access_locked := not bool(view.call("_is_output_site_available", site_id))
	set_meta("access_locked", access_locked)
	tooltip_text = String(view.call("_output_site_locked_text", site_id)) if access_locked else ""
	title.text = String(view.call("_site_region_title", site_id))
	title.tooltip_text = title.text
	_set_site_image(site_id)
	view.output_site_title_labels[site_id] = title
	automation_toggle.visible = not access_locked and bool(view.call("_is_output_site_automation_available"))
	automation_toggle.set_pressed_no_signal(bool(view.call("_is_output_site_managed", site_id)))
	automation_toggle.tooltip_text = String(view.call("_output_site_automation_tooltip", site_id))
	prev_button.disabled = not bool(view.call("_is_output_site_prev_page_available", site_id))
	page_label.text = String(view.call("_output_site_page_label", site_id))
	next_button.disabled = not bool(view.call("_is_output_site_next_page_available", site_id))
	view.output_site_grids[site_id] = grid
	view.call("_populate_output_site_grid", site_id, grid)
	refresh_production_summary()


func refresh_production_summary(now_unix: int = -1) -> void:
	if _view == null or _site_id.is_empty():
		return
	if not bool(_view.call("_is_output_site_available", _site_id)):
		var locked_signature := "locked:%s" % String(_view.call("_output_site_locked_text", _site_id))
		if locked_signature == _summary_signature:
			return
		_summary_signature = locked_signature
		_clear_summary_list()
		var locked_label := Label.new()
		locked_label.text = String(_view.call("_output_site_locked_text", _site_id))
		locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		locked_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		summary_list.add_child(locked_label)
		return
	var summary_value: Variant = _view.call("_output_site_production_summary", _site_id, now_unix)
	var summary_signature := JSON.stringify(summary_value)
	if summary_signature == _summary_signature:
		return
	_summary_signature = summary_signature
	_clear_summary_list()
	if not summary_value is Array or (summary_value as Array).is_empty():
		var empty_label := Label.new()
		empty_label.text = "尚未开始生产"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.add_theme_font_size_override("font_size", 14)
		summary_list.add_child(empty_label)
		return

	for entry_value: Variant in summary_value as Array:
		summary_list.add_child(_make_summary_line(entry_value))


func _ready() -> void:
	_bind_nodes()
	if not prev_button.pressed.is_connected(_on_prev_pressed):
		prev_button.pressed.connect(_on_prev_pressed)
	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)
	if not automation_toggle.toggled.is_connected(_on_automation_toggled):
		automation_toggle.toggled.connect(_on_automation_toggled)


func _on_prev_pressed() -> void:
	if _view != null:
		_view.call("_change_output_site_page", _site_id, -1)


func _on_next_pressed() -> void:
	if _view != null:
		_view.call("_change_output_site_page", _site_id, 1)


func _on_automation_toggled(managed: bool) -> void:
	if _view != null:
		_view.call("_on_output_site_automation_toggled", _site_id, managed)


func _set_site_image(site_id: String) -> void:
	var image_path := "%s/%s.png" % [SITE_IMAGE_DIRECTORY, site_id]
	if ResourceLoader.exists(image_path):
		site_image.texture = load(image_path) as Texture2D
	else:
		site_image.texture = null


func _make_summary_line(entry_value: Variant) -> Label:
	var entry: Dictionary = entry_value if entry_value is Dictionary else {}
	var item_name := String(entry.get("name", entry.get("item_id", "")))
	var ready_amount := maxi(0, int(entry.get("ready_amount", 0)))
	var producing_amount := maxi(0, int(entry.get("producing_amount", 0)))
	var status_parts: Array[String] = []
	if ready_amount > 0:
		status_parts.append("待收获 %d" % ready_amount)
	if producing_amount > 0:
		status_parts.append("生产中 %d" % producing_amount)
	var line := Label.new()
	line.name = "ItemLine"
	line.custom_minimum_size = Vector2(100, 20)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("font_size", 14)
	line.text = "%s · %s" % [item_name, " / ".join(status_parts)]
	line.tooltip_text = line.text
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return line


func _clear_summary_list() -> void:
	for child in summary_list.get_children():
		summary_list.remove_child(child)
		child.queue_free()


func _bind_nodes() -> void:
	if title != null:
		return
	title = $OutputSiteBox/OutputSiteBody/SiteIdentityColumn/OutputSiteTitle
	site_image = $OutputSiteBox/OutputSiteBody/SiteIdentityColumn/OutputSiteImage
	prev_button = $OutputSiteBox/OutputSiteBody/PlotColumn/OutputSitePager/OutputPrevPageButton
	page_label = $OutputSiteBox/OutputSiteBody/PlotColumn/OutputSitePager/OutputPageLabel
	next_button = $OutputSiteBox/OutputSiteBody/PlotColumn/OutputSitePager/OutputNextPageButton
	automation_toggle = $OutputSiteBox/OutputSiteBody/ProductionSummaryPanel/ProductionSummaryBox/ProductionSummaryHeader/OutputSiteAutomationToggle
	summary_list = $OutputSiteBox/OutputSiteBody/ProductionSummaryPanel/ProductionSummaryBox/ProductionSummaryList
	grid = $OutputSiteBox/OutputSiteBody/PlotColumn/OutputSiteGrid
