# 邻里甜品店现有控件换肤设计

## 目标

将 `resources/ui/skin/neighborhood_dessert/` 中已生成、但尚未接入的素材，仅应用到当前项目中真实存在的 Godot 控件。保持业务逻辑、节点路径、控件文本和交互信号不变；皮肤资源只负责外观与交互状态。

## 范围

本轮接入以下已存在的控件族：

1. 输入与选择：`LineEdit`、`OptionButton`、`SpinBox`、`CheckButton`。
2. 数值与导航：`ProgressBar`、`TabBar`、`HScrollBar`/`VScrollBar`、现有分页与关闭图标按钮。
3. 信息反馈：`PopupMenu`、默认 Tooltip、产出单元与厨房排程中的状态标签。
4. 动态格子：现有库存、研发、图鉴、产出等运行时创建的 `Button`，仅补齐可见状态所需的语义变体。

以下素材不在本轮接入范围，因为当前项目没有对应的实际控件或页面承载它们：`tab_side_*`、`radio_*`、`slider_*`、`hanging_sign_normal`、`title_plate_normal`、`focus_ring`、`selection_ring`、`overlay_locked`、`shadow_panel_soft`。素材保留在皮肤目录中，后续新增功能时再接入。

## 方案

继续以 `neighborhood_dessert_theme.tres` 为单一视觉入口。`tools/build_neighborhood_dessert_skin.py` 负责从透明源图生成统一裁边、统一尺寸的运行时 PNG；Theme 通过语义 `theme_type_variation` 为场景节点和运行时节点提供 `StyleBoxTexture`、图标纹理及文字颜色。

不在场景中逐节点复制 `theme_override_styles`。场景只声明控件职责，例如 `DessertTextInput`、`DessertDropdownInput`、`DessertNumberInput`、`DessertToggle`、`DessertProgressBar`、`DessertTopTabBar`、`DessertPopupMenu` 和 `DessertStatusTag*`。这样同一类控件可复用同一套九宫格边距，状态切换不会引起文字或布局跳动。

## 控件映射

| 素材族 | 运行时 Theme 变体 | 当前使用位置 |
| --- | --- | --- |
| `input_text_*` | `DessertTextInput` | 库存搜索框与后续同类 `LineEdit` |
| `input_dropdown_*` | `DessertDropdownInput` | 库存排序、厨房排程的三个 `OptionButton` |
| `input_number_*` | `DessertNumberInput`（应用到 `SpinBox` 内部 `LineEdit`） | 厨房排程 `TargetStockSpin` 及动态保留量 `SpinBox` |
| `toggle_*` | `DessertToggle` | 产出托管开关、厨房暂停/离线开关 |
| `progress_track` + `progress_fill_green` | `DessertProgressBar` | `OutputCell/ProductionProgressBar` |
| `tab_top_*` | `DessertTopTabBar` | 采购分类、库存、图鉴等 `TabBar` |
| `scrollbar_track` + `scrollbar_thumb_*` | `DessertVerticalScrollBar` / `DessertHorizontalScrollBar` | 现有 `ScrollContainer` 自动创建的滚动条 |
| `panel_popup_normal` | `DessertPopupMenu` | 产出右键菜单、库存变体菜单 |
| `tooltip_bubble_normal` | `TooltipPanel` | Godot 默认 Tooltip 背景 |
| `status_tag_*` | `DessertStatusTagNormal/Positive/Warning/Negative` | 产出托管状态和厨房排程状态 |
| `button_danger_*` | `DessertDangerButton` | 厨房排程“移除规则”等危险操作 |

现有已接入的主/次/扁平/图标按钮、面板和物品槽保持不变；本轮只补齐缺口。

## 运行时素材处理

构建器为每个状态族使用同一个 alpha 并集裁切框，缩放到该族的目标尺寸后写入 `resources/ui/skin/neighborhood_dessert/runtime/`。所有多状态家族必须在检查中满足：RGBA、输出尺寸一致、alpha 边界一致。

滚动条横向纹理由同一竖向源图在构建器中旋转导出，避免重复生成图片。`StyleBoxTexture` 的九宫格边距必须落在直边区；输入框、进度条和滚动条中心区只能被拉伸，圆角、端点、分隔区和高光边缘不得被拉伸。

## 动态状态与回退

动态创建的格子继续使用当前节点类型和信号。需要皮肤的节点由创建代码设置语义变体；`SpinBox` 的输入框皮肤设置在其内部 `LineEdit`，因为 Godot 的 `SpinBox` 不提供整块输入框的 `normal` / `focus` StyleBox 槽。业务脚本不加载 PNG，也不维护纹理路径。

状态标签只在现有标签节点可见时切换变体，不新增遮挡交互的包装节点。若某个控件类型不支持所需 Theme 样式，保留 Godot 默认外观并在自检中记录为未接入，而不是改变其行为或节点结构。

## 验证

新增/扩展 `tests/neighborhood_dessert_theme_self_check.gd`，验证：

- 每个新增 Theme 变体拥有完整所需状态与 `StyleBoxTexture`/纹理。
- 每个新增场景节点及动态创建路径使用正确的语义变体。
- 多状态运行时图片尺寸与 alpha 边界严格一致。
- `Main.tscn` 可实例化，原有稳定节点路径仍存在。

每个控件族按红—绿循环实施：先新增失败断言并运行对应 Godot 自检，再添加最小 Theme/场景/脚本变更使其通过。最终运行运行时皮肤检查、Theme 自检和与本轮场景有关的窄范围布局检查。

## 完成标准

用户可在现有页面中看到输入、选择、托管开关、进度、标签、滚动、弹出菜单和状态反馈使用同一套邻里甜品店视觉语言；没有业务逻辑变化、没有文本跳动、没有状态图错位；未使用的素材不被强行接入。
