# 橱窗连通式格子扩建实施计划

**目标：** 将固定矩形扩建替换为受等级、递增价格和四方向连通约束的单格/N格/整行/整列购买，并让全部橱窗规则读取实际解锁格集合。

## Phase A：空间数据与纯服务

### A1. 扩建纯服务

- 新建 `scripts/showcase_expansion_service.gd`。
- 提供等级最大格数、逐格价格、批量报价、四方向连通、可添加格、整行候选和整列候选。
- 新建 `tests/showcase_expansion_service_self_check.gd`，先验证失败，再实现服务。

### A2. 解锁格集合存档

- `GameState` 新增 `showcase_unlocked_cells`。
- 新档生成 16 格；旧 `showcase_unlocked_bounds` 存档展开为格集合；保存同时保留兼容边界。
- `is_showcase_cell_unlocked`、数量、外包范围和测试入口全部改读格集合。
- 新建 `tests/showcase_unlocked_cells_state_self_check.gd` 覆盖新档、旧档、去重、裁剪和保存恢复。

## Phase B：不规则区域与下游规则

### B1. 区域服务

- 扩展 `ShowcaseRegionService`，增加基于实际格集合的区域解析和格子分类。
- 保留 bounds API 作为兼容包装。
- 更新区域自检，覆盖缺口、突出格、有效行列和黄金交集。

### B2. 规则、热点与界面投影

- `GameState`、`ShopSimulation`、`ShowcaseRuleService`、`ShowcaseHotspotService` 和 `main_view.gd` 改读实际解锁格。
- 热点行只包含该行实际已解锁格。
- 放置、道具、拖放、留白和利用率不穿过缺口。
- 更新对应规则、热点、布局和拖放测试。

## Phase C：原子购买合同

### C1. 报价与购买

- `GameState.quote_showcase_cell_purchase(cells)` 返回数量、首末格价格、总价、等级额度、金币差额和失败原因。
- `GameState.purchase_showcase_cells(cells)` 在确认时重新校验并原子扣款。
- 保留旧矩形扩张方法为兼容入口或移除其 UI 使用，禁止两套购买逻辑并行生效。
- 新建 `tests/showcase_cell_purchase_self_check.gd` 覆盖价格、等级、连通、营业锁定和失败不变性。

## Phase D：场景优先的扩建模式

### D1. 棋盘扩建工具栏

- 在 `scenes/ui/storefront/showcase_board.tscn` 声明扩建工具栏、模式按钮、报价摘要和确认/取消按钮。
- `showcase_board.gd` 只负责工具栏信号与状态展示。
- 视觉沿用甜品店暖色体系：已解锁为现有区域色、已选为蜂蜜金、可选为薄荷绿、不可选维持锁定灰；不新增装饰性动效。

### D2. 交互控制

- `main_view.gd` 管理扩建模式、选择集合、行列候选、实时报价、确认和取消。
- 扩建期间禁用营业、商品拖放、道具操作和主题切换；退出后恢复。
- 错误原因通过状态栏和扩建摘要同时显示。
- 新建 `tests/showcase_expansion_mode_scene_self_check.gd` 覆盖入口、模式切换、选择、报价、确认、取消和可见反馈。

## Phase E：迁移与回归

- 更新原固定矩形扩建测试为新合同。
- 更新设计规范和规则书中的扩建说明。
- 运行区域、规则、热点、拖放、经营轮、存档、弹窗与组件合同核心回归。
- 运行 Godot 项目解析和 `git diff --check`。
- 不提交 Git，除非用户明确要求。
