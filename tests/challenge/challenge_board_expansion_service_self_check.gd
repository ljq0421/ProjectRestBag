extends SceneTree

const Service = preload("res://scripts/challenge/challenge_board_expansion_service.gd")


func _init() -> void:
	var service = Service.new()
	var meta := service.bootstrap_meta({})
	var cells: Array = service.unlocked_cells(meta)
	_expect(cells.size() == 16, "initial board must unlock exactly 4 x 4 cells")
	_expect(int(meta.get("expansion_tickets", -1)) == 0, "initial tickets must be zero")

	var products := service.products()
	_expect(products.size() == 6, "six expansion shapes must be available")
	_expect(_price(products, "bar_3") == 3, "bar 3 must cost three tickets")
	_expect(_price(products, "l_4") == 4, "L 4 must cost four tickets")

	var rewarded := service.grant_ticket(meta, "elite:first")
	_expect(bool(rewarded.get("applied", false)), "first elite clear must grant a ticket")
	meta = rewarded.get("meta", {})
	var duplicate := service.grant_ticket(meta, "elite:first")
	_expect(not bool(duplicate.get("applied", false)), "ticket reward must be idempotent")

	meta["expansion_tickets"] = 4
	var valid := service.preview(meta, "l_4", 0, Vector2i(2, 3))
	_expect(bool(valid.get("valid", false)), "L 4 must attach to the left edge")
	var purchased := service.purchase(meta, "l_4", 0, Vector2i(2, 3))
	_expect(bool(purchased.get("applied", false)), "valid L 4 purchase must apply")
	var next_meta: Dictionary = purchased.get("meta", {})
	_expect(int(next_meta.get("expansion_tickets", -1)) == 0, "purchase must charge after placement")
	_expect(service.unlocked_cells(next_meta).size() == 20, "L 4 must add four cells")

	var disconnected := service.preview(next_meta, "single_1", 0, Vector2i(0, 13))
	_expect(not bool(disconnected.get("valid", false)), "disconnected placement must be rejected")
	print("PASS challenge_board_expansion_service_self_check")
	quit(0)


func _price(products: Array, product_id: String) -> int:
	for product in products:
		if String(product.get("id", "")) == product_id:
			return int(product.get("price", -1))
	return -1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
