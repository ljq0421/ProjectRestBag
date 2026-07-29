# 阶段 4「无尽爬升」新会话交接

日期：2026-07-29  
目标仓库：`D:\Project\ProjectRest\project-rest-two`  
当前分支：`main`  
当前 HEAD：`bbad15b7`

## 1. 不可违反的仓库边界

- 只修改 `project-rest-two`，不得修改 `project-rest-new`。
- 当前工作区有约 93 个未提交改动，包含阶段 2、阶段 3 代码、配置、测试、截图和文档。
- 这些改动属于用户成果，禁止 `git reset --hard`、`git checkout --`、清理未跟踪文件或用旧版本覆盖。
- 用户没有要求提交、推送或开 PR；完成阶段 4 后也不要擅自执行这些操作。
- 挑战备货继续独立，不消耗采购、制作、长期库存或旧经营仓库。

## 2. 当前已确认状态

阶段 2/用户所称阶段 3 的工程验收已经通过：

- `ALL_CHALLENGE_SELF_CHECKS_PASS=28`
- 强化路径：`paths=81 choices=324`
- 真实鼠标五场整链：`stages=5 clicks=22 drags=34`
- 7 个页面均完成 1920×1080 视觉复验
- 双向压力、战报、强化页、总结页和研究树的玩家侧表达已修复
- `git diff --check` 通过
- “无尽爬升”尚未实现

证据：

- `docs/superpowers/verification/2026-07-29-stage-3-product-acceptance.md`
- `docs/superpowers/verification/2026-07-29-stage-3/`
- `docs/superpowers/plans/2026-07-28-backpack-boss-standard-short-chain.md`

## 3. 尚未满足的产品证据门

真人试玩尚未完成，当前结论仍是：

`TECHNICAL GO / PRODUCT EVIDENCE PENDING`

缺少：

- 1 名不熟悉玩家完整体验；
- 2 名熟悉玩家分别走不同构筑；
- 是否真正产生构筑选择、变强感与重开动机的记录。

原计划把真人证据视为后续扩展门。若用户在新会话中明确写出：

> 我接受在真人产品证据尚未完成的情况下，先实现阶段 4 无尽爬升；完成后仍保持 PRODUCT EVIDENCE PENDING。

则把它视为用户主动接受风险，可以继续实现，但不得把自动测试描述成真人产品通过。

## 4. 阶段 4权威规格

先完整阅读：

- `docs/superpowers/specs/2026-07-27-backpack-boss-roguelite-core-design.md`
  - 第 9 节“无尽爬升”
  - 第 17 节阶段 4路线
  - 第 28 节验收证据
- `docs/superpowers/plans/2026-07-28-backpack-boss-standard-short-chain.md`
- 阶段 3产品验收记录

已确认的无尽合同：

1. 首次完成标准五场短链后开放。
2. 无尽每局从独立局内状态开始，不继承上一局强化。
3. 使用玩家已经永久解锁的配方池。
4. 不消耗长期库存，只使用独立挑战备货。
5. 每层提高 Boss 挑剔、需求复杂度或预算压力。
6. 每若干层组合精英/Boss 规则。
7. 胜利后继续获得局内强化。
8. 经营信心可沿用标准模式，恢复节点必须配置化。
9. 保存最高层、最终构筑快照和关键战报。
10. 研究收益递减或阶段封顶，不能让无尽成为唯一有效养成路径。
11. 需要专项确定性、保存恢复、幂等、性能、真实鼠标和 1920×1080 验证。

阶段 4不包括：

- PvP；
- 对手店铺模拟；
- 战中主动技能；
- 隐藏随机事件；
- 永久战斗数值碾压；
- 与 `project-rest-new` 共享存档；
- 为了做无尽而恢复采购、制作、产地或旧研发流程。

## 5. 新会话执行顺序

1. 使用 `superpowers:using-superpowers`，随后用 `superpowers:brainstorming` 复核阶段 4细节。
2. 先做只读审计：现有 run/session/save/research/UI 合同与 dirty diff。
3. 写独立的阶段 4实施计划；不要直接把无尽逻辑塞进 `challenge_main_view.gd`。
4. 领域逻辑优先落在独立服务，例如无尽路线生成、难度缩放、阶段收益和记录服务。
5. 扩展保存格式时必须验证旧的当前格式存档恢复；不需要兼容更早已明确废弃的开发格式。
6. UI 继续保持场景结构在 `.tscn`，脚本负责绑定、刷新和信号。
7. 每个新合同先写失败自检，再实现。
8. 完成后运行全部 `tests/challenge/*_self_check.gd`、新增无尽自检、主场景启动、`git diff --check`。
9. 使用真实鼠标完成“开放无尽 → 连续爬层 → 选择强化 → 失败/结束 → 查看最高层 → 恢复一次”的完整路径。
10. 重新做 1920×1080 页面检查并生成验收文档。
11. 不得伪造真人试玩结论。

## 6. 新会话启动指令

把下面内容完整粘贴到新的 Codex 会话：

```text
目标仓库是 D:\Project\ProjectRest\project-rest-two，只能修改该仓库，不得修改 project-rest-new。

请先阅读：
1. docs/superpowers/handoffs/2026-07-29-stage-4-endless-climb.md
2. docs/superpowers/specs/2026-07-27-backpack-boss-roguelite-core-design.md
3. docs/superpowers/verification/2026-07-29-stage-3-product-acceptance.md
4. docs/superpowers/plans/2026-07-28-backpack-boss-standard-short-chain.md

当前工作区包含阶段2/3的未提交成果，禁止 reset、checkout 覆盖或清理未跟踪文件。

我接受在真人产品证据尚未完成的情况下，先实现阶段4“无尽爬升”；完成后仍保持 PRODUCT EVIDENCE PENDING。

使用 using-superpowers 和 brainstorming，先做只读审计并给出简洁的阶段4实施方案，然后继续完成实现、测试、真实鼠标整链和1920×1080视觉验收。不要停在计划阶段，不要实现166配方迁移，不要提交或推送Git。
```
