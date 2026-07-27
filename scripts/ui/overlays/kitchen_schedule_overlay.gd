class_name KitchenScheduleOverlay
extends VBoxContainer


func panel() -> Control:
	return $KitchenAutomationPanel


func refresh(state) -> void:
	$KitchenAutomationPanel.call("refresh", state)
	$KitchenAutomationPanel.call("focus_rule", "")
