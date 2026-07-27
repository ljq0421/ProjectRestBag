# 主页面整体背景图替换设计

## 目标

将 `project-rest-new` 主场景的整体底图替换为
`res://resources/ui/skin_v1/background.png`。背景覆盖完整的 1920×1080
主画面，不改变弹窗、橱窗、功能面板及其交互。

## 现状

- 主场景为 `scenes/Main.tscn`。
- 最底层节点 `PageBackground` 当前是 `NinePatchRect`，使用共享
  `panel_v1` 运行时纹理及 52 像素九宫格边距。
- 新背景图尺寸为 5184×2918，宽高比接近 16:9。
- `Main.tscn` 存在与本任务无关的未提交修改，实施时只改
  `PageBackground` 资源声明和节点属性。

## 设计

1. 将 `PageBackground` 改为全屏 `TextureRect`，保持它是 `Main` 的第一个
   子节点，使其继续渲染在全部主页面内容下方。
2. 纹理绑定到 `res://resources/ui/skin_v1/background.png`。
3. 使用 `TextureRect.STRETCH_KEEP_ASPECT_COVERED`，按比例铺满区域。
   新图与 16:9 只有极小比例差异，因此仅允许边缘发生极少裁切，不拉伸图像。
4. 保留四边全屏锚点、自动增长方向和 `MOUSE_FILTER_IGNORE`，背景不得拦截输入。
5. 移除只属于旧 `NinePatchRect` 的 52 像素 patch margin。
6. 不修改共享主题中的 `panel_v1`，其他大面板和弹窗仍可继续使用它。

## 验证

- 更新 `tests/main_page_background_self_check.gd`，断言节点类型、纹理路径、
  全屏锚点、最底层顺序、输入穿透和按比例覆盖模式。
- 更新 `tests/panel_v1_background_self_check.gd`，不再要求主页面背景使用
  `panel_v1`，但继续验证其他共享面板的 `panel_v1` 契约。
- 运行上述两个 Godot 自检；Godot 命令显式使用可写的 `--log-file`。
- 运行 `git diff --check`，确认场景与测试补丁不存在格式问题。

## 非目标

- 不替换弹窗、购买页、目录页、研究页、设备成长页或橱窗背景。
- 不修改 `background.png` 图像内容或生成派生运行时图片。
- 不改动当前工作区内与本任务无关的未提交文件。
