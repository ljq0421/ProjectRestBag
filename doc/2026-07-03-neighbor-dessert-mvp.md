# 《邻街甜品店》Godot MVP 实施计划

> **给执行 agent 的要求：** 实施本计划时使用 `superpowers:subagent-driven-development` 或 `superpowers:executing-plans`。每个任务都要按清单执行、验证、提交或说明未提交原因。

**目标：** 按 `doc/v3.md` 实现一个可玩的 Godot MVP：采购、农场/牧场/鱼塘产出、配方研发、甜品生产、橱窗营业、店铺升级、图鉴、存档和自动自检。

**架构：** 静态数据集中在 `catalog.gd`，可变状态集中在 `game_state.gd`，玩法规则拆到独立脚本。UI 布局直接维护在 `.tscn` 场景文件中，`main_view.gd` 只负责节点引用、事件绑定、状态刷新和调用规则，尽量不在代码中动态创建页面组件。

**技术栈：** Godot 4.6、GDScript、`Control` UI、JSON 存档 `user://neighbor_dessert_save.json`、headless 自检脚本 `res://tests/mvp_self_check.gd`。

## 当前实现状态（2026-07-03）

- 任务 1-9 已在 `main` 分支直接实施：静态数据、游戏状态、农场/牧场/鱼塘产出、配方研发、甜品生产、橱窗营业、存档、主界面和完整 MVP 流程自检均已接入。
- UI 布局已放在 `scenes/Main.tscn`；`scripts/main_view.gd` 只引用已有节点、绑定事件、刷新状态和调用玩法规则，不动态创建页面布局组件。
- 最终验证命令为：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --quit
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

- 当前验证结果：Godot parse check 通过；MVP 自检输出 `MVP_SELF_CHECK_PASS`。

---

## 0. 输入文档

- 策划案：`doc/v3.md`
- 当前项目根目录：`D:\Project\ProjectRest\project-rest`
- 目标验证命令：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

## 1. 文件结构

需要创建：

- `scripts/catalog.gd`：食材、产出场景、设备、配方、顾客、升级表。
- `scripts/game_state.gd`：金币、口碑、等级、库存、产出槽位、橱窗、配方、日志。
- `scripts/production_site.gd`：农场、牧场、鱼塘的安排、推进、取消、收获。
- `scripts/recipe_book.gd`：研发判定、失败线索、配方解锁、甜品制作。
- `scripts/shop_simulation.gd`：顾客生成、商品评分、购买结算。
- `scripts/save_system.gd`：JSON 存档读写和损坏存档兜底。
- `scripts/main_view.gd`：单主界面 UI。
- `scenes/Main.tscn`：主场景。
- `tests/mvp_self_check.gd`：自动自检入口。

需要修改：

- `project.godot`：设置 `run/main_scene="res://scenes/Main.tscn"`。

## 2. 任务 1：静态数据与基础自检

**目标：** 建立所有 MVP 静态数据，并让 headless 自检能检查数据完整性。

**文件：**

- 新建 `scripts/catalog.gd`
- 新建 `tests/mvp_self_check.gd`

**步骤：**

- [ ] 创建 `tests/mvp_self_check.gd`，检查食材 21 个、设备 4 个、配方 18 个、产出场景 3 个、顾客 6 个。
- [ ] 运行自检，确认因 `catalog.gd` 缺失而失败。
- [ ] 创建 `scripts/catalog.gd`，写入：
  - 20 个核心食材 + `sea_salt`
  - `farm`、`ranch`、`pond`
  - `mixer`、`oven`、`chiller`、`griddle`
  - 18 个配方
  - 6 类顾客
  - 1-5 级升级表
- [ ] 自检必须验证配方引用的材料存在于食材或配方表中。
- [ ] 运行自检通过。

**验收：**

- 输出包含 `MVP_SELF_CHECK_PASS`。
- 没有 Godot GDScript parse error。

## 3. 任务 2：游戏状态与存档

**目标：** 实现新存档、库存、金币、口碑、橱窗、配方、日志，以及 JSON 保存读取。

**文件：**

- 新建 `scripts/game_state.gd`
- 新建 `scripts/save_system.gd`
- 修改 `tests/mvp_self_check.gd`

**步骤：**

- [ ] 在自检中加入初始状态检查：金币 120、口碑 0、等级 1、橱窗 3 格。
- [ ] 实现 `GameState.new_game()`。
- [ ] 实现食材和成品库存的增减检查。
- [ ] 实现 `set_display_slot()`、`add_recipe()`、`upgrade()`、`to_dict()`、`from_dict()`。
- [ ] 实现 `SaveSystem.save_game()` 和 `SaveSystem.load_game()`。
- [ ] 自检覆盖保存后读取状态一致。

**验收：**

- 新游戏状态正确。
- 库存消耗不会变成负数。
- 缺字段存档能使用默认值补齐。

## 4. 任务 3：农场、牧场、鱼塘产出

**目标：** 让食材来源从纯采购扩展为“采购 + 自产”。

**文件：**

- 新建 `scripts/production_site.gd`
- 修改 `tests/mvp_self_check.gd`

**步骤：**

- [ ] 在自检中加入农场种草莓、营业推进、成熟收获。
- [ ] 实现 `start_slot(state, site_id, item_id)`。
- [ ] 实现 `advance_after_business(state)`。
- [ ] 实现 `harvest_slot(state, index)`。
- [ ] 实现 `cancel_slot(state, index)`。
- [ ] 检查等级限制、槽位上限、金币成本、未成熟不能收获。
- [ ] 自检覆盖鱼塘 3 级后可产出 `sea_salt`。

**验收：**

- 农场能收草莓 x3。
- 牧场能收牛奶或鸡蛋 x4。
- 鱼塘能收海盐 x2。
- 产出槽位可以存档并读取。

## 5. 任务 4：配方研发与甜品生产

**目标：** 实现“设备 + 2-3 个材料 = 新配方”的核心玩法。

**文件：**

- 新建 `scripts/recipe_book.gd`
- 修改 `tests/mvp_self_check.gd`

**步骤：**

- [ ] 自检加入 `oven + flour + egg + sugar` 解锁 `sponge_cake`。
- [ ] 实现 `research(state, device_id, material_ids)`。
- [ ] 正确组合解锁配方并奖励口碑。
- [ ] 错误设备返回设备线索。
- [ ] 缺 1 个材料返回材料类型线索。
- [ ] 等级不足返回等级线索。
- [ ] 实现 `make_product(state, recipe_id, batches)`。
- [ ] 支持制作 1 次和 5 次。
- [ ] 支持复合配方材料，例如 `cream_shortcake` 消耗 `sponge_cake` 成品。

**验收：**

- 至少 `sponge_cake` 可研发、生产并进入成品库存。
- 错误组合会生成中文失败线索。
- 材料不足时不会消耗已有库存。

## 6. 任务 5：顾客与营业结算

**目标：** 实现橱窗商品销售、金币口碑结算、顾客反馈，并推进产出槽位。

**文件：**

- 新建 `scripts/shop_simulation.gd`
- 修改 `tests/mvp_self_check.gd`

**步骤：**

- [ ] 自检加入上架 `sponge_cake` 后营业。
- [ ] 实现顾客池按店铺等级生成。
- [ ] 实现商品评分：标签匹配、低价加成、招牌加成、超预算惩罚。
- [ ] 实现成功购买：扣成品、加金币、加口碑。
- [ ] 实现未匹配反馈和缺货反馈。
- [ ] 每次营业后 `business_runs += 1`。
- [ ] 每次营业后调用 `ProductionSite.advance_after_business(state)`。

**验收：**

- 营业会卖出匹配商品。
- 金币和口碑增加。
- 成品库存减少。
- 产出槽位轮数推进。

## 7. 任务 6：主场景与 UI 外壳

**目标：** 建立可运行的 Godot 主场景和单屏多标签 UI。

**文件：**

- 新建 `scripts/main_view.gd`
- 新建 `scenes/Main.tscn`
- 修改 `project.godot`

**步骤：**

- [ ] 在 `scenes/Main.tscn` 中直接创建 UI 节点：顶部资源栏、左侧导航、中间内容区、右侧反馈栏、底部状态条。
- [ ] `main_view.gd` 使用 `@onready` 引用场景节点，只负责绑定按钮事件、刷新文本和切换内容，不在代码中批量创建页面布局节点。
- [ ] 导航包含：采购、产出、研发、生产、橱窗、图鉴、升级。
- [ ] 采购页可购买当前等级食材。
- [ ] 产出页可安排和收获农场/牧场/鱼塘。
- [ ] 生产页可制作已解锁甜品。
- [ ] 生产页上架后即时售卖；橱窗页只读展示当前在售商品。
- [ ] 图鉴页显示已解锁和未解锁配方。
- [ ] 升级页显示并执行升级。
- [ ] `project.godot` 设置主场景。

**验收：**

- Godot headless parse check 通过。
- 自检通过。

## 8. 任务 7：完整 MVP 流程自检

**目标：** 自动验证核心闭环。

**文件：**

- 修改 `tests/mvp_self_check.gd`

**步骤：**

- [ ] 从新状态开始。
- [ ] 添加基础材料。
- [ ] 研发 `sponge_cake`。
- [ ] 制作 `sponge_cake`。
- [ ] 上架到橱窗。
- [ ] 营业卖出。
- [ ] 人为满足升级条件并升到 2 级。
- [ ] 人为升到 3 级后安排鱼塘产出海盐。
- [ ] 推进 3 轮并收获海盐。

**验收：**

- 自检输出 `MVP_SELF_CHECK_PASS`。
- 失败时错误信息能指出具体断点。

## 9. 任务 8：UI 交互补全

**目标：** 让不看代码的玩家可以完成一轮 MVP。

**文件：**

- 修改 `scripts/main_view.gd`

**步骤：**

- [ ] 研发页提供可点击的配方试做按钮。
- [ ] 每个按钮显示甜品名、设备、材料。
- [ ] 橱窗页允许将已解锁甜品放入指定槽位。
- [ ] 每个按钮禁用时显示原因或在状态栏提示原因。
- [ ] 每次操作后保存存档并刷新顶部资源栏和反馈栏。

**验收：**

- 玩家能通过 UI 完成采购、产出、研发、生产、上架、营业、升级。
- 自检通过。

## 10. 任务 9：最终验证与文档同步

**目标：** 确认 MVP 实现与策划案一致。

**文件：**

- 视情况修改 `doc/v3.md`
- 视情况修改本计划
- 视情况修改 `tests/mvp_self_check.gd`

**步骤：**

- [ ] 运行 Godot parse check：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --quit
```

- [ ] 运行 MVP 自检：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://tests/mvp_self_check.gd
```

- [ ] 检查 `git status --short`。
- [ ] 确认以下功能存在：
  - 采购食材。
  - 农场、牧场、鱼塘各完成一次产出闭环。
  - 研发解锁至少 `sponge_cake`。
  - 生产成品。
  - 橱窗上架。
  - 营业增加金币和口碑。
  - 升级增加橱窗槽位。
  - 存档恢复库存、产出槽位、橱窗、配方和日志。

**验收：**

- Godot parse check 通过。
- `mvp_self_check.gd` 通过。
- 没有阻断性崩溃、死循环或存档损坏。

## 11. 范围说明

- MVP 允许研发页先使用“已知配方试做按钮”，规则层仍支持任意设备和材料组合。
- 鱼塘在 MVP 中只产出 `sea_salt`，暂不要求当前 18 个配方使用水产材料。
- UI 第一版以可用和清晰为优先，不做复杂美术；布局优先写在 `.tscn`，脚本避免动态搭页面。
