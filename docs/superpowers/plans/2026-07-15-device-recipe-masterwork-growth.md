# 设备五级与配方名作成长实施计划

> 说明：brainstorming 流程要求下一步使用 `writing-plans`，但当前会话没有提供该技能。本文件使用等价的详细任务、接口、测试和验证结构作为回退。设计来源：`docs/superpowers/specs/2026-07-15-device-recipe-masterwork-growth-design.zh.md`。

**目标：** 在 `project-rest-new` 现有四阶段、标签/形状候选特性和正向邻接成长上，加入五台成品设备的固定五级成长，以及招牌款完成两次特性选择后的名作 Lv.1—Lv.10。

**架构：** 新建纯规则 `DeviceGrowthService`；`GameState` 持久化设备成长并统一处理升级事务和结构化成功事件；`RecipeGrowthService` 保留现有特性生成职责并增加阶段上限、等待状态、L4 培养换算和名作等级规则。UI 使用紧凑设备栏、右侧详情抽屉和图鉴成长详情组件，稳定结构写在 `.tscn` 中。

**技术栈：** Godot 4.6.1、GDScript、JSON 存档、现有 `SceneTree` 自检脚本、Python 配方展示配置测试。

## 实施前约束

- 工作目录必须是 `D:\Project\ProjectRest\project-rest-new`，不得写入 `project-rest`。
- 当前工作树存在用户正在进行的配方成长展示配置和 `.uid` 变更；实现时只修改本计划列出的文件，不清理、不覆盖、不提交无关改动。
- 本计划本身不授权自动提交。只有用户明确要求时才创建功能提交。
- 保留 `mastery_level`、`made_count`、`sold_count`、`adjacency_trigger_count`、候选特性和已选特性的现有语义。
- 保留 166 道售卖配方及当前 `growth_variants`；不得修改配方售价、产量、材料或解锁等级。
- 不增加成品制作倒计时、产量、材料返还、售价、售速、采购优惠或四类经营专精。
- 不给 `grinder` 增加设备成长；`round_pot` 的酸奶加工也不计设备使用。
- 不增加“最多 3 个本店招牌”限制；全部 166 道配方都可以达到名作 Lv.10。
- 开发期不做旧存档补偿和追认；读取缺失字段只应用安全默认值。
- `docs/superpowers/specs/2026-07-14-project-rest-new-isolation-design.zh.md` 已说明旧 `mvp_self_check.gd` 可能保留过时的 149 配方或有限等级断言。不得为了让旧广域测试通过而恢复废弃业务语义；聚焦测试和当前 166 配方契约是阻断门，`mvp_self_check.gd` 只作为分类检查。
- 所有 Godot 无头命令必须传入可写的 `--log-file "$env:TEMP\<name>.log"`，不得使用 `NUL`。

## 当前运行入口

| 领域 | 当前入口 | 实施重点 |
|---|---|---|
| 设备目录 | `scripts/catalog.gd::DEVICES` | 显式标记五台成品设备可成长，研磨机不可成长 |
| 配方规则 | `scripts/recipe_growth_service.gd` | 保留四阶段和特性，增加设备上下文和名作规则 |
| 持久化 | `scripts/game_state.gd` | `device_growth`、升级事务、名作经验、只读状态视图 |
| 成功研发/手动制作 | `scripts/recipe_book.gd` | 传递设备、批次、产量和来源；L2 线索增量 |
| 自动化制作 | `scripts/game_state.gd::complete_recipe_production()`、`scripts/automation_service.gd` | 按队列中的真实批次和 `source` 记录 |
| 真实销售 | `scripts/game_state.gd::record_recipe_sold()` | 名作销售与正向邻接经验 |
| 研发制作 UI | `scenes/ui/pages/workbench_pages.tscn`、`scripts/main_view.gd` | 紧凑设备栏和抽屉入口 |
| 特性选择 | `scenes/ui/overlays/recipe_growth_choice_dialog.tscn` | 直接复用，不新增第二套选择弹窗 |
| 图鉴 | `scenes/ui/overlays/catalog_overlay.tscn`、`scripts/ui/overlays/catalog_overlay.gd`、`scripts/main_view.gd` | 设备筛选、成长详情和名作状态 |
| 图鉴卡片 | `scenes/ui/overlays/catalog_recipe_card.tscn` | 阶段徽标和名作里程碑外观 |
| 橱窗卡片 | `scenes/ui/storefront/showcase_slot.tscn`、`scripts/ui/storefront/showcase_slot.gd` | 共享名作外观，不增加独立图片资产 |

## Task 1：建立设备成长与名作的失败契约

**Files:**

- Create: `tests/device_growth_self_check.gd`
- Create: `tests/recipe_masterwork_growth_self_check.gd`
- Modify: `tests/progression_catalog_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`

- [ ] **Step 1：为设备目录写失败断言**

在 `progression_catalog_self_check.gd` 断言：

- `round_pot/oven/chiller/griddle/mixer` 显式声明成品设备成长；
- `grinder` 显式声明不参与；
- 参与集合恰好 5 台，不能通过“当前是否恰好有配方”隐式推导。

- [ ] **Step 2：创建设备规则自检骨架**

`device_growth_self_check.gd` 首先只加载待创建的 `res://scripts/device_growth_service.gd`，断言：

- 五级累计次数 `0/10/30/70/150`；
- 升级金币 `0/120/360/900/2200`；
- 阶段上限 `稳定/稳定/人气/人气/招牌`；
- L2 线索增量为 2；
- L4 培养倍率为 1.2；
- 五台总满级成本为 17,900，累计有效使用为 750；
- 研磨机查询返回不可成长，而不是伪造 L1。

- [ ] **Step 3：创建名作规则自检骨架**

`recipe_masterwork_growth_self_check.gd` 断言：

- 默认名作等级 0、经验 0；
- 两次特性选择完成并达到招牌后才变为 Lv.1；
- 阈值 `0/20/50/90/140/200/275/365/470/600`；
- Lv.10 经验在内部 6000 十分之一单位封顶；
- Lv.3/Lv.6/Lv.10 分别返回银框、光效、金框与名作印章里程碑。

- [ ] **Step 4：把新组件加入组件契约的预期列表**

提前为计划中的 `DeviceGrowthBar`、`DeviceGrowthDrawer`、`RecipeGrowthDetailPanel` 写场景、信号和方法预期，让测试先因场景不存在而失败。

- [ ] **Step 5：运行红灯测试**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-red.log" -s res://tests/device_growth_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\masterwork-growth-red.log" -s res://tests/recipe_masterwork_growth_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-catalog-red.log" -s res://tests/progression_catalog_self_check.gd
```

Expected: 因 `DeviceGrowthService`、名作字段和新 UI 组件不存在而失败；失败必须落在新增契约上。

## Task 2：实现设备规则、状态和升级事务

**Files:**

- Create: `scripts/device_growth_service.gd`
- Modify: `scripts/catalog.gd`
- Modify: `scripts/game_state.gd`
- Modify: `tests/device_growth_self_check.gd`

- [ ] **Step 1：实现纯规则 `DeviceGrowthService`**

提供单一五级表和以下最小接口：

```gdscript
static func supports_growth(device_id: String, devices: Dictionary) -> bool
static func default_state() -> Dictionary
static func sanitize_state(raw_value: Variant) -> Dictionary
static func level_definition(level: int) -> Dictionary
static func stage_cap(level: int) -> int
static func research_hint_increment(level: int) -> int
static func production_growth_multiplier(level: int) -> float
static func upgrade_quote(device_id: String, state: Dictionary, coins: int, unlocked: bool, devices: Dictionary) -> Dictionary
```

`upgrade_quote()` 返回当前等级、下一等级、累计次数要求、金币费用、两项缺口、当前/下一效果、是否可升级和稳定错误码。服务不读取或修改 `GameState`。

- [ ] **Step 2：在设备目录显式声明资格**

在 `Catalog.DEVICES` 为五台成品设备增加 `recipe_growth_enabled: true`，为研磨机增加 `false`。不得依赖配方数量运行时推断，以免未来内容变化静默改变存档规则。

- [ ] **Step 3：增加 `GameState.device_growth`**

每台已解锁成品设备保存：

```gdscript
{
    "level": 1,
    "use_count": 0,
    "research_count": 0,
    "production_batch_count": 0
}
```

实现：

```gdscript
func get_device_growth(device_id: String) -> Dictionary
func device_growth_quote(device_id: String) -> Dictionary
func upgrade_device_growth(device_id: String) -> Dictionary
```

未解锁设备返回稳定的 `locked` 视图但不创建可操作记录；`unlock_device()` 成功时为合法成品设备初始化 L1。研磨机始终返回 `unsupported`。

- [ ] **Step 4：保存、加载和清洗**

`new_game()` 初始化已解锁的成品设备；`from_dict()` 只保留合法设备、限制等级 1—5、累计数不小于 0，并强制：

```text
use_count = research_count + production_batch_count
```

`to_dict()` 写入 `device_growth`。缺失字段使用默认值，不编写旧开发存档追认或补偿。

- [ ] **Step 5：实现原子升级**

升级顺序：

1. 校验设备支持且已解锁；
2. 读取下一等级；
3. 同时计算使用次数和金币缺口；
4. 条件不足时返回全部缺口且不修改状态；
5. 条件满足时只扣金币、等级加一、累计数不变；
6. L5 再次升级返回 `max_level`。

不要在升级事务里遍历并改写 `recipe_growth`。

- [ ] **Step 6：运行设备状态测试**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-state.log" -s res://tests/device_growth_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-catalog.log" -s res://tests/progression_catalog_self_check.gd
```

Expected: 设备规则、单级升级、金币扣除、缺口、L5 和保存往返全部通过。

## Task 3：接通有效使用事件与 L2 研发线索

**Files:**

- Modify: `scripts/game_state.gd`
- Modify: `scripts/recipe_book.gd`
- Modify: `scripts/automation_service.gd`（只有现有完成入口无法传递来源时才修改）
- Modify: `tests/device_growth_self_check.gd`
- Modify: `tests/research_progressive_hints_self_check.gd`
- Modify: `tests/automation_settlement_self_check.gd`

- [ ] **Step 1：增加两个明确的设备成功事件**

在 `GameState` 实现：

```gdscript
func record_device_research_success(device_id: String) -> Dictionary
func record_device_production_batches(device_id: String, batches: int) -> Dictionary
```

两者原子更新 `use_count` 和对应明细字段。失败、0 批、研磨机、未解锁设备都不修改状态。

- [ ] **Step 2：成功研发后记录 1 次**

`RecipeBook.research()` 只在 `state.add_recipe(recipe_id, true)` 成功之后调用 `record_device_research_success(device_id)`。重复研发、材料不足、设备错误和接近失败都不计数。

- [ ] **Step 3：让 L2 控制线索增量**

将 `_upgrade_research_hint()` 改为接收本次选择的 `device_id` 或显式增量。`_fail_research_with_hint()` 从 `GameState.get_device_growth()` 和 `DeviceGrowthService.research_hint_increment()` 取得 1 或 2，最终仍夹在 0—3。

保持以下行为：

- L1 第一次接近失败到线索 1；
- L2 第一次接近失败直接到线索 2；
- L2 第二次最多到线索 3；
- 材料仍只消耗一次；
- 失败不给设备使用次数；
- 研磨机始终使用基础增量 1。

- [ ] **Step 4：制作接口显式区分批次和产量**

把现有接口向后兼容地扩展为：

```gdscript
func record_recipe_made(recipe_id: String, output_amount: int, batches: int = 1, source: String = "manual") -> Dictionary
```

`made_count` 继续增加 `output_amount`；设备使用增加 `batches`。`RecipeBook.make_product()` 传入手动来源和真实批次。

`record_recipe_made()` 是制作成功后的唯一公共写入口：它在同一次事务中更新配方产量，并且仅调用一次内部的 `record_device_production_batches()`。任何调用方都不得在调用 `record_recipe_made()` 后再次单独累计设备批次。

- [ ] **Step 5：自动化完成传递真实来源**

`complete_recipe_production()` 从队列项读取 `batches` 和 `source`，然后只调用一次 `record_recipe_made(recipe_id, output_amount, batches, source)`：

- `record_recipe_made()` 同时记录商品产量与真实完成批次；
- `record_device_production_batches()` 只作为 `record_recipe_made()` 的内部委托，不由完成队列再次调用；
- `source` 保留 `manual/automation`，供名作经验使用；
- 离线不完成的队列不能提前计数。

不要让 `RecipeBook.process_ingredient()` 调用任何设备成长事件；`制作全部` 自然按每个成功的成品批次累计，处理配方不计。

- [ ] **Step 6：运行事件测试**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-events.log" -s res://tests/device_growth_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-hints.log" -s res://tests/research_progressive_hints_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-automation.log" -s res://tests/automation_settlement_self_check.gd
```

Expected: 1 批/5 批、产量较高配方、成功/失败研发、加工和自动化来源全部计数正确。

## Task 4：加入设备阶段上限、等待状态和 L4 换算

**Files:**

- Modify: `scripts/recipe_growth_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `tests/device_growth_self_check.gd`
- Modify: `tests/recipe_masterwork_growth_self_check.gd`
- Modify: `tests/recipe_growth_choice_scene_self_check.gd`

- [ ] **Step 1：拆开“自然资格”和“实际阶段”**

在 `RecipeGrowthService` 增加纯函数：

```gdscript
static func natural_mastery_level(growth: Dictionary, device_level: int) -> int
static func capped_mastery_level(natural_level: int, device_level: int) -> int
static func effective_signature_made_count(actual_made_count: int, device_level: int) -> int
static func growth_status(growth: Dictionary, device_context: Dictionary) -> Dictionary
```

规则：

- 稳定款仍要求实际制作 5、售卖 3；
- 人气款仍要求实际制作 15、售卖 10；
- 只有招牌款制作条件在 L4+ 使用 `floor(made_count × 1.2)`；
- 招牌仍完整要求售卖 25、正向邻接 10；
- L1/L2、L3/L4、L5 的上限分别为稳定、人气、招牌；
- 已达到阶段永不降低。

- [ ] **Step 2：让读取保持只读**

当前 `get_recipe_growth()` 会调用 `_update_recipe_growth()`，这会导致设备升级后仅打开图鉴就偷偷晋升。改为：

- `get_recipe_growth()` 只确保记录存在并返回副本，不因读取推进阶段；
- `recipe_growth_status(recipe_id)` 返回动态设备缺口、自然资格、阶段上限、有效制作贡献和下一条件；
- UI 统一读取 `recipe_growth_status()`，派生字段不写回存档。

- [ ] **Step 3：只在正确事件中释放设备门槛**

设备升级不修改配方。对于升级前已经满足条件、只等待设备的配方：

- 查询状态不晋升；
- 后续单纯打开页面不晋升；
- 设备升级后的售卖事件不用于释放已经存在的设备等待；
- 下一次手动或自动化成功制作允许释放门槛并晋升。

同时保留现有正常成长：如果一次售卖或正向邻接事件本身刚好补齐了自然条件，而且设备在事件发生前已经满足上限，则仍可由该事件晋升。

实现时在更新前后比较“自然资格”，并把 `trigger` 和 `natural_level_before_event` 传给阶段更新，避免新增持久化的 `pending_device` 布尔值。

- [ ] **Step 4：保留候选特性和待选择状态**

设备上限只能限制 `mastery_level`，不能清空 `available_traits`、`selected_traits` 或 `pending_trait_choice`。一次事件跨越多个自然阶段时仍由当前候选生成规则得出最终候选池，已选合法特性保留。

- [ ] **Step 5：设备升级只产生汇总**

`upgrade_device_growth()` 成功后通过只读 `growth_status()` 统计等待该设备的已解锁配方数量，通知只写：

> 烤箱已升至 L3，人气款培养已开放。3 道配方将在下次制作后晋升。

不得逐配方调用 `_update_recipe_growth()` 或逐个入队通知。

- [ ] **Step 6：运行阶段测试**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-stage-cap.log" -s res://tests/device_growth_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-stage-masterwork.log" -s res://tests/recipe_masterwork_growth_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\growth-choice-regression.log" -s res://tests/recipe_growth_choice_scene_self_check.gd
```

Expected: 33/34 换算、设备等待、只读查询、售卖不释放旧门槛、下一次制作晋升和候选特性保留全部通过。

## Task 5：实现名作开启、经验和十级荣誉

**Files:**

- Modify: `scripts/recipe_growth_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `tests/recipe_masterwork_growth_self_check.gd`
- Modify: `tests/automation_settlement_self_check.gd`
- Modify: `tests/showcase_live_listing_self_check.gd`

- [ ] **Step 1：扩展配方成长默认值和清洗**

增加：

```gdscript
"masterwork_level": 0,
"masterwork_xp_tenths": 0
```

清洗规则：

- 等级夹在 0—10；
- 未开启时经验强制为 0；
- 已开启时等级由经验阈值重新计算，但最低为 1；
- 经验夹在 0—6000；
- 不修改现有四阶段和特性字段。

- [ ] **Step 2：实现名作纯规则**

在 `RecipeGrowthService` 增加：

```gdscript
static func can_activate_masterwork(growth: Dictionary) -> bool
static func masterwork_level_for_xp_tenths(xp_tenths: int) -> int
static func masterwork_next_threshold(level: int) -> int
static func masterwork_milestone(level: int) -> Dictionary
static func masterwork_title(recipe_name: String, level: int) -> String
```

开启必须同时满足招牌款和 `selected_traits.size() >= 2`。

- [ ] **Step 3：通过统一入口尝试开启名作**

新增内部 `_try_activate_masterwork()`，在阶段更新完成后和 `select_recipe_trait()` 合法写入并重新计算候选后调用。这样无论“先成为招牌款、后选择第二个特性”还是未来数据修复形成相反顺序，都只有一个开启判断入口。

如果首次满足开启条件：

- 写入 `masterwork_level = 1`；
- 写入 `masterwork_xp_tenths = 0`；
- 发送一条“名作培养已开启”通知；
- 不追溯此前制作、销售或邻接。

达到招牌但尚未选择完特性时保持等级 0。

- [ ] **Step 4：制作和销售事件增加经验**

只有事件发生前已经开启名作才增加经验：

| 来源 | 基础十分之一经验 | L4+ |
|---|---:|---:|
| 手动制作每批 | 20 | 24 |
| 自动化制作每批 | 10 | 12 |
| 真实售卖每份 | 20 | 20 |
| 正向邻接售卖每份 | 额外 10 | 额外 10 |

一次销售 `amount = N` 且 `positive_adjacency = true` 时增加 `N × 30`，但 `adjacency_trigger_count` 继续按现有事件语义只增加 1 次，不能混淆两者。

- [ ] **Step 5：升级与通知合并**

经验事件后计算最终等级。如果一次批量事件跨过多个阈值：

- 最终等级可以直接更新；
- 只发送一条“名作提升至 Lv.X”通知；
- Lv.10 后经验固定 6000，不再产生升级通知或经济效果。

- [ ] **Step 6：验证无追溯和来源差异**

测试：

- 招牌未选完特性时制作和销售均为 0 经验；
- 第二次选择只开启，不补发；
- 开启后的手动、自动化、销售、邻接增量准确；
- L4 只增强制作经验；
- 一次正向邻接销售 3 份增加 90；
- Lv.10 封顶、标题和里程碑正确。

- [ ] **Step 7：运行名作测试**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\masterwork-xp.log" -s res://tests/recipe_masterwork_growth_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\masterwork-automation.log" -s res://tests/automation_settlement_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\masterwork-live-sales.log" -s res://tests/showcase_live_listing_self_check.gd
```

Expected: 开启门槛、十分之一计数、来源差异、批量销售、通知合并和封顶全部通过。

## Task 6：构建设备紧凑栏与右侧详情抽屉

**Files:**

- Create: `scenes/ui/pages/device_growth_bar.tscn`
- Create: `scripts/ui/pages/device_growth_bar.gd`
- Create: `scenes/ui/overlays/device_growth_drawer.tscn`
- Create: `scripts/ui/overlays/device_growth_drawer.gd`
- Modify: `scenes/ui/pages/workbench_pages.tscn`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Create: `tests/device_recipe_growth_ui_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`

- [ ] **Step 1：先写场景结构红灯测试**

`device_recipe_growth_ui_self_check.gd` 断言：

- `workbench_pages.tscn` 在 `ResearchInputBar` 与 `ResearchHintPanel` 之间实例化 `DeviceGrowthBar`；
- Main 场景实例化右侧 `DeviceGrowthDrawer`；
- 进度、当前等级、主要缺口、详情按钮、升级按钮、关闭按钮和“查看关联配方”按钮都在 `.tscn` 中；
- 研磨机说明节点存在；
- 脚本只刷新节点和发信号，不动态拼装稳定控件树。

- [ ] **Step 2：实现 `DeviceGrowthBar`**

接口：

```gdscript
signal details_requested(device_id: String)
func refresh(state, catalog, device_id: String) -> void
```

正常设备显示名称、Lx、`use_count/next_required`、进度条和可升级标记。研磨机显示“加工设备，不参与成品设备成长”，隐藏进度和升级状态。

- [ ] **Step 3：实现右侧抽屉**

`DeviceGrowthDrawer` 使用右侧锚定 `PanelContainer`，不使用临时状态文字冒充抽屉。接口：

```gdscript
signal close_requested()
signal upgrade_requested(device_id: String)
signal catalog_filter_requested(device_id: String)
func show_device(state, catalog, device_id: String, recipe_summary: Dictionary) -> void
func refresh(state, catalog, recipe_summary: Dictionary) -> void
```

抽屉显示当前/下一效果、两项准确缺口、关联阶段数量、等待数量和满级荣誉明细。研磨机不打开可升级抽屉。

- [ ] **Step 4：接入主场景和研究页刷新**

`main_view.gd`：

- 监听当前 `selected_research_tool_id`；
- `_refresh_research_page()` 后刷新设备栏；
- 设备栏点击打开抽屉；
- 升级按钮调用 `state.upgrade_device_growth()`；
- 成功后保存、刷新金币和当前页、展示单条通知；
- 失败时在抽屉和状态栏同时显示全部缺口；
- 关闭后清理抽屉状态。

- [ ] **Step 5：验证场景和交互**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-ui.log" -s res://tests/device_recipe_growth_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-components.log" -s res://tests/component_contract_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-research-strip.log" -s res://tests/research_input_strip_self_check.gd
```

Expected: 设备栏不挤掉原材料槽，抽屉为真实场景结构，升级成功/失败和研磨机说明均可见。

## Task 7：扩展图鉴设备筛选、成长详情和特性入口

**Files:**

- Create: `scenes/ui/overlays/recipe_growth_detail_panel.tscn`
- Create: `scripts/ui/overlays/recipe_growth_detail_panel.gd`
- Modify: `scenes/ui/overlays/catalog_overlay.tscn`
- Modify: `scripts/ui/overlays/catalog_overlay.gd`
- Modify: `scenes/ui/overlays/catalog_recipe_card.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/device_recipe_growth_ui_self_check.gd`
- Modify: `tests/catalog_popup_size_self_check.gd`
- Modify: `tests/recipe_growth_choice_scene_self_check.gd`

- [ ] **Step 1：添加可见的设备筛选条**

在 `CatalogFilterTabs` 下增加稳定的 `CatalogDeviceFilterRow`，包含当前设备名和清除按钮。`main_view.gd` 新增 `selected_catalog_device_filter`，`_catalog_recipe_matches_filter()` 先检查设备，再检查现有甜点/饮品/水果/烘焙/新品标签。

从设备抽屉点击“查看关联配方”时：

1. 设置设备筛选；
2. 重置图鉴页码和选中项；
3. 打开现有 CatalogOverlay；
4. 在顶部清楚显示“设备：烤箱”；
5. 清除按钮恢复全部设备。

- [ ] **Step 2：图鉴卡片增加紧凑成长状态**

在 `catalog_recipe_card.tscn` 预置：

- `StageBadge`；
- `MasterworkBadge`；
- `WaitingDeviceIndicator`；
- 共享 `MilestoneFrame`/`MilestoneGlow` 节点。

`_make_catalog_cell()` 只绑定：阶段名、`名作 Lv.X` 或“名作未开启”、等待设备标记。材料、候选和精确进度继续放在 tooltip 或详情，不把卡片塞满。

- [ ] **Step 3：用真实详情组件替代长字符串成长区**

`recipe_growth_detail_panel.tscn` 预置：

- 四阶段轨道；
- 制作/有效制作、售卖、邻接进度行；
- 设备等级和等待原因；
- 已选/候选特性区；
- “选择成长特性”按钮；
- 名作锁定说明或经验条；
- 下一名作等级和里程碑说明。

接口：

```gdscript
signal trait_choice_requested(recipe_id: String)
func refresh(state, catalog, recipe_id: String) -> void
```

保留现有基础配方信息和组合关联文本，但不要继续把成长详情只藏在卡片 tooltip 的 `_recipe_growth_detail_text()` 中。

- [ ] **Step 4：复用现有特性选择弹窗**

图鉴详情的按钮调用现有 `_maybe_show_pending_recipe_growth_choice()` 的单配方版本；提取候选预估构建函数，避免 storefront 自动提示和图鉴按钮各复制一套 30 秒预计成交逻辑。继续使用现有 `RecipeGrowthChoiceDialog` 和“稍后选择”。

- [ ] **Step 5：验证布局和选择闭环**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-growth-ui.log" -s res://tests/device_recipe_growth_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-growth-choice.log" -s res://tests/recipe_growth_choice_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\recipe-growth-popup-size.log" -s res://tests/catalog_popup_size_self_check.gd
```

Expected: 设备筛选可见且可清除，图鉴卡片紧凑，详情完整，候选仍只选一次，弹窗尺寸无回归。

## Task 8：实现共享名作边框、光效、印章与称号

**Files:**

- Modify: `scenes/ui/overlays/catalog_recipe_card.tscn`
- Modify: `scenes/ui/storefront/showcase_slot.tscn`
- Modify: `scripts/ui/storefront/showcase_slot.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/device_recipe_growth_ui_self_check.gd`
- Modify: `tests/showcase_slot_visual_self_check.gd`

- [ ] **Step 1：只使用共享 UI 层**

不为 166 道配方生成新的名作图片。两种卡片场景预置共享外观层：

- Lv.3：银色边框；
- Lv.6：轻微共享光效；
- Lv.10：金色边框和名作印章。

低于里程碑时节点隐藏。光效必须克制，不能遮挡现有配方阶段图片和占格轮廓。

- [ ] **Step 2：扩展橱窗视图模型**

当前橱窗条目已经传递 `growth_level`。增加 `masterwork_level` 和 `masterwork_milestone`，由 `main_view.gd` 绑定到 `ShowcaseSlot`。营业规则、售价、售速和布局计算不得读取名作外观字段。

- [ ] **Step 3：显示 Lv.10 称号**

图鉴详情和橱窗 tooltip 使用 `RecipeGrowthService.masterwork_title()` 生成“配方名＋名匠”，不持久化重复称号文本。

- [ ] **Step 4：验证无经济影响**

测试同一配方在名作 Lv.1、3、6、10 时：

- 只有外观节点和文案变化；
- 售价、售速、产量、材料和橱窗 bonus breakdown 完全相同；
- 共享光效不新增每配方纹理加载。

- [ ] **Step 5：运行视觉契约测试**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\masterwork-card-visual.log" -s res://tests/device_recipe_growth_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\masterwork-showcase-visual.log" -s res://tests/showcase_slot_visual_self_check.gd
```

Expected: 三个里程碑外观和 Lv.10 称号正确，经济字段不变。

## Task 9：通知、文档同步与完整回归

**Files:**

- Modify: `doc/2026-07-10-developer-quick-reference.md`
- Modify: `doc/2026-07-09-post-mvp-task-completion-plan.md`
- Modify: `tests/device_growth_self_check.gd`
- Modify: `tests/recipe_masterwork_growth_self_check.gd`
- Modify: `tests/device_recipe_growth_ui_self_check.gd`
- Verify: `doc/recipe_display_config.json`
- Verify: `tests/test_recipe_growth_display_config.py`

- [ ] **Step 1：统一通知数据**

确认：

- 设备升级只入队一条汇总通知；
- 配方真正晋升时才发送现有配方通知；
- 一次经验事件最多发送一条名作升级通知；
- 第二次特性选择只发送一条名作开启通知；
- 通知 metadata 包含 `device_id` 或 `recipe_id`，便于 UI 刷新和测试。

- [ ] **Step 2：更新当前开发参考**

在开发参考中记录：

- 五台设备五级表；
- 有效使用定义；
- `device_growth` 和新增名作字段；
- 阶段上限与 L4 33/34 边界；
- 名作开启、经验、阈值和外观里程碑；
- 研磨机排除；
- 当前聚焦测试命令。

历史规格和已完成计划不重写，只在当前参考文档中指向新规格。

- [ ] **Step 3：运行聚焦回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-final.log" -s res://tests/device_growth_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\masterwork-growth-final.log" -s res://tests/recipe_masterwork_growth_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-growth-ui-final.log" -s res://tests/device_recipe_growth_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\growth-hints-final.log" -s res://tests/research_progressive_hints_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\growth-choice-final.log" -s res://tests/recipe_growth_choice_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\growth-automation-final.log" -s res://tests/automation_settlement_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\growth-live-sales-final.log" -s res://tests/showcase_live_listing_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\growth-components-final.log" -s res://tests/component_contract_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\growth-showcase-visual-final.log" -s res://tests/showcase_slot_visual_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\growth-catalog-final.log" -s res://tests/progression_catalog_self_check.gd
```

- [ ] **Step 4：验证 166 配方展示配置**

```powershell
python -m unittest tests.test_recipe_growth_display_config
```

Expected: 顶层 166 个配方、498 个成长差量配置和合法形状保持不变。

- [ ] **Step 5：运行项目解析和旧广域分类检查**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-masterwork-project.log" --quit
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\device-masterwork-mvp-classification.log" -s res://tests/mvp_self_check.gd
```

项目解析必须通过。若 `mvp_self_check.gd` 仍因已记录的 149 配方、有限等级或旧任务路线断言失败，应记录为旧契约漂移，不得恢复旧业务语义；若失败落在本功能修改的成长、保存或 UI 路径，则必须修复。

- [ ] **Step 6：检查工作树边界**

```powershell
git diff --check
git status --short
```

确认没有覆盖当前用户的 `doc/recipe_display_config.json`、配方展示配置计划、工具脚本或无关 `.uid` 文件。没有用户明确授权时不提交。

## 完成标准

- 五台成品设备按统一五级表独立升级，研磨机明确排除。
- 有效使用严格按成功研发和成功制作批次累计，不按商品产量、销售、失败研发或加工累计。
- L2 线索、L1/L3/L5 阶段上限、L4 33/34 边界全部有聚焦测试。
- 设备升级不批量晋升配方，读取状态不产生副作用，下一次成功制作才释放旧设备门槛。
- 现有四阶段、标签/形状候选、两次特性选择和正向邻接条件保持有效。
- 招牌且完成两次选择后从名作 Lv.1 开始，经验来源、十分之一计数、阈值和 Lv.10 封顶正确。
- 名作只改变共享荣誉外观和称号，不改变任何经济计算。
- 研发制作页采用紧凑栏＋右侧抽屉，图鉴提供可见设备筛选和完整成长详情。
- 166 配方展示配置、自动化、真实销售、橱窗槽位、任务和保存路径无功能回归。
- 所有稳定 UI 结构由 `.tscn` 持有，脚本只负责数据绑定、刷新和信号。
