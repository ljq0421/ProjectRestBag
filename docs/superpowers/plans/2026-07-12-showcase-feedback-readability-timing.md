# 橱窗反馈可读性时长调整 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 延长左侧出售脉冲、关系线、金币轨迹和文字反馈，使玩家能看清增益/减损来源。

**Architecture:** 在 `main_view.gd` 集中定义表现时长常量，现有反馈节点与经济事件接口保持不变。关系线增加停留阶段，其余 tween 只延长播放时间，不改变输入穿透、队列、成交和收银语义。

**Tech Stack:** Godot 4.6.1、GDScript、现有 headless self-check。

## Global Constraints

- 格子脉冲总时长 1.6 秒。
- 金币轨迹 1.4 秒。
- 金额浮字 2.4 秒。
- 关系线总时长 2.4 秒，其中先停留 0.8 秒，再淡出 1.6 秒。
- 原因文字 3.0 秒，溢出汇总 2.4 秒，连售提示 3.2 秒。
- 不改变反馈层鼠标穿透、自动成交入账和集中收银语义。

---

### Task 1: 调整并验证反馈节奏

**Files:**

- Modify: `scripts/main_view.gd`
- Modify: `tests/showcase_sale_feedback_self_check.gd`

**Interfaces:**

- Produces: `SHOWCASE_FEEDBACK_*_SECONDS` 表现常量。
- Preserves: `_play_showcase_sale_pulse()`、`_spawn_showcase_relation_line()`、`_spawn_showcase_coin_flight()` 现有调用接口。

- [x] **Step 1:** 在 `showcase_sale_feedback_self_check.gd` 断言目标时长常量及其实际使用。
- [x] **Step 2:** 运行自检，确认因常量尚不存在而失败。
- [x] **Step 3:** 在 `main_view.gd` 加入常量并替换 tween 字面量，关系线加入 0.4 秒停留。
- [x] **Step 4:** 运行反馈、布局和组件自检；右侧经营自检存在与本任务无关的旧容量/文案断言。
- [x] **Step 5:** 运行 `git diff --check` 并确认本次代码差异只涉及时长实现与合约测试。

## Self-Review

- 单一表现节奏任务，无经济或状态改动。
- 所有目标时长均为明确数值，无占位符。
- 关系线停留与淡出之和严格等于 1.2 秒。
