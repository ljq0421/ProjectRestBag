# 配方成长节奏与晋级信息实施计划

**依据：** `docs/superpowers/specs/2026-07-17-recipe-growth-pacing-and-progress-design.md`

**目标：** 将配方四阶段成长从“累计成品件数、销量和逐次邻接成交”改为按当前阶段累计的真实制作批次、有效营业轮次和协同营业轮次；完整路线固定为 10/20/40 批与 3/7/14 轮，并在配方列表标签右侧、成长详情和营业结算中持续显示剩余条件与本轮成长反馈。

**架构：** `RecipeGrowthService` 负责纯阶段门槛、当前阶段进度、剩余量、设备等待和单级晋升；`GameState` 负责保存阶段计数、在生产完成和结算成功后原子记录贡献，并在设备升级时释放最多一级晋升；`ShowcaseRoundReportService` 负责从真实成交事件汇总逐配方有效/协同营业标记；配方行与成长详情的稳定节点全部声明在 `.tscn`，脚本只绑定状态；结算弹窗消费结算前已确定的逐配方成长增量，不自行推算或重复写入状态。

**技术栈：** Godot 4.6.1、GDScript、现有 `RecipeGrowthService` / `DeviceGrowthService` / `GameState` / `ShowcaseRoundReportService` / `ShowcaseRoundSettlementDialog`、仓库头部自检脚本。

## 全局约束

- 目标 checkout 固定为 `D:\Project\ProjectRest\project-rest-new`。
- 当前工作树存在大量与本功能无关或部分重叠的用户改动；实施前后都必须逐文件检查差异，禁止覆盖或回退这些改动。
- `scripts/game_state.gd`、`scripts/main_view.gd`、`scenes/ui/pages/recipe_action_row.tscn`、`scripts/ui/pages/recipe_action_row.gd`、结算弹窗场景与脚本均为当前重叠文件，补丁必须围绕现有结构精细合并。
- 四阶段制作门槛只按真实完成批次计数。设备 L4/L5 的 1.2 倍不得缩短 40 批要求，只继续作用于招牌款之后的名作制作经验。
- 有效营业和协同营业按配方、按已完成结算的轮次计数，同一配方每轮各最多 +1。
- 真实销量与逐次邻接成交继续在销售事件发生时更新；结算阶段不得二次增加生命周期统计。
- 一次制作完成、一次结算或一次设备升级最多晋升一级；晋级后当前阶段进度清零，不继承超额贡献。
- 普通营业与挑战营业采用完全相同的成长轮次口径。
- 稳定 UI 结构必须写入 `.tscn`；脚本只负责绑定、刷新、格式化和信号。
- 列表摘要固定放在 `RecipeInfoColumn/RecipeMetaRow/RecipeTagsLabel` 后方并与标签同排，不增加信息行，不得撑宽配方行。
- 不接入成长图标或成长形状，不调整阶段固定收益、特性候选、名作门槛、成交速度或营业时长。
- 旧存档保留 `mastery_level` 与生命周期统计；缺失的当前阶段字段初始化为 0，不从旧成品件数或销量反推。
- 所有 Godot headless 命令必须从 `project-rest-new` 运行，并显式传入 `D:\Project\ProjectRest\tmp` 下的可写日志文件。

---

## Task 1：阶段进度模型与单级晋升（RED -> GREEN）

**Files:**

- Create: `tests/recipe_growth_stage_progress_self_check.gd`
- Modify: `scripts/recipe_growth_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `scripts/device_growth_service.gd`
- Modify: `tests/device_growth_self_check.gd`
- Modify: `tests/recipe_production_timing_self_check.gd`

**核心数据契约：**

```gdscript
{
    "mastery_level": 0,
    "stage_made_batches": 0,
    "stage_effective_rounds": 0,
    "stage_synergy_rounds": 0,
    "made_count": 0,
    "sold_count": 0,
    "adjacency_trigger_count": 0
}
```

`RecipeGrowthService` 暴露当前阶段要求与只读状态：

- `stage_requirement(mastery_level) -> Dictionary`
- `stage_progress_status(growth, device_level) -> Dictionary`
- `can_advance_stage(growth, device_level) -> bool`
- `advance_one_stage(recipe_id, growth, recipe, display_config, device_level) -> Dictionary`

阶段要求按当前阶段索引：

- 试作品：10 批、3 有效轮、0 协同轮、设备 L1；
- 稳定款：20 批、7 有效轮、3 协同轮、设备 L3；
- 人气款：40 批、14 有效轮、8 协同轮、设备 L5；
- 招牌款：无下一阶段要求。

- [ ] **Step 1.1：先写失败的阶段领域自检**

覆盖：

- 默认成长包含三个当前阶段计数字段且均为 0；
- 9/10 批、2/3 有效轮时试作品不晋级，同时满足后只升稳定款；
- 稳定款需要 20 批、7 有效轮、3 协同轮和设备 L3；
- 人气款需要真实 40 批、14 有效轮、8 协同轮和设备 L5；
- L4/L5 的 1.2 倍不改变阶段批次，39 批仍不足、40 批才满足；
- 晋级后三个当前阶段字段清零，生命周期统计保持；
- 一个包含多批的完成事件最多晋升一级；
- 设备不足时其他进度保持完成状态；设备升级只释放一级；
- 招牌款不再生成下一阶段目标；
- 旧成长字典缺少新字段时初始化为 0，已有阶段和生命周期统计不改变。

- [ ] **Step 1.2：运行测试并确认 RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-stage-red.log" -s res://tests/recipe_growth_stage_progress_self_check.gd
```

预期：测试因新字段和新接口尚不存在而失败。

- [ ] **Step 1.3：实现纯阶段要求与进度状态**

在 `RecipeGrowthService` 中：

1. 用当前阶段要求替代旧 `LEVEL_THRESHOLDS` 的生命周期累计判断；
2. `stage_progress_status()` 返回当前阶段、下一阶段、每项当前值/目标值/剩余量/完成状态、设备当前值/目标值、`waiting_for_device`、`ready_to_advance`；
3. `advance_one_stage()` 最多 `mastery_level + 1`，清零三个当前阶段字段，再按新阶段刷新候选特性；
4. 删除或停止使用 `natural_mastery_level()`、`capped_mastery_level()`、`effective_signature_made_count()` 的旧晋级语义，并更新所有调用者；
5. `sanitize_growth()` 读取新字段，缺失时使用 0，不迁移旧统计；
6. 保留 `made_count`、`sold_count`、`adjacency_trigger_count` 和名作字段的现有清洗与收益用途。

- [ ] **Step 1.4：把生产完成接入真实批次计数**

修改 `GameState.record_recipe_made()`：

- `made_count` 仍按 `output_amount` 更新；
- `stage_made_batches` 按参数 `batches` 更新，不乘 `output_count`，不乘设备倍率；
- 完成后执行一次单级晋升检查；
- 招牌款且名作已激活时，设备倍率仍只作用于名作制作经验；
- 排队开始和未到期任务不更新阶段批次。

将 `_update_recipe_growth()` 收窄为“检查并最多推进一级”，移除旧的销售跨门槛和设备等待特殊分支。

- [ ] **Step 1.5：修改设备升级释放规则与说明**

`upgrade_device_growth()` 成功后遍历使用该设备的已解锁配方：

- 只检查当前阶段已经完成其他要求的配方；
- 每道配方最多晋升一级；
- 汇总实际晋级配方数量，而不是只返回等待数量；
- 通知说明晋级结果或仍缺少的条件；
- L4/L5 效果文案改为“名作制作经验 +20%”。

`record_recipe_sold()` 继续更新生命周期销量、邻接事件和名作经验，但不再推进四阶段。

- [ ] **Step 1.6：运行 GREEN 与生产边界回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-stage-green.log" -s res://tests/recipe_growth_stage_progress_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-device.log" -s res://tests/device_growth_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-production.log" -s res://tests/recipe_production_timing_self_check.gd
```

---

## Task 2：逐配方有效/协同营业与结算幂等（RED -> GREEN）

**Files:**

- Modify: `tests/showcase_round_report_service_self_check.gd`
- Modify: `tests/showcase_business_round_scene_self_check.gd`
- Create: `tests/recipe_growth_round_progress_self_check.gd`
- Modify: `scripts/showcase_round_report_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `scripts/main_view.gd`

**核心接口：**

- `ShowcaseRoundReportService.growth_round_flags(events) -> Dictionary`
- `GameState.record_recipe_business_round(recipe_id, effective, synergy) -> Dictionary`

逐配方报告至少包含：

```gdscript
{
    "sold_count": 3,
    "positive_adjacency_sale_count": 2,
    "growth_effective_round": true,
    "growth_synergy_round": true
}
```

- [ ] **Step 2.1：先写失败的报告与状态自检**

覆盖：

- 同一配方一轮销售 1 次或 8 次都只产生一个有效营业标记；
- 至少一个 `quantity > 0 && positive_adjacency` 的真实成交产生一个协同营业标记；
- `bonus_only`、`quantity == 0`、清仓项和仅奖励金币不产生有效/协同营业；
- 有效但无正向邻接的轮次只增加有效营业；
- 普通轮和挑战轮报告产生相同标记；
- `GameState.apply_showcase_round_settlement()` 只在完整报告且结算 ID 首次接受时写入一次阶段轮次；
- 重复提交同一结算 ID 不重复写入；
- 结算不重复增加 `sold_count` 或 `adjacency_trigger_count`；
- 结算可触发一次阶段晋升，但不能跨两级。

- [ ] **Step 2.2：运行测试并确认 RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-round-red.log" -s res://tests/recipe_growth_round_progress_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-report-red.log" -s res://tests/showcase_round_report_service_self_check.gd
```

- [ ] **Step 2.3：集中汇总成长轮次标记**

在 `ShowcaseRoundReportService` 增加纯汇总函数：

1. 只读取真实销售事件；
2. 按 `recipe_id` 汇总真实销量和正向邻接真实销量；
3. 输出有效/协同营业布尔值；
4. `build_report()` 的 `products` 复用该结果；
5. `main_view.gd::_build_showcase_round_summary()` 同样复用该结果，避免预结算摘要和最终报告口径分叉。

- [ ] **Step 2.4：在结算成功边界原子记录阶段轮次**

修改 `GameState.apply_showcase_round_settlement()`：

- 先完成现有 settlement ID、pending ID 和结果合法性检查；
- 只对完整 `round_report.products` 中 `growth_effective_round == true` 的配方调用一次 `record_recipe_business_round()`；
- 协同轮只在报告标记为 true 时增加；
- 把本轮实际写入的 `effective_round_delta`、`synergy_round_delta`、晋级前后阶段加入报告中的逐配方成长结果，供后续通知和结算展示使用；
- 在 `applied_showcase_settlement_ids` 幂等边界内完成写入；
- 不触碰实时销售事件已经累计的生命周期统计。

- [ ] **Step 2.5：运行 GREEN 与普通/挑战结算回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-round-green.log" -s res://tests/recipe_growth_round_progress_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-report-green.log" -s res://tests/showcase_round_report_service_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-round-scene.log" -s res://tests/showcase_business_round_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-challenge.log" -s res://tests/showcase_business_challenge_runtime_self_check.gd
```

---

## Task 3：配方列表标签右侧成长摘要（RED -> GREEN）

**Files:**

- Modify: `scenes/ui/pages/recipe_action_row.tscn`
- Modify: `scripts/ui/pages/recipe_action_row.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/production_recipe_tags_self_check.gd`
- Modify: `tests/recipe_action_icon_layout_self_check.gd`
- Modify: `tests/recipe_production_ui_self_check.gd`
- Create: `tests/recipe_growth_summary_ui_self_check.gd`

- [ ] **Step 3.1：先写失败的配方行结构与文本测试**

验证：

- `RecipeInfoColumn/RecipeMetaRow/RecipeGrowthSummaryLabel` 固定存在；
- 它紧跟 `RecipeTagsLabel`，与标签同属 `RecipeMetaRow`，不得成为新行；
- `RecipeMetaRow` 有稳定小间距；
- 标签和成长摘要都启用裁切与省略，长文本不会改变 `RecipeInfoColumn` 或整行最小宽度；
- 成品配方显示摘要，中间产品同时隐藏标签和摘要；
- 试作品、稳定款、人气款分别只显示未完成条件；
- 仅设备未完成时显示 `成长：待设备 L3/L5`；
- 招牌款显示 `成长：招牌款`；
- 摘要悬停提示包含当前阶段、下一阶段、全部当前值/目标值/剩余量以及有效/协同营业定义；
- 当前阶段进度变化后刷新已有行，无需重建列表。

- [ ] **Step 3.2：运行测试并确认 RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-summary-red.log" -s res://tests/recipe_growth_summary_ui_self_check.gd
```

- [ ] **Step 3.3：在场景中声明同排摘要节点**

在当前已修改的 `recipe_action_row.tscn` 上增量合并：

```text
RecipeInfoColumn
└─ RecipeMetaRow
   ├─ RecipeTagsLabel
   └─ RecipeGrowthSummaryLabel
```

- `RecipeGrowthSummaryLabel` 位于标签之后；
- `RecipeMetaRow` 使用固定小间距；
- 两个 Label 都使用可伸缩、裁切和省略配置，不能以内容最小宽度撑开父行；
- 不改变现有 `RecipeMaterialsLabel`、`ProductionProgressArea`、材料图标和操作按钮顺序。

- [ ] **Step 3.4：实现摘要与完整悬停提示绑定**

在 `recipe_action_row.gd` 中：

- 绑定新节点；
- `configure_production()` 首次填充成长摘要；
- `configure_processing()` 隐藏标签与摘要；
- 新增刷新方法，读取 `state.recipe_growth_status(recipe_id)`，只格式化未完成条件；
- 使用固定短文案：`成长：距稳定款 4批·1轮`、`成长：距人气款 8批·2轮·1协同`、`成长：待设备 L3`、`成长：招牌款`；
- tooltip 始终保存完整文本，即使摘要被裁切。

在 `main_view.gd::_refresh_recipe_production_statuses()` 中同时刷新生产进度和成长摘要，确保生产完成、结算完成、设备升级后已有配方行立即同步。

- [ ] **Step 3.5：运行 GREEN 与现有配方行回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-summary-green.log" -s res://tests/recipe_growth_summary_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-tags.log" -s res://tests/production_recipe_tags_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-row-layout.log" -s res://tests/recipe_action_icon_layout_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-production-ui.log" -s res://tests/recipe_production_ui_self_check.gd
```

---

## Task 4：成长详情、结算增量与晋级通知（RED -> GREEN）

**Files:**

- Modify: `scenes/ui/overlays/recipe_growth_detail_panel.tscn`
- Modify: `scripts/ui/overlays/recipe_growth_detail_panel.gd`
- Modify: `scenes/ui/overlays/showcase_round_settlement_dialog.tscn`
- Modify: `scripts/ui/overlays/showcase_round_settlement_dialog.gd`
- Modify: `scripts/game_state.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/device_recipe_growth_ui_self_check.gd`
- Modify: `tests/showcase_round_settlement_dialog_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`

- [ ] **Step 4.1：先写失败的详情与结算反馈测试**

验证：

- 成长详情场景声明当前阶段、下一阶段、制作批次、有效营业、协同营业、设备等级和“所有条件需同时满足”的稳定节点；
- 不适用的协同/设备行隐藏但其他行顺序稳定；
- 已完成项显示完成状态，不显示“还差 0”；
- 只差设备时显示设备名称、当前等级、目标等级和等待说明；
- 招牌款显示成长完成并继续显示名作区域；
- 结算详情每个真实成交配方显示 `有效营业 +1`，有正向邻接时追加 `协同营业 +1`；
- 零成交和仅清仓配方不显示成长增量；
- 晋级通知列出新阶段固定收益、特性选择和下一设备要求；
- 条件完成但设备不足的等待通知只入队一次，不在后续每轮重复。

- [ ] **Step 4.2：运行测试并确认 RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-detail-red.log" -s res://tests/device_recipe_growth_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-settlement-ui-red.log" -s res://tests/showcase_round_settlement_dialog_self_check.gd
```

- [ ] **Step 4.3：场景化成长条件行**

在 `recipe_growth_detail_panel.tscn` 中保留现有阶段轨迹、特性和名作区域，新增固定条件行容器：

- `NextStageLabel`
- `StageMadeRow`
- `StageEffectiveRoundRow`
- `StageSynergyRoundRow`
- `StageDeviceRow`
- `AllConditionsHintLabel`

每行声明名称、当前/目标和剩余状态 Label。脚本只根据 `stage_progress_status()` 绑定文本、完成状态与可见性。现有生命周期统计改为次要统计文案，不再表现为晋级门槛。

- [ ] **Step 4.4：为结算逐配方行增加成长列**

在当前结算弹窗场景的 `RoundDetailGrid` 末尾增加稳定的 `成长` 表头，并在脚本中扩展列数与固定列宽。成长单元格读取逐配方报告的 `growth_effective_round`、`growth_synergy_round`，格式化为：

- `有效营业 +1`
- `有效营业 +1｜协同营业 +1`
- 无增长时 `—`

必须在当前已存在的结算表格修改上增量合并，并通过 combined minimum size 检查避免弹窗溢出。

- [ ] **Step 4.5：集中晋级与等待反馈**

`GameState` 的单级晋升结果返回结构化字段：晋级前后阶段、固定收益说明、是否需要特性选择、下一阶段设备要求。`main_view.gd` 和现有通知队列消费该结果：

- 晋级只生成一次通知；
- 待选择特性仍走现有选择弹窗；
- 等待设备提示写入一次性状态或稳定日志标记，防止每轮重复；
- 列表和详情始终从状态实时显示等待设备，不依赖通知是否已经展示。

- [ ] **Step 4.6：运行 GREEN 与组件契约回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-detail-green.log" -s res://tests/device_recipe_growth_ui_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-settlement-ui-green.log" -s res://tests/showcase_round_settlement_dialog_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-components.log" -s res://tests/component_contract_self_check.gd
```

---

## Task 5：旧成长夹具、自动化报告与文档同步（RED -> GREEN）

**Files:**

- Modify: `tests/automation_settlement_self_check.gd`
- Modify: `tests/recipe_growth_choice_scene_self_check.gd`
- Modify: `tests/recipe_masterwork_growth_self_check.gd`
- Modify: `tests/device_growth_self_check.gd`
- Modify: `tests/device_recipe_growth_ui_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`
- Modify: `doc/2026-07-10-developer-quick-reference.md`

- [ ] **Step 5.1：更新旧测试夹具到当前阶段进度语义**

- 自动化报告若要验证一次制作触发晋级，先把试作品设为 9/10 批、3/3 有效轮，再完成 1 批；
- 特性选择测试直接使用已经晋级的阶段夹具，不再用旧生命周期统计触发晋级；
- 名作测试先按新阶段字段进入招牌款，再验证两次特性选择和名作经验；
- 设备测试删除 33/34 件乘 1.2 的旧招牌门槛断言，改为 39/40 真实批次；
- 继续断言 `made_count`、`sold_count`、`adjacency_trigger_count` 作为生命周期统计正常累计；
- 自动化报告的 `made_count` 仍表示成品件数，同时新增或验证 `made_batches`，不得混用。

- [ ] **Step 5.2：运行受影响测试并确认 GREEN**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-automation.log" -s res://tests/automation_settlement_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-choice.log" -s res://tests/recipe_growth_choice_scene_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-masterwork.log" -s res://tests/recipe_masterwork_growth_self_check.gd
```

- [ ] **Step 5.3：更新当前开发者参考**

修改 `doc/2026-07-10-developer-quick-reference.md`：

- 将旧 5/15/40 件、3/10/25 销量、逐次邻接门槛替换为当前阶段 10/20/40 批、3/7/14 有效轮、0/3/8 协同轮；
- 写明阶段进度晋级后清零、每次事件最多升一级；
- 写明普通/挑战营业、零成交、清仓和奖励事件口径；
- 写明 L4/L5 的 1.2 倍只作用于名作制作经验；
- 保留旧历史计划和旧设计文档作为历史记录，不批量回写它们。

---

## Task 6：最终验证与代码审查

- [ ] **Step 6.1：运行新增核心自检**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-stage-final.log" -s res://tests/recipe_growth_stage_progress_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-round-final.log" -s res://tests/recipe_growth_round_progress_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-summary-final.log" -s res://tests/recipe_growth_summary_ui_self_check.gd
```

- [ ] **Step 6.2：运行受影响领域与 UI 回归**

依次运行：

- `device_growth_self_check.gd`
- `recipe_production_timing_self_check.gd`
- `showcase_round_report_service_self_check.gd`
- `showcase_business_round_scene_self_check.gd`
- `showcase_business_challenge_runtime_self_check.gd`
- `production_recipe_tags_self_check.gd`
- `recipe_action_icon_layout_self_check.gd`
- `recipe_production_ui_self_check.gd`
- `device_recipe_growth_ui_self_check.gd`
- `showcase_round_settlement_dialog_self_check.gd`
- `automation_settlement_self_check.gd`
- `recipe_growth_choice_scene_self_check.gd`
- `recipe_masterwork_growth_self_check.gd`
- `component_contract_self_check.gd`

每个命令都使用独立的 `D:\Project\ProjectRest\tmp\*.log`。

- [ ] **Step 6.3：运行项目加载和宽回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-load.log" --quit
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "D:\Project\ProjectRest\tmp\rest-new-growth-mvp.log" -s res://tests/mvp_self_check.gd
git diff --check
```

如果宽回归存在与本功能无关的既有失败，必须与新增聚焦自检结果分开报告，不得通过扩大修改范围掩盖工作区漂移。

- [ ] **Step 6.4：逐项人工审查**

- 确认四阶段实际需要 10/20/40 真实批次与 3/7/14 有效轮；
- 确认快售和慢售配方每轮都最多贡献一个有效/协同轮；
- 确认任何路径都不能从试作品直接跳到人气款或招牌款；
- 确认销售事件和结算没有双计生命周期统计；
- 确认配方列表摘要位于标签右侧且同排，长文本不扩张布局；
- 确认详情、结算和通知全部消费状态层结果，不各自重新计算门槛；
- 确认未接入成长图标/形状，未改变名作门槛与阶段收益；
- 确认所有提交只包含本功能明确文件，并保留当前用户改动。

完成聚焦与宽回归后，再使用代码审查流程检查需求覆盖、状态幂等、场景节点稳定性和意外范围扩张。
