extends SceneTree

const Catalog := preload("res://scripts/catalog.gd")
const CoreFeatureUnlockService := preload("res://scripts/core_feature_unlock_service.gd")
const DevRecipeUnlockImporter := preload("res://scripts/dev_recipe_unlock_importer.gd")
const GameState := preload("res://scripts/game_state.gd")
const SaveSystem := preload("res://scripts/save_system.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := Catalog.new()
	var markdown := """# 验收清单
  rice_milk_drink  
resources/recipe_icons/matcha_pudding.png
resources/recipe_icons/matcha_pudding_popular.png
resources/recipe_icons/matcha_pudding_signature.png
## 米浆饮（rice_milk_drink）
## 不是配方（grinder）
unknown_recipe_id
- milk_rice_dew
`matcha`、`green_tea` 和 `unknown_prompt_token` 只是正文。
"""
	var parsed: Dictionary = DevRecipeUnlockImporter.parse_markdown_text(markdown, catalog.get_recipes())
	_expect(bool(parsed.get("ok", false)), "parser should accept legal recipe markers")
	_expect_equal(parsed.get("recipe_ids", []), ["rice_milk_drink", "matcha_pudding"], "parser should accept whole-line bare ids, normalize stages, and preserve first-seen order")
	_expect((parsed.get("ignored_ids", []) as Array).has("grinder"), "parser should report explicit non-recipe heading ids")
	_expect((parsed.get("ignored_ids", []) as Array).has("unknown_recipe_id"), "parser should report an unknown whole-line bare id")
	_expect(not (parsed.get("recipe_ids", []) as Array).has("milk_rice_dew"), "parser should not accept list-marked ids")
	_expect(not (parsed.get("ignored_ids", []) as Array).has("matcha"), "parser should not scan arbitrary prompt-body ids")

	var empty_parse: Dictionary = DevRecipeUnlockImporter.parse_markdown_text("`matcha` only", catalog.get_recipes())
	_expect(not bool(empty_parse.get("ok", true)), "parser should reject markdown with no legal recipes")

	var plan: Dictionary = DevRecipeUnlockImporter.build_plan(parsed, catalog)
	_expect(bool(plan.get("ok", false)), "dependency plan should be valid")
	_expect_equal(int(plan.get("required_level", -1)), 5, "matcha pudding should require level five")
	_expect((plan.get("device_ids", []) as Array).has("chiller"), "plan should include the recipe device")
	_expect((plan.get("device_ids", []) as Array).has("grinder"), "plan should include the matcha processing device")
	_expect((plan.get("process_unlock_ids", []) as Array).has("matcha"), "plan should unlock matcha processing")
	_expect(not (plan.get("purchase_unlock_ids", []) as Array).has("matcha"), "plan should not fabricate a matcha purchase permission")

	var state = GameState.new_game()
	var tutorial_before: String = state.tutorial_guide_step
	var tasks_before: Array = state.completed_tasks.duplicate(true)
	var notifications_before: Array = state.pending_notifications.duplicate(true)
	var inventory_before: Dictionary = state.ingredient_inventory.duplicate(true)
	var products_before: Dictionary = state.product_inventory.duplicate(true)
	var growth_before: Dictionary = state.recipe_growth.duplicate(true)
	var snapshot: Dictionary = DevRecipeUnlockImporter.snapshot_state(state)
	var applied: Dictionary = DevRecipeUnlockImporter.apply_plan(state, plan)
	_expect(bool(applied.get("ok", false)), "valid plan should apply")
	_expect_equal(state.level, 5, "plan should raise but not lower shop level")
	_expect(state.is_core_feature_unlocked(CoreFeatureUnlockService.LIST), "plan should unlock through listing")
	_expect(not state.is_core_feature_unlocked(CoreFeatureUnlockService.RULEBOOK), "plan should not unlock post-list features")
	_expect(state.unlocked_devices.has("chiller") and state.unlocked_devices.has("grinder"), "plan should explicitly unlock required devices")
	_expect(state.is_ingredient_process_unlocked("matcha"), "plan should unlock required ingredient processing")
	_expect(state.is_recipe_unlocked("matcha_pudding") and state.is_recipe_unlocked("rice_milk_drink"), "plan should unlock target recipes")
	_expect_equal(state.tutorial_guide_step, tutorial_before, "plan should not advance tutorial")
	_expect_equal(state.completed_tasks, tasks_before, "plan should not complete tasks")
	_expect_equal(state.pending_notifications, notifications_before, "plan should not queue notifications")
	_expect_equal(state.ingredient_inventory, inventory_before, "plan should not grant ingredients")
	_expect_equal(state.product_inventory, products_before, "plan should not grant products")
	_expect_equal(state.recipe_growth, growth_before, "plan should not change recipe growth")

	var log_count_after_first: int = state.feedback_log.size()
	var applied_again: Dictionary = DevRecipeUnlockImporter.apply_plan(state, plan)
	_expect(bool(applied_again.get("ok", false)), "second application should still succeed")
	_expect_equal(int(applied_again.get("added_recipe_count", -1)), 0, "second application should add no recipes")
	_expect_equal(state.feedback_log.size(), log_count_after_first, "second application should add no duplicate unlock logs")

	var save_path := OS.get_temp_dir().path_join("markdown_recipe_unlock_importer_self_check.json")
	_delete_file(save_path)
	_expect(SaveSystem.save_game(state, save_path, 1000), "imported fixture should save")
	var loaded = SaveSystem.load_game(save_path, save_path + ".broken", 1000)
	_expect_equal(loaded.level, 5, "imported level should survive reload")
	_expect(loaded.is_recipe_unlocked("matcha_pudding"), "imported recipe should survive reload")
	_expect(loaded.is_ingredient_process_unlocked("matcha"), "process permission should survive reload")
	_delete_file(save_path)
	_delete_file(save_path + ".broken")

	DevRecipeUnlockImporter.restore_snapshot(state, snapshot)
	_expect_equal(state.level, int(snapshot.get("level", -1)), "rollback should restore level")
	_expect_equal(state.unlocked_recipes, snapshot.get("unlocked_recipes", []), "rollback should restore recipes")
	_expect_equal(state.unlocked_devices, snapshot.get("unlocked_devices", []), "rollback should restore devices")
	_expect_equal(state.feedback_log, snapshot.get("feedback_log", []), "rollback should restore feedback log")

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _finish() -> void:
	if failures.is_empty():
		print("MARKDOWN_RECIPE_UNLOCK_IMPORTER_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		printerr("MARKDOWN_RECIPE_UNLOCK_IMPORTER_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
