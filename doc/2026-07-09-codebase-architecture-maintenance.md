# ProjectRest 代码架构与维护说明

生成日期：2026-07-09

本文基于当前 `D:\Project\ProjectRest\project-rest` 代码梳理，用于后续功能扩展、排查问题和维护交接。项目是 Godot 4.6 的单机经营 MVP，核心循环是“采购/自产原料 -> 研发或加工 -> 制作成品 -> 橱窗上架 -> 顾客购买 -> 任务/等级/配方成长推进”。

## 1. 项目入口与运行配置

入口配置在 `project.godot`：

- 主场景：`res://scenes/Main.tscn`
- 项目名：`project-rest`
- 目标特性：Godot 4.6、Mobile
- 视口：`1920x1080`
- 拉伸：`window/stretch/mode="canvas_items"`，`window/stretch/aspect="keep"`；动态字体按实际输出分辨率渲染，非 16:9 窗口保留黑边
- 渲染：mobile renderer，Windows 使用 D3D12
- autoload：仅 `_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"`

业务状态没有做成 autoload，而是在 `scripts/main_view.gd` 中通过：

- `state = SaveSystem.load_game(save_path, broken_save_path)`
- `var catalog := Catalog.new()`

来加载和持有。也就是说，当前实际的运行协调中心是 `Main.tscn + main_view.gd`。

## 2. 顶层目录职责

```text
project-rest/
  project.godot                         Godot 项目配置
  game_data.json                        解锁路线、任务文案等外部数据源
  scenes/                               主场景与 UI 分场景
  scripts/                              核心业务、状态、服务与主视图脚本
  scripts/ui/                           部分页/弹窗的薄组件脚本
  doc/                                  设计文档、数据配置、生成提示词、本文档
  docs/superpowers/                     开发过程中的规格与执行计划
  resources/recipe_icons/               配方图标资源与 Godot import 元数据
  tests/                                Godot headless 自检脚本和 Python 工具测试
  tools/                                辅助生成工具
  addons/godot_ai/                      Godot AI 插件，非核心游戏业务
```

维护时优先关注 `scenes/`、`scripts/`、`doc/`、`game_data.json`、`tests/`。`addons/godot_ai/` 是工具插件，除非问题明确出在 MCP/日志/测试环境，否则不要把游戏业务逻辑放进去。

## 3. 架构分层

### 3.1 配置与数据层

`scripts/catalog.gd` 是游戏静态内容的主入口，内部维护多组常量，并通过 getter 返回深拷贝：

- `INGREDIENTS`：食材、种子、幼畜、加工品、采购属性、产出来源、解锁等级、生产时长等。
- `PRODUCTION_SITES`：农场、养殖场、林地、水塘；包含 `base_slots`、`yield_amount`、`cost_rate`、可产出物列表。
- `TOOLS`：当前主要是产地加速器，和产地槽位兼容。
- `DEVICES`：研发/加工设备，如双手、圆锅、研磨机、搅拌台、烤箱、冷藏柜、煎烤盘。
- `RECIPES`：成品配方，包含设备、材料、售价、产出数量、解锁等级、标签。
- `PROCESSING_RECIPES`：中间加工配方，输入原料转为中间材料。
- `CUSTOMERS`：顾客偏好、预算、解锁等级。
- `UPGRADE_TABLE`：等级名、升级成本、展示槽、顾客数量、解锁提示。
- `PURCHASE_CATEGORIES`、生产槽/背包页扩展成本。

`catalog.gd` 还会读取两个 JSON 配置：

- `doc/recipe_display_config.json`：配方橱窗形状、格子占用、图标/展示相关配置。
- `doc/display_rules_full.json`：橱窗加成、套装、冲突、区域规则。读取失败时回退到 `catalog.gd` 内置 `DISPLAY_RULES`。

`game_data.json` 当前由 `TaskService` 读取，用来输出解锁路线摘要和任务阶段文案。注意：主线任务的可执行定义不完全来自 JSON，而是内置在 `scripts/task_service.gd`。

### 3.2 存档状态层

`scripts/game_state.gd` 定义 `class_name GameState`，是全部可变游戏状态的聚合根。主要字段包括：

- 资源：`coins`、`reputation`、`level/shop_level`
- 库存：`ingredient_inventory`、`product_inventory`、`tool_inventory`
- 解锁：`unlocked_tools`、`unlocked_devices`、`unlocked_recipes`、`ingredient_purchase_unlocks`、`ingredient_process_unlocks`
- 任务：`completed_tasks`、`task_progress`、`pending_notifications`
- 产出：`production_slots`、`production_slot_unlocks`、`production_bag_page_unlocks`
- 橱窗：兼容旧 `display_slots`，新逻辑主要使用 `display_items`
- 成长：`recipe_growth`
- 反馈/存档辅助：`feedback_log`、`business_runs`、`last_saved_at_unix`、`offline_ready_count`

`GameState` 的职责不是纯数据容器，它同时负责状态变更校验：

- 增删库存、工具、成品。
- 解锁设备、工具、配方、加工采购能力。
- 装备和卸下产地加速器。
- 橱窗自由摆放、上架库存、售出扣库存、形状与重叠校验。
- 记录配方制作/售卖成长。
- 触发任务事件和通知队列。
- 升级、序列化、反序列化和旧存档清洗。

设计含义：新增玩法状态时，先判断是否属于长期存档。如果要存档、要兼容旧数据、要被测试稳定读取，应放入 `GameState` 并同步 `to_dict()`、`from_dict()`、清洗函数和 `tests/mvp_self_check.gd`。

### 3.3 领域服务层

当前按玩法域拆了几个无状态或弱状态服务，基本都继承 `RefCounted` 并以 static 方法工作。

`scripts/production_site.gd`

- 负责产地槽位开始生产、成熟判定、收获、自动重启、下一轮队列、取消、槽位扩展、背包页扩展。
- 生产输入有两类：种子/幼畜类消耗库存，其他可产物按 `cost_rate` 消耗金币。
- 收获后会调用 `TutorialProgress.on_ingredient_harvested()` 推进任务。
- 加速器通过 `GameState.get_equipped_accelerator("%s:%d")` 读取，按工具的 `duration_multiplier` 缩短时长。

`scripts/recipe_book.gd`

- 负责研发成品、制作成品、加工中间材料。
- 研发逻辑按设备和材料组合匹配 `Catalog.RECIPES`，会处理材料不足、设备不匹配、等级不足、重复研发、差一材料提示等失败路径。
- 制作成品会消耗材料，增加 `product_inventory`，记录配方成长，并通过 `TutorialProgress.on_product_made()` 推进任务。
- 加工逻辑按 `PROCESSING_RECIPES` 精确匹配材料组合，输出到 `ingredient_inventory`，并解锁对应加工能力。

`scripts/shop_simulation.gd`

- 负责营业结算和顾客选择。
- 顾客池来自 `Catalog.CUSTOMERS` 和当前等级的 `customer_count`。
- 优先读取新橱窗结构 `state.display_items`，没有时兼容旧 `display_slots`。
- 每个顾客按偏好标签、预算、橱窗加成、配方成长加成计算最优购买项。
- 成功售出后增加金币和口碑，扣橱窗库存，记录销售明细、反馈、任务事件 `business_result`。
- 橱窗加成来源包括区域、相邻标签、套装、冲突惩罚、黄金 C 位倍率、配方成长。

`scripts/task_service.gd`

- 负责主线任务定义、事件匹配、任务进度、奖励发放、任务面板数据。
- `apply_event(state, event_name, payload)` 是任务推进入口。
- 支持事件类型包括 `harvest`、`make_product`、`display_product`、`research_success`、`business_result`。
- 奖励可以加金币、口碑、工具、食材、解锁工具/设备、直接设置等级。
- 完成任务后进入 `GameState.pending_notifications`，由主视图弹窗消费。

`scripts/tutorial_progress.gd`

- 是业务动作到任务事件的薄适配层。
- 例如收获 -> `harvest`，研发成功 -> `research_success`，制作 -> `make_product`，上架 -> `display_product`。
- 新增关键成长事件时，优先在这里建立统一入口，避免各业务服务直接拼散乱任务事件。

`scripts/recipe_growth_service.gd`

- 负责配方熟练度/成长阶段。
- 阶段：试作、稳定、人气、招牌。
- 阈值由制作数、售卖数、相邻触发次数决定。
- 成长会给价格/售速加成，并可解锁展示特性。

`scripts/save_system.gd`

- 负责 `user://neighbor_dessert_save.json` 的保存、读取、坏档备份和离线产出成熟提示。
- 保存采用 `目标.tmp -> 目标.previous -> 目标` 的替换流程，降低写坏存档的风险。
- 读取失败会把原始坏档写到 `.broken.json`，然后回到 `GameState.new_game()`。
- 读取存档后会调用 `ProductionSite.evaluate_slots()`，并计算离线期间成熟的产出数量。

### 3.4 UI 与交互层

主场景是 `scenes/Main.tscn`，根节点挂 `scripts/main_view.gd`。当前主视图仍是 UI 和业务编排的集中点。

主场景结构：

- `Root/TopBar`：金币、口碑、等级、任务/库存/图鉴入口。
- `Root/Body/MainArea/StorefrontPanel/ShowcasePanel`：左侧橱窗展示。
- `Root/Body/MainArea/WorkbenchPanel/ConsoleTabs`：采购、产出、研发制作、橱窗经营页签。
- `Root/Body/MainArea/WorkbenchPanel/ContentPanel`：页面标题、筛选/列表、操作按钮。
- `GlobalPopupBackdrop` + `GlobalOverlayLayer`：任务、库存、图鉴三类全局弹窗。
- `TaskPopup`：任务完成、升级、配方成长等通知弹窗。

`main_view.gd` 的职责：

- `_ready()`：加载存档、绑定按钮/菜单/分页/弹窗/拖放信号、初始化页面。
- `_process()`：每秒更新产出倒计时、处理橱窗自动销售、刷新状态。
- 页面刷新：`_refresh_purchase_page()`、`_refresh_output_page()`、`_refresh_research_page()`、`_refresh_storefront_manage_page()`。
- 用户动作：采购、产出开始/收获/取消/加速器、研发/加工、制作/批量制作、上架/批量上架、营业结算。
- 橱窗：10x10 视觉格、自由形状摆放、移动、旋转、预览、倒计时、自动售出、加成提示。
- 全局弹窗：任务、库存、图鉴切换、关闭、背景点击、顶部按钮重复点击切换。
- 持久化：多数动作后调用 `_save_game()`，再刷新页面和通知。

`scripts/ui/` 下的页面/弹窗脚本目前多为薄组件：

- `pages/output_page.gd` 可动态创建产地面板，但实际刷新仍由主视图驱动。
- `pages/research_craft_page.gd` 负责构造配方/加工行，但通过 `view.call(...)` 读取主视图辅助方法。
- `overlays/inventory_overlay.gd`、`overlays/catalog_overlay.gd` 会调用主视图方法填充格子。
- `ui/storefront/showcase_board.gd` 当前是信号和接口占位，主橱窗逻辑仍在 `main_view.gd`。

维护含义：后续如果继续组件化，应该逐步把“渲染某一页/某一弹窗”的代码迁到对应页面脚本，但状态变更仍通过 `GameState` 和领域服务完成。

## 4. 核心玩法流程

### 4.1 新游戏和存档加载

1. `Main._ready()`
2. `SaveSystem.load_game()`
3. 无存档时 `GameState.new_game()`
4. 有存档时 `GameState.from_dict()` 清洗并恢复状态
5. `SaveSystem._apply_offline_ready_state()` 标记离线成熟产出
6. 刷新采购页、资源栏、橱窗和通知弹窗

初始状态目前包括：金币 120、口碑 0、等级 0、`rice_seed: 6`、空设备解锁列表、10x10 橱窗存储结构。

### 4.2 产出流程

1. 玩家在产出页选择产地和物品。
2. `main_view.gd` 调用 `ProductionSite.start_slot(state, site_id, item_id, slot_index)`。
3. `ProductionSite` 检查产地、物品、等级、槽位、库存/金币。
4. 写入 `state.production_slots`，包含开始时间、时长、成熟时间、加速器。
5. `_process()`/页面刷新调用 `ProductionSite.evaluate_slots()` 或倒计时辅助函数。
6. 玩家收获时调用 `ProductionSite.harvest_slot()`。
7. 收获物进入 `ingredient_inventory`，触发 `TutorialProgress.on_ingredient_harvested()`。
8. 如果输入足够，槽位按当前或 queued item 自动进入下一轮；否则移除并记录失败日志。

### 4.3 研发、加工、制作流程

研发：

1. 玩家选择设备和至少 2 个材料。
2. `RecipeBook.research()` 按设备和材料匹配 `Catalog.RECIPES`。
3. 校验材料库存、设备解锁、等级、是否重复研发。
4. 消耗配方材料，`state.add_recipe(recipe_id, true)`。
5. 增加口碑，触发 `TutorialProgress.on_recipe_unlocked()`。

加工：

1. 玩家选择设备和 1 个原料。
2. `RecipeBook.process_ingredient()` 精确匹配 `PROCESSING_RECIPES`。
3. 消耗原料，产出中间材料。
4. `state.unlock_ingredient_process(output_item_id)` 记录加工能力。

制作：

1. 玩家在研发制作页点击配方制作。
2. `RecipeBook.make_product(state, recipe_id, batches)` 校验已解锁和材料充足。
3. 消耗材料，增加成品库存。
4. `state.record_recipe_made()` 更新配方成长。
5. `TutorialProgress.on_product_made()` 推进任务。

### 4.4 橱窗上架与销售流程

1. 成品可以从研发页按钮、批量上架或库存拖放进入橱窗。
2. 主视图计算配方形状，调用 `state.list_display_item(recipe_id, cells, amount, sale_ready_at_unix, listed_at_unix)`。
3. `GameState` 校验配方已解锁、成品库存、形状格数、旋转形状、范围、重叠。
4. 上架成功后扣成品库存，写入 `display_items[recipe_id]`。
5. `_process()` 每秒检查橱窗倒计时，成熟后 `_sell_ready_showcase_slot()` 走营业/销售逻辑。
6. `ShopSimulation.run_business()` 或单品销售会扣橱窗库存、加金币口碑、记录销售反馈和任务事件。

当前橱窗有两套兼容结构：

- 新结构：`display_items`，按 `recipe_id` 存格子、库存、上架时间、售卖成熟时间。
- 旧结构：`display_slots`，按槽位存 recipe 或带数量的 dictionary。仍保留用于旧存档和旧逻辑兼容。

新增橱窗能力时，应优先扩展 `display_items` 路径，并确认旧结构是否还需要兼容。

### 4.5 任务和通知流程

1. 业务服务通过 `TutorialProgress` 或直接调用 `state.record_task_event(event_name, payload)`。
2. `GameState.record_task_event()` 委托 `TaskService.apply_event()`。
3. `TaskService` 按事件名、等级、前置任务、条件匹配任务。
4. 达成目标后 `_complete_task()`：
   - `state.complete_task(task_id)`
   - `_apply_reward()`
   - `state.enqueue_notification(title, body)`
   - 如等级提升，再追加升级通知
5. `main_view.gd` 的 `_show_next_notification()` 弹出 `TaskPopup`。

维护时注意：可见反馈是任务体验的一部分。新增任务事件时，需要同步任务定义、触发点、弹窗文案、状态栏反馈和自检。

## 5. 数据同步边界

### 5.1 新增食材

通常至少要改：

- `scripts/catalog.gd` 的 `INGREDIENTS`
- 对应产地的 `PRODUCTION_SITES[site_id].items`
- 如可采购，确认 `purchase_category` 和购买页筛选逻辑
- 如是加工产物，补 `PROCESSING_RECIPES`
- 如影响路线，更新 `game_data.json` 和相关 `doc/` 设计文档
- 如进主线，补 `TaskService` 条件或测试

### 5.2 新增配方

通常至少要改：

- `scripts/catalog.gd` 的 `RECIPES`
- `doc/recipe_display_config.json` 的形状、格子、图标配置
- 如要图标生成，更新/运行 `tools/generate_recipe_icon_prompts.py` 相关配置
- 如有橱窗规则影响，确认 `doc/display_rules_full.json`
- 如是路线关键配方，更新任务/路线文档和自检

### 5.3 新增设备或工具

设备：

- `Catalog.DEVICES`
- 配方或加工配方的 `device`
- `GameState` 初始解锁/任务奖励/等级解锁逻辑
- 研发页设备展示、可用状态、自检

工具：

- `Catalog.TOOLS`
- 购买页工具展示
- `GameState` 的工具库存和 `equip_accelerator()` 校验
- `ProductionSite.production_duration_seconds()` 或相关使用逻辑

注意：当前项目约定 `TOOLS` 和 `DEVICES` 不应混用。设备用于研发/加工能力，工具用于购买、库存和产地加速等消耗/装备型能力。

### 5.4 新增任务或改主线

至少同步：

- `scripts/task_service.gd`：可执行任务定义、事件、条件、奖励、通知。
- `game_data.json`：路线摘要和玩家/文档层描述。
- `doc/2026-07-05-progressive-unlock-route-and-tasks.md` 或新的路线设计文档。
- 触发点：`TutorialProgress`、`RecipeBook`、`ProductionSite`、`ShopSimulation`、`main_view.gd`。
- `tests/mvp_self_check.gd` 或窄自检，如 `tests/task_mainline_self_check.gd`。

当前主线倾向使用通用行为门槛，例如制作、上架、售出、营业结果，而不是强绑定某个配方名。修改路线时要避免代码、JSON 和文档出现互相矛盾。

### 5.5 新增页面或弹窗

优先路径：

1. 在 `scenes/ui/pages/` 或 `scenes/ui/overlays/` 建 `.tscn`。
2. 写对应 `scripts/ui/...` 薄组件脚本，声明信号和必要渲染入口。
3. 在 `scenes/Main.tscn` 实例化。
4. 在 `main_view.gd` 绑定信号、刷新数据、保存状态。
5. 增加场景结构自检或页面自检。

当前项目偏好 `.tscn` 先承载布局，脚本负责绑定和行为。不要把大量布局节点临时堆在业务服务里。

## 6. 测试与验证

### 6.1 主要自检

`tests/mvp_self_check.gd` 是最全面的 headless gate，覆盖：

- catalog 数据完整性和引用合法性
- source model、生产、工具、设备、采购分类
- `GameState` 行为和存档序列化
- `TaskService` 主线行为
- `ProductionSite`、`RecipeBook`、`ShopSimulation`
- 完整 MVP 流程
- 主场景结构、拖放、橱窗、图鉴、库存、任务等 UI 关键路径

其他窄自检按页面/问题拆分，例如：

- `tests/task_mainline_self_check.gd`
- `tests/output_sites_self_check.gd`
- `tests/output_quadrant_self_check.gd`
- `tests/output_layout_self_check.gd`
- `tests/storefront_grid_layout_self_check.gd`
- `tests/showcase_bonus_reason_self_check.gd`
- `tests/right_console_experience_self_check.gd`
- `tests/console_tabs_purchase_drawer_self_check.gd`
- `tests/main_scene_split_shell_self_check.gd`
- `tests/component_contract_self_check.gd`
- `tests/ui_scaling_self_check.gd`

Python 工具测试：

- `tests/test_generate_recipe_icon_prompts.py` 验证提示词生成工具的配置解析、形状描述、输出等。

### 6.2 Codex 里运行 Godot headless 的命令

从包含 `project.godot` 的目录运行：

```powershell
cd D:\Project\ProjectRest\project-rest
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/mvp_self_check.gd
```

跑其他自检时只替换脚本路径：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/task_mainline_self_check.gd
```

不要使用 `--log-file NUL`。如果报 `File not found`，先确认 `res://tests/...` 文件存在，再排查业务逻辑。

## 7. 当前架构风险与维护建议

1. `main_view.gd` 过大，当前承担页面渲染、交互、拖放、业务调用、存档刷新、弹窗控制等职责。短期维护可以继续窄改；中期建议按页面逐步迁出渲染代码。

2. UI 组件脚本和主视图之间耦合较强，部分组件通过 `view.call("_xxx")` 反向调用主视图私有方法。继续组件化时，应把页面需要的数据组装成明确参数，减少字符串方法名调用。

3. 配置分散在 `catalog.gd`、`game_data.json`、`doc/*.json` 和 Markdown 设计文档。改内容模型时要同步源码、数据、文档和测试，不要只改其中一层。

4. 橱窗同时保留 `display_slots` 和 `display_items`。新功能应优先走 `display_items`，但存档读取和营业模拟仍需保留旧结构兼容判断，直到明确迁移完成。

5. 任务路线既有 `game_data.json` 的叙述层，也有 `TaskService` 的可执行定义。修改主线时要同时搜索旧文案和旧条件，避免玩家看到的目标和代码判定不一致。

6. 部分历史中文注释或字符串在 PowerShell 默认输出中会显示为乱码。这通常是控制台编码问题，不应直接判断文件损坏；读取/编辑中文文件时使用 UTF-8。

7. `addons/godot_ai` 是工具插件，可能被插件更新覆盖。涉及 headless 日志问题时，优先遵循根目录 `AGENTS.md` 的 `--log-file` 运行方式和 logger guard 说明。

## 8. 推荐扩展路线

### 短期：保持窄改和测试闭环

- 数据类改动：先改 `catalog.gd` 或 JSON，再补 `mvp_self_check.gd` 数据断言。
- UI 类改动：优先改 `.tscn`，脚本只做绑定和行为。
- 任务/路线改动：同步 `TaskService`、`game_data.json`、路线文档和任务自检。
- 橱窗改动：同步 `GameState.display_items`、`main_view.gd`、`ShopSimulation` 和橱窗自检。

### 中期：拆分主视图

建议按以下顺序迁出 `main_view.gd` 代码：

1. 采购页：购买列表、工具列表、补货推荐。
2. 产出页：产地面板、槽位格、背包页、上下文菜单。
3. 研发制作页：材料选择、设备选择、配方/加工行。
4. 橱窗：10x10 格、拖放、形状预览、倒计时。
5. 全局弹窗：任务、库存、图鉴。

迁出原则：页面脚本负责渲染和发信号；状态变更仍调用 `GameState` 和领域服务。

### 长期：数据外置和 schema 化

当配方、食材、展示规则继续扩张时，可以考虑：

- 将 `Catalog.RECIPES`、`INGREDIENTS`、`PRODUCTION_SITES` 拆成 JSON/TOML。
- 给配置加 schema/校验工具。
- 把 `mvp_self_check.gd` 中的数据一致性断言拆成更快的独立数据校验。
- 保留 Godot 自检覆盖真实 UI 和交互路径。

## 9. 维护速查

常见需求对应入口：

| 需求 | 首要文件 | 同步关注 |
| --- | --- | --- |
| 改食材/采购 | `scripts/catalog.gd` | 产地、购买页、任务、测试 |
| 改配方 | `scripts/catalog.gd` | 展示配置、图标、图鉴、测试 |
| 改产地生产 | `scripts/production_site.gd` | `GameState.production_slots`、产出页、自检 |
| 改研发/制作 | `scripts/recipe_book.gd` | `Catalog.RECIPES/PROCESSING_RECIPES`、任务事件 |
| 改橱窗摆放 | `GameState` + `main_view.gd` | `ShopSimulation`、展示配置、橱窗自检 |
| 改营业结算 | `scripts/shop_simulation.gd` | 顾客、标签、橱窗规则、任务事件 |
| 改主线任务 | `scripts/task_service.gd` | `game_data.json`、路线文档、任务自检 |
| 改存档 | `scripts/save_system.gd` + `GameState` | 版本兼容、坏档、离线成熟、自检 |
| 改全局弹窗 | `scenes/Main.tscn` + `main_view.gd` | overlay 脚本、关闭逻辑、交互自检 |
| 改图标提示词 | `tools/generate_recipe_icon_prompts.py` | `doc/recipe_icon_prompts.toml`、展示配置、Python 测试 |

每次改完后，至少按影响面选择一个窄自检；跨系统改动跑 `tests/mvp_self_check.gd`。
