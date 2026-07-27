# 新手箭头引导实施计划

**依据：** `docs/superpowers/specs/2026-07-17-new-player-arrow-guide-design.zh.md`

**目标：** 为新存档实现“采购水稻种子 → 手动产出大米 → 研发米浆饮 → 制作米浆饮 → 上架米浆饮 → 查看构筑规则 → 拖动与右键旋转 → 开始营业 → 查看橱窗经营 → 完成”的十阶段箭头引导；支持逐步跳过、完成面板、非破坏性重播、存档恢复和真实业务事件推进。

## Task 1：状态与业务事件（RED → GREEN）

- 新增 `tests/tutorial_guide_state_self_check.gd`。
- 先验证新游戏初始资源、十阶段合法顺序、构筑规则阶段、拖动/旋转双条件、指定物品/配方过滤、逐步跳过/关闭/重播、序列化与旧存档默认跳过。
- 扩展 `scripts/game_state.gd` 与 `scripts/tutorial_progress.gd`，只实现测试要求的状态与推进 API。

## Task 2：场景化引导层（RED → GREEN）

- 新增 `tests/tutorial_guide_overlay_self_check.gd`。
- 新增 `scenes/ui/overlays/tutorial_guide_overlay.tscn` 与 `scripts/ui/overlays/tutorial_guide_overlay.gd`。
- 普通引导层只包含单箭头、步骤标签、短提示和紧凑的“跳过本步”按钮，尺寸约 `214×66`；完成态显示“关闭引导”和“再来一遍”。主体鼠标穿透，箭头跟踪目标矩形，弹窗期间可暂停。

## Task 3：动态目标接口（RED → GREEN）

- 新增 `tests/tutorial_guide_dynamic_target_self_check.gd`。
- 为采购数量行、产出单元格、配方操作行和橱窗上方构筑规则按钮增加稳定的语义目标查询或引用。
- `main_view.gd` 按阶段解析当前目标；产出阶段永不选择“一键收获”。

## Task 4：真实交互路线（RED → GREEN）

- 新增 `tests/tutorial_guide_route_self_check.gd`。
- 在采购结算、手动收获大米、研发、制作、上架、指定构筑规则按钮、真实位移、右键旋转、成功开始营业和“橱窗经营”按钮出口刷新引导。
- 只有橱窗上方“构筑规则”按钮的真实信号成功打开弹窗才推进；“查看全部规则”等其他入口不推进，关闭弹窗后恢复布置箭头。
- 每个阶段只自动路由一次，玩家手动切页后不再被当前阶段反复拉回；只有真实位移与右键旋转均完成才允许开始营业阶段，只有玩家按下“橱窗经营”按钮才显示完成面板。
- “跳过本步”只推进一个引导阶段并保存，不补资源、不解锁内容、不触发业务或任务事件；从最后普通阶段跳过后进入完成面板。
- 重播只重置引导字段；已知米浆饮再次正确研发时不重复扣材料，正在运行的经营轮不被中断。
- 同步米浆饮研发通知测试为 `大米 + 泉水 + 圆锅`。

## Task 5：验证与审查

- 运行全部新手引导聚焦自检。
- 运行采购、产出、任务、米浆饮研发、上架相关回归。
- 运行项目加载检查与 `git diff --check`。
- 审查需求逐项覆盖，修复 Critical/Important 问题后再交付。

所有 Godot headless 命令从 `project-rest-new` 运行，并显式传入写到临时目录的 `--log-file`。
