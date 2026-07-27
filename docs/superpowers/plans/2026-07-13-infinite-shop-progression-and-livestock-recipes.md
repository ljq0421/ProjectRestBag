# 无限店铺等级、设备养殖路线与增量配方实施计划

> **执行说明：** 按任务顺序实施，每个任务先写失败检查，再做最小实现并运行聚焦验证。当前工作区未授权 Git 提交，因此本计划不包含自动提交步骤。

**目标：** 将店铺等级改为可无限增长；落实 Lv.0–Lv.5 单级单设备路线、逐级养殖投入品和 17 道新增配方；让 Lv.2 以后由营业手册手动升级，升级只扣金币、不扣口碑。

**架构：** `scripts/catalog.gd` 统一提供显式基础等级、Lv.6+ 公式、设备、食材、养殖投入和配方数据；`scripts/game_state.gd` 只负责升级判定、资源扣除、等级保存和通知；`scripts/task_service.gd` 只负责教学、奖励和提示；营业手册场景拥有稳定升级 UI，脚本负责绑定状态与信号。现有 149 道配方只调整必要的 `unlock_level`，其他字段由基线快照保护。

**技术栈：** Godot 4.6.1、GDScript、`.tscn`、JSON、Python 3、Pillow、仓库内 SceneTree headless self-check。

**权威设计：** `docs/superpowers/specs/2026-07-13-device-unlock-pacing-design.zh.md`

## 全局约束

- 所有命令从 `D:\Project\ProjectRest\project-rest` 运行。
- 所有 Godot 无头命令必须传入可写的 `--log-file`，不能使用 `NUL`。
- 不实现旧开发存档迁移，不为了旧存档保留错误等级；新规则创建的存档仍需正常保存和加载。
- Lv.0 第一次上架自动进入 Lv.1；Lv.2 起只能通过营业手册的升级按钮逐级升级。
- 升级消耗金币；口碑只作累计门槛，任何升级路径都不能扣除口碑。
- 任务不得在 Lv.1–Lv.5 直接设置等级，也不得以指定配方、评鉴、评级或挑战阻塞升级。
- 稳定升级区结构写入 `.tscn`，不得由 `main_view.gd` 动态拼装。
- 现有 149 道配方只允许调整 `unlock_level`；ID、名称、设备、材料、售价、产量和标签保持不变。
- 新增 17 道配方使用设计规格中的全新 ID，不占用或改造旧配方。
- 不覆盖或清理工作区中的无关用户改动。
- 未经用户明确授权，不执行 Git commit、push 或 PR 操作。

---

## 文件与职责图

### 核心数据和运行时

- `scripts/catalog.gd`：升级定义、Lv.6+ 公式、里程碑、设备、食材、产地、加工配方和售卖配方。
- `scripts/game_state.gd`：无限等级保存、升级缺口、金币扣除、等级变化和通知。
- `scripts/task_service.gd`：Lv.0 自动升级例外、阶段教学、奖励和“可以升级”提示。
- `game_data.json`：玩家可读的分级路线摘要和任务说明。

### 营业手册 UI

- `scenes/ui/overlays/business_handbook_overlay.tscn`：升级要求、里程碑和升级按钮的稳定结构。
- `scripts/ui/overlays/business_handbook_overlay.gd`：升级信息绑定、禁用原因和 `upgrade_requested` 信号。
- `scripts/main_view.gd`：接收升级请求、调用状态方法并刷新页面和通知。

### 配方展示与资产

- `doc/recipe_display_config.json`：166 道配方的占格、形状和旋转配置。
- `resources/ingredient_icons/`：新增养殖投入品和产物图标。
- `resources/recipe_icons/`：17 道新增配方各自以配方 ID 命名的 512×512 源图标。
- `resources/recipe_icons_catalog/`、`resources/recipe_icons_inventory/`、`resources/recipe_icons_action/`、`resources/recipe_icons_showcase/`：生成后的各使用面图标。
- `doc/recipe_data_audit.md`：重新生成的严格配方数据审计。

### 聚焦验证

- `tests/fixtures/existing_recipe_contract_v1.json`
- `tools/snapshot_recipe_contract.py`
- `tests/infinite_shop_level_self_check.gd`
- `tests/progression_catalog_self_check.gd`
- `tests/business_handbook_upgrade_self_check.gd`
- `tests/task_mainline_self_check.gd`
- `tests/mvp_self_check.gd`

---

### Task 1：冻结现有 149 道配方并建立失败契约

**文件：**

- Create: `tools/snapshot_recipe_contract.py`
- Create: `tests/fixtures/existing_recipe_contract_v1.json`
- Create: `tests/infinite_shop_level_self_check.gd`
- Create: `tests/progression_catalog_self_check.gd`

**接口：**

- `snapshot_recipe_contract.py` 从 `scripts/catalog.gd` 导出每道现有配方的 `id/name/device/materials/price/output_count/tags`，明确排除 `unlock_level`。
- `existing_recipe_contract_v1.json` 固定实施前 149 道配方的不可变字段。
- 两个自检分别保护升级数学和内容目录。

- [ ] **Step 1：在修改 catalog 前生成配方基线**

脚本只允许在本任务首次执行时生成基线，并断言源目录恰好为 149 道配方。JSON 按 ID 排序，包含 `meta.recipe_count = 149`。生成后不要在实现阶段重新覆盖该文件。

- [ ] **Step 2：编写无限升级失败检查**

覆盖：

- Lv.0 不能手动升级；Lv.1 可按 180 金币、8 累计口碑升 Lv.2。
- Lv.2–Lv.5 的要求分别为 `360/22`、`680/48`、`1100/85`。
- Lv.6、10、11、16、21、26、40、50、75、100 与规格表一致。
- 目标营业日按 `5.0/5.5/6.0/6.5/7.0` 分段，费用和累计口碑长期单调增长。
- 升级前后口碑完全相等，金币只扣当级费用。
- 一次调用只提升一级。
- Lv.100 可通过 `to_dict()` / `from_dict()` 往返且不被裁剪。

- [ ] **Step 3：编写内容目录失败检查**

覆盖：

- 设备开放等级依次为 Lv.1 研磨机、Lv.2 烤箱、Lv.3 冷藏柜、Lv.4 煎烤盘、Lv.5 搅拌机；圆锅仍由 Lv.0 教学开放。
- 核心食材新增数量为 `3 / 6 / 10 / 10 / 10 / 10`。
- 售卖配方新增数量为 `1 / 8 / 17 / 23 / 35 / 44`。
- Lv.0–Lv.5 共 128 道，Lv.6+ 储备池 38 道，全目录 166 道。
- 每道配方不早于设备、原料和加工产物等级。
- 17 个新增 ID 与规格一致且不重复。
- 基线中的 149 道配方除 `unlock_level` 外与 fixture 完全一致。

- [ ] **Step 4：运行并确认测试按预期失败**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\infinite-shop-level-red.log" -s res://tests/infinite_shop_level_self_check.gd
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\progression-catalog-red.log" -s res://tests/progression_catalog_self_check.gd
```

Expected: 前者因有限升级表、口碑扣除和等级裁剪失败；后者因旧设备路线、缺少养殖内容和配方数仍为 149 失败。

---

### Task 2：实现无限升级定义与单级单设备路线

**文件：**

- Modify: `scripts/catalog.gd`
- Modify: `scripts/game_state.gd`
- Test: `tests/infinite_shop_level_self_check.gd`

**接口：**

- Produces: `Catalog.get_upgrade_definition(target_level: int) -> Dictionary`
- Produces: `Catalog.get_next_level_milestone(current_level: int) -> Dictionary`
- Produces: `GameState.upgrade_eligibility() -> Dictionary`
- Preserves: `GameState.can_upgrade() -> bool`
- Preserves: `GameState.upgrade() -> bool`

- [ ] **Step 1：把基础等级改为显式定义**

Lv.0–Lv.5 返回设计规格中的阶段名、金币、累计口碑、设备和文案。设备规则：

- 圆锅继续由 `main_l0_harvest_rice` 教学奖励开放。
- 研磨机 `unlock_level = 1`。
- 烤箱 `unlock_level = 2`。
- 冷藏柜 `unlock_level = 3`。
- 煎烤盘 `unlock_level = 4`。
- 搅拌机 `unlock_level = 5`。

保留 `get_upgrade_table()` 供旧只读调用者读取 Lv.0–Lv.5 显式定义；所有运行时升级判定改用 `get_upgrade_definition()`。新增空或稀疏的 `LEVEL_MILESTONES` 配置，未配置奖励的等级也必须可以升级。

- [ ] **Step 2：实现 Lv.6+ 统一公式**

严格实现规格中的 `D(L)`、`C(L)`、`DeltaR(L)` 和 `R(L)`。累计口碑可以使用静态缓存，但任意调用顺序都必须得到相同结果，不能依赖有限表的最大键值。

- [ ] **Step 3：提供可解释的升级缺口**

`upgrade_eligibility()` 至少返回：

```gdscript
{
    "ok": bool,
    "target_level": int,
    "cost": int,
    "required_reputation": int,
    "missing_coins": int,
    "missing_reputation": int,
    "device_id": String,
    "milestone": Dictionary
}
```

Lv.0 返回 `tutorial_required`，不允许按钮跳过第一次上架教学。

- [ ] **Step 4：修正升级资源变化和等级保存**

- `upgrade()` 只扣金币，不扣口碑。
- 单次只提升一级并记录 `upgrade` 事件。
- `from_dict()` 不再通过 `_max_level()` 裁剪等级，改为接受任意非负整数。
- 不提升 `SAVE_VERSION`，不添加旧开发存档迁移分支。
- 保留新规则存档的正常序列化和反序列化。

- [ ] **Step 5：运行无限升级检查**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\infinite-shop-level-green.log" -s res://tests/infinite_shop_level_self_check.gd
```

Expected: `INFINITE_SHOP_LEVEL_SELF_CHECK_PASS`。

---

### Task 3：落实逐级食材、养殖投入和 17 道新增配方

**文件：**

- Modify: `scripts/catalog.gd`
- Modify: `game_data.json`
- Test: `tests/progression_catalog_self_check.gd`

**接口与数据：**

- New ingredients/inputs: `bee_colony`、`duckling`、`duck_egg`、`duck_meat`、`lamb`、`goat_milk`、`mutton`。
- Ranch outputs: 蜜蜂群→蜂蜜；小鸭苗→鸭蛋、鸭肉；小羊羔→羊奶、羊肉。
- New recipes: 规格第 2.3、2.5、2.6、2.7 节列出的 17 个 ID。

- [ ] **Step 1：重排现有食材和生产投入品等级**

按规格设置全部食材、种子和幼畜等级。把蜂蜜来源改为养殖场，农场和林场的 `items` 都移除蜂蜜；养殖场加入 `bee_colony`、`duckling`、`lamb`。新增产物不可直接采购。

- [ ] **Step 2：加入新养殖投入与产物**

沿用 `harvest_outputs` 多产物结构，并为新条目提供价格、时长、标签、采购分类、谜面名和 `purchasable`。数值先沿用相邻阶段的线性梯度，不引入新生产机制。

- [ ] **Step 3：重排现有配方的 unlock_level**

以设计规格逐级清单为唯一目标。原配方只能修改 `unlock_level`；实现后由 fixture 证明其他字段未变。

- [ ] **Step 4：新增 17 道独立配方**

完整写入规格规定的 ID、名称、设备和材料，并补齐现有目录要求的售价、产量和规范标签。售价与同级、同设备、同材料数配方对齐，不引入新标签词。

- [ ] **Step 5：同步玩家可读路线数据**

更新 `game_data.json` 的 `unlock_route`，删除旧设备和终局表述，准确列出每级设备、养殖投入和核心食材。

- [ ] **Step 6：运行目录检查**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\progression-catalog-green.log" -s res://tests/progression_catalog_self_check.gd
```

Expected: `PROGRESSION_CATALOG_SELF_CHECK_PASS`，并证明现有 149 道配方不可变字段未被修改。

---

### Task 4：补齐展示配置和图标资产

**文件：**

- Modify: `doc/recipe_display_config.json`
- Modify: `doc/recipe_data_audit.md`
- Create: `resources/ingredient_icons/{bee_colony,duckling,duck_egg,duck_meat,lamb,goat_milk,mutton}.png`
- Create: `resources/recipe_icons/` 下以 17 个新增配方 ID 分别命名的 PNG 文件
- Regenerate: `resources/recipe_icons_catalog/`
- Regenerate: `resources/recipe_icons_inventory/`
- Regenerate: `resources/recipe_icons_action/`
- Regenerate: `resources/recipe_icons_showcase/`
- Modify test: `tests/inventory_recipe_icon_layout_self_check.gd`
- Test: `tests/test_generate_catalog_recipe_icons.py`
- Test: `tests/test_generate_inventory_recipe_icons.py`
- Test: `tests/test_generate_action_recipe_icons.py`
- Test: `tests/test_generate_showcase_recipe_icons.py`
- Test: `tests/test_recipe_data_audit.py`

- [ ] **Step 1：为 17 道新配方配置展示形状**

将 `meta.total_recipes` 改为 166，为每个新 ID 配置 `recipe_name`、`cell_count`、`shape_category`、`default_shape`、`rotatable`。杯装/羹汤优先竖杯款，饼/糕优先横盘或中块款，焗饭和烧卖避免全部使用同一形状。

- [ ] **Step 2：生成新增食材与配方源图标**

实施时必须使用 `imagegen` 技能生成位图；保持现有温暖手绘、粗深棕轮廓、透明背景和居中留白风格。食材图标输出到 `resources/ingredient_icons`，配方源图输出为 512×512 PNG 到 `resources/recipe_icons`。

- [ ] **Step 3：使用工作区随附 Python 生成各尺寸图标**

```powershell
$py = "C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
& $py tools/generate_catalog_recipe_icons.py --source-dir resources/recipe_icons --output-dir resources/recipe_icons_catalog --catalog-path scripts/catalog.gd
& $py tools/generate_inventory_recipe_icons.py --source-dir resources/recipe_icons --output-dir resources/recipe_icons_inventory --catalog-path scripts/catalog.gd
& $py tools/generate_action_recipe_icons.py --source-dir resources/recipe_icons --output-dir resources/recipe_icons_action
& $py tools/generate_showcase_recipe_icons.py --source-dir resources/recipe_icons --output-dir resources/recipe_icons_showcase --config-path doc/recipe_display_config.json
```

- [ ] **Step 4：触发 Godot 资源导入**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\progression-assets-import.log" --quit
```

Expected: 无 `SCRIPT ERROR`、无缺失 PNG 或导入错误。

- [ ] **Step 5：运行图标与数据审计**

```powershell
$py = "C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
& $py -m unittest discover -s tests -p "test_generate_*recipe_icons.py"
& $py tools/audit_recipe_data.py --catalog scripts/catalog.gd --display-config doc/recipe_display_config.json --display-rules doc/display_rules_full.json --taxonomy doc/recipe_tag_taxonomy.json --out doc/recipe_data_audit.md --strict
& $py tests/test_recipe_data_audit.py
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\progression-icon-layout.log" -s res://tests/inventory_recipe_icon_layout_self_check.gd
```

Expected: 166 道配方均有展示配置和图标，严格审计无阻断项。

---

### Task 5：把任务系统从“升级所有者”改为教学和提示

**文件：**

- Modify: `scripts/task_service.gd`
- Modify: `game_data.json`
- Modify: `tests/task_mainline_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

- [ ] **Step 1：先改写任务契约测试**

断言：

- 只有 `main_l0_list_first_product` 的 progression reward 包含 `set_level = 1`。
- `main_l1_upgrade` 至 `main_l4_upgrade` 不含 `set_level`，完成和领奖都不能改变等级。
- 金币和口碑达到门槛时，升级准备任务仍可完成并显示“可以升级”。
- 实际等级只能在玩家调用 `GameState.upgrade()` 后改变。

- [ ] **Step 2：移除任务提前设备奖励**

`main_l0_make_first_product` 不再奖励研磨机；研磨机随自动进入 Lv.1 开放。圆锅仍由收获水稻教学开放。

- [ ] **Step 3：重排阶段教学主题**

- Lv.1：研磨和正式营业。
- Lv.2：烤箱和基础烘焙。
- Lv.3：冷藏、临期和库存规划。
- Lv.4：煎烤与多设备菜单。
- Lv.5：搅拌、复合配方和招牌路线。

任务可以奖励金币、口碑、工具或提示，但不能直接设置 Lv.2 以上等级。

- [ ] **Step 4：删除终局文案**

把“名店主线完成”“MVP 完成”“后 MVP”改为“基础厨房建设完成”“长期经营”或具体挑战名称。Lv.5 评级和评鉴继续作为经营证明，不作为结局。

- [ ] **Step 5：运行任务聚焦检查**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\task-mainline-progression.log" -s res://tests/task_mainline_self_check.gd
```

Expected: `TASK_MAINLINE_SELF_CHECK_PASS`；若现有测试包含旧自动升级断言，全部更新为手动升级路径。

---

### Task 6：在营业手册加入手动升级区和可见反馈

**文件：**

- Modify: `scenes/ui/overlays/business_handbook_overlay.tscn`
- Modify: `scripts/ui/overlays/business_handbook_overlay.gd`
- Modify: `scripts/main_view.gd`
- Create: `tests/business_handbook_upgrade_self_check.gd`

**接口：**

- Signal: `upgrade_requested()`
- Produces: `BusinessHandbookOverlay.refresh(state, catalog)` 中的升级绑定。
- Consumes: `GameState.upgrade_eligibility()`。

- [ ] **Step 1：写失败场景检查**

断言阶段路线区域拥有稳定节点：

- `UpgradeRequirementLabel`
- `UpgradeGapLabel`
- `NextMilestoneLabel`
- `UpgradeButton`

并验证 Lv.0 隐藏/禁用手动升级、Lv.1 资源不足显示两个缺口、资源满足时按钮可用、Lv.5 后仍显示公式生成的下一等级。

- [ ] **Step 2：在 tscn 中建立升级结构**

将升级内容放在右栏“阶段路线”内或其紧邻的独立 `PanelContainer`；保持现有左右栏布局，不在脚本中动态创建稳定控件。

- [ ] **Step 3：绑定要求、缺口和里程碑**

- 金币不足：显示还差多少金币。
- 累计口碑不足：显示还差多少口碑。
- 两者不足：同时显示两个缺口。
- Lv.0：提示完成第一次上架教学。
- Lv.6+：显示 5–7 个标准营业日平衡说明和下一个已配置里程碑。

- [ ] **Step 4：由 main_view 处理升级请求**

连接 `upgrade_requested`，调用 `state.upgrade()`。成功后刷新营业手册、目录、输出、研究和通知；失败时显示当前缺口，不静默失败。成功通知包含新等级、新设备或里程碑及下一等级要求。

- [ ] **Step 5：运行营业手册检查**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\business-handbook-upgrade.log" -s res://tests/business_handbook_upgrade_self_check.gd
```

Expected: `BUSINESS_HANDBOOK_UPGRADE_SELF_CHECK_PASS`。

---

### Task 7：同步文档与当前运行规则

**文件：**

- Modify: `doc/2026-07-05-progressive-unlock-route-and-tasks.md`
- Modify: `doc/2026-07-10-developer-quick-reference.md`
- Modify: `docs/superpowers/specs/2026-07-13-business-day-visible-customer-goal-ladder-design.zh.md`
- Verify: `game_data.json`

- [ ] **Step 1：同步玩家路线文档**

写入新设备、养殖、食材和配方数量；明确 Lv.5 是基础厨房完成而不是结局，Lv.6+ 使用统一公式持续增长。

- [ ] **Step 2：同步开发者快速参考**

记录升级定义入口、`upgrade_eligibility()` 返回结构、五种逐级养殖投入、166 道配方总数，以及“旧配方仅 unlock_level 可变”契约。

- [ ] **Step 3：清理陈旧终局和有限等级表达**

```powershell
rg -n "MVP 完成|后 MVP|最终等级|Lv\.5 结束|最大等级|口碑.*扣" scripts game_data.json doc docs/superpowers/specs
```

Expected: 当前规则来源中无把 Lv.5、评级或评鉴描述为结局的文本；历史计划若保留旧措辞，明确标注非当前规则来源，不机械改写已完成计划。

---

### Task 8：完整验证和补丁边界审查

**文件：**

- Verify all files changed by Tasks 1–7.

- [ ] **Step 1：运行聚焦自检**

```powershell
$tests = @(
  'infinite_shop_level_self_check.gd',
  'progression_catalog_self_check.gd',
  'task_mainline_self_check.gd',
  'business_handbook_upgrade_self_check.gd',
  'recipe_unlock_notification_self_check.gd',
  'inventory_recipe_icon_layout_self_check.gd',
  'output_sites_self_check.gd'
)
foreach ($test in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\$($test).log" -s "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

- [ ] **Step 2：运行 Python 严格审计**

```powershell
$py = "C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
& $py -m unittest discover -s tests -p "test_*.py"
& $py tools/audit_recipe_data.py --catalog scripts/catalog.gd --display-config doc/recipe_display_config.json --display-rules doc/display_rules_full.json --taxonomy doc/recipe_tag_taxonomy.json --out doc/recipe_data_audit.md --strict
```

- [ ] **Step 3：运行广域回归**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\infinite-progression-mvp.log" -s res://tests/mvp_self_check.gd
```

Expected: 新进度断言通过；若广域测试存在与本功能无关的既有失败，必须记录具体失败，不得用聚焦测试替代或隐瞒。

- [ ] **Step 4：检查补丁边界**

```powershell
git diff --check
git status --short
git diff -- scripts/catalog.gd scripts/game_state.gd scripts/task_service.gd game_data.json scenes/ui/overlays/business_handbook_overlay.tscn scripts/ui/overlays/business_handbook_overlay.gd scripts/main_view.gd tests doc docs/superpowers/specs
```

Expected: 无空白错误；所有变更都能映射到本计划任务；无旧开发存档迁移代码；无无关工作区文件被覆盖。
