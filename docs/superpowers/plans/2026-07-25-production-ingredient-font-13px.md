# Production Ingredient 13px Three-Column Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Increase production ingredient text to 13px and make the fixed 300px material area use three equal columns per line.

**Architecture:** Keep the existing unboxed `HFlowContainer`, but give every ingredient item the same calculated one-third width. Build each item after calculating its complete quantity text, then assign the remaining column width to the ellipsized name so the quantity never causes an early wrap.

**Tech Stack:** Godot 4.6.1, GDScript, repository `SceneTree` self-checks, Godot MCP runtime inspection.

## Global Constraints

- Target only `D:\Project\ProjectRest\project-rest-new`.
- Keep each recipe row at `68px` and the material area at `300px`.
- Use three equal material columns separated by two `4px` gaps; each item is approximately `97.3px` wide.
- Items 1–3 stay on the first line; items 4–6 use the second line; six items must be `3 + 3`.
- Set ingredient names and quantities to `13px`; keep icons at `18px`.
- Keep ingredient items unboxed.
- Long names may show an ellipsis, but quantities must remain complete.
- Keep missing and sufficient quantities in the same neutral color.
- Do not change sorting, production, progress, or inventory behavior.
- Do not stage unrelated asset changes.
- Every Godot headless command must use a writable `$env:TEMP` log path.

---

### Task 1: Enforce 13px fixed three-column ingredient items

**Files:**
- Modify: `tests/production_queue_scene_self_check.gd:171-251`
- Modify: `scripts/ui/pages/production_queue_recipe_row.gd:8-139`

**Interfaces:**
- Consumes: `_make_material_item(material: Dictionary) -> HBoxContainer` and `MaterialItems: HFlowContainer`.
- Produces: fixed-width unboxed items with `MaterialNameLabel` and `MaterialQuantityLabel` at 13px.

- [ ] **Step 1: Write the failing font and column contract**

Change the existing font assertions:

```gdscript
_expect_equal(
	"material name font size",
	sufficient_name.get_theme_font_size("font_size"),
	13
)
_expect_equal(
	"material quantity font size",
	sufficient_quantity.get_theme_font_size("font_size"),
	13
)
```

Build a long-name six-item fixture:

```gdscript
var dense_materials: Array = []
for material_index in range(6):
	dense_materials.append({
		"name": "超长材料名称%d" % material_index,
		"owned_count": 0,
		"required_count": 10,
		"display_text": "超长材料名称%d 0/10" % material_index,
		"missing": true
	})
```

After configuring the first three items, wait two frames and assert one line:

```gdscript
row.call("configure", {
	"entry_kind": "finished",
	"recipe_id": "three_material_recipe",
	"name": "三材料配方",
	"materials": dense_materials.slice(0, 3),
	"duration_seconds": 8,
	"price": 30,
	"action_kind": "restock",
	"action_enabled": true
})
await process_frame
await process_frame
_expect_equal("three materials stay on one line", material_strip.get_line_count(), 1)
```

Configure four items and assert `3 + 1`:

```gdscript
row.call("configure", {
	"entry_kind": "finished",
	"recipe_id": "four_material_recipe",
	"name": "四材料配方",
	"materials": dense_materials.slice(0, 4),
	"duration_seconds": 8,
	"price": 30,
	"action_kind": "restock",
	"action_enabled": true
})
await process_frame
await process_frame
_expect_equal("four materials use two lines", material_strip.get_line_count(), 2)
var first_of_four := material_strip.get_child(0) as Control
var fourth_of_four := material_strip.get_child(3) as Control
_expect_equal(
	"fourth material starts the second line",
	fourth_of_four.position.x,
	first_of_four.position.x
)
_expect(
	fourth_of_four.position.y > first_of_four.position.y,
	"fourth material must sit below the first"
)
```

Configure all six and assert fixed widths plus `3 + 3`:

```gdscript
row.call("configure", {
	"entry_kind": "finished",
	"recipe_id": "six_material_recipe",
	"name": "六材料配方",
	"materials": dense_materials,
	"duration_seconds": 8,
	"price": 30,
	"action_kind": "restock",
	"action_enabled": true
})
await process_frame
await process_frame
_expect_equal("six materials use two lines", material_strip.get_line_count(), 2)
var first_of_six := material_strip.get_child(0) as Control
var second_of_six := material_strip.get_child(1) as Control
var fourth_of_six := material_strip.get_child(3) as Control
var fifth_of_six := material_strip.get_child(4) as Control
_expect_equal(
	"six materials use three columns",
	fourth_of_six.position.x,
	first_of_six.position.x
)
_expect_equal(
	"second row keeps the second column",
	fifth_of_six.position.x,
	second_of_six.position.x
)
for material_item_value: Variant in material_strip.get_children():
	var material_item := material_item_value as HBoxContainer
	var quantity_label := material_item.get_node("MaterialQuantityLabel") as Label
	_expect(is_equal_approx(material_item.size.x, 292.0 / 3.0), "material item must use one-third width")
	_expect_equal("dense quantity remains complete", quantity_label.text, "0/10")
	_expect_equal("dense quantity does not clip", quantity_label.clip_text, false)
```

- [ ] **Step 2: Run the scene test and verify it fails**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-production-ingredient-13px-columns-red.log" `
  -s res://tests/production_queue_scene_self_check.gd
```

Expected: font assertions report `11` instead of `13`; long items use content widths rather than three equal columns.

- [ ] **Step 3: Implement fixed column width and quantity-first sizing**

Replace the current font and width constants with:

```gdscript
const MATERIAL_ICON_SIZE := Vector2(18, 18)
const MATERIAL_FONT_SIZE := 13
const MATERIAL_ITEM_HEIGHT := 24.0
const MATERIAL_AREA_WIDTH := 300.0
const MATERIAL_FLOW_HORIZONTAL_GAP := 4.0
const MATERIAL_COLUMNS_PER_LINE := 3.0
const MATERIAL_INNER_GAP := 2.0
const MATERIAL_ITEM_WIDTH := (
	(MATERIAL_AREA_WIDTH - MATERIAL_FLOW_HORIZONTAL_GAP * (MATERIAL_COLUMNS_PER_LINE - 1.0))
	/ MATERIAL_COLUMNS_PER_LINE
)
const MATERIAL_NAME_MIN_WIDTH := 11.0
const MATERIAL_TEXT_COLOR := Color(0.31, 0.25, 0.21, 1.0)
```

Replace the name measurement helper:

```gdscript
func _material_text_width(text: String) -> float:
	var font := get_theme_font("font", "Label")
	return ceilf(font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		MATERIAL_FONT_SIZE
	).x)


func _material_name_width(material_name: String, quantity_text: String) -> float:
	var reserved_width := (
		MATERIAL_ICON_SIZE.x
		+ MATERIAL_INNER_GAP * 2.0
		+ _material_text_width(quantity_text)
	)
	var available_width := maxf(
		MATERIAL_NAME_MIN_WIDTH,
		MATERIAL_ITEM_WIDTH - reserved_width
	)
	return clampf(
		_material_text_width(material_name),
		MATERIAL_NAME_MIN_WIDTH,
		available_width
	)
```

In `_make_material_item`, set the fixed column width and calculate quantity text first:

```gdscript
var item := HBoxContainer.new()
item.custom_minimum_size = Vector2(MATERIAL_ITEM_WIDTH, MATERIAL_ITEM_HEIGHT)
item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
item.add_theme_constant_override("separation", int(MATERIAL_INNER_GAP))

var owned_count := maxi(0, int(material.get("owned_count", 0)))
var required_count := maxi(0, int(material.get("required_count", 0)))
var quantity_text := (
	"%d/%d" % [owned_count, required_count]
	if bool(material.get("missing", false))
	else "×%d" % required_count
)

var material_name := String(material.get("name", ""))
name_label.custom_minimum_size.x = _material_name_width(material_name, quantity_text)
quantity_label.text = quantity_text
```

Keep `name_label.clip_text = true`, `name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS`, and the quantity label’s default `clip_text = false`.

- [ ] **Step 4: Run focused regression tests**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-13px-columns-scene.log" -s res://tests/production_queue_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-13px-columns-ui.log" -s res://tests/recipe_production_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-13px-columns-interaction.log" -s res://tests/production_queue_interaction_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-13px-columns-layout.log" -s res://tests/output_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-new-production-ingredient-13px-columns-mvp.log" -s res://tests/mvp_self_check.gd
```

Expected: each command exits `0` and prints its corresponding `*_PASS` marker.

- [ ] **Step 5: Verify the real production queue**

Restart the connected `project-rest-new` game and inspect:

```text
MaterialNameLabel font size = 13
MaterialQuantityLabel font size = 13
MaterialIcon size = 18×18
Every MaterialItem width ≈ 97.3
Three materials: MaterialItems height = 24
Four to six materials: MaterialItems height = 52
Six materials: child 3 x = child 0 x and child 4 x = child 1 x
No MaterialItem is a PanelContainer
```

Capture a full-resolution screenshot and confirm the 13px text is more legible, the fourth item starts the second line, and quantities remain complete.

- [ ] **Step 6: Commit only the font-and-column change**

```powershell
git add -- tests/production_queue_scene_self_check.gd scripts/ui/pages/production_queue_recipe_row.gd
git commit -m "style: enlarge production ingredient grid"
```

Confirm both target files are clean after the commit and leave all unrelated asset changes untouched.
