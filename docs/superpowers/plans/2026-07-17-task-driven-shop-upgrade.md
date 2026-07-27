# 任务驱动的店铺升级实现计划

## 目标

把 Lv.1 及之后的店铺升级作为“成长任务”中的动态并行任务。玩家在任务详情中查看金币与累计口碑进度，达标后点击“升级店铺”，由既有 `GameState.upgrade()` 扣款并升级。

## 实施步骤

1. 先新增聚焦自检 `tests/task_shop_upgrade_self_check.gd`，覆盖 Lv.0 无升级卡、Lv.1 并行任务、动态进度、升级资格、扣款与下一等级卡。
2. 先运行该自检并确认因动态升级任务缺失而失败。
3. 在 `TaskService` 中增加动态升级任务构造，并让当前成长任务返回所有可用成长项而不是单槽。
4. 更新任务卡与详情组件：增加“升级”类型、动态目标显示和“升级店铺”专用动作。
5. 在 `main_view.gd` 局部增加升级请求处理，成功时保存、刷新资源与任务，并展示既有升级通知；失败时显示资源缺口。
6. 把任务页“当前目标”改为“成长任务”，同步顶部摘要与相关自检。
7. 更新 `game_data.json` 中营业手册遗留文案。
8. 运行聚焦自检转绿，再运行任务可见性、任务覆盖层、主线和无限等级相关回归自检。
9. 检查工作区差异，确保不覆盖已有未提交修改。

## 预期修改文件

- `scripts/task_service.gd`
- `scripts/ui/overlays/task_overlay.gd`
- `scripts/ui/overlays/task_entry_button.gd`
- `scripts/ui/overlays/task_detail_content.gd`
- `scripts/main_view.gd`
- `game_data.json`
- `tests/task_shop_upgrade_self_check.gd`
- 与页签名称或并行任务数量直接相关的现有聚焦自检

## 验证命令

所有 Godot 命令从 `project-rest-new` 执行，并传入可写日志文件：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --log-file "$env:TEMP\godot-headless.log" -s res://tests/task_shop_upgrade_self_check.gd
```

回归验证优先选择直接相关的任务和等级自检，避免用无关的大套件掩盖结果。
