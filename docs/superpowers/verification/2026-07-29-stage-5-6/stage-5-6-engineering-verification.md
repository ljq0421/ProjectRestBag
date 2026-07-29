# 阶段 5–6 工程验收记录

日期：2026-07-29

## 结论

- 阶段 5 工程部分：GO
- 阶段 6 工程部分：GO
- 阶段 5 真人产品门：PENDING
- 阶段 7 批量迁移：BLOCKED，等待真人产品门结果

本记录不把自动化 PASS 等同于产品完成。尚未执行计划要求的 3 名真人测试，因此不能据此进入阶段 7 的 12 → 30 配方迁移。

## 阶段 5 数据结果

- Catalog 配方：166
- 显示配置配方：166
- 迁移清单配方：166
- 当前挑战运行时配方：12
- 开局配方：6
- 研究配方：6
- 规划草稿配方：154
- 迁移批次：
  - baseline：12
  - A：18
  - B：34
  - C：48
  - D：54

生成与审计命令：

```powershell
python tools/generate_challenge_recipe_catalog.py --check
python tools/audit_challenge_recipe_progression.py --check
```

结果：

```text
CHALLENGE_RECIPE_GENERATION_OK manifest=166 runtime=12 starters=6
CHALLENGE_RECIPE_AUDIT_PASS catalog=166 runtime=12 draft=154
```

## 阶段 6 合同结果

- 新档默认菜单为现有 6 个开局配方。
- 菜单合法范围为 4～8 个不同且已永久解锁的配方。
- 永久收藏规模可达到 166，但活动局快照最多 8 个配方。
- 研究解锁只写入永久收藏，不自动改变本局菜单。
- 标准和无尽开局都从本局菜单创建 `permanent_pool_snapshot`。
- 活动局存在时禁止修改菜单，避免污染已冻结快照。
- 大厅菜单页支持搜索、研究分支、战斗标签、占格和构筑角色筛选。
- 菜单页提供 8 个槽位、标准路线覆盖分析和恢复六配方默认菜单。
- 备战页只显示快照配方，并按构筑方向分组。
- 研究页改为动态左侧分支导航、中部节点链、右侧节点详情。
- 单个研究节点可以奖励多个配方；购买后会揭示同分支直接后继。

开发存档只直接扩展当前结构，不实现版本迁移。旧开发存档若缺少当前必需字段，可按现有“不兼容开发存档”流程重置。

## 自动化回归

运行：

```powershell
$tests = Get-ChildItem tests/challenge -Filter '*_self_check.gd' | Sort-Object Name
foreach ($item in $tests) {
  & "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
    --headless `
    --path . `
    --log-file "$env:TEMP\project-rest-two-final-$($item.Name).log" `
    -s "res://tests/challenge/$($item.Name)"
}
```

结果：

```text
TOTAL=41
ALL_CHALLENGE_SELF_CHECKS_PASS
```

关键真实输入结果：

```text
CHALLENGE_STANDARD_RUN_MOUSE_SELF_CHECK_PASS stages=5 clicks=25 drags=34
CHALLENGE_ENDLESS_MOUSE_SELF_CHECK_PASS floors=2 clicks=5 drags=5
CHALLENGE_MENU_MOUSE_SELF_CHECK_PASS clicks=5
CHALLENGE_RESEARCH_TREE_MOUSE_SELF_CHECK_PASS clicks=2
```

Windows 环境会重复输出系统根证书读取失败；所有上述测试退出码仍为 0。`challenge_meta_views_self_check.gd` 的两个虚构配方会产生缺失展示图标警告，不涉及真实配方资源。

## 1920×1080 渲染证据

渲染命令：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --path . `
  --log-file "$env:TEMP\project-rest-two-stage6-visual-final.log" `
  -s res://tests/challenge/challenge_stage6_visual_capture.gd
```

结果：

```text
CHALLENGE_STAGE6_VISUAL_CAPTURE_PASS images=3
```

证据：

- `01-menu-editor-1920x1080.png`
- `02-research-tree-1920x1080.png`
- `03-grouped-preparation-1920x1080.png`

人工检查三张渲染图：菜单编辑、动态研究树和分组备战均完整落在 1920×1080 画面内，没有裁切。

## 尚未完成的产品证据

阶段 5 仍需安排至少 3 名真人玩家，记录：

- 两分钟内能否说明三种开局方向；
- 首败归因；
- 主动重排次数；
- 强化是否改变布局；
- 是否理解研究树与菜单的关系；
- 无尽失败后的重开意愿。

只有真人结果确认“失败可归因”且至少两名玩家会主动调整布局，才允许进入阶段 7。
