# 任务系统精简实施计划

**目标：** 把当前 6 个教学任务、20 个 Lv.1～Lv.5课程/评鉴和 5 个任务页签，替换为 3 个带子目标的教学任务、7 个成长任务和“当前目标 / 支线任务”两个页签；任意时刻只曝光 1 个当前目标与最多 3 个支线任务，铜银金只保留在 Lv.6+可重复经营合同。

**依据：** `docs/superpowers/specs/2026-07-15-task-system-simplification-design.zh.md`

**实施原则：**

- 每项行为变更按 RED → GREEN → REFACTOR 执行：先写会因目标能力缺失而失败的聚焦自检，再写最小实现，最后清理重复代码。
- 从 `D:\Project\ProjectRest\project-rest-new` 运行 Godot；所有 headless 命令显式传入可写的`--log-file`。
- `game_data.json.tasks`是任务定义唯一真相；任务服务不得重新硬编码第二份教学或成长路线。
- 营业类子目标和 Lv.3～Lv.5挑战继续读取统一营业报告，不在任务服务中另算营业指标。
- 稳定页签、详情区、子目标列表和按钮结构写入`.tscn`；脚本只做数据绑定、刷新和信号协调。
- 项目处于开发阶段，不实现旧任务 ID、旧进度、旧每日选择或旧页签的存档迁移；验证使用新存档。
- 工作区已有其他未提交修改。实施只触碰本计划列出的任务相关文件，逐项检查差异，不覆盖无关改动，不自动提交 Git。

## Task 1：替换任务目录并强化配置校验

**Files**

- Modify: `game_data.json`
- Modify: `scripts/task_catalog_service.gd`
- Modify: `tests/task_catalog_config_self_check.gd`

**RED**

- 将目录自检改为只接受`tutorial_tasks`、`growth_tasks`、`round_contracts`、`side_tasks`四个分组。
- 断言目录恰好有 3 个教学任务和 7 个成长任务，且不存在旧分组`build_courses`、`stage_evaluations`、`resource_side_tasks`。
- 断言旧 6 个教学 ID、15 个课程 ID 和 5 个评鉴 ID 不再出现在运行时目录。
- 断言带`objectives`的任务允许省略任务级单条件，但每个子目标必须有唯一 ID、玩家可见标题、事件、结构化条件和正目标值。
- 断言子目标即时效果只允许使用既有流程解锁键；普通金币、口碑和星辉不能放在子目标效果中。
- 断言教学和成长任务包含`tiers`或`required_tier`时配置失败；合同缺少合法铜银金递进目标时配置失败。
- 断言所有前置任务存在且不形成循环，所有营业报告字段、奖励键和自动化任务引用有效。
- 断言新任务奖励总量和规格一致，自动化星辉映射只引用新教学/成长 ID。

**GREEN**

- 将`TaskCatalogService.CATEGORIES`改为四个新分组；类型收敛为`tutorial`、`growth`、`contract`、`daily`、`feature`。
- 校验器支持两种任务形态：非空`objectives`数组，或现有单事件/单条件任务；为子目标执行 ID、事件、目标、条件和即时效果校验。
- 对教学/成长任务拒绝评级字段，对合同继续复用现有递进评级校验。
- 增加前置关系环检测；缺失引用和环都返回包含任务 ID 的明确错误。
- 用规格中的 3 个教学、7 个成长、现有 5 个合同和现有 9 个支线定义重写`game_data.json.tasks`。
- 将`automation.starlight_rewards.tasks`映射为新 ID：最终教学 2，Lv.1余货决策 3，Lv.2紧凑构筑 4，Lv.3库存 4，Lv.4连锁 5，Lv.5招牌 6。
- 保留`feature_output_automation`和`feature_kitchen_automation` ID，使自动化配置与自动化中枢现有引用继续有效。

**REFACTOR**

- 删除只为旧五分组、旧课程类型和旧评鉴类型服务的常量与校验分支。
- 保留统一的报告条件递归校验和合同评级递进校验，不复制求值逻辑。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-catalog-simplification.log" -s res://tests/task_catalog_config_self_check.gd
```

## Task 2：实现子目标进度、即时效果与幂等完成

**Files**

- Create: `tests/task_objective_progress_self_check.gd`
- Modify: `scripts/task_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `scripts/tutorial_progress.gd`

**RED**

- 断言采集事件只勾选“完成第一份商品”的采集子目标、立即解锁圆锅，但不会完成整张任务或产生待领取金币。
- 断言随后制作商品才完成整卡，生成 50 金币待领取奖励。
- 断言重复采集、重复制作或重复发送同一营业报告不会重复触发即时效果、重复完成任务或重复发奖。
- 断言不同子目标可以跨事件、跨营业轮保存；一个含多个报告指标的复合子目标必须由同一份完整报告同时满足。
- 断言不完整、缺字段或重复应用的营业报告不能推进营业类子目标。
- 断言`task_progress`保存每个子目标的计数、目标与完成状态，经过`to_dict()`/`from_dict()`后保持一致。
- 断言单条件日常、自动化任务、Lv.3～Lv.5挑战和合同仍沿用现有进度路径。

**GREEN**

- 在`TaskService.apply_event()`中先判断任务是否使用`objectives`；只更新接受当前事件的未完成子目标。
- 使用`task_progress[task_id].objectives[objective_id]`保存子目标进度，并用完成子目标数生成整卡`count/goal`摘要。
- 子目标完成时写入幂等完成标记，然后应用允许的即时流程效果；圆锅开放走现有设备解锁接口。
- 所有子目标完成后调用一次现有`_complete_task()`；任务级金币、口碑、星辉与等级效果仍按现有“完成生效 / 领取发奖”边界处理。
- 更新`GameState._sanitize_task_progress()`以保存嵌套子目标进度和现有自动化专用字段；只做新结构读取，不添加旧 ID 迁移。
- 删除`tutorial_progress.gd`中不再使用的旧任务 ID 常量，保留真实采集、制作、上架事件入口。
- 扩展`format_task_progress_detail()`，为带子目标任务返回“已完成 X/Y 项”，并提供每项勾选状态给 UI。

**REFACTOR**

- 将“单条件进度”和“子目标进度”分成小型私有函数，避免继续扩大`apply_event()`主体。
- 即时效果复用现有流程解锁函数，任务级奖励继续复用既有领取函数。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-objective-progress.log" -s res://tests/task_objective_progress_self_check.gd
```

## Task 3：限制当前目标与支线曝光数量

**Files**

- Create: `tests/task_visibility_selection_self_check.gd`
- Modify: `scripts/task_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `tests/daily_task_self_check.gd`
- Modify: `tests/automation_task_progress_self_check.gd`

**RED**

- 断言新游戏只曝光第一张教学卡；后续教学和成长任务即使等级满足，也不会并列出现。
- 断言完成当前任务后，下一张满足最低等级的任务自动成为唯一当前目标，不要求先领取上一张奖励。
- 断言玩家等级高于路线进度时仍显示最前面的未完成成长任务；成长路线全部完成后才开放 Lv.6+合同位置。
- 断言每日刷新周期从符合条件的日常定义中稳定选择最多 2 个；同一周期反复刷新、保存读取和完成任务后都不补位、不重抽。
- 断言未被选中的日常任务不会接收事件、不会完成，也不计入活动任务数量。
- 断言新刷新周期清理全部日常完成、领取与进度状态，并生成新的稳定选择；非日常任务不受影响。
- 断言符合条件的自动化任务最多追加 1 个，多个同时可用时选择排序最前者。
- 断言任务快照分别返回`current_entries`、`side_entries`、`claimable`、当前/支线空状态文案和`current_slot_count`；当前位置为 0 或 1，支线为 0～3。

**GREEN**

- 在`GameState`新增`daily_task_selected_ids`，加入新游戏初始化、保存输出、读取清洗和每日刷新重置。
- 每日选择使用“符合条件任务稳定排序 + 日键确定性起点 + 循环取最多 2 个”；一旦写入状态，本周期不因可用集合变化而重抽。
- 将任务选择拆为：最前未完成教学/成长、已选合同、已选日常、首个自动化功能任务。
- `TaskService.apply_event()`只遍历当前可处理任务：唯一教学/成长目标、已选合同、已选日常和曝光的自动化任务。
- 将`get_visible_tasks()`保留为当前与支线条目的兼容并集；新的 UI 和顶部计数只消费结构化任务快照。
- 待领取任务不进入当前或支线列表；前置判断仍基于“已完成”而不是“已领取”。

**REFACTOR**

- 把每日选择、当前路线选择、支线选择和可处理 ID 集合拆成独立纯函数，确保列表展示与事件推进使用同一选择结果。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-visibility-selection.log" -s res://tests/task_visibility_selection_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-daily-task-selection.log" -s res://tests/daily_task_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-automation-task-side.log" -s res://tests/automation_task_progress_self_check.gd
```

## Task 4：把任务面板收敛为两个页签

**Files**

- Create: `scenes/ui/overlays/task_objective_row.tscn`
- Create: `scripts/ui/overlays/task_objective_row.gd`
- Modify: `scenes/ui/overlays/task_overlay.tscn`
- Modify: `scripts/ui/overlays/task_overlay.gd`
- Modify: `scenes/ui/overlays/task_detail_content.tscn`
- Modify: `scripts/ui/overlays/task_detail_content.gd`
- Modify: `scripts/ui/overlays/task_entry_button.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_task_overlay_self_check.gd`
- Modify: `tests/task_bulk_claim_self_check.gd`

**RED**

- 断言任务面板只声明`current`和`side`两个筛选 ID，显示“当前目标”“支线任务”，不存在合同、自动化、待领取独立页签。
- 断言当前页只显示当前任务；合同阶段未选择时显示 3 个候选条目但摘要`当前目标`仍计为 1，选择后只显示已锁定合同。
- 断言支线页最多显示 2 个日常和 1 个自动化任务。
- 断言详情场景拥有稳定子目标列表容器，每个子目标行显示未完成/已完成、名称和当前值；脚本不临时拼整页结构。
- 断言普通教学/成长/支线详情不显示铜银金，合同详情继续显示评级目标。
- 断言完成任务立即从列表消失，待领取任务只影响顶部“一键领取奖励（N）”，不再作为列表条目或页签。
- 断言顶部摘要严格显示`当前目标 N｜支线 N｜待领取 N`，数量来自结构化快照，不读取所有可用定义。
- 断言当前路线等待等级、Lv.6合同待选和支线全部完成分别显示规格中的明确空状态，不再显示笼统“暂无任务”。
- 断言切换空页再返回不会丢失任务列表和详情；主视图接受两个新筛选 ID，不保存旧白名单。

**GREEN**

- 将`TaskOverlay.TASK_FILTER_ORDER`改为`["current", "side"]`，由该组件继续作为筛选 ID 和标签唯一来源。
- 将稳定子目标列表容器加入`task_detail_content.tscn`，使用独立`task_objective_row.tscn`实例化可变数量行。
- 任务条目类型标签收敛为教学、成长、合同、日常、自动化；子目标进度优先显示“X/Y 项”。
- 详情按钮行为收敛为“前往”或“选择合同”；移除单任务领取入口，所有任务奖励只从顶部统一领取。
- `main_view.gd`默认筛选改为`current`；刷新时构建一次任务快照，并用快照计数更新顶部摘要。
- 当成长路线已完成且等级达到 Lv.6 时，主视图把现有`_showcase_contract_choices()`结果传入任务快照；合同候选复用现有接受合同方法。
- 接受合同后立即刷新任务面板、橱窗挑战区和保存状态；普通营业仍不强制选择合同。
- 清除旧“进行中 / 弹窗提示”摘要和旧五分类映射。

**REFACTOR**

- `TaskOverlay`只做筛选、列表与详情绑定；合同选择和页面跳转仍由主视图处理。
- 保留现有任务筛选按钮、条目按钮和详情场景的复用关系，不在`main_view.gd`动态创建任务 UI。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-overlay-two-tabs.log" -s res://tests/showcase_task_overlay_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-bulk-claim-simplified.log" -s res://tests/task_bulk_claim_self_check.gd
```

## Task 5：走通 3 个教学任务与 7 个成长任务

**Files**

- Create: `tests/showcase_task_growth_route_self_check.gd`
- Modify: `tests/showcase_task_l0_route_self_check.gd`
- Modify: `tests/task_mainline_self_check.gd`
- Modify: `tests/showcase_task_end_to_end_self_check.gd`
- Modify: `tests/mvp_self_check.gd`
- Modify: `scripts/main_view.gd`

**RED**

- 断言真实“采集 → 制作 → 上架 → 开始营业 → 真实成交 → 完整结算”依次完成 3 张教学卡，结算前保持 Lv.0，最终教学完成后进入 Lv.1。
- 断言没有真实成交的结算不能完成最终教学；查看售价或待售时间不是任务事件、前置或提示。
- 断言 Lv.1销售节奏和余货决策、Lv.2基础组合和紧凑构筑的子目标可由真实营业报告逐项完成。
- 断言 Lv.3库存压力只在同一轮同时达到“售出 7、补货 2、强制清仓不超过 1”时完成。
- 断言 Lv.4连锁效率只在同一轮同时达到“3 种商品、2 次连锁、60 额外收益”时完成。
- 断言 Lv.5招牌构筑只在同一轮同时达到“不超过 9 格、3 件共享主题、300 金币”时完成。
- 断言 7 个成长任务均没有评级字段；同样报告仍可让已选择的 Lv.6合同得到铜银金评价。
- 断言玩家达到 Lv.6但未完成成长路线时仍显示最前成长目标；全部完成后显示合同选择入口。
- 断言合并任务领取后得到规格确定的金币、口碑和星辉总量，且 Lv.1以后没有`set_level`。

**GREEN**

- 按真实事件入口修正教学推进，不增加仅供测试使用的完成分支。
- 确认统一营业报告已包含 7 个成长任务使用的全部字段；如字段缺失，只补报告生成，不在任务服务重算。
- 为 Lv.1～Lv.2子目标保留跨轮进度，为 Lv.3～Lv.5使用单个复合报告条件。
- 更新新任务完成提示和下一步文案，Lv.5完成后明确进入 Lv.6合同循环。
- 确保合同选择、合同评价和门店评级仍沿用现有`ShowcaseChallengeService`与`GameState`幂等路径。

**REFACTOR**

- 删除主视图、任务服务和教程桥接中仅引用旧教学/课程/评鉴 ID 的分支。
- 不改变统一营业报告和合同服务中与本次精简无关的算法。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-l0-three-cards.log" -s res://tests/showcase_task_l0_route_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-growth-route.log" -s res://tests/showcase_task_growth_route_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-mainline-simplified.log" -s res://tests/task_mainline_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-contract-e2e.log" -s res://tests/showcase_task_end_to_end_self_check.gd
```

## Task 6：清理旧契约并完成任务回归

**Files**

- Modify: `tests/automation_task_progress_self_check.gd`
- Modify: `tests/daily_task_self_check.gd`
- Modify: `tests/task_bulk_claim_self_check.gd`
- Modify: `tests/showcase_task_overlay_self_check.gd`
- Modify: `tests/task_catalog_config_self_check.gd`
- Modify: `tests/task_mainline_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**RED**

- 扫描运行代码、场景、`game_data.json`和任务自检，断言不存在旧教学、课程、评鉴 ID、旧五分组或`main_course`筛选 ID。
- 断言自动化中枢仍能读取两个功能任务的进度，但任务面板将它们显示在“支线任务”。
- 断言一键领取可以一次领取多张已完成新任务的奖励，领取后按钮、顶部角标和待领取集合同时归零。
- 断言日常刷新不会清除教学、成长、合同或自动化任务状态。
- 断言任务面板、任务按钮角标、合同选择区和自动化中枢对同一状态给出一致结果。
- 断言所有任务相关聚焦自检与 MVP 自检使用新目录和新页签契约。

**GREEN**

- 更新所有仍引用旧 ID、旧数量、旧分类和旧奖励合计的任务测试。
- 删除运行时旧筛选字符串、旧类型标签和旧评鉴专用展示分支；合同评级展示保留。
- 只根据实际聚焦测试失败修正任务范围内的遗漏，不扩展到无关 UI 或营业系统重构。

**REFACTOR**

- 用一次`rg`确认旧运行契约只允许出现在历史设计文档的说明中，不出现在运行代码、场景、配置或测试中。
- 运行`git diff --check`并人工确认未覆盖工作区中原有无关修改。

**Verify**

```powershell
$tests = @(
  'task_catalog_config_self_check.gd',
  'task_objective_progress_self_check.gd',
  'task_visibility_selection_self_check.gd',
  'showcase_task_l0_route_self_check.gd',
  'showcase_task_growth_route_self_check.gd',
  'task_mainline_self_check.gd',
  'daily_task_self_check.gd',
  'automation_task_progress_self_check.gd',
  'showcase_task_overlay_self_check.gd',
  'task_bulk_claim_self_check.gd',
  'showcase_task_end_to_end_self_check.gd',
  'mvp_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-$test.log" -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

```powershell
rg -n 'tutorial_l0_(gather|craft|list|start_round|real_sale|settle)|course_l[12]_|build_l[345]_|evaluation_l[1-5]_|main_course|stage_evaluations|build_courses|resource_side_tasks' scripts scenes tests game_data.json
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-task-simplification-import.log" --quit
```

```powershell
git diff --check
```

## 最终验收

- 新游戏只看到 1 张教学卡，并能通过真实完整经营闭环完成 3 张教学卡进入 Lv.1。
- Lv.1～Lv.2各有 2 张带子目标的成长卡；Lv.3～Lv.5各有 1 张单一完成标准的综合构筑挑战。
- 任意时刻`当前目标`为 0 或 1 个位置，`支线任务`最多 3 个，未选日常不推进也不计数。
- 任务面板只存在“当前目标”“支线任务”两个页签；“待领取”只存在于顶部统一领取按钮。
- 顶部摘要与实际条目一致，不再出现“进行中 7”但列表为空。
- 教学和成长任务没有铜银金；Lv.6+可重复合同继续使用铜银金并可正常选择、评价和领奖。
- 子目标即时效果、整卡完成、待领取和批量领取均幂等。
- 新任务配置、状态保存、自动化解锁、营业报告、合同流程和相关 Godot 自检全部通过。
