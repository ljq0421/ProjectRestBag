# 橱窗经营工作流分区重构实施计划

## 目标

按已批准的设计，将橱窗经营页改为一屏工作流结构：左侧 `RoundControlBar` 单行追加环境百分比，右侧只保留经营概览、特殊挑战、最近营业报告和橱窗扩张。

设计依据：`docs/superpowers/specs/2026-07-15-storefront-management-workflow-layout-design.zh.md`

## 任务 1：先收紧 UI 契约

- 修改 `tests/showcase_round_ui_self_check.gd`：断言右侧环境与四个删除面板不存在；断言左侧环境标签包含标签、售价和售速；断言保留卡片存在。
- 修改 `tests/right_console_experience_self_check.gd`：断言右侧只包含保留区块，并验证最近营业报告与橱窗扩张共享同一个底部横向容器。
- 必要时补充 `tests/showcase_business_round_scene_self_check.gd`：锁定 `RoundControlBar` 单行节点结构和环境摘要。
- 运行专项自检，确认测试因旧结构仍存在、环境百分比尚未追加而按预期失败。

## 任务 2：重构场景结构

- 在 `scenes/Main.tscn` 删除 `StorefrontEnvironmentPanel`、`StorefrontSettlePanel`、`StorefrontBonusPanel`、`StorefrontReceiptPanel`、`StorefrontRiskPanel`。
- 将经营概览压缩为顶部区块。
- 保留特殊挑战作为主体区块。
- 新增底部 `HBoxContainer`，等宽承载最近营业报告和橱窗扩张。
- 保留 `StorefrontManagePanel` 的低分辨率滚动兜底，但 1920×1080 下不得出现实际纵向滚动需求。

## 任务 3：清理绑定和文案

- 在 `scripts/main_view.gd` 删除被移除区块的 `@onready` 绑定、刷新赋值和专用文本函数。
- 缩短经营概览文案，只保留阶段、开放格、摆放数和可售库存。
- 将环境标签格式改为 `{原环境标签}｜售价 ±N%｜售速 ±N%`，继续写入左侧已有 `EnvironmentLabel`。
- 将下一行 `ShowcasePulseSummary` 收窄为阶段、热度和可售库存，移除重复环境与待补货计数。
- 保持当前 Lv.6 合同三选一、报告、扩张数据与既有行为不变，不回退并行开发中的合同系统。

## 任务 4：验证与评审

- 重新运行专项自检，确认从红转绿。
- 运行橱窗 UI、营业轮次、右侧控制台和 MVP 相关回归。
- 运行 `git diff --check` 并审查工作树，只检查本任务范围，不覆盖用户已有修改。
- 请求独立代码评审，修复关键和重要问题后再做最终验证。
