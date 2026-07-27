# 研发等待与结果弹窗实施计划

## 目标

在 `project-rest-new` 中实现已确认的研发等待弹窗：有效点击后在同一弹窗中先显示“研发中”，按食材数量等待 0.5 / 1.0 / 1.5 秒，结算后切换为成功或失败结果，玩家确认后关闭。

## 实施步骤

### 1. 新增场景化弹窗组件

文件：

- `scenes/ui/overlays/research_progress_dialog.tscn`
- `scripts/ui/overlays/research_progress_dialog.gd`

实现等待态、产物成功态与普通结果态接口。等待态隐藏确认按钮并拒绝关闭；产物成功态显示约 `128×128` 的产物图标、产物名称、成功文案和确认按钮，同时供成品配方与中间加工产物使用；研发或加工失败使用普通文字结果态。每次状态切换都清空并隐藏不适用的图标和名称，避免复用弹窗时残留。内容区保留清晰的动画替换位置。

### 2. 接入主场景和研发流程

文件：

- `scenes/Main.tscn`
- `scripts/main_view.gd`

将弹窗实例加入主场景。主界面负责前置校验、操作快照、食材数量到时长的映射、忙碌保护与计时器。计时结束后才调用现有加工或研发业务逻辑，随后保存、刷新并把结果写回原弹窗。研发成功时根据返回的 `recipe_id` 使用研发结果专用方法加载 `resources/recipe_icons/<recipe_id>.png` 的 `512×512` 原始纹理；加工成功时根据返回的 `ingredient_id` 使用现有原料图标方法加载 `resources/ingredient_icons/<ingredient_id>.png` 的 `512×512` 原始纹理。两条成功路径都把纹理、产物名称和成功文案传给同一弹窗接口；缺失纹理时仍显示名称和文案。操作栏现有 `_material_icon_texture()` 及其 `32×32` 图标保持不变。

弹窗可见时暂停全局通知展示；结果确认关闭后继续通知队列。

### 3. 避免成功通知重复

文件：

- `scripts/recipe_book.gd`

为 `RecipeBook.research()` 增加默认开启的向后兼容通知参数。研发页弹窗路径显式关闭同一次“解锁新配方”通知，其他调用方保持原行为。

### 4. 添加聚焦回归

文件：

- `tests/research_wait_dialog_self_check.gd`

验证场景结构、等待与结果状态、三个时长档位、等待前不结算、重复请求保护、单次结算、成品与大米粉图标运行时纹理严格为 `512×512`、显示区域保持 `128×128`、正确产物名称、大米粉 `x2` 数量文案、图标缺失回退、状态复用无残留、成功通知去重和结果确认后的通知续播。

### 5. 验证

从 `project-rest-new` 目录运行 Godot 4.6.1 头部自检，并为每次命令提供可写的 `--log-file`：

- `research_wait_dialog_self_check.gd`
- `research_input_strip_self_check.gd`
- `research_progressive_hints_self_check.gd`
- `tutorial_guide_dynamic_target_self_check.gd`
- `component_contract_self_check.gd`

最后运行 Godot `--headless --quit` 启动检查，并检查仅本功能文件的差异。
