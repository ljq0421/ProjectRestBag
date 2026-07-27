# 橱窗构筑任务路线重设计实施计划

**目标：** 保留现有任务面板、奖励领取、店铺等级与橱窗营业框架，把任务路线重建为“Lv.0–Lv.2 强引导、Lv.3–Lv.5 固定构筑评鉴、Lv.6+ 轮换经营合同”，并让任务、挑战、结算说明和历史记录统一读取同一份营业轮报告。

**依据：** `docs/superpowers/specs/2026-07-15-showcase-build-task-route-redesign.zh.md`

**实施原则：**

- 所有行为修改采用 RED → GREEN → REFACTOR：先增加会因目标能力缺失而失败的聚焦自检，再写最少实现。
- 从 `D:\Project\ProjectRest\project-rest-new` 运行 Godot，所有 headless 命令显式传入可写 `--log-file`。
- `game_data.json.tasks` 是任务内容唯一真相；`doc/showcase_round_rules.json` 只保留营业规则、环境参数和数值配置。
- `ShowcaseRoundReportService` 生成任务与挑战共同使用的营业报告；不得在 `TaskService` 或 `main_view.gd` 另算一套营业指标。
- `TaskService` 负责开放、一次性进度、完成状态和领奖；纯条件求值与评级拆到小型服务，不继续扩大现有约 900 行的任务服务。
- 稳定任务页、营业栏和结算弹窗结构优先声明在 `.tscn`；脚本只负责绑定、信号、状态刷新和协调。
- Lv.1 以后任务不得直接设置店铺等级，也不得以指定配方解锁阻塞升级。
- 项目处于开发阶段，不实现旧任务 ID、旧进度或旧挑战快照迁移；验证使用新存档。
- 本计划不自动提交 Git。每个任务完成后先检查差异，保留并绕开工作区中的其他未提交改动。

## 总体阶段

### 阶段 A：统一数据与判定基础

完成 Task 1–4 后，任务定义、营业报告、条件求值、挑战快照和真实结算推进链拥有一致的数据合同；当前挑战 ID 漂移和挑战成功不推进任务的问题被消除。

### 阶段 B：替换阶段任务路线

完成 Task 5–8 后，新游戏可以完成 Lv.0 完整营业教学，Lv.1–Lv.2 学会售速、补货和基础构筑，Lv.3–Lv.5 只面对构筑评鉴，Lv.6+ 可以从三个合同中选择一个并积累门店评级。

### 阶段 C：三段反馈与旧语义收口

完成 Task 9–11 后，任务面板、营业前目标、营业中实时进度和结算评级使用同一套数据；旧主线、旧挑战 ID、旧每日任务语义和相关过时测试/文档全部清理。

## Task 1：建立任务目录与配置校验

**Files**

- Create: `scripts/task_catalog_service.gd`
- Modify: `game_data.json`
- Modify: `scripts/task_service.gd`
- Modify: `scripts/star_progression_service.gd`
- Create: `tests/task_catalog_config_self_check.gd`
- Modify: `tests/daily_task_self_check.gd`

**RED**

- 断言 `game_data.json.tasks` 包含 `tutorial_tasks`、`build_courses`、`stage_evaluations`、`round_contracts` 和 `resource_side_tasks` 五类完整定义，而不是只有描述性 `main_tasks` 名称列表。
- 断言任务 ID 全局唯一、版本为正整数、类型合法，并且每个任务至少包含一个完成条件。
- 断言所有前置任务、环境 ID、条件字段、评级等级和奖励键都能解析。
- 断言铜、银、金目标严格递进；`gte` 条件随评级升高不能降低，`lte` 条件随评级升高不能放宽。
- 断言 Lv.3 以后所有主线/评鉴任务都不使用 `harvest`、`make_product`、`research_attempt` 或 `research_success`。
- 断言资源支线可以声明每日重置，但每日重置不会删除主线、评鉴或合同最佳成绩。
- 断言 `automation.feature_unlocks.*.task_id` 全部指向统一任务目录，`automation.feature_tasks` 不再保存第二套任务定义。

**GREEN**

- 在 `task_catalog_service.gd` 实现加载、分类合并、ID 索引、引用校验、可用机制校验和稳定排序；该服务不修改 `GameState`。
- 把当前 `_mainline_task_definitions()`、`_daily_task_definitions()` 和 `automation.feature_tasks` 的内容迁到 `game_data.json.tasks`，先保持可运行的等价定义，再由后续任务逐段替换目标。
- 自动化任务保留 `type = "feature"` 和独立 UI 分类，但定义位于 `resource_side_tasks`；`automation.feature_unlocks` 只通过 `task_id` 引用统一目录。
- `TaskService.get_task_definitions()` 改为只消费目录服务结果，并继续从 `StarProgressionService` 附加食谱星辉数值，不再从其他配置合并任务定义。
- 保留任务奖励键的现有白名单并加入评级相关键；未知奖励键在配置校验中失败，不在领取时静默忽略。
- 将每日重置从硬编码 `_daily_task_definitions()` 改为按任务的 `reset_policy = "daily"` 处理。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-catalog-config.log" -s res://tests/task_catalog_config_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-daily-task.log" -s res://tests/daily_task_self_check.gd
```

## Task 2：扩展统一营业轮报告

**Files**

- Modify: `scripts/showcase_round_report_service.gd`
- Modify: `scripts/showcase_freshness_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `tests/showcase_round_report_service_self_check.gd`
- Create: `tests/showcase_task_round_report_self_check.gd`

**RED**

- 断言事件报告与重放报告都返回同名字段，不再因 `live_layout_changed` 分支产生不同任务口径。
- 断言报告包含 `report_id`、`round_id`、`kind`、`challenge_id`、`challenge_version`、`duration_ms`、环境快照、布局快照和完整性状态。
- 断言报告包含总成交、总金币、基础/环境/布局收益、连锁次数、补货次数与数量、待补货次数、八折余货、五折清仓和强制清仓数量。
- 断言布局统计包含占用格数、不同商品数、角色计数和标签计数，并来自营业开始时的锁定快照。
- 断言同一个结算 ID 生成稳定 `report_id`；重复应用不能追加第二份报告。
- 断言缺少必须字段的报告明确返回 `is_complete = false` 与 `missing_fields`，不能用默认零值误判挑战。

**GREEN**

- 在 `ShowcaseRoundReportService` 先建立共同基础报告，再由重放/事件分支只填充成交明细，最后统一计算派生指标。
- 让余货服务在结算结果中返回数量与收入两套字段，报告服务不从金币反推清仓件数。
- 从 `active_business_round` 读取挑战快照、环境、初始布局、角色和标签统计；报告只保存序列化安全的数组/字典值。
- `GameState.apply_showcase_round_settlement()` 只接收完整报告进入任务/挑战判定；不完整报告可以保存开发日志，但不得推进任务。
- 保持现有最近十份营业报告上限和结算幂等列表。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-report.log" -s res://tests/showcase_round_report_service_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-task-report.log" -s res://tests/showcase_task_round_report_self_check.gd
```

## Task 3：实现纯任务条件与铜银金评级服务

**Files**

- Create: `scripts/task_condition_service.gd`
- Create: `tests/task_condition_service_self_check.gd`
- Modify: `scripts/task_service.gd`

**RED**

- 断言条件服务支持从营业报告按点路径读取字段，例如 `layout.occupied_cells`、`counts.forced_clearance` 和 `products.<id>.sold_count`。
- 断言支持 `eq`、`gte`、`lte`、`contains`、`not_contains`、`all` 和 `any`；未知操作符返回无效结果而不是 false 成绩。
- 断言单条件、嵌套复合条件、角色/标签计数、不同商品数和连续轮次均可确定性求值。
- 断言评级始终返回最高已达等级、逐项达成状态、未达成原因和到下一等级的数值差。
- 断言报告不完整时返回 `valid = false`，不生成铜级或失败结果。
- 断言评价服务是纯函数，不修改任务进度、金币、奖励或挑战快照。

**GREEN**

- 实现 `evaluate_condition()`、`evaluate_condition_group()`、`evaluate_tiers()` 和稳定失败文案格式化。
- 条件结果统一包含 `field`、`operator`、`target`、`current`、`passed`、`gap` 和 `reason`。
- `TaskService` 保留教学事件计数与一次性任务状态；所有营业轮目标通过条件服务消费最终报告。
- 连续表现只消费由 `TaskService` 保存的历史结果摘要，不直接扫描 UI 日志或最近成交文案。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-condition-service.log" -s res://tests/task_condition_service_self_check.gd
```

## Task 4：统一挑战快照、真实结算与任务推进链

**Files**

- Modify: `scripts/showcase_challenge_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `scripts/main_view.gd`
- Modify: `game_data.json`
- Modify: `doc/showcase_round_rules.json`
- Modify: `tests/showcase_business_challenge_self_check.gd`
- Modify: `tests/showcase_business_challenge_runtime_self_check.gd`
- Create: `tests/showcase_task_challenge_runtime_self_check.gd`

**RED**

- 断言挑战列表来自 `game_data.json.tasks.round_contracts`，规则文件不再拥有第二套挑战名称和目标。
- 断言挑战快照保存任务 ID、任务版本、实例 ID、条件、评级、环境参数、当前开放商品集合和营业时长。
- 断言接受挑战后修改配置不会改变当前快照的结算条件。
- 断言完整路径“接受挑战 → 开始营业 → 完成结算 → 评价 → 写入任务结果”只执行一次。
- 断言挑战成功不再通过 `GameState.apply_showcase_challenge_result()` 直接重复发任务金币；保证金返还/扣除与可领取任务奖励分开处理。
- 断言挑战失败、报告无效和重复结算分别得到不同状态，并保留可执行原因。
- 断言旧的 `low_conflict_window` 等任务 ID 与 `sprint_sales` 等规则模板 ID 不再形成跨文件引用。

**GREEN**

- `ShowcaseChallengeService` 改为接收任务定义与环境规则，负责可用合同筛选、快照生成和评级，不再遍历规则文件中的 `challenge_templates`。
- `main_view.gd` 在完整结算报告生成并成功应用后，只调用一个任务/挑战结算协调入口。
- `GameState.apply_showcase_challenge_result()` 保存结果、幂等键和保证金结果；任务奖励仍由 `TaskService.claim_task_reward()` 发放。
- 将最终营业报告通过 `record_task_event("business_round_completed", report)` 或等价单入口交给 `TaskService`，删除需要手工伪造 `showcase_challenge` 事件的旧路径。
- 从规则文件删除挑战名称、任务目标和奖励，只保留挑战可引用的环境/时长/经济参数。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-business-challenge.log" -s res://tests/showcase_business_challenge_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-task-challenge-runtime.log" -s res://tests/showcase_task_challenge_runtime_self_check.gd
```

## Task 5：重建 Lv.0 完整营业教学

**Files**

- Modify: `game_data.json`
- Modify: `scripts/task_service.gd`
- Modify: `scripts/tutorial_progress.gd`
- Modify: `scripts/game_state.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/task_mainline_self_check.gd`
- Create: `tests/showcase_task_l0_route_self_check.gd`

**RED**

- 断言新游戏只显示第一个 Lv.0 教学步骤，后续步骤严格按前置任务开放。
- 断言 Lv.0 顺序覆盖：获得基础材料、制作首件、上架、查看售价/待售时间、开始营业、发生真实成交、完成余货处理与结算。
- 断言第一次上架不再立即设置 Lv.1；只有完整结算教学任务完成并领取/应用进度效果后才进入 Lv.1。
- 断言首轮没有成交时，教学不会伪完成，并明确引导检查库存、待售时间或重新营业。
- 断言教学奖励足以继续下一步骤，但不会重复发放。
- 断言后续等级任务不引用固定教学配方 ID。

**GREEN**

- 用新的 `tutorial_l0_*` 任务定义替换旧 Lv.0 三任务链，并将 `set_level = 1` 移到最终完整结算任务。
- 保留一个固定教学商品和现有最小生产链，确保教学确定性；固定商品只存在于 Lv.0 定义。
- 在玩家实际打开/聚焦商品销售条款时记录“查看售价与待售时间”，不以页面初始化代替真实交互。
- 从真实营业开始、真实成交和完整结算入口记录教学事件；不在自检专用代码中直接完成任务。
- 完成任务后继续使用现有任务通知与待领取奖励路径。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-task-l0-route.log" -s res://tests/showcase_task_l0_route_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-mainline-l0.log" -s res://tests/task_mainline_self_check.gd
```

## Task 6：交付 Lv.1–Lv.2 构筑课程

**Files**

- Modify: `game_data.json`
- Modify: `scripts/task_service.gd`
- Modify: `scripts/showcase_round_report_service.gd`
- Create: `tests/showcase_task_l1_l2_course_self_check.gd`
- Modify: `tests/task_mainline_self_check.gd`

**RED**

- 断言 Lv.1 依次教授：标准 30 秒营业、同款一轮售出两份、进入待补货并轮内补货、八折保留、五折清仓和无强制清仓评鉴。
- 断言 Lv.2 依次教授：两种不同商品角色、一次布局/连锁额外收益、限定格数收益、按可见环境调整和基础角色组合评鉴。
- 断言每个普通课程只包含一个核心概念；只有阶段评鉴允许复合条件。
- 断言任务条件不包含固定配方 ID，并且可以由该等级至少一组当前开放商品完成。
- 断言未达成时返回具体差距，例如缺少一次补货、超过两格或还差若干布局收益。
- 断言完成课程不会直接升级，也不会阻塞金币/口碑达到后的手动升级。

**GREEN**

- 在任务目录写入 Lv.1–Lv.2 完整课程、阶段评鉴、奖励和通知文案。
- 为报告补齐课程需要的待补货、补货、余货决策、角色组合和环境适配字段；所有字段仍从真实轮状态产生。
- 增加配置可完成性检查：根据等级开放的角色、标签、环境和商品集合验证任务不存在硬性死路。
- 将旧 Lv.1–Lv.2 顾客类型、指定设备制作和泛销量主线迁出；仍有价值的生产目标降为资源支线。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-task-l1-l2.log" -s res://tests/showcase_task_l1_l2_course_self_check.gd
```

## Task 7：交付 Lv.3–Lv.5 固定构筑评鉴与资源支线

**Files**

- Modify: `game_data.json`
- Modify: `scripts/task_service.gd`
- Modify: `scripts/ui/overlays/task_overlay.gd`
- Create: `tests/showcase_task_l3_l5_route_self_check.gd`
- Modify: `tests/task_mainline_self_check.gd`
- Modify: `tests/daily_task_self_check.gd`

**RED**

- 断言 Lv.3、Lv.4、Lv.5 各包含两项普通构筑挑战和一项阶段评鉴。
- 断言 Lv.3 只考查库存压力、待补货、轮内补货、余货和清仓控制。
- 断言 Lv.4 只考查多商品协同、连续成交、连锁或布局额外收入。
- 断言 Lv.5 只考查环境适配、限制格数、高收益和主题构筑。
- 断言这些任务不使用采集、制作、研发、指定顾客或指定配方完成条件。
- 断言原采集、生产、研发和自动化日常内容进入 `resource_side_tasks`，不成为阶段评鉴前置。
- 断言 Lv.1–Lv.5 升级仍只检查金币与累计口碑，且任务奖励没有 `set_level`。

**GREEN**

- 替换 Lv.3–Lv.5 旧主线任务和旧 `post_*` 任务，使用报告条件与铜银金评价。
- 资源支线保留每日重置与资源奖励，但类型改为 `resource`，UI 与主线分栏。
- 为每个阶段评鉴写出可解释的失败提示和下一评价差值。
- 删除“终章”“MVP 完成”“通关”等结束语义，Lv.5 只负责引导进入持续经营合同。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-task-l3-l5.log" -s res://tests/showcase_task_l3_l5_route_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-mainline-route.log" -s res://tests/task_mainline_self_check.gd
```

## Task 8：实现 Lv.6+ 三选一经营合同与门店评级

**Files**

- Modify: `game_data.json`
- Modify: `scripts/showcase_challenge_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `scripts/task_service.gd`
- Create: `tests/showcase_round_contract_self_check.gd`
- Modify: `tests/showcase_business_challenge_runtime_self_check.gd`

**RED**

- 断言 Lv.6+ 在没有待处理挑战时稳定生成三个不同、当前可完成的合同。
- 断言合同选择基于等级、当前开放机制和营业轮 ID，存取档后不会无故换题。
- 断言三个合同至少覆盖两种不同的构筑维度，不会全部退化为单纯金币目标。
- 断言合同具有铜、银、金三级评价，并保存每个合同版本的历史最高评价。
- 断言普通营业无需选择合同；只有主动选择后才生成挑战轮与合同评价。
- 断言合同完成后增加门店评级点数，同一报告不能重复增加；失败不倒扣长期评级。
- 断言合同奖励可领取，保证金只适用于显式 `risk = "high"` 的合同。

**GREEN**

- 在任务目录增加一组可复用合同模板、等级/机制可用条件、环境引用、评级目标、奖励和风险标记。
- 用确定性种子从可用模板生成三个选择；完成或失败并完成结算后才刷新下一组。
- 在 `GameState` 保存当前合同选择集、已选快照、合同最佳评级、门店评级点数和已应用报告 ID。
- 门店评级采用配置化阶梯 `I / II / III / IV / V`，每阶同时保存玩家可见称号；首版称号固定为“门店评级 I”至“门店评级 V”，后续可以只改配置替换文案，不改变评级状态结构。
- `TaskService` 负责合同奖励领取，挑战服务只负责选择、快照和评价。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-contract.log" -s res://tests/showcase_round_contract_self_check.gd
```

## Task 9：重组任务面板与营业前合同选择

**Files**

- Modify: `scenes/ui/overlays/task_overlay.tscn`
- Modify: `scripts/ui/overlays/task_overlay.gd`
- Modify: `scenes/ui/overlays/task_entry_button.tscn`
- Modify: `scripts/ui/overlays/task_entry_button.gd`
- Modify: `scenes/ui/overlays/task_detail_content.tscn`
- Modify: `scripts/ui/overlays/task_detail_content.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Create: `tests/showcase_task_overlay_self_check.gd`

**RED**

- 断言任务面板分为“主线课程 / 经营合同 / 资源支线 / 自动化 / 待领取”，不再把所有重复内容塞进旧“每日”页。
- 断言主线详情显示阶段、当前条件、前置状态和奖励；合同详情显示环境、铜银金目标、风险与选择按钮。
- 断言资源支线与主线分栏，资源支线完成或过期不会改变主线选中项。
- 断言 Lv.6+ 三个合同在营业前可见且只能选择一个；选择后显示已锁定快照摘要。
- 断言稳定面板、按钮和详情结构存在于 `.tscn`，脚本不在刷新时临时拼整页节点。
- 断言领奖、一键领取、任务选中和关闭弹窗仍沿用现有信号路径。

**GREEN**

- 更新任务筛选 ID、标签和分类映射，同时保留现有任务列表/详情/奖励轨道的场景结构。
- 扩展任务条目与详情组件，支持任务类型、评级目标、失败差距、合同风险和选择状态。
- 复用当前橱窗页“特殊挑战”区域作为营业前合同入口，不新增重复的独立挑战页面。
- `main_view.gd` 只提供数据与处理选择信号；筛选、条目和详情展示留在 overlay 脚本。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-task-overlay.log" -s res://tests/showcase_task_overlay_self_check.gd
```

## Task 10：交付营业中实时指标与结算评级说明

**Files**

- Modify: `scenes/ui/storefront/showcase_board.tscn`
- Modify: `scripts/ui/storefront/showcase_board.gd`
- Modify: `scenes/ui/overlays/showcase_round_settlement_dialog.tscn`
- Modify: `scripts/ui/overlays/showcase_round_settlement_dialog.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_round_ui_self_check.gd`
- Modify: `tests/showcase_round_settlement_dialog_self_check.gd`
- Create: `tests/showcase_task_feedback_ui_self_check.gd`

**RED**

- 断言营业前显示合同条件、当前布局静态条件检查和具体不满足原因。
- 断言营业中最多显示三个可变化指标，格式为“当前值 / 目标值”，且字段名与最终营业报告一致。
- 断言布局已锁定后不显示无法在营业中改变的冗余静态条件。
- 断言结算弹窗显示最高评价、逐项达成状态、下一评价和最小数值差。
- 断言失败结果显示可执行原因，不只显示“挑战失败”。
- 断言无合同的普通营业保持现有单页营业结算，不出现空评级区域。
- 断言反馈层不阻挡橱窗拖拽、补货或结算选择输入。

**GREEN**

- 在 `showcase_board.tscn` 增加稳定的 `TaskProgressPanel`，由 board 脚本接收最多三行格式化进度。
- 在结算弹窗场景增加稳定的评级摘要与条件明细区域，继续使用真实容器对齐。
- 增加纯展示格式化函数，接收条件服务结果；UI 不重新计算评级。
- `main_view.gd` 在营业前、营业中事件更新和结算后分别传递同一个挑战快照/评价结果。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-task-feedback-ui.log" -s res://tests/showcase_task_feedback_ui_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-settlement-dialog.log" -s res://tests/showcase_round_settlement_dialog_self_check.gd
```

## Task 11：删除旧语义并完成端到端回归

**Files**

- Modify: `scripts/task_service.gd`
- Modify: `scripts/showcase_challenge_service.gd`
- Modify: `scripts/main_view.gd`
- Modify: `game_data.json`
- Modify: `doc/showcase_round_rules.json`
- Modify: `doc/2026-07-05-progressive-unlock-route-and-tasks.md`
- Modify: `doc/2026-07-09-post-mvp-task-completion-plan.md`
- Modify: `doc/2026-07-10-developer-quick-reference.md`
- Modify: `tests/task_mainline_self_check.gd`
- Modify: `tests/mvp_self_check.gd`
- Create: `tests/showcase_task_end_to_end_self_check.gd`

**RED**

- 断言仓库不再包含运行时引用的旧 `post_rule_understanding`、`post_growth_showcase`、`post_signature_window`、`low_conflict_window`、`growth_showcase` 或 `summer_refreshing_set`。
- 断言主线不再包含“指定顾客购买”“研发若干次”“收获若干次”作为 Lv.3+ 完成条件。
- 断言端到端路径从新游戏走通 Lv.0 完整营业教学，并能构造 Lv.1、Lv.2、Lv.3–Lv.5 和 Lv.6+ 的代表性任务结果。
- 断言真实合同成功会推进任务并产生一次待领取奖励，失败会保存差距，重复结算不重复推进或发奖。
- 断言任务面板、营业中指标、结算弹窗和历史报告对同一轮给出一致数值。
- 断言金币/口碑升级、营业补货、余货处理、清仓、现有自动化任务和奖励领取回归不受破坏。

**GREEN**

- 删除 `TaskService` 中旧硬编码主线构造、旧挑战事件特判和仅供旧任务使用的辅助分支。
- 删除规则文件中的旧挑战任务模板与重复奖励配置。
- 将设计文档、开发者快速参考和后 MVP 计划同步到新任务目录、统一报告和阶段路线。
- 重写 `task_mainline_self_check.gd` 与 `mvp_self_check.gd` 中的旧任务 ID、旧终章语义和手工伪造挑战事件断言。
- 保留与新路线无关的自动化功能任务、奖励领取和通知能力。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-task-e2e.log" -s res://tests/showcase_task_end_to_end_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-mainline-final.log" -s res://tests/task_mainline_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-ui-final.log" -s res://tests/showcase_round_ui_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-completion-final.log" -s res://tests/showcase_completion_contract_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-mvp-task-route-final.log" -s res://tests/mvp_self_check.gd
```

```powershell
git diff --check
```

## Task 12：删除独立销售条款教学任务

**Files**

- Modify: `game_data.json`
- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_task_l0_route_self_check.gd`
- Modify: `tests/task_catalog_config_self_check.gd`
- Modify: `tests/task_mainline_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**RED**

- 断言 Lv.0 只保留“采集 → 制作 → 上架 → 开始营业 → 真实成交 → 完成结算”六个任务。
- 断言任务目录中不存在 `tutorial_l0_inspect_terms`，也不存在消费 `showcase_terms_viewed` 的任务。
- 断言完成上架后直接开放 `tutorial_l0_start_round`，随后的 `business_round_started` 事件立即完成它。

**GREEN**

- 从任务目录删除 `tutorial_l0_inspect_terms`，将 `tutorial_l0_start_round` 的前置改为 `tutorial_l0_list`。
- 将上架完成提示改为直接引导开始营业。
- 删除橱窗悬停路径对 `showcase_terms_viewed` 的记录，不增加替代提示、按钮限制或存档迁移。
- 同步所有 Lv.0 路线自检与端到端序列。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-task-l0-route.log" -s res://tests/showcase_task_l0_route_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-catalog-config.log" -s res://tests/task_catalog_config_self_check.gd
```

## Task 13：统一任务筛选 ID 契约

**Files**

- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_task_overlay_self_check.gd`

**RED**

- 通过真实主视图回调依次切换五个任务分类，断言 `selected_task_filter` 与按钮发出的新 ID 一致。
- 从空的自动化分类切回主线和资源分类后，任务列表和右侧详情必须恢复内容。

**GREEN**

- 删除 `main_view.gd` 中遗留的旧任务筛选白名单及入口拦截。
- `TaskOverlay` 继续作为五个筛选 ID 和显示标签的唯一来源；主视图只保存当前选择并刷新。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-task-overlay.log" -s res://tests/showcase_task_overlay_self_check.gd
```

## 最终验收

- 新玩家在 Lv.1 前已经完成一次真实“制作 → 上架 → 营业 → 结算 → 余货处理”闭环。
- Lv.1–Lv.2 的每个课程只教授一个构筑概念，阶段评鉴才组合条件。
- Lv.3–Lv.5 主线完全由构筑挑战组成，采集、制作、研发只存在于资源支线。
- Lv.6+ 每次提供三个当前可完成的合同，玩家可选择、结算、获得铜银金评价并推进门店评级。
- 任务、挑战、营业中进度、结算弹窗和历史记录使用同一份营业报告与条件求值结果。
- 不存在旧挑战 ID 漂移、手工伪造挑战事件或重复发奖路径。
- 店铺升级仍只依赖金币与累计口碑，任务不会用指定配方阻塞升级。
- 所有聚焦自检、相关回归、`mvp_self_check.gd` 和 `git diff --check` 通过。
