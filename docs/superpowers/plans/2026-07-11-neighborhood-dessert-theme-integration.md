# Neighborhood Dessert Theme Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable Godot Theme from the neighborhood dessert PNG assets and apply role-specific skin variants to the current game UI without changing business behavior or stable node paths.

**Architecture:** Preserve ImageGen PNGs as source assets. A deterministic Python builder crops each state family with one shared alpha union, downsizes it to runtime dimensions, and writes aligned PNGs under `runtime/`; a single `.tres` Theme references those files through semantic type variations. Existing `.tscn` files opt into the variations, while a focused headless self-check verifies resource integrity and scene mappings.

**Tech Stack:** Godot 4.6.1, GDScript scene self-checks, Godot `Theme` and `StyleBoxTexture`, Python 3 with Pillow for deterministic image preprocessing.

## Global Constraints

- Preserve all existing PNGs in `resources/ui/skin/neighborhood_dessert/` unchanged.
- Do not include `_preview_*.png` in the runtime skin or Theme.
- Keep every state in a family pixel-aligned by using one shared crop rectangle and output size.
- Keep layout and stable node paths in `.tscn`; do not restructure `WorkbenchPanel` or other container hierarchies.
- Do not modify business logic, persistence, recipes, catalog data, or game rules.
- Run Godot headless commands from the directory containing `project.godot` and always pass `--log-file` to a writable temporary path.
- Do not commit changes unless the user explicitly asks.

---

### Task 1: Add the failing Theme contract self-check

**Files:**
- Create: `tests/neighborhood_dessert_theme_self_check.gd`

**Interfaces:**
- Consumes: the expected Theme path and semantic variation names from the approved design.
- Produces: exit code `0` and `NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_PASS` only when Theme resources and scene mappings are complete.

- [ ] **Step 1: Write the failing test**

Create a `SceneTree` self-check that loads `res://resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres`, verifies these variations and styles, and then instantiates `res://scenes/Main.tscn`:

```gdscript
extends SceneTree

const THEME_PATH := "res://resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"

const REQUIRED_STYLES := {
	"DessertPrimaryButton": ["normal", "hover", "pressed", "disabled"],
	"DessertSecondaryButton": ["normal", "hover", "pressed", "disabled"],
	"DessertFlatButton": ["normal", "hover", "pressed", "disabled"],
	"DessertIconButton": ["normal", "hover", "pressed", "disabled"],
	"DessertTopTabButton": ["normal", "hover", "pressed", "disabled"],
	"DessertMainPanel": ["panel"],
	"DessertSectionPanel": ["panel"],
	"DessertInsetPanel": ["panel"],
	"DessertModalPanel": ["panel"],
}

var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var theme := load(THEME_PATH) as Theme
	if theme == null:
		_fail("Theme is missing")
		_finish()
		return
	for variation in REQUIRED_STYLES:
		for style_name in REQUIRED_STYLES[variation]:
			var style := theme.get_stylebox(style_name, variation)
			if not style is StyleBoxTexture:
				_fail("%s/%s must be StyleBoxTexture" % [variation, style_name])
			elif (style as StyleBoxTexture).texture == null:
				_fail("%s/%s texture is missing" % [variation, style_name])
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Main scene is missing")
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	_check_variation(main, "Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/LeftActionHalf/PrimaryActionButton", "DessertPrimaryButton")
	_check_variation(main, "Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/RightActionHalf/SecondaryActionButton", "DessertSecondaryButton")
	_check_variation(main, "Root/Body/MainArea/WorkbenchPanel/ContentPanel/ActionRow/RightActionHalf/TertiaryActionButton", "DessertFlatButton")
	_check_variation(main, "GlobalOverlayLayer", "DessertModalPanel")
	var backdrop := main.get_node_or_null("GlobalPopupBackdrop") as Button
	if backdrop == null or not backdrop.flat or not backdrop.theme_type_variation.is_empty():
		_fail("GlobalPopupBackdrop must remain an unskinned flat button")
	main.queue_free()
	_finish()

func _check_variation(root_node: Node, path: NodePath, expected: StringName) -> void:
	var control := root_node.get_node_or_null(path) as Control
	if control == null:
		_fail("Missing control: %s" % path)
	elif control.theme_type_variation != expected:
		_fail("%s variation should be %s" % [path, expected])

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_PASS")
		quit(0)
	else:
		quit(1)
```

- [ ] **Step 2: Run the self-check and verify RED**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\projectrest-neighborhood-theme.log" `
  -s res://tests/neighborhood_dessert_theme_self_check.gd
```

Expected: non-zero exit with `Theme is missing` because the Theme has not been created.

### Task 2: Build aligned runtime PNGs

**Files:**
- Create: `tools/build_neighborhood_dessert_skin.py`
- Create: `resources/ui/skin/neighborhood_dessert/runtime/*.png`

**Interfaces:**
- Consumes: transparent source PNGs in `resources/ui/skin/neighborhood_dessert/`.
- Produces: deterministic runtime PNGs required by the Theme, with one crop and output geometry per state family.

- [ ] **Step 1: Implement the source-family builder**

The script must use explicit family configuration, union all alpha bounding boxes in a family, add a four-pixel source safety pad, resize every state through the same geometry, and write RGBA PNGs. Initial families and visible target sizes are:

```python
FAMILIES = {
    "button_primary": (["normal", "hover", "pressed", "disabled"], (144, 40)),
    "button_secondary": (["normal", "hover", "pressed", "disabled"], (144, 40)),
    "button_flat": (["normal", "hover", "pressed", "disabled"], (144, 36)),
    "button_icon": (["normal", "hover", "pressed", "disabled"], (40, 40)),
    "tab_top": (["normal", "hover", "selected", "disabled"], (144, 40)),
    "panel_main": (["normal"], (320, 200)),
    "panel_section": (["normal"], (280, 160)),
    "panel_inset": (["normal"], (280, 160)),
    "panel_modal": (["normal"], (320, 200)),
}
```

Output filenames must remain identical to the source filenames under `runtime/`. The script must fail before writing any files when a required source is missing, lacks alpha, or a state family's source canvases differ.

- [ ] **Step 2: Run the builder**

Run:

```powershell
& "C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" `
  tools/build_neighborhood_dessert_skin.py
```

Expected: one success line per family and all configured files under `resources/ui/skin/neighborhood_dessert/runtime/`.

- [ ] **Step 3: Verify generated alignment**

Run the builder with `--check`. It must reopen outputs and verify each family has identical canvas size and identical alpha bounding box across all states. Expected: `NEIGHBORHOOD_DESSERT_RUNTIME_SKIN_CHECK_PASS`.

### Task 3: Create the centralized Godot Theme

**Files:**
- Create: `resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres`

**Interfaces:**
- Consumes: runtime PNG paths from Task 2.
- Produces: semantic Theme variations used by scenes in Task 4.

- [ ] **Step 1: Define texture resources and StyleBoxTexture resources**

Reference every runtime PNG as an `ext_resource`. Each button state uses the matching texture; each panel uses its single normal texture. Use shared geometry within each family:

```text
button primary/secondary: texture margins 18, 12, 18, 12; content margins 18, 8, 18, 8
button flat: texture margins 16, 10, 16, 10; content margins 16, 7, 16, 7
button icon: texture margins 16, 16, 16, 16; content margins 8, 8, 8, 8
top tab: texture margins 16, 12, 16, 12; content margins 16, 8, 16, 8
main/modal panel: texture margins 30, 30, 30, 30; content margins 22, 20, 22, 20
section/inset panel: texture margins 24, 24, 24, 24; content margins 16, 14, 16, 14
```

Set horizontal and vertical axis stretch to stretch, not tile, because each center region was generated to be nearly flat.

- [ ] **Step 2: Define semantic variations**

Add variation bases and style mappings:

```text
DessertPrimaryButton -> Button
DessertSecondaryButton -> Button
DessertFlatButton -> Button
DessertIconButton -> Button
DessertTopTabButton -> Button
DessertMainPanel -> PanelContainer
DessertSectionPanel -> PanelContainer
DessertInsetPanel -> PanelContainer
DessertModalPanel -> PanelContainer
```

For `DessertTopTabButton`, map `tab_top_selected.png` to both `pressed` and `hover_pressed`. For ordinary buttons, reuse `normal` as `focus` to avoid adding an unrelated focus outline in this pass.

- [ ] **Step 3: Run Theme contract check**

Run the Task 1 command. Expected: the Theme-style assertions pass, then the test fails on missing scene variation mappings.

### Task 4: Apply Theme variations to current scenes

**Files:**
- Modify: `scenes/Main.tscn`
- Modify: `scenes/ui/pages/workbench_pages.tscn`
- Modify: `scenes/ui/pages/output_site_region.tscn`

**Interfaces:**
- Consumes: `neighborhood_dessert_theme.tres` and its named variations.
- Produces: a Main scene whose current role-specific controls use the skin without node-path changes.

- [ ] **Step 1: Load the Theme at the Main root**

Add the Theme as an external resource in `Main.tscn` and set the root `Main` control's `theme` property to that resource. Do not define a base `Button` or base `PanelContainer` style in the Theme, so unassigned controls keep their current appearance.

- [ ] **Step 2: Map action and navigation buttons**

Set these properties in `Main.tscn`:

```text
PrimaryActionButton.theme_type_variation = &"DessertPrimaryButton"
SecondaryActionButton.theme_type_variation = &"DessertSecondaryButton"
TertiaryActionButton.theme_type_variation = &"DessertFlatButton"
TaskButton, InventoryButton, CatalogButton = &"DessertSecondaryButton"
PurchaseButton, OutputButton, ResearchButton, StorefrontManageButton = &"DessertTopTabButton"
OverlayCloseButton = &"DessertIconButton"
```

Do not assign any variation to `GlobalPopupBackdrop`.

- [ ] **Step 3: Map panels**

Remove only the obsolete local `theme_override_styles/panel` where the new Theme variation replaces it, then assign:

```text
GlobalOverlayLayer = &"DessertModalPanel"
StorefrontOverviewPanel, StorefrontSettlePanel, StorefrontBonusPanel,
StorefrontReceiptPanel, StorefrontRiskPanel, StorefrontExpansionPanel = &"DessertSectionPanel"
ResearchHintPanel = &"DessertInsetPanel"
OutputSiteRegion = &"DessertInsetPanel"
```

Do not change container node types or parent paths.

- [ ] **Step 4: Verify GREEN**

Run the Task 1 command. Expected: exit code `0` with `NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_PASS`.

- [ ] **Step 5: Run focused existing checks**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\projectrest-layout-refinement.log" `
  -s res://tests/layout_refinement_self_check.gd
```

If this check has an unrelated pre-existing failure, record the exact failure and separately prove the Theme self-check remains green. Do not modify unrelated gameplay behavior to make a broad check pass.

- [ ] **Step 6: Inspect the final scene visually**

Launch or capture the main scene at the 1920×1080 design viewport and inspect normal, hover, pressed, selected, and disabled button states plus modal and inset panel stretching. Confirm no visible transparent padding, corner distortion, text jump, clipped labels, or styled backdrop.

### Task 5: Final verification and handoff

**Files:**
- Verify only; no new production files unless a failure requires a scoped fix.

**Interfaces:**
- Consumes: all artifacts from Tasks 1–4.
- Produces: evidence-backed completion summary.

- [ ] **Step 1: Re-run deterministic asset check**

Run the builder with `--check` and require `NEIGHBORHOOD_DESSERT_RUNTIME_SKIN_CHECK_PASS`.

- [ ] **Step 2: Re-run the focused Theme self-check**

Require `NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_PASS` with exit code `0`.

- [ ] **Step 3: Review scoped diff**

Run:

```powershell
git diff -- tools/build_neighborhood_dessert_skin.py tests/neighborhood_dessert_theme_self_check.gd resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres scenes/Main.tscn scenes/ui/pages/workbench_pages.tscn scenes/ui/pages/output_site_region.tscn
```

Confirm the diff contains only skin generation, Theme definitions, semantic scene mappings, and self-check coverage.

### Task 6: Integrate the storefront showcase skin

**Files:**
- Modify: `tools/build_neighborhood_dessert_skin.py`
- Modify: `resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres`
- Modify: `scenes/ui/storefront/showcase_board.tscn`
- Modify: `scenes/ui/storefront/showcase_slot.tscn`
- Modify: `scripts/ui/storefront/showcase_slot.gd`
- Modify: `scripts/main_view.gd`
- Create: `tests/showcase_skin_self_check.gd`

**Interfaces:**
- Consumes: `slot_item_{normal|hover|selected|locked|disabled|reward}.png`, `status_tag_{normal|positive}.png`, and existing `DessertMainPanel`.
- Produces: a skinned showcase panel and 80×80 slot controls whose theme states coexist with multi-cell product outlines.

- [ ] **Step 1: Write the failing showcase skin self-check**

Verify the Theme contains `DessertShowcaseSlot`, `DessertShowcaseSlotLocked`, `DessertShowcaseSlotReward`, `DessertShowcaseBadge`, and `DessertShowcaseBadgeReady`; verify the board root is a `PanelContainer` using `DessertMainPanel`; verify the slot scene exposes a separate `GroupOutline` panel and changes variations through `set_skin_state()` without adding style overrides to the Button itself.

- [ ] **Step 2: Run the self-check and verify RED**

Run with Godot 4.6.1 and a writable `--log-file`. Expected: failure because the new Theme variations and `GroupOutline` node do not exist.

- [ ] **Step 3: Add aligned runtime families**

Extend the builder with:

```python
"slot_item": Family(("normal", "hover", "selected", "locked", "disabled", "reward"), (80, 80)),
"status_tag": Family(("normal", "positive"), (64, 20)),
```

Rebuild and require shared size and alpha alignment within each family.

- [ ] **Step 4: Add showcase Theme variations**

Map `DessertShowcaseSlot` normal/hover/pressed/disabled to the matching slot textures. Map every visual state of `DessertShowcaseSlotLocked` to the locked texture and every state of `DessertShowcaseSlotReward` to the reward texture. Map `DessertShowcaseBadge` and `DessertShowcaseBadgeReady` to Label `normal` StyleBoxTexture resources based on normal and positive status tags.

- [ ] **Step 5: Skin the board without breaking product outlines**

Change the showcase board root to `PanelContainer` using `DessertMainPanel`, place its current title, summary, scroll and grid under a `ShowcaseContent` VBoxContainer, and update exact node paths in `main_view.gd`. Add a full-rect mouse-ignoring `GroupOutline` Panel to each slot; move dynamic `StyleBoxFlat` outline overrides from the Button to this overlay so the slot texture remains visible.

- [ ] **Step 6: Map runtime showcase states**

Reset every refreshed slot to `DessertShowcaseSlot`. Use `DessertShowcaseSlotLocked` for expansion-locked cells and `DessertShowcaseSlotReward` when an occupied slot has `sale_ready_at_unix > 0` and is ready to sell. Keep selected artwork mapped to the Button pressed state, and keep preview tint and multi-cell outlines layered above the base skin.

- [ ] **Step 7: Verify GREEN and regressions**

Require `SHOWCASE_SKIN_SELF_CHECK_PASS`, `NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_PASS`, `LAYOUT_REFINEMENT_SELF_CHECK_PASS`, and `NEIGHBORHOOD_DESSERT_RUNTIME_SKIN_CHECK_PASS`.

### Task 7: Skin the right-side workbench panel without changing paths

**Files:**
- Create: `scripts/ui/common/skinned_vbox_container.gd`
- Modify: `resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres`
- Modify: `scenes/Main.tscn`
- Modify: `tests/neighborhood_dessert_theme_self_check.gd`

**Interfaces:**
- Consumes: the existing runtime `panel_main_normal.png` and `StyleBox_panel_main` Theme resource.
- Produces: `DessertWorkbenchPanel`, a VBoxContainer Theme variation whose panel StyleBox is drawn behind the existing WorkbenchPanel children.

- [ ] **Step 1: Extend the Theme self-check and verify RED**

Require `DessertWorkbenchPanel/panel`, assert `WorkbenchPanel` remains a `VBoxContainer`, uses `DessertWorkbenchPanel`, loads a skin-drawing script, and preserves direct `ConsoleTabs` and `ContentPanel` child paths. Expected failure: the variation and script are missing.

- [ ] **Step 2: Add the skinned VBoxContainer helper**

Create a focused script that extends `VBoxContainer`, resolves the current variation's `panel` StyleBox in `_draw()`, draws it across the full control rect, and queues redraw after resize or Theme changes.

- [ ] **Step 3: Add and apply the Theme variation**

Define `DessertWorkbenchPanel/base_type = VBoxContainer` and map its `panel` style to `StyleBox_panel_main`. Attach the helper and variation to `Root/Body/MainArea/WorkbenchPanel` without adding wrapper nodes or changing child paths.

- [ ] **Step 4: Verify GREEN and layout stability**

Require `NEIGHBORHOOD_DESSERT_THEME_SELF_CHECK_PASS`, `LAYOUT_REFINEMENT_SELF_CHECK_PASS`, `RIGHT_CONSOLE_EXPERIENCE_SELF_CHECK_PASS`, and `git diff --check`.
