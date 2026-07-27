# Production Ingredient Unboxed Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace boxed, six-equal-width production ingredients with readable unboxed items that flow across the fixed 300px material area and wrap to a second line when needed.

**Architecture:** Keep the existing `ProductionQueueRecipeRow` scene and its fixed `68px` row contract. Make the scene-owned material region a centered `HFlowContainer`; keep data binding in the existing row script, but have it create ordinary `HBoxContainer` items with an icon, a width-capped name label, and a quantity label.

**Tech Stack:** Godot 4.6.1, GDScript, `.tscn` scenes, repository headless `SceneTree` self-checks, Godot MCP runtime inspection.

## Global Constraints

- Target only `D:\Project\ProjectRest\project-rest-new`.
- Keep each production row at `68px` high.
- Keep the material region at `300px` wide and preserve all other fixed row columns.
- Use `18px` ingredient icons and `11px` ingredient text.
- Do not render per-ingredient backgrounds, borders, corner radii, or separators.
- Keep sufficient and missing quantities in the same neutral text color.
- Allow at most two material lines; all material bounds must remain inside the `300×68px` region.
- Preserve sorting, production, progress, inventory, and tooltip behavior.
- Do not stage or edit unrelated `resources/ui/icons_v1` files.
- Every Godot headless command must pass a writable `--log-file` under `$env:TEMP`.

---

### Task 1: Convert the scene-owned material strip to a centered flow layout

**Files:**
- Modify: `tests/production_queue_scene_self_check.gd:149-153`
- Modify: `tests/recipe_growth_summary_ui_self_check.gd:16-22`
- Modify: `scenes/ui/pages/production_queue_recipe_row.tscn:79-91`
- Modify: `scripts/ui/pages/production_queue_recipe_row.gd:14`

**Interfaces:**
- Consumes: the existing node path `Content/MaterialStrip/MaterialItems`.
- Produces: `MaterialStrip: CenterContainer`, `MaterialItems: HFlowContainer`, and `material_strip: HFlowContainer`.

- [ ] **Step 1: Write the failing flow-container contract**

Update the production queue scene check:

```gdscript
var material_strip := row.get_node(
	"Content/MaterialStrip/MaterialItems"
) as HFlowContainer
_expect(material_strip != null, "material items must use a horizontal flow container")
if material_strip != null:
	_expect_equal("material horizontal gap", material_strip.get_theme_constant("h_separation"), 4)
	_expect_equal("material vertical gap", material_strip.get_theme_constant("v_separation"), 4)
```

Update the recipe growth summary contract:

```gdscript
_expect(
	row.get_node_or_null("Content/MaterialStrip/MaterialItems") is HFlowContainer,
	"production row should wrap material readiness within the fixed strip"
)
```

- [ ] **Step 2: Run the focused tests and verify the new contract fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-production-ingredient-flow-red.log" `
  -s res://tests/production_queue_scene_self_check.gd

& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-production-growth-flow-red.log" `
  -s res://tests/recipe_growth_summary_ui_self_check.gd
```

Expected: both checks fail because `MaterialItems` is still an `HBoxContainer`.

- [ ] **Step 3: Make the scene own the centered flow structure**

Replace the current material nodes with:

```text
[node name="MaterialStrip" type="CenterContainer" parent="Content"]
clip_contents = true
custom_minimum_size = Vector2(300, 0)
layout_mode = 2

[node name="MaterialItems" type="HFlowContainer" parent="Content/MaterialStrip"]
custom_minimum_size = Vector2(300, 0)
layout_mode = 2
theme_override_constants/h_separation = 4
theme_override_constants/v_separation = 4
```

Update the row binding type without changing its node path:

```gdscript
@onready var material_strip: HFlowContainer = $Content/MaterialStrip/MaterialItems
```

- [ ] **Step 4: Run the focused tests and verify the flow contract passes**

Repeat both commands from Step 2 with log filenames ending in `-green.log`.

Expected:

```text
PRODUCTION_QUEUE_SCENE_SELF_CHECK_PASS
RECIPE_GROWTH_SUMMARY_UI_SELF_CHECK_PASS
```

- [ ] **Step 5: Commit the flow-container change**

```powershell
git add -- tests/production_queue_scene_self_check.gd tests/recipe_growth_summary_ui_self_check.gd scenes/ui/pages/production_queue_recipe_row.tscn scripts/ui/pages/production_queue_recipe_row.gd
git commit -m "refactor: flow production ingredients"
```

---

### Task 2: Render each ingredient as an unboxed single-line item

**Files:**
- Modify: `tests/production_queue_scene_self_check.gd:126-205`
- Modify: `scripts/ui/pages/production_queue_recipe_row.gd:8-135`

**Interfaces:**
- Consumes: material dictionaries with `name`, `icon`, `owned_count`, `required_count`, `missing`, and `tooltip`.
- Produces: `_make_material_item(material: Dictionary) -> HBoxContainer`, with named children `MaterialIcon`, `MaterialNameLabel`, and `MaterialQuantityLabel`.

- [ ] **Step 1: Replace the boxed-chip assertions with the unboxed item contract**

After configuring the two-material fixture, assert:

```gdscript
var sufficient_item := material_strip.get_child(0) as HBoxContainer
var missing_item := material_strip.get_child(1) as HBoxContainer
_expect(sufficient_item != null, "sufficient material must use an unboxed row")
_expect(missing_item != null, "missing material must use an unboxed row")
_expect(not material_strip.get_child(0) is PanelContainer, "material must not render a panel frame")
_expect(not material_strip.get_child(1) is PanelContainer, "missing material must not render a panel frame")

var sufficient_name := sufficient_item.get_node("MaterialNameLabel") as Label
var sufficient_quantity := sufficient_item.get_node("MaterialQuantityLabel") as Label
var missing_name := missing_item.get_node("MaterialNameLabel") as Label
_expect_equal("material name font size", sufficient_name.get_theme_font_size("font_size"), 11)
_expect_equal("material quantity font size", sufficient_quantity.get_theme_font_size("font_size"), 11)
_expect_equal(
	"missing material text stays neutral",
	missing_name.get_theme_color("font_color"),
	sufficient_name.get_theme_color("font_color")
)
```

For the six-material fixture, wait two frames and assert wrapping plus both axes:

```gdscript
await process_frame
await process_frame
_expect_equal("dense materials wrap to two lines", material_strip.get_line_count(), 2)
for material_item_value: Variant in material_strip.get_children():
	var material_item := material_item_value as Control
	_expect(
		material_item.position.x + material_item.size.x <= material_strip.size.x + 0.1,
		"material items must stay inside the 300px strip horizontally"
	)
	_expect(
		material_item.position.y + material_item.size.y <= material_strip.size.y + 0.1,
		"material items must stay inside the 68px strip vertically"
	)
```

- [ ] **Step 2: Run the scene check and verify it fails for the boxed items**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-production-ingredient-item-red.log" `
  -s res://tests/production_queue_scene_self_check.gd
```

Expected: failure because current children are `PanelContainer` instances with `9px` two-line labels.

- [ ] **Step 3: Implement the unboxed item builder**

Replace `MATERIAL_ICON_SIZE` and `_make_material_chip` with:

```gdscript
const MATERIAL_ICON_SIZE := Vector2(18, 18)
const MATERIAL_FONT_SIZE := 11
const MATERIAL_ITEM_HEIGHT := 24.0
const MATERIAL_NAME_MIN_WIDTH := 11.0
const MATERIAL_NAME_MAX_WIDTH := 66.0
const MATERIAL_TEXT_COLOR := Color(0.31, 0.25, 0.21, 1.0)


func _material_name_width(material_name: String) -> float:
	var font := get_theme_font("font", "Label")
	var measured_width := font.get_string_size(
		material_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		MATERIAL_FONT_SIZE
	).x
	return clampf(ceilf(measured_width), MATERIAL_NAME_MIN_WIDTH, MATERIAL_NAME_MAX_WIDTH)


func _make_material_item(material: Dictionary) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.custom_minimum_size = Vector2(0, MATERIAL_ITEM_HEIGHT)
	item.add_theme_constant_override("separation", 2)
	item.tooltip_text = String(material.get("tooltip", ""))

	var icon := TextureRect.new()
	icon.name = "MaterialIcon"
	icon.custom_minimum_size = MATERIAL_ICON_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = material.get("icon") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.add_child(icon)

	var material_name := String(material.get("name", ""))
	var name_label := Label.new()
	name_label.name = "MaterialNameLabel"
	name_label.custom_minimum_size.x = _material_name_width(material_name)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", MATERIAL_FONT_SIZE)
	name_label.add_theme_color_override("font_color", MATERIAL_TEXT_COLOR)
	name_label.text = material_name
	item.add_child(name_label)

	var owned_count := maxi(0, int(material.get("owned_count", 0)))
	var required_count := maxi(0, int(material.get("required_count", 0)))
	var quantity_label := Label.new()
	quantity_label.name = "MaterialQuantityLabel"
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_label.add_theme_font_size_override("font_size", MATERIAL_FONT_SIZE)
	quantity_label.add_theme_color_override("font_color", MATERIAL_TEXT_COLOR)
	quantity_label.text = (
		"%d/%d" % [owned_count, required_count]
		if bool(material.get("missing", false))
		else "×%d" % required_count
	)
	item.add_child(quantity_label)
	return item
```

Change `_bind_materials` to call the renamed builder:

```gdscript
material_strip.add_child(_make_material_item(material_value as Dictionary))
```

Do not add any stylebox override to the item.

- [ ] **Step 4: Run focused queue and component regressions**

Run each test separately with its own writable log:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-scene-green.log" -s res://tests/production_queue_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-ui-green.log" -s res://tests/recipe_production_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-interaction-green.log" -s res://tests/production_queue_interaction_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-component-green.log" -s res://tests/component_contract_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-skin-green.log" -s res://tests/red_operation_button_skin_self_check.gd
```

Expected: each script exits `0` and prints its corresponding `*_PASS` marker.

- [ ] **Step 5: Commit the unboxed item rendering**

```powershell
git add -- tests/production_queue_scene_self_check.gd scripts/ui/pages/production_queue_recipe_row.gd
git commit -m "style: remove production ingredient frames"
```

---

### Task 3: Verify runtime geometry and visual result

**Files:**
- Verify only: `scenes/ui/pages/production_queue_recipe_row.tscn`
- Verify only: `scripts/ui/pages/production_queue_recipe_row.gd`

**Interfaces:**
- Consumes: the completed flow scene and unboxed item builder.
- Produces: measured runtime evidence that the feature matches the approved `300×68px` contract.

- [ ] **Step 1: Import and parse the project**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-production-ingredient-import.log" `
  --editor `
  --quit
```

Expected: exit `0` with no parse error in the modified scene or script.

- [ ] **Step 2: Open the real production queue**

Use the connected `project-rest-new` Godot session, run the project, and navigate through the actual workbench production entry. Do not use a standalone synthetic row as the only visual proof.

- [ ] **Step 3: Inspect runtime properties**

Confirm:

```text
ProductionQueueRecipeRow height = 68
MaterialStrip width = 300
MaterialItems class = HFlowContainer
MaterialItems line count = 1 or 2 according to content
Every MaterialItem class = HBoxContainer
Every MaterialIcon size = 18×18
Every MaterialNameLabel font size = 11
Every MaterialQuantityLabel font size = 11
No MaterialItem is a PanelContainer
```

- [ ] **Step 4: Capture and inspect the production queue screenshot**

Check the real queue at normal project resolution:

- no independent ingredient box is visible;
- icon, name, and quantity read as one item on one line;
- six or long ingredients wrap cleanly without overlapping the time column;
- one-row ingredients are vertically centered;
- two-row ingredients remain inside the `68px` row;
- missing quantities are legible and not red.

- [ ] **Step 5: Run the final layout regressions**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-output-layout.log" -s res://tests/output_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-mvp.log" -s res://tests/mvp_self_check.gd
```

Expected:

```text
OUTPUT_LAYOUT_SELF_CHECK_PASS
MVP_SELF_CHECK_PASS
```

- [ ] **Step 6: Confirm repository scope**

Run:

```powershell
git status --short
git log -3 --oneline
```

Expected: only the previously existing untracked `resources/ui/icons_v1` assets remain; the two implementation commits contain only the files named in this plan.
