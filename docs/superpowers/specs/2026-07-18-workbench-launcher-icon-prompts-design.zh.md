# 工作台导航图标 Image Gen 提示词设计

日期：2026-07-18
目标项目：`project-rest-new`
目标入口：星辉、任务、库存、图鉴、采购、产出、橱窗经营

## 1. 使用方式

- 每次仅将一条完整提示词交给 Image Gen，生成一张独立图片。
- 输出为 1024×1024、1:1、真实透明 Alpha 背景的 PNG。
- 不要把七个图标生成在同一张图中，不要生成图标表或拼贴图。
- 生成后保留图标主体四周的透明安全区；正式接入时缩放至约 48 px 显示。
- 建议文件名依次为：`starlight.png`、`task.png`、`inventory.png`、`catalog.png`、`purchase.png`、`output.png`、`storefront.png`。

## 2. 统一视觉契约

七枚图标必须属于同一套“邻里甜点店”管理游戏 UI：单主体、圆润友好、清晰粗描边、温暖手绘上色。主体约占画布的 78%，居中，采用正面略带俯视的正交视角。最终导航只显示图标，中文名称放入 tooltip，因此图标缩小到约 48 px 后仍须仅凭轮廓互相区分。

固定调色板：

- warm cream `#FFF2CF`
- pale custard `#FFE6A8`
- honey gold `#F4B43A`
- coral red `#F36F5E`
- dark chocolate brown `#693719`
- soft leaf green `#8FC447`

所有提示词共同排除：文字、字母、数字、伪文字、徽章底板、圆形底板、方形底板、外框、按钮皮肤、场景背景、地面、投影、多个独立图标、拼贴图、图标表、摄影写实和 3D 渲染。

## 3. 七条独立完整提示词

### 3.1 星辉 `starlight.png`

```text
Create one isolated navigation icon for a cozy neighborhood dessert shop management game.

SUBJECT: one large, plump five-point starlight star, with a honey-gold outer body and a small coral-red inset center. Add exactly three tiny sparkle accents closely attached to the upper-right edge so the whole design reads as one compact subject. Make the star silhouette bold, symmetrical, friendly, magical, and instantly recognizable at 48 px. Do not add a wand, moon, sky, constellation, character, or separate decorative scene.

STYLE: polished 2D hand-painted game icon; rounded friendly geometry; thick, smooth, consistent dark-chocolate-brown outline; warm cream highlights; soft layered cel shading with a light painted finish; restrained upper-left highlight; clean mobile-game readability; front-facing orthographic view with only a very slight top-down angle; not photorealistic and not a 3D render.

PALETTE LOCK: use only warm cream #FFF2CF, pale custard #FFE6A8, honey gold #F4B43A, coral red #F36F5E, dark chocolate brown #693719, and soft leaf green #8FC447. Dark chocolate brown is for the main outline. Honey gold must dominate this icon. Do not introduce blue, purple, gray, black, or white outside this palette.

COMPOSITION: square 1:1 canvas, 1024x1024; a single centered icon occupying about 78% of the canvas; generous even transparent padding; compact silhouette; no cropped edges; no tiny internal detail that disappears at 48 px.

BACKGROUND AND OUTPUT: true fully transparent alpha background; isolated subject only; no colored backdrop, no badge plate, no circular tile, no square tile, no border, no button skin, no floor plane, and no cast shadow. Output one standalone PNG icon, not an icon sheet and not a collage.

STRICT EXCLUSIONS: no text, letters, numbers, Chinese characters, pseudo-text, logo, watermark, food, extra objects, multiple icon variants, photorealism, or 3D rendering.
```

### 3.2 任务 `task.png`

```text
Create one isolated navigation icon for a cozy neighborhood dessert shop management game.

SUBJECT: one compact cream-colored task clipboard with a rounded honey-gold clip. Show one large coral-red check mark and two simple blank rounded task markers as clean graphic shapes; include no writing and no line that could resemble text. Keep the clipboard slightly wider and softer than an office clipboard, with a friendly handcrafted dessert-shop feel. The silhouette must read immediately as “tasks” at 48 px. Do not add a pencil, character, desk, loose paper, or second clipboard.

STYLE: polished 2D hand-painted game icon; rounded friendly geometry; thick, smooth, consistent dark-chocolate-brown outline; warm cream surfaces; soft layered cel shading with a light painted finish; restrained upper-left highlight; clean mobile-game readability; front-facing orthographic view with only a very slight top-down angle; not photorealistic and not a 3D render.

PALETTE LOCK: use only warm cream #FFF2CF, pale custard #FFE6A8, honey gold #F4B43A, coral red #F36F5E, dark chocolate brown #693719, and soft leaf green #8FC447. Dark chocolate brown is for the main outline. Warm cream must dominate the clipboard, with coral red reserved for the check mark. Do not introduce blue, purple, gray, black, or white outside this palette.

COMPOSITION: square 1:1 canvas, 1024x1024; a single centered icon occupying about 78% of the canvas; generous even transparent padding; compact silhouette; no cropped edges; no tiny internal detail that disappears at 48 px.

BACKGROUND AND OUTPUT: true fully transparent alpha background; isolated subject only; no colored backdrop, no badge plate, no circular tile, no square tile, no border, no button skin, no floor plane, and no cast shadow. Output one standalone PNG icon, not an icon sheet and not a collage.

STRICT EXCLUSIONS: no text, letters, numbers, Chinese characters, pseudo-text, handwriting, ruled text lines, logo, watermark, extra objects, multiple icon variants, photorealism, or 3D rendering.
```

### 3.3 库存 `inventory.png`

```text
Create one isolated navigation icon for a cozy neighborhood dessert shop management game.

SUBJECT: one sturdy closed wooden storage chest used for shop inventory. Give it a broad rounded lid, two simple honey-gold corner brackets, and one centered coral-red latch. The chest must look organized, dependable, and clearly closed, with a strong rectangular silhouette that remains recognizable at 48 px. Keep all details large and simple. Do not show products spilling out, shopping handles, coins, shelves, a room, or a second box.

STYLE: polished 2D hand-painted game icon; rounded friendly geometry; thick, smooth, consistent dark-chocolate-brown outline; warm custard-colored wood rather than realistic brown wood; soft layered cel shading with a light painted finish; restrained upper-left highlight; clean mobile-game readability; front-facing orthographic view with only a very slight top-down angle; not photorealistic and not a 3D render.

PALETTE LOCK: use only warm cream #FFF2CF, pale custard #FFE6A8, honey gold #F4B43A, coral red #F36F5E, dark chocolate brown #693719, and soft leaf green #8FC447. Dark chocolate brown is for the main outline. Pale custard and honey gold must dominate the storage chest. Do not introduce blue, purple, gray, black, or white outside this palette.

COMPOSITION: square 1:1 canvas, 1024x1024; a single centered icon occupying about 78% of the canvas; generous even transparent padding; compact silhouette; no cropped edges; no tiny wood grain or fine texture that disappears at 48 px.

BACKGROUND AND OUTPUT: true fully transparent alpha background; isolated subject only; no colored backdrop, no badge plate, no circular tile, no square tile, no border, no button skin, no floor plane, and no cast shadow. Output one standalone PNG icon, not an icon sheet and not a collage.

STRICT EXCLUSIONS: no text, letters, numbers, Chinese characters, pseudo-text, logo, watermark, open chest, shopping basket, extra objects, multiple icon variants, photorealistic wood, or 3D rendering.
```

### 3.4 图鉴 `catalog.png`

```text
Create one isolated navigation icon for a cozy neighborhood dessert shop management game.

SUBJECT: one open recipe catalog book with thick rounded cream pages, a honey-gold cover edge, and one coral-red ribbon bookmark hanging from the center. On the two visible pages, use only one large simple dessert silhouette and one small star-shaped discovery mark as flat decorative symbols; do not use writing, lists, or lines that resemble text. The open-book silhouette must be broad, balanced, and instantly recognizable at 48 px. Do not add loose pages, a pen, ingredients, a table, or a second book.

STYLE: polished 2D hand-painted game icon; rounded friendly geometry; thick, smooth, consistent dark-chocolate-brown outline; warm cream surfaces; soft layered cel shading with a light painted finish; restrained upper-left highlight; clean mobile-game readability; front-facing orthographic view with only a very slight top-down angle; not photorealistic and not a 3D render.

PALETTE LOCK: use only warm cream #FFF2CF, pale custard #FFE6A8, honey gold #F4B43A, coral red #F36F5E, dark chocolate brown #693719, and soft leaf green #8FC447. Dark chocolate brown is for the main outline. Warm cream must dominate the pages; coral red is reserved for the center ribbon. Do not introduce blue, purple, gray, black, or white outside this palette.

COMPOSITION: square 1:1 canvas, 1024x1024; a single centered icon occupying about 78% of the canvas; generous even transparent padding; compact silhouette; no cropped edges; no tiny page details that disappear at 48 px.

BACKGROUND AND OUTPUT: true fully transparent alpha background; isolated subject only; no colored backdrop, no badge plate, no circular tile, no square tile, no border, no button skin, no floor plane, and no cast shadow. Output one standalone PNG icon, not an icon sheet and not a collage.

STRICT EXCLUSIONS: no text, letters, numbers, Chinese characters, pseudo-text, handwriting, ruled text lines, logo, watermark, extra objects, multiple icon variants, photorealism, or 3D rendering.
```

### 3.5 采购 `purchase.png`

```text
Create one isolated navigation icon for a cozy neighborhood dessert shop management game.

SUBJECT: one plump woven market shopping basket with a single large rounded handle. Attach one clearly visible honey-gold coin tag to the front, marked only by a simple embossed four-point sparkle shape, never a currency letter or number. Keep the basket closed-looking and empty from the viewing angle so it reads as “purchasing” rather than “inventory” or “harvest.” Use broad coral-red weave bands as a restrained accent. The handle-and-basket silhouette must remain recognizable at 48 px. Do not add groceries, seed packets, a shop counter, hands, multiple coins, or a second basket.

STYLE: polished 2D hand-painted game icon; rounded friendly geometry; thick, smooth, consistent dark-chocolate-brown outline; simplified warm woven texture using broad shapes only; soft layered cel shading with a light painted finish; restrained upper-left highlight; clean mobile-game readability; front-facing orthographic view with only a very slight top-down angle; not photorealistic and not a 3D render.

PALETTE LOCK: use only warm cream #FFF2CF, pale custard #FFE6A8, honey gold #F4B43A, coral red #F36F5E, dark chocolate brown #693719, and soft leaf green #8FC447. Dark chocolate brown is for the main outline. Pale custard must dominate the basket, with honey gold on the coin tag. Do not introduce blue, purple, gray, black, or white outside this palette.

COMPOSITION: square 1:1 canvas, 1024x1024; a single centered icon occupying about 78% of the canvas; generous even transparent padding; compact silhouette; no cropped edges; no fine weave pattern that disappears at 48 px.

BACKGROUND AND OUTPUT: true fully transparent alpha background; isolated subject only; no colored backdrop, no badge plate, no circular tile, no square tile, no border, no button skin, no floor plane, and no cast shadow. Output one standalone PNG icon, not an icon sheet and not a collage.

STRICT EXCLUSIONS: no text, letters, numbers, Chinese characters, pseudo-text, currency symbols, logo, watermark, extra objects, multiple icon variants, photorealism, or 3D rendering.
```

### 3.6 产出 `output.png`

```text
Create one isolated navigation icon for a cozy neighborhood dessert shop management game.

SUBJECT: one shallow rounded wooden harvest tray holding one compact, unified harvest arrangement: a bold honey-gold wheat ear at the back, one small cream milk bottle on the left, one soft-leaf-green leaf in the center, and one large pale-custard water droplet on the right. Treat the tray and its contents as one tightly grouped subject, not four separate icons. Use very few, oversized shapes so the full silhouette remains clear at 48 px. The icon must communicate collected output from farm, ranch, forest, and pond. Do not add a shopping handle, coin, storage lid, landscape, buildings, animals, or extra produce.

STYLE: polished 2D hand-painted game icon; rounded friendly geometry; thick, smooth, consistent dark-chocolate-brown outline around the outer subject and clear simplified internal separations; warm cream surfaces; soft layered cel shading with a light painted finish; restrained upper-left highlight; clean mobile-game readability; front-facing orthographic view with only a very slight top-down angle; not photorealistic and not a 3D render.

PALETTE LOCK: use only warm cream #FFF2CF, pale custard #FFE6A8, honey gold #F4B43A, coral red #F36F5E, dark chocolate brown #693719, and soft leaf green #8FC447. Dark chocolate brown is for the main outline. Honey gold, warm cream, and soft leaf green should clearly separate the four harvest symbols. Do not introduce blue, purple, gray, black, or white outside this palette; the water droplet must use pale custard, not blue.

COMPOSITION: square 1:1 canvas, 1024x1024; a single centered icon occupying about 78% of the canvas; generous even transparent padding; compact triangular silhouette; no cropped edges; no tiny ingredients or fine texture that disappears at 48 px.

BACKGROUND AND OUTPUT: true fully transparent alpha background; isolated subject only; no colored backdrop, no badge plate, no circular tile, no square tile, no border, no button skin, no floor plane, and no cast shadow. Output one standalone PNG icon, not an icon sheet and not a collage.

STRICT EXCLUSIONS: no text, letters, numbers, Chinese characters, pseudo-text, logo, watermark, shopping basket, separate mini-icons, extra objects, multiple icon variants, photorealism, or 3D rendering.
```

### 3.7 橱窗经营 `storefront.png`

```text
Create one isolated navigation icon for a cozy neighborhood dessert shop management game.

SUBJECT: one compact neighborhood dessert shop storefront facade. Use a broad coral-red and pale-custard striped awning, one large warm-cream display window, and one simple honey-gold cake silhouette centered behind the glass. Add a tiny soft-leaf-green open-status dot as a decorative light, but no signboard and no written sign. Make the facade wider than it is tall, with a bold shop-shaped silhouette that remains instantly recognizable at 48 px. Do not add a street, customers, tables, multiple cakes, surrounding buildings, or a full interior scene.

STYLE: polished 2D hand-painted game icon; rounded friendly architecture; thick, smooth, consistent dark-chocolate-brown outline; warm cream surfaces; soft layered cel shading with a light painted finish; restrained upper-left highlight; clean mobile-game readability; front-facing orthographic view with only a very slight top-down angle; not photorealistic and not a 3D render.

PALETTE LOCK: use only warm cream #FFF2CF, pale custard #FFE6A8, honey gold #F4B43A, coral red #F36F5E, dark chocolate brown #693719, and soft leaf green #8FC447. Dark chocolate brown is for the main outline. Coral red and pale custard must dominate the awning; warm cream and honey gold define the window and cake. Do not introduce blue glass, purple, gray, black, or white outside this palette.

COMPOSITION: square 1:1 canvas, 1024x1024; a single centered icon occupying about 78% of the canvas; generous even transparent padding; compact silhouette; no cropped edges; no tiny architectural detail that disappears at 48 px.

BACKGROUND AND OUTPUT: true fully transparent alpha background; isolated subject only; no colored backdrop, no badge plate, no circular tile, no square tile, no border, no button skin, no floor plane, and no cast shadow. Output one standalone PNG icon, not an icon sheet and not a collage.

STRICT EXCLUSIONS: no text, letters, numbers, Chinese characters, pseudo-text, shop name, logo, watermark, scene background, extra objects, multiple icon variants, photorealism, or 3D rendering.
```

## 4. 一致性验收标准

- 七张图片的描边粗细、光照方向、透视角度、主体占比和透明留白一致。
- 星辉、任务、库存、图鉴、采购、产出、橱窗经营在 48 px 下可仅凭轮廓区分。
- 库存保持“关闭储物箱”，采购保持“带把手购物篮”，产出保持“无把手收获托盘”，避免三者混淆。
- 所有可见色均来自固定调色板；不出现蓝色玻璃、蓝色水滴、纯黑描边或纯白高光。
- 每次只输出一个独立图标；不出现图标表、拼贴、多个方案或附加装饰场景。
- 图片不含任何文字、数字、伪文字、品牌标记或水印。
