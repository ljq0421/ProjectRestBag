# 首批配方差异化试玩指南

本轮只验证 `recipe_distinctiveness_pilot.json` 中已经确认的 12 个试点配方。自动审计已经证明它们在数据上不再完全重复或全面支配，但不能证明玩家能够理解和使用这些差异。

## 执行顺序

1. 按 `exact-001`、`exact-002`、`exact-003`、`exact-005` 的顺序试玩。
2. 每组完成两局，对应记录 `S01` 至 `S08`。
3. 同组两局必须使用相同路线、Boss、备货预算、升级和菜单候选。
4. 保证该组全部配方都可以被选择；不要用未解锁状态制造虚假拒绝。
5. 观察玩家决策，不提前讲解配置文件中的设计定位。
6. 试玩结束后填写 `recipe_distinctiveness_playtest_results.json`，再运行验收脚本。

## 需要记录什么

每个配方都要记录：

- 是否实际可选以及是否上阵；
- 上阵份数和首次售卖时间；
- 总销量、总满足力和剩余库存；
- 玩家如何描述该配方；
- 摆盘形状或朝向是否影响决策；
- 选择或拒绝它的具体原因。

每局还要记录：

- 玩家能否解释同组配方差异；
- 是否观察到真实的空间取舍；
- 是否存在明显无脑最优配方；
- 是否发现异常标签、需求或升级组合；
- 胜负和失败原因。

## 填写规则

- 未执行的记录保持 `status: "pending"`，不要填写推测值。
- 完成后改为 `status: "completed"`，并填写真实观察员和 ISO 8601 时间。
- 没有上阵的配方仍要填写拒绝原因；上阵配方必须填写四项战斗数据。
- 输局必须填写 `failure_reason`。
- 若观察到统治选择，设置 `dominant_choice_observed: true` 并填写 `dominant_recipe_id`。

## 运行验收

生成或刷新报告：

```powershell
python tools/evaluate_recipe_distinctiveness_playtest.py
```

检查报告是否与记录一致：

```powershell
python tools/evaluate_recipe_distinctiveness_playtest.py --check
```

在发布门槛中要求真人试玩 GO：

```powershell
python tools/evaluate_recipe_distinctiveness_playtest.py --require-product-go
```

`--require-product-go` 在记录未完成或验收失败时返回退出码 3。

## 判定

- `PENDING`：八局未全部完成，不能确认本批配方。
- `NO_GO`：八局完整但至少一项失败；只修正有证据的问题后复测。
- `GO`：八局完整并通过全部七项验收。
