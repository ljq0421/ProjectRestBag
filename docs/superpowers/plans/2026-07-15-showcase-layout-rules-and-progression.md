# 橱窗布局规则与成长实施计划

**目标：** 以“已解锁橱窗区域”为唯一空间真相，完成动态区域、现有规则修正、规则显性化、陈列道具、橱窗主题、成长选择，以及后续留白/拥挤、方向连锁、陈列容量、动态热点和真实扩张。

**设计依据：** `docs/superpowers/specs/2026-07-15-showcase-layout-rules-and-progression-design.zh.md`

## 实施原则与集成边界

- 所有行为改动遵循 RED → GREEN → REFACTOR：先新增或修改聚焦自检并确认因缺少目标能力而失败，再写最小实现。
- Godot 自检从包含 `project.godot` 的目录运行，并始终传入可写的 `--log-file`。
- `game_state.gd`、`main_view.gd` 当前已有用户的任务系统改动；本计划只在橱窗状态、橱窗视图和相邻辅助函数处做局部补丁，不覆盖或格式化无关段落。
- 稳定页面结构、规则图鉴、构筑摘要、道具/主题面板和成长弹窗优先写入 `.tscn`；脚本只负责数据绑定、信号与状态刷新。
- `display_rules_full.json` 是布局数值真相；区域计算只在 `ShowcaseRegionService` 中实现，其他服务消费其结果，不复制百分比算法。
- 每个阶段独立通过聚焦自检、相关橱窗回归和 `git diff --check` 后再进入下一阶段，不自动提交 Git。

## 阶段 A：区域真相与现有规则修正

### Task A1：建立动态区域纯服务

**Files**

- Create: `scripts/showcase_region_service.gd`
- Create: `tests/showcase_region_service_self_check.gd`
- Modify: `doc/display_rules_full.json`

**RED**

- 断言初始边界第 5–8 行、第 6–9 列得到 16 个已解锁格。
- 断言第 5 行为引流、第 8 行为宝藏、第 6–7 行为中间，且第 6–7 行与第 7–8 列交集为黄金 C 位。
- 断言不同尺寸矩形的前/中/后行段和黄金行列均至少 1 行/列。
- 断言单个商品全部占格必须属于同一功能区；跨区返回空区域。

**GREEN**

- 新增无场景依赖的 `ShowcaseRegionService`，提供边界规范化、格子解锁判断、区域解析、单格和多格区域判定。
- 使用格子中心归一化比例实现 30% / 40% / 30%，在极小矩形中按最少 1 行/列做确定性回退。
- 将区域配置由固定 `row_range` / `col_range` 改为百分比策略和效果值。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-region.log" -s res://tests/showcase_region_service_self_check.gd
```

### Task A2：让 GameState 持有已解锁矩形

**Files**

- Modify: `scripts/game_state.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/storefront_grid_layout_self_check.gd`
- Modify: `tests/showcase_region_service_self_check.gd`

**RED**

- 断言新游戏只解锁第 5–8 行、第 6–9 列，共 16 格。
- 断言 `showcase_unlocked_bounds` 能保存/加载并被规范到 12×14 棋盘内。
- 断言放置、移动、旋转、替换和道具都不能占用未解锁格。

**GREEN**

- 增加 `showcase_unlocked_bounds` 字段、默认值、序列化、反序列化与规范化入口。
- `is_showcase_cell_unlocked()` 和主视图回退逻辑统一消费该边界。
- 更新扩张摘要为当前矩形和 `16/168`，移除“中心 6×6”旧文案。

### Task A3：将动态区域接入规则计算与报告

**Files**

- Modify: `scripts/shop_simulation.gd`
- Modify: `scripts/showcase_rule_service.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_bonus_reason_self_check.gd`
- Modify: `tests/showcase_round_config_self_check.gd`

**RED**

- 断言初始 4×4 中三类区域沿用现有效果：引流价 -3%/速 +8%，黄金价 +5% 且相邻/套装/冲突放大 1.2 倍，宝藏价 +8%/速 -4%。
- 断言跨区域商品没有固定区域效果，原因列表明确标记“跨区”。
- 断言预览、经营快照和结算报告使用相同区域 ID、名称与数值。

**GREEN**

- `ShopSimulation` 从状态取得已解锁矩形并调用区域服务。
- `ShowcaseRuleService` 保留稳定原因 ID，并向 UI/报告暴露区域归因。
- 删除运行时固定行列范围判断。

### Task A4：修正规则合同

**Files**

- Modify: `scripts/shop_simulation.gd`
- Modify: `scripts/showcase_rule_service.gd`
- Modify: `scripts/game_state.gd`
- Modify: `tests/showcase_bonus_reason_self_check.gd`
- Modify: `tests/showcase_business_round_state_self_check.gd`

**RED**

- 一对商品可叠加多条不同相邻规则，同一规则不因多格接触重复。
- 连通套装缺少任一 `required_tags` 不触发；只奖励实际覆盖全部标签的最小连通成员组。
- 同标签但互不连通的第三件商品不触发扎堆惩罚；每个连通分量前两件安全。
- `sample` 真实成交额外 +1 口碑，清仓和纯金币连锁不增加。

**GREEN**

- 相邻规则以“规则 ID + 无序商品对”去重，不以商品对整体短路。
- 套装先构建四方向商品图，再搜索稳定的最小标签覆盖连通组。
- 扎堆按相同标签的四方向连通分量分别计算并按锚点稳定排序。
- 变体输出独立的 `reputation_delta`，仅由真实成交入口计入。

## 阶段 B：规则显性化

### Task B1：规则图鉴与常驻入口

**Files**

- Create: `scenes/ui/overlays/showcase_rulebook_dialog.tscn`
- Create: `scripts/ui/overlays/showcase_rulebook_dialog.gd`
- Modify: `scenes/ui/storefront/showcase_board.tscn`
- Modify: `scripts/ui/storefront/showcase_board.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Create: `tests/showcase_rulebook_scene_self_check.gd`

**RED**

- 断言营业控制区存在常驻“构筑规则”按钮，三个营业阶段均可查看。
- 断言图鉴是居中真弹窗并包含区域、四方向相邻、连通套装、冲突减损、上架变体、配方成长、角色与热度连锁、陈列道具、橱窗主题九类。
- 断言区域页显示当前动态行列，规则数值来自实际配置。

**GREEN**

- 在场景中声明固定按钮、分类导航、规则滚动区和关闭按钮。
- 绑定配置与服务输出，未开放规则显示“未开放/预告”而不是隐藏。

### Task B2：当前构筑卡与棋盘区域视觉

**Files**

- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `scenes/ui/storefront/showcase_board.tscn`
- Modify: `scripts/ui/storefront/showcase_board.gd`
- Create: `tests/showcase_build_summary_self_check.gd`

**RED**

- 断言右侧经营概览之后存在“当前构筑”卡，显示 16/168、正向规则、冲突、套装、主题、道具和最强三条影响。
- 断言已解锁空格以浅青/浅金/浅紫棕区分引流/黄金/宝藏，锁定格仍以锁定皮肤优先。
- 断言区域底色不会覆盖图标、徽标、进度和拖拽状态。

**GREEN**

- 复用现有暖色甜品店视觉，区域色只作为低强度背景/角标，不引入第二套视觉语言。
- 构筑卡只消费规则服务摘要，不在 UI 内重算。

### Task B3：拖拽差异预览

**Files**

- Modify: `scripts/main_view.gd`
- Modify: `scripts/showcase_rule_service.gd`
- Modify: `tests/showcase_drag_preview_perf_self_check.gd`
- Create: `tests/showcase_drag_rule_delta_self_check.gd`

**RED**

- 断言预览固定输出“新增 / 失去 / 风险”三行。
- 断言能识别区域、相邻、套装、冲突、跨区、拥挤、断链和未解锁格变化。
- 断言快速拖动仍复用缓存，规则差异计算不造成逐帧全量配置加载。

**GREEN**

- 比较移动前后标准化 reason IDs，分类生成三行摘要。
- 保留现有售价/售速预估，新增差异行而非用临时提示替代。

## 阶段 C：道具、主题与成长选择

### Task C1：开放陈列道具收藏与放置

**Files**

- Modify: `scripts/game_state.gd`
- Modify: `scripts/showcase_rule_service.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Create: `tests/showcase_prop_progression_self_check.gd`
- Create: `tests/showcase_prop_interaction_self_check.gd`

**RED**

- 断言蛋糕架、冷藏展示柜、复古托盘、试吃牌、礼盒角五种道具效果与配置一致。
- 断言阶段奖励永久解锁道具；道具占真实格且不能重叠或越过已解锁边界。
- 断言只有调整阶段可放置/移动/移除，失败显示明确原因。

**GREEN**

- 增加永久 `unlocked_showcase_prop_ids`，复用现有 `display_props` 布局状态。
- 在右侧“道具与主题”卡展示已解锁道具、占格、范围和实时收益预估，并支持拖放。

### Task C2：开放橱窗主题选择

**Files**

- Modify: `scripts/game_state.gd`
- Modify: `scripts/showcase_rule_service.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Create: `tests/showcase_theme_selection_self_check.gd`

**RED**

- 断言夏日、复古、茶会三主题使用现有效果，同轮只能选择一个或无主题。
- 断言调整阶段可选择，营业开始后锁定并显示原因。
- 断言主题预览显示命中商品数与预计售价/售速变化。

**GREEN**

- 增加永久主题解锁集合，保留 `showcase_theme_id` 为当前选择。
- 主题与营业环境分别归因、分别展示。

### Task C3：接入真实成长选择弹窗

**Files**

- Create: `scenes/ui/overlays/recipe_growth_choice_dialog.tscn`
- Create: `scripts/ui/overlays/recipe_growth_choice_dialog.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `scripts/game_state.gd`
- Create: `tests/recipe_growth_choice_scene_self_check.gd`

**RED**

- 断言存在 `pending_trait_choice` 时打开居中真弹窗，显示候选对 30 秒预计成交、金币、占格、角色和热度的影响。
- 断言未选择前不可静默跳过；确认后只调用一次现有 `select_recipe_trait()`。
- 断言规则图鉴和商品详情显示各成长阶段阈值、基础收益和可选特性。

**GREEN**

- 场景声明候选卡、对比行和确认按钮；运行时只绑定现有成长配置和选择入口。
- 商品格只保留简短成长角标，完整解释集中在详情和图鉴。

## 阶段 D：空间深度

### Task D1：留白与拥挤

**Files**

- Modify: `doc/display_rules_full.json`
- Modify: `scripts/showcase_rule_service.gd`
- Modify: `scripts/main_view.gd`
- Create: `tests/showcase_spacing_rule_self_check.gd`

**RED**

- 断言已解锁格少于 36 时只显示预告、不生效。
- 中块/大块/收获型商品外围至少两个已解锁空格时售价 +6%；没有任何外围空格时售速 -6%。
- 锁定格、棋盘外和道具占格不算空格。

**GREEN**

- 在规则配置中声明启用阈值、目标尺寸/角色和效果。
- 规则服务统一计算，拖拽差异和报告复用相同原因 ID。

### Task D2：方向连锁

**Files**

- Modify: `scripts/showcase_chain_service.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_chain_service_self_check.gd`
- Create: `tests/showcase_chain_preview_self_check.gd`

**RED**

- 推进角色只能选择四方向直接相邻的可售商品；没有相邻目标时不推进并返回“连锁断开”。
- 多目标按距离、行、列、配方 ID 稳定排序；一次连锁最多四个不同商品。
- 预览和经营快照显示实际方向箭头。

**GREEN**

- 用商品占格接触图替换全橱窗最近距离候选。
- 输出边列表供棋盘绘制有效连锁箭头；无目标节点不绘制文字标记。

## 阶段 E：容量、热点与扩张

### Task E1：陈列容量

**Files**

- Modify: `scripts/showcase_round_sale_service.gd`
- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_round_sale_service_self_check.gd`
- Modify: `tests/showcase_business_round_scene_self_check.gd`

**RED**

- 断言最大陈列库存为 `2 + ceil(cell_count / 2)`。
- 超量补货保留在仓库，不扣除、不丢失，并显示“陈列容量已满”。
- 一键上新与轮内补货遵守相同容量合同。

**GREEN**

- 在批次状态中保存容量和实际补入数，所有库存扣减只使用实际补入数。

### Task E2：动态热点

**Files**

- Modify: `doc/showcase_round_rules.json`
- Create: `scripts/showcase_hotspot_service.gd`
- Modify: `scripts/business_round_service.gd`
- Modify: `scripts/showcase_rule_service.gd`
- Modify: `scripts/main_view.gd`
- Create: `tests/showcase_hotspot_service_self_check.gd`

**RED**

- 断言同项目种子和轮 ID 生成相同热点，且热点只落在已解锁矩形内。
- 断言客流热点 +10% 售速、品质展位 +8% 售价、拥堵带 -6% 售速/+3% 售价。
- 热点营业前可见、开始后锁定、仅持续本轮，并与永久区域/主题分别归因。

**GREEN**

- 新增确定性纯服务，在创建营业轮时生成并写入不可变快照。
- 规则服务和棋盘只消费该快照。

### Task E3：真实矩形扩张

**Files**

- Modify: `scripts/game_state.gd`
- Modify: `scripts/main_view.gd`
- Modify: `scenes/Main.tscn`
- Create: `tests/showcase_expansion_self_check.gd`

**RED**

- 断言扩张保持居中矩形，按阶段永久解锁，且不会产生洞或不规则突出格。
- 扩张报价显示扩张前后行列、格数、区域分布和新开放机制。
- 购买后放置、区域视觉、容量、热点和存档立即使用新矩形。

**GREEN**

- 扩张只通过一个原子入口更新 `showcase_unlocked_bounds`、扣款、记录阶段并刷新规则摘要。
- 移除仅有提示文案但不改变可用格的旧扩张路径。

## 最终验证

1. 逐项运行本计划新增/修改的聚焦自检，全部要求退出码 0 且输出显式 PASS。
2. 运行现有橱窗核心回归：布局、规则原因、拖拽、营业轮、成交、余货、连锁、任务路线。
3. 以真实交互路径验证：新档 → 查看规则 → 摆放跨区商品 → 放置道具/选择主题 → 开始营业 → 真实成交 → 成长选择 → 结算 → 扩张。
4. 检查 `git diff --check`，并确认 `game_state.gd`、`main_view.gd` 中用户现有任务系统改动未被覆盖。
