# 挑战配方相似度与全面支配审计

由 `tools/audit_challenge_recipe_similarity.py` 生成。

本报告用于持续分诊和验证人工重做结果；算法结果不能替代路线模拟与真人试玩。

## 摘要

- 运行时配方：166
- 唯一精确战斗签名：145
- 完全重复簇：20
- 完全重复簇涉及配方：41
- 重复配方槽位：21
- 近似重复配对（分数 >= 85): 322
- 保守全面支配关系：72
- 被支配配方：35

## 审计规则

- 精确签名包含构筑角色、标签、标准形状、旋转语义、成本、复制上限、库存、周期和满足力。
- 可旋转形状会在 0/90/180/270 度之间归一化，避免横竖方向制造虚假差异。
- 近似重复分数只用于安排人工复核优先级，不直接证明玩家体感相同。
- 全面支配要求形状和旋转语义相同，角色与标签为超集，全部战斗数值不差，且至少一项严格更优。

## 研究分支覆盖

| 分支 | 配方数 |
| --- | ---: |
| `crisp_bake` | 12 |
| `fruit_set` | 35 |
| `milk_soft` | 33 |
| `savory_hearty` | 29 |
| `signature_display` | 20 |
| `spatial_combo` | 10 |
| `tea_bittersweet` | 24 |
| `tempo_display` | 3 |

## 完全重复簇

### exact-001 · 3 个配方

- 角色：`softness`；标签：`soft`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 4；复制上限 2；库存 4；周期 2000 ms；满足力 9

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `pumpkin_steamed_cake` · 南瓜蒸糕 | `milk_soft` | 3 | `C` |
| `red_bean_milk_drink` · 红豆牛奶饮 | `milk_soft` | 3 | `C` |
| `red_bean_rice_cake` · 红豆沙米糕 | `milk_soft` | 3 | `C` |

### exact-002 · 2 个配方

- 角色：`pairing`；标签：`drink, fruit, refreshing`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 4；复制上限 2；库存 4；周期 4000 ms；满足力 11

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `berry_rice_drink` · 莓果米浆饮 | `fruit_set` | 4 | `D` |
| `berry_rice_flour_cake` · 莓果米粉蒸糕 | `fruit_set` | 4 | `D` |

### exact-003 · 2 个配方

- 角色：`shape, tempo`；标签：`crisp, rich`
- 形状：`(0,0)`；可旋转：`false`
- 成本 3；复制上限 3；库存 6；周期 4000 ms；满足力 8

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `black_sesame_crisp_cake` · 黑芝麻酥饼 | `crisp_bake` | 3 | `B` |
| `matcha_cookie` · 抹茶曲奇 | `crisp_bake` | 3 | `D` |

### exact-004 · 2 个配方

- 角色：`signature`；标签：`fast, rich`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 4；复制上限 2；库存 4；周期 4000 ms；满足力 10

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `black_sesame_oats_soup` · 黑芝麻燕麦糊 | `signature_display` | 3 | `C` |
| `black_sesame_soup` · 黑芝麻糊 | `signature_display` | 3 | `B` |

### exact-005 · 2 个配方

- 角色：`flavor`；标签：`rich, tea`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 4；复制上限 2；库存 4；周期 8000 ms；满足力 12

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `black_tea_caramel_mousse` · 红茶焦糖慕斯 | `tea_bittersweet` | 4 | `D` |
| `black_tea_mousse` · 红茶慕斯杯 | `tea_bittersweet` | 4 | `D` |

### exact-006 · 2 个配方

- 角色：`sustain`；标签：`savory, tea`
- 形状：`(0,0) (0,1) (1,0) (1,1)`；可旋转：`false`
- 成本 6；复制上限 1；库存 2；周期 8000 ms；满足力 16

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `black_tea_chicken_baked_rice` · 红茶鸡肉焗饭 | `savory_hearty` | 4 | `D` |
| `black_tea_light_cheesecake` · 红茶轻芝士蛋糕 | `savory_hearty` | 4 | `D` |

### exact-007 · 2 个配方

- 角色：`pairing`；标签：`drink, fruit, set`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 3；复制上限 2；库存 5；周期 5000 ms；满足力 8

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `blueberry_mousse` · 蓝莓慕斯杯 | `fruit_set` | 2 | `baseline` |
| `strawberry_mousse` · 草莓慕斯杯 | `fruit_set` | 2 | `baseline` |

### exact-008 · 2 个配方

- 角色：`softness`；标签：`rich, soft`
- 形状：`(0,0)`；可旋转：`false`
- 成本 3；复制上限 3；库存 6；周期 4000 ms；满足力 8

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `chestnut_glutinous_rice_cake` · 栗子糯米糍 | `milk_soft` | 3 | `C` |
| `cocoa_glutinous_rice_cake` · 可可糯米糍 | `milk_soft` | 3 | `C` |

### exact-009 · 2 个配方

- 角色：`softness`；标签：`rich, soft`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 4；复制上限 2；库存 4；周期 8000 ms；满足力 11

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `chestnut_mousse` · 栗子慕斯杯 | `milk_soft` | 3 | `C` |
| `matcha_redbean_mousse` · 抹茶红豆慕斯 | `milk_soft` | 3 | `D` |

### exact-010 · 2 个配方

- 角色：`signature`；标签：`rich`
- 形状：`(0,0) (0,1) (1,0)`；可旋转：`false`
- 成本 5；复制上限 1；库存 2；周期 8000 ms；满足力 13

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `chestnut_pound_cake` · 栗香磅蛋糕 | `signature_display` | 3 | `C` |
| `coffee_pound_cake` · 咖啡磅蛋糕 | `signature_display` | 3 | `C` |

### exact-011 · 2 个配方

- 角色：`sustain`；标签：`rich, savory`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 3；复制上限 2；库存 4；周期 2000 ms；满足力 8

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `chicken_cream_soup` · 鸡肉奶油浓汤 | `savory_hearty` | 2 | `A` |
| `sea_salt_caramel_pudding` · 海盐焦糖布丁 | `savory_hearty` | 2 | `B` |

### exact-012 · 2 个配方

- 角色：`sustain`；标签：`hearty, savory`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 3；复制上限 2；库存 4；周期 2000 ms；满足力 7

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `chicken_steamed_dumpling` · 鸡肉蒸饺 | `savory_hearty` | 1 | `A` |
| `chicken_wheat_porridge` · 鸡肉麦仁粥 | `savory_hearty` | 1 | `A` |

### exact-013 · 2 个配方

- 角色：`signature`；标签：`rich`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 4；复制上限 2；库存 4；周期 8000 ms；满足力 11

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `cocoa_steamed_cake` · 可可蒸蛋糕 | `signature_display` | 3 | `B` |
| `coffee_muffin` · 咖啡玛芬 | `signature_display` | 3 | `B` |

### exact-014 · 2 个配方

- 角色：`space`；标签：`spatial`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 3；复制上限 2；库存 4；周期 4000 ms；满足力 8

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `egg_rice_flour_custard` · 蛋香米粉羹 | `spatial_combo` | 1 | `A` |
| `white_sugar_rice_porridge` · 白糖米粥 | `spatial_combo` | 1 | `A` |

### exact-015 · 2 个配方

- 角色：`flavor`；标签：`soft, tea`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 4；复制上限 2；库存 4；周期 4000 ms；满足力 10

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `goat_milk_black_tea_jelly` · 羊奶红茶冻 | `tea_bittersweet` | 3 | `C` |
| `green_tea_panna_cotta` · 绿茶奶冻 | `tea_bittersweet` | 3 | `C` |

### exact-016 · 2 个配方

- 角色：`pairing`；标签：`drink, fruit, refreshing`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 4；复制上限 2；库存 4；周期 2000 ms；满足力 9

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `honey_yogurt` · 蜂蜜酸奶杯 | `fruit_set` | 3 | `C` |
| `orange_crepe` · 橙香可丽饼 | `fruit_set` | 3 | `C` |

### exact-017 · 2 个配方

- 角色：`pairing`；标签：`drink, refreshing, rich`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 4；复制上限 2；库存 4；周期 2000 ms；满足力 9

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `matcha_pudding` · 抹茶布丁 | `fruit_set` | 3 | `D` |
| `mint_cocoa_cup` · 薄荷可可杯 | `fruit_set` | 3 | `D` |

### exact-018 · 2 个配方

- 角色：`sustain`；标签：`hearty, savory`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 4；复制上限 2；库存 4；周期 2000 ms；满足力 9

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `mutton_glutinous_shumai` · 羊肉糯米烧卖 | `savory_hearty` | 3 | `D` |
| `sea_salt_duck_rice_cup` · 海盐鸭肉米盏 | `savory_hearty` | 3 | `C` |

### exact-019 · 2 个配方

- 角色：`space`；标签：`spatial`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 4；复制上限 2；库存 4；周期 2000 ms；满足力 9

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `pumpkin_pudding` · 南瓜布丁 | `spatial_combo` | 3 | `C` |
| `redbean_pancake` · 红豆煎饼 | `spatial_combo` | 3 | `C` |

### exact-020 · 2 个配方

- 角色：`space`；标签：`spatial`
- 形状：`(0,0) (0,1)`；可旋转：`true`
- 成本 3；复制上限 2；库存 4；周期 2000 ms；满足力 7

| 配方 | 分支 | 层级 | 批次 |
| --- | --- | ---: | --- |
| `rice_flour_steamed_cake` · 米粉蒸糕 | `spatial_combo` | 1 | `A` |
| `soft_steamed_egg_cake` · 软蒸鸡蛋糕 | `spatial_combo` | 1 | `A` |

## 高优先级近似重复配对

展示 322 个命中项中的前 40 个。

| 分数 | 左侧 | 右侧 | 同形状 | 同角色 | 同标签 |
| ---: | --- | --- | :---: | :---: | :---: |
| 99.33 | `butter_beef_baked_rice` | `chestnut_mutton_baked_rice` | 是 | 是 | 是 |
| 99.29 | `black_tea_nut_brownie` | `black_tea_pound_cake` | 是 | 是 | 是 |
| 99.29 | `chestnut_pound_cake` | `nuts_cocoa_brownie` | 是 | 是 | 是 |
| 99.29 | `coffee_pound_cake` | `nuts_cocoa_brownie` | 是 | 是 | 是 |
| 99.09 | `apple_steamed_rice_cake` | `duck_egg_banana_griddle_cake` | 是 | 是 | 是 |
| 99.09 | `black_tea_rice_steamed_cake` | `green_tea_rice_drink` | 是 | 是 | 是 |
| 99.09 | `lemon_honey_black_tea` | `mint_iced_green_tea` | 是 | 是 | 是 |
| 99.00 | `chicken_rice_flour_cake` | `pumpkin_duck_pancake` | 是 | 是 | 是 |
| 99.00 | `mutton_glutinous_shumai` | `steamed_meat_rice_cup` | 是 | 是 | 是 |
| 99.00 | `sea_salt_duck_rice_cup` | `steamed_meat_rice_cup` | 是 | 是 | 是 |
| 98.75 | `butter_chicken_steamed_cake` | `chicken_cream_soup` | 是 | 是 | 是 |
| 98.75 | `butter_chicken_steamed_cake` | `sea_salt_caramel_pudding` | 是 | 是 | 是 |
| 98.75 | `honey_lemon_drink` | `rice_milk_drink` | 是 | 是 | 是 |
| 98.75 | `honey_redbean_steamed_cake` | `rice_flour_steamed_cake` | 是 | 是 | 是 |
| 98.75 | `honey_redbean_steamed_cake` | `soft_steamed_egg_cake` | 是 | 是 | 是 |
| 98.75 | `red_bean_glutinous_rice_ball` | `sugar_roasted_chestnut` | 是 | 是 | 是 |
| 96.59 | `chestnut_mousse` | `chocolate_mousse` | 是 | 是 | 是 |
| 96.59 | `chocolate_mousse` | `matcha_redbean_mousse` | 是 | 是 | 是 |
| 96.59 | `lemon_madeleine` | `mint_chocolate_pudding` | 是 | 是 | 是 |
| 96.50 | `banana_milk_drink` | `cocoa_panna_cotta` | 是 | 是 | 是 |
| 96.39 | `black_sesame_roll` | `milk_rice_dew` | 是 | 是 | 是 |
| 96.39 | `caramel_pudding_steamed` | `pumpkin_steamed_cake` | 是 | 是 | 是 |
| 96.39 | `caramel_pudding_steamed` | `red_bean_milk_drink` | 是 | 是 | 是 |
| 96.39 | `caramel_pudding_steamed` | `red_bean_rice_cake` | 是 | 是 | 是 |
| 96.39 | `honey_peach_jelly` | `honey_yogurt` | 是 | 是 | 是 |
| 96.39 | `honey_peach_jelly` | `orange_crepe` | 是 | 是 | 是 |
| 96.39 | `honey_redbean_steamed_cake` | `pumpkin_pudding` | 是 | 是 | 是 |
| 96.39 | `honey_redbean_steamed_cake` | `redbean_pancake` | 是 | 是 | 是 |
| 96.39 | `mango_milk_drink` | `mango_yogurt_cup` | 是 | 是 | 是 |
| 95.28 | `chicken_steamed_dumpling` | `mutton_glutinous_shumai` | 是 | 是 | 是 |
| 95.28 | `chicken_steamed_dumpling` | `sea_salt_duck_rice_cup` | 是 | 是 | 是 |
| 95.28 | `chicken_wheat_porridge` | `mutton_glutinous_shumai` | 是 | 是 | 是 |
| 95.28 | `chicken_wheat_porridge` | `sea_salt_duck_rice_cup` | 是 | 是 | 是 |
| 95.28 | `pumpkin_pudding` | `rice_flour_steamed_cake` | 是 | 是 | 是 |
| 95.28 | `pumpkin_pudding` | `soft_steamed_egg_cake` | 是 | 是 | 是 |
| 95.28 | `redbean_pancake` | `rice_flour_steamed_cake` | 是 | 是 | 是 |
| 95.28 | `redbean_pancake` | `soft_steamed_egg_cake` | 是 | 是 | 是 |
| 95.00 | `banana_rice_pudding` | `peach_mousse` | 是 | 是 | 是 |
| 95.00 | `berry_rice_drink` | `berry_yogurt_ice` | 是 | 是 | 是 |
| 95.00 | `berry_rice_flour_cake` | `berry_yogurt_ice` | 是 | 是 | 是 |

## 保守全面支配关系

| 支配方 | 被支配方 | 严格优势 |
| --- | --- | --- |
| `berry_rice_drink` | `apple_steamed_rice_cake` | `tag_superset` |
| `berry_rice_flour_cake` | `apple_steamed_rice_cake` | `tag_superset` |
| `community_parfait` | `banana_pancake` | `higher_satisfaction, tag_superset` |
| `honey_yogurt` | `banana_pancake` | `tag_superset` |
| `mango_cream_cup` | `banana_pancake` | `tag_superset` |
| `orange_crepe` | `banana_pancake` | `tag_superset` |
| `berry_rice_drink` | `berry_yogurt_ice` | `faster_cycle` |
| `berry_rice_flour_cake` | `berry_yogurt_ice` | `faster_cycle` |
| `black_tea_nut_brownie` | `black_tea_pound_cake` | `higher_satisfaction` |
| `honey_orange_black_tea` | `black_tea_rice_steamed_cake` | `tag_superset` |
| `lemon_honey_black_tea` | `black_tea_rice_steamed_cake` | `tag_superset` |
| `chicken_cream_soup` | `butter_chicken_steamed_cake` | `higher_satisfaction` |
| `sea_salt_caramel_pudding` | `butter_chicken_steamed_cake` | `higher_satisfaction` |
| `mango_milk_drink` | `caramel_pudding_steamed` | `tag_superset` |
| `milk_rice_dew` | `caramel_pudding_steamed` | `tag_superset` |
| `butter_beef_baked_rice` | `chestnut_mutton_baked_rice` | `higher_satisfaction` |
| `nuts_cocoa_brownie` | `chestnut_pound_cake` | `higher_satisfaction` |
| `steamed_meat_rice_cup` | `chicken_rice_flour_cake` | `tag_superset` |
| `nuts_cocoa_brownie` | `coffee_pound_cake` | `higher_satisfaction` |
| `apple_steamed_rice_cake` | `duck_egg_banana_griddle_cake` | `higher_satisfaction` |
| `berry_rice_drink` | `duck_egg_banana_griddle_cake` | `higher_satisfaction, tag_superset` |
| `berry_rice_flour_cake` | `duck_egg_banana_griddle_cake` | `higher_satisfaction, tag_superset` |
| `community_parfait` | `duck_egg_banana_griddle_cake` | `faster_cycle, tag_superset` |
| `black_sesame_oats_soup` | `duck_egg_pumpkin_pudding` | `tag_superset` |
| `black_sesame_soup` | `duck_egg_pumpkin_pudding` | `tag_superset` |
| `honey_redbean_steamed_cake` | `egg_rice_flour_custard` | `faster_cycle` |
| `black_tea_rice_steamed_cake` | `green_tea_rice_drink` | `higher_satisfaction` |
| `goat_milk_black_tea_jelly` | `green_tea_rice_drink` | `tag_superset` |
| `green_tea_panna_cotta` | `green_tea_rice_drink` | `tag_superset` |
| `honey_orange_black_tea` | `green_tea_rice_drink` | `higher_satisfaction, tag_superset` |
| `lemon_honey_black_tea` | `green_tea_rice_drink` | `higher_satisfaction, tag_superset` |
| `matcha_goat_milk_mousse` | `green_tea_rice_drink` | `tag_superset` |
| `mint_iced_green_tea` | `green_tea_rice_drink` | `tag_superset` |
| `black_tea_caramel_mousse` | `green_tea_steamed_cake` | `tag_superset` |
| `black_tea_mousse` | `green_tea_steamed_cake` | `tag_superset` |
| `nut_black_tea_crisp` | `green_tea_steamed_cake` | `tag_superset` |
| `oats_black_tea_cake` | `green_tea_steamed_cake` | `tag_superset` |
| `honey_peach_jelly` | `honey_lemon_drink` | `tag_superset` |
| `peach_jelly` | `honey_lemon_jelly` | `tag_superset` |
| `community_parfait` | `honey_yogurt` | `higher_satisfaction, tag_superset` |
| `berry_rice_drink` | `lemon_yogurt_muffin` | `faster_cycle, tag_superset` |
| `berry_rice_flour_cake` | `lemon_yogurt_muffin` | `faster_cycle, tag_superset` |
| `berry_yogurt_ice` | `lemon_yogurt_muffin` | `tag_superset` |
| `mint_chocolate_pudding` | `lemon_yogurt_muffin` | `tag_superset` |
| `blueberry_mousse` | `milk_pudding` | `higher_stock, higher_satisfaction, tag_superset` |
| `strawberry_mousse` | `milk_pudding` | `higher_stock, higher_satisfaction, tag_superset` |
| `lemon_honey_black_tea` | `mint_iced_green_tea` | `higher_satisfaction` |
| `steamed_meat_rice_cup` | `mutton_glutinous_shumai` | `higher_satisfaction` |
| `community_parfait` | `orange_crepe` | `higher_satisfaction, tag_superset` |
| `chicken_rice_flour_cake` | `pumpkin_duck_pancake` | `higher_satisfaction` |
| `mutton_glutinous_shumai` | `pumpkin_duck_pancake` | `tag_superset` |
| `sea_salt_duck_rice_cup` | `pumpkin_duck_pancake` | `tag_superset` |
| `steamed_meat_rice_cup` | `pumpkin_duck_pancake` | `higher_satisfaction, tag_superset` |
| `black_sesame_roll` | `pumpkin_steamed_cake` | `tag_superset` |
| `goat_milk_oats_porridge` | `pumpkin_steamed_cake` | `tag_superset` |
| `mango_yogurt_cup` | `pumpkin_steamed_cake` | `tag_superset` |
| `matcha_mochi` | `red_bean_glutinous_rice_ball` | `tag_superset` |
| `sugar_roasted_chestnut` | `red_bean_glutinous_rice_ball` | `higher_satisfaction` |
| `black_sesame_roll` | `red_bean_milk_drink` | `tag_superset` |
| `goat_milk_oats_porridge` | `red_bean_milk_drink` | `tag_superset` |
| `mango_yogurt_cup` | `red_bean_milk_drink` | `tag_superset` |
| `black_sesame_roll` | `red_bean_rice_cake` | `tag_superset` |
| `goat_milk_oats_porridge` | `red_bean_rice_cake` | `tag_superset` |
| `mango_yogurt_cup` | `red_bean_rice_cake` | `tag_superset` |
| `honey_redbean_steamed_cake` | `rice_flour_steamed_cake` | `higher_satisfaction` |
| `honey_lemon_drink` | `rice_milk_drink` | `higher_satisfaction` |
| `honey_peach_jelly` | `rice_milk_drink` | `higher_satisfaction, tag_superset` |
| `steamed_meat_rice_cup` | `sea_salt_duck_rice_cup` | `higher_satisfaction` |
| `honey_redbean_steamed_cake` | `soft_steamed_egg_cake` | `higher_satisfaction` |
| `chocolate_mousse` | `vanilla_panna_cotta` | `tag_superset` |
| `peach_mousse` | `vanilla_panna_cotta` | `tag_superset` |
| `honey_redbean_steamed_cake` | `white_sugar_rice_porridge` | `faster_cycle` |

## 已确认试点验收

- 验收状态：`pass`
- 试点配方：12
- 全局完全重复碰撞：0
- 试点内部近似重复配对：0
- 涉及试点的全面支配关系：0
- 与非试点配方的近似配对：14（保留为后续人工复核线索）

### 相较审计基线

| 指标 | 调整前 | 调整后 | 变化 |
| --- | ---: | ---: | ---: |
| 完全重复簇 | 24 | 20 | -4 |
| 重复簇涉及配方 | 53 | 41 | -12 |
| 近似重复配对 | 387 | 322 | -65 |
| 全面支配关系 | 86 | 72 | -14 |

| 配方 | 差异化定位 | 核心取舍 |
| --- | --- | --- |
| `coffee_mousse` · 咖啡慕斯 | 冷藏柔滑续航 | 增加备货并放慢周期，以 soft 覆盖换取持续经营能力。 |
| `hot_cocoa_drink` · 热可可饮 | 紧凑热饮快销 | 压缩为单格并提高复制能力，但降低单次满足力。 |
| `matcha_redbean` · 抹茶红豆杯 | 定向套装爆发 | 固定朝向且减少库存，换取 set 覆盖和更高单次满足力。 |
| `sea_salt_cream_coffee` · 海盐奶盖咖啡 | 异形招牌重击 | 改为三格 L 形、单份上阵和较高成本，换取高单次满足力。 |
| `black_tea_latte` · 醇香红茶拿铁 | 单格奶茶快销 | 紧凑多复制，但单次满足力较低。 |
| `black_tea_panna` · 红茶奶冻 | 定向奶冻高单次 | 固定朝向、低库存和长周期，换取较高单次满足力。 |
| `green_tea_latte` · 清润绿茶拿铁 | 清润多标签覆盖 | 保持常规两格效率，以更多需求标签换取较低满足力。 |
| `mint_lemon_drink` · 薄荷柠檬饮 | 单格清爽快攻 | 用 fast 标签、单格和短周期抢早期窗口，但满足力偏低。 |
| `mint_rice_drink` · 薄荷米浆饮 | 固定朝向长线饮品 | 固定两格且满足力较低，换取较大的持续库存。 |
| `mint_yogurt_cup` · 薄荷酸奶杯 | 异形复合覆盖 | 三格 L 形、单份上阵和长周期，换取四标签与高单次满足力。 |
| `banana_rice_pudding` · 香蕉米布丁 | 水果软糯小批次 | 加入 fruit 覆盖并减少库存，以较高满足力服务复合需求。 |
| `rich_rice_drink` · 醇香米浆 | 低成本单格米饮 | 降低成本并压缩为单格，以较低满足力换取灵活补位。 |

## 下一批试点提案

- 状态：`proposal_only_no_balance_changes`
- 选择规则：保持完全重复簇完整，不拆开配方簇，并尽量填满 12 个试点上限。
- 选中簇：exact-001, exact-002, exact-003, exact-004, exact-005
- 候选配方：11

| # | 配方 | 名称 | 分支 | 层级 | 完全重复簇 |
| ---: | --- | --- | --- | ---: | --- |
| 1 | `pumpkin_steamed_cake` | 南瓜蒸糕 | `milk_soft` | 3 | `exact-001` |
| 2 | `red_bean_milk_drink` | 红豆牛奶饮 | `milk_soft` | 3 | `exact-001` |
| 3 | `red_bean_rice_cake` | 红豆沙米糕 | `milk_soft` | 3 | `exact-001` |
| 4 | `berry_rice_drink` | 莓果米浆饮 | `fruit_set` | 4 | `exact-002` |
| 5 | `berry_rice_flour_cake` | 莓果米粉蒸糕 | `fruit_set` | 4 | `exact-002` |
| 6 | `black_sesame_crisp_cake` | 黑芝麻酥饼 | `crisp_bake` | 3 | `exact-003` |
| 7 | `matcha_cookie` | 抹茶曲奇 | `crisp_bake` | 3 | `exact-003` |
| 8 | `black_sesame_oats_soup` | 黑芝麻燕麦糊 | `signature_display` | 3 | `exact-004` |
| 9 | `black_sesame_soup` | 黑芝麻糊 | `signature_display` | 3 | `exact-004` |
| 10 | `black_tea_caramel_mousse` | 红茶焦糖慕斯 | `tea_bittersweet` | 4 | `exact-005` |
| 11 | `black_tea_mousse` | 红茶慕斯杯 | `tea_bittersweet` | 4 | `exact-005` |

## 证据边界

- 相似度是确定性的分诊分数，不能据此断言两个配方的真人体感完全相同。
- 全面支配规则刻意保守，不比较标准形状或旋转语义不同的配方。
- 研究时机、Boss 需求、强化可用性和玩家偏好仍需路线模拟与真人试玩验证。
