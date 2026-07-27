# 研发工作台底部功能栏与统一弹窗实施计划

## 目标

按已批准的设计，将 `project-rest-new` 主页面右侧改为“固定研发制作 + 底部七入口”的结构，并让星辉、任务、库存、图鉴、采购、产出、橱窗经营全部通过现有统一覆盖层打开。

设计依据：`docs/superpowers/specs/2026-07-17-research-workbench-bottom-launcher-design.zh.md`

## 实施约束

- 左侧 `StorefrontPanel/ShowcasePanel` 的节点路径、伸缩比例和交互保持不变。
- 稳定布局和弹窗内容放在 `.tscn`，`main_view.gd` 只负责绑定、状态刷新、路由和可见反馈。
- 采购、产出、橱窗经营继续调用现有业务服务与 `GameState` 接口，不修改业务规则和存档结构。
- 复用现有 `GlobalPopupBackdrop`、`GlobalOverlayLayer`、`OverlayFrame`、`OverlayModeStack`，不建立第二套弹窗框架。
- 保留用户工作区中与本功能无关的配置、图标和导入文件改动；每次提交只暂存本计划列出的文件。
- 所有 Godot 头部命令显式传入可写的 `--log-file`，不使用默认 `user://logs`，也不使用 `NUL`。

## 任务 1：先建立失败的页面结构与交互契约

### 文件

- 新增 `tests/workbench_bottom_launcher_self_check.gd`
- 新增 `tests/workbench_overlay_state_self_check.gd`
- 修改 `tests/neighborhood_dessert_theme_self_check.gd`
- 修改 `tests/viewport_1920_layout_self_check.gd`

### 契约

在 `workbench_bottom_launcher_self_check.gd` 中实例化 `scenes/Main.tscn`，先锁定以下结构：

- `Root/TopBar` 不再存在 `StarlightButton`、`TaskButton`、`InventoryButton`、`CatalogButton`。
- `Root/Body/MainArea/WorkbenchPanel` 不再存在 `ConsoleTabs`。
- `WorkbenchPanel` 直接包含固定的 `ResearchWorkbench` 和常驻的 `WorkbenchLauncher`。
- `ResearchWorkbench` 使用剩余竖向空间；`WorkbenchLauncher` 有明确最小高度，在 1920×1080 下接近右栏高度的 10%，且不会挤压或覆盖研发内容。
- 功能栏按固定顺序包含 `StarlightButton`、`TaskButton`、`InventoryButton`、`CatalogButton`、`PurchaseButton`、`OutputButton`、`StorefrontManageButton`。
- 七个按钮都有非空图标、可读文字和 tooltip。
- `OverlayModeStack` 除现有四种内容外，还包含采购、产出和橱窗经营内容场景。
- 左侧 `StorefrontPanel` 与 `ShowcasePanel` 的原路径和伸缩比例不变。

在 `workbench_overlay_state_self_check.gd` 中锁定交互：

- 逐个点击七个入口时，`global_popup_mode` 切换为对应模式，只显示一个内容节点。
- 再次点击当前入口关闭弹窗，关闭按钮和 `Esc` 也能关闭。
- 弹窗打开时遮罩阻断研发区和橱窗区输入。
- 打开、切换、关闭弹窗前后，研发工具与材料选择保持不变。
- 关闭弹窗后主界面仍显示研发制作，不存在恢复旧 Tab 页的过程。
- 禁用入口不打开空弹窗，并保留明确的解锁 tooltip。

更新主题与视口自检，使其不再要求旧顶栏按钮或 `ConsoleTabs`，改为检查底部功能栏、统一按钮主题、弹窗最小尺寸和 1920 视口下的无裁切状态。

### 首次验证

运行新增自检并确认因目标节点尚不存在而失败：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\workbench-launcher-red.log" `
  -s res://tests/workbench_bottom_launcher_self_check.gd

& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\workbench-overlay-state-red.log" `
  -s res://tests/workbench_overlay_state_self_check.gd
```

## 任务 2：建立底部功能栏和七枚统一图标

### 文件

- 新增 `scenes/ui/navigation/workbench_launcher.tscn`
- 新增 `scripts/ui/navigation/workbench_launcher.gd`
- 新增：
  - `resources/ui/icons/workbench/starlight.svg`
  - `resources/ui/icons/workbench/task.svg`
  - `resources/ui/icons/workbench/inventory.svg`
  - `resources/ui/icons/workbench/catalog.svg`
  - `resources/ui/icons/workbench/purchase.svg`
  - `resources/ui/icons/workbench/output.svg`
  - `resources/ui/icons/workbench/storefront.svg`
- 修改 `resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres`

### 实现

- 在 `workbench_launcher.tscn` 中用单行 `HBoxContainer` 建立七个等宽入口，图标在上、短文字在下，按钮节点名与测试契约一致。
- 为功能栏按钮增加专用主题变体，例如 `DessertWorkbenchLauncherButton`，统一正常、悬停、按下、禁用和焦点状态。
- SVG 使用一致的线宽、圆角和当前甜品店皮肤配色，图形分别表达星光、清单、收纳箱、图鉴书、采购篮、产出地和店铺橱窗；不复用菜谱或原料图片作为导航图标。
- `workbench_launcher.gd` 只暴露七个语义信号和小型状态接口：设置文字、角标、禁用状态与 tooltip，不读取或修改 `GameState`。
- 动态角标放在按钮内部覆盖层，固定右上角锚点，更新数字时不得推动按钮和相邻入口。

## 任务 3：把研发、采购、产出和橱窗经营拆成稳定场景

### 文件

- 新增 `scenes/ui/pages/research_workbench.tscn`
- 修改 `scenes/ui/pages/purchase_page.tscn`
- 修改 `scripts/ui/pages/purchase_page.gd`
- 修改 `scenes/ui/pages/output_page.tscn`
- 修改 `scripts/ui/pages/output_page.gd`
- 修改 `scenes/ui/pages/storefront_manage_page.tscn`
- 修改 `scripts/ui/pages/storefront_manage_page.gd`
- 修改 `scenes/Main.tscn`
- 在完成迁移且确认无引用后删除 `scenes/ui/pages/workbench_pages.tscn`

### 实现顺序

1. 将现有 `ContentPanel` 中研发专用的标题、研发输入栏、线索面板、设备成长、配方列表和研发操作按钮迁入 `research_workbench.tscn`。
2. 将现有采购分类、采购商品列表、数量行、购物车摘要与采购操作按钮补全到 `purchase_page.tscn`。
3. 将产出滚动区、产地格子、背包分页、产出操作区和 `OutputContextMenu` 补全到 `output_page.tscn`。
4. 将当前内联的 `StorefrontManagePanel/StorefrontManageSections` 完整迁入 `storefront_manage_page.tscn`，保留经营概览、组合加成、轮次预测、道具主题和三个入口按钮的现有节点语义。
5. 在 `Main.tscn` 中：
   - 从 `TopBar` 移除四个旧入口；
   - 从 `WorkbenchPanel` 移除 `ConsoleTabs`；
   - 让 `WorkbenchPanel` 只承载 `ResearchWorkbench` 与 `WorkbenchLauncher`；
   - 将采购、产出和橱窗经营场景实例加入 `OverlayModeStack`；
   - 保留现有四个 overlay 实例及全局遮罩、拖动、关闭结构。
6. 只有在 `rg` 确认无场景引用后才删除旧的 `workbench_pages.tscn`，避免提前破坏并行中的节点迁移。

场景拆分期间保持原节点名称的业务含义，但不强行保留旧的完整绝对路径。新路径统一从 `ResearchWorkbench` 或对应的 `OverlayModeStack` 子场景开始。

## 任务 4：迁移主视图绑定、刷新和弹窗模式

### 文件

- 修改 `scripts/main_view.gd`

### 弹窗模式

将统一弹窗模式固定为：

- `automation`：星辉
- `task`：任务
- `inventory`：库存
- `catalog`：图鉴
- `purchase`：采购
- `output`：产出
- `storefront_manage`：橱窗经营

### 绑定与刷新

- 将四个顶栏按钮和四个 `ConsoleTabs` 按钮的 `@onready` 路径替换为 `WorkbenchLauncher` 中的七个按钮或语义信号。
- 将研发控件路径改到 `ResearchWorkbench`；将采购、产出、橱窗经营控件路径改到各自的 overlay 内容实例。
- 扩展 `_show_global_popup_mode()`，统一切换七种内容节点，并为每种模式设置标题和摘要。
- 为采购、产出、橱窗经营增加与现有 `_show_*_global_popup()` 同级的打开函数；打开前刷新对应内容，关闭时不清空业务选择。
- 把 `_refresh_current_page()` 拆成固定研发区刷新与当前弹窗刷新两个职责，移除“先清空共享控件、再按页复用”的逻辑。
- 逐个审计原先依赖 `current_page` 的守卫：采购回调检查 `global_popup_mode == "purchase"`，产出回调检查 `global_popup_mode == "output"`，橱窗经营刷新检查 `global_popup_mode == "storefront_manage"`；研发业务继续以固定研发场景为目标。
- 删除 `current_page`、`_set_navigation_pressed()` 和旧 Tab 切换连接。研发目的地保留为无弹窗的路由常量，采购、产出、橱窗经营直接复用对应的 popup mode 常量，避免同时维护两套导航真相。
- 资源栏刷新时同步更新功能栏状态：星辉数量、任务待领取、库存警告，以及各入口的解锁状态和 tooltip。

### 关闭语义

- `_close_global_popup()` 只关闭 overlay、清理弹窗专用拖放状态并恢复输入，不重建或清空 `ResearchWorkbench`。
- 点击同一个底部入口沿用 `_close_if_global_popup_mode()` 的再次点击关闭语义。
- 点击不同入口直接切换 `OverlayModeStack` 内容，不先显示底层页面，也不产生弹窗叠层。
- 保持库存拖入研发材料槽的现有特殊路径：库存 overlay 在拖动期间可以暂时隐藏，但研发材料目标和遮罩恢复逻辑必须继续成立。

## 任务 5：迁移教程、任务跳转与可见反馈

### 文件

- 修改 `scripts/main_view.gd`
- 修改 `tests/tutorial_guide_route_self_check.gd`
- 修改 `tests/tutorial_guide_popup_self_check.gd`
- 修改 `tests/tutorial_guide_dynamic_target_self_check.gd`
- 修改 `tests/showcase_task_l0_route_self_check.gd`
- 修改 `tests/showcase_task_growth_route_self_check.gd`
- 修改 `tests/task_bulk_claim_self_check.gd`

### 实现

- 用 `_open_workbench_destination(destination)` 替代旧 `_show_page()`：采购和产出打开对应 overlay，研发关闭当前功能弹窗并聚焦固定研发区，橱窗经营打开其 overlay。
- 新手教程的采购、产出步骤自动打开对应弹窗；研发与制作步骤关闭功能弹窗并指向固定研发控件。
- 调整 `_is_tutorial_popup_blocking()`：教程当前步骤要求的采购或产出 overlay 是教程内容本身，不应被当作阻断弹窗；无关 overlay 仍暂停箭头引导。
- 任务详情中的“前往”继续使用原有 destination 数据，但路由到新弹窗或固定研发区。
- 橱窗经营首次查看仍触发 `TutorialProgress.on_storefront_viewed()`，只把触发入口从旧 Tab 改为底部弹窗入口。
- 一键领取任务后刷新底部任务角标和文字；不再查询已删除的 `Root/TopBar/TaskButton`。
- 所有成功、禁用与失败路径继续通过状态栏或 tooltip 给出可见原因。

## 任务 6：迁移现有页面专项自检

### 文件

- 将 `tests/console_tabs_purchase_drawer_self_check.gd` 重命名并改写为 `tests/workbench_purchase_overlay_self_check.gd`
- 修改 `tests/layout_refinement_self_check.gd`
- 修改 `tests/right_console_experience_self_check.gd`
- 修改 `tests/purchase_cart_self_check.gd`
- 修改 `tests/output_layout_self_check.gd`
- 修改 `tests/output_quadrant_self_check.gd`
- 修改 `tests/output_production_band_self_check.gd`
- 修改 `tests/storefront_grid_layout_self_check.gd`
- 修改 `tests/compact_global_overlay_self_check.gd`

### 迁移原则

- 只更新因场景承载位置变化而失效的节点路径，不弱化采购、产出和橱窗经营原有业务断言。
- 采购测试先点击底部采购入口，再验证分类、数量行、购物车、小票和按钮状态。
- 产出测试先打开产出 overlay，再验证四区布局、分页、成熟/收获、上下文菜单和自动化反馈。
- 橱窗经营测试先打开对应 overlay，再验证一屏内容、挑战、报告、扩张及关闭行为。
- `compact_global_overlay_self_check.gd` 增加七种模式共用同一外壳、尺寸和遮罩的断言。
- 删除所有要求旧 `ConsoleTabs` 或旧顶栏功能按钮存在的断言，替换为底部入口与 overlay 内容断言。

## 任务 7：分层验证与最终审查

### 第一层：新增核心自检

```powershell
$tests = @(
  'workbench_bottom_launcher_self_check.gd',
  'workbench_overlay_state_self_check.gd',
  'workbench_purchase_overlay_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
    --headless `
    --path . `
    --log-file "$env:TEMP\$test.log" `
    -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

### 第二层：受影响页面与路由回归

依次运行：

- `layout_refinement_self_check.gd`
- `right_console_experience_self_check.gd`
- `purchase_cart_self_check.gd`
- `output_layout_self_check.gd`
- `output_quadrant_self_check.gd`
- `output_production_band_self_check.gd`
- `storefront_grid_layout_self_check.gd`
- `compact_global_overlay_self_check.gd`
- `tutorial_guide_route_self_check.gd`
- `tutorial_guide_popup_self_check.gd`
- `tutorial_guide_dynamic_target_self_check.gd`
- `task_bulk_claim_self_check.gd`
- `showcase_task_l0_route_self_check.gd`
- `showcase_task_growth_route_self_check.gd`
- `neighborhood_dessert_theme_self_check.gd`
- `viewport_1920_layout_self_check.gd`

每个脚本使用与第一层相同的 Godot 命令形式，并为 `--log-file` 使用独立的 `$env:TEMP` 文件名。

### 第三层：项目级检查

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\research-workbench-project-load.log" `
  --quit

& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\research-workbench-mvp.log" `
  -s res://tests/mvp_self_check.gd
```

### 人工检查

在 1920×1080 运行路径中确认：

- 左侧橱窗视觉和交互与改造前一致。
- 右侧研发区约占 90%，底部入口约占 10%，七个图标和文字没有裁切。
- 七个入口逐一打开正确内容，切换时不叠层。
- 研发中选好工具和材料后打开、切换、关闭弹窗，选择保持不变。
- 采购、产出、橱窗经营弹窗内容可完整滚动或分页。
- 禁用入口、空列表和业务失败均有可见说明。

### 收尾

- 运行 `git diff --check`。
- 用 `git status --short` 和定向 `git diff -- <paths>` 审核范围，确认没有暂存用户原有改动。
- 检查 `rg -n "ConsoleTabs|Root/TopBar/(Starlight|Task|Inventory|Catalog)Button|current_page" scenes scripts tests`，要求无剩余命中。
- 完成代码评审后修复关键问题，再重复受影响的最窄自检和项目级检查。
