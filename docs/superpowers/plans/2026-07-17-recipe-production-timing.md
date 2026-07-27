# 商品制作计时实施计划

**依据：** `docs/superpowers/specs/2026-07-17-recipe-production-timing-design.zh.md`

**目标：** 将成品制作从点击即入库改为配置驱动的 2/4/8 秒并行任务；支持在线完成、普通手动任务离线完成、自动入库、每批独立进度条和单品 9 批上限，并保持配方成长、设备成长、任务、新手引导和厨房自动化边界正确。

**架构：** `scripts/catalog.gd` 是每道配方制作时长的权威来源；`GameState` 负责原子启动、单品 9 批上限、完成和只读批次快照；`RecipeBook` 保留玩家制作入口但改为创建手动任务；`SaveSystem` 只结算离线前已经存在的普通手动任务；`AutomationService` 保留现有自动规则与批次数量语义，但不得突破单品上限；`main_view.gd` 负责每秒协调完成、保存、刷新和可见反馈；配方行场景声明固定进度区域，脚本复用少量进度条节点渲染逐批状态。

**技术栈：** Godot 4.6.1、GDScript、Python 标准库、现有 `Catalog` / `GameState` / `RecipeBook` / `AutomationService` / `SaveSystem`、仓库头部自检脚本。

## 全局约束

- 目标 checkout 固定为 `D:\Project\ProjectRest\project-rest-new`。
- 不修改 `doc/recipe_display_config.json`；制作时长属于 `Catalog.RECIPES` 的玩法数据，不属于橱窗展示配置。
- 166 道配方必须显式包含 `production_duration_seconds`，合法值只有 `2`、`4`、`8`。
- 每次玩家点击固定创建一批；不增加 1 批/5 批选择。
- 第一版不限制同一设备并发数量，不设计设备排产；同一种商品的手动与自动化批次合计最多 9 批。
- 自动化整组批次超过剩余位置时整组拒绝，不拆批、不扣材料，等待后续正常触发再试。
- 中间原料加工与研发仍即时完成。
- 制作使用现实秒，不受营业暂停或 1x/2x 倍速影响。
- 普通手动任务可以在离线期间完成，但离线期间不得自动创建下一批。
- 既有自动化规则的批次数量、优先级和目标库存语义不重做；但设备级互斥必须移除，手动任务不能再让同设备自动规则暂停。
- 稳定 UI 结构写入 `.tscn`；脚本只做状态绑定与刷新。
- 制作进度区域固定为视觉稿确认的 164 px；1–3 批单列全宽、4–6 批双列等宽、7–9 批三列等宽，每列最多 3 条。
- 进度条高度 7 px、同列间距 4 px，表面不显示秒数、编号、百分比或数值；剩余秒数只放在悬停提示中。
- 所有 Godot headless 命令必须从 `project-rest-new` 运行，并显式传入可写的 `--log-file`。
- 保留工作区中所有无关改动；实施提交只能包含本功能明确涉及的文件。

---

## Task 1：配置生成与严格审计（RED -> GREEN）

**Files:**

- Modify: `tools/generate_recipe_production_durations.py`
- Modify: `tests/test_recipe_production_duration_config.py`
- Modify: `scripts/catalog.gd`
- Modify: `tools/audit_recipe_data.py`
- Modify: `tests/test_recipe_data_audit.py`

**接口与数据契约：**

- `Catalog.RECIPES[recipe_id].production_duration_seconds -> int`
- `generate_recipe_production_durations.py --check`
- `generate_recipe_production_durations.py --write`
- 严格审计拒绝缺失字段和非 `2/4/8` 值。

- [ ] **Step 1.1：先写失败的 Python 配置测试**

覆盖以下断言：

- `RECIPES` 恰好包含 166 道配方；
- 每道配方都有显式 `production_duration_seconds`；
- 2 秒档 69 道、4 秒档 49 道、8 秒档 48 道；
- 2–3、4、5+ 材料分别生成 2、4、8；
- 使用成品材料的 `cream_shortcake` 生成 8；
- `--write` 幂等，第二次运行不改变文件；
- `--check` 在缺失或非法值时返回非零。

- [ ] **Step 1.2：运行测试并确认 RED**

```powershell
python -B -m unittest tests.test_recipe_production_duration_config tests.test_recipe_data_audit
```

预期：新测试因生成器不存在、配方字段缺失而失败。

- [ ] **Step 1.3：实现最小生成器**

生成器应复用仓库现有工具对 `const RECIPES := { ... }` 的定位方式：

1. 先读取全部配方 ID；
2. 再读取每道配方的 `materials`；
3. 如果任意材料属于配方 ID 集合，写入 8；
4. 否则按材料数量写入 2/4/8；
5. 只更新 `RECIPES` 块，保留配方顺序、注释和其他字段；
6. `--check` 只检查，不写文件；`--write` 执行确定性更新。

- [ ] **Step 1.4：生成 166 道配方字段并扩展严格审计**

运行生成器写入 `scripts/catalog.gd`。扩展 `audit_recipe_data.py`，让严格模式检查字段完整性与合法值，但不在运行时重新计算或覆盖单项配置。

- [ ] **Step 1.5：运行 GREEN 与幂等验证**

```powershell
python -B tools/generate_recipe_production_durations.py --check
python -B -m unittest tests.test_recipe_production_duration_config tests.test_recipe_data_audit
```

---

## Task 2：制作任务、单品上限与批次快照（RED -> GREEN）

**Files:**

- Modify: `tests/recipe_production_timing_self_check.gd`
- Modify: `scripts/game_state.gd`
- Modify: `scripts/recipe_book.gd`

**核心接口：**

- `RecipeBook.make_product(state, recipe_id, 1, now_unix = -1) -> Dictionary`
- `GameState.queue_recipe_production(recipe_id, batches, now_unix, source, automation_rule_id) -> bool`
- `GameState.complete_recipe_production(index, now_unix) -> bool`
- `GameState.complete_ready_manual_recipe_productions(now_unix) -> Dictionary`
- `GameState.recipe_production_queue_summary(now_unix) -> Dictionary`

每个配方摘要包含 `active_count` 和最多 9 个稳定排序的 `batch_progress` 项；每项至少包含任务稳定序号、任务内批次序号、开始时间、完成时间、时长、剩余秒数和 0–1 进度值。

- [ ] **Step 2.1：先写失败的领域自检**

使用固定时间戳验证：

- 点击制作立即扣除一批材料；
- 完成前成品库存、`made_count`、设备使用次数、任务事件和新手引导均不推进；
- `rice_milk_drink` 使用配置的 2 秒，4 秒和 8 秒配方分别读取自身配置；
- 手动 `batches = 5` 被拒绝；
- 同一设备可以同时创建多个同配方和不同配方任务；
- 手动任务和自动任务可以在同一设备上同时存在；
- 同一商品的前 9 个手动批次可以启动，第 10 个被拒绝且不扣材料；
- 不同商品分别拥有 9 个并发位；
- 一个 5 批自动化任务占用 5 个批次位，手动与自动化共同计数；
- 自动化整组会突破 9 批时整组拒绝，不静默缩减；
- 未到期不能完成，到期后按 `output_count` 入库；
- 完成时才调用 `TutorialProgress.on_product_made()` 并记录成长/任务；
- 同一任务不能结算两次；
- 汇总结果按 `recipe_id` 返回在制批次数、最近完成时间和稳定排序的逐批进度快照。

- [ ] **Step 2.2：运行测试并确认 RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\rest-new-recipe-production-domain.log" -s res://tests/recipe_production_timing_self_check.gd
```

- [ ] **Step 2.3：把玩家制作入口切换到队列**

修改 `RecipeBook.make_product()`：

- 不再直接消费材料和入库；
- 只调用 `state.queue_recipe_production(..., source = "manual")`；
- 返回“已开始制作”的结构化结果；
- 保留明确的失败原因；
- 增加可注入 `now_unix`，便于确定性测试。

- [ ] **Step 2.4：实现设备无限并发、单品 9 批与配置时长**

修改 `GameState.queue_recipe_production()`：

- 手动来源只接受 `batches == 1`；
- 移除 `queue_recipe_production()` 的同设备活动任务限制，手动和自动来源都不再被设备容量拒绝；
- 在任何材料扣除前统计同一 `recipe_id` 的实际在制批次数；手动与自动化共同计数，整次申请导致总数超过 9 时返回明确的上限失败原因；
- 直接读取 `recipe.production_duration_seconds`；
- 手动任务时长不做批次数乘法；
- 自动化来源继续保留既有批次数量行为，避免本任务重写自动化平衡。

- [ ] **Step 2.5：集中实现到期结算与单遍汇总**

`complete_ready_manual_recipe_productions()` 只处理 `source == "manual"` 且已经到期的任务，倒序或使用稳定 ID 避免数组删除跳项，并返回按配方聚合的入库数量与完成批次数。

`recipe_production_queue_summary()` 单遍扫描队列，按配方返回：

- `active_count`
- `nearest_ready_at_unix`
- `remaining_seconds`
- `batch_progress`

`batch_progress` 把任务的 `batches` 展开为实际批次，按 `started_at_unix`、队列稳定序号、任务内批次序号排序并限制为 9 项。每项包含渲染所需的时间与进度，不让 166 个配方行各自再次扫描全队列。

完成成功后才调用 `TutorialProgress.on_product_made()`；入库失败时保留任务，不推进任何成长或任务事件。

- [ ] **Step 2.6：运行 GREEN**

重新运行 `recipe_production_timing_self_check.gd`，确认全部领域断言通过。

---

## Task 3：在线与离线结算边界（RED -> GREEN）

**Files:**

- Modify: `scripts/save_system.gd`
- Modify: `scripts/automation_service.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/automation_settlement_self_check.gd`
- Modify: `tests/showcase_legacy_cleanup_self_check.gd`
- Extend: `tests/recipe_production_timing_self_check.gd`

- [ ] **Step 3.1：先写失败的在线/离线测试**

覆盖：

- 在线每秒结算所有到期手动任务并只保存一次；
- 离线前已存在且到期的手动任务自动入库；
- 离线不足时不后移手动任务时间，重新进入后保留真实剩余时间；
- 离线完成不会自动创建下一批手动任务；
- 多个离线完成项只生成一条汇总通知；
- 同一存档同一时间重复加载不重复入库；
- 自动化任务继续遵守现有离线暂停/重锚语义；
- 自动化 5 批任务在剩余位置少于 5 时不启动、不扣材料、不创建部分任务；有足够位置后可按现有触发节奏重新尝试；
- 同设备手动任务不再暂停自动规则，多条同设备自动规则可以各有一个活动任务；
- 营业轮次和待结算橱窗状态不被离线手动制作改动。

- [ ] **Step 3.2：运行相关测试并确认 RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\rest-new-recipe-production-offline.log" -s res://tests/recipe_production_timing_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\rest-new-automation-settlement.log" -s res://tests/automation_settlement_self_check.gd
```

- [ ] **Step 3.3：实现离线手动任务结算**

在 `SaveSystem.load_game()` 的离线处理阶段：

1. 使用当前现实时间调用 `complete_ready_manual_recipe_productions()`；
2. 将结果合并为一条 `recipe_production_report` 通知；
3. 再执行现有产出与自动化离线逻辑；
4. 原子保存结算后的状态，保存失败时沿用现有回滚边界。

修改 `AutomationService._shift_kitchen_queue_for_offline()`，只后移需要保持既有离线暂停语义的自动化任务，不再后移普通手动任务。

同时把在线自动规则的占用判断从“同设备只能一个任务”收窄为“同一自动规则最多一个活动任务”：

- 删除 `manual_queue_busy` 的设备级暂停；
- 手动任务与自动任务可以在同一设备上并行；
- 多条同设备自动规则按既有优先级和 `sort_order` 依次尝试启动；
- 每条规则已有活动任务时不重复启动；
- 材料竞争仍按既有确定顺序解决。

- [ ] **Step 3.4：实现在线协调与反馈聚合**

在 `main_view.gd::_process()` 的每秒分支中，先完成到期手动任务，再运行现有在线自动化结算。只有实际完成时才：

- 保存游戏；
- 刷新资源栏、当前页和相关引导目标；
- 显示一次聚合完成文本；
- 继续按既有顺序展示任务通知。

- [ ] **Step 3.5：运行 GREEN 和旧边界回归**

运行本任务涉及的三个聚焦自检，确认普通手动任务的新离线语义与自动化、营业轮次隔离同时成立。

---

## Task 4：配方信息分行、逐批进度条、9 批按钮状态与“制作全部”（RED -> GREEN）

**Files:**

- Modify: `scenes/ui/pages/recipe_action_row.tscn`
- Modify: `scripts/ui/pages/recipe_action_row.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/recipe_production_ui_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`
- Modify: `tests/recipe_action_icon_layout_self_check.gd`

- [ ] **Step 4.1：先写失败的 UI 自检**

验证：

- `ProductionProgressArea` 是 `RecipeActionRow` 中紧跟 `RecipeInfoColumn` 的同级节点，不嵌入信息列；
- `RecipeInfoColumn/RecipeMaterialsLabel` 直接位于 `RecipeInfo` 后、`RecipeMetaRow` 前，成品与中间原料加工行都使用同一结构；
- `RecipeInfo` 的可见文字只显示配方名称，不再拼接“材料：”；`RecipeMaterialsLabel` 独占第二行并以“材料：”开头；
- 材料行字号为 10 px，关闭自动换行，单行裁剪并使用省略号；悬浮提示保留不省略的完整材料文字；
- 外部区域固定宽度 164 px，0、1、3、4、6、7、9 批时 `RecipeInfoColumn` 与整行最小宽度保持不变；
- 场景声明三个可等分宽度的纵向列容器，脚本只显示当前需要的 1、2 或 3 列；
- 1–3 批单列占满 164 px，4–6 批双列等宽，7–9 批三列等宽，每列最多 3 条并先纵向填满；
- 每个实际批次对应一个 7 px 高的小型 `ProgressBar`，`show_percentage = false`，无可见文字；
- 各条进度值来自不同批次快照，完成后移除对应条目并稳定紧凑重排；
- 脚本按需创建并缓存最多 9 个进度条，后续每秒刷新只改父列、可见性、值和提示，不重建配方行或重复销毁节点；
- 0 批时保留固定区域但不显示占位文字；中间原料加工行同样不显示进度条；
- 9 批时“制作”按钮禁用且提示为“同时制作已达 9 批上限”，任一批完成后按上限、设备和材料重新判定；
- “制作全部”跳过已达 9 批的商品，对其他可制作商品各启动一批，并显示“已开始制作 N 项”。

- [ ] **Step 4.2：运行 UI 测试并确认 RED**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\rest-new-recipe-production-ui.log" -s res://tests/recipe_production_ui_self_check.gd
```

- [ ] **Step 4.3：场景化拆分材料行并增加固定制作进度区域**

在 `.tscn` 中于 `RecipeInfo` 后、`RecipeMetaRow` 前声明 `RecipeMaterialsLabel`，字号固定为 10 px，单行省略且不自动换行。`recipe_action_row.gd` 将 `RecipeInfo.text` 改为只绑定配方名称，将带“材料：”前缀的材料摘要绑定到新标签，并把未裁剪的完整文字写入其 `tooltip_text`；成品与中间原料加工行共用该绑定逻辑。这个新增节点只占用 `RecipeInfoColumn` 内的第二行，不改变右侧制作进度区域的固定宽度。

同时在 `.tscn` 中删除文字倒计时 `ProductionStatusLabel`，保留 `RecipeTagsLabel` 的裁剪语义，并在 `RecipeInfoColumn` 后、`MaterialIcons` 前声明 `ProductionProgressArea`。该区域固定为 164 px，内部声明三个等分的 `VBoxContainer`，列间距和条间距均为 4 px；隐藏的列不占内部宽度，因此单列与双列会自动铺满整个外部区域。

`recipe_action_row.gd` 绑定固定节点路径，提供 `refresh_production_progress(batch_progress)`：

1. 根据批次数计算 `ceil(count / 3)`，限制为 0–3 列；
2. 显示所需列并让可见列等宽伸展；
3. 按列优先顺序把批次映射到缓存的进度条；
4. 更新 `value`、`tooltip_text` 和可见性；
5. 隐藏未使用的缓存条，不在每秒刷新时 `queue_free()`；
6. 处理行始终传入空快照。

- [ ] **Step 4.4：改造制作按钮与“制作全部”反馈**

- 单项制作成功提示改为“已开始制作：商品名，预计 N 秒”；
- `制作全部` 继续先即时处理可用中间原料，再按现有确定顺序为材料仍足够的成品各启动一批；
- `_recipe_unavailable_status()` 在配方有效和设备解锁后检查单品在制批次；达到 9 时优先返回固定上限提示，避免按钮仍显示材料原因；
- 结果提示使用“已开始制作”，不得提前写成“制作完成”；
- 完成前“上架”仍只检查真实成品库存。

- [ ] **Step 4.5：运行 GREEN 与组件契约回归**

运行新增 UI 自检、组件契约和配方操作行布局自检。

---

## Task 5：成长、任务、新手路线和文档同步（RED -> GREEN）

**Files:**

- Modify: `tests/device_growth_self_check.gd`
- Modify: `tests/tutorial_guide_route_self_check.gd`
- Modify: `tests/task_mainline_self_check.gd`
- Modify: `tests/mvp_self_check.gd`
- Modify: `doc/v3.md`
- Modify: `doc/2026-07-10-developer-quick-reference.md`

- [ ] **Step 5.1：更新测试，使“开始”和“完成”成为两个明确阶段**

更新既有即时制作夹具：

- 设备有效使用只在队列完成后增加；
- 配方 `made_count` 只在完成后增加；
- 新手箭头在点击制作后仍停留于制作阶段，到期完成后才前往上架；
- 主线 `make_product` 目标只由真实完成事件满足；
- 旧的手动五批制作测试改为一个手动批次或明确的自动化批次测试。

- [ ] **Step 5.2：同步玩家规则与开发者契约**

修改文档：

- 删除“手动制作 1 次或 5 次”的旧说明；
- 写明每次点击一批、材料启动时扣除、2/4/8 秒后自动入库；
- 记录 `production_duration_seconds` 为每道成品配方必填字段；
- 记录普通手动任务的在线/离线完成边界。

- [ ] **Step 5.3：运行成长与路线聚焦回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\rest-new-device-growth.log" -s res://tests/device_growth_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\rest-new-tutorial-route.log" -s res://tests/tutorial_guide_route_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\rest-new-task-mainline.log" -s res://tests/task_mainline_self_check.gd
```

---

## Task 6：最终验证与审查

- [ ] **Step 6.1：运行配置测试**

```powershell
python -B tools/generate_recipe_production_durations.py --check
python -B -m unittest tests.test_recipe_production_duration_config tests.test_recipe_data_audit
```

- [ ] **Step 6.2：运行聚焦 Godot 自检**

依次运行：

- `recipe_production_timing_self_check.gd`
- `recipe_production_ui_self_check.gd`
- `automation_settlement_self_check.gd`
- `showcase_legacy_cleanup_self_check.gd`
- `device_growth_self_check.gd`
- `tutorial_guide_route_self_check.gd`
- `task_mainline_self_check.gd`
- `component_contract_self_check.gd`
- `recipe_action_icon_layout_self_check.gd`

每个命令都使用独立的 `%TEMP%` 日志文件，避免 Godot 访问不可写的 `user://logs`。

- [ ] **Step 6.3：运行项目加载和宽回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\rest-new-recipe-production-load.log" --quit
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\rest-new-recipe-production-mvp.log" -s res://tests/mvp_self_check.gd
git diff --check
```

如果宽回归存在与本功能无关的既有失败，必须与本功能聚焦测试分开报告，不得通过扩大修改范围掩盖基线漂移。

- [ ] **Step 6.4：逐项审查规格覆盖**

确认：

- 配置是运行时权威来源；
- 69/49/48 分布与复合成品规则正确；
- 设备级无限并发成立，单品最多 9 批，手动与自动化共同计数，不同商品分别计算；
- 手动五批入口不存在；
- 在线和离线都只完成已经启动的普通手动任务；
- 完成前不可上架且不推进成长；
- 页面使用单遍汇总提供逐批快照，不按 166 行重复扫描队列；
- 固定 164 px 制作区域在 0–9 批之间不改变信息列或整行最小宽度；
- 1/2/3 列自适应、每列最多 3 条、无可见倒计时文字与 9 批按钮提示均符合视觉确认；
- 自动化、营业轮次和产出页行为没有被意外重写。
