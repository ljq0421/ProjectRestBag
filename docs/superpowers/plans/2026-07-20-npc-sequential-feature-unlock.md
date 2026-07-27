# NPC 顺序功能解锁实施计划

## 目标

落实已批准的 [`2026-07-20-npc-sequential-feature-unlock-design.zh.md`](../specs/2026-07-20-npc-sequential-feature-unlock-design.zh.md)：新存档从农场采购水稻种子开始，只有真实成功操作才能依次开放产出、库存、研发、制作、图鉴、上架、规则、橱窗调整、营业和橱窗经营；首轮有成交结算后由外婆最终对话升至 Lv.1并开放任务。采购与产出内部继续按等级逐批开放来源、产地和物品。

## 开始实施前的工作区约束

当前工作区已经存在与研发结果弹窗有关的未提交修改：

- `scenes/ui/overlays/research_progress_dialog.tscn`
- `scripts/main_view.gd`
- `scripts/ui/overlays/research_progress_dialog.gd`
- `tests/research_wait_dialog_self_check.gd`

实施者必须先检查这些差异并原样保留。`scripts/main_view.gd` 与本功能重叠，所有修改都应基于当前工作树增量应用；不得 reset、checkout 或覆盖用户已有改动。

每个阶段遵循 RED → GREEN：先建立能准确失败的聚焦自检，再写最小生产代码，最后运行相邻回归。不要等全部代码完成后一次性补测试。

## 阶段 1：建立核心解锁状态与服务

### 文件

- 新增 `scripts/core_feature_unlock_service.gd`
- 修改 `scripts/game_state.gd`
- 新增 `tests/core_feature_unlock_state_self_check.gd`

### 失败自检

先覆盖：

- 新状态只开放 `purchase`。
- `output` 依赖 `purchase`，`research` 依赖 `output`，其余主线按规格顺序形成前置闭包。
- `inventory` 与 `output` 同批开放，`catalog` 与 `craft` 同批开放。
- `task` 与 `starlight` 默认锁定。
- 解锁重复调用无副作用、不重复返回新增 ID。
- `core_unlock_progress` 能保存和恢复拖动、旋转、经营页访问与有成交结算证据。
- 后续功能存在而前置缺失时，加载修复只补开、不反向关闭。
- 新状态初始库存为 10 份泉水，不含 `spring_water_starter`。

先运行该自检，确认当前项目因缺少服务和字段而失败。

### 实现

在 `CoreFeatureUnlockService` 中集中定义：

- 核心功能 ID。
- 主线顺序与前置关系。
- `is_unlocked()`、`unlock()`、`unlock_many()`。
- `locked_reason()`。
- 前置闭包与业务证据修复。
- 新存档种子状态。

在 `GameState` 中新增并持久化：

- `core_feature_unlocks`。
- `core_unlock_progress`。
- 查询、开放和修复的薄封装。

初始状态只写入 `purchase`；不要把现有 `feature_unlocks` 与核心账本混用，现有字典继续保存一键收获、批量制作等熟练度功能。

### GREEN 验证

- `core_feature_unlock_state_self_check.gd`
- `showcase_unlocked_cells_state_self_check.gd`
- `harvest_all_unlock_self_check.gd`
- `research_batch_unlock_self_check.gd`

## 阶段 2：实现采购区域、产地与物品的等级门禁

### 文件

- 修改 `scripts/catalog.gd`
- 修改 `scripts/main_view.gd`
- 修改 `scripts/ui/pages/purchase_category_panel.gd`
- 修改 `scenes/ui/pages/purchase_category_panel.tscn`
- 修改 `scripts/ui/pages/output_page.gd`
- 修改 `scripts/ui/pages/output_site_region.gd`
- 修改 `scenes/ui/pages/output_site_region.tscn`
- 新增 `tests/progression_source_unlock_self_check.gd`
- 更新 `tests/console_tabs_purchase_drawer_self_check.gd`
- 更新 `tests/output_sites_self_check.gd`

### 失败自检

覆盖：

- 采购六区始终存在且顺序不变。
- Lv.0 只有农场区域可操作，只有水稻种子可加入购物车。
- 养殖场、水塘、辅料、工具在 Lv.1 开放。
- 林场在 Lv.2 开放。
- Lv.0 产出页只有农场可操作；其他三个产地保留锁定占位。
- 养殖场与水塘在 Lv.1 开放，林场在 Lv.2 开放。
- 来源已开但物品等级不足时，行仍可见并使用 `mystery_name` 与 `Lv.X 开放`。
- 锁定区域和物品不能修改购物车、产出槽、金币或库存。

### 实现

在目录数据中增加明确的采购区域开放等级，并把 `PRODUCTION_SITES` 改为：

- `farm = 0`
- `ranch = 1`
- `pond = 1`
- `forest = 2`

采购候选生成拆分为“用于可见预告的候选”和“真正可购买候选”。打开区域后再使用单项 `unlock_level` 与现有动态采购开放规则决定可操作性。

产出区域组件增加锁定展示接口。锁定区域不创建可操作产出格，不允许拖放或上下文操作；解锁后继续使用现有槽位、背包页和自动化逻辑。

### GREEN 验证

- `progression_source_unlock_self_check.gd`
- `console_tabs_purchase_drawer_self_check.gd`
- `purchase_cart_self_check.gd`
- `output_sites_self_check.gd`
- `output_layout_self_check.gd`
- `output_production_band_self_check.gd`

## 阶段 3：建立统一可点击锁定控件契约

### 文件

- 修改 `scripts/ui/navigation/workbench_launcher.gd`
- 修改 `scenes/ui/navigation/workbench_launcher.tscn`
- 修改 `scripts/ui/storefront/showcase_board.gd`
- 修改 `scenes/ui/storefront/showcase_board.tscn`
- 修改 `scripts/main_view.gd`
- 新增 `tests/core_feature_lock_ui_self_check.gd`
- 更新 `tests/workbench_purchase_overlay_self_check.gd`
- 更新 `tests/workbench_output_overlay_self_check.gd`
- 更新 `tests/workbench_storefront_overlay_self_check.gd`

### 失败自检

覆盖底部任务、库存、图鉴、产出、星辉、橱窗经营和橱窗顶部规则、营业按钮：

- 未开放时名称与位置保留。
- 显示统一锁标记与锁定主题。
- 锁定项仍能接收点击并返回准确原因。
- 点击锁定项不打开目标页、不修改状态。
- 开放后原位移除锁，不改变布局几何。
- 当前主线的下一锁定项可以请求重新显示外婆提示。

### 实现

扩展 `WorkbenchLauncher.set_entry_enabled()` 为明确的 `set_entry_locked(button_name, locked, reason)` 契约，或新增同等职责接口。不要仅设置原生 `disabled`，否则点击反馈无法触发。

在主视图建立统一门禁 helper：

1. 查询 `core_feature_unlocks`。
2. 锁定时显示原因并可请求恢复当前外婆说明。
3. 开放时才执行原入口处理器。

规则与营业按钮使用同一门禁语义，但保留营业中、待结算、无商品等现有业务禁用原因；“功能未开放”优先于运行期禁用原因显示。

### GREEN 验证

- `core_feature_lock_ui_self_check.gd`
- 三项 `workbench_*_overlay_self_check.gd`
- `showcase_rulebook_scene_self_check.gd`
- `showcase_round_ui_self_check.gd`
- `layout_refinement_self_check.gd`

## 阶段 4：接入采购、收获、研发、制作与上架的真实成功事件

### 文件

- 修改 `scripts/main_view.gd`
- 修改 `scripts/tutorial_progress.gd`
- 修改 `scripts/game_state.gd`
- 新增 `tests/core_feature_unlock_route_self_check.gd`
- 更新 `tests/tutorial_guide_route_self_check.gd`
- 更新 `tests/tutorial_guide_dynamic_target_self_check.gd`
- 更新 `tests/recipe_unlock_notification_self_check.gd`

### 失败自检

逐一验证正反路径：

- 成功购买水稻种子开放 `output` 与 `inventory`；购买其他物品、购物车编辑或结算失败不开放。
- 成功手动收获大米开放 `research` 并直接开放圆锅；自动、一键、离线、失败或其他收获不开放。
- 成功研发米浆饮开放 `craft` 与 `catalog`；研发失败、其他配方或仅打开研发页不开放。
- 米浆饮制作完成并入库后开放 `list`；点击制作、排队中或取消不开放。
- 米浆饮成功上架后开放 `rulebook`；失败拖放、补货或其他 UI 刷新不开放。

### 实现

在现有业务成功返回点调用核心解锁服务。调用顺序固定为：业务状态成功 → 里程碑/解锁 → 保存 → UI 与通知。

取消圆锅对已删除教学任务 objective effect 的依赖。手动收获大米成功时由核心解锁路径调用 `state.unlock_device("round_pot")`，并与研发入口开放合并通知。

制作解锁点必须接在配方队列完成和成品入库路径，不接在 `_on_*craft_pressed` 等请求入口。

### GREEN 验证

- `core_feature_unlock_route_self_check.gd`
- `tutorial_guide_route_self_check.gd`
- `tutorial_guide_dynamic_target_self_check.gd`
- `recipe_production_timing_self_check.gd`
- `recipe_unlock_notification_self_check.gd`
- `showcase_live_listing_self_check.gd`

## 阶段 5：锁定研发、制作与上架工作台内部功能

### 文件

- 修改 `scripts/main_view.gd`
- 修改 `scripts/ui/pages/research_craft_page.gd`
- 修改 `scenes/ui/pages/research_craft_page.tscn`
- 修改工作台现有相关组件测试
- 新增 `tests/research_craft_core_lock_self_check.gd`

### 失败自检

覆盖：

- `research` 未开放时工作台显示整页锁层，研究材料、工具和动作不可操作。
- `research` 开放且 `craft` 未开放时，仅研发输入可操作。
- `craft` 开放且 `list` 未开放时，制作可操作，上架按钮/拖拽源保持锁定。
- `list` 开放后恢复现有单项上架和拖拽上架。
- 锁定原因精确，页面刷新和动态重建不绕过门禁。
- 现有一键补货、制作全部、上架全部仍由各自 `feature_unlocks` 控制，不与核心锁混淆。

### 实现

稳定锁层、锁图标和说明节点优先放在 `.tscn`；脚本只绑定状态、原因和输入拦截。保留当前研发结果弹窗相关未提交修改，不重排或覆盖其代码路径。

### GREEN 验证

- `research_craft_core_lock_self_check.gd`
- `research_input_strip_self_check.gd`
- `research_wait_dialog_self_check.gd`
- `research_progressive_hints_self_check.gd`
- `research_batch_unlock_self_check.gd`
- `component_contract_self_check.gd`

## 阶段 6：接入规则、调整、营业、经营页与有成交结算

### 文件

- 修改 `scripts/main_view.gd`
- 修改 `scripts/tutorial_progress.gd`
- 修改 `scripts/tutorial_dialogue_catalog.gd`
- 更新 `tests/tutorial_guide_state_self_check.gd`
- 更新 `tests/tutorial_dialogue_catalog_self_check.gd`
- 新增 `tests/onboarding_settlement_completion_self_check.gd`
- 更新 `tests/showcase_business_round_scene_self_check.gd`
- 更新 `tests/showcase_round_settlement_dialog_self_check.gd`

### 失败自检

覆盖：

- 只有橱窗顶部 `RulebookButton` 成功打开规则后开放 `arrange`。
- “查看全部规则”不开放 `arrange`。
- 米浆饮真实拖动、旋转各一次后才开放 `business`，顺序不限且进度可保存。
- 开始营业失败不开放 `storefront_manage`；成功创建运行中营业轮才开放。
- 打开橱窗经营后从 `storefront` 进入新增 `settlement`，不直接完成。
- 零成交结算留在 `settlement`，不升级、不开放任务。
- `counts.sold >= 1` 的真实结算进入 `complete`。

### 实现

在 `TutorialProgress.STEPS` 中插入 `settlement`。新增外婆等待成交、零成交重试和最终任务开放台词。

在 `_confirm_showcase_round_settlement()` 成功形成 `round_report` 后，先让核心解锁服务记录结算证据，再决定是否进入最终对话。任务事件在此阶段仍被总闸拒绝，不能让首轮教学结算提前累计后续成长任务。

### GREEN 验证

- `onboarding_settlement_completion_self_check.gd`
- `tutorial_guide_state_self_check.gd`
- `tutorial_dialogue_catalog_self_check.gd`
- `tutorial_guide_route_self_check.gd`
- `showcase_business_round_scene_self_check.gd`
- `showcase_round_settlement_dialog_self_check.gd`
- `showcase_round_persistence_self_check.gd`

## 阶段 7：改写“我自己来”与最终确认

### 文件

- 修改 `scripts/tutorial_progress.gd`
- 修改 `scripts/ui/overlays/tutorial_guide_overlay.gd`
- 修改 `scenes/ui/overlays/tutorial_guide_overlay.tscn`
- 修改 `scripts/main_view.gd`
- 修改 `scripts/game_state.gd`
- 更新全部 `tutorial_guide_*_self_check.gd`

### 失败自检

覆盖：

- 按钮文案为“我自己来”。
- 点击后只持久化当前阶段提示停止状态，不修改引导步骤和核心解锁。
- 保存加载同阶段不重新主动展开。
- 真实操作推进后，下一阶段外婆重新主动展开。
- 点击下一项锁定入口可以清除当前提示停止状态并重新显示说明。
- `complete` 最终确认要求有成交结算证据。
- 最终确认执行 `level = max(level, 1)` 并开放 `task`，不增加金币或星辉。
- 重复确认与重播引导不重复产生副作用。

### 实现

移除现有 `skip_current_step()` 的逐步跳转语义，改为保存 `tutorial_guide_dismissed_step` 或同等单一字段。普通对话确认仍进入行动阶段；“我自己来”隐藏本阶段对话与箭头。

最终确认先验证 `core_unlock_progress` 中的有成交结算里程碑，再原子写入：

- 教学完成。
- `task` 开放。
- 店铺至少 Lv.1。

之后保存、刷新 Lv.1 内容并显示一条合并通知。

### GREEN 验证

- `tutorial_guide_state_self_check.gd`
- `tutorial_guide_overlay_self_check.gd`
- `tutorial_guide_route_self_check.gd`
- `tutorial_guide_popup_self_check.gd`
- `tutorial_guide_dynamic_target_self_check.gd`

## 阶段 8：删除三个教学任务并设置任务总闸

### 文件

- 修改 `game_data.json`
- 修改 `scripts/task_service.gd`
- 修改 `scripts/game_state.gd`
- 修改 `scripts/main_view.gd`
- 更新任务相关自检

### 数据变更

删除：

- `tutorial_l0_first_product`
- `tutorial_l0_open_shop`
- `tutorial_l0_first_business`
- `tutorial_l0_first_business` 的 2 星辉映射
- `growth_l1_sales_rhythm` 对旧教学任务的前置引用

让 `growth_l1_sales_rhythm` 通过 Lv.1 与 `task` 核心开放状态成为第一项成长任务。

### 失败自检

先改写或替换以下旧契约：

- `task_catalog_config_self_check.gd`
- `task_mainline_self_check.gd`
- `task_objective_progress_self_check.gd`
- `task_visibility_selection_self_check.gd`
- `task_level_claim_timing_self_check.gd`
- `showcase_task_l0_route_self_check.gd`
- `showcase_task_growth_route_self_check.gd`
- `showcase_task_overlay_self_check.gd`
- `task_bulk_claim_self_check.gd`
- `daily_task_self_check.gd`
- `task_shop_upgrade_self_check.gd`

原有教学任务专用自检应删除或改名为核心新手主线自检，不能只删断言而丢失对应覆盖。

新增断言：

- `task` 未开放时 `record_task_event()` 不累计成长、每日或功能任务。
- 任务入口、列表、角标、通知和领取 UI 均保持锁定/空状态。
- 最终确认开放任务后才初始化当日任务并开始记录事件。
- 第一项成长任务是 `growth_l1_sales_rhythm`。
- 教学期的首轮营业报告不会倒算到该成长任务。

### 实现

任务事件总闸必须位于状态/任务服务边界，不能只隐藏 UI。核心解锁服务继续直接接收业务成功事件，因此任务总闸不会阻止外婆主线推进。

清理 `main_view.gd` 中 `tutorial_l0_open_shop` 完成通知等运行时特殊分支，并把需要保留的玩家反馈迁移到核心解锁通知。

### GREEN 验证

- 上述全部任务自检
- `automation_task_progress_self_check.gd`
- `showcase_task_end_to_end_self_check.gd`
- `showcase_task_feedback_ui_self_check.gd`

## 阶段 9：首次星辉开放入口

### 文件

- 修改 `scripts/game_state.gd`
- 修改 `scripts/main_view.gd`
- 更新星辉与自动化相关自检
- 新增 `tests/starlight_entry_unlock_self_check.gd`

### 失败自检与实现

覆盖并实现：

- 教学最终确认后 `recipe_starlight_total == 0`，星辉入口保持锁定。
- `claim_starlight_reward()` 第一次真正增加总星辉时开放 `starlight` 并保存。
- 重复领取失败、花费星辉或余额降到 0 不会重新锁定入口。
- 旧存档已有累计星辉时加载补开入口。
- 星辉入口开放不等于自动化模块开放；现有自动化条件继续有效。

### GREEN 验证

- `starlight_entry_unlock_self_check.gd`
- `automation_task_progress_self_check.gd`
- 自动化与星辉奖励现有聚焦自检

## 阶段 10：旧存档重建与完整恢复

### 文件

- 修改 `scripts/game_state.gd`
- 扩展 `tests/core_feature_unlock_state_self_check.gd`
- 新增 `tests/core_feature_unlock_migration_self_check.gd`

### 失败自检

构造缺少新字段的旧存档并覆盖：

- 已研发米浆饮。
- 已有成品库存。
- 已有橱窗商品。
- 营业中、待结算、历史营业记录。
- 已完成或领取旧教学任务。
- 店铺等级不低于 Lv.1。
- 已有累计星辉。
- 中间阶段后续已开但前置缺失。

### 实现

按业务证据重建并执行前置闭包。旧教学任务 ID 只作为迁移证据，不再出现在新任务目录：

- 已完成首件商品任务可证明至少开放研发/制作。
- 已完成开店任务可证明已开放规则、调整、营业和橱窗经营。
- 已完成或领取首次经营任务、等级不低于 Lv.1或已有后续任务进度，可证明完整核心闭环与任务已经开放。

迁移不补金币、不补星辉、不重放通知；已经获得的历史资源保持原值。

### GREEN 验证

- `core_feature_unlock_state_self_check.gd`
- `core_feature_unlock_migration_self_check.gd`
- `infinite_shop_level_self_check.gd`
- `showcase_round_persistence_self_check.gd`
- `daily_task_self_check.gd`

## 阶段 11：全量聚焦回归与交付检查

### 旧 ID 清理

运行：

```powershell
rg -n "tutorial_l0_first_product|tutorial_l0_open_shop|tutorial_l0_first_business" scripts tests game_data.json
```

最终只允许旧存档迁移夹具或明确的迁移注释引用这些 ID；运行时目录、UI、普通任务测试不得继续依赖。

### Godot 验证

从 `D:\Project\ProjectRest\project-rest-new` 运行。每项命令都必须使用独立可写日志，例如：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\core-feature-unlock-state.log" `
  -s res://tests/core_feature_unlock_state_self_check.gd
```

至少运行以下测试组：

1. 所有新增 `core_feature_*`、`progression_source_*`、`research_craft_core_lock_*`、`onboarding_settlement_*` 与 `starlight_entry_*` 自检。
2. 全部 `tutorial_guide_*` 与 `tutorial_dialogue_catalog_self_check.gd`。
3. 本计划列出的任务、采购、产出、研发、橱窗营业与存档聚焦自检。
4. `component_contract_self_check.gd` 与 `layout_refinement_self_check.gd`。

### 项目检查

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\npc-sequential-unlock-project-load.log" `
  --quit

git diff --check
git status --short
```

确认：

- 所有测试退出码为 0 且输出明确 PASS 标记。
- 项目加载无脚本解析错误。
- 设计之外没有误改配方、价格、营业算法或自动化规则。
- 开始实施前已有的研发结果弹窗修改完整保留。

## 完成条件

- 新存档只开放农场采购区与水稻种子，其余内容可见带锁。
- 核心功能严格由指定真实成功事件单向开放。
- “我自己来”不开放任何功能。
- 首轮有成交结算后才出现最终对话；最终确认只升 Lv.1并开放任务。
- 三个旧教学任务完全退出新任务目录，教学期间不累计任何任务。
- 星辉入口只在第一次真实获得星辉后开放。
- Lv.0–Lv.5 来源、产地和物品等级门禁一致。
- 保存加载、旧存档、零成交、重播和弹窗阻塞均不会造成软锁或重复副作用。
- 聚焦测试、项目加载和差异检查全部通过。
