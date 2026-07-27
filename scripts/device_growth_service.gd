class_name DeviceGrowthService
extends RefCounted

const MIN_LEVEL := 1
const MAX_LEVEL := 5

const LEVELS := {
	1: {
		"level": 1,
		"required_uses": 0,
		"coin_cost": 0,
		"stage_cap": 0,
		"research_hint_increment": 1,
		"production_growth_multiplier": 1.0,
		"effect": "试作品培养上限"
	},
	2: {
		"level": 2,
		"required_uses": 10,
		"coin_cost": 120,
		"stage_cap": 0,
		"research_hint_increment": 2,
		"production_growth_multiplier": 1.0,
		"effect": "试作品培养上限；研发失败线索 +2"
	},
	3: {
		"level": 3,
		"required_uses": 30,
		"coin_cost": 360,
		"stage_cap": 1,
		"research_hint_increment": 2,
		"production_growth_multiplier": 1.0,
		"effect": "人气款培养上限"
	},
	4: {
		"level": 4,
		"required_uses": 70,
		"coin_cost": 900,
		"stage_cap": 1,
		"research_hint_increment": 2,
		"production_growth_multiplier": 1.2,
		"effect": "人气款培养上限；名作制作经验 +20%"
	},
	5: {
		"level": 5,
		"required_uses": 150,
		"coin_cost": 2200,
		"stage_cap": 2,
		"research_hint_increment": 2,
		"production_growth_multiplier": 1.2,
		"effect": "招牌款培养上限；名作制作经验 +20%；设备满级徽章"
	}
}


static func supports_growth(device_id: String, devices: Dictionary) -> bool:
	return devices.has(device_id) and bool(devices[device_id].get("recipe_growth_enabled", false))


static func default_state() -> Dictionary:
	return {
		"level": MIN_LEVEL,
		"use_count": 0,
		"research_count": 0,
		"production_batch_count": 0
	}


static func sanitize_state(raw_value: Variant) -> Dictionary:
	var result := default_state()
	if not raw_value is Dictionary:
		return result
	var raw: Dictionary = raw_value
	result["level"] = clampi(int(raw.get("level", MIN_LEVEL)), MIN_LEVEL, MAX_LEVEL)
	result["research_count"] = maxi(0, int(raw.get("research_count", 0)))
	result["production_batch_count"] = maxi(0, int(raw.get("production_batch_count", 0)))
	result["use_count"] = int(result["research_count"]) + int(result["production_batch_count"])
	return result


static func level_definition(level: int) -> Dictionary:
	return LEVELS.get(clampi(level, MIN_LEVEL, MAX_LEVEL), LEVELS[MIN_LEVEL]).duplicate(true)


static func stage_cap(level: int) -> int:
	return int(level_definition(level).get("stage_cap", 0))


static func research_hint_increment(level: int) -> int:
	return int(level_definition(level).get("research_hint_increment", 1))


static func production_growth_multiplier(level: int) -> float:
	return float(level_definition(level).get("production_growth_multiplier", 1.0))


static func upgrade_quote(device_id: String, state: Dictionary, coins: int, unlocked: bool, devices: Dictionary) -> Dictionary:
	if not supports_growth(device_id, devices):
		return {
			"ok": false,
			"can_upgrade": false,
			"status": "unsupported",
			"error": "unsupported"
		}
	var clean := sanitize_state(state)
	var current_level := int(clean.get("level", MIN_LEVEL))
	var current_definition := level_definition(current_level)
	if not unlocked:
		return {
			"ok": false,
			"can_upgrade": false,
			"status": "locked",
			"error": "locked",
			"level": current_level,
			"current_effect": String(current_definition.get("effect", ""))
		}
	if current_level >= MAX_LEVEL:
		return {
			"ok": false,
			"can_upgrade": false,
			"status": "max_level",
			"error": "max_level",
			"level": MAX_LEVEL,
			"next_level": MAX_LEVEL,
			"missing_uses": 0,
			"missing_coins": 0,
			"current_effect": String(current_definition.get("effect", "")),
			"next_effect": "已满级"
		}
	var next_level := current_level + 1
	var next_definition := level_definition(next_level)
	var required_uses := int(next_definition.get("required_uses", 0))
	var coin_cost := int(next_definition.get("coin_cost", 0))
	var missing_uses := maxi(0, required_uses - int(clean.get("use_count", 0)))
	var missing_coins := maxi(0, coin_cost - maxi(0, coins))
	var can_upgrade := missing_uses == 0 and missing_coins == 0
	return {
		"ok": can_upgrade,
		"can_upgrade": can_upgrade,
		"status": "ready" if can_upgrade else "blocked",
		"error": "" if can_upgrade else "requirements_not_met",
		"level": current_level,
		"next_level": next_level,
		"use_count": int(clean.get("use_count", 0)),
		"required_uses": required_uses,
		"coin_cost": coin_cost,
		"missing_uses": missing_uses,
		"missing_coins": missing_coins,
		"current_effect": String(current_definition.get("effect", "")),
		"next_effect": String(next_definition.get("effect", ""))
	}
