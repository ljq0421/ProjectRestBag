# 橱窗背景 v1 替换设计

## 目标

在 `project-rest-new` 中将左侧橱窗现有背景替换为 `res://resources/ui/skin_v1/橱窗背景_v1.png`。去除显示区域中的纯透明外沿，并让橱窗图片主体等比铺满整个左侧橱窗区域。

## 范围

本次仅调整左侧橱窗背景资源的绑定与显示方式：

- 保留 `Root/Body/MainArea/StorefrontPanel/StorefrontBackground` 节点及其现有层级。
- 保留 `ShowcasePanel`、14×12 商品网格、槽位尺寸、拖放、经营反馈和全部业务逻辑。
- 不重写、不缩小源图，也不生成运行时图片副本；仅在场景资源中定义显示裁切区域。
- 主体铺满优先于全部可见；允许等比覆盖时少量裁掉顶部或底部可见内容，但不允许拉伸变形。
- 不修改右侧工作台、全局页面背景、弹窗皮肤及当前工作树中的其他未提交改动。

## 接入设计

`橱窗背景_v1.png` 是 `3456×2688` 的 RGBA 图片。其非透明像素边界为 `(336,116)` 至 `(3118,2574)`，对应 `2782×2458` 的主体区域。`Main.tscn` 直接引用该源文件，不再经由 `resources/ui/backgrounds/橱窗背景.png` 的旧绑定。

在 `Main.tscn` 中增加一个 `AtlasTexture` 子资源：`atlas` 指向完整源图，`region` 设置为 `Rect2(336,116,2782,2458)`。`StorefrontBackground` 使用该子资源，仅排除纯透明外沿，不修改磁盘上的原图。

`StorefrontBackground` 仍填满 `StorefrontPanel` 的布局区域并保持鼠标穿透，显示模式使用等比覆盖。主体在不同窗口比例下始终铺满区域；比例不一致时允许少量裁掉顶部或底部可见内容，但不能横向或纵向拉伸。`StorefrontPanel.clip_contents` 继续负责裁掉区域外内容，不额外添加填充色或装饰层。

## 验收标准

- `Main.tscn` 的橱窗背景子资源以 `res://resources/ui/skin_v1/橱窗背景_v1.png` 为原始图集。
- `AtlasTexture.region` 精确为 `Rect2(336,116,2782,2458)`，只排除源图的纯透明外沿。
- 源图保持 `3456×2688` 且磁盘内容不变，不生成裁剪后的 PNG 副本。
- `StorefrontBackground` 继续覆盖整个 `StorefrontPanel` 布局区域，并使用等比覆盖显示；主体铺满区域且不拉伸变形。
- `ShowcasePanel` 与背景共享同一橱窗区域，网格路径、几何、交互和业务脚本不变。
- 橱窗背景专项自检、1920 布局自检、场景加载检查和 `git diff --check` 通过。
