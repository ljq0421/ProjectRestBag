extends VBoxContainer

signal start_output_requested(site_id: String, item_id: String, slot_index: int)
signal harvest_requested(site_id: String, slot_index: int, slot_array_index: int)
signal harvest_all_requested()
signal accelerator_menu_requested(site_id: String, slot_index: int, global_position: Vector2)
signal output_context_action_requested(action_id: int)

const OutputSiteRegionScene := preload("res://scenes/ui/pages/output_site_region.tscn")


func refresh(_state, _catalog, _now_unix: int) -> void:
	pass


func clear_context_menu() -> void:
	pass


func selected_site_id() -> String:
	return ""


func create_site_region(view, site_id: String) -> PanelContainer:
	var panel := OutputSiteRegionScene.instantiate()
	panel.call("configure", view, site_id)
	return panel
