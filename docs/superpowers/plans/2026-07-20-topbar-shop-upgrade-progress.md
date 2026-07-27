# 顶部栏店铺升级进度实施计划

## 目标

落实 `docs/superpowers/specs/2026-07-20-topbar-shop-upgrade-progress-design.zh.md`：在顶部栏金币与口碑资源标签下常驻展示升至下一店铺等级的独立进度条。

## 变更范围

- 修改 `scenes/Main.tscn`，增加两条场景内进度条。
- 修改 `scripts/main_view.gd`，绑定并刷新升级目标。
- 新增 `tests/topbar_shop_upgrade_progress_self_check.gd`。
- 不修改升级公式、任务服务、存档结构或顶部栏以外的布局。

## 实施步骤

### 1. 建立失败回归

新增聚焦自检，实例化主场景并覆盖：

- Lv.1 的金币、口碑真实当前值和下一等级分母。
- 当前值超过门槛时标签不截断且进度条封顶。
- Lv.0 与缺失下一等级定义时隐藏进度条。
- 升级并刷新后分母切换到下一等级条件。
- 金币和口碑提示文本分别说明扣除与不扣除语义。

先运行自检并确认当前场景缺少目标进度条。

### 2. 添加稳定场景结构

在 `scenes/Main.tscn` 中：

- 保持 `TopBar` 原有 `44px` 高度，避免主体页面纵向偏移。
- 金币、口碑标签保持 `44px` 高度和 `180px` 宽度。
- 在现有 `CoinsLabel`、`ReputationLabel` 下分别增加 `UpgradeProgress` 子节点。
- 使用子节点而不搬移现有标签，以保持 `Root/TopBar/CoinsLabel` 等既有路径以及销售金币飞行动画锚点兼容。
- 进度条固定为 `8px` 高，顶部放在资源模块局部坐标 `24px`，让文字与进度条视觉间距缩短到约 `2–3px`。
- 进度条隐藏内置百分比，金币复用主题进度样式，口碑使用独立填充色覆盖。

### 3. 接入唯一升级数据源

在 `scripts/main_view.gd` 中：

- 绑定两条 `ProgressBar`。
- 让 `_refresh_resource_bar()` 调用 `state.upgrade_eligibility()`。
- 有有效手动升级目标时显示 `当前值 / 门槛`、进度和提示文本。
- Lv.0 或 `definition_missing` 时回退到现有纯资源文本并隐藏进度条。
- 提取金币标签格式化辅助函数，让营业金币滚动动画期间也保留当前升级分母。

### 4. 验证

按仓库约定为每条 Godot headless 命令传入可写的 `--log-file`，运行：

- `tests/topbar_shop_upgrade_progress_self_check.gd`
- `tests/task_shop_upgrade_self_check.gd`
- Godot `--headless --quit` 场景解析
- `git diff --check`

聚焦自检还要断言 `TopBar` 运行时高度为 `44px`、进度条高度为 `8px`、主体容器顶部仍位于原始布局位置。

## 完成条件

- 顶部栏在 Lv.1 及以上显示两条真实升级进度。
- 标签保留实际资源量，进度视觉封顶。
- Lv.0 和无下一等级定义状态不显示 `0 / 0`。
- 新增进度条不改变主体页面纵向位置，文字与进度条保持紧凑间距。
- 升级条件和扣除语义仍由现有业务层决定。
- 既有顶部资源标签节点路径与金币反馈动画保持可用。
