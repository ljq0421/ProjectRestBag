# 阶段 11：六人产品验收执行协议

## 当前结论

- 工程验收工具：已实现。
- 真人产品验收：`PENDING`，当前为 0/6。
- 产品发布门：未打开。自动化测试通过不能替代真人观察。

权威记录文件：

- 人工记录：`doc/challenge/stage11_playtest_results.json`
- 生成结论：`doc/challenge/stage11_product_gate.md`
- 测试档服务：`scripts/challenge/stage11_playtest_fixture_service.gd`
- 客观遥测：`scripts/challenge/stage11_playtest_telemetry_service.gd`
- 测试入口：`tools/stage11_playtest_launcher.gd`

## 1. 六个独立测试档

| 档位 | 玩家类型 | 收藏量 | 必测内容 |
|---|---|---:|---|
| P01 | 新玩家 | 6 | 新档到第一次研究解锁 |
| P02 | 新玩家 | 6 | 新档到第一次研究解锁 |
| P03 | 中期玩家 | 30 | 路线 A、路线 B |
| P04 | 中期玩家 | 64 | 路线 A、路线 B |
| P05 | 后期玩家 | 112 | 路线 C、无尽 |
| P06 | 后期玩家 | 166 | 路线 C、无尽 |

每个档位只能分配给一名真人玩家。不得让同一玩家同时充当两个名额，也不得把开发者演示记作真人验收。

## 2. 启动、续测与结束

在项目根目录运行。第一次开始某名玩家的测试时使用 `--reset`：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64.exe" `
  --path . `
  -s res://tools/stage11_playtest_launcher.gd `
  -- --profile=P01 --reset
```

中断后续测时去掉 `--reset`：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64.exe" `
  --path . `
  -s res://tools/stage11_playtest_launcher.gd `
  -- --profile=P01
```

观察完成后，把该档遥测标记为完成：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-two-stage11-complete.log" `
  -s res://tools/stage11_playtest_launcher.gd `
  -- --profile=P01 --complete
```

将命令中的 `P01` 依次替换为实际档位。启动器会在控制台打印该档的绝对存档路径。

## 3. 观察纪律

1. 场景可交互时开始计时。
2. 前两分钟不解释配方方向、标签、周期、形状、菜单或路线。
3. 玩家必须使用真实鼠标路径完成菜单、研究、摆放、旋转、开战、战报和重排。
4. 观察员可以询问“你为什么这样改”，但不能给答案或推荐构筑。
5. 崩溃或主动暂停后使用原档续测，不能重置后挑选更好的一次。
6. 客观事件以存档遥测为准；理解、原因、计划与意愿只能由观察员记录。

## 4. 必填人工记录

测试结束后编辑 `doc/challenge/stage11_playtest_results.json` 中对应玩家：

- 将 `status` 改为 `completed`；
- 填写 `human_observer`、`started_at`、`completed_at`；
- 记录识别两条和三条方向的时间；
- 记录第一次菜单编辑原因、各路线菜单变更次数；
- 记录失败归因的正确次数/总次数及是否作出针对性调整；
- 记录强化后的主动重排次数；
- 记录购买研究节点数，以及三局内实际进入菜单的节点数；
- 为每条路线写入可辨认构筑名称；
- 中后期记录是否出现非纯数值进展；
- 后期记录无尽最高层、主动改构筑次数和重开意愿；
- 记录无用途/重复配方、研究等待过长和统治菜单现象。
- 对路线图列出的 NO-GO 现象逐项填 `true/false`，不能用空值表示“没有”。

`completed` 记录缺少观察员、起止时间或关键布尔结论时，判定器会直接拒绝，不能进入 GO/NO-GO 计算。

## 5. 导出客观遥测

把启动器打印的六个绝对存档路径传给汇总工具：

```powershell
python tools/summarize_stage11_telemetry.py `
  --save "<P01绝对路径>" `
  --save "<P02绝对路径>" `
  --save "<P03绝对路径>" `
  --save "<P04绝对路径>" `
  --save "<P05绝对路径>" `
  --save "<P06绝对路径>" `
  --output doc/challenge/stage11_telemetry_summary.md
```

遥测会汇总路线开局、菜单保存、战斗结果、失败窗口、升级、研究和棋盘扩展，但不会自动填写玩家动机或理解。

## 6. 生成产品判定

每次更新人工记录后重新生成并校验：

```powershell
python tools/evaluate_stage11_product_gate.py
python tools/evaluate_stage11_product_gate.py --check
```

发布流程必须再运行强制门：

```powershell
python tools/evaluate_stage11_product_gate.py `
  --check `
  --require-product-go
```

退出码规则：

- `0`：文件有效；若启用强制门则必须为产品 `GO`；
- `1`：生成报告已过期；
- `2`：记录结构无效或伪完成；
- `3`：记录有效，但产品结论仍为 `PENDING` 或 `NO_GO`。

## 7. 判定规则

只有六人全部完成并同时满足路线图八项产品 GO 条件，结论才是 `GO`。六人未完成时固定为 `PENDING`；六人完成但任一项失败时为 `NO_GO`。触发 `NO_GO` 后停止增加配方，回到对应路线、Boss、研究节奏或菜单负担进行修正，再使用新的真人观察复测。

## 8. 工程自检

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-two-stage11.log" `
  -s res://tests/challenge/stage11_playtest_fixture_self_check.gd

& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-two-stage11.log" `
  -s res://tests/challenge/stage11_playtest_telemetry_self_check.gd

& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-two-stage11.log" `
  -s res://tests/challenge/stage11_session_telemetry_self_check.gd

python tools/test_stage11_product_gate.py
python tools/evaluate_stage11_product_gate.py --check
```

这些命令只证明测试工具和发布门工作正常，不证明玩家体验已通过。

## 9. 2026-07-30 工程验证结果

- P01–P06 六个隔离档均成功载入真实主场景；
- 全部 60 个 `tests/challenge/*_self_check.gd` 通过，包含标准路线、无尽、
  菜单、研究树和棋盘扩展的鼠标输入脚本；
- 166 配方生成一致性、路线生成一致性、配方进度审计和 720 组平衡模拟通过；
- 当前主场景实机截图未见面板重叠或文字截断，运行日志无游戏错误；
- 判定器自检覆盖 `PENDING`、`GO`、`NO_GO`，并确认当前 0/6 的强制发布门
  以退出码 `3` 阻断。

因此当前只能给出“阶段 11 验收基础设施工程通过”，不能给出“产品体验通过”。
