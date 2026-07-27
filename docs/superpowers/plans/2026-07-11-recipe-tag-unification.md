# Recipe Tag Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current 59-label recipe vocabulary with 15 canonical gameplay tags, migrate all 149 recipes, remove duplicate tag/rule sources, and make the recipe audit enforce zero tag islands.

**Architecture:** `doc/recipe_tag_taxonomy.json` defines the allowed vocabulary, while `scripts/catalog.gd` remains the only source of per-recipe assignments. Runtime consumers read canonical tags directly; `doc/recipe_display_config.json` keeps geometry only, and `doc/display_rules_full.json` becomes the sole showcase-rule source. A self-contained Python audit validates every cross-file contract before focused Godot checks exercise runtime behavior.

**Tech Stack:** Godot 4.6.1 / GDScript, Python 3 standard library (`unittest`, `json`, `re`), JSON, PowerShell.

## Global Constraints

- The canonical recipe vocabulary contains exactly: `甜`, `苦甜`, `咸香`, `果香`, `茶香`, `奶香`, `香脆`, `软糯`, `清爽`, `浓郁`, `清凉`, `低负担`, `饱腹`, `经典`, `招牌`.
- A recipe without `招牌` has 1–2 tags; a recipe with `招牌` has at most 3 tags.
- No runtime alias or automatic normalization layer may remain after migration.
- Do not change recipe materials, prices, output counts, unlock levels, devices, icons, or showcase shapes.
- Preserve unrelated dirty worktree changes, especially the existing `.gitignore` and `doc/recipe_display_config.json` edits.
- Run Godot commands from `D:\Project\ProjectRest\project-rest` and always pass `--log-file` to a writable path.
- Do not commit unless the user explicitly authorizes commits. The review checkpoints below replace automatic commit steps.

---

## File Structure

- Create `doc/recipe_tag_taxonomy.json`: canonical tag metadata and declared consumer categories.
- Modify `tools/audit_recipe_data.py`: self-contained parsing, canonical-tag validation, consumer coverage, display-tag duplication checks, and strict blockers.
- Modify `tests/test_recipe_data_audit.py`: Python contract tests and invalid-fixture coverage.
- Modify `scripts/catalog.gd`: all 149 final tag assignments, normalized customer conditions, and removal of the duplicate `DISPLAY_RULES` constant.
- Modify `doc/recipe_display_config.json`: remove recipe-level `tags` keys only.
- Modify `doc/display_rules_full.json`: canonicalize `香浓`, add deterministic base-rule priorities.
- Modify `scripts/shop_simulation.gd`: apply at most one base adjacency rule per pair; use typed low-price preference and canonical `饱腹`.
- Modify `scripts/showcase_rule_service.gd`: remove `香气` from theme tag references.
- Modify `scripts/main_view.gd`: remove legacy sweet-tag aliases.
- Create `tests/recipe_tag_rules_self_check.gd`: focused runtime validation for canonical tags, rule priority, set/conflict behavior, and customer scoring.
- Regenerate `doc/recipe_data_audit.md`: final zero-island report.

---

### Task 1: Canonical Taxonomy and Self-Contained Audit

**Files:**
- Create: `doc/recipe_tag_taxonomy.json`
- Modify: `tools/audit_recipe_data.py:1-339`
- Modify: `tests/test_recipe_data_audit.py:1-46`

**Interfaces:**
- Consumes: `scripts/catalog.gd`, `doc/recipe_display_config.json`, `doc/display_rules_full.json`.
- Produces: `load_taxonomy(path: Path) -> dict[str, dict[str, Any]]`, `load_customers(path: Path) -> dict[str, dict[str, Any]]`, and audit keys `illegal_recipe_tags`, `invalid_recipe_tag_counts`, `duplicate_display_tags`, `illegal_consumer_tags`, `orphan_tags`, `legacy_tag_references`.

- [ ] **Step 1: Add failing audit tests**

Extend `tests/test_recipe_data_audit.py` with fixture helpers and these assertions:

```python
import json
import tempfile

CANONICAL_TAGS = {
    "甜", "苦甜", "咸香", "果香", "茶香", "奶香", "香脆", "软糯",
    "清爽", "浓郁", "清凉", "低负担", "饱腹", "经典", "招牌",
}

def test_taxonomy_contains_exact_canonical_vocabulary(self):
    root = Path(__file__).resolve().parents[1]
    data = json.loads((root / "doc/recipe_tag_taxonomy.json").read_text(encoding="utf-8"))
    self.assertEqual(set(data["tags"]), CANONICAL_TAGS)
    self.assertEqual(data["meta"]["total_tags"], 15)

def test_audit_is_self_contained_and_strict_rejects_unknown_tag(self):
    root = Path(__file__).resolve().parents[1]
    catalog_text = (root / "scripts/catalog.gd").read_text(encoding="utf-8-sig")
    catalog_text = catalog_text.replace('"tags": ["经典", "清爽"]', '"tags": ["不存在"]', 1)
    with tempfile.TemporaryDirectory() as raw_tmp:
        tmp = Path(raw_tmp)
        catalog = tmp / "catalog.gd"
        catalog.write_text(catalog_text, encoding="utf-8")
        result = subprocess.run([
            sys.executable, str(root / "tools/audit_recipe_data.py"),
            "--catalog", str(catalog),
            "--taxonomy", str(root / "doc/recipe_tag_taxonomy.json"),
            "--out", str(tmp / "audit.md"), "--strict",
        ], cwd=root, text=True, capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("不存在", (tmp / "audit.md").read_text(encoding="utf-8"))
```

- [ ] **Step 2: Run the tests and verify the intended failures**

Run:

```powershell
python -m unittest tests.test_recipe_data_audit -v
```

Expected: the taxonomy test fails because the file does not exist, and the subprocess test fails because the audit still imports missing `generate_recipe_icon_prompts`.

- [ ] **Step 3: Create the exact taxonomy**

Create `doc/recipe_tag_taxonomy.json` with this shape and all 15 entries:

```json
{
  "meta": {"version": "1.0", "total_tags": 15},
  "tags": {
    "甜": {"category": "风味", "description": "明确甜味", "consumers": ["display_rules", "customers", "tasks", "growth"]},
    "苦甜": {"category": "风味", "description": "可可、咖啡或茶类苦甜", "consumers": ["display_rules", "customers", "growth"]},
    "咸香": {"category": "风味", "description": "咸口主餐或点心", "consumers": ["display_rules", "customers"]},
    "果香": {"category": "香型", "description": "水果主导风味", "consumers": ["display_rules", "customers", "growth"]},
    "茶香": {"category": "香型", "description": "茶底主导风味", "consumers": ["display_rules", "growth"]},
    "奶香": {"category": "香型", "description": "乳制品主导香型", "consumers": ["display_rules"]},
    "香脆": {"category": "口感", "description": "曲奇、酥饼或坚果脆感", "consumers": ["display_rules", "growth"]},
    "软糯": {"category": "口感", "description": "糯米或柔软黏糯口感", "consumers": ["display_rules", "growth"]},
    "清爽": {"category": "风格", "description": "清新、解腻或轻盈风格", "consumers": ["display_rules", "customers", "growth"]},
    "浓郁": {"category": "风格", "description": "奶油、芝士、坚果或厚重风味", "consumers": ["display_rules", "customers", "growth"]},
    "清凉": {"category": "风格", "description": "薄荷或冰凉主题", "consumers": ["display_rules"]},
    "低负担": {"category": "定位", "description": "燕麦、酸奶或轻食定位", "consumers": ["display_rules", "customers", "growth"]},
    "饱腹": {"category": "定位", "description": "主餐或高饱腹产品", "consumers": ["display_rules"]},
    "经典": {"category": "定位", "description": "传统或基础款", "consumers": ["display_rules", "customers", "growth"]},
    "招牌": {"category": "定位", "description": "特色招牌产品", "consumers": ["customers"]}
  }
}
```

- [ ] **Step 4: Make the audit parser self-contained**

Delete the `generate_recipe_icon_prompts` import and define the parsing helpers inside `tools/audit_recipe_data.py`:

```python
DEFAULT_TAXONOMY_PATH = Path("doc/recipe_tag_taxonomy.json")
DISPLAY_REQUIRED_FIELDS = ("recipe_name", "cell_count", "shape_category", "default_shape", "rotatable")
LEGACY_TAGS = {
    "Q弹", "丝滑", "养生", "咸甜", "咸鲜", "回甘", "复合香", "嫩滑", "微苦",
    "扎实", "拉丝", "暖胃", "松软", "栗香", "流心", "浓醇", "润喉", "清冽",
    "清新", "清润", "清淡", "清甘", "清甜", "温润", "湿润", "滋润", "焦脆",
    "焦香", "管饱", "米香", "粉糯", "粗粮", "绵密", "解腻", "软嫩", "酥脆",
    "酸甜", "醇厚", "醇香", "顺滑", "香气", "香甜", "鲜软", "香浓",
}

def _extract_const_block(text: str, const_name: str) -> str:
    marker = f"const {const_name} := {{"
    start = text.index(marker) + len(marker)
    depth = 1
    for index in range(start, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[start:index]
    raise ValueError(f"unterminated const block: {const_name}")

def _string_field(body: str, key: str) -> str | None:
    match = re.search(rf'"{re.escape(key)}"\s*:\s*"([^"]*)"', body)
    return match.group(1) if match else None

def _array_field(body: str, key: str) -> list[str]:
    match = re.search(rf'"{re.escape(key)}"\s*:\s*\[([^]]*)\]', body)
    return re.findall(r'"([^"]+)"', match.group(1)) if match else []

def load_taxonomy(path: Path) -> dict[str, dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    tags = data.get("tags", {})
    if int(data.get("meta", {}).get("total_tags", -1)) != len(tags):
        raise ValueError("taxonomy meta.total_tags does not match tags")
    return {str(key): value for key, value in tags.items()}

def load_customers(path: Path) -> dict[str, dict[str, Any]]:
    block = _extract_const_block(path.read_text(encoding="utf-8-sig"), "CUSTOMERS")
    result = {}
    for line in block.splitlines():
        match = re.match(r'\s*"([^"]+)"\s*:\s*\{(.+?)\},?\s*$', line)
        if match:
            customer_id, body = match.groups()
            result[customer_id] = {"preference_tags": _array_field(body, "preference_tags")}
    return result

def load_structured_tag_references(paths: list[Path]) -> dict[str, set[str]]:
    references: dict[str, set[str]] = {}
    for path in paths:
        text = path.read_text(encoding="utf-8-sig")
        tags: set[str] = set()
        for match in re.finditer(r'"(?:tags|preference_tags)"\s*:\s*\[([^]]*)\]', text):
            tags.update(re.findall(r'"([^"]+)"', match.group(1)))
        tags.update(re.findall(r'"tag"\s*:\s*"([^"]+)"', text))
        references[path.as_posix()] = tags
    return references
```

Add `--taxonomy`, load structured references from `scripts/recipe_growth_service.gd`, `scripts/task_service.gd`, and `scripts/showcase_rule_service.gd`, calculate the six new blocker collections, render each under `## Tag Integrity`, and include them in strict mode. `duplicate_display_tags` is every display recipe containing a `tags` key; `orphan_tags` is `canonical_tags - (rule_tags | customer_preference_tags | structured growth/task tag references)`. Detect runtime legacy compatibility separately by searching `.has("<legacy tag>")` in `scripts/shop_simulation.gd`, `scripts/main_view.gd`, `scripts/showcase_rule_service.gd`, `scripts/recipe_growth_service.gd`, and `scripts/task_service.gd`; do not flag legacy words that occur only in prose.

- [ ] **Step 5: Run the focused Python tests**

Run:

```powershell
python -m unittest tests.test_recipe_data_audit -v
```

Expected: taxonomy and isolated fixture tests pass; the project-generation test may still report legacy data but must no longer crash on import.

- [ ] **Step 6: Review checkpoint**

Review only `doc/recipe_tag_taxonomy.json`, `tools/audit_recipe_data.py`, and `tests/test_recipe_data_audit.py`. Do not commit without explicit user authorization.

---

### Task 2: Migrate All Recipe and Display Data

**Files:**
- Modify: `scripts/catalog.gd:117-287`
- Modify: `scripts/catalog.gd:289-296`
- Modify: `doc/recipe_display_config.json:1-2113`
- Test: `tests/test_recipe_data_audit.py`

**Interfaces:**
- Consumes: `load_taxonomy()` and strict blockers from Task 1.
- Produces: exactly 149 explicit canonical recipe assignments in `Catalog.RECIPES`; display entries without `tags`; typed customer price preference.

- [ ] **Step 1: Prove the current project fails canonical strict mode**

Run:

```powershell
python tools\audit_recipe_data.py --strict --out tmp\recipe_tag_migration_before.md
```

Expected: exit code 1, with legacy recipe tags and duplicate display tags listed.

- [ ] **Step 2: Apply deterministic direct mappings to every recipe line**

Edit only each recipe's `tags` array in `Catalog.RECIPES`. Use these fixed replacements before recipe-specific review:

```text
清甜|香甜 -> 甜
咸鲜 -> 咸香
酥脆|焦脆 -> 香脆
粉糯|Q弹 -> 软糯
醇厚|浓醇|香浓 -> 浓郁
清新|清润|清冽|解腻|清淡 -> 清爽
微苦 -> 苦甜
养生 -> 低负担
暖胃|扎实|管饱 -> 饱腹
```

For ambiguous tags, inspect the recipe's actual `materials` and assign the explicit final array according to the approved rules:

```text
咸甜 -> 咸香 + 甜, unless the recipe has no meaningful sweet component
酸甜 + fruit material -> 果香 + 清爽
酸甜 without fruit -> 甜 + 清爽
香气|复合香 -> one of 果香/茶香/奶香/浓郁 based on primary material
回甘 + tea -> 茶香; 回甘 + coffee/cocoa -> 苦甜
米香 -> 经典 or 软糯 based on product form
栗香 -> 浓郁
丝滑|嫩滑|绵密|流心|拉丝|湿润|滋润|润喉|松软|清甘|温润|焦香|粗粮|软嫩|顺滑|鲜软|醇香 -> remove as tags and replace only when the recipe has a truthful canonical gameplay identity
```

Keep each non-signature recipe at 1–2 tags. Keep `招牌` only on genuine signature recipes, as the optional third tag.

- [ ] **Step 3: Normalize customer conditions**

Change the two pseudo-tag customers to explicit data:

```gdscript
"student": {"id": "student", "name": "放学学生", "preference_tags": ["甜"], "low_price_threshold": 20, "budget": 20, "unlock_level": 1, "description": "喜欢便宜、直接的甜味"},
"blogger": {"id": "blogger", "name": "探店博主", "preference_tags": ["招牌"], "budget": 50, "unlock_level": 5, "description": "追求高价值和特色标签"}
```

Leave the other customer preference arrays unchanged because they already use canonical tags.

- [ ] **Step 4: Remove duplicate display tags without changing geometry**

Remove each recipe-level `tags` key from `doc/recipe_display_config.json`. Do not modify `recipe_name`, `cell_count`, `shape_category`, `default_shape`, `shape_cells`, `rotatable`, `variants`, or `remark`.

Validate JSON and count:

```powershell
python -c "import json,pathlib; p=pathlib.Path('doc/recipe_display_config.json'); d=json.loads(p.read_text(encoding='utf-8-sig')); assert len(d['recipes'])==149; assert all('tags' not in r for r in d['recipes'].values()); print('DISPLAY_TAGS_REMOVED')"
```

Expected: `DISPLAY_TAGS_REMOVED`.

- [ ] **Step 5: Run strict audit and resolve every data-level failure**

Run:

```powershell
python tools\audit_recipe_data.py --strict --out tmp\recipe_tag_migration_after.md
```

Expected at this stage: zero illegal recipe tags, zero invalid tag counts, and zero duplicate display tags. Rule-side `香浓` and runtime legacy references may remain for Tasks 3–4.

- [ ] **Step 6: Review checkpoint**

Inspect `git diff -- scripts/catalog.gd doc/recipe_display_config.json` and verify only tag arrays, the two customer records, and removal of display `tags` changed. Do not commit without explicit user authorization.

---

### Task 3: Single Rule Source and One Base Rule Per Pair

**Files:**
- Modify: `doc/display_rules_full.json:1-205`
- Modify: `scripts/catalog.gd:308-475,542-546`
- Modify: `scripts/shop_simulation.gd:329-404`
- Create: `tests/recipe_tag_rules_self_check.gd`

**Interfaces:**
- Consumes: canonical recipe tags from Task 2.
- Produces: `Catalog.get_display_rules() -> Dictionary` from JSON only; deterministic priority selection in `ShopSimulation._calc_adjacency_tag_bonuses(...)`.

- [ ] **Step 1: Write the failing focused Godot self-check**

Create `tests/recipe_tag_rules_self_check.gd` with a two-rule overlap and existing set/conflict checks:

```gdscript
extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")
const ShopSimulation = preload("res://scripts/shop_simulation.gd")

var failed := false

func _init() -> void:
	var cells := {"left": [Vector2i(0, 0)], "right": [Vector2i(1, 0)]}
	var recipes := {
		"left": {"name": "左侧", "tags": ["果香", "甜"]},
		"right": {"name": "右侧", "tags": ["清爽", "咸香"]},
	}
	var rules := {
		"low": {"priority": 10, "rule_name": "低优先", "trigger_tag_a": "果香", "trigger_tag_b": "清爽", "price_bonus_pct": 5},
		"high": {"priority": 20, "rule_name": "高优先", "trigger_tag_a": "甜", "trigger_tag_b": "咸香", "price_bonus_pct": 12},
	}
	var result: Dictionary = ShopSimulation._calc_adjacency_tag_bonuses(cells, recipes, rules)
	if int((result["left"] as Dictionary).get("price_pct", 0)) != 12:
		_fail("only the highest-priority base rule should apply")
	if ((result["left"] as Dictionary).get("reasons", []) as Array).size() != 1:
		_fail("one adjacent pair should expose one base-rule reason")
	var loaded := Catalog.new().get_display_rules()
	if loaded.get("base_tag_bonuses", {}).is_empty():
		_fail("display rules should load from JSON")
	if failed:
		quit(1)
	print("RECIPE_TAG_RULES_SELF_CHECK_PASS")
	quit(0)

func _fail(message: String) -> void:
	failed = true
	push_error(message)
```

- [ ] **Step 2: Run the self-check and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-tag-rules-red.log" -s res://tests/recipe_tag_rules_self_check.gd
```

Expected: exit code 1 because both matching base rules are summed.

- [ ] **Step 3: Add stable priorities to the eight base rules**

In `doc/display_rules_full.json`, add priorities matching current declaration order to minimize drift:

```text
tag_bonus_001=80, tag_bonus_002=70, tag_bonus_003=60, tag_bonus_004=50,
tag_bonus_005=40, tag_bonus_006=30, tag_bonus_007=20, tag_bonus_008=10
```

Also change `set_bonus_003.required_tags` from `香浓` to `浓郁`.

- [ ] **Step 4: Select one matching base rule per pair**

At the start of `_calc_adjacency_tag_bonuses`, sort rule IDs by descending priority and stable ID:

```gdscript
	var ordered_rule_ids: Array = tag_rules.keys()
	ordered_rule_ids.sort_custom(func(left, right):
		var left_priority := int((tag_rules.get(left, {}) as Dictionary).get("priority", 0))
		var right_priority := int((tag_rules.get(right, {}) as Dictionary).get("priority", 0))
		if left_priority == right_priority:
			return String(left) < String(right)
		return left_priority > right_priority
	)
```

Replace `for rule_id in tag_rules.keys()` with `for rule_id in ordered_rule_ids` and add `break` immediately after recording the matched rule for both recipes. This preserves all existing reason metadata while preventing stacking.

- [ ] **Step 5: Remove the duplicate rule constant and make fallback explicit**

Delete the full `const DISPLAY_RULES := {...}` block from `scripts/catalog.gd`. Replace `get_display_rules()` with:

```gdscript
func get_display_rules() -> Dictionary:
	var rules := _load_json_dictionary(DISPLAY_RULES_PATH)
	if not rules.is_empty():
		return rules
	push_error("Display rules could not be loaded from %s" % DISPLAY_RULES_PATH)
	return {
		"meta": {"version": "missing", "total_rules": 0},
		"base_tag_bonuses": {},
		"set_bonuses": {},
		"conflict_penalties": {},
		"zone_bonuses": {},
	}
```

- [ ] **Step 6: Run focused rule tests**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-tag-rules-green.log" -s res://tests/recipe_tag_rules_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-bonus-reason.log" -s res://tests/showcase_bonus_reason_self_check.gd
```

Expected: `RECIPE_TAG_RULES_SELF_CHECK_PASS` and `SHOWCASE_BONUS_REASON_SELF_CHECK_PASS`.

- [ ] **Step 7: Review checkpoint**

Review rule ordering, the single `break`, JSON priorities, and removal of the fallback constant. Do not commit without explicit user authorization.

---

### Task 4: Normalize Runtime Consumers

**Files:**
- Modify: `scripts/shop_simulation.gd:574-599,767-780,839-846`
- Modify: `scripts/showcase_rule_service.gd:15-19`
- Modify: `scripts/main_view.gd:6104-6113`
- Modify: `tests/recipe_tag_rules_self_check.gd`
- Modify: `tests/mvp_self_check.gd:765-804`

**Interfaces:**
- Consumes: canonical customer data from Task 2 and canonical rules from Task 3.
- Produces: customer scoring without pseudo-tags and runtime code with no structured legacy tag references.

- [ ] **Step 1: Extend the focused self-check with customer scoring assertions**

Add before the final pass branch in `tests/recipe_tag_rules_self_check.gd`:

```gdscript
	var student := {"preference_tags": ["甜"], "low_price_threshold": 20, "budget": 20}
	var cheap_sweet := {"tags": ["甜"], "price": 18}
	var expensive_sweet := {"tags": ["甜"], "price": 28}
	var cheap_score := ShopSimulation._score_product(student, cheap_sweet, 1)
	var expensive_score := ShopSimulation._score_product(student, expensive_sweet, 1)
	if cheap_score <= expensive_score:
		_fail("typed low-price preference should favor the affordable recipe")
	var blogger := {"id": "blogger", "preference_tags": ["招牌"], "budget": 50}
	if ShopSimulation._score_product(blogger, {"tags": ["招牌"], "price": 40}, 1) <= 10:
		_fail("blogger should retain the signature bonus")
```

Run the focused test and expect failure because `_score_product` still checks the pseudo-tag `低价`.

- [ ] **Step 2: Replace pseudo-tag scoring with typed data**

Replace the low-price block in `_score_product` with:

```gdscript
	var low_price_bonus := 0
	var low_price_threshold := maxi(0, int(customer.get("low_price_threshold", 0)))
	if low_price_threshold > 0 and price <= low_price_threshold:
		low_price_bonus = 8
```

Keep the existing `招牌` bonus and budget penalty unchanged.

- [ ] **Step 3: Remove legacy tag compatibility from runtime consumers**

Make these exact replacements:

```gdscript
# scripts/shop_simulation.gd
if tags.has("咸香") or tags.has("饱腹"):

# scripts/main_view.gd sweet filter branch
return _recipe_tags(recipe).has("甜")

# scripts/showcase_rule_service.gd
"retro": {"label": "复古", "tags": ["经典", "茶香", "浓郁"], "price_pct": 6.0, "speed_pct": 0.0},
```

Do not replace legacy words in human-readable descriptions, labels, or recipe names; the audit must target structured tag references rather than prose.

- [ ] **Step 4: Tighten existing customer contract validation**

In `_expect_customer_preference_tags()` in `tests/mvp_self_check.gd`, load the canonical taxonomy JSON and assert every `preference_tags` entry is canonical. Add a separate assertion that `student.low_price_threshold == 20` and that no customer preference contains `低价` or `稀有`.

- [ ] **Step 5: Run consumer and MVP checks**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-tag-consumers.log" -s res://tests/recipe_tag_rules_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-tag-mvp.log" -s res://tests/mvp_self_check.gd
```

Expected: focused pass marker and `MVP_SELF_CHECK_PASS`.

- [ ] **Step 6: Review checkpoint**

Confirm only structured tag checks changed; user-facing prose remains intact. Do not commit without explicit user authorization.

---

### Task 5: Rule Matrix, Final Audit, and Regression Gate

**Files:**
- Modify: `tools/audit_recipe_data.py`
- Modify: `tests/test_recipe_data_audit.py`
- Regenerate: `doc/recipe_data_audit.md`

**Interfaces:**
- Consumes: completed canonical data and runtime rules from Tasks 1–4.
- Produces: pairwise `rule_match_matrix` summary, strict zero-island audit, and final verification evidence.

- [ ] **Step 1: Add a failing pairwise matrix test**

Add a Python test that calls a new `build_rule_match_matrix(recipes, base_rules)` helper and asserts no pair has more than one selected rule and every base rule has a coverage count:

```python
def test_rule_match_matrix_selects_at_most_one_rule_per_pair(self):
    root = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(root / "tools"))
    import audit_recipe_data as audit
    recipes = audit.load_catalog(root / "scripts/catalog.gd")
    rules = audit.load_display_rules(root / "doc/display_rules_full.json")["base_tag_bonuses"]
    matrix = audit.build_rule_match_matrix(recipes, rules)
    self.assertEqual(matrix["selected_pair_count"], sum(matrix["coverage_by_rule"].values()))
    self.assertEqual(set(matrix["coverage_by_rule"]), set(rules))
```

Expected before implementation: failure because `build_rule_match_matrix` is undefined.

- [ ] **Step 2: Implement deterministic matrix generation**

Add:

```python
def build_rule_match_matrix(recipes: dict[str, dict[str, Any]], rules: dict[str, Any]) -> dict[str, Any]:
    ordered = sorted(rules, key=lambda rule_id: (-int(rules[rule_id].get("priority", 0)), rule_id))
    coverage = {rule_id: 0 for rule_id in rules}
    selected_pairs = []
    multi_match_pairs = []
    recipe_ids = sorted(recipes)
    for index, left_id in enumerate(recipe_ids):
        left_tags = set(recipes[left_id].get("tags", []))
        for right_id in recipe_ids[index + 1:]:
            right_tags = set(recipes[right_id].get("tags", []))
            matches = []
            for rule_id in ordered:
                rule = rules[rule_id]
                tag_a = str(rule.get("trigger_tag_a", ""))
                tag_b = str(rule.get("trigger_tag_b", ""))
                if (tag_a in left_tags and tag_b in right_tags) or (tag_b in left_tags and tag_a in right_tags):
                    matches.append(rule_id)
            if matches:
                selected = matches[0]
                coverage[selected] += 1
                selected_pairs.append({"left": left_id, "right": right_id, "rule": selected})
            if len(matches) > 1:
                multi_match_pairs.append({"left": left_id, "right": right_id, "matches": matches})
    return {
        "selected_pair_count": len(selected_pairs),
        "coverage_by_rule": coverage,
        "multi_match_pairs": multi_match_pairs,
    }
```

The runtime intentionally chooses one rule when several match; the report should list raw multi-match candidates as a warning, not a blocker, while asserting selected runtime output is singular.

- [ ] **Step 3: Render final integrity and matrix sections**

Add these headings to `render_markdown()`:

```markdown
## Tag Integrity
### Illegal recipe tags
### Invalid recipe tag counts
### Duplicate display tags
### Illegal consumer tags
### Legacy structured tag references
### Tag islands

## Base Rule Match Matrix
- Selected recipe pairs: N
- Raw multi-match candidates: N
```

Render all 15 canonical tag usage counts and all eight base-rule coverage counts. Strict mode must fail on illegal tags, invalid counts, duplicate display tags, illegal consumer tags, legacy structured references, or orphan tags; raw multi-match candidates remain reported because priority resolves them deterministically.

- [ ] **Step 4: Run all Python audit tests and regenerate the report**

Run:

```powershell
python -m unittest tests.test_recipe_data_audit -v
python tools\audit_recipe_data.py --strict --out doc\recipe_data_audit.md
```

Expected: all tests pass, exit code 0, and the report shows `None` for all blocking/tag-integrity lists with zero tag islands.

- [ ] **Step 5: Run the final Godot verification gate**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-tag-final-focused.log" -s res://tests/recipe_tag_rules_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-tag-final-showcase.log" -s res://tests/showcase_bonus_reason_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-tag-final-mvp.log" -s res://tests/mvp_self_check.gd
```

Expected: all commands exit 0 with their pass markers.

- [ ] **Step 6: Verify final scope and hand off**

Run:

```powershell
git diff --check
git status --short
git diff -- doc/recipe_tag_taxonomy.json tools/audit_recipe_data.py tests/test_recipe_data_audit.py scripts/catalog.gd doc/recipe_display_config.json doc/display_rules_full.json scripts/shop_simulation.gd scripts/showcase_rule_service.gd scripts/main_view.gd tests/recipe_tag_rules_self_check.gd tests/mvp_self_check.gd doc/recipe_data_audit.md
```

Expected: no whitespace errors; only planned files plus pre-existing unrelated user changes appear. Do not commit unless the user explicitly requests it.
