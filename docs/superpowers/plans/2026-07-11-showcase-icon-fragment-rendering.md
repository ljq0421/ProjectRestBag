# Showcase Icon Fragment Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render each displayed recipe as one continuous image distributed across its occupied showcase cells, including variants, irregular shapes, rotations, drag previews, anchor-only badges, and cached countdown-safe updates.

**Architecture:** A Python/Pillow generator creates compact shape canvases and a manifest under `resources/recipe_icons_showcase`. A focused Godot service lazily loads those canvases and caches `AtlasTexture` fragments; the reusable showcase-slot scene owns stable visual nodes, while `main_view.gd` maps current display state onto fragments without changing placement, sale, or persistence rules.

**Tech Stack:** Godot 4.6.1, GDScript, Python 3, Pillow, JSON, PNG.

## Global Constraints

- Implement on the current `main` checkout and preserve unrelated dirty files.
- Treat `doc/recipe_display_config.json` and `ShowcaseRuleService.variant_definition()` as shape sources; do not edit either merely to satisfy tests.
- Keep the showcase at `10×10`, its initially unlocked center at `6×6`, and each slot at `44×44`.
- Keep each icon fragment at `40×40` with `4px` between cells.
- Write generated assets only to `resources/recipe_icons_showcase`; never modify `resources/recipe_icons`.
- Perform image resize, alpha masking, and rotation offline with Pillow LANCZOS; generate unique rotations for every multi-cell shape because the current runtime permits all multi-cell products to rotate, regardless of the config's `rotatable` metadata; do no runtime pixel processing.
- Countdown refreshes must not load textures, create `AtlasTexture` instances, recompute shapes, or refresh all 100 slots.
- Drag-preview refreshes must remain limited to the union of previous and current occupied cells.
- Every Godot headless command must include `--log-file` pointing to a writable `%TEMP%` path.

---

### Task 1: Generate shape canvases and a validated manifest

**Files:**
- Create: `tools/generate_showcase_recipe_icons.py`
- Create: `tests/test_generate_showcase_recipe_icons.py`

**Interfaces:**
- Consumes: source PNG directory, `recipe_display_config.json`, and output directory.
- Produces: `generate_showcase_icons(source_dir: Path, output_dir: Path, config_path: Path) -> dict`.
- Manifest entry key: `<recipe_id>|<variant_id>|r<degrees>`.
- Manifest entry fields: `texture_path`, `variant_id`, `rotation`, `rows`, `cols`, `cells`, and `regions`.
- Region map key: `<row>:<col>`; value: `[x, y, 40, 40]`.

- [ ] **Step 1: Write failing generator tests**

Create tests that use temporary 512×512 RGBA images and a minimal config. Include these exact behaviors:

```python
def test_generates_horizontal_canvas_manifest_and_preserves_source(self):
    config = {
        "recipes": {
            "horizontal": {
                "cell_count": 2,
                "default_shape": "1x2",
                "rotatable": True,
            }
        }
    }
    source = self.write_source("horizontal", (512, 512), (220, 80, 40, 255))
    original = source.read_bytes()
    manifest = self.module.generate_showcase_icons(
        self.source_dir, self.output_dir, self.write_config(config)
    )
    r0 = manifest["entries"]["horizontal|standard|r0"]
    r90 = manifest["entries"]["horizontal|standard|r90"]
    self.assertEqual((r0["cols"], r0["rows"]), (2, 1))
    self.assertEqual((r90["cols"], r90["rows"]), (1, 2))
    self.assertEqual(r0["regions"]["1:1"], [0, 0, 40, 40])
    self.assertEqual(r0["regions"]["1:2"], [44, 0, 40, 40])
    with Image.open(self.output_dir / Path(r0["texture_path"]).name) as image:
        self.assertEqual(image.size, (84, 40))
    self.assertEqual(source.read_bytes(), original)

def test_masks_missing_l_shape_cell(self):
    config = {
        "recipes": {
            "corner": {
                "cell_count": 3,
                "default_shape": "2x2",
                "shape_cells": [[1, 1], [1, 2], [2, 1]],
                "rotatable": True,
            }
        }
    }
    manifest = self.generate(config, "corner")
    entry = manifest["entries"]["corner|standard|r0"]
    self.assertNotIn("2:2", entry["regions"])
    with Image.open(self.output_dir / Path(entry["texture_path"]).name) as image:
        self.assertEqual(image.getpixel((64, 64))[3], 0)

def test_failure_keeps_existing_output_unchanged(self):
    sentinel = self.output_dir / "sentinel.png"
    self.output_dir.mkdir()
    sentinel.write_bytes(b"existing")
    with self.assertRaises(FileNotFoundError):
        self.module.generate_showcase_icons(
            self.source_dir, self.output_dir, self.write_config({"recipes": {"missing": {}}})
        )
    self.assertEqual(sentinel.read_bytes(), b"existing")
```

Also assert the `small`, `sample`, `gift_box`, and `large` target counts match the Godot rule: `1`, `1`, `base + 1`, and `base + 1`.

- [ ] **Step 2: Run the tests and verify RED**

Run:

```powershell
& "C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" `
  -m unittest tests.test_generate_showcase_recipe_icons
```

Expected: FAIL because `tools/generate_showcase_recipe_icons.py` does not exist.

- [ ] **Step 3: Implement the minimal generator**

Use these constants and public entry point:

```python
CELL_SIZE = 40
CELL_GAP = 4
VARIANT_IDS = ("standard", "small", "gift_box", "large", "sample")

def generate_showcase_icons(
    source_dir: Path,
    output_dir: Path,
    config_path: Path,
) -> dict:
    # Validate every configured recipe and source before writing staging output.
    # Build each variant shape, deduplicate normalized rotations, generate PNGs,
    # validate dimensions/regions, write the manifest, then publish staging files.
```

Implement shape helpers with the same row/column convention as Godot:

```python
def normalize_cells(cells: list[tuple[int, int]]) -> list[tuple[int, int]]:
    min_row = min(row for row, _ in cells)
    min_col = min(col for _, col in cells)
    return sorted((row - min_row + 1, col - min_col + 1) for row, col in cells)

def rotate_clockwise(cells: list[tuple[int, int]]) -> list[tuple[int, int]]:
    rows = max(row for row, _ in cells)
    return normalize_cells([(col, rows - row + 1) for row, col in cells])

def canvas_extent(cells: list[tuple[int, int]]) -> tuple[int, int]:
    rows = max(row for row, _ in cells)
    cols = max(col for _, col in cells)
    return cols * CELL_SIZE + (cols - 1) * CELL_GAP, rows * CELL_SIZE + (rows - 1) * CELL_GAP
```

Build `regions` from occupied cells only. Alpha-mask every unoccupied cell rectangle in the shape bounding box. Save filenames as `<recipe_id>__<variant_id>__r<degrees>.png` and store Godot paths as `res://resources/recipe_icons_showcase/<filename>`.

Publish only after all staging outputs pass validation. Remove stale generated PNGs only inside `resources/recipe_icons_showcase`; never enumerate or remove files outside the resolved output directory.

- [ ] **Step 4: Run the generator tests and verify GREEN**

Run the Step 2 command again.

Expected: all generator unit tests pass.

- [ ] **Step 5: Commit the generator and unit tests**

```powershell
git add -- tools/generate_showcase_recipe_icons.py tests/test_generate_showcase_recipe_icons.py
git commit -m "feat: 添加橱窗配方图标生成器"
```

---

### Task 2: Generate and verify the complete showcase asset set

**Files:**
- Create: `resources/recipe_icons_showcase/*.png`
- Create: `resources/recipe_icons_showcase/showcase_icon_manifest.json`

**Interfaces:**
- Consumes: `generate_showcase_icons(...)` from Task 1.
- Produces: the complete runtime resource set referenced by the manifest.

- [ ] **Step 1: Add a full-repository asset test**

Add this test to `tests/test_generate_showcase_recipe_icons.py`:

```python
def test_repository_sources_cover_every_configured_recipe(self):
    config_path = ROOT / "doc" / "recipe_display_config.json"
    source_dir = ROOT / "resources" / "recipe_icons"
    config = json.loads(config_path.read_text(encoding="utf-8-sig"))
    recipe_ids = sorted(config["recipes"])
    source_ids = sorted(path.stem for path in source_dir.glob("*.png"))
    self.assertEqual(len(recipe_ids), 149)
    self.assertEqual(source_ids, recipe_ids)
```

Do not assert a hard-coded shape for `egg_milk_custard`; derive every expected shape from the current config.

- [ ] **Step 2: Run the full-repository asset test and verify its result**

Run the Task 1 unit-test command.

Expected: PASS if the current 149 source icons match the config. If it fails, report the exact missing or extra IDs and stop; do not edit the user-owned config.

- [ ] **Step 3: Generate the formal resources**

Run:

```powershell
& "C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" `
  tools\generate_showcase_recipe_icons.py `
  --source-dir resources\recipe_icons `
  --output-dir resources\recipe_icons_showcase `
  --config-path doc\recipe_display_config.json
```

Expected: success output includes 149 recipes and the count of generated unique variant-direction canvases.

- [ ] **Step 4: Validate every manifest entry and source preservation**

Add a test that opens the checked-in manifest, verifies every `texture_path` exists, confirms each image size equals the formula from `rows`/`cols`, confirms every region is `40×40`, and verifies no region exists for an unoccupied cell.

Run the full Python test module again.

Expected: all tests pass.

- [ ] **Step 5: Commit the generated runtime assets**

```powershell
git add -- resources/recipe_icons_showcase tests/test_generate_showcase_recipe_icons.py
git commit -m "assets: 生成橱窗跨格配方图标"
```

---

### Task 3: Add the lazy-loaded fragment cache service

**Files:**
- Create: `scripts/ui/storefront/showcase_icon_service.gd`
- Create: `tests/showcase_icon_service_self_check.gd`

**Interfaces:**
- Produces class: `ShowcaseIconService extends RefCounted`.
- `load_manifest(path: String = "res://resources/recipe_icons_showcase/showcase_icon_manifest.json") -> bool`.
- `layout_for_shape(recipe_id: String, variant_id: String, local_cells: Array[Vector2i]) -> Dictionary`.
- `fragment(recipe_id: String, variant_id: String, rotation: int, local_cell: Vector2i) -> AtlasTexture`.
- `texture_cache_size() -> int` and `fragment_cache_size() -> int` for focused performance verification.
- `entry_keys() -> Array` and `entry(key: String) -> Dictionary` for read-only focused-test inspection.
- `clear() -> void` for explicit test isolation.

- [ ] **Step 1: Write the failing Godot service self-check**

The test must:

```gdscript
var service := ShowcaseIconService.new()
_expect(service.load_manifest(), "showcase icon manifest should load")

var horizontal := [Vector2i(1, 1), Vector2i(1, 2)]
var layout := service.layout_for_shape("apple_pie", "standard", horizontal)
_expect(not layout.is_empty(), "horizontal layout should resolve")

var first := service.fragment("apple_pie", "standard", int(layout.rotation), Vector2i(1, 1))
var second := service.fragment("apple_pie", "standard", int(layout.rotation), Vector2i(1, 2))
_expect(first != null and second != null, "occupied cells should resolve fragments")
_expect(first.region.size == Vector2(40, 40), "fragment should be 40x40")

var cache_size := service.fragment_cache_size()
var repeated := service.fragment("apple_pie", "standard", int(layout.rotation), Vector2i(1, 1))
_expect(repeated == first, "fragment lookup should reuse the cached AtlasTexture")
_expect(service.fragment_cache_size() == cache_size, "repeated lookup should not grow cache")
```

Select the test recipe deterministically from the loaded manifest:

```gdscript
var horizontal_recipe_id := ""
for entry_key_value in service.entry_keys():
    var entry_key := String(entry_key_value)
    var entry := service.entry(entry_key)
    if String(entry.get("variant_id", "")) == "standard" and int(entry.get("rows", 0)) == 1 and int(entry.get("cols", 0)) == 2:
        horizontal_recipe_id = entry_key.get_slice("|", 0)
        break
_expect(not horizontal_recipe_id.is_empty(), "manifest should contain a standard horizontal recipe")
```

Add `entry_keys() -> Array` and `entry(key: String) -> Dictionary` as read-only service inspection methods used by this focused self-check.

- [ ] **Step 2: Run the service check and verify RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . `
  --log-file "$env:TEMP\showcase-icon-service-red.log" `
  -s res://tests/showcase_icon_service_self_check.gd
```

Expected: FAIL because `ShowcaseIconService` does not exist.

- [ ] **Step 3: Implement the cache service**

Use manifest dictionaries plus two caches:

```gdscript
class_name ShowcaseIconService
extends RefCounted

const DEFAULT_MANIFEST_PATH := "res://resources/recipe_icons_showcase/showcase_icon_manifest.json"

var _entries: Dictionary = {}
var _texture_cache: Dictionary = {}
var _fragment_cache: Dictionary = {}
var _warned_keys: Dictionary = {}
```

`layout_for_shape` must normalize `local_cells`, compare their sorted `row:col` keys with manifest entries for the recipe and variant, and return the matching rotation. `fragment` must load the canvas once, create an `AtlasTexture` with the manifest region once, and return `null` after a one-time warning when any entry is missing.

- [ ] **Step 4: Run the service check and verify GREEN**

Run the Step 2 command again.

Expected: `SHOWCASE_ICON_SERVICE_SELF_CHECK_PASS` and exit code 0.

- [ ] **Step 5: Commit the service and self-check**

```powershell
git add -- scripts/ui/storefront/showcase_icon_service.gd tests/showcase_icon_service_self_check.gd
git commit -m "feat: 缓存橱窗图标切片"
```

---

### Task 4: Make the showcase slot own its stable visual nodes

**Files:**
- Create: `scripts/ui/storefront/showcase_slot.gd`
- Modify: `scenes/ui/storefront/showcase_slot.tscn`
- Create: `tests/showcase_slot_visual_self_check.gd`

**Interfaces:**
- `showcase_slot.gd` extends `res://scripts/output_cell.gd` and preserves its drag/drop API.
- `set_icon_fragment(texture: Texture2D, preview: bool = false) -> void`.
- `clear_product_visual() -> void`.
- `set_status_badge(text: String) -> void`.
- `set_preview_state(active: bool, valid: bool) -> void`.
- `set_outline_edges(top: bool, right: bool, bottom: bool, left: bool, color: Color, hovered: bool = false) -> void`.

- [ ] **Step 1: Write the failing scene self-check**

Load and instantiate the scene, then assert:

```gdscript
var slot := load("res://scenes/ui/storefront/showcase_slot.tscn").instantiate()
var icon := slot.get_node("RecipeIcon") as TextureRect
var tint := slot.get_node("PreviewTint") as Control
var badge := slot.get_node("StatusBadge") as Control
_expect(slot.custom_minimum_size == Vector2(44, 44), "slot should remain 44x44")
_expect(icon.custom_minimum_size == Vector2(40, 40), "fragment should remain 40x40")
_expect(icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "icon should not intercept drag")
_expect(tint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "preview tint should not intercept drag")
_expect(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "badge should not intercept drag")

slot.call("set_status_badge", "12s")
_expect(badge.visible, "non-empty badge should be visible")
slot.call("clear_product_visual")
_expect(icon.texture == null and not badge.visible, "clear should reset stable visuals")
```

- [ ] **Step 2: Run the scene check and verify RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . `
  --log-file "$env:TEMP\showcase-slot-visual-red.log" `
  -s res://tests/showcase_slot_visual_self_check.gd
```

Expected: FAIL because `PreviewTint`, `StatusBadge`, and the visual methods do not exist.

- [ ] **Step 3: Implement the scene and slot script**

Keep `RecipeIcon` inset to a `40×40` centered area. Add `PreviewTint` filling the same area and a compact bottom-right `StatusBadge`. Set all three child controls to mouse-filter ignore.

Implement `set_icon_fragment` without creating nodes:

```gdscript
func set_icon_fragment(texture: Texture2D, preview: bool = false) -> void:
    recipe_icon.texture = texture
    recipe_icon.modulate.a = 0.55 if preview else 1.0

func set_status_badge(text: String) -> void:
    status_badge.text = text
    status_badge.visible = not text.is_empty()

func clear_product_visual() -> void:
    recipe_icon.texture = null
    recipe_icon.modulate = Color.WHITE
    status_badge.text = ""
    status_badge.visible = false
    preview_tint.visible = false
```

Build outline `StyleBoxFlat` instances only when edge state or hover state changes; cache the last outline key on the slot to avoid needless recreation.

- [ ] **Step 4: Run the scene check and verify GREEN**

Run the Step 2 command again.

Expected: `SHOWCASE_SLOT_VISUAL_SELF_CHECK_PASS` and exit code 0.

- [ ] **Step 5: Commit the reusable scene changes**

```powershell
git add -- scenes/ui/storefront/showcase_slot.tscn scripts/ui/storefront/showcase_slot.gd tests/showcase_slot_visual_self_check.gd
git commit -m "feat: 扩展橱窗格视觉节点"
```

---

### Task 5: Integrate fragments, group outlines, badges, and previews

**Files:**
- Modify: `scripts/main_view.gd:194-197,3152-3323,3387-3425,3727-3739,3948-4228`
- Create: `tests/showcase_icon_distribution_self_check.gd`
- Modify: `tests/showcase_drag_preview_perf_self_check.gd`

**Interfaces:**
- Consumes: `ShowcaseIconService` and showcase-slot visual methods from Tasks 3-4.
- Produces: `_refresh_all_showcase_product_visuals(now_unix: int) -> void`.
- Produces: `_apply_showcase_group_visual(recipe_id: String, cells: Array, variant_id: String, preview: bool, now_unix: int) -> void`.
- Produces: `_refresh_showcase_anchor_badges(now_unix: int) -> void`.
- Produces: `_showcase_status_badge_text(slot: Dictionary, now_unix: int) -> String`.
- Produces: `_showcase_outline_edges(local_cell: Vector2i, occupied: Dictionary) -> Dictionary`.

- [ ] **Step 1: Write the failing distribution self-check**

The focused test must scan the current config and select the first sorted recipe ID in each of these categories: one cell, `1×2`, `2×1`, `2×2`, and a recipe with non-empty `shape_cells`. Fail with a category-specific message if any category cannot be found; do not substitute a hard-coded recipe ID or edit the config. Create isolated state, unlock each selected recipe, and place it using its configured cells. For every placed product assert:

```gdscript
var occupied_buttons := _buttons_for_recipe(root, recipe_id)
_expect(occupied_buttons.size() == expected_cells.size(), "every occupied cell should have a slot")
for button in occupied_buttons:
    var icon := button.get_node("RecipeIcon") as TextureRect
    _expect(icon.texture is AtlasTexture, "occupied cell should use an AtlasTexture fragment")
    _expect((icon.texture as AtlasTexture).region.size == Vector2(40, 40), "fragment should be 40x40")
    _expect(button.text.is_empty(), "occupied cells should not repeat recipe text")

var anchor := occupied_buttons[0]
_expect(anchor.get_node("StatusBadge").visible, "anchor should display the status badge")
for covered in occupied_buttons.slice(1):
    _expect(not covered.get_node("StatusBadge").visible, "covered cells should hide the status badge")
```

For an irregular shape, assert the missing bounding-box cell has no icon. Rotate a rotatable product and assert the fragment atlas and local regions match the rotated layout. Assert every occupied cell has the same full tooltip.

- [ ] **Step 2: Extend the performance test and verify RED**

Add assertions to `showcase_drag_preview_perf_self_check.gd`:

```gdscript
var icon_service = root.get("showcase_icon_service")
var texture_count_before := icon_service.texture_cache_size()
var fragment_count_before := icon_service.fragment_cache_size()
root.call("_refresh_showcase_countdown_texts", int(Time.get_unix_time_from_system()) + 1)
_expect(icon_service.texture_cache_size() == texture_count_before, "countdown should not load textures")
_expect(icon_service.fragment_cache_size() == fragment_count_before, "countdown should not create fragments")
```

Run both focused tests. Expected: FAIL because the grid still repeats full textures/text and countdown still calls `_apply_showcase_slot_button_state` for all slots.

- [ ] **Step 3: Add the icon service and split status from visual refresh**

In `main_view.gd`, add one long-lived service:

```gdscript
var showcase_icon_service := ShowcaseIconService.new()
```

Load its manifest during view initialization. Change `_refresh_showcase_countdown_texts` to:

```gdscript
func _refresh_showcase_countdown_texts(now_unix: int) -> void:
    _refresh_showcase_anchor_badges(now_unix)
```

`_refresh_showcase_anchor_badges` must iterate display-item anchors, resolve only their existing buttons, and call `set_status_badge`; it must not call `_apply_showcase_slot_button_state`.

- [ ] **Step 4: Apply grouped fragments and external outlines**

After the 100 stable buttons are created and their empty/locked/drop state is applied, call `_refresh_all_showcase_product_visuals(now_unix)`.

For each display item:

1. Normalize its actual cells with `_local_showcase_shape_cells`.
2. Ask the icon service for a matching layout.
3. Map global cells to local cells.
4. Assign the cached fragment to each occupied button.
5. Clear button text and set the shared tooltip.
6. Set the badge only on `_showcase_anchor_slot_index_for_cells(cells)`.
7. Build an occupied-cell key dictionary and enable an outline edge only when that side has no same-product neighbor.

Use the same helper for drag preview with `preview = true`. Keep `_refresh_showcase_slot_indices` scoped to the existing old/new union, but after resetting those slots reapply visuals for products touching that union.

Connect each slot's `mouse_entered` and `mouse_exited` once in `_make_storefront_slot_button`; the handlers resolve the current recipe by slot index and reapply only that product's outline with `hovered = true/false`.

- [ ] **Step 5: Implement badge priority and no-image fallback**

Use this exact priority:

```gdscript
func _showcase_status_badge_text(slot: Dictionary, now_unix: int) -> String:
    var ready_at := int(slot.get("sale_ready_at_unix", 0))
    if ready_at > now_unix:
        return "%ds" % (ready_at - now_unix)
    if ready_at > 0:
        return "可售"
    var quantity := maxi(1, int(slot.get("quantity", 1)))
    return "×%d" % quantity if quantity > 1 else ""
```

If layout or texture lookup returns empty/null, leave the icon empty but still apply tooltip, badge, drag behavior, and external outline.

- [ ] **Step 6: Run focused tests and verify GREEN**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-icon-distribution.log" -s res://tests/showcase_icon_distribution_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-icon-perf.log" -s res://tests/showcase_drag_preview_perf_self_check.gd
```

Expected: distribution and performance self-checks pass. Cache counts remain unchanged across countdown refresh; preview scope contains only changed slots.

- [ ] **Step 7: Commit the runtime integration**

```powershell
git add -- scripts/main_view.gd tests/showcase_icon_distribution_self_check.gd tests/showcase_drag_preview_perf_self_check.gd
git commit -m "feat: 显示橱窗跨格配方图标"
```

---

### Task 6: Import assets and run the regression gate

**Files:**
- Create through Godot import: `resources/recipe_icons_showcase/*.png.import`
- Create through Godot import: any new `.gd.uid` files for new scripts/tests.

**Interfaces:**
- Consumes: all completed tasks.
- Produces: a Godot-imported, parseable project with focused and existing showcase regressions passing.

- [ ] **Step 1: Run Godot editor import headlessly**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --editor --quit --path . `
  --log-file "$env:TEMP\showcase-icon-import.log"
```

Expected: exit code 0 and all showcase PNGs receive import metadata. Ignore only the known Windows root-certificate/editor-settings warnings if the exit code remains 0; report any resource-import or script-parse errors.

- [ ] **Step 2: Run all new focused checks**

Run the Python test and these Godot scripts with separate writable log files:

```text
tests/showcase_icon_service_self_check.gd
tests/showcase_slot_visual_self_check.gd
tests/showcase_icon_distribution_self_check.gd
tests/showcase_drag_preview_perf_self_check.gd
```

Expected: every command exits 0 with its PASS marker.

- [ ] **Step 3: Run existing showcase and layout regressions**

Run:

```text
tests/showcase_bonus_reason_self_check.gd
tests/showcase_sale_feedback_self_check.gd
tests/output_layout_self_check.gd
```

Expected: every focused regression exits 0. Do not change unrelated dirty config to force a broad suite result.

- [ ] **Step 4: Run the broad MVP self-check and classify failures**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . `
  --log-file "$env:TEMP\showcase-icon-mvp.log" `
  -s res://tests/mvp_self_check.gd
```

Expected: PASS. If it fails, compare each failure against the focused checks and current unrelated dirty files; fix only failures caused by this feature and report pre-existing failures separately.

- [ ] **Step 5: Inspect the final diff and commit generated import metadata**

```powershell
git diff --check
git status --short
git add -- resources/recipe_icons_showcase `
  scripts/ui/storefront/showcase_icon_service.gd.uid `
  scripts/ui/storefront/showcase_slot.gd.uid `
  tests/showcase_icon_service_self_check.gd.uid `
  tests/showcase_slot_visual_self_check.gd.uid `
  tests/showcase_icon_distribution_self_check.gd.uid
git commit -m "chore: 导入橱窗配方图标资源"
```

Before committing, use `git diff --cached --name-only` to verify no user-owned `.gitignore`, `doc/recipe_display_config.json`, audit document, or unrelated plan/spec is staged.

## Final Acceptance Checklist

- [ ] A placed recipe appears as one continuous image across all occupied cells.
- [ ] Irregular missing cells remain empty and transparent.
- [ ] Rotating a product rotates both footprint and artwork distribution.
- [ ] Standard, small, gift-box, large, and sample variants resolve matching canvases.
- [ ] Occupied cells do not repeat recipe names.
- [ ] Only the anchor displays `12s`, `可售`, or `×N` according to priority.
- [ ] All occupied cells preserve the complete tooltip and drag behavior.
- [ ] Internal borders are hidden; only the product perimeter is drawn and group hover highlights together.
- [ ] Valid drag previews use half-transparent fragments and invalid previews leave no fragment residue.
- [ ] Missing resources fall back to no image without breaking placement, rotation, sale, or save data.
- [ ] Countdown refresh does not change texture or fragment cache size.
- [ ] Drag preview refresh does not rebuild all 100 cells.
- [ ] Original 512×512 icons remain byte-for-byte unchanged.
