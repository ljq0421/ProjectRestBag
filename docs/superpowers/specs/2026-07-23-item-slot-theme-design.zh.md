# 库存、图鉴与产出格子主题设计

## 目标

在 `project-rest-new` 中，将库存、图鉴和产出页面仍在使用 Godot 默认 `Button`
背景的格子，统一切换到现有的甜品店物品格视觉体系。

本次只改变格子背景及其交互状态外观，不改变格子尺寸、内容层级、分页、拖拽、
选择、锁定、收获或自动化行为。

## 已确认范围

纳入修改：

- 库存格，包括商品、原料和空格。
- 图鉴配方卡，包括已解锁、未解锁和分页补位空格。
- 产出格。

保持现状：

- 研究投料格继续使用 `DessertContentButton`。
- 橱窗格继续使用 `DessertShowcaseSlot` 及其现有状态变体。
- 操作按钮、分页按钮、筛选按钮和其他普通 `Button` 不受影响。
- 不修改 sibling checkout `project-rest`。

## 现状

统一主题已经载入以下物品格素材：

- `slot_item_normal.png`
- `slot_item_hover.png`
- `slot_item_selected.png`
- `slot_item_locked.png`
- `slot_item_disabled.png`
- `slot_item_reward.png`

这些素材已经用于橱窗格主题，但库存格、图鉴卡和产出格根节点没有物品格
`theme_type_variation`。全局普通 `Button` 只覆盖了文字颜色，没有覆盖背景
StyleBox，因此这些格子仍显示 Godot 默认按钮背景。

## 方案比较

### 方案 A：为现有 Button 增加物品格 Theme Variation

直接在统一 Theme 中增加语义化物品格变体，并绑定到现有格子根节点。

优点：

- 复用现有状态素材。
- 不增加节点，不影响鼠标命中、拖拽、裁切和内容层级。
- 状态映射集中在 Theme，后续可以统一调整。
- 只影响明确绑定的格子。

这是本次采用的方案。

### 方案 B：为每个格子增加 NinePatchRect 背景节点

可以独立控制背景层，但会增加场景节点和层级管理，还需要保证
`mouse_filter = MOUSE_FILTER_IGNORE`，并重新检查裁切和拖拽预览。当前没有必须使用
独立背景节点才能实现的视觉要求，因此不采用。

### 方案 C：覆盖全局 Button 背景

实现最少，但会同时改变操作按钮、分页按钮、筛选按钮和其他普通按钮，范围失控，
因此不采用。

## 主题结构

统一 Theme 新增两个语义变体：

### `DessertItemSlot`

- `normal`、`focus`：`StyleBox_slot_normal`
- `hover`：`StyleBox_slot_hover`
- `pressed`、`hover_pressed`：`StyleBox_slot_selected`
- `disabled`：`StyleBox_slot_disabled`

用于库存格、产出格、已解锁图鉴卡和分页补位空格。库存格当前的
`toggle_mode` 和 `button_pressed` 继续驱动选中背景。

### `DessertItemSlotLocked`

- 所有状态使用 `StyleBox_slot_locked`

用于真实存在但尚未解锁的图鉴配方卡。锁定卡仍保持 `disabled = true`，不能点击；
该变体只改变锁定状态的表现，不改变解锁规则。

`slot_item_reward.png` 本次不新增使用场景，继续保留给已有奖励状态。

## 场景与运行时绑定

### 库存

`inventory_product_cell.tscn` 根按钮绑定 `DessertItemSlot`。

由 `basic_button.tscn` 创建的库存原料回退格和空格不能全局修改基础按钮场景，
因为该场景还被其他非格子界面复用。因此 `_make_inventory_cell()` 在完成实例化后，
统一将本次库存按钮设置为 `DessertItemSlot`。

### 图鉴

`catalog_recipe_card.tscn` 根按钮默认绑定 `DessertItemSlot`。

`_make_catalog_cell()` 根据卡片内容切换状态：

- 空配方 ID：保持 `DessertItemSlot`，并继续禁用。
- 已解锁配方：保持 `DessertItemSlot`。
- 未解锁配方：切换到 `DessertItemSlotLocked`，并继续禁用。

### 产出

`output_cell.tscn` 根按钮绑定 `DessertItemSlot`。现有商品图标、数量、进度条、
自动化状态标签和上下文操作均保持原样。

## 交互与失败行为

- Theme 资源缺失属于项目资源错误，不增加静默运行时回退逻辑。
- 不新增背景子控件，因此鼠标事件仍由原根 `Button` 接收。
- 库存选择仍由 `toggle_mode` 与 `button_pressed` 表达。
- 图鉴锁定卡仍不能点击，空补位卡不会伪装成需要解锁的真实配方。
- 产出格的禁用状态使用 `slot_item_disabled`，不使用锁定背景。

## 验证

新增或扩展聚焦自检，至少验证：

1. Theme 中存在 `DessertItemSlot` 和 `DessertItemSlotLocked`，且各状态映射正确。
2. 库存商品格和图鉴卡场景根按钮绑定预期变体。
3. 由 `_make_inventory_cell()` 创建的商品、原料与空格均使用
   `DessertItemSlot`。
4. 图鉴已解锁、未解锁和空补位卡分别使用正确变体，且禁用状态不变。
5. 产出格绑定 `DessertItemSlot`，并仍能构建现有内容节点。
6. 现有研究投料格与橱窗格主题绑定未改变。
7. 使用带可写 `--log-file` 的 Godot 4.6.1 headless 命令运行聚焦自检。
8. 运行相关既有回归检查和 `git diff --check`。

## 非目标

- 不制作或替换新的 PNG。
- 不修改现有物品格素材的颜色、边距或分辨率。
- 不调整格子尺寸、列数、分页数量或页面布局。
- 不改变库存拖拽、图鉴解锁、产出收获和自动化逻辑。
- 不重做研究投料格或橱窗格。
- 不把物品格皮肤扩散到普通操作按钮。
