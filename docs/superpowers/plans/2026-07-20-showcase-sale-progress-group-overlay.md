# 橱窗商品级联合进度覆盖实施计划

**目标：** 将当前每格独立销售进度替换为每件商品唯一的联合轮廓覆盖；横向连续、纵向使用一条全局液面，不规则形状不覆盖空格。

**设计依据：** `docs/superpowers/specs/2026-07-17-showcase-sale-progress-cell-overlay-design.zh.md`

**工作边界：** 只修改销售进度覆盖与成交反馈相关代码。当前工作区存在大量并行改动，所有编辑和差异检查必须限定到下列文件与对应 hunk。

## Task 1：建立商品级覆盖几何红测

**Files**

- Create: `scenes/ui/storefront/showcase_sale_progress_group.tscn`
- Create: `scripts/ui/storefront/showcase_sale_progress_group.gd`
- Modify: `tests/showcase_sale_progress_overlay_self_check.gd`

先改测试，要求新场景能够加载，但当前尚不存在，因此聚焦自检必须以“缺少商品级覆盖场景/接口”失败。

随后增加以下几何合同：

1. 横向两个 `Rect2(0,0,48,48)`、`Rect2(48,0,48,48)` 在 50% 时生成一个连续的 96px 液面区间。
2. 纵向两个格在 50% 时只生成下方完整填充矩形。
3. L 形三个格在 50% 时只填充下排真实格，不填充外接矩形空角。
4. 同一液面上的相邻亮边区间合并；不相邻区间保持分离。
5. 覆盖色为 `#F06400 / 45%`，亮边为 `#FFE08A / 100%`，节点忽略鼠标。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-group-progress-red.log" -s res://tests/showcase_sale_progress_overlay_self_check.gd
```

## Task 2：实现联合轮廓绘制组件

**Files**

- Create: `scenes/ui/storefront/showcase_sale_progress_group.tscn`
- Create: `scripts/ui/storefront/showcase_sale_progress_group.gd`

组件接口：

- `configure(recipe_id: String, cell_rects: Array[Rect2], progress: float, active: bool)`
- `play_sale_complete_feedback()`
- `clear_feedback()`

组件行为：

- 合并有效格子得到控件外接矩形，并把格子矩形转换为局部坐标。
- 以 `size.y * (1.0 - progress)` 计算唯一液面 Y。
- 缓存“格子矩形与液面下方区域”的交集，`_draw()` 只绘制这些交集。
- 将同一液面上相邻的水平亮边区间合并。
- 成交脉冲只改变商品级亮边/闪烁状态；重复触发安全重启 Tween。
- `active == false` 时隐藏常态填充，但允许正在播放的成交反馈结束。

再次运行聚焦自检，确认组件几何转绿。

## Task 3：把 Main 迁移到每商品一个覆盖实例

**Files**

- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_sale_progress_overlay_self_check.gd`

实现：

1. 增加 `showcase_sale_progress_groups := {}`。
2. 用 `_refresh_showcase_sale_progress_groups()` 替代 `_refresh_showcase_sale_progress_cells()`。
3. 每次刷新从 `state.get_display_item_cells(recipe_id)` 采集真实格子 `global_rect`，转换到 `ShowcaseFeedbackLayer` 坐标。
4. 每个 `recipe_id` 只复用一个 `ShowcaseSaleProgressGroup`；下架商品清理对应实例。
5. 任一真实占用格处于预览状态时隐藏整个商品覆盖；无关预览不影响。
6. 经营且库存大于零时显示，否则隐藏；每帧只更新进度和必要几何。
7. 成交确认且售罄格刷新完成后，先通知商品级覆盖播放亮边反馈，再按现有 `cell_indices` 播放格子闪白。

集成红测必须证明：横向、纵向、L 形商品分别只有一个覆盖实例，格子节点不再显示常态进度。

## Task 4：移除格子级常态进度职责

**Files**

- Modify: `scenes/ui/storefront/showcase_slot.tscn`
- Modify: `scripts/ui/storefront/showcase_slot.gd`
- Modify: `tests/showcase_sale_progress_overlay_self_check.gd`

实现：

- 移除 `SaleProgressClip/SaleProgressFill/SaleProgressEdge` 和 `set_sale_progress()` 常态进度路径。
- 保留 `SaleCompleteFlash`、格子成交闪白与安全 Tween 重启。
- `clear_product_visual()` 只清理商品图案、徽章及格子成交反馈，不再管理销售进度。
- 确保覆盖组件和格子闪光都使用 `MOUSE_FILTER_IGNORE`。

## Task 5：验证与差异审计

依次运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-group-progress.log" -s res://tests/showcase_sale_progress_overlay_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-slot-visual.log" -s res://tests/showcase_slot_visual_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-sale-feedback.log" -s res://tests/showcase_sale_feedback_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-soldout-path.log" -s res://tests/showcase_sold_out_drag_path_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-soldout-engine.log" -s res://tests/showcase_sold_out_engine_drag_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\viewport-1920.log" -s res://tests/viewport_1920_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --quit --log-file "$env:TEMP\showcase-group-parse.log"
```

最后执行定向 `git diff --check`，确认生产代码中不存在格子级 `set_sale_progress` 调用，也不存在旧动态 `ProgressBar`。

