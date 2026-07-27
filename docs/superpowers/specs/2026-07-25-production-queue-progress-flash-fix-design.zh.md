# 制作队列绿色进度闪烁修复设计

## 问题

`ProductionQueueRecipeRow` 是 `PanelContainer`。当前半透明绿色
`ProgressFill` 是它的直接子节点，同时脚本又手动设置
`ProgressFill.position` 和 `ProgressFill.size`。

制作、加工或产地收获触发制作工作台刷新时，容器重新布局直接子节点，
会把 `ProgressFill` 暂时拉伸到整行；下一次运行时进度刷新再恢复其宽度，
因此出现绿色闪烁。

## 方案

在队列行下增加全尺寸 `ProgressLayer: Control`，把 `ProgressFill` 移到
`ProgressLayer` 内。

- `PanelContainer` 只负责把 `ProgressLayer` 铺满整行。
- `ProgressFill` 不再是 `Container` 的直接子节点，其宽度只由
  `ProductionQueueRecipeRow._apply_progress_width()` 控制。
- `Content`、行高、颜色、按钮、材料列表和交互信号保持不变。

不采用修改队列行根节点类型的方案，因为这会扩大主题、最小尺寸和裁剪行为的
回归范围；不改用 `ProgressBar`，因为该问题不需要引入新的主题状态。

## 验收标准

1. 非制作中的行在队列刷新和重新排序后，绿色进度宽度始终为零。
2. 制作中的行在队列刷新和重新排序后，绿色宽度始终等于行宽乘以实际进度。
3. 点击制作小麦以及农场、养殖场等产地收获时，制作队列不再整行闪绿。
4. 现有制作按钮、材料显示、倒计时、队列排序与行高不变。

## 验证

扩展制作队列场景自检，覆盖 `ProgressLayer` 层级、鼠标穿透与刷新后进度宽度；
运行制作队列场景、交互和生产 UI 聚焦自检，并检查 Godot 日志中没有新增错误。
