# ProjectRest 开发者速查手册

生成日期：2026-07-10
前置阅读：[2026-07-09-codebase-architecture-maintenance.md](./2026-07-09-codebase-architecture-maintenance.md)

本文是**代码级**速查手册，侧重具体代码模式、数据结构形状、API 签名和修改步骤。架构概念和流程描述请先阅读架构维护文档。

---

## 1. 代码约定与架构模式

### 1.1 类组织模式

项目统一使用 `class_name` + `extends RefCounted` + `static func` 模式组织业务逻辑：

```gdscript
class_name ServiceName
extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const TutorialProgress = preload("res://scripts/tutorial_progress.gd")

static func do_something(state, ...) -> Dictionary:
    if state == null:
        return {"ok": false, "error": "..."}
    # 业务逻辑
    return {"ok": true, ...}
```

**所有领域服务**（`RecipeBook`, `ShopSimulation`, `ProductionSite`, `TaskService`, `ShowcaseRuleService`, `RecipeGrowthService`, `SaveSystem`）都遵循此模式：
- `extends RefCounted` — 无状态工具类
- `static func` — 无实例化开销
- 返回 `Dictionary` — 统一用 `{"ok": bool, ...}` 模式
- `state` 作为第一参数 — `GameState` 实例是所有状态变更的聚合根

### 1.2 返回值约定

成功返回：
```gdscript
return {"ok": true, "recipe_id": recipe_id, "message": "研发成功：..."}
```

失败返回：
```gdscript
return {"ok": false, "error": "库存不足，缺少：..."}
```

调用方检查模式：
```gdscript
var result := RecipeBook.research(state, device_id, materials)
if result.get("ok"):
    _save_game()
    _refresh_page()
```

### 1.3 Catalog 访问模式

`Catalog` 是可变实例（含 JSON 缓存），每次调用需 `new()`：

```gdscript
var catalog := Catalog.new()
var recipes: Dictionary = catalog.get_recipes()
var ingredients: Dictionary = catalog.get_ingredients()
var sites: Dictionary = catalog.get_production_sites()
var devices: Dictionary = catalog.get_devices()
var display_rules: Dictionary = catalog.get_display_rules()
```

**关键 getter 都返回深拷贝** — 修改返回值不影响原始数据。

### 1.4 UI 与业务通信模式

UI 脚本通过 `main_view.gd` 间接调用业务逻辑：

```gdscript
# 在 ui/pages/*.gd 中
func _on_button_pressed():
    view.call("_handle_research")  # 旧：字符串方法名调用
```

新代码**应避免** `view.call("_private_method")` 模式，改为：
- 页面脚本发出信号（signal）
- `main_view.gd` 连接信号并处理
- 或直接调用静态服务方法（如果不需要 UI 刷新）

### 1.5 任务事件触发模式

业务代码通过 `TutorialProgress` 薄适配层触发任务事件，不要直接拼装事件：

```gdscript
# ✅ 正确：通过 TutorialProgress
TutorialProgress.on_recipe_unlocked(state, recipe_id)
TutorialProgress.on_product_made(state, recipe_id, amount)
TutorialProgress.on_ingredient_harvested(state, item_id, amount, site_id)
TutorialProgress.on_product_displayed(state, recipe_id, amount)

# ❌ 避免：直接调用
state.record_task_event("research_success", {"recipe_id": recipe_id})
```

`TutorialProgress` 定义在 [tutorial_progress.gd](../scripts/tutorial_progress.gd)，只有约 50 行。

### 1.6 存档保存模式

```gdscript
static func save_game(state, path: String = SAVE_PATH) -> bool:
    # 写入 .tmp → 备份旧文件 → .tmp 重命名为目标
    var temp_path := path + ".tmp"
    # ... 写入 temp_path ...
    return _replace_file_with_temp(temp_path, path)
```

三文件轮换：`目标.tmp` → `目标.previous` → `目标`，降低写入中断损坏存档的风险。

存档路径：
- 正式存档：`user://neighbor_dessert_save.json`
- 坏档备份：`user://neighbor_dessert_save.broken.json`

### 1.7 无限店铺等级与升级入口

- Lv.0 第一次上架后自动进入 Lv.1；这是任务奖励唯一允许写 `set_level` 的地方。
- Lv.1 起由经营手册发出 `upgrade_requested` 信号，`main_view.gd` 调用 `GameState.upgrade()`。
- `Catalog.get_upgrade_definition(target_level)` 同时覆盖固定的 Lv.1–Lv.5 表和 Lv.6+ 公式，不要直接索引固定表处理高等级。
- `GameState.upgrade_eligibility()` 返回金币、累计口碑、差额和失败原因；升级只扣金币，不扣口碑。
- `GameState.from_dict()` 接受任意非负等级；不要重新加入 Lv.5 上限。

---

## 2. 关键数据结构速查

### 2.1 Catalog.INGREDIENTS 条目

```gdscript
{
    "id": "rice_seed",                    # String — 唯一标识
    "name": "水稻种子",                    # String — 显示名
    "type": "种子",                       # String — 分类（种子/农作/水果/乳制/肉禽/调味/风味...）
    "price": 1,                           # int — 采购价
    "unlock_level": 0,                    # int — 解锁等级
    "source": "采购",                     # String — 来源（采购/农场/养殖场/林场/水塘/研磨加工/发酵加工）
    "tags": ["农作"],                     # Array[String] — 标签
    "purchase_category": "农作",          # String — 采购页分类
    "mystery_name": "神秘的农作种子",      # String — 未解锁时显示名

    # 仅种子/幼畜/水引：
    "harvest_item_id": "rice",           # String — 收获产物 id
    "production_duration_seconds": 2,     # int — 生产时长（秒）

    # 仅幼畜（多产物）：
    "harvest_outputs": {"egg": 2, "chicken": 1},  # Dictionary[String, int]

    # 仅自产物：
    "purchasable": false,                # bool — 不可直接采购

    # 仅水引：
    "consumes_stock_for_production": true,  # bool — 扣库存

    # 可选：
    "production_duration_seconds": 28     # 部分农作/水果/加工品
}
```

**关键规则**：
- 种子类 id 以 `_seed` 结尾，harvest_item_id 指向同名收获物
- 幼畜 `harvest_outputs` 是多产物 key-value（不是数组）
- `purchasable: false` 表示必须通过生产获得

### 2.2 Catalog.PRODUCTION_SITES 条目

```gdscript
{
    "id": "farm",                        # String — "farm" | "ranch" | "forest" | "pond"
    "name": "农场",
    "unlock_level": 0,
    "enabled": true,
    "base_slots": 8,                     # int — 基础槽位数（2 页，每页 4 格）
    "cycles": 2,                         # int — 自动循环次数
    "yield_amount": 3,                   # int — 单次收获数量
    "cost_rate": 0.3,                    # float — 金币消耗倍率（非种子类）
    "items": ["rice_seed", "..."]        # Array[String] — 可生产物品列表
}
```

### 2.3 Catalog.DEVICES 条目

```gdscript
{
    "id": "round_pot",
    "name": "蒸煮一体的圆锅",
    "unlock_level": 999,                 # int — 999 = 不可自然解锁，靠任务/剧情
    "usage": "蒸煮米、水和温热甜品",
    "research_meaning": "蒸煮"           # String — 研发提示用简称
}
```

**当前设备解锁规则**：
- `round_pot` (level=999): Lv.0 自动拥有
- `grinder` (level=999): Lv.0 自动拥有
- `mixer`, `oven` (level=1): Lv.1 解锁
- `chiller` (level=2): Lv.2 解锁
- `griddle` (level=3): Lv.3 解锁

### 2.4 Catalog.RECIPES 条目

```gdscript
{
    "id": "rice_milk_drink",
    "name": "米浆饮",
    "device": "round_pot",               # String — 所需设备 id
    "materials": ["rice", "spring_water", "sugar"],  # Array[String] — 所需材料（2-4 个）
    "production_duration_seconds": 2,     # int — 必填，只允许 2 / 4 / 8
    "price": 12,                         # int — 基础售价
    "output_count": 3,                   # int — 单次制作产出数量
    "unlock_level": 0,                   # int — 解锁等级
    "tags": ["经典", "清爽"]              # Array[String] — 标签
}
```

### 2.5 Catalog.PROCESSING_RECIPES 条目

```gdscript
{
    "id": "rice_flour_from_rice",
    "name": "研磨大米粉",
    "device": "grinder",
    "materials": ["rice"],               # 加工配方只需 1 个原料
    "output": "rice_flour",              # String — 产物 id
    "output_count": 2,
    "unlock_level": 0
}
```

### 2.6 Catalog.TOOLS 条目

```gdscript
{
    "id": "farm_accelerator",
    "name": "农场加速器",
    "purchase_category": "工具",
    "price": 30,
    "compatible_site": "farm",           # String — 适配产地
    "duration_multiplier": 0.75,         # float — 时长倍率（<1 = 加速）
    "unlock_level": 1,
    "tool_kind": "accelerator"           # String — 工具类型
}
```

### 2.7 GameState 关键字段

```gdscript
# 资源
var coins: int = 120
var reputation: int = 0
var level: int = 0

# 库存（key=item_id, value=quantity）
var ingredient_inventory: Dictionary = {}   # {"rice_seed": 6, ...}
var product_inventory: Dictionary = {}      # {"rice_milk_drink": 3, ...}
var tool_inventory: Dictionary = {}         # {"farm_accelerator": 1, ...}

# 解锁
var unlocked_recipes: Array[String] = []
var unlocked_devices: Array[String] = []
var unlocked_tools: Array[String] = []
var ingredient_purchase_unlocks: Array[String] = []
var ingredient_process_unlocks: Array[String] = []

# 生产
var production_slots: Array = []             # 见 2.8
var equipped_accelerators: Dictionary = {}   # {"farm:0": "farm_accelerator", ...}

# 橱窗（新结构）
var display_items: Dictionary = {}           # 见 2.9
var display_props: Dictionary = {}
var showcase_theme_id: String = ""

# 橱窗（旧结构，兼容用）
var display_slots: Array = []

# 配方成长
var recipe_growth: Dictionary = {}           # 见 2.10

# 任务
var completed_tasks: Array[String] = []
var claimed_tasks: Array[String] = []
var task_progress: Dictionary = {}           # {"harvest": {"rice": 5}, ...}
var pending_notifications: Array[Dictionary] = []
```

### 2.8 production_slots 条目

```gdscript
{
    "site_id": "farm",                   # String
    "slot_index": 0,                     # int — 槽位编号
    "item_id": "rice_seed",              # String — 生产物品
    "started_at_unix": 1750000000,       # int
    "duration_seconds": 2,               # int
    "ready_at_unix": 1750000002,         # int
    "accelerator_id": ""                 # String — 装备的加速器 id，空=无
}
```

### 2.9 display_items 条目

```gdscript
# key: recipe_id (String)
# value: Dictionary
{
    "cells": [Vector2i(0, 0), Vector2i(1, 0)],  # Array[Vector2i] — 占用格坐标
    "stock": 3,                                   # int — 上架数量
    "listed_at_unix": 1750000000,                 # int — 上架时间
    "sale_ready_at_unix": 1750000010              # int — 可售时间
}
```

### 2.10 recipe_growth 条目

```gdscript
{
	"mastery_level": 0,                  # int — 0=试作, 1=稳定, 2=人气, 3=招牌
	"stage_made_batches": 0,             # int — 当前阶段真实完成批次
	"stage_effective_rounds": 0,         # int — 当前阶段有效营业轮次
	"stage_synergy_rounds": 0,           # int — 当前阶段协同营业轮次
	"made_count": 0,                     # int — 累计制作成品件数
    "sold_count": 0,                     # int — 累计售出次数
    "adjacency_trigger_count": 0,        # int — 相邻触发次数
    "display_traits": [],                # Array[String] — 展示特性
    "available_traits": [],              # Array[String] — 可选特性池
    "selected_traits": [],               # Array[String] — 已选特性
    "pending_trait_choice": false        # bool — 是否有待选特性
}
```

阶段阈值按当前阶段计数，所有条件必须同时满足：
| 当前阶段 → 下一阶段 | 真实完成批次 | 有效营业 | 协同营业 | 设备等级 |
|------|---:|---:|---:|---:|
| 试作品 → 人气款 | 30 | 10 | 3 | L3 |
| 人气款 → 招牌款 | 40 | 14 | 8 | L5 |

- 有效营业：普通或挑战营业正常完成结算，且该配方至少真实售出 1 件；零成交、取消和仅清仓不计。
- 协同营业：有效营业中至少发生 1 次正向邻接真实成交；同一配方每轮最多 `+1`。
- 晋级后当前阶段三个计数清零，不继承超额贡献；一次制作、结算或设备升级最多晋升一级。
- `made_count/sold_count/adjacency_trigger_count` 继续作为生涯统计和名作来源，不再作为三阶段硬门槛。

---

## 3. 领域服务 API 速查

### 3.1 RecipeBook

```gdscript
# 研发成品配方
static func research(state, device_id: String, material_ids: Array) -> Dictionary
# 返回: {"ok": true, "recipe_id": "...", "message": "..."}
# 失败: {"ok": false, "error": "...", "stage": "..."}

# 开始普通手动制作（立即扣材料，不立即增加 product_inventory）
static func make_product(state, recipe_id: String, batches: int, now_unix: int = -1) -> Dictionary
# batches 仅允许 1；返回: {"ok": true, "status": "started", "duration_seconds": N, ...}
# 到期结算统一走 GameState.complete_ready_manual_recipe_productions(now_unix)

# 加工中间材料
static func process_ingredient(state, device_id: String, material_id: String) -> Dictionary
# 返回: {"ok": true, "output_id": "...", "output_count": N}

# 获取配方失败信息（研发提示用）
static func research_failure_info(state, device_id: String, material_ids: Array) -> Dictionary
```

### 3.2 ProductionSite

```gdscript
# 开始生产
static func start_slot(state, site_id: String, item_id: String,
                        slot_index_or_now_unix: int = -1, now_unix: int = -1) -> bool

# 收获
static func harvest_slot(state, site_id: String, slot_index: int, now_unix: int = -1) -> Dictionary
# 返回: {"ok": true, "item_id": "...", "amount": N}

# 检查成熟状态
static func evaluate_slots(state, now_unix: int = -1) -> void

# 取消生产
static func cancel_slot(state, site_id: String, slot_index: int) -> bool

# 获取生产时长（含加速器修正）
static func production_duration_seconds(state, site_id: String,
                                         item_id: String, slot_index: int) -> int

# 槽位管理
static func unlock_next_slot(state, site_id: String) -> bool
static func unlock_bag_page(state, site_id: String) -> bool
```

### 3.3 ShopSimulation

```gdscript
# 营业结算（全部上架商品）
static func run_business(state, rng_seed: int = -1) -> Dictionary
# 返回: {"ok": bool, "sold_count": int, "earned_coins": int,
#        "earned_reputation": int, "sales": Array, "feedback": Array,
#        "product_bonuses": Dictionary}

# 单个商品售出
static func sell_single(state, recipe_id: String) -> Dictionary
```

### 3.4 TaskService

```gdscript
# 任务事件推进（由 GameState.record_task_event 调用）
static func apply_event(state, event_name: String, payload: Dictionary) -> void

# 获取当前可见任务列表
static func get_visible_tasks(state) -> Array

# 获取主线任务摘要
static func mainline_summary() -> Array
```

### 3.5 ShowcaseRuleService

```gdscript
# 计算所有展出配方的完整加成
static func calculate(state, recipes: Dictionary, display_rules: Dictionary) -> Dictionary
# 返回: {"ok": true, "items": {recipe_id: {...}}, "summary": {...}}

# 获取品类定义
static func variant_definition(recipe_id: String, variant_id: String,
                                display_config: Dictionary) -> Dictionary
```

### 3.6 RecipeGrowthService

```gdscript
# 创建默认成长数据
static func default_growth(recipe_id: String) -> Dictionary

# 清洗并重新计算成长状态
static func sanitize_growth(recipe_id: String, raw_value: Variant,
                             recipe: Dictionary, display_config: Dictionary) -> Dictionary

# 获取当前阶段
static func get_mastery_level(growth: Dictionary) -> int

# 判断是否有正向相邻加成来源
static func has_positive_showcase_growth_source(product_bonus: Dictionary) -> bool
```

### 3.7 SaveSystem

```gdscript
static func save_game(state, path: String = SAVE_PATH) -> bool
static func load_game(path: String = SAVE_PATH, broken_path: String = "") -> GameState
```

### 3.8 TutorialProgress（事件触发入口）

```gdscript
static func on_ingredient_harvested(state, item_id: String, amount: int, site_id: String = "") -> void
static func on_recipe_unlocked(state, recipe_id: String) -> void
static func on_product_made(state, recipe_id: String, amount: int = 1) -> void
static func on_product_displayed(state, recipe_id: String, amount: int = 1) -> void
```

### 3.9 GameState 常用方法速查

```gdscript
# 库存操作
func has_ingredient(item_id: String, amount: int = 1) -> bool
func add_ingredient(item_id: String, amount: int) -> void
func remove_ingredient(item_id: String, amount: int) -> bool
func has_product(recipe_id: String, amount: int = 1) -> bool
func add_product(recipe_id: String, amount: int) -> void
func remove_product(recipe_id: String, amount: int) -> bool

# 配方
func is_recipe_unlocked(recipe_id: String) -> bool
func add_recipe(recipe_id: String, save_compatible: bool = false) -> bool

# 设备/工具
func is_device_unlocked(device_id: String) -> bool
func unlock_device(device_id: String) -> void

# 橱窗
func list_display_item(recipe_id: String, cells: Array, amount: int,
                        sale_ready_at_unix: int, listed_at_unix: int) -> bool
func remove_display_item_stock(recipe_id: String, amount: int) -> bool
func get_display_item(recipe_id: String) -> Dictionary

# 任务
func record_task_event(event_name: String, payload: Dictionary) -> void
func enqueue_notification(title: String, body: String) -> void

# 成长
func record_recipe_made(recipe_id: String, count: int = 1) -> void
func record_recipe_sold(recipe_id: String, count: int = 1,
                         adjacency_source: bool = false) -> void

# 序列化
func to_dict() -> Dictionary
static func from_dict(data: Dictionary) -> GameState

# 店铺升级
func upgrade_eligibility() -> Dictionary
func can_upgrade() -> bool
func upgrade() -> bool
```

---

## 4. 任务事件系统参考

### 4.1 事件类型与 payload

| event_name | 触发时机 | payload 字段 | 触发位置 |
|-----------|---------|-------------|---------|
| `harvest` | 收获原料 | `item_id`, `amount`, `site_id` | `TutorialProgress.on_ingredient_harvested()` |
| `make_product` | 制作队列完成（不是点击开始时） | `recipe_id`, `quantity` | `TutorialProgress.on_product_made()` |
| `display_product` | 上架橱窗 | `recipe_id`, `quantity` | `TutorialProgress.on_product_displayed()` |
| `research_success` | 研发成功 | `recipe_id`, `device_id` | `TutorialProgress.on_recipe_unlocked()` |
| `business_result` | 营业结算 | `earned_coins`, `sold_count`, `customer_pool`, `sales` | `ShopSimulation.run_business()` |

### 4.2 任务定义结构

```gdscript
{
    "id": "tutorial_l0_gather",          # String — 唯一 id
    "name": "初次收获",
    "sort_order": 1,
    "event_name": "harvest",             # String — 匹配事件
    "condition": {
        "item_id": "rice",               # 条件：指定物品
        "min_count": 1                   # 条件：数量阈值
    },
    "reward": {
        "coins": 50,
        "reputation": 5,
        "unlock_devices": ["round_pot"]  # 可选奖励类型
    },
    "notification": {
        "title": "任务完成",
        "body": "收获了大米！"
    }
}
```

### 4.3 奖励类型

| 字段 | 类型 | 示例 |
|------|------|------|
| `coins` | int | `100` |
| `reputation` | int | `10` |
| `ingredients` | Dictionary | `{"rice_seed": 5}` |
| `tools` | Dictionary | `{"farm_accelerator": 1}` |
| `unlock_devices` | Array[String] | `["mixer", "oven"]` |
| `unlock_tools` | Array[String] | `["farm_accelerator"]` |
| `set_level` | int | `1` — 仅限 Lv.0 第一次上架自动进入 Lv.1；后续任务禁止使用 |

---

## 5. 常见修改步骤

### 5.1 新增食材

1. **[catalog.gd](../scripts/catalog.gd)** `INGREDIENTS`：添加条目，确定 `id/name/type/price/unlock_level/source/tags/purchase_category`
2. **如果是种子类**：添加对应收获物条目，设 `purchasable: false`
3. **如果是幼畜类**：设 `harvest_outputs` 映射
4. **对应产地**：在 `PRODUCTION_SITES[site_id].items` 中添加
5. **如果是可采购的**：确认 `purchase_category` 匹配现有分类
6. **如果有加工配方**：在 `PROCESSING_RECIPES` 中添加
7. **[tests/mvp_self_check.gd](../tests/mvp_self_check.gd)**：添加数据完整性断言

### 5.2 新增配方

1. **[catalog.gd](../scripts/catalog.gd)** `RECIPES`：添加条目
2. **[doc/recipe_display_config.json](../doc/recipe_display_config.json)**：添加形状/格子/图标配置
3. **图标**：如需要，更新 `tools/generate_recipe_icon_prompts.py` 配置并运行
4. **[doc/display_rules_full.json](../doc/display_rules_full.json)**：如需橱窗规则影响
5. **任务/路线**：如果是路线关键配方，更新 `TaskService` 和路线文档
6. **[tests/mvp_self_check.gd](../tests/mvp_self_check.gd)**：添加配方数据断言

### 5.3 新增设备

1. **[catalog.gd](../scripts/catalog.gd)** `DEVICES`：添加条目
2. **关联配方**：在 `RECIPES` 中使用此设备 id
3. **解锁逻辑**：在 `GameState` 初始状态或 `TaskService` 奖励中处理
4. **研发页 UI**：确保 `research_craft_page.gd` 中设备列表正确展示
5. **[tests/mvp_self_check.gd](../tests/mvp_self_check.gd)**：添加设备引用合法性断言

### 5.4 新增任务事件

1. **[game_data.json](../game_data.json)**：在 `tasks` 的对应分类中添加唯一任务定义
2. **[task_catalog_service.gd](../scripts/task_catalog_service.gd)**：如引入新字段，补充目录校验规则
3. **[task_service.gd](../scripts/task_service.gd)**：仅在引入新事件或特殊进度语义时扩展事件消费逻辑
4. **业务代码调用点**：从真实交互路径记录任务事件；营业构筑任务统一消费完整营业报告
5. **通知文案**：在任务定义中写好 `notification_title` 和 `notification_body`
6. **测试**：在目录、条件或对应路线 self-check 中添加行为断言

### 5.5 新增橱窗规则

1. **[doc/display_rules_full.json](../doc/display_rules_full.json)**：添加 adjacency/set/conflict/zone 规则
2. **[shop_simulation.gd](../scripts/shop_simulation.gd)**：如果规则计算逻辑需要调整，修改 `_calculate_all_product_bonuses()`
3. **[showcase_rule_service.gd](../scripts/showcase_rule_service.gd)**：如果规则影响 price/speed 上限，调整 `MAX_PRICE_MULTIPLIER`/`MAX_SPEED_MULTIPLIER`
4. **[tests/showcase_bonus_reason_self_check.gd](../tests/showcase_bonus_reason_self_check.gd)**：添加新规则效果断言

### 5.6 新增 UI 页面/弹窗

1. **[scenes/ui/](../scenes/ui/)**：创建 `.tscn` 场景文件
2. **[scripts/ui/](../scripts/ui/)**：创建对应脚本，声明信号
3. **[scenes/Main.tscn](../scenes/Main.tscn)**：实例化新场景
4. **[scripts/main_view.gd](../scripts/main_view.gd)**：绑定信号、添加刷新/数据处理逻辑
5. **[tests/](../tests/)**：添加场景结构或 UI 交互自检

---

## 6. 自检脚本索引

| 脚本 | 覆盖范围 |
|------|---------|
| `mvp_self_check.gd` | **主门控** — 全系统数据+行为+流程+UI 关键路径 |
| `infinite_shop_level_self_check.gd` | 无限等级公式、金币/口碑扣除规则、高等级存档回环 |
| `progression_catalog_self_check.gd` | 设备、食材、养殖投入品和 166 配方分级契约 |
| `business_handbook_upgrade_self_check.gd` | 营业手册升级条件、差额、里程碑和按钮结构 |
| `task_mainline_self_check.gd` | 主线任务 Lv.0-Lv.3 行为 |
| `output_sites_self_check.gd` | 产地面板逻辑 |
| `output_quadrant_self_check.gd` | 产出象限选择 UI |
| `output_layout_self_check.gd` | 产出页布局 |
| `storefront_grid_layout_self_check.gd` | 橱窗 10×10 布局 |
| `showcase_bonus_reason_self_check.gd` | 橱窗加成计算 |
| `right_console_experience_self_check.gd` | 右侧控制台交互 |
| `console_tabs_purchase_drawer_self_check.gd` | 采购抽屉 UI |
| `main_scene_split_shell_self_check.gd` | 主场景结构完整性 |
| `component_contract_self_check.gd` | 组件接口契约 |
| `ui_scaling_self_check.gd` | UI 缩放适配 |
| `layout_refinement_self_check.gd` | 布局精调 |
| `purchase_cart_self_check.gd` | 购物车逻辑 |
| `recipe_unlock_notification_self_check.gd` | 配方解锁通知 |
| `showcase_drag_preview_perf_self_check.gd` | 橱窗拖放预览性能 |

**运行命令**：
```powershell
cd D:\Project\ProjectRest\project-rest
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/mvp_self_check.gd
```

---

## 7. 当前代码质量标记

### 7.1 已知技术债

| 问题 | 影响范围 | 建议 |
|------|---------|------|
| `main_view.gd` 过大 | UI 维护困难 | 按页面逐步迁出渲染代码 |
| `view.call("_xxx")` 反向调用 | UI 组件无法独立测试 | 改为信号或明确参数接口 |
| `display_slots` + `display_items` 双结构 | 橱窗逻辑分散 | 新功能只走 display_items，确认迁移完成后移除旧结构 |
| 配置分散在 .gd / .json / .md | 改内容需多文件同步 | 维护时优先查本文档的数据同步清单 |
| 45 个 tag 无 display rule 覆盖 | 部分标签不影响玩法 | 见 `recipe_data_audit.md`，按需补规则 |

### 7.2 安全修改路径

按架构层级，改动风险从低到高：

1. **数据新增**（最低风险）：在 `catalog.gd` 末尾加条目，不加逻辑
2. **数据修改**（低风险）：改现有条目字段值，需同步测试断言
3. **UI 调整**（中风险）：改 `.tscn` 布局或页面脚本，需跑对应 self_check
4. **服务逻辑修改**（较高风险）：改 `RecipeBook`/`ShopSimulation`/`ProductionSite` 核心方法，需跑 `mvp_self_check`
5. **GameState 结构调整**（高风险）：改序列化/反序列化，需兼容旧存档 + 完整自检
6. **存档格式变更**（最高风险）：改 `to_dict()`/`from_dict()` 结构，需版本号 + 清洗逻辑 + 坏档回退

---

## 8. 相关文档索引

| 文档 | 用途 |
|------|------|
| [v3.md](./v3.md) | MVP 完整设计（系统规格、数值表） |
| [v3-expanded-variety.md](./v3-expanded-variety.md) | 36→36 配方扩展设计 |
| [2026-07-03-neighbor-dessert-mvp.md](./2026-07-03-neighbor-dessert-mvp.md) | MVP 任务清单与验证 |
| [2026-07-05-lv0-onboarding-production-line.md](./2026-07-05-lv0-onboarding-production-line.md) | Lv.0 新手引导产线设计 |
| [2026-07-05-progressive-unlock-route-and-tasks.md](./2026-07-05-progressive-unlock-route-and-tasks.md) | Lv.0-Lv.5 密集解锁与 Lv.6+ 持续经营路线 |
| [2026-07-13-device-unlock-pacing-design.zh.md](../docs/superpowers/specs/2026-07-13-device-unlock-pacing-design.zh.md) | 无限等级、设备、食材与配方完整现行规格 |
| [2026-07-09-post-mvp-task-completion-plan.md](./2026-07-09-post-mvp-task-completion-plan.md) | Post-MVP P0-P6 计划与进度 |
| [2026-07-09-codebase-architecture-maintenance.md](./2026-07-09-codebase-architecture-maintenance.md) | 架构分层、流程、维护说明 |
| [recipe_data_audit.md](./recipe_data_audit.md) | 166 配方数据审计报告 |
| [橱窗配方布局设计.md](./橱窗配方布局设计.md) | 橱窗形状与布局设计 |
| [任务图鉴库存推荐方案.md](./任务图鉴库存推荐方案.md) | GlobalOverlayLayer 迁移方案 |
| [解锁路线与任务系统设计.md](./解锁路线与任务系统设计.md) | 任务系统设计 |
| [AGENTS.md](../AGENTS.md) | 项目级 Agent 指令（headless 测试等） |

---

## 9. 设备培养与配方名作成长（2026-07-15）

设备与名作基础规格见[设备五级与配方名作成长设计](../docs/superpowers/specs/2026-07-15-device-recipe-masterwork-growth-design.zh.md)；当前三档配方规则以[三档配方成长设计](../docs/superpowers/specs/2026-07-22-three-stage-recipe-growth-design.zh.md)为准。

### 9.1 设备五级表

| 设备等级 | 累计有效使用 | 升级金币 | 配方阶段上限 | 培养效果 |
|---:|---:|---:|---|---|
| L1 | 0 | 0 | 试作品 | 基础研发线索 +1 |
| L2 | 10 | 120 | 试作品 | 接近失败时线索 +2 |
| L3 | 30 | 360 | 人气款 | 开放人气款培养 |
| L4 | 70 | 900 | 人气款 | 名作制作经验 +20% |
| L5 | 150 | 2200 | 招牌款 | 名作制作经验 +20%；显示满级铭牌 |

- 参与设备固定为 `round_pot/oven/chiller/griddle/mixer`；`grinder` 只加工，不参与成长。
- 有效使用只包括成功研发 `+1` 和成功完成的成品制作批次；商品产量、销售、失败研发与加工不计入。
- `GameState.device_growth` 每台保存 `level/use_count/research_count/production_batch_count`，读取时强制 `use_count = research_count + production_batch_count`。
- 设备升级只扣金币并生成一条汇总通知；已完成其他当前阶段条件的配方会立即检查晋级，每道配方最多晋升一级。
- L4/L5 的 `1.2` 倍不影响三阶段真实批次；人气款仍需实际完成 40 批才能晋升招牌款，只在招牌款开启名作后增加制作经验。

### 9.2 名作等级

- 配方达到招牌款并完成两次特性选择后开启名作 Lv.1，开启前事件不追溯。
- 内部经验使用十分之一单位：手动制作每批 `20/24`、自动化每批 `10/12`、每份真实售卖 `20`、正向邻接售卖每份额外 `10`；斜杠后为 L4+ 制作经验。
- Lv.1—Lv.10 阈值为 `0/20/50/90/140/200/275/365/470/600`；存档值对应 `0/200/.../6000`。
- Lv.3 银框、Lv.6 共享光效、Lv.10 金框/印章/称号均为荣誉展示，不进入售价、售速、产量或材料计算。

### 9.3 当前入口与聚焦测试

- 规则：`scripts/device_growth_service.gd`、`scripts/recipe_growth_service.gd`。
- 状态与事件：`scripts/game_state.gd`、`scripts/recipe_book.gd`。
- UI：研究页 `DeviceGrowthBar`、右侧 `DeviceGrowthDrawer`、图鉴 `RecipeGrowthDetailPanel`。
- 聚焦测试：`device_growth_self_check.gd`、`recipe_masterwork_growth_self_check.gd`、`device_recipe_growth_ui_self_check.gd`。

从 `D:\Project\ProjectRest\project-rest-new` 运行 Godot 自检时必须为每条命令提供可写的 `--log-file`。
