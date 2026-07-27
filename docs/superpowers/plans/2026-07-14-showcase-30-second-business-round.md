# 橱窗 30 秒标准营业轮实施计划

**目标：** 把当前按绝对时间常驻、支持离线补算的橱窗售卖，替换为可暂停、可复盘的 30 秒标准营业轮；支持轮内同款补货、8 折余货、5 折主动清仓、1 折强制清仓，并在第二阶段加入热度连锁、市场/天气/节日环境和特殊挑战。

**依据：** `docs/superpowers/specs/2026-07-14-showcase-30-second-business-round-design.zh.md`

**实施原则：**

- 所有行为改动遵循 RED -> GREEN -> REFACTOR；先写会因目标能力缺失而失败的聚焦自检，再写最少实现。
- 运行测试时必须从包含 `project.godot` 的目录执行，并给 Godot 传入可写的 `--log-file`。
- 保留现有左侧橱窗、右侧控制台和拖拽交互主结构；稳定节点、表格和弹窗内容优先写在 `.tscn`，脚本只负责状态绑定、信号和刷新。
- 橱窗布局、批次库存、活动营业轮和待处理结算只能各有一个经济真相；不得保留第二套常驻售卖或离线售卖字段。
- 本计划不自动提交 Git；每个阶段验证后先检查工作区差异。

## 总体阶段

### 阶段 A：基础可玩闭环

完成 Task 1-7 后，玩家可以调整布局、补货、开始固定 30 秒营业、营业中补入同款、看到独立销售进度、结算并逐项选择 5 折清仓或 8 折保留；上轮 8 折余货未售完会自动 1 折清仓。

### 阶段 B：布局深度

完成 Task 8-11 后，营业轮具备稳定环境、热度、角色、确定性连锁、特殊挑战和可复算的收益归因。

### 阶段 C：表现与旧路径收口

完成 Task 12-14 后，右侧经营页、左侧反馈、结算弹窗和离线范围全部统一到新语义，旧的常驻/离线橱窗销售服务与测试被删除。

## Task 1：统一 12 x 14 坐标真相与营业轮配置

**Files**

- Create: `doc/showcase_round_rules.json`
- Modify: `doc/display_rules_full.json`
- Modify: `scripts/catalog.gd`
- Modify: `scripts/shop_simulation.gd`
- Modify: `scripts/showcase_challenge_service.gd`
- Create: `tests/showcase_round_config_self_check.gd`
- Modify: `tests/showcase_bonus_reason_self_check.gd`
- Modify: `tests/storefront_grid_layout_self_check.gd`

**RED**

- 断言营业轮配置包含 `standard_duration_seconds = 30`、快/中/慢三档范围、环境强度上限、热度上限和连锁深度上限。
- 断言橱窗规则元数据为 12 行、14 列、168 格，不再出现 5 x 10 或 100 格口径。
- 断言区域规则的行列范围均落在 12 x 14 内，位置判断按 `Vector2i(x, y)` 与 1 基配置坐标正确换算。
- 断言利用率按当前已开放格数计算，初始中心 6 x 6 的满占用为 100%，而不是除以 100 或 168。
- 断言每个可售配方都能从形状模板得到 4-25 秒内的基础销售周期；少量配方覆盖值仍需落在对应档位。

**GREEN**

- 在 `showcase_round_rules.json` 集中声明标准时长、形状到基础周期/角色的模板、少量招牌覆盖、热度/连锁参数、环境模板和挑战模板。
- 更新 `display_rules_full.json` 的元数据与区域范围，使区域规则真正覆盖 12 x 14 棋盘；保留现有相邻、套装和冲突规则 ID。
- 为 `Catalog` 增加 `get_showcase_round_rules()`，配置缺失或非法时返回空字典并由上层使用安全默认值。
- 把 `ShowcaseChallengeService._grid_utilization_score()` 改为使用已开放格数量；不在该服务内硬编码 100。
- 保持 `GameState.DISPLAY_GRID_ROWS/COLUMNS`、`Main.tscn` 的 14 列和 168 格为棋盘真相。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-config.log" -s res://tests/showcase_round_config_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-bonus-reason.log" -s res://tests/showcase_bonus_reason_self_check.gd
```

## Task 2：建立可暂停的营业轮状态机

**Files**

- Create: `scripts/business_round_service.gd`
- Create: `tests/business_round_service_self_check.gd`

**RED**

- 断言标准轮固定为 30 秒，特殊挑战时长只能来自挑战定义。
- 断言状态只允许 `adjusting -> running -> settlement -> adjusting`，不能跳过待处理结算开始新轮。
- 断言运行时间按注入的在线 `delta` 推进，不读取系统绝对时间计算离线跨度。
- 断言恰好到结束时刻的事件可处理，结束时刻之后的事件被拒绝。
- 断言暂停、存档和载入不会推进剩余时间、热度、环境或挑战。
- 断言同一轮 ID、种子和状态重复执行不会生成第二次结算。

**GREEN**

- 实现纯状态机 API：`create_round()`、`start_round()`、`advance()`、`pause()`、`resume()`、`begin_settlement()`、`complete_settlement()`。
- 轮内时间统一用毫秒整数保存：`duration_ms`、`elapsed_ms`、`remaining_ms`；UI 再格式化为秒，避免浮点边界漂移。
- 活动轮至少保存：

```gdscript
{
    "round_id": 1,
    "kind": "standard",
    "phase": "running",
    "duration_ms": 30000,
    "elapsed_ms": 0,
    "heat": 0,
    "environment": {},
    "challenge": {},
    "layout_snapshot": {},
    "item_states": {},
    "refill_events": [],
    "sale_events": []
}
```

- 服务只返回确定性状态和事件，不直接修改 `GameState`、金币、UI 或文件。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-business-round-service.log" -s res://tests/business_round_service_self_check.gd
```

## Task 3：实现批次库存、独立销售周期与轮内补货

**Files**

- Create: `scripts/showcase_round_sale_service.gd`
- Create: `tests/showcase_round_sale_service_self_check.gd`

**RED**

- 断言商品分别按自身周期成交，15 秒商品在 30 秒内恰好成交 2 次。
- 断言未完成周期在轮末作废，不带入下一轮。
- 断言同一时刻多件商品按锚点升序、再按配方 ID 处理。
- 断言 `carried_stock` 始终先于 `fresh_stock` 扣减，8 折价格为正常最终成交价乘 80%。
- 断言数量归零后进入 `waiting_for_refill`，不会继续推进周期，也不会生成“缺货损失”。
- 断言活动商品补货不重置当前周期；待补货商品补入后从补货时刻开始完整周期。
- 断言补货事件保存实际 `elapsed_ms`、配方 ID 和数量，供结算归因重放。
- 断言第 30 秒的自然成交及其即时事件被纳入，正向时间效果不能越过结束线。

**GREEN**

- 使用每个布局实例的轮内状态：`cycle_elapsed_ms`、`cycle_duration_ms`、`carried_stock`、`fresh_stock`、`waiting_for_refill`。
- 实现 `build_item_states()`、`advance_items()`、`refill_item()` 和稳定事件排序。
- 纯服务只产出成交事件和下一状态；金币、口碑、成长、任务写入由运行时适配层统一完成。
- 删除“理论成交数减实际成交数”等损失计算；预计成交档位仅作为库存持续充足时的预览。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-sale.log" -s res://tests/showcase_round_sale_service_self_check.gd
```

## Task 4：实现余货保留与清仓服务

**Files**

- Create: `scripts/showcase_freshness_service.gd`
- Create: `tests/showcase_freshness_service_self_check.gd`

**RED**

- 断言轮末未售出的 `carried_stock` 自动按基础售价 10% 清仓并清零。
- 断言每个布局实例的 `fresh_stock` 可以独立选择 `clear_50` 或 `carry_80`。
- 断言 5 折和 1 折均按基础售价计算，不应用市场、布局、成长、变体或连锁加成。
- 断言清仓不产生口碑、配方成长、任务、订单、挑战或热度进度。
- 断言同一批商品最多跨一轮，`carried_stock` 不能再次保留。
- 断言重复提交相同结算 ID 返回零收益，不重复发放金币。

**GREEN**

- 实现 `prepare_settlement()`、`quote_fresh_decision()`、`apply_decisions()`。
- 结算先生成不可变报价，再由玩家逐项选择；应用时校验轮 ID、布局实例和报价版本。
- 对整数价格严格使用设计规格中的 `floor(基础售价 x 折扣)`，不额外应用售价或布局修正。
- 清仓完成后保留布局实例，批次数量为 0，显示 `待补货`。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-freshness.log" -s res://tests/showcase_freshness_service_self_check.gd
```

## Task 5：让 GameState 持有唯一营业轮与批次真相

**Files**

- Modify: `scripts/game_state.gd`
- Modify: `scripts/save_system.gd`
- Create: `tests/showcase_business_round_state_self_check.gd`
- Modify: `tests/showcase_sale_feedback_self_check.gd`

**RED**

- 断言 `display_items` 只保存布局、变体和批次库存，不再保存绝对销售到期时间。
- 断言 `active_business_round`、`pending_showcase_settlement`、`business_round_id` 和最近轮报告能序列化、清洗并往返恢复。
- 断言活动轮载入后保持原 `elapsed_ms`，不会使用 `last_saved_at_unix` 推进。
- 断言旧开发存档中的 `stock` 被一次性吸收为 `fresh_stock`，旧 `sale_ready_at_unix`、`cycle_started_at_unix` 和 `cycle_paused_progress` 被丢弃。
- 断言已完成成交与结算 ID 幂等，重新载入不会重复记账。
- 断言单笔成交不会增加 `business_runs`；一次营业轮完成余货处理后只增加 1，表示一个营业日。
- 断言移除布局时只退回可正常回仓的批次；营业中与待结算阶段禁止移除布局。

**GREEN**

- 将 `display_items` 收敛为：`cells`、`variant_id`、`fresh_stock`、`carried_stock`，可额外保留不参与计时的配方展示元数据。
- 增加活动轮、待结算和报告字段，以及小型清洗/序列化函数；不引入另一套常驻计时字段。
- 给 `GameState` 增加原子入口：轮内补货、应用真实成交、应用清仓、完成营业轮、保存轮报告；这些入口负责金币、口碑、成长、任务和日志的一致性。
- `business_runs` 只在完成一轮余货处理时增加 1，不再随商品成交数量累加。
- `SaveSystem.load_game()` 仍只根据绝对时间推进允许离线的产地系统，活动营业轮原样恢复。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-state.log" -s res://tests/showcase_business_round_state_self_check.gd
```

## Task 6：接入 30 秒运行循环、锁布局和轮内补货

**Files**

- Modify: `scenes/ui/storefront/showcase_board.tscn`
- Modify: `scripts/ui/storefront/showcase_board.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Create: `tests/showcase_business_round_scene_self_check.gd`
- Modify: `tests/showcase_auto_sale_service_self_check.gd`
- Modify: `tests/showcase_drag_preview_perf_self_check.gd`

**RED**

- 断言左侧橱窗场景声明营业状态、环境摘要、30 秒倒计时、热度条和“开始营业”按钮，不由 `main_view.gd` 临时创建。
- 断言调整阶段可移动、旋转、改变变体和放置陈列道具；营业阶段这些操作被拒绝并显示明确原因。
- 断言营业阶段仍可把同款成品拖到原布局实例补货，补货后库存与进度立即刷新。
- 断言 `_process(delta)` 每帧推进活动轮，但产地的一秒刷新节流不会提前返回并阻断营业轮。
- 断言开始营业时锁定布局快照、最终周期和本轮环境；中途切换右侧页面不影响倒计时。
- 断言运行中退出前保存活动轮，载入后从原剩余时间继续。
- 断言启动和在线 `_process()` 都不再调用旧 `_settle_showcase_sales()`，离线时间不会产生橱窗成交。

**GREEN**

- 在 `showcase_board.tscn` 增加稳定的 `RoundControlBar`：状态标签、环境摘要、倒计时、热度条、开始按钮；保留 `ShowcaseGrid` 直接路径。
- `showcase_board.gd` 只发出开始轮、补货提示等信号，不持有经济状态。
- 将 `main_view.gd._process()` 拆成每帧营业轮推进和每秒产地/UI 刷新两条路径，取消当前同一秒直接 `return` 对营业轮的影响。
- 开始轮时从 `ShowcaseRuleService`、配置和当前布局生成不可变销售条款快照。
- 营业阶段的拖拽仅允许命中同配方布局实例并调用轮内补货；移动、旋转、变体和道具操作统一返回“营业中布局已锁定”。
- 每次真实成交、补货、整秒检查点和阶段切换保存活动状态；不要每帧写盘。
- 从 `_ready()` 和 `_process()` 移除旧常驻/离线橱窗结算调用；旧服务文件可以留到 Task 13 统一删除，但从本任务起不得再有运行时引用。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-scene.log" -s res://tests/showcase_business_round_scene_self_check.gd
```

## Task 7：交付基础结算弹窗与余货决策闭环

**Files**

- Create: `scenes/ui/overlays/showcase_round_settlement_dialog.tscn`
- Create: `scripts/ui/overlays/showcase_round_settlement_dialog.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Create: `tests/showcase_round_settlement_scene_self_check.gd`

**RED**

- 断言倒计时结束后进入真实居中弹窗，活动轮不能自动跳回调整阶段。
- 断言弹窗第一层显示总金币、基础成交收入、清仓收入、总成交数和贡献最高商品。
- 断言商品明细使用真实 `GridContainer` 表格，不用空格字符模拟列对齐。
- 断言每个有新鲜余货的布局实例都必须选择“5 折清仓”或“下轮 8 折”，未完成选择时确认按钮禁用并说明原因。
- 断言上轮 8 折余货在弹窗打开前已按 1 折列入强制清仓明细，不再提供保留选项。
- 断言确认后金币只发放一次、批次正确转换、下一轮环境才允许生成。
- 断言确认一次标准轮或特殊挑战轮只增加 1 个 `business_runs`，重复确认不增加。

**GREEN**

- 弹窗场景固定声明摘要区、贡献商品区、明细表头/滚动区、余货决策区和确认按钮。
- 脚本接收只读报价与报告，逐行绑定数据并发出一次 `settlement_confirmed(decisions)` 信号。
- `main_view.gd` 负责调用 `ShowcaseFreshnessService`、原子应用结果、保存并返回调整阶段。
- 阶段 A 完成时运行一次完整玩家路径：调整 -> 补货 -> 30 秒营业 -> 轮内补货 -> 结算 -> 余货选择 -> 下一轮。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-settlement-scene.log" -s res://tests/showcase_round_settlement_scene_self_check.gd
```

## Task 8：生成并锁定市场、天气、节日与价格波动

**Files**

- Create: `scripts/round_environment_service.gd`
- Create: `tests/round_environment_service_self_check.gd`
- Modify: `scripts/business_round_service.gd`
- Modify: `scripts/showcase_round_sale_service.gd`
- Modify: `scripts/main_view.gd`

**RED**

- 断言相同项目种子和 `business_round_id` 始终得到相同环境。
- 断言环境在调整阶段可见，开轮后锁定；暂停、读档、切页和退出不能重抽。
- 断言普通轮时长仍为 30 秒，环境不能修改时长。
- 断言环境最多包含一个市场、一个天气、一个低概率节日和一个整轮波动。
- 断言常规正向总修正不超过 +25%，负向不低于 -10%，且不会使商品无法成交。
- 断言无已解锁商品匹配时重选次级因素，最终可回退为无修正普通街区。

**GREEN**

- 使用 `showcase_round_rules.json` 中的模板生成可序列化环境快照。
- 环境只修正销售条款快照中的售价/周期，不在每笔成交时重新随机。
- 为每项修正保存来源、匹配标签和文字理由，供调整预览、商品提示和结算归因复用。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-round-environment.log" -s res://tests/round_environment_service_self_check.gd
```

## Task 9：实现商品角色、热度与确定性连锁

**Files**

- Create: `scripts/showcase_role_service.gd`
- Create: `scripts/showcase_chain_service.gd`
- Create: `tests/showcase_chain_service_self_check.gd`
- Modify: `scripts/showcase_round_sale_service.gd`
- Modify: `scripts/business_round_service.gd`
- Modify: `scripts/ui/storefront/showcase_feedback_director.gd`
- Modify: `scripts/main_view.gd`

**RED**

- 断言形状、标签、变体和成长能得到引流器、推进器、放大器或收割器角色；招牌覆盖只作用于配置列出的少量配方。
- 断言每次真实基础成交默认产生 4 热度，热度始终在 0-100，基础成交不消耗热度。
- 断言推进、放大和收割只在条件有效时扣热度；目标待补货或位置无效时跳过且不扣除。
- 断言单链最多 4 层，同一布局实例单链最多发动一次。
- 断言连锁推进成交必须扣除真实批次库存，并遵循 8 折批次优先。
- 断言本链新生成的热度在整条链结束后再加入，不能供本链继续消费。
- 断言第 30 秒自然成交触发的即时连锁完整处理，需要正向时间推进的效果不越过结束线。
- 断言相同布局、库存、种子和输入事件得到完全相同的连锁顺序与经济结果。

**GREEN**

- `ShowcaseRoleService` 只生成角色和目标关系快照；营业中不重新查询可变布局。
- `ShowcaseChainService.resolve_chain()` 接收自然成交、角色快照、批次状态和热度，返回有序效果/成交事件与下一状态。
- 复用现有反馈导演的商品回弹、浮字、金币弧线和关系线，增加热度获得/消耗与推进目标的可见反馈。
- 动画排队和溢出压缩不得改变服务产出的经济结果。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-chain.log" -s res://tests/showcase_chain_service_self_check.gd
```

## Task 10：建立可重放的营业轮报告与收益归因

**Files**

- Create: `scripts/showcase_round_report_service.gd`
- Create: `tests/showcase_round_report_service_self_check.gd`
- Modify: `scripts/showcase_round_sale_service.gd`
- Modify: `scripts/showcase_rule_service.gd`
- Modify: `scripts/game_state.gd`

**RED**

- 断言报告记录每件商品的成交次数、全价/8 折次数、收入、补货次数、最高单笔和触发规则。
- 断言贡献最高商品按金币、成交数、锚点、配方 ID 稳定决胜。
- 断言基础收入使用同一轮实际补货时间和批次，关闭布局、环境和连锁后重放。
- 断言市场影响为“仅应用环境”减基础收入；布局额外收入为实际正常成交收入减基础与市场影响。
- 断言 5 折和 1 折清仓收入独立列出，不混入布局额外收入。
- 断言基础、市场影响、布局额外收入和清仓收入可以对账到本轮总金币。
- 断言报告不包含缺货损失、假想顾客或未发生成交次数。

**GREEN**

- 成交与补货日志使用纯数据结构，保存足以重放的布局快照、销售条款、事件时间、批次来源和连锁来源。
- 报告服务使用 `ShowcaseRoundSaleService` 的纯计算入口做三次确定性重放，不复制一套近似销售公式。
- `ShowcaseRuleService` 保留布局倍率与原因计算；旧的单笔粗分摊只作为兼容 UI 辅助，不再作为本轮总归因真相。
- `GameState` 只保留最近有限数量的轮报告，避免存档无限增长。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-report.log" -s res://tests/showcase_round_report_service_self_check.gd
```

## Task 11：把特殊挑战改为真实营业轮变体

**Files**

- Modify: `scripts/showcase_challenge_service.gd`
- Modify: `scripts/business_round_service.gd`
- Modify: `scripts/game_state.gd`
- Create: `tests/showcase_business_challenge_self_check.gd`

**RED**

- 断言挑战在开始前完整给出时长、限制、环境、目标、保证金和奖励。
- 断言挑战只引用当前等级已解锁的配方、标签、变体和陈列道具。
- 断言同一挑战 ID/版本时长固定；20、45、60 秒等时长只作用于特殊挑战。
- 断言失败不扣本轮正常营业收入，只损失事先展示的保证金。
- 断言重复挑战结算不能重复发奖，退出/读档不能重抽条件。
- 断言标准轮成绩只与标准轮比较，挑战成绩只与同挑战 ID 和版本比较。

**GREEN**

- 将当前静态橱窗评分挑战替换为基于营业轮报告的布局型、连锁型、市场型和时限型模板。
- 接受挑战时生成并保存挑战快照、扣除保证金；结算时按真实报告判断并原子发奖。
- 保留当前 `ShowcaseChallengeService` 文件名作为唯一挑战入口，删除旧的常驻布局即时评分语义。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-business-challenge.log" -s res://tests/showcase_business_challenge_self_check.gd
```

## Task 12：完成左侧反馈、右侧经营页和结算第二层

**Files**

- Modify: `scenes/ui/storefront/showcase_board.tscn`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `scripts/ui/storefront/showcase_feedback_director.gd`
- Modify: `scripts/ui/overlays/showcase_round_settlement_dialog.gd`
- Modify: `tests/showcase_business_round_scene_self_check.gd`
- Modify: `tests/showcase_round_settlement_scene_self_check.gd`
- Modify: `tests/right_console_experience_self_check.gd`

**RED**

- 断言调整阶段显示每件商品预计成交次数和“距离下一档还差多少秒”，并明确该预估以库存持续充足为前提。
- 断言营业中左侧同时可读：剩余时间、热度、当前环境、每件商品周期、全价/8 折库存和待补货状态。
- 断言右侧不再出现“自动经营中、自动结算、缺货损失、离线汇总”等旧语义。
- 断言右侧经营页按场景固定分为：本轮概览、环境、布局加成、补货与余货、特殊挑战、最近轮报告、橱窗扩张。
- 断言结算第二层显示各商品成交次数、贡献、补货、触发的相邻/套装/区域/角色/连锁，以及距离下一档收益还差什么。
- 断言售卖、连锁和结算反馈不拦截拖拽输入；待补货和禁用操作都有可见原因。

**GREEN**

- 将 `ShowcasePulseSummary` 从常驻自动经营摘要改为本轮状态摘要，文案只使用“调整中、营业中、待补货、待处理余货”。
- 在 `Main.tscn` 中重命名并重排经营页稳定区块；使用真实标签、按钮、进度条和表格，不在脚本中临时拼装结构。
- 右侧挑战区只在调整阶段可接受；运行阶段显示已锁定条件。
- 结算弹窗支持摘要与商品明细两层切换，并保留余货决策的明确确认门槛。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-ui.log" -s res://tests/showcase_business_round_scene_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-round-settlement-ui.log" -s res://tests/showcase_round_settlement_scene_self_check.gd
```

## Task 13：收紧离线范围并删除旧常驻售卖路径

**Files**

- Delete: `scripts/showcase_auto_sale_service.gd`
- Delete: `scripts/showcase_auto_sale_service.gd.uid`
- Delete: `tests/showcase_auto_sale_service_self_check.gd`
- Delete: `tests/showcase_auto_sale_service_self_check.gd.uid`
- Modify: `scripts/main_view.gd`
- Modify: `scripts/game_state.gd`
- Modify: `scripts/automation_service.gd`
- Modify: `scripts/save_system.gd`
- Modify: `scripts/shop_simulation.gd`
- Modify: `scenes/ui/pages/kitchen_automation_panel.tscn`
- Modify: `scripts/ui/pages/kitchen_automation_panel.gd`
- Modify: `tests/automation_settlement_self_check.gd`
- Modify: `tests/showcase_backpack_scene_self_check.gd`
- Modify: `tests/showcase_backpack_feedback_self_check.gd`
- Modify: `tests/showcase_sale_feedback_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**RED**

- 断言启动时不会调用橱窗离线结算，不生成离线橱窗金币、口碑、成长、成交记录或反馈。
- 断言离线只推进农场、林场、养殖场和水塘；厨房队列、营业轮、环境、挑战和余货均保持暂停。
- 断言厨房自动化界面不再提供“允许离线”开关或误导文案。
- 断言活动营业轮载入后从保存进度继续，未活动时保持调整阶段。
- 断言仓库不再存在可直接发放经营收入的 `ShopSimulation.run_business()` 或 `main_view._run_business()` 第二经济路径。
- 断言仓库内不再引用 `ShowcaseAutoSaleService`、`plan_offline`、`offline_showcase_batch`、`_play_offline_showcase_sale_summary` 或绝对销售到期字段。

**GREEN**

- 删除 `_ready()` 的离线橱窗结算和所有离线橱窗汇总动画、事件字段、文案及测试。
- `AutomationService` 在离线模式完全跳过厨房规则和厨房队列，只处理四类产地；回到在线后从原进度继续。
- 移除厨房离线开关；已有开发存档中的 `allow_offline` 在清洗时忽略，不再影响行为。
- 删除 `main_view._run_business()` 和 `ShopSimulation.run_business()`；`ShopSimulation` 暂只保留被 `ShowcaseRuleService` 使用的纯布局加成计算，后续不得直接改金币、口碑、库存或 `business_runs`。
- 删除旧服务与旧自检，以新营业轮服务测试作为唯一销售经济验证入口。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-automation-settlement.log" -s res://tests/automation_settlement_self_check.gd
```

```powershell
rg -n "ShowcaseAutoSaleService|plan_offline|offline_showcase_batch|_play_offline_showcase_sale_summary|sale_ready_at_unix|cycle_started_at_unix|run_business\(|_run_business\(" scripts scenes tests
```

预期第二条命令无匹配；如果仅剩明确的开发存档清洗注释，应继续收敛到不保留运行字段。

## Task 14：完整回归、可玩路径和数值验收

**Files**

- Modify: `tests/mvp_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`
- Modify: `tests/storefront_grid_layout_self_check.gd`
- Modify: `tests/showcase_icon_distribution_self_check.gd`
- Modify: `tests/showcase_drag_preview_perf_self_check.gd`
- Modify: `tests/showcase_bonus_reason_self_check.gd`
- Modify: `tests/showcase_sale_feedback_self_check.gd`

**Functional Verify**

- 新游戏能够在中心 6 x 6 内摆放商品并补货。
- 开始标准轮后倒计时恰好 30 秒，布局锁定但同款补货可用。
- 快售、中速、慢速商品分别形成高频引流、相邻推进和招牌收割三种可用布局。
- 售速跨档时能直观看到多完成一轮；未跨档时结算能说明还差多少。
- 新鲜余货逐项可选 5 折清仓或下一轮 8 折；8 折余货再剩余时强制 1 折。
- 市场、天气、节日与波动在开轮前可见，整轮不变，标准轮仍为 30 秒。
- 退出并重进不会推进营业轮，但四类产地按既有离线规则推进。
- 结算总金币能与基础、市场、布局和清仓分项对账。
- 每轮完成后 `business_runs` 只增加 1，商品成交次数不再被误记为营业日数量。

**Automated Verify**

逐个运行本计划新增的聚焦自检，再运行以下回归：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-storefront-grid.log" -s res://tests/storefront_grid_layout_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-icon-distribution.log" -s res://tests/showcase_icon_distribution_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-sale-feedback.log" -s res://tests/showcase_sale_feedback_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-component-contract.log" -s res://tests/component_contract_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-mvp.log" -s res://tests/mvp_self_check.gd
```

```powershell
git diff --check
```

若某个回归因本功能之外的既有基线漂移失败，记录确切脚本、错误与复现命令，不扩大到无关重构。

## 实施顺序与停靠条件

1. 严格按 Task 1 -> 14 执行；配置与纯服务先于 `main_view.gd` 接线。
2. Task 7 完成后先做一次阶段 A 玩家路径验收；基础 30 秒闭环不成立时，不进入热度和随机环境。
3. Task 11 完成后做阶段 B 确定性重放验收；相同输入经济结果不一致时，不进入表现收口。
4. Task 13 删除旧服务前，先确认所有新营业轮聚焦自检通过；删除后用 `rg` 验证无旧运行引用。
5. Task 14 全部通过后再决定是否提交或继续调平衡，本计划本身不创建提交。
