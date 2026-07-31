extends SceneTree

const AUDIT_PATH := "res://doc/challenge/recipe_similarity_audit.json"
const RECIPES_PATH := "res://doc/challenge/challenge_recipes.json"

var _failures: Array[String] = []


func _init() -> void:
	var audit := _load_json(AUDIT_PATH)
	var runtime := _load_json(RECIPES_PATH)
	var recipes: Dictionary = runtime.get("recipes", {})
	var summary: Dictionary = audit.get("summary", {})
	var proposal: Dictionary = audit.get("pilot_proposal", {})
	var confirmed: Dictionary = audit.get("confirmed_pilot_evaluation", {})
	var clusters: Array = audit.get("exact_duplicate_clusters", [])
	var recipe_ids := {}
	for recipe_id in recipes:
		recipe_ids[String(recipe_id)] = true

	_expect(
		int(audit.get("schema_version", 0)) == 2,
		"similarity audit schema should remain version 2"
	)
	_expect(
		int(summary.get("recipe_count", 0)) == recipes.size(),
		"similarity audit recipe count should match runtime"
	)
	_expect(
		int(summary.get("exact_duplicate_cluster_count", -1)) == clusters.size(),
		"similarity audit cluster count should match its cluster payload"
	)

	var clustered_count := 0
	var seen_clustered := {}
	for cluster_value in clusters:
		if not cluster_value is Dictionary:
			_failures.append("similarity audit cluster must be a dictionary")
			continue
		var cluster: Dictionary = cluster_value
		var members: Array = cluster.get("recipes", [])
		_expect(members.size() >= 2, "exact duplicate cluster must have at least two recipes")
		for member_value in members:
			if not member_value is Dictionary:
				_failures.append("cluster member must be a dictionary")
				continue
			var recipe_id := String(member_value.get("recipe_id", ""))
			_expect(recipe_ids.has(recipe_id), "cluster recipe must exist: %s" % recipe_id)
			_expect(
				not seen_clustered.has(recipe_id),
				"recipe must not appear in multiple exact clusters: %s" % recipe_id
			)
			seen_clustered[recipe_id] = true
			clustered_count += 1
	_expect(
		clustered_count == int(summary.get("recipes_in_exact_duplicate_clusters", -1)),
		"clustered recipe count should match audit summary"
	)

	var pilot_ids: Array = proposal.get("recipe_ids", [])
	var target_range: Array = proposal.get("target_range", [])
	_expect(
		target_range.size() == 2
		and int(target_range[0]) == 10
		and int(target_range[1]) == 12,
		"pilot target range should remain 10-12 recipes"
	)
	_expect(
		pilot_ids.size() >= 10 and pilot_ids.size() <= 12,
		"pilot proposal should contain 10-12 recipes"
	)
	for recipe_id_value in pilot_ids:
		var recipe_id := String(recipe_id_value)
		_expect(recipe_ids.has(recipe_id), "pilot recipe must exist: %s" % recipe_id)
		_expect(
			seen_clustered.has(recipe_id),
			"pilot recipe should come from an exact duplicate cluster: %s" % recipe_id
		)
	_expect(
		String(proposal.get("status", "")) == "proposal_only_no_balance_changes",
		"next pilot proposal must remain non-mutating until product approval"
	)
	_expect(
		String(confirmed.get("status", "")) == "pass",
		"confirmed distinctiveness pilot should pass its acceptance contract"
	)
	_expect(
		int(confirmed.get("recipe_count", 0)) == 12,
		"confirmed distinctiveness pilot should contain 12 recipes"
	)
	_expect(
		int(confirmed.get("global_exact_collision_count", -1)) == 0,
		"confirmed pilot recipes should have globally unique exact signatures"
	)
	_expect(
		int(confirmed.get("internal_near_duplicate_pair_count", -1)) == 0,
		"confirmed pilot recipes should have no internal near-duplicate pairs"
	)
	_expect(
		int(confirmed.get("involved_dominance_relation_count", -1)) == 0,
		"confirmed pilot recipes should not participate in dominance relations"
	)
	_finish()


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_failures.append("%s must contain a JSON dictionary" % path)
		return {}
	return parsed


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_RECIPE_DISTINCTIVENESS_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
