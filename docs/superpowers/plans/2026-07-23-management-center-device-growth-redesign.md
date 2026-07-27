# 经营中心与设备培养页面重构实施计划

> **范围：** 仅修改 `D:\Project\ProjectRest\project-rest-new`。

**目标：** 将玩家可见的“橱窗经营”升级为固定尺寸的“经营中心”，拆成经营总览、橱窗策略、设备培养三个顶层页签；从研发页移除设备培养铭牌，并在设备培养页签内完成设备总览、详情、升级和关联配方跳转。

**架构：** 保留内部路由 ID `storefront_manage` 和现有业务服务。以 `scenes/ui/pages/storefront_manage_page.tscn` 作为经营中心的场景结构入口，重用现有经营面板并按页签重新归属；新增独立的设备培养页组件负责五台成品设备的绑定和信号。`scripts/main_view.gd` 继续协调全局弹窗、存档、金币刷新和跨页面跳转，不复制设备等级或经营规则。

**验证：** 先建立失败契约，再进行场景和脚本迁移。所有 Godot 自检都从项目根目录运行，并显式传入 `--log-file` 到可写路径。最终验证真实页签点击、设备选择、升级、图鉴跳转、弹窗关闭和页面几何稳定性。

---

## Task 1：建立经营中心新结构的失败契约

**Files：**

- Create: `tests/management_center_layout_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`
- Modify: `tests/device_recipe_growth_ui_self_check.gd`
- Modify: `tests/storefront_grid_layout_self_check.gd`
- Modify: `tests/right_console_experience_self_check.gd`
- Modify: `tests/layout_refinement_self_check.gd`
- Modify: `tests/workbench_storefront_overlay_self_check.gd`

**Steps：**

1. 在 `management_center_layout_self_check.gd` 加载 `res://scenes/Main.tscn`，开放 `storefront_manage` 并真实调用现有入口。
2. 断言全局弹窗仍使用 `StorefrontManageOverlay`，但玩家可见标题为“经营中心”，内部路由仍为 `storefront_manage`。
3. 断言经营中心存在稳定节点：

   ```text
   StorefrontManageOverlay
   └── StorefrontManagePanel
       ├── ManagementCenterTabs
       │   ├── OverviewTab
       │   ├── StrategyTab
       │   └── DeviceGrowthTab
       └── ManagementCenterPages
           ├── OverviewPage
           ├── StrategyPage
           └── DeviceGrowthPage
   ```

4. 断言默认只显示 `OverviewPage`，切换页签后只显示目标页面。
5. 断言 `OverviewPage` 只包含当前构筑、本轮预估、Top 4 和最近营业报告入口。
6. 断言 `StrategyPage` 包含组合加成、规则、道具、主题、特殊挑战和橱窗扩建，不包含经营预测或设备成长控件。
7. 断言 `DeviceGrowthPage` 包含五台成品设备、详情区、升级区和关联配方入口。
8. 断言研究工作台不再挂载 `DeviceGrowthBar`，Main 根节点不再挂载 `DeviceGrowthDrawer`。
9. 断言经营中心根内容不是页面级 `ScrollContainer`；道具和主题拥有局部滚动容器。
10. 记录切换三个页签前后的 `OverlayFrame`、经营中心外框、左侧橱窗和右侧工作台尺寸，断言几何不变。
11. 将 `component_contract_self_check.gd` 中旧 `DeviceGrowthBar` / `DeviceGrowthDrawer` 契约替换为新的 `DeviceGrowthCenterPage` 契约。
12. 将现有橱窗布局测试的旧节点路径改为新语义路径，但暂不修改运行时代码。

**Red verification：**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "D:\Project\ProjectRest\tmp\management-center-red.log" `
  -s res://tests/management_center_layout_self_check.gd
```

Expected: 因新页签、页面容器和设备培养页不存在而失败；失败必须落在新增契约上。

---

## Task 2：把橱窗经营场景重构为三页签经营中心

**Files：**

- Modify: `scenes/ui/pages/storefront_manage_page.tscn`
- Modify: `scripts/ui/pages/storefront_manage_page.gd`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`

**Steps：**

1. 将 `StorefrontManagePanel` 从页面级滚动容器改为固定尺寸的纵向容器。
2. 在场景中声明 `ManagementCenterTabs` 和 `ManagementCenterPages`，禁止脚本运行时拼装稳定结构。
3. 将当前构筑面板和本轮预估面板迁入 `OverviewPage`：
   - 当前构筑保持三列；
   - 本轮预估保持四列；
   - Top 4 保持固定四行。
4. 将组合加成、道具与主题迁入 `StrategyPage`：
   - 左列约 55%；
   - 右列约 45%；
   - 组合加成保持 `3×2`；
   - 道具和主题列表使用局部滚动。
5. 删除旧 `StorefrontEntranceRow`，将三个入口迁移到所属页面：
   - 最近营业报告 → 当前构筑标题右侧；
   - 特殊挑战 → 策略页左下行动卡；
   - 橱窗扩建 → 策略页左下行动卡。
6. 将“查看全部规则”从当前构筑标题迁到组合加成标题右侧。
7. 在 `storefront_manage_page.gd` 中定义页签 ID 和切换方法：

   ```gdscript
   const TAB_OVERVIEW := "overview"
   const TAB_STRATEGY := "strategy"
   const TAB_DEVICE_GROWTH := "device_growth"

   func show_tab(tab_id: String) -> void
   func reset_to_default_tab() -> void
   func set_device_upgrade_badge(count: int) -> void
   ```

8. `_show_storefront_manage_global_popup()` 每次打开时重置为经营总览，再刷新三个页面所需数据和设备升级计数。
9. 更新 `main_view.gd` 的 `@onready` 路径和类型，不保留指向旧 `StorefrontManageSections` 堆叠结构的引用。
10. 复用 `DessertMetricPanel` 等现有紧凑样式，不修改全局主题资源。
11. 保证三个页签根容器拥有相同的伸展和最小尺寸规则。

**Focused verification：**

```powershell
$tests = @(
  "management_center_layout_self_check.gd",
  "storefront_grid_layout_self_check.gd",
  "right_console_experience_self_check.gd",
  "layout_refinement_self_check.gd"
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
    --headless `
    --path . `
    --log-file "D:\Project\ProjectRest\tmp\$($test).log" `
    -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

---

## Task 3：新增设备培养中心页组件

**Files：**

- Create: `scenes/ui/pages/device_growth_center_page.tscn`
- Create: `scripts/ui/pages/device_growth_center_page.gd`
- Modify: `scenes/ui/pages/storefront_manage_page.tscn`
- Modify: `scripts/ui/pages/storefront_manage_page.gd`
- Modify: `tests/device_recipe_growth_ui_self_check.gd`
- Modify: `tests/component_contract_self_check.gd`
- Modify: `tests/panel_v1_background_self_check.gd`

**Steps：**

1. 在 `.tscn` 中预声明五台设备选择卡：
   - `round_pot`；
   - `oven`；
   - `chiller`；
   - `griddle`；
   - `mixer`。
2. 不在设备培养页创建 `grinder` 卡片。
3. 每张设备卡提供固定节点：
   - 图标；
   - 名称；
   - 等级；
   - 使用进度；
   - 可升级徽标；
   - 锁定或满级状态。
4. 未解锁设备保持可见但不可操作，显示现有解锁条件；不得为锁定设备创建可升级状态。
5. 页面下方声明左右详情区：
   - 左侧：当前效果、下一等级效果、试作/人气/招牌统计、等待设备配方数量、研发次数、制作批次和关联配方按钮；
   - 右侧：下一等级、使用要求、金币费用、缺口说明和升级按钮。
6. `device_growth_center_page.gd` 只负责绑定和信号：

   ```gdscript
   signal upgrade_requested(device_id: String)
   signal catalog_filter_requested(device_id: String)

   func refresh(state, catalog, preferred_device_id: String = "") -> void
   func upgrade_ready_count(state, catalog) -> int
   func selected_device_id() -> String
   ```

7. `upgrade_ready_count()` 只统计已解锁、未满级且 `device_growth_quote().can_upgrade == true` 的五台设备。
8. 数量为零时隐藏设备培养页签徽标；数量大于零时显示“`x 可升级`”。
9. 默认选择第一台已解锁设备；没有已解锁设备时显示统一空状态。
10. 所有禁用升级状态同时显示缺少使用次数、金币、解锁条件或满级原因。
11. 设备升级成功后由 `main_view.gd` 负责保存，并让页面一次性刷新设备卡、详情、徽标和顶部金币。
12. 页面背景继续使用全局甜品店主题，不引入与当前皮肤不一致的独立样式。

**Focused verification：**

1. 没有可升级设备时徽标隐藏。
2. 一台和多台可升级时数量正确。
3. 使用足够但金币不足不计数。
4. 金币足够但使用不足不计数。
5. 锁定、满级和 `grinder` 不计数。
6. 升级成功后计数立即重新计算。
7. 五张设备卡切换时详情内容跟随变化。

---

## Task 4：迁移设备升级与图鉴跳转的真实业务路径

**Files：**

- Modify: `scripts/main_view.gd`
- Modify: `scripts/ui/pages/device_growth_center_page.gd`
- Modify: `tests/device_recipe_growth_ui_self_check.gd`

**Steps：**

1. 将现有 `_on_device_growth_upgrade_requested()` 改为刷新经营中心设备页，不再刷新 `device_growth_bar` 或 `device_growth_drawer`。
2. 保留 `state.upgrade_device_growth(device_id)` 作为唯一升级事务。
3. 升级失败时继续显示明确状态文字，并在页内保留缺口说明；不得静默禁用。
4. 升级成功时继续：
   - 保存游戏；
   - 显示升级等级、立即晋级配方数和等待数量；
   - 刷新配方制作状态；
   - 刷新金币；
   - 刷新设备页和页签徽标。
5. `_on_device_growth_catalog_filter_requested()` 继续设置 `selected_catalog_device_filter`，关闭经营中心后打开图鉴全局模式。
6. 不恢复原经营中心页签状态；再次打开经营中心时默认回到经营总览。
7. 删除 `_on_device_growth_selected()` 中针对研磨机的分支，因为新页面不提供研磨机入口。
8. 删除 `_on_device_growth_drawer_closed()` 及对应连接。
9. 用真实鼠标输入验证设备卡按下、升级按钮按下和关联配方按钮按下，不以手动发射信号代替。

---

## Task 5：从研发页移除旧铭牌和嵌套培养抽屉

**Files：**

- Modify: `scenes/ui/pages/workbench_pages.tscn`
- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Delete: `scenes/ui/pages/device_growth_bar.tscn`
- Delete: `scripts/ui/pages/device_growth_bar.gd`
- Delete: `scripts/ui/pages/device_growth_bar.gd.uid`
- Delete: `scenes/ui/overlays/device_growth_drawer.tscn`
- Delete: `scripts/ui/overlays/device_growth_drawer.gd`
- Delete: `scripts/ui/overlays/device_growth_drawer.gd.uid`
- Modify: `tests/component_contract_self_check.gd`
- Modify: `tests/layout_refinement_self_check.gd`
- Delete: `tests/device_growth_drawer_skin_self_check.gd`
- Delete: `tests/device_growth_drawer_skin_self_check.gd.uid`
- Create: `tests/device_growth_center_skin_self_check.gd`
- Modify: `tests/close_image_button_self_check.gd`
- Modify: `tests/panel_v1_background_self_check.gd`

**Steps：**

1. 从 `workbench_pages.tscn` 删除 `DeviceGrowthBar` 实例和外部资源引用。
2. 从 `Main.tscn` 删除 `DeviceGrowthDrawer` 实例和外部资源引用。
3. 从 `main_view.gd` 删除：
   - `device_growth_bar`；
   - `device_growth_drawer`；
   - 旧信号连接；
   - 旧页面刷新调用；
   - 抽屉关闭回调。
4. 用 `rg` 确认旧组件没有其他运行时消费者后，删除旧场景、脚本和已跟踪 `.uid`。
5. 用 `device_growth_center_skin_self_check.gd` 替代旧抽屉皮肤测试，验证设备培养中心页的面板皮肤；关闭按钮测试改为验证经营中心统一关闭契约。
6. 调整研发上半区高度和伸展规则，使研发输入条移除铭牌后自然衔接配方列表，不留下空白。
7. 保持研发成功、研发失败线索和有效使用次数业务逻辑不变。

**Absence checks：**

```powershell
rg -n "DeviceGrowthBar|DeviceGrowthDrawer|device_growth_bar|device_growth_drawer" `
  scenes scripts tests `
  --glob "*.tscn" `
  --glob "*.gd"
```

Expected: 只允许在历史设计文档中出现；活动场景、脚本和测试不得继续依赖旧组件。

---

## Task 6：更新玩家可见名称并保留内部路由

**Files：**

- Modify: `scenes/ui/navigation/workbench_launcher.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `scripts/ui/overlays/showcase_rulebook_dialog.gd`
- Modify tutorial/task copy files found by the scoped text scan
- Modify: `tests/workbench_bottom_launcher_self_check.gd`
- Modify: `tests/tutorial_guide_route_self_check.gd`
- Modify: `tests/tutorial_guide_dynamic_target_self_check.gd`
- Modify: `tests/core_feature_lock_ui_self_check.gd`

**Steps：**

1. 将启动栏提示改为“查看经营总览、橱窗策略和设备培养”。
2. 将共享弹窗标题从“橱窗经营”改为“经营中心”。
3. 将教程行动提示中的玩家可见“橱窗经营”改为“经营中心”。
4. 将规则书中“橱窗经营页”的入口说明改为“经营中心的橱窗策略页签”。
5. 将任务目的地等玩家可见标签更新为“经营中心”。
6. 明确保留：
   - `PAGE_STOREFRONT_MANAGE`；
   - `storefront_manage_requested`；
   - `global_popup_mode == "storefront_manage"`；
   - 核心功能 ID `storefront_manage`；
   - 教程和任务内部目的地。
7. 增加文本契约测试，防止玩家可见入口仍显示旧名称，同时断言内部 ID 没有被重命名。

---

## Task 7：补齐经营中心交互、状态和几何回归

**Files：**

- Modify: `tests/management_center_layout_self_check.gd`
- Modify: `tests/workbench_overlay_state_self_check.gd`
- Modify: `tests/workbench_storefront_overlay_self_check.gd`
- Modify: `tests/showcase_rulebook_scene_self_check.gd`
- Modify: `tests/showcase_prop_theme_progression_self_check.gd`
- Modify: `tests/showcase_expansion_self_check.gd`
- Modify: `tests/showcase_round_ui_self_check.gd`
- Modify: `tests/neighborhood_dessert_theme_self_check.gd`

**Steps：**

1. 用真实鼠标点击经营中心入口，断言弹窗打开且默认页签正确。
2. 真实点击三个页签并验证：
   - 只显示目标页面；
   - 页签选中视觉不只依赖颜色；
   - 外框尺寸不变。
3. 从经营总览真实点击最近营业报告，关闭后回到经营总览。
4. 从橱窗策略真实点击规则、挑战和扩建，验证现有目标流程及背景关闭语义。
5. 验证道具和主题只在内部滚动，标题栏和页签栏保持固定。
6. 验证设备升级按钮禁用原因、升级成功反馈和页签徽标。
7. 验证关联配方跳转关闭经营中心并打开正确的设备过滤结果。
8. 验证从经营中心切换到其他底部工作台模式时仍遵守现有直接切换契约。
9. 验证教程真实点击经营中心入口仍推进 `storefront_viewed`，直接调用 `_show_page()` 不伪造玩家行为。
10. 验证非 16:9 窗口继续使用既定 letterbox 策略，不出现经营中心局部拉伸。

---

## Task 8：运行最终验证并审查工作树

**Focused Godot checks：**

```powershell
$tests = @(
  "management_center_layout_self_check.gd",
  "device_recipe_growth_ui_self_check.gd",
  "device_growth_center_skin_self_check.gd",
  "component_contract_self_check.gd",
  "right_console_experience_self_check.gd",
  "layout_refinement_self_check.gd",
  "storefront_grid_layout_self_check.gd",
  "workbench_storefront_overlay_self_check.gd",
  "workbench_overlay_state_self_check.gd",
  "workbench_bottom_launcher_self_check.gd",
  "tutorial_guide_route_self_check.gd",
  "tutorial_guide_dynamic_target_self_check.gd",
  "showcase_rulebook_scene_self_check.gd",
  "showcase_prop_theme_progression_self_check.gd",
  "showcase_expansion_self_check.gd",
  "showcase_round_ui_self_check.gd",
  "neighborhood_dessert_theme_self_check.gd",
  "panel_v1_background_self_check.gd",
  "close_image_button_self_check.gd"
)

foreach ($test in $tests) {
  $log = "D:\Project\ProjectRest\tmp\management-center-$($test).log"
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
    --headless `
    --path . `
    --log-file $log `
    -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

**Project parse：**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "D:\Project\ProjectRest\tmp\management-center-parse.log" `
  --quit
```

**Runtime verification：**

1. 在已连接的 Godot 编辑器中运行主场景。
2. 截图确认经营总览、橱窗策略和设备培养三个状态。
3. 读取可见 UI 元素，检查页签、徽标、锁定原因和升级按钮矩形。
4. 用真实鼠标完成：
   - 打开经营中心；
   - 切换页签；
   - 选择设备；
   - 执行一次符合条件的升级；
   - 跳转关联配方；
   - 关闭或切换全局弹窗。
5. 读取游戏和编辑器日志，确认没有解析错误、无效节点路径或输入层级错误。

**Diff hygiene：**

```powershell
git diff --check
git status --short
git diff --stat
```

最终逐文件审查：

- 内部 `storefront_manage` ID 没有被误改；
- 旧设备铭牌和抽屉没有活动引用；
- 经营总览没有设备摘要；
- “x 可升级”只在设备培养页签出现；
- 当前大量未提交的配方图片、预览清单和其他用户改动保持原样；
- 没有提交 `.superpowers/brainstorm` 临时文件或 Godot 日志。
