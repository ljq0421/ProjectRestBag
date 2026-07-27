# 图鉴图标卡片实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将图鉴改为每页 4×6 个 132×132 正方形卡片，已解锁配方只显示独立生成的 132×132 图标，未解锁配方保留现有文字。

**Architecture:** 使用仓库内 Python 工具从工作区 `output/imagegen` 生成图鉴专用缩略图，运行时仍由 `main_view.gd` 按配方 ID 绑定卡片状态。稳定卡片几何放在 `catalog_recipe_card.tscn`，分页和解锁状态继续由现有图鉴 overlay 调度。

**Tech Stack:** Godot 4.6.1、GDScript、Python 3、Pillow 12.2.0、PNG RGBA。

## Global Constraints

- 图鉴卡片与图标区域均固定为 132×132。
- 图鉴固定为 6 列、每页 24 格，即 4 行 × 6 列。
- 已解锁卡片只显示图标，完整信息保留在 tooltip 与右侧详情。
- 未解锁卡片不显示图标，保留现有锁定文字。
- 图鉴图标输出到 `res://resources/recipe_icons_catalog/`，不修改 `D:\Project\ProjectRest\output\imagegen` 原图。
- 使用 Pillow `Image.Resampling.LANCZOS`，保留完整画面与透明通道。
- 不提交 Git，除非用户后续明确要求。

---

### Task 1: 图鉴缩略图生成器

**Files:**
- Create: `tools/generate_catalog_recipe_icons.py`
- Create: `tests/test_generate_catalog_recipe_icons.py`
- Create: `resources/recipe_icons_catalog/*.png`

**Interfaces:**
- Consumes: `--source-dir`、`--output-dir`、`--catalog-path` 命令行参数；`scripts/catalog.gd` 中 `RECIPES` 键。
- Produces: `generate_catalog_icons(source_dir: Path, output_dir: Path, catalog_path: Path) -> list[Path]`；每个配方 ID 对应一个 132×132 RGBA PNG。

- [ ] **Step 1: 编写失败的 Python 测试**

```python
def test_generates_132_square_rgba_icon_without_touching_source(self):
    source = self.source_dir / "sample_recipe.png"
    Image.new("RGBA", (512, 512), (20, 40, 60, 128)).save(source)
    original = source.read_bytes()
    generated = module.generate_catalog_icons(
        self.source_dir,
        self.output_dir,
        self.catalog_path,
    )
    result = Image.open(generated[0])
    self.assertEqual(result.size, (132, 132))
    self.assertEqual(result.mode, "RGBA")
    self.assertEqual(source.read_bytes(), original)
```

另加一条测试，使用 `baked_rice_cake` 验证它从 `baked_rice_cake_icon_512_alpha_2x1.png` 明确映射，而不是按模糊名称选择。

- [ ] **Step 2: 运行测试并确认 RED**

Run:

```powershell
& "C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m unittest tests.test_generate_catalog_recipe_icons -v
```

Expected: FAIL，因为 `tools/generate_catalog_recipe_icons.py` 尚不存在。

- [ ] **Step 3: 实现最小生成器**

生成器必须包含以下确定映射：

```python
SOURCE_ALIASES = {
    "baked_rice_cake": "baked_rice_cake_icon_512_alpha_2x1.png",
    "egg_milk_custard": "egg_milk_custard_icon_512_alpha_2x2.png",
    "milk_rice_dew": "milk_rice_dew_icon_512_alpha_1x2.png",
    "rice_milk_drink": "rice_milk_drink_icon_512_alpha_1x2.png",
    "rich_rice_drink": "rich_rice_drink_icon_512_alpha_1x2.png",
}
```

对每个配方 ID 优先读取 `<recipe_id>.png`，不存在时只允许读取上述映射。加载后执行：

```python
with Image.open(source_path) as image:
    rgba = image.convert("RGBA")
    resized = rgba.resize((132, 132), Image.Resampling.LANCZOS)
    resized.save(output_path, format="PNG", optimize=True)
```

缺少任何配方源图时以非零状态退出，并打印缺失 ID。

- [ ] **Step 4: 运行测试并确认 GREEN**

Run: 与 Step 2 相同。

Expected: 两条测试 PASS。

- [ ] **Step 5: 生成完整图鉴资源并校验数量**

Run:

```powershell
& "C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/generate_catalog_recipe_icons.py --source-dir "D:\Project\ProjectRest\output\imagegen" --output-dir resources/recipe_icons_catalog --catalog-path scripts/catalog.gd
```

Expected: 输出 `generated 149 catalog icons`；每个 PNG 均为 132×132 RGBA。

### Task 2: 卡片场景与运行时状态

**Files:**
- Modify: `scenes/ui/overlays/catalog_recipe_card.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `res://resources/recipe_icons_catalog/<recipe_id>.png`。
- Produces: `_make_catalog_cell(recipe_id: String, recipe: Dictionary) -> Button`，其 `RecipeIcon` 对已解锁配方可见、对未解锁配方清空。

- [ ] **Step 1: 先修改运行时断言并确认 RED**

将现有断言更新为：

```gdscript
if catalog_grid.columns != 6:
    _fail("catalog grid should use six columns")
if catalog_grid.get_child_count() != 24:
    _fail("catalog global popup should always show twenty-four paged cells")
```

遍历有效卡片并断言：卡片最小尺寸为 `Vector2(132, 132)`；已解锁卡片 `text == ""`、`RecipeIcon.texture != null`、`RecipeIcon.mouse_filter == Control.MOUSE_FILTER_IGNORE`；未解锁卡片 `RecipeIcon.texture == null` 且文字包含 `未解锁线索`。

- [ ] **Step 2: 运行聚焦前置测试并确认 RED**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\catalog-icon-mvp-red.log" -s res://tests/mvp_self_check.gd
```

Expected: FAIL，报告当前仍为 5 列/20格或已解锁卡片仍显示文字。

- [ ] **Step 3: 修改场景几何**

`CatalogRecipeCard`：

```ini
custom_minimum_size = Vector2(132, 132)
clip_contents = true
```

`RecipeIcon`：

```ini
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 5
```

- [ ] **Step 4: 修改分页与卡片绑定**

在 `main_view.gd` 中设置：

```gdscript
const CATALOG_GRID_COLUMNS := 6
const CATALOG_CELLS_PER_PAGE := 24
const CATALOG_CELL_SIZE := Vector2(132, 132)
```

在 `_make_catalog_cell` 中先构造完整 tooltip 文本。已解锁时设置 `button.text = ""`，仅从 `res://resources/recipe_icons_catalog/%s.png` 加载图标；未解锁时保留当前锁定文本并确保 `RecipeIcon.texture = null`。空白分页格同样清空图标。

- [ ] **Step 5: 运行 MVP 自检并确认 GREEN**

Run: 与 Step 2 相同，日志改为 `catalog-icon-mvp-green.log`。

Expected: `MVP_SELF_CHECK_PASS`；若出现既有无关数据漂移，记录后继续运行下一步聚焦组件验证。

### Task 3: 最终验证

**Files:**
- Verify: `resources/recipe_icons_catalog/*.png`
- Verify: `scenes/ui/overlays/catalog_recipe_card.tscn`
- Verify: `scripts/main_view.gd`

**Interfaces:**
- Consumes: Task 1 与 Task 2 的生成结果。
- Produces: 可交付的分支工作树与验证记录。

- [ ] **Step 1: 运行 Python 测试**

Run: Task 1 Step 2 的 unittest 命令。

Expected: PASS。

- [ ] **Step 2: 运行 Godot 载入验证**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\catalog-icon-load.log" --quit
```

Expected: exit code 0，无新增解析错误。

- [ ] **Step 3: 运行组件契约自检**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\catalog-icon-component.log" -s res://tests/component_contract_self_check.gd
```

Expected: `COMPONENT_CONTRACT_SELF_CHECK_PASS`。

- [ ] **Step 4: 检查最终差异**

确认没有修改 `D:\Project\ProjectRest\output\imagegen`，不存在 512×512 图标误写入图鉴目录，且 Git diff 只包含规格、计划、生成器、测试、图鉴场景、`main_view.gd` 和132×132缩略图。

