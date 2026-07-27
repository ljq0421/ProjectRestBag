# 邻里甜品店 Theme 接入设计

日期：2026-07-11  
项目：ProjectRest（Godot 4.6.1）

## 目标

将 `resources/ui/skin/neighborhood_dessert/` 中已经生成并去背的 UI 素材整理为可稳定九宫格拉伸的运行时资源，创建一个集中维护的 Godot Theme，并把样式按控件职责接入现有游戏界面。

本次只处理 UI 皮肤和 Theme 引用，不修改业务逻辑、存档结构、配方数据或游戏规则。

## 现状与约束

- ImageGen 原始 PNG 的画布、透明留白和像素尺寸并不统一，不能原尺寸直接作为小型 Godot 控件的 `StyleBoxTexture`。
- 同一控件族的状态图已经基本保持画布和可见轮廓对齐；运行时处理必须继续保持这种对齐，避免交互状态切换时跳动。
- 当前项目没有集中式全局 Theme。部分场景使用默认控件样式，部分 `PanelContainer` 在 `.tscn` 中内嵌 `StyleBoxFlat`。
- 项目布局和稳定节点结构继续以 `.tscn` 为主；Theme 只负责视觉样式，不承担业务布局。
- 不覆盖或移动 ImageGen 母版素材；运行时副本放在独立子目录。
- 不修改 `_preview_*.png`，这些文件只用于人工预览，不进入 Theme。

## 方案选择

采用“集中 Theme + 类型变体 + 运行时派生素材”。

不采用全局把所有 `Button` 或所有 `PanelContainer` 强制套用同一种皮肤，因为当前按钮同时承担主操作、次操作、标签页、分页、列表项和透明遮罩等不同角色。

不采用大量节点级 `theme_override_styles`，因为它会把九宫格配置分散到多个场景，难以统一调整。

## 文件结构

新增或维护以下文件：

```text
resources/ui/skin/neighborhood_dessert/
├── 原始 ImageGen PNG（保持不变）
├── neighborhood_dessert_theme.tres
└── runtime/
    └── 统一裁边、缩放后的运行时 PNG

tools/
└── build_neighborhood_dessert_skin.py

tests/
└── neighborhood_dessert_theme_self_check.gd
```

派生脚本必须可重复执行：相同输入生成相同尺寸、相同文件名和相同九宫格参数来源。运行时素材由脚本生成，不手工逐张调整。

## 运行时素材处理

### 裁切

- 读取同一控件族的全部状态图。
- 计算该族所有状态非透明像素边界的并集。
- 在并集外保留固定透明安全边距。
- 同族所有状态使用完全相同的裁切矩形和输出画布。
- 辅助预览图、无透明通道的文件和不符合命名规则的文件不处理。

### 缩放

- 按控件族而不是单张图片确定目标尺寸。
- 按钮、标签、输入框、状态标签等横向控件统一到适合 1920×1080 设计视口的 2×运行时源尺寸。
- 面板保留更高分辨率，但四角和边框必须落在可配置的九宫格安全区内。
- 固定尺寸控件（复选框、单选框、滑块手柄、徽章等）保持正方形或规定长宽比，不使用九宫格拉伸。
- 缩放使用带透明通道的高质量重采样，并保持同族状态逐像素对齐。

### 九宫格参数

- 九宫格切线落在圆角、高光端点和边框装饰之外的纯直边区域。
- 同族所有状态使用相同的四边 patch margin 和 content margin。
- 九宫格参数由派生脚本生成清单，Theme 按清单写入 `StyleBoxTexture`。
- 文字安全区通过 `content_margin_*` 提供，交互状态不改变文字位置。

## Theme 架构

Theme 资源路径：

`res://resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres`

Theme 使用基础控件类型和语义化类型变体。计划包含：

- `DessertPrimaryButton`：主操作按钮四状态。
- `DessertSecondaryButton`：次操作和普通工具按钮四状态。
- `DessertDangerButton`：危险或破坏性操作四状态。
- `DessertFlatButton`：低强调操作四状态。
- `DessertIconButton`：方形图标和分页按钮四状态。
- `DessertTopTabButton`：顶部标签普通、悬停、选中、禁用状态。
- `DessertMainPanel`：主内容容器。
- `DessertSectionPanel`：分区卡片。
- `DessertInsetPanel`：内嵌内容区。
- `DessertModalPanel`：全局弹窗。
- `DessertPopupPanel`：紧凑弹出菜单。
- 输入、选择、进度、滚动条和物品槽变体：仅在项目现有节点类型能够安全承接时启用；其余样式先定义在 Theme 中，等待对应控件出现后使用。

文本、数字、箭头、对勾、锁和业务图标继续由 Godot 控件绘制或叠加，不烘焙进皮肤。

## 首轮场景映射

首轮接入优先覆盖角色明确且不需要改变节点路径的控件：

- `PrimaryActionButton` → `DessertPrimaryButton`
- `SecondaryActionButton` → `DessertSecondaryButton`
- `TertiaryActionButton` → `DessertFlatButton`
- 工作台顶部页面按钮 → `DessertTopTabButton`
- 顶部任务、库存、图鉴按钮 → `DessertSecondaryButton`
- 分页和紧凑图标操作按钮 → `DessertIconButton`，前提是尺寸和文本布局适合方形按钮
- `GlobalOverlayLayer` → `DessertModalPanel`
- 店铺经营分区 `PanelContainer` → `DessertSectionPanel`
- `ResearchHintPanel`、产出站点等内嵌区域 → `DessertInsetPanel`

透明全屏遮罩按钮 `GlobalPopupBackdrop` 保持 `flat`，不得继承可见按钮皮肤。

现有 `VBoxContainer`、`HBoxContainer` 不为换皮强行改变父子层级。本轮不把 `WorkbenchPanel` 改造成新的 `PanelContainer`，以免破坏大量稳定节点路径。后续如需给整个工作台增加主面板背景，应作为独立的场景结构任务处理。

## 动态创建控件

由脚本实例化的 `BasicButtonScene`、橱窗槽、任务条目和图鉴卡片会继承根 Theme，但必须通过场景中的 `theme_type_variation` 或创建后设置变体来表达角色。

首轮只给职责明确的动态控件应用变体。橱窗格、库存格和图鉴卡片应优先使用物品槽家族，而不是普通主按钮家族；已有特殊高亮 `StyleBoxFlat` 的橱窗组合提示继续保留，避免覆盖业务态边框。

## 错误处理与回退

- 派生脚本发现同族状态尺寸或透明边界异常时直接失败并报告文件名，不生成部分结果。
- Theme 缺少所需纹理或类型变体时，自检失败。
- 无法安全映射的节点保持当前默认样式，不进行猜测性替换。
- 原始 PNG 不变，因此可以通过移除 Theme 引用和运行时目录恢复接入前状态。

## 验证

新增 `tests/neighborhood_dessert_theme_self_check.gd`，至少验证：

1. Theme 文件可以加载且类型为 `Theme`。
2. 必需的运行时 PNG 存在并带透明通道。
3. 主按钮四个状态均为 `StyleBoxTexture`，纹理非空。
4. 同一控件族四个状态的纹理尺寸、patch margin 和 content margin 一致。
5. 面板变体存在并引用对应运行时素材。
6. `scenes/Main.tscn` 可以实例化，关键节点的 `theme_type_variation` 与设计映射一致。
7. `GlobalPopupBackdrop` 仍为透明扁平遮罩，不显示普通按钮皮肤。

验证命令从包含 `project.godot` 的目录运行，并按仓库约定传入可写日志路径：

```powershell
& "D:\Godot\Godot_v4.6.1-stable_win64_console.exe" `
  --headless `
  --path . `
  --log-file "$env:TEMP\projectrest-neighborhood-theme.log" `
  -s res://tests/neighborhood_dessert_theme_self_check.gd
```

Theme 自检通过后，再运行最窄的现有 UI 布局自检，确认皮肤接入没有改变节点路径、控件可见性和交互入口。

## 完成标准

- Theme 资源集中定义皮肤，不依赖运行时业务代码拼装样式。
- ImageGen 母版保持不变，运行时副本可重复生成。
- 主、次、扁平按钮和顶部标签状态切换无轮廓跳动。
- 现有面板按用途显示对应皮肤，透明遮罩不被误换肤。
- 主场景和相关 UI 自检通过，无新增 Godot 解析错误。
