# 食材图标 ImageGen 批量提示词

下面的 YAML 可整批交给支持多图任务的 ImageGen 调度器。每个 `item` 必须生成一张独立图片，不能生成拼图、联系表或雪碧图。

```yaml
batch_instruction: >
  Generate 64 separate 512x512 PNG images, exactly one image per item.
  Use each item's filename exactly. Do not create a collage, contact sheet, sprite sheet,
  comparison board, or multi-panel image. Keep the visual style and apparent scale consistent
  across the entire batch.

common_prompt: >
  512x512 game ingredient inventory icon, isolated single ingredient subject,
  hand-drawn simple 2D illustration, thick dark-brown outline, rounded cute shapes,
  warm natural pastel colors, simple but not empty, a few clear interior details,
  clean readable silhouette, slightly top-down 3/4 view, cozy cooking game UI icon.
  Center the subject and make it fit comfortably inside one centered cell of an invisible 4x4 grid;
  do not draw the grid. Leave generous transparent padding on every side.
  Transparent PNG background preferred. If transparency is unavailable, use one perfectly flat
  solid chroma-key light cyan background (#DDF8F5), with no texture, gradient, or shadow.

negative_prompt: >
  photorealistic, 3D render, realistic food photography, thin outline, messy sketch,
  complex scene, kitchen, farm landscape, table surface, basket, decorative frame,
  branded packaging, readable label, text, Chinese characters, numbers, watermark, logo,
  visible grid, UI frame, gradient background, textured background, cast shadow, drop shadow,
  glow, multiple unrelated ingredients, recipe dish, cooked meal, cropped subject, low contrast

items:
  # 种子类：统一使用无文字的小牛皮纸种子袋，袋口露出少量种子，正面只画对应作物图案。
  - filename: rice_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with several pale golden rice grains visible at the opening,
      a simple rice-ear pictogram on the pouch, no text, one compact centered icon.
  - filename: wheat_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with warm tan wheat kernels visible at the opening,
      a simple wheat-ear pictogram on the pouch, no text, one compact centered icon.
  - filename: red_bean_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with a few glossy deep-red bean seeds visible at the opening,
      a simple red-bean pod pictogram on the pouch, no text.
  - filename: black_sesame_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with a small cluster of black sesame seeds visible at the opening,
      a simple sesame pod pictogram on the pouch, no text.
  - filename: pumpkin_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with several flat cream pumpkin seeds visible at the opening,
      a simple orange pumpkin pictogram on the pouch, no text.
  - filename: glutinous_rice_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with short pearly-white glutinous rice grains visible at the opening,
      a simple plump rice-ear pictogram on the pouch, no text.
  - filename: chestnut_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch holding one glossy chestnut seed partly visible at the opening,
      a simple chestnut pictogram on the pouch, no text.
  - filename: oats_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with slender beige oat grains visible at the opening,
      a simple oat-panicle pictogram on the pouch, no text.
  - filename: strawberry_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with a few tiny golden strawberry seeds visible at the opening,
      a simple bright-red strawberry pictogram on the pouch, no text.
  - filename: blueberry_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with tiny reddish-brown blueberry seeds visible at the opening,
      a simple blue blueberry pictogram on the pouch, no text.
  - filename: banana_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with several small dark banana seeds visible at the opening,
      a simple curved yellow banana pictogram on the pouch, no text.
  - filename: apple_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with several glossy teardrop-shaped brown apple seeds visible,
      a simple red apple pictogram on the pouch, no text.
  - filename: lemon_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with several pale pointed lemon seeds visible at the opening,
      a simple yellow lemon pictogram on the pouch, no text.
  - filename: peach_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch holding one ridged tan peach stone partly visible at the opening,
      a simple pink peach pictogram on the pouch, no text.
  - filename: orange_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch with several smooth cream orange seeds visible at the opening,
      a simple orange-fruit pictogram on the pouch, no text.
  - filename: mango_seed.png
    prompt: >
      A tiny unbranded kraft-paper seed pouch holding one broad flat mango seed partly visible at the opening,
      a simple golden mango pictogram on the pouch, no text.

  # 农作物与养殖
  - filename: rice.png
    prompt: >
      A neat small mound of pearly uncooked rice grains with several individually readable grains,
      warm ivory highlights, no bowl, sack, plant, or extra props.
  - filename: wheat.png
    prompt: >
      A compact bundle of three ripe golden wheat ears tied by their own curved stems,
      plump kernels and a clean fan-shaped silhouette, no sack or field.
  - filename: red_bean.png
    prompt: >
      A compact cluster of glossy deep-red adzuki beans, several beans overlapping naturally,
      each with a tiny pale hilum, no bowl or pouch.
  - filename: black_sesame.png
    prompt: >
      A compact oval mound of tiny black sesame seeds, a few separated at the edge for readability,
      subtle charcoal and warm-black variation, no bowl or spoon.
  - filename: pumpkin.png
    prompt: >
      One small round orange pumpkin with deep rounded ribs, a short curled green stem,
      and a tiny leaf attached to the same stem, whole uncut ingredient.
  - filename: glutinous_rice.png
    prompt: >
      A neat small mound of short plump pearly glutinous rice grains, visibly rounder and whiter than regular rice,
      no bowl, sack, or plant.
  - filename: chestnut.png
    prompt: >
      A compact cluster of three glossy brown chestnuts, one showing its pale tan base,
      rounded triangular forms, no leaves, branch, or roasting marks.
  - filename: oats.png
    prompt: >
      A compact bundle of pale golden oat panicles with curved stems and clearly separated oat grains,
      airy but readable silhouette, no sack or field.
  - filename: chick.png
    prompt: >
      One tiny fluffy yellow chick standing in a gentle 3/4 pose, round body, orange beak and feet,
      simple friendly expression, no eggshell, nest, grass, or farm scenery.
  - filename: calf.png
    prompt: >
      One small cream-and-caramel calf standing in a gentle 3/4 pose, rounded muzzle, tiny ears and hooves,
      friendly simple expression, no bell, fence, grass, or farm scenery.
  - filename: egg.png
    prompt: >
      A compact pair of clean whole chicken eggs, one warm cream and one pale beige,
      gently overlapping with simple speckle details, no nest, carton, or broken shell.
  - filename: milk.png
    prompt: >
      One small clear glass bottle filled with opaque fresh white milk, rounded shoulders and a simple stopper,
      no label, text, straw, splash, cow, or extra props.
  - filename: chicken.png
    prompt: >
      One clean raw chicken breast cut shown as a soft pale-pink rounded fillet with two simple contour details,
      appetizing game-ingredient styling, no blood, bones, plate, knife, or garnish.
  - filename: beef.png
    prompt: >
      One clean raw beef cut shown as a deep-red rounded steak with a simple cream fat edge and subtle marbling,
      appetizing game-ingredient styling, no blood, bones, plate, knife, or garnish.

  # 乳制品、水果与林场食材
  - filename: butter.png
    prompt: >
      A compact golden-yellow block of butter with softly rounded corners and two shallow cut lines,
      a tiny curled shaving attached to the block, no wrapper, plate, knife, or text.
  - filename: cream.png
    prompt: >
      One neat glossy swirl of thick white whipped cream with rounded folds and a soft peak,
      no bowl, piping bag, fruit, cake, or garnish.
  - filename: cheese.png
    prompt: >
      One warm golden wedge of semi-hard cheese with a few rounded holes and a creamy cut face,
      no wrapper, board, knife, grapes, or text.
  - filename: yogurt.png
    prompt: >
      One small plain ceramic cup filled with smooth white yogurt, a single creamy swirl visible on top,
      no label, foil lid, fruit, spoon, or garnish.
  - filename: strawberry.png
    prompt: >
      One ripe heart-shaped strawberry, bright red with evenly spaced golden seeds and a fresh green leafy crown,
      whole uncut fruit, no flower, basket, or extra berries.
  - filename: blueberry.png
    prompt: >
      A compact cluster of three plump blueberries in varied deep-blue tones, clear star-shaped calyx details,
      no leaves, branch, bowl, or extra fruit.
  - filename: banana.png
    prompt: >
      One small curved ripe yellow banana with a dark tip and a few soft brown freckles,
      whole unpeeled fruit, no bunch, leaf, peel pieces, or plate.
  - filename: apple.png
    prompt: >
      One round ripe red apple with a warm yellow cheek, short brown stem and one attached green leaf,
      whole uncut fruit, no slice, basket, or blossom.
  - filename: lemon.png
    prompt: >
      One bright yellow lemon with a slightly pointed oval shape, dimpled peel details and one attached green leaf,
      whole uncut fruit, no slices, juice splash, or glass.
  - filename: peach.png
    prompt: >
      One plump peach with warm pink and golden skin, a clear center crease, soft fuzz marks,
      short stem and one attached leaf, no slices or basket.
  - filename: orange.png
    prompt: >
      One round vivid orange with subtle dimpled peel, short stem and one attached dark-green leaf,
      whole uncut fruit, no segments, juice splash, or basket.
  - filename: mango.png
    prompt: >
      One plump curved mango with golden-yellow skin blending into coral red and a small attached green leaf,
      whole uncut fruit, no slices, pit, or basket.
  - filename: honey.png
    prompt: >
      One small round clear jar filled with glowing amber honey, a simple cork lid and one thick honey curl
      visible inside the jar, no label, text, dipper, bee, flower, or spill.
  - filename: nuts.png
    prompt: >
      A compact mixed cluster of shelled walnut, hazelnut and cashew pieces, warm natural browns,
      clearly readable shapes, no bowl, sack, leaves, or scattered crumbs.
  - filename: mint.png
    prompt: >
      One compact fresh mint sprig with three pairs of bright green serrated leaves and a curved stem,
      visible leaf veins, no pot, soil, drink, ice, or extra herbs.
  - filename: cinnamon.png
    prompt: >
      A compact pair of warm reddish-brown cinnamon sticks crossed gently, curled layered ends clearly visible,
      no powder pile, ribbon, cup, star anise, or extra spices.

  # 水塘、调味与加工辅料
  - filename: spring_water_starter.png
    prompt: >
      One small clear teardrop-shaped glass vial filled with pale aqua spring-water starter,
      sealed with a simple cork and marked only by an embossed ripple symbol, no text, label, splash, or scenery.
  - filename: spring_water.png
    prompt: >
      One large crystal-clear pale-blue water droplet with two simple white highlight shapes and a subtle inner ripple,
      no glass, bottle, splash scene, wave, fish, or landscape.
  - filename: sea_salt.png
    prompt: >
      A neat compact mound of coarse white sea-salt crystals with a few pale-blue edge highlights,
      clearly faceted grains, no bowl, spoon, shaker, shell, or sea scenery.
  - filename: sugar.png
    prompt: >
      A neat compact mound of fine sparkling white sugar with several larger translucent crystals at the front,
      warm-white tone distinct from sea salt, no bowl, spoon, cube, or packet.
  - filename: chocolate.png
    prompt: >
      One compact dark-brown chocolate bar broken into three rounded square segments,
      one corner piece slightly lifted to show thickness, no wrapper, cocoa beans, crumbs, or text.
  - filename: vanilla.png
    prompt: >
      A compact pair of slender dark vanilla pods gently curved and crossed, one pod split slightly to reveal
      tiny seeds, no flower, bottle, powder, ice cream, or extra props.
  - filename: caramel.png
    prompt: >
      One glossy amber caramel dollop shaped like a thick curled ribbon with a rounded peak,
      translucent golden highlights, no jar, spoon, candy wrapper, dessert, or spill.
  - filename: gelatin.png
    prompt: >
      A compact stack of three translucent pale-gold gelatin sheets with softly wavy edges and clear layered corners,
      no packet, bowl, jelly dessert, powder pile, or text.
  - filename: yeast.png
    prompt: >
      A neat compact mound of tiny warm-beige dry yeast granules with several distinct round grains at the edge,
      no packet, bowl, spoon, bread, dough, or text.
  - filename: matcha.png
    prompt: >
      A neat compact mound of vivid moss-green matcha powder with one clean curved ridge and a few fine dust specks,
      no bowl, whisk, spoon, tea cup, leaves, or packaging.
  - filename: coffee.png
    prompt: >
      A compact cluster of five glossy roasted coffee beans in rich dark brown, each with a clear curved center groove,
      no cup, sack, branch, leaves, steam, or powder.
  - filename: cocoa.png
    prompt: >
      A neat compact mound of deep warm-brown cocoa powder with one smooth curved ridge and a few fine dust specks,
      no bowl, spoon, cocoa pod, chocolate bar, or packaging.
  - filename: almond.png
    prompt: >
      A compact cluster of three whole almonds with warm tan ridged skins and one pale split almond showing its center,
      no bowl, shell fragments, leaves, chocolate, or crumbs.
  - filename: black_tea.png
    prompt: >
      A compact loose cluster of twisted dry black-tea leaves in deep reddish brown, with several curled leaf shapes
      clearly readable, no cup, teapot, liquid, sachet, or packaging.
  - filename: green_tea.png
    prompt: >
      A compact loose cluster of slender rolled green-tea leaves in fresh olive and jade tones,
      clearly readable leaf shapes, no cup, teapot, liquid, sachet, or packaging.
  - filename: rice_flour.png
    prompt: >
      A neat compact mound of fine warm-ivory rice flour with a smooth peak and two tiny grain-like specks,
      no bowl, scoop, rice grains, sack, or packaging.
  - filename: flour.png
    prompt: >
      A neat compact mound of fine pale-cream wheat flour with a soft airy peak and one shallow curved groove,
      no bowl, scoop, wheat ears, dough, sack, or packaging.
  - filename: glutinous_rice_flour.png
    prompt: >
      A neat compact mound of very fine pearly-white glutinous rice flour with a rounded dense peak
      and subtle cool highlights, no bowl, scoop, rice grains, mochi, sack, or packaging.
```

## 使用说明

如果所用界面不能真正一次输出 64 个独立文件，可按 YAML 中的顺序拆成 4 批，每批 16 张；每批都保留相同的 `common_prompt` 和 `negative_prompt`。透明背景不稳定时，先生成统一的 `#DDF8F5` 纯色底，再批量抠图，边缘会比复杂白底更干净。
