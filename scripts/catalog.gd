extends RefCounted

const INGREDIENTS := {
	# ===== 种子类 =====
	"rice_seed":              {"id": "rice_seed", "name": "水稻种子", "type": "种子", "price": 1, "unlock_level": 0, "source": "采购", "tags": ["农作"], "purchase_category": "农作", "mystery_name": "神秘的农作种子", "harvest_item_id": "rice", "production_duration_seconds": 2},
	"wheat_seed":             {"id": "wheat_seed", "name": "小麦种子", "type": "种子", "price": 1, "unlock_level": 1, "source": "采购", "tags": ["农作"], "purchase_category": "农作", "mystery_name": "神秘的农作种子", "harvest_item_id": "wheat", "production_duration_seconds": 20},
	"red_bean_seed":          {"id": "red_bean_seed", "name": "红豆种子", "type": "种子", "price": 2, "unlock_level": 3, "source": "采购", "tags": ["农作"], "purchase_category": "农作", "mystery_name": "神秘的农作种子", "harvest_item_id": "red_bean", "production_duration_seconds": 28},
	"black_sesame_seed":      {"id": "black_sesame_seed", "name": "黑芝麻种子", "type": "种子", "price": 2, "unlock_level": 3, "source": "采购", "tags": ["农作"], "purchase_category": "农作", "mystery_name": "神秘的农作种子", "harvest_item_id": "black_sesame", "production_duration_seconds": 28},
	"pumpkin_seed":           {"id": "pumpkin_seed", "name": "南瓜种子", "type": "种子", "price": 2, "unlock_level": 4, "source": "采购", "tags": ["农作"], "purchase_category": "农作", "mystery_name": "神秘的农作种子", "harvest_item_id": "pumpkin", "production_duration_seconds": 28},
	"glutinous_rice_seed":    {"id": "glutinous_rice_seed", "name": "糯米种子", "type": "种子", "price": 2, "unlock_level": 4, "source": "采购", "tags": ["农作"], "purchase_category": "农作", "mystery_name": "神秘的农作种子", "harvest_item_id": "glutinous_rice", "production_duration_seconds": 28},
	"chestnut_seed":          {"id": "chestnut_seed", "name": "栗子种子", "type": "种子", "price": 3, "unlock_level": 5, "source": "采购", "tags": ["农作"], "purchase_category": "农作", "mystery_name": "神秘的农作种子", "harvest_item_id": "chestnut", "production_duration_seconds": 30},
	"oats_seed":              {"id": "oats_seed", "name": "燕麦种子", "type": "种子", "price": 2, "unlock_level": 5, "source": "采购", "tags": ["农作"], "purchase_category": "农作", "mystery_name": "神秘的农作种子", "harvest_item_id": "oats", "production_duration_seconds": 30},
	"strawberry_seed":        {"id": "strawberry_seed", "name": "草莓种子", "type": "种子", "price": 2, "unlock_level": 2, "source": "采购", "tags": ["果香", "清爽"], "purchase_category": "水果", "mystery_name": "神秘的红色水果种子", "harvest_item_id": "strawberry", "production_duration_seconds": 20},
	"blueberry_seed":         {"id": "blueberry_seed", "name": "蓝莓种子", "type": "种子", "price": 3, "unlock_level": 2, "source": "采购", "tags": ["果香", "清爽"], "purchase_category": "水果", "mystery_name": "神秘的蓝色水果种子", "harvest_item_id": "blueberry", "production_duration_seconds": 22},
	"banana_seed":            {"id": "banana_seed", "name": "香蕉种子", "type": "种子", "price": 2, "unlock_level": 2, "source": "采购", "tags": ["甜", "果香"], "purchase_category": "水果", "mystery_name": "神秘的黄色水果种子", "harvest_item_id": "banana", "production_duration_seconds": 18},
	"apple_seed":             {"id": "apple_seed", "name": "苹果种子", "type": "种子", "price": 2, "unlock_level": 3, "source": "采购", "tags": ["果香"], "purchase_category": "水果", "mystery_name": "神秘的红色水果种子", "harvest_item_id": "apple", "production_duration_seconds": 24},
	"lemon_seed":             {"id": "lemon_seed", "name": "柠檬种子", "type": "种子", "price": 2, "unlock_level": 3, "source": "采购", "tags": ["清爽"], "purchase_category": "水果", "mystery_name": "神秘的酸香水果种子", "harvest_item_id": "lemon", "production_duration_seconds": 16},
	"peach_seed":             {"id": "peach_seed", "name": "桃子种子", "type": "种子", "price": 3, "unlock_level": 3, "source": "采购", "tags": ["果香", "清爽"], "purchase_category": "水果", "mystery_name": "神秘的粉色水果种子", "harvest_item_id": "peach", "production_duration_seconds": 24},
	"orange_seed":            {"id": "orange_seed", "name": "橙子种子", "type": "种子", "price": 2, "unlock_level": 3, "source": "采购", "tags": ["果香", "清爽"], "purchase_category": "水果", "mystery_name": "神秘的橙色水果种子", "harvest_item_id": "orange", "production_duration_seconds": 22},
	"mango_seed":             {"id": "mango_seed", "name": "芒果种子", "type": "种子", "price": 3, "unlock_level": 3, "source": "采购", "tags": ["果香", "甜"], "purchase_category": "水果", "mystery_name": "神秘的热带水果种子", "harvest_item_id": "mango", "production_duration_seconds": 26},

	# ===== 农场自产原料（仅种植收获，不可直接采购）=====
	"rice":                   {"id": "rice", "name": "大米", "type": "农作", "price": 0, "unlock_level": 0, "source": "农场", "tags": ["朴素", "主食"], "purchase_category": "农作", "mystery_name": "神秘的谷物", "purchasable": false},
	"wheat":                  {"id": "wheat", "name": "小麦", "type": "农作", "price": 0, "unlock_level": 1, "source": "农场", "tags": ["经典", "主食"], "purchase_category": "农作", "mystery_name": "神秘的谷物", "purchasable": false},
	"red_bean":               {"id": "red_bean", "name": "红豆", "type": "农作", "price": 0, "unlock_level": 3, "source": "农场", "tags": ["甜", "经典"], "purchase_category": "农作", "mystery_name": "神秘的红色农作", "purchasable": false, "production_duration_seconds": 28},
	"black_sesame":           {"id": "black_sesame", "name": "黑芝麻", "type": "农作", "price": 0, "unlock_level": 3, "source": "农场", "tags": ["香气", "经典"], "purchase_category": "农作", "mystery_name": "神秘的黑色农作", "purchasable": false},
	"pumpkin":                {"id": "pumpkin", "name": "南瓜", "type": "蔬果", "price": 0, "unlock_level": 4, "source": "农场", "tags": ["甜", "经典"], "purchase_category": "农作", "mystery_name": "神秘的黄色蔬果", "purchasable": false},
	"glutinous_rice":         {"id": "glutinous_rice", "name": "糯米", "type": "农作", "price": 0, "unlock_level": 4, "source": "农场", "tags": ["软糯", "经典"], "purchase_category": "农作", "mystery_name": "神秘的糯性谷物", "purchasable": false},
	"chestnut":               {"id": "chestnut", "name": "栗子", "type": "农作", "price": 0, "unlock_level": 5, "source": "农场", "tags": ["甜", "浓郁"], "purchase_category": "农作", "mystery_name": "神秘的带壳农作", "purchasable": false},
	"oats":                   {"id": "oats", "name": "燕麦", "type": "农作", "price": 0, "unlock_level": 5, "source": "农场", "tags": ["低负担", "香脆"], "purchase_category": "农作", "mystery_name": "神秘的粗粮谷物", "purchasable": false},

	# ===== 养殖场幼畜（商店采购，养殖后收获）=====
	"chick":                  {"id": "chick", "name": "小鸡仔", "type": "幼畜", "price": 6, "unlock_level": 1, "source": "采购", "tags": ["经典", "咸香"], "purchase_category": "畜牧", "mystery_name": "神秘的幼禽", "harvest_outputs": {"egg": 2, "chicken": 1}, "production_duration_seconds": 12},
	"calf":                   {"id": "calf", "name": "小牛犊", "type": "幼畜", "price": 8, "unlock_level": 2, "source": "采购", "tags": ["清爽", "浓郁"], "purchase_category": "畜牧", "mystery_name": "神秘的幼畜", "harvest_outputs": {"milk": 2, "beef": 1}, "production_duration_seconds": 20},
	"bee_colony":             {"id": "bee_colony", "name": "蜜蜂群", "type": "幼畜", "price": 10, "unlock_level": 3, "source": "采购", "tags": ["甜", "香气"], "purchase_category": "畜牧", "mystery_name": "神秘的蜂群", "harvest_outputs": {"honey": 2}, "production_duration_seconds": 24},
	"duckling":               {"id": "duckling", "name": "小鸭苗", "type": "幼畜", "price": 12, "unlock_level": 4, "source": "采购", "tags": ["经典", "咸香"], "purchase_category": "畜牧", "mystery_name": "神秘的水禽幼苗", "harvest_outputs": {"duck_egg": 2, "duck_meat": 1}, "production_duration_seconds": 28},
	"lamb":                   {"id": "lamb", "name": "小羊羔", "type": "幼畜", "price": 14, "unlock_level": 5, "source": "采购", "tags": ["浓郁", "咸香"], "purchase_category": "畜牧", "mystery_name": "神秘的绵羊幼崽", "harvest_outputs": {"goat_milk": 2, "mutton": 1}, "production_duration_seconds": 32},

	# ===== 养殖场自产原料（仅养殖收获，不可直接采购）=====
	"egg":                    {"id": "egg", "name": "鸡蛋", "type": "基底", "price": 5, "unlock_level": 1, "source": "养殖场", "tags": ["经典"], "purchase_category": "畜牧", "mystery_name": "神秘的养殖场食材", "purchasable": false},
	"milk":                   {"id": "milk", "name": "牛奶", "type": "乳制", "price": 5, "unlock_level": 2, "source": "养殖场", "tags": ["清爽"], "purchase_category": "畜牧", "mystery_name": "神秘的白色饮品", "purchasable": false},
	"chicken":                {"id": "chicken", "name": "鸡肉", "type": "肉禽", "price": 10, "unlock_level": 1, "source": "养殖场", "tags": ["咸香", "清爽"], "purchase_category": "畜牧", "mystery_name": "神秘的白肉食材", "purchasable": false},
	"beef":                   {"id": "beef", "name": "牛肉", "type": "肉禽", "price": 12, "unlock_level": 2, "source": "养殖场", "tags": ["咸香", "浓郁"], "purchase_category": "畜牧", "mystery_name": "神秘的红肉食材", "purchasable": false},
	"duck_egg":               {"id": "duck_egg", "name": "鸭蛋", "type": "基底", "price": 6, "unlock_level": 4, "source": "养殖场", "tags": ["经典", "浓郁"], "purchase_category": "畜牧", "mystery_name": "神秘的水禽蛋", "purchasable": false},
	"duck_meat":              {"id": "duck_meat", "name": "鸭肉", "type": "肉禽", "price": 13, "unlock_level": 4, "source": "养殖场", "tags": ["咸香", "浓郁"], "purchase_category": "畜牧", "mystery_name": "神秘的深色禽肉", "purchasable": false},
	"goat_milk":              {"id": "goat_milk", "name": "羊奶", "type": "乳制", "price": 7, "unlock_level": 5, "source": "养殖场", "tags": ["奶香", "浓郁"], "purchase_category": "畜牧", "mystery_name": "神秘的醇厚乳品", "purchasable": false},
	"mutton":                 {"id": "mutton", "name": "羊肉", "type": "肉禽", "price": 15, "unlock_level": 5, "source": "养殖场", "tags": ["咸香", "浓郁"], "purchase_category": "畜牧", "mystery_name": "神秘的浓香红肉", "purchasable": false},

	# ===== 乳制辅料 =====
	"butter":                 {"id": "butter", "name": "黄油", "type": "乳制", "price": 6, "unlock_level": 1, "source": "采购", "tags": ["浓郁"], "purchase_category": "畜牧", "mystery_name": "神秘的金色乳制品"},
	"cream":                  {"id": "cream", "name": "奶油", "type": "乳制", "price": 8, "unlock_level": 2, "source": "采购", "tags": ["浓郁"], "purchase_category": "畜牧", "mystery_name": "神秘的白色乳制品"},
	"cheese":                 {"id": "cheese", "name": "芝士", "type": "乳制", "price": 11, "unlock_level": 2, "source": "采购", "tags": ["浓郁"], "purchase_category": "畜牧", "mystery_name": "神秘的浓郁乳制品"},
	"yogurt":                 {"id": "yogurt", "name": "酸奶", "type": "乳制", "price": 9, "unlock_level": 4, "source": "发酵加工", "tags": ["清爽"], "purchase_category": "畜牧", "mystery_name": "神秘的清爽乳制品", "purchasable": false},

	# ===== 林场自产原料（种子种植后获得，不可直接采购）=====
	"strawberry":             {"id": "strawberry", "name": "草莓", "type": "水果", "price": 8, "unlock_level": 2, "source": "林场", "tags": ["果香", "清爽"], "purchase_category": "水果", "mystery_name": "神秘的红色水果", "purchasable": false, "production_duration_seconds": 20},
	"blueberry":              {"id": "blueberry", "name": "蓝莓", "type": "水果", "price": 9, "unlock_level": 2, "source": "林场", "tags": ["果香", "清爽"], "purchase_category": "水果", "mystery_name": "神秘的蓝色水果", "purchasable": false, "production_duration_seconds": 22},
	"banana":                 {"id": "banana", "name": "香蕉", "type": "水果", "price": 7, "unlock_level": 2, "source": "林场", "tags": ["甜", "果香"], "purchase_category": "水果", "mystery_name": "神秘的黄色水果", "purchasable": false, "production_duration_seconds": 18},
	"apple":                  {"id": "apple", "name": "苹果", "type": "水果", "price": 7, "unlock_level": 3, "source": "林场", "tags": ["果香"], "purchase_category": "水果", "mystery_name": "神秘的红色水果", "purchasable": false, "production_duration_seconds": 24},
	"lemon":                  {"id": "lemon", "name": "柠檬", "type": "水果", "price": 7, "unlock_level": 3, "source": "林场", "tags": ["清爽"], "purchase_category": "水果", "mystery_name": "神秘的酸香水果", "purchasable": false, "production_duration_seconds": 16},
	"peach":                  {"id": "peach", "name": "桃子", "type": "水果", "price": 9, "unlock_level": 3, "source": "林场", "tags": ["果香", "清爽"], "purchase_category": "水果", "mystery_name": "神秘的粉色水果", "purchasable": false, "production_duration_seconds": 24},
	"orange":                 {"id": "orange", "name": "橙子", "type": "水果", "price": 8, "unlock_level": 3, "source": "林场", "tags": ["果香", "清爽"], "purchase_category": "水果", "mystery_name": "神秘的橙色水果", "purchasable": false, "production_duration_seconds": 22},
	"mango":                  {"id": "mango", "name": "芒果", "type": "水果", "price": 10, "unlock_level": 3, "source": "林场", "tags": ["果香", "甜"], "purchase_category": "水果", "mystery_name": "神秘的热带水果", "purchasable": false, "production_duration_seconds": 26},
	"honey":                  {"id": "honey", "name": "蜂蜜", "type": "调味", "price": 8, "unlock_level": 3, "source": "养殖场", "tags": ["甜"], "purchase_category": "畜牧", "mystery_name": "神秘的金色蜜露", "purchasable": false},
	"nuts":                   {"id": "nuts", "name": "坚果", "type": "配料", "price": 9, "unlock_level": 5, "source": "林场", "tags": ["香脆"], "purchase_category": "农作", "mystery_name": "神秘的香脆农作", "purchasable": false, "production_duration_seconds": 30},
	"mint":                   {"id": "mint", "name": "薄荷", "type": "草本", "price": 8, "unlock_level": 4, "source": "林场", "tags": ["清爽", "香气"], "purchase_category": "农作", "mystery_name": "神秘的清凉草本", "purchasable": false, "production_duration_seconds": 18},
	"cinnamon":               {"id": "cinnamon", "name": "肉桂", "type": "香料", "price": 8, "unlock_level": 5, "source": "林场", "tags": ["香气", "经典"], "purchase_category": "配料", "mystery_name": "神秘的辛香香料", "purchasable": false, "production_duration_seconds": 30},

	# ===== 水塘/鱼塘投入与产物 =====
	"spring_water_starter":   {"id": "spring_water_starter", "name": "泉水引", "type": "水引", "price": 1, "unlock_level": 1, "source": "采购", "tags": ["清爽"], "purchase_category": "水塘", "mystery_name": "神秘的清澈水引", "harvest_item_id": "spring_water", "production_duration_seconds": 10, "consumes_stock_for_production": true},
	"spring_water":           {"id": "spring_water", "name": "泉水", "type": "水塘", "price": 1, "unlock_level": 0, "source": "水塘", "tags": ["清爽"], "purchase_category": "水塘", "mystery_name": "神秘的清澈水源", "purchasable": false},
	"sea_salt":               {"id": "sea_salt", "name": "海盐", "type": "调味", "price": 6, "unlock_level": 3, "source": "采购", "tags": ["清爽", "咸香"], "purchase_category": "配料", "mystery_name": "神秘的海边调味"},

	# ===== 商店直购辅料（初始即可采购）=====
	"sugar":                  {"id": "sugar", "name": "白糖", "type": "调味", "price": 3, "unlock_level": 1, "source": "采购", "tags": ["甜"], "purchase_category": "配料", "mystery_name": "神秘的甜味调料"},
	"chocolate":              {"id": "chocolate", "name": "巧克力", "type": "风味", "price": 9, "unlock_level": 2, "source": "采购", "tags": ["苦甜", "浓郁"], "purchase_category": "配料", "mystery_name": "神秘的苦甜配料"},
	"vanilla":                {"id": "vanilla", "name": "香草", "type": "风味", "price": 10, "unlock_level": 2, "source": "采购", "tags": ["香气", "经典"], "purchase_category": "配料", "mystery_name": "神秘的香气配料"},
	"caramel":                {"id": "caramel", "name": "焦糖", "type": "调味", "price": 9, "unlock_level": 2, "source": "采购", "tags": ["甜", "苦甜"], "purchase_category": "配料", "mystery_name": "神秘的焦香调料"},
	"gelatin":                {"id": "gelatin", "name": "吉利丁", "type": "凝固", "price": 7, "unlock_level": 3, "source": "采购", "tags": ["清爽"], "purchase_category": "配料", "mystery_name": "神秘的凝固配料"},
	"yeast":                  {"id": "yeast", "name": "酵母", "type": "发酵", "price": 5, "unlock_level": 4, "source": "采购", "tags": ["经典"], "purchase_category": "配料", "mystery_name": "神秘的发酵辅料"},
	"matcha":                 {"id": "matcha", "name": "抹茶", "type": "风味", "price": 10, "unlock_level": 5, "source": "研磨加工", "tags": ["苦甜", "清爽"], "purchase_category": "配料", "mystery_name": "神秘的绿色风味", "purchasable": false},
	"coffee":                 {"id": "coffee", "name": "咖啡", "type": "风味", "price": 10, "unlock_level": 4, "source": "林场", "tags": ["苦甜"], "purchase_category": "配料", "mystery_name": "神秘的深色风味", "purchasable": false, "production_duration_seconds": 28},
	"cocoa":                  {"id": "cocoa", "name": "可可粉", "type": "风味", "price": 10, "unlock_level": 4, "source": "研磨加工", "tags": ["苦甜"], "purchase_category": "配料", "mystery_name": "神秘的可可风味", "purchasable": false},
	"almond":                 {"id": "almond", "name": "杏仁", "type": "配料", "price": 10, "unlock_level": 5, "source": "采购", "tags": ["香脆", "香气"], "purchase_category": "配料", "mystery_name": "神秘的坚果配料"},
	"black_tea":              {"id": "black_tea", "name": "红茶", "type": "风味", "price": 10, "unlock_level": 5, "source": "林场", "tags": ["香气", "苦甜"], "purchase_category": "配料", "mystery_name": "神秘的红色茶汤", "purchasable": false, "production_duration_seconds": 30},
	"green_tea":              {"id": "green_tea", "name": "绿茶", "type": "风味", "price": 10, "unlock_level": 5, "source": "林场", "tags": ["清爽", "香气"], "purchase_category": "配料", "mystery_name": "神秘的绿色茶汤", "purchasable": false, "production_duration_seconds": 30},

	# ===== 研磨加工品（首次研磨后开放采购）=====
	"rice_flour":             {"id": "rice_flour", "name": "大米粉", "type": "基底", "price": 5, "unlock_level": 1, "source": "研磨加工", "tags": ["经典"], "purchase_category": "配料", "mystery_name": "神秘的米制基底", "purchasable": false},
	"flour":                  {"id": "flour", "name": "面粉", "type": "基底", "price": 4, "unlock_level": 1, "source": "研磨加工", "tags": ["经典"], "purchase_category": "配料", "mystery_name": "神秘的白色基底", "purchasable": false},
	"glutinous_rice_flour":   {"id": "glutinous_rice_flour", "name": "糯米粉", "type": "基底", "price": 7, "unlock_level": 4, "source": "研磨加工", "tags": ["经典", "软糯"], "purchase_category": "配料", "mystery_name": "神秘的糯性基底", "purchasable": false}
}

const PURCHASE_CATEGORIES := ["农作", "配料", "水果", "畜牧", "水塘", "工具"]

const PRODUCTION_SITES := {
	"farm": {"id": "farm", "name": "农场", "unlock_level": 0, "enabled": true, "base_slots": 8, "cycles": 2, "yield_amount": 3, "cost_rate": 0.3, "items": ["rice_seed", "wheat_seed", "red_bean_seed", "black_sesame_seed", "pumpkin_seed", "glutinous_rice_seed", "chestnut_seed", "oats_seed", "red_bean", "nuts"]},
	"ranch": {"id": "ranch", "name": "养殖场", "unlock_level": 1, "enabled": true, "base_slots": 8, "cycles": 2, "yield_amount": 4, "cost_rate": 0.4, "items": ["chick", "calf", "bee_colony", "duckling", "lamb"]},
	"forest": {"id": "forest", "name": "林场", "unlock_level": 2, "enabled": true, "base_slots": 8, "cycles": 2, "yield_amount": 3, "cost_rate": 0.4, "items": ["strawberry_seed", "blueberry_seed", "banana_seed", "apple_seed", "lemon_seed", "peach_seed", "orange_seed", "mango_seed", "nuts", "mint", "cinnamon", "coffee", "black_tea", "green_tea", "red_bean"]},
	"pond": {"id": "pond", "name": "水塘", "unlock_level": 1, "enabled": true, "base_slots": 8, "cycles": 3, "yield_amount": 2, "cost_rate": 0.4, "items": ["spring_water_starter"]}
}

const PRODUCTION_SLOT_UNLOCK_COSTS := [50, 100, 150, 250, 400, 600, 800]
const PRODUCTION_BAG_PAGE_UNLOCK_COSTS := [100, 200, 400, 800]
const RECIPE_DISPLAY_CONFIG_PATH := "res://doc/recipe_display_config.json"
const DISPLAY_RULES_PATH := "res://doc/display_rules_full.json"
const SHOWCASE_ROUND_RULES_PATH := "res://doc/showcase_round_rules.json"
static var _json_dictionary_cache := {}

const TOOLS := {
	"farm_accelerator": {"id": "farm_accelerator", "name": "农场加速器", "purchase_category": "工具", "price": 30, "compatible_site": "farm", "duration_multiplier": 0.75, "unlock_level": 1, "tool_kind": "accelerator"},
	"ranch_accelerator": {"id": "ranch_accelerator", "name": "养殖场加速器", "purchase_category": "工具", "price": 45, "compatible_site": "ranch", "duration_multiplier": 0.75, "unlock_level": 2, "tool_kind": "accelerator"},
	"pond_accelerator": {"id": "pond_accelerator", "name": "水塘加速器", "purchase_category": "工具", "price": 60, "compatible_site": "pond", "duration_multiplier": 0.75, "unlock_level": 3, "tool_kind": "accelerator"}
}

const DEVICES := {
	"round_pot": {"id": "round_pot", "name": "蒸煮一体的圆锅", "unlock_level": 999, "usage": "蒸煮米、水和温热甜品", "research_meaning": "蒸煮", "recipe_growth_enabled": true},
	"grinder": {"id": "grinder", "name": "研磨机", "unlock_level": 1, "usage": "研磨谷物、坚果和风味粉", "research_meaning": "研磨", "recipe_growth_enabled": false},
	"oven": {"id": "oven", "name": "烤箱", "unlock_level": 2, "usage": "蛋糕、曲奇、塔、烘焙类", "research_meaning": "烘烤", "recipe_growth_enabled": true},
	"chiller": {"id": "chiller", "name": "冷藏柜", "unlock_level": 3, "usage": "布丁、慕斯、冷藏定型甜品", "research_meaning": "冷藏", "recipe_growth_enabled": true},
	"griddle": {"id": "griddle", "name": "煎烤盘", "unlock_level": 4, "usage": "松饼、煎饼、轻烤甜品", "research_meaning": "煎烤", "recipe_growth_enabled": true},
	"mixer": {"id": "mixer", "name": "搅拌机", "unlock_level": 5, "usage": "牛乳杯、奶油类、杯装甜品", "research_meaning": "混合、打发", "recipe_growth_enabled": true}
}

const RECIPES := {
	# ===== Lv.0 新手配方 =====
	"rice_milk_drink":              {"id": "rice_milk_drink", "name": "米浆饮", "device": "round_pot", "materials": ["rice", "spring_water" ], "production_duration_seconds": 2, "price": 12, "output_count": 3, "unlock_level": 0, "tags": ["经典", "清爽"]},
	
	# ===== Lv.1 圆锅与研磨线 =====
	"rice_flour_steamed_cake":      {"id": "rice_flour_steamed_cake", "name": "米粉蒸糕", "device": "round_pot", "materials": ["rice_flour", "sugar", "egg"], "production_duration_seconds": 2, "price": 16, "output_count": 3, "unlock_level": 1, "tags": ["经典", "甜"]},
	"sponge_cake":                  {"id": "sponge_cake", "name": "海绵杯蛋糕", "device": "oven", "materials": ["flour", "egg", "sugar"], "production_duration_seconds": 2, "price": 18, "output_count": 3, "unlock_level": 2, "tags": ["经典", "甜"]},
	"butter_cookie":                {"id": "butter_cookie", "name": "黄油曲奇", "device": "oven", "materials": ["flour", "butter", "sugar"], "production_duration_seconds": 2, "price": 16, "output_count": 4, "unlock_level": 2, "tags": ["经典", "香脆"]},
	"rich_rice_drink":              {"id": "rich_rice_drink", "name": "醇香米浆", "device": "round_pot", "materials": ["rice", "milk", "spring_water", "sugar"], "production_duration_seconds": 4, "price": 16, "output_count": 3, "unlock_level": 2, "tags": ["奶香", "甜"]},
	"milk_rice_dew":                {"id": "milk_rice_dew", "name": "牛奶米露", "device": "round_pot", "materials": ["rice", "milk", "sugar"], "production_duration_seconds": 2, "price": 18, "output_count": 3, "unlock_level": 2, "tags": ["浓郁", "奶香"]},
	"egg_milk_custard":             {"id": "egg_milk_custard", "name": "蛋奶甜羹", "device": "round_pot", "materials": ["egg", "milk", "sugar"], "production_duration_seconds": 2, "price": 17, "output_count": 2, "unlock_level": 2, "tags": ["奶香", "甜"]},
	"caramel_pudding_steamed":      {"id": "caramel_pudding_steamed", "name": "焦糖布丁", "device": "oven", "materials": ["egg", "milk", "sugar"], "production_duration_seconds": 2, "price": 20, "output_count": 2, "unlock_level": 2, "tags": ["奶香", "甜"]},
	"baked_rice_cake":              {"id": "baked_rice_cake", "name": "烤米香饼", "device": "oven", "materials": ["rice_flour", "egg", "sugar"], "production_duration_seconds": 2, "price": 15, "output_count": 4, "unlock_level": 2, "tags": ["香脆", "经典"]},
	"milk_crisp_cake":              {"id": "milk_crisp_cake", "name": "牛奶酥饼", "device": "oven", "materials": ["flour", "butter", "milk", "sugar"], "production_duration_seconds": 4, "price": 18, "output_count": 4, "unlock_level": 2, "tags": ["奶香", "香脆"]},
	"soft_steamed_egg_cake":        {"id": "soft_steamed_egg_cake", "name": "软蒸鸡蛋糕", "device": "round_pot", "materials": ["egg", "flour", "sugar"], "production_duration_seconds": 2, "price": 16, "output_count": 3, "unlock_level": 1, "tags": ["经典", "甜"]},
	"white_sugar_rice_ball":        {"id": "white_sugar_rice_ball", "name": "白糖米圆子", "device": "round_pot", "materials": ["rice_flour", "sugar", "spring_water"], "production_duration_seconds": 2, "price": 12, "output_count": 5, "unlock_level": 1, "tags": ["软糯", "甜"]},
	"chicken_steamed_dumpling":     {"id": "chicken_steamed_dumpling", "name": "鸡肉蒸饺", "device": "round_pot", "materials": ["flour", "chicken", "spring_water"], "production_duration_seconds": 2, "price": 22, "output_count": 4, "unlock_level": 1, "tags": ["咸香", "饱腹"]},
	"beef_baked_pie":               {"id": "beef_baked_pie", "name": "牛肉烤馅饼", "device": "oven", "materials": ["flour", "beef", "spring_water"], "production_duration_seconds": 2, "price": 26, "output_count": 3, "unlock_level": 2, "tags": ["香脆", "咸香"]},
	"chicken_rice_flour_cake":      {"id": "chicken_rice_flour_cake", "name": "鸡肉米粉糕", "device": "round_pot", "materials": ["rice_flour", "chicken", "spring_water"], "production_duration_seconds": 2, "price": 20, "output_count": 3, "unlock_level": 6, "tags": ["咸香", "经典"]},
	"butter_beef_baked_rice":       {"id": "butter_beef_baked_rice", "name": "黄油牛肉烤饭", "device": "oven", "materials": ["rice", "butter", "beef", "spring_water"], "production_duration_seconds": 4, "price": 28, "output_count": 2, "unlock_level": 6, "tags": ["咸香", "饱腹"]},
	"steamed_meat_rice_cup":        {"id": "steamed_meat_rice_cup", "name": "蒸肉米盏", "device": "round_pot", "materials": ["rice_flour", "chicken", "egg"], "production_duration_seconds": 2, "price": 24, "output_count": 3, "unlock_level": 6, "tags": ["咸香", "饱腹"]},
	"white_sugar_rice_porridge":    {"id": "white_sugar_rice_porridge", "name": "白糖米粥", "device": "round_pot", "materials": ["rice", "rice_flour", "spring_water", "sugar"], "production_duration_seconds": 4, "price": 14, "output_count": 3, "unlock_level": 1, "tags": ["甜", "经典"]},

	# ===== Lv.2 烤箱与基础风味线 =====
	"milk_pudding":                 {"id": "milk_pudding", "name": "牛奶布丁", "device": "chiller", "materials": ["milk", "egg", "sugar"], "production_duration_seconds": 2, "price": 20, "output_count": 3, "unlock_level": 3, "tags": ["清爽", "经典"]},
	"cream_shortcake":              {"id": "cream_shortcake", "name": "鲜奶油小蛋糕", "device": "mixer", "materials": ["sponge_cake", "cream", "strawberry"], "production_duration_seconds": 8, "price": 28, "output_count": 2, "unlock_level": 5, "tags": ["果香", "浓郁"]},
	"chocolate_cookie":             {"id": "chocolate_cookie", "name": "巧克力曲奇", "device": "oven", "materials": ["flour", "butter", "chocolate"], "production_duration_seconds": 2, "price": 24, "output_count": 4, "unlock_level": 2, "tags": ["苦甜", "香脆"]},
	"blueberry_mousse":             {"id": "blueberry_mousse", "name": "蓝莓慕斯杯", "device": "chiller", "materials": ["blueberry", "cream", "sugar"], "production_duration_seconds": 2, "price": 26, "output_count": 3, "unlock_level": 3, "tags": ["果香", "清爽"]},
	"vanilla_scone":                {"id": "vanilla_scone", "name": "香草司康", "device": "oven", "materials": ["flour", "butter", "vanilla"], "production_duration_seconds": 2, "price": 24, "output_count": 3, "unlock_level": 2, "tags": ["经典", "香脆"]},
	"strawberry_jelly":             {"id": "strawberry_jelly", "name": "草莓果冻杯", "device": "chiller", "materials": ["strawberry", "sugar", "gelatin"], "production_duration_seconds": 2, "price": 27, "output_count": 3, "unlock_level": 3, "tags": ["果香", "清爽"]},
	"banana_pound_cake":            {"id": "banana_pound_cake", "name": "香蕉磅蛋糕", "device": "oven", "materials": ["flour", "butter", "egg", "sugar", "banana"], "production_duration_seconds": 8, "price": 30, "output_count": 2, "unlock_level": 2, "tags": ["浓郁", "奶香"]},
	"strawberry_mousse":            {"id": "strawberry_mousse", "name": "草莓慕斯杯", "device": "chiller", "materials": ["strawberry", "cream", "milk", "gelatin", "sugar"], "production_duration_seconds": 8, "price": 28, "output_count": 3, "unlock_level": 3, "tags": ["清爽", "果香"]},
	"blueberry_jelly":              {"id": "blueberry_jelly", "name": "蓝莓果冻", "device": "chiller", "materials": ["blueberry", "gelatin", "sugar", "spring_water"], "production_duration_seconds": 4, "price": 25, "output_count": 3, "unlock_level": 3, "tags": ["果香", "清爽"]},
	"chocolate_lava_cake":          {"id": "chocolate_lava_cake", "name": "巧克力熔岩蛋糕", "device": "oven", "materials": ["flour", "chocolate", "butter", "egg", "sugar"], "production_duration_seconds": 8, "price": 32, "output_count": 2, "unlock_level": 6, "tags": ["奶香", "浓郁"]},
	"vanilla_cream_puff":           {"id": "vanilla_cream_puff", "name": "香草奶油泡芙", "device": "oven", "materials": ["flour", "butter", "egg", "cream", "vanilla", "sugar"], "production_duration_seconds": 8, "price": 28, "output_count": 3, "unlock_level": 6, "tags": ["香脆", "奶香"]},
	"banana_rice_pudding":          {"id": "banana_rice_pudding", "name": "香蕉米布丁", "device": "chiller", "materials": ["rice", "milk", "banana", "sugar"], "production_duration_seconds": 4, "price": 24, "output_count": 3, "unlock_level": 3, "tags": ["软糯", "奶香"]},
	"strawberry_cream_cake":        {"id": "strawberry_cream_cake", "name": "草莓奶油蛋糕", "device": "oven", "materials": ["flour", "egg", "sugar", "cream", "strawberry"], "production_duration_seconds": 8, "price": 36, "output_count": 1, "unlock_level": 2, "tags": ["果香", "奶香"]},
	"blueberry_muffin":             {"id": "blueberry_muffin", "name": "蓝莓麦芬", "device": "oven", "materials": ["flour", "butter", "egg", "milk", "blueberry", "sugar"], "production_duration_seconds": 8, "price": 22, "output_count": 3, "unlock_level": 2, "tags": ["果香", "经典"]},
	"caramel_mousse":               {"id": "caramel_mousse", "name": "焦糖慕斯", "device": "chiller", "materials": ["caramel", "cream", "milk", "gelatin", "sugar"], "production_duration_seconds": 8, "price": 29, "output_count": 3, "unlock_level": 3, "tags": ["甜", "浓郁"]},
	"berry_rice_drink":             {"id": "berry_rice_drink", "name": "莓果米浆饮", "device": "round_pot", "materials": ["rice", "spring_water", "blueberry", "sugar"], "production_duration_seconds": 4, "price": 20, "output_count": 3, "unlock_level": 6, "tags": ["果香", "清爽"]},
	"vanilla_panna_cotta":          {"id": "vanilla_panna_cotta", "name": "香草奶冻", "device": "chiller", "materials": ["milk", "cream", "gelatin", "vanilla", "sugar"], "production_duration_seconds": 8, "price": 26, "output_count": 3, "unlock_level": 3, "tags": ["奶香", "经典"]},
	"banana_baked_pancake":         {"id": "banana_baked_pancake", "name": "香蕉烤松饼", "device": "oven", "materials": ["flour", "egg", "milk", "banana", "sugar"], "production_duration_seconds": 8, "price": 25, "output_count": 3, "unlock_level": 4, "tags": ["经典", "甜"]},
	"chocolate_mousse":             {"id": "chocolate_mousse", "name": "巧克力慕斯杯", "device": "chiller", "materials": ["chocolate", "cream", "milk", "gelatin", "sugar"], "production_duration_seconds": 8, "price": 30, "output_count": 3, "unlock_level": 3, "tags": ["浓郁", "奶香"]},
	"berry_rice_flour_cake":        {"id": "berry_rice_flour_cake", "name": "莓果米粉蒸糕", "device": "round_pot", "materials": ["rice_flour", "sugar", "egg", "strawberry"], "production_duration_seconds": 4, "price": 20, "output_count": 3, "unlock_level": 6, "tags": ["果香", "清爽"]},
	"caramel_brulee":               {"id": "caramel_brulee", "name": "焦糖烤布蕾", "device": "oven", "materials": ["egg", "milk", "cream", "caramel", "sugar"], "production_duration_seconds": 8, "price": 32, "output_count": 2, "unlock_level": 6, "tags": ["甜", "奶香"]},
	"banana_milk_drink":            {"id": "banana_milk_drink", "name": "香蕉牛奶饮", "device": "round_pot", "materials": ["milk", "banana", "sugar", "spring_water"], "production_duration_seconds": 4, "price": 19, "output_count": 3, "unlock_level": 2, "tags": ["浓郁", "奶香"]},
	"blueberry_cream_tart":         {"id": "blueberry_cream_tart", "name": "蓝莓奶油塔", "device": "oven", "materials": ["flour", "butter", "cream", "blueberry", "sugar"], "production_duration_seconds": 8, "price": 30, "output_count": 2, "unlock_level": 6, "tags": ["香脆", "果香"]},
	"chicken_cream_soup":           {"id": "chicken_cream_soup", "name": "鸡肉奶油浓汤", "device": "round_pot", "materials": ["chicken", "cream", "milk"], "production_duration_seconds": 2, "price": 28, "output_count": 2, "unlock_level": 2, "tags": ["浓郁", "咸香"]},

	# ===== Lv.3 冷藏与多元风味线 =====
	"banana_pancake":               {"id": "banana_pancake", "name": "香蕉松饼", "device": "griddle", "materials": ["flour", "milk", "banana"], "production_duration_seconds": 2, "price": 25, "output_count": 3, "unlock_level": 4, "tags": ["甜", "果香"]},
	"orange_crepe":                 {"id": "orange_crepe", "name": "橙香可丽饼", "device": "griddle", "materials": ["flour", "milk", "orange"], "production_duration_seconds": 2, "price": 26, "output_count": 3, "unlock_level": 4, "tags": ["果香", "清爽"]},
	"lemon_tart":                   {"id": "lemon_tart", "name": "柠檬小塔", "device": "oven", "materials": ["flour", "butter", "lemon"], "production_duration_seconds": 2, "price": 27, "output_count": 2, "unlock_level": 3, "tags": ["清爽", "经典"]},
	"peach_jelly":                  {"id": "peach_jelly", "name": "桃子果冻杯", "device": "chiller", "materials": ["peach", "sugar", "gelatin"], "production_duration_seconds": 2, "price": 27, "output_count": 3, "unlock_level": 3, "tags": ["果香", "清爽"]},
	"matcha_pudding":               {"id": "matcha_pudding", "name": "抹茶布丁", "device": "chiller", "materials": ["milk", "egg", "matcha"], "production_duration_seconds": 2, "price": 29, "output_count": 3, "unlock_level": 5, "tags": ["苦甜", "清爽"]},
	"coffee_mousse":                {"id": "coffee_mousse", "name": "咖啡慕斯", "device": "chiller", "materials": ["coffee", "cream", "sugar"], "production_duration_seconds": 2, "price": 30, "output_count": 3, "unlock_level": 4, "tags": ["苦甜", "浓郁"]},
	"redbean_pancake":              {"id": "redbean_pancake", "name": "红豆煎饼", "device": "griddle", "materials": ["flour", "red_bean", "milk"], "production_duration_seconds": 2, "price": 28, "output_count": 3, "unlock_level": 4, "tags": ["甜", "经典"]},
	"cheesecake":                   {"id": "cheesecake", "name": "芝士蛋糕", "device": "oven", "materials": ["cheese", "egg", "sugar"], "production_duration_seconds": 2, "price": 34, "output_count": 2, "unlock_level": 2, "tags": ["浓郁", "经典"]},
	"sea_salt_caramel_pudding":     {"id": "sea_salt_caramel_pudding", "name": "海盐焦糖布丁", "device": "chiller", "materials": ["sea_salt", "caramel", "milk"], "production_duration_seconds": 2, "price": 32, "output_count": 3, "unlock_level": 3, "tags": ["苦甜", "咸香"]},
	"matcha_mochi":                 {"id": "matcha_mochi", "name": "抹茶糯米团", "device": "mixer", "materials": ["glutinous_rice_flour", "matcha", "red_bean"], "production_duration_seconds": 2, "price": 31, "output_count": 3, "unlock_level": 5, "tags": ["苦甜", "软糯"]},
	"black_sesame_roll":            {"id": "black_sesame_roll", "name": "黑芝麻糯米卷", "device": "mixer", "materials": ["glutinous_rice_flour", "black_sesame", "sugar"], "production_duration_seconds": 2, "price": 30, "output_count": 3, "unlock_level": 5, "tags": ["浓郁", "软糯"]},
	"mango_cream_cup":              {"id": "mango_cream_cup", "name": "芒果奶油杯", "device": "mixer", "materials": ["mango", "cream", "sugar"], "production_duration_seconds": 2, "price": 33, "output_count": 3, "unlock_level": 5, "tags": ["果香", "浓郁"]},
	"apple_pie":                    {"id": "apple_pie", "name": "苹果派", "device": "oven", "materials": ["flour", "butter", "apple", "sugar"], "production_duration_seconds": 4, "price": 32, "output_count": 2, "unlock_level": 3, "tags": ["果香", "香脆"]},
	"lemon_madeleine":              {"id": "lemon_madeleine", "name": "柠檬玛德琳", "device": "oven", "materials": ["flour", "butter", "egg", "lemon", "sugar"], "production_duration_seconds": 8, "price": 28, "output_count": 3, "unlock_level": 3, "tags": ["清爽", "浓郁"]},
	"orange_chiffon_cake":          {"id": "orange_chiffon_cake", "name": "橙香戚风蛋糕", "device": "oven", "materials": ["flour", "egg", "orange", "sugar"], "production_duration_seconds": 4, "price": 30, "output_count": 2, "unlock_level": 3, "tags": ["经典", "果香"]},
	"peach_mousse":                 {"id": "peach_mousse", "name": "蜜桃慕斯杯", "device": "chiller", "materials": ["peach", "cream", "gelatin", "milk", "sugar"], "production_duration_seconds": 8, "price": 31, "output_count": 3, "unlock_level": 3, "tags": ["奶香", "果香"]},
	"matcha_cookie":                {"id": "matcha_cookie", "name": "抹茶曲奇", "device": "oven", "materials": ["flour", "butter", "matcha", "sugar"], "production_duration_seconds": 4, "price": 26, "output_count": 4, "unlock_level": 5, "tags": ["苦甜", "香脆"]},
	"matcha_redbean_mousse":        {"id": "matcha_redbean_mousse", "name": "抹茶红豆慕斯", "device": "chiller", "materials": ["matcha", "red_bean", "cream", "gelatin", "milk", "sugar"], "production_duration_seconds": 8, "price": 33, "output_count": 3, "unlock_level": 5, "tags": ["苦甜", "奶香"]},
	"coffee_pound_cake":            {"id": "coffee_pound_cake", "name": "咖啡磅蛋糕", "device": "oven", "materials": ["flour", "butter", "egg", "coffee", "sugar"], "production_duration_seconds": 8, "price": 32, "output_count": 2, "unlock_level": 4, "tags": ["浓郁", "苦甜"]},
	"red_bean_rice_cake":           {"id": "red_bean_rice_cake", "name": "红豆沙米糕", "device": "round_pot", "materials": ["rice_flour", "red_bean", "sugar"], "production_duration_seconds": 2, "price": 22, "output_count": 3, "unlock_level": 4, "tags": ["软糯", "经典"]},
	"red_bean_milk_drink":          {"id": "red_bean_milk_drink", "name": "红豆牛奶饮", "device": "round_pot", "materials": ["red_bean", "milk", "sugar"], "production_duration_seconds": 2, "price": 21, "output_count": 3, "unlock_level": 4, "tags": ["奶香", "经典"]},
	"mango_glutinous_rice_cake":    {"id": "mango_glutinous_rice_cake", "name": "芒果糯米糍", "device": "mixer", "materials": ["glutinous_rice_flour", "mango", "cream", "sugar"], "production_duration_seconds": 4, "price": 32, "output_count": 3, "unlock_level": 5, "tags": ["软糯", "果香"]},
	"black_sesame_soup":            {"id": "black_sesame_soup", "name": "黑芝麻糊", "device": "round_pot", "materials": ["rice", "black_sesame", "sugar", "spring_water"], "production_duration_seconds": 4, "price": 20, "output_count": 3, "unlock_level": 4, "tags": ["浓郁", "低负担"]},
	"black_sesame_crisp_cake":      {"id": "black_sesame_crisp_cake", "name": "黑芝麻酥饼", "device": "oven", "materials": ["flour", "butter", "black_sesame", "sugar"], "production_duration_seconds": 4, "price": 24, "output_count": 4, "unlock_level": 4, "tags": ["香脆", "浓郁"]},
	"pumpkin_pie":                  {"id": "pumpkin_pie", "name": "南瓜派", "device": "oven", "materials": ["flour", "butter", "pumpkin", "egg", "sugar"], "production_duration_seconds": 8, "price": 30, "output_count": 2, "unlock_level": 4, "tags": ["甜", "经典"]},
	"pumpkin_steamed_cake":         {"id": "pumpkin_steamed_cake", "name": "南瓜蒸糕", "device": "round_pot", "materials": ["rice_flour", "pumpkin", "sugar"], "production_duration_seconds": 2, "price": 18, "output_count": 3, "unlock_level": 4, "tags": ["软糯", "甜"]},
	"honey_lemon_drink":            {"id": "honey_lemon_drink", "name": "蜂蜜柠檬饮", "device": "round_pot", "materials": ["lemon", "honey", "spring_water"], "production_duration_seconds": 2, "price": 22, "output_count": 3, "unlock_level": 3, "tags": ["清爽", "甜"]},
	"honey_sponge_cake":            {"id": "honey_sponge_cake", "name": "蜂蜜海绵蛋糕", "device": "oven", "materials": ["flour", "egg", "honey", "sugar"], "production_duration_seconds": 4, "price": 24, "output_count": 3, "unlock_level": 3, "tags": ["甜", "经典"]},
	"sea_salt_chocolate_cookie":    {"id": "sea_salt_chocolate_cookie", "name": "海盐巧克力曲奇", "device": "oven", "materials": ["flour", "butter", "chocolate", "sea_salt", "sugar"], "production_duration_seconds": 8, "price": 28, "output_count": 4, "unlock_level": 4, "tags": ["咸香", "苦甜"]},
	"cheese_chicken_baked_rice":    {"id": "cheese_chicken_baked_rice", "name": "芝士鸡肉焗饭", "device": "oven", "materials": ["rice", "chicken", "cheese", "butter", "spring_water"], "production_duration_seconds": 8, "price": 36, "output_count": 2, "unlock_level": 6, "tags": ["咸香", "奶香"]},
	"beef_cheese_pie":              {"id": "beef_cheese_pie", "name": "牛肉芝士派", "device": "oven", "materials": ["flour", "butter", "beef", "cheese"], "production_duration_seconds": 4, "price": 38, "output_count": 2, "unlock_level": 6, "tags": ["咸香", "香脆"]},
	"pumpkin_rice_drink":           {"id": "pumpkin_rice_drink", "name": "南瓜米浆饮", "device": "round_pot", "materials": ["rice", "pumpkin", "spring_water", "sugar"], "production_duration_seconds": 4, "price": 18, "output_count": 3, "unlock_level": 4, "tags": ["浓郁", "饱腹"]},
	"mango_milk_drink":             {"id": "mango_milk_drink", "name": "芒果牛奶饮", "device": "round_pot", "materials": ["mango", "milk", "sugar"], "production_duration_seconds": 2, "price": 24, "output_count": 3, "unlock_level": 3, "tags": ["果香", "奶香"]},
	"red_bean_glutinous_rice_ball": {"id": "red_bean_glutinous_rice_ball", "name": "红豆糯米团", "device": "round_pot", "materials": ["glutinous_rice_flour", "red_bean", "sugar"], "production_duration_seconds": 2, "price": 26, "output_count": 3, "unlock_level": 4, "tags": ["软糯", "甜"]},
	"cheese_baked_pumpkin":         {"id": "cheese_baked_pumpkin", "name": "芝士焗南瓜", "device": "oven", "materials": ["pumpkin", "cheese", "sugar"], "production_duration_seconds": 2, "price": 28, "output_count": 2, "unlock_level": 4, "tags": ["浓郁", "咸香"]},
	"coffee_muffin":                {"id": "coffee_muffin", "name": "咖啡玛芬", "device": "oven", "materials": ["flour", "milk", "egg", "coffee", "sugar"], "production_duration_seconds": 8, "price": 24, "output_count": 3, "unlock_level": 4, "tags": ["苦甜", "经典"]},
	"apple_steamed_rice_cake":      {"id": "apple_steamed_rice_cake", "name": "苹果蒸米糕", "device": "round_pot", "materials": ["rice_flour", "apple", "egg", "sugar"], "production_duration_seconds": 4, "price": 22, "output_count": 3, "unlock_level": 6, "tags": ["经典", "果香"]},

	# ===== Lv.4 高阶细分线 =====
	"honey_yogurt":                 {"id": "honey_yogurt", "name": "蜂蜜酸奶杯", "device": "mixer", "materials": ["yogurt", "honey", "blueberry"], "production_duration_seconds": 2, "price": 32, "output_count": 3, "unlock_level": 5, "tags": ["清爽", "果香"]},
	"apple_crumble":                {"id": "apple_crumble", "name": "苹果坚果酥", "device": "oven", "materials": ["apple", "nuts", "butter"], "production_duration_seconds": 2, "price": 36, "output_count": 2, "unlock_level": 6, "tags": ["果香", "香脆"]},
	"cocoa_brownie":                {"id": "cocoa_brownie", "name": "可可布朗尼", "device": "oven", "materials": ["cocoa", "chocolate", "butter"], "production_duration_seconds": 2, "price": 38, "output_count": 2, "unlock_level": 4, "tags": ["苦甜", "浓郁"]},
	"matcha_redbean":               {"id": "matcha_redbean", "name": "抹茶红豆杯", "device": "mixer", "materials": ["matcha", "red_bean", "cream"], "production_duration_seconds": 2, "price": 36, "output_count": 2, "unlock_level": 5, "tags": ["苦甜", "甜"]},
	"mint_cocoa_cup":               {"id": "mint_cocoa_cup", "name": "薄荷可可杯", "device": "mixer", "materials": ["mint", "cocoa", "milk"], "production_duration_seconds": 2, "price": 34, "output_count": 3, "unlock_level": 5, "tags": ["清凉", "苦甜"]},
	"almond_chocolate_tart":        {"id": "almond_chocolate_tart", "name": "巧克力杏仁塔", "device": "oven", "materials": ["almond", "chocolate", "flour"], "production_duration_seconds": 2, "price": 40, "output_count": 2, "unlock_level": 5, "tags": ["苦甜", "香脆"]},
	"pumpkin_pudding":              {"id": "pumpkin_pudding", "name": "南瓜布丁", "device": "chiller", "materials": ["pumpkin", "egg", "milk"], "production_duration_seconds": 2, "price": 31, "output_count": 3, "unlock_level": 4, "tags": ["甜", "经典"]},
	"oats_yogurt_bowl":             {"id": "oats_yogurt_bowl", "name": "燕麦酸奶碗", "device": "mixer", "materials": ["oats", "yogurt", "honey"], "production_duration_seconds": 2, "price": 33, "output_count": 3, "unlock_level": 5, "tags": ["清爽", "低负担"]},
	"honey_lemon_jelly":            {"id": "honey_lemon_jelly", "name": "蜂蜜柠檬冻", "device": "chiller", "materials": ["honey", "lemon", "gelatin"], "production_duration_seconds": 2, "price": 34, "output_count": 3, "unlock_level": 3, "tags": ["清爽", "甜"]},
	"sea_salt_cream_coffee":        {"id": "sea_salt_cream_coffee", "name": "海盐奶盖咖啡", "device": "mixer", "materials": ["sea_salt", "coffee", "cream"], "production_duration_seconds": 2, "price": 37, "output_count": 2, "unlock_level": 5, "tags": ["苦甜", "浓郁"]},
	"chestnut_pound_cake":          {"id": "chestnut_pound_cake", "name": "栗香磅蛋糕", "device": "oven", "materials": ["flour", "butter", "chestnut", "egg", "sugar"], "production_duration_seconds": 8, "price": 35, "output_count": 2, "unlock_level": 5, "tags": ["浓郁", "经典"]},
	"chestnut_mousse":              {"id": "chestnut_mousse", "name": "栗子慕斯杯", "device": "chiller", "materials": ["chestnut", "cream", "gelatin", "milk", "sugar"], "production_duration_seconds": 8, "price": 36, "output_count": 3, "unlock_level": 5, "tags": ["奶香", "浓郁"]},
	"sugar_roasted_chestnut":       {"id": "sugar_roasted_chestnut", "name": "糖烤栗子", "device": "oven", "materials": ["chestnut", "sugar", "spring_water"], "production_duration_seconds": 2, "price": 28, "output_count": 3, "unlock_level": 6, "tags": ["软糯", "甜"]},
	"chestnut_glutinous_rice_cake": {"id": "chestnut_glutinous_rice_cake", "name": "栗子糯米糍", "device": "mixer", "materials": ["glutinous_rice_flour", "chestnut", "sugar", "butter"], "production_duration_seconds": 4, "price": 34, "output_count": 3, "unlock_level": 5, "tags": ["软糯", "浓郁"]},
	"oats_cookie":                  {"id": "oats_cookie", "name": "燕麦曲奇", "device": "oven", "materials": ["flour", "butter", "oats", "egg", "sugar"], "production_duration_seconds": 8, "price": 26, "output_count": 4, "unlock_level": 5, "tags": ["香脆", "低负担"]},
	"oats_baked_pudding":           {"id": "oats_baked_pudding", "name": "燕麦烤布丁", "device": "oven", "materials": ["oats", "egg", "milk", "sugar"], "production_duration_seconds": 4, "price": 28, "output_count": 3, "unlock_level": 5, "tags": ["低负担", "奶香"]},
	"nut_oats_crisp":               {"id": "nut_oats_crisp", "name": "坚果燕麦酥", "device": "oven", "materials": ["oats", "nuts", "butter", "honey", "sugar"], "production_duration_seconds": 8, "price": 32, "output_count": 3, "unlock_level": 5, "tags": ["香脆", "饱腹"]},
	"berry_yogurt_ice":             {"id": "berry_yogurt_ice", "name": "莓果酸奶冰酪", "device": "chiller", "materials": ["yogurt", "strawberry", "blueberry", "gelatin", "sugar"], "production_duration_seconds": 8, "price": 35, "output_count": 3, "unlock_level": 4, "tags": ["清爽", "果香"]},
	"mango_yogurt_cup":             {"id": "mango_yogurt_cup", "name": "芒果酸奶杯", "device": "mixer", "materials": ["yogurt", "mango", "honey"], "production_duration_seconds": 2, "price": 34, "output_count": 3, "unlock_level": 5, "tags": ["果香", "奶香"]},
	"yogurt_cheesecake":            {"id": "yogurt_cheesecake", "name": "酸奶芝士蛋糕", "device": "oven", "materials": ["cheese", "yogurt", "egg", "flour", "sugar"], "production_duration_seconds": 8, "price": 38, "output_count": 2, "unlock_level": 4, "tags": ["清爽", "浓郁"]},
	"lemon_yogurt_muffin":          {"id": "lemon_yogurt_muffin", "name": "柠檬酸奶麦芬", "device": "oven", "materials": ["flour", "yogurt", "lemon", "egg", "sugar"], "production_duration_seconds": 8, "price": 26, "output_count": 3, "unlock_level": 4, "tags": ["清爽", "经典"]},
	"nuts_pound_cake":              {"id": "nuts_pound_cake", "name": "坚果磅蛋糕", "device": "oven", "materials": ["flour", "butter", "nuts", "egg", "sugar"], "production_duration_seconds": 8, "price": 34, "output_count": 2, "unlock_level": 5, "tags": ["浓郁", "饱腹"]},
	"sea_salt_nuts_cookie":         {"id": "sea_salt_nuts_cookie", "name": "海盐坚果曲奇", "device": "oven", "materials": ["flour", "butter", "sea_salt", "nuts", "sugar"], "production_duration_seconds": 8, "price": 30, "output_count": 4, "unlock_level": 6, "tags": ["咸香", "香脆"]},
	"nuts_cocoa_brownie":           {"id": "nuts_cocoa_brownie", "name": "坚果可可布朗尼", "device": "oven", "materials": ["cocoa", "chocolate", "butter", "nuts", "egg", "flour"], "production_duration_seconds": 8, "price": 40, "output_count": 2, "unlock_level": 6, "tags": ["苦甜", "浓郁"]},
	"mint_lemon_drink":             {"id": "mint_lemon_drink", "name": "薄荷柠檬饮", "device": "round_pot", "materials": ["mint", "lemon", "honey", "spring_water"], "production_duration_seconds": 4, "price": 26, "output_count": 3, "unlock_level": 4, "tags": ["清凉", "清爽"]},
	"mint_mousse":                  {"id": "mint_mousse", "name": "薄荷慕斯杯", "device": "chiller", "materials": ["mint", "cream", "gelatin", "milk", "sugar"], "production_duration_seconds": 8, "price": 33, "output_count": 3, "unlock_level": 4, "tags": ["清凉", "奶香"]},
	"mint_chocolate_pudding":       {"id": "mint_chocolate_pudding", "name": "薄荷巧克力布丁", "device": "chiller", "materials": ["mint", "chocolate", "milk", "gelatin", "sugar"], "production_duration_seconds": 8, "price": 32, "output_count": 3, "unlock_level": 4, "tags": ["清凉", "苦甜"]},
	"mint_rice_drink":              {"id": "mint_rice_drink", "name": "薄荷米浆饮", "device": "round_pot", "materials": ["rice", "spring_water", "mint", "sugar"], "production_duration_seconds": 4, "price": 18, "output_count": 3, "unlock_level": 4, "tags": ["清凉", "经典"]},
	"cocoa_steamed_cake":           {"id": "cocoa_steamed_cake", "name": "可可蒸蛋糕", "device": "round_pot", "materials": ["flour", "egg", "cocoa", "milk", "sugar"], "production_duration_seconds": 8, "price": 24, "output_count": 3, "unlock_level": 4, "tags": ["苦甜", "经典"]},
	"cocoa_panna_cotta":            {"id": "cocoa_panna_cotta", "name": "可可奶冻", "device": "chiller", "materials": ["milk", "cocoa", "gelatin", "sugar"], "production_duration_seconds": 4, "price": 28, "output_count": 3, "unlock_level": 4, "tags": ["奶香", "苦甜"]},
	"cocoa_glutinous_rice_cake":    {"id": "cocoa_glutinous_rice_cake", "name": "可可糯米糍", "device": "mixer", "materials": ["glutinous_rice_flour", "cocoa", "red_bean", "sugar"], "production_duration_seconds": 4, "price": 32, "output_count": 3, "unlock_level": 5, "tags": ["软糯", "苦甜"]},
	"hot_cocoa_drink":              {"id": "hot_cocoa_drink", "name": "热可可饮", "device": "round_pot", "materials": ["milk", "cocoa", "sugar"], "production_duration_seconds": 2, "price": 22, "output_count": 3, "unlock_level": 4, "tags": ["苦甜", "浓郁"]},
	"nut_chicken_patty":            {"id": "nut_chicken_patty", "name": "坚果鸡肉饼", "device": "oven", "materials": ["chicken", "nuts", "flour", "egg", "sea_salt"], "production_duration_seconds": 8, "price": 36, "output_count": 2, "unlock_level": 6, "tags": ["咸香", "饱腹"]},
	"chestnut_chicken_baked_rice":  {"id": "chestnut_chicken_baked_rice", "name": "栗子鸡肉焗饭", "device": "oven", "materials": ["rice", "chicken", "chestnut", "butter", "sea_salt"], "production_duration_seconds": 8, "price": 38, "output_count": 2, "unlock_level": 6, "tags": ["咸香", "饱腹"]},
	"beef_nut_pie":                 {"id": "beef_nut_pie", "name": "牛肉坚果派", "device": "oven", "materials": ["flour", "butter", "beef", "nuts", "sea_salt"], "production_duration_seconds": 8, "price": 40, "output_count": 2, "unlock_level": 6, "tags": ["咸香", "香脆"]},
	"oats_milk_porridge":           {"id": "oats_milk_porridge", "name": "燕麦牛奶粥", "device": "round_pot", "materials": ["oats", "milk", "sugar"], "production_duration_seconds": 2, "price": 20, "output_count": 3, "unlock_level": 6, "tags": ["低负担", "饱腹"]},
	"chestnut_redbean_steamed_cake":{"id": "chestnut_redbean_steamed_cake", "name": "栗子红豆蒸糕", "device": "round_pot", "materials": ["rice_flour", "chestnut", "red_bean", "sugar"], "production_duration_seconds": 4, "price": 28, "output_count": 3, "unlock_level": 6, "tags": ["软糯", "甜"]},
	"nut_pumpkin_cake":             {"id": "nut_pumpkin_cake", "name": "坚果南瓜饼", "device": "oven", "materials": ["pumpkin", "glutinous_rice_flour", "nuts", "sugar"], "production_duration_seconds": 4, "price": 26, "output_count": 3, "unlock_level": 6, "tags": ["甜", "香脆"]},
	"mint_yogurt_cup":              {"id": "mint_yogurt_cup", "name": "薄荷酸奶杯", "device": "mixer", "materials": ["yogurt", "mint", "honey", "blueberry"], "production_duration_seconds": 4, "price": 33, "output_count": 3, "unlock_level": 5, "tags": ["清凉", "清爽"]},
	"black_sesame_oats_soup":       {"id": "black_sesame_oats_soup", "name": "黑芝麻燕麦糊", "device": "round_pot", "materials": ["black_sesame", "oats", "milk", "sugar"], "production_duration_seconds": 4, "price": 24, "output_count": 3, "unlock_level": 5, "tags": ["浓郁", "低负担"]},

	# ===== Lv.5 搅拌、招牌与长期经营储备线 =====
	"community_parfait":            {"id": "community_parfait", "name": "邻街招牌芭菲", "device": "chiller", "materials": ["cream", "strawberry", "yogurt"], "production_duration_seconds": 2, "price": 42, "output_count": 2, "unlock_level": 6, "tags": ["果香", "清爽", "招牌"]},
	"mango_cheese_cup":             {"id": "mango_cheese_cup", "name": "芒果芝士杯", "device": "chiller", "materials": ["mango", "cheese", "cream"], "production_duration_seconds": 2, "price": 44, "output_count": 2, "unlock_level": 3, "tags": ["果香", "浓郁", "招牌"]},
	"chestnut_tart":                {"id": "chestnut_tart", "name": "栗子挞", "device": "oven", "materials": ["chestnut", "butter", "cream"], "production_duration_seconds": 2, "price": 43, "output_count": 2, "unlock_level": 5, "tags": ["甜", "浓郁"]},
	"black_tea_panna":              {"id": "black_tea_panna", "name": "红茶奶冻", "device": "chiller", "materials": ["black_tea", "milk", "gelatin"], "production_duration_seconds": 2, "price": 39, "output_count": 3, "unlock_level": 5, "tags": ["茶香", "奶香"]},
	"apple_cinnamon_pie":           {"id": "apple_cinnamon_pie", "name": "苹果肉桂派", "device": "oven", "materials": ["apple", "cinnamon", "flour"], "production_duration_seconds": 2, "price": 41, "output_count": 2, "unlock_level": 5, "tags": ["果香", "经典"]},
	"chocolate_banana_roll":        {"id": "chocolate_banana_roll", "name": "巧克力香蕉卷", "device": "oven", "materials": ["banana", "chocolate", "flour"], "production_duration_seconds": 2, "price": 36, "output_count": 3, "unlock_level": 6, "tags": ["苦甜", "果香"]},
	"black_tea_latte":              {"id": "black_tea_latte", "name": "醇香红茶拿铁", "device": "round_pot", "materials": ["black_tea", "milk", "sugar"], "production_duration_seconds": 2, "price": 28, "output_count": 3, "unlock_level": 5, "tags": ["茶香", "奶香"]},
	"green_tea_latte":              {"id": "green_tea_latte", "name": "清润绿茶拿铁", "device": "round_pot", "materials": ["green_tea", "milk", "sugar"], "production_duration_seconds": 2, "price": 28, "output_count": 3, "unlock_level": 5, "tags": ["茶香", "奶香"]},
	"lemon_honey_black_tea":        {"id": "lemon_honey_black_tea", "name": "柠檬蜂蜜红茶", "device": "round_pot", "materials": ["black_tea", "lemon", "honey", "spring_water"], "production_duration_seconds": 4, "price": 30, "output_count": 3, "unlock_level": 6, "tags": ["茶香", "清爽"]},
	"mint_iced_green_tea":          {"id": "mint_iced_green_tea", "name": "薄荷冰绿茶", "device": "chiller", "materials": ["green_tea", "mint", "honey", "spring_water"], "production_duration_seconds": 4, "price": 30, "output_count": 3, "unlock_level": 5, "tags": ["清凉", "茶香"]},
	"black_tea_butter_cookie":      {"id": "black_tea_butter_cookie", "name": "红茶黄油曲奇", "device": "oven", "materials": ["flour", "butter", "black_tea", "sugar"], "production_duration_seconds": 4, "price": 30, "output_count": 4, "unlock_level": 5, "tags": ["茶香", "香脆"]},
	"black_tea_chiffon_cake":       {"id": "black_tea_chiffon_cake", "name": "红茶戚风蛋糕", "device": "oven", "materials": ["flour", "egg", "black_tea", "sugar"], "production_duration_seconds": 4, "price": 36, "output_count": 2, "unlock_level": 5, "tags": ["经典", "茶香"]},
	"green_tea_panna_cotta":        {"id": "green_tea_panna_cotta", "name": "绿茶奶冻", "device": "chiller", "materials": ["green_tea", "milk", "gelatin", "sugar"], "production_duration_seconds": 4, "price": 36, "output_count": 3, "unlock_level": 5, "tags": ["茶香", "奶香"]},
	"black_tea_mousse":             {"id": "black_tea_mousse", "name": "红茶慕斯杯", "device": "chiller", "materials": ["black_tea", "cream", "gelatin", "milk", "sugar"], "production_duration_seconds": 8, "price": 38, "output_count": 3, "unlock_level": 6, "tags": ["茶香", "浓郁"]},
	"green_tea_redbean_mochi":      {"id": "green_tea_redbean_mochi", "name": "绿茶红豆糯米糍", "device": "mixer", "materials": ["glutinous_rice_flour", "green_tea", "red_bean", "sugar"], "production_duration_seconds": 4, "price": 34, "output_count": 3, "unlock_level": 5, "tags": ["茶香", "软糯"]},
	"black_tea_pound_cake":         {"id": "black_tea_pound_cake", "name": "红茶磅蛋糕", "device": "oven", "materials": ["flour", "butter", "egg", "black_tea", "sugar"], "production_duration_seconds": 8, "price": 36, "output_count": 2, "unlock_level": 5, "tags": ["茶香", "浓郁"]},
	"black_tea_light_cheesecake":   {"id": "black_tea_light_cheesecake", "name": "红茶轻芝士蛋糕", "device": "oven", "materials": ["cheese", "egg", "black_tea", "flour", "sugar"], "production_duration_seconds": 8, "price": 40, "output_count": 2, "unlock_level": 6, "tags": ["咸香", "茶香"]},
	"honey_orange_black_tea":       {"id": "honey_orange_black_tea", "name": "蜜橙红茶饮", "device": "round_pot", "materials": ["black_tea", "orange", "honey", "spring_water"], "production_duration_seconds": 4, "price": 30, "output_count": 3, "unlock_level": 6, "tags": ["果香", "茶香"]},
	"green_tea_lemon_jelly":        {"id": "green_tea_lemon_jelly", "name": "绿茶冻柠杯", "device": "chiller", "materials": ["green_tea", "lemon", "gelatin", "sugar"], "production_duration_seconds": 4, "price": 32, "output_count": 3, "unlock_level": 6, "tags": ["茶香", "清爽"]},
	"black_tea_brulee":             {"id": "black_tea_brulee", "name": "红茶烤布蕾", "device": "oven", "materials": ["black_tea", "milk", "cream", "egg", "sugar"], "production_duration_seconds": 8, "price": 38, "output_count": 2, "unlock_level": 6, "tags": ["茶香", "奶香"]},
	"nut_black_tea_crisp":          {"id": "nut_black_tea_crisp", "name": "坚果红茶酥", "device": "oven", "materials": ["flour", "butter", "nuts", "black_tea", "sugar"], "production_duration_seconds": 8, "price": 34, "output_count": 3, "unlock_level": 6, "tags": ["香脆", "茶香"]},
	"green_tea_yogurt_cup":         {"id": "green_tea_yogurt_cup", "name": "绿茶酸奶杯", "device": "mixer", "materials": ["yogurt", "green_tea", "honey", "blueberry"], "production_duration_seconds": 4, "price": 35, "output_count": 3, "unlock_level": 5, "tags": ["低负担", "清爽"]},
	"black_tea_rice_steamed_cake":  {"id": "black_tea_rice_steamed_cake", "name": "红茶米粉蒸糕", "device": "round_pot", "materials": ["rice_flour", "egg", "black_tea", "sugar"], "production_duration_seconds": 4, "price": 26, "output_count": 3, "unlock_level": 6, "tags": ["经典", "茶香"]},
	"black_tea_cocoa_cookie":       {"id": "black_tea_cocoa_cookie", "name": "红茶可可曲奇", "device": "oven", "materials": ["flour", "butter", "black_tea", "cocoa", "sugar"], "production_duration_seconds": 8, "price": 32, "output_count": 4, "unlock_level": 6, "tags": ["茶香", "香脆"]},
	"green_tea_rice_drink":         {"id": "green_tea_rice_drink", "name": "绿茶米浆饮", "device": "round_pot", "materials": ["rice", "green_tea", "spring_water", "sugar"], "production_duration_seconds": 4, "price": 22, "output_count": 3, "unlock_level": 5, "tags": ["茶香", "经典"]},
	"black_tea_chicken_baked_rice": {"id": "black_tea_chicken_baked_rice", "name": "红茶鸡肉焗饭", "device": "oven", "materials": ["rice", "chicken", "black_tea", "butter", "sea_salt"], "production_duration_seconds": 8, "price": 40, "output_count": 2, "unlock_level": 6, "tags": ["咸香", "茶香"]},
	"oats_black_tea_cake":          {"id": "oats_black_tea_cake", "name": "燕麦红茶饼", "device": "oven", "materials": ["oats", "flour", "butter", "black_tea", "honey"], "production_duration_seconds": 8, "price": 30, "output_count": 3, "unlock_level": 6, "tags": ["茶香", "低负担"]},
	"black_tea_caramel_mousse":     {"id": "black_tea_caramel_mousse", "name": "红茶焦糖慕斯", "device": "chiller", "materials": ["black_tea", "caramel", "cream", "gelatin", "milk"], "production_duration_seconds": 8, "price": 40, "output_count": 3, "unlock_level": 6, "tags": ["茶香", "浓郁"]},
	"green_tea_steamed_cake":       {"id": "green_tea_steamed_cake", "name": "绿茶蒸蛋糕", "device": "round_pot", "materials": ["flour", "egg", "green_tea", "milk", "sugar"], "production_duration_seconds": 8, "price": 26, "output_count": 3, "unlock_level": 6, "tags": ["茶香", "经典"]},
	"black_tea_nut_brownie":        {"id": "black_tea_nut_brownie", "name": "红茶坚果布朗尼", "device": "oven", "materials": ["chocolate", "egg", "butter", "nuts", "black_tea", "flour"], "production_duration_seconds": 8, "price": 42, "output_count": 2, "unlock_level": 6, "tags": ["浓郁", "茶香"]},

	# ===== 养殖扩展配方 =====
	"egg_rice_flour_custard":       {"id": "egg_rice_flour_custard", "name": "蛋香米粉羹", "device": "round_pot", "materials": ["rice_flour", "egg", "spring_water", "sugar"], "production_duration_seconds": 4, "price": 17, "output_count": 3, "unlock_level": 1, "tags": ["经典", "甜"]},
	"butter_chicken_steamed_cake":  {"id": "butter_chicken_steamed_cake", "name": "黄油鸡肉蒸糕", "device": "round_pot", "materials": ["flour", "chicken", "butter"], "production_duration_seconds": 2, "price": 23, "output_count": 3, "unlock_level": 1, "tags": ["咸香", "浓郁"]},
	"chicken_wheat_porridge":       {"id": "chicken_wheat_porridge", "name": "鸡肉麦仁粥", "device": "round_pot", "materials": ["wheat", "chicken", "spring_water"], "production_duration_seconds": 2, "price": 20, "output_count": 3, "unlock_level": 1, "tags": ["咸香", "饱腹"]},
	"honey_peach_jelly":            {"id": "honey_peach_jelly", "name": "蜂蜜桃子冻", "device": "chiller", "materials": ["honey", "peach", "gelatin"], "production_duration_seconds": 2, "price": 28, "output_count": 3, "unlock_level": 3, "tags": ["果香", "清爽"]},
	"honey_redbean_steamed_cake":   {"id": "honey_redbean_steamed_cake", "name": "蜂蜜红豆蒸糕", "device": "round_pot", "materials": ["honey", "red_bean", "rice_flour"], "production_duration_seconds": 2, "price": 24, "output_count": 3, "unlock_level": 3, "tags": ["甜", "经典"]},
	"duck_egg_pumpkin_pudding":     {"id": "duck_egg_pumpkin_pudding", "name": "鸭蛋南瓜布丁", "device": "chiller", "materials": ["duck_egg", "pumpkin", "milk", "sugar"], "production_duration_seconds": 4, "price": 30, "output_count": 3, "unlock_level": 4, "tags": ["经典", "浓郁"]},
	"coffee_duck_egg_cake":         {"id": "coffee_duck_egg_cake", "name": "咖啡鸭蛋糕", "device": "oven", "materials": ["duck_egg", "coffee", "flour", "sugar"], "production_duration_seconds": 4, "price": 30, "output_count": 3, "unlock_level": 4, "tags": ["苦甜", "浓郁"]},
	"duck_egg_banana_griddle_cake": {"id": "duck_egg_banana_griddle_cake", "name": "鸭蛋香蕉煎糕", "device": "griddle", "materials": ["duck_egg", "banana", "flour", "milk"], "production_duration_seconds": 4, "price": 28, "output_count": 3, "unlock_level": 4, "tags": ["甜", "果香"]},
	"cheese_duck_baked_rice":       {"id": "cheese_duck_baked_rice", "name": "芝士鸭肉焗饭", "device": "oven", "materials": ["duck_meat", "rice", "cheese", "butter"], "production_duration_seconds": 4, "price": 38, "output_count": 2, "unlock_level": 4, "tags": ["咸香", "浓郁"]},
	"sea_salt_duck_rice_cup":       {"id": "sea_salt_duck_rice_cup", "name": "海盐鸭肉米盏", "device": "round_pot", "materials": ["duck_meat", "rice_flour", "sea_salt"], "production_duration_seconds": 2, "price": 32, "output_count": 3, "unlock_level": 4, "tags": ["咸香", "饱腹"]},
	"pumpkin_duck_pancake":         {"id": "pumpkin_duck_pancake", "name": "南瓜鸭肉煎饼", "device": "griddle", "materials": ["duck_meat", "pumpkin", "flour"], "production_duration_seconds": 2, "price": 34, "output_count": 3, "unlock_level": 4, "tags": ["咸香", "经典"]},
	"goat_milk_black_tea_jelly":    {"id": "goat_milk_black_tea_jelly", "name": "羊奶红茶冻", "device": "chiller", "materials": ["goat_milk", "black_tea", "gelatin", "sugar"], "production_duration_seconds": 4, "price": 36, "output_count": 3, "unlock_level": 5, "tags": ["茶香", "奶香"]},
	"matcha_goat_milk_mousse":      {"id": "matcha_goat_milk_mousse", "name": "抹茶羊奶慕斯", "device": "mixer", "materials": ["goat_milk", "matcha", "cream", "gelatin"], "production_duration_seconds": 4, "price": 40, "output_count": 3, "unlock_level": 5, "tags": ["茶香", "浓郁"]},
	"goat_milk_oats_porridge":      {"id": "goat_milk_oats_porridge", "name": "羊奶燕麦粥", "device": "round_pot", "materials": ["goat_milk", "oats", "sugar"], "production_duration_seconds": 2, "price": 28, "output_count": 3, "unlock_level": 5, "tags": ["低负担", "奶香"]},
	"chestnut_mutton_baked_rice":   {"id": "chestnut_mutton_baked_rice", "name": "栗子羊肉焗饭", "device": "oven", "materials": ["mutton", "rice", "chestnut", "butter"], "production_duration_seconds": 4, "price": 42, "output_count": 2, "unlock_level": 5, "tags": ["咸香", "饱腹"]},
	"black_tea_mutton_pastry":      {"id": "black_tea_mutton_pastry", "name": "红茶羊肉酥饼", "device": "oven", "materials": ["mutton", "black_tea", "flour", "butter"], "production_duration_seconds": 4, "price": 40, "output_count": 3, "unlock_level": 5, "tags": ["茶香", "咸香"]},
	"mutton_glutinous_shumai":      {"id": "mutton_glutinous_shumai", "name": "羊肉糯米烧卖", "device": "round_pot", "materials": ["mutton", "glutinous_rice_flour", "sea_salt"], "production_duration_seconds": 2, "price": 38, "output_count": 3, "unlock_level": 5, "tags": ["咸香", "饱腹"]},

	# ===== 现有原材料扩展配方 =====
	"cinnamon_chestnut_scone":      {"id": "cinnamon_chestnut_scone", "name": "肉桂栗子司康", "device": "oven", "materials": ["flour", "butter", "chestnut", "cinnamon", "milk"], "production_duration_seconds": 8, "price": 34, "output_count": 3, "unlock_level": 5, "tags": ["香脆", "浓郁"]},
	"almond_orange_cookie":         {"id": "almond_orange_cookie", "name": "杏仁橙香曲奇", "device": "oven", "materials": ["flour", "butter", "almond", "orange", "sugar"], "production_duration_seconds": 8, "price": 32, "output_count": 4, "unlock_level": 5, "tags": ["香脆", "果香"]},
	"beef_wheat_porridge":          {"id": "beef_wheat_porridge", "name": "牛肉麦仁粥", "device": "round_pot", "materials": ["wheat", "beef", "spring_water", "sea_salt"], "production_duration_seconds": 4, "price": 28, "output_count": 3, "unlock_level": 3, "tags": ["饱腹", "咸香"]},
	"vanilla_peach_panna_cotta":    {"id": "vanilla_peach_panna_cotta", "name": "香草蜜桃奶冻", "device": "chiller", "materials": ["peach", "milk", "cream", "vanilla", "gelatin"], "production_duration_seconds": 8, "price": 34, "output_count": 3, "unlock_level": 3, "tags": ["果香", "奶香"]},
	"caramel_duck_egg_pudding":     {"id": "caramel_duck_egg_pudding", "name": "焦糖鸭蛋布丁", "device": "chiller", "materials": ["duck_egg", "milk", "caramel", "sugar"], "production_duration_seconds": 4, "price": 32, "output_count": 3, "unlock_level": 4, "tags": ["经典", "浓郁"]},
	"orange_goat_milk_jelly":       {"id": "orange_goat_milk_jelly", "name": "橙香羊奶冻", "device": "chiller", "materials": ["goat_milk", "orange", "gelatin", "honey"], "production_duration_seconds": 4, "price": 36, "output_count": 3, "unlock_level": 5, "tags": ["奶香", "清爽"]},
	"honey_orange_duck_baked_rice": {"id": "honey_orange_duck_baked_rice", "name": "蜜橙鸭肉焗饭", "device": "oven", "materials": ["duck_meat", "rice", "orange", "honey", "sea_salt"], "production_duration_seconds": 8, "price": 42, "output_count": 2, "unlock_level": 4, "tags": ["果香", "咸香"]}
}

const PROCESSING_RECIPES := {
	"rice_flour_process":           {"id": "rice_flour_process", "name": "大米粉加工", "device": "grinder", "materials": ["rice"], "output_item_id": "rice_flour", "output_count": 2, "production_duration_seconds": 2, "unlock_level": 1},
	"wheat_flour_process":          {"id": "wheat_flour_process", "name": "面粉加工", "device": "grinder", "materials": ["wheat"], "output_item_id": "flour", "output_count": 2, "production_duration_seconds": 2, "unlock_level": 1},
	"glutinous_rice_flour_process": {"id": "glutinous_rice_flour_process", "name": "糯米粉加工", "device": "grinder", "materials": ["glutinous_rice"], "output_item_id": "glutinous_rice_flour", "output_count": 2, "production_duration_seconds": 4, "unlock_level": 4},
	"matcha_process":               {"id": "matcha_process", "name": "抹茶加工", "device": "grinder", "materials": ["green_tea"], "output_item_id": "matcha", "output_count": 1, "production_duration_seconds": 4, "unlock_level": 5},
	"cocoa_process":                {"id": "cocoa_process", "name": "可可粉加工", "device": "grinder", "materials": ["coffee"], "output_item_id": "cocoa", "output_count": 1, "production_duration_seconds": 4, "unlock_level": 4},
	"yogurt_process":               {"id": "yogurt_process", "name": "酸奶发酵", "device": "round_pot", "materials": ["milk", "yeast"], "output_item_id": "yogurt", "output_count": 1, "production_duration_seconds": 8, "unlock_level": 4}
}

const CUSTOMERS := {
	"student": {"id": "student", "name": "放学学生", "preference_tags": ["甜"], "low_price_threshold": 20, "budget": 20, "unlock_level": 1, "description": "喜欢便宜、直接的甜味"},
	"office_worker": {"id": "office_worker", "name": "加班白领", "preference_tags": ["苦甜", "浓郁"], "budget": 35, "unlock_level": 2, "description": "偏好咖啡、巧克力、奶油"},
	"family": {"id": "family", "name": "亲子家庭", "preference_tags": ["果香", "经典"], "budget": 40, "unlock_level": 2, "description": "喜欢安全感强的水果和经典款"},
	"fitness_neighbor": {"id": "fitness_neighbor", "name": "健身居民", "preference_tags": ["清爽", "低负担"], "budget": 35, "unlock_level": 3, "description": "喜欢酸奶、清爽、水果"},
	"old_regular": {"id": "old_regular", "name": "老街熟客", "preference_tags": ["经典", "甜"], "budget": 30, "unlock_level": 3, "description": "偏好朴素熟悉的点心"},
	"blogger": {"id": "blogger", "name": "探店博主", "preference_tags": ["招牌"], "budget": 50, "unlock_level": 5, "description": "追求高价值和特色标签"}
}

const MAX_UPGRADE_LEVEL := 247

const UPGRADE_TABLE := {
	0: {"level": 0, "name": "圆锅教学期", "cost": 0, "required_reputation": 0, "target_business_days": 0.0, "display_slots": 1, "customer_count": 0, "device_id": "round_pot", "unlocks": ["大米", "泉水", "白糖", "蒸煮一体的圆锅"]},
	1: {"level": 1, "name": "研磨与正式营业", "cost": 0, "required_reputation": 0, "target_business_days": 0.0, "display_slots": 3, "customer_count": 12, "device_id": "grinder", "unlocks": ["研磨机", "小麦", "大米粉", "面粉", "小鸡仔", "鸡蛋", "鸡肉", "黄油"]},
	2: {"level": 2, "name": "基础烘焙", "cost": 900, "required_reputation": 30, "target_business_days": 5.0, "display_slots": 4, "customer_count": 16, "device_id": "oven", "unlocks": ["烤箱", "小牛犊", "牛奶", "牛肉", "香蕉", "草莓", "蓝莓", "基础烘焙配方"]},
	3: {"level": 3, "name": "冷藏与库存规划", "cost": 2200, "required_reputation": 80, "target_business_days": 6.0, "display_slots": 4, "customer_count": 20, "device_id": "chiller", "unlocks": ["冷藏柜", "蜜蜂群", "蜂蜜", "桃子", "苹果", "柠檬", "橙子", "芒果"]},
	4: {"level": 4, "name": "煎烤与多设备菜单", "cost": 4500, "required_reputation": 170, "target_business_days": 7.0, "display_slots": 5, "customer_count": 24, "device_id": "griddle", "unlocks": ["煎烤盘", "小鸭苗", "鸭蛋", "鸭肉", "南瓜", "糯米", "咖啡", "可可粉"]},
	5: {"level": 5, "name": "搅拌与招牌经营", "cost": 8000, "required_reputation": 300, "target_business_days": 8.0, "display_slots": 5, "customer_count": 28, "device_id": "mixer", "unlocks": ["搅拌机", "小羊羔", "羊奶", "羊肉", "红茶", "绿茶", "抹茶", "持续经营等级"]},
	6: {"level": 6, "name": "经营合同起步", "cost": 13000, "required_reputation": 500, "target_business_days": 9.0, "display_slots": 5, "customer_count": 28, "device_id": "", "unlocks": ["经营合同循环"]}
}

const LEVEL_MILESTONES := {}
static var _required_reputation_cache := {6: 500}

func get_ingredients() -> Dictionary:
	return INGREDIENTS.duplicate(true)


func get_production_sites() -> Dictionary:
	return PRODUCTION_SITES.duplicate(true)


func get_devices() -> Dictionary:
	return DEVICES.duplicate(true)


func get_recipes() -> Dictionary:
	return RECIPES.duplicate(true)


func get_processing_recipes() -> Dictionary:
	return PROCESSING_RECIPES.duplicate(true)


static func processing_recipe_duration(process_id: String) -> int:
	if not PROCESSING_RECIPES.has(process_id):
		return 0
	return maxi(1, int((PROCESSING_RECIPES[process_id] as Dictionary).get("production_duration_seconds", 1)))


func get_customers() -> Dictionary:
	return CUSTOMERS.duplicate(true)


func get_upgrade_table() -> Dictionary:
	return UPGRADE_TABLE.duplicate(true)


func get_upgrade_definition(target_level: int) -> Dictionary:
	if target_level < 0:
		return {}
	if target_level > MAX_UPGRADE_LEVEL:
		return {}
	if UPGRADE_TABLE.has(target_level):
		var base_definition: Dictionary = UPGRADE_TABLE[target_level].duplicate(true)
		base_definition["milestone"] = LEVEL_MILESTONES.get(target_level, {}).duplicate(true)
		return base_definition
	if target_level < 7:
		return {}

	var target_days := _target_business_days(target_level)
	var milestone: Dictionary = LEVEL_MILESTONES.get(target_level, {}).duplicate(true)
	return {
		"level": target_level,
		"name": String(milestone.get("name", "持续经营 Lv.%d" % target_level)),
		"cost": _round_to_500(15000.0 * pow(1.15, float(target_level - 7)) * (target_days / 10.0)),
		"required_reputation": _required_reputation_for_level(target_level),
		"reputation_increment": _reputation_increment_for_level(target_level),
		"target_business_days": target_days,
		"display_slots": 5,
		"customer_count": 28,
		"device_id": String(milestone.get("device_id", "")),
		"unlocks": milestone.get("unlocks", []).duplicate(true),
		"milestone": milestone
	}


func get_next_level_milestone(current_level: int) -> Dictionary:
	var milestone_levels: Array = LEVEL_MILESTONES.keys()
	milestone_levels.sort()
	for level_value: Variant in milestone_levels:
		var milestone_level := int(level_value)
		if milestone_level <= current_level:
			continue
		var milestone: Dictionary = LEVEL_MILESTONES[milestone_level].duplicate(true)
		milestone["level"] = milestone_level
		return milestone
	return {}


func _target_business_days(target_level: int) -> float:
	var segment := int(floor(float(target_level - 7) / 5.0))
	return minf(16.0, 10.0 + float(segment))


func _reputation_increment_for_level(target_level: int) -> int:
	var target_days := _target_business_days(target_level)
	var raw_increment := target_days * (22.0 + 2.0 * float(target_level - 7))
	return _round_to_10(raw_increment)


func _required_reputation_for_level(target_level: int) -> int:
	if target_level <= 6:
		return int(UPGRADE_TABLE.get(target_level, {}).get("required_reputation", 0))
	if _required_reputation_cache.has(target_level):
		return int(_required_reputation_cache[target_level])
	var highest_cached_level := 6
	for cached_level_value: Variant in _required_reputation_cache:
		highest_cached_level = maxi(highest_cached_level, int(cached_level_value))
	var cumulative := int(_required_reputation_cache.get(highest_cached_level, 500))
	for level_value in range(highest_cached_level + 1, target_level + 1):
		cumulative += _reputation_increment_for_level(level_value)
		_required_reputation_cache[level_value] = cumulative
	return cumulative


func _round_to_500(value: float) -> int:
	return int(round(value / 500.0)) * 500


func _round_to_10(value: float) -> int:
	return int(round(value / 10.0)) * 10


func get_purchase_categories() -> Array:
	return PURCHASE_CATEGORIES.duplicate(true)


func get_tools() -> Dictionary:
	return TOOLS.duplicate(true)


func get_production_slot_unlock_costs() -> Array:
	return PRODUCTION_SLOT_UNLOCK_COSTS.duplicate(true)


func get_production_bag_page_unlock_costs() -> Array:
	return PRODUCTION_BAG_PAGE_UNLOCK_COSTS.duplicate(true)

func get_recipe_display_config() -> Dictionary:
	return _load_json_dictionary(RECIPE_DISPLAY_CONFIG_PATH)


func get_display_rules() -> Dictionary:
	var rules := _load_json_dictionary(DISPLAY_RULES_PATH)
	if not rules.is_empty():
		return rules
	push_error("Display rules could not be loaded from %s" % DISPLAY_RULES_PATH)
	return {
		"meta": {"version": "missing", "total_rules": 0},
		"base_tag_bonuses": {},
		"set_bonuses": {},
		"conflict_penalties": {},
		"zone_bonuses": {},
	}


func get_showcase_round_rules() -> Dictionary:
	return _load_json_dictionary(SHOWCASE_ROUND_RULES_PATH)


func clear_json_cache() -> void:
	_json_dictionary_cache.clear()


func cached_json_path_count() -> int:
	return _json_dictionary_cache.size()


func _load_json_dictionary(path: String) -> Dictionary:
	if _json_dictionary_cache.has(path):
		var cached: Dictionary = _json_dictionary_cache[path]
		return cached.duplicate(true)
	if not FileAccess.file_exists(path):
		_json_dictionary_cache[path] = {}
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_json_dictionary_cache[path] = {}
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var value: Dictionary = parsed
		_json_dictionary_cache[path] = value.duplicate(true)
		return value.duplicate(true)
	_json_dictionary_cache[path] = {}
	return {}
