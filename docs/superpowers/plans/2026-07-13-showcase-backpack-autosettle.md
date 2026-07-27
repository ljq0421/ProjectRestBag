# 橱窗独立售卖与跳金币实施计划

**目标：** 在 `feature/showcase-backpack-autosettle` 上实现每件商品独立自动售卖、缺货保形、离线补算、移动保进度和跳金币反馈。

**依据：** `docs/superpowers/specs/2026-07-13-showcase-backpack-autosettle-design.zh.md`

**方法：** 所有行为改动遵循 RED → GREEN → REFACTOR。每个任务先新增或修改最小自检并确认因缺少目标能力而失败，再写最少实现使其通过。

## Task 1：建立独立售卖领域服务

**Files**

- Create: `scripts/showcase_auto_sale_service.gd`
- Create: `tests/showcase_auto_sale_service_self_check.gd`

**RED**

- 断言不同周期的商品独立到期。
- 断言同一 tick 返回全部到期商品并按锚点排序。
- 断言离线数量受库存限制。
- 断言进度比例可映射到新的周期时长。
- 断言系统时间倒退、零周期和空规则安全。

**GREEN**

- 实现纯计算 API：在线计划、离线计划、进度重映射。
- 计划只返回确定性的商品批次，不修改状态、不创建 UI、不保存。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-showcase-auto-sale.log" -s res://tests/showcase_auto_sale_service_self_check.gd
```

## Task 2：让 GameState 以 display_items 为售卖真相

**Files**

- Modify: `scripts/game_state.gd`
- Modify: `tests/showcase_auto_sale_service_self_check.gd`
- Modify: `tests/showcase_sale_feedback_self_check.gd`

**RED**

- 售出最后一份后 `display_items` 仍保留占格且 `stock == 0`。
- 补货恢复同一条目，不重新摆放。
- 周期字段能序列化当前开发期存档。
- 最近成交最多保留 30 条。
- 不再存在 `cashier_summary` 消费语义。

**GREEN**

- 增加周期字段和批量应用成交入口。
- `remove_display_item_stock()` 保留零库存条目。
- 新增 `recent_showcase_sales`，删除集中收银汇总路径。
- `display_slots` 仅保留现有界面命中投影，不持有独立经济状态。

## Task 3：接入在线与离线自动结算

**Files**

- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_auto_sale_service_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**RED**

- 同一 tick 两件到期商品均真实入账。
- 每件只扣正确库存，任务与成长使用真实数量。
- 离线补算合并入账且只保存一次。
- 不再调用集中收银。

**GREEN**

- `_process_showcase_sales()` 使用领域服务生成并应用完整批次。
- 统一构造成交事件，在线逐商品投递、离线只投递一条汇总表现。
- 删除 `_show_cashier_summary()` 与回放路径。

## Task 4：补货、移动和旋转保留进度

**Files**

- Modify: `scripts/main_view.gd`
- Modify: `scripts/game_state.gd`
- Modify: `tests/showcase_auto_sale_service_self_check.gd`
- Modify: `tests/mvp_self_check.gd`

**RED**

- 同款拖入缺货商品时原位补货。
- 移动和旋转后完成比例不变。
- 新布局售速立即换算剩余时间。
- 已到期商品先成交，不能通过移动延后。

**GREEN**

- 在 drop/move/rotate 路径中结算到期项并调用进度重映射。
- 同款命中已有形状时优先走补货路径。

## Task 5：实现整体进度、缺货态和跳金币反馈

**Files**

- Modify: `scenes/Main.tscn`
- Modify: `scenes/ui/storefront/showcase_board.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `scripts/ui/storefront/showcase_feedback_director.gd`
- Create: `tests/showcase_backpack_feedback_self_check.gd`
- Create: `tests/showcase_backpack_scene_self_check.gd`

**RED**

- 每件商品只有一条整体进度元数据。
- 缺货商品保留图标与占格并显示明确提示。
- 同屏完整成交反馈最多四组，溢出汇总金额与数量正确。
- 金币和状态覆盖层均不拦截输入。
- 离线批次只产生一个汇总表现。

**GREEN**

- 复用场景声明的反馈覆盖层，在脚本中创建单件商品进度、金币和离线汇总表现。
- 商品成交播放占格整体回弹、金额浮字、3–6 枚弧线金币和顶部余额回弹。
- 同一秒成交按约 0.12 秒错峰，超量只压缩表现。

## Task 6：重做右侧橱窗经营信息

**Files**

- Modify: `scenes/Main.tscn`
- Modify: `scripts/main_view.gd`
- Modify: `tests/right_console_experience_self_check.gd`
- Modify: `tests/showcase_sale_feedback_self_check.gd`

**RED**

- 页面不存在“集中收银”动作。
- 页面显示实时效率、缺货提醒、最近成交和收益来源。
- 最近成交读取结构化 `recent_showcase_sales`。

**GREEN**

- 移除集中收银按钮与消费汇总文案。
- 保留现有左右主结构和四个控制台页面。

## Task 7：完整回归与整理

**Verify**

- `tests/showcase_auto_sale_service_self_check.gd`
- `tests/showcase_backpack_feedback_self_check.gd`
- `tests/showcase_backpack_scene_self_check.gd`
- `tests/showcase_sale_feedback_self_check.gd`
- `tests/layout_refinement_self_check.gd`
- `tests/right_console_experience_self_check.gd`
- `tests/inventory_cell_name_display_self_check.gd`
- `tests/purchase_cart_self_check.gd`
- `git diff --check`

若 `mvp_self_check.gd` 仍因与本功能无关的基线漂移失败，单独报告，不扩大本次修复范围。
