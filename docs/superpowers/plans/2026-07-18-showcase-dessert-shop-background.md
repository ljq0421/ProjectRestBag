# 橱窗甜品店背景实现计划

## 范围

仅在 `project-rest-new` 中生成并接入左侧橱窗背景，保持现有 14×12 网格直接路径、几何和交互契约。

## 步骤

1. 新增 `tests/showcase_background_self_check.gd`，先验证背景资源、网格直达路径、目标几何与格子局部透明度契约，并观察预期失败。
2. 使用内置 `imagegen` 生成无文字的粉黄薄荷绿甜品店橱窗背景，检查后复制到 `resources/ui/backgrounds/`，裁切或缩放为 `1008×864`。
3. 在 `showcase_board.tscn` 中声明背景资源和顶部奶油遮罩样式；在 `showcase_board.gd` 的父级绘制阶段用等比 `cover` 将图片铺满根面板，并从根节点顶部到 `ShowcaseGrid` 顶部绘制连续遮罩，保持 `ShowcaseGrid` 直接子路径不变。
4. 在 `showcase_slot.tscn` 中仅设置根按钮 `self_modulate`，让主题底图半透明且不影响商品和状态子节点。
5. 运行新增自检并修复到通过，再运行最窄相关布局与视觉自检。
6. 启动项目做截图检查，确认背景覆盖整个 `StorefrontPanel`、顶部信息位于半透明遮罩上，且不遮挡商品、状态或右侧工作台。
7. 运行 `git diff --check`，复核只包含本功能及计划文件的改动。
