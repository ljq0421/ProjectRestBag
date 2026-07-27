# 橱窗爽感与完整反馈系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将橱窗从“拖拽上架 + tooltip 解释加成”升级为完整的策略反馈系统，让玩家在摆放前、放下时、营业中、售出后和长期成长中都能感知加成带来的收益与爽感。

**Architecture:** 采用“规则计算层 -> 拖拽预览层 -> 表现编排层 -> 售卖结算层 -> 长期成长层”的分层方案。所有 UI 展示、售卖结算、tooltip、售卖记录和成长触发都必须消费同一个橱窗规则计算结果，避免同一布局在不同界面显示不同数值。

**Tech Stack:** Godot 4.6.1, GDScript, `.tscn` scene-first UI edits, existing `GameState`, `shop_simulation.gd`, `recipe_growth_service.gd`, `display_rules_full.json`, headless self-check scripts.

## Global Constraints

- 橱窗物理棋盘最终规格为 `10x10`，玩家初始只解锁中心或指定起始区 `6x6`；未解锁格子必须渲染为锁定格并拒绝拖拽，后续通过升级扩展到完整 `10x10`。
- 历史 `5x10` 文档只能作为规则来源参考，不得继续作为运行时尺寸来源。
- 四方向相邻是唯一有效相邻判定；斜角不计入加成、减损或成长触发。
- UI 不重复计算规则；UI 只展示规则计算层产出的 `reasons`, `affected_cells`, `price_bonus_pct`, `speed_bonus_pct`, `groups`, `penalties` 等结果。
- ProjectRest UI 修改优先编辑 `scenes/Main.tscn`，`scripts/main_view.gd` 只负责节点绑定、状态刷新、拖拽路径和表现调度。
- 规则解释保持计算层优先：`doc/display_rules_full.json` 提供规则名和描述，`shop_simulation.gd`、`recipe_growth_service.gd` 或新规则服务生成原因，`main_view.gd` 只格式化展示。
- 拖拽上架必须走真实 `_drop_showcase_data()` 路径，不能只验证按钮上架路径。
- Godot headless 验证必须从包含 `project.godot` 的 `D:\Project\ProjectRest\project-rest` 运行，并显式传入 writable `--log-file "$env:TEMP\godot-headless.log"`。
- 本计划不要求一次性上线全部表现；但最终版架构必须从第一阶段开始为全部反馈形态预留字段，避免后续推倒重写。

---

## 最终体验方案

### 体验闭环

最终版橱窗体验分为六个连续环节：

1. **摆放前预判**：拖起商品后，玩家能看到商品形状、可放置区域、预计收益、冲突风险、差一步套装提示。
2. **放下瞬间爆发**：商品成功落位时，根据结果播放普通上架、基础加成、套装成立、冲突、区域强化、成长触发等不同强度反馈。
3. **常态可读**：满格橱窗中仍能一眼看出套装组、冲突点、招牌商品、区域价值和当前售卖进度。
4. **营业中可见**：售速加成通过进度条速度、金币飞行、套装连击和售出节奏体现出来。
5. **售出后归因**：每笔售卖都能展示基础售价、区域加成、相邻加成、套装加成、成长加成和惩罚扣减。
6. **长期成长**：常用搭配会让产品成长为人气款、招牌款、镇店款，解锁形态变化和橱窗特性。

### 拖拽预览

拖动产品进入橱窗时，预览态需要展示：

- 商品实际占格形状，包含旋转后的格子覆盖。
- 合法格使用冷色透明覆盖，非法格使用红色覆盖。
- 未解锁格使用锁定覆盖，tooltip 明确显示扩展条件，不参与收益预览。
- 正向相邻边使用绿色或金色短线连接。
- 负面冲突边使用红色短线或裂纹连接。
- 落点收益摘要，例如 `预计 售价 +23% / 售速 +18% / 触发 经典下午茶三件套`。
- 差一步提示，例如 `旁边再放 1 个茶香商品可成立全茶风味套装`。
- 已覆盖格和锁定格说明必须继续存在，不能被收益提示覆盖。

拖拽预览的目标是让玩家在放下前就感到“这里可能很赚”，而不是等结算后才知道结果。

### 放下瞬间反馈

商品成功上架或移动后，反馈按强度分层：

- **普通上架**：商品轻微缩放回弹，格子闪光一次。
- **基础相邻加成**：相邻商品之间出现短暂连线，双方弹出 `售价 +8%`、`售速 +5%` 等小字。
- **套装成立**：整组商品出现轮廓线，中央或右侧短暂显示套装名，例如 `经典下午茶三件套成立！`。
- **区域强化**：黄金 C 位商品触发时展示灯扫光，引流位和宝藏位使用更低调的区域光效。
- **冲突减损**：冲突边变红并轻震，显示 `口感冲突 -8% 售价` 或 `饱腹压制 -5% 售速`。
- **成长触发**：若本次摆放或售卖推进成长阶段，使用现有通知/弹窗系统显示 `黄油曲奇成长为人气款，解锁 茶点搭档`。

反馈强度必须与收益层级匹配。普通加成不能抢套装成立的表现，负面反馈要清晰但不能阻断操作。

### 常态橱窗可读性

橱窗满格时，默认态只显示高价值信息：

- 商品名、库存、成长短标、售卖进度。
- 初始 `6x6` 以外的格子显示为锁定橱窗区，保持 `10x10` 棋盘轮廓，让玩家看到未来扩展空间。
- 套装组徽章或轻描边。
- 当前负面冲突点。
- 招牌款或镇店款专属边框。
- 区域底纹区分前排引流位、黄金 C 位、宝藏深处位。

选中或悬停一个商品时，才展开详细关系：

- 与该商品相关的所有正向相邻边。
- 与该商品相关的冲突边。
- 参与的套装组。
- 当前最终售价倍率和售速倍率。
- 下一步可优化提示，例如 `移动到黄金 C 位可让相邻加成额外 +20%`。

### 营业中动态反馈

售速加成必须有体感：

- 每个在售商品显示小型进度环或进度条。
- 售速加成越高，进度推进越快，颜色越积极。
- 套装商品售出时，金币从商品飞向收银区。
- 连续售出同一套装时，营业记录显示 `下午茶三件套 x3，本轮额外 +126`。
- 售速减损商品的进度条变灰或有拖慢效果，让惩罚可见。

### 售出归因

售卖记录和一轮营业总结都必须拆分来源。单件售出示例：

```text
海绵杯蛋糕售出 +48
基础售价 +40
黄金C位 +2
经典下午茶三件套 +6
招牌成长 +3
口感冲突 -3
最终 +48
```

一轮营业总结需要展示：

- 基础收入。
- 橱窗相邻与套装加成。
- 区域加成。
- 成长加成。
- 冲突损失。
- 最高贡献商品。
- 最高贡献套装。

### 长期成长

成长维度：

- 制作次数：影响成本、产量或制作效率。
- 售卖次数：影响基础售价或售速。
- 有效相邻次数：解锁邻接特性。
- 套装参与次数：解锁套装核心能力。
- 区域使用偏好：长期在前排、C 位或深处售卖后获得区域适性。

成长阶段：

| 阶段 | 定位 | 解锁方向 |
|---|---|---|
| 试作品 | 刚研发成功 | 基础售价、基础售速 |
| 稳定款 | 经过制作和售卖验证 | 成本、产量、轻量售价收益 |
| 人气款 | 市场认可 | 第一个橱窗特性 |
| 招牌款 | build 核心 | 形态变化或套装核心 |
| 镇店款 | 长期培养目标 | 专属视觉、专属播报、顾客偏好入口 |

特性示例：

| 特性 | 触发条件 | 效果 |
|---|---|---|
| 茶点搭档 | 相邻商品含 `茶香` | 双方售速 +5% |
| 核心展位 | 位于黄金 C 位且至少 2 个邻居 | 自身售价 +6% |
| 咸甜桥梁 | 一侧为 `咸香`，另一侧为 `甜` | 三件售速 +6% |
| 礼盒装 | 迷你或横盘商品成长后切换 | 占格增加，售价提高，售速略降 |
| 招牌大份 | 中块或招牌商品成长后切换 | 占格增加，相邻加成倍率提高，售速下降 |

---

## File Structure

### Data and Docs

- Modify: `D:\Project\ProjectRest\project-rest\doc\橱窗配方布局设计.md`
  - 统一最终规则说明，标记旧 `5x10` 为历史版本，写入 `6x6` 初始可用区、`10x10` 最终规格、解锁扩展路径和区域定义。
- Modify: `D:\Project\ProjectRest\project-rest\doc\display_rules_full.json`
  - 保留基础标签、套装、冲突、区域规则，增加 UI 表现需要的 `visual_tier`, `effect_color`, `feedback_key`, `hint_template` 字段。
- Modify: `D:\Project\ProjectRest\project-rest\doc\recipe_display_config.json`
  - 确保每个可售产品有形状、旋转、默认尺寸、可用形态、标签和显示名。

### Runtime Logic

- Create: `D:\Project\ProjectRest\project-rest\scripts\showcase_rule_evaluator.gd`
  - 纯规则计算层，输入布局和预览落点，输出统一加成结果。
- Create: `D:\Project\ProjectRest\project-rest\scripts\showcase_preview_model.gd`
  - 拖拽预览数据模型，负责合法格、非法格、预期加成、差一步提示。
- Create: `D:\Project\ProjectRest\project-rest\scripts\showcase_feedback_director.gd`
  - 表现编排层，负责把规则结果映射为 UI feedback events。
- Modify: `D:\Project\ProjectRest\project-rest\scripts\shop_simulation.gd`
  - 售卖结算读取 `showcase_rule_evaluator.gd` 输出，不再单独拼装另一套加成原因。
- Modify: `D:\Project\ProjectRest\project-rest\scripts\recipe_growth_service.gd`
  - 增加套装参与、区域使用、镇店款阶段和成长通知原因。
- Modify: `D:\Project\ProjectRest\project-rest\scripts\game_state.gd`
  - 持久化 `recipe_growth`、橱窗布局、形态选择、成长事件摘要。

### UI

- Modify: `D:\Project\ProjectRest\project-rest\scenes\Main.tscn`
  - 橱窗节点增加预览层、连线层、反馈层、售卖进度层和归因记录容器。
- Modify: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`
  - 绑定新 UI 节点，调用预览模型、规则计算和反馈导演，格式化 tooltip 与售卖记录。

### Tests

- Modify: `D:\Project\ProjectRest\project-rest\tests\showcase_bonus_reason_self_check.gd`
  - 覆盖统一规则结果、正负原因、售卖归因。
- Modify: `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`
  - 保留真实 `_drop_showcase_data()` 拖拽路径、上架、移动、旋转、售卖和成长流程。
- Create: `D:\Project\ProjectRest\project-rest\tests\showcase_preview_feedback_self_check.gd`
  - 覆盖拖拽预览、反馈事件、套装轮廓、冲突提示和售速表现元数据。

---

## Shared Interfaces

### `ShowcaseRuleEvaluator.evaluate_layout`

```gdscript
static func evaluate_layout(game_state: GameState, catalog: Catalog, now_unix: int = 0) -> Dictionary
```

Returns:

```gdscript
{
	"items": {
		"slot_index": {
			"recipe_id": "sponge_cake",
			"anchor_slot": 44,
			"cells": [44, 45, 54, 55],
			"price_bonus_pct": 23,
			"speed_bonus_pct": 18,
			"price_multiplier": 1.23,
			"speed_multiplier": 1.18,
			"reasons": [],
			"penalties": [],
			"groups": [],
			"growth_bonus": {},
			"zone_bonus": {}
		}
	},
	"groups": [],
	"edges": [],
	"summary": {
		"total_price_bonus_pct": 0,
		"total_speed_bonus_pct": 0,
		"penalty_count": 0,
		"set_count": 0
	}
}
```

### `ShowcaseRuleEvaluator.preview_drop`

```gdscript
static func preview_drop(game_state: GameState, catalog: Catalog, drag_data: Dictionary, target_slot: int, rotation: int = 0) -> Dictionary
```

Returns:

```gdscript
{
	"can_drop": true,
	"target_slot": 44,
	"cells": [44, 45, 54, 55],
	"invalid_cells": [],
	"edges": [],
	"new_reasons": [],
	"new_penalties": [],
	"near_miss_hints": [],
	"summary_text": "预计 售价 +23% / 售速 +18% / 触发 经典下午茶三件套"
}
```

### `ShowcaseFeedbackDirector.build_events`

```gdscript
static func build_events(before_result: Dictionary, after_result: Dictionary, context: Dictionary = {}) -> Array[Dictionary]
```

Returns:

```gdscript
[
	{
		"type": "set_completed",
		"tier": 3,
		"title": "经典下午茶三件套成立！",
		"cells": [44, 45, 54, 55, 46, 56],
		"edges": [],
		"duration_sec": 1.2
	}
]
```

### `RecipeGrowthService.record_showcase_sale`

```gdscript
static func record_showcase_sale(game_state: GameState, recipe_id: String, rule_item_result: Dictionary, sale_context: Dictionary = {}) -> Dictionary
```

Returns:

```gdscript
{
	"leveled_up": true,
	"new_stage": "人气款",
	"unlocked_traits": ["tea_partner"],
	"notification_title": "黄油曲奇成长为人气款",
	"notification_body": "解锁橱窗特性：茶点搭档。"
}
```

---

## Task 1: 统一 6x6 起步到 10x10 的橱窗规则与历史文档

**Files:**
- Modify: `D:\Project\ProjectRest\project-rest\doc\橱窗配方布局设计.md`
- Modify: `D:\Project\ProjectRest\project-rest\doc\display_rules_full.json`
- Modify: `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`

**Interfaces:**
- Consumes: existing product shape and display rule docs.
- Produces: one authoritative runtime assumption: physical grid is `10x10` with 100 cells, initial unlocked area is `6x6` with 36 usable cells, four-direction adjacency only.

- [ ] **Step 1: Add failing assertions for final grid size**

In `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`, ensure the storefront grid assertion requires 100 children and 10 columns. Add assertions that a new save exposes 36 unlocked showcase cells, locked cells reject product drag preview, and locked cell tooltip explains the expansion requirement. Keep the current `_drop_showcase_data()` live interaction coverage.

- [ ] **Step 2: Run the focused existing self-check**

Run from `D:\Project\ProjectRest\project-rest`:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: PASS if the current runtime already renders 100 cells and gates the initial 36 usable cells correctly; otherwise FAIL on the exact grid-size or locked-cell assertion.

- [ ] **Step 3: Update docs to mark 6x6 initial unlock and 10x10 final board**

In `doc\橱窗配方布局设计.md`, update the basic rule section to state:

```markdown
- **初始规格**：新玩家初始解锁 6行 × 6列 = 36个可用标准格子。
- **最终规格**：完整橱窗为 10行 × 10列 = 100个标准格子，未解锁格子显示为锁定扩展区。
- **历史说明**：旧版 `5行 × 10列` 仅保留为早期设计记录，运行时、测试和新规则均以 `6x6 起步、10x10 封顶` 为准。
```

- [ ] **Step 4: Update `display_rules_full.json` metadata**

Set the metadata description to reference `6x6` initial unlock and `10x10` final board, then add explicit fields:

```json
"grid": {
  "rows": 10,
  "columns": 10,
  "initial_unlocked_rows": 6,
  "initial_unlocked_columns": 6,
  "adjacency": "orthogonal"
}
```

- [ ] **Step 5: Run verification**

Run:

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: PASS, or a failure unrelated to grid size that must be captured before moving to Task 2.

---

## Task 2: 抽出统一规则计算层

**Files:**
- Create: `D:\Project\ProjectRest\project-rest\scripts\showcase_rule_evaluator.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\shop_simulation.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\showcase_bonus_reason_self_check.gd`

**Interfaces:**
- Consumes: `GameState.display_slots`, `Catalog.get_display_rules()`, recipe tags, recipe growth state.
- Produces: `ShowcaseRuleEvaluator.evaluate_layout(...)` and `ShowcaseRuleEvaluator.preview_drop(...)`.

- [ ] **Step 1: Add failing test for single-source rule output**

In `tests\showcase_bonus_reason_self_check.gd`, assert that a known positive adjacency returns the same reason text in tooltip and sale receipt. The test should inspect existing tooltip text and `_showcase_bonus_for_recipe(...)` output.

- [ ] **Step 2: Run focused test**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_bonus_reason_self_check.gd
```

Expected: FAIL until rule results are centralized.

- [ ] **Step 3: Create `showcase_rule_evaluator.gd`**

Create a script with static methods:

```gdscript
extends RefCounted
class_name ShowcaseRuleEvaluator

static func evaluate_layout(game_state: GameState, catalog: Catalog, now_unix: int = 0) -> Dictionary:
	var result := {
		"items": {},
		"groups": [],
		"edges": [],
		"summary": {
			"total_price_bonus_pct": 0,
			"total_speed_bonus_pct": 0,
			"penalty_count": 0,
			"set_count": 0
		}
	}
	# Move existing bonus, penalty, set and zone computation here.
	return result

static func preview_drop(game_state: GameState, catalog: Catalog, drag_data: Dictionary, target_slot: int, rotation: int = 0) -> Dictionary:
	return {
		"can_drop": false,
		"target_slot": target_slot,
		"cells": [],
		"invalid_cells": [],
		"edges": [],
		"new_reasons": [],
		"new_penalties": [],
		"near_miss_hints": [],
		"summary_text": ""
	}
```

- [ ] **Step 4: Move existing rule computation into evaluator**

Port the current bonus and reason-building logic from `shop_simulation.gd`, `recipe_growth_service.gd` or `main_view.gd` into `ShowcaseRuleEvaluator`. Preserve current rule names, descriptions and numeric outputs.

- [ ] **Step 5: Update UI and sale code to consume evaluator**

Replace local rule formatting in `main_view.gd` with calls to `ShowcaseRuleEvaluator.evaluate_layout(...)`. Replace sale scoring in `shop_simulation.gd` so price and speed use the same item result.

- [ ] **Step 6: Run focused and MVP tests**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_bonus_reason_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: both PASS.

---

## Task 3: 拖拽预览收益与冲突提示

**Files:**
- Create: `D:\Project\ProjectRest\project-rest\scripts\showcase_preview_model.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\showcase_preview_feedback_self_check.gd`

**Interfaces:**
- Consumes: `ShowcaseRuleEvaluator.preview_drop(...)`.
- Produces: preview metadata on grid buttons: `showcase_preview`, `showcase_preview_positive_edges`, `showcase_preview_penalty_edges`, `showcase_preview_summary`.

- [ ] **Step 1: Create failing preview test**

Create `tests\showcase_preview_feedback_self_check.gd` that:

- Instantiates `Main.tscn`.
- Places two products that can form a known positive adjacency.
- Calls `_can_drop_showcase_data("showcase", drag_data)`.
- Asserts preview cells have `showcase_preview` metadata.
- Asserts at least one preview cell tooltip or metadata contains `预计`.
- Asserts conflict cases expose a penalty reason when using a known conflict pair.

- [ ] **Step 2: Run the new test**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_preview_feedback_self_check.gd
```

Expected: FAIL because preview summary metadata does not exist yet.

- [ ] **Step 3: Implement `ShowcasePreviewModel`**

Create methods:

```gdscript
extends RefCounted
class_name ShowcasePreviewModel

static func build_preview(game_state: GameState, catalog: Catalog, drag_data: Dictionary, target_slot: int, rotation: int = 0) -> Dictionary:
	return ShowcaseRuleEvaluator.preview_drop(game_state, catalog, drag_data, target_slot, rotation)

static func summary_for_preview(preview: Dictionary) -> String:
	if not bool(preview.get("can_drop", false)):
		return "无法放置"
	return String(preview.get("summary_text", "可上架"))
```

- [ ] **Step 4: Wire preview into `_can_drop_showcase_data()`**

In `main_view.gd`, call `ShowcasePreviewModel.build_preview(...)` during drag hover, apply metadata and tooltip text to affected grid cells, and clear metadata via the existing drag cleanup path.

- [ ] **Step 5: Run preview and MVP tests**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_preview_feedback_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: both PASS.

---

## Task 4: 放下瞬间反馈事件

**Files:**
- Create: `D:\Project\ProjectRest\project-rest\scripts\showcase_feedback_director.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scenes\Main.tscn`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\showcase_preview_feedback_self_check.gd`

**Interfaces:**
- Consumes: before and after `ShowcaseRuleEvaluator.evaluate_layout(...)` results.
- Produces: feedback events with `type`, `tier`, `title`, `cells`, `edges`, `duration_sec`.

- [ ] **Step 1: Extend preview feedback test**

Add assertions that after `_drop_showcase_data(...)`, `main_view.gd` stores recent feedback event metadata or renders a feedback label containing a known rule name when a set or adjacency becomes active.

- [ ] **Step 2: Run test**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_preview_feedback_self_check.gd
```

Expected: FAIL until feedback events exist.

- [ ] **Step 3: Implement `ShowcaseFeedbackDirector`**

Create `build_events(...)` to compare before and after results:

- new positive adjacency -> `type = "adjacency_bonus"`, `tier = 1`
- new set group -> `type = "set_completed"`, `tier = 3`
- new penalty -> `type = "penalty_triggered"`, `tier = 2`
- new zone effect -> `type = "zone_bonus"`, `tier = 1`
- growth stage change -> `type = "growth_unlocked"`, `tier = 4`

- [ ] **Step 4: Add scene feedback containers**

In `Main.tscn`, add or expose:

- `ShowcasePreviewLayer`
- `ShowcaseEdgeLayer`
- `ShowcaseFeedbackLayer`
- `ShowcaseFloatingTextLayer`

Keep them inside the storefront showcase panel, not as unrelated global UI.

- [ ] **Step 5: Dispatch feedback after successful drop**

In `_drop_showcase_data(...)`, capture rule result before mutation, run the existing drop logic, refresh state, capture rule result after mutation, call `ShowcaseFeedbackDirector.build_events(...)`, then render feedback.

- [ ] **Step 6: Run verification**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_preview_feedback_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: both PASS.

---

## Task 5: 常态橱窗关系可读性

**Files:**
- Modify: `D:\Project\ProjectRest\project-rest\scenes\Main.tscn`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\showcase_preview_feedback_self_check.gd`

**Interfaces:**
- Consumes: evaluator `groups`, `edges`, `penalties`, `growth_bonus`.
- Produces: stable cell metadata and visual states: `showcase_group_highlight`, `showcase_set_badge`, `showcase_penalty_marker`, `showcase_growth_stage`.

- [ ] **Step 1: Add assertions for常态 metadata**

Extend `showcase_preview_feedback_self_check.gd` to assert:

- products participating in a set expose `showcase_set_badge`.
- products with conflicts expose `showcase_penalty_marker`.
- growth stage text remains visible.
- repeated one-cell products still use existing group highlight behavior.

- [ ] **Step 2: Run test**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_preview_feedback_self_check.gd
```

Expected: FAIL until metadata is added.

- [ ] **Step 3: Render group, penalty and growth states**

In `_refresh_storefront_showcase()`, apply cell metadata and styleboxes based on `ShowcaseRuleEvaluator.evaluate_layout(...)`.

- [ ] **Step 4: Keep detail expansion on hover or selection**

When hovering a cell, show detailed rule sources only for that product. Do not render all edge labels at once in default state.

- [ ] **Step 5: Run verification**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_preview_feedback_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: both PASS.

---

## Task 6: 营业动态售速表现

**Files:**
- Modify: `D:\Project\ProjectRest\project-rest\scenes\Main.tscn`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\shop_simulation.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`

**Interfaces:**
- Consumes: item-level `speed_multiplier`, `sale_ready_at_unix`, current time.
- Produces: visual sale progress percentage and adjusted sale timer.

- [ ] **Step 1: Add sale speed assertions**

In `mvp_self_check.gd`, keep existing `_showcase_sale_seconds_for_bonus(20, 1.25)` and `_showcase_sale_seconds_for_bonus(20, 0.75)` assertions. Add one assertion that the showcase grid cell exposes sale progress metadata after refresh.

- [ ] **Step 2: Run MVP self-check**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: FAIL if progress metadata is missing.

- [ ] **Step 3: Add progress metadata and UI rendering**

In `main_view.gd`, compute:

```gdscript
var listed_at := int(slot.get("listed_at_unix", now_unix))
var ready_at := int(slot.get("sale_ready_at_unix", now_unix))
var total := max(1, ready_at - listed_at)
var elapsed := clamp(now_unix - listed_at, 0, total)
var progress := float(elapsed) / float(total)
button.set_meta("showcase_sale_progress", progress)
```

Render this as a small progress strip or ring inside each occupied anchor cell.

- [ ] **Step 4: Trigger visible sale feedback when sale completes**

When `_process_showcase_sales(...)` sells a product, use `ShowcaseFeedbackDirector` event `sale_completed` and include item-level attribution.

- [ ] **Step 5: Run verification**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: PASS.

---

## Task 7: 售出归因账单与营业总结

**Files:**
- Modify: `D:\Project\ProjectRest\project-rest\scripts\shop_simulation.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\showcase_bonus_reason_self_check.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`

**Interfaces:**
- Consumes: item-level `reasons`, `penalties`, `zone_bonus`, `growth_bonus`.
- Produces: sale receipt lines and round summary fields.

- [ ] **Step 1: Add receipt assertions**

In `showcase_bonus_reason_self_check.gd`, assert sale receipt contains:

- `基础售价`
- `橱窗加成`
- at least one rule name from `display_rules_full.json`
- `最终`

- [ ] **Step 2: Run focused test**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_bonus_reason_self_check.gd
```

Expected: FAIL until receipt lines are expanded.

- [ ] **Step 3: Build receipt formatter in `main_view.gd`**

Add a formatter that receives one sale result dictionary and returns lines:

```text
{商品名}售出 +{最终金币}
基础售价 +{基础售价}
{区域名} {正负金额}
{规则名} {正负金额}
{成长名} {正负金额}
最终 +{最终金币}
```

- [ ] **Step 4: Persist sale attribution in recent feedback**

When a timed showcase sale completes, append the full receipt to existing recent feedback or cashier receipt UI. Keep short summary visible and full detail in tooltip or expandable text.

- [ ] **Step 5: Add round summary**

Aggregate per-sale attribution into one营业总结:

- base income
- showcase bonus income
- growth bonus income
- penalty loss
- best product
- best set

- [ ] **Step 6: Run verification**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_bonus_reason_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: both PASS.

---

## Task 8: 产品成长最终版

**Files:**
- Modify: `D:\Project\ProjectRest\project-rest\scripts\recipe_growth_service.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\game_state.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\shop_simulation.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\mvp_self_check.gd`

**Interfaces:**
- Consumes: sale attribution and rule item result.
- Produces: `recipe_growth` with stages, traits, set participation and region preference.

- [ ] **Step 1: Add growth assertions**

In `mvp_self_check.gd`, assert that a product can progress through:

- made count
- sold count
- adjacency trigger count
- set participation count
- region use count
- stage text rendered in showcase grid

- [ ] **Step 2: Run MVP self-check**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: FAIL until added growth fields exist.

- [ ] **Step 3: Extend growth state**

Add fields under each recipe:

```json
{
  "mastery_level": 0,
  "made_count": 0,
  "sold_count": 0,
  "adjacency_trigger_count": 0,
  "set_participation_count": 0,
  "front_row_sales": 0,
  "center_zone_sales": 0,
  "deep_row_sales": 0,
  "display_traits": [],
  "selected_display_traits": [],
  "signature_stage": ""
}
```

- [ ] **Step 4: Record sale growth from rule result**

Add `RecipeGrowthService.record_showcase_sale(game_state, recipe_id, rule_item_result, sale_context)` and call it only when a product is truly sold, not when it is listed.

- [ ] **Step 5: Add stage thresholds**

Use deterministic thresholds:

- 试作品 -> 稳定款: `made_count >= 5` and `sold_count >= 3`
- 稳定款 -> 人气款: `made_count >= 15` and `sold_count >= 10` and `adjacency_trigger_count >= 3`
- 人气款 -> 招牌款: `made_count >= 40` and `sold_count >= 25` and `adjacency_trigger_count >= 10`
- 招牌款 -> 镇店款: `sold_count >= 80` and `set_participation_count >= 20`

- [ ] **Step 6: Render growth unlock feedback**

Use existing pending notification or popup queue. Do not create a parallel notification system.

- [ ] **Step 7: Run verification**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: PASS.

---

## Task 9: 后期策略扩展

**Files:**
- Modify: `D:\Project\ProjectRest\project-rest\doc\display_rules_full.json`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\showcase_rule_evaluator.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\game_state.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`
- Create: `D:\Project\ProjectRest\project-rest\tests\showcase_strategy_extensions_self_check.gd`

**Interfaces:**
- Consumes: finalized evaluator output and growth state.
- Produces: daily hot tags, showcase themes, display props and customer preference modifiers.

- [ ] **Step 1: Add strategy extension test**

Create `showcase_strategy_extensions_self_check.gd` that asserts:

- a daily hot tag changes speed or price attribution.
- a showcase theme adds a named reason.
- a display prop affects only its configured nearby cells.
- customer preference appears in receipt attribution without replacing base showcase rules.

- [ ] **Step 2: Run the new test**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_strategy_extensions_self_check.gd
```

Expected: FAIL until extensions are implemented.

- [ ] **Step 3: Add daily hot tags**

Store a daily or cycle-based `hot_tags` list in `GameState`, and have `ShowcaseRuleEvaluator` add a reason when listed products match the tag.

- [ ] **Step 4: Add showcase themes**

Represent active theme as `game_state.active_showcase_theme`. Theme effects must be data-driven and appear in attribution as `主题橱窗：{主题名}`.

- [ ] **Step 5: Add display props**

Props occupy cells and provide local bonuses. They must use the same cell occupancy and adjacency APIs as products so drag/drop collision stays consistent.

- [ ] **Step 6: Add customer preference modifiers**

Customer preference modifies selection or speed after base showcase rules are calculated. It must not mutate base rule results; it adds a separate attribution line.

- [ ] **Step 7: Run verification**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_strategy_extensions_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: both PASS.

---

## Task 10: 表现节奏、可访问性与性能收口

**Files:**
- Modify: `D:\Project\ProjectRest\project-rest\scenes\Main.tscn`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\main_view.gd`
- Modify: `D:\Project\ProjectRest\project-rest\scripts\showcase_feedback_director.gd`
- Modify: `D:\Project\ProjectRest\project-rest\tests\showcase_preview_feedback_self_check.gd`

**Interfaces:**
- Consumes: all feedback events.
- Produces: capped, readable and non-overlapping visual feedback.

- [ ] **Step 1: Add event-rate assertions**

In `showcase_preview_feedback_self_check.gd`, assert no more than a fixed number of simultaneous floating texts are active after a dense sale or dense drop event. Use `max_active_showcase_feedback_events = 6` as the first cap.

- [ ] **Step 2: Run test**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_preview_feedback_self_check.gd
```

Expected: FAIL until feedback throttling exists.

- [ ] **Step 3: Add feedback priority and throttling**

In `ShowcaseFeedbackDirector`, sort by `tier` and keep:

- all tier 4 growth events
- all tier 3 set events up to 3
- tier 2 penalty events up to 2
- tier 1 adjacency or zone events only if no higher-tier event uses the same cells

- [ ] **Step 4: Add reduced-motion and compact feedback path**

Expose a boolean setting or constant for reduced motion. In reduced mode, replace movement effects with color/label state changes.

- [ ] **Step 5: Run final verification**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_preview_feedback_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/showcase_bonus_reason_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

Expected: all PASS.

---

## Final Acceptance Criteria

- 玩家拖拽商品时，不放下也能判断收益、冲突、套装机会、非法格原因和未解锁格扩展条件。
- 商品放下时，基础加成、套装成立、区域强化、冲突减损、成长解锁有不同层级反馈。
- 初始 `6x6` 橱窗默认态空间足够清晰；扩展到 `10x10` 满格后仍可读，选中商品后能展开详细关系。
- 售速加成能通过售卖进度和售出节奏感知。
- 每笔售出能解释基础售价、橱窗加成、成长加成、冲突扣减和最终收益。
- 产品成长与橱窗规则叠加，不替代相邻、套装、冲突和区域规则。
- UI 展示、售卖结算、tooltip、销售记录和成长触发来自同一个规则计算结果。
- 所有 Godot headless 验证都使用 writable `--log-file`。

## Implementation Order

1. 先做 Task 1 和 Task 2，保证规则源统一。
2. 再做 Task 3 到 Task 5，让摆放体验成型。
3. 再做 Task 6 和 Task 7，让营业与结算有体感。
4. 再做 Task 8，让长期成长接上完整闭环。
5. 最后做 Task 9 和 Task 10，扩展后期策略并控制表现噪音。

## Self-Review

- Spec coverage: 最终体验方案覆盖拖拽预判、放下反馈、常态可读、营业动态、售出归因和长期成长；实施任务覆盖规则、UI、结算、成长、扩展和验证。
- Placeholder scan: 本文不包含未定义占位字段；所有新增脚本、测试和命令都有明确路径。
- Type consistency: 计划中统一使用 `ShowcaseRuleEvaluator`, `ShowcasePreviewModel`, `ShowcaseFeedbackDirector`, `RecipeGrowthService.record_showcase_sale` 作为跨任务接口。
- Scope check: 这是完整最终版计划，建议按任务顺序分阶段合入，每个任务都有独立验证命令。
