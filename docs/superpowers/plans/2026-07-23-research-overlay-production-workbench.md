# 研发覆盖层与常驻制作区域实施计划

## 目标

落实
`docs/superpowers/specs/2026-07-23-research-overlay-production-workbench-design.zh.md`：

- 把当前研发输入区迁入统一全局覆盖层。
- 在底部图鉴与采购之间增加研发入口。
- 让当前制作区域原样占满右侧工作台。
- 不增加暂停、取消、调序、手动领取或新的制作数据模型。

## 实施边界

主要修改：

- `scenes/Main.tscn`
- `scenes/ui/navigation/workbench_launcher.tscn`
- `scripts/ui/navigation/workbench_launcher.gd`
- `scripts/main_view.gd`
- `scenes/ui/pages/research_workbench.tscn`
- `scenes/ui/pages/workbench_pages.tscn`
- `resources/ui/icons/workbench/generated/research_v1.png`
- `resources/ui/icons/workbench/generated/research.png`
- 对应的 Godot `.import` 文件
- 新增研发覆盖层与制作工作台场景
- 相关聚焦自检

工作区当前存在大量与本功能无关的未提交图片、文档和代码改动。实施时：

- 只编辑计划列出的功能文件和测试。
- 不格式化或整文件重写 `scripts/main_view.gd`。
- 每一步使用路径限定的 `git diff` 审计。
- 不把无关的已暂存或未暂存改动纳入功能提交。

## 关键实现决定

### 页面语义

新增两个明确目的地：

- `PAGE_PRODUCTION = "production"`：右侧常驻制作区域；导航到这里表示关闭阻挡操作的全局覆盖层。
- `PAGE_RESEARCH = "research"`：真正的研发全局覆盖层。

不再用 `PAGE_RESEARCH` 表示“关闭覆盖层、返回默认页”。

### 场景职责

- `ProductionWorkbench` 常驻 `Root/Body/MainArea/WorkbenchPanel`。
- `ResearchOverlay` 实例化在
  `GlobalOverlayLayer/OverlayFrame/OverlayModeStack`。
- 研发执行按钮不再在运行时于页头和动作行之间重挂。
- 制作全部、上架全部、一键补货继续属于常驻制作区域。

### 研发库存选择器返回

增加非持久化的覆盖层返回上下文：

- 从研发材料槽进入库存时，记录返回模式为 `research`。
- 选择材料、点击关闭或点击背景取消库存选择时，返回研发覆盖层。
- 从底部库存按钮正常打开库存时不设置返回上下文，关闭后仍回到常驻制作区域。

该上下文只存在于 `main_view.gd` 运行时状态，不写入存档。

### 研发入口图标

仓库当前只有七个工作台入口图标，没有可复用的
`research.png`。本功能需要新增一张研发图标，不能错误复用图鉴、
采购或设备图标。

研发图标的视觉主题固定为一个“正在冒泡的甜点研发锅，配一个紧贴锅体的
试验火花”。它必须与现有七图标使用同一邻里甜品店手绘契约：

- 单一紧凑主体、圆润粗轮廓、透明背景。
- 只使用现有奶油、卡仕达、蜂蜜金、珊瑚红、深巧克力和叶绿调色板。
- 不使用文字、徽章底板、按钮皮肤、场景背景或多个独立图标。
- 缩小到约 `48px` 可见主体时仍能与图鉴书、采购篮和产出托盘区分。

使用 ImageGen 只生成这一张图，原始结果保存为
`research_v1.png`，再按现有运行时图标流程规范化为带透明 Alpha 的
`512×512` `research.png`。生成和规范化不得改写现有七张图标。

## 实施步骤

### 1. 先建立场景拆分与底部入口的失败回归

修改：

- `tests/workbench_bottom_launcher_self_check.gd`
- 新增
  `tests/research_overlay_production_workbench_self_check.gd`

先更新 `workbench_bottom_launcher_self_check.gd`：

- 把预期入口从七个改为八个。
- 固定顺序为：
  `StarlightButton`、`TaskButton`、`InventoryButton`、
  `CatalogButton`、`ResearchButton`、`PurchaseButton`、
  `OutputButton`、`StorefrontManageButton`。
- 断言研发按钮：
  - 使用 `research.png`
  - `64×64`
  - `icon_max_width=64`
  - 使用 `DessertLauncherIconButton`
  - 拥有非空工具提示
- 把原 `ResearchWorkbench` 几何断言改为
  `ProductionWorkbench`：
  - 常驻右侧
  - 位于 `WorkbenchLauncher` 上方
  - 占据比启动栏更大的垂直份额
  - 研发输入条不再位于常驻工作台

新自检覆盖：

- `ProductionWorkbench` 存在并包含当前
  `KitchenAutomationPanel`、`RecipeScroll/RecipeRows` 和批量动作按钮。
- `ResearchOverlay` 位于统一 `OverlayModeStack`。
- 常驻制作区中不存在研发设备槽、材料槽或研发执行按钮。
- 研发覆盖层中存在研发摘要、设备槽、六个材料槽和研发执行按钮。
- 真实鼠标按下/释放研发启动按钮后：
  - `global_popup_mode == "research"`
  - `ResearchOverlay.visible == true`
  - `ProductionWorkbench.visible == true`
- 再次点击研发按钮或点击统一关闭按钮后：
  - 覆盖层关闭
  - 制作区仍可见

先运行两个自检，确认它们因缺少新场景和研发入口而失败。

### 2. 拆分 `.tscn` 场景并增加研发启动按钮

新增或重构：

- `scenes/ui/pages/production_workbench.tscn`
- `scenes/ui/overlays/research_overlay.tscn`
- `scenes/ui/pages/research_workbench.tscn`
- `scenes/ui/pages/workbench_pages.tscn`
- `scenes/Main.tscn`
- `scenes/ui/navigation/workbench_launcher.tscn`

先生成并验收单张研发入口图标：

- 使用 ImageGen 生成上一节确定的“甜点研发锅 + 试验火花”单主体图标。
- 保留生成原图为
  `resources/ui/icons/workbench/generated/research_v1.png`。
- 输出透明背景、`512×512` 的运行时版本
  `resources/ui/icons/workbench/generated/research.png`。
- 触发 Godot 重导入并保留对应 `.import` 描述。
- 检查透明边缘、主体留白、调色板和缩小到 `48px` 后的轮廓辨识度。
- 确认现有七张 `*.png` 与 `*_v1.png` 的内容和哈希未变化。

制作工作台迁移：

- 将当前 `SecondaryList` 内的
  `KitchenAutomationPanel`、`RecipeScroll` 和 `RecipeRows`
  移入 `ProductionWorkbench`。
- 将当前动作行中的制作全部、上架全部和一键补货按钮移入
  `ProductionWorkbench`。
- 保留当前主题变化、最小尺寸、间距、滚动容器和尺寸旗标。
- 不重新设计配方行或厨房自动化布局。
- 右侧工作台只实例化 `ProductionWorkbench` 和
  `WorkbenchLauncher`。

研发覆盖层迁移：

- 将当前研发 `PageDescription`、`ResearchInputBar`、
  `ToolSlot`、`InventoryGrid`、`ResearchToolPickerPopup`
  和研发执行按钮移入 `ResearchOverlay`。
- 六个材料槽继续由脚本按当前规则动态生成。
- 研发执行按钮固定在研发覆盖层的明确动作区，不再使用
  `_move_primary_action_button_to()`。
- 沿用统一覆盖层外框、页头、关闭按钮和背景，不增加第二套模态外壳。

底部入口：

- 在 `CatalogButton` 与 `PurchaseButton` 之间增加
  `ResearchButton`。
- 使用
  `res://resources/ui/icons/workbench/generated/research.png`。
- 规格与其他启动按钮一致：
  `64×64`、`DessertLauncherIconButton`、
  `icon_max_width=64`。
- 自检断言运行时研发纹理为 `512×512`，并在透明按钮皮肤中完整显示。
- 保持整个启动栏在当前 `760px` 右侧工作台内居中。

完成后只运行场景解析与第 1 步两个自检，直到场景结构绿灯。

### 3. 接通研发覆盖层模式和常驻制作刷新

修改：

- `scripts/ui/navigation/workbench_launcher.gd`
- `scripts/main_view.gd`
- `tests/workbench_overlay_state_self_check.gd`
- `tests/right_console_experience_self_check.gd`

启动栏脚本：

- 新增 `research_requested` 信号。
- 将 `ResearchButton` 加入 `SIGNAL_BY_BUTTON`。
- 保持真实坐标点击转发、锁定徽记和工具提示逻辑不变。

`main_view.gd` 节点绑定：

- 将制作相关 `@onready` 路径改到
  `ProductionWorkbench`。
- 将研发相关 `@onready` 路径改到
  `ResearchOverlay`。
- 增加 `research_overlay` 绑定。
- 移除运行时重挂研发执行按钮所需的路径和
  `_move_primary_action_button_to()` 调用。

统一覆盖层：

- `_show_global_popup_mode()` 增加 `research` 可见性与标题/摘要。
- 新增 `_show_research_global_popup()`。
- 新增 `_on_research_global_button_pressed()`。
- 研发按钮再次点击时按现有入口规则关闭研发覆盖层。
- `_refresh_core_feature_access()` 将 `ResearchButton` 绑定到
  `CoreFeatureUnlockService.RESEARCH`，保留灰态、锁徽记和解锁提示。
- 研发按钮即使锁定仍允许打开研发面板查看原因；真正执行研发时继续由
  `_on_primary_action()` 和 `_require_core_feature()` 阻止。

常驻制作刷新：

- 将 `_refresh_research_page()` 拆为：
  - `_refresh_production_workbench()`
  - `_refresh_research_overlay()`
- `_refresh_current_page()` 始终刷新制作区。
- 仅当 `global_popup_mode == PAGE_RESEARCH` 时刷新研发覆盖层；
  其他覆盖层继续调用各自刷新方法。
- 启动时默认显示制作区，不再调用
  `_show_page(PAGE_RESEARCH)` 作为“默认页”。
- 在线制作完成、研发成功、补货和上架后的
  `_refresh_current_page()` 不得关闭当前覆盖层或清空研发选择。

更新覆盖层测试：

- 把 `ResearchOverlay` 纳入现有模式循环。
- 把“其他覆盖层背后研发页仍可见”改为
  “其他覆盖层背后制作区仍可见”。
- 断言所有模式开关和切换过程中
  `selected_research_material_ids` 与
  `selected_research_tool_id` 不变。
- `_open_workbench_destination("research")` 应打开研发覆盖层。
- `_open_workbench_destination("production")` 应关闭覆盖层。

更新 `right_console_experience_self_check.gd` 的节点路径和语义：

- 制作摘要、配方行与批量制作/上架/补货断言改指向
  `ProductionWorkbench`。
- 研发输入与研发动作断言改指向 `ResearchOverlay`。
- 打开采购或经营中心时，常驻制作区保持完整。

### 4. 实现研发库存选择器的返回上下文

修改：

- `scripts/main_view.gd`
- `tests/tutorial_guide_popup_self_check.gd`
- `tests/workbench_overlay_state_self_check.gd`

新增瞬时状态，例如：

- `global_popup_return_mode := ""`

进入库存选择器：

- `_on_research_material_slot_pressed()` 在打开库存前：
  - 设置 `pending_research_material_slot_index`
  - 设置 `global_popup_return_mode = PAGE_RESEARCH`
  - 切换到库存覆盖层
- 底部库存按钮打开库存时明确清空返回模式。

返回规则：

- `_select_research_material_from_inventory()` 完成赋值后：
  - 清空待选槽位
  - 返回 `ResearchOverlay`
  - 刷新研发槽位和摘要
  - 保持制作区刷新
- 库存选择器的统一关闭按钮和背景关闭：
  - 如果返回模式为研发，则取消当前待选槽并回到研发
  - 否则按现有规则完全关闭覆盖层
- 从研发切换到其他底部入口时，清空材料选择器的返回上下文，
  防止以后错误回跳研发。
- 关闭研发覆盖层时不清空
  `selected_research_material_ids` 或
  `selected_research_tool_id`。

真实交互测试覆盖：

- 研发按钮打开研发。
- 点击空材料槽打开库存。
- 点击真实库存格后回到研发，槽位显示选择结果。
- 再次进入库存并点击关闭按钮后回到研发，原有选择保持。
- 普通库存按钮打开并关闭时直接回到制作区，不回到研发。

### 5. 修正教程与任务目的地

修改：

- `scripts/main_view.gd`
- `tests/tutorial_guide_dynamic_target_self_check.gd`
- `tests/tutorial_guide_popup_self_check.gd`
- `tests/tutorial_guide_route_self_check.gd`
- 与任务跳转相关的聚焦自检

教程路由：

- `_tutorial_required_page(STEP_RESEARCH)` 返回
  `PAGE_RESEARCH`。
- `STEP_CRAFT` 与 `STEP_LIST` 返回
  `PAGE_PRODUCTION`。
- `_is_workbench_destination_active(PAGE_PRODUCTION)` 在没有阻挡覆盖层时为真。
- 研发步骤的动态目标来自 `ResearchOverlay`：
  - 空材料槽
  - 设备槽
  - 研发执行按钮
- 制作和上架步骤的动态目标来自常驻
  `ProductionWorkbench/RecipeRows`。
- 研发库存选择器打开时，箭头继续定位真实库存格；
  选择后返回研发覆盖层。
- 教程跳过仍只隐藏引导，不打开研发、不授予配方、不开始制作。

任务目的地：

- `research_attempt` 跳到 `PAGE_RESEARCH`。
- `make_product` 与 `recipe_queue_complete` 跳到
  `PAGE_PRODUCTION`。
- 任务“前往”提示文字区分“研发”“制作”和“经营中心”。
- 导航到制作区时只关闭覆盖层，不重建或清空当前制作进度。

先运行教程与任务聚焦自检，确认真实目标路径和事件时机正确。

### 6. 保持研发、制作与补货行为不变

更新必要的旧节点路径，不改业务断言：

- `tests/research_input_strip_self_check.gd`
- `tests/research_batch_unlock_self_check.gd`
- `tests/research_recipe_restock_self_check.gd`
- `tests/research_wait_dialog_self_check.gd`
- `tests/research_progressive_hints_self_check.gd`
- `tests/recipe_production_ui_self_check.gd`
- `tests/recipe_production_timing_self_check.gd`

重点确认：

- 研发设备和六个材料槽的视觉及选择规则不变。
- 研发渐进线索、等待桶和结果确认不变。
- 制作全部、上架全部和一键补货仍使用当前真实报价及原子购买。
- 配方行内制作、补货、上架按钮语义不变。
- 单配方最多九批、独立进度条、在线完成和离线自动入库不变。
- 研发成功后新配方在常驻制作区立即出现。
- 研发覆盖层开关不暂停制作计时。

不得为了通过路径测试而复制状态或手动发射业务信号。

### 7. 聚焦验证

所有 Godot 无头命令都从
`D:\Project\ProjectRest\project-rest-new` 执行，并传入可写日志文件。

场景与导航：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-research-launcher.log" `
  -s res://tests/workbench_bottom_launcher_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-research-production-layout.log" `
  -s res://tests/research_overlay_production_workbench_self_check.gd
```

覆盖层与真实输入：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-research-overlay-state.log" `
  -s res://tests/workbench_overlay_state_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-research-picker-return.log" `
  -s res://tests/tutorial_guide_popup_self_check.gd
```

教程路由：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-research-tutorial-route.log" `
  -s res://tests/tutorial_guide_route_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-research-tutorial-target.log" `
  -s res://tests/tutorial_guide_dynamic_target_self_check.gd
```

制作与研发回归：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-recipe-production-ui.log" `
  -s res://tests/recipe_production_ui_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-research-wait.log" `
  -s res://tests/research_wait_dialog_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-research-restock.log" `
  -s res://tests/research_recipe_restock_self_check.gd
```

场景解析：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-research-scene-parse.log" `
  --quit
```

### 8. 运行时视觉与交互检查

在 `1920×1080` 运行画面中检查：

- 右侧制作区域从顶部延伸到底部启动栏上方。
- 配方行、厨房排程和批量按钮没有被拉伸、遮挡或重排。
- 八个底部入口完整居中，无横向溢出。
- 研发图标位于图鉴与采购之间。
- 研发图标透明边缘干净，在约 `48px` 可见主体下仍能辨认为研发锅，
  且不与图鉴书、采购篮或产出托盘混淆。
- 研发覆盖层使用统一外框、页头和关闭按钮。
- 六个材料槽和设备槽完整显示。
- 打开研发、打开材料库存、返回研发、关闭研发的真实点击路径正确。
- 研发覆盖层关闭后，制作进度继续推进且没有闪烁或重建丢失。
- 锁定状态能打开研发查看条件，但不能执行研发。

视觉检查后读取游戏与编辑器日志，确认没有节点路径错误、
重复信号连接或运行时类型错误。

## 差异审计

完成实现后：

- 运行 `git diff --check`。
- 对计划内场景、脚本和测试执行路径限定的 `git diff`。
- 检查 `git status --short`，确认未纳入无关图片和其他用户改动。
- 对比现有七张工作台图标的实现前后哈希，确认只新增
  `research_v1.png` 与 `research.png`。
- 确认没有新增存档字段或迁移代码。
- 确认没有新增暂停、取消、调序或手动领取功能。
- 确认旧 `ResearchWorkbench` 与 `workbench_pages.tscn`
  若已无引用，则仅在所有节点路径和预加载迁移完成后删除；
  若仍有合法用途，则保留但不得继续混合研发和制作职责。

## 完成条件

- 底部八个入口顺序和尺寸符合设计。
- 新研发入口使用独立、透明、`512×512` 的同风格图标。
- 研发作为统一覆盖层正常打开、切换和关闭。
- 当前制作区域原样常驻并占满右侧释放空间。
- 研发材料与设备选择跨覆盖层保持。
- 研发库存选择器选择和取消后都返回研发。
- 教程与任务跳转分别命中研发覆盖层或常驻制作区。
- 制作、补货、上架、研发等待、结果和批次规则未改变。
- 聚焦自检、场景解析、运行时交互检查和差异审计全部通过。
