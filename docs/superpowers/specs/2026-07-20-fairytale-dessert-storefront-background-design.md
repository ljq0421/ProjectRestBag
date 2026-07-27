# 左侧橱窗童话甜品店背景设计

## 目标

为 `project-rest-new` 左侧橱窗生成并接入一张全新的童话街边甜品店背景。现有背景视为废弃稿，不作为新图的构图或风格参考。

新背景需要让玩家一眼识别出“这是一家甜品店”，同时保证覆盖在其上的 14×12 商品格子、配方图标、状态标记和经营反馈仍然清晰可读。

## 已确认的视觉方向

- 场景类型：童话感街边甜品小店。
- 构图方式：正面店面框景，不使用明显斜透视。
- 信息密度：四周丰富、中部简洁。
- 时间与光线：明亮晴日下午，奶油暖光。
- 画风：简约、可爱、多巴胺；参考现有配方图标和 UI 素材的圆润轮廓、明亮配色、柔和高光与精致但不过度写实的质感。
- 主色：粉红、柠檬黄、薄荷绿与奶油白，辅以少量焦糖棕描边。

## 画面构成

背景采用正面观察的童话甜品店橱窗：

- 顶部设置粉红、柠檬黄、薄荷绿相间的波浪雨篷。
- 左右边缘可出现糖果立柱、蛋糕展示台、马卡龙、纸杯蛋糕、盆栽和小串灯等甜品店装饰。
- 底部以店铺窗台或低矮展示基座收边。
- 中部约 70% 的区域保持开阔，使用奶油色玻璃、柔和暖光和极轻的质感变化，不放置大型物体或高对比细节。
- 四周装饰不得向中心伸入过多，避免与商品图标争夺视觉焦点。

## 约束

- 最终项目资源尺寸为 `1008×864`，对应当前橱窗网格区域。
- 不包含人物、动物、文字、店名、Logo、水印或可被误读为按钮的标志。
- 不绘制商品格子、UI 面板、价格、标签或交互状态；这些仍由 Godot 场景负责。
- 不使用照片写实、厚重油画、像素画、暗黑或低饱和风格。
- 中央区域不得出现高对比招牌、大型蛋糕、门、桌椅或透视线汇聚点。
- 新资源使用独立文件名，生成与验收期间不覆盖现有背景文件。

## ImageGen 输入角色

- 现有配方图标：风格参考图，用于圆润轮廓、明亮色彩、柔和高光和可爱甜品质感。
- 现有 UI 素材：风格参考图，用于色彩协调与界面级清晰度。
- 现有橱窗背景：不输入、不参考，也不是编辑目标。

## 生成提示词规格

```text
Use case: stylized-concept
Asset type: 2D game storefront background behind an interactive 14 by 12 dessert display grid
Primary request: Create a brand-new front-facing fairytale street-side dessert shop window background. It must immediately read as a cute dessert shop while leaving the central display area visually quiet for game items.
Input images: Recipe icon and UI images are style references only for rounded silhouettes, bright colors, soft highlights, and polished cute game art. Do not copy their subjects or layouts. Do not use the existing storefront background as a reference.
Scene/backdrop: A whimsical dessert boutique facade on a bright sunny afternoon, seen straight from the front.
Subject: A striped scalloped awning in pink, lemon yellow, mint green, and cream across the top; candy-like trim, small cake stands, macarons, cupcakes, potted greenery, and tiny string lights concentrated around the left, right, and bottom edges; a warm cream-colored shop-window surface in the center.
Style/medium: Polished 2D casual-game illustration, simple, cute, dopamine-bright, rounded shapes, clean caramel-brown outlines, soft dimensional highlights, consistent with the supplied recipe icons and UI references.
Composition/framing: 7:6 landscape canvas, straight-on symmetrical storefront framing. Keep approximately 70 percent of the center open, calm, low-detail, and low-contrast. Rich decoration stays at the perimeter and does not intrude into the central product grid.
Lighting/mood: Bright sunny afternoon, warm creamy daylight, cheerful and welcoming, no dramatic shadows.
Color palette: Strawberry pink, lemon yellow, mint green, cream white, with restrained caramel brown outlines.
Text: none.
Constraints: background artwork only; no grid cells; no UI panels; no characters or animals; no words, signs, logos, numbers, or watermark; no large central objects; no strong perspective; no photorealism; no dark or muted palette.
Avoid: clutter in the center, oversized cakes in the middle, doors or furniture in the central area, high-contrast focal points behind product icons, copied composition from any existing storefront background.
```

## 接入设计

1. 使用内置 ImageGen 生成一张全新候选图，配方图标和 UI 图只作为风格参考。
2. 检查构图、中心留白、色彩和禁用项；如需迭代，每次只调整一个问题。
3. 将通过验收的图片等比裁切并缩放为 `1008×864`，以新文件名保存到 `resources/ui/backgrounds/`。
4. 在 `showcase_board.tscn` 中仅替换背景资源绑定，保留 `ShowcaseGrid` 直接子节点路径、14×12 几何、槽位交互和现有反馈层级。
5. 不触碰当前工作区中与橱窗背景无关的修改。

## 验收标准

- 空橱窗状态下，玩家能立即识别童话街边甜品店、彩色雨篷和甜品装饰。
- 商品铺满后，中心配方图标、格子状态和文字仍然比背景更醒目。
- 背景四周有明显多巴胺色彩与装饰，中部没有抢眼物体或高频纹理。
- 图片无文字、人物、Logo、水印和 UI 伪元素。
- 资源以 `1008×864` 加载，不拉伸变形，不改变当前左侧橱窗尺寸。
- 橱窗专项自检、相关布局自检和 `git diff --check` 通过。
