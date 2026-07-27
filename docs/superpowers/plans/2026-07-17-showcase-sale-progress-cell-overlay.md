# 橱窗待售进度逐格覆盖 Implementation Plan

> **实施要求：** 开始修改产品代码前使用 `superpowers:test-driven-development`，严格按每个任务的 RED → GREEN → REFACTOR 顺序执行。

**Goal:** 用商品占用格内自下而上的半透明覆盖层替代原有底部横向进度条，并在确认成交时提供短促的逐格闪光反馈。

**Architecture:** `showcase_slot.tscn` 持有稳定的覆盖、液面亮边和成交闪光节点；`showcase_slot.gd` 提供纯展示接口；`main_view.gd` 消费现有销售进度和已确认销售事件，逐格刷新表现，不拥有新计时状态，也不改变销售、库存、存档或结算逻辑。

**Tech Stack:** Godot 4.6.1、GDScript、现有 headless self-check。

**Design source:** `docs/superpowers/specs/2026-07-17-showcase-sale-progress-cell-overlay-design.zh.md`

## Global Constraints

- 目标 checkout 固定为 `D:\Project\ProjectRest\project-rest-new`。
- 保留当前工作区所有无关改动；每次暂存前检查 `git diff --cached --name-only`。
- 覆盖层位于商品图案上方，使用高饱和琥珀橙 `#F06400`、45% 不透明度，方向严格自下而上；液面亮边使用暖金黄 `#FFE08A`、100% 不透明度。
- 多格和不规则商品只更新真实占用格，不使用外接矩形。
- 调整阶段、售罄商品、未占用格、道具格、未解锁格和拖拽预览格不显示销售进度。
- 覆盖层、液面亮边和成交闪光必须使用 `MOUSE_FILTER_IGNORE`。
- 不改变 `ShowcaseRoundSaleService`、`GameState`、经营轮持久化或结算数据形状。
- 保留现有 `ShowcaseFeedbackLayer` 的连锁、金币和成交反馈；本功能的进度节点归 `showcase_slot` 所有。
- 移除旧 `ShowcaseSaleProgress_*` 动态进度条及其缓存，不保留双重进度表达。
- 所有 Godot headless 命令必须传入可写的 `--log-file`，不得使用 `NUL`。

---

### Task 1: 让单个橱窗格拥有稳定的销售进度节点

**Files:**

- Modify: `scenes/ui/storefront/showcase_slot.tscn`
- Modify: `scripts/ui/storefront/showcase_slot.gd`
- Create: `tests/showcase_sale_progress_overlay_self_check.gd`

**Interfaces:**

- `set_sale_progress(progress: float, active: bool) -> void`
- `clear_sale_progress() -> void`
- `play_sale_complete_feedback() -> void`
- Stable nodes: `SaleProgressClip/SaleProgressFill`, `SaleProgressClip/SaleProgressEdge`, `SaleCompleteFlash`

- [ ] **Step 1: 写组件级失败断言**

在新自检中加载并实例化 `showcase_slot.tscn`，至少断言：

```gdscript
var clip := slot.get_node_or_null("SaleProgressClip") as Control
var fill := slot.get_node_or_null("SaleProgressClip/SaleProgressFill") as ColorRect
var edge := slot.get_node_or_null("SaleProgressClip/SaleProgressEdge") as ColorRect
var flash := slot.get_node_or_null("SaleCompleteFlash") as ColorRect

_expect(clip != null and fill != null and edge != null and flash != null, "slot should own sale progress visuals")
_expect(clip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "progress clip should ignore mouse input")
_expect(fill.mouse_filter == Control.MOUSE_FILTER_IGNORE, "progress fill should ignore mouse input")
_expect(edge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "progress edge should ignore mouse input")
_expect(flash.mouse_filter == Control.MOUSE_FILTER_IGNORE, "sale flash should ignore mouse input")
_expect(slot.has_method("set_sale_progress"), "slot should expose sale progress refresh")
_expect(slot.has_method("clear_sale_progress"), "slot should expose sale progress clearing")
_expect(slot.has_method("play_sale_complete_feedback"), "slot should expose confirmed-sale feedback")
```

再调用 `set_sale_progress(0.5, true)`，断言填充层和亮边可见，且其顶部锚点位于半格高度；调用 `set_sale_progress(-1.0, true)` 与 `set_sale_progress(2.0, true)`，断言进度被裁切到 `0.0–1.0`；调用 `clear_product_visual()`，断言进度和闪光全部清除。

- [ ] **Step 2: 运行新自检并确认 RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . `
  --log-file "$env:TEMP\showcase-sale-progress-slot-red.log" `
  -s res://tests/showcase_sale_progress_overlay_self_check.gd
```

Expected: FAIL，因为场景节点和三个接口尚不存在。

- [ ] **Step 3: 在场景中声明固定视觉结构**

按规格将节点放在 `RecipeIcon` 之后、名作视觉与状态节点之前：

```text
RecipeIcon
SaleProgressClip
├── SaleProgressFill
└── SaleProgressEdge
SaleCompleteFlash
MasterworkGlow
MasterworkFrame
...
```

`SaleProgressClip` 全格铺满并启用 `clip_contents`；填充层和亮边从底部锚定；所有节点默认隐藏并忽略鼠标。颜色集中在场景资源中，不在 `main_view.gd` 写视觉字面量。

- [ ] **Step 4: 实现最小格子展示接口**

在 `showcase_slot.gd` 绑定新节点，并实现：

```gdscript
func set_sale_progress(progress: float, active: bool) -> void:
    var fraction := clampf(progress, 0.0, 1.0)
    sale_progress_clip.visible = active
    sale_progress_fill.anchor_top = 1.0 - fraction
    sale_progress_edge.anchor_top = 1.0 - fraction
    sale_progress_edge.anchor_bottom = 1.0 - fraction

func clear_sale_progress() -> void:
    # 隐藏并归零覆盖；停止并清理未完成的成交 tween。

func play_sale_complete_feedback() -> void:
    # 重启一个总时长约 0.2 秒的闪白与亮边 tween。
```

`clear_product_visual()` 调用 `clear_sale_progress()`，确保复用格子不残留状态。

- [ ] **Step 5: 运行组件自检并确认 GREEN**

重复 Step 2 命令。

Expected: `SHOWCASE_SALE_PROGRESS_OVERLAY_SELF_CHECK_PASS`，退出码 0。

- [ ] **Step 6: 运行既有格子视觉回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . `
  --log-file "$env:TEMP\showcase-slot-visual-regression.log" `
  -s res://tests/showcase_slot_visual_self_check.gd
```

Expected: `SHOWCASE_SLOT_VISUAL_SELF_CHECK_PASS`。

---

### Task 2: 接入逐格平滑进度并移除旧横条

**Files:**

- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_sale_progress_overlay_self_check.gd`

**Interfaces:**

- Produces: `_refresh_showcase_sale_progress_cells() -> void`
- Removes: `showcase_progress_bars`
- Removes: `_clear_showcase_progress_bars()`
- Removes: `_refresh_showcase_group_progress_bars(now_unix: int)`

- [ ] **Step 1: 增加主场景集成失败断言**

在聚焦自检中实例化 `Main.tscn`，构造一个经营中的四格商品：

```gdscript
state.active_business_round = {
    "phase": "running",
    "item_states": {
        "sponge_cake": {
            "fresh_stock": 2,
            "carried_stock": 0,
            "duration_ms": 10_000,
            "cycle_elapsed_ms": 5_000,
            "waiting_for_refill": false,
        }
    }
}
```

刷新后断言：

- 四个占用格都显示 50% 高度的覆盖层。
- 同一商品所有占用格使用相同进度。
- 相邻非占用格没有覆盖层。
- 切换到 `adjusting` 后全部隐藏。
- 数量归零或 `waiting_for_refill = true` 后全部隐藏。
- `ShowcaseFeedbackLayer` 下不存在名称以 `ShowcaseSaleProgress_` 开头的节点。
- `main_view.gd` 不再暴露 `_refresh_showcase_group_progress_bars()`。

- [ ] **Step 2: 运行聚焦自检并确认 RED**

使用 Task 1 Step 2 的命令。

Expected: FAIL，因为主场景仍在创建旧横条，且尚未给占用格传入进度。

- [ ] **Step 3: 删除旧横条实现**

从 `main_view.gd` 删除：

- `showcase_progress_bars` 字典。
- `_refresh_storefront_showcase()` 中的旧清理与延迟刷新调用。
- `_refresh_showcase_countdown_texts()` 中的旧横条刷新。
- `_clear_showcase_progress_bars()`、`_refresh_showcase_group_progress_bars()` 及其动态 `ProgressBar` 创建逻辑。

不得删除 `ShowcaseFeedbackLayer` 本身，因为连锁关系线、断链标记、金币飞行和既有成交脉冲仍使用该层。

- [ ] **Step 4: 实现逐格进度刷新**

新增 `_refresh_showcase_sale_progress_cells()`：

1. 遍历 `state.display_items`。
2. 读取 `_showcase_round_item_view(recipe_id)` 的 `phase`、`quantity` 和 `progress`。
3. 只在 `phase == "running"` 且 `quantity > 0` 时激活覆盖层。
4. 通过 `state.get_display_item_cells(recipe_id)` 获取真实占用格。
5. 对有效格子按钮调用 `set_sale_progress(progress, active)`。
6. 对清空或不再占用的格子依靠现有 `clear_product_visual()` 清理。

在完整橱窗刷新后调用一次该方法；经营轮每帧推进并更新 `item_states` 后，在橱窗管理页调用该方法，以获得平滑液面，而不是沿用原横条的一秒级跳变。该刷新不得重新加载纹理、创建 `AtlasTexture` 或重建整个橱窗节点树。

- [ ] **Step 5: 运行聚焦自检并确认 GREEN**

重复 Task 1 Step 2 命令。

Expected: 多格进度、隐藏条件和旧横条移除断言全部通过。

- [ ] **Step 6: 运行进度相关回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-round-ui-progress.log" -s res://tests/showcase_round_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-multicell-progress.log" -s res://tests/showcase_initial_multicell_interaction_self_check.gd
```

Expected: 两项退出码均为 0；拖拽路径和多格图标不受覆盖层影响。

---

### Task 3: 在已确认成交事件上播放逐格短闪

**Files:**

- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_sale_progress_overlay_self_check.gd`

**Interfaces:**

- Produces: `_play_showcase_sale_progress_completion(event: Dictionary) -> void`
- Consumes: enriched sale-event field `cell_indices`

- [ ] **Step 1: 增加成交反馈失败断言**

在聚焦自检中构造包含四个 `cell_indices` 的已确认事件，调用新的辅助方法并断言：

- 四个对应格子的 `SaleCompleteFlash` 同时进入可见状态。
- 非事件格不播放闪光。
- 连续调用同一事件时，格子安全重启反馈，不创建重复节点。
- 等待约 0.25 秒后，闪光层恢复隐藏。
- 缺少 `cell_indices`、索引越界或格子已释放时安全跳过。

- [ ] **Step 2: 运行聚焦自检并确认 RED**

使用 Task 1 Step 2 的命令。

Expected: FAIL，因为成交辅助方法尚不存在。

- [ ] **Step 3: 接入已确认销售事件**

实现 `_play_showcase_sale_progress_completion(event)`，只遍历事件的 `cell_indices` 并调用格子接口。在 `state.apply_showcase_round_sale(...)` 返回 `true` 后调用它，确保：

- 普通成交使用 enriched event 的真实占用格。
- 非 `bonus_only` 的连锁成交也使用 enriched event 的真实占用格。
- 纯奖励事件不伪造商品成交闪光。
- 本地 0.2 秒闪光立即响应成交；现有 feedback director 的排队反馈保持原样。

- [ ] **Step 4: 运行聚焦自检并确认 GREEN**

重复 Task 1 Step 2 命令。

Expected: 成交反馈、重复触发和无效索引断言通过。

- [ ] **Step 5: 运行现有成交与售罄回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-sale-feedback-overlay.log" -s res://tests/showcase_sale_feedback_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-sold-out-drag-overlay.log" -s res://tests/showcase_sold_out_drag_path_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-sold-out-engine-overlay.log" -s res://tests/showcase_sold_out_engine_drag_self_check.gd
```

Expected: 三项退出码均为 0；售罄灰态、拖出下架和替换路径保持不变。

---

### Task 4: 完整验证与差异审计

**Files:**

- Verify only; no planned product-code additions.

- [ ] **Step 1: 运行新聚焦自检**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . `
  --log-file "$env:TEMP\showcase-sale-progress-final.log" `
  -s res://tests/showcase_sale_progress_overlay_self_check.gd
```

Expected: `SHOWCASE_SALE_PROGRESS_OVERLAY_SELF_CHECK_PASS`。

- [ ] **Step 2: 运行现有聚焦回归包**

分别使用独立、可写的 `%TEMP%` 日志文件运行：

```text
tests/showcase_slot_visual_self_check.gd
tests/showcase_round_ui_self_check.gd
tests/showcase_initial_multicell_interaction_self_check.gd
tests/showcase_sale_feedback_self_check.gd
tests/showcase_sold_out_drag_path_self_check.gd
tests/showcase_sold_out_engine_drag_self_check.gd
tests/viewport_1920_layout_self_check.gd
```

Expected: 每项退出码为 0，并出现对应 PASS 标记。

- [ ] **Step 3: 运行项目解析检查**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . --quit `
  --log-file "$env:TEMP\showcase-sale-progress-parse.log"
```

Expected: 退出码 0；没有新脚本解析、场景加载或资源错误。

- [ ] **Step 4: 审计最终差异**

```powershell
git diff --check
git status --short
git diff -- scenes/ui/storefront/showcase_slot.tscn `
  scripts/ui/storefront/showcase_slot.gd `
  scripts/main_view.gd `
  tests/showcase_sale_progress_overlay_self_check.gd
```

确认最终产品改动只包含计划内四个文件及 Godot 自动生成的对应 `.uid`（若有），并且未覆盖用户当前其他改动。

## Final Acceptance Checklist

- [ ] 原底部 5px 横向进度条完全移除。
- [ ] 经营中的有库存商品按真实占用格显示自下而上的半透明进度。
- [ ] 多格商品所有占用格进度同步，不规则形状的空格不被覆盖。
- [ ] 覆盖层位于商品图案上方，名作边框、预览轮廓和状态徽章仍清晰可见。
- [ ] 调整阶段、售罄商品、道具格、未解锁格和预览格不显示覆盖层。
- [ ] 成交时所有占用格同步播放约 0.2 秒短闪，随后正确归零或隐藏。
- [ ] 覆盖视觉不拦截悬停、拖拽、右键和放置输入。
- [ ] 销售、库存、连锁、结算、存档和既有反馈队列的数据与行为未改变。
- [ ] 新聚焦自检、既有橱窗回归和项目解析检查全部通过。
