# 顶部金币与口碑皮肤进度条实施计划

## 目标

落实 `docs/superpowers/specs/2026-07-23-topbar-skinned-progress-design.zh.md`：保持顶部栏既有尺寸、业务数据和交互语义，把金币进度替换为星星皮肤，把口碑进度替换为蛋糕皮肤，并让黄色填充继续准确反映真实升级进度。

## 变更范围

- 纳入但不修改以下用户提供的源素材及 Godot 导入描述：
  - `resources/ui/skin_v1/top_star_progress.png`
  - `resources/ui/skin_v1/top_star_progress.png.import`
  - `resources/ui/skin_v1/progress_cake.png`
  - `resources/ui/skin_v1/progress_cake.png.import`
- 新增星星条派生素材及 Godot 导入描述：
  - `resources/ui/skin_v1/top_star_progress_174.png`
  - `resources/ui/skin_v1/top_star_progress_174.png.import`
- 修改 `scenes/Main.tscn`，增加两张皮肤图层并重设现有进度条的局部槽体样式与位置。
- 对 `scripts/main_view.gd` 做窄范围修改，绑定皮肤节点并让它们与进度条同步显示、隐藏。
- 扩展 `tests/topbar_shop_upgrade_progress_self_check.gd`，覆盖资源映射、图层状态、数据刷新与几何回归。
- 不修改升级公式、任务服务、存档结构、两张源 PNG 或顶部栏以外的布局。

`scripts/main_view.gd` 当前已有用户的未提交修改。实施时只编辑顶部资源节点绑定和 `_refresh_resource_bar()` 附近，不格式化或覆盖文件中的其他差异。

## 实施步骤

### 1. 先扩展失败回归

在 `tests/topbar_shop_upgrade_progress_self_check.gd` 中先加入新合同：

- 取得 `CoinsLabel/SkinTexture` 与 `ReputationLabel/SkinTexture`。
- 断言金币皮肤直接引用 `top_star_progress_174.png`，口碑皮肤引用 `progress_cake.png`。
- 断言金币 `SkinTexture` 是单个 `TextureRect`，且不存在 `TrackTexture` 或 `IconTexture` 子节点。
- 断言派生纹理尺寸为 `660×167`。
- 断言金币与口碑皮肤的视觉根矩形均为 `x=3..177`，总长度 `174px`。
- 断言两个 `UpgradeProgress` 均为 `x=42..167`，动态填充长度 `125px`。
- 有有效升级目标时，皮肤与对应 `UpgradeProgress` 同时可见。
- Lv.0 和 `definition_missing` 时，皮肤与对应 `UpgradeProgress` 同时隐藏。
- 保留金币、口碑当前值与分母、超额封顶、升级后分母切换和金币滚动动画断言。
- 保留 `TopBar=44px`、`Body.y=52`、两个资源模块均为 `180×44px` 的几何断言。
- 断言进度条背景为完全不透明，以保证 0% 时能遮住源图自带的黄色填充。
- 断言两个标签均使用 `14px` 字号、`#FFF4D1` 文字、`#4A2414` 描边与 `3px` 描边宽度。
- 断言两个标签使用相同内容边距并避开左侧图标，不依靠字符串空格定位。

先运行聚焦自检，确认它因金币皮肤仍是 Atlas 双层而失败。

### 2. 生成单张无缝星星条

以 `resources/ui/skin_v1/top_star_progress.png` 为唯一参考进行一次图像编辑：

- 输出透明背景的单张横向进度条。
- 左侧星星图标、右侧圆角端帽、奶油色边框、棕色槽体、高光和阴影保持原始视觉。
- 只增加中间平直槽体长度，不生成第二个图标、断裂边框或新的装饰。
- 最终规范化为 `660×167`，保存为 `resources/ui/skin_v1/top_star_progress_174.png`。
- 检查左右拼接区域在 100% 原始尺寸下无亮度跳变、错位或重复纹理。

原始 `top_star_progress.png` 的文件内容和哈希必须保持不变。

### 3. 在场景中恢复单层皮肤

在 `scenes/Main.tscn` 中：

- 声明 `top_star_progress_174.png` 和 `progress_cake.png` 两个 `Texture2D` 外部资源。
- 保持 `CoinsLabel`、`ReputationLabel` 和两个 `UpgradeProgress` 的现有节点路径不变。
- 保留两个名为 `SkinTexture` 的视觉根节点：
  - 金币 `SkinTexture` 恢复为单个 `TextureRect`，绑定 `top_star_progress_174.png` 并覆盖 `Rect2(3, 0, 174, 44)`。
  - 口碑 `SkinTexture` 保持 `TextureRect`，调整到 `Rect2(3, 0, 174, 44)`；蛋糕素材原始比例与该矩形近似一致，不产生可见形变。
  - 初始 `visible=false`。
  - `mouse_filter=IGNORE`。
  - 设置 `show_behind_parent=true`，作为文字后的绘制层，不抢占布局和输入。
- 删除金币 `SkinTexture` 下的 `TrackTexture`、`IconTexture` 和两个 Atlas 子资源。
- 两个 `UpgradeProgress` 同样设置 `show_behind_parent=true`，并保持子节点顺序为皮肤图层、进度图层，使进度槽覆盖源图烘焙的黄色部分，但资源文字仍绘制在最前。
- 为金币与口碑分别建立局部 `StyleBoxFlat`：
  - 背景使用不透明棕色并匹配对应素材内部槽体。
  - 填充使用素材中的暖黄色。
  - 圆角与槽体高度匹配。
- 把两个既有 `UpgradeProgress` 统一为 `Rect2(42, 15, 125, 17)`；它们继续关闭内置百分比并忽略鼠标。
- 为两个标签配置相同的 `StyleBoxEmpty` 内容边距（左 `42px`、右 `13px`），把文字限制在统一槽体区域。
- 两个标签统一设置 `font_size=14`、`font_color=#FFF4D1`、`font_outline_color=#4A2414`、`outline_size=3`，不修改全局 Theme。

场景调整不得改变：

- `TopBar.custom_minimum_size.y = 44`
- `CoinsLabel.custom_minimum_size = Vector2(180, 44)`
- `ReputationLabel.custom_minimum_size = Vector2(180, 44)`
- 店名、金币、口碑、等级的节点顺序

### 4. 同步皮肤可见状态

在 `scripts/main_view.gd` 中：

- 将 `coins_upgrade_skin`、`reputation_upgrade_skin` 两个节点绑定恢复为 `TextureRect`。
- 增加只负责同步可见性的 `_set_topbar_upgrade_visuals_visible(visible: bool)`。
- 当 `_topbar_shop_upgrade_target()` 为空时，同时隐藏两张皮肤和两个进度条，保留现有纯资源文本和提示。
- 当升级目标有效时，同时显示两张皮肤和两个进度条。
- 保留 `GameState.upgrade_eligibility()` 为唯一要求来源，不改动 `max_value`、`value` 和封顶逻辑。
- 保留 `_topbar_coins_text()` 与 `_set_coins_label_roll_value()` 的现有数据路径，使金币滚动时文字、分母和填充继续同步。

不在脚本中保存皮肤进度副本，也不把槽体几何移到脚本动态生成。

### 5. 聚焦验证与视觉校准

按仓库约定为所有 Godot headless 命令传入可写 `--log-file`，依次运行：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-topbar-skin-test.log" `
  -s res://tests/topbar_shop_upgrade_progress_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-task-upgrade-test.log" `
  -s res://tests/task_shop_upgrade_self_check.gd
```

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\project-rest-new-scene-parse.log" `
  --quit
```

然后在 1920×1080 运行时画面中检查：

- 星星与蛋糕不变形，图标完整。
- 金币星星、边框、高光、阴影和槽体在整条范围内连续，不存在分层接缝。
- 两个皮肤的左边界、右边界和视觉总长度一致。
- 两个黄色动态填充区域起点、终点和总长度一致。
- 0%、中间值和 100% 的黄色长度与真实进度一致。
- 0% 不残留源图烘焙的黄色假进度。
- 数值文字在棕色空槽和黄色填充上都清晰，且在两种分母长度下仍能完整阅读。
- 顶部栏和正文没有发生纵向位移。

如果视觉校准需要调整，只改 `Main.tscn` 中两个局部槽体矩形、圆角、内容边距和局部颜色，并同步更新聚焦自检中的精确几何断言。

### 6. 差异审计

- 运行 `git diff --check`。
- 使用路径限定的 `git diff` 检查 `Main.tscn`、`main_view.gd`、聚焦自检、两张源素材及新增派生素材。
- 确认没有把工作区中无关的配方图、图标或其他未提交改动纳入本功能。
- 确认两张源 PNG 的文件内容未被实施过程改写。

## 完成条件

- 金币显示星星皮肤，口碑显示蛋糕皮肤。
- 金币使用单张 `660×167` 派生纹理，无 Atlas 分层接缝。
- 星星图标不变形；金币与口碑皮肤均为 174px，动态填充均为 125px。
- 两组文字均使用 14px 奶油色文字和 3px 深巧克力描边。
- 黄色填充由真实 `value/max_value` 驱动，而不是沿用源图固定进度。
- Lv.0 和缺失定义状态回退纯文字，不残留皮肤。
- 金币滚动动画、提示语义、超额封顶和升级后目标切换保持正确。
- 顶部栏仍为 44px，正文仍从 y=52 开始，两个资源模块仍为 180×44px。
- 聚焦自检、店铺升级自检、场景解析和差异检查全部通过。
