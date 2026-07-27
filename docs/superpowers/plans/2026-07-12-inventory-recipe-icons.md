# Inventory Recipe Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将库存页面的配方和原料格统一为 80×80，并让配方格使用从原始 512×512 画布统一缩放得到的库存专用图标。

**Architecture:** 新增独立 Python 生成器，按 `scripts/catalog.gd` 的配方清单解析源图并原画布缩放到库存资源目录。新增场景化的配方库存格，复用 `output_cell.gd` 的拖拽能力；`main_view.gd` 只负责绑定图标、数量、tooltip 和既有交互。

**Tech Stack:** Python 3、Pillow LANCZOS、Godot 4.6.1、GDScript、Godot `.tscn`。

## Global Constraints

- 所有库存单格尺寸固定为 `80×80`。
- 所有配方图标从原始 `512×512` 完整画布统一缩放为 `80×80`，不得透明边界裁剪。
- 资源写入 `res://resources/recipe_icons_inventory/`，不得修改源图或橱窗图标。
- 保留库存配方格的拖拽、右键变体、选择和 tooltip 行为。
- 保持 10 列、每页 80 格。

---

### Task 1: 库存图标生成器

**Files:**
- Create: `tools/generate_inventory_recipe_icons.py`
- Create: `tests/test_generate_inventory_recipe_icons.py`
- Create: `resources/recipe_icons_inventory/*.png`

**Interfaces:**
- Consumes: `generate_inventory_icons(source_dir: Path, output_dir: Path, catalog_path: Path) -> list[Path]`
- Produces: 149 个 `<recipe_id>.png`，每个为 RGBA `80×80`。

- [x] **Step 1: Write the failing test**

  测试创建带透明边界和定位色块的 `512×512` 图片，断言输出色块位置按 `80/512` 缩放，源文件字节不变；另测非 `512×512` 输入拒绝生成且不覆盖旧输出。

- [x] **Step 2: Run test to verify it fails**

  Run: `python tests/test_generate_inventory_recipe_icons.py`
  Expected: FAIL，因为 `tools/generate_inventory_recipe_icons.py` 尚不存在。

- [x] **Step 3: Write minimal implementation**

  实现 `INVENTORY_ICON_SIZE = (80, 80)`、目录解析、5 个旧文件名别名、严格 512×512 校验、LANCZOS 整图缩放和暂存目录原子发布。

- [x] **Step 4: Run test to verify it passes**

  Run: `python tests/test_generate_inventory_recipe_icons.py`
  Expected: 所有测试 PASS。

- [x] **Step 5: Generate project assets**

  Run: `python tools/generate_inventory_recipe_icons.py --source-dir ../output/imagegen --output-dir resources/recipe_icons_inventory --catalog-path scripts/catalog.gd`
  Expected: `generated 149 inventory icons`。

### Task 2: 场景化库存配方格与运行时绑定

**Files:**
- Create: `scenes/ui/overlays/inventory_product_cell.tscn`
- Create: `tests/inventory_recipe_icon_layout_self_check.gd`
- Modify: `scripts/main_view.gd`

**Interfaces:**
- Consumes: `res://resources/recipe_icons_inventory/%s.png`、`OutputCellButton.configure_drag(...)`。
- Produces: 节点 `RecipeIcon: TextureRect` 与 `QuantityBadge: Label` 的 80×80 配方库存按钮。

- [x] **Step 1: Write the failing Godot self-check**

  自检实例化主场景，打开库存并分别构造配方、原料条目，断言两者最小尺寸为 `Vector2(80, 80)`；配方格必须含图标和数量角标、图标纹理尺寸为 80×80、拖拽数据保留 `recipe_id`；原料格不要求配方图标。

- [x] **Step 2: Run test to verify it fails**

  Run: `Godot --headless --path . --log-file <writable> -s res://tests/inventory_recipe_icon_layout_self_check.gd`
  Expected: FAIL，因为当前库存格仍为 74×58 且配方格没有 `RecipeIcon`。

- [x] **Step 3: Write minimal implementation**

  新建以 `output_cell.gd` 为脚本的按钮场景，加入全尺寸 `RecipeIcon` 和右下角 `QuantityBadge`；在 `main_view.gd` 中预加载场景，把 `INVENTORY_CELL_SIZE` 改为 `Vector2(80, 80)`，配方分支实例化场景并加载库存专用纹理，配方按钮正文留空，原料分支保持现状。

- [x] **Step 4: Run focused test to verify it passes**

  Run: `Godot --headless --path . --log-file <writable> -s res://tests/inventory_recipe_icon_layout_self_check.gd`
  Expected: PASS，0 failures。

### Task 3: 回归验证

**Files:**
- Modify only if required by observed regression: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: Tasks 1-2 的最终资源与运行时节点。
- Produces: 可复现的验证记录。

- [x] **Step 1: Run generator tests**

  Run: `python -m unittest tests.test_generate_inventory_recipe_icons tests.test_generate_catalog_recipe_icons tests.test_generate_action_recipe_icons`
  Expected: PASS。

- [x] **Step 2: Run focused Godot checks**

  运行库存图标聚焦自检和 `tests/output_layout_self_check.gd`，每条命令均指定可写 `--log-file`。

- [x] **Step 3: Run MVP self-check**

  运行 `tests/mvp_self_check.gd`，记录总数与失败项；若失败与本次库存改动相关则先修复并重跑，既有无关失败明确列出。

- [x] **Step 4: Inspect final diff**

  Run: `git status --short` 与 `git diff --check`；确认不包含用户已有的 `.gitignore` 和 `doc/recipe_data_audit.md`。
