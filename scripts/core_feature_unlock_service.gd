class_name CoreFeatureUnlockService
extends RefCounted

const PURCHASE := "purchase"
const OUTPUT := "output"
const INVENTORY := "inventory"
const RESEARCH := "research"
const CRAFT := "craft"
const CATALOG := "catalog"
const LIST := "list"
const RULEBOOK := "rulebook"
const ARRANGE := "arrange"
const BUSINESS := "business"
const STOREFRONT_MANAGE := "storefront_manage"
const TASK := "task"
const STARLIGHT := "starlight"

const ORDER: Array[String] = [
	PURCHASE,
	OUTPUT,
	INVENTORY,
	RESEARCH,
	CRAFT,
	CATALOG,
	LIST,
	RULEBOOK,
	ARRANGE,
	BUSINESS,
	STOREFRONT_MANAGE,
	TASK,
	STARLIGHT,
]

const LABELS := {
	PURCHASE: "采购",
	OUTPUT: "产出",
	INVENTORY: "仓库",
	RESEARCH: "研发",
	CRAFT: "制作",
	CATALOG: "图鉴",
	LIST: "上架",
	RULEBOOK: "经营规则",
	ARRANGE: "橱窗调整",
	BUSINESS: "营业",
	STOREFRONT_MANAGE: "经营中心",
	TASK: "任务",
	STARLIGHT: "星辉",
}

const PREREQUISITES := {
	PURCHASE: [],
	OUTPUT: [PURCHASE],
	INVENTORY: [PURCHASE],
	RESEARCH: [OUTPUT, INVENTORY],
	CRAFT: [RESEARCH],
	CATALOG: [RESEARCH],
	LIST: [CRAFT, CATALOG],
	RULEBOOK: [LIST],
	ARRANGE: [RULEBOOK],
	BUSINESS: [ARRANGE],
	STOREFRONT_MANAGE: [BUSINESS],
	TASK: [STOREFRONT_MANAGE],
	STARLIGHT: [],
}


static func default_unlocks() -> Dictionary:
	return {PURCHASE: true}


static func sanitize_unlocks(raw_value: Variant) -> Dictionary:
	var result := default_unlocks()
	if raw_value is Dictionary:
		for feature_id in ORDER:
			if bool((raw_value as Dictionary).get(feature_id, false)):
				result[feature_id] = true
	repair_prerequisites(result)
	return result


static func is_unlocked(unlocks: Dictionary, feature_id: String) -> bool:
	return bool(unlocks.get(feature_id, false))


static func unlock(unlocks: Dictionary, feature_id: String) -> bool:
	if not ORDER.has(feature_id) or is_unlocked(unlocks, feature_id):
		return false
	for prerequisite_id in prerequisites(feature_id):
		if not is_unlocked(unlocks, prerequisite_id):
			return false
	unlocks[feature_id] = true
	return true


static func prerequisites(feature_id: String) -> Array[String]:
	var result: Array[String] = []
	var raw_value: Variant = PREREQUISITES.get(feature_id, [])
	if raw_value is Array:
		for prerequisite_value: Variant in raw_value:
			result.append(String(prerequisite_value))
	return result


static func prerequisite_closure(feature_id: String) -> Array[String]:
	var required := {}
	_collect_prerequisites(feature_id, required)
	var result: Array[String] = []
	for ordered_id in ORDER:
		if bool(required.get(ordered_id, false)):
			result.append(ordered_id)
	return result


static func repair_prerequisites(unlocks: Dictionary) -> bool:
	var changed := false
	var unlocked_snapshot: Array[String] = []
	for feature_id in ORDER:
		if is_unlocked(unlocks, feature_id):
			unlocked_snapshot.append(feature_id)
	for feature_id in unlocked_snapshot:
		for prerequisite_id in prerequisite_closure(feature_id):
			if not is_unlocked(unlocks, prerequisite_id):
				unlocks[prerequisite_id] = true
				changed = true
	if not is_unlocked(unlocks, PURCHASE):
		unlocks[PURCHASE] = true
		changed = true
	return changed


static func locked_reason(unlocks: Dictionary, feature_id: String) -> String:
	if is_unlocked(unlocks, feature_id):
		return ""
	for prerequisite_id in prerequisites(feature_id):
		if not is_unlocked(unlocks, prerequisite_id):
			return "跟随外婆指引完成“%s”后开放" % String(LABELS.get(prerequisite_id, prerequisite_id))
	return "跟随外婆指引完成当前步骤后开放"


static func _collect_prerequisites(feature_id: String, target: Dictionary) -> void:
	for prerequisite_id in prerequisites(feature_id):
		if bool(target.get(prerequisite_id, false)):
			continue
		target[prerequisite_id] = true
		_collect_prerequisites(prerequisite_id, target)
