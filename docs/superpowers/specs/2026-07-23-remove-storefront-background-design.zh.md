# 删除左侧橱窗独立背景设计

## 目标

删除主页面左侧橱窗区域自己的背景显示层，使新的全局
`PageBackground` 直接透过橱窗区域显示。保留橱窗内容、布局、交互和源图片文件。

## 现状

- `scenes/Main.tscn` 的 `StorefrontPanel` 使用透明 `StyleBoxEmpty`。
- `StorefrontBackground` 是 `StorefrontPanel` 的独立 `TextureRect` 子节点，
  使用裁切后的 `橱窗背景_v1.png`。
- `ShowcasePanel` 是覆盖同一区域的 `VBoxContainer`，不会绘制面板底色。
- 两项自检仍要求 `StorefrontBackground` 存在并验证其裁切参数。

## 设计

1. 从 `scenes/Main.tscn` 删除 `StorefrontBackground` 节点。
2. 删除只为该节点服务的 `AtlasTexture_storefront_background` 子资源和
   `28_storefront_background` 外部资源声明。
3. 保留 `resources/ui/skin_v1/橱窗背景_v1.png` 文件，不删除或修改源图。
4. 保持 `StorefrontPanel`、`ShowcasePanel`、14×12 橱窗格、尺寸比例和全部
   交互节点不变。
5. 不通过 `visible = false` 或透明度模拟删除，避免保留无效运行时资源。

## 验证

- 更新 `tests/showcase_background_self_check.gd`：
  - 断言 `StorefrontBackground` 不存在；
  - 继续断言 `ShowcasePanel` 填满 `StorefrontPanel`；
  - 继续验证橱窗格子、标题覆盖层和格子透明度契约。
- 更新 `tests/viewport_1920_layout_self_check.gd`：
  - 断言独立橱窗背景节点不存在；
  - 继续验证左右区域不重叠、橱窗内容填满左侧区域以及 14×12 布局不变。
- 运行上述两项 Godot 自检、主页面背景自检和 `git diff --check`。

## 非目标

- 不删除 `橱窗背景_v1.png`。
- 不修改全局背景图片或其显示模式。
- 不调整橱窗格子、橱窗标题栏、经营逻辑或左右区域比例。
- 不改动工作区内与本任务无关的未提交修改。
