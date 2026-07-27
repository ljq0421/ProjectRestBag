class_name TutorialProgress
extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const CoreFeatureUnlockService = preload("res://scripts/core_feature_unlock_service.gd")

const STEP_PURCHASE := "purchase"
const STEP_OUTPUT := "output"
const STEP_RESEARCH := "research"
const STEP_CRAFT := "craft"
const STEP_LIST := "list"
const STEP_RULEBOOK := "rulebook"
const STEP_ARRANGE := "arrange"
const STEP_BUSINESS := "business"
const STEP_STOREFRONT := "storefront"
const STEP_SETTLEMENT := "settlement"
const STEP_COMPLETE := "complete"
const STEPS := [
	STEP_PURCHASE,
	STEP_OUTPUT,
	STEP_RESEARCH,
	STEP_CRAFT,
	STEP_LIST,
	STEP_RULEBOOK,
	STEP_ARRANGE,
	STEP_BUSINESS,
	STEP_STOREFRONT,
	STEP_SETTLEMENT,
	STEP_COMPLETE,
]
const TUTORIAL_RECIPE_ID := "rice_milk_drink"
const TUTORIAL_OUTPUT_IDS := ["rice"]
const TUTORIAL_RESEARCH_MATERIAL_IDS := ["rice", "spring_water"]
const TUTORIAL_RESEARCH_DEVICE_ID := "round_pot"


static func sanitize_step(step: String) -> String:
	return step if STEPS.has(step) else STEP_PURCHASE


static func is_guide_active(state) -> bool:
	return state != null and not bool(state.tutorial_guide_finished) and not bool(state.tutorial_guide_skipped)


static func is_current_guidance_dismissed(state) -> bool:
	return state != null \
		and is_guide_active(state) \
		and String(state.tutorial_guide_dismissed_step) == String(state.tutorial_guide_step)


static func on_purchase_completed(state, purchased_quantities: Dictionary) -> bool:
	if not _is_current_step(state, STEP_PURCHASE) or int(purchased_quantities.get("rice_seed", 0)) <= 0:
		return false
	state.record_core_unlock_progress("purchased_rice_seed", true)
	state.unlock_core_feature(CoreFeatureUnlockService.OUTPUT)
	state.unlock_core_feature(CoreFeatureUnlockService.INVENTORY)
	return _advance_guide(state, STEP_OUTPUT)


static func on_ingredient_harvested(
	state,
	item_id: String,
	amount: int,
	site_id: String = "",
	harvest_batch_id: String = "",
	is_manual_guide_harvest: bool = false
) -> void:
	if state == null:
		return
	var payload := {"item_id": item_id, "amount": amount, "site_id": site_id}
	if not harvest_batch_id.is_empty():
		payload["harvest_batch_id"] = harvest_batch_id
	state.record_task_event("harvest", payload)
	if not is_manual_guide_harvest \
			or not _is_current_step(state, STEP_OUTPUT) \
			or not TUTORIAL_OUTPUT_IDS.has(item_id):
		return
	if not state.tutorial_guide_harvested_ids.has(item_id):
		state.tutorial_guide_harvested_ids.append(item_id)
	for required_item_id in TUTORIAL_OUTPUT_IDS:
		if not state.tutorial_guide_harvested_ids.has(required_item_id):
			return
	state.record_core_unlock_progress("manual_rice_harvested", true)
	state.unlock_core_feature(CoreFeatureUnlockService.RESEARCH)
	state.unlock_device(TUTORIAL_RESEARCH_DEVICE_ID)
	_advance_guide(state, STEP_RESEARCH)


static func on_recipe_unlocked(state, recipe_id: String) -> void:
	if state == null:
		return
	var device_id := String(Catalog.new().get_recipes().get(recipe_id, {}).get("device", ""))
	state.record_task_event("research_success", {"recipe_id": recipe_id, "device_id": device_id})
	if not _is_current_step(state, STEP_RESEARCH) or recipe_id != TUTORIAL_RECIPE_ID:
		return
	_complete_research_step(state)


static func on_research_attempted(state, device_id: String, material_ids: Array) -> bool:
	if not _is_current_step(state, STEP_RESEARCH):
		return false
	if device_id != TUTORIAL_RESEARCH_DEVICE_ID or not state.is_recipe_unlocked(TUTORIAL_RECIPE_ID):
		return false
	var normalized_material_ids: Array[String] = []
	for material_value: Variant in material_ids:
		normalized_material_ids.append(String(material_value))
	normalized_material_ids.sort()
	var expected_material_ids: Array[String] = []
	for material_id in TUTORIAL_RESEARCH_MATERIAL_IDS:
		expected_material_ids.append(material_id)
	expected_material_ids.sort()
	if normalized_material_ids != expected_material_ids:
		return false
	return _complete_research_step(state)


static func on_product_made(state, recipe_id: String, amount: int = 1) -> void:
	if state == null:
		return
	state.record_task_event("make_product", {"recipe_id": recipe_id, "quantity": maxi(1, amount)})
	if not _is_current_step(state, STEP_CRAFT) or recipe_id != TUTORIAL_RECIPE_ID:
		return
	state.record_core_unlock_progress("rice_milk_product_completed", true)
	state.unlock_core_feature(CoreFeatureUnlockService.LIST)
	_advance_guide(state, STEP_LIST)


static func on_product_displayed(state, recipe_id: String, amount: int = 1) -> void:
	if state == null:
		return
	state.record_task_event("display_product", {"recipe_id": recipe_id, "quantity": maxi(1, amount)})
	on_guide_product_displayed(state, recipe_id)


static func on_guide_product_displayed(state, recipe_id: String) -> bool:
	if not _is_current_step(state, STEP_LIST) or recipe_id != TUTORIAL_RECIPE_ID:
		return false
	state.record_core_unlock_progress("rice_milk_listed", true)
	state.unlock_core_feature(CoreFeatureUnlockService.RULEBOOK)
	return _advance_guide(state, STEP_RULEBOOK)


static func on_showcase_rulebook_opened(state) -> bool:
	if not _is_current_step(state, STEP_RULEBOOK):
		return false
	state.record_core_unlock_progress("guided_rulebook_opened", true)
	state.unlock_core_feature(CoreFeatureUnlockService.ARRANGE)
	return _advance_guide(state, STEP_ARRANGE)


static func on_showcase_product_moved(state, recipe_id: String) -> bool:
	if not _is_current_step(state, STEP_ARRANGE) or recipe_id != TUTORIAL_RECIPE_ID:
		return false
	state.tutorial_guide_showcase_moved = true
	state.record_core_unlock_progress("rice_milk_moved", true)
	_finish_showcase_arrangement_if_ready(state)
	return true


static func on_showcase_product_rotated(state, recipe_id: String) -> bool:
	if not _is_current_step(state, STEP_ARRANGE) or recipe_id != TUTORIAL_RECIPE_ID:
		return false
	state.tutorial_guide_showcase_rotated = true
	state.record_core_unlock_progress("rice_milk_rotated", true)
	_finish_showcase_arrangement_if_ready(state)
	return true


static func on_business_round_started(state) -> bool:
	if not _is_current_step(state, STEP_BUSINESS):
		return false
	state.record_core_unlock_progress("business_round_started", true)
	state.unlock_core_feature(CoreFeatureUnlockService.STOREFRONT_MANAGE)
	return _advance_guide(state, STEP_STOREFRONT)


static func on_storefront_viewed(state) -> bool:
	if not _is_current_step(state, STEP_STOREFRONT):
		return false
	state.record_core_unlock_progress("storefront_viewed", true)
	var advanced := _advance_guide(state, STEP_SETTLEMENT)
	_try_complete_business_guide(state)
	return advanced


static func on_business_round_settled(state, round_report: Dictionary) -> bool:
	if not is_guide_active(state) or not [STEP_STOREFRONT, STEP_SETTLEMENT].has(String(state.tutorial_guide_step)):
		return false
	# Reaching STEP_SETTLEMENT already proves the storefront was viewed. This also
	# repairs saves created before storefront_viewed became persisted evidence.
	if String(state.tutorial_guide_step) == STEP_SETTLEMENT:
		state.record_core_unlock_progress("storefront_viewed", true)
	var counts_value: Variant = round_report.get("counts", {})
	var counts: Dictionary = counts_value if counts_value is Dictionary else {}
	var sold_count := maxi(0, int(counts.get("sold", round_report.get("sold", round_report.get("sold_count", 0)))))
	if sold_count < 1:
		return false
	state.record_core_unlock_progress("first_sale_settlement_completed", true)
	return _try_complete_business_guide(state)


static func skip_current_step(state) -> bool:
	if not is_guide_active(state) or String(state.tutorial_guide_step) == STEP_COMPLETE:
		return false
	state.tutorial_guide_dismissed_step = String(state.tutorial_guide_step)
	return true


static func close_guide(state) -> bool:
	if not _is_current_step(state, STEP_COMPLETE):
		return false
	state.level = maxi(1, int(state.level))
	state.unlock_core_feature(CoreFeatureUnlockService.TASK)
	state.record_core_unlock_progress("grandma_final_dialogue_confirmed", true)
	state.tutorial_guide_dismissed_step = ""
	state.tutorial_guide_finished = true
	return true


static func restart_guide(state) -> bool:
	if state == null or (String(state.tutorial_guide_step) != STEP_COMPLETE and not bool(state.tutorial_guide_finished)):
		return false
	state.tutorial_guide_step = STEP_PURCHASE
	state.tutorial_guide_finished = false
	state.tutorial_guide_skipped = false
	state.tutorial_guide_dialogue_acknowledged_step = ""
	state.tutorial_guide_dismissed_step = ""
	state.tutorial_guide_harvested_ids.clear()
	state.tutorial_guide_showcase_moved = false
	state.tutorial_guide_showcase_rotated = false
	return true


static func _complete_research_step(state) -> bool:
	state.record_core_unlock_progress("rice_milk_researched", true)
	state.unlock_core_feature(CoreFeatureUnlockService.CRAFT)
	state.unlock_core_feature(CoreFeatureUnlockService.CATALOG)
	return _advance_guide(state, STEP_CRAFT)


static func _is_current_step(state, expected_step: String) -> bool:
	return is_guide_active(state) and String(state.tutorial_guide_step) == expected_step


static func _advance_guide(state, next_step: String) -> bool:
	if not is_guide_active(state):
		return false
	state.tutorial_guide_step = sanitize_step(next_step)
	state.tutorial_guide_dismissed_step = ""
	return true


static func _try_complete_business_guide(state) -> bool:
	if state == null or not is_guide_active(state):
		return false
	if String(state.tutorial_guide_step) != STEP_SETTLEMENT:
		return false
	if not bool(state.get_core_unlock_progress("storefront_viewed", false)) \
			or not bool(state.get_core_unlock_progress("first_sale_settlement_completed", false)):
		return false
	return _advance_guide(state, STEP_COMPLETE)


static func _finish_showcase_arrangement_if_ready(state) -> bool:
	if not bool(state.tutorial_guide_showcase_moved) or not bool(state.tutorial_guide_showcase_rotated):
		return false
	state.unlock_core_feature(CoreFeatureUnlockService.BUSINESS)
	return _advance_guide(state, STEP_BUSINESS)
