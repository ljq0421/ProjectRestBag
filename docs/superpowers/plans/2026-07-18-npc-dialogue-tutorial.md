# 外婆 NPC 对话式新手引导实施计划

**依据：** `docs/superpowers/specs/2026-07-18-npc-dialogue-tutorial-design.md`

**目标：** 在不改变现有十步引导业务进度和橱窗网格尺寸的前提下，把箭头短提示替换为“外婆主动对话 + 左下角图标入口 + 目标箭头”的混合式引导。

## Task 1：数据驱动对话目录（RED → GREEN）

- 新增 `tests/tutorial_dialogue_catalog_self_check.gd`，先要求十个步骤都返回非空的 `step_name`、`dialogue`、`action_hint` 和 `confirm_label`，并覆盖未知步骤兜底。
- 用带 `--log-file` 的 Godot headless 命令运行自检，确认因脚本/接口不存在而失败。
- 新增 `scripts/tutorial_dialogue_catalog.gd`，只实现测试要求的只读目录 API。
- 重跑目录自检直到通过。

## Task 2：对话已读状态持久化（RED → GREEN）

- 先扩展 `tests/tutorial_guide_state_self_check.gd`，覆盖：新游戏默认为空、序列化往返、旧存档默认、确认当前步骤、步骤变化后旧值失效、重新引导清空。
- 运行状态自检并确认因字段/API 缺失而失败。
- 最小修改 `scripts/game_state.gd` 和 `scripts/tutorial_progress.gd`，增加 `tutorial_guide_dialogue_acknowledged_step`，同步新游戏、读取、写出和重新引导。
- 重跑状态自检直到通过。

## Task 3：场景化外婆对话层（RED → GREEN）

- 先改写 `tests/tutorial_guide_overlay_self_check.gd`，要求场景声明：`GrandmaIconButton`、`DialoguePanel`、主题化剪影、姓名、步骤名、两行正文、跳过/确认按钮和完成操作。
- 测试收起时只显示外婆图标，点击图标展开，确认按钮收起；完成状态复用同一对话框；弹窗暂停后恢复此前模式。
- 测试传入橱窗矩形后，展开面板与橱窗等宽、约 `118px` 高，收起图标锚定橱窗左下角；目标不存在时隐藏箭头。
- 运行 Overlay 自检并确认旧结构无法满足新节点和行为契约。
- 重构 `scenes/ui/overlays/tutorial_guide_overlay.tscn` 与 `scripts/ui/overlays/tutorial_guide_overlay.gd`，只实现上述场景与状态切换。
- 重跑 Overlay 自检直到通过。

## Task 4：MainView 主动对话编排（RED → GREEN）

- 先扩展 `tests/tutorial_guide_route_self_check.gd`：首次进入主动展开；确认后收起并记录已读；同一步刷新不重复展开；真实推进或跳过后下一步主动展开；点击外婆图标可重看；完成步骤主动展开。
- 先扩展 `tests/tutorial_guide_popup_self_check.gd`：阻塞前展开则恢复展开，阻塞前收起则恢复图标，不把弹窗关闭误判为新主动对话。
- 保留 `tests/tutorial_guide_dynamic_target_self_check.gd` 的目标解析断言，调整对新 Overlay 内部字段的读取。
- 运行三项自检，确认旧 `main_view.gd` 和旧 Overlay 调用契约失败。
- 修改 `scripts/main_view.gd`：预加载对话目录，移除硬编码 `_tutorial_message()`，把 `ShowcasePanel` 矩形传入 Overlay，按步骤变化和已读状态决定主动展开或收起，确认收起时保存。
- 重跑路线、弹窗和动态目标自检直到通过。

## Task 5：回归验证与审查

- 依次运行：
  - `tests/tutorial_dialogue_catalog_self_check.gd`
  - `tests/tutorial_guide_overlay_self_check.gd`
  - `tests/tutorial_guide_state_self_check.gd`
  - `tests/tutorial_guide_route_self_check.gd`
  - `tests/tutorial_guide_popup_self_check.gd`
  - `tests/tutorial_guide_dynamic_target_self_check.gd`
- 运行 `--headless --quit` 做场景解析检查。
- 运行 `tests/component_contract_self_check.gd`，确认 Main 仍挂载唯一引导 Overlay，稳定节点契约未破坏。
- 运行 `git diff --check` 并检查工作树，只审阅本功能涉及的文件，不清理用户已有改动。
- 使用 `superpowers:requesting-code-review` 做完成前审查；修复本功能范围内的 Critical/Important 问题。
- 使用 `superpowers:verification-before-completion` 根据最新命令输出交付，不复用旧测试结果。

## Godot 命令模板

所有命令从 `D:\Project\ProjectRest\project-rest-new` 运行，并显式写入可写日志文件：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\godot-headless.log" `
  -s res://tests/tutorial_dialogue_catalog_self_check.gd
```

每个 TDD 周期只替换测试脚本路径，并保存 RED 与 GREEN 的实际输出。
