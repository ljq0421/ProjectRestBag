# Project Rest Two：阶段 2「完整 5 场短链」实施计划

> **执行方式：** 按任务顺序逐项实施。每个任务先写失败自检，再实现最小功能，最后运行本任务自检和既有回归测试。每个任务应形成一个可独立回滚的提交。

**目标：** 把阶段 1 的单 Boss 竖切扩展为一条完整、可保存恢复的 5 场 Roguelite 短链：3 场普通客潮、1 场精英、1 场最终 Boss；前 4 场胜利后各进行一次局内三选一；完整通关后获得一次幂等研究收益，并可在局外研究树解锁新配方后重新开局。

**架构：** 保留阶段 1 的确定性战斗、空间布局、战报和原子存档内核。新增 `BossEncounterService`、`RunUpgradeService`、`RecipeResearchService` 和会话事务协调器。领域服务是状态唯一写入者；场景只发出玩家意图并渲染服务结果。`challenge_main_view.gd` 不再直接改写 `run_state`、扣信心、生成奖励或发研究点。

**技术栈：** Godot 4.6.1、GDScript、JSON 配置、`.tscn` 场景、无 UI `SceneTree` 自检、1920×1080 鼠标路径验证。

## 实施状态（2026-07-29）

- Task 0–10 的游戏代码、配置、页面拆分、当前开发期存档和自动自检已经实施。
- `tests/challenge/*_self_check.gd` 共 28 项全部通过。
- Task 11 的自动主链、事务幂等、恢复验证和 81 条强化路径穷举均已覆盖。
- 真实鼠标已完成五场整链：5 场、22 次点击、34 次拖放；1920×1080 七页面已复验并修复视觉阻断项。
- 真人可玩性验收仍待 1 名不熟悉玩家和 2 名熟悉玩家实际填写，当前结论为 `TECHNICAL GO / PRODUCT EVIDENCE PENDING`。
- 详见 `docs/superpowers/verification/2026-07-29-stage-3-product-acceptance.md`。
- 166 配方迁移与“无尽爬升”仍未开始，继续受产品证据门约束。
- 本轮没有实现旧开发存档迁移：不兼容结构会保留坏档副本并创建当前格式新档。

---

## 0. 阶段 2 固定合同

### 0.1 不可变产品规则

- 标准短链固定为：

```text
普通 1 → 强化
普通 2 → 强化
普通 3 → 强化
精英 4 → 强化
最终 Boss 5 → 研究结算
```

- 每局初始拥有 2 点经营信心。
- 失败扣 1 点；信心仍大于 0 时回到同一场战前准备。
- 重试保留当前场次、已有强化、遭遇实例、完整时间轴、遭遇种子和奖励种子。
- 重试创建新的 `battle_attempt_id`，但不创建新遭遇。
- 第 1–4 场胜利后才有局内强化；第 5 场胜利不发无用途强化。
- 失败不发强化、不刷新强化候选、不改变研究收益。
- 研究点只在完整短链通关后发放；研究树只在局外大厅开放。
- 永久研究解锁不能改变已经开始的 run，更不能改变已经冻结的战斗快照。
- 全程使用独立挑战备货，不读取或写入长期库存、制作队列、采购、产地或旧研发。

### 0.2 阶段 2 原型起始值

这些值用于首版实施与自动验证，阶段 2 真人试玩后允许统一调参：

- 每场战斗继续以约 30 秒为起点。
- 短链目标总时长为 15–20 分钟，包含整理、战斗、战报、强化和研究。
- 挑战池扩展到 12 个配方：
  - 6 个初始配方：`butter_cookie`、`strawberry_jelly`、`milk_pudding`、`blueberry_muffin`、`sponge_cake`、`chocolate_lava_cake`；
  - 6 个研究配方：`vanilla_scone`、`chocolate_cookie`、`blueberry_mousse`、`strawberry_mousse`、`cream_shortcake`、`caramel_mousse`。
- 一次标准短链通关获得 3 研究点。
- 三条研究分支各含 1 个基础节点和 1 个中期节点：
  - 基础节点 3 点，约一条成功短链；
  - 中期节点 7 点，约 2–3 条成功短链。
- 首批局内强化不少于 12 个，其中至少 6 个改变空间、复制上限、周期、标签覆盖或关系，而不是只增加满足力。

### 0.3 阶段边界

阶段 2 不包含：

- 166 个配方全量迁移；
- 无尽爬升；
- 旧生产系统的大规模物理删除；
- PvP、主动技能、随机暴击或隐藏战中规则；
- 永久全局满足力百分比叠加。

### 0.4 阶段 1 产品出口

编写和执行阶段 2 不替代真人产品证据。开始任务 11 前，验证记录至少应补录：

- 一名不熟悉玩家是否能在 2 分钟内理解核心循环；
- 首次失败后是否能指出具体窗口；
- 是否主动重排；
- 三类构筑是否产生不同摆放决策。

没有真人证据时可以继续阶段 2 技术开发，但不得启动阶段 3 的 166 配方迁移。

---

## 1. 状态、身份与存档合同

### 1.1 顶层状态

使用以下状态名，不允许 UI 自造并行状态：

```text
meta_hub
research_tree
run_create
preparation
battle
battle_result_win
battle_result_loss
upgrade_select
run_complete
run_failed
```

### 1.2 不可变身份

```text
run_id                  = standard:<profile-sequence>:<run-seed>
encounter_instance_id   = <run_id>:stage:<stage-index>
battle_attempt_id       = <encounter_instance_id>:attempt:<attempt-index>
settlement_id           = <battle_attempt_id>:<outcome>
upgrade_offer_id        = <run_id>:upgrade:<stage-index>
upgrade_reward_tx       = <upgrade_offer_id>:<upgrade-id>
research_reward_tx      = <run_id>:research-complete
```

- `stage_index` 统一使用 0–4；界面显示时加 1。
- 身份由领域服务生成，不能使用 `settled_ids.size() + 1`。
- 同一不可变输入必须生成同一身份。

### 1.3 当前开发期存档形状

保留文件名：

```text
user://project_rest_two_save_v1.json
```

项目仍在开发阶段，不实现旧开发存档迁移或多版本兼容。顶层保留
`schema_version = 1` 作为当前结构标识；结构不匹配时直接创建新存档。

```text
schema_version
meta
  research_points
  unlocked_recipe_ids
  unlocked_variant_ids
  unlocked_upgrade_ids
  revealed_research_node_ids
  boss_first_clear_ids
  applied_reward_transaction_ids
  endless_records
  onboarding

active_run
  run_id
  mode
  seed
  phase
  route_id
  stage_index
  confidence
  permanent_pool_snapshot
  run_upgrades
  encounter_instances
  loadout_draft
  pending_upgrade_offer
  stage_history
  settled_settlement_ids
  applied_run_reward_transaction_ids
  next_attempt_index

active_battle
  battle_attempt_id
  encounter_instance_id
  stage_index
  snapshot
  elapsed_ms
  item_states
  pickiness
  reputation
  resolved_windows
  events
  next_event_seq
```

`pending_upgrade_offer` 必须保存完整的三个候选 ID，不允许恢复时重新抽取。

---

## 2. 计划文件地图

### 新增配置

- `doc/challenge/standard_run.json`
- `doc/challenge/run_upgrades.json`
- `doc/challenge/research_tree.json`
- 扩展 `doc/challenge/boss_encounters.json`
- 扩展 `doc/challenge/challenge_recipes.json`

### 新增领域服务

- `scripts/challenge/boss_encounter_service.gd`
- `scripts/challenge/run_upgrade_service.gd`
- `scripts/challenge/recipe_research_service.gd`
- `scripts/challenge/challenge_session_service.gd`

### 修改领域服务

- `scripts/challenge/challenge_save_service.gd`
- `scripts/challenge/challenge_run_service.gd`
- `scripts/challenge/challenge_config_validator.gd`
- `scripts/challenge/challenge_loadout_service.gd`
- `scripts/challenge/boss_battle_service.gd`
- `scripts/challenge/boss_battle_report_service.gd`

### 新增／拆分 UI

- `scenes/challenge/challenge_hub_view.tscn`
- `scripts/challenge/ui/challenge_hub_view.gd`
- `scenes/challenge/challenge_preparation_view.tscn`
- `scripts/challenge/ui/challenge_preparation_view.gd`
- `scenes/challenge/challenge_upgrade_select_view.tscn`
- `scripts/challenge/ui/challenge_upgrade_select_view.gd`
- `scenes/challenge/challenge_research_view.tscn`
- `scripts/challenge/ui/challenge_research_view.gd`
- `scenes/challenge/challenge_run_summary_view.tscn`
- `scripts/challenge/ui/challenge_run_summary_view.gd`
- 修改 `scenes/challenge/challenge_main.tscn`
- 修改 `scripts/challenge/challenge_main_view.gd`
- 修改 `scripts/challenge/ui/challenge_battle_view.gd`

### 新增核心自检

- `tests/challenge/challenge_save_state_self_check.gd`
- `tests/challenge/challenge_standard_run_service_self_check.gd`
- `tests/challenge/boss_encounter_service_self_check.gd`
- `tests/challenge/run_upgrade_service_self_check.gd`
- `tests/challenge/recipe_research_service_self_check.gd`
- `tests/challenge/challenge_upgrade_effects_self_check.gd`
- `tests/challenge/challenge_dynamic_timeline_self_check.gd`
- `tests/challenge/challenge_meta_views_self_check.gd`
- `tests/challenge/challenge_session_recovery_self_check.gd`
- `tests/challenge/challenge_standard_run_end_to_end_self_check.gd`

---

## Task 0：固定基线与阶段 1 回归门

**文件：**

- 修改：`docs/superpowers/verification/2026-07-27-backpack-boss-vertical-slice-playtest.md`
- 新增：`docs/superpowers/verification/2026-07-28-stage-2-baseline.md`

- [ ] 记录开始阶段 2 时的 `main` 提交、工作树状态和阶段 1 自检清单。
- [ ] 运行现有 `tests/challenge/` 自检，保存通过数量与失败日志路径。
- [ ] 若真人试玩尚未完成，在文档中明确写 `TECHNICAL GO / PRODUCT EVIDENCE PENDING`，不得伪造观察结果。
- [ ] 记录 `project-rest-new` 的 HEAD 和干净状态。

验证：

```powershell
git status --short --branch
git rev-parse HEAD
git -C D:\Project\ProjectRest\project-rest-new status --short
git -C D:\Project\ProjectRest\project-rest-new rev-parse HEAD
```

提交：

```powershell
git add docs/superpowers/verification
git commit -m "docs: record stage two baseline"
```

---

## Task 1：当前存档结构、合法性检查和永久奖励账本

**文件：**

- 修改：`scripts/challenge/challenge_save_service.gd`
- 新增：`tests/challenge/challenge_save_state_self_check.gd`
- 修改：`tests/challenge/challenge_save_service_self_check.gd`

**接口：**

```gdscript
ChallengeSaveService.empty_save() -> Dictionary
ChallengeSaveService.validate_current(raw: Dictionary) -> Dictionary
ChallengeSaveService.load_from_path(path: String) -> Dictionary
ChallengeSaveService.save_to_path(path: String, data: Dictionary) -> Dictionary
```

- [ ] 先写失败自检，覆盖新档、合法当前结构、结构不匹配和坏档回退。
- [ ] `validate_current` 必须检查当前结构的必需字段和类型，不做迁移或字段猜测。
- [ ] `schema_version != 1`、旧 `vertical_slice` 活动局或字段结构不匹配时，返回明确的 `incompatible_development_save`；上层直接创建新存档。
- [ ] 不保留旧顶层 `active_draft`；当前布局只存入 `active_run.loadout_draft`。
- [ ] 新增永久 `applied_reward_transaction_ids`，最终研究奖励以此防重。
- [ ] 保存前必须验证顶层是 JSON-safe Dictionary 且 `schema_version == 1`。
- [ ] 保留现有 `.tmp`、`.previous`、`.broken` 原子替换和恢复语义。

必须测试的崩溃点：

1. 战斗进行中；
2. 战报已生成但未确认；
3. 强化候选已生成但未选择；
4. 强化选择已经应用但下一场尚未显示；
5. 最终研究点已发但活动局尚未清除。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-save-state.log" -s res://tests/challenge/challenge_save_state_self_check.gd
```

提交：

```powershell
git add scripts/challenge/challenge_save_service.gd tests/challenge/challenge_save_service_self_check.gd tests/challenge/challenge_save_state_self_check.gd
git commit -m "feat: replace challenge save state"
```

---

## Task 2：完整短链状态机与稳定交易身份

**文件：**

- 修改：`scripts/challenge/challenge_run_service.gd`
- 修改：`tests/challenge/challenge_run_service_self_check.gd`
- 新增：`tests/challenge/challenge_standard_run_service_self_check.gd`

**接口：**

```gdscript
create_standard_run(run_id, seed, route_id, permanent_pool_snapshot) -> Dictionary
lock_encounters(run_state, encounter_instances) -> Dictionary
begin_battle(run_state) -> Dictionary
register_result(run_state, settlement) -> Dictionary
attach_upgrade_offer(run_state, offer) -> Dictionary
choose_upgrade(run_state, offer_id, upgrade_id, reward_tx) -> Dictionary
mark_research_rewarded(run_state, reward_tx) -> Dictionary
return_to_hub(run_state) -> Dictionary
current_encounter(run_state) -> Dictionary
```

- [ ] `create_standard_run` 创建 `stage_index = 0`、`confidence = 2`、空强化、空历史。
- [ ] `lock_encounters` 只接受严格 5 场且类型为 `normal, normal, normal, elite, final_boss` 的不可变遭遇数组。
- [ ] `begin_battle` 生成新的 `battle_attempt_id` 并增加 `next_attempt_index`。
- [ ] 失败首次提交：
  - 只扣 1 点信心；
  - 保留同一 `encounter_instance_id` 和奖励种子；
  - 信心大于 0 时回到 `battle_result_loss`；
  - 信心等于 0 时进入 `run_failed`。
- [ ] 第 1–4 场胜利进入 `battle_result_win`，随后只能进入 `upgrade_select`。
- [ ] 选择合法强化后才将 `stage_index + 1` 并进入下一场 `preparation`。
- [ ] 第 5 场胜利直接进入 `run_complete`，不创建强化候选。
- [ ] 重复 `settlement_id`、`upgrade_reward_tx`、`research_reward_tx` 均返回 `applied = false` 且不改变状态。
- [ ] 保留 `create_single_encounter` 作为阶段 1 服务回归包装器，直到阶段 3 清理。

测试必须穷举：

- 五场正常胜利；
- 第一场连续两次失败；
- 任一中间场失败后重试；
- 第 1–4 场各自重复提交胜利；
- 第 5 场没有强化；
- 重试不改布局时战斗身份变化、遭遇身份不变。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-standard-run.log" -s res://tests/challenge/challenge_standard_run_service_self_check.gd
```

提交：

```powershell
git add scripts/challenge/challenge_run_service.gd tests/challenge/challenge_run_service_self_check.gd tests/challenge/challenge_standard_run_service_self_check.gd
git commit -m "feat: add five encounter run state machine"
```

---

## Task 3：BossEncounterService 与五场内容合同

**文件：**

- 新增：`doc/challenge/standard_run.json`
- 修改：`doc/challenge/boss_encounters.json`
- 修改：`doc/challenge/challenge_recipes.json`
- 新增：`scripts/challenge/boss_encounter_service.gd`
- 修改：`scripts/challenge/challenge_config_validator.gd`
- 新增：`tests/challenge/boss_encounter_service_self_check.gd`
- 修改：`tests/challenge/challenge_config_validator_self_check.gd`

**五场职责：**

| 场次 | ID | 类型 | 主要压力 |
|---|---|---|---|
| 1 | `morning_rush` | normal | 早期售卖节奏 |
| 2 | `pairing_tasting` | normal | 标签与相邻关系 |
| 3 | `afternoon_wave` | normal | 区间持续满足力与标签覆盖 |
| 4 | `weekend_feature` | elite | 两类窗口组合、预算压力 |
| 5 | `picky_food_critic` | final_boss | 节奏、关系、持续输出综合考核 |

**接口：**

```gdscript
validate_route(route_def, encounter_defs, recipe_defs, starter_pool) -> Dictionary
create_standard_encounters(run_id, seed, route_def, encounter_defs, pool_snapshot) -> Dictionary
encounter_for_stage(encounter_instances, stage_index) -> Dictionary
```

- [ ] 配置中每场必须包含 `display_name`、`encounter_type`、`rule_tags`、`required_mechanism_tags`、完整窗口、可达性夹具和蓝图揭示 ID。
- [ ] 创建后将完整遭遇定义深拷贝进 `encounter_instances`，后续配置变化不能改变活动局。
- [ ] 遭遇种子和奖励种子从 run seed 与 stage index 确定性派生。
- [ ] 重试只能读取已锁定遭遇，禁止重新生成。
- [ ] 每个遭遇提供至少一个 `validation_draft`；用真实 `ChallengeLoadoutService` 构建快照并用 `BossBattleService.simulate` 验证可通关。
- [ ] 当前组合枚举器只可作为快速上界预筛，不得再把“预算和总占格可行”描述成严格空间可达。
- [ ] 扩展到 12 个配方时，验证器只对当前永久池和当前 route 使用的数据运行，不能指数枚举全部 166 配方。
- [ ] 每场引用的机制必须在阶段 2 已启用；未知指标或未知标签立即使配置失败。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-encounters.log" -s res://tests/challenge/boss_encounter_service_self_check.gd
```

提交：

```powershell
git add doc/challenge scripts/challenge/boss_encounter_service.gd scripts/challenge/challenge_config_validator.gd tests/challenge/boss_encounter_service_self_check.gd tests/challenge/challenge_config_validator_self_check.gd
git commit -m "feat: define standard short chain encounters"
```

---

## Task 4：需求维度扩展与动态战斗时间轴

**文件：**

- 修改：`scripts/challenge/boss_battle_service.gd`
- 修改：`scripts/challenge/boss_battle_report_service.gd`
- 修改：`scripts/challenge/ui/challenge_battle_view.gd`
- 修改：`scenes/challenge/challenge_battle_view.tscn`
- 修改：`tests/challenge/boss_battle_service_self_check.gd`
- 修改：`tests/challenge/boss_battle_report_self_check.gd`
- 新增：`tests/challenge/challenge_dynamic_timeline_self_check.gd`

新增窗口指标：

```text
tag_sales_count
tag_satisfaction
distinct_tag_count
```

- [ ] 战斗快照中的实例和 `item_states` 保存排序后的 tags。
- [ ] sale 事件携带 tags，战报从事件读取，不回查可变配置。
- [ ] `tag_sales_count` 统计截止窗口前指定标签的售卖次数。
- [ ] `tag_satisfaction` 统计指定区间内指定标签产生的最终满足力。
- [ ] `distinct_tag_count` 统计截止窗口前实际售出过的不同目标标签数量。
- [ ] 相同时间戳仍保持：售卖 → 关系 → 满足力 → 即时胜利 → 窗口 → 口碑伤害 → 失败。
- [ ] BattleView 不再固定查找 `Window08/16/24/30`；根据遭遇窗口数组动态创建行。
- [ ] 时间轴支持不同窗口数量和时间，但最终截止必须始终可见。
- [ ] 阶段 1 的 `sales_count`、`active_relation_count`、`window_satisfaction` 结果完全回归。
- [ ] UI 不计算指标，只显示事件中的 `actual/target/passed`。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-dynamic-timeline.log" -s res://tests/challenge/challenge_dynamic_timeline_self_check.gd
```

提交：

```powershell
git add scripts/challenge/boss_battle_service.gd scripts/challenge/boss_battle_report_service.gd scripts/challenge/ui/challenge_battle_view.gd scenes/challenge/challenge_battle_view.tscn tests/challenge
git commit -m "feat: add varied boss demand windows"
```

---

## Task 5：确定性局内三选一

**文件：**

- 新增：`doc/challenge/run_upgrades.json`
- 新增：`scripts/challenge/run_upgrade_service.gd`
- 新增：`tests/challenge/run_upgrade_service_self_check.gd`

**效果管线：**

```text
基础配方数据
→ 永久变体
→ 本局强化
→ 当前场有效配方／预算／关系规则
→ ChallengeLoadoutService
→ 不可变 BattleSnapshot
```

**接口：**

```gdscript
validate_definitions(upgrade_defs, known_recipe_defs) -> Dictionary
generate_offer(run_state, draft_analysis, unlocked_recipe_ids, upgrade_defs) -> Dictionary
apply_choice(run_state, offer, upgrade_id) -> Dictionary
resolve_context(base_recipe_defs, base_rules, run_upgrades) -> Dictionary
describe_effect(before_context, after_context, upgrade_id) -> Dictionary
```

首批效果类型：

- `supply_budget_add`
- `copy_limit_add`
- `cycle_pct`
- `satisfaction_add`
- `virtual_stock_add`
- `relation_bonus_add`
- `tag_add`
- `shape_variant`
- `first_window_guard`

候选约束：

- [ ] 恰好 3 个互不重复候选。
- [ ] 至少 1 个直接兼容当前构筑。
- [ ] 至少 1 个不依赖具体配方的通用强化。
- [ ] 最多 1 个转型强化。
- [ ] 转型候选只能指向本局永久池中已解锁但当前未使用的配方／标签。
- [ ] 兼容池为空时使用经过验证的通用候选，不出现空卡。
- [ ] 候选池先按稳定 ID 排序，再用本地确定性评分选择；禁止依赖 Dictionary 遍历顺序。
- [ ] 相同 run、stage、reward seed、构筑和强化层数必须得到完全相同的候选顺序。
- [ ] `offer_id`、候选 ID 和 reward transaction 在弹窗显示前保存。
- [ ] 重复应用同一 reward transaction 不增加层数。
- [ ] 叠层上限、互斥规则和最大效果必须来自配置。
- [ ] 影响摘要至少返回受影响配方、字段、before、after 和是否建议重排。

首批池硬门槛：

- 至少 12 个定义；
- 至少 6 个会改变空间、复制上限、周期、标签或关系；
- 至少 3 个通用兜底；
- 所有 6 个初始配方都至少有一个兼容强化；
- 不允许 12 个定义全部归结为满足力百分比。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-upgrades.log" -s res://tests/challenge/run_upgrade_service_self_check.gd
```

提交：

```powershell
git add doc/challenge/run_upgrades.json scripts/challenge/run_upgrade_service.gd tests/challenge/run_upgrade_service_self_check.gd
git commit -m "feat: add deterministic run upgrades"
```

---

## Task 6：强化接入布局、预测、快照与战报

**文件：**

- 修改：`scripts/challenge/challenge_loadout_service.gd`
- 修改：`scripts/challenge/boss_battle_service.gd`
- 修改：`scripts/challenge/boss_battle_report_service.gd`
- 修改：`scripts/challenge/ui/challenge_board.gd`
- 新增：`tests/challenge/challenge_upgrade_effects_self_check.gd`
- 修改：既有 loadout、battle、report 自检

- [ ] UI 或 BattleService 不直接读取 `run_upgrades`。
- [ ] `RunUpgradeService.resolve_context` 先生成有效 recipe defs、预算、复制上限、关系与窗口缓冲。
- [ ] LoadoutService 只消费有效上下文并冻结进快照。
- [ ] 强化选择不能回写基础 JSON。
- [ ] `shape_variant` 使已有布局非法时，下一场明确标记需重排，不自动移动配方。
- [ ] `copy_limit_add`、预算变化和 tag 变化立即反映在备货卡、预算与覆盖预测。
- [ ] 战报事件记录强化来源 ID，使新增满足力、周期或关系效果可追溯。
- [ ] 无强化时，阶段 1 三种测试构筑的事件和结果完全不变。
- [ ] 测试至少证明：
  - 一个强化改变合法摆法；
  - 一个强化改变窗口覆盖；
  - 一个强化改变可选择副本数；
  - 一个纯通用强化仍能正确应用；
  - 强化后的快照恢复结果与连续运行一致。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-upgrade-effects.log" -s res://tests/challenge/challenge_upgrade_effects_self_check.gd
```

提交：

```powershell
git add scripts/challenge tests/challenge
git commit -m "feat: apply run upgrades to challenge builds"
```

---

## Task 7：初版研究树与永久解锁

**文件：**

- 新增：`doc/challenge/research_tree.json`
- 新增：`scripts/challenge/recipe_research_service.gd`
- 新增：`tests/challenge/recipe_research_service_self_check.gd`

**初版分支：**

| 分支 | 基础节点（3 点） | 中期节点（7 点） | 构筑用途 |
|---|---|---|---|
| 节奏陈列 | `vanilla_scone` | `chocolate_cookie` | 快速出餐与多副本 |
| 水果套装 | `blueberry_mousse` | `strawberry_mousse` | 标签覆盖与套装关系 |
| 招牌展示 | `cream_shortcake` | `caramel_mousse` | 大件、高满足力与空间取舍 |

**接口：**

```gdscript
validate_tree(tree_def, recipe_defs, upgrade_defs) -> Dictionary
bootstrap_meta(meta, tree_def) -> Dictionary
reveal_for_boss_clear(meta, encounter_id, reveal_ids, reward_tx) -> Dictionary
grant_run_completion(meta, points, reward_tx) -> Dictionary
node_state(meta, node_id, tree_def) -> Dictionary
purchase_node(meta, node_id, tree_def, reward_tx) -> Dictionary
available_recipe_ids(meta, tree_def) -> Array[String]
```

- [ ] 验证所有前置存在、无循环、同一 unlock ID 不重复。
- [ ] 新建开发期档案获得 6 个初始配方，但不获得研究配方。
- [ ] Boss 首胜揭示分支只发生一次。
- [ ] 已揭示节点显示前置、成本、标签和构筑用途。
- [ ] 未揭示、前置不足、研究点不足时拒绝购买。
- [ ] 重复购买不扣点、不重复解锁。
- [ ] 完整短链发 3 点且 `research_reward_tx` 永久幂等。
- [ ] 当前 run 在创建时冻结 `permanent_pool_snapshot`；局外解锁只影响下一局。
- [ ] 研究节点可以解锁 recipe、variant 或 upgrade pool，但阶段 2 首版至少真实解锁上述 6 个 recipe。
- [ ] 不出现随机三选一永久配方。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-research.log" -s res://tests/challenge/recipe_research_service_self_check.gd
```

提交：

```powershell
git add doc/challenge/research_tree.json scripts/challenge/recipe_research_service.gd tests/challenge/recipe_research_service_self_check.gd
git commit -m "feat: add initial recipe research tree"
```

---

## Task 8：拆分阶段 2 页面与动态备货池

**文件：**

- 新增五组 view `.tscn/.gd`：
  - `challenge_hub_view`
  - `challenge_preparation_view`
  - `challenge_upgrade_select_view`
  - `challenge_research_view`
  - `challenge_run_summary_view`
- 修改：`scenes/challenge/challenge_main.tscn`
- 修改：`scripts/challenge/ui/challenge_supply_card.gd`
- 新增：`tests/challenge/challenge_meta_views_self_check.gd`

稳定场景结构：

```text
ChallengeMain
  GlobalTopBar
  PageHost
    HubView
    PreparationView
    BattleView
    UpgradeSelectView
    ResearchView
    RunSummaryView
  SettlementDialog
  TutorialLayer
```

页面职责：

- Hub：开始标准短链、继续活动局、打开研究树、显示研究点。
- Preparation：五场进度、信心、当前 Boss、动态时间轴、棋盘、动态备货池。
- UpgradeSelect：三张候选卡、影响摘要、选择确认。
- Research：三条分支、节点详情、价格、前置、解锁按钮。
- RunSummary：通关／失败、五场历史、四次强化、研究收益、返回大厅。

- [ ] 从 `challenge_main.tscn` 删除 6 张硬编码 SupplyCard。
- [ ] Preparation 按 `permanent_pool_snapshot` 动态实例化备货卡，并按稳定 recipe ID 排序。
- [ ] 解锁新配方后，下一局备货池出现；活动局中不突然出现。
- [ ] UpgradeSelect 只显示已持久化候选，不调用随机生成。
- [ ] 选择按钮提交后立即禁用，防止双击。
- [ ] ResearchView 不直接扣研究点，只发出 `purchase_requested(node_id)`。
- [ ] 稳定布局在 `.tscn`，脚本只绑定、刷新和发信号。
- [ ] Battle 时间轴和 Boss 文案来自当前遭遇，不再硬编码挑剔评论家。
- [ ] 1920×1080 下所有页面无重叠、裁切和被弹窗遮挡的核心操作。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-meta-views.log" -s res://tests/challenge/challenge_meta_views_self_check.gd
```

提交：

```powershell
git add scenes/challenge scripts/challenge/ui tests/challenge/challenge_meta_views_self_check.gd
git commit -m "feat: add short chain meta views"
```

---

## Task 9：会话事务服务与五场根流程

**文件：**

- 新增：`scripts/challenge/challenge_session_service.gd`
- 修改：`scripts/challenge/challenge_main_view.gd`
- 修改：`scenes/challenge/challenge_main.tscn`
- 修改：`tests/challenge/challenge_main_scene_self_check.gd`
- 新增：`tests/challenge/challenge_session_recovery_self_check.gd`

**ChallengeSessionService 职责：**

- 按顺序协调 Save、Research、Run、Encounter、Upgrade；
- 每次事务只调用各领域唯一写入者；
- 返回新的 save data 和 UI 可展示结果；
- 不引用任何 Node；
- 不计算布局、满足力或战报。

**事务接口：**

```gdscript
create_standard_run(save_data, route_id, seed) -> Dictionary
start_battle(save_data, draft) -> Dictionary
settle_battle(save_data, battle_state) -> Dictionary
acknowledge_battle_result(save_data) -> Dictionary
prepare_upgrade_offer(save_data, draft_analysis) -> Dictionary
choose_upgrade(save_data, offer_id, upgrade_id) -> Dictionary
grant_completion_reward(save_data) -> Dictionary
purchase_research(save_data, node_id) -> Dictionary
return_to_hub(save_data) -> Dictionary
```

- [ ] `challenge_main_view.gd` 不再出现 `run_state["phase"] = ...`。
- [ ] UI 不生成 settlement、offer 或 reward transaction ID。
- [ ] 每个事务先在内存得到完整新状态，再使用 SaveService 原子写盘。
- [ ] `settle_battle` 必须保留已经结束的 `active_battle`，使战报界面退出后能从事件流重建；玩家确认战报前不得偷偷进入下一场。
- [ ] 每场首次胜利调用 `RecipeResearchService.reveal_for_boss_clear`，以永久交易 ID 写入 Boss 首胜与蓝图揭示；即使本局后来失败，该首胜揭示仍然保留。
- [ ] 第 1–4 场胜利流程：

```text
结算战斗
→ 保存 battle_result_win
→ 显示并确认战报
→ 生成并保存 pending_upgrade_offer
→ 清除已确认的 active_battle
→ 显示三选一
→ 选择并保存强化
→ 锁定下一场遭遇
→ 保存 preparation
```

- [ ] 最终胜利流程：

```text
保存 run_complete
→ 显示并确认最终战报
→ RecipeResearchService 检查永久 reward ledger
→ 发研究点和 Boss 首胜揭示
→ 保存 meta 与 run 的 rewarded 状态
→ 显示 RunSummary
→ 玩家确认后清 active_run
```

- [ ] 失败流程保存扣信心结果后才显示战报；玩家确认重试时才清除已结束的 `active_battle` 并回到 preparation。重试不生成新遭遇或新候选。
- [ ] Hub 启动时：
  - 有活动局显示继续；
  - 无活动局显示开始；
  - `run_complete` 或 `run_failed` 未确认时恢复到 RunSummary。
- [ ] MainView 只负责页面切换、信号连接、文本绑定和调用 session API。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-session-recovery.log" -s res://tests/challenge/challenge_session_recovery_self_check.gd
```

提交：

```powershell
git add scripts/challenge/challenge_session_service.gd scripts/challenge/challenge_main_view.gd scenes/challenge/challenge_main.tscn tests/challenge
git commit -m "feat: connect the complete standard short chain"
```

---

## Task 10：中断恢复、教程升级和故障注入

**文件：**

- 修改：`scripts/challenge/challenge_tutorial_progress.gd`
- 修改：`scripts/challenge/ui/challenge_tutorial_overlay.gd`
- 修改：`scripts/challenge/challenge_main_view.gd`
- 修改：相关教程自检
- 新增：`tests/challenge/challenge_stage_two_tutorial_self_check.gd`

新增阶段 2 上下文提示：

- 第一次看到五场进度；
- 第一次进入强化三选一；
- 强化选择后查看预测变化；
- 第一次短链通关与研究点；
- 第一次研究节点解锁；
- 下一局出现新配方。

- [ ] 保留阶段 1 的战前、战斗、战报、重排引导进度。
- [ ] 已完成阶段 1 引导的玩家只看到阶段 2 增量提示，不重播全套。
- [ ] 引导状态不能阻塞存档事务或改变候选。
- [ ] 以下恢复点逐一故障注入：
  1. preparation；
  2. battle running；
  3. battle result；
  4. pending upgrade offer；
  5. upgrade applied；
  6. next encounter locked；
  7. run complete before research reward；
  8. research reward applied before run cleared；
  9. research node purchase。
- [ ] 战斗恢复保持暂停。
- [ ] pending offer 恢复后候选、顺序、offer ID 完全不变。
- [ ] 研究点已发后的恢复不得重复增加。
- [ ] 活动战斗身份与 run/stage/encounter/attempt 任一不一致时，降级回同场 preparation，并显示明确恢复原因。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-stage-two-tutorial.log" -s res://tests/challenge/challenge_stage_two_tutorial_self_check.gd
```

提交：

```powershell
git add scripts/challenge scenes/challenge tests/challenge
git commit -m "feat: guide and restore the five encounter run"
```

---

## Task 11：全链验证、组合穷举与产品出口

**文件：**

- 新增：`tests/challenge/challenge_standard_run_end_to_end_self_check.gd`
- 修改：`tests/challenge/challenge_vertical_slice_self_check.gd`
- 新增：`docs/superpowers/verification/2026-07-28-standard-short-chain-playtest.md`

### 自动验证

- [ ] 从空当前格式存档进入 Hub。
- [ ] 创建 5 场标准短链。
- [ ] 完成 3 普通、1 精英、1 最终 Boss。
- [ ] 第 1–4 场各出现一次三选一；第 5 场没有强化。
- [ ] 至少一次失败扣信心并重试同场。
- [ ] 四次选择后运行中有四笔唯一强化交易。
- [ ] 最终只发一次 3 点研究收益。
- [ ] 在研究树购买一个 3 点节点。
- [ ] 新开一局出现新配方，上一局的强化不继承。
- [ ] 空旧仓库也能完成整条短链，旧库存前后完全相同。
- [ ] `project_rest_new`、`state.inventory`、`production_queue`、旧研发等禁用依赖扫描为零。
- [ ] 相同输入、强化、布局、遭遇和种子得到相同事件。
- [ ] 恢复运行与连续运行结果相同。
- [ ] 所有重复结算、重复强化、重复研究收益均幂等。
- [ ] 枚举四次三选一最多 `3^4 = 81` 条选择路径；每条路径都不能出现空候选、无效配置或无法进入下一场。
- [ ] 12 个配方、5 个遭遇、强化池和研究图全部通过配置合法性验证。

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\project-rest-two-standard-e2e.log" -s res://tests/challenge/challenge_standard_run_end_to_end_self_check.gd
```

随后运行全部阶段 1 与阶段 2 challenge 自检：

```powershell
$tests = Get-ChildItem -LiteralPath tests\challenge -Filter *_self_check.gd | Sort-Object Name
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
    --headless `
    --path . `
    --log-file "$env:TEMP\project-rest-two-$($test.BaseName).log" `
    -s "res://tests/challenge/$($test.Name)"
  if ($LASTEXITCODE -ne 0) { throw "$($test.Name) failed" }
}
```

### 真实鼠标路径

只使用鼠标完成：

1. 从 Hub 开始新短链；
2. 查看五场进度与第 1 场完整时间轴；
3. 拖放、旋转、查看覆盖预测；
4. 自动战斗；
5. 失败、阅读战报、重排、重试；
6. 选择强化并看见预测变化；
7. 依次完成三场普通、一场精英和最终 Boss；
8. 获得研究点；
9. 打开研究树并解锁节点；
10. 新开一局并看到新配方；
11. 在战斗与强化选择界面各退出恢复一次。

### 真人产品验收

记录至少：

- 1 名不熟悉玩家完整体验；
- 2 名熟悉玩家分别走不同构筑；
- 每人记录总时长、失败窗口、四次强化选择、是否重排、研究目标理解。

通过条件：

- 新玩家约 2 分钟理解“看需求—摆放—自动战斗—调整”；
- 完整短链平均 15–20 分钟；
- 每次失败都能指出具体窗口或截止条件；
- 四次强化都能看见构筑变强；
- 至少两次强化促使重排或改变挑战备货；
- 至少三类构筑方向可行；
- 玩家理解研究树是规划永久配方，而不是随机领奖。

止损条件：

- 五场只是挑剔值逐级增加：停止增加 Boss，重做需求维度。
- 所有强化都只选最高百分比：停止扩研究内容，重做强化池。
- 玩家仍只说“数值不够”：先修预测和战报，不加新机制。
- 新挑战代码访问长期库存：阻断合并。
- UI 直接扣信心、发强化或发研究点：阻断合并。
- `challenge_main_view.gd` 再次承载领域计算：拆分后再继续。

提交：

```powershell
git add tests/challenge docs/superpowers/verification
git commit -m "test: verify the complete standard short chain"
```

---

## 3. 阶段 2 完成定义

只有同时满足以下条件，阶段 2 才算完成：

- 5 场顺序严格为普通、普通、普通、精英、最终 Boss。
- 2 点信心和两次失败容错正确。
- 重试不刷新遭遇、时间轴或奖励候选。
- 第 1–4 场各一次局内三选一，第 5 场不发强化。
- 强化候选满足兼容／通用／最多一个转型，无死卡。
- 至少一半首批强化改变空间、复制上限、周期、标签或关系。
- 强化影响能在布局、预测、快照和战报中解释。
- 完整通关只发一次研究收益。
- 初版研究树可真实解锁至少一个新配方。
- 下一局读取新的永久配方池，当前局不被局外解锁污染。
- 战斗、战报、强化选择、最终奖励和研究购买均可中断恢复。
- 所有结算与奖励交易幂等。
- 空旧仓库可完成短链，长期库存零变化。
- 阶段 1 回归和阶段 2 新自检全部通过。
- 真实鼠标路径通过。
- 产品试玩达到 15–20 分钟、可解释失败、可见强化和三类构筑目标。
- `project-rest-new` 的工作树、提交和存档不受影响。

阶段 2 通过前，不进入 166 配方全量迁移，也不开发无尽爬升。
