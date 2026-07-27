# 移除单配方陈列容量上限 Implementation Plan

**目标：** 仓库库存成为单配方上架数量的唯一数量上限，同时保留橱窗占格、放置和销售规则。

**设计：** [2026-07-16-remove-showcase-display-capacity-design.zh.md](../specs/2026-07-16-remove-showcase-display-capacity-design.zh.md)

## Task 1：用营业轮服务测试固定无限补货合同

**Files**

- Modify: `tests/showcase_round_sale_service_self_check.gd`
- Modify: `scripts/showcase_round_sale_service.gd`

**RED**

- 把旧的容量公式断言改为“不再暴露容量计算”。
- 传入带旧 `display_capacity` 的状态并补入超过旧上限的数量，断言全部接收、零拒绝、事件记录完整数量。
- 断言新建营业轮状态不生成 `display_capacity`。

**GREEN**

- 删除 `display_capacity()`。
- `build_item_states()` 不再写入容量。
- `refill_item()` 对合法商品完整接受请求数量并忽略旧字段。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-round-sale-service.log" -s res://tests/showcase_round_sale_service_self_check.gd
```

## Task 2：用状态测试固定调整阶段无限上架合同

**Files**

- Modify: `tests/showcase_business_round_state_self_check.gd`
- Modify: `scripts/game_state.gd`

**RED**

- 建立一格陈列项及超过旧容量的仓库库存。
- 断言 `add_display_item_stock()` 一次转入全部请求数量，仓库扣减正确，`fresh_stock`、`carried_stock`、`stock` 同步。

**GREEN**

- 直接以请求数量校验和扣减仓库库存。
- 删除 `get_display_item_capacity()` 与 `get_display_item_free_capacity()`。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-business-round-state.log" -s res://tests/showcase_business_round_state_self_check.gd
```

## Task 3：移除页面批量截断和容量文案

**Files**

- Modify: `tests/showcase_research_bulk_live_listing_self_check.gd`
- Modify: `scripts/main_view.gd`

**RED**

- 批量上架测试准备超过旧容量的库存，断言已有商品和新商品均按全部仓库库存转移。
- 营业中补货断言完整扣减库存，状态反馈不含容量文案。

**GREEN**

- 删除新品批量上架的占格容量截断。
- 删除营业补货“容量已满”分支和状态中的容量显示。
- 保留真实库存不足与新品空间不足反馈。

**Verify**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\showcase-research-bulk-live-listing.log" -s res://tests/showcase_research_bulk_live_listing_self_check.gd
```

## Task 4：回归与残留审计

**Files**

- Verify only

**Verify**

- 运行上述三项自检及 `showcase_live_listing_self_check.gd`、`showcase_business_round_scene_self_check.gd`。
- 搜索运行代码和测试中的 `display_capacity`、`get_display_item_capacity`、`get_display_item_free_capacity`、`陈列容量已满`、批量容量公式残留。
- 运行 `git diff --check` 并审查只修改本任务文件。

