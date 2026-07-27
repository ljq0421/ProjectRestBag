extends RefCounted

const DeviceGrowthService = preload("res://scripts/device_growth_service.gd")

const MASTERY_TRIAL := 0
const MASTERY_POPULAR := 1
const MASTERY_SIGNATURE := 2

const MASTERY_NAMES := {
	MASTERY_TRIAL: "试作品",
	MASTERY_POPULAR: "人气款",
	MASTERY_SIGNATURE: "招牌款"
}

const STAGE_REQUIREMENTS := {
	MASTERY_TRIAL: {"next_level": MASTERY_POPULAR, "made_batches": 30, "effective_rounds": 10, "synergy_rounds": 3, "device_level": 3},
	MASTERY_POPULAR: {"next_level": MASTERY_SIGNATURE, "made_batches": 40, "effective_rounds": 14, "synergy_rounds": 8, "device_level": 5}
}

const MASTERWORK_XP_THRESHOLDS_TENTHS := [0, 200, 500, 900, 1400, 2000, 2750, 3650, 4700, 6000]
const MASTERWORK_MAX_LEVEL := 10
const MASTERWORK_MAX_XP_TENTHS := 6000

const TAG_TRAITS := [
	{"id": "summer_fresh", "tags": ["果香", "清爽"], "price_pct": 0.0, "speed_pct": 5.0, "label": "夏日清爽"},
	{"id": "rich_bittersweet", "tags": ["苦甜", "浓郁"], "price_pct": 5.0, "speed_pct": 0.0, "label": "醇厚苦甜"},
	{"id": "sweet_salty_bridge", "tags": ["甜", "咸香"], "price_pct": 0.0, "speed_pct": 6.0, "label": "咸甜桥梁"},
	{"id": "soft_sweet_hot", "tags": ["软糯", "甜"], "price_pct": 0.0, "speed_pct": 5.0, "label": "软糯热卖"},
	{"id": "tea_partner", "tags": ["经典", "香脆"], "price_pct": 0.0, "speed_pct": 5.0, "label": "茶点搭档"},
	{"id": "classic_display", "tags": ["经典"], "price_pct": 0.0, "speed_pct": 3.0, "label": "经典陈列"},
	{"id": "light_fresh", "tags": ["低负担", "清爽"], "price_pct": 3.0, "speed_pct": 3.0, "label": "轻食推荐"}
]

const SHAPE_TRAITS := {
	"迷你款": {"id": "gift_box_shape", "price_pct": 8.0, "speed_pct": -3.0, "label": "礼盒装"},
	"横盘款": {"id": "gift_box_shape", "price_pct": 8.0, "speed_pct": -3.0, "label": "礼盒装"},
	"竖杯款": {"id": "small_fast_shape", "price_pct": -3.0, "speed_pct": 6.0, "label": "小份走量"},
	"中块款": {"id": "large_signature_shape", "price_pct": 10.0, "speed_pct": -5.0, "label": "大份招牌"},
	"招牌款": {"id": "large_signature_shape", "price_pct": 10.0, "speed_pct": -5.0, "label": "大份招牌"}
}

const GENERIC_TRAITS := {
	"popular_adjacency": {"price_pct": 0.0, "speed_pct": 4.0, "label": "相邻呼应"},
	"signature_margin": {"price_pct": 6.0, "speed_pct": -2.0, "label": "招牌溢价"}
}


static func default_growth(_recipe_id: String) -> Dictionary:
	return {
		"mastery_level": MASTERY_TRIAL,
		"stage_made_batches": 0,
		"stage_effective_rounds": 0,
		"stage_synergy_rounds": 0,
		"stage_device_wait_notified": false,
		"made_count": 0,
		"sold_count": 0,
		"adjacency_trigger_count": 0,
		"display_traits": [],
		"available_traits": [],
		"selected_traits": [],
		"selected_display_traits": [],
		"pending_trait_choice": false,
		"masterwork_level": 0,
		"masterwork_xp_tenths": 0
	}


static func effective_signature_made_count(actual_made_count: int, device_level: int) -> int:
	return maxi(0, actual_made_count)


static func stage_requirement(mastery_level: int) -> Dictionary:
	return STAGE_REQUIREMENTS.get(clampi(mastery_level, MASTERY_TRIAL, MASTERY_SIGNATURE), {}).duplicate(true)


static func stage_progress_status(growth: Dictionary, device_level: int) -> Dictionary:
	var actual_level := clampi(int(growth.get("mastery_level", MASTERY_TRIAL)), MASTERY_TRIAL, MASTERY_SIGNATURE)
	var requirement := stage_requirement(actual_level)
	var clean_device_level := clampi(device_level, 1, 5)
	if requirement.is_empty():
		return {
			"mastery_level": actual_level,
			"mastery_name": mastery_name(actual_level),
			"next_level": -1,
			"next_mastery_name": "",
			"complete": true,
			"waiting_for_device": false,
			"ready_to_advance": false,
			"device_level": clean_device_level,
			"device_target_level": 0
		}
	var made_batches := maxi(0, int(growth.get("stage_made_batches", 0)))
	var effective_rounds := maxi(0, int(growth.get("stage_effective_rounds", 0)))
	var synergy_rounds := maxi(0, int(growth.get("stage_synergy_rounds", 0)))
	var made_target := int(requirement.get("made_batches", 0))
	var effective_target := int(requirement.get("effective_rounds", 0))
	var synergy_target := int(requirement.get("synergy_rounds", 0))
	var device_target := int(requirement.get("device_level", 1))
	var made_complete := made_batches >= made_target
	var effective_complete := effective_rounds >= effective_target
	var synergy_complete := synergy_rounds >= synergy_target
	var device_complete := clean_device_level >= device_target
	var non_device_complete := made_complete and effective_complete and synergy_complete
	return {
		"mastery_level": actual_level,
		"mastery_name": mastery_name(actual_level),
		"next_level": int(requirement.get("next_level", actual_level + 1)),
		"next_mastery_name": mastery_name(int(requirement.get("next_level", actual_level + 1))),
		"made_batches": made_batches,
		"made_batches_target": made_target,
		"made_batches_remaining": maxi(0, made_target - made_batches),
		"made_batches_complete": made_complete,
		"effective_rounds": effective_rounds,
		"effective_rounds_target": effective_target,
		"effective_rounds_remaining": maxi(0, effective_target - effective_rounds),
		"effective_rounds_complete": effective_complete,
		"synergy_rounds": synergy_rounds,
		"synergy_rounds_target": synergy_target,
		"synergy_rounds_remaining": maxi(0, synergy_target - synergy_rounds),
		"synergy_rounds_complete": synergy_complete,
		"device_level": clean_device_level,
		"device_target_level": device_target,
		"device_level_remaining": maxi(0, device_target - clean_device_level),
		"device_level_complete": device_complete,
		"waiting_for_device": non_device_complete and not device_complete,
		"ready_to_advance": non_device_complete and device_complete,
		"complete": false,
		"requirement": requirement
	}


static func can_advance_stage(growth: Dictionary, device_level: int) -> bool:
	return bool(stage_progress_status(growth, device_level).get("ready_to_advance", false))


static func advance_one_stage(recipe_id: String, growth: Dictionary, recipe: Dictionary, display_config: Dictionary, device_level: int) -> Dictionary:
	var updated := growth.duplicate(true)
	if not can_advance_stage(updated, device_level):
		return evaluate_growth(recipe_id, updated, recipe, display_config, device_level)
	updated["mastery_level"] = mini(MASTERY_SIGNATURE, int(updated.get("mastery_level", MASTERY_TRIAL)) + 1)
	updated["stage_made_batches"] = 0
	updated["stage_effective_rounds"] = 0
	updated["stage_synergy_rounds"] = 0
	updated["stage_device_wait_notified"] = false
	return evaluate_growth(recipe_id, updated, recipe, display_config, device_level)


static func natural_mastery_level(growth: Dictionary, device_level: int) -> int:
	var level := clampi(int(growth.get("mastery_level", MASTERY_TRIAL)), MASTERY_TRIAL, MASTERY_SIGNATURE)
	return mini(MASTERY_SIGNATURE, level + 1) if can_advance_stage(growth, device_level) else level


static func capped_mastery_level(natural_level: int, device_level: int) -> int:
	return mini(clampi(natural_level, MASTERY_TRIAL, MASTERY_SIGNATURE), DeviceGrowthService.stage_cap(device_level))


static func growth_status(growth: Dictionary, device_context: Dictionary) -> Dictionary:
	var device_level := clampi(int(device_context.get("level", 1)), 1, 5)
	var status := stage_progress_status(growth, device_level)
	status["natural_level"] = natural_mastery_level(growth, device_level)
	status["stage_cap"] = DeviceGrowthService.stage_cap(device_level)
	status["waiting_reason"] = "device_level" if bool(status.get("waiting_for_device", false)) else ""
	status["effective_signature_made_count"] = maxi(0, int(growth.get("stage_made_batches", 0)))
	status["next_threshold"] = status.get("requirement", {}).duplicate(true)
	return status


static func can_activate_masterwork(growth: Dictionary) -> bool:
	return int(growth.get("mastery_level", 0)) >= MASTERY_SIGNATURE and _sanitize_string_array(growth.get("selected_traits", [])).size() >= 2


static func masterwork_level_for_xp_tenths(xp_tenths: int) -> int:
	var clean_xp := clampi(xp_tenths, 0, MASTERWORK_MAX_XP_TENTHS)
	var level := 1
	for index in range(MASTERWORK_XP_THRESHOLDS_TENTHS.size()):
		if clean_xp >= int(MASTERWORK_XP_THRESHOLDS_TENTHS[index]):
			level = index + 1
	return clampi(level, 1, MASTERWORK_MAX_LEVEL)


static func masterwork_next_threshold(level: int) -> int:
	var clean_level := clampi(level, 1, MASTERWORK_MAX_LEVEL)
	if clean_level >= MASTERWORK_MAX_LEVEL:
		return MASTERWORK_MAX_XP_TENTHS
	return int(MASTERWORK_XP_THRESHOLDS_TENTHS[clean_level])


static func masterwork_milestone(level: int) -> Dictionary:
	var clean_level := clampi(level, 0, MASTERWORK_MAX_LEVEL)
	return {
		"frame": "gold" if clean_level >= 10 else ("silver" if clean_level >= 3 else ""),
		"glow": clean_level >= 6,
		"seal": clean_level >= 10
	}


static func masterwork_title(recipe_name: String, level: int) -> String:
	if level < MASTERWORK_MAX_LEVEL or recipe_name.is_empty():
		return ""
	return "%s名匠" % recipe_name


static func sanitize_growth(recipe_id: String, raw_value: Variant, recipe: Dictionary, display_config: Dictionary, device_level: int = 5) -> Dictionary:
	var growth := default_growth(recipe_id)
	if raw_value is Dictionary:
		var raw: Dictionary = raw_value
		growth["mastery_level"] = clampi(int(raw.get("mastery_level", 0)), 0, MASTERY_SIGNATURE)
		growth["stage_made_batches"] = maxi(0, int(raw.get("stage_made_batches", 0)))
		growth["stage_effective_rounds"] = maxi(0, int(raw.get("stage_effective_rounds", 0)))
		growth["stage_synergy_rounds"] = maxi(0, int(raw.get("stage_synergy_rounds", 0)))
		growth["stage_device_wait_notified"] = bool(raw.get("stage_device_wait_notified", false))
		growth["made_count"] = maxi(0, int(raw.get("made_count", 0)))
		growth["sold_count"] = maxi(0, int(raw.get("sold_count", 0)))
		growth["adjacency_trigger_count"] = maxi(0, int(raw.get("adjacency_trigger_count", 0)))
		growth["display_traits"] = _sanitize_string_array(raw.get("display_traits", []))
		growth["available_traits"] = _sanitize_string_array(raw.get("available_traits", growth["display_traits"]))
		growth["selected_traits"] = _sanitize_string_array(raw.get("selected_traits", raw.get("selected_display_traits", [])))
		growth["selected_display_traits"] = growth["selected_traits"].duplicate()
		growth["pending_trait_choice"] = bool(raw.get("pending_trait_choice", false))
		growth["masterwork_level"] = clampi(int(raw.get("masterwork_level", 0)), 0, MASTERWORK_MAX_LEVEL)
		growth["masterwork_xp_tenths"] = clampi(int(raw.get("masterwork_xp_tenths", 0)), 0, MASTERWORK_MAX_XP_TENTHS)
	return evaluate_growth(recipe_id, growth, recipe, display_config, device_level)


static func evaluate_growth(recipe_id: String, growth: Dictionary, recipe: Dictionary, display_config: Dictionary, device_level: int = 5) -> Dictionary:
	var level := clampi(int(growth.get("mastery_level", 0)), MASTERY_TRIAL, MASTERY_SIGNATURE)
	growth["mastery_level"] = level
	growth["stage_made_batches"] = maxi(0, int(growth.get("stage_made_batches", 0)))
	growth["stage_effective_rounds"] = maxi(0, int(growth.get("stage_effective_rounds", 0)))
	growth["stage_synergy_rounds"] = maxi(0, int(growth.get("stage_synergy_rounds", 0)))
	growth["stage_device_wait_notified"] = bool(growth.get("stage_device_wait_notified", false))
	var traits := _candidate_traits_for_recipe(recipe_id, recipe, display_config, level)
	var selected := _sanitize_string_array(growth.get("selected_traits", growth.get("selected_display_traits", [])))
	var sanitized_selected: Array[String] = []
	for trait_id in selected:
		if traits.has(trait_id) and not sanitized_selected.has(trait_id):
			sanitized_selected.append(trait_id)
	var required_count := _required_selected_trait_count(level)
	while sanitized_selected.size() > required_count:
		sanitized_selected.pop_back()
	growth["display_traits"] = traits
	growth["available_traits"] = traits.duplicate()
	growth["selected_traits"] = sanitized_selected
	growth["selected_display_traits"] = sanitized_selected.duplicate()
	growth["pending_trait_choice"] = traits.size() > sanitized_selected.size() and sanitized_selected.size() < required_count
	_sanitize_masterwork_fields(growth)
	return growth


static func mastery_name(level: int) -> String:
	return String(MASTERY_NAMES.get(clampi(level, 0, MASTERY_SIGNATURE), "试作品"))


static func growth_bonus(recipe_id: String, growth: Dictionary, recipe: Dictionary, display_config: Dictionary) -> Dictionary:
	var level := clampi(int(growth.get("mastery_level", 0)), 0, MASTERY_SIGNATURE)
	var price_pct := 0.0
	var speed_pct := 0.0
	var reasons: Array[String] = []
	if level >= MASTERY_POPULAR:
		price_pct += 5.0
		reasons.append("受成长阶段「%s」影响：持续制作和售卖积累人气，提高基础售价" % mastery_name(level))
	if level >= MASTERY_SIGNATURE:
		price_pct += 8.0
		speed_pct += 5.0
		reasons.append("受成长阶段「%s」影响：招牌款带来额外溢价和售速提升" % mastery_name(level))
	for trait_id in _sanitize_string_array(growth.get("selected_traits", growth.get("selected_display_traits", []))):
		var trait_bonus := _trait_bonus(recipe_id, trait_id, recipe, display_config)
		price_pct += float(trait_bonus.get("price_pct", 0.0))
		speed_pct += float(trait_bonus.get("speed_pct", 0.0))
		if absf(float(trait_bonus.get("price_pct", 0.0))) >= 0.01 or absf(float(trait_bonus.get("speed_pct", 0.0))) >= 0.01:
			reasons.append("受成长特性「%s」影响：产品标签或形状适配橱窗展示，改变售价/售速" % _trait_label(trait_id))
	price_pct = clampf(price_pct, -15.0, 20.0)
	speed_pct = clampf(speed_pct, -15.0, 20.0)
	return {
		"price_pct": price_pct,
		"speed_pct": speed_pct,
		"price_multiplier": 1.0 + price_pct / 100.0,
		"speed_multiplier": 1.0 + speed_pct / 100.0,
		"mastery_level": level,
		"mastery_name": mastery_name(level),
		"traits": _sanitize_string_array(growth.get("display_traits", [])),
		"selected_traits": _sanitize_string_array(growth.get("selected_traits", [])),
		"trait_labels": trait_labels(growth.get("display_traits", [])),
		"selected_trait_labels": trait_labels(growth.get("selected_traits", [])),
		"reasons": reasons
	}


static func trait_labels(traits_value: Variant) -> Array[String]:
	var labels: Array[String] = []
	for trait_id in _sanitize_string_array(traits_value):
		labels.append(_trait_label(trait_id))
	return labels


static func trait_definition(recipe_id: String, trait_id: String, recipe: Dictionary, display_config: Dictionary) -> Dictionary:
	var bonus := _trait_bonus(recipe_id, trait_id, recipe, display_config)
	return {
		"id": trait_id,
		"label": _trait_label(trait_id),
		"price_pct": float(bonus.get("price_pct", 0.0)),
		"speed_pct": float(bonus.get("speed_pct", 0.0))
	}


static func has_positive_showcase_growth_source(bonus: Dictionary) -> bool:
	var breakdown: Dictionary = bonus.get("breakdown", {})
	if breakdown.has("adjacency_tag"):
		var adjacency: Dictionary = breakdown.get("adjacency_tag", {})
		if float(adjacency.get("price_pct", 0.0)) > 0.0 or float(adjacency.get("speed_pct", 0.0)) > 0.0:
			return true
	if breakdown.has("set"):
		var set_bonus: Dictionary = breakdown.get("set", {})
		if float(set_bonus.get("price_pct", 0.0)) > 0.0 or float(set_bonus.get("speed_pct", 0.0)) > 0.0:
			return true
	return false


static func _tag_trait_for_recipe(recipe: Dictionary) -> String:
	var tags: Array = recipe.get("tags", [])
	for entry in TAG_TRAITS:
		var required: Array = entry.get("tags", [])
		var matches_all := true
		for tag in required:
			if not tags.has(tag):
				matches_all = false
				break
		if matches_all:
			return String(entry.get("id", ""))
	return ""


static func _shape_trait_for_recipe(recipe_id: String, display_config: Dictionary) -> String:
	var recipe_display: Dictionary = display_config.get("recipes", {}).get(recipe_id, {})
	var shape_category := String(recipe_display.get("shape_category", ""))
	return String(SHAPE_TRAITS.get(shape_category, {}).get("id", ""))


static func _candidate_traits_for_recipe(recipe_id: String, recipe: Dictionary, display_config: Dictionary, level: int) -> Array[String]:
	var traits: Array[String] = []
	if level >= MASTERY_POPULAR:
		var tag_trait := _tag_trait_for_recipe(recipe)
		if not tag_trait.is_empty():
			traits.append(tag_trait)
		if not traits.has("popular_adjacency"):
			traits.append("popular_adjacency")
	if level >= MASTERY_SIGNATURE:
		var shape_trait := _shape_trait_for_recipe(recipe_id, display_config)
		if not shape_trait.is_empty() and not traits.has(shape_trait):
			traits.append(shape_trait)
		if not traits.has("signature_margin"):
			traits.append("signature_margin")
	return traits


static func _required_selected_trait_count(level: int) -> int:
	if level >= MASTERY_SIGNATURE:
		return 2
	if level >= MASTERY_POPULAR:
		return 1
	return 0


static func _sanitize_masterwork_fields(growth: Dictionary) -> void:
	var stored_level := clampi(int(growth.get("masterwork_level", 0)), 0, MASTERWORK_MAX_LEVEL)
	if stored_level <= 0 or not can_activate_masterwork(growth):
		growth["masterwork_level"] = 0
		growth["masterwork_xp_tenths"] = 0
		return
	var xp_tenths := clampi(int(growth.get("masterwork_xp_tenths", 0)), 0, MASTERWORK_MAX_XP_TENTHS)
	growth["masterwork_xp_tenths"] = xp_tenths
	growth["masterwork_level"] = masterwork_level_for_xp_tenths(xp_tenths)


static func _trait_bonus(recipe_id: String, trait_id: String, recipe: Dictionary, display_config: Dictionary) -> Dictionary:
	for entry in TAG_TRAITS:
		if String(entry.get("id", "")) == trait_id:
			return {"price_pct": float(entry.get("price_pct", 0.0)), "speed_pct": float(entry.get("speed_pct", 0.0))}
	var recipe_display: Dictionary = display_config.get("recipes", {}).get(recipe_id, {})
	var shape_category := String(recipe_display.get("shape_category", ""))
	var shape_trait: Dictionary = SHAPE_TRAITS.get(shape_category, {})
	if String(shape_trait.get("id", "")) == trait_id:
		return {"price_pct": float(shape_trait.get("price_pct", 0.0)), "speed_pct": float(shape_trait.get("speed_pct", 0.0))}
	var generic_trait: Dictionary = GENERIC_TRAITS.get(trait_id, {})
	if not generic_trait.is_empty():
		return {"price_pct": float(generic_trait.get("price_pct", 0.0)), "speed_pct": float(generic_trait.get("speed_pct", 0.0))}
	return {"price_pct": 0.0, "speed_pct": 0.0}


static func _trait_label(trait_id: String) -> String:
	for entry in TAG_TRAITS:
		if String(entry.get("id", "")) == trait_id:
			return String(entry.get("label", trait_id))
	for shape_trait in SHAPE_TRAITS.values():
		if String(shape_trait.get("id", "")) == trait_id:
			return String(shape_trait.get("label", trait_id))
	if GENERIC_TRAITS.has(trait_id):
		return String(GENERIC_TRAITS[trait_id].get("label", trait_id))
	return trait_id


static func _sanitize_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		var text := String(item)
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result
