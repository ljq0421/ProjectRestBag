# 邻里甜品店 UI 皮肤 ImageGen 提示词规格

日期：2026-07-10  
目标项目：Godot 4.6，1920×1080 设计视口  
输出目标：无文字、2× 源素材、独立透明 PNG、可切片或可九宫格拉伸

## 1. 最终画风基准

UI 控件只参考以下两张图片：

1. `output/imagegen/neighborhood_dessert_shop_concept.png`：整体 UI、颜色、面板、按钮和标签页语言。
2. `output/imagegen/ui_icons/dessert_shop_ui_icon_sheet_4x4.png`：圆润轮廓、深棕描边、暖色高光和图标精致度。

配方与甜品图片只作为界面中的内容图标，不参与 UI 控件的风格迁移。不得把食品颗粒、玻璃杯、奶油旋涡、食材或甜品造型带入面板和按钮。

## 2. 生成方式

每个生成提示词由三段拼接：

```text
[固定风格前缀]
[控件族描述]
[状态描述或固定素材描述]
```

执行约束：

- 每次只生成一个控件或一个状态。
- 普通状态先生成；悬停、按下、选中和禁用状态优先以普通状态图片作为编辑目标生成，避免轮廓漂移。
- 编辑状态时重复要求：只改变颜色、亮度或压感，尺寸、圆角、描边、透明留白必须完全不变。
- 可九宫格拉伸的素材不带外部投影；投影单独生成或在 Godot 中实现。
- 输出图片不得含文字、数字、图标、伪文字和水印。
- 内置 ImageGen 先生成纯色键控背景，再在本地去背；普通控件使用 `#00FF00`，绿色控件使用 `#FF00FF`。
- 去背后统一裁边和画布尺寸；同一控件族的各状态必须逐像素对齐。

## 3. 固定风格前缀

以下内容添加到每条新生成提示词之前：

```text
Use case: ui-mockup
Asset type: one isolated 2D game UI skin control for direct use in a Godot project

Input images:
Image 1 is the full neighborhood dessert shop UI style reference only.
Image 2 is the matching dessert shop UI icon style reference only.
Use both images only to match their visual language. Do not reproduce their screen layout, text, icons, food, characters, or individual objects.

Style/medium:
cozy neighborhood dessert shop management game UI;
cute polished 2D hand-painted illustration;
rounded friendly geometry;
thick smooth dark-chocolate-brown outlines;
warm cream surfaces;
honey-gold edges;
coral-red accents;
subtle upper-left highlights;
soft pastel colors;
clean mobile-game readability;
front-facing orthographic UI asset, not a perspective object.

Color palette:
warm cream #FFF2CF;
pale custard #FFE6A8;
honey gold #F4B43A;
coral red #F36F5E;
dark chocolate brown #693719;
soft leaf green #8FC447.

Nine-slice requirements:
the asset must be suitable for clean 9-slice scaling;
perfectly constant border thickness;
four corners must have matching radius and visual weight;
long horizontal and vertical border sections must be straight and repeatable;
the center region must be broad, clean, nearly flat, and free of decorative details;
no texture, highlight streak, ornament, seam, or shadow may cross a stretchable center line;
keep decorative shading confined to protected borders and corners;
symmetrical geometry;
generous padding around the asset.

Content constraints:
blank control skin only;
no text, letters, numbers, Chinese characters, pseudo-text, icons, symbols, food, characters, logos, or watermark;
no external cast shadow;
no floor plane;
no perspective;
no cropped edges.

Background:
place the single control on a perfectly flat solid #00FF00 chroma-key background;
the background must be completely uniform with no gradient, texture, lighting variation, reflection, or shadow;
do not use #00FF00 anywhere inside the control.
```

绿色控件把最后一段替换为：

```text
Background:
place the single control on a perfectly flat solid #FF00FF chroma-key background;
the background must be completely uniform with no gradient, texture, lighting variation, reflection, or shadow;
do not use #FF00FF anywhere inside the control.
```

## 4. 通用状态编辑提示词

状态图必须以同族普通状态为编辑目标。下列提示词无需再次加入参考图；每次都保留“不改变轮廓”的约束。

### 4.1 悬停状态

```text
Edit target: the supplied normal-state UI control.
Change only the interaction state to hover.
Keep the canvas size, transparent padding, silhouette, border thickness, corner radius, proportions, center safe area, and lighting direction pixel-aligned and unchanged.
Make the face slightly brighter and warmer, strengthen only the protected inner-rim highlight, and add a restrained welcoming emphasis.
Do not enlarge, move, crop, deform, add text, add an icon, or add an external shadow.
```

### 4.2 按下状态

```text
Edit target: the supplied normal-state UI control.
Change only the interaction state to pressed.
Keep the canvas size, transparent padding, silhouette, outer border, corner radius, proportions, and stretchable center region pixel-aligned and unchanged.
Darken the face slightly, reduce the upper highlight, and create a gentle inset feeling confined inside the protected border.
No perspective shift, no position shift, no new shadow, no text, and no icon.
```

### 4.3 禁用状态

```text
Edit target: the supplied normal-state UI control.
Change only the interaction state to disabled.
Keep the canvas size, transparent padding, silhouette, border thickness, corner radius, proportions, and center safe area pixel-aligned and unchanged.
Desaturate the face toward pale peach-beige, lower the contrast of the brown outline, and minimize highlights while preserving readability.
Do not add a lock icon, text, pattern, overlay symbol, or external shadow.
```

### 4.4 选中状态

```text
Edit target: the supplied normal-state UI control.
Change only the interaction state to selected.
Keep the canvas size, transparent padding, silhouette, border thickness, corner radius, proportions, and center safe area pixel-aligned and unchanged.
Use a warm coral face or coral inner rim, a clear honey-gold protected highlight, and slightly stronger contrast.
Do not resize, move, crop, add text, add an icon, or place decoration in the stretchable center.
```

## 5. 容器类提示词

### `panel_main_normal.png`

```text
Primary request: create one large blank main UI panel frame.
Shape: wide horizontal rounded rectangle.
Appearance: warm cream interior; dark-chocolate outer outline; honey-gold inner rim; subtle pale highlight along the protected upper border; slightly warmer shading along the protected lower border.
Layout: large uninterrupted center area suitable for dense inventory grids and production controls.
State: neutral default container.
Avoid: attached title tab, hanging sign, ornaments, corner icons, food motifs, external shadow.
```

### `panel_section_normal.png`

```text
Primary request: create one blank secondary section panel.
Shape: rounded rectangle with a slightly smaller corner radius than the main panel.
Appearance: pale custard interior; single dark-chocolate outline; restrained honey inner edge; quieter contrast than the main panel.
Layout: broad clean center for lists, descriptions, and grouped controls.
Avoid: title text, icons, decorative tabs, external shadow.
```

### `panel_inset_normal.png`

```text
Primary request: create one blank inset content well.
Shape: rounded rectangle designed to appear recessed inside a larger cream panel.
Appearance: very pale warm-beige center; medium brown inner outline; subtle protected upper-inner shadow and lower-inner highlight.
Layout: clean center for item grids, materials, or status content.
Avoid: external border ornament, external shadow, texture in the center.
```

### `panel_modal_normal.png`

```text
Primary request: create one blank modal dialog panel.
Shape: centered medium-wide rounded rectangle with a strong but friendly frame.
Appearance: warm cream face; double dark-brown and honey-gold rim; slightly stronger protected top highlight than normal panels.
Layout: large empty center and generous inner padding for a title, content, and action row added later in Godot.
Avoid: title text, close icon, buttons, ribbons, food motifs, external shadow.
```

### `panel_popup_normal.png`

```text
Primary request: create one blank compact popup menu panel.
Shape: vertical rounded rectangle with modest corner radius.
Appearance: pale cream face; thin dark-brown outline; small honey-gold inner rim.
Layout: uninterrupted center suitable for a vertical menu.
Avoid: pointer tail, menu items, separators, text, icons, external shadow.
```

### `tooltip_bubble_normal.png`

```text
Primary request: create one blank tooltip bubble background.
Shape: compact rounded rectangle with one small centered downward pointer tail integrated into the protected bottom border.
Appearance: light custard face; dark-brown outline; soft upper-left highlight.
Layout: clean empty interior for short Godot-rendered tooltip text.
Avoid: text, question-mark icon, food motifs, detached tail, external shadow.
```

### `title_plate_normal.png`

```text
Primary request: create one blank horizontal title plate.
Shape: wide wooden-sign-inspired rounded plaque without chains or hanging hardware.
Appearance: pale biscuit-cream face; dark-brown outline; honey-gold inner edge; tiny protected corner flourishes only.
Layout: broad empty center for a page title rendered in Godot.
Avoid: text, carved letters, icons, food, wood grain across the center, external shadow.
```

### `hanging_sign_normal.png`

```text
Primary request: create one blank compact hanging page sign as a single isolated asset.
Shape: rounded horizontal plaque with two short symmetrical hanging loops contained inside the asset bounds.
Appearance: warm biscuit face; dark-brown outline; honey highlights; friendly dessert-shop styling.
Layout: blank center for a short title.
Avoid: text, long chains, perspective, food icons, external cast shadow.
```

## 6. 按钮类提示词

每种按钮先生成普通状态，再用第 4 节生成 `hover`、`pressed`、`disabled`。

### 主按钮族：`button_primary_{state}.png`

```text
Primary request: create one blank primary action button in its normal state.
Shape: wide pill-like rounded rectangle.
Appearance: coral-red face; dark-chocolate outline; thin warm-orange inner rim; broad empty center.
State: normal and clearly clickable; gentle upper highlight confined to the protected top border; slightly darker protected lower edge.
Avoid: glow, icon, text, pressed indentation, external shadow.
```

### 次按钮族：`button_secondary_{state}.png`

```text
Primary request: create one blank secondary action button in its normal state.
Shape: wide rounded rectangle matching the primary button's height and corner radius.
Appearance: pale custard face; dark-chocolate outline; honey-gold inner rim; broad empty center.
State: normal, friendly, and lower emphasis than the coral primary button.
Avoid: icon, text, coral fill, external shadow.
```

### 警示按钮族：`button_danger_{state}.png`

```text
Primary request: create one blank warning or destructive action button in its normal state.
Shape: wide rounded rectangle matching the primary button geometry.
Appearance: warm tomato-red face; dark-chocolate outline; restrained golden inner rim; empty center.
State: visibly cautionary without looking hostile or photorealistic.
Avoid: warning symbol, icon, text, flame motif, external shadow.
```

### 扁平按钮族：`button_flat_{state}.png`

```text
Primary request: create one blank low-emphasis text-button background in its normal state.
Shape: slim rounded rectangle.
Appearance: very pale translucent-looking cream face rendered as opaque artwork; thin warm-brown outline; minimal protected highlight.
State: quiet and suitable for secondary links or compact actions.
Avoid: text, icon, transparency inside the control, external shadow.
```

### 方形图标按钮族：`button_icon_{state}.png`

```text
Primary request: create one blank square icon-button background in its normal state.
Shape: square with large rounded corners, centered and perfectly symmetrical.
Appearance: pale cream face; dark-chocolate outline; honey-gold inner rim; empty central icon area.
State: normal and clearly clickable.
Avoid: icon, symbol, text, circular frame, external shadow.
```

## 7. 标签页提示词

### 顶部标签族：`tab_top_{state}.png`

普通状态：

```text
Primary request: create one blank horizontal top tab in its inactive normal state.
Shape: wide tab with rounded upper corners, modest lower corners, and a straight repeatable bottom edge.
Appearance: pale custard face; dark-brown outline; honey inner rim; empty center.
State: inactive but readable.
Avoid: text, icon, downward pointer, external shadow.
```

选中状态使用第 4.4 节；悬停和禁用分别使用第 4.1、4.3 节。

### 侧边标签族：`tab_side_{state}.png`

普通状态：

```text
Primary request: create one blank vertical side-navigation tab in its inactive normal state.
Shape: tall rounded rectangle with a slightly extended protected outer edge; front-facing and symmetrical.
Appearance: pale custard face; dark-brown outline; honey inner rim; large empty center.
State: inactive and lower emphasis than the selected tab.
Avoid: text, icon, arrow, external shadow.
```

选中状态使用第 4.4 节；悬停和禁用分别使用第 4.1、4.3 节。

## 8. 输入与选择控件提示词

### 文本输入框：`input_text_{normal|focus|error|disabled}.png`

```text
Primary request: create one blank single-line text input frame in its normal state.
Shape: long low rounded rectangle.
Appearance: off-white center; thin dark-brown outline; pale honey inner edge; broad clean typing area.
Avoid: placeholder text, cursor, icon, underline, external shadow.
```

聚焦编辑提示词：

```text
Edit target: the supplied normal text input frame.
Change only the state to focused.
Keep all geometry and padding pixel-aligned and unchanged.
Strengthen the honey-gold inner rim and add a restrained warm highlight confined to the protected border.
No text, cursor, icon, glow outside the bounds, or size change.
```

错误编辑提示词：

```text
Edit target: the supplied normal text input frame.
Change only the state to validation error.
Keep all geometry and padding pixel-aligned and unchanged.
Change only the protected inner rim to warm coral red and slightly increase border contrast.
No warning icon, text, shake effect, external glow, or size change.
```

禁用使用第 4.3 节。

### 数字输入框：`input_number_{normal|focus|error|disabled}.png`

```text
Primary request: create one blank numeric input frame in its normal state.
Shape: medium-width low rounded rectangle with a clean main entry region and one protected narrow segment on the right reserved for stepper buttons.
Appearance: off-white center; thin dark-brown outline; pale honey inner edge; one straight vertical divider inside the protected right segment.
Avoid: numbers, plus sign, minus sign, arrows, icons, external shadow.
```

其余状态沿用文本输入框的编辑规则。

### 下拉框：`input_dropdown_{normal|focus|error|disabled}.png`

```text
Primary request: create one blank dropdown selector frame in its normal state.
Shape: long low rounded rectangle with a protected square segment on the right reserved for a dropdown icon.
Appearance: off-white center; thin dark-brown outline; honey inner edge; one straight divider before the protected icon segment.
Avoid: arrow icon, text, menu, external shadow.
```

其余状态沿用文本输入框的编辑规则。

### 复选框：`checkbox_{unchecked|checked|hover|disabled}.png`

未选中：

```text
Asset type: one isolated fixed-size 2D game UI selection control, not a nine-slice panel.
Primary request: create one blank unchecked checkbox.
Shape: small square with rounded corners.
Appearance: warm-white center; dark-chocolate outline; subtle honey inner rim.
Avoid: check mark, text, icon, external shadow.
```

已选中：

```text
Edit target: the supplied unchecked checkbox.
Change only the state to checked.
Keep canvas size, padding, silhouette, and border unchanged.
Fill the protected interior with coral red and place one simple cream-colored check mark centered inside.
No text, no extra decoration, and no external shadow.
```

悬停和禁用使用第 4.1、4.3 节。

### 单选框：`radio_{unchecked|checked|hover|disabled}.png`

未选中：

```text
Asset type: one isolated fixed-size 2D game UI selection control, not a nine-slice panel.
Primary request: create one blank unselected radio button.
Shape: perfect small circle.
Appearance: warm-white center; dark-chocolate outline; subtle honey inner rim.
Avoid: center dot, text, external shadow.
```

已选中：

```text
Edit target: the supplied unselected radio button.
Change only the state to selected.
Keep canvas size, padding, circle silhouette, outline, and lighting unchanged.
Add one centered coral-red circular dot with a tiny protected highlight.
No text, no extra ring, and no external shadow.
```

悬停和禁用使用第 4.1、4.3 节。

### 开关：`toggle_{off|on|hover|disabled}.png`

关闭：

```text
Asset type: one isolated fixed-size 2D game UI toggle control, not a nine-slice panel.
Primary request: create one toggle switch in the off state.
Shape: horizontal rounded capsule with one circular cream thumb positioned on the left.
Appearance: muted pale-beige track; dark-chocolate outline; honey rim; cream thumb.
Avoid: text, icons, external shadow.
```

开启：

```text
Edit target: the supplied off-state toggle.
Change only the state to on.
Keep canvas size, padding, track silhouette, outline, and thumb size unchanged.
Change the track to soft leaf green and move the circular cream thumb to the symmetrical right position.
No text, icon, glow, or external shadow.
```

悬停和禁用分别在对应基础状态上应用第 4.1、4.3 节。

## 9. 数值与进度控件提示词

### `progress_track.png`

```text
Primary request: create one blank horizontal progress-bar track.
Shape: long low rounded capsule.
Appearance: dark warm-brown outer outline; recessed pale-custard interior; clean uninterrupted center.
Layout: designed to receive a separately rendered fill bar layered above it in Godot.
Avoid: fill amount, text, tick marks, icon, external shadow.
```

### `progress_fill_green.png`

使用洋红键控背景：

```text
Primary request: create one isolated horizontal progress-bar fill strip.
Shape: long rounded capsule with symmetrical ends and no outer frame.
Appearance: soft leaf-green face; lighter protected top highlight; slightly darker lower edge; clean repeatable middle segment.
Layout: suitable for horizontal nine-slice scaling and clipping to different fill amounts.
Avoid: track, text, tick marks, glow, external shadow.
```

### `progress_fill_gold.png`

```text
Primary request: create one isolated horizontal progress-bar fill strip.
Shape: long rounded capsule with symmetrical ends and no outer frame.
Appearance: honey-gold face; pale custard protected top highlight; warm orange lower edge; clean repeatable middle segment.
Layout: suitable for horizontal nine-slice scaling and clipping to different fill amounts.
Avoid: track, text, tick marks, glow, external shadow.
```

### `progress_fill_coral.png`

```text
Primary request: create one isolated horizontal progress-bar fill strip.
Shape: long rounded capsule with symmetrical ends and no outer frame.
Appearance: coral-red face; pale peach protected top highlight; warm red lower edge; clean repeatable middle segment.
Layout: suitable for horizontal nine-slice scaling and clipping to different fill amounts.
Avoid: track, text, tick marks, glow, external shadow.
```

### `slider_track.png`

```text
Primary request: create one isolated horizontal slider track.
Shape: very long thin rounded capsule.
Appearance: pale custard inset center; thin dark-brown outline; no fill amount.
Avoid: thumb, tick marks, text, external shadow.
```

### `slider_thumb_{normal|hover|pressed|disabled}.png`

```text
Asset type: one isolated fixed-size 2D game UI slider thumb.
Primary request: create one circular slider thumb in its normal state.
Shape: perfect circle.
Appearance: coral-red center; dark-chocolate outline; thin honey inner rim; small protected upper-left highlight.
Avoid: track, text, icon, external shadow.
```

其余状态使用第 4.1、4.2、4.3 节。

## 10. 物品槽提示词

### `slot_item_{normal|hover|selected|locked|disabled|reward}.png`

普通状态：

```text
Primary request: create one blank square inventory item slot in its normal state.
Shape: square with medium rounded corners.
Appearance: warm cream recessed center; dark-chocolate outline; pale honey inner rim; broad empty icon area.
Avoid: item, food, number, label, icon, external shadow.
```

悬停使用第 4.1 节，选中使用第 4.4 节，禁用使用第 4.3 节。

锁定状态：

```text
Edit target: the supplied normal inventory slot.
Change only the state to locked.
Keep canvas size, padding, silhouette, border, corner radius, and center area pixel-aligned and unchanged.
Darken and desaturate the recessed center and add a very subtle translucent warm-gray protected overlay.
Do not add a lock icon, text, chain, pattern, or external shadow; the lock icon will be layered separately in Godot.
```

奖励高亮状态：

```text
Edit target: the supplied normal inventory slot.
Change only the state to reward-highlighted.
Keep canvas size, padding, silhouette, border, corner radius, and center area pixel-aligned and unchanged.
Make the protected inner rim honey-gold, brighten the cream center slightly, and add small restrained corner sparkles confined outside the icon-safe center.
No item, text, badge, external glow, or external shadow.
```

## 11. 信息与导航素材提示词

### `badge_round.png`

```text
Asset type: one isolated fixed-size 2D game UI badge background.
Primary request: create one blank circular notification badge.
Appearance: coral-red face; dark-chocolate outline; tiny pale upper-left highlight; empty center for a Godot-rendered number.
Avoid: number, text, icon, external shadow.
```

### `counter_pill.png`

```text
Primary request: create one blank compact counter pill.
Shape: short horizontal rounded capsule.
Appearance: pale custard face; dark-brown outline; honey inner rim; clean empty center.
Avoid: number, label, icon, external shadow.
```

### `status_tag_{normal|positive|warning|negative}.png`

普通状态：

```text
Primary request: create one blank compact status label background.
Shape: short low rounded capsule.
Appearance: pale cream face; medium brown outline; minimal protected highlight; empty center.
Avoid: text, icon, external shadow.
```

正向状态把表面改为软叶绿色，警告状态改为蜂蜜金，负向状态改为珊瑚红；所有状态必须保持轮廓和尺寸完全一致。绿色版本使用洋红键控背景。

### `divider_horizontal.png`

```text
Asset type: one isolated fixed-size horizontal UI divider.
Primary request: create one long thin horizontal separator line.
Appearance: warm medium-brown center line with one subtle pale-custard highlight directly above it; softly rounded ends.
Layout: clean repeatable center segment, suitable for horizontal stretching.
Avoid: ornaments, text, icon, external shadow.
```

垂直分隔线可在 Godot 中旋转复用。

### `scrollbar_track.png`

```text
Primary request: create one isolated vertical scrollbar track.
Shape: long thin rounded capsule.
Appearance: recessed pale-custard center; thin warm-brown outline; no thumb.
Layout: clean vertically repeatable middle section.
Avoid: arrows, thumb, text, external shadow.
```

横向滚动条轨道可在 Godot 中旋转复用。

### `scrollbar_thumb_{normal|hover|pressed|disabled}.png`

```text
Primary request: create one isolated vertical scrollbar thumb in its normal state.
Shape: short rounded capsule.
Appearance: honey-gold face; dark-chocolate outline; protected pale upper-left highlight; clean center.
Avoid: grip lines, arrows, text, external shadow.
```

其余状态使用第 4.1、4.2、4.3 节。横向滑块可在 Godot 中旋转复用。

分页按钮复用 `button_icon_{state}.png`，箭头由现有 UI 图标叠加；不单独生成带箭头的按钮。

## 12. 独立辅助素材

### `shadow_panel_soft.png`

```text
Use case: ui-mockup
Asset type: one isolated reusable soft panel shadow for a 2D game UI
Primary request: create one subtle rounded-rectangle ambient shadow only, with an empty transparent-looking center and generous padding.
Style: warm soft brown shadow, very low opacity appearance, smooth falloff, symmetrical, front-facing.
Background: perfectly flat solid #00FF00 chroma-key background with no variation.
Constraints: no panel, no border, no text, no icon, no hard edge, no cast direction, no watermark; do not use #00FF00 in the shadow.
```

### `focus_ring.png`

```text
Use case: ui-mockup
Asset type: one isolated reusable focus ring for a 2D game UI
Primary request: create one blank rounded-rectangle honey-gold focus outline with a clean empty center.
Style: cozy dessert-shop mobile-game UI; dark-chocolate outer hairline; warm honey glow confined close to the ring.
Background: perfectly flat solid #00FF00 chroma-key background with no variation.
Constraints: suitable for nine-slice scaling; no panel fill, no text, no icon, no external wide glow, no watermark.
```

### `selection_ring.png`

```text
Use case: ui-mockup
Asset type: one isolated reusable selected-item outline for a 2D game UI
Primary request: create one square rounded-corner coral and honey selection frame with a completely empty center.
Style: dark-chocolate outer outline, coral inner band, tiny protected honey corner highlights.
Background: perfectly flat solid #00FF00 chroma-key background with no variation.
Constraints: suitable for nine-slice scaling; no item, no text, no icon, no external shadow, no watermark.
```

### `overlay_locked.png`

```text
Use case: ui-mockup
Asset type: one isolated reusable locked-state overlay for a square item slot
Primary request: create one blank rounded-square translucent-looking warm-gray overlay with a clean center.
Style: very restrained cozy game UI shading, no border ornament.
Background: perfectly flat solid #00FF00 chroma-key background with no variation.
Constraints: no lock icon, no chain, no text, no pattern, no external shadow, no watermark.
```

## 13. 首批校准顺序

先只制作以下五张：

1. `panel_main_normal.png`
2. `button_primary_normal.png`
3. `button_primary_hover.png`
4. `button_primary_pressed.png`
5. `button_primary_disabled.png`

验收标准：

- 主面板中央横向、纵向拉伸后无纹理断裂。
- 四个按钮状态的画布、轮廓、描边、圆角和透明留白完全对齐。
- 状态只通过色彩、亮度和内凹感区分，不依赖文字或图标。
- 缩小到 2× 源素材的目标显示尺寸后，深棕描边仍然清晰。
- 素材与概念图、UI 图标表并排时属于同一套游戏视觉语言。

校准通过后再按“容器 → 按钮 → 标签 → 输入 → 数值 → 物品槽 → 信息导航 → 辅助素材”的顺序生成。

## 14. Godot 使用约束

- 面板、按钮、标签、输入框、进度条和状态标签使用 `NinePatchRect`、`StyleBoxTexture` 或对应 Theme 样式。
- 九宫格 patch margin 必须落在纯直边区域内，不能切到圆角、高光端点或装饰。
- 文字、数字、箭头、对勾、锁和业务图标由 Godot 节点叠加，不烘焙进皮肤。
- 按钮各状态使用同一内容边距，避免交互时文字跳动。
- 横纵分隔线和滚动条优先旋转复用，减少重复资产。
- 运行时需要的主题资源和场景结构仍以 `.tscn` 为主，图片只承担皮肤，不承担布局。
