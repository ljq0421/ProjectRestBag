# 采购页六区平铺实现计划

## 范围

仅修改 `D:\Project\ProjectRest\project-rest-new`。把采购页六个来源 tab 改为三列、两行的固定区域；顺序为“农场、养殖场、林场 / 水塘、辅料、工具”。六区独立滚动并共用底部购物车，价格和库存使用 SVG 图标与数值。商品范围、价格、解锁、结算、小票、任务、存档和教程完成事件保持不变。

## 步骤

1. 先更新 `tests/console_tabs_purchase_drawer_self_check.gd` 和 `tests/layout_refinement_self_check.gd`，让它们断言旧 `PurchaseCategoryTabs` 已移除、采购网格为三列、六区顺序正确、各区有独立滚动容器且底部购物车位于网格外；运行并确认新断言在旧实现上失败。
2. 新增金币与库存两个小型 SVG 资源，并调整 `purchase_quantity_row.tscn` / `.gd`：商品名独立伸缩和截断，单价与库存使用图标加数值，图标提供悬停提示，新增局部状态更新方法以同步数量、库存和按钮状态而不重建行。
3. 新增 `purchase_category_panel.tscn` / `.gd` 可复用组件，包含标题、固定高度面板、独立 `ScrollContainer`、商品行容器和空状态；组件负责配置行、按 `item_key` 查找或更新行、暴露教程目标并保存与恢复滚动位置，但不修改业务状态。
4. 重构 `purchase_page.tscn`：删除分类 `TabBar`、单一商品滚动区和隐藏 `PrimaryItemList`，新增三列网格并按“农场、养殖场、林场 / 水塘、辅料、工具”放置六个区域实例；保留顶部说明和网格外的共用购物车底栏。
5. 重构 `main_view.gd` 的采购刷新路径：移除 `selected_purchase_category`、tab 填充和 tab 切换逻辑；一次刷新六区，继续复用现有候选商品、工具可见性和解锁判断；购物车以 `item_key` 为唯一键，并同步更新所有重复来源行和底部汇总。
6. 保留现有整单购买、小票、任务推进和存档流程，只把结算后的 UI 刷新切换为六区刷新；数量增减采用局部更新，集合变化时刷新内容并恢复各区滚动位置，空区域显示紧凑空状态。
7. 更新教程采购目标：直接从农场区域查找 `rice_seed` 行并滚动到可见位置；空购物车时定位该行 `+`，已有水稻种子时定位底部购买按钮。更新 `tests/tutorial_guide_dynamic_target_self_check.gd` 和必要的路径断言，保持 `tests/tutorial_guide_route_self_check.gd` 的真实采购推进通过。
8. 扩展 `tests/purchase_cart_self_check.gd`：覆盖跨区域购物车、重复物品同步、数量变化不重置滚动位置、金币不足、整单购买和小票。修正不再适用的“选中采购分类”断言，但保留小票背景点击不得穿透页面的契约。
9. 使用 Godot 4.6.1 从 `project-rest-new` 目录依次运行聚焦自检，每次都传入可写日志，例如：`& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/console_tabs_purchase_drawer_self_check.gd`。随后运行布局、购物车、教程动态目标和教程路由自检，再执行 `--headless --quit` 项目加载检查与 `git diff --check`。
10. 复核工作区差异只包含本功能文件和已确认的设计、计划文档；不修改或提交现有无关改动。

