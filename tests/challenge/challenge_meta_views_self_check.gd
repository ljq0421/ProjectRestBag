extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")
const ChallengeLoadoutService = preload("res://scripts/challenge/challenge_loadout_service.gd")
const RunUpgradeService = preload("res://scripts/challenge/run_upgrade_service.gd")

const VIEW_PATHS := [
	"res://scenes/challenge/challenge_hub_view.tscn",
	"res://scenes/challenge/challenge_preparation_view.tscn",
	"res://scenes/challenge/challenge_upgrade_select_view.tscn",
	"res://scenes/challenge/challenge_research_view.tscn",
	"res://scenes/challenge/challenge_run_summary_view.tscn"
]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var instances := {}
	for path in VIEW_PATHS:
		var packed: PackedScene = load(path)
		_expect(packed != null, "view should load: %s" % path)
		if packed == null:
			continue
		var instance = packed.instantiate()
		_expect(instance != null, "view should instantiate: %s" % path)
		if instance != null:
			root.add_child(instance)
			instances[instance.name] = instance

	var hub = instances.get("ChallengeHubView")
	if hub != null:
		hub.bind({"research_points": 3, "unlocked_recipe_ids": ["a", "b"]}, null)
		_expect(hub.get_node("Content/Actions/StartButton").visible, "hub should show start without active run")
		hub.bind({"research_points": 3, "unlocked_recipe_ids": ["a", "b"]}, {
			"stage_index": 2,
			"confidence": 1
		})
		_expect(hub.get_node("Content/Actions/ContinueButton").visible, "hub should show continue with active run")

	var preparation = instances.get("ChallengePreparationView")
	if preparation != null:
		_expect(
			preparation.get_node("SupplyScroll/SupplyStrip").get_child_count() == 0,
			"preparation scene should not contain hard-coded supply cards"
		)
		var recipe_defs := _recipe_defs()
		var effective := RunUpgradeService.new().resolve_context(
			recipe_defs,
			{"supply_budget": 8},
			[]
		)
		preparation.bind(
			{
				"stage_index": 0,
				"confidence": 2,
				"run_upgrades": [
					{"upgrade_id": "test_a", "stack_count": 2},
					{"upgrade_id": "test_b", "stack_count": 1},
					{"upgrade_id": "test_c", "stack_count": 1}
				],
				"loadout_draft": {"placements": []},
				"permanent_pool_snapshot": {
					"recipe_ids": ["z_recipe", "a_recipe"]
				}
			},
			_encounter(),
			effective,
			ChallengeLoadoutService.new(),
			Catalog.new().get_recipes()
		)
		_expect(
			"本局强化 4" in preparation.get_node("StageMeta").text,
			"preparation should count stacked upgrades instead of merged entries"
		)
		var supply_cards: Array = preparation.supply_cards()
		_expect(supply_cards.size() == 2, "preparation should build supply cards from frozen pool")
		if supply_cards.size() == 2:
			_expect(
				String(supply_cards[0].get_meta("recipe_id", "")) == "a_recipe",
				"dynamic supply cards should use stable recipe ID order"
			)

	var upgrade_view = instances.get("ChallengeUpgradeSelectView")
	if upgrade_view != null:
		upgrade_view.bind(_offer())
		_expect(
			upgrade_view.get_node("Content/Candidates/Candidate0").visible
			and upgrade_view.get_node("Content/Candidates/Candidate2").visible,
			"upgrade view should show exactly three persisted candidates"
		)
		_expect(
			not "run:upgrade" in upgrade_view.get_node("Content/OfferIdentity").text,
			"upgrade page should not expose the persisted offer transaction ID"
		)

	var research_view = instances.get("ChallengeResearchView")
	if research_view != null:
		research_view.bind(_research_tree(), {"research_points": 3}, {
			"butter_cookie": {
				"revealed": true,
				"unlocked": false,
				"unlockable": true,
				"cost": 3,
				"status": "available",
				"build_purpose": "测试构筑"
			}
		})
		var branch_buttons = research_view.get_node(
			"Content/Branches/BranchRail/Content/BranchScroll/BranchButtons"
		)
		var node_list = research_view.get_node(
			"Content/Branches/NodePanel/Content/NodeScroll/NodeList"
		)
		_expect(
			branch_buttons.get_child_count() == 3,
			"research view should render its dynamic branch navigation"
		)
		if node_list.get_child_count() >= 1:
			var branch_title: Label = research_view.get_node(
				"Content/Branches/NodePanel/Content/BranchTitle"
			)
			_expect(
				branch_title.get_theme_color("font_color").is_equal_approx(Color("#29213D")),
				"selected research branch heading should keep readable dark text"
			)
			var research_button: Button = node_list.get_child(0)
			_expect("黄油曲奇" in research_button.text, "research node should use the player-facing recipe name")
			_expect(not "available" in research_button.text, "research node should translate internal status values")

	var summary = instances.get("ChallengeRunSummaryView")
	if summary != null:
		summary.bind({
			"phase": "run_complete",
			"confidence": 1,
			"run_upgrades": [
				{"upgrade_id": "test_a", "stack_count": 2},
				{"upgrade_id": "test_b", "stack_count": 1},
				{"upgrade_id": "test_c", "stack_count": 1}
			],
			"research_rewarded": false,
			"stage_history": [
				{"kind": "battle"},
				{"kind": "battle"},
				{"kind": "battle"},
				{"kind": "battle"},
				{"kind": "battle"}
			]
		}, {"research_points": 0})
		_expect(
			summary.get_node("Content/Actions/RewardButton").visible,
			"completed unrewarded run should show reward action"
		)
		_expect(
			"获得强化 4 个" in summary.get_node("Content/History").text,
			"summary should count stacked upgrades instead of merged upgrade entries"
		)

	for instance in instances.values():
		instance.queue_free()
	_finish()


func _recipe_defs() -> Dictionary:
	var result := {}
	for recipe_id in ["a_recipe", "z_recipe"]:
		result[recipe_id] = {
			"shape_cells": [[0, 0]],
			"supply_cost": 1,
			"copy_limit": 1,
			"virtual_stock": 3,
			"cycle_ms": 3000,
			"satisfaction": 4,
			"tags": ["fast"],
			"rotatable": false
		}
	return result


func _encounter() -> Dictionary:
	return {
		"id": "test",
		"display_name": "测试客潮",
		"duration_ms": 10000,
		"initial_pickiness": 10,
		"initial_reputation": 100,
		"relation": {},
		"windows": [{
			"id": "rush",
			"at_ms": 5000,
			"metric": "sales_count",
			"target": 1,
			"reputation_damage": 10
		}]
	}


func _offer() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for index in range(3):
		candidates.append({
			"id": "upgrade_%d" % index,
			"upgrade_id": "upgrade_%d" % index,
			"display_name": "强化 %d" % (index + 1),
			"description": "改变构筑的测试强化",
			"category": "universal"
		})
	return {
		"offer_id": "run:upgrade:0",
		"candidate_ids": ["upgrade_0", "upgrade_1", "upgrade_2"],
		"candidates": candidates
	}


func _research_tree() -> Dictionary:
	return {
		"branches": [
			{"id": "tempo", "display_name": "节奏", "description": "更快出餐", "node_ids": ["butter_cookie"]},
			{"id": "fruit", "display_name": "水果", "description": "标签覆盖", "node_ids": []},
			{"id": "signature", "display_name": "招牌", "description": "高满足力", "node_ids": []}
		],
		"nodes": {
			"butter_cookie": {"tier": 1, "cost": 3, "build_purpose": "测试构筑"}
		}
	}


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_META_VIEWS_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
