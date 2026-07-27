# 待结算按钮重新打开弹窗实现计划

**目标：** 让营业轮处于 `settlement` 且存在 `pending_showcase_settlement` 时，“待结算”按钮可点击并重新打开当前结算弹窗；异常缺失结算数据时禁止开始下一轮。

## 任务 1：锁定真实恢复路径

- 修改 `tests/showcase_business_round_scene_self_check.gd`。
- 营业结束后断言“待结算”按钮启用。
- 隐藏结算弹窗并通过按钮的真实 `pressed` 信号重新打开。
- 断言重新打开不会改变金币、营业次数、轮次 ID、待结算报价或已应用结算 ID。
- 结算完成后断言按钮恢复“开始营业”。
- 构造 `settlement` 但无待结算数据的异常状态，断言显示“结算异常”并禁用。

## 任务 2：实现按钮双重语义

- 修改 `scripts/main_view.gd`。
- `_start_showcase_business_round()` 优先处理合法待结算恢复和异常待结算状态，再进入现有开始营业校验。
- `_refresh_showcase_round_controls()` 按阶段与待结算数据共同设置文字、禁用状态和工具提示。
- 不修改结算服务、存档结构、场景节点或公共信号。

## 任务 3：验证

- 运行 `showcase_business_round_scene_self_check.gd`。
- 运行 `showcase_round_ui_self_check.gd`。
- 运行 `showcase_round_settlement_dialog_self_check.gd`。
- 所有 Godot 命令使用显式可写的 `--log-file`。
- 运行 `git diff --check` 并复核仅有目标文件改动。
