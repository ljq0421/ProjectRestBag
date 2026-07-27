# 外婆对话与目标箭头互斥实施计划

## 目标

落实 `2026-07-20-tutorial-dialogue-pointer-exclusive-design.zh.md`：新步骤先显示外婆对话；玩家点击动作化按钮后，对话隐藏，左下角外婆图标保留，目标有效时才显示箭头；点击图标回看期间再次隐藏箭头。

## 变更范围

- 修改 `tests/tutorial_guide_overlay_self_check.gd`。
- 修改 `scripts/ui/overlays/tutorial_guide_overlay.gd`。
- 如聚焦测试证明主视图协调存在缺口，才最小修改 `scripts/main_view.gd`；否则保持不变。
- 不修改引导步骤、业务完成事件、对话目录、存档结构或场景布局。

## 实施步骤

### 1. 建立失败回归

在 `tutorial_guide_overlay_self_check.gd` 中改写现有错误预期，并覆盖：

- 展开对话时箭头隐藏。
- 点击动作按钮后图标与箭头显示、对话与遮罩隐藏。
- 点击外婆图标后对话显示、图标与箭头隐藏。
- 再次确认可返回行动阶段。
- 弹窗暂停恢复保留对话或行动阶段。
- 无效目标只隐藏箭头，不隐藏行动阶段图标。
- 完成阶段不显示图标和箭头。

先运行该自检并确认现有代码失败。

### 2. 实现明确显示阶段

在 `tutorial_guide_overlay.gd` 中：

- 定义 `DIALOGUE`、`ACTION`、`COMPLETION` 显示阶段。
- 用统一阶段切换函数控制遮罩、对话、图标和箭头资格。
- `present_step(..., true)` 进入对话阶段，`present_step(..., false)` 进入行动阶段。
- 动作按钮进入行动阶段；外婆图标进入对话阶段。
- `_update_layout()` 仅在行动阶段且目标有效时显示箭头，否则显式隐藏。
- 完成、隐藏和弹窗暂停保持设计规定的恢复语义。

### 3. 聚焦验证

运行：

- `tests/tutorial_guide_overlay_self_check.gd`
- `tests/tutorial_guide_popup_self_check.gd`
- `tests/tutorial_guide_route_self_check.gd`
- `tests/tutorial_guide_dynamic_target_self_check.gd`
- `tests/layout_refinement_self_check.gd`

每个 Godot 命令使用独立、可写的 `--log-file`。

### 4. 项目与差异验证

- 运行 Godot `--headless --quit` 场景解析。
- 运行 `git diff --check`。
- 检查最终差异只包含本计划内文件。
- 提交实现与测试。

## 完成条件

- 聚焦测试先红后绿。
- 对话面板与目标箭头在所有普通步骤中互斥。
- 行动阶段保留左下角外婆图标。
- 动作化按钮文案保持不变。
- 弹窗恢复、无效目标和完成阶段没有显隐回归。
