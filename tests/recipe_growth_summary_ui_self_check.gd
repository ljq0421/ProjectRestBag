extends SceneTree

const ProductionQueueRecipeRowScene := preload("res://scenes/ui/pages/production_queue_recipe_row.tscn")
const ShowcaseRulebookDialog := preload("res://scripts/ui/overlays/showcase_rulebook_dialog.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_production_row_focus()
	_test_rulebook_growth_copy()
	_finish()


func _test_production_row_focus() -> void:
	var row := ProductionQueueRecipeRowScene.instantiate()
	_expect(row.get_node_or_null("Content/RecipeNameLabel") is Label, "production row should keep recipe identity visible")
	_expect(row.get_node_or_null("Content/MaterialStrip") is Control, "production row should clip materials within the fixed queue width")
	_expect(
		row.get_node_or_null("Content/MaterialStrip/MaterialItems") is HFlowContainer,
		"production row should wrap material readiness within the fixed strip"
	)
	_expect(row.get_node_or_null("Content/ActionButton") is Button, "production row should keep its contextual action")
	_expect(row.find_child("RecipeGrowthSummaryLabel", true, false) == null, "production queue should not crowd action rows with growth metadata")
	row.free()


func _test_rulebook_growth_copy() -> void:
	var dialog := ShowcaseRulebookDialog.new()
	var growth_text := String(dialog.call("_growth_text"))
	_expect(growth_text.find("试作品") >= 0, "rulebook should expose the trial stage")
	_expect(growth_text.find("人气款") >= 0, "rulebook should expose the popular stage")
	_expect(growth_text.find("招牌款") >= 0, "rulebook should expose the signature stage")
	_expect(growth_text.find("稳定款") == -1, "rulebook growth copy should not mention the removed stable stage")
	dialog.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("RECIPE_GROWTH_SUMMARY_UI_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
