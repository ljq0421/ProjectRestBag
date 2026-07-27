class_name ProgressionAccessService
extends RefCounted

const PURCHASE_REGION_LEVELS := {
	"农场": 0,
	"养殖场": 1,
	"水塘": 1,
	"辅料": 1,
	"工具": 1,
	"林场": 2,
}

const OUTPUT_SITE_LEVELS := {
	"farm": 0,
	"ranch": 1,
	"pond": 1,
	"forest": 2,
}


static func purchase_region_level(category_id: String) -> int:
	return maxi(0, int(PURCHASE_REGION_LEVELS.get(category_id, 0)))


static func output_site_level(site_id: String) -> int:
	return maxi(0, int(OUTPUT_SITE_LEVELS.get(site_id, 0)))


static func is_purchase_region_open(category_id: String, shop_level: int) -> bool:
	return shop_level >= purchase_region_level(category_id)


static func is_output_site_open(site_id: String, shop_level: int) -> bool:
	return shop_level >= output_site_level(site_id)


static func level_lock_text(required_level: int) -> String:
	return "🔒 Lv.%d 开放" % maxi(0, required_level)
