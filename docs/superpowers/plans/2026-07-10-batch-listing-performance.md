# “上架全部”性能优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让批量上架按配方批量更新状态，并且每次用户操作只执行一次存档和一次最终 UI 刷新。

**Architecture:** 保留 `_drop_showcase_data()` 作为单件交互路径；在 `main_view.gd` 中新增无 UI 副作用的批量查位与批量转移 helper。`_list_all_available_products()` 只协调状态更新，两个现有入口继续负责最终持久化和刷新。

**Tech Stack:** Godot 4.6.1、GDScript、现有 SceneTree headless 自检。

## Global Constraints

- 不改变单件拖拽、移动、旋转和售卖路径。
- 不触碰用户存档；自检继续注入临时存档路径。
- Godot headless 命令必须使用可写的 `--log-file`。
- 不提交工作区改动。

---

### Task 1: 锁定批量函数的无副作用契约

**Files:**
- Modify: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: `Main._list_all_available_products()`、可覆盖的 `save_path`、现有 `ShowcaseGrid`。
- Produces: 批量内部不存档、不重建橱窗节点的回归断言。

- [x] **Step 1: 写失败测试**

在现有批量上架状态测试中改为直接调用 `_list_all_available_products()`，使用 25 份和 3 份库存；调用前删除专用临时存档并记录首个橱窗按钮实例 ID。调用后断言库存全部转移、临时存档不存在、首个按钮实例 ID 未变化。

- [x] **Step 2: 验证测试因现有逐份副作用失败**

运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/mvp_self_check.gd
```

预期：失败信息指出批量函数写入了存档或替换了橱窗按钮。

### Task 2: 实现按配方批量状态更新

**Files:**
- Modify: `scripts/main_view.gd`
- Test: `tests/mvp_self_check.gd`

**Interfaces:**
- Produces: `_first_available_showcase_placement(recipe_id: String, variant_id: String) -> Dictionary`。
- Produces: `_list_recipe_stock_batch(recipe_id: String, now_unix: int) -> int`。
- Consumes: `GameState.add_display_item_stock()`、`GameState.list_display_item()`、`_sync_showcase_slot_from_display_item()`。

- [x] **Step 1: 写最小实现**

新增纯查位 helper，返回 `slot_index` 和 `cells`；新增批量转移 helper，一次读取并转移某配方全部库存。重写 `_list_all_available_products()`，每个配方只调用一次批量 helper。

- [x] **Step 2: 验证聚焦回归转绿**

运行 Task 1 的 `mvp_self_check.gd` 命令，预期输出 `MVP self-check passed.` 且退出码为 0。

### Task 3: 完整验证

**Files:**
- Verify: `scripts/main_view.gd`
- Verify: `tests/mvp_self_check.gd`

**Interfaces:**
- Consumes: Task 1 和 Task 2 的最终实现。
- Produces: 主场景加载、研发制作布局、库存批量入口与 MVP 交互路径的验证证据。

- [x] **Step 1: 运行语法和主场景加载检查**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" --quit
```

- [x] **Step 2: 运行研发制作聚焦布局检查**

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/layout_refinement_self_check.gd
```

- [x] **Step 3: 再次运行完整 MVP 自检**

运行 `mvp_self_check.gd`，确认退出码为 0，并检查 `git diff --check` 无空白错误。
