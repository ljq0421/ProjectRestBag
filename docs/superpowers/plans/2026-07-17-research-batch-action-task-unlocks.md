# 研发制作批量按钮任务解锁实施计划

> 依据规格：`docs/superpowers/specs/2026-07-17-research-batch-action-task-unlocks-design.zh.md`

## 2026-07-17 一键补货条件调整

原计划中 `feature_restock_all` 与 `feature_make_all` 共用制作事件的设计已被新需求替代，以下增量计划优先于后文对应内容：

1. 将 `feature_restock_all` 改为订阅 `manual_restock_success`，目标仍为 10，文案改为“成功手动补货10次”。
2. 在单项补货确认购买返回成功后记录一次事件；取消、失败和页面级 `一键补货` 均不记录。
3. `manual_craft_success` 只继续推进 `feature_make_all`，制作与加工行为不再推进一键补货任务。
4. 不编写存档迁移；开发期旧存档由本次实施直接删除，使新任务从 0 开始。
5. 先修改 `tests/research_batch_unlock_self_check.gd` 与补货聚焦测试并确认 RED，再修改数据与运行时代码。
6. 两个工程分别运行补货、批量解锁、任务目录和解析验证，并检查本功能差异。

## 目标

在 `project-rest` 与 `project-rest-new` 中实现三个并行功能任务：

- 成功手动制作或加工 10 次，解锁 `一键补货`；
- 成功手动制作或加工 30 次，解锁 `制作全部`；
- 成功点击或拖拽上架 60 次，解锁 `上架全部`。

所有失败、批量和自动操作均不计数；未解锁按钮隐藏；任务完成后自动生效。

## 实施约束

- 两个工程保持相同任务 ID、事件名、功能 ID 和玩家可见文案；
- 保留当前脏工作区中与本功能无关的改动；
- 使用测试驱动开发，每个行为先写失败断言，再修改实现；
- 只在顶层成功手动交互处广播事件，不在共享底层函数中广播；
- 继续使用现有事件索引，不引入逐事件全任务扫描；
- Godot 无头验证必须通过 `--log-file` 写入 `D:\Project\ProjectRest\tmp`；
- 旧存档从 0 开始，不推算历史次数。

## Task 1：建立聚焦自检并确认 RED

**新增文件**

- `tests/research_batch_unlock_self_check.gd`

**步骤**

1. 在两个工程创建相同的聚焦自检。
2. 先固定任务目录契约：
   - 三个任务 ID 存在；
   - 两个制作任务订阅 `manual_craft_success`；
   - 上架任务订阅 `manual_list_success`；
   - 目标分别为 10、30、60；
   - 奖励分别解锁 `research_bulk_restock`、`research_make_all`、`research_list_all`。
3. 固定新游戏契约：
   - 三个功能均未解锁；
   - 研发制作页三个批量按钮隐藏；
   - 单项制作、加工、上架入口仍存在。
4. 固定并行进度契约：
   - 单个 `manual_craft_success` 同时推进两个制作任务；
   - 第 10 次只解锁一键补货，制作全部任务保持 10/30；
   - 第 30 次解锁制作全部；
   - 第 60 次 `manual_list_success` 解锁上架全部。
5. 固定无领取契约：
   - 三个任务不进入可领取列表；
   - 任务状态为已生效；
   - 每个解锁通知只出现一次。
6. 运行两个工程的聚焦测试，确认它们因缺少任务、事件和按钮门控而失败。

**验证命令**

从各自包含 `project.godot` 的目录运行：

`& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\research-batch-unlock-red.log" -s res://tests/research_batch_unlock_self_check.gd`

## Task 2：添加任务数据与功能解锁持久化

**修改文件**

- `game_data.json`
- `scripts/game_state.gd`
- `scripts/task_catalog_service.gd`（仅在奖励白名单仍需扩展时）
- `tests/research_batch_unlock_self_check.gd`
- `tests/task_mainline_self_check.gd`
- `tests/task_catalog_config_self_check.gd`（仅 `project-rest-new`）

**步骤**

1. 在两个目录体系各自的功能任务数据区添加三项任务定义。
2. 使用规格中的任务 ID、标题、目标、事件、排序、通知和 `unlock_features`。
3. 确认任务没有经济奖励，完成后自动标记奖励已生效。
4. 复用 `GameState.feature_unlocks`，不新增三个独立布尔字段。
5. 在 `from_dict` 中增加完成任务到功能 ID 的修复映射：
   - `feature_restock_all -> research_bulk_restock`；
   - `feature_make_all -> research_make_all`；
   - `feature_list_all -> research_list_all`。
6. 不根据库存、配方成长、制作记录或橱窗状态推算旧存档进度。
7. 扩充聚焦测试，验证保存往返和完成任务后的缺失解锁修复。
8. 运行任务目录与聚焦测试。

## Task 3：允许功能任务按事件并行推进

**修改文件**

- `scripts/task_service.gd`
- `tests/research_batch_unlock_self_check.gd`
- `tests/task_visibility_selection_self_check.gd`（仅 `project-rest-new`）
- `tests/harvest_all_unlock_self_check.gd`

**步骤**

1. 保留 `task_ids_for_event()` 作为唯一候选入口。
2. `project-rest`：
   - 现有 `apply_event` 已对事件候选逐项处理；
   - 只补充针对两个同事件功能任务同时推进的回归断言，不重写路由。
3. `project-rest-new`：
   - 在 `apply_event` 中让所有可用、未完成、订阅当前事件的 `feature` 任务可处理；
   - 不再用 `_current_feature_task_id` 排他过滤事件候选；
   - `get_side_tasks` 返回所有可用的未完成功能任务，并保持任务排序稳定；
   - 教程、成长、日常和合同任务继续使用原有路由规则。
4. 确认 `manual_craft_success` 的候选只有两个任务，`manual_list_success` 的候选只有一个任务。
5. 清理因并行化而失去调用者的单功能任务缓存或辅助函数，但不移除仍被其他界面使用的查询。
6. 验证 `feature_harvest_all` 仍正常累计、完成和显示。

## Task 4：记录成功的手动制作与加工

**修改文件**

- `scripts/main_view.gd`
- `tests/research_batch_unlock_self_check.gd`
- 可能复用 `tests/recipe_production_queue_self_check.gd` 或现有制作聚焦测试

**步骤**

1. 在 `_on_recipe_make_pressed` 中：
   - 先执行现有可制作检查；
   - 调用 `_make_recipe_product(recipe_id, 1)`；
   - 只有返回成功时发送一次 `manual_craft_success`；
   - 负载包含 `action_kind: recipe` 与 `recipe_id`。
2. 在 `_on_process_make_pressed` 中：
   - 使用 `_make_process_ingredient` 的布尔返回值；
   - 只有成功时发送一次 `manual_craft_success`；
   - 负载包含 `action_kind: processing` 与 `process_id`。
3. 不在 `_make_recipe_product`、`_make_process_ingredient`、`RecipeBook` 或生产队列完成函数中发送专用事件。
4. 用测试证明：
   - 成功进入队列立即 +1；
   - 队列完成不再次 +1；
   - 失败制作和失败加工不计；
   - `_make_all_available_products` 不计；
   - 自动和离线制作不计。
5. 运行聚焦测试和现有制作/自动化测试。

## Task 5：记录成功的手动点击与拖拽上架

**修改文件**

- `scripts/main_view.gd`
- `tests/research_batch_unlock_self_check.gd`
- 可能复用 `tests/showcase_*_self_check.gd` 与 `tests/business_day_*_self_check.gd`

**步骤**

1. 为每次顶层成功手动上架记录且只记录一次 `manual_list_success`。
2. `project-rest`：
   - `_on_recipe_list_pressed` 在 `_display_recipe_product` 返回成功后发送 `action_kind: button`；
   - `_drop_showcase_data` 在库存成品拖拽上架成功后发送 `action_kind: drag`；
   - 移动已上架商品不发送。
3. `project-rest-new`：
   - 处理 `_display_recipe_product` 复用 `_drop_showcase_data` 的调用关系；
   - 通过明确的交互来源元数据或单一事件发送点区分 `button` 与 `drag`；
   - 确保行按钮不会因嵌套调用被记录两次。
4. 事件负载携带 `recipe_id`，计数固定为 1，不使用实际上架数量。
5. `_list_all_available_products`、自动补货、经营结算、销售和库存移动不发送专用事件。
6. 用测试覆盖成功按钮、成功拖拽、失败按钮、失败拖拽、移动商品和上架全部。

## Task 6：隐藏按钮并保护直接入口

**修改文件**

- `scripts/main_view.gd`
- `tests/research_batch_unlock_self_check.gd`
- `tests/console_tabs_purchase_drawer_self_check.gd`
- `tests/layout_refinement_self_check.gd`
- `tests/right_console_experience_self_check.gd`
- `tests/research_recipe_restock_self_check.gd`
- `tests/mvp_self_check.gd`（仅修改与三个批量按钮直接相关的断言/夹具）

**步骤**

1. 在 `_refresh_research_page` 中分别依据三个功能 ID 设置按钮可见性。
2. 未解锁时不显示按钮，不使用禁用态冒充锁定态。
3. 已解锁的一键补货继续计算现有报价和禁用原因。
4. 在以下函数开头增加功能解锁守卫：
   - `_on_research_bulk_restock_pressed`；
   - `_make_all_available_products`；
   - `_list_all_available_products`。
5. 未解锁直接调用时：
   - 返回失败或不执行；
   - 显示对应任务名称和当前进度；
   - 不改变金币、库存、生产队列、橱窗或待确认补货状态。
6. 完成任务并刷新页面后，对应按钮立即出现；其他两个按钮仍按各自任务独立隐藏。
7. 更新原先假设新游戏三个按钮可见的测试。
8. 对测试中需要调用批量行为的夹具显式执行 `unlock_feature`，不要绕过运行时守卫。

## Task 7：通知、任务历史与旧存档行为

**修改文件**

- `scripts/task_service.gd`
- `scripts/game_state.gd`
- `scripts/main_view.gd` 或现有任务条目组件（仅当“已生效”显示仍缺口）
- `tests/research_batch_unlock_self_check.gd`

**步骤**

1. 验证三个任务完成后各自产生一次通知。
2. 验证继续发送事件时进度保持目标值，不重复通知。
3. 验证完成任务不进入可领取列表，历史状态显示 `已生效`。
4. 验证旧存档缺少新任务进度时三项均为 0，按钮隐藏。
5. 验证已完成任务但缺少功能标记时加载修复。
6. 验证部分完成进度与功能解锁在保存往返后保持一致。

## Task 8：完整回归与差异审查

**聚焦验证**

两个工程分别运行：

- `tests/research_batch_unlock_self_check.gd`
- `tests/harvest_all_unlock_self_check.gd`
- `tests/task_mainline_self_check.gd`
- `tests/automation_task_progress_self_check.gd`
- `tests/research_recipe_restock_self_check.gd`
- `tests/console_tabs_purchase_drawer_self_check.gd`
- `tests/layout_refinement_self_check.gd`
- `tests/right_console_experience_self_check.gd`
- `tests/output_layout_self_check.gd`

`project-rest-new` 额外运行：

- `tests/task_visibility_selection_self_check.gd`
- `tests/task_catalog_config_self_check.gd`

**解析与卫生**

1. 两个工程运行 `Godot --headless --path . --log-file <writable-path> --quit`。
2. 对本功能涉及的文件运行 `git diff --check`。
3. 检查两套任务 ID、事件名、功能 ID、阈值和通知文案一致。
4. 检查工作区差异，确认未修改或撤回无关用户改动。
5. 进行一次功能范围代码审查，重点检查：
   - 成功事件是否可能双发；
   - 批量或自动路径是否误计数；
   - `project-rest-new` 并行功能任务是否影响其他任务类型；
   - 隐藏按钮之外是否有直接入口守卫；
   - 完成任务后的通知与旧存档修复是否幂等。

## 完成标准

- 三个任务严格按 10、30、60 的成功手动操作累计；
- 两个制作任务从同一累计起点并行推进；
- 三个按钮未解锁时隐藏，解锁后正常工作；
- 所有失败、批量和自动路径均不增加进度；
- 存档、旧存档、任务历史和通知符合规格；
- 两套工程的聚焦与相关回归测试通过；
- 没有引入全任务扫描或无关工作区改动。
