# Rest New 三阶段橱窗配方图标包设计

## 问题与目标

当前图鉴、库存、制作行和研发结果已经按 `mastery_level` 加载试作品、人气款和招牌款图标，但配方上架到橱窗后仍显示旧画风。

原因是橱窗不加载普通配方图标。它通过 `resources/recipe_icons_showcase/showcase_icon_manifest.json` 选择带上架变体、旋转方向和占格区域的专用画布，再把画布切成每格 80×80 的 `AtlasTexture`。

本设计为 `resources/ui/icons_v1` 中的十个配方增加三阶段橱窗专用资源，同时保留下列现有行为：

- 配方占格形状；
- `standard`、`small`、`gift_box`、`large`、`sample` 上架变体；
- 可用旋转方向；
- 多格和 L 形切片；
- 拖拽预览、售罄状态、边框、名作装饰和状态徽章。

## 方案

新增独立的三阶段橱窗资源目录，不重写现有 `resources/recipe_icons_showcase` 及其 manifest。

```text
resources/recipe_icons_showcase_staged/
  staged_showcase_icon_manifest.json
  <recipe_id>__trial__<variant_id>__r<rotation>.png
  <recipe_id>__popular__<variant_id>__r<rotation>.png
  <recipe_id>__signature__<variant_id>__r<rotation>.png
```

十个目标配方按当前 `recipe_display_config.json` 共有 102 个形状、变体和旋转组合。完整三阶段资源包包含 306 张画布，其中人气款和招牌款增加 204 张。旧 manifest 只包含 95 个组合，因为其中的 `baked_rice_cake` 和 `egg_milk_custard` 尚未同步当前工作区已经确认的占格调整；阶段包以运行时正在读取的当前显示配置为准。

独立目录具有两个目的：

1. 未处理的配方继续使用当前 1713 张旧橱窗资源；
2. 新资源包可以单独生成、审计和回退，不制造整个旧 manifest 与旧图片集的机械性改写。

## 生成流程

新增三阶段橱窗生成工具，复用现有 `generate_showcase_recipe_icons.py` 的形状、变体和旋转规则。主体先按方向旋转，再放入该占格形状中最大的连续矩形区域，并保留至少 4 px 透明安全边距；即使是 L 形也不得通过清空缺失格来裁断主体。

输入为：

- `resources/recipe_icons/<recipe_id>.png`：试作品；
- `resources/recipe_icons/<recipe_id>_popular.png`：人气款；
- `resources/recipe_icons/<recipe_id>_signature.png`：招牌款；
- `doc/recipe_display_config.json`：占格和形状来源；
- 明确列出的十个配方 ID。

生成器在发布前验证每个目标配方的三阶段输入、显示配置和所有输出画布。任一目标无效时不发布部分 manifest。它只管理 `recipe_icons_showcase_staged`，不删除或修改旧橱窗目录。

阶段 manifest 的每个条目记录：

- `recipe_id`；
- `mastery_level` 和阶段名；
- `variant_id`；
- `rotation`；
- `rows`、`cols`、`cells` 和 `regions`；
- 阶段画布 `texture_path`。

## 运行时解析

`ShowcaseIconService` 同时加载：

1. 现有基础 manifest，仍为必要资源；
2. 新阶段 manifest，作为可选覆盖层。

服务的布局和切片查询增加 `mastery_level` 参数，并按以下顺序解析：

1. 当前阶段的新橱窗条目；
2. 试作品的新橱窗条目；
3. 现有旧橱窗条目；
4. 没有任何条目时返回空结果。

缓存键必须包含实际选中的阶段条目键，避免同一配方不同阶段复用错误的 `AtlasTexture`。

旧调用保持默认 `mastery_level = 0`，降低对既有测试和工具的影响。

## 主界面数据流

`_apply_showcase_group_visual()` 在正式上架和拖拽预览时都从 `GameState.get_recipe_growth(recipe_id)` 读取当前 `mastery_level`，并把它传给布局和切片查询。

阶段只影响纹理选择，不进入存档中的橱窗布局数据。配方晋级后，下次调用现有橱窗刷新流程即可更新图标，不需要迁移存档，也不改变 `display_items`、`display_slots` 或上架变体。

## 回退与错误处理

- 阶段 manifest 不存在或无效：记录一次警告，继续使用旧橱窗资源；
- 某个配方缺少当前阶段：回退该配方的新试作品资源；
- 新试作品资源也缺失：回退现有旧橱窗资源；
- 所有资源均缺失：维持当前空图处理，不影响按钮、拖拽或售卖逻辑；
- 非目标配方：始终使用现有旧橱窗资源。

## 测试与验收

### 生成器测试

- 三阶段文件名和 manifest 键正确；
- 形状、变体、旋转和 80×80 regions 与现有生成规则一致；
- 每张画布的主体包围框不得触及外边缘，也不得跨越形状中的空格；
- 缺少任一阶段输入时不发布部分输出；
- 只生成明确指定的配方；
- 不修改 `resources/recipe_icons_showcase`。

### 服务测试

- 三个阶段分别加载不同画布；
- 同一多格配方的各格仍得到不同 region；
- 当前阶段缺失时回退新试作品；
- 非目标配方回退旧 manifest；
- 阶段切换不会错误复用切片缓存。

### 运行时测试

- `rice_milk_drink` 在试作品、人气款、招牌款状态下，上架格纹理路径分别指向对应阶段画布；
- 正式上架和拖拽预览使用同一阶段；
- 多格、L 形和旋转布局不变；
- 原有橱窗售卖、状态徽章、名作框和拖拽测试继续通过。

### 可视验收

至少检查：

- 一个 1×1 配方；
- 一个 1×2/2×1 配方及其旋转；
- 一个 L 形配方旋转后主体仍完整；
- 一个 L 形或三格变体；
- 同一配方三个阶段的主体差异和透明边缘。

## 工作区保护

当前工作区仍包含其他未提交功能和上一轮三阶段图标实现。补充实现只修改橱窗图标服务、主界面对应查询点、专用生成工具、专用测试和新阶段资源目录；不得覆盖或提交其他工作。

书面设计作为独立提交保存。后续实现不自动提交，以免把现有脏工作树中的其他改动混入。
