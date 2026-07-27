# 店铺升级要求整体提高实现计划

## 目标

把 Lv.2～Lv.6 固定升级要求和 Lv.7+ 生成公式替换为已批准的新曲线，并让现有成长任务卡自动显示新门槛。

## 实施步骤

1. 先修改 `tests/infinite_shop_level_self_check.gd`，写入 Lv.2～Lv.12 新锚点、目标轮数递增与封顶断言。
2. 修改 `tests/task_shop_upgrade_self_check.gd`，把 Lv.2 卡片、差 1 资源、扣款和旧卡保护切换到 900/30 与 2200/80。
3. 运行两个聚焦测试，确认因旧 Catalog 数值而失败。
4. 修改 `scripts/catalog.gd`：增加明确 Lv.6 定义，替换 Lv.7+ 目标轮数、资金与累计口碑公式，并在 Lv.247 的 `int64` 安全边界停止生成升级定义。
5. 修改 `game_data.json`：同步 Lv.2～Lv.6 玩家文案与新数值。
6. 运行聚焦测试转绿，再运行等级、任务页、任务主线和组件契约回归。
7. 检查 JSON、差异和遗留旧数值，确保未覆盖工作区其他未提交改动。

## 预期修改文件

- `scripts/catalog.gd`
- `game_data.json`
- `tests/infinite_shop_level_self_check.gd`
- `tests/task_shop_upgrade_self_check.gd`
- 必要时补充负责数据与玩家文案一致性的聚焦自检

## 验证

所有 Godot 自检从 `project-rest-new` 执行，并传入可写的 `--log-file`。重点验证新锚点、公式样例、单调递增、目标轮数封顶、Lv.247/Lv.248 数值边界、恰好达标扣款、差 1 不可升级和动态任务卡显示。
