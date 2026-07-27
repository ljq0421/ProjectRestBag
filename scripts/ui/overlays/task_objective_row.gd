extends HBoxContainer


func configure(objective: Dictionary) -> void:
	var completed := bool(objective.get("completed", false))
	$StateLabel.text = "✓" if completed else "○"
	$StateLabel.modulate = Color(0.35, 0.78, 0.45) if completed else Color(0.72, 0.72, 0.72)
	$ObjectiveLabel.text = String(objective.get("title", objective.get("id", "目标")))
	$ProgressLabel.text = "已完成" if completed else "%d/%d" % [
		maxi(0, int(objective.get("count", 0))),
		maxi(1, int(objective.get("goal", 1)))
	]
