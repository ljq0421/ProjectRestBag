class_name RoundEnvironmentService
extends RefCounted


static func generate(project_seed: int, round_id: int, unlocked_tags: Array, rules: Dictionary) -> Dictionary:
	var config: Dictionary = rules.get("environment", {})
	var limits: Dictionary = rules.get("environment_limits", {})
	var seed_value := _stable_seed("%d:%d" % [project_seed, maxi(1, round_id)])
	var market := _pick_factor(config.get("markets", []), unlocked_tags, seed_value + 11)
	var weather := _pick_factor(config.get("weather", []), unlocked_tags, seed_value + 23)
	var wave := _pick_factor(config.get("waves", []), unlocked_tags, seed_value + 37)
	var festival := {}
	var festival_chance := clampi(int(config.get("festival_chance_pct", 0)), 0, 100)
	if posmod(seed_value + 41, 100) < festival_chance:
		festival = _pick_factor(config.get("festivals", []), unlocked_tags, seed_value + 53)
	var factors: Array[Dictionary] = []
	for factor in [market, weather, festival, wave]:
		if factor is Dictionary and not (factor as Dictionary).is_empty():
			factors.append((factor as Dictionary).duplicate(true))
	var positive_limit := float(limits.get("positive_pct", 25.0))
	var negative_limit := float(limits.get("negative_pct", -10.0))
	var price_pct := clampf(_factor_total(factors, "price_pct"), negative_limit, positive_limit)
	var speed_pct := clampf(_factor_total(factors, "speed_pct"), negative_limit, positive_limit)
	var labels: Array[String] = []
	for factor in factors:
		var label := String(factor.get("label", ""))
		if not label.is_empty():
			labels.append(label)
	return {
		"round_id": maxi(1, round_id),
		"seed": seed_value,
		"market": market,
		"weather": weather,
		"festival": festival,
		"wave": wave,
		"factors": factors,
		"total_price_pct": price_pct,
		"total_speed_pct": speed_pct,
		"label": "｜".join(labels) if not labels.is_empty() else "普通街区"
	}


static func apply_to_terms(terms: Dictionary, environment: Dictionary) -> Dictionary:
	var result := terms.duplicate(true)
	var factors: Array = environment.get("factors", [])
	for recipe_id_value in result.keys():
		var term: Dictionary = result.get(recipe_id_value, {})
		var tags: Array = term.get("tags", [])
		var price_pct := 0.0
		var speed_pct := 0.0
		var reasons: Array[String] = []
		if factors.is_empty():
			price_pct = float(environment.get("total_price_pct", 0.0))
			speed_pct = float(environment.get("total_speed_pct", 0.0))
			if not String(environment.get("label", "")).is_empty() and (not is_zero_approx(price_pct) or not is_zero_approx(speed_pct)):
				reasons.append("%s：售价 %+.0f%%，售速 %+.0f%%" % [String(environment.get("label", "挑战环境")), price_pct, speed_pct])
		for factor_value in factors:
			if not factor_value is Dictionary:
				continue
			var factor: Dictionary = factor_value
			if not _matches_tags(factor.get("match_tags", []), tags):
				continue
			price_pct += float(factor.get("price_pct", 0.0))
			speed_pct += float(factor.get("speed_pct", 0.0))
			reasons.append("%s：售价 %+.0f%%，售速 %+.0f%%" % [String(factor.get("label", "环境")), float(factor.get("price_pct", 0.0)), float(factor.get("speed_pct", 0.0))])
		price_pct = clampf(price_pct, -10.0, 25.0)
		speed_pct = clampf(speed_pct, -10.0, 25.0)
		var source_price := maxi(0, int(term.get("unit_price", term.get("base_price", 0))))
		var source_duration := maxi(1, int(term.get("duration_seconds", 1)))
		term["pre_environment_price"] = source_price
		term["pre_environment_duration_seconds"] = source_duration
		term["environment_price_pct"] = price_pct
		term["environment_speed_pct"] = speed_pct
		term["unit_price"] = maxi(0, int(round(float(source_price) * (1.0 + price_pct / 100.0))))
		term["duration_seconds"] = maxi(1, int(round(float(source_duration) / maxf(0.1, 1.0 + speed_pct / 100.0))))
		term["environment_reasons"] = reasons
		result[recipe_id_value] = term
	return result


static func _pick_factor(raw_factors: Variant, unlocked_tags: Array, seed_value: int) -> Dictionary:
	if not raw_factors is Array:
		return {}
	var candidates: Array[Dictionary] = []
	for factor_value in raw_factors as Array:
		if factor_value is Dictionary and _matches_tags((factor_value as Dictionary).get("match_tags", []), unlocked_tags):
			candidates.append((factor_value as Dictionary).duplicate(true))
	if candidates.is_empty():
		return {}
	return candidates[posmod(seed_value, candidates.size())]


static func _matches_tags(required_value: Variant, available: Array) -> bool:
	if not required_value is Array or (required_value as Array).is_empty():
		return true
	for tag_value in required_value as Array:
		if available.has(tag_value) or available.has(String(tag_value)):
			return true
	return false


static func _factor_total(factors: Array[Dictionary], key: String) -> float:
	var total := 0.0
	for factor in factors:
		total += float(factor.get(key, 0.0))
	return total


static func _stable_seed(value: String) -> int:
	var result := 2166136261
	for byte in value.to_utf8_buffer():
		result = int((result ^ int(byte)) * 16777619) & 0x7fffffff
	return result
