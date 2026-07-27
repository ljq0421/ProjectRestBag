# 橱窗棋盘与右侧分页控制台布局重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## 2026-07-08 实施基线更新

- 主布局采用左侧橱窗 70% / 右侧控制台 30%，不是旧草案里的 75% / 25%。
- 橱窗固定预留 10x10 共 100 个格子；初始只开放中心 6x6 共 36 格，外围格显示“待扩张”并拒绝新商品拖放。
- 游戏仍在开发期，本轮不做旧存档兼容承诺；需要时删除旧存档重建。
- 右侧控制台保留 `采购` / `产出` / `研发` / `橱窗经营` 四个分页，研发页按钮和格子尺寸按 30% 右栏做紧凑化处理。
- 已新增聚焦验证 `tests/storefront_grid_layout_self_check.gd` 覆盖 70/30、10x10、中心 6x6、锁格拖放和橱窗经营分页。

**Goal:** 按 4 张概念图把当前主界面重构为“左侧 70% 橱窗 10x10 棋盘 + 右侧 30% 分页控制台”，让橱窗成为主舞台，采购、产出、研发制作、橱窗经营成为右侧高密度操作页。

**Architecture:** 保留现有经济规则、橱窗拖拽、商品形状、收益加成、倒计时售卖、产地生产、采购和研发逻辑；先重排场景节点，再把 `main_view.gd` 的刷新逻辑按右侧分页拆清楚。`Main.tscn` 继续作为布局来源；`main_view.gd` 只负责绑定节点、刷新状态和处理交互。

**Tech Stack:** Godot 4.6.1, GDScript, static `.tscn` scene layout, `tests/mvp_self_check.gd`, `tests/output_layout_self_check.gd`.

## Global Constraints

- 不改变核心经济数值和配方规则，先做布局与反馈重构。
- 页面结构优先写入 `scenes/Main.tscn`，不要在 `main_view.gd` 动态创建固定布局骨架。
- 用户可见文案使用中文。
- `采购` 是补货支持页，不再压过橱窗主舞台。
- `研发` 和 `制作` 合并为右侧 `研发制作` 页，形成“解锁 -> 制作 -> 上架”的连续动作。
- `橱窗经营` 是收益优化页，不是只读展示页。
- Godot headless 验证必须加 `--log-file "$env:TEMP\godot-headless.log"`，避免 sandbox 下默认日志路径崩溃。
- 不自动提交，除非用户明确要求。

---

## 方案

### 目标信息架构

```text
Root
├─ TopBar: 金币 / 口碑 / 等级 / 今日收益 / 当前任务 / 全局入口
├─ Body: HBoxContainer
│  ├─ StorefrontBoardPanel: 左侧 75%
│  │  ├─ StorefrontHeader: 橱窗常驻 / 已解锁 42/100 格 / 扩张入口
│  │  ├─ ShowcaseGrid: 10x10 小格橱窗棋盘
│  │  └─ StorefrontFeedbackRow: 最近售出 / 收益加成 / 低库存 / 顾客偏好摘要
│  └─ RightConsolePanel: 右侧 25%
│     ├─ ConsoleTabs: 采购 / 产出 / 研发制作 / 橱窗经营
│     ├─ ConsoleTitle
│     ├─ ConsoleContentStack
│     │  ├─ PurchasePage
│     │  ├─ OutputPage
│     │  ├─ ResearchCraftPage
│     │  └─ StorefrontManagePage
│     └─ ConsoleActionRow
└─ StatusBar
```

### 四张概念图对应的运行状态

1. `产出` 页：右侧显示农场、牧场、林场、水塘四条挂机收益线；左侧橱窗继续售卖并跳收益。
2. `采购` 页：右侧按“任务所需 / 常用食材 / 种子 / 工具”快速补货；左侧橱窗保持主舞台。
3. `研发制作` 页：右侧显示配方路线、研发台、解锁卡片、制作并上架；新品可以直接飞向左侧空格。
4. `橱窗经营` 页：右侧显示顾客偏好、组合加成、本轮预估、自动补货、扩张橱窗；左侧棋盘显示连线和推荐摆放。

### 关键取舍

- 当前实现已经有 `5x10=50` 橱窗格、商品形状、拖拽、组合加成、倒计时售卖。新方案应把它扩到 `10x10=100`，而不是重写橱窗系统。
- 当前实现已经有上方店面/下方工作台。新方案把这个结构旋转成左右布局：左侧常驻橱窗棋盘，右侧工作台分页。
- 右侧 25% 空间很窄，所以各页都要做“纵向卡片 + 大按钮 + 摘要指标”，避免左右双列表。

---

## File Structure

- Modify: `scenes/Main.tscn`
  - 把 `Root/Body/MainArea` 从上下 `StorefrontPanel + WorkbenchPanel` 改为左右 `StorefrontBoardPanel + RightConsolePanel`。
  - 保留并迁移 `ShowcaseGrid`，将列数固定为 10，视觉目标为 10x10。
  - 新增右侧分页容器和四个页面骨架：`PurchasePage`、`OutputPage`、`ResearchCraftPage`、`StorefrontManagePage`。

- Modify: `scripts/game_state.gd`
  - 将 `DISPLAY_SLOT_COUNT` 从 50 升级到 100。
  - 将 `DISPLAY_GRID_ROWS` 从 5 升级到 10，`DISPLAY_GRID_COLUMNS` 保持 10。
  - 保持旧存档迁移：旧 50 格存档加载后补齐到 100 格，不清空玩家已摆放商品。
  - 后续若要真正做“逐步扩张”，新增 `display_slot_unlock_count` 或按等级映射已解锁格数；第一阶段可以先用锁定视觉，不改变售卖规则。

- Modify: `scripts/main_view.gd`
  - 更新 `@onready` 路径。
  - 将页面常量改为 `PAGE_PURCHASE`、`PAGE_OUTPUT`、`PAGE_RESEARCH_CRAFT`、`PAGE_STOREFRONT_MANAGE`。
  - 保留现有 `_refresh_storefront_showcase()`、`_can_drop_showcase_data()`、`_drop_showcase_data()`、`_showcase_bonus_panel_text()` 等橱窗逻辑，优先改布局绑定和文案。
  - 新增右侧分页刷新函数：`_refresh_console_tabs()`、`_refresh_purchase_console()`、`_refresh_output_console()`、`_refresh_research_craft_console()`、`_refresh_storefront_manage_console()`。
  - 产出页新增汇总文案：每个产地的进行中数量、可收获数量、预计收益、满仓/空闲状态。

- Modify: `scripts/catalog.gd`
  - 如需视觉扩张价格，新增橱窗扩张价格表，例如 `DISPLAY_SLOT_UNLOCK_COSTS`。
  - 不在第一阶段改配方、采购、产地数据。

- Modify: `scripts/production_site.gd`
  - 第一阶段不改生产规则。
  - 第二阶段可新增纯查询汇总函数，供右侧产出页显示：每个产地的 active/ready/idle/yield summary。

- Modify: `scripts/shop_simulation.gd`
  - 第一阶段不改结算规则。
  - 后续如要做“本轮预估”，优先新增只读预估函数，不复用会改状态的营业函数。

- Modify: `tests/mvp_self_check.gd`
  - 更新主场景节点路径。
  - 覆盖 10x10 橱窗、100 个 display slot、右侧四页分页、旧存档补齐、切页时橱窗不消失。
  - 覆盖研发制作页仍能研发、制作并上架；产出页仍能收获；采购页仍能购买；橱窗经营页能显示收益加成。

- Modify: `tests/output_layout_self_check.gd`
  - 更新产出页布局断言：农场、牧场、林场、水塘四条收益线必须存在。

- Reference: `doc/recipe_display_config.json`, `doc/display_rules_full.json`
  - 继续作为商品形状与橱窗加成数据来源。

---

## Task 1: 锁定左右主布局

**目标:** 先用测试锁定左 75% 橱窗、右 25% 控制台的场景结构。

**Files:**
- Modify: `tests/mvp_self_check.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`

**Steps:**
- [ ] 在 `_expect_main_scene_structure()` 中把旧上下布局断言改为左右布局断言。
- [ ] 要求存在：
  - `Root/Body/StorefrontBoardPanel`
  - `Root/Body/StorefrontBoardPanel/StorefrontHeader`
  - `Root/Body/StorefrontBoardPanel/ShowcaseGrid`
  - `Root/Body/StorefrontBoardPanel/StorefrontFeedbackRow`
  - `Root/Body/RightConsolePanel`
  - `Root/Body/RightConsolePanel/ConsoleTabs`
  - `Root/Body/RightConsolePanel/ConsoleContentStack`
  - `Root/Body/RightConsolePanel/ConsoleContentStack/PurchasePage`
  - `Root/Body/RightConsolePanel/ConsoleContentStack/OutputPage`
  - `Root/Body/RightConsolePanel/ConsoleContentStack/ResearchCraftPage`
  - `Root/Body/RightConsolePanel/ConsoleContentStack/StorefrontManagePage`
- [ ] 断言 `StorefrontBoardPanel.size_flags_stretch_ratio == 75.0`。
- [ ] 断言 `RightConsolePanel.size_flags_stretch_ratio == 25.0`。
- [ ] 断言 `ShowcaseGrid.columns == 10`。
- [ ] 运行失败测试：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/mvp_self_check.gd
```

Expected: FAIL，缺少新的左右布局节点。

- [ ] 直接编辑 `scenes/Main.tscn`，把当前 `MainArea` 的上下布局改成 `Root/Body` 下的左右布局。
- [ ] 更新 `main_view.gd` 的 `@onready` 路径，先让场景可 `_ready()`。
- [ ] 再次运行 `tests/mvp_self_check.gd`，Expected: PASS 到结构检查之后，或只剩后续行为断言失败。

---

## Task 2: 橱窗棋盘扩到 10x10，开发期重建存档

**目标:** 把橱窗从当前 50 格升级到 100 格，同时不破坏商品形状、拖拽、售卖倒计时和已有加成。

**Files:**
- Modify: `scripts/game_state.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`

**Steps:**
- [ ] 在测试中断言 `GameState.DISPLAY_SLOT_COUNT == 100`、`DISPLAY_GRID_ROWS == 10`、`DISPLAY_GRID_COLUMNS == 10`。
- [ ] 不增加旧存档迁移断言；开发期删除旧存档重建。
- [ ] 在 `game_state.gd` 中调整常量并确保 `_resize_display_slots()`、`_sanitize_display_slots()` 使用新上限。
- [ ] 在 `main_view.gd` 中调整 `SHOWCASE_SLOT_COUNT`、`SHOWCASE_GRID_ROWS`、`SHOWCASE_GRID_COLUMNS`。
- [ ] 修正任何硬编码 `5` 行的边界检查，例如 `_showcase_cells_for_slot()` 与 `_showcase_cells_for_local_shape()` 中的行数判断。
- [ ] 将 `SHOWCASE_CELL_SIZE` 下调到适合 10x10 左侧主舞台的尺寸，建议先用 `Vector2(44, 44)`，再通过截图微调。
- [ ] 运行 `tests/mvp_self_check.gd`。
- [ ] 运行 `tests/output_layout_self_check.gd`，确认产出旧布局断言未被误伤。

---

## Task 3: 右侧分页控制台骨架

**目标:** 右侧 25% 控制台能在四个分页间切换，左侧橱窗始终可见。

**Files:**
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`

**Steps:**
- [ ] 将当前 `WorkbenchTabs` 从左侧竖排改为右侧顶部 `ConsoleTabs`，四个按钮为 `采购`、`产出`、`研发制作`、`橱窗经营`。
- [ ] 新增或迁移四个页面容器，确保同一时间只有当前页 `visible = true`。
- [ ] 将 `current_page` 的默认值设为 `PAGE_OUTPUT` 或 `PAGE_STOREFRONT_MANAGE`。建议默认 `PAGE_OUTPUT`，因为早期玩家先收获材料。
- [ ] `_show_page(page)` 改为：更新按钮选中态、切换右侧页面可见性、刷新当前页、刷新橱窗。
- [ ] 测试中循环切换四页，断言 `ShowcaseGrid.visible == true` 且 `StorefrontBoardPanel.visible == true`。
- [ ] 运行 `tests/mvp_self_check.gd`。

---

## Task 4: 采购页改为“缺口补货抽屉”

**目标:** 采购页服务当前任务、研发、产出和橱窗库存，不再像全屏商店。

**Files:**
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`

**Right Page Layout:**

```text
PurchasePage
├─ PurchaseNeedTabs: 任务所需 / 常用食材 / 种子 / 工具
├─ PurchaseNeedList: 每项显示 名称 / 库存 / 价格 / 缺口原因
├─ PurchasePreviewLabel: 本次采购 -X 金币，可完成任务
└─ PurchaseQuickBuyButton: 一键购买
```

**Steps:**
- [ ] 复用 `catalog.get_purchase_categories()` 和现有购买逻辑，不改物品数据。
- [ ] 先把现有 `PurchaseCategoryTabs + PrimaryItemList` 映射到右侧窄栏。
- [ ] 增加“缺口原因”只读文案，第一版用简单规则：
  - 当前任务需要的材料：`任务所需`
  - 选中研发材料不足：`研发缺少`
  - 产出投放物库存低：`产出投放`
  - 橱窗商品成品库存为 0：`橱窗补货`
- [ ] 测试：切到采购页后，能看到 `任务所需` 或现有采购分类，购买一个已解锁物品后金币减少、库存增加。
- [ ] 运行 `tests/mvp_self_check.gd`。

---

## Task 5: 产出页改为四条挂机收益线

**目标:** 右侧产出页不再强调背包铺开，而是强调农场、牧场、林场、水塘四条挂机收益线的“可收获、每分钟产出、满仓、下次成熟”。

**Files:**
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `scripts/production_site.gd`
- Modify: `tests/output_layout_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**Right Page Layout:**

```text
OutputPage
├─ OutputSummaryLabel: 离线收益 / 本轮可收获
├─ OutputSiteCards
│  ├─ FarmCard: 农场 active/ready/idle/yield
│  ├─ RanchCard: 牧场 active/ready/idle/yield
│  ├─ ForestCard: 林场 active/ready/idle/yield
│  └─ PondCard: 水塘 active/ready/idle/yield
├─ OutputMaterialDrawer: 当前产地可投放物
└─ HarvestAllButton: 一键收获
```

**Steps:**
- [ ] 保留现有单格点击、右键加速器、拖拽开工逻辑；第一版只是重新排列显示。
- [ ] 新增只读汇总 helper，建议放 `main_view.gd` 内先实现：
  - `_output_site_ready_count(site_id: String) -> int`
  - `_output_site_active_count(site_id: String) -> int`
  - `_output_site_idle_count(site_id: String) -> int`
  - `_output_site_yield_summary(site_id: String) -> String`
- [ ] `HarvestAllButton` 调用所有 ready slot 的 `ProductionSite.harvest_slot()`，逐个收获并刷新橱窗/库存反馈。
- [ ] 成功文案必须汇总：`一键收获：大米 +6，牛奶 +4，泉水 +2`。
- [ ] 测试：四个产地卡都存在；至少一个成熟槽时点击一键收获，库存增加，状态文案包含收获物名称。
- [ ] 运行 `tests/output_layout_self_check.gd`。
- [ ] 运行 `tests/mvp_self_check.gd`。

---

## Task 6: 研发制作页合并闭环

**目标:** 把当前 `研发` 和 `制作/上架` 操作在右侧窄栏中串成连续路径：配方路线 -> 研发台 -> 新配方解锁 -> 制作并上架。

**Files:**
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`

**Right Page Layout:**

```text
ResearchCraftPage
├─ RecipeRoutePanel: 配方路线 / 当前目标 / 解锁进度
├─ ResearchBenchPanel: 工具槽 + 3 个材料槽 + 研发按钮
├─ RecipeUnlockCard: 新配方解锁 / 售价 / 标签 / 首卖加成
└─ CraftPanel: 制作1 / 制作5 / 制作并上架
```

**Steps:**
- [ ] 复用当前 `selected_research_material_ids` 和 `selected_research_tool_id`。
- [ ] 右侧材料选择改为可滚动小格；不要在 25% 宽度里放双大列表。
- [ ] 研发成功后把 `last_unlocked_recipe_id` 缓存在 `main_view.gd`，展示 `RecipeUnlockCard`。
- [ ] `制作并上架` 先调用现有制作逻辑，再调用现有橱窗上架/拖拽相关逻辑的“放入第一个可用区域” helper。
- [ ] 如果无空位，提示玩家切到 `橱窗经营` 或点击推荐空格，不静默失败。
- [ ] 测试：从新档走通 Lv.0 米浆饮研发、制作、上架，橱窗格出现米浆饮。
- [ ] 运行 `tests/mvp_self_check.gd`。

---

## Task 7: 橱窗经营页做收益优化面板

**目标:** 右侧 `橱窗经营` 页把已有加成逻辑显性化：顾客偏好、组合加成、本轮预估、低库存、扩张入口。

**Files:**
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `scripts/shop_simulation.gd`
- Modify: `tests/mvp_self_check.gd`

**Right Page Layout:**

```text
StorefrontManagePage
├─ CustomerPreferencePanel: 学生 / 白领 / 亲子 等偏好摘要
├─ BonusPanel: 当前组合加成
├─ BusinessPreviewPanel: 本轮预估 金币 / 口碑 / 售出数 / 低库存风险
├─ StorefrontActionRow: 开始营业 / 自动补货 / 一键下架低库存
└─ ExpansionPanel: 已解锁 42/100 格 / 扩张橱窗
```

**Steps:**
- [ ] 复用 `_showcase_bonus_panel_text()` 展示组合加成。
- [ ] 新增只读预估函数，不要调用会改状态的结算函数。建议先在 `main_view.gd` 中基于当前 display slots、库存和价格做粗略预估。
- [ ] `开始营业` 如果当前仍采用倒计时自动售卖，就改成“结算当前已成熟商品”；不要引入第二套营业规则。
- [ ] `自动补货` 第一版只做可见提示和未来入口，避免同时改库存自动购买规则。
- [ ] `扩张橱窗` 第一版如果没有扩张数据，只显示锁定格和价格预览；真正付费解锁放 Task 8。
- [ ] 测试：右侧显示收益加成；售出商品后 `CashierFeedback` 和右侧预估刷新。
- [ ] 运行 `tests/mvp_self_check.gd`。

---

## Task 8: 橱窗扩张从视觉锁定变为真实成长

**目标:** 将 10x10 棋盘做成后续可扩张系统，而不是一次性全开放。

**Files:**
- Modify: `scripts/game_state.gd`
- Modify: `scripts/catalog.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`

**Steps:**
- [ ] 新增 `display_unlocked_slot_count`，新档按等级或 Lv.0 任务初始化，例如 20 或 30。
- [ ] 旧存档如果没有该字段，按当前非空格数量和等级推导，不能小于已占用最大格。
- [ ] 新增扩张价格表：20 -> 30 -> 42 -> 56 -> 72 -> 100。
- [ ] 锁定格显示锁图标和价格，不允许放置商品。
- [ ] 点击 `扩张橱窗` 扣金币并增加已解锁格数。
- [ ] 测试：锁定格不能放置；扩张后可放置；旧存档不会把已上架商品锁住。
- [ ] 运行 `tests/mvp_self_check.gd`。

---

## Task 9: 视觉密度与可读性收口

**目标:** 在 16:9 和较窄窗口下保证 10x10 棋盘、右侧窄栏和按钮文字不挤压重叠。

**Files:**
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/mvp_self_check.gd`

**Steps:**
- [ ] 棋盘格固定最小尺寸，不让按钮文本把格子撑大。
- [ ] 商品格主要展示图标/短名/库存，详细信息放 tooltip 或右侧面板。
- [ ] 右侧按钮使用短文案：`购买`、`收获`、`制作并上架`、`扩张`。
- [ ] `PageDescription` 改为右侧小摘要，不占过多高度。
- [ ] 自检增加最小窗口下关键节点存在和文本非空断言；视觉部分以手动截图验证。
- [ ] 运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  --quit

& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/mvp_self_check.gd
```

Expected: parse/import succeeds and self-check prints `MVP_SELF_CHECK_PASS`.

---

## Recommended Milestones

### Milestone 1: 可切换的左右布局

完成 Task 1-3。交付标准：左侧 10x10 橱窗棋盘常驻，右侧四个分页能切换，旧核心流程不坏。

### Milestone 2: 产出和采购可用

完成 Task 4-5。交付标准：采购能快速补货；产出能看四条产地收益线并一键收获。

### Milestone 3: 研发制作闭环

完成 Task 6。交付标准：玩家能在右侧完成研发、制作、上架，左侧橱窗立即变化。

### Milestone 4: 橱窗经营爽感

完成 Task 7-8。交付标准：玩家能看懂为什么这样摆更赚钱，并能扩张橱窗。

### Milestone 5: QA 收口

完成 Task 9。交付标准：headless gate 通过，主要布局在桌面窗口下不重叠。

---

## Risks

- 10x10 格子会把商品文字压得很小。解决：格内少字，详细信息进 tooltip/右侧面板。
- 右侧 25% 放研发制作会很紧。解决：用纵向步骤卡，不再放双列表。
- 旧存档从 50 格扩到 100 格时，商品形状和 covered slot 容易出错。解决：先测试迁移，再改 UI。
- “开始营业”和当前倒计时售卖可能出现两套规则。解决：第一版只结算 ready 商品，不新增独立营业模拟。
- `main_view.gd` 已经很大。解决：本轮先不拆文件；如果改动继续扩大，再单独规划 `showcase_board.gd` 或服务类。

---

## Verification Commands

从 `D:\Project\ProjectRest\project-rest` 运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  --quit
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/mvp_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/output_layout_self_check.gd
```
